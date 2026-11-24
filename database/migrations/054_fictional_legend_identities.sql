-- 054: Six legacy Legend identities become original fictional footballers.
-- IMPORTANT: Never edit historical migration 010 on an existing staging DB:
-- staging-db-bootstrap.sh verifies the SHA256 of already applied migrations.
-- Keep immutable cards.id and historical slug, tier, position, power, stats,
-- club, league, nationality and all user_cards/deck_cards/match references.
-- The historical slug is an internal stable identifier, NOT a display name.
-- The original public names remain only in cards_identity_archive and
-- historical migration 010 for audit/rollback; UI reads cards.full_name.
--
-- Mapping:
--  Lev Yashin        -> Taren Volsk      (GK 95)
--  Franz Beckenbauer -> Borek Kaldren    (DEF 96)
--  Diego Maradona    -> Nerio Valtan     (MID 99)
--  Johan Cruyff      -> Elias Veyron     (MID 97)
--  Pele              -> Aren Solmar      (FWD 98)
--  Ferenc Puskas     -> Miran Korvek     (FWD 94)

DO $migration$
DECLARE
  v_card_count int;
  v_collision_count int;
BEGIN
  SELECT count(*) INTO v_card_count
  FROM cards
  WHERE slug IN (
    'legend-kaleci-lev-yashin',
    'legend-defans-franz-beckenbauer',
    'legend-orta-diego-maradona',
    'legend-orta-johan-cruyff',
    'legend-forvet-pele',
    'legend-forvet-ferenc-puskas'
  );
  IF v_card_count <> 6 THEN
    RAISE EXCEPTION '054 ABORT: expected six legacy Legend cards, found %', v_card_count;
  END IF;

  SELECT count(*) INTO v_collision_count
  FROM cards
  WHERE slug NOT IN (
    'legend-kaleci-lev-yashin',
    'legend-defans-franz-beckenbauer',
    'legend-orta-diego-maradona',
    'legend-orta-johan-cruyff',
    'legend-forvet-pele',
    'legend-forvet-ferenc-puskas'
  )
  AND full_name IN (
    'Taren Volsk', 'Borek Kaldren', 'Nerio Valtan',
    'Elias Veyron', 'Aren Solmar', 'Miran Korvek'
  );
  IF v_collision_count > 0 THEN
    RAISE EXCEPTION '054 ABORT: fictional name collision with another card';
  END IF;

  UPDATE cards AS c
  SET full_name = v.new_name,
      image_url = NULL -- legacy paths contained names and never existed as files
  FROM (VALUES
    ('legend-kaleci-lev-yashin', 'Taren Volsk'),
    ('legend-defans-franz-beckenbauer', 'Borek Kaldren'),
    ('legend-orta-diego-maradona', 'Nerio Valtan'),
    ('legend-orta-johan-cruyff', 'Elias Veyron'),
    ('legend-forvet-pele', 'Aren Solmar'),
    ('legend-forvet-ferenc-puskas', 'Miran Korvek')
  ) AS v(slug, new_name)
  WHERE c.slug = v.slug
    AND (c.full_name IS DISTINCT FROM v.new_name OR c.image_url IS NOT NULL);

  IF EXISTS (
    SELECT 1 FROM cards
    WHERE full_name IN (
      'Lev Yashin', 'Franz Beckenbauer', 'Diego Maradona',
      'Johan Cruyff', 'Pele', 'Ferenc Puskas'
    )
  ) THEN
    RAISE EXCEPTION '054 ABORT: legacy public Legend name remains in active cards';
  END IF;

  IF EXISTS (
    SELECT 1 FROM cards c
    JOIN (VALUES
      ('legend-kaleci-lev-yashin','Taren Volsk','GK'::card_position,95),
      ('legend-defans-franz-beckenbauer','Borek Kaldren','DEF'::card_position,96),
      ('legend-orta-diego-maradona','Nerio Valtan','MID'::card_position,99),
      ('legend-orta-johan-cruyff','Elias Veyron','MID'::card_position,97),
      ('legend-forvet-pele','Aren Solmar','FWD'::card_position,98),
      ('legend-forvet-ferenc-puskas','Miran Korvek','FWD'::card_position,94)
    ) v(slug,name,pos,power) ON c.slug=v.slug
    WHERE c.full_name <> v.name OR c.tier <> 'legend'
      OR c.position <> v.pos OR c.power <> v.power
  ) THEN
    RAISE EXCEPTION '054 ABORT: legend identity or gameplay values mismatch';
  END IF;
END;
$migration$;
