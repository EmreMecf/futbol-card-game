-- 061: satın alma kaydı, ücretli elmas, iade/borç, katalog kapıları (geri alınan işlem)
BEGIN;
DO $test$
DECLARE
  a uuid := (select id from users where username = 'dbtest_1');
  b uuid := (select id from users where username = 'dbtest_2');
  v_free int := (select gems from users where username = 'dbtest_1');
  r jsonb;
  c jsonb;
  v_hata text;
BEGIN
  -- ---------- KATALOG: varsayılan kapalı, ürünler taslak ----------
  c := product_catalog_for(a, 'android', '1.0.0');
  IF (c ->> 'enabled')::boolean OR jsonb_array_length(c -> 'products') <> 0 THEN
    RAISE EXCEPTION '061: varsayilan katalog kapali ve bos olmali: %', c;
  END IF;

  -- ---------- DOĞRULANMIŞ ÖDEME: bayrak kapalı olsa da hak verilir ----------
  r := purchase_grant_verified(a, 'android', 'gems_popular_300', 'GPA.1', 'h1', 'sandbox', 'purchased', 79990000, 'TRY');
  IF r ->> 'status' <> 'granted' OR (select paid_gems from users where id = a) <> 300 THEN
    RAISE EXCEPTION '061: dogrulanan odeme verilmeli: %', r;
  END IF;
  IF (select currency from gem_ledger where idempotency_key = 'purchase:' || (r ->> 'purchase_id')) <> 'paid' THEN
    RAISE EXCEPTION '061: defter satiri ucretli olmali';
  END IF;
  IF (select gems from users where id = a) <> v_free THEN RAISE EXCEPTION '061: ucretsiz elmas degismemeli'; END IF;

  -- Tekrar: ikinci kez verilmez
  r := purchase_grant_verified(a, 'android', 'gems_popular_300', 'GPA.1', 'h1', 'sandbox', 'purchased');
  IF NOT coalesce((r ->> 'replay')::boolean, false) OR (select paid_gems from users where id = a) <> 300 THEN
    RAISE EXCEPTION '061: ayni islem ikinci kez verilmemeli';
  END IF;

  -- Başka hesap: aynı işlem ya da aynı jeton kullanılamaz
  BEGIN
    perform purchase_grant_verified(b, 'android', 'gems_popular_300', 'GPA.1', 'h1', 'sandbox', 'purchased');
    RAISE EXCEPTION '061: baska hesapta kullanilmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'purchase_belongs_to_another_account:%' THEN RAISE; END IF;
  END;
  BEGIN
    perform purchase_grant_verified(b, 'android', 'gems_popular_300', 'GPA.999', 'h1', 'sandbox', 'purchased');
    RAISE EXCEPTION '061: ayni jeton baska islemle kullanilmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'purchase_belongs_to_another_account:%' THEN RAISE; END IF;
  END;
  IF (select paid_gems from users where id = b) <> 0 THEN RAISE EXCEPTION '061: B elmas almamali'; END IF;

  -- ---------- BEKLEYEN ÖDEME ----------
  r := purchase_grant_verified(a, 'ios', 'gems_starter_100', '2000001', null, 'sandbox', 'pending');
  IF r ->> 'status' <> 'pending' OR (select paid_gems from users where id = a) <> 300 THEN
    RAISE EXCEPTION '061: bekleyen odeme odul vermemeli';
  END IF;
  r := purchase_grant_verified(a, 'ios', 'gems_starter_100', '2000001', null, 'sandbox', 'purchased');
  IF r ->> 'status' <> 'granted' OR (select paid_gems from users where id = a) <> 400 THEN
    RAISE EXCEPTION '061: tamamlanan bekleyen odeme verilmeli: %', r;
  END IF;

  -- Google bekleyen ödeme sipariş kimliksiz gelir, sonra gerçek kimlikle tamamlanır
  r := purchase_grant_verified(a, 'android', 'gems_starter_100', 'pending:abc', 'hp', 'sandbox', 'pending');
  r := purchase_grant_verified(a, 'android', 'gems_starter_100', 'GPA.P1', 'hp', 'sandbox', 'purchased');
  IF r ->> 'status' <> 'granted' OR (select paid_gems from users where id = a) <> 500
     OR NOT exists (select 1 from purchase_transactions where store_transaction_id = 'GPA.P1') THEN
    RAISE EXCEPTION '061: bekleyen Google odemesi gercek siparis kimligine gecmeli: %', r;
  END IF;
  perform purchase_refund('android', 'GPA.P1', 'refunded', 'test');

  -- ---------- İADE + BORÇ ----------
  r := purchase_refund('android', 'GPA.1', 'refunded', 'test iade');
  IF (select paid_gems from users where id = a) <> 100 THEN RAISE EXCEPTION '061: iade geri almali'; END IF;
  r := purchase_refund('android', 'GPA.1', 'refunded', 'test iade');
  IF NOT coalesce((r ->> 'replay')::boolean, false) OR (select paid_gems from users where id = a) <> 100 THEN
    RAISE EXCEPTION '061: iade ikinci kez islenmemeli';
  END IF;
  update users set paid_gems = 30 where id = a;   -- harcanmış gibi
  r := purchase_refund('ios', '2000001', 'revoked', 'aile paylasimi geri alindi');
  IF (select paid_gems from users where id = a) <> 0 OR (select paid_gems_debt from users where id = a) <> 70 THEN
    RAISE EXCEPTION '061: yetmeyen kisim borca yazilmali: %', r;
  END IF;
  r := purchase_grant_verified(a, 'android', 'gems_popular_300', 'GPA.3', 'h3', 'sandbox', 'purchased');
  IF (select paid_gems from users where id = a) <> 230 OR (select paid_gems_debt from users where id = a) <> 0 THEN
    RAISE EXCEPTION '061: yeni satin alma once borcu kapatmali';
  END IF;
  IF (purchase_refund('android', 'BILINMEYEN', 'refunded', 'x') ->> 'status') <> 'unknown' THEN
    RAISE EXCEPTION '061: bilinmeyen iade';
  END IF;

  -- ---------- ÜCRETLİ ELMAS GÜÇ SATMAZ ----------
  update users set gems = 0 where id = a;
  BEGIN
    perform buy_coins_with_gems(a, 'gold_small', 'k-ucretli');
    RAISE EXCEPTION '061: ucretli elmas altina cevrilmemeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'not_enough_gems:%' THEN RAISE; END IF;
  END;
  BEGIN
    insert into product_catalog (id, category, product_type, name, contents)
    values ('kotu_paket', 'EVENT_OFFER', 'consumable', 'Altin', '{"coins": 1000}');
    RAISE EXCEPTION '061: guc veren icerik reddedilmeli';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    perform purchase_grant_verified(a, 'android', 'yok_boyle', 'GPA.4', 'h4', 'sandbox', 'purchased');
    RAISE EXCEPTION '061: bilinmeyen urun';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'product_not_found:%' THEN RAISE; END IF;
  END;

  -- ---------- KATALOG KAPILARI + TEK SEFERLİK ÜRÜN ----------
  update product_catalog set status = 'active';
  update users set created_at = now() - interval '2 days' where id in (a, b);
  perform set_monetization_config(jsonb_build_object('monetization_enabled', true, 'iap_enabled', true,
    'gem_packs_enabled', true, 'whitelist', jsonb_build_array(a::text)), 'dbtest', 'katalog testi');
  c := product_catalog_for(a, 'android', '1.0.0');
  IF NOT (c ->> 'enabled')::boolean OR jsonb_array_length(c -> 'products') <> 3 THEN
    RAISE EXCEPTION '061: yalniz elmas paketleri gorunmeli (baslangic bayragi kapali): %', c;
  END IF;
  IF jsonb_array_length(product_catalog_for(b, 'android', '1.0.0') -> 'products') <> 0 THEN
    RAISE EXCEPTION '061: beyaz listede olmayan gormemeli';
  END IF;
  IF jsonb_array_length(product_catalog_for(a, 'web', '1.0.0') -> 'products') <> 0 THEN
    RAISE EXCEPTION '061: web satis yok';
  END IF;
  perform set_monetization_config('{"starter_pack_enabled": true}', 'dbtest', 'baslangic');
  c := product_catalog_for(a, 'android', '1.0.0');
  IF NOT (c -> 'products') @> '[{"id": "starter_pack_1", "problem": null}]'::jsonb THEN
    RAISE EXCEPTION '061: baslangic paketi gorunmeli: %', c;
  END IF;
  perform purchase_grant_verified(a, 'android', 'starter_pack_1', 'GPA.S1', 'hs1', 'sandbox', 'purchased');
  c := product_catalog_for(a, 'android', '1.0.0');
  IF NOT (c -> 'products') @> '[{"id": "starter_pack_1", "problem": "already_owned"}]'::jsonb THEN
    RAISE EXCEPTION '061: alinmis paket sahip olunan gorunmeli: %', c;
  END IF;
  r := purchase_grant_verified(a, 'android', 'starter_pack_1', 'GPA.S2', 'hs2', 'sandbox', 'purchased');
  IF r ->> 'status' <> 'failed' THEN RAISE EXCEPTION '061: tek seferlik paket ikinci kez verilmemeli: %', r; END IF;
  -- Hesap yaşı: 7 günden eski hesaba başlangıç paketi yok
  update users set created_at = now() - interval '30 days' where id = b;
  perform set_monetization_config(jsonb_build_object('whitelist', jsonb_build_array(a::text, b::text)), 'dbtest', 'hesap yasi testi');
  IF (select count(*) from jsonb_array_elements(product_catalog_for(b, 'android', '1.0.0') -> 'products') x
      where x ->> 'id' = 'starter_pack_1') <> 0 THEN
    RAISE EXCEPTION '061: eski hesaba baslangic paketi gosterilmemeli';
  END IF;

  IF jsonb_array_length(purchase_history(a)) < 4 THEN RAISE EXCEPTION '061: gecmis eksik'; END IF;
  RAISE NOTICE '061 OK: dogrulanmis odul, tekillik, capraz hesap, bekleyen, iade/borc, guc yasagi, katalog';
END;
$test$;
ROLLBACK;
