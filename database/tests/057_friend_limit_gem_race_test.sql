-- 057: arkadaş sınırı kabulde, elmas defteri tekrar, gerçek bitmiş maçta
-- rakip kadrosu (geri alınan işlem içinde). Eş zamanlı yarışlar ayrıca
-- scripts/esz-zamanli-yaris-testi.sh içinde denenir.
BEGIN;
DO $test$
DECLARE
  a uuid := (select id from users where username = 'dbtest_1');
  b uuid := (select id from users where username = 'dbtest_2');
  c uuid;
  d uuid;
  v_kalabalik uuid[];
  v_hata text;
  v_gems int;
  v_sonuc int;
  v_mac uuid;
  v_kart uuid;
  v_kadro jsonb;
  m matches%rowtype;
  i int;
BEGIN
  -- Yardımcı oyuncular: 100 arkadaş doldurmak için
  insert into users (email, password_hash, username)
  select 't057_' || g || '@test.local', 'x', 't057_' || g from generate_series(1, 101) g;
  select array_agg(id order by username) into v_kalabalik from users where username like 't057_%';
  c := v_kalabalik[101];
  insert into users (email, password_hash, username) values ('t057_d@test.local', 'x', 't057_d') returning id into d;

  -- ---------------- 1) KABULDE SINIR ----------------
  -- a'nın 100 arkadaşı var; c'nin bekleyen isteği kabul edilemez
  insert into friendships (user_low, user_high, requested_by, status, accepted_at)
  select least(a, x), greatest(a, x), a, 'accepted', now() from unnest(v_kalabalik[1:100]) x;
  insert into friendships (user_low, user_high, requested_by) values (least(a, c), greatest(a, c), c);
  BEGIN
    perform friend_respond(a, c, true);
    RAISE EXCEPTION '057: 100 arkadasla kabul edilmemeliydi';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'friend_limit:%' THEN RAISE; END IF;
  END;
  IF _friend_count(a) <> 100 THEN RAISE EXCEPTION '057: a 100 arkadasta kalmali (%)', _friend_count(a); END IF;

  -- Karşılıklı istekle otomatik kabul de sınırı aşamaz (a dolu)
  BEGIN
    perform friend_request(a, c);
    RAISE EXCEPTION '057: karsilikli istek siniri asmamaliydi';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'friend_limit:%' THEN RAISE; END IF;
  END;

  -- Karşı taraf doluysa: d, a'ya istek atabilir ama a dolu olduğu için
  -- d'nin kabul etmesi (karşılıklı) friend_limit_other verir
  insert into friendships (user_low, user_high, requested_by) values (least(a, d), greatest(a, d), a);
  BEGIN
    perform friend_respond(d, a, true);
    RAISE EXCEPTION '057: dolu oyuncuyla kabul edilmemeliydi';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'friend_limit_other:%' THEN RAISE; END IF;
  END;
  BEGIN
    perform friend_request(d, a);
    RAISE EXCEPTION '057: karsilikli istek dolu oyuncuyla kabul edilmemeliydi';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'friend_limit_other:%' THEN RAISE; END IF;
  END;
  IF _friend_status(d, a) <> 'incoming' THEN RAISE EXCEPTION '057: istek bekler durumda kalmali'; END IF;

  -- Biri çıkarılınca kabul çalışır
  perform friend_remove(a, v_kalabalik[1]);
  perform friend_respond(a, c, true);
  IF _friend_status(a, c) <> 'friends' OR _friend_count(a) <> 100 THEN
    RAISE EXCEPTION '057: yer acilinca kabul edilmeliydi';
  END IF;

  -- ---------------- 2) ELMAS DEFTERİ ----------------
  v_gems := (select gems from users where id = b);
  v_sonuc := _gem_add(b, 7, 'test', 't057', 't057:gem');
  IF v_sonuc <> v_gems + 7 THEN RAISE EXCEPTION '057: elmas eklenmeliydi'; END IF;
  IF _gem_add(b, 7, 'test', 't057', 't057:gem') <> v_gems + 7
     OR (select gems from users where id = b) <> v_gems + 7
     OR (select count(*) from gem_ledger where idempotency_key = 't057:gem') <> 1 THEN
    RAISE EXCEPTION '057: ayni anahtar ikinci kez islenmemeli';
  END IF;

  -- ---------------- 3) GERÇEK BİTMİŞ MAÇTA RAKİP KADROSU ----------------
  v_mac := _create_match(a, (select id from decks where owner_id = a and is_active), '{}',
                         b, (select id from decks where owner_id = b and is_active), '{}');
  FOR i IN 1..60 LOOP
    select * into m from matches where id = v_mac;
    EXIT WHEN m.status <> 'active';
    IF m.rules_version >= 4 THEN
      RAISE EXCEPTION '057: test klasik (sirali) kurallarla kurulmus mac bekler, surum %', m.rules_version;
    END IF;
    select user_card_id into v_kart from match_hands
    where match_id = m.id and user_id = m.current_turn_id and not is_played
      and (m.required_position is null or position = m.required_position)
    limit 1;
    IF v_kart IS NULL THEN
      perform play_card(m.current_turn_id, m.id, null);
    ELSE
      perform play_card(m.current_turn_id, m.id, v_kart);
    END IF;
  END LOOP;
  IF (select status from matches where id = v_mac) <> 'finished' THEN
    RAISE EXCEPTION '057: mac bitmeliydi';
  END IF;

  v_kadro := match_opponent_squad(a, v_mac);
  IF jsonb_array_length(v_kadro -> 'cards') <> 11 THEN
    RAISE EXCEPTION '057: rakip kadrosu 11 kart olmali (%)', jsonb_array_length(v_kadro -> 'cards');
  END IF;
  IF (v_kadro -> 'opponent' ->> 'id')::uuid <> b THEN RAISE EXCEPTION '057: rakip b olmali'; END IF;
  IF exists (select 1 from jsonb_array_elements(v_kadro -> 'cards') x
             where coalesce(x ->> 'slug', '') = ''
                or (x ->> 'card_id')::uuid not in (select card_id from match_hands where match_id = v_mac and user_id = b)) THEN
    RAISE EXCEPTION '057: kartlar rakibin eli olmali ve slug tasimali';
  END IF;
  -- Ters yönden de 11 kart; maçın oyuncusu olmayan göremez
  IF jsonb_array_length(match_opponent_squad(b, v_mac) -> 'cards') <> 11 THEN
    RAISE EXCEPTION '057: b de 11 kart gormeli';
  END IF;
  BEGIN
    perform match_opponent_squad(c, v_mac);
    RAISE EXCEPTION '057: macin oyuncusu olmayan gormemeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'match_not_found:%' THEN RAISE; END IF;
  END;

  -- Açık profil kartlarında slug
  IF exists (select 1 from jsonb_array_elements(public_profile(a, b) -> 'top_cards') x
             where coalesce(x ->> 'slug', '') = '') THEN
    RAISE EXCEPTION '057: profil kartlari slug tasimali';
  END IF;

  RAISE NOTICE '057 OK: kabulde sinir, elmas tekrar, bitmis macta 11 kartlik rakip kadrosu';
END;
$test$;
ROLLBACK;
