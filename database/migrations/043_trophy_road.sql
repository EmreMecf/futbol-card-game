-- =====================================================================
-- 043 KUPA YOLU + SEZON SONU LIG SIFIRLAMASI (FAZ 4, KAPALI GELIR)
-- =====================================================================
-- Onay: kullanici (13 Kasim 2026). Tasarim: docs/OYUN_TASARIMI_V3.md §3.
-- Kullanici kararlari:
--   * Basamak odulu "onerilen tablo" (asagida, economy_config 'trophy_road').
--   * GERIYE DONUK ODUL YOK: oyuncunun simdiye kadar ulastigi en yuksek
--     basamak (mac kayitlarindaki puanlardan) "ulasilmis" sayilir.
--   * Sezon sonu: yumusak sifirlama + sezon ligi odulu.
--   * Kart havuzu kurali (lige gore sandik karti) UYGULANMADI.
--
-- ANAHTARLAR (ikisi de KAPALI):
--   'trophy_road'         : puan artip YENI bir basamaga ilk kez ulasilinca odul
--   'league_season_reset' : Sezon Yolu sezonu kapaninca lig odulu + sifirlama
--
-- KUPA YOLU: her basamak oyuncu basina BIR KEZ (sezon sifirlamasindan sonra
-- tekrar cikinca odul yok). Amator 1 baslangic, odulsuz.
-- SEZON SONU (Sezon Yolu ile ayni takvim; close_due_seasons sezonu
-- kapatinca tetiklenir):
--   * O sezon en az bir DERECELI mac bitiren oyuncu bitis ligine gore odul
--     alir: Amator Gumus, Usta Altin, Master Altin + 200 altin, Master Class Efsane.
--   * Usta ve ustu herkes bir basamak asagi: puani bir alt basamagin
--     tabanina iner (Master 2 -> Master 1 tabani 1625; Usta 1 -> Amator 3
--     tabani 1200). Amator'e dokunulmaz.
--   * Her sonuc season_league_results'a yazilir (denetim + tekrar calismaz).
--
-- DEGISMEYENLER: mac, MMR +-25, eslestirme, sandik sanslari, kartlar,
-- mac gecmisi. Botlar odul ve sifirlama gormez. Anahtarlar kapaliyken
-- hicbir veri degismez.
-- =====================================================================

insert into economy_config_versions (kind, version, payload, note)
select 'feature_flags', max(version) + 1,
       (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1)
         || '{"trophy_road": false, "league_season_reset": false}'::jsonb,
       '043: kupa yolu + sezon sonu lig sifirlamasi (kapali)'
from economy_config_versions
where kind = 'feature_flags'
  and not ((select payload from economy_config_versions where kind = 'feature_flags'
            order by version desc limit 1) ? 'trophy_road')
having count(*) > 0;

-- Odul tablosu (surumlu; ileride yeni surum satiriyla degisir)
insert into economy_config_versions (kind, version, payload, note)
values ('trophy_road', 1, '{
  "tiers": {
    "2":  {"chest": "silver", "coins": 50},
    "3":  {"chest": "silver", "coins": 50},
    "4":  {"chest": "gold",   "coins": 100, "cosmetic": "frame_league_usta"},
    "5":  {"chest": "gold",   "coins": 100},
    "6":  {"chest": "gold",   "coins": 100},
    "7":  {"chest": "gold",   "coins": 200, "cosmetic": "frame_league_master"},
    "8":  {"chest": "gold",   "coins": 200},
    "9":  {"chest": "gold",   "coins": 200},
    "10": {"chest": "legend", "coins": 300, "cosmetic": "frame_league_master_class"},
    "11": {"chest": "legend", "coins": 300},
    "12": {"chest": "legend", "coins": 300}
  },
  "season_end": {
    "amateur":      {"chest": "silver", "coins": 0},
    "usta":         {"chest": "gold",   "coins": 0},
    "master":       {"chest": "gold",   "coins": 200},
    "master_class": {"chest": "legend", "coins": 0}
  }
}'::jsonb, '043: kupa yolu odul tablosu (kullanici onayli)')
on conflict (kind, version) do nothing;

-- Lig girisi kozmetikleri (profil cercevesi)
insert into item_definitions (slug, kind, category, name, description, max_stack, duration_seconds, cosmetic_slot, overflow_coins, params, sort_order) values
  ('frame_league_usta', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Usta',
   'Usta ligine ilk girişte kupa yolu ödülü.', null, null, 'frame', 100, '{"league": "usta"}', 86),
  ('frame_league_master', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Master',
   'Master ligine ilk girişte kupa yolu ödülü.', null, null, 'frame', 150, '{"league": "master"}', 87),
  ('frame_league_master_class', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Master Class',
   'Master Class ligine ilk girişte kupa yolu ödülü.', null, null, 'frame', 200, '{"league": "master_class"}', 88)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------
-- 1) KUPA YOLU
-- ---------------------------------------------------------------------
create table if not exists user_trophy_road (
  user_id        uuid primary key references users(id) on delete cascade,
  best_tier      int  not null references league_tiers(id),
  baseline_tier  int  not null references league_tiers(id),   -- acilista ulasilmis sayilan (odulsuz)
  updated_at     timestamptz not null default now()
);

create table if not exists trophy_road_grants (
  user_id     uuid not null references users(id) on delete cascade,
  tier_id     int  not null references league_tiers(id),
  reward      jsonb not null,
  granted_at  timestamptz not null default now(),
  primary key (user_id, tier_id)
);

-- Oyuncunun bugune kadar ulastigi en yuksek basamak: su anki puan ve
-- mac kayitlarindaki (022) once/sonra puanlarinin en buyugu.
create or replace function _trophy_historic_tier(p_user_id uuid, p_mmr int) returns int
language sql stable as $$
  select (rank_for_mmr(greatest(
            p_mmr,
            coalesce((select max(greatest(coalesce(mmr_before, 0), coalesce(mmr_after, 0)))
                      from match_players where user_id = p_user_id), 0)))).id
$$;

create or replace function _trophy_road_grant(p_user_id uuid, p_tier int) returns jsonb
language plpgsql as $$
declare
  r     jsonb := economy_config('trophy_road') -> 'tiers' -> p_tier::text;
  v_ek  int;
begin
  if r is null then
    return null;   -- odulsuz basamak (Amator 1)
  end if;
  insert into trophy_road_grants (user_id, tier_id, reward) values (p_user_id, p_tier, r)
  on conflict (user_id, tier_id) do nothing;
  get diagnostics v_ek = row_count;
  if v_ek = 0 then
    return null;   -- zaten verilmis
  end if;
  if r ? 'chest' then
    perform _grant_chest(p_user_id, r ->> 'chest', 'trophy_road', p_tier::text);
  end if;
  if coalesce((r ->> 'coins')::int, 0) > 0 then
    perform _ledger_add(p_user_id, 'trophy_road', (r ->> 'coins')::int, r, 'trophy_road', p_tier::text,
                        'trophy_road:' || p_user_id || ':' || p_tier);
  end if;
  if r ? 'cosmetic' then
    perform grant_item(p_user_id, r ->> 'cosmetic', 1, 'trophy_road', p_tier::text,
                       'trophy_road:' || p_user_id || ':' || p_tier);
  end if;
  return r;
end;
$$;

create or replace function _trophy_road_on_mmr()
returns trigger language plpgsql as $$
declare
  v_yeni  int;
  v_en    int;
  v_taban int;
  t       int;
begin
  if not economy_flag('trophy_road') or new.is_bot then
    return null;
  end if;
  v_yeni := (rank_for_mmr(new.mmr)).id;

  select best_tier into v_en from user_trophy_road where user_id = new.id for update;
  if not found then
    -- Ilk gorulus: o ana kadar ulasilan en yuksek basamak odulsuz sayilir
    v_taban := _trophy_historic_tier(new.id, old.mmr);
    insert into user_trophy_road (user_id, best_tier, baseline_tier) values (new.id, v_taban, v_taban)
    on conflict (user_id) do nothing;
    v_en := v_taban;
  end if;

  if v_yeni <= v_en then
    return null;
  end if;
  for t in v_en + 1 .. v_yeni loop
    begin
      perform _trophy_road_grant(new.id, t);
    exception when others then
      insert into economy_errors (context, user_id, source_id, error)
      values ('trophy_road', new.id, t::text, sqlerrm);
    end;
  end loop;
  update user_trophy_road set best_tier = v_yeni, updated_at = now() where user_id = new.id;
  return null;
end;
$$;

drop trigger if exists trg_trophy_road on users;
create trigger trg_trophy_road
  after update of mmr on users
  for each row
  when (new.mmr > old.mmr)
  execute function _trophy_road_on_mmr();

-- Oyuncunun kupa yolu (arayuz)
create or replace function trophy_road_overview(p_user_id uuid) returns jsonb
language sql stable as $$
  with ben as (
    select u.mmr,
           (rank_for_mmr(u.mmr)).id as simdiki,
           coalesce(tr.best_tier, _trophy_historic_tier(u.id, u.mmr)) as en_iyi,
           coalesce(tr.baseline_tier, _trophy_historic_tier(u.id, u.mmr)) as taban
    from users u left join user_trophy_road tr on tr.user_id = u.id
    where u.id = p_user_id
  )
  select jsonb_build_object(
    'enabled', economy_flag('trophy_road'),
    'current_tier', b.simdiki,
    'best_tier', b.en_iyi,
    'mmr', b.mmr,
    'tiers', (select jsonb_agg(jsonb_build_object(
                'tier_id', t.id, 'league_code', t.league_code, 'league_name', t.league_name,
                'division', t.division, 'min_mmr', t.min_mmr, 'color', t.color,
                'reward', economy_config('trophy_road') -> 'tiers' -> t.id::text,
                'status', case
                  when g.tier_id is not null then 'granted'
                  when t.id <= b.taban then 'reached_before'
                  when t.id <= b.en_iyi then 'reached_before'
                  else 'locked' end) order by t.id)
              from league_tiers t
              left join trophy_road_grants g on g.user_id = p_user_id and g.tier_id = t.id))
  from ben b
$$;

-- ---------------------------------------------------------------------
-- 2) SEZON SONU: lig odulu + yumusak sifirlama
-- ---------------------------------------------------------------------
create table if not exists season_league_results (
  season_id    uuid not null references seasons(id) on delete cascade,
  user_id      uuid not null references users(id) on delete cascade,
  tier_before  int  not null references league_tiers(id),
  mmr_before   int  not null,
  mmr_after    int  not null,
  reward       jsonb,                    -- null: o sezon dereceli oynamadi
  created_at   timestamptz not null default now(),
  primary key (season_id, user_id)
);

create or replace function _league_season_end(p_season_id uuid) returns int
language plpgsql as $$
declare
  s      seasons%rowtype;
  u      record;
  t      league_tiers%rowtype;
  v_yeni int;
  r      jsonb;
  v_ek   int;
  n      int := 0;
begin
  select * into s from seasons where id = p_season_id;
  for u in select id, mmr from users where not is_bot order by id for update loop
    begin
      t := rank_for_mmr(u.mmr);
      v_yeni := case when t.id >= 4
                     then (select min_mmr from league_tiers where id = t.id - 1)
                     else u.mmr end;
      -- odul yalniz o sezon en az bir dereceli mac bitirene
      r := case when exists (select 1 from matches m
                             where m.status = 'finished' and m.mode = 'ranked'
                               and u.id in (m.player1_id, m.player2_id)
                               and m.finished_at >= s.starts_at and m.finished_at < s.ends_at + interval '1 day')
                then economy_config('trophy_road') -> 'season_end' -> t.league_code end;

      insert into season_league_results (season_id, user_id, tier_before, mmr_before, mmr_after, reward)
      values (p_season_id, u.id, t.id, u.mmr, v_yeni, r)
      on conflict (season_id, user_id) do nothing;
      get diagnostics v_ek = row_count;
      continue when v_ek = 0;              -- bu sezon zaten islendi

      if r is not null then
        if r ? 'chest' then
          perform _grant_chest(u.id, r ->> 'chest', 'season_league', p_season_id::text);
        end if;
        if coalesce((r ->> 'coins')::int, 0) > 0 then
          perform _ledger_add(u.id, 'season_league', (r ->> 'coins')::int, r, 'season_league', p_season_id::text,
                              'season_league:' || p_season_id || ':' || u.id);
        end if;
      end if;
      if v_yeni <> u.mmr then
        update users set mmr = v_yeni where id = u.id;
      end if;
      n := n + 1;
    exception when others then
      insert into economy_errors (context, user_id, source_id, error)
      values ('season_league', u.id, p_season_id::text, sqlerrm);
    end;
  end loop;
  return n;
end;
$$;

create or replace function _league_season_on_close()
returns trigger language plpgsql as $$
begin
  if economy_flag('league_season_reset') then
    perform _league_season_end(new.id);
  end if;
  return null;
end;
$$;

drop trigger if exists trg_league_season_close on seasons;
create trigger trg_league_season_close
  after update of status on seasons
  for each row
  when (new.status = 'closed' and old.status is distinct from 'closed')
  execute function _league_season_on_close();
