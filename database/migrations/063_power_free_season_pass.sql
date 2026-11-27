-- =====================================================================
-- 063 - GÜÇSÜZ PREMIUM SEZON YOLU (Faz 5)
-- =====================================================================
-- Belgeler: docs/monetization/ECONOMY_RISK_ANALYSIS.md (R2)
--
-- Sorun (R2): 035 premium yolu joker, sandık, altın, ustalık kitabı veriyor.
-- Satılırsa parayla güç satılmış olur. Bu yüzden 035'ten beri premium
-- satın alma yok.
--
-- Çözüm:
-- 1) SEZON KURALI SÜRÜM 2: ücretsiz yol AYNEN korunur; premium yol yalnız
--    ÜCRETLİ ELMAS (kozmetikte harcanır, altına/sandığa dönmez, R1) ve
--    pas'a özel kozmetik (tekrar telafisi 0 altın). Ödül tablosu sezon
--    başında dondurulduğu için (035) bu kural YENİ sezonlarda geçerli olur;
--    süren sezonun tablosu değişmez.
-- 2) SATIS KAPISI: premium yalnız, o anki sezonun premium yolunun TAMAMI
--    güçsüzse satılır (_season_premium_power_free). Güçlü yollu (035) bir
--    sezonda satış kapalı kalır. Ayrıca monetization_gate
--    (iap_enabled + premium_season_pass_enabled), sezon başına tek alım.
-- 3) GERİYE DÖNÜK ÖDÜL: sezon ortasında alınırsa ulaşılmış bütün premium
--    kademeleri hemen alınabilir; alınmayanlar sezon sonunda otomatik verilir
--    (035 kuralı). Ödül kaybolmaz.
-- 4) İADE: premium kaldırılır; o sezonun premium yolundan alınan ücretli
--    elmas geri alınır (yetmezse borç, 061) ve pas kozmetikleri envanterden
--    çıkar.
--
-- KULLANICI VERİSİ: yeni ayar sürümü, iki kozmetik, bir taslak ürün. Süren
-- sezon, bakiye, XP, alınmış ödül değişmez. Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) PAS KOZMETİKLERİ (yalnız premium yoldan; mağazada satılmaz)
-- ---------------------------------------------------------------------
insert into item_definitions (slug, kind, category, name, description, max_stack, duration_seconds, cosmetic_slot,
                              overflow_coins, params, sort_order) values
  ('frame_pass_ice', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Buz Kristali',
   'Premium sezon yolunun ilk ödülü.', null, null, 'frame', 0, '{"pass": true}', 110),
  ('frame_pass_gold', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Altın Kupa',
   'Premium sezon yolunun son ödülü.', null, null, 'frame', 0, '{"pass": true}', 111)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------
-- 2) SEZON KURALI SÜRÜM 2 (ücretsiz yol aynı, premium güçsüz)
-- ---------------------------------------------------------------------
insert into economy_config_versions (kind, version, payload, note)
select 'season_rules', 2,
       v1.payload || jsonb_build_object(
         'premium_power_free', true,
         'tiers', (select jsonb_agg(t || jsonb_build_object('premium',
                      case (t ->> 'tier')::int
                        when 1  then '{"type": "item", "slug": "frame_pass_ice", "qty": 1}'::jsonb
                        when 50 then '{"type": "item", "slug": "frame_pass_gold", "qty": 1}'::jsonb
                        when 10 then '{"type": "paid_gems", "amount": 20}'::jsonb
                        when 20 then '{"type": "paid_gems", "amount": 20}'::jsonb
                        when 25 then '{"type": "paid_gems", "amount": 25}'::jsonb
                        when 30 then '{"type": "paid_gems", "amount": 20}'::jsonb
                        when 40 then '{"type": "paid_gems", "amount": 20}'::jsonb
                        else '{"type": "paid_gems", "amount": 5}'::jsonb
                      end) order by (t ->> 'tier')::int)
                   from jsonb_array_elements(v1.payload -> 'tiers') t)),
       '063: premium yol gucsuz (ucretli elmas + pas kozmetigi); ucretsiz yol 035 ile ayni'
from economy_config_versions v1
where v1.kind = 'season_rules' and v1.version = 1
on conflict (kind, version) do nothing;

-- Sezonun premium yolu tamamen güçsüz mü? (yalnız ücretli elmas ve
-- telafisi 0 olan kozmetik)
create or replace function _season_premium_power_free(p_season uuid)
returns boolean
language sql stable as $$
  select exists (select 1 from season_tiers where season_id = p_season and track = 'premium')
     and not exists (
       select 1 from season_tiers st
       where st.season_id = p_season and st.track = 'premium'
         and not (st.reward ->> 'type' = 'paid_gems'
                  or (st.reward ->> 'type' = 'item'
                      and exists (select 1 from item_definitions d
                                  where d.slug = st.reward ->> 'slug' and d.kind = 'cosmetic'
                                    and d.overflow_coins = 0))));
$$;

-- ---------------------------------------------------------------------
-- 3) ÖDÜL VER: yeni tür "paid_gems" (035 _season_grant + bir dal)
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
  when 'paid_gems' then
    -- 063: ücretli elmas (altına çevrilemez, sandık açamaz)
    perform _paid_gem_add(p_user_id, (r ->> 'amount')::int, 'season_reward', v_src, v_key);
    v_sonuc := jsonb_build_object('paid_gems', (r ->> 'amount')::int);
  else
    raise exception 'tier_not_found: Bilinmeyen odul turu.';
  end case;

  v_sonuc := jsonb_build_object('tier', p_tier, 'track', p_track, 'reward', r) || v_sonuc;
  update season_claims set result = v_sonuc
  where user_id = p_user_id and season_id = p_season and tier = p_tier and track = p_track;
  return v_sonuc;
end;
$$;

-- ---------------------------------------------------------------------
-- 4) ÜRÜN (taslak) + satış kuralı
-- ---------------------------------------------------------------------
insert into product_catalog (id, category, google_product_id, apple_product_id, product_type, name, description,
                             contents, status, purchase_limit, eligibility, sort_order)
values ('season_pass_premium', 'SEASON_PASS', 'season_pass_premium', 'season_pass_premium', 'consumable',
        'Premium Sezon Yolu', 'Bu sezonun premium yolu: ücretli elmas ve pas kozmetikleri. Maç gücü vermez.',
        '{"season_premium": true}', 'draft', null, '{}', 3)
on conflict (id) do nothing;

-- Bu oyuncu bu sezonun premium yoluna sahip mi
create or replace function _season_premium_owned(p_user_id uuid, p_season uuid)
returns boolean
language sql stable as $$
  select coalesce((select premium from user_seasons where user_id = p_user_id and season_id = p_season), false);
$$;

-- 061 _product_problem + premium yol kuralları
create or replace function _product_problem(p_user_id uuid, p product_catalog, p_platform text, p_app_version text)
returns text
language plpgsql stable as $$
declare
  s seasons%rowtype;
begin
  if p.id is null then return 'product_not_found'; end if;
  if p.status <> 'active' then return 'product_not_active'; end if;
  if (p.starts_at is not null and p.starts_at > now()) or (p.ends_at is not null and p.ends_at <= now()) then
    return 'product_not_available';
  end if;
  if not (lower(coalesce(p_platform, '')) = any(p.platforms)) then return 'platform_not_supported'; end if;
  if p.contents ? 'season_premium' then
    -- Süren sezon (yalnız okuma: yoksa satış yok)
    select * into s from seasons where starts_at <= now() and ends_at > now() order by number desc limit 1;
    if not found or not economy_flag('economy_v2_enabled') then return 'season_not_active'; end if;
    if not _season_premium_power_free(s.id) then return 'season_not_eligible'; end if;
  end if;
  return coalesce(
    monetization_gate(p_user_id, 'iap_enabled', p_platform, p_app_version),
    monetization_gate(p_user_id, _product_flag(p.category), p_platform, p_app_version),
    case when p.purchase_limit is not null and _purchase_count(p_user_id, p.id) >= p.purchase_limit
         then 'already_owned' end,
    case when p.contents ? 'season_premium' and _season_premium_owned(p_user_id, s.id) then 'already_owned' end,
    (select case when u2.created_at < now() - make_interval(days => (p.eligibility ->> 'max_account_age_days')::int)
                 then 'not_eligible' end
     from users u2 where u2.id = p_user_id and p.eligibility ? 'max_account_age_days'));
end;
$$;

-- ---------------------------------------------------------------------
-- 5) SATIN ALMA: premium yolu aç (061 purchase_grant_verified + bir dal)
-- ---------------------------------------------------------------------
create or replace function purchase_grant_verified(
  p_user_id uuid, p_platform text, p_store_product text, p_store_tx text, p_token_hash text,
  p_environment text, p_state text, p_price_micros bigint default null, p_currency text default null)
returns jsonb
language plpgsql as $$
declare
  p      product_catalog%rowtype;
  t      purchase_transactions%rowtype;
  s      seasons%rowtype;
  v_n    int;
  v_red  text;
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
      perform _purchase_event(t.id, p_platform, p_store_tx, 'cross_account_blocked', false, p_user_id::text);
      raise exception 'purchase_belongs_to_another_account: Bu satin alma baska bir hesaba ait.';
    end if;
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
  if p.purchase_limit is not null and _purchase_count(p_user_id, p.id) > p.purchase_limit then
    v_red := 'limit_exceeded';
  end if;

  -- 063: premium yol. Ödeme SÜREN sezona bağlanır; sezon güçsüz değilse
  -- ya da oyuncu zaten premiumsa ödül verilmez (iade için işaretlenir).
  if v_red is null and t.contents ? 'season_premium' then
    s := _current_season();
    if not _season_premium_power_free(s.id) then
      v_red := 'season_not_eligible';
    elsif _season_premium_owned(p_user_id, s.id) then
      v_red := 'already_owned';
    end if;
  end if;

  if v_red is not null then
    update purchase_transactions set status = 'failed', failure_reason = v_red || '_refund_required' where id = t.id;
    perform _purchase_event(t.id, p_platform, p_store_tx, 'grant_rejected', false, v_red || '_refund_required');
    return jsonb_build_object('purchase_id', t.id, 'status', 'failed', 'reason', v_red);
  end if;

  v_n := coalesce((t.contents ->> 'paid_gems')::int, 0);
  if v_n > 0 then
    perform _paid_gem_add(p_user_id, v_n, 'purchase', t.id::text, 'purchase:' || t.id);
  end if;
  for i in select x ->> 'slug' as slug, coalesce((x ->> 'qty')::int, 1) as qty
           from jsonb_array_elements(coalesce(t.contents -> 'items', '[]'::jsonb)) x loop
    perform grant_item(p_user_id, i.slug, i.qty, 'purchase', t.id::text, 'purchase_item:' || t.id || ':' || i.slug);
  end loop;
  if t.contents ? 'season_premium' then
    insert into user_seasons (user_id, season_id, premium) values (p_user_id, s.id, true)
    on conflict (user_id, season_id) do update set premium = true, updated_at = now();
    update purchase_transactions set contents = contents || jsonb_build_object('season_id', s.id, 'season_number', s.number)
    where id = t.id returning * into t;
  end if;
  update purchase_transactions set status = 'granted', granted_at = now() where id = t.id;
  perform _purchase_event(t.id, p_platform, p_store_tx, 'purchase_granted', true, null);
  perform monetization_event(p_user_id, 'purchase_granted', null, null, jsonb_build_object('product', p.id));
  return jsonb_build_object('purchase_id', t.id, 'status', 'granted', 'contents', t.contents,
                            'paid_gems', (select paid_gems from users where id = p_user_id));
end;
$$;

-- ---------------------------------------------------------------------
-- 6) İADE: premium kaldırılır, premium yoldan alınanlar geri alınır
-- ---------------------------------------------------------------------
create or replace function purchase_refund(p_platform text, p_store_tx text, p_kind text, p_reason text)
returns jsonb
language plpgsql as $$
declare
  t   purchase_transactions%rowtype;
  v_n int;
  v_s uuid;
  i   record;
  c   season_claims%rowtype;
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
    -- 063: premium yol
    v_s := nullif(t.contents ->> 'season_id', '')::uuid;
    if v_s is not null then
      update user_seasons set premium = false, updated_at = now() where user_id = t.user_id and season_id = v_s;
      for c in select * from season_claims where user_id = t.user_id and season_id = v_s and track = 'premium' loop
        if c.reward ->> 'type' = 'paid_gems' then
          perform _paid_gem_add(t.user_id, -((c.reward ->> 'amount')::int), 'purchase_refund', t.id::text,
                                'refund:' || t.id || ':tier:' || c.tier, true);
        elsif c.reward ->> 'type' = 'item' then
          begin
            perform _item_take(t.user_id, c.reward ->> 'slug', coalesce((c.reward ->> 'qty')::int, 1));
            delete from user_equipped where user_id = t.user_id and item_slug = c.reward ->> 'slug';
          exception when others then
            perform _purchase_event(t.id, p_platform, p_store_tx, 'refund_item_missing', false, c.reward ->> 'slug');
          end;
        end if;
      end loop;
    end if;
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

-- ---------------------------------------------------------------------
-- 7) OKUMA: premium yolun güçsüz olup olmadığı istemciye de söylenir
-- ---------------------------------------------------------------------
create or replace function season_premium_status(p_user_id uuid)
returns jsonb
language plpgsql as $$
declare
  s seasons%rowtype;
begin
  if not economy_flag('economy_v2_enabled') then
    return jsonb_build_object('enabled', false);
  end if;
  s := _current_season();
  return jsonb_build_object(
    'enabled', true,
    'season_id', s.id,
    'season_number', s.number,
    'premium', _season_premium_owned(p_user_id, s.id),
    'power_free', _season_premium_power_free(s.id),
    'ends_at', s.ends_at);
end;
$$;
