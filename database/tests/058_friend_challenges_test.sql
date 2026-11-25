-- 058: arkadaşı dostluk maçına çağırma (geri alınan işlem içinde)
BEGIN;
DO $test$
DECLARE
  a uuid := (select id from users where username = 'dbtest_1');
  b uuid := (select id from users where username = 'dbtest_2');
  c uuid;
  d uuid;
  v jsonb;
  v2 jsonb;
  v_liste jsonb;
  v_hata text;
  v_oda friend_rooms%rowtype;
BEGIN
  insert into users (email, password_hash, username) values ('t058c@test.local', 'x', 't058_c') returning id into c;
  insert into users (email, password_hash, username) values ('t058d@test.local', 'x', 't058_d') returning id into d;
  insert into friendships (user_low, user_high, requested_by, status, accepted_at)
  values (least(a, b), greatest(a, b), a, 'accepted', now()),
         (least(a, d), greatest(a, d), a, 'accepted', now());

  -- Arkadaş olmayan çağrılamaz
  BEGIN
    perform friend_challenge_send(a, c);
    RAISE EXCEPTION '058: arkadas olmayan cagrilmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'challenge_not_friend:%' THEN RAISE; END IF;
  END;

  -- Çağır: oda açılır, davet bekler; tekrar çağırmak aynı daveti döner
  v := friend_challenge_send(a, b);
  IF v ->> 'status' <> 'pending' OR coalesce(v ->> 'code', '') = '' OR (v -> 'from' ->> 'id')::uuid <> a THEN
    RAISE EXCEPTION '058: davet olusmali: %', v;
  END IF;
  IF (v ->> 'seconds_left')::int NOT BETWEEN 55 AND 60 THEN RAISE EXCEPTION '058: 60 sn olmali'; END IF;
  v2 := friend_challenge_send(a, b);
  IF v2 ->> 'id' <> v ->> 'id' THEN RAISE EXCEPTION '058: ayni arkadasa ikinci davet acilmamali'; END IF;
  select * into v_oda from friend_rooms where invite_code = v ->> 'code';
  IF v_oda.host_id <> a OR v_oda.status <> 'waiting' THEN RAISE EXCEPTION '058: cagiranin odasi acilmali'; END IF;

  -- Çağrılana görünür, başkasına görünmez
  v_liste := friend_challenge_incoming(b);
  IF jsonb_array_length(v_liste) <> 1 OR v_liste -> 0 ->> 'id' <> v ->> 'id'
     OR v_liste -> 0 -> 'from' ->> 'username' <> 'dbtest_1' THEN
    RAISE EXCEPTION '058: b daveti gormeli: %', v_liste;
  END IF;
  IF jsonb_array_length(friend_challenge_incoming(a)) <> 0 THEN RAISE EXCEPTION '058: a kendi davetini gormemeli'; END IF;

  -- Başkası yanıtlayamaz
  BEGIN
    perform friend_challenge_respond(c, (v ->> 'id')::uuid, true);
    RAISE EXCEPTION '058: baskasi yanitlamamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'challenge_not_found:%' THEN RAISE; END IF;
  END;

  -- Ret: liste boşalır, ikinci yanıt reddedilir
  v2 := friend_challenge_respond(b, (v ->> 'id')::uuid, false);
  IF v2 ->> 'status' <> 'declined' THEN RAISE EXCEPTION '058: reddedilmeli'; END IF;
  IF jsonb_array_length(friend_challenge_incoming(b)) <> 0 THEN RAISE EXCEPTION '058: ret sonrasi liste bos olmali'; END IF;
  BEGIN
    perform friend_challenge_respond(b, (v ->> 'id')::uuid, true);
    RAISE EXCEPTION '058: kapanan davet kabul edilmemeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'challenge_closed:%' THEN RAISE; END IF;
  END;

  -- Süre dolan davet listelenmez ve kabul edilemez
  v := friend_challenge_send(a, b);
  update friend_challenges set expires_at = now() - interval '1 second' where id = (v ->> 'id')::uuid;
  IF jsonb_array_length(friend_challenge_incoming(b)) <> 0 THEN RAISE EXCEPTION '058: suresi dolan listelenmemeli'; END IF;
  BEGIN
    perform friend_challenge_respond(b, (v ->> 'id')::uuid, true);
    RAISE EXCEPTION '058: suresi dolan kabul edilmemeli';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'challenge_closed:%' THEN RAISE; END IF;
  END;

  -- Geri çekme
  v := friend_challenge_send(a, b);
  v2 := friend_challenge_cancel(a, (v ->> 'id')::uuid);
  IF v2 ->> 'status' <> 'cancelled' OR jsonb_array_length(friend_challenge_incoming(b)) <> 0 THEN
    RAISE EXCEPTION '058: geri cekilen davet kapanmali';
  END IF;

  -- Oda tek kişilik: d'yi çağırınca b'ye giden davet kapanır
  v := friend_challenge_send(a, b);
  v2 := friend_challenge_send(a, d);
  IF (select status from friend_challenges where id = (v ->> 'id')::uuid) <> 'cancelled' THEN
    RAISE EXCEPTION '058: ayni odadan eski davet kapanmali';
  END IF;

  -- Kabul: d odaya katılır, davet kabul edilir
  v := friend_challenge_respond(d, (v2 ->> 'id')::uuid, true);
  select * into v_oda from friend_rooms where invite_code = v2 ->> 'code';
  IF v ->> 'status' <> 'accepted' OR v_oda.guest_id <> d THEN RAISE EXCEPTION '058: kabulde odaya katilmali'; END IF;

  -- Odada misafir varken yeni davet açılamaz
  BEGIN
    perform friend_challenge_send(a, b);
    RAISE EXCEPTION '058: dolu odayla davet acilmamali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'challenge_room_full:%' THEN RAISE; END IF;
  END;

  -- Sıklık sınırı: dakikada 6
  update friend_rooms set status = 'cancelled' where host_id = a;
  insert into friend_challenges (from_id, to_id, room_id, status)
  select a, d, (select id from friend_rooms where host_id = a limit 1), 'declined' from generate_series(1, 6);
  BEGIN
    perform friend_challenge_send(a, b);
    RAISE EXCEPTION '058: siklik siniri uygulanmali';
  EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_hata = MESSAGE_TEXT;
    IF v_hata NOT LIKE 'challenge_rate_limit:%' THEN RAISE; END IF;
  END;

  RAISE NOTICE '058 OK: cagir, gelen, ret, sure, geri cek, kabul, oda dolu, siklik siniri';
END;
$test$;
ROLLBACK;
