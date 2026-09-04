/// Sunucu ve Flutter uygulamasinin ORTAK kullandigi veri modelleri.
///
/// NEDEN PAYLASILAN PAKET?
/// Sunucu bu siniflari `toJson()` ile gonderir, uygulama `fromJson()`
/// ile okur. Ikisi de AYNI sinifi kullandigi icin "sunucu user_card_id
/// gonderiyor ama uygulama userCardId bekliyor" turu hatalar derleme
/// zamaninda yakalanir; calisma aninda sessizce null donmez.
///
/// Kod uretmek icin:
///   cd packages/shared_models
///   dart run build_runner build --delete-conflicting-outputs
library;

export 'src/auth_models.dart';
export 'src/card_attributes.dart';
export 'src/card_model.dart';
export 'src/chemistry.dart';
export 'src/deck_models.dart';
export 'src/enums.dart';
export 'src/game_rules.dart';
export 'src/match_history.dart';
export 'src/match_models.dart';
export 'src/match_result.dart';
export 'src/pack_models.dart';
export 'src/realtime_event.dart';
export 'src/sbc_models.dart';
export 'src/user_model.dart';
