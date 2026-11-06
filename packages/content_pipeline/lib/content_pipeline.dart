/// Özgün futbolcu karakteri üretim hattı.
///
///   Claude (kimlik, JSON şema) → CharacterValidator → BalanceEngine
///   → taslak katalog (insan onayı olmadan yayınlanmaz)
///
/// Plan: docs/KARAKTER_SISTEMI_PLANI.md
library;

export 'src/balance_engine.dart';
export 'src/blocklist.dart';
export 'src/catalog_slot.dart';
export 'src/generator.dart';
export 'src/pipeline.dart';
export 'src/validator.dart';
