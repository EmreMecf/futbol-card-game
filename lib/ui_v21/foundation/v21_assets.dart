/// V2.1 görsel varlıkları.
///
/// Hepsi `design/reference/` altındaki HTML prototipinin gömülü 390×844
/// PNG'lerinden KIRPILARAK üretildi (bkz. `tool/v21/extract_reference.dart`
/// ve `docs/UI_V21_IMPLEMENTATION_PROGRESS.md`). Kaynak 1× çözünürlükte
/// olduğu için yüksek yoğunluklu ekranlarda yumuşak görünür; tasarımcıdan
/// katmanlı, 3× görseller gelince yalnız bu dosyadaki yollar değişir.
///
/// Tam ekran PNG'ler (`assets/v21/screens/`) uygulamaya PAKETLENMEZ;
/// yalnız karşılaştırma referansıdır.
abstract final class V21Assets {
  static const String _root = 'assets/v21';

  /// MASKOT Efsane Kaptan: ana sayfa görseli (stadyum + maskot)
  static const String homeHero = '$_root/illustrations/home_hero_stadium.png';

  /// MASKOT: zafer ekranı (kenarları ekranda yumuşatılır)
  static const String victoryMascot = '$_root/illustrations/victory_mascot.png';

  /// MASKOT: giriş ve kayıt ekranı görseli
  static const String loginHeroes = '$_root/illustrations/login_heroes.png';

  /// MASKOT: yükleme ekranı (logo, maskot ve stadyum tek görselde, 380×679)
  static const String loadingSplash = '$_root/illustrations/loading_splash.webp';

  /// Altın sandık (saydam zemin). home.png 2. yuva.
  static const String chestGold = '$_root/icons/chest_gold.png';

  /// Büyük altın sandık (saydam zemin, 138×112). chests.png Gümüş yuvası.
  /// 60 px üstü kullanımlarda (sandık kartı, ödül kartı) bulanıklaşmasın.
  static const String chestGoldLarge = '$_root/icons/chest_gold_large.png';

  /// Alt menü "ARENA" stadyum rozeti (daire kırpılır)
  static const String navArenaStadium = '$_root/icons/nav_arena_stadium.png';

  /// Bütün paketlenen V2.1 görselleri (önbelleğe alma ve testler için)
  static const List<String> all = [
    homeHero,
    victoryMascot,
    loginHeroes,
    loadingSplash,
    chestGold,
    chestGoldLarge,
    navArenaStadium,
  ];
}
