-- =====================================================================
-- 006 - ESLESTIRME (MATCHMAKING) FONKSIYONLARI
-- =====================================================================
-- DEGISIKLIK NOTU (Supabase'den gecis):
-- Supabase'de kullanici kimligi auth.uid() ile otomatik geliyordu.
-- Simdi backend, JWT'den cozdugu kullanici kimligini p_user_id
-- parametresi olarak geciriyor.
--
-- ONEMLI: p_user_id'yi backend BELIRLER, istemci degil. Uygulama
-- "ben su kullaniciyim" diyemez; backend jetondan okur.
-- =====================================================================

-- ---------------------------------------------------------------------
-- YARDIMCI: Oyuncunun devam eden bir maci var mi?
-- ---------------------------------------------------------------------
create or replace function get_active_match_id(p_user_id uuid)
returns uuid
language sql
stable
as $$
  select m.id
  from matches m
  where m.status = 'active'
    and (m.player1_id = p_user_id or m.player2_id = p_user_id)
  order by m.created_at desc
  limit 1;
$$;

-- ---------------------------------------------------------------------
-- IC FONKSIYON: Iki oyuncu arasinda mac kurar ve kartlari dagitir.
-- ---------------------------------------------------------------------
create or replace function _create_match(
  p_user_a uuid, p_deck_a uuid, p_prot_a uuid[],
  p_user_b uuid, p_deck_b uuid, p_prot_b uuid[]
)
returns uuid
language plpgsql
as $$
declare
  v_match_id uuid;
  v_starter  uuid;
begin
  -- ILK BASLAYANI SUNUCU RASTGELE SECER (istemci karisamaz)
  v_starter := case when random() < 0.5 then p_user_a else p_user_b end;

  insert into matches (
    player1_id, player2_id,
    current_turn_id, lead_player_id,
    turn_deadline
  )
  values (
    p_user_a, p_user_b,
    v_starter, v_starter,
    now() + make_interval(secs => turn_timeout_seconds())
  )
  returning id into v_match_id;

  insert into match_players (match_id, user_id, deck_id, protected_card_ids)
  values (v_match_id, p_user_a, p_deck_a, p_prot_a),
         (v_match_id, p_user_b, p_deck_b, p_prot_b);

  -- ELLERI DAGIT: Destedeki 11 kartin o anki degerlerini dondurarak kopyala
  insert into match_hands (
    match_id, user_id, user_card_id, card_id, position, tier, power
  )
  select v_match_id, uc.owner_id, uc.id, c.id, c.position, c.tier, c.power
  from deck_cards dc
  join user_cards uc on uc.id = dc.user_card_id
  join cards c       on c.id  = uc.card_id
  where dc.deck_id in (p_deck_a, p_deck_b);

  -- KARTLARI KILITLE: mac bitene kadar deste degistirilemez / satilamaz
  update user_cards uc
  set locked_match_id = v_match_id
  where uc.id in (
    select dc.user_card_id from deck_cards dc
    where dc.deck_id in (p_deck_a, p_deck_b)
  );

  return v_match_id;
end;
$$;

-- ---------------------------------------------------------------------
-- YARDIMCI: Koruma listesi gecerli mi?
-- ---------------------------------------------------------------------
-- NULL donerse gecerli, aksi halde Turkce hata mesaji.
create or replace function validate_protection(
  p_user_id uuid, p_deck_id uuid, p_protected uuid[]
)
returns text
language plpgsql
stable
as $$
declare
  v_slots int;
  v_count int;
  v_in_deck int;
begin
  select protection_slots into v_slots from users where id = p_user_id;

  v_count := coalesce(array_length(p_protected, 1), 0);

  if v_count > least(v_slots, max_protection_slots()) then
    return format('En fazla %s kart korumaya alabilirsiniz.',
                  least(v_slots, max_protection_slots()));
  end if;

  if v_count = 0 then
    return null;
  end if;

  select count(*) into v_in_deck
  from unnest(p_protected) pid
  where exists (
    select 1 from deck_cards dc
    where dc.deck_id = p_deck_id and dc.user_card_id = pid
  );

  if v_in_deck <> v_count then
    return 'Korumaya aldiginiz kartlarin tamami kadronuzda olmali.';
  end if;

  if (select count(distinct x) from unnest(p_protected) x) <> v_count then
    return 'Ayni kart birden fazla kez korumaya alinamaz.';
  end if;

  return null;
end;
$$;

-- ---------------------------------------------------------------------
-- ANA FONKSIYON: MAC ARA
-- ---------------------------------------------------------------------
-- Donus (json):
--   { "status": "matched",  "match_id": "..." }  -> Hemen mac bulundu
--   { "status": "queued",   "match_id": null  }  -> Kuyruga alindi, bekle
--   { "status": "in_match", "match_id": "..." }  -> Zaten devam eden macin var
-- Hata durumunda exception firlatir; backend bunu 400 olarak dondurur.
create or replace function find_match(
  p_user_id uuid,
  p_deck_id uuid,
  p_protected_card_ids uuid[] default '{}'
)
returns json
language plpgsql
as $$
declare
  v_err       text;
  v_mmr       int;
  v_banned    boolean;
  v_active    uuid;
  v_opponent  record;
  v_match_id  uuid;
begin
  select mmr, is_banned into v_mmr, v_banned
  from users where id = p_user_id;

  if not found then
    raise exception 'Kullanici bulunamadi.';
  end if;

  if v_banned then
    raise exception 'Hesabiniz askiya alinmis. Mac aranamaz.';
  end if;

  -- Zaten devam eden maci varsa direkt oraya yonlendir
  v_active := get_active_match_id(p_user_id);
  if v_active is not null then
    return json_build_object('status', 'in_match', 'match_id', v_active);
  end if;

  -- Deste ve koruma dogrulamasi (ISTEMCIYE GUVENME)
  v_err := validate_deck(p_user_id, p_deck_id);
  if v_err is not null then
    raise exception '%', v_err;
  end if;

  v_err := validate_protection(p_user_id, p_deck_id, p_protected_card_ids);
  if v_err is not null then
    raise exception '%', v_err;
  end if;

  -- -------------------------------------------------------------------
  -- KRITIK BOLGE (Race Condition korumasi)
  -- -------------------------------------------------------------------
  -- Iki oyuncu ayni milisaniyede "Mac Ara" derse ikisi de birbirini
  -- gormeyip kuyrukta kalabilir ya da bir oyuncu iki maca birden girebilir.
  -- Bu advisory lock sayesinde eslestirme kodu ayni anda tek bir
  -- transaction tarafindan calistirilir. Transaction bitince otomatik acilir.
  perform pg_advisory_xact_lock(hashtext('futbol_card_matchmaking'));

  -- Bayat kuyruk kayitlarini temizle (uygulama kapanmis olabilir)
  delete from matchmaking_queue
  where status = 'searching'
    and updated_at < now() - interval '2 minutes';

  -- Uygun rakip ara: MMR farki en yakin olan, esitlikte en uzun bekleyen.
  -- Bekleme suresi arttikca MMR toleransi genisler (her 10 sn'de +50).
  select q.user_id, q.deck_id, q.protected_card_ids
  into v_opponent
  from matchmaking_queue q
  where q.status = 'searching'
    and q.user_id <> p_user_id
    and abs(q.mmr - v_mmr) <=
        200 + (extract(epoch from (now() - q.created_at)) / 10)::int * 50
  order by abs(q.mmr - v_mmr) asc, q.created_at asc
  limit 1
  for update skip locked;

  if found then
    -- Rakibin destesi hala gecerli mi? (bu arada kart kaybetmis olabilir)
    v_err := validate_deck(v_opponent.user_id, v_opponent.deck_id);

    if v_err is not null then
      -- Rakibin destesi bozulmus: kuyruktan dusur
      update matchmaking_queue
      set status = 'cancelled'
      where user_id = v_opponent.user_id;
    else
      v_match_id := _create_match(
        v_opponent.user_id, v_opponent.deck_id, v_opponent.protected_card_ids,
        p_user_id,          p_deck_id,          p_protected_card_ids
      );

      -- Bekleyen oyuncuya haber ver (NOTIFY trigger'i devreye girer)
      update matchmaking_queue
      set status = 'matched', match_id = v_match_id
      where user_id = v_opponent.user_id;

      update matchmaking_queue
      set status = 'matched', match_id = v_match_id
      where user_id = p_user_id;

      return json_build_object('status', 'matched', 'match_id', v_match_id);
    end if;
  end if;

  -- Rakip yok -> kuyruga gir
  insert into matchmaking_queue (user_id, deck_id, protected_card_ids, mmr, status, match_id)
  values (p_user_id, p_deck_id, p_protected_card_ids, v_mmr, 'searching', null)
  on conflict (user_id) do update
  set deck_id            = excluded.deck_id,
      protected_card_ids = excluded.protected_card_ids,
      mmr                = excluded.mmr,
      status             = 'searching',
      match_id           = null,
      updated_at         = now();

  return json_build_object('status', 'queued', 'match_id', null);
end;
$$;

-- ---------------------------------------------------------------------
-- KUYRUKTAN CIK (Iptal)
-- ---------------------------------------------------------------------
create or replace function cancel_matchmaking(p_user_id uuid)
returns json
language plpgsql
as $$
declare
  v_row matchmaking_queue%rowtype;
begin
  select * into v_row from matchmaking_queue where user_id = p_user_id;

  if not found then
    return json_build_object('status', 'not_in_queue');
  end if;

  -- Bu arada eslesme olduysa iptal edilemez, maca yonlendir
  if v_row.status = 'matched' and v_row.match_id is not null then
    return json_build_object('status', 'matched', 'match_id', v_row.match_id);
  end if;

  delete from matchmaking_queue where user_id = p_user_id;
  return json_build_object('status', 'cancelled');
end;
$$;
