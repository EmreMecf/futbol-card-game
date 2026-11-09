import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/match/domain/clash_event.dart';
import 'package:futbol_card/features/match/presentation/arena/stage2d/duel_stage.dart';
import 'package:futbol_card/features/match/presentation/view/match_view.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart';
import 'package:futbol_card/features/matchmaking/presentation/view/matchmaking_view.dart';
import 'package:futbol_card/features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import 'package:futbol_card/shared/widgets/avatar2d/avatar_spec.dart';
import 'package:futbol_card/shared/widgets/ref_card/ref_player_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_araclari.dart';
import 'sahte_veri.dart';

/// FAZ 5 — maç hazırlığı ve arena: 6 boyutta golden + taşma denetimi.
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
    getIt
      ..registerFactoryParam<MatchViewModel, String, void>(
        (id, _) => MatchViewModel(GoldenArenaRepo(), GoldenSocket(), oturum, matchId: id),
      )
      ..registerFactory<MatchmakingViewModel>(
        () => MatchmakingViewModel(GoldenMatchmakingRepo(), GoldenSocket(), oturum),
      );
  });

  Future<void> ac(WidgetTester t, Widget ekran, Size boyut) async {
    t.view.physicalSize = boyut;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ChangeNotifierProvider<SessionManager>.value(
        value: oturum,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: RepaintBoundary(key: const Key('ekran'), child: ekran),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> esle(WidgetTester t, String ad) =>
      expectLater(find.byKey(const Key('ekran')), matchesGoldenFile('ekranlar/$ad.png'));

  for (final boyut in kGoldenSizes) {
    testWidgets('maç ${sizeName(boyut)}', (t) async {
      await ac(t, const MatchView(matchId: 'm'), boyut);
      expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
      expect(find.text('CANLI ARENA'), findsOneWidget);
      expect(find.text('2 – 2'), findsOneWidget);
      await esle(t, '02_arena_${sizeName(boyut)}');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);

    testWidgets('maç hazırlığı ${sizeName(boyut)}', (t) async {
      await ac(t, const MatchmakingView(), boyut);
      expect(t.takeException(), isNull, reason: 'taşma veya çizim hatası');
      await esle(t, '02h_mac_hazirligi_${sizeName(boyut)}');
      await t.pumpWidget(const SizedBox());
    }, skip: atla != null);
  }

  testWidgets('maç: kart seçildi, taktik seçildi 390x844', (t) async {
    await ac(t, const MatchView(matchId: 'm'), const Size(390, 844));
    // Forvet zorunlu: Kuzey Yıldızı (96 + 4 kimya = 100)
    await t.tap(find.byWidgetPredicate((w) => w is RefPlayerCard && w.name == 'Kuzey Yıldızı'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Kontra Atak'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('100'), findsWidgets, reason: 'SENİN KARTIN gerçek gücü');
    expect(t.takeException(), isNull);
    await esle(t, '02_arena_secili_390x844');
    await t.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await t.pump(const Duration(milliseconds: 300));
    await esle(t, '02b_arena_alt_390x844');
    await t.pumpWidget(const SizedBox());
  }, skip: atla != null);

  testWidgets('tur sonucu düellosu kare kare (maç hızı 1.8x)', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var bitti = false;
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: const Color(0xE6020810),
          child: RepaintBoundary(
            key: const Key('ekran'),
            child: DuelStageFrame(
              child: DuelStage(
                me: DuelSide(
                  spec: AvatarSpec.generate('golden-Kuzey Yıldızı', kitSeed: null),
                  seed: 'golden-Kuzey Yıldızı',
                  name: 'Kuzey Yıldızı',
                  tier: CardTier.legend,
                  power: 113,
                ),
                opponent: DuelSide(
                  spec: AvatarSpec.generate('Hız Ustası'),
                  name: 'Hız Ustası',
                  tier: CardTier.diamond,
                  power: 90,
                ),
                position: CardPosition.forward,
                outcome: ClashOutcome.win,
                speed: 1.8,
                skippable: true,
                headline: 'ELİ KAZANDIN!',
                detail: 'Kontra Atak eli çevirdi! (+13)',
                onFinished: () => bitti = true,
              ),
            ),
          ),
        ),
      ),
    );
    final toplam = DuelStage.totalMs(CardPosition.forward, ClashOutcome.win) / 1.8;
    // Kullanıcının hareket dili: çatışma 1-3 sn, toplam sahne kısa
    expect(toplam, lessThan(3300));
    var simdi = 0.0;
    for (final (i, ms) in [150.0, 420.0, 600.0, 1100.0, 1700.0, toplam - 50].indexed) {
      await t.pump(Duration(milliseconds: (ms - simdi).round()));
      simdi = ms;
      await esle(t, '02d_duello_${i + 1}');
    }
    await t.pump(const Duration(milliseconds: 200));
    expect(bitti, isTrue);
  }, skip: atla != null);

  testWidgets('düello dokununca sonuca atlar, ikinci dokunuş kapatır', (t) async {
    var bitti = false;
    await t.pumpWidget(
      MaterialApp(
        home: DuelStage(
          me: DuelSide(spec: AvatarSpec.generate('a'), name: 'A', tier: CardTier.gold, power: 80),
          opponent: DuelSide(spec: AvatarSpec.generate('b'), name: 'B', tier: CardTier.gold, power: 70),
          position: CardPosition.defender,
          outcome: ClashOutcome.loss,
          speed: 1.8,
          skippable: true,
          headline: 'ELİ KAYBETTİN',
          onFinished: () => bitti = true,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byType(DuelStage));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('ELİ KAYBETTİN'), findsOneWidget);
    expect(bitti, isFalse);
    await t.tap(find.byType(DuelStage));
    await t.pump();
    expect(bitti, isTrue);
  });
}
