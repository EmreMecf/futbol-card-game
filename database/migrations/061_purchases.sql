-- =====================================================================
-- 061 - UYGULAMA İÇİ SATIN ALMA (Faz 3)
-- =====================================================================
-- Belgeler: docs/monetization/ARCHITECTURE.md, GOOGLE_PLAY_BILLING_SETUP.md,
--           APPLE_IAP_SETUP.md, ECONOMY_RISK_ANALYSIS.md (R1)
--
-- 1) ÜRÜN KATALOĞU: mağaza kimlikleri, içerik, durum, tarih, limit, platform.
--    FİYAT YOK: gerçek fiyat mağaza SDK'sından yerel para biriminde gelir.
--    Tohum ürünler "draft" (görünmez) başlar.
-- 2) SATIN ALMA KAYDI: her mağaza işlemi bir satır; (platform, işlem kimliği)
--    ve Google jeton özeti TEKİL. Aynı ödeme ikinci kez ya da BAŞKA HESAPTA
--    kullanılamaz. Yaşam döngüsü: created → pending → verification_required →
--    verified → granted → acknowledged; cancelled, failed, refunded, revoked.
-- 3) ÖDÜL yalnız sunucu, mağazanın kendi API'siyle doğruladıktan sonra
--    purchase_grant_verified ile verilir (tek işlem: kayıt + elmas defteri).
--    Ücretli elmas users.paid_gems'e (060) ve gem_ledger'a currency='paid'
--    ile yazılır. Ücretli elmas altına çevrilemez, sandık açamaz (R1).
-- 4) İADE/İPTAL: ücretli elmas geri alınır; bakiye yetmezse kalan
--    users.paid_gems_debt olur ve sonraki satın almadan önce düşülür
--    (bakiye asla eksiye inmez, CHECK korunur).
-- 5) AÇMA-KAPAMA: katalog monetizasyon kapılarına bağlı (iap_enabled +
--    kategori bayrağı). DOĞRULANMIŞ bir ödemenin ödülü kapı kapalı olsa da
--    verilir: oyuncu ödediyse hakkı kaybolmaz (acil kapatma yalnız YENİ
--    satın almayı durdurur).
--
-- KULLANICI VERİSİ: yalnız yeni tablo/sütun (paid_gems_debt = 0). Mevcut
-- bakiyeler değişmez. Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- ELMAS DEFTERİ: para türü
-- ---------------------------------------------------------------------
alter table gem_ledger add column if not exists currency text not null default 'free';
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'gem_ledger_currency_check') then
    alter table gem_ledger add constraint gem_ledger_currency_check check (currency in ('free', 'paid'));
  end if;
end $$;

alter table users add column if not exists paid_gems_debt int not null default 0;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'users_paid_gems_debt_nonnegative') then
    alter table users add constraint users_paid_gems_debt_nonnegative check (paid_gems_debt >= 0);
  end if;
end $$;
comment on column users.paid_gems_debt is
  '061: iade edilen ucretli elmasin bakiyeden karsilanamayan kismi. Sonraki ucretli elmas once bunu kapatir.';

-- Ücretli elmas ekle/düş. Ekleme önce borcu kapatır. Düşüşte bakiye
-- yetmezse hata (harcama) ya da p_to_debt ise kalan borca yazılır (iade).
create or replace function _paid_gem_add(p_user_id uuid, p_delta int, p_reason text, p_source text, p_key text,
                                         p_to_debt boolean default false)
returns int
language plpgsql as $$
declare
  v_gems int;
  v_borc int;
  v_eski gem_ledger%rowtype;
  v_net  int;
  v_yeni_borc int;
begin
  select * into v_eski from gem_ledger where idempotency_key = p_key;
  if found then return v_eski.gems_after; end if;
  select paid_gems, paid_gems_debt into v_gems, v_borc from users where id = p_user_id for update;
  if not found then raise exception 'user_not_found: Oyuncu bulunamadi.'; end if;
  select * into v_eski from gem_ledger where idempotency_key = p_key;
  if found then return v_eski.gems_after; end if;

  if p_delta >= 0 then
    v_net := greatest(0, p_delta - v_borc);
    v_yeni_borc := greatest(0, v_borc - p_delta);
  elsif v_gems + p_delta >= 0 then
    v_net := p_delta;
    v_yeni_borc := v_borc;
  elsif p_to_debt then
    v_net := -v_gems;
    v_yeni_borc := v_borc + (-p_delta - v_gems);
  else
    raise exception 'not_enough_gems: Yeterli elmas yok. Gerekli: %, mevcut: %', -p_delta, v_gems;
  end if;

  update users set paid_gems = paid_gems + v_net, paid_gems_debt = v_yeni_borc where id = p_user_id;
  insert into gem_ledger (user_id, delta, gems_after, reason, source_id, idempotency_key, currency)
  values (p_user_id, v_net, v_gems + v_net, p_reason, p_source, p_key, 'paid');
  return v_gems + v_net;
end;
$$;

-- ---------------------------------------------------------------------
-- ÜRÜN KATALOĞU
-- ---------------------------------------------------------------------
create table if not exists product_catalog (
  id                 text primary key check (id ~ '^[a-z0-9_]{3,60}$'),
  category           text not null check (category in ('GEM_PACK', 'COSMETIC', 'COSMETIC_BUNDLE', 'STARTER_PACK',
                                                       'SEASON_PASS', 'EVENT_OFFER')),
  google_product_id  text unique,
  apple_product_id   text unique,
  product_type       text not null check (product_type in ('consumable', 'non_consumable')),
  name               text not null,
  description        text not null default '',
  -- {"paid_gems": 100, "items": [{"slug": "frame_x", "qty": 1}]}. Güç veren
  -- içerik (altın, joker, sandık, kart) YASAK (R1): CHECK ile engellenir.
  contents           jsonb not null,
  image              text,
  animation          jsonb not null default '{}'::jsonb,
  status             text not null default 'draft' check (status in ('draft', 'active', 'paused', 'retired')),
  starts_at          timestamptz,
  ends_at            timestamptz,
  purchase_limit     int check (purchase_limit is null or purchase_limit > 0),
  eligibility        jsonb not null default '{}'::jsonb,
  platforms          text[] not null default array['android', 'ios'],
  sort_order         int not null default 100,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (not (contents ?| array['coins', 'jokers', 'chests', 'cards', 'gems']))
);
comment on table product_catalog is
  '061: gercek parayla satilan urunler. Fiyat magazadan gelir. Icerik guc veremez (yalniz ucretli elmas ve kozmetik).';

-- Tohum (draft: görünmez; açmak ayrı karar). Fiyat taslağı yalnız belgede.
insert into product_catalog (id, category, google_product_id, apple_product_id, product_type, name, description,
                             contents, status, purchase_limit, eligibility, sort_order)
values
  ('gems_starter_100', 'GEM_PACK', 'gems_starter_100', 'gems_starter_100', 'consumable',
   '100 Elmas', 'Kozmetik ürünlerde kullanılır.', '{"paid_gems": 100}', 'draft', null, '{}', 10),
  ('gems_popular_300', 'GEM_PACK', 'gems_popular_300', 'gems_popular_300', 'consumable',
   '300 Elmas', 'Kozmetik ürünlerde kullanılır.', '{"paid_gems": 300}', 'draft', null, '{}', 20),
  ('gems_large_700', 'GEM_PACK', 'gems_large_700', 'gems_large_700', 'consumable',
   '700 Elmas', 'Kozmetik ürünlerde kullanılır.', '{"paid_gems": 700}', 'draft', null, '{}', 30),
  ('starter_pack_1', 'STARTER_PACK', 'starter_pack_1', 'starter_pack_1', 'non_consumable',
   'Başlangıç Paketi', 'Hesaba bağlı kozmetik ve az miktar elmas. Tek seferlik.', '{"paid_gems": 50}',
   'draft', 1, '{"max_account_age_days": 7}', 5)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------
-- SATIN ALMA KAYITLARI
-- ---------------------------------------------------------------------
create table if not exists purchase_transactions (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null references users(id) on delete restrict,
  product_id            text not null references product_catalog(id),
  platform              text not null check (platform in ('android', 'ios', 'test')),
  store_transaction_id  text not null check (char_length(store_transaction_id) between 1 and 200),
  purchase_token_hash   text unique,
  environment           text not null default 'production' check (environment in ('production', 'sandbox', 'test')),
  status                text not null check (status in ('created', 'pending', 'verification_required', 'verified',
                                                       'granted', 'acknowledged', 'cancelled', 'failed',
                                                       'refunded', 'revoked')),
  price_micros          bigint,
  currency              text,
  contents              jsonb not null default '{}'::jsonb,
  failure_reason        text,
  created_at            timestamptz not null default now(),
  verified_at           timestamptz,
  granted_at            timestamptz,
  acknowledged_at       timestamptz,
  refunded_at           timestamptz,
  unique (platform, store_transaction_id)
);
create index if not exists idx_purchase_transactions_user on purchase_transactions (user_id, created_at desc);
create index if not exists idx_purchase_transactions_product on purchase_transactions (product_id);
comment on table purchase_transactions is
  '061: magaza islemleri. Makbuz/jeton saklanmaz (yalniz SHA-256 ozeti). Odul yalniz sunucu dogrulamasindan sonra.';

create table if not exists purchase_verification_events (
  id                    bigint generated always as identity primary key,
  purchase_id           uuid references purchase_transactions(id) on delete set null,
  platform              text,
  store_transaction_id  text,
  event                 text not null check (event ~ '^[a-z_]+$'),
  ok                    boolean not null,
  detail                text,
  created_at            timestamptz not null default now()
);
create index if not exists idx_purchase_events_time on purchase_verification_events (created_at desc);
create index if not exists idx_purchase_events_purchase on purchase_verification_events (purchase_id);

create or replace function _purchase_event(p_purchase uuid, p_platform text, p_tx text, p_event text, p_ok boolean, p_detail text)
returns void language sql as $$
  insert into purchase_verification_events (purchase_id, platform, store_transaction_id, event, ok, detail)
  values (p_purchase, p_platform, left(p_tx, 200), p_event, p_ok, left(p_detail, 300));
$$;

create or replace function _product_for_store(p_platform text, p_store_product text) returns product_catalog
language sql stable as $$
  select * from product_catalog
  where case p_platform when 'android' then google_product_id when 'ios' then apple_product_id else id end = p_store_product;
$$;

-- Hesap başına geçerli (iade edilmemiş) satın alma sayısı
create or replace function _purchase_count(p_user_id uuid, p_product text) returns int
language sql stable as $$
  select count(*)::int from purchase_transactions
  where user_id = p_user_id and product_id = p_product and status in ('verified', 'granted', 'acknowledged');
$$;

-- Kategori → özellik bayrağı
create or replace function _product_flag(p_category text) returns text
language sql immutable as $$
  select case p_category
    when 'GEM_PACK' then 'gem_packs_enabled'
    when 'STARTER_PACK' then 'starter_pack_enabled'
    when 'SEASON_PASS' then 'premium_season_pass_enabled'
    else 'cosmetic_shop_enabled' end;
$$;

-- Ürün bu oyuncuya şimdi satılabilir mi? null = evet, aksi hâlde neden
create or replace function _product_problem(p_user_id uuid, p product_catalog, p_platform text, p_app_version text)
returns text
language plpgsql stable as $$
declare
begin
  if p.id is null then return 'product_not_found'; end if;
  if p.status <> 'active' then return 'product_not_active'; end if;
  if (p.starts_at is not null and p.starts_at > now()) or (p.ends_at is not null and p.ends_at <= now()) then
    return 'product_not_available';
  end if;
  if not (lower(coalesce(p_platform, '')) = any(p.platforms)) then return 'platform_not_supported'; end if;
  return coalesce(
    monetization_gate(p_user_id, 'iap_enabled', p_platform, p_app_version),
    monetization_gate(p_user_id, _product_flag(p.category), p_platform, p_app_version),
    case when p.purchase_limit is not null and _purchase_count(p_user_id, p.id) >= p.purchase_limit
         then 'already_owned' end,
    (select case when u2.created_at < now() - make_interval(days => (p.eligibility ->> 'max_account_age_days')::int)
                 then 'not_eligible' end
     from users u2 where u2.id = p_user_id and p.eligibility ? 'max_account_age_days'));
end;
$$;

-- Bu oyuncuya gösterilecek katalog (fiyat yok; istemci mağazadan alır)
create or replace function product_catalog_for(p_user_id uuid, p_platform text, p_app_version text)
returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'enabled', monetization_gate(p_user_id, 'iap_enabled', p_platform, p_app_version) is null,
    'products', coalesce(jsonb_agg(jsonb_build_object(
        'id', p.id, 'category', p.category, 'product_type', p.product_type,
        'store_product_id', case lower(p_platform) when 'android' then p.google_product_id
                                                   when 'ios' then p.apple_product_id else p.id end,
        'name', p.name, 'description', p.description, 'contents', p.contents,
        'image', p.image, 'animation', p.animation, 'ends_at', p.ends_at,
        'purchase_limit', p.purchase_limit,
        'purchased_count', _purchase_count(p_user_id, p.id),
        'problem', _product_problem(p_user_id, p, p_platform, p_app_version))
      order by p.sort_order, p.id) filter (where _product_problem(p_user_id, p, p_platform, p_app_version) is null
                                              or _product_problem(p_user_id, p, p_platform, p_app_version) = 'already_owned'),
      '[]'::jsonb))
  from product_catalog p
  where p.status = 'active';
$$;

-- Ödülü ver (yalnız sunucu, mağaza API'siyle doğruladıktan sonra çağırır).
-- p_state: 'purchased' | 'pending'. Aynı işlem tekrar gelirse aynı sonuç.
create or replace function purchase_grant_verified(
  p_user_id uuid, p_platform text, p_store_product text, p_store_tx text, p_token_hash text,
  p_environment text, p_state text, p_price_micros bigint default null, p_currency text default null)
returns jsonb
language plpgsql as $$
declare
  p      product_catalog%rowtype;
  t      purchase_transactions%rowtype;
  v_n    int;
  i      record;
begin
  if p_store_tx is null or char_length(p_store_tx) not between 1 and 200 then
    raise exception 'invalid_purchase: Islem kimligi gecersiz.';
  end if;
  perform pg_advisory_xact_lock(hashtext('purchase:' || p_platform || ':' || p_store_tx));
  p := _product_for_store(p_platform, p_store_product);
  if p.id is null then
    perform _purchase_event(null, p_platform, p_store_tx, 'grant_rejected', false, 'product_not_found');
    raise exception 'product_not_found: Urun bulunamadi.';
  end if;

  select * into t from purchase_transactions where platform = p_platform and store_transaction_id = p_store_tx for update;
  if not found and p_token_hash is not null then
    select * into t from purchase_transactions where purchase_token_hash = p_token_hash for update;
  end if;
  if found then
    if t.user_id <> p_user_id then
      -- Aynı ödeme başka hesapta kullanılamaz
      perform _purchase_event(t.id, p_platform, p_store_tx, 'cross_account_blocked', false, p_user_id::text);
      raise exception 'purchase_belongs_to_another_account: Bu satin alma baska bir hesaba ait.';
    end if;
    -- Bekleyen Google ödemesi sipariş kimliği olmadan kaydedilmişti
    -- ("pending:" + jeton özeti); gerçek kimlik gelince ona geçilir
    -- (iade bildirimleri sipariş kimliğiyle gelir).
    if t.store_transaction_id like 'pending:%' and p_store_tx not like 'pending:%' then
      update purchase_transactions set store_transaction_id = p_store_tx where id = t.id returning * into t;
    end if;
    if t.status in ('granted', 'acknowledged', 'refunded', 'revoked', 'failed', 'cancelled')
       or (t.status = 'pending' and p_state = 'pending') then
      return jsonb_build_object('purchase_id', t.id, 'status', t.status, 'replay', true,
                                'paid_gems', (select paid_gems from users where id = p_user_id));
    end if;
  else
    insert into purchase_transactions (user_id, product_id, platform, store_transaction_id, purchase_token_hash,
                                       environment, status, price_micros, currency, contents)
    values (p_user_id, p.id, p_platform, p_store_tx, p_token_hash, coalesce(p_environment, 'production'),
            'verification_required', p_price_micros, p_currency, p.contents)
    returning * into t;
  end if;

  if p_state = 'pending' then
    update purchase_transactions set status = 'pending' where id = t.id;
    perform _purchase_event(t.id, p_platform, p_store_tx, 'purchase_pending', true, null);
    return jsonb_build_object('purchase_id', t.id, 'status', 'pending');
  end if;

  update purchase_transactions set status = 'verified', verified_at = now() where id = t.id;
  -- Tek seferlik ürün limiti (istemci engeller; aşıldıysa ödül verilmez, iade için işaretlenir)
  if p.purchase_limit is not null and _purchase_count(p_user_id, p.id) > p.purchase_limit then
    update purchase_transactions set status = 'failed', failure_reason = 'limit_exceeded_refund_required' where id = t.id;
    perform _purchase_event(t.id, p_platform, p_store_tx, 'grant_rejected', false, 'limit_exceeded_refund_required');
    return jsonb_build_object('purchase_id', t.id, 'status', 'failed', 'reason', 'limit_exceeded');
  end if;

  v_n := coalesce((t.contents ->> 'paid_gems')::int, 0);
  if v_n > 0 then
    perform _paid_gem_add(p_user_id, v_n, 'purchase', t.id::text, 'purchase:' || t.id);
  end if;
  for i in select x ->> 'slug' as slug, coalesce((x ->> 'qty')::int, 1) as qty
           from jsonb_array_elements(coalesce(t.contents -> 'items', '[]'::jsonb)) x loop
    perform grant_item(p_user_id, i.slug, i.qty, 'purchase', t.id::text, 'purchase_item:' || t.id || ':' || i.slug);
  end loop;
  update purchase_transactions set status = 'granted', granted_at = now() where id = t.id;
  perform _purchase_event(t.id, p_platform, p_store_tx, 'purchase_granted', true, null);
  perform monetization_event(p_user_id, 'purchase_granted', null, null, jsonb_build_object('product', p.id));
  return jsonb_build_object('purchase_id', t.id, 'status', 'granted', 'contents', t.contents,
                            'paid_gems', (select paid_gems from users where id = p_user_id));
end;
$$;

-- Mağazaya "teslim edildi" bildirildi (Google acknowledge / consume, Apple finish)
create or replace function purchase_mark_acknowledged(p_purchase uuid) returns void
language sql as $$
  update purchase_transactions set status = 'acknowledged', acknowledged_at = now()
  where id = p_purchase and status = 'granted';
$$;

-- İade / iptal (webhook ya da mutabakat). Tekrar gelirse etkisiz.
create or replace function purchase_refund(p_platform text, p_store_tx text, p_kind text, p_reason text)
returns jsonb
language plpgsql as $$
declare
  t   purchase_transactions%rowtype;
  v_n int;
  i   record;
begin
  if p_kind not in ('refunded', 'revoked') then raise exception 'invalid_refund: Gecersiz iade turu.'; end if;
  perform pg_advisory_xact_lock(hashtext('purchase:' || p_platform || ':' || p_store_tx));
  select * into t from purchase_transactions where platform = p_platform and store_transaction_id = p_store_tx for update;
  if not found then
    perform _purchase_event(null, p_platform, p_store_tx, 'refund_unknown_purchase', false, p_reason);
    return jsonb_build_object('status', 'unknown');
  end if;
  if t.status in ('refunded', 'revoked') then
    return jsonb_build_object('purchase_id', t.id, 'status', t.status, 'replay', true);
  end if;
  if t.status in ('granted', 'acknowledged') then
    v_n := coalesce((t.contents ->> 'paid_gems')::int, 0);
    if v_n > 0 then
      perform _paid_gem_add(t.user_id, -v_n, 'purchase_refund', t.id::text, 'refund:' || t.id, true);
    end if;
    for i in select x ->> 'slug' as slug, coalesce((x ->> 'qty')::int, 1) as qty
             from jsonb_array_elements(coalesce(t.contents -> 'items', '[]'::jsonb)) x loop
      begin
        perform _item_take(t.user_id, i.slug, i.qty);
      exception when others then
        perform _purchase_event(t.id, p_platform, p_store_tx, 'refund_item_missing', false, i.slug);
      end;
    end loop;
  end if;
  update purchase_transactions set status = p_kind, refunded_at = now(), failure_reason = left(p_reason, 200)
  where id = t.id;
  perform _purchase_event(t.id, p_platform, p_store_tx, 'purchase_' || p_kind, true, p_reason);
  perform monetization_event(t.user_id, 'purchase_refunded', null, null, jsonb_build_object('product', t.product_id));
  return jsonb_build_object('purchase_id', t.id, 'status', p_kind,
                            'paid_gems', (select paid_gems from users where id = t.user_id),
                            'paid_gems_debt', (select paid_gems_debt from users where id = t.user_id));
end;
$$;

-- Doğrulama başarısız (sahte makbuz vb.): kayıt, ödül yok
create or replace function purchase_record_failure(p_user_id uuid, p_platform text, p_store_tx text, p_reason text)
returns void language sql as $$
  select _purchase_event(null, p_platform, p_store_tx, 'verification_failed', false, p_user_id::text || ': ' || p_reason);
$$;

create or replace function purchase_history(p_user_id uuid) returns jsonb
language sql stable as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'purchase_id', t.id, 'product_id', t.product_id, 'platform', t.platform, 'status', t.status,
    'contents', t.contents, 'created_at', t.created_at, 'granted_at', t.granted_at, 'refunded_at', t.refunded_at)
    order by t.created_at desc), '[]'::jsonb)
  from purchase_transactions t where t.user_id = p_user_id;
$$;
