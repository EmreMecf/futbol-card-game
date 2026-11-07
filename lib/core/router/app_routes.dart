/// Uygulamadaki tum yol (route) adlari.
///
/// Metin olarak yol yazmak yerine bu sabitleri kullan; yazim hatasi
/// yuzunden calisma aninda hata almazsin.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/giris';
  static const String register = '/kayit';
  static const String home = '/ana-sayfa';
  static const String collection = '/koleksiyon';
  static const String deck = '/kadro';
  static const String matchmaking = '/eslesme';
  static const String match = '/mac';
  static const String profile = '/profil';
  static const String settings = '/ayarlar';

  /// Tasarim sistemi vitrini. SADECE gelistirme surumunde baglanti var.
  static const String designSystem = '/ayarlar/tasarim';

  /// Geliştirici: tek karakter prototipi (Aşama A1)
  static const String characterPreview = '/ayarlar/karakter-onizleme';
  static const String stylePrototype = '/ayarlar/stil-prototipi';
  static const String leaderboard = '/liderlik';
  static const String leagueTiers = '/ligler';
  static const String store = '/magaza';
  static const String sbc = '/gorevler';

  /// Gorev kadrosu kurma ekrani: /gorevler/{challenge_id}
  static String sbcBuilderWithId(String challengeId) => '$sbc/$challengeId';

  /// Mac ekranina id ile gitmek icin: `/mac/{match_id}`
  static String matchWithId(String matchId) => '$match/$matchId';
}
