import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/l10n/app_language.dart';
import 'package:futbol_card/core/l10n/language_rebuilder.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/core/storage/favorites_store.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/chests/presentation/viewmodel/chests_view_model.dart';
import 'package:futbol_card/features/items/domain/items_repository.dart';
import 'package:futbol_card/features/items/presentation/viewmodel/items_view_model.dart';
import 'package:futbol_card/features/leaderboard/presentation/viewmodel/league_tiers_view_model.dart';
import 'package:futbol_card/features/profile/presentation/viewmodel/profile_view_model.dart';
import 'package:futbol_card/features/progress/presentation/viewmodel/progress_view_model.dart';
import 'package:futbol_card/features/sbc/presentation/viewmodel/sbc_list_view_model.dart';
import 'package:futbol_card/features/settings/presentation/viewmodel/settings_view_model.dart';
import 'package:futbol_card/ui_v21/screens/inner/v21_inner_screens.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/sahte_item.dart';
import '../goldens/sahte_veri.dart';
import 'v21_compare.dart';
import 'v21_test_support.dart';

/// FAZ 4 — geri düğmeli iç ekranlar. Gerçek ViewModel'ler + sahte depolar.

/// Kupa yolu (043): Usta ve Master girişleri alındı, Master Class kilitli
const _road = TrophyRoad(
  enabled: true,
  currentTier: 8,
  bestTier: 8,
  tiers: [
    TrophyRoadTier(tierId: 1, leagueCode: 'amateur', status: 'reached_before'),
    TrophyRoadTier(
      tierId: 4,
      leagueCode: 'usta',
      reward: {'chest': 'gold', 'cosmetic': 'frame_usta'},
      status: 'granted',
    ),
    TrophyRoadTier(
      tierId: 7,
      leagueCode: 'master',
      reward: {'chest': 'gold', 'cosmetic': 'frame_master'},
      status: 'granted',
    ),
    TrophyRoadTier(
      tierId: 10,
      leagueCode: 'master_class',
      reward: {'chest': 'legend', 'cosmetic': 'frame_mc'},
      status: 'locked',
    ),
  ],
);

void main() {
  final skipGolden = v21GoldenSkipReason;
  late SessionManager session;
  late GoldenItemsRepo items;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await loadV21Fonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    session = await goldenSession();
    items = GoldenItemsRepo();
    getIt
      ..registerSingleton<ItemsRepository>(items)
      ..registerFactory<ChestsViewModel>(
        () => ChestsViewModel(GoldenChestRepo(), items: items, clock: () => kGoldenServerTime),
      )
      ..registerFactory<LeagueTiersViewModel>(
        () => LeagueTiersViewModel(GoldenLeaderboardRepo(), trophyRoad: () async => _road),
      )
      ..registerFactory<ProgressViewModel>(() => ProgressViewModel(GoldenProgressRepo(), session: session))
      ..registerFactory<ItemsViewModel>(() => ItemsViewModel(items))
      ..registerFactory<ProfileViewModel>(
        () => ProfileViewModel(
          GoldenMatchRepo(),
          GoldenAuthRepo(),
          GoldenLeaderboardRepo(),
          session,
          collectionRepository: GoldenCollectionRepo(),
          favorites: FavoritesStore(),
        ),
      )
      ..registerLazySingleton<SettingsViewModel>(SettingsViewModel.new)
      ..registerFactory<SbcListViewModel>(() => SbcListViewModel(GoldenSbcRepo()));
    await getIt<SettingsViewModel>().load();
  });

  Future<void> pump(WidgetTester t, Widget screen, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ChangeNotifierProvider<SessionManager>.value(
        value: session,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: RepaintBoundary(key: const Key('screen'), child: screen),
        ),
      ),
    );
    await t.runAsync(() async {
      for (final a in V21Assets.all) {
        await precacheImage(AssetImage(a), t.binding.rootElement!);
      }
    });
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester t) => t.pumpWidget(const SizedBox.shrink());

  Future<void> openDialog(WidgetTester t, Finder f) async {
    await t.tap(f);
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  // ------------------------------------------------------------------
  group('Sandıklar', () {
    testWidgets('sandık hakkı, yuvalar, hemen aç, posta kutusu', (t) async {
      await pump(t, const V21ChestsScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('7/10'), findsOneWidget);
      expect(find.text("Her 96 dk'da 1 hak yenilenir · sonraki 41 dk"), findsOneWidget);
      expect(find.text('GÜMÜŞ SANDIK'), findsOneWidget);
      expect(find.text('1:23:45'), findsOneWidget);
      expect(find.text('6 sa'), findsOneWidget);
      expect(find.text('BOŞ YUVA'), findsOneWidget);
      expect(find.text('BRONZ SANDIK'), findsOneWidget, reason: 'hemen açılabilen');
      expect(find.text('AÇ!'), findsOneWidget);
      final nav = t.widget<V21BottomNavigation>(find.byType(V21BottomNavigation));
      expect(nav.items[nav.activeIndex].label, 'ARENA');
      await unmount(t);
    });

    testWidgets('anahtar varken kilitli sandık seçenek diyaloğu açar', (t) async {
      await pump(t, const V21ChestsScreen(), const Size(390, 844));
      await openDialog(t, find.bySemanticsLabel(RegExp(r'^ALTIN SANDIK kilitli')));
      expect(find.textContaining('ANAHTARLA AÇ'), findsOneWidget);
      expect(find.textContaining('KİLİDİ AÇ'), findsNothing, reason: 'başka sandığın sayacı çalışıyor');
      await t.tap(find.text('VAZGEÇ'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Lig Yolu', () {
    testWidgets('ligler yukarıdan aşağı; oyuncunun ligi, geçilen ve kilitli ligler', (t) async {
      await pump(t, const V21LeagueScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('LİG YOLU'), findsOneWidget);
      expect(find.text('SEN · M2'), findsOneWidget);
      expect(find.text('1.825'), findsOneWidget, reason: 'kupa hapı');
      expect(find.bySemanticsLabel(RegExp(r'^MASTER CLASS, .*kilitli$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^MASTER, .*şu an bu ligdesin$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^USTA, .*ödül Altın sandık · çerçeve, alındı, geçildi$')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^AMATÖR, .*geçildi$')), findsOneWidget);
      final top = t.getTopLeft(find.text('MASTER CLASS')).dy;
      final bottom = t.getTopLeft(find.text('AMATÖR')).dy;
      expect(top, lessThan(bottom), reason: 'en yüksek lig üstte');
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Gelişim', () {
    testWidgets('joker parçalar, seviyeler, ana eylem düğmeleri', (t) async {
      await pump(t, const V21ProgressScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('JOKER PARÇALAR'), findsOneWidget);
      expect(find.text('SEVİYE 3'), findsOneWidget);
      expect(find.text('SEVİYE ATLA'), findsOneWidget);
      expect(find.text('JOKERLE ATLA'), findsOneWidget);
      await t.drag(find.byType(ListView).first, const Offset(0, -1600));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('SEVİYE 10'), findsOneWidget);
      expect(find.text('EN YÜKSEK SEVİYE '), findsOneWidget);
      await unmount(t);
    });

    testWidgets('SEVİYE ATLA: kutlama penceresi çıkar, kopya sayısı yazılır', (t) async {
      await getIt.unregister<ProgressViewModel>();
      getIt.registerFactory<ProgressViewModel>(() => ProgressViewModel(_AtlayanDepo(), session: session));
      await pump(t, const V21ProgressScreen(), const Size(390, 844));
      expect(find.text('2/2'), findsWidgets, reason: 'kopya ilerlemesi sayıyla görünür');
      await t.tap(find.text('SEVİYE ATLA'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('SEVİYE 4!'), findsOneWidget);
      expect(find.textContaining('250 altın harcandı'), findsOneWidget);
      await t.tap(find.text('HARİKA'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('SEVİYE 4!'), findsNothing);
      expect(t.takeException(), isNull);
      await unmount(t);
    });

    testWidgets('kopya dönüştürme geri alınamaz: açık onay ister, vazgeçince sunucuya gitmez', (t) async {
      await pump(t, const V21ProgressScreen(), const Size(390, 844));
      final more = find.bySemanticsLabel(RegExp(r'Genç Yetenek: diğer seçenekler'));
      await t.scrollUntilVisible(more, 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(more);
      await t.pump(const Duration(milliseconds: 100));
      await openDialog(t, more);
      await t.tap(find.text('2 KOPYAYI ÇEVİR'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KOPYALAR ÇEVRİLSİN Mİ?'), findsOneWidget);
      expect(find.textContaining('GERİ ALINAMAZ'), findsWidgets);
      await t.tap(find.text('VAZGEÇ'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KOPYALAR ÇEVRİLSİN Mİ?'), findsNothing);
      expect(t.takeException(), isNull, reason: 'sahte depoda convert yok: çağrılsaydı hata verirdi');
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Envanter', () {
    testWidgets('eşya karoları, adetler, KULLAN / GİY / ÇIKAR ve ayrıntı', (t) async {
      await pump(t, const V21InventoryScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('Sandık anahtarı'), findsOneWidget);
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('KULLAN'), findsOneWidget, reason: 'enerji içeceği');
      await t.scrollUntilVisible(find.text('ÇIKAR'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('GİYİLİ'), findsOneWidget);
      await openDialog(t, find.bySemanticsLabel(RegExp(r'^Sandık anahtarı, 3 adet')));
      expect(find.textContaining('Yuvadaki bir sandığın kilidini'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('KULLAN sunucuya gider', (t) async {
      await pump(t, const V21InventoryScreen(), const Size(390, 844));
      await t.tap(find.text('KULLAN'));
      await t.pump(const Duration(milliseconds: 300));
      expect(items.kullanilan, contains('energy_drink'));
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Profil', () {
    testWidgets('kimlik, istatistikler, başarımlar, AYARLAR', (t) async {
      await pump(t, const V21ProfileScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('testoyuncu'), findsOneWidget);
      expect(find.text('MASTER 2'), findsOneWidget);
      expect(find.text('24G · 9M · 2B'), findsOneWidget);
      expect(find.text('1.825'), findsOneWidget);
      expect(find.text('2.450'), findsOneWidget);
      expect(find.textContaining('BAŞARIMLAR'), findsOneWidget);
      expect(find.text('AYARLAR'), findsOneWidget);
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Ayarlar', () {
    testWidgets('anahtarlar ayarı değiştirir; ses ve müzik pasif; alt menü yok', (t) async {
      await pump(t, const V21SettingsScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.byType(V21BottomNavigation), findsNothing);
      expect(find.text('YAKINDA'), findsNWidgets(2));
      final vm = getIt<SettingsViewModel>();
      final before = vm.vibration;
      await t.tap(find.bySemanticsLabel('Titreşim'));
      await t.pump(const Duration(milliseconds: 300));
      expect(vm.vibration, !before);
      final sound = t.getSemantics(find.bySemanticsLabel('Ses efektleri, yakında'));
      expect(sound.flagsCollection.isEnabled.name, 'isFalse');
      await unmount(t);
    });

    testWidgets('DİL: English seçilince ekran İngilizceye, Türkçe seçilince geri döner', (t) async {
      addTearDown(() => AppLanguageController.instance.value = AppLanguage.tr);
      await pump(t, const LanguageRebuilder(child: V21SettingsScreen()), const Size(390, 844));
      expect(find.text('AYARLAR'), findsWidgets);
      final english = find.byKey(const ValueKey('dil-en'));
      await t.scrollUntilVisible(english, 200, scrollable: find.byType(Scrollable).first);
      await t.tap(english);
      await t.pump(const Duration(milliseconds: 300));
      expect(AppLanguageController.instance.value, AppLanguage.en);
      expect(find.text('SETTINGS'), findsWidgets);
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.text('AYARLAR'), findsNothing);
      // Seçim cihazda saklanır
      final depo = await SharedPreferences.getInstance();
      expect(depo.getString(AppLanguageController.prefsKey), 'en');

      await t.tap(find.byKey(const ValueKey('dil-tr')));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('AYARLAR'), findsWidgets);
      expect(find.text('DİL'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('çıkış onay ister', (t) async {
      await pump(t, const V21SettingsScreen(), const Size(390, 844));
      await t.scrollUntilVisible(find.text('ÇIKIŞ YAP'), 200, scrollable: find.byType(Scrollable).first);
      await openDialog(t, find.text('ÇIKIŞ YAP'));
      expect(find.text('ÇIKIŞ YAPILSIN MI?'), findsOneWidget);
      await t.tap(find.text('VAZGEÇ'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(session.isSignedIn || session.user != null, isTrue, reason: 'oturum açık kaldı');
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Kart Takası', () {
    testWidgets('afiş, görev kartları, ödül kutusu ve uyarı', (t) async {
      await pump(t, const V21SbcScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.textContaining('Kullanmadığın kartları ver'), findsOneWidget);
      expect(find.text(V21Format.upper(kGoldenChallenges.first.name)), findsOneWidget);
      expect(find.text('BAŞLA'), findsWidgets);
      await t.scrollUntilVisible(
        find.text('Verilen kartlar kalıcı olarak silinir'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  final screens = <String, Widget Function()>{
    'chests': () => const V21ChestsScreen(),
    'league': () => const V21LeagueScreen(),
    'progress': () => const V21ProgressScreen(),
    'inventory': () => const V21InventoryScreen(),
    'profile': () => const V21ProfileScreen(),
    'settings': () => const V21SettingsScreen(),
    'sbc': () => const V21SbcScreen(),
  };

  group('duyarlı yerleşim + golden', () {
    for (final e in screens.entries) {
      for (final size in kV21AllSizes) {
        testWidgets('${e.key} ${v21SizeName(size)}', (t) async {
          await pump(t, e.value(), size);
          expect(t.takeException(), isNull, reason: 'taşma olmamalı');
          if (skipGolden == null && v21GoldenFor(size)) {
            await expectLater(
              find.byKey(const Key('screen')),
              matchesGoldenFile('goldens/v21_${e.key}_${v21SizeName(size)}.png'),
            );
          }
          await unmount(t);
        });
      }
    }
  });

  group('390×844 referans karşılaştırması', () {
    const regions = {
      'başlık (0-70)': (0, 70),
      'üst içerik (70-420)': (70, 420),
      'alt içerik (420-760)': (420, 760),
      'menü (760-844)': (760, 844),
    };
    const titles = {
      'chests': 'Sandıklar',
      'league': 'Lig Yolu',
      'progress': 'Gelişim',
      'inventory': 'Envanter',
      'profile': 'Profil',
      'settings': 'Ayarlar',
      'sbc': 'Kart Takası',
    };
    for (final e in screens.entries) {
      testWidgets(titles[e.key]!, (t) async {
        await pump(t, e.value(), const Size(390, 844));
        final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(const Key('screen')));
        final r = await t.runAsync(
          () => compareWithReference(boundary, screen: e.key, title: titles[e.key]!, regions: regions),
        );
        expect(r!['overall']!, lessThan(75));
        await unmount(t);
      }, skip: skipGolden != null);
    }
  });
}
/// Seviye atlamayı kabul eden sahte gelişim deposu
class _AtlayanDepo extends GoldenProgressRepo {
  @override
  Future<Result<LevelUpResult>> levelUp(String cardId,
          {required bool useJokers, bool useDiscount = false, required String idempotencyKey}) async =>
      Success(LevelUpResult(
        cardId: cardId,
        level: 4,
        coinsSpent: 250,
        coinsAfter: 2200,
        next: const LevelCost(copies: 3, coins: 400),
      ));
}
