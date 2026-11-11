import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/chests/presentation/view/chest_open_view.dart';
import 'package:futbol_card/features/chests/presentation/widgets/match_chest_panel.dart';
import 'package:futbol_card/features/matchmaking/presentation/view/matchmaking_view.dart';
import 'package:futbol_card/features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_veri.dart';

/// EKONOMİ V2 — 037 (R1 / R2 / R3) ve 038 (item kaynakları) ekranları:
/// enerjisiz Bronz sandık + galibiyet gelişim kopyası, sandıktan ek item,
/// kart kaybı kapalıyken maç hazırlığı. Kurallar varsayılan KAPALI; bu
/// ekranlar yalnız sunucu yeni kuralla cevap verdiğinde görünür.
void main() {
  final atla = goldenSkipReason;
  late SessionManager oturum;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    if (atla == null) await loadGoldenFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    oturum = await goldenSession();
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

  testWidgets('36 maç sonu: enerjisiz Bronz sandık + galibiyet kopyası', (t) async {
    final bronz = goldenChest('mb', ChestTypes.bronze).copyWith(location: 'instant', status: ChestStatus.ready, slotNo: null);
    await ac(
        t,
        Scaffold(
          backgroundColor: const Color(0xFF08111F),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              MatchChestPanel(
                matchId: 'm',
                preview: SourceChest(
                    chest: bronz,
                    noEnergy: true,
                    winCopy: const {'card_id': 'c1', 'full_name': 'Arda Yılmaz', 'tier': 'gold', 'copies': 1}),
              ),
              // Eski kural, enerjisiz: sandık yok (karşılaştırma)
              const MatchChestPanel(matchId: 'm2', preview: SourceChest(skipped: 'no_energy')),
            ]),
          ),
        ),
        const Size(390, 520));
    expect(t.takeException(), isNull);
    expect(find.text('Ödül enerjin yoktu: Bronz sandık (hemen açılır)'), findsOneWidget);
    expect(find.text('+1 GELİŞİM KOPYASI: Arda Yılmaz'), findsOneWidget);
    expect(find.text('Ödül enerjin bitmişti'), findsOneWidget, reason: 'eski kural ekranı değişmedi');
    await esle(t, '36_mac_sonu_bronz_ve_kopya');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('37 sandık açılışı: ek item ödülü', (t) async {
    await ac(
        t,
        ChestOpenView(
            result: kGoldenChestOpen.copyWith(chestType: ChestTypes.legend, extras: const {'chest_key': 1, 'mastery_book_diamond': 1}),
            onClose: () {}),
        const Size(390, 844),
        kare: 30);
    expect(t.takeException(), isNull);
    await t.scrollUntilVisible(find.textContaining('Ek ödül:'), 200);
    expect(find.text('Ek ödül: Sandık anahtarı · Ustalık kitabı (Elmas)'), findsOneWidget);
    await esle(t, '37_sandik_ek_odul_390x844');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  for (final (ad, kayip) in [('38_mac_hazirligi_kayipsiz', false), ('38b_mac_hazirligi_eski_kural', true)]) {
    testWidgets('$ad 390x844', (t) async {
      getIt.registerFactory<MatchmakingViewModel>(
          () => MatchmakingViewModel(GoldenMatchmakingRepo(), GoldenSocket(), oturum, cardLossEnabled: () async => kayip));
      await ac(t, const MatchmakingView(), const Size(390, 844));
      expect(t.takeException(), isNull);
      if (kayip) {
        expect(find.text('KARTLARINI KORU'), findsOneWidget, reason: 'eski kural: koruma aynen');
      } else {
        expect(find.text('KART KAYBI YOK'), findsOneWidget);
        expect(find.text('KADRON'), findsOneWidget);
        expect(find.text('KARTLARINI KORU'), findsNothing);
      }
      await t.scrollUntilVisible(find.text(kayip ? 'KARTLARINI KORU' : 'KADRON'), 300, scrollable: find.byType(Scrollable).last);
      await t.pump(const Duration(milliseconds: 300));
      await esle(t, '${ad}_390x844');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);
  }
}
