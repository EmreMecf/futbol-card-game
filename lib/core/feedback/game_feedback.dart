import 'package:flutter/services.dart';

import '../../features/settings/presentation/viewmodel/settings_view_model.dart';
import '../di/injection.dart';

/// Titreşim şiddeti.
///
/// MD'deki dört kademe:
///   [selection] -> hafif dokunma (kart seçme, buton)
///   [light]     -> kart oynama, altın kart açılışı
///   [medium]    -> önemli hamle (tur kazanma)
///   [heavy]     -> zafer, Legend/Diamond walkout
enum HapticStrength { none, selection, light, medium, heavy }

/// Oyuncuya verilen DOKUNSAL ve görsel geri bildirimin TEK kapısı.
///
/// ===================================================================
/// NEDEN TEK KAPI?
/// ===================================================================
/// Ayarlar ekranında "Titreşim", "Kart animasyonları" ve "Süre
/// uyarısı" anahtarları vardı ama hiçbir kod bunları okumuyordu:
/// oyuncu titreşimi kapatıyor, telefon titremeye devam ediyordu.
///
/// Sebep, `HapticFeedback.heavyImpact()` çağrısının ekranlara dağılmış
/// olmasıydı; her çağrı yeri ayarı ayrı ayrı kontrol etmeyi
/// "hatırlamak" zorundaydı. Artık kural şu:
///
///   ❌ HapticFeedback.heavyImpact();          // ayarı bilmez
///   ✅ GameFeedback.haptic(HapticStrength.heavy);
///
/// Yeni bir titreşim eklendiğinde ayar kontrolü kendiliğinden gelir.
///
/// ===================================================================
/// AYAR YOKSA VARSAYILAN: AÇIK
/// ===================================================================
/// Widget testleri bağımlılık kaydı (Get_It) yapmadan çalışabiliyor.
/// O durumda ayar okunamaz; varsayılan değerlerle (hepsi açık)
/// devam ediyoruz. Bu, uygulamadaki varsayılanlarla aynı.
class GameFeedback {
  const GameFeedback._();

  static SettingsViewModel? get _ayarlar =>
      getIt.isRegistered<SettingsViewModel>()
      ? getIt<SettingsViewModel>()
      : null;

  /// Titreşim açık mı?
  static bool get vibrationEnabled => _ayarlar?.vibration ?? true;

  /// 3B eğilme, holografik parlama ve dönen çerçeve açık mı?
  ///
  /// Kapalıyken kartlar statik çizilir. Düşük donanımlı telefonlarda
  /// pil ve akıcılık için (MD madde 9: "düşük performanslı cihazlarda
  /// azaltılabilir").
  static bool get cardAnimationsEnabled => _ayarlar?.cardAnimations ?? true;

  /// Son saniyelerde sayacın kırmızıya dönmesi açık mı?
  static bool get turnWarningEnabled => _ayarlar?.turnWarning ?? true;

  /// Ayara uyarak titreşim verir. Kapalıysa hiçbir şey yapmaz.
  static Future<void> haptic(HapticStrength strength) async {
    if (!vibrationEnabled) return;

    switch (strength) {
      case HapticStrength.none:
        return;
      case HapticStrength.selection:
        await HapticFeedback.selectionClick();
      case HapticStrength.light:
        await HapticFeedback.lightImpact();
      case HapticStrength.medium:
        await HapticFeedback.mediumImpact();
      case HapticStrength.heavy:
        await HapticFeedback.heavyImpact();
    }
  }
}
