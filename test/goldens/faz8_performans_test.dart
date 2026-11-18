import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/storage/favorites_store.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/auth/presentation/view/login_view.dart';
import 'package:futbol_card/features/auth/presentation/view/register_view.dart';
import 'package:futbol_card/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:futbol_card/features/collection/presentation/view/collection_view.dart';
import 'package:futbol_card/features/collection/presentation/viewmodel/collection_view_model.dart';
import 'package:futbol_card/features/deck/presentation/view/deck_view.dart';
import 'package:futbol_card/features/deck/presentation/viewmodel/deck_view_model.dart';
import 'package:futbol_card/features/home/presentation/view/home_view.dart';
import 'package:futbol_card/features/home/presentation/viewmodel/home_view_model.dart';
import 'package:futbol_card/features/leaderboard/presentation/view/leaderboard_view.dart';
import 'package:futbol_card/features/leaderboard/presentation/view/league_tiers_view.dart';
import 'package:futbol_card/features/leaderboard/presentation/viewmodel/leaderboard_view_model.dart';
import 'package:futbol_card/features/leaderboard/presentation/viewmodel/league_tiers_view_model.dart';
import 'package:futbol_card/features/match/presentation/view/match_view.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:futbol_card/features/matchmaking/presentation/view/matchmaking_view.dart';
import 'package:futbol_card/features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import 'package:futbol_card/features/profile/presentation/view/profile_view.dart';
import 'package:futbol_card/features/profile/presentation/viewmodel/profile_view_model.dart';
import 'package:futbol_card/features/sbc/presentation/view/sbc_list_view.dart';
import 'package:futbol_card/features/sbc/presentation/viewmodel/sbc_list_view_model.dart';
import 'package:futbol_card/features/settings/presentation/view/settings_view.dart';
import 'package:futbol_card/features/settings/presentation/viewmodel/settings_view_model.dart';
import 'package:futbol_card/features/store/presentation/view/store_view.dart';
import 'package:futbol_card/features/store/presentation/viewmodel/store_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_veri.dart';

/// FAZ 8 — performans ve büyük yazı denetimi (bütün ana ekranlar).
///
/// 1) BOŞTA KARE SAYISI
///    Ekran açılıp giriş hareketi bittikten sonra hâlâ kare isteyen
///    (sürekli dönen) animasyon var mı? `transientCallbackCount` her
///    karede çalışacak animasyon sayısıdır. Ayarlardan "Kart
///    animasyonları" KAPALIYKEN bütün ekranlar tamamen durmalı (0):
///    düşük donanımlı telefonda pil ve akıcılık için.
///    Açıkken yalnız bilerek hareketli olanlar çalışır (Efsane kart
///    ışığı, stadyumdaki oyuncular).
///
/// 2) BÜYÜK YAZI (%130) + EN DAR TELEFON (320×568)
///    Erişilebilirlik ayarında yazıyı büyüten oyuncuda hiçbir ekran
///    taşmamalı.
void main() {
  final atla = goldenSkipReason;
  late SessionManager oturum;
  late SettingsViewModel ayar;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    if (atla == null) await loadGoldenFonts();
  });

  Future<void> kur({required bool animasyon}) async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    oturum = await goldenSession();
    ayar = SettingsViewModel();
    await ayar.load();
    await ayar.setCardAnimations(animasyon);
    getIt
      ..registerSingleton<SettingsViewModel>(ayar)
      ..registerFactory<HomeViewModel>(
          () => HomeViewModel(GoldenLeaderboardRepo(), GoldenMatchRepo(), GoldenDeckRepo()))
      ..registerFactory<CollectionViewModel>(() => CollectionViewModel(GoldenCollectionRepo()))
      ..registerFactory<DeckViewModel>(() => DeckViewModel(GoldenDeckRepo()))
      ..registerFactory<StoreViewModel>(() => StoreViewModel(GoldenStoreRepo(), oturum))
      ..registerFactoryParam<MatchViewModel, String, void>(
          (id, _) => MatchViewModel(GoldenArenaRepo(), GoldenSocket(), oturum, matchId: id))
      ..registerFactory<MatchmakingViewModel>(
          () => MatchmakingViewModel(GoldenMatchmakingRepo(), GoldenSocket(), oturum))
      ..registerFactory<LeaderboardViewModel>(() => LeaderboardViewModel(GoldenLeaderboardRepo(), oturum))
      ..registerFactory<LeagueTiersViewModel>(() => LeagueTiersViewModel(GoldenLeaderboardRepo()))
      ..registerFactory<ProfileViewModel>(() => ProfileViewModel(
          GoldenMatchRepo(), GoldenAuthRepo(), GoldenLeaderboardRepo(), oturum,
          collectionRepository: GoldenCollectionRepo(), favorites: FavoritesStore()))
      ..registerFactory<SbcListViewModel>(() => SbcListViewModel(GoldenSbcRepo()));
  }

  Future<void> ac(WidgetTester t, Widget ekran, Size boyut, {double yazi = 1}) async {
    t.view.physicalSize = boyut;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionManager>.value(value: oturum),
        ChangeNotifierProvider<AuthViewModel>(create: (_) => AuthViewModel(GoldenAuthRepo())),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        builder: (context, cocuk) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(yazi)),
          child: cocuk!,
        ),
        home: ekran,
      ),
    ));
    // Veri yüklensin, sayfa giriş hareketleri bitsin
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  final ekranlar = <String, Widget Function()>{
    'Ana sayfa': () => const HomeView(),
    'Koleksiyon': () => const CollectionView(),
    'Kadro': () => const DeckView(forceLegacy: true),
    'Maç hazırlığı': () => const MatchmakingView(),
    'Arena (maç)': () => const MatchView(matchId: 'm'),
    'Mağaza': () => const StoreView(),
    'Ligler': () => const LeaderboardView(),
    'Lig basamakları': () => const LeagueTiersView(),
    'Profil': () => const ProfileView(),
    'Görevler': () => const SbcListView(),
    'Ayarlar': () => const SettingsView(),
    'Giriş': () => const LoginView(),
    'Kayıt': () => const RegisterView(),
  };

  // Açıkken bilerek hareketli olan ekranlar (ötekiler boşta durmalı)
  // Koleksiyon: görünen Efsane kartların ışığı; maç hazırlığı ve arena:
  // referans stadyumundaki oyuncuların salınımı (.pitch3d).
  const hareketliEkranlar = {'Koleksiyon', 'Maç hazırlığı', 'Arena (maç)'};

  group('Boşta kare (animasyonlar KAPALI)', () {
    for (final e in ekranlar.entries) {
      testWidgets('${e.key}: ekran tamamen durur', (t) async {
        await kur(animasyon: false);
        await ac(t, e.value(), const Size(390, 844));
        expect(t.takeException(), isNull);
        expect(t.binding.transientCallbackCount, 0,
            reason: '${e.key}: animasyonlar kapalıyken hâlâ her karede çizen bir animasyon var');
        await t.pumpWidget(const SizedBox());
      }, skip: atla != null);
    }
  });

  group('Boşta kare (animasyonlar AÇIK)', () {
    for (final e in ekranlar.entries) {
      testWidgets('${e.key}: yalnız bilerek hareketli ekranlar çizer', (t) async {
        await kur(animasyon: true);
        await ac(t, e.value(), const Size(390, 844));
        expect(t.takeException(), isNull);
        final sayi = t.binding.transientCallbackCount;
        // Rapor için (docs/REFERANS_SADAKAT_RAPORU.md FAZ 8 tablosu)
        debugPrint('BOSTA_ANIMASYON ${e.key}: $sayi');
        if (!hareketliEkranlar.contains(e.key)) {
          expect(sayi, 0, reason: '${e.key}: boştayken gereksiz animasyon');
        }
        await t.pumpWidget(const SizedBox());
      }, skip: atla != null);
    }
  });

  group('Büyük yazı %130, 320×568', () {
    for (final e in ekranlar.entries) {
      testWidgets('${e.key}: taşma yok', (t) async {
        await kur(animasyon: false);
        await ac(t, e.value(), const Size(320, 568), yazi: 1.3);
        expect(t.takeException(), isNull, reason: '${e.key}: %130 yazıda taşma');
        await t.pumpWidget(const SizedBox());
      }, skip: atla != null);
    }
  });

  // Walkout kartı jiroskop dinler; burada kullanılmıyor ama ekranlardan
  // biri açarsa test ortamı çökmesin.
  setUp(() {
    final ileti = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    ileti.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/sensors/method'), (_) async => null);
  });
}
