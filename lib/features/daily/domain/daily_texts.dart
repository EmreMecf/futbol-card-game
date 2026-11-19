import 'package:shared_models/shared_models.dart';

/// Günlük panel metinleri (test edilebilsin diye ayrı)
abstract final class DailyPanelTexts {
  static String sandikAdi(String t) => t == 'silver' ? 'Gümüş' : 'Bronz';

  static (String, String) texts(DailyStatus d) {
    final sandik = d.claimedToday
        ? 'Bugünkü ${sandikAdi(d.chestType)} sandığı alındı. Seri: ${d.streak} gün.'
        : 'Bugün ücretsiz ${sandikAdi(d.chestType)} sandık seni bekliyor.'
            // yeni oyuncuya "Seri: 0 gün" gösterme
            '${d.streak > 0 ? ' Seri: ${d.streak} gün.' : ''}';
    final galibiyet = d.firstWinToday
        ? 'Günün ilk galibiyeti alındı (çift XP).'
        : 'Günün ilk dereceli galibiyeti ${d.firstWinMultiplier} kat sezon XP\'si verir.';
    return (sandik, galibiyet);
  }
}
