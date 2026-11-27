-- 063: güçsüz premium sezon yolu — kural sürümü, satış kapısı, geriye dönük ödül, iade (geri alınan işlem)
BEGIN;
DO $test$
DECLARE
  a uuid := (select id from users where username = 'dbtest_1');
  b uuid := (select id from users where username = 'dbtest_2');
  k jsonb;
  s seasons%rowtype;
  r jsonb;
  c jsonb;
  v_hata text;
  v_paid int;
  v_coins int;
BEGIN
  -- ---------- KURAL SÜRÜM 2 ----------
  k := economy_config('season_rules');
  IF economy_config_version('season_rules') <> 2 OR NOT (k ->> 'premium_power_free')::boolean THEN
    RAISE EXCEPTION '063: sezon kurali surum 2 olmali';
  END IF;
  -- Ücretsiz yol 035 ile birebir aynı
  IF (select jsonb_agg(t -> 'free' order by (t ->> 'tier')::int) from jsonb_array_elements(k -> 'tiers') t)
     <> (select jsonb_agg(t -> 'free' order by (t ->> 'tier')::int)
         from economy_config_versions v, jsonb_array_elements(v.payload -> 'tiers') t
         where v.kind = 'season_rules' and v.version = 1) THEN
    RAISE EXCEPTION '063: ucretsiz yol degismemeli';
  END IF;
  -- Premium yolda güç yok
  IF exists (select 1 from jsonb_array_elements(k -> 'tiers') t
             where t -> 'premium' ->> 'type' not in ('paid_gems', 'item')
                or (t -> 'premium' ->> 'type' = 'item'
                    and not exists (select 1 from item_definitions d where d.slug = t -> 'premium' ->> 'slug'
                                    and d.kind = 'cosmetic' and d.overflow_coins = 0))) THEN
    RAISE EXCEPTION '063: premium yolda guc veren odul olmamali';
  END IF;

  -- Ekonomi açık, yeni sezon (v2 tablo)
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 995, '{"economy_v2_enabled": true}', 'test');
  update seasons set ends_at = now() - interval '1 second', starts_at = least(starts_at, now() - interval '2 seconds')
  where ends_at > now();
  s := _current_season();
  IF NOT _season_premium_power_free(s.id) THEN RAISE EXCEPTION '063: yeni sezonun premium yolu gucsuz olmali'; END IF;

  -- ---------- KATALOG KAPISI ----------
  update product_catalog set status = 'active' where id = 'season_pass_premium';
  perform set_monetization_config(jsonb_build_object('monetization_enabled', true, 'iap_enabled', true,
    'premium_season_pass_enabled', true, 'whitelist', jsonb_build_array(a::text, b::text)), 'dbtest', 'premium yol testi');
  c := product_catalog_for(a, 'android', '1.0.0');
  IF NOT exists (select 1 from jsonb_array_elements(c -> 'products') x where x ->> 'id' = 'season_pass_premium') THEN
    RAISE EXCEPTION '063: premium yol katalogda gorunmeli: %', c;
  END IF;

  -- ---------- GERİYE DÖNÜK: 12. kademedeyken satın al ----------
  perform dev_season_add_xp(a, 12 * (k ->> 'xp_per_tier')::int);
  BEGIN
    perform claim_season_reward(a, 1, 'premium');
    RAISE EXCEPTION '063: satin almadan premium alinmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'premium_required:%' THEN RAISE; END IF;
  END;
  v_paid := (select paid_gems from users where id = a);
  v_coins := (select coins from users where id = a);
  r := purchase_grant_verified(a, 'android', 'season_pass_premium', 'GPA.SP1', 'hsp1', 'sandbox', 'purchased');
  IF r ->> 'status' <> 'granted' OR NOT _season_premium_owned(a, s.id) THEN
    RAISE EXCEPTION '063: premium acilmali: %', r;
  END IF;
  IF (r -> 'contents' ->> 'season_id')::uuid <> s.id THEN RAISE EXCEPTION '063: odeme surem sezona baglanmali'; END IF;

  r := claim_all_season_rewards(a);
  -- 12 ücretsiz + 12 premium
  IF (r ->> 'count')::int <> 24 THEN RAISE EXCEPTION '063: 24 odul (geriye donuk) alinmali: %', r ->> 'count'; END IF;
  -- Premium: 1 çerçeve + 10. kademe 20 + 10 x 5 = 70 ücretli elmas
  IF (select paid_gems from users where id = a) <> v_paid + 70 THEN
    RAISE EXCEPTION '063: premium yoldan 70 ucretli elmas beklenir, gelen %', (select paid_gems from users where id = a) - v_paid;
  END IF;
  IF _item_qty(a, 'frame_pass_ice') <> 1 THEN RAISE EXCEPTION '063: pas cercevesi verilmeli'; END IF;
  -- Premium yol altın vermez: altın farkı yalnız ücretsiz yoldan
  IF (select coalesce(sum(coins_delta), 0) from economy_ledger where user_id = a and entry_type = 'season_reward'
      and items ->> 'track' = 'premium') <> 0 THEN
    RAISE EXCEPTION '063: premium yol altin vermemeli';
  END IF;

  -- Aynı sezonda ikinci alım: katalogda sahip, doğrulansa da ödül yok
  IF (select x ->> 'problem' from jsonb_array_elements(product_catalog_for(a, 'android', '1.0.0') -> 'products') x
      where x ->> 'id' = 'season_pass_premium') <> 'already_owned' THEN
    RAISE EXCEPTION '063: ayni sezonda sahip gorunmeli';
  END IF;
  r := purchase_grant_verified(a, 'android', 'season_pass_premium', 'GPA.SP2', 'hsp2', 'sandbox', 'purchased');
  IF r ->> 'status' <> 'failed' OR r ->> 'reason' <> 'already_owned' THEN
    RAISE EXCEPTION '063: ikinci alim reddedilmeli: %', r;
  END IF;

  -- ---------- İADE ----------
  perform equip_cosmetic(a, 'frame_pass_ice');
  r := purchase_refund('android', 'GPA.SP1', 'refunded', 'test');
  IF _season_premium_owned(a, s.id) THEN RAISE EXCEPTION '063: iadede premium kalkmali'; END IF;
  IF (select paid_gems from users where id = a) <> v_paid OR (select paid_gems_debt from users where id = a) <> 0 THEN
    RAISE EXCEPTION '063: premium yoldan alinan 70 elmas geri alinmali';
  END IF;
  IF _item_qty(a, 'frame_pass_ice') <> 0
     OR exists (select 1 from user_equipped where user_id = a and item_slug = 'frame_pass_ice') THEN
    RAISE EXCEPTION '063: iadede pas cercevesi envanterden ve giyilenden cikmali';
  END IF;
  -- Ücretsiz yol ödülleri iadeden etkilenmez
  IF (select count(*) from season_claims where user_id = a and season_id = s.id and track = 'free') <> 12 THEN
    RAISE EXCEPTION '063: ucretsiz yol odulleri kalmali';
  END IF;

  -- ---------- GÜÇLÜ YOLLU SEZONDA SATIŞ YOK ----------
  update season_tiers set reward = '{"type": "chest", "chest_type": "gold"}' where season_id = s.id and track = 'premium' and tier = 5;
  IF (select x ->> 'id' from jsonb_array_elements(product_catalog_for(b, 'android', '1.0.0') -> 'products') x
      where x ->> 'id' = 'season_pass_premium') IS NOT NULL THEN
    RAISE EXCEPTION '063: guclu premium yolda urun gorunmemeli';
  END IF;
  r := purchase_grant_verified(b, 'android', 'season_pass_premium', 'GPA.SP3', 'hsp3', 'sandbox', 'purchased');
  IF r ->> 'status' <> 'failed' OR r ->> 'reason' <> 'season_not_eligible' OR _season_premium_owned(b, s.id) THEN
    RAISE EXCEPTION '063: guclu yolda premium verilmemeli: %', r;
  END IF;
END
$test$;
ROLLBACK;
