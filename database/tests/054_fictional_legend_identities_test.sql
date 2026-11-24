-- 054 Legend names migration regression tests.
-- The migration is run by scripts/db-testleri.sh before this test.
-- Read-only assertions enclosed in a rollback transaction.
BEGIN;
DO $test$
DECLARE
 v_count int;
 v_bad int;
BEGIN
 SELECT count(*) INTO v_count FROM cards
 WHERE slug IN (
  'legend-kaleci-lev-yashin','legend-defans-franz-beckenbauer',
  'legend-orta-diego-maradona','legend-orta-johan-cruyff',
  'legend-forvet-pele','legend-forvet-ferenc-puskas'
 );
 IF v_count <> 6 THEN RAISE EXCEPTION '054: expected six stable legacy slugs, found %',v_count; END IF;

 SELECT count(*) INTO v_bad
 FROM (VALUES
  ('legend-kaleci-lev-yashin','Taren Volsk','GK'::card_position,95),
  ('legend-defans-franz-beckenbauer','Borek Kaldren','DEF'::card_position,96),
  ('legend-orta-diego-maradona','Nerio Valtan','MID'::card_position,99),
  ('legend-orta-johan-cruyff','Elias Veyron','MID'::card_position,97),
  ('legend-forvet-pele','Aren Solmar','FWD'::card_position,98),
  ('legend-forvet-ferenc-puskas','Miran Korvek','FWD'::card_position,94)
 ) v(slug,new_name,pos,power)
 LEFT JOIN cards c ON c.slug=v.slug
 WHERE c.id IS NULL OR c.full_name IS DISTINCT FROM v.new_name
 OR c.tier IS DISTINCT FROM 'legend'::card_tier
 OR c.position IS DISTINCT FROM v.pos OR c.power IS DISTINCT FROM v.power
 OR c.image_url IS NOT NULL OR c.is_active IS DISTINCT FROM true;
 IF v_bad <> 0 THEN RAISE EXCEPTION '054: active card identity mismatch on % cards',v_bad; END IF;

 IF EXISTS (SELECT 1 FROM cards WHERE full_name IN (
  'Lev Yashin','Franz Beckenbauer','Diego Maradona',
  'Johan Cruyff','Pele','Ferenc Puskas'
 )) THEN RAISE EXCEPTION '054: old real footballer name visible in catalog'; END IF;

 -- Historical audit stays intact, unchanged original names and same IDs.
 SELECT count(*) INTO v_count FROM cards c JOIN cards_identity_archive a ON a.card_id=c.id
 WHERE a.full_name IN (
  'Lev Yashin','Franz Beckenbauer','Diego Maradona',
  'Johan Cruyff','Pele','Ferenc Puskas'
 ) AND a.slug=c.slug AND a.tier=c.tier AND a.position=c.position
 AND a.power=c.power AND a.club IS NOT DISTINCT FROM c.club
 AND a.league IS NOT DISTINCT FROM c.league
 AND a.nationality IS NOT DISTINCT FROM c.nationality;
 IF v_count <> 6 THEN RAISE EXCEPTION '054: six original names or gameplay fields not preserved in archive: %',v_count; END IF;

 RAISE NOTICE '054 OK: six original character names; unchanged card IDs, tiers, positions, power, chemistry and ownership references';
END;
$test$;
ROLLBACK;
