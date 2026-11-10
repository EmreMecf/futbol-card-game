-- =====================================================================
-- 035 EKONOMI V2 FAZ 4 — BATTLE PASS (SEZON YOLU) + GOREVLER
-- =====================================================================
-- Tasarim: docs/EKONOMI_V2_TASARIM.md §3 (odul tablosu), §5 (XP), §7.
--
-- Kurallar:
--   * K1: sezon XP'si, kademe ve odulleri macta guc VERMEZ.
--   * K4: premium SATIN ALMA YOK. Premium yol gorunur ama kilitli;
--     yalniz gelistirme ortaminda test icin acilabilir.
--   * Mac sonu mevcut oduller (altin, MMR, koruma, kart kaybi) DEGISMEZ.
--   * XP: enerjili mac kazanma/beraberlik/yenilgi 100/70/60, enerjisiz
--     %25. K6 ile ayni: 4. turdan once biten macta XP ve gorev ilerlemesi yok.
--   * Her XP ve odul tek sefer: defter anahtari + season_claims birincil anahtari.
--   * Sezon bitince ulasilmis ama alinmamis odul KAYBOLMAZ: close_due_seasons()
--     otomatik verir (sandik yuva doluysa posta kutusuna gider).
--   * Tetikleyicide hata olursa mac sonucu ETKILENMEZ (economy_errors).
-- =====================================================================

-- ---------------------------------------------------------------------
-- AYARLAR (surumlu; yayinlanan surum degismez)
-- ---------------------------------------------------------------------
insert into economy_config_versions (kind, version, payload, note)
values ('season_rules', 1, $json${
  "season_days": 30,
  "max_tier": 50,
  "xp_per_tier": 1000,
  "match_xp": {"win": 100, "draw": 70, "loss": 60},
  "no_energy_pct": 25,
  "min_rounds": 4,
  "plus_bonus_pct": 10,
  "premium_purchase_enabled": false,
  "tiers": [
    {"tier":1,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"kit_season1","qty":1}},
    {"tier":2,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"joker_gold","qty":3}},
    {"tier":3,"free":{"type":"chest","chest_type":"silver"},"premium":{"type":"coins","amount":195}},
    {"tier":4,"free":{"type":"coins","amount":93},"premium":{"type":"coins","amount":195}},
    {"tier":5,"free":{"type":"coins","amount":93},"premium":{"type":"chest","chest_type":"gold"}},
    {"tier":6,"free":{"type":"item","slug":"joker_gold","qty":2},"premium":{"type":"coins","amount":195}},
    {"tier":7,"free":{"type":"coins","amount":93},"premium":{"type":"coins","amount":195}},
    {"tier":8,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"joker_gold","qty":3}},
    {"tier":9,"free":{"type":"chest","chest_type":"silver"},"premium":{"type":"coins","amount":195}},
    {"tier":10,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"card_skin_night","qty":1}},
    {"tier":11,"free":{"type":"coins","amount":93},"premium":{"type":"coins","amount":195}},
    {"tier":12,"free":{"type":"chest","chest_type":"gold"},"premium":{"type":"coins","amount":195}},
    {"tier":13,"free":{"type":"coins","amount":93},"premium":{"type":"chest","chest_type":"gold"}},
    {"tier":14,"free":{"type":"coins","amount":93},"premium":{"type":"coins","amount":195}},
    {"tier":15,"free":{"type":"chest","chest_type":"silver"},"premium":{"type":"chest","chest_type":"legend"}},
    {"tier":16,"free":{"type":"coins","amount":93},"premium":{"type":"coins","amount":195}},
    {"tier":17,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"joker_gold","qty":3}},
    {"tier":18,"free":{"type":"item","slug":"joker_gold","qty":2},"premium":{"type":"coins","amount":195}},
    {"tier":19,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"joker_diamond","qty":2}},
    {"tier":20,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"frame_season1","qty":1}},
    {"tier":21,"free":{"type":"chest","chest_type":"silver"},"premium":{"type":"coins","amount":195}},
    {"tier":22,"free":{"type":"coins","amount":93},"premium":{"type":"chest","chest_type":"gold"}},
    {"tier":23,"free":{"type":"coins","amount":93},"premium":{"type":"coins","amount":195}},
    {"tier":24,"free":{"type":"chest","chest_type":"gold"},"premium":{"type":"coins","amount":195}},
    {"tier":25,"free":{"type":"item","slug":"badge_s1_bronze","qty":1},"premium":{"type":"item","slug":"badge_s1_gold","qty":1}},
    {"tier":26,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"joker_gold","qty":3}},
    {"tier":27,"free":{"type":"item","slug":"joker_gold","qty":2},"premium":{"type":"coins","amount":195}},
    {"tier":28,"free":{"type":"coins","amount":93},"premium":{"type":"chest","chest_type":"gold"}},
    {"tier":29,"free":{"type":"coins","amount":93},"premium":{"type":"coins","amount":195}},
    {"tier":30,"free":{"type":"item","slug":"energy_drink","qty":2},"premium":{"type":"item","slug":"arena_rainy_night","qty":1}},
    {"tier":31,"free":{"type":"coins","amount":93},"premium":{"type":"coins","amount":195}},
    {"tier":32,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"joker_gold","qty":4}},
    {"tier":33,"free":{"type":"chest","chest_type":"silver"},"premium":{"type":"coins","amount":195}},
    {"tier":34,"free":{"type":"coins","amount":93},"premium":{"type":"coins","amount":195}},
    {"tier":35,"free":{"type":"coins","amount":93},"premium":{"type":"chest","chest_type":"legend"}},
    {"tier":36,"free":{"type":"chest","chest_type":"gold"},"premium":{"type":"coins","amount":195}},
    {"tier":37,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"joker_diamond","qty":2}},
    {"tier":38,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"chest_speedup_2h","qty":2}},
    {"tier":39,"free":{"type":"item","slug":"joker_gold","qty":2},"premium":{"type":"coins","amount":195}},
    {"tier":40,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"victory_fireworks","qty":1}},
    {"tier":41,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"joker_gold","qty":4}},
    {"tier":42,"free":{"type":"chest","chest_type":"gold"},"premium":{"type":"coins","amount":195}},
    {"tier":43,"free":{"type":"coins","amount":93},"premium":{"type":"coins","amount":195}},
    {"tier":44,"free":{"type":"coins","amount":93},"premium":{"type":"chest","chest_type":"gold"}},
    {"tier":45,"free":{"type":"chest","chest_type":"silver"},"premium":{"type":"item","slug":"captain_band","qty":1}},
    {"tier":46,"free":{"type":"coins","amount":93},"premium":{"type":"item","slug":"mastery_book_gold","qty":1}},
    {"tier":47,"free":{"type":"coins","amount":93},"premium":{"type":"chest","chest_type":"gold"}},
    {"tier":48,"free":{"type":"item","slug":"joker_gold","qty":2},"premium":{"type":"coins","amount":210}},
    {"tier":49,"free":{"type":"coins","amount":117},"premium":{"type":"item","slug":"joker_diamond","qty":2}},
    {"tier":50,"free":{"type":"chest","chest_type":"legend"},"premium":{"type":"chest","chest_type":"legend"}}
  ]
}$json$, '035: Battle Pass 50 kademe (tool/ekonomi/bp_tablo.py ile ayni dagilim)')
on conflict (kind, version) do nothing;

create or replace function _season_rules()
returns jsonb language sql stable as $$ select economy_config('season_rules') $$;

-- ---------------------------------------------------------------------
-- TABLOLAR
-- ---------------------------------------------------------------------
create table if not exists seasons (
  id             uuid primary key default gen_random_uuid(),
  number         int  not null unique check (number > 0),
  name           text not null,
  starts_at      timestamptz not null,
  ends_at        timestamptz not null,
  rules_version  int  not null,
  status         text not null default 'active' check (status in ('active', 'closed')),
  closed_at      timestamptz,
  created_at     timestamptz not null default now(),
  check (ends_at > starts_at)
);

-- Odul tablosu sezon basladiginda dondurulur (ayar sonradan degisse de
-- o sezonun odulleri ayni kalir)
create table if not exists season_tiers (
  season_id  uuid not null references seasons(id) on delete cascade,
  tier       int  not null check (tier > 0),
  track      text not null check (track in ('free', 'premium')),
  reward     jsonb not null,
  primary key (season_id, tier, track)
);

create table if not exists user_seasons (
  user_id       uuid not null references users(id) on delete cascade,
  season_id     uuid not null references seasons(id) on delete cascade,
  xp            int  not null default 0 check (xp >= 0),
  premium       boolean not null default false,
  premium_plus  boolean not null default false,
  updated_at    timestamptz not null default now(),
  primary key (user_id, season_id)
);

create table if not exists season_claims (
  user_id     uuid not null references users(id) on delete cascade,
  season_id   uuid not null references seasons(id) on delete cascade,
  tier        int  not null,
  track       text not null check (track in ('free', 'premium')),
  reward      jsonb not null,
  result      jsonb not null default '{}'::jsonb,
  auto        boolean not null default false,   -- sezon sonu otomatik
  claimed_at  timestamptz not null default now(),
  primary key (user_id, season_id, tier, track)
);

create table if not exists missions (
  slug        text primary key check (slug ~ '^[a-z0-9_]+$'),
  period      text not null check (period in ('daily', 'weekly', 'season')),
  metric      text not null check (metric in ('match_played', 'match_won', 'chest_opened',
                                              'sbc_completed', 'player_level')),
  target      int  not null check (target > 0),
  xp          int  not null check (xp > 0),
  title       text not null,
  description text not null default '',
  sort_order  int  not null default 0,
  is_active   boolean not null default true
);

create table if not exists user_missions (
  user_id       uuid not null references users(id) on delete cascade,
  mission_slug  text not null references missions(slug),
  period_key    text not null,
  progress      int  not null default 0 check (progress >= 0),
  completed_at  timestamptz,
  updated_at    timestamptz not null default now(),
  primary key (user_id, mission_slug, period_key)
);

-- Gorevler (§5): gunluk 600, haftalik 6.000, sezon 10.000 XP.
-- Yalniz oynayarak yapilir; odeme gerektirmez.
insert into missions (slug, period, metric, target, xp, title, description, sort_order) values
  ('daily_play_1',    'daily',  'match_played',   1,  150, '1 maç oyna',               'Dereceli maçı sonuna kadar oyna.', 10),
  ('daily_play_2',    'daily',  'match_played',   2,  200, '2 maç oyna',               'Dereceli maçı sonuna kadar oyna.', 11),
  ('daily_play_3',    'daily',  'match_played',   3,  250, '3 maç oyna',               'Dereceli maçı sonuna kadar oyna.', 12),
  ('weekly_play_25',  'weekly', 'match_played',  25, 2500, '25 maç oyna',              'Bu hafta 25 maç tamamla.', 20),
  ('weekly_win_10',   'weekly', 'match_won',     10, 2000, '10 galibiyet',             'Bu hafta 10 maç kazan.', 21),
  ('weekly_chests_3', 'weekly', 'chest_opened',   3, 1500, '3 sandık aç',              'Bu hafta 3 sandık aç.', 22),
  ('season_play_120', 'season', 'match_played', 120, 6000, '120 maç oyna',             'Bu sezon 120 maç tamamla.', 30),
  ('season_level_5',  'season', 'player_level',   5, 2000, 'Bir futbolcuyu 5. seviyeye çıkar', 'Gelişim ekranından seviye atla.', 31),
  ('season_sbc_3',    'season', 'sbc_completed',  3, 2000, '3 kart görevi tamamla',    'Kart görevlerinden 3 tanesini bitir.', 32)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------
-- SEZON: tembel olusturma (ayri zamanlayici gerekmez)
-- ---------------------------------------------------------------------
create or replace function _current_season()
returns seasons
language plpgsql as $$
declare
  s       seasons%rowtype;
  son     seasons%rowtype;
  k       jsonb := _season_rules();
  v_bas   timestamptz;
  t       jsonb;
begin
  select * into s from seasons where starts_at <= now() and ends_at > now() order by number desc limit 1;
  if found then
    return s;
  end if;

  perform pg_advisory_xact_lock(hashtext('seasons:create'));
  select * into s from seasons where starts_at <= now() and ends_at > now() order by number desc limit 1;
  if found then
    return s;
  end if;

  select * into son from seasons order by number desc limit 1;
  -- Sunucu uzun sure kapali kaldiysa bos sezonlar uretilmez: bugun baslar
  v_bas := greatest(coalesce(son.ends_at, '-infinity'::timestamptz), date_trunc('day', now()));
  insert into seasons (number, name, starts_at, ends_at, rules_version)
  values (coalesce(son.number, 0) + 1, 'Sezon ' || (coalesce(son.number, 0) + 1),
          v_bas, v_bas + make_interval(days => (k ->> 'season_days')::int),
          economy_config_version('season_rules'))
  returning * into s;

  for t in select * from jsonb_array_elements(k -> 'tiers') loop
    insert into season_tiers (season_id, tier, track, reward) values
      (s.id, (t ->> 'tier')::int, 'free', t -> 'free'),
      (s.id, (t ->> 'tier')::int, 'premium', t -> 'premium');
  end loop;
  return s;
end;
$$;

create or replace function _season_tier_of(p_xp int, p_rules jsonb)
returns int language sql immutable as $$
  select least((p_rules ->> 'max_tier')::int, p_xp / (p_rules ->> 'xp_per_tier')::int)
$$;

-- Gorev donemi anahtari: gunluk/haftalik sunucu saatine gore, sezon kimligi
create or replace function _mission_period_key(p_period text, p_season uuid)
returns text language sql stable as $$
  select case p_period
    when 'daily'  then 'D' || to_char(date_trunc('day', now()), 'YYYY-MM-DD')
    when 'weekly' then 'W' || to_char(date_trunc('week', now()), 'YYYY-MM-DD')
    else 'S' || p_season::text
  end
$$;

-- ---------------------------------------------------------------------
-- XP EKLE (tek sefer: defter anahtari; kullanici satiri kilitli)
-- ---------------------------------------------------------------------
create or replace function _season_add_xp(p_user_id uuid, p_xp int, p_source_type text,
                                          p_source_id text, p_key text)
returns int
language plpgsql as $$
declare
  s     seasons%rowtype := _current_season();
  us    user_seasons%rowtype;
  v_xp  int;
begin
  if p_xp <= 0 then
    return 0;
  end if;
  insert into user_seasons (user_id, season_id) values (p_user_id, s.id) on conflict do nothing;
  select * into us from user_seasons where user_id = p_user_id and season_id = s.id for update;

  if exists (select 1 from economy_ledger where idempotency_key = 'sxp:' || p_key) then
    return 0;
  end if;
  v_xp := case when us.premium_plus
               then p_xp + p_xp * (_season_rules() ->> 'plus_bonus_pct')::int / 100
               else p_xp end;
  perform _ledger_add(p_user_id, 'season_xp', 0,
                      jsonb_build_object('xp', v_xp, 'season_id', s.id),
                      p_source_type, p_source_id, 'sxp:' || p_key);
  update user_seasons set xp = xp + v_xp, updated_at = now()
  where user_id = p_user_id and season_id = s.id;
  return v_xp;
end;
$$;

-- ---------------------------------------------------------------------
-- GOREV OLAYI: ilgili gorevlerin ilerlemesi; tamamlaninca XP (otomatik)
-- p_mode 'add' (sayac) ya da 'max' (ulasilan en yuksek deger)
-- ---------------------------------------------------------------------
create or replace function _mission_event(p_user_id uuid, p_metric text, p_value int,
                                          p_mode text default 'add')
returns void
language plpgsql as $$
declare
  s      seasons%rowtype := _current_season();
  m      missions%rowtype;
  um     user_missions%rowtype;
  v_key  text;
begin
  for m in select * from missions where metric = p_metric and is_active order by sort_order loop
    v_key := _mission_period_key(m.period, s.id);
    insert into user_missions (user_id, mission_slug, period_key)
    values (p_user_id, m.slug, v_key) on conflict do nothing;
    select * into um from user_missions
    where user_id = p_user_id and mission_slug = m.slug and period_key = v_key for update;
    if um.completed_at is not null then
      continue;
    end if;
    update user_missions
    set progress = least(m.target, case when p_mode = 'max' then greatest(progress, p_value)
                                        else progress + p_value end),
        updated_at = now()
    where user_id = p_user_id and mission_slug = m.slug and period_key = v_key
    returning * into um;
    if um.progress >= m.target then
      update user_missions set completed_at = now()
      where user_id = p_user_id and mission_slug = m.slug and period_key = v_key;
      perform _season_add_xp(p_user_id, m.xp, 'mission', m.slug || ':' || v_key,
                             'mission:' || p_user_id || ':' || m.slug || ':' || v_key);
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- MAC BITINCE: XP + gorevler (sandik tetikleyicisinden SONRA calisir:
-- tetikleyiciler ada gore siralanir, 'm' < 's')
-- ---------------------------------------------------------------------
create or replace function _economy_season_on_match_finished()
returns trigger
language plpgsql as $$
declare
  k        jsonb;
  v_tur    int;
  p        uuid;
  v_sonuc  text;
  v_xp     int;
  v_enerji boolean;
begin
  if not economy_flag('economy_v2_enabled') then
    return null;
  end if;
  k := _season_rules();
  if k is null then
    return null;
  end if;
  select count(*) into v_tur from match_rounds where match_id = new.id;
  if v_tur < coalesce((k ->> 'min_rounds')::int, 4) then
    return null;
  end if;

  foreach p in array array[new.player1_id, new.player2_id] loop
    v_sonuc := case when new.is_draw then 'draw' when new.winner_id = p then 'win' else 'loss' end;
    begin
      -- Enerjisiz = sandik tetikleyicisi enerji yok diye atladi
      v_enerji := not exists (select 1 from economy_ledger
                              where idempotency_key = 'chest_skip:' || new.id || ':' || p);
      v_xp := (k -> 'match_xp' ->> v_sonuc)::int;
      if not v_enerji then
        v_xp := v_xp * (k ->> 'no_energy_pct')::int / 100;
      end if;
      perform _season_add_xp(p, v_xp, 'match', new.id::text, 'match:' || new.id || ':' || p);
      perform _mission_event(p, 'match_played', 1);
      if v_sonuc = 'win' then
        perform _mission_event(p, 'match_won', 1);
      end if;
    exception when others then
      insert into economy_errors (context, user_id, source_id, error)
      values ('season_match', p, new.id::text, sqlerrm);
    end;
  end loop;
  return null;
end;
$$;

drop trigger if exists trg_economy_season_match_finished on matches;
create trigger trg_economy_season_match_finished
  after update of status on matches
  for each row
  when (new.status = 'finished' and old.status is distinct from 'finished')
  execute function _economy_season_on_match_finished();

-- Sandik acildi -> gorev
create or replace function _economy_season_on_chest_opened()
returns trigger
language plpgsql as $$
begin
  if economy_flag('economy_v2_enabled') then
    begin
      perform _mission_event(new.user_id, 'chest_opened', 1);
    exception when others then
      insert into economy_errors (context, user_id, source_id, error)
      values ('season_chest', new.user_id, new.id::text, sqlerrm);
    end;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_economy_season_chest_opened on user_chests;
create trigger trg_economy_season_chest_opened
  after update of status on user_chests
  for each row
  when (new.status = 'opened' and old.status is distinct from 'opened')
  execute function _economy_season_on_chest_opened();

-- Kart gorevi (SBC) tamamlandi -> gorev
create or replace function _economy_season_on_sbc()
returns trigger
language plpgsql as $$
begin
  if economy_flag('economy_v2_enabled') then
    begin
      perform _mission_event(new.user_id, 'sbc_completed', 1);
    exception when others then
      insert into economy_errors (context, user_id, source_id, error)
      values ('season_sbc', new.user_id, new.id::text, sqlerrm);
    end;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_economy_season_sbc on sbc_completions;
create trigger trg_economy_season_sbc
  after insert on sbc_completions
  for each row execute function _economy_season_on_sbc();

-- Futbolcu seviye atladi -> gorev (ulasilan en yuksek seviye)
create or replace function _economy_season_on_level()
returns trigger
language plpgsql as $$
begin
  if economy_flag('economy_v2_enabled') then
    begin
      perform _mission_event(new.user_id, 'player_level', new.level, 'max');
    exception when others then
      insert into economy_errors (context, user_id, source_id, error)
      values ('season_level', new.user_id, new.card_id::text, sqlerrm);
    end;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_economy_season_level on player_progress;
create trigger trg_economy_season_level
  after update of level on player_progress
  for each row
  when (new.level > old.level)
  execute function _economy_season_on_level();

-- ---------------------------------------------------------------------
-- ODUL VER (tek sefer: season_claims birincil anahtari)
-- ---------------------------------------------------------------------
create or replace function _season_grant(p_user_id uuid, p_season uuid, p_tier int, p_track text,
                                         p_auto boolean)
returns jsonb
language plpgsql as $$
declare
  r       jsonb;
  v_src   text := p_season || ':' || p_tier || ':' || p_track;
  v_key   text := 'season:' || p_season || ':' || p_tier || ':' || p_track || ':' || p_user_id;
  v_sonuc jsonb;
  v_eski  season_claims%rowtype;
  v_chest uuid;
begin
  select reward into r from season_tiers where season_id = p_season and tier = p_tier and track = p_track;
  if r is null then
    raise exception 'tier_not_found: Kademe bulunamadi.';
  end if;

  insert into season_claims (user_id, season_id, tier, track, reward, auto)
  values (p_user_id, p_season, p_tier, p_track, r, p_auto)
  on conflict do nothing;
  if not found then
    select * into v_eski from season_claims
    where user_id = p_user_id and season_id = p_season and tier = p_tier and track = p_track;
    return v_eski.result || jsonb_build_object('replay', true);
  end if;

  case r ->> 'type'
  when 'coins' then
    perform _ledger_add(p_user_id, 'season_reward', (r ->> 'amount')::int,
                        jsonb_build_object('tier', p_tier, 'track', p_track),
                        'season_tier', v_src, v_key);
    v_sonuc := jsonb_build_object('coins', (r ->> 'amount')::int);
  when 'chest' then
    v_chest := _grant_chest(p_user_id, r ->> 'chest_type', 'season_tier', replace(v_src, ':', '_'));
    perform _ledger_add(p_user_id, 'season_reward', 0,
                        jsonb_build_object('tier', p_tier, 'track', p_track, 'chest_id', v_chest),
                        'season_tier', v_src, v_key);
    v_sonuc := jsonb_build_object('chest_id', v_chest, 'chest_type', r ->> 'chest_type');
  when 'item' then
    v_sonuc := grant_item(p_user_id, r ->> 'slug', (r ->> 'qty')::int, 'season_tier', v_src, v_key);
  else
    raise exception 'tier_not_found: Bilinmeyen odul turu.';
  end case;

  v_sonuc := jsonb_build_object('tier', p_tier, 'track', p_track, 'reward', r) || v_sonuc;
  update season_claims set result = v_sonuc
  where user_id = p_user_id and season_id = p_season and tier = p_tier and track = p_track;
  return v_sonuc;
end;
$$;

create or replace function claim_season_reward(p_user_id uuid, p_tier int, p_track text)
returns jsonb
language plpgsql as $$
declare
  s   seasons%rowtype;
  us  user_seasons%rowtype;
  k   jsonb := _season_rules();
begin
  if not economy_flag('economy_v2_enabled') then
    raise exception 'economy_disabled: Bu ozellik henuz acik degil.';
  end if;
  if p_track not in ('free', 'premium') then
    raise exception 'tier_not_found: Gecersiz yol.';
  end if;
  s := _current_season();
  insert into user_seasons (user_id, season_id) values (p_user_id, s.id) on conflict do nothing;
  select * into us from user_seasons where user_id = p_user_id and season_id = s.id for update;
  if p_tier < 1 or p_tier > (k ->> 'max_tier')::int then
    raise exception 'tier_not_found: Kademe bulunamadi.';
  end if;
  if _season_tier_of(us.xp, k) < p_tier then
    raise exception 'tier_locked: Bu kademeye henuz ulasmadin.';
  end if;
  if p_track = 'premium' and not us.premium then
    raise exception 'premium_required: Premium yol kilitli.';
  end if;
  return _season_grant(p_user_id, s.id, p_tier, p_track, false);
end;
$$;

-- Ulasilmis ve alinmamis butun odulleri al
create or replace function claim_all_season_rewards(p_user_id uuid)
returns jsonb
language plpgsql as $$
declare
  s       seasons%rowtype;
  us      user_seasons%rowtype;
  k       jsonb := _season_rules();
  t       season_tiers%rowtype;
  v_liste jsonb := '[]'::jsonb;
begin
  if not economy_flag('economy_v2_enabled') then
    raise exception 'economy_disabled: Bu ozellik henuz acik degil.';
  end if;
  s := _current_season();
  insert into user_seasons (user_id, season_id) values (p_user_id, s.id) on conflict do nothing;
  select * into us from user_seasons where user_id = p_user_id and season_id = s.id for update;
  for t in select st.* from season_tiers st
           where st.season_id = s.id and st.tier <= _season_tier_of(us.xp, k)
             and (st.track = 'free' or us.premium)
             and not exists (select 1 from season_claims c
                             where c.user_id = p_user_id and c.season_id = s.id
                               and c.tier = st.tier and c.track = st.track)
           order by st.tier, st.track loop
    v_liste := v_liste || _season_grant(p_user_id, s.id, t.tier, t.track, false);
  end loop;
  return jsonb_build_object('claimed', v_liste, 'count', jsonb_array_length(v_liste));
end;
$$;

-- ---------------------------------------------------------------------
-- SEZON KAPANISI: alinmamis odulleri otomatik ver (tekrar calisirsa
-- sonuc degismez). Sunucu zamanlayicisi cagirir.
-- ---------------------------------------------------------------------
create or replace function close_due_seasons()
returns int
language plpgsql as $$
declare
  s    seasons%rowtype;
  us   user_seasons%rowtype;
  t    season_tiers%rowtype;
  k    jsonb := _season_rules();
  n    int := 0;
begin
  for s in select * from seasons where ends_at <= now() and status = 'active' order by number for update loop
    for us in select * from user_seasons where season_id = s.id loop
      for t in select st.* from season_tiers st
               where st.season_id = s.id and st.tier <= _season_tier_of(us.xp, k)
                 and (st.track = 'free' or us.premium)
                 and not exists (select 1 from season_claims c
                                 where c.user_id = us.user_id and c.season_id = s.id
                                   and c.tier = st.tier and c.track = st.track)
               order by st.tier, st.track loop
        begin
          perform _season_grant(us.user_id, s.id, t.tier, t.track, true);
          n := n + 1;
        exception when others then
          insert into economy_errors (context, user_id, source_id, error)
          values ('season_close', us.user_id, s.id || ':' || t.tier || ':' || t.track, sqlerrm);
        end;
      end loop;
    end loop;
    update seasons set status = 'closed', closed_at = now() where id = s.id;
  end loop;
  return n;
end;
$$;

-- ---------------------------------------------------------------------
-- OKUMA
-- ---------------------------------------------------------------------
create or replace function _season_reward_json(r jsonb)
returns jsonb language sql stable as $$
  select r || case when r ->> 'type' = 'item'
                   then jsonb_build_object('name', (select name from item_definitions where slug = r ->> 'slug'),
                                           'category', (select category from item_definitions where slug = r ->> 'slug'))
                   else '{}'::jsonb end
$$;

create or replace function season_overview(p_user_id uuid)
returns jsonb
language plpgsql as $$
declare
  s   seasons%rowtype;
  us  user_seasons%rowtype;
  k   jsonb := _season_rules();
begin
  if not economy_flag('economy_v2_enabled') or k is null then
    return jsonb_build_object('enabled', false, 'server_time', now());
  end if;
  s := _current_season();
  select * into us from user_seasons where user_id = p_user_id and season_id = s.id;
  return jsonb_build_object(
    'enabled', true,
    'season', jsonb_build_object('id', s.id, 'number', s.number, 'name', s.name,
                                 'starts_at', s.starts_at, 'ends_at', s.ends_at),
    'xp', coalesce(us.xp, 0),
    'tier', _season_tier_of(coalesce(us.xp, 0), k),
    'xp_per_tier', (k ->> 'xp_per_tier')::int,
    'max_tier', (k ->> 'max_tier')::int,
    'premium', coalesce(us.premium, false),
    'premium_plus', coalesce(us.premium_plus, false),
    'premium_purchase_enabled', coalesce((k ->> 'premium_purchase_enabled')::boolean, false),
    'tiers', (select jsonb_agg(jsonb_build_object(
                'tier', f.tier,
                'free', _season_reward_json(f.reward),
                'premium', _season_reward_json(p.reward),
                'free_claimed', exists (select 1 from season_claims c where c.user_id = p_user_id
                                        and c.season_id = s.id and c.tier = f.tier and c.track = 'free'),
                'premium_claimed', exists (select 1 from season_claims c where c.user_id = p_user_id
                                           and c.season_id = s.id and c.tier = f.tier and c.track = 'premium'))
                order by f.tier)
              from season_tiers f
              join season_tiers p on p.season_id = f.season_id and p.tier = f.tier and p.track = 'premium'
              where f.season_id = s.id and f.track = 'free'),
    'server_time', now());
end;
$$;

create or replace function missions_overview(p_user_id uuid)
returns jsonb
language plpgsql as $$
declare
  s  seasons%rowtype;
begin
  if not economy_flag('economy_v2_enabled') or _season_rules() is null then
    return jsonb_build_object('enabled', false, 'missions', '[]'::jsonb, 'server_time', now());
  end if;
  s := _current_season();
  return jsonb_build_object(
    'enabled', true,
    'missions', coalesce((select jsonb_agg(jsonb_build_object(
        'slug', m.slug, 'period', m.period, 'title', m.title, 'description', m.description,
        'target', m.target, 'xp', m.xp,
        'progress', coalesce(um.progress, 0),
        'completed', um.completed_at is not null,
        'resets_at', case m.period when 'daily' then date_trunc('day', now()) + interval '1 day'
                                   when 'weekly' then date_trunc('week', now()) + interval '7 days'
                                   else s.ends_at end)
        order by m.sort_order)
      from missions m
      left join user_missions um on um.user_id = p_user_id and um.mission_slug = m.slug
                                and um.period_key = _mission_period_key(m.period, s.id)
      where m.is_active), '[]'::jsonb),
    'server_time', now());
end;
$$;

-- Mac sonu ekrani: bu macta kazanilan sezon XP'si
create or replace function season_match_xp(p_user_id uuid, p_match_id uuid)
returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'xp', coalesce((select (items ->> 'xp')::int from economy_ledger
                    where idempotency_key = 'sxp:match:' || p_match_id || ':' || p_user_id), 0),
    'no_energy', exists (select 1 from economy_ledger
                         where idempotency_key = 'chest_skip:' || p_match_id || ':' || p_user_id))
$$;

-- ---------------------------------------------------------------------
-- GELISTIRME (sunucu yalniz uretim disinda acar)
-- ---------------------------------------------------------------------
create or replace function dev_season_add_xp(p_user_id uuid, p_xp int)
returns int
language sql as $$
  select _season_add_xp(p_user_id, p_xp, 'dev', 'dev', 'dev:' || p_user_id || ':' || gen_random_uuid())
$$;

create or replace function dev_set_season_premium(p_user_id uuid, p_premium boolean)
returns boolean
language plpgsql as $$
declare
  s seasons%rowtype := _current_season();
begin
  insert into user_seasons (user_id, season_id, premium) values (p_user_id, s.id, p_premium)
  on conflict (user_id, season_id) do update set premium = excluded.premium, updated_at = now();
  return p_premium;
end;
$$;
