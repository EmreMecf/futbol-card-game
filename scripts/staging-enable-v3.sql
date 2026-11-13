-- STAGING ONLY: one-time V3 PvP activation, append-only economy config.
-- Invoke ONLY from guarded staging entrypoint on DB_NAME=futbol_card_staging.
BEGIN;
DO $$
DECLARE
  latest record;
  desired jsonb;
BEGIN
  IF current_database() <> 'futbol_card_staging' THEN
    RAISE EXCEPTION 'STAGING ONLY: refused for %', current_database();
  END IF;
  IF to_regclass('public.game_rule_versions') IS NULL
     OR NOT EXISTS (SELECT 1 FROM game_rule_versions WHERE version = 5) THEN
    RAISE EXCEPTION 'V3 level-power rule version 5 missing; abort';
  END IF;
  SELECT version, payload INTO latest
  FROM economy_config_versions
  WHERE kind = 'feature_flags' AND active_from <= now()
  ORDER BY version DESC LIMIT 1 FOR SHARE;
  IF latest.version IS NULL THEN
    RAISE EXCEPTION 'feature flags not initialized';
  END IF;

  desired := latest.payload || '{
    "economy_v2_enabled": true,
    "ranked_rewards_v2": true,
    "duel_v4": true,
    "card_level_power": true
  }'::jsonb;
  IF desired IS DISTINCT FROM latest.payload THEN
    INSERT INTO economy_config_versions(kind, version, payload, note)
    VALUES ('feature_flags', latest.version + 1, desired,
            'STAGING ONLY: two Android devices V3 PvP evaluation; feature flags enabled');
    RAISE NOTICE 'STAGING: V3 PvP flags activated';
  ELSE
    RAISE NOTICE 'STAGING: V3 PvP flags already active, no update';
  END IF;
END $$;
COMMIT;

DO $$
BEGIN
  IF current_rules_version() <> 5 THEN
    RAISE EXCEPTION 'STAGING: expected current_rules_version=5, got %', current_rules_version();
  END IF;
END $$;
