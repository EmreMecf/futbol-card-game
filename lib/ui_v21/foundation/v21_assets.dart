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

  /// Ana sayfa kahraman görseli: stadyum + maskot "Efsane Kaptan".
  /// home.png (0,146)–(390,558). Arayüz öğesi içermez.
  static const String homeHero = '$_root/illustrations/home_hero_stadium.png';

  /// Zafer ekranı maskotu (win.png 50,100–350,388; kenarları ekranda
  /// radyal olarak yumuşatılır)
  static const String victoryMascot = '$_root/illustrations/victory_mascot.png';

  /// Açılış/giriş kahramanları (login.png 0,150–390,438; logo yazısı
  /// kodla çizilir, kırpımda yok)
  static const String loginHeroes = '$_root/illustrations/login_heroes.png';

  /// Altın sandık (saydam zemin). home.png 2. yuva.
  static const String chestGold = '$_root/icons/chest_gold.png';

  /// Büyük altın sandık (saydam zemin, 138×112). chests.png Gümüş yuvası.
  /// 60 px üstü kullanımlarda (sandık kartı, ödül kartı) bulanıklaşmasın.
  static const String chestGoldLarge = '$_root/icons/chest_gold_large.png';

  /// Alt menü "KADRO" portresi (daire kırpılır)
  static const String navSquadPortrait = '$_root/icons/nav_squad_portrait.png';

  /// Alt menü "ARENA" stadyum rozeti (daire kırpılır)
  static const String navArenaStadium = '$_root/icons/nav_arena_stadium.png';

  /// Bütün paketlenen V2.1 görselleri (önbelleğe alma ve testler için)
  static const List<String> all = [
    homeHero,
    victoryMascot,
    loginHeroes,
    chestGold,
    chestGoldLarge,
    navSquadPortrait,
    navArenaStadium,
  ];
}
