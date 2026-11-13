-- New OAuth identity table may not modify preexisting card/account records.
BEGIN;
DO $$
DECLARE
  a uuid;
  b uuid;
  current_count integer;
BEGIN
  SELECT count(*) INTO current_count FROM user_auth_providers;
  INSERT INTO users(email, password_hash, username)
  VALUES ('oauth_test_1@test.invalid','x','oauth_test_one') RETURNING id INTO a;
  INSERT INTO users(email, password_hash, username)
  VALUES ('oauth_test_2@test.invalid','x','oauth_test_two') RETURNING id INTO b;
  INSERT INTO user_auth_providers(provider, provider_subject, user_id)
  VALUES ('google', 'google_test_subject_1', a);
  INSERT INTO user_auth_providers(provider, provider_subject, user_id)
  VALUES ('apple', 'apple_test_subject_1', a);

  IF (SELECT count(*) FROM user_auth_providers WHERE user_id = a) <> 2 THEN
    RAISE EXCEPTION 'Same player must support Google plus Apple';
  END IF;

  BEGIN
    INSERT INTO user_auth_providers(provider, provider_subject, user_id)
    VALUES ('google', 'google_test_subject_1', b);
    RAISE EXCEPTION 'REJECT_EXPECTED: same Google identity assigned to two players';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  BEGIN
    INSERT INTO user_auth_providers(provider, provider_subject, user_id)
    VALUES ('google', 'google_test_subject_2', a);
    RAISE EXCEPTION 'REJECT_EXPECTED: two Google identities on same player';
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  IF (SELECT count(*) FROM user_auth_providers) <> current_count + 2 THEN
    RAISE EXCEPTION 'Unexpected social identities count';
  END IF;
  RAISE NOTICE 'SOCIAL AUTH: account mapping, uniqueness and no overwrite passed';
END $$;
ROLLBACK;
