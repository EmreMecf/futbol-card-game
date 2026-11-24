import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/chests/presentation/viewmodel/chests_view_model.dart';
import 'package:futbol_card/features/home/presentation/viewmodel/home_view_model.dart';
import 'package:futbol_card/features/season/presentation/viewmodel/season_view_model.dart';
import 'package:futbol_card/ui_v21/screens/home/v21_home_screen.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/sahte_sezon.dart';
import '../goldens/sahte_veri.dart';
import 'v21_compare.dart';
import 'v21_test_support.dart';

/// V2.1 ANA SAYFA — gerçek ViewModel'ler + sahte depolar.
///
/// Sahte depolar referans ekrandaki örnek veriyi döndürür (testoyuncu,
/// 2.450 altın, Master 2 / 1.825, 1:23:45 sayaçlı sandık, kademe 12) ki
/// Flutter çıktısı `assets/v21/screens/home.png` ile yan yana
/// karşılaştırılabilsin. Uygulama her zaman sunucu verisini gösterir.
void main() {
  final skipGolden = v21GoldenSkipReason;
  late SessionManager session;
  late GoldenChestRepo chests;

  // Sahte sunucu saati (sayaç testi ilerletir)
  var now = kGoldenServerTime;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await loadV21Fonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = kGoldenServerTime;
    await getIt.reset();
    session = await goldenSession();
    chests = GoldenChestRepo();
    final season = GoldenSeasonRepo()..sezon = goldenSeason(xp: 12600);
    getIt
      ..registerFactory<HomeViewModel>(
        () => HomeViewModel(GoldenLeaderboardRepo(), GoldenMatchRepo(), GoldenDeckRepo()),
      )
      ..registerFactory<ChestsViewModel>(() => ChestsViewModel(chests, clock: () => now))
      ..registerFactory<SeasonViewModel>(() => SeasonViewModel(season));
  });

  Future<void> pumpHome(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ChangeNotifierProvider<SessionManager>.value(
        value: session,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const RepaintBoundary(key: Key('screen'), child: V21HomeScreen()),
        ),
      ),
    );
    // Görsel çözümleme + veri yükleme + giriş animasyonları
    await t.runAsync(() async {
      for (final a in V21Assets.all) {
        await precacheImage(AssetImage(a), t.element(find.byType(V21HomeScreen)));
      }
    });
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester t) async {
    // Sayaç zamanlayıcısı kapansın
    await t.pumpWidget(const SizedBox.shrink());
  }

  group('V2.1 ana sayfa: sunucu verisi', () {
    testWidgets('başlık, lig, düğme, sandık ve menü gerçek veriyi gösterir', (t) async {
      await pumpHome(t, const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('testoyuncu'), findsOneWidget);
      expect(find.text('2.450'), findsOneWidget, reason: 'altın SessionManager.user.coins');
      expect(find.text('M2'), findsOneWidget, reason: 'lig kodu PlayerRank (master, 2)');
      expect(find.text('MASTER 2'), findsOneWidget);
      expect(find.text('1.825'), findsOneWidget, reason: 'MMR');
      expect(find.text('12'), findsOneWidget, reason: 'sezon kademesi (xp 12600 / 1000)');
      expect(find.text('MAÇA BAŞLA'), findsOneWidget);
      // Sandıklar: sunucu saatine göre sayaç, kilitli süreler, boş yuva
      expect(find.text('AÇILIYOR'), findsOneWidget);
      expect(find.text('1:23:45'), findsOneWidget);
      expect(find.text('ALTIN'), findsOneWidget);
      expect(find.text('6 sa'), findsOneWidget);
      expect(find.text('EFSANE'), findsOneWidget);
      expect(find.text('12 sa'), findsOneWidget);
      expect(find.bySemanticsLabel('Sandık yuvası 3 boş'), findsOneWidget);
      for (final l in ['KARTLAR', 'KADRO', 'ARENA', 'MAĞAZA', 'SEZON']) {
        expect(find.text(l), findsOneWidget);
      }
      await unmount(t);
    });

    testWidgets('sayaç sunucu saatiyle geri sayar', (t) async {
      await pumpHome(t, const Size(390, 844));
      expect(find.text('1:23:45'), findsOneWidget);
      now = now.add(const Duration(seconds: 5));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('1:23:40'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('ekonomi kapalıysa sandık şeridi hiç çizilmez (uydurma yuva yok)', (t) async {
      chests.inventory = kGoldenChestInventory.copyWith(enabled: false);
      await pumpHome(t, const Size(390, 844));
      expect(find.byType(V21ChestSlot), findsNothing);
      expect(find.text('MAÇA BAŞLA'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('lig yüklenemezse yer tutucu, sayı uydurulmaz', (t) async {
      await getIt.unregister<HomeViewModel>();
      getIt.registerFactory<HomeViewModel>(() => HomeViewModel(_FailingRank(), GoldenMatchRepo()));
      await pumpHome(t, const Size(390, 844));
      expect(find.text('MASTER 2'), findsNothing);
      expect(find.text('1.825'), findsNothing);
      expect(find.text('LİG'), findsOneWidget);
      await unmount(t);
    });
  });

  group('V2.1 ana sayfa: duyarlı yerleşim', () {
    for (final size in kV21AllSizes) {
      testWidgets('${v21SizeName(size)} taşmaz', (t) async {
        await pumpHome(t, size);
        expect(t.takeException(), isNull, reason: 'RenderFlex taşması olmamalı');
        // Web tasarımı ayrı yerleşimdir: burada yalnız taşma denetlenir
        if (size.width >= 1100 && size.height >= 600) {
          expect(find.text('SANDIKLAR'), findsOneWidget);
          await unmount(t);
          return;
        }
        // Ana eylem ve menü her boyutta görünür ve ekran içinde
        final button = t.getRect(find.byType(V21GameButton));
        expect(button.bottom, lessThanOrEqualTo(size.height));
        expect(button.height, greaterThanOrEqualTo(48), reason: 'dokunma hedefi');
        expect(find.byType(V21Scale.forSize(size).isExpanded ? V21SideNavigation : V21BottomNavigation), findsOneWidget);
        await unmount(t);
      });

      testWidgets('${v21SizeName(size)} golden', (t) async {
        await pumpHome(t, size);
        await expectLater(
          find.byKey(const Key('screen')),
          matchesGoldenFile('goldens/v21_home_${v21SizeName(size)}.png'),
        );
        await unmount(t);
      }, skip: skipGolden != null || !v21GoldenFor(size));
    }
  });

  testWidgets('390×844 referans karşılaştırması (fark raporu)', (t) async {
    await pumpHome(t, const Size(390, 844));
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(const Key('screen')));
    final report = await t.runAsync(
      () => compareWithReference(
        boundary,
        screen: 'home',
        title: 'ana sayfa',
        regions: const {
          'header (0-60)': (0, 60),
          'league (60-146)': (60, 146),
          'hero (146-558)': (146, 558),
          'button (558-646)': (558, 646),
          'chests (646-760)': (646, 760),
          'nav (760-844)': (760, 844),
        },
      ),
    );
    // Rapor dosyaya yazılır; eşik: ana bölgelerin ortalama farkı makul olmalı
    expect(report, isNotNull);
    expect(report!['overall']!, lessThan(60), reason: 'ortalama kanal farkı (0-255)');
    await unmount(t);
  }, skip: skipGolden != null);
}

class _FailingRank extends GoldenLeaderboardRepo {
  @override
  Future<Result<PlayerRank>> fetchMyRank() async => const Failure(AppException.network());
}
