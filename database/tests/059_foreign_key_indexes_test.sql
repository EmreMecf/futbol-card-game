-- 059: büyüyen oyun tablolarındaki her yabancı anahtarın başında bir dizin var
BEGIN;
DO $test$
DECLARE
  v_eksik text;
BEGIN
  select string_agg(c.conrelid::regclass || '.' || a.attname, ', ' order by 1)
  into v_eksik
  from pg_constraint c
  join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
  where c.contype = 'f' and array_length(c.conkey, 1) = 1
    and not exists (select 1 from pg_index i where i.indrelid = c.conrelid and i.indkey[0] = c.conkey[1])
    -- Küçük katalog tabloları bilerek dizinlenmez (059 açıklaması)
    and c.conrelid::regclass::text not in (
      'cards', 'fictional_regions', 'fictional_leagues', 'fictional_clubs', 'characters',
      'character_assets', 'user_trophy_road', 'trophy_road_grants')
    and not (c.conrelid::regclass::text = 'matches' and a.attname = 'rules_version')
    and not (c.conrelid::regclass::text = 'season_league_results' and a.attname = 'tier_before');
  IF v_eksik IS NOT NULL THEN
    RAISE EXCEPTION '059: dizinsiz yabanci anahtar: %', v_eksik;
  END IF;
  RAISE NOTICE '059 OK: oyun tablolarindaki yabanci anahtarlar dizinli';
END;
$test$;
ROLLBACK;
