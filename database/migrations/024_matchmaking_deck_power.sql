-- =====================================================================
-- 024: KADRO GUCUNU DE GOZETEN ESLESTIRME (ALTERNATIF, VARSAYILAN KAPALI)
-- =====================================================================
-- SORUN: Eslestirme sadece MMR'a bakiyor. Nufus simulasyonunda yeni
-- gelen (baslangic kadrosu, 1000 MMR) ilk 20 macinin %49'unda
-- "umutsuz" (ortalama kadro gucu farki >= 4) rakiple eslesiyor ve %28
-- puan aliyor. Siralama beceriyi degil kadroyu olcuyor.
--
-- ALTERNATIF 'combined': uzaklik = |dMMR|/100 + |dGuc|/1.5, bekleme
-- uzadikca sinir genisler. Simulasyonda yeni gelen %52 puan, umutsuz
-- mac %0; 40 kisilik nufusta bekleme p90 ~50 sn.
--
-- CANLI KURAL DEGISMEDI: matchmaking_settings.mode varsayilan 'mmr'.
-- Acmak (KULLANICI ONAYIYLA):
--   update matchmaking_settings set mode = 'combined';
-- Geri almak:
--   update matchmaking_settings set mode = 'mmr';
--
-- find_match govdesi 006'dan programla turetildi; farklar
-- "ESLESTIRME MODU (024)" ve 'combined' satirlari.
-- =====================================================================

create table if not exists matchmaking_settings (
  id          int primary key default 1 check (id = 1),
  mode        text not null default 'mmr' check (mode in ('mmr', 'combined')),
  updated_at  timestamptz not null default now()
);

insert into matchmaking_settings (id, mode) values (1, 'mmr')
on conflict (id) do nothing;

create or replace function matchmaking_mode() returns text
language sql stable as $$
  select coalesce((select mode from matchmaking_settings where id = 1), 'mmr')
$$;

-- Kadronun ortalama efektif gucu (guc + kimya), maca giren degerle ayni
create or replace function deck_power(p_deck_id uuid) returns numeric
language sql stable as $$
  select round(avg(c.power + coalesce(ch.chemistry, 0))::numeric, 2)
  from deck_cards dc
  join user_cards uc on uc.id = dc.user_card_id
  join cards c on c.id = uc.card_id
  left join calculate_deck_chemistry(p_deck_id) ch
    on ch.user_card_id = dc.user_card_id
  where dc.deck_id = p_deck_id
$$;

alter table matchmaking_queue add column if not exists deck_power numeric;

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
  v_mode      text := matchmaking_mode();          -- ESLESTIRME MODU (024)
  v_power     numeric;                             -- ESLESTIRME MODU (024)
  v_my_wait   int := 0;                            -- ESLESTIRME MODU (024)
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

  -- ESLESTIRME MODU (024): kadro gucu ve BENIM bekleme surem
  -- (find_match her 4 sn yeniden cagriliyor; ilk giris zamani korunuyor)
  v_power := deck_power(p_deck_id);
  select (extract(epoch from (now() - created_at)) / 10)::int
  into v_my_wait
  from matchmaking_queue
  where user_id = p_user_id and status = 'searching';
  v_my_wait := coalesce(v_my_wait, 0);

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
    and (
      -- 'mmr' (BUGUNKU KURAL, varsayilan): degismedi
      (v_mode = 'mmr' and abs(q.mmr - v_mmr) <=
        200 + (extract(epoch from (now() - q.created_at)) / 10)::int * 50)
      or
      -- 'combined' (ALTERNATIF, onay bekliyor): MMR + kadro gucu.
      -- Uzaklik = |dMMR|/100 + |dGuc|/1.5; sinir 2 + 0.5 x bekleme adimi
      -- (iki tarafin uzun bekleyeni esas alinir). Simulasyon:
      -- packages/tactics_prototype/lib/src/matchmaking.dart
      (v_mode = 'combined' and
        abs(q.mmr - v_mmr) / 100.0
          + abs(coalesce(q.deck_power, v_power) - v_power) / 1.5
        <= 2 + 0.5 * greatest(
             (extract(epoch from (now() - q.created_at)) / 10)::int,
             v_my_wait))
    )
  order by
    case when v_mode = 'combined'
         then abs(q.mmr - v_mmr) / 100.0
              + abs(coalesce(q.deck_power, v_power) - v_power) / 1.5
         else abs(q.mmr - v_mmr) end asc,
    q.created_at asc
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
  insert into matchmaking_queue (user_id, deck_id, protected_card_ids, mmr, deck_power, status, match_id)
  values (p_user_id, p_deck_id, p_protected_card_ids, v_mmr, v_power, 'searching', null)
  on conflict (user_id) do update
  set deck_id            = excluded.deck_id,
      protected_card_ids = excluded.protected_card_ids,
      mmr                = excluded.mmr,
      deck_power         = excluded.deck_power,
      status             = 'searching',
      match_id           = null,
      updated_at         = now();

  return json_build_object('status', 'queued', 'match_id', null);
end;
$$;

