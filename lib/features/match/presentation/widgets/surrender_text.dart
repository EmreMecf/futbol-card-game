import 'package:shared_models/shared_models.dart';

/// Teslim olma onayındaki uyarı. Yalnız kartlar gerçekten el değiştiriyorsa
/// kart kaybından söz eder.
String surrenderWarning(MatchState? d) {
  if (d != null && d.mode != 'ranked') {
    return 'Teslim olursan maç biter. Bu modda puan, ödül ve kart kaybı yok.';
  }
  if (d?.cardTransfer == false) {
    return 'Teslim olursan maçı kaybetmiş sayılırsın. Kart kaybı yok: kartların sende kalır.';
  }
  return 'Teslim olursan maçı kaybetmiş sayılırsın ve korumaya almadığın '
      '${GameRules.penaltyCardCount} kartın kalıcı olarak rakibe geçer.';
}
