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
  static const String friends = '/arkadaslar';
  static const String friendInvite = '/davet';
  static String friendInviteWithCode(String code) => '$friendInvite/$code';

  /// Giriş/kayıt adresinde bekleyen davet kodunun parametresi
  static const String inviteParam = 'davet';
  static final RegExp _inviteCode = RegExp(r'^[0-9a-f]{30}$');

  /// Giriş yapmamış oyuncu bu adrese gelince davet kodu giriş adresinde taşınır
  static String loginFor(String location) {
    final parts = Uri.parse(location).pathSegments;
    final isInvite = parts.length == 2 && '/${parts[0]}' == friendInvite && _inviteCode.hasMatch(parts[1]);
    return isInvite ? '$login?$inviteParam=${parts[1]}' : login;
  }

  /// Giriş ekranından kayıt ekranına geçerken bekleyen davet korunur
  static String registerFrom(Uri current) {
    final code = current.queryParameters[inviteParam];
    return code != null && _inviteCode.hasMatch(code) ? '$register?$inviteParam=$code' : register;
  }

  /// Giriş ya da kayıt bitince açılacak ekran: bekleyen davet, yoksa ana sayfa
  static String afterAuth(Uri current) {
    final code = current.queryParameters[inviteParam];
    return code != null && _inviteCode.hasMatch(code) ? friendInviteWithCode(code) : home;
  }

  static const String match = '/mac';
  static const String profile = '/profil';
  static const String settings = '/ayarlar';

  static const String leaderboard = '/liderlik';
  static const String leagueTiers = '/ligler';
  static const String store = '/magaza';
  static const String sbc = '/gorevler';

  /// Ekonomi V2 (FAZ 1): sandıklar ve sürümlü olasılık tablosu
  static const String chests = '/sandiklar';
  static const String chestOdds = '/sandiklar/olasiliklar';

  /// Ekonomi V2 (FAZ 2): futbolcu seviyeleri
  static const String progress = '/gelisim';

  /// Ekonomi V2 (FAZ 3): item envanteri
  static const String inventory = '/envanter';

  /// Ekonomi V2 (FAZ 4): Battle Pass + görevler
  static const String season = '/sezon';

  /// Gorev kadrosu kurma ekrani: /gorevler/{challenge_id}
  static String sbcBuilderWithId(String challengeId) => '$sbc/$challengeId';

  /// Mac ekranina id ile gitmek icin: `/mac/{match_id}`
  static String matchWithId(String matchId) => '$match/$matchId';
}
