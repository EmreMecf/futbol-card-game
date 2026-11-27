-- =====================================================================
-- 064 - MONETIZASYON YÖNETİMİ / LIVEOPS (Faz 6)
-- =====================================================================
-- Belgeler: docs/monetization/LIVEOPS_GUIDE.md, SECURITY_REVIEW.md
--
-- 1) ROLLER (admin_users): viewer (okur), operator (ayar, teklif, acil
--    kapatma, deney), owner (ek olarak GERÇEK PARA: satın alma bayrakları ve
--    ücretli ürünü yayına alma). Rol yalnız veritabanından verilir; API ile
--    rol verilemez. Rolü olmayan herkes 'admin_forbidden'.
-- 2) YÖNETİCİ İŞLEMLERİ rol denetimli SQL fonksiyonları; her değişiklik
--    monetization_admin_audit'e (değiştirilemez, 060) yazılır. Gerekçe zorunlu.
-- 3) DENEY (A/B): deterministik ve KALICI atama (ilk görülmede yazılır;
--    ağırlık sonradan değişse de oyuncunun grubu değişmez). Grup istemci
--    ayarında döner; deneye göre olay ve satın alma metrikleri.
-- 4) METRİKLER: günlük reklam, satın alma (tahmini gelir: mağaza fiyatı;
--    kesin gelir mağaza panelinden), iade, kozmetik harcama, dolaşımdaki
--    ücretli elmas ve borç.
-- 5) SAKLAMA (KVKK veri minimizasyonu): analitik olay 180, SSV ham kaydı
--    90, doğrulama olayı 400 gün. Satın alma kaydı, defterler ve denetim
--    SİLİNMEZ (mali kayıt).
--
-- KULLANICI VERİSİ: yalnız yeni tablo ve fonksiyon. Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) ROLLER
-- ---------------------------------------------------------------------
create table if not exists admin_users (
  user_id     uuid primary key references users(id) on delete cascade,
  role        text not null check (role in ('viewer', 'operator', 'owner')),
  granted_by  text not null check (char_length(granted_by) between 1 and 100),
  note        text,
  granted_at  timestamptz not null default now(),
  revoked_at  timestamptz
);
comment on table admin_users is
  '064: monetizasyon yoneticileri. Rol yalniz veritabanindan verilir (API ile verilemez).';

-- Etkin rol (yoksa null)
create or replace function _admin_role(p_user_id uuid) returns text
language sql stable as $$
  select role from admin_users where user_id = p_user_id and revoked_at is null;
$$;

-- Rol yetiyor mu; yetmiyorsa hata. Doner: aktör etiketi ("admin:<kullanıcı adı>")
create or replace function _admin_require(p_user_id uuid, p_min text) returns text
language plpgsql stable as $$
declare
  r text := _admin_role(p_user_id);
  sira jsonb := '{"viewer": 1, "operator": 2, "owner": 3}';
begin
  if r is null or (sira ->> r)::int < (sira ->> p_min)::int then
    raise exception 'admin_forbidden: Bu islem icin yetkin yok.';
  end if;
  return 'admin:' || coalesce((select username from users where id = p_user_id), p_user_id::text);
end;
$$;

create or replace function _admin_audit(p_actor text, p_action text, p_patch jsonb, p_reason text)
returns void language plpgsql as $$
begin
  if p_reason is null or char_length(btrim(p_reason)) < 3 then
    raise exception 'invalid_reason: Gerekce zorunlu (en az 3 karakter).';
  end if;
  insert into monetization_admin_audit (actor, action, config_kind, from_version, to_version, patch, reason)
  values (p_actor, p_action, 'monetization', null, null, coalesce(p_patch, '{}'::jsonb), p_reason);
end;
$$;

-- ---------------------------------------------------------------------
-- 2) YÖNETİCİ İŞLEMLERİ
-- ---------------------------------------------------------------------
-- Gerçek para açan anahtarlar (owner ister)
create or replace function _admin_real_money_keys() returns text[]
language sql immutable as $$
  select array['iap_enabled', 'gem_packs_enabled', 'starter_pack_enabled', 'premium_season_pass_enabled'];
$$;

create or replace function admin_set_monetization_config(p_actor uuid, p_patch jsonb, p_reason text)
returns jsonb
language plpgsql as $$
declare
  v_etiket text := _admin_require(p_actor, 'operator');
  k text;
begin
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    raise exception 'invalid_config: Yama bir nesne olmali.';
  end if;
  for k in select jsonb_object_keys(p_patch) loop
    if k = any(_admin_real_money_keys()) and (p_patch ->> k) = 'true' then
      perform _admin_require(p_actor, 'owner');
    end if;
  end loop;
  return set_monetization_config(p_patch, v_etiket, p_reason);
end;
$$;

create or replace function admin_kill_switch(p_actor uuid, p_reason text)
returns jsonb
language plpgsql as $$
begin
  return monetization_kill_switch(_admin_require(p_actor, 'operator'), p_reason);
end;
$$;

-- Gerçek parayla satılan ürünün durumu. 'active' yapmak owner ister.
create or replace function admin_set_product_status(p_actor uuid, p_product text, p_status text, p_reason text)
returns jsonb
language plpgsql as $$
declare
  v_etiket text := _admin_require(p_actor, case when p_status = 'active' then 'owner' else 'operator' end);
  v_eski text;
begin
  if p_status not in ('draft', 'active', 'paused', 'retired') then
    raise exception 'invalid_status: Gecersiz durum.';
  end if;
  select status into v_eski from product_catalog where id = p_product for update;
  if not found then raise exception 'product_not_found: Urun bulunamadi.'; end if;
  perform _admin_audit(v_etiket, 'product_status',
    jsonb_build_object('product', p_product, 'from', v_eski, 'to', p_status), p_reason);
  update product_catalog set status = p_status, updated_at = now() where id = p_product;
  return jsonb_build_object('product', p_product, 'status', p_status, 'previous', v_eski);
end;
$$;

-- Elmasla kozmetik teklifi (fiyat / durum / öne çıkan / bitiş)
create or replace function admin_update_cosmetic_offer(p_actor uuid, p_offer text, p_patch jsonb, p_reason text)
returns jsonb
language plpgsql as $$
declare
  v_etiket text := _admin_require(p_actor, 'operator');
  o cosmetic_offers%rowtype;
  k text;
begin
  select * into o from cosmetic_offers where id = p_offer for update;
  if not found then raise exception 'offer_not_found: Teklif bulunamadi.'; end if;
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    raise exception 'invalid_offer: Yama bir nesne olmali.';
  end if;
  for k in select jsonb_object_keys(p_patch) loop
    if k not in ('price_gems', 'status', 'featured', 'ends_at', 'sort_order') then
      raise exception 'invalid_offer: Bilinmeyen alan %.', k;
    end if;
  end loop;
  perform _admin_audit(v_etiket, 'cosmetic_offer',
    jsonb_build_object('offer', p_offer, 'patch', p_patch,
                       'from', jsonb_build_object('price_gems', o.price_gems, 'status', o.status,
                                                  'featured', o.featured, 'ends_at', o.ends_at)), p_reason);
  update cosmetic_offers set
    price_gems = coalesce((p_patch ->> 'price_gems')::int, price_gems),
    status     = coalesce(p_patch ->> 'status', status),
    featured   = coalesce((p_patch ->> 'featured')::boolean, featured),
    ends_at    = case when p_patch ? 'ends_at' then (p_patch ->> 'ends_at')::timestamptz else ends_at end,
    sort_order = coalesce((p_patch ->> 'sort_order')::int, sort_order)
  where id = p_offer
  returning * into o;
  return to_jsonb(o);
end;
$$;

-- ---------------------------------------------------------------------
-- 3) DENEYLER (A/B)
-- ---------------------------------------------------------------------
create table if not exists monetization_experiments (
  key          text primary key check (key ~ '^[a-z0-9_]{3,60}$'),
  description  text not null default '',
  -- [{"name": "control", "weight": 50}, {"name": "b", "weight": 50}]
  variants     jsonb not null check (jsonb_typeof(variants) = 'array' and jsonb_array_length(variants) between 2 and 5),
  status       text not null default 'draft' check (status in ('draft', 'running', 'stopped')),
  created_by   text not null,
  created_at   timestamptz not null default now(),
  started_at   timestamptz,
  stopped_at   timestamptz
);

create table if not exists experiment_assignments (
  experiment_key  text not null references monetization_experiments(key) on delete cascade,
  user_id         uuid not null references users(id) on delete cascade,
  variant         text not null,
  assigned_at     timestamptz not null default now(),
  primary key (experiment_key, user_id)
);
create index if not exists idx_experiment_assignments_user on experiment_assignments (user_id);

-- Deney gruplarının biçimi: ad tekil, ağırlık 0-100 tam sayı, toplam 100
create or replace function _experiment_variants_valid(p jsonb) returns boolean
language sql immutable as $$
  select jsonb_typeof(p) = 'array'
     and jsonb_array_length(p) between 2 and 5
     and not exists (select 1 from jsonb_array_elements(p) v
                     where coalesce(v ->> 'name', '') !~ '^[a-z0-9_]{1,30}$'
                        or jsonb_typeof(v -> 'weight') <> 'number'
                        or (v ->> 'weight')::numeric not between 0 and 100
                        or (v ->> 'weight')::numeric <> trunc((v ->> 'weight')::numeric))
     and (select count(distinct v ->> 'name') from jsonb_array_elements(p) v) = jsonb_array_length(p)
     and (select sum((v ->> 'weight')::int) from jsonb_array_elements(p) v) = 100;
$$;

-- Oyuncunun grubu: deney çalışmıyorsa null. İlk çağrıda deterministik
-- dilimle seçilir ve KALICI yazılır.
create or replace function experiment_variant(p_user_id uuid, p_key text) returns text
language plpgsql as $$
declare
  e monetization_experiments%rowtype;
  v_var text;
  v_dilim int;
  v_top int := 0;
  g jsonb;
begin
  select variant into v_var from experiment_assignments where experiment_key = p_key and user_id = p_user_id;
  if found then
    return case when exists (select 1 from monetization_experiments where key = p_key and status = 'running')
                then v_var end;
  end if;
  select * into e from monetization_experiments where key = p_key and status = 'running';
  if not found then return null; end if;
  v_dilim := monetization_bucket(p_user_id, 'experiment:' || p_key);
  for g in select * from jsonb_array_elements(e.variants) loop
    v_top := v_top + (g ->> 'weight')::int;
    if v_dilim < v_top then
      v_var := g ->> 'name';
      exit;
    end if;
  end loop;
  insert into experiment_assignments (experiment_key, user_id, variant) values (p_key, p_user_id, v_var)
  on conflict (experiment_key, user_id) do nothing;
  select variant into v_var from experiment_assignments where experiment_key = p_key and user_id = p_user_id;
  return v_var;
end;
$$;

-- Bu oyuncunun çalışan deneylerdeki grupları {anahtar: grup}
create or replace function experiment_variants_for(p_user_id uuid) returns jsonb
language plpgsql as $$
declare
  v jsonb := '{}'::jsonb;
  e record;
begin
  for e in select key from monetization_experiments where status = 'running' order by key loop
    v := v || jsonb_build_object(e.key, experiment_variant(p_user_id, e.key));
  end loop;
  return v;
end;
$$;

create or replace function admin_create_experiment(p_actor uuid, p_key text, p_description text, p_variants jsonb,
                                                   p_reason text)
returns jsonb
language plpgsql as $$
declare
  v_etiket text := _admin_require(p_actor, 'operator');
begin
  if p_key is null or p_key !~ '^[a-z0-9_]{3,60}$' then raise exception 'invalid_experiment: Gecersiz anahtar.'; end if;
  if not _experiment_variants_valid(p_variants) then
    raise exception 'invalid_experiment: Gruplar 2-5 adet, tekil ad, tam sayi agirlik, toplam 100 olmali.';
  end if;
  if exists (select 1 from monetization_experiments where key = p_key) then
    raise exception 'experiment_exists: Bu anahtarla deney var.';
  end if;
  perform _admin_audit(v_etiket, 'experiment_create', jsonb_build_object('key', p_key, 'variants', p_variants), p_reason);
  insert into monetization_experiments (key, description, variants, created_by)
  values (p_key, coalesce(p_description, ''), p_variants, v_etiket);
  return jsonb_build_object('key', p_key, 'status', 'draft');
end;
$$;

-- draft → running → stopped (geri dönüş yok: durmuş deney yeniden başlamaz)
create or replace function admin_set_experiment_status(p_actor uuid, p_key text, p_status text, p_reason text)
returns jsonb
language plpgsql as $$
declare
  v_etiket text := _admin_require(p_actor, 'operator');
  e monetization_experiments%rowtype;
begin
  select * into e from monetization_experiments where key = p_key for update;
  if not found then raise exception 'experiment_not_found: Deney bulunamadi.'; end if;
  if not ((e.status = 'draft' and p_status = 'running') or (e.status = 'running' and p_status = 'stopped')
          or (e.status = 'draft' and p_status = 'stopped')) then
    raise exception 'invalid_status: % durumundan % durumuna gecilemez.', e.status, p_status;
  end if;
  perform _admin_audit(v_etiket, 'experiment_status',
    jsonb_build_object('key', p_key, 'from', e.status, 'to', p_status), p_reason);
  update monetization_experiments
  set status = p_status,
      started_at = case when p_status = 'running' then now() else started_at end,
      stopped_at = case when p_status = 'stopped' then now() else stopped_at end
  where key = p_key;
  return jsonb_build_object('key', p_key, 'status', p_status);
end;
$$;

-- Deney sonucu: grup başına oyuncu, olay sayıları, satın alan oyuncu
create or replace function admin_experiment_report(p_actor uuid, p_key text) returns jsonb
language plpgsql as $$
declare
  e monetization_experiments%rowtype;
begin
  perform _admin_require(p_actor, 'viewer');
  select * into e from monetization_experiments where key = p_key;
  if not found then raise exception 'experiment_not_found: Deney bulunamadi.'; end if;
  return jsonb_build_object(
    'experiment', to_jsonb(e),
    'variants', coalesce((
      select jsonb_agg(jsonb_build_object(
        'variant', g.variant,
        'players', g.players,
        'ad_rewards', (select count(*) from ad_sessions s join experiment_assignments a2 on a2.user_id = s.user_id
                       where a2.experiment_key = p_key and a2.variant = g.variant
                         and s.status in ('granted', 'credit') and s.created_at >= coalesce(e.started_at, e.created_at)),
        'payers', (select count(distinct t.user_id) from purchase_transactions t
                   join experiment_assignments a3 on a3.user_id = t.user_id
                   where a3.experiment_key = p_key and a3.variant = g.variant
                     and t.status in ('granted', 'acknowledged') and t.created_at >= coalesce(e.started_at, e.created_at)))
        order by g.variant)
      from (select variant, count(*) as players from experiment_assignments
            where experiment_key = p_key group by variant) g), '[]'::jsonb));
end;
$$;

-- İstemci ayarı + deney grupları (060 monetization_client_config + bir alan)
create or replace function monetization_client_config(p_user_id uuid, p_platform text, p_app_version text)
returns jsonb
language sql as $$
  select jsonb_build_object(
    'rewarded_ads', monetization_gate(p_user_id, 'rewarded_ads_enabled', p_platform, p_app_version) is null,
    'daily_reward_ads', monetization_gate(p_user_id, 'daily_reward_ads_enabled', p_platform, p_app_version) is null,
    'chest_speedup_ads', monetization_gate(p_user_id, 'chest_speedup_ads_enabled', p_platform, p_app_version) is null,
    'post_match_ads', monetization_gate(p_user_id, 'post_match_ads_enabled', p_platform, p_app_version) is null,
    'iap', monetization_gate(p_user_id, 'iap_enabled', p_platform, p_app_version) is null,
    'ad_server_verification_required', coalesce((monetization_config() ->> 'ad_server_verification_required')::boolean, true),
    'config_version', economy_config_version('monetization'),
    'experiments', case when monetization_gate(p_user_id, 'monetization_enabled', p_platform, p_app_version) is null
                        then experiment_variants_for(p_user_id) else '{}'::jsonb end);
$$;

-- ---------------------------------------------------------------------
-- 4) METRİKLER
-- ---------------------------------------------------------------------
create or replace function admin_monetization_metrics(p_actor uuid, p_days int default 7) returns jsonb
language plpgsql stable as $$
declare
  v_gun int := least(greatest(coalesce(p_days, 7), 1), 90);
  v_bas timestamptz;
begin
  perform _admin_require(p_actor, 'viewer');
  v_bas := date_trunc('day', now()) - make_interval(days => v_gun - 1);
  return jsonb_build_object(
    'days', v_gun,
    'from', v_bas,
    'ads', coalesce((select jsonb_agg(x order by x ->> 'day') from (
        select jsonb_build_object('day', game_day, 'placement', placement,
                                  'granted', count(*) filter (where status in ('granted', 'credit')),
                                  'rejected', count(*) filter (where status = 'rejected'),
                                  'started', count(*)) x
        from ad_sessions where created_at >= v_bas group by game_day, placement) q), '[]'::jsonb),
    'ssv_invalid_signatures', (select count(*) from ad_ssv_events where received_at >= v_bas and not signature_valid),
    'purchases', coalesce((select jsonb_agg(x) from (
        select jsonb_build_object('product', product_id, 'currency', currency,
                                  'granted', count(*) filter (where status in ('granted', 'acknowledged')),
                                  'pending', count(*) filter (where status = 'pending'),
                                  'failed', count(*) filter (where status = 'failed'),
                                  'refunded', count(*) filter (where status in ('refunded', 'revoked')),
                                  'estimated_revenue_micros',
                                    coalesce(sum(price_micros) filter (where status in ('granted', 'acknowledged')), 0),
                                  'payers', count(distinct user_id) filter (where status in ('granted', 'acknowledged'))) x
        from purchase_transactions where created_at >= v_bas and environment = 'production'
        group by product_id, currency) q), '[]'::jsonb),
    'sandbox_purchases', (select count(*) from purchase_transactions
                          where created_at >= v_bas and environment <> 'production'),
    'cosmetics', coalesce((select jsonb_agg(x) from (
        select jsonb_build_object('offer', offer_id, 'sold', count(*),
                                  'free_gems', sum(free_spent), 'paid_gems', sum(paid_spent)) x
        from cosmetic_purchases where created_at >= v_bas group by offer_id) q), '[]'::jsonb),
    'paid_gems_in_circulation', (select coalesce(sum(paid_gems), 0) from users),
    'paid_gems_debt', (select coalesce(sum(paid_gems_debt), 0) from users),
    'note', 'Gelir tahminidir (magaza fiyati, vergi ve komisyon dahil degil). Kesin gelir magaza panelindedir.');
end;
$$;

create or replace function admin_monetization_overview(p_actor uuid) returns jsonb
language plpgsql stable as $$
declare
  v_rol text;
begin
  perform _admin_require(p_actor, 'viewer');
  v_rol := _admin_role(p_actor);
  return jsonb_build_object(
    'role', v_rol,
    'config', monetization_config(),
    'config_version', economy_config_version('monetization'),
    'products', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'category', category, 'status', status,
                                                              'contents', contents) order by sort_order, id)
                          from product_catalog), '[]'::jsonb),
    'cosmetic_offers', coalesce((select jsonb_agg(to_jsonb(o) order by o.sort_order, o.id) from cosmetic_offers o), '[]'::jsonb),
    'experiments', coalesce((select jsonb_agg(to_jsonb(e) order by e.created_at desc) from monetization_experiments e), '[]'::jsonb),
    'audit', coalesce((select jsonb_agg(to_jsonb(a) order by a.id desc)
                       from (select * from monetization_admin_audit order by id desc limit 30) a), '[]'::jsonb));
end;
$$;

-- ---------------------------------------------------------------------
-- 5) SAKLAMA SÜRESİ
-- ---------------------------------------------------------------------
create index if not exists idx_ad_ssv_events_time on ad_ssv_events (received_at);

create or replace function purge_monetization_events(
  p_event_days int default 180, p_ssv_days int default 90, p_verification_days int default 400)
returns jsonb
language plpgsql as $$
declare
  a int;
  b int;
  c int;
begin
  if least(p_event_days, p_ssv_days, p_verification_days) < 30 then
    raise exception 'invalid_retention: Saklama suresi en az 30 gun olmali.';
  end if;
  delete from monetization_events where created_at < now() - make_interval(days => p_event_days);
  get diagnostics a = row_count;
  delete from ad_ssv_events where received_at < now() - make_interval(days => p_ssv_days);
  get diagnostics b = row_count;
  delete from purchase_verification_events where created_at < now() - make_interval(days => p_verification_days);
  get diagnostics c = row_count;
  return jsonb_build_object('monetization_events', a, 'ad_ssv_events', b, 'purchase_verification_events', c);
end;
$$;
comment on function purge_monetization_events is
  '064: analitik ve ham dogrulama kayitlarini saklama suresi sonunda siler. Satin alma kaydi, defter ve denetim silinmez.';
