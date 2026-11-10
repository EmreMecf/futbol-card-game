import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/chests/domain/chest_repository.dart';
import 'package:futbol_card/features/chests/presentation/view/chest_odds_view.dart';
import 'package:futbol_card/features/chests/presentation/view/chest_open_view.dart';
import 'package:futbol_card/features/chests/presentation/view/chests_view.dart';
import 'package:futbol_card/features/chests/presentation/viewmodel/chests_view_model.dart';
import 'package:futbol_card/features/deck/presentation/view/deck_view.dart';
import 'package:futbol_card/features/deck/presentation/viewmodel/deck_view_model.dart';
import 'package:futbol_card/features/home/presentation/view/home_view.dart';
import 'package:futbol_card/features/home/presentation/viewmodel/home_view_model.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:futbol_card/features/match/presentation/widgets/match_result_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_veri.dart';

/// EKONOMİ V2 FAZ 1 — sandık ekranları (6 boyut, taşma denetimli) ve
/// mevcut ekranlara eklenen bölümler (ana sayfa şeridi, maç sonu
/// sandığı, kadro ekranında acil kadro).
void main() {
  final atla = goldenSkipReason;
  late SessionManager oturum;
  late GoldenChestRepo depo;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    if (atla == null) await loadGoldenFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    oturum = await goldenSession();
    depo = GoldenChestRepo();
    getIt
      ..registerSingleton<ChestRepository>(depo)
      // Sabit saat: sayaç (1:23:45) makine yükünden bağımsız, kararlı
      ..registerFactory<ChestsViewModel>(() => ChestsViewModel(depo, session: oturum, clock: () => kGoldenServerTime))
      ..registerFactory<HomeViewModel>(
          () => HomeViewModel(GoldenLeaderboardRepo(), GoldenMatchRepo(), GoldenDeckRepo()))
      ..registerFactory<DeckViewModel>(() => DeckViewModel(GoldenDeckRepo()));
  });

  Future<void> ac(WidgetTester t, Widget ekran, Size boyut, {int kare = 10}) async {
    t.view.physicalSize = boyut;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ChangeNotifierProvider<SessionManager>.value(
      value: oturum,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: RepaintBoundary(key: const Key('ekran'), child: ekran),
      ),
    ));
    for (var i = 0; i < kare; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esle(WidgetTester t, String ad) =>
      expectLater(find.byKey(const Key('ekran')), matchesGoldenFile('ekranlar/$ad.png'));

  final ekranlar = <String, Widget Function()>{
    '20_sandiklar': () => const ChestsView(),
    '21_sandik_acilisi': () => ChestOpenView(result: kGoldenChestOpen, onClose: () {}),
    '22_olasiliklar': () => const ChestOddsView(),
  };

  for (final e in ekranlar.entries) {
    for (final boyut in kGoldenSizes) {
      testWidgets('${e.key} ${sizeName(boyut)} taşmaz', (t) async {
        await ac(t, e.value(), boyut, kare: 30);
        expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
        await esle(t, '${e.key}_${sizeName(boyut)}');
        await t.pumpWidget(const SizedBox());
      }, skip: atla != null);
    }
  }

  testWidgets('sandıklar: sayaç sunucu saatine göre, yuvalar ve posta', (t) async {
    await ac(t, const ChestsView(), const Size(390, 844));
    expect(find.text('1:23:45'), findsOneWidget, reason: 'kalan süre sunucu saatine göre');
    expect(find.text('GÜMÜŞ'), findsOneWidget);
    expect(find.text('BOŞ'), findsOneWidget, reason: '3. yuva boş');
    expect(find.text('7 / 10'), findsOneWidget, reason: 'ödül enerjisi');
    await t.scrollUntilVisible(find.text('YUVAYA TAŞI'), 300);
    expect(find.text('YUVAYA TAŞI'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('sandık açılışı: 3 kart ve sonuç rozetleri', (t) async {
    await ac(t, ChestOpenView(result: kGoldenChestOpen, onClose: () {}), const Size(390, 844), kare: 30);
    expect(find.text('YENİ'), findsOneWidget);
    expect(find.text('+1 GELİŞİM'), findsOneWidget);
    expect(find.text('KADRO KORUMASI'), findsOneWidget);
    expect(find.text('+104 altın'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  for (final boyut in [const Size(390, 844), const Size(320, 568), const Size(1366, 768)]) {
    testWidgets('ana sayfa sandık şeridi ${sizeName(boyut)}', (t) async {
      await ac(t, const HomeView(), boyut);
      expect(t.takeException(), isNull);
      // Masaüstünde kenar çubuğu da kaydırılabilir: içerik alanı (sonuncusu)
      await t.scrollUntilVisible(find.text('SANDIKLAR'), 300, scrollable: find.byType(Scrollable).last);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('1 SANDIK AÇILMAYA HAZIR'), findsOneWidget);
      await esle(t, '23_ana_sayfa_sandik_${sizeName(boyut)}');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);
  }

  for (final (ad, kaynak) in [
    ('24_mac_sonu_sandik', SourceChest(chest: goldenChest('mc', ChestTypes.silver, slot: 3))),
    ('24e_mac_sonu_enerji_yok', const SourceChest(skipped: 'no_energy')),
  ]) {
    testWidgets('$ad 390x844', (t) async {
      depo.matchChest = kaynak;
      await ac(
        t,
        MatchResultView(
          result: const MatchResultSummary(matchId: 'm', didIWin: true, myScore: 7, opponentScore: 4),
          rewardDelta: const MatchRewardDelta(coins: 100, rating: 25, protectionSlots: 1),
          onClose: () {},
          onNewMatch: () {},
        ),
        const Size(390, 844),
        kare: 20,
      );
      expect(t.takeException(), isNull);
      await t.scrollUntilVisible(find.text(kaynak.skippedNoEnergy ? 'Ödül enerjin bitmişti' : 'SANDIK KAZANDIN'), 200);
      await t.pump(const Duration(milliseconds: 300));
      await esle(t, '${ad}_390x844');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);
  }

  testWidgets('kadro ekranında acil kadro uyarısı 390x844', (t) async {
    await ac(t, const DeckView(), const Size(390, 844));
    // Sahte kadro tam; uyarı yalnız kadro eksikken görünür -> burada YOK
    expect(find.text('Kadron kurulamıyor'), findsNothing);
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);
}
