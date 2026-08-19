-- =====================================================================
-- 0007 — EŞLEŞTİRME (MATCHMAKING) FONKSİYONLARI
-- =====================================================================
-- AKIŞ:
--   1) Flutter -> rpc('find_match', {deck_id, protected_card_ids})
--   2) Fonksiyon desteyi ve koruma listesini doğrular.
--   3) Kuyrukta uygun rakip varsa MAÇ KURULUR, match_id döner.
--   4) Rakip yoksa oyuncu kuyruğa yazılır ve NULL döner.
--   5) Bekleyen oyuncu kendi matchmaking_queue satırını Realtime ile
--      dinler; karşı taraf onu bulunca match_id alanı dolar ve
--      oyun ekranına geçer.
-- =====================================================================

-- ---------------------------------------------------------------------
-- YARDIMCI: Oyuncunun devam eden bir maçı var mı?
-- ---------------------------------------------------------------------
create or replace function public.get_active_match_id(p_user_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select m.id
  from public.matches m
  where m.status = 'active'
    and (m.player1_id = p_user_id or m.player2_id = p_user_id)
  order by m.created_at desc
  limit 1;
$$;

-- ---------------------------------------------------------------------
-- İÇ FONKSİYON: İki oyuncu arasında maç kurar ve kartları dağıtır.
-- ---------------------------------------------------------------------
create or replace function public._create_match(
  p_user_a uuid, p_deck_a uuid, p_prot_a uuid[],
  p_user_b uuid, p_deck_b uuid, p_prot_b uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_match_id uuid;
  v_starter  uuid;
begin
  -- İLK BAŞLAYANI SUNUCU RASTGELE SEÇER (istemci karışamaz)
  v_starter := case when random() < 0.5 then p_user_a else p_user_b end;

  insert into public.matches (
    player1_id, player2_id,
    current_turn_id, lead_player_id,
    turn_deadline
  )
  values (
    p_user_a, p_user_b,
    v_starter, v_starter,
    now() + make_interval(secs => public.turn_timeout_seconds())
  )
  returning id into v_match_id;

  -- Maç oyuncu satırları
  insert into public.match_players (match_id, user_id, deck_id, protected_card_ids)
  values (v_match_id, p_user_a, p_deck_a, p_prot_a),
         (v_match_id, p_user_b, p_deck_b, p_prot_b);

  -- ELLERİ DAĞIT: Destedeki 11 kartın o anki değerlerini dondurarak kopyala
  insert into public.match_hands (
    match_id, user_id, user_card_id, card_id, position, tier, power
  )
  select v_match_id, uc.owner_id, uc.id, c.id, c.position, c.tier, c.power
  from public.deck_cards dc
  join public.user_cards uc on uc.id = dc.user_card_id
  join public.cards c       on c.id  = uc.card_id
  where dc.deck_id in (p_deck_a, p_deck_b);

  -- KARTLARI KİLİTLE: maç bitene kadar deste değiştirilemez / satılamaz
  update public.user_cards uc
  set locked_match_id = v_match_id
  where uc.id in (
    select dc.user_card_id from public.deck_cards dc
    where dc.deck_id in (p_deck_a, p_deck_b)
  );

  return v_match_id;
end;
$$;

-- ---------------------------------------------------------------------
-- YARDIMCI: Koruma listesi geçerli mi?
-- ---------------------------------------------------------------------
-- NULL dönerse geçerli, aksi halde Türkçe hata mesajı.
create or replace function public.validate_protection(
  p_user_id uuid, p_deck_id uuid, p_protected uuid[]
)
returns text
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_slots int;
  v_count int;
  v_in_deck int;
begin
  select protection_slots into v_slots
  from public.profiles where id = p_user_id;

  v_count := coalesce(array_length(p_protected, 1), 0);

  if v_count > least(v_slots, public.max_protection_slots()) then
    return format('En fazla %s kart korumaya alabilirsiniz.',
                  least(v_slots, public.max_protection_slots()));
  end if;

  if v_count = 0 then
    return null;
  end if;

  -- Korunan kartların hepsi bu destede olmalı
  select count(*) into v_in_deck
  from unnest(p_protected) pid
  where exists (
    select 1 from public.deck_cards dc
    where dc.deck_id = p_deck_id and dc.user_card_id = pid
  );

  if v_in_deck <> v_count then
    return 'Korumaya aldiginiz kartlarin tamami kadronuzda olmali.';
  end if;

  -- Aynı kart iki kez gönderilmiş olabilir
  if (select count(distinct x) from unnest(p_protected) x) <> v_count then
    return 'Ayni kart birden fazla kez korumaya alinamaz.';
  end if;

  return null;
end;
$$;

-- ---------------------------------------------------------------------
-- ANA RPC: MAÇ ARA
-- ---------------------------------------------------------------------
-- Dönüş (json):
--   { "status": "matched",   "match_id": "..." }   -> Hemen maç bulundu
--   { "status": "queued",    "match_id": null  }   -> Kuyruğa alındı, bekle
--   { "status": "in_match",  "match_id": "..." }   -> Zaten devam eden maçın var
-- Hata durumunda exception fırlatır (Flutter'da PostgrestException olarak yakalanır).
create or replace function public.find_match(
  p_deck_id uuid,
  p_protected_card_ids uuid[] default '{}'
)
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid       uuid := auth.uid();
  v_err       text;
  v_mmr       int;
  v_banned    boolean;
  v_active    uuid;
  v_opponent  record;
  v_match_id  uuid;
begin
  if v_uid is null then
    raise exception 'Oturum bulunamadi. Lutfen tekrar giris yapin.';
  end if;

  select mmr, is_banned into v_mmr, v_banned
  from public.profiles where id = v_uid;

  if v_banned then
    raise exception 'Hesabiniz askiya alinmis. Mac aranamaz.';
  end if;

  -- Zaten devam eden maçı varsa direkt oraya yönlendir
  v_active := public.get_active_match_id(v_uid);
  if v_active is not null then
    return json_build_object('status', 'in_match', 'match_id', v_active);
  end if;

  -- Deste ve koruma doğrulaması (İSTEMCİYE GÜVENME)
  v_err := public.validate_deck(v_uid, p_deck_id);
  if v_err is not null then
    raise exception '%', v_err;
  end if;

  v_err := public.validate_protection(v_uid, p_deck_id, p_protected_card_ids);
  if v_err is not null then
    raise exception '%', v_err;
  end if;

  -- -------------------------------------------------------------------
  -- KRİTİK BÖLGE (Race Condition koruması)
  -- -------------------------------------------------------------------
  -- İki oyuncu aynı milisaniyede "Maç Ara" derse ikisi de birbirini
  -- görmeyip kuyrukta kalabilir ya da üç kişilik maç kurulabilir.
  -- Bu advisory lock sayesinde eşleştirme kodu aynı anda tek bir
  -- transaction tarafından çalıştırılır. Transaction bitince otomatik açılır.
  perform pg_advisory_xact_lock(hashtext('futbol_card_matchmaking'));

  -- Bayat kuyruk kayıtlarını temizle (uygulama kapanmış olabilir)
  delete from public.matchmaking_queue
  where status = 'searching'
    and updated_at < now() - interval '2 minutes';

  -- Uygun rakip ara: MMR farkı en yakın olan, eşitlikte en uzun bekleyen.
  -- Bekleme süresi arttıkça MMR toleransı da genişler (her 10 sn'de +50).
  select q.user_id, q.deck_id, q.protected_card_ids
  into v_opponent
  from public.matchmaking_queue q
  where q.status = 'searching'
    and q.user_id <> v_uid
    and abs(q.mmr - v_mmr) <=
        200 + (extract(epoch from (now() - q.created_at)) / 10)::int * 50
  order by abs(q.mmr - v_mmr) asc, q.created_at asc
  limit 1
  for update skip locked;

  if found then
    -- Rakibin destesi hâlâ geçerli mi? (bu arada kart kaybetmiş olabilir)
    v_err := public.validate_deck(v_opponent.user_id, v_opponent.deck_id);

    if v_err is not null then
      -- Rakibin destesi bozulmuş: kuyruktan düşür, bu oyuncuyu kuyruğa al
      update public.matchmaking_queue
      set status = 'cancelled'
      where user_id = v_opponent.user_id;
    else
      v_match_id := public._create_match(
        v_opponent.user_id, v_opponent.deck_id, v_opponent.protected_card_ids,
        v_uid,              p_deck_id,          p_protected_card_ids
      );

      -- Bekleyen oyuncuya Realtime ile haber ver
      update public.matchmaking_queue
      set status = 'matched', match_id = v_match_id
      where user_id = v_opponent.user_id;

      -- Kendi kuyruk kaydımız varsa onu da kapat
      update public.matchmaking_queue
      set status = 'matched', match_id = v_match_id
      where user_id = v_uid;

      return json_build_object('status', 'matched', 'match_id', v_match_id);
    end if;
  end if;

  -- Rakip yok -> kuyruğa gir (upsert: tekrar tuşa basarsa hata vermesin)
  insert into public.matchmaking_queue (user_id, deck_id, protected_card_ids, mmr, status, match_id)
  values (v_uid, p_deck_id, p_protected_card_ids, v_mmr, 'searching', null)
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
-- KUYRUKTAN ÇIK (İptal)
-- ---------------------------------------------------------------------
create or replace function public.cancel_matchmaking()
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.matchmaking_queue%rowtype;
begin
  if v_uid is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  select * into v_row from public.matchmaking_queue where user_id = v_uid;

  if not found then
    return json_build_object('status', 'not_in_queue');
  end if;

  -- Bu arada eşleşme olduysa iptal edilemez, maça yönlendir
  if v_row.status = 'matched' and v_row.match_id is not null then
    return json_build_object('status', 'matched', 'match_id', v_row.match_id);
  end if;

  delete from public.matchmaking_queue where user_id = v_uid;
  return json_build_object('status', 'cancelled');
end;
$$;

-- ---------------------------------------------------------------------
-- YETKİLENDİRME
-- ---------------------------------------------------------------------
-- İç fonksiyonlar istemciye kapalı, sadece RPC'ler açık.
revoke all on function public._create_match(uuid, uuid, uuid[], uuid, uuid, uuid[]) from public, anon, authenticated;

grant execute on function public.find_match(uuid, uuid[])              to authenticated;
grant execute on function public.cancel_matchmaking()                  to authenticated;
grant execute on function public.get_active_match_id(uuid)             to authenticated;
grant execute on function public.validate_deck(uuid, uuid)             to authenticated;
grant execute on function public.validate_protection(uuid, uuid, uuid[]) to authenticated;
