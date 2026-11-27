-- 064: yönetici rolleri, denetim, gerçek para için owner, deney ataması, metrik, saklama (geri alınan işlem)
BEGIN;
DO $test$
DECLARE
  a uuid := (select id from users where username = 'dbtest_1');   -- operator
  b uuid := (select id from users where username = 'dbtest_2');   -- rolsüz, sonra viewer
  r jsonb;
  v_hata text;
  v_audit int;
  v1 text;
  i int;
  n_a int := 0;
BEGIN
  -- ---------- ROLSÜZ: her şey reddedilir ----------
  BEGIN
    perform admin_monetization_overview(b);
    RAISE EXCEPTION '064: rolsuz okuyamamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'admin_forbidden:%' THEN RAISE; END IF;
  END;

  insert into admin_users (user_id, role, granted_by) values (a, 'operator', 'dbtest'), (b, 'viewer', 'dbtest');

  -- ---------- VIEWER: okur, değiştiremez ----------
  r := admin_monetization_overview(b);
  IF r ->> 'role' <> 'viewer' OR r -> 'config' IS NULL THEN RAISE EXCEPTION '064: viewer genel bakis: %', r; END IF;
  BEGIN
    perform admin_kill_switch(b, 'deneme');
    RAISE EXCEPTION '064: viewer acil kapatma yapamamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'admin_forbidden:%' THEN RAISE; END IF;
  END;

  -- ---------- OPERATOR: ayar + denetim; gerçek para owner ister ----------
  v_audit := (select count(*) from monetization_admin_audit);
  r := admin_set_monetization_config(a, '{"rewarded_ads_enabled": true}', 'reklam acilisi');
  IF NOT (monetization_config() ->> 'rewarded_ads_enabled')::boolean THEN RAISE EXCEPTION '064: ayar uygulanmali'; END IF;
  IF (select actor from monetization_admin_audit order by id desc limit 1) <> 'admin:dbtest_1' THEN
    RAISE EXCEPTION '064: denetimde aktor admin:kullanici olmali';
  END IF;
  BEGIN
    perform admin_set_monetization_config(a, '{"iap_enabled": true}', 'para acma');
    RAISE EXCEPTION '064: operator gercek parayi acamamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'admin_forbidden:%' THEN RAISE; END IF;
  END;
  -- Kapatmak serbest (operator)
  perform admin_set_monetization_config(a, '{"iap_enabled": false}', 'para kapali');
  BEGIN
    perform admin_set_product_status(a, 'gems_starter_100', 'active', 'yayina al');
    RAISE EXCEPTION '064: operator ucretli urunu yayina alamamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'admin_forbidden:%' THEN RAISE; END IF;
  END;
  -- Gerekçesiz değişiklik yok
  BEGIN
    perform admin_set_product_status(a, 'gems_starter_100', 'paused', '');
    RAISE EXCEPTION '064: gerekcesiz degisiklik reddedilmeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'invalid_reason:%' THEN RAISE; END IF;
  END;

  -- OWNER
  update admin_users set role = 'owner' where user_id = a;
  perform admin_set_product_status(a, 'gems_starter_100', 'active', 'yayina al');
  IF (select status from product_catalog where id = 'gems_starter_100') <> 'active' THEN
    RAISE EXCEPTION '064: owner yayina alabilmeli';
  END IF;
  -- Rol geri alınınca yetki biter
  update admin_users set revoked_at = now() where user_id = a;
  BEGIN
    perform admin_monetization_overview(a);
    RAISE EXCEPTION '064: geri alinan rol okuyamamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'admin_forbidden:%' THEN RAISE; END IF;
  END;
  update admin_users set revoked_at = null, role = 'operator' where user_id = a;

  -- Kozmetik teklif: fiyat değişir, bilinmeyen alan reddedilir
  r := admin_update_cosmetic_offer(a, 'offer_frame_neon', '{"price_gems": 99, "featured": false}', 'fiyat testi');
  IF (select price_gems from cosmetic_offers where id = 'offer_frame_neon') <> 99 THEN RAISE EXCEPTION '064: fiyat degismeli'; END IF;
  BEGIN
    perform admin_update_cosmetic_offer(a, 'offer_frame_neon', '{"item_slug": "chest_key"}', 'kotu alan');
    RAISE EXCEPTION '064: bilinmeyen alan reddedilmeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'invalid_offer:%' THEN RAISE; END IF;
  END;

  -- Acil kapatma
  perform admin_set_monetization_config(a, '{"monetization_enabled": true}', 'acik');
  perform admin_kill_switch(a, 'test');
  IF (monetization_config() ->> 'monetization_enabled')::boolean THEN RAISE EXCEPTION '064: acil kapatma calismali'; END IF;
  -- 6 basarili degisiklik (reklam, iap kapat, urun, teklif, acik, acil kapatma);
  -- reddedilenler denetime yazilmaz (islem geri alinir)
  IF (select count(*) from monetization_admin_audit) - v_audit <> 6 THEN
    RAISE EXCEPTION '064: her degisiklik denetime yazilmali (%)', (select count(*) from monetization_admin_audit) - v_audit;
  END IF;

  -- ---------- DENEY ----------
  BEGIN
    perform admin_create_experiment(a, 'kotu_deney', '', '[{"name": "a", "weight": 60}, {"name": "b", "weight": 30}]', 'toplam 90');
    RAISE EXCEPTION '064: toplami 100 olmayan deney reddedilmeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'invalid_experiment:%' THEN RAISE; END IF;
  END;
  perform admin_create_experiment(a, 'reklam_metni', 'gunluk odul hapi metni',
    '[{"name": "control", "weight": 50}, {"name": "b", "weight": 50}]', 'metin denemesi');
  IF experiment_variant(a, 'reklam_metni') IS NOT NULL THEN RAISE EXCEPTION '064: taslak deneyde grup olmamali'; END IF;
  perform admin_set_experiment_status(a, 'reklam_metni', 'running', 'basla');
  v1 := experiment_variant(a, 'reklam_metni');
  IF v1 NOT IN ('control', 'b') THEN RAISE EXCEPTION '064: grup atanmali'; END IF;
  -- Kalıcı: ağırlık değişse de aynı
  update monetization_experiments set variants = '[{"name": "control", "weight": 0}, {"name": "b", "weight": 100}]'
  where key = 'reklam_metni';
  IF experiment_variant(a, 'reklam_metni') <> v1 THEN RAISE EXCEPTION '064: atama kalici olmali'; END IF;
  -- Dağılım: 200 sanal oyuncuda iki grup da dolu (deterministik dilim)
  update monetization_experiments set variants = '[{"name": "control", "weight": 50}, {"name": "b", "weight": 50}]'
  where key = 'reklam_metni';
  FOR i IN 1..200 LOOP
    IF (select case when monetization_bucket(gen_random_uuid(), 'experiment:reklam_metni') < 50 then 1 else 0 end) = 1 THEN
      n_a := n_a + 1;
    END IF;
  END LOOP;
  IF n_a < 60 OR n_a > 140 THEN RAISE EXCEPTION '064: dagilim dengesiz: % / 200', n_a; END IF;
  -- Durmuş deney yeniden başlamaz; durunca grup dönmez
  perform admin_set_experiment_status(a, 'reklam_metni', 'stopped', 'bitti');
  IF experiment_variant(a, 'reklam_metni') IS NOT NULL THEN RAISE EXCEPTION '064: durmus deneyde grup donmemeli'; END IF;
  BEGIN
    perform admin_set_experiment_status(a, 'reklam_metni', 'running', 'tekrar');
    RAISE EXCEPTION '064: durmus deney yeniden baslamamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'invalid_status:%' THEN RAISE; END IF;
  END;
  r := admin_experiment_report(b, 'reklam_metni');
  IF jsonb_array_length(r -> 'variants') <> 1 THEN RAISE EXCEPTION '064: rapor: %', r; END IF;

  -- İstemci ayarında deneyler alanı var
  IF NOT (monetization_client_config(a, 'android', '1.0.0') ? 'experiments') THEN
    RAISE EXCEPTION '064: istemci ayarinda experiments olmali';
  END IF;

  -- ---------- METRİK ----------
  r := admin_monetization_metrics(b, 7);
  IF (r ->> 'days')::int <> 7 OR NOT (r ? 'purchases') OR NOT (r ? 'paid_gems_in_circulation') THEN
    RAISE EXCEPTION '064: metrik bicimi: %', r;
  END IF;

  -- ---------- SAKLAMA ----------
  insert into monetization_events (user_id, event, created_at) values (a, 'eski_olay', now() - interval '200 days'),
                                                                     (a, 'yeni_olay', now());
  r := purge_monetization_events();
  IF exists (select 1 from monetization_events where event = 'eski_olay')
     OR NOT exists (select 1 from monetization_events where event = 'yeni_olay') THEN
    RAISE EXCEPTION '064: yalniz suresi dolan olay silinmeli: %', r;
  END IF;
  BEGIN
    perform purge_monetization_events(1, 1, 1);
    RAISE EXCEPTION '064: 30 gunden kisa saklama reddedilmeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'invalid_retention:%' THEN RAISE; END IF;
  END;
END
$test$;
ROLLBACK;
