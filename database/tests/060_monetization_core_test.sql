-- 060: monetizasyon ayarı, kapılar, ödüllü reklam oturumu ve SSV ödülü
-- (geri alınan işlem içinde)
BEGIN;
DO $test$
DECLARE
  a uuid := (select id from users where username = 'dbtest_1');
  b uuid := (select id from users where username = 'dbtest_2');
  v_audit int := (select count(*) from monetization_admin_audit);
  e jsonb;
  s1 uuid; s2 uuid; s3 uuid; s4 uuid; s5 uuid;
  r jsonb;
  v_coins int;
  v_chest uuid; v_chest2 uuid;
  v_ready timestamptz;
  v_mac uuid;
  v_hata text;
  m json;
BEGIN
  -- ---------- VARSAYILAN: HER ŞEY KAPALI ----------
  e := ad_eligibility(a, 'daily_reward', 'android', '1.0.0');
  IF (e ->> 'eligible')::boolean OR e ->> 'reason' <> 'monetization_disabled' THEN
    RAISE EXCEPTION '060: varsayilan kapali olmali: %', e;
  END IF;
  BEGIN
    perform ad_session_create(a, 'daily_reward', 'android', '1.0.0');
    RAISE EXCEPTION '060: kapaliyken oturum acilmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'ad_not_eligible: monetization_disabled%' THEN RAISE; END IF;
  END;
  IF (monetization_client_config(a, 'android', '1.0.0') ->> 'rewarded_ads')::boolean THEN
    RAISE EXCEPTION '060: istemci ayari kapali gostermeli';
  END IF;

  -- ---------- AYAR DOĞRULAMA ----------
  BEGIN
    perform set_monetization_config('{"bilinmeyen": true}', 'test', 'deneme');
    RAISE EXCEPTION '060: bilinmeyen anahtar reddedilmeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'invalid_config:%' THEN RAISE; END IF;
  END;
  BEGIN
    perform set_monetization_config('{"daily_rewarded_ad_limit": 50}', 'test', 'deneme');
    RAISE EXCEPTION '060: aralik disi limit reddedilmeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'invalid_config:%' THEN RAISE; END IF;
  END;

  r := set_monetization_config(jsonb_build_object(
         'monetization_enabled', true, 'rewarded_ads_enabled', true,
         'daily_reward_ads_enabled', true, 'chest_speedup_ads_enabled', true, 'post_match_ads_enabled', true,
         'whitelist', jsonb_build_array(a::text, b::text)), 'dbtest', 'beyaz listede reklam testi');
  IF (select count(*) from monetization_admin_audit) <> v_audit + 1 THEN RAISE EXCEPTION '060: denetim kaydi yok'; END IF;
  IF (r ->> 'version')::int < 2 THEN RAISE EXCEPTION '060: yeni surum eklenmeli'; END IF;

  -- ---------- KAPILAR ----------
  e := ad_eligibility(a, 'daily_reward', 'android', '1.0.0');
  IF e ->> 'reason' <> 'first_session' THEN RAISE EXCEPTION '060: yeni hesapta ilk oturum reklami kapali olmali: %', e; END IF;
  update users set created_at = now() - interval '3 days' where id in (a, b);
  IF ad_eligibility(a, 'daily_reward', 'web', '1.0.0') ->> 'reason' <> 'platform_not_supported' THEN
    RAISE EXCEPTION '060: web desteklenmemeli';
  END IF;
  IF ad_eligibility(a, 'daily_reward', 'android', '0.9') ->> 'reason' <> 'app_version_too_old' THEN
    RAISE EXCEPTION '060: eski surum reddedilmeli';
  END IF;
  perform set_monetization_config('{"whitelist": []}', 'dbtest', 'yuzde testi');
  IF ad_eligibility(a, 'daily_reward', 'android', '1.0.0') ->> 'reason' <> 'not_in_rollout' THEN
    RAISE EXCEPTION '060: yuzde 0 iken listede olmayan kapali olmali';
  END IF;
  perform set_monetization_config('{"rollout_percent": 100}', 'dbtest', 'herkes');
  e := ad_eligibility(a, 'daily_reward', 'android', '1.0.0');
  IF NOT (e ->> 'eligible')::boolean OR (e ->> 'remaining_today')::int <> 2 THEN RAISE EXCEPTION '060: uygun olmali: %', e; END IF;

  -- ---------- GÜNLÜK ÖDÜL: OTURUM + SSV ----------
  v_coins := (select coins from users where id = a);
  s1 := (ad_session_create(a, 'daily_reward', 'android', '1.0.0') ->> 'session_id')::uuid;
  IF (ad_session_create(a, 'daily_reward', 'android', '1.0.0') ->> 'session_id')::uuid <> s1 THEN
    RAISE EXCEPTION '060: cift dokunma ayni rezervasyonu dondurmeli';
  END IF;
  -- İstemci "kazandım" der: ödül YOK, yalnız doğrulama bekleniyor
  perform ad_session_client_event(a, s1, 'earned');
  IF (select coins from users where id = a) <> v_coins THEN RAISE EXCEPTION '060: istemci olayi odul vermemeli'; END IF;
  IF (select status from ad_sessions where id = s1) <> 'verifying' THEN RAISE EXCEPTION '060: verifying olmali'; END IF;
  -- Başka oyuncu adına geri çağrı: ödül yok, oturum yanmaz
  r := ad_ssv_grant('tx-sahte', s1::text, b::text, 1, 'unit', 1);
  IF r ->> 'reason' <> 'user_mismatch' OR (select status from ad_sessions where id = s1) <> 'verifying' THEN
    RAISE EXCEPTION '060: farkli kullanici reddedilmeli: %', r;
  END IF;
  r := ad_ssv_grant('tx-1', s1::text, a::text, 1, 'unit', 1);
  IF r ->> 'outcome' <> 'granted' OR (select coins from users where id = a) <> v_coins + 40 THEN
    RAISE EXCEPTION '060: SSV odulu verilmeli: %', r;
  END IF;
  r := ad_ssv_grant('tx-1', s1::text, a::text, 1, 'unit', 1);
  IF r ->> 'outcome' <> 'duplicate' OR (select coins from users where id = a) <> v_coins + 40 THEN
    RAISE EXCEPTION '060: ayni islem ikinci odul vermemeli';
  END IF;
  r := ad_ssv_grant('tx-2', s1::text, a::text, 1, 'unit', 1);
  IF r ->> 'reason' <> 'session_already_rewarded' THEN RAISE EXCEPTION '060: ayni oturum ikinci kez odullenmemeli'; END IF;
  IF (select count(*) from economy_ledger where idempotency_key = 'ad_reward:' || s1) <> 1 THEN
    RAISE EXCEPTION '060: deftere tek satir';
  END IF;

  -- İptal edilen rezervasyon hakkı geri verir
  s2 := (ad_session_create(a, 'daily_reward', 'android', '1.0.0') ->> 'session_id')::uuid;
  perform ad_session_client_event(a, s2, 'closed');
  IF (ad_eligibility(a, 'daily_reward', 'android', '1.0.0') ->> 'remaining_today')::int <> 1 THEN
    RAISE EXCEPTION '060: kapatilan reklam hak dusurmemeli';
  END IF;

  -- ---------- SANDIK HIZLANDIRMA + KREDİ ----------
  insert into user_chests (user_id, chest_type, rules_version, source_type, source_id, status, location, slot_no,
                           unlock_started_at, unlock_ready_at)
  values (a, 'gold', (select max(version) from economy_config_versions where kind = 'chest_rules'), 'test', 'ad-1',
          'unlocking', 'slot', (select s from generate_series(1, 4) s where s not in
            (select slot_no from user_chests where user_id = a and location = 'slot' and status in ('sealed', 'unlocking')
             and slot_no is not null) limit 1),
          now(), now() + interval '2 hours')
  returning id into v_chest;
  IF (ad_eligibility(a, 'chest_speedup', 'android', '1.0.0', 'yanlis') ->> 'reason') <> 'chest_not_eligible' THEN
    RAISE EXCEPTION '060: gecersiz sandik reddedilmeli';
  END IF;
  s3 := (ad_session_create(a, 'chest_speedup', 'android', '1.0.0', v_chest::text) ->> 'session_id')::uuid;
  -- Reklam sırasında sandık açıldı: ödül kaybolmaz, kredi olur
  update user_chests set status = 'opened', opened_at = now() where id = v_chest;
  r := ad_ssv_grant('tx-3', s3::text, a::text, 1, 'unit', 1);
  IF r ->> 'outcome' <> 'credit' THEN RAISE EXCEPTION '060: sandik bittiyse kredi olmali: %', r; END IF;
  IF jsonb_array_length(ad_status(a, 'android', '1.0.0') -> 'credits') <> 1 THEN RAISE EXCEPTION '060: kredi listede yok'; END IF;
  insert into user_chests (user_id, chest_type, rules_version, source_type, source_id, status, location, slot_no,
                           unlock_started_at, unlock_ready_at)
  values (a, 'silver', (select max(version) from economy_config_versions where kind = 'chest_rules'), 'test', 'ad-2',
          'unlocking', 'slot', (select s from generate_series(1, 4) s where s not in
            (select slot_no from user_chests where user_id = a and location = 'slot' and status in ('sealed', 'unlocking')
             and slot_no is not null) limit 1),
          now(), now() + interval '5 minutes')
  returning id into v_chest2;
  perform ad_session_apply_credit(a, s3, v_chest2);
  v_ready := (select unlock_ready_at from user_chests where id = v_chest2);
  IF v_ready > now() + interval '1 second' THEN RAISE EXCEPTION '060: sure negatife degil, simdiye inmeli (%)', v_ready; END IF;
  IF (select status from ad_sessions where id = s3) <> 'granted' THEN RAISE EXCEPTION '060: kredi kullanilinca granted'; END IF;
  BEGIN
    perform ad_session_apply_credit(a, s3, v_chest2);
    RAISE EXCEPTION '060: kredi ikinci kez kullanilmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'ad_credit_not_found:%' THEN RAISE; END IF;
  END;

  -- ---------- GÜNLÜK TAVAN (3) ----------
  s4 := (ad_session_create(a, 'daily_reward', 'android', '1.0.0') ->> 'session_id')::uuid;
  perform ad_ssv_grant('tx-4', s4::text, a::text, 1, 'unit', 1);
  e := ad_eligibility(a, 'daily_reward', 'android', '1.0.0');
  IF e ->> 'reason' <> 'daily_limit' THEN RAISE EXCEPTION '060: 3 reklamdan sonra gunluk tavan: %', e; END IF;
  -- Süresi dolmuş iptal oturumuna sonradan gelen geri çağrı tavanı aşamaz
  r := ad_ssv_grant('tx-5', s2::text, a::text, 1, 'unit', 1);
  IF r ->> 'reason' <> 'daily_limit' THEN RAISE EXCEPTION '060: gec gelen geri cagri tavani asmamali: %', r; END IF;
  r := ad_ssv_grant('tx-6', 'gecersiz', a::text, 1, 'unit', 1);
  IF r ->> 'reason' <> 'session_not_found' THEN RAISE EXCEPTION '060: bilinmeyen oturum'; END IF;

  -- ---------- AKTİF MAÇTA REKLAM YOK; MAÇ SONU TEKLİFİ ----------
  m := find_match(b, (select id from decks where owner_id = b and is_active limit 1), '{}');
  m := find_match(a, (select id from decks where owner_id = a and is_active limit 1), '{}');
  v_mac := get_active_match_id(b);
  IF v_mac IS NULL THEN RAISE EXCEPTION '060: mac baslamadi: %', m; END IF;
  IF ad_eligibility(b, 'daily_reward', 'android', '1.0.0') ->> 'reason' <> 'in_match' THEN
    RAISE EXCEPTION '060: aktif macta reklam olmamali';
  END IF;
  IF ad_eligibility(b, 'post_match', 'android', '1.0.0', v_mac::text) ->> 'reason' <> 'in_match' THEN
    RAISE EXCEPTION '060: mac bitmeden mac sonu teklifi yok';
  END IF;
  perform surrender_match(b, v_mac);
  e := ad_eligibility(b, 'post_match', 'android', '1.0.0', v_mac::text);
  IF NOT (e ->> 'eligible')::boolean THEN RAISE EXCEPTION '060: mac sonu uygun olmali: %', e; END IF;
  s5 := (ad_session_create(b, 'post_match', 'android', '1.0.0', v_mac::text) ->> 'session_id')::uuid;
  perform ad_ssv_grant('tx-7', s5::text, b::text, 1, 'unit', 1);
  IF ad_eligibility(b, 'post_match', 'android', '1.0.0', v_mac::text) ->> 'reason' <> 'placement_limit' THEN
    RAISE EXCEPTION '060: mac sonu teklifi tekrar edilmemeli';
  END IF;

  -- ---------- ACİL KAPATMA ----------
  perform monetization_kill_switch('dbtest', 'test');
  IF ad_eligibility(b, 'daily_reward', 'android', '1.0.0') ->> 'reason' <> 'monetization_disabled' THEN
    RAISE EXCEPTION '060: acil kapatma calismali';
  END IF;
  IF (select status from ad_sessions where id = s5) <> 'granted' THEN RAISE EXCEPTION '060: kapatma verilen odulu silmemeli'; END IF;

  -- ---------- ÜCRETLİ ELMAS: mevcut bakiye değişmedi ----------
  IF (select paid_gems from users where id = a) <> 0 THEN RAISE EXCEPTION '060: ucretli elmas 0 baslamali'; END IF;

  RAISE NOTICE '060 OK: kapilar, rezervasyon, SSV tekilligi, kredi, tavan, aktif mac, acil kapatma';
END;
$test$;
ROLLBACK;
