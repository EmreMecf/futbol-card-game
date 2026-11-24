-- 056: elmas, arkadaşlık, açık profil, rakip kadrosu (geri alınan işlem içinde)
BEGIN;
DO $test$
DECLARE
  a uuid := (select id from users where username = 'dbtest_1');
  b uuid := (select id from users where username = 'dbtest_2');
  v_chest uuid;
  v_cost int;
  v_sonuc jsonb;
  v_profil jsonb;
  v_liste jsonb;
  v_gems int;
  v_coins int;
  v_hata text;
BEGIN
  -- ---------------- ELMAS ----------------
  IF (select gems from users where id = a) <> 50 THEN
    RAISE EXCEPTION '056: oyuncu 50 elmasla baslamali';
  END IF;

  insert into user_chests (user_id, chest_type, rules_version, source_type, source_id, status, location, slot_no)
  values (a, 'bronze', (select max(version) from economy_config_versions where kind = 'chest_rules'),
          'test', 'gem-test-1', 'sealed', 'slot',
          (select s from generate_series(1, 4) s
           where s not in (select slot_no from user_chests where user_id = a and location = 'slot'
                           and status in ('sealed', 'unlocking') and slot_no is not null)
           limit 1))
  returning id into v_chest;

  v_cost := gem_open_cost((select c from user_chests c where id = v_chest));
  IF v_cost < 1 THEN RAISE EXCEPTION '056: elmas bedeli en az 1 olmali (%)', v_cost; END IF;

  BEGIN
    perform open_chest_with_gems(a, v_chest, v_cost - 1);
    RAISE EXCEPTION '056: ekranda gorulenden yuksek bedel alinmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'gem_cost_changed:%' THEN RAISE; END IF;
  END;

  v_sonuc := open_chest_with_gems(a, v_chest, v_cost);
  IF (v_sonuc ->> 'gems_spent')::int <> v_cost THEN RAISE EXCEPTION '056: harcanan elmas yanlis'; END IF;
  IF (v_sonuc ->> 'gems')::int NOT BETWEEN 1 AND 3 THEN RAISE EXCEPTION '056: bronz sandik 1-3 elmas vermeli'; END IF;
  IF (select gems from users where id = a) <> 50 - v_cost + (v_sonuc ->> 'gems')::int THEN
    RAISE EXCEPTION '056: elmas bakiyesi tutmuyor';
  END IF;
  IF (select status from user_chests where id = v_chest) <> 'opened' THEN RAISE EXCEPTION '056: sandik acilmadi'; END IF;
  -- Tekrar çağrı: ikinci kez elmas düşmez
  v_gems := (select gems from users where id = a);
  perform open_chest_with_gems(a, v_chest, v_cost);
  IF (select gems from users where id = a) <> v_gems THEN RAISE EXCEPTION '056: tekrar cagrida elmas dustu'; END IF;
  IF (select count(*) from gem_ledger where user_id = a) <> 2 THEN RAISE EXCEPTION '056: defterde 2 satir olmali'; END IF;

  -- Elmasla altın: aynı istek anahtarı iki kez işlemez
  update users set gems = 30 where id = a;
  v_coins := (select coins from users where id = a);
  v_sonuc := buy_coins_with_gems(a, 'gold_small', 'k1');
  v_sonuc := buy_coins_with_gems(a, 'gold_small', 'k1');
  IF NOT coalesce((v_sonuc ->> 'replay')::boolean, false) THEN RAISE EXCEPTION '056: tekrar istek replay olmali'; END IF;
  IF (select gems from users where id = a) <> 20 OR (select coins from users where id = a) <> v_coins + 250 THEN
    RAISE EXCEPTION '056: elmas/altin degisimi yanlis';
  END IF;
  BEGIN
    perform buy_coins_with_gems(a, 'gold_large', 'k2');
    RAISE EXCEPTION '056: yetersiz elmasla alinmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'not_enough_gems:%' THEN RAISE; END IF;
  END;
  IF (gem_status(a) -> 'exchange') IS NULL OR (gem_status(a) ->> 'gems')::int <> 20 THEN
    RAISE EXCEPTION '056: gem_status eksik';
  END IF;

  -- ---------------- ARKADAŞLIK ----------------
  BEGIN
    perform friend_request(a, a);
    RAISE EXCEPTION '056: kendine istek olmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'friend_self:%' THEN RAISE; END IF;
  END;

  IF friend_request(a, b) ->> 'friend_status' <> 'outgoing' THEN RAISE EXCEPTION '056: istek gonderilemedi'; END IF;
  IF _friend_status(b, a) <> 'incoming' THEN RAISE EXCEPTION '056: karsi taraf istegi gormeli'; END IF;
  v_liste := friend_list(b);
  IF jsonb_array_length(v_liste -> 'incoming') <> 1 OR jsonb_array_length(v_liste -> 'friends') <> 0 THEN
    RAISE EXCEPTION '056: gelen istek listesi yanlis';
  END IF;
  IF friend_respond(b, a, true) ->> 'friend_status' <> 'friends' THEN RAISE EXCEPTION '056: kabul edilemedi'; END IF;
  IF jsonb_array_length(friend_list(a) -> 'friends') <> 1 THEN RAISE EXCEPTION '056: arkadas listede yok'; END IF;
  perform friend_remove(a, b);
  IF _friend_status(a, b) <> 'none' THEN RAISE EXCEPTION '056: arkadaslik silinmedi'; END IF;
  -- Karşılıklı istek otomatik arkadaşlık olur
  perform friend_request(a, b);
  IF friend_request(b, a) ->> 'friend_status' <> 'friends' THEN RAISE EXCEPTION '056: karsilikli istek kabul sayilmali'; END IF;
  -- Reddetme
  perform friend_remove(a, b);
  perform friend_request(a, b);
  perform friend_respond(b, a, false);
  IF _friend_status(a, b) <> 'none' THEN RAISE EXCEPTION '056: reddedilen istek silinmeli'; END IF;

  -- ---------------- ARAMA ----------------
  v_liste := search_players(a, 'dbtest');
  IF jsonb_array_length(v_liste) <> 1 OR v_liste -> 0 ->> 'username' <> 'dbtest_2' THEN
    RAISE EXCEPTION '056: arama kendini disarida birakip digerini bulmali: %', v_liste;
  END IF;
  IF jsonb_array_length(search_players(a, 'd')) <> 0 THEN RAISE EXCEPTION '056: 2 harften kisa arama bos donmeli'; END IF;
  IF jsonb_array_length(search_players(a, 'dbtest\_%')) <> 0 AND jsonb_array_length(search_players(a, '%')) <> 0 THEN
    RAISE EXCEPTION '056: joker karakterler kacirilmali';
  END IF;

  -- ---------------- AÇIK PROFİL ----------------
  v_profil := public_profile(a, b);
  IF v_profil ? 'email' OR v_profil ? 'coins' OR v_profil ? 'gems' THEN
    RAISE EXCEPTION '056: profilde gizli bilgi var: %', v_profil;
  END IF;
  IF v_profil ->> 'username' <> 'dbtest_2' OR (v_profil ->> 'collection_count')::int < 1
     OR jsonb_array_length(v_profil -> 'top_cards') NOT BETWEEN 1 AND 3 THEN
    RAISE EXCEPTION '056: profil eksik: %', v_profil;
  END IF;
  IF v_profil -> 'rank' IS NULL OR v_profil -> 'head_to_head' IS NULL THEN RAISE EXCEPTION '056: lig/karsilasma yok'; END IF;

  -- ---------------- RAKİP KADROSU ----------------
  BEGIN
    perform match_opponent_squad(a, gen_random_uuid());
    RAISE EXCEPTION '056: olmayan mac bulunmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'match_not_found:%' THEN RAISE; END IF;
  END;

  RAISE NOTICE '056 OK: elmas, arkadaslik, arama, acik profil';
END;
$test$;
ROLLBACK;
