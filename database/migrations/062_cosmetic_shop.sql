-- =====================================================================
-- 062 - KOZMETİK MAĞAZA + BAŞLANGIÇ PAKETİ (Faz 4)
-- =====================================================================
-- Belgeler: docs/monetization/ECONOMY_RISK_ANALYSIS.md (R1, R6, R7),
--           docs/monetization/ARCHITECTURE.md (ücretli / ücretsiz elmas)
--
-- 1) YENİ KOZMETİKLER: yalnız oyunda GERÇEKTEN çizilenler satılır
--    (profil çerçevesi: profil + açık profil; zafer animasyonu: maç sonu).
--    Mağazaya özel kozmetiklerin tekrar telafisi 0 altın: elmas → kozmetik
--    → tekrar → altın yolu kapalı (R1).
-- 2) TEKLİFLER (cosmetic_offers): sabit içerik, sabit elmas fiyatı, rastgele
--    ürün YOK (R6). Fiyat ve durum sunucuda.
-- 3) SATIN ALMA (buy_cosmetic): tek işlem, oyuncu kilidi, istek anahtarıyla
--    tekrar güvenli. Önce ÜCRETSİZ, yetmezse ÜCRETLİ elmas harcanır
--    (ARCHITECTURE). Aynı kozmetik iki kez satılmaz. Kapı:
--    monetization_gate(cosmetic_shop_enabled) — varsayılan KAPALI.
-- 4) BAŞLANGIÇ PAKETİ (061 starter_pack_1, taslak): içerik = 50 ücretli
--    elmas + mağazada satılmayan "Çaylak" çerçevesi. Güç vermez (R7).
--
-- KULLANICI VERİSİ: yalnız yeni tablo ve katalog satırı; bakiye, envanter
-- değişmez. Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) KOZMETİKLER
-- ---------------------------------------------------------------------
insert into item_definitions (slug, kind, category, name, description, max_stack, duration_seconds, cosmetic_slot,
                              overflow_coins, params, sort_order) values
  ('frame_neon', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Neon',
   'Profil avatarının çevresinde mavi-mor neon halka.', null, null, 'frame', 0, '{"shop": true}', 100),
  ('frame_crimson', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Kızıl Alev',
   'Profil avatarının çevresinde kızıl-turuncu halka.', null, null, 'frame', 0, '{"shop": true}', 101),
  ('frame_emerald', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Zümrüt',
   'Profil avatarının çevresinde yeşil-altın halka.', null, null, 'frame', 0, '{"shop": true}', 102),
  ('frame_starter', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Çaylak',
   'Başlangıç paketine özel çerçeve.', null, null, 'frame', 0, '{"shop": true, "starter": true}', 103),
  ('victory_star_rain', 'cosmetic', 'victory_anim', 'Zafer animasyonu: Yıldız Yağmuru',
   'Maç sonu zafer ekranında altın yıldız yağmuru.', null, null, 'victory', 0, '{"shop": true}', 104)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------
-- 2) TEKLİFLER
-- ---------------------------------------------------------------------
create table if not exists cosmetic_offers (
  id           text primary key check (id ~ '^[a-z0-9_]{3,60}$'),
  item_slug    text not null references item_definitions(slug),
  price_gems   int  not null check (price_gems between 1 and 5000),
  status       text not null default 'active' check (status in ('draft', 'active', 'paused', 'retired')),
  featured     boolean not null default false,
  starts_at    timestamptz,
  ends_at      timestamptz,
  sort_order   int not null default 100,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists idx_cosmetic_offers_item on cosmetic_offers (item_slug);
comment on table cosmetic_offers is
  '062: elmasla satilan kozmetikler. Sabit icerik ve fiyat; rastgele urun yok. Kapi: cosmetic_shop_enabled.';

-- Kozmetik dışı item satılamaz (güç veren item mağazaya giremez)
create or replace function _cosmetic_offer_check() returns trigger
language plpgsql as $$
begin
  if not exists (select 1 from item_definitions where slug = new.item_slug and kind = 'cosmetic') then
    raise exception 'invalid_offer: Yalniz kozmetik satilabilir.';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists trg_cosmetic_offer_check on cosmetic_offers;
create trigger trg_cosmetic_offer_check before insert or update on cosmetic_offers
  for each row execute function _cosmetic_offer_check();

insert into cosmetic_offers (id, item_slug, price_gems, featured, sort_order) values
  ('offer_frame_neon', 'frame_neon', 120, true, 10),
  ('offer_frame_crimson', 'frame_crimson', 120, false, 20),
  ('offer_frame_emerald', 'frame_emerald', 90, false, 30),
  ('offer_victory_star_rain', 'victory_star_rain', 150, false, 40)
on conflict (id) do nothing;

create table if not exists cosmetic_purchases (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references users(id) on delete cascade,
  offer_id     text not null references cosmetic_offers(id),
  item_slug    text not null references item_definitions(slug),
  price_gems   int  not null,
  free_spent   int  not null check (free_spent >= 0),
  paid_spent   int  not null check (paid_spent >= 0),
  request_key  text not null check (char_length(request_key) between 8 and 100),
  created_at   timestamptz not null default now(),
  unique (user_id, request_key),
  unique (user_id, item_slug),
  check (free_spent + paid_spent = price_gems)
);
create index if not exists idx_cosmetic_purchases_offer on cosmetic_purchases (offer_id);
create index if not exists idx_cosmetic_purchases_item on cosmetic_purchases (item_slug);
comment on table cosmetic_purchases is '062: elmasla kozmetik alimlari (ne kadari ucretsiz, ne kadari ucretli).';

-- Teklif bu oyuncuya şimdi satılabilir mi? null = evet
create or replace function _cosmetic_offer_problem(p_user_id uuid, o cosmetic_offers, p_platform text, p_app_version text)
returns text
language sql stable as $$
  select coalesce(
    case when o.id is null then 'offer_not_found' end,
    case when o.status <> 'active' then 'offer_not_active' end,
    case when (o.starts_at is not null and o.starts_at > now()) or (o.ends_at is not null and o.ends_at <= now())
         then 'offer_not_available' end,
    monetization_gate(p_user_id, 'cosmetic_shop_enabled', p_platform, p_app_version),
    case when _item_qty(p_user_id, o.item_slug) > 0 then 'already_owned' end);
$$;

-- Mağaza listesi: bakiyeler + teklifler (sahip olunanlar "owned" ile)
create or replace function cosmetic_shop(p_user_id uuid, p_platform text, p_app_version text)
returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'enabled', monetization_gate(p_user_id, 'cosmetic_shop_enabled', p_platform, p_app_version) is null,
    'gems', u.gems,
    'paid_gems', u.paid_gems,
    'offers', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', o.id, 'item_slug', o.item_slug, 'name', d.name, 'description', d.description,
          'slot', d.cosmetic_slot, 'category', d.category, 'price_gems', o.price_gems,
          'featured', o.featured, 'ends_at', o.ends_at,
          'owned', _item_qty(p_user_id, o.item_slug) > 0,
          'equipped', exists (select 1 from user_equipped e where e.user_id = p_user_id and e.item_slug = o.item_slug))
        order by o.featured desc, o.sort_order, o.id)
      from cosmetic_offers o join item_definitions d on d.slug = o.item_slug
      where o.status = 'active' and d.is_active
        and (o.starts_at is null or o.starts_at <= now()) and (o.ends_at is null or o.ends_at > now())),
      '[]'::jsonb))
  from users u where u.id = p_user_id;
$$;

-- Satın al. Önce ücretsiz, sonra ücretli elmas. Tekrar aynı anahtarla
-- gelirse aynı sonuç (ikinci kez harcanmaz).
create or replace function buy_cosmetic(p_user_id uuid, p_offer text, p_platform text, p_app_version text,
                                        p_request_key text)
returns jsonb
language plpgsql as $$
declare
  o        cosmetic_offers%rowtype;
  u        users%rowtype;
  k        cosmetic_purchases%rowtype;
  v_sorun  text;
  v_free   int;
  v_paid   int;
begin
  if p_request_key is null or char_length(p_request_key) not between 8 and 100 then
    raise exception 'invalid_request: Istek anahtari gecersiz.';
  end if;
  -- Oyuncu kilidi: aynı anda iki satın alma bakiyeyi aşamaz
  select * into u from users where id = p_user_id for update;
  if not found then raise exception 'user_not_found: Oyuncu bulunamadi.'; end if;

  select * into k from cosmetic_purchases where user_id = p_user_id and request_key = p_request_key;
  if found then
    return jsonb_build_object('purchase_id', k.id, 'item_slug', k.item_slug, 'replay', true,
                              'gems', u.gems, 'paid_gems', u.paid_gems);
  end if;

  select * into o from cosmetic_offers where id = p_offer;
  v_sorun := _cosmetic_offer_problem(p_user_id, o, p_platform, p_app_version);
  if v_sorun = 'already_owned' then
    raise exception 'already_owned: Bu kozmetige zaten sahipsin.';
  elsif v_sorun in ('offer_not_found', 'offer_not_active', 'offer_not_available') then
    raise exception 'offer_not_available: Bu teklif su an satista degil.';
  elsif v_sorun is not null then
    raise exception 'shop_disabled: Kozmetik magazasi su an kapali (%).', v_sorun;
  end if;

  if u.gems + u.paid_gems < o.price_gems then
    raise exception 'not_enough_gems: Yeterli elmas yok. Gerekli: %, mevcut: %', o.price_gems, u.gems + u.paid_gems;
  end if;
  v_free := least(u.gems, o.price_gems);
  v_paid := o.price_gems - v_free;

  insert into cosmetic_purchases (user_id, offer_id, item_slug, price_gems, free_spent, paid_spent, request_key)
  values (p_user_id, o.id, o.item_slug, o.price_gems, v_free, v_paid, p_request_key)
  returning * into k;

  if v_free > 0 then
    perform _gem_add(p_user_id, -v_free, 'cosmetic_purchase', k.id::text, 'cosmetic:' || k.id || ':free');
  end if;
  if v_paid > 0 then
    perform _paid_gem_add(p_user_id, -v_paid, 'cosmetic_purchase', k.id::text, 'cosmetic:' || k.id || ':paid');
  end if;
  perform grant_item(p_user_id, o.item_slug, 1, 'cosmetic_shop', k.id::text, 'cosmetic:' || k.id);
  perform monetization_event(p_user_id, 'cosmetic_purchased', null, null,
    jsonb_build_object('offer', o.id, 'price', o.price_gems, 'free', v_free, 'paid', v_paid));

  return jsonb_build_object('purchase_id', k.id, 'item_slug', o.item_slug, 'slot',
                            (select cosmetic_slot from item_definitions where slug = o.item_slug),
                            'free_spent', v_free, 'paid_spent', v_paid,
                            'gems', (select gems from users where id = p_user_id),
                            'paid_gems', (select paid_gems from users where id = p_user_id));
end;
$$;

-- ---------------------------------------------------------------------
-- 3) BAŞLANGIÇ PAKETİ İÇERİĞİ (yalnız taslaktayken; yayındaki ürün değişmez)
-- ---------------------------------------------------------------------
update product_catalog
set contents = '{"paid_gems": 50, "items": [{"slug": "frame_starter", "qty": 1}]}'::jsonb,
    description = 'Mağazada satılmayan Çaylak çerçevesi ve 50 elmas. Tek seferlik; maç gücü vermez.',
    updated_at = now()
where id = 'starter_pack_1' and status = 'draft' and not (contents ? 'items');
