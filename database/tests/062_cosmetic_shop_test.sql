-- 062: kozmetik mağaza (kapı, ücretsiz-önce harcama, tekrar, sahiplik), başlangıç paketi (geri alınan işlem)
BEGIN;
DO $test$
DECLARE
  a uuid := (select id from users where username = 'dbtest_1');
  b uuid := (select id from users where username = 'dbtest_2');
  r jsonb;
  c jsonb;
  v_hata text;
  v_coins int;
BEGIN
  -- ---------- VARSAYILAN KAPALI ----------
  c := cosmetic_shop(a, 'android', '1.0.0');
  IF (c ->> 'enabled')::boolean THEN RAISE EXCEPTION '062: magaza varsayilan kapali olmali: %', c; END IF;
  BEGIN
    perform buy_cosmetic(a, 'offer_frame_neon', 'android', '1.0.0', 'istek-0001');
    RAISE EXCEPTION '062: kapaliyken satilmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'shop_disabled:%' THEN RAISE; END IF;
  END;

  -- Kozmetik dışı item teklif olamaz
  BEGIN
    insert into cosmetic_offers (id, item_slug, price_gems) values ('offer_bad', 'chest_key', 10);
    RAISE EXCEPTION '062: kozmetik disi teklif reddedilmeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'invalid_offer:%' THEN RAISE; END IF;
  END;

  -- ---------- AÇ (yalnız A beyaz listede) ----------
  perform set_monetization_config(jsonb_build_object('monetization_enabled', true, 'cosmetic_shop_enabled', true,
    'whitelist', jsonb_build_array(a::text)), 'dbtest', 'kozmetik testi');
  c := cosmetic_shop(a, 'android', '1.0.0');
  IF NOT (c ->> 'enabled')::boolean OR jsonb_array_length(c -> 'offers') <> 4 THEN
    RAISE EXCEPTION '062: A icin 4 teklif acik olmali: %', c;
  END IF;
  IF (cosmetic_shop(b, 'android', '1.0.0') ->> 'enabled')::boolean THEN
    RAISE EXCEPTION '062: B (yuzde 0, listede degil) kapali gormeli';
  END IF;
  IF (cosmetic_shop(a, 'web', '1.0.0') ->> 'enabled')::boolean THEN
    RAISE EXCEPTION '062: web platformu kapali olmali';
  END IF;

  -- ---------- YETERSİZ ELMAS ----------
  update users set gems = 50, paid_gems = 0, paid_gems_debt = 0 where id = a;
  BEGIN
    perform buy_cosmetic(a, 'offer_frame_neon', 'android', '1.0.0', 'istek-0002');
    RAISE EXCEPTION '062: yetersiz elmasla satilmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'not_enough_gems:%' THEN RAISE; END IF;
  END;

  -- ---------- ÖNCE ÜCRETSİZ, SONRA ÜCRETLİ ----------
  update users set paid_gems = 100 where id = a;
  v_coins := (select coins from users where id = a);
  r := buy_cosmetic(a, 'offer_frame_neon', 'android', '1.0.0', 'istek-0003');
  IF (r ->> 'free_spent')::int <> 50 OR (r ->> 'paid_spent')::int <> 70
     OR (select gems from users where id = a) <> 0 OR (select paid_gems from users where id = a) <> 30 THEN
    RAISE EXCEPTION '062: once ucretsiz (50) sonra ucretli (70) harcanmali: %', r;
  END IF;
  IF _item_qty(a, 'frame_neon') <> 1 THEN RAISE EXCEPTION '062: kozmetik verilmeli'; END IF;
  IF (select coins from users where id = a) <> v_coins THEN RAISE EXCEPTION '062: altin degismemeli'; END IF;
  IF (select count(*) from gem_ledger where idempotency_key like 'cosmetic:' || (r ->> 'purchase_id') || ':%') <> 2 THEN
    RAISE EXCEPTION '062: iki defter satiri (ucretsiz + ucretli) olmali';
  END IF;
  IF (select currency from gem_ledger where idempotency_key = 'cosmetic:' || (r ->> 'purchase_id') || ':paid') <> 'paid' THEN
    RAISE EXCEPTION '062: ucretli satir ucretli para turunde olmali';
  END IF;

  -- Tekrar (aynı anahtar): ikinci kez harcanmaz
  r := buy_cosmetic(a, 'offer_frame_neon', 'android', '1.0.0', 'istek-0003');
  IF NOT coalesce((r ->> 'replay')::boolean, false) OR (select paid_gems from users where id = a) <> 30 THEN
    RAISE EXCEPTION '062: ayni istek ikinci kez harcamamali: %', r;
  END IF;

  -- Sahip olunan ikinci kez alınamaz (yeni anahtarla da)
  update users set gems = 500 where id = a;
  BEGIN
    perform buy_cosmetic(a, 'offer_frame_neon', 'android', '1.0.0', 'istek-0004');
    RAISE EXCEPTION '062: sahip olunan tekrar satilmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'already_owned:%' THEN RAISE; END IF;
  END;
  IF NOT ((select x from jsonb_array_elements(cosmetic_shop(a, 'android', '1.0.0') -> 'offers') x
           where x ->> 'id' = 'offer_frame_neon') ->> 'owned')::boolean THEN
    RAISE EXCEPTION '062: listede sahip olundu gorunmeli';
  END IF;

  -- Yalnız ücretsiz elmasla
  r := buy_cosmetic(a, 'offer_frame_emerald', 'android', '1.0.0', 'istek-0005');
  IF (r ->> 'paid_spent')::int <> 0 OR (select gems from users where id = a) <> 410 THEN
    RAISE EXCEPTION '062: yeterli ucretsiz elmas varken ucretli harcanmamali: %', r;
  END IF;

  -- Giyilebilir
  perform equip_cosmetic(a, 'frame_emerald');
  IF NOT exists (select 1 from user_equipped where user_id = a and slot = 'frame' and item_slug = 'frame_emerald') THEN
    RAISE EXCEPTION '062: alinan cerceve giyilebilmeli';
  END IF;

  -- Duraklatılan teklif satılmaz
  update cosmetic_offers set status = 'paused' where id = 'offer_frame_crimson';
  BEGIN
    perform buy_cosmetic(a, 'offer_frame_crimson', 'android', '1.0.0', 'istek-0006');
    RAISE EXCEPTION '062: duraklatilan teklif satilmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'offer_not_available:%' THEN RAISE; END IF;
  END;

  -- Mağazaya özel kozmetik tekrar gelse altın vermez (elmas → altın yolu kapalı)
  v_coins := (select coins from users where id = a);
  perform grant_item(a, 'frame_neon', 1, 'test', 'x', 'tekrar-neon');
  IF (select coins from users where id = a) <> v_coins THEN
    RAISE EXCEPTION '062: magaza kozmetigi tekrarinda altin verilmemeli';
  END IF;

  -- ---------- BAŞLANGIÇ PAKETİ ----------
  c := (select contents from product_catalog where id = 'starter_pack_1');
  IF (c ->> 'paid_gems')::int <> 50 OR c -> 'items' -> 0 ->> 'slug' <> 'frame_starter' THEN
    RAISE EXCEPTION '062: baslangic paketi icerigi: %', c;
  END IF;
  IF exists (select 1 from cosmetic_offers where item_slug = 'frame_starter') THEN
    RAISE EXCEPTION '062: caylak cercevesi elmasla satilmamali';
  END IF;
  r := purchase_grant_verified(b, 'android', 'starter_pack_1', 'GPA.S1', 'hs1', 'sandbox', 'purchased');
  IF r ->> 'status' <> 'granted' OR _item_qty(b, 'frame_starter') <> 1 THEN
    RAISE EXCEPTION '062: baslangic paketi cerceveyi vermeli: %', r;
  END IF;
END
$test$;
ROLLBACK;
