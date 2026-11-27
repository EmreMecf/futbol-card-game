-- =====================================================================
-- 060 - MONETİZASYON ÇEKİRDEĞİ (Faz 1) + ÖDÜLLÜ REKLAM (Faz 2)
-- =====================================================================
-- Belgeler: docs/monetization/ARCHITECTURE.md, ECONOMY_RISK_ANALYSIS.md
--
-- 1) AYAR: economy_config_versions'a yeni tür 'monetization'. Sürümlü ve
--    değiştirilemez (028 tetikleyicisi). HER ŞEY KAPALI başlar.
--    Kapı sırası: global → özellik → platform → en düşük sürüm →
--    beyaz liste (her zaman açık) → deterministik yüzde dilimi.
--    Ayar okunamazsa kapalı (fail-closed).
-- 2) DENETİM: her ayar değişikliği monetization_admin_audit'e yazılır.
-- 3) OLAYLAR: monetization_events (reklam/satın alma huni olayları).
-- 4) ÜCRETLİ ELMAS: users.paid_gems (0). Mevcut users.gems = ücretsiz
--    elmas, DEĞİŞMEZ. Altın değişimi ve sandık açma yalnız ücretsiz elmas
--    harcar (056/057 zaten yalnız gems sütununu kullanıyor).
-- 5) ÖDÜLLÜ REKLAM: oturum (süreli rezervasyon) → istemci reklamı gösterir
--    → AdMob imzalı SSV geri çağrısı (sunucu imzayı doğrular) → bu dosyadaki
--    ad_ssv_grant tek işlemde ödülü verir. transaction_id tekil; aynı
--    geri çağrı ikinci kez ödül vermez. Günlük sınır sunucu gününe
--    (game_day) göre, eşzamanlı isteklere karşı oyuncu kilidiyle.
--    AKTİF MAÇ VARKEN OTURUM AÇILAMAZ.
--
-- KULLANICI VERİSİ: yalnız yeni sütun (paid_gems = 0) ve yeni tablolar.
-- Mevcut bakiye, kart, sandık, maç kayıtları değişmez. Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) AYAR
-- ---------------------------------------------------------------------
insert into economy_config_versions (kind, version, payload, note)
values ('monetization', 1, '{
  "monetization_enabled": false,
  "rewarded_ads_enabled": false,
  "interstitial_ads_enabled": false,
  "banner_ads_enabled": false,
  "native_ads_enabled": false,
  "iap_enabled": false,
  "gem_packs_enabled": false,
  "cosmetic_shop_enabled": false,
  "starter_pack_enabled": false,
  "premium_season_pass_enabled": false,
  "daily_reward_ads_enabled": false,
  "chest_speedup_ads_enabled": false,
  "post_match_ads_enabled": false,
  "first_session_ads_enabled": false,
  "ranked_match_ads_enabled": false,
  "paid_gems_chest_open_enabled": false,
  "ad_server_verification_required": true,
  "purchase_server_verification_required": true,
  "daily_rewarded_ad_limit": 3,
  "session_ttl_seconds": 900,
  "ssv_grace_seconds": 3600,
  "credit_valid_days": 7,
  "first_session_hours": 24,
  "platforms": ["android", "ios"],
  "min_app_version": "1.0.0",
  "rollout_percent": 0,
  "whitelist": [],
  "placements": {
    "daily_reward":  {"flag": "daily_reward_ads_enabled",  "daily_limit": 2, "reward": {"type": "coins", "amount": 40}},
    "chest_speedup": {"flag": "chest_speedup_ads_enabled", "daily_limit": 1, "reward": {"type": "chest_minutes", "amount": 10}},
    "post_match":    {"flag": "post_match_ads_enabled",    "daily_limit": 1, "reward": {"type": "coins", "amount": 20}}
  }
}'::jsonb, '060: monetizasyon, her sey kapali')
on conflict (kind, version) do nothing;

create or replace function monetization_config() returns jsonb
language sql stable as $$ select economy_config('monetization') $$;

-- "1.10.2" >= "1.9" ? (sayısal parça karşılaştırması; bozuk girdi = false)
create or replace function _version_ge(p_a text, p_b text) returns boolean
language plpgsql immutable as $$
declare
  a int[];
  b int[];
begin
  if p_a is null or p_a !~ '^[0-9]+(\.[0-9]+){0,3}$' or p_b !~ '^[0-9]+(\.[0-9]+){0,3}$' then
    return false;
  end if;
  a := string_to_array(p_a, '.')::int[];
  b := string_to_array(p_b, '.')::int[];
  for i in 1..greatest(cardinality(a), cardinality(b)) loop
    if coalesce(a[i], 0) <> coalesce(b[i], 0) then
      return coalesce(a[i], 0) > coalesce(b[i], 0);
    end if;
  end loop;
  return true;
end;
$$;

-- Oyuncunun bu yüzde dilimi (0-99), özellik başına sabit
create or replace function monetization_bucket(p_user_id uuid, p_feature text) returns int
language sql immutable as $$
  select (abs(hashtext(p_user_id::text || ':' || p_feature)::bigint) % 100)::int
$$;

-- Kapı: null = açık; aksi hâlde neden kodu
create or replace function monetization_gate(p_user_id uuid, p_feature text, p_platform text, p_app_version text)
returns text
language plpgsql stable as $$
declare
  c jsonb := monetization_config();
begin
  if c is null then return 'config_unavailable'; end if;
  if not coalesce((c ->> 'monetization_enabled')::boolean, false) then return 'monetization_disabled'; end if;
  if not coalesce((c ->> p_feature)::boolean, false) then return 'feature_disabled'; end if;
  if p_platform is null or not coalesce(c -> 'platforms', '[]'::jsonb) ? lower(p_platform) then
    return 'platform_not_supported';
  end if;
  if not _version_ge(p_app_version, coalesce(c ->> 'min_app_version', '999')) then
    return 'app_version_too_old';
  end if;
  if coalesce(c -> 'whitelist', '[]'::jsonb) ? p_user_id::text then return null; end if;
  if monetization_bucket(p_user_id, p_feature) >= coalesce((c ->> 'rollout_percent')::int, 0) then
    return 'not_in_rollout';
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------
-- 2) YÖNETİCİ DENETİMİ + AYAR DEĞİŞTİRME
-- ---------------------------------------------------------------------
create table if not exists monetization_admin_audit (
  id            bigint generated always as identity primary key,
  actor         text not null check (char_length(actor) between 1 and 100),
  action        text not null check (action ~ '^[a-z_]+$'),
  config_kind   text not null default 'monetization',
  from_version  int,
  to_version    int,
  patch         jsonb not null default '{}'::jsonb,
  reason        text not null check (char_length(reason) between 3 and 500),
  created_at    timestamptz not null default now()
);
create index if not exists idx_monetization_admin_audit_time on monetization_admin_audit (created_at desc);

create or replace function _monetization_audit_no_change() returns trigger
language plpgsql as $$
begin
  raise exception 'Denetim kaydi degistirilemez.';
end;
$$;
drop trigger if exists trg_monetization_audit_immutable on monetization_admin_audit;
create trigger trg_monetization_audit_immutable
  before update or delete on monetization_admin_audit
  for each row execute function _monetization_audit_no_change();

-- Ayarı değiştir: mevcut sürüm + yama → yeni sürüm (eski sürüm kalır).
-- Bilinmeyen anahtar ve aralık dışı sayı reddedilir.
create or replace function set_monetization_config(p_patch jsonb, p_actor text, p_reason text)
returns jsonb
language plpgsql as $$
declare
  v_eski   int;
  v_yeni   jsonb;
  v_ver    int;
  k        text;
  v_bool   text[] := array['monetization_enabled','rewarded_ads_enabled','interstitial_ads_enabled','banner_ads_enabled',
                           'native_ads_enabled','iap_enabled','gem_packs_enabled','cosmetic_shop_enabled',
                           'starter_pack_enabled','premium_season_pass_enabled','daily_reward_ads_enabled',
                           'chest_speedup_ads_enabled','post_match_ads_enabled','first_session_ads_enabled',
                           'ranked_match_ads_enabled','paid_gems_chest_open_enabled',
                           'ad_server_verification_required','purchase_server_verification_required'];
  v_int    jsonb := '{"daily_rewarded_ad_limit":[0,10],"session_ttl_seconds":[60,3600],"ssv_grace_seconds":[300,86400],
                      "credit_valid_days":[1,30],"first_session_hours":[0,168],"rollout_percent":[0,100]}';
begin
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    raise exception 'invalid_config: Yama bir nesne olmali.';
  end if;
  perform pg_advisory_xact_lock(hashtext('monetization_config'));
  for k in select jsonb_object_keys(p_patch) loop
    if k = any(v_bool) then
      if jsonb_typeof(p_patch -> k) <> 'boolean' then raise exception 'invalid_config: % mantiksal olmali.', k; end if;
    elsif v_int ? k then
      if jsonb_typeof(p_patch -> k) <> 'number'
         or (p_patch ->> k)::numeric not between (v_int -> k ->> 0)::numeric and (v_int -> k ->> 1)::numeric
         or (p_patch ->> k)::numeric <> trunc((p_patch ->> k)::numeric) then
        raise exception 'invalid_config: % % ile % arasinda tam sayi olmali.', k, v_int -> k ->> 0, v_int -> k ->> 1;
      end if;
    elsif k in ('platforms', 'whitelist') then
      if jsonb_typeof(p_patch -> k) <> 'array' then raise exception 'invalid_config: % dizi olmali.', k; end if;
    elsif k = 'min_app_version' then
      if (p_patch ->> k) !~ '^[0-9]+(\.[0-9]+){0,3}$' then raise exception 'invalid_config: surum bicimi gecersiz.'; end if;
    elsif k = 'placements' then
      if jsonb_typeof(p_patch -> k) <> 'object' then raise exception 'invalid_config: placements nesne olmali.'; end if;
    else
      raise exception 'invalid_config: bilinmeyen anahtar %.', k;
    end if;
  end loop;
  if p_actor is null or char_length(p_actor) = 0 or p_reason is null or char_length(p_reason) < 3 then
    raise exception 'invalid_config: Degisikligi yapan ve gerekce zorunlu.';
  end if;
  v_eski := economy_config_version('monetization');
  v_yeni := coalesce(monetization_config(), '{}'::jsonb) || p_patch;
  v_ver := coalesce(v_eski, 0) + 1;
  insert into economy_config_versions (kind, version, payload, note)
  values ('monetization', v_ver, v_yeni, left(p_actor || ': ' || p_reason, 200));
  insert into monetization_admin_audit (actor, action, from_version, to_version, patch, reason)
  values (p_actor, 'config_change', v_eski, v_ver, p_patch, p_reason);
  return jsonb_build_object('version', v_ver, 'config', v_yeni);
end;
$$;

-- Acil kapatma: tek çağrıyla bütün reklam ve satın almayı kapatır.
-- Önceden doğrulanmış ödüller etkilenmez (yalnız YENİ oturum açılamaz).
create or replace function monetization_kill_switch(p_actor text, p_reason text)
returns jsonb
language sql as $$
  select set_monetization_config(
    '{"monetization_enabled": false, "rewarded_ads_enabled": false, "iap_enabled": false}'::jsonb,
    p_actor, 'ACIL KAPATMA: ' || p_reason);
$$;

-- ---------------------------------------------------------------------
-- 3) OLAYLAR (analitik)
-- ---------------------------------------------------------------------
create table if not exists monetization_events (
  id          bigint generated always as identity primary key,
  user_id     uuid references users(id) on delete set null,
  event       text not null check (event ~ '^[a-z_]+$'),
  placement   text,
  session_id  uuid,
  props       jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists idx_monetization_events_time on monetization_events (created_at desc);
create index if not exists idx_monetization_events_user on monetization_events (user_id, created_at desc);

create or replace function monetization_event(p_user_id uuid, p_event text, p_placement text, p_session uuid, p_props jsonb)
returns void
language sql as $$
  insert into monetization_events (user_id, event, placement, session_id, props)
  values (p_user_id, p_event, p_placement, p_session, coalesce(p_props, '{}'::jsonb));
$$;

-- ---------------------------------------------------------------------
-- 4) ÜCRETLİ ELMAS (Faz 3'te satın almayla dolar; bugün herkes 0)
-- ---------------------------------------------------------------------
alter table users add column if not exists paid_gems int not null default 0;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'users_paid_gems_nonnegative') then
    alter table users add constraint users_paid_gems_nonnegative check (paid_gems >= 0);
  end if;
end $$;
comment on column users.paid_gems is
  '060: gercek parayla alinan elmas. Altina cevrilemez, sandik acamaz (guc satilmaz). gems = ucretsiz elmas.';

-- ---------------------------------------------------------------------
-- 5) ÖDÜLLÜ REKLAM
-- ---------------------------------------------------------------------
create table if not exists ad_sessions (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references users(id) on delete cascade,
  placement           text not null check (placement in ('daily_reward', 'chest_speedup', 'post_match')),
  target_id           text,
  status              text not null default 'reserved'
                        check (status in ('reserved', 'verifying', 'granted', 'credit', 'rejected', 'cancelled')),
  game_day            date not null,
  reward              jsonb not null,
  client_platform     text,
  client_app_version  text,
  created_at          timestamptz not null default now(),
  expires_at          timestamptz not null,
  verified_at         timestamptz,
  granted_at          timestamptz,
  ssv_transaction_id  text unique,
  ssv_ad_unit         text,
  reject_reason       text,
  credit_applied_to   text
);
create index if not exists idx_ad_sessions_user_day on ad_sessions (user_id, game_day);
-- Maç sonu teklifi maç başına bir kez
create unique index if not exists uq_ad_sessions_post_match
  on ad_sessions (user_id, target_id) where placement = 'post_match' and status not in ('cancelled', 'rejected');

-- Her SSV geri çağrısının kaydı (imza geçersiz olanlar dahil). İmza
-- değeri saklanmaz.
create table if not exists ad_ssv_events (
  id              bigint generated always as identity primary key,
  transaction_id  text,
  key_id          bigint,
  session_id      uuid,
  ssv_user_id     text,
  ad_unit         text,
  reward_amount   int,
  signature_valid boolean not null,
  outcome         text not null,
  received_at     timestamptz not null default now()
);
create index if not exists idx_ad_ssv_events_tx on ad_ssv_events (transaction_id);

create or replace function _ad_placement(p_placement text) returns jsonb
language sql stable as $$ select monetization_config() -> 'placements' -> p_placement $$;

-- Bugün sayılan oturumlar: doğrulanan/verilen + süresi dolmamış rezervasyon
create or replace function _ad_used_today(p_user_id uuid, p_placement text, p_exclude uuid default null) returns int
language sql stable as $$
  select count(*)::int from ad_sessions s
  where s.user_id = p_user_id and s.game_day = game_day()
    and (p_placement is null or s.placement = p_placement)
    and (p_exclude is null or s.id <> p_exclude)
    and (s.status in ('verifying', 'granted', 'credit')
         or (s.status = 'reserved' and s.expires_at > now()))
$$;

-- Hedef geçerli mi? null = geçerli, aksi hâlde neden
create or replace function _ad_target_problem(p_user_id uuid, p_placement text, p_target text) returns text
language plpgsql stable as $$
declare
  c user_chests%rowtype;
  m matches%rowtype;
begin
  if p_placement = 'chest_speedup' then
    if p_target is null or p_target !~ '^[0-9a-f-]{36}$' then return 'chest_not_eligible'; end if;
    select * into c from user_chests where id = p_target::uuid and user_id = p_user_id;
    if not found or c.location <> 'slot' or c.status <> 'unlocking' or c.unlock_ready_at <= now() + interval '60 seconds' then
      return 'chest_not_eligible';
    end if;
  elsif p_placement = 'post_match' then
    if p_target is null or p_target !~ '^[0-9a-f-]{36}$' then return 'match_not_eligible'; end if;
    select * into m from matches where id = p_target::uuid;
    if not found or p_user_id not in (m.player1_id, m.player2_id) or m.status <> 'finished'
       or m.finished_at < now() - interval '30 minutes' then
      return 'match_not_eligible';
    end if;
  end if;
  return null;
end;
$$;

-- Uygunluk (oturum açmadan önce ve ekranda düğme durumu için)
create or replace function ad_eligibility(p_user_id uuid, p_placement text, p_platform text, p_app_version text,
                                          p_target text default null)
returns jsonb
language plpgsql stable as $$
declare
  c       jsonb := monetization_config();
  p       jsonb := _ad_placement(p_placement);
  u       users%rowtype;
  v_neden text;
  v_genel int;
  v_yer   int;
  v_glim  int;
  v_plim  int;
begin
  select * into u from users where id = p_user_id;
  v_genel := _ad_used_today(p_user_id, null);
  v_yer   := _ad_used_today(p_user_id, p_placement);
  v_glim  := coalesce((c ->> 'daily_rewarded_ad_limit')::int, 0);
  v_plim  := coalesce((p ->> 'daily_limit')::int, 0);
  v_neden := case
    when not found or u.is_banned then 'account_not_eligible'
    when p is null then 'unknown_placement'
    else coalesce(monetization_gate(p_user_id, 'rewarded_ads_enabled', p_platform, p_app_version),
                  monetization_gate(p_user_id, p ->> 'flag', p_platform, p_app_version))
  end;
  if v_neden is null and get_active_match_id(p_user_id) is not null then v_neden := 'in_match'; end if;
  if v_neden is null and not coalesce((c ->> 'first_session_ads_enabled')::boolean, false)
     and u.created_at > now() - make_interval(hours => coalesce((c ->> 'first_session_hours')::int, 24)) then
    v_neden := 'first_session';
  end if;
  if v_neden is null and v_genel >= v_glim then v_neden := 'daily_limit'; end if;
  if v_neden is null and v_yer >= v_plim then v_neden := 'placement_limit'; end if;
  if v_neden is null then v_neden := _ad_target_problem(p_user_id, p_placement, p_target); end if;
  return jsonb_build_object(
    'placement', p_placement,
    'eligible', v_neden is null,
    'reason', v_neden,
    'reward', coalesce(p -> 'reward', '{}'::jsonb),
    'remaining_today', greatest(0, least(v_glim - v_genel, v_plim - v_yer)),
    'placement_limit', v_plim,
    'global_limit', v_glim,
    'used_today', v_genel,
    'resets_at', next_game_day_at());
end;
$$;

-- Oturum aç (süreli rezervasyon). Aynı yerleşim ve hedef için açık
-- rezervasyon varsa onu döndürür (çift dokunma ikinci hak harcamaz).
create or replace function ad_session_create(p_user_id uuid, p_placement text, p_platform text, p_app_version text,
                                             p_target text default null)
returns jsonb
language plpgsql as $$
declare
  e   jsonb;
  s   ad_sessions%rowtype;
  c   jsonb := monetization_config();
begin
  perform pg_advisory_xact_lock(hashtext('ads:' || p_user_id::text));
  select * into s from ad_sessions
  where user_id = p_user_id and placement = p_placement and target_id is not distinct from p_target
    and status = 'reserved' and expires_at > now()
  order by created_at desc limit 1;
  if found then
    return jsonb_build_object('session_id', s.id, 'ssv_user_id', s.user_id, 'custom_data', s.id,
                              'reward', s.reward, 'expires_at', s.expires_at, 'reused', true);
  end if;
  e := ad_eligibility(p_user_id, p_placement, p_platform, p_app_version, p_target);
  if not (e ->> 'eligible')::boolean then
    perform monetization_event(p_user_id, 'ad_eligibility_checked', p_placement, null,
                               jsonb_build_object('eligible', false, 'reason', e ->> 'reason'));
    raise exception 'ad_not_eligible: %', e ->> 'reason';
  end if;
  insert into ad_sessions (user_id, placement, target_id, game_day, reward, client_platform, client_app_version, expires_at)
  values (p_user_id, p_placement, p_target, game_day(), e -> 'reward', lower(p_platform), p_app_version,
          now() + make_interval(secs => coalesce((c ->> 'session_ttl_seconds')::int, 900)))
  returning * into s;
  perform monetization_event(p_user_id, 'ad_requested', p_placement, s.id, '{}'::jsonb);
  return jsonb_build_object('session_id', s.id, 'ssv_user_id', s.user_id, 'custom_data', s.id,
                            'reward', s.reward, 'expires_at', s.expires_at, 'reused', false);
end;
$$;

-- İstemci olayları. "earned": doğrulama bekleniyor (rezervasyon düşmez).
-- "closed"/"failed": ödül kazanılmadıysa rezervasyon bırakılır (hak geri gelir).
-- Hiçbiri ödül VERMEZ.
create or replace function ad_session_client_event(p_user_id uuid, p_session uuid, p_event text)
returns jsonb
language plpgsql as $$
declare
  s ad_sessions%rowtype;
begin
  if p_event not in ('shown', 'earned', 'closed', 'failed') then
    raise exception 'invalid_event: Gecersiz olay.';
  end if;
  select * into s from ad_sessions where id = p_session and user_id = p_user_id for update;
  if not found then raise exception 'ad_session_not_found: Reklam oturumu bulunamadi.'; end if;
  if p_event = 'earned' and s.status = 'reserved' then
    update ad_sessions set status = 'verifying' where id = s.id returning * into s;
  elsif p_event in ('closed', 'failed') and s.status = 'reserved' then
    update ad_sessions set status = 'cancelled' where id = s.id returning * into s;
  end if;
  perform monetization_event(p_user_id,
    case p_event when 'shown' then 'ad_started' when 'earned' then 'ad_completed'
                 when 'closed' then 'ad_closed' else 'ad_load_failed' end,
    s.placement, s.id, '{}'::jsonb);
  return ad_session_status(p_user_id, p_session);
end;
$$;

-- Ödülü uygula (yalnız ad_ssv_grant ve kredi uygulama çağırır)
create or replace function _ad_apply_reward(s ad_sessions, p_chest text) returns text
language plpgsql as $$
declare
  c   user_chests%rowtype;
  v_dk int;
begin
  if (s.reward ->> 'type') = 'coins' then
    perform _ledger_add(s.user_id, 'ad_reward', (s.reward ->> 'amount')::int,
                        jsonb_build_object('placement', s.placement), 'ad_session', s.id::text, 'ad_reward:' || s.id);
    return 'granted';
  elsif (s.reward ->> 'type') = 'chest_minutes' then
    v_dk := (s.reward ->> 'amount')::int;
    if p_chest is not null and p_chest ~ '^[0-9a-f-]{36}$' then
      perform pg_advisory_xact_lock(hashtext('user_chests:' || s.user_id::text));
      select * into c from user_chests where id = p_chest::uuid and user_id = s.user_id for update;
      if found and c.location = 'slot' and c.status = 'unlocking' and c.unlock_ready_at > now() then
        -- Süre negatife düşmez: en erken "şimdi"
        update user_chests set unlock_ready_at = greatest(now(), unlock_ready_at - make_interval(mins => v_dk))
        where id = c.id;
        return 'granted';
      end if;
    end if;
    -- Sandık reklam sırasında bitti/açıldı: ödül kaybolmaz, kredi olur
    return 'credit';
  end if;
  raise exception 'invalid_reward: Bilinmeyen odul turu.';
end;
$$;

-- SSV ile ödül. Sunucu imzayı DOĞRULADIKTAN sonra çağırır. Tekrar gelen
-- transaction_id aynı sonucu döndürür, ikinci ödül yok.
create or replace function ad_ssv_grant(p_transaction_id text, p_session text, p_ssv_user text,
                                        p_reward_amount int, p_ad_unit text, p_key_id bigint)
returns jsonb
language plpgsql as $$
declare
  s        ad_sessions%rowtype;
  c        jsonb := monetization_config();
  v_sonuc  text;
  v_onceki ad_sessions%rowtype;
begin
  if p_transaction_id is null or char_length(p_transaction_id) not between 1 and 200 then
    raise exception 'invalid_ssv: transaction_id gecersiz.';
  end if;
  -- Aynı işlem daha önce işlendiyse aynı cevap (Google yeniden denemeleri)
  select * into v_onceki from ad_sessions where ssv_transaction_id = p_transaction_id;
  if found then
    insert into ad_ssv_events (transaction_id, key_id, session_id, ssv_user_id, ad_unit, reward_amount, signature_valid, outcome)
    values (p_transaction_id, p_key_id, v_onceki.id, p_ssv_user, p_ad_unit, p_reward_amount, true, 'duplicate');
    perform monetization_event(v_onceki.user_id, 'ad_reward_duplicate_blocked', v_onceki.placement, v_onceki.id, '{}');
    return jsonb_build_object('outcome', 'duplicate', 'status', v_onceki.status, 'session_id', v_onceki.id);
  end if;

  if p_session is null or p_session !~ '^[0-9a-f-]{36}$' then
    v_sonuc := 'session_not_found';
  else
    select * into s from ad_sessions where id = p_session::uuid for update;
    if not found then
      v_sonuc := 'session_not_found';
    elsif p_ssv_user is distinct from s.user_id::text then
      v_sonuc := 'user_mismatch';
    elsif s.status in ('granted', 'credit') then
      v_sonuc := 'session_already_rewarded';
    elsif s.status = 'rejected' then
      v_sonuc := 'session_rejected';
    elsif s.created_at < now() - make_interval(secs => coalesce((c ->> 'ssv_grace_seconds')::int, 3600)) then
      v_sonuc := 'session_expired';
    end if;
  end if;

  if v_sonuc is null then
    perform pg_advisory_xact_lock(hashtext('ads:' || s.user_id::text));
    -- Rezervasyon düşmüşse (süre doldu / istemci kapattı) sınır yeniden sayılır
    if not (s.status = 'verifying' or (s.status = 'reserved' and s.expires_at > now())) then
      if _ad_used_today(s.user_id, null, s.id) >= coalesce((c ->> 'daily_rewarded_ad_limit')::int, 0)
         or _ad_used_today(s.user_id, s.placement, s.id) >= coalesce((_ad_placement(s.placement) ->> 'daily_limit')::int, 0) then
        v_sonuc := 'daily_limit';
      end if;
    end if;
  end if;

  if v_sonuc is not null then
    insert into ad_ssv_events (transaction_id, key_id, session_id, ssv_user_id, ad_unit, reward_amount, signature_valid, outcome)
    values (p_transaction_id, p_key_id, case when s.id is not null then s.id end, p_ssv_user, p_ad_unit, p_reward_amount, true, v_sonuc);
    if s.id is not null and v_sonuc in ('daily_limit', 'session_expired') then
      update ad_sessions set status = 'rejected', reject_reason = v_sonuc, ssv_transaction_id = p_transaction_id,
                             verified_at = now() where id = s.id;
    end if;
    perform monetization_event(s.user_id, 'ad_verification_failed', s.placement, s.id, jsonb_build_object('reason', v_sonuc));
    return jsonb_build_object('outcome', 'rejected', 'reason', v_sonuc);
  end if;

  v_sonuc := _ad_apply_reward(s, s.target_id);
  update ad_sessions
  set status = v_sonuc, ssv_transaction_id = p_transaction_id, ssv_ad_unit = p_ad_unit,
      verified_at = now(), granted_at = case when v_sonuc = 'granted' then now() end
  where id = s.id;
  insert into ad_ssv_events (transaction_id, key_id, session_id, ssv_user_id, ad_unit, reward_amount, signature_valid, outcome)
  values (p_transaction_id, p_key_id, s.id, p_ssv_user, p_ad_unit, p_reward_amount, true, v_sonuc);
  perform monetization_event(s.user_id, 'ad_verification_received', s.placement, s.id, '{}');
  perform monetization_event(s.user_id, 'ad_reward_granted', s.placement, s.id, jsonb_build_object('status', v_sonuc));
  return jsonb_build_object('outcome', v_sonuc, 'session_id', s.id);
end;
$$;

-- Geçersiz imzalı geri çağrının kaydı (ödül yok)
create or replace function ad_ssv_record_invalid(p_transaction_id text, p_key_id bigint, p_session text, p_reason text)
returns void
language sql as $$
  insert into ad_ssv_events (transaction_id, key_id, session_id, signature_valid, outcome)
  values (left(p_transaction_id, 200), p_key_id,
          case when p_session ~ '^[0-9a-f-]{36}$' then p_session::uuid end, false, left(p_reason, 60));
$$;

-- Krediyi (sandık reklam sırasında bittiyse) başka bir sayaçlı sandığa uygula
create or replace function ad_session_apply_credit(p_user_id uuid, p_session uuid, p_chest uuid)
returns jsonb
language plpgsql as $$
declare
  s   ad_sessions%rowtype;
  c   jsonb := monetization_config();
  v   text;
begin
  select * into s from ad_sessions where id = p_session and user_id = p_user_id for update;
  if not found or s.status <> 'credit' then
    raise exception 'ad_credit_not_found: Kullanilabilir hizlandirma hakki yok.';
  end if;
  if s.verified_at < now() - make_interval(days => coalesce((c ->> 'credit_valid_days')::int, 7)) then
    raise exception 'ad_credit_expired: Hizlandirma hakkinin suresi doldu.';
  end if;
  v := _ad_apply_reward(s, p_chest::text);
  if v <> 'granted' then
    raise exception 'chest_not_eligible: Bu sandik hizlandirilamaz.';
  end if;
  update ad_sessions set status = 'granted', granted_at = now(), credit_applied_to = p_chest::text where id = s.id;
  return ad_session_status(p_user_id, p_session);
end;
$$;

create or replace function ad_session_status(p_user_id uuid, p_session uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'session_id', s.id, 'placement', s.placement, 'status', s.status, 'reward', s.reward,
    'target_id', s.target_id, 'reject_reason', s.reject_reason, 'expires_at', s.expires_at,
    'granted_at', s.granted_at,
    'coins_after', (select coins from users where id = s.user_id))
  from ad_sessions s where s.id = p_session and s.user_id = p_user_id;
$$;

-- Ekran özeti: her yerleşim için uygunluk + kullanılmamış krediler
create or replace function ad_status(p_user_id uuid, p_platform text, p_app_version text) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'placements', jsonb_build_object(
      'daily_reward', ad_eligibility(p_user_id, 'daily_reward', p_platform, p_app_version),
      'chest_speedup', ad_eligibility(p_user_id, 'chest_speedup', p_platform, p_app_version),
      'post_match', ad_eligibility(p_user_id, 'post_match', p_platform, p_app_version)),
    'credits', coalesce((
      select jsonb_agg(jsonb_build_object('session_id', s.id, 'reward', s.reward, 'verified_at', s.verified_at))
      from ad_sessions s
      where s.user_id = p_user_id and s.status = 'credit'
        and s.verified_at >= now() - make_interval(days => coalesce((monetization_config() ->> 'credit_valid_days')::int, 7))),
      '[]'::jsonb),
    'resets_at', next_game_day_at());
$$;

-- İstemciye açık ayar özeti (sır yok): bu oyuncu için açık özellikler
create or replace function monetization_client_config(p_user_id uuid, p_platform text, p_app_version text)
returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'rewarded_ads', monetization_gate(p_user_id, 'rewarded_ads_enabled', p_platform, p_app_version) is null,
    'daily_reward_ads', monetization_gate(p_user_id, 'daily_reward_ads_enabled', p_platform, p_app_version) is null,
    'chest_speedup_ads', monetization_gate(p_user_id, 'chest_speedup_ads_enabled', p_platform, p_app_version) is null,
    'post_match_ads', monetization_gate(p_user_id, 'post_match_ads_enabled', p_platform, p_app_version) is null,
    'iap', monetization_gate(p_user_id, 'iap_enabled', p_platform, p_app_version) is null,
    'ad_server_verification_required', coalesce((monetization_config() ->> 'ad_server_verification_required')::boolean, true),
    'config_version', economy_config_version('monetization'));
$$;
