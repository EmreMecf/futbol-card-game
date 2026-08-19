/// Oyun kurallarina ait sabitler.
///
/// Bu degerler veritabanindaki fonksiyonlarla (squad_size(),
/// turn_timeout_seconds() vb.) AYNI olmalidir. Burasi sadece arayuzun
/// sayac gostermesi, buton kilitlemesi gibi isler icindir; gercek
/// dogrulama her zaman sunucuda yapilir.
class GameRules {
  const GameRules._();

  /// Kadrodaki toplam kart sayisi
  static const int squadSize = 11;

  /// Zorunlu formasyon: 1 kaleci, 4 defans, 4 orta saha, 2 forvet
  static const Map<String, int> formation = {
    'GK': 1,
    'DEF': 4,
    'MID': 4,
    'FWD': 2,
  };

  /// Bir oyuncunun kart oynamasi icin verilen sure
  static const Duration turnDuration = Duration(seconds: 45);

  /// Tur suresi bittikten sonra taninan ek sure.
  /// Bu da dolarsa oyuncu maci HUKMEN kaybeder.
  static const Duration afkGrace = Duration(seconds: 15);

  /// Maci kaybeden oyuncunun kaptiracagi kart sayisi
  static const int penaltyCardCount = 3;

  /// Baslangictaki kart koruma hakki
  static const int baseProtectionSlots = 3;

  /// Kart koruma hakkinin ulasabilecegi en yuksek deger
  static const int maxProtectionSlots = 10;

  /// Eslesme beklerken sunucunun tekrar sorgulanma araligi
  static const Duration matchmakingPollInterval = Duration(seconds: 4);
}
