import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/home/presentation/view/home_view.dart';
import 'package:futbol_card/features/home/presentation/viewmodel/home_view_model.dart';
import 'package:futbol_card/features/season/domain/season_repository.dart';
import 'package:futbol_card/features/season/presentation/view/season_view.dart';
import 'package:futbol_card/features/season/presentation/viewmodel/season_view_model.dart';
import 'package:futbol_card/features/season/presentation/widgets/season_home_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_sezon.dart';
import 'sahte_veri.dart';

/// EKONOMİ V2 FAZ 4 — Sezon Yolu (6 boyut, taşma denetimli), ana sayfa
/// görev kartı, maç sonu XP satırı ve ödül alma davranışı.
void main() {
  final atla = goldenSkipReason;
  late SessionManager oturum;
  late GoldenSeasonRepo depo;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    if (atla == null) await loadGoldenFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    oturum = await goldenSession();
    depo = GoldenSeasonRepo();
    getIt
      ..registerSingleton<SeasonRepository>(depo)
      ..registerFactory<SeasonViewModel>(() => SeasonViewModel(depo))
      ..registerFactory<HomeViewModel>(
          () => HomeViewModel(GoldenLeaderboardRepo(), GoldenMatchRepo(), GoldenDeckRepo()));
  });

  Future<void> ac(WidgetTester t, Widget ekran, Size boyut) async {
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
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esle(WidgetTester t, String ad) =>
      expectLater(find.byKey(const Key('ekran')), matchesGoldenFile('ekranlar/$ad.png'));

  for (final boyut in kGoldenSizes) {
    testWidgets('29_sezon_yolu ${sizeName(boyut)} taşmaz', (t) async {
      await ac(t, const SeasonView(), boyut);
      expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
      expect(find.text('TÜMÜNÜ AL (3)'), findsOneWidget, reason: 'kademe 5-7 ücretsiz ödül');
      await esle(t, '29_sezon_yolu_${sizeName(boyut)}');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);
  }

  testWidgets('29b sezon yolu: ödül kademeleri 390x844', (t) async {
    await ac(t, const SeasonView(), const Size(390, 844));
    await t.scrollUntilVisible(find.text('ÖDÜL YOLU'), 400, scrollable: find.byType(Scrollable).last);
    await t.drag(find.byType(Scrollable).last, const Offset(0, -60));
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
    expect(find.text('PREMIUM (YAKINDA)'), findsOneWidget, reason: 'K4: satın alma yok');
    await esle(t, '29b_sezon_odul_yolu_390x844');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('sezon yolu: ödüle dokununca alınır; kilitli premium alınmaz', (t) async {
    await ac(t, const SeasonView(), const Size(390, 844));
    // Sayfanın üstüne hizala (alt menü çubuğunun altında kalmasın)
    await t.ensureVisible(find.text('DOKUN, AL').first);
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('DOKUN, AL').first);
    await t.pump(const Duration(milliseconds: 200));
    expect(depo.alinan, ['free:5']);
    expect(find.textContaining('5. kademe ödülü alındı'), findsOneWidget);
    // Premium hücreleri kilitli: dokunmak hiçbir şey göndermez
    await t.tap(find.text('KİLİTLİ').first, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 200));
    expect(depo.alinan, ['free:5']);
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('30 ana sayfa günlük görevler 390x844', (t) async {
    await ac(t, const HomeView(), const Size(390, 844));
    await t.scrollUntilVisible(find.text('SEZON YOLUNA GİT'), 300, scrollable: find.byType(Scrollable).last);
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    expect(find.text('1/3 TAMAM'), findsOneWidget);
    expect(find.text('Günlük görevler yakında'), findsNothing, reason: 'eski kart yerine gerçek görevler');
    await esle(t, '30_ana_sayfa_gorevler_390x844');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('31 maç sonu sezon XP satırı 390x844', (t) async {
    await ac(
        t,
        const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: [
              MatchSeasonXpLine(matchId: 'm', preview: MatchSeasonXp(xp: 100)),
              MatchSeasonXpLine(matchId: 'm2', preview: MatchSeasonXp(xp: 15, noEnergy: true)),
              MatchSeasonXpLine(matchId: 'm3', preview: MatchSeasonXp(xp: 0)),
            ]),
          ),
        ),
        const Size(390, 844));
    expect(find.text('+100 SEZON XP'), findsOneWidget);
    expect(find.text('+15 SEZON XP'), findsOneWidget);
    expect(find.textContaining('%25'), findsOneWidget);
    expect(find.text('+0 SEZON XP'), findsNothing, reason: 'kısa maçta yer kaplamaz');
    await esle(t, '31_mac_sonu_sezon_xp_390x844');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  test('ağ hatasında aynı anahtar; kural reddinde yeni anahtar', () async {
    final vm = SeasonViewModel(depo);
    await vm.load();
    final t5 = vm.overview!.tiers[4];
    depo.hatalar.add(const AppException.network());
    expect(await vm.claim(t5, 'free'), isFalse);
    expect(await vm.claim(t5, 'free'), isTrue);
    expect(depo.anahtarlar[0], depo.anahtarlar[1], reason: 'ağ hatası sonrası tekrar = aynı istek');

    final t6 = vm.overview!.tiers[5];
    depo.hatalar.add(const AppException(message: 'x', technicalDetail: 'tier_locked'));
    expect(await vm.claim(t6, 'free'), isFalse);
    expect(vm.actionError, 'Bu kademeye henüz ulaşmadın.');
    expect(await vm.claim(t6, 'free'), isTrue);
    expect(depo.anahtarlar[2], isNot(depo.anahtarlar[3]));
  });

  test('model: kademe ilerlemesi ve alınabilir ödül sayısı', () {
    final s = goldenSeason();
    expect(s.tier, 7);
    expect(s.xpToNext, 660);
    expect(s.tierProgress, closeTo(0.34, 0.001));
    expect(s.claimableCount, 3, reason: 'premium kilitli: yalnız ücretsiz 5-7');
    expect(goldenSeason(premium: true).claimableCount, 10, reason: 'premium 1-7 + ücretsiz 5-7');
    expect(goldenSeason(xp: 60000).isMaxed, isTrue);
  });
}
