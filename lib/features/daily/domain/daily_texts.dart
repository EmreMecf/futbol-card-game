import 'package:shared_models/shared_models.dart';
import '../../../core/l10n/app_language.dart';

/// Günlük panel metinleri (test edilebilsin diye ayrı)
abstract final class DailyPanelTexts {
  static String sandikAdi(String t) => t == 'silver' ? 'Gümüş'.tr : 'Bronz'.tr;

  static (String, String) texts(DailyStatus d) {
    final sandik = d.claimedToday
        ? 'Bugünkü {p} sandığı alındı. Seri: {streak} gün.'.trArgs({'p': sandikAdi(d.chestType), 'streak': d.streak})
        : 'Bugün ücretsiz {p} sandık seni bekliyor.{p2}'.trArgs({'p': sandikAdi(d.chestType), 'p2': d.streak > 0 ? ' Seri: {streak} gün.'.trArgs({'streak': d.streak}) : ''});
    final galibiyet = d.firstWinToday
        ? 'Günün ilk galibiyeti alındı (çift XP).'.tr
        : 'Günün ilk dereceli galibiyeti {firstWinMultiplier} kat sezon XP\'si verir.'.trArgs({'firstWinMultiplier': d.firstWinMultiplier});
    return (sandik, galibiyet);
  }
}
