import 'package:shared_models/shared_models.dart';
import '../../../../core/l10n/app_language.dart';

/// Teslim olma onayındaki uyarı. Yalnız kartlar gerçekten el değiştiriyorsa
/// kart kaybından söz eder.
String surrenderWarning(MatchState? d) {
  if (d != null && d.mode != 'ranked') {
    return 'Teslim olursan maç biter. Bu modda puan, ödül ve kart kaybı yok.'.tr;
  }
  if (d?.cardTransfer == false) {
    return 'Teslim olursan maçı kaybetmiş sayılırsın. Kart kaybı yok: kartların sende kalır.'.tr;
  }
  return 'Teslim olursan maçı kaybetmiş sayılırsın ve korumaya almadığın {penaltyCardCount} kartın kalıcı olarak rakibe geçer.'.trArgs({'penaltyCardCount': GameRules.penaltyCardCount});
}
