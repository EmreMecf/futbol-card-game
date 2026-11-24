-- 055 kimya kaldirma testleri (yalniz okuma, geri alinan islem icinde)
BEGIN;
DO $test$
BEGIN
  IF chemistry_link_score('TUR', 'Super Lig', 'Anadolu SK', 'TUR', 'Super Lig', 'Anadolu SK') <> 0 THEN
    RAISE EXCEPTION '055: ayni kulup/lig/uyruk hala kimya puani veriyor';
  END IF;

  IF EXISTS (SELECT 1 FROM sbc_challenges WHERE requirements @> '[{"type": "min_chemistry"}]'::jsonb) THEN
    RAISE EXCEPTION '055: kimya sarti iceren SBC gorevi var';
  END IF;

  IF EXISTS (SELECT 1 FROM sbc_challenges WHERE slug = 'mukemmel-uyum' AND is_active) THEN
    RAISE EXCEPTION '055: kimyaya dayali Mukemmel Uyum gorevi hala acik';
  END IF;

  -- Diger sartlar korunur (yalniz kimya sarti silinir)
  IF NOT EXISTS (SELECT 1 FROM sbc_challenges WHERE slug = 'gumus-yukseltme'
                 AND requirements = '[{"type": "exact_tier", "tier": "silver"}]'::jsonb) THEN
    RAISE EXCEPTION '055: gumus-yukseltme sartlari beklenen gibi degil';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM sbc_challenges WHERE slug = 'altin-standart'
                 AND requirements @> '[{"type": "min_avg_power", "value": 78}]'::jsonb) THEN
    RAISE EXCEPTION '055: altin-standart guc sarti kayboldu';
  END IF;

  RAISE NOTICE '055 OK: kimya her yerde 0, SBC kimya sartlari kaldirildi';
END;
$test$;
ROLLBACK;
