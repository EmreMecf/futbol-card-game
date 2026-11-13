-- =====================================================================
-- 044 GUNLUK DONGU + MAGAZA TEKLIFI + PAKET SADELESTIRMESI (FAZ 5a, KAPALI)
-- =====================================================================
-- Onay: kullanici (13 Kasim 2026). Tasarim: docs/OYUN_TASARIMI_V3.md §4-5.
-- Kullanici kararlari:
--   * Gunluk ucretsiz sandik: her gun Bronz; ART ARDA 3. gunde Gumus
--     (seri bozulursa bastan). Gun = Turkiye saatiyle 00:00-24:00.
--   * Gunun ilk DERECELI galibiyeti: cift sezon XP'si (galibiyet XP'si
--     kadar ek; enerjisiz macta ayni oran). Altin degismez.
--   * Magaza: gunde 1 teklif, herkes icin ayni rastgele paket %25
--     indirimli, kisi basi gunde 1 alim (yalniz altin).
--   * Sadelestirme: paketten gelen ve SAHIP OLUNAN futbolcu fiziksel kopya
--     yerine GELISIM KOPYASI (sandik kurali; seviye 10'da joker, kadroda
--     o mevki eksikse fiziksel kart). Baslangic paketi haric.
--   * Hafta sonu etkinligi bu adimda YOK (ayri adim).
--
-- ANAHTARLAR (hepsi KAPALI):
--   'daily_loop'         : gunluk sandik + gunun ilk galibiyeti
--   'daily_shop'         : gunluk indirimli paket
--   'pack_duplicates_v2' : paket tekrar karti -> gelisim kopyasi
--
-- DEGISMEYENLER: mac, MMR, mac sandigi sanslari, paket sanslari ve
-- fiyatlari, sezon XP tablosu. Anahtarlar kapaliyken open_pack 011 ile
-- AYNI davranir (yalniz yanitta bos 'progress' alani).
-- =====================================================================

insert into economy_config_versions (kind, version, payload, note)
select 'feature_flags', max(version) + 1,
       (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1)
         || '{"daily_loop": false, "daily_shop": false, "pack_duplicates_v2": false}'::jsonb,
       '044: gunluk dongu + magaza teklifi + paket sadelestirmesi (kapali)'
from economy_config_versions
where kind = 'feature_flags'
  and not ((select payload from economy_config_versions where kind = 'feature_flags'
            order by version desc limit 1) ? 'daily_loop')
having count(*) > 0;

insert into economy_config_versions (kind, version, payload, note)
values ('daily_loop', 1, '{
  "timezone": "Europe/Istanbul",
  "chest": "bronze",
  "streak_chest": "silver",
  "streak_every": 3,
  "first_win_xp_multiplier": 2,
  "shop_packs": ["standard", "premium", "squad"],
  "shop_discount_pct": 25,
  "shop_per_day": 1
}'::jsonb, '044: gunluk dongu (kullanici onayli)')
on conflict (kind, version) do nothing;

create or replace function _daily_rules() returns jsonb
language sql stable as $$ select economy_config('daily_loop') $$;

-- Oyun gunu (Turkiye saati)
create or replace function game_day(p_at timestamptz default now()) returns date
language sql stable as $$
  select (p_at at time zone coalesce(_daily_rules() ->> 'timezone', 'Europe/Istanbul'))::date
$$;

-- Bir sonraki gun sinirinin zamani
create or replace function next_game_day_at() returns timestamptz
language sql stable as $$
  select ((game_day() + 1)::timestamp) at time zone coalesce(_daily_rules() ->> 'timezone', 'Europe/Istanbul')
$$;

-- ---------------------------------------------------------------------
-- 1) GUNLUK UCRETSIZ SANDIK (seri)
-- ---------------------------------------------------------------------
create table if not exists daily_chest_claims (
  user_id     uuid not null references users(id) on delete cascade,
  day         date not null,
  streak      int  not null check (streak >= 1),
  chest_type  text not null,
  chest_id    uuid,
  claimed_at  timestamptz not null default now(),
  primary key (user_id, day)
);

-- Gunun ilk galibiyeti kaydi (asagida 2. bolum kullanir)
create table if not exists daily_first_wins (
  user_id     uuid not null references users(id) on delete cascade,
  day         date not null,
  match_id    uuid not null references matches(id) on delete cascade,
  bonus_xp    int  not null,
  created_at  timestamptz not null default now(),
  primary key (user_id, day)
);

create or replace function daily_status(p_user_id uuid) returns jsonb
language sql stable as $$
  with k as (select _daily_rules() r),
       bugun as (select * from daily_chest_claims where user_id = p_user_id and day = game_day()),
       dun   as (select * from daily_chest_claims where user_id = p_user_id and day = game_day() - 1)
  select jsonb_build_object(
    'enabled',        economy_flag('daily_loop'),
    'shop_enabled',   economy_flag('daily_shop'),
    'day',            game_day(),
    'next_reset_at',  next_game_day_at(),
    'claimed_today',  exists (select 1 from bugun),
    'streak',         coalesce((select streak from bugun), (select streak from dun), 0),
    -- bugun alinacak (alinmadiysa) ya da alinan sandik
    'chest_type',     coalesce((select chest_type from bugun),
                        case when (coalesce((select streak from dun), 0) + 1) % ((select r from k) ->> 'streak_every')::int = 0
                             then (select r from k) ->> 'streak_chest' else (select r from k) ->> 'chest' end),
    'first_win_today', exists (select 1 from daily_first_wins where user_id = p_user_id and day = game_day()),
    'first_win_multiplier', ((select r from k) ->> 'first_win_xp_multiplier')::int)
$$;

create or replace function claim_daily_chest(p_user_id uuid) returns jsonb
language plpgsql as $$
declare
  k       jsonb := _daily_rules();
  v_gun   date := game_day();
  v_seri  int;
  v_tur   text;
  v_id    uuid;
  v_eski  daily_chest_claims%rowtype;
begin
  if not economy_flag('daily_loop') then
    raise exception 'daily_disabled: Gunluk sandik kapali.';
  end if;
  perform pg_advisory_xact_lock(hashtext('daily:' || p_user_id::text));
  select * into v_eski from daily_chest_claims where user_id = p_user_id and day = v_gun;
  if found then
    return jsonb_build_object('already_claimed', true, 'chest_id', v_eski.chest_id,
                              'chest_type', v_eski.chest_type, 'streak', v_eski.streak);
  end if;
  v_seri := coalesce((select streak from daily_chest_claims where user_id = p_user_id and day = v_gun - 1), 0) + 1;
  v_tur  := case when v_seri % (k ->> 'streak_every')::int = 0 then k ->> 'streak_chest' else k ->> 'chest' end;
  v_id   := _grant_chest(p_user_id, v_tur, 'daily', v_gun::text);
  insert into daily_chest_claims (user_id, day, streak, chest_type, chest_id)
  values (p_user_id, v_gun, v_seri, v_tur, v_id);
  return jsonb_build_object('already_claimed', false, 'chest_id', v_id, 'chest_type', v_tur, 'streak', v_seri);
end;
$$;

-- ---------------------------------------------------------------------
-- 2) GUNUN ILK DERECELI GALIBIYETI: cift sezon XP'si
-- ---------------------------------------------------------------------
create or replace function _daily_first_win_on_match_finished()
returns trigger language plpgsql as $$
declare
  s        jsonb;
  v_tur    int;
  v_xp     int;
  v_gun    date;
  v_ek     int;
begin
  if not economy_flag('daily_loop') or not economy_flag('economy_v2_enabled')
     or new.winner_id is null or new.is_draw
     or (select is_bot from users where id = new.winner_id) then
    return null;
  end if;
  s := _season_rules();
  if s is null then
    return null;
  end if;
  select count(*) into v_tur from match_rounds where match_id = new.id;
  if v_tur < coalesce((s ->> 'min_rounds')::int, 4) then
    return null;   -- K6: sezon XP'si de verilmez
  end if;
  begin
    v_gun := game_day(coalesce(new.finished_at, now()));
    -- normal galibiyet XP'si (enerjisiz macta sezon kurali ayni oranla dusurur)
    v_xp := (s -> 'match_xp' ->> 'win')::int;
    if exists (select 1 from economy_ledger where idempotency_key = 'chest_skip:' || new.id || ':' || new.winner_id) then
      v_xp := v_xp * (s ->> 'no_energy_pct')::int / 100;
    end if;
    v_xp := v_xp * (coalesce((_daily_rules() ->> 'first_win_xp_multiplier')::int, 2) - 1);
    insert into daily_first_wins (user_id, day, match_id, bonus_xp) values (new.winner_id, v_gun, new.id, v_xp)
    on conflict (user_id, day) do nothing;
    get diagnostics v_ek = row_count;
    if v_ek = 1 and v_xp > 0 then
      perform _season_add_xp(new.winner_id, v_xp, 'first_win', new.id::text,
                             'first_win:' || v_gun || ':' || new.winner_id);
    end if;
  exception when others then
    insert into economy_errors (context, user_id, source_id, error)
    values ('first_win', new.winner_id, new.id::text, sqlerrm);
  end;
  return null;
end;
$$;

drop trigger if exists trg_daily_first_win on matches;
create trigger trg_daily_first_win
  after update of status on matches
  for each row
  when (new.status = 'finished' and old.status is distinct from 'finished' and new.mode = 'ranked')
  execute function _daily_first_win_on_match_finished();

-- ---------------------------------------------------------------------
-- 3) PAKET: SANDIK KURALI (011 govdesi; farklar yalniz "044" satirlari)
-- ---------------------------------------------------------------------
create or replace function open_pack(
  p_user_id   uuid,
  p_pack_slug text,
  p_free      boolean default false   -- sadece sistem cagrilarinda true
)
returns json
language plpgsql
as $$
declare
  v_pack       pack_types%rowtype;
  v_coins      int;
  v_pozisyonlar card_position[];
  v_pozisyon   card_position;
  v_tier       card_tier;
  v_card_id    uuid;
  v_user_card  uuid;
  v_kart_idler uuid[] := '{}';
  v_seviyeler  text[] := '{}';
  v_i          int;
  v_ucret      int;
  v_sonuc      text;                                  -- 044
  v_kart_row   cards%rowtype;                         -- 044
  v_ilerleme   jsonb := '[]'::jsonb;                  -- 044: kopya / joker olanlar
  v_tasma      jsonb := '{}'::jsonb;                  -- 044
  v_yeni_kural boolean := economy_flag('pack_duplicates_v2') and p_pack_slug <> 'starter';  -- 044
  j            record;                                -- 044
begin
  -- ---- PAKETI BUL ----
  select * into v_pack from pack_types
  where slug = p_pack_slug and is_active;

  if not found then
    raise exception 'Boyle bir paket yok: %', p_pack_slug;
  end if;

  if not v_pack.is_purchasable and not p_free then
    raise exception 'Bu paket magazadan satin alinamaz.';
  end if;

  -- ---- KULLANICIYI KILITLE (coin dusumu icin) ----
  select coins into v_coins from users where id = p_user_id for update;

  if not found then
    raise exception 'Kullanici bulunamadi.';
  end if;

  v_ucret := case when p_free then 0 else v_pack.price_coins end;

  if v_coins < v_ucret then
    raise exception 'Yeterli coin yok. Gerekli: %, mevcut: %', v_ucret, v_coins;
  end if;

  -- ---- POZISYONLARI BELIRLE ----
  v_pozisyonlar := _build_position_list(v_pack.position_quota, v_pack.card_count);

  -- ---- KARTLARI CEK ----
  for v_i in 1..v_pack.card_count loop
    v_pozisyon := v_pozisyonlar[v_i];
    v_tier := _roll_tier(v_pack.tier_weights, v_pack.max_tier);
    v_card_id := _pick_card(v_tier, v_pozisyon);

    -- 044: SANDIK KURALI (anahtar 'pack_duplicates_v2'): sahip olunan
    -- futbolcu fiziksel kopya yerine gelisim kopyasi; seviye 10 ise joker;
    -- kadroda o mevki eksikse fiziksel kart (kadro korumasi).
    v_sonuc := 'new';
    if v_yeni_kural and exists (select 1 from user_cards where owner_id = p_user_id and card_id = v_card_id) then
      select * into v_kart_row from cards where id = v_card_id;
      if v_kart_row.position = any (_squad_missing_positions(p_user_id)) then
        v_sonuc := 'squad_guard';
      elsif coalesce((select level from player_progress where user_id = p_user_id and card_id = v_card_id), 1)
            >= coalesce((_level_rules() ->> 'max_level')::int, 10) then
        v_sonuc := 'joker';
      else
        v_sonuc := 'copy';
      end if;
    end if;

    if v_sonuc in ('new', 'squad_guard') then
      insert into user_cards (owner_id, card_id)
      values (p_user_id, v_card_id)
      returning id into v_user_card;

      v_kart_idler := v_kart_idler || v_user_card;
      if v_yeni_kural then
        insert into player_progress (user_id, card_id) values (p_user_id, v_card_id) on conflict do nothing;
      end if;
    elsif v_sonuc = 'copy' then
      insert into player_progress (user_id, card_id, copies) values (p_user_id, v_card_id, 1)
      on conflict (user_id, card_id) do update
        set copies = player_progress.copies + 1, updated_at = now();
    else
      v_tasma := jsonb_set(v_tasma, array[v_kart_row.tier::text],
                   to_jsonb(coalesce((v_tasma ->> v_kart_row.tier::text)::int, 0)
                            + coalesce((_level_rules() -> 'overflow_jokers' ->> v_kart_row.tier::text)::int, 1)));
    end if;
    if v_sonuc in ('copy', 'joker') then
      v_ilerleme := v_ilerleme || jsonb_build_object(
        'card_id', v_kart_row.id, 'slug', v_kart_row.slug, 'full_name', v_kart_row.full_name,
        'position', v_kart_row.position, 'tier', v_kart_row.tier, 'power', v_kart_row.power,
        'club', v_kart_row.club, 'nationality', v_kart_row.nationality,
        'image_url', v_kart_row.image_url, 'outcome', v_sonuc);
    end if;
    -- Gercekte hangi seviye verildi? (_pick_card alt seviyeye inmis olabilir)
    v_seviyeler := v_seviyeler || (select tier::text from cards where id = v_card_id);
  end loop;

  -- 044: seviye 10 tasmasi joker parca olarak
  for j in select key, value::int as n from jsonb_each_text(v_tasma) loop
    perform _item_add(p_user_id, 'joker_' || j.key, j.n, 'pack');
  end loop;

  -- ---- COIN DUS ----
  if v_ucret > 0 then
    update users set coins = coins - v_ucret where id = p_user_id
    returning coins into v_coins;
  end if;

  -- ---- DENETIM KAYDI ----
  insert into pack_openings (user_id, pack_slug, card_ids, tiers, coins_spent)
  values (p_user_id, p_pack_slug, v_kart_idler, v_seviyeler, v_ucret);

  -- ---- SONUCU DON ----
  return json_build_object(
    'pack', json_build_object(
      'slug', v_pack.slug,
      'name', v_pack.name,
      'card_count', v_pack.card_count
    ),
    'coins_spent', v_ucret,
    'coins_left', v_coins,
    -- 044: fiziksel kart yerine gelisim kopyasi / joker olanlar
    'progress', v_ilerleme,
    'cards', (
      select coalesce(json_agg(
        json_build_object(
          'user_card_id', uc.id,
          'card_id', c.id,
          'slug', c.slug,
          'full_name', c.full_name,
          'position', c.position,
          'tier', c.tier,
          'power', c.power,
          'nationality', c.nationality,
          -- 'league' eksikti: paketten cikan kart koleksiyona duserken
          -- ligi bos geliyor, kimya onizlemesi yanlis hesapliyordu.
          'league', c.league,
          'club', c.club,
          'attributes', card_attributes_json(
            c.shooting, c.pace, c.physical,
            c.defending, c.dribbling, c.acceleration
          ),
          'image_url', c.image_url
        ) order by tier_rank(c.tier) desc, c.power desc
      ), '[]'::json)
      from user_cards uc
      join cards c on c.id = uc.card_id
      where uc.id = any (v_kart_idler)
    )
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 4) GUNLUK MAGAZA TEKLIFI: herkes icin ayni paket, %25 indirim, gunde 1
-- ---------------------------------------------------------------------
create table if not exists daily_shop_purchases (
  user_id      uuid not null references users(id) on delete cascade,
  day          date not null,
  pack_slug    text not null,
  price_paid   int  not null,
  created_at   timestamptz not null default now(),
  primary key (user_id, day)
);

-- Gunun teklifi: tarih tohumuyla secilir (sunucular arasinda ayni)
create or replace function daily_shop_offer(p_day date default null) returns jsonb
language sql stable as $$
  with k as (select _daily_rules() r),
       liste as (select array(select jsonb_array_elements_text((select r from k) -> 'shop_packs')) a),
       secim as (select (select a from liste)[1 + abs(hashtext('daily_shop:' || coalesce(p_day, game_day())::text))
                                               % cardinality((select a from liste))] as slug)
  select jsonb_build_object(
    'day', coalesce(p_day, game_day()),
    'pack_slug', p.slug, 'name', p.name, 'card_count', p.card_count,
    'price', p.price_coins,
    'discount_pct', ((select r from k) ->> 'shop_discount_pct')::int,
    'discounted_price', p.price_coins * (100 - ((select r from k) ->> 'shop_discount_pct')::int) / 100)
  from pack_types p, secim
  where p.slug = secim.slug and p.is_active
$$;

create or replace function daily_shop_status(p_user_id uuid) returns jsonb
language sql stable as $$
  select daily_shop_offer() || jsonb_build_object(
    'enabled', economy_flag('daily_shop'),
    'bought_today', exists (select 1 from daily_shop_purchases where user_id = p_user_id and day = game_day()),
    'next_reset_at', next_game_day_at())
$$;

create or replace function buy_daily_offer(p_user_id uuid) returns jsonb
language plpgsql as $$
declare
  o      jsonb;
  v_gun  date := game_day();
  v_paket json;
begin
  if not economy_flag('daily_shop') then
    raise exception 'shop_disabled: Gunun teklifi kapali.';
  end if;
  perform pg_advisory_xact_lock(hashtext('daily_shop:' || p_user_id::text));
  if exists (select 1 from daily_shop_purchases where user_id = p_user_id and day = v_gun) then
    raise exception 'offer_used: Gunun teklifini bugun zaten aldin.';
  end if;
  o := daily_shop_offer(v_gun);
  if o is null then
    raise exception 'offer_missing: Bugun teklif yok.';
  end if;
  -- once ode (yetmezse _ledger_add reddeder), sonra paketi ucretsiz ac
  perform _ledger_add(p_user_id, 'daily_shop', -(o ->> 'discounted_price')::int, o,
                      'daily_shop', v_gun::text, 'daily_shop:' || v_gun || ':' || p_user_id);
  insert into daily_shop_purchases (user_id, day, pack_slug, price_paid)
  values (p_user_id, v_gun, o ->> 'pack_slug', (o ->> 'discounted_price')::int);
  v_paket := open_pack(p_user_id, o ->> 'pack_slug', true);
  return jsonb_build_object('offer', o, 'pack', v_paket::jsonb);
end;
$$;

-- ---------------------------------------------------------------------
-- 5) SADELESTIRME: "odul enerjisi" -> "sandik hakki" (yalniz gorunen metin;
--    taktik enerjisiyle karismasin). Slug ve etkisi AYNI.
-- ---------------------------------------------------------------------
update item_definitions
set name = 'Sandık hakkı paketi',
    description = '+3 sandık hakkı. Günde en fazla 2 kez kullanılır.'
where slug = 'energy_drink' and name = 'Enerji içeceği';
