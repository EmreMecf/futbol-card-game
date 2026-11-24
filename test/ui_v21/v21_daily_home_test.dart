import 'package:material_ui/material_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/chests/presentation/viewmodel/chests_view_model.dart';
import 'package:futbol_card/features/chests/domain/chest_texts.dart' show chestInventoryChanged;
import 'package:futbol_card/features/daily/data/daily_service.dart';
import 'package:futbol_card/features/home/presentation/viewmodel/home_view_model.dart';
import 'package:futbol_card/features/season/presentation/viewmodel/season_view_model.dart';
import 'package:futbol_card/ui_v21/screens/home/v21_home_screen.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/sahte_sezon.dart';
import '../goldens/sahte_veri.dart';
import 'v21_test_support.dart';

/// Sunucuya gitmeyen günlük döngü servisi
class _SahteGunluk implements DailyLoopService {
  DailyStatus durum = const DailyStatus(enabled: true, streak: 2, chestType: 'silver');
  int alma = 0;

  @override
  Future<DailyStatus?> status() async => durum;

  @override
  Future<Map<String, dynamic>> claim() async {
    alma++;
    durum = durum.copyWith(claimedToday: true, streak: 3);
    return {'chest_type': 'silver'};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// V2.1 ana sayfada günlük sandık şeridi: görünür, alınır, hiçbir boyutta taşmaz.
void main() {
  late SessionManager session;
  late _SahteGunluk gunluk;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await loadV21Fonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    session = await goldenSession();
    gunluk = _SahteGunluk();
    final sezon = GoldenSeasonRepo()..sezon = goldenSeason(xp: 12600);
    final sandik = GoldenChestRepo();
    getIt
      ..registerFactory<HomeViewModel>(
        () => HomeViewModel(GoldenLeaderboardRepo(), GoldenMatchRepo(), GoldenDeckRepo()),
      )
      ..registerFactory<ChestsViewModel>(() => ChestsViewModel(sandik, clock: () => kGoldenServerTime))
      ..registerFactory<SeasonViewModel>(() => SeasonViewModel(sezon))
      ..registerSingleton<DailyLoopService>(gunluk);
  });

  Future<void> kur(WidgetTester t, Size boyut) async {
    t.view.physicalSize = boyut;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ChangeNotifierProvider<SessionManager>.value(
        value: session,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: const RepaintBoundary(key: Key('ekran'), child: V21HomeScreen()),
        ),
      ),
    );
    await t.runAsync(() async {
      for (final a in V21Assets.all) {
        await precacheImage(AssetImage(a), t.element(find.byType(V21HomeScreen)));
      }
    });
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  for (final boyut in kV21AllSizes) {
    testWidgets('günlük şerit ${v21SizeName(boyut)} taşmaz', (t) async {
      await kur(t, boyut);
      expect(t.takeException(), isNull);
      // Web tasarımında günlük sandık Sandıklar başlığındadır
      final web = boyut.width >= 1100 && boyut.height >= 600;
      expect(find.text(web ? 'GÜNLÜK SANDIK AL' : 'Gümüş sandık hazır · Seri 2'), findsOneWidget);
      if (!web) expect(find.text('MAÇA BAŞLA'), findsOneWidget);
      await expectLater(
        find.byKey(const Key('ekran')),
        matchesGoldenFile('goldens/v21_home_daily_${v21SizeName(boyut)}.png'),
        skip: v21GoldenSkipReason != null || !v21GoldenFor(boyut),
      );
      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('AL: sandık alınır, sandık bölümü yenilenir, düğme kalkar', (t) async {
    await kur(t, const Size(390, 844));
    final once = chestInventoryChanged.value;
    await t.tap(find.text('AL'));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(gunluk.alma, 1);
    expect(chestInventoryChanged.value, once + 1);
    expect(find.text('Sandık alındı · Seri 3'), findsOneWidget);
    expect(find.text('AL'), findsNothing);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 5));
  });
}
