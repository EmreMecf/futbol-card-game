import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/match/presentation/widgets/tutorial_hint.dart';
import 'package:futbol_card/ui_v21/screens/auth/v21_splash_art.dart';
import 'package:futbol_card/ui_v21/screens/match/v21_tutorial_hint.dart';
import 'package:futbol_card/ui_v21/screens/rewards/v21_walkout.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'v21_test_support.dart';

/// FAZ 7 — PR'lardan bağımsız kalanlar: öğretici ipucu (hf12–hf14),
/// geçersiz kadro uyarısı (hf17; Kadrom davranışı v21_tabs_test'te),
/// walkout sinematiği, açılış ekranı.

MatchState _state(int step, {String? phase, bool lead = false}) => MatchState(
  matchId: 'm',
  status: MatchStatus.active,
  roundNumber: 1,
  mode: 'tutorial',
  tutorialStep: step,
  simultaneous: true,
  phase: phase,
  amILead: lead,
);

const _legend = InventoryCard(
  userCardId: 'w1',
  cardId: 'golden-Efsane Kaptan',
  fullName: 'Efsane Kaptan',
  position: CardPosition.midfielder,
  power: 98,
  tier: CardTier.legend,
  club: 'Mavi Şimşek',
  nationality: 'TUR',
);

void main() {
  final skipGolden = v21GoldenSkipReason;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await loadV21Fonts();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester t, Widget screen, Size size, {bool reduced = false, int frames = 10}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: RepaintBoundary(key: const Key('screen'), child: screen),
      ),
    );
    await t.runAsync(() async {
      for (final a in V21Assets.all) {
        await precacheImage(AssetImage(a), t.binding.rootElement!);
      }
    });
    for (var i = 0; i < frames; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester t) => t.pumpWidget(const SizedBox.shrink());

  Widget hintPage(int step, {String? phase, bool lead = false}) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: V21Background()),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              TutorialHint(
                state: _state(step, phase: phase, lead: lead),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------------
  group('Öğretici ipucu (hf12–hf14)', () {
    testWidgets('TutorialHint varsayılan olarak V2.1 çizer: adım, çizelge, ödülsüz', (t) async {
      await pump(t, hintPage(1, phase: 'position', lead: true), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.byType(V21TutorialHint), findsOneWidget);
      expect(find.text('ÖĞRETİCİ · 1/3'), findsOneWidget);
      expect(find.text('ÖDÜLSÜZ'), findsOneWidget);
      for (final s in ['MEVKİ', 'KART', 'TAKTİK']) {
        expect(find.text(s), findsOneWidget);
      }
      expect(find.text('MEVKİ SEÇ'), findsOneWidget, reason: 'metin eski kaynaktan (textFor)');
      expect(find.bySemanticsLabel(RegExp(r'^Öğretici, adım 1 / 3, mevki')), findsOneWidget);
      await unmount(t);
    });

    testWidgets('adım 3: önceki iki adım tamam (✓), taktik metni', (t) async {
      await pump(t, hintPage(3, phase: 'pick'), const Size(390, 844));
      expect(find.text('ÖĞRETİCİ · 3/3'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.text('TAKTİK'), findsNWidgets(2), reason: 'çizelge etiketi + balon başlığı');
      await unmount(t);
    });

    testWidgets('forceLegacy eski paneli çizer', (t) async {
      await pump(
        t,
        Scaffold(
          body: TutorialHint(state: _state(2, phase: 'pick'), forceLegacy: true),
        ),
        const Size(390, 844),
      );
      expect(find.byType(V21TutorialHint), findsNothing);
      expect(find.textContaining('ÖĞRETİCİ 2/3'), findsOneWidget);
      await unmount(t);
    });
  });

  group('Geçersiz kadro uyarısı (hf17)', () {
    testWidgets('eksik mevkiler, KADROYU DÜZENLE true, KAPAT false döner', (t) async {
      final results = <bool>[];
      await pump(
        t,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => results.add(
                await V21SquadWarning.show(context, missing: const {CardPosition.defender: 1, CardPosition.forward: 2}),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
        const Size(390, 844),
      );
      for (final (button, expected) in [('KADROYU DÜZENLE', true), ('KAPAT', false)]) {
        await t.tap(find.text('aç'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        expect(find.text('KADRO EKSİK'), findsOneWidget);
        expect(find.text('Maça çıkmak için 11 geçerli kart gerekli.'), findsOneWidget);
        expect(find.text('DEF'), findsOneWidget);
        expect(find.text('FWD'), findsOneWidget);
        expect(find.text('×2'), findsOneWidget);
        await t.tap(find.text(button));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        expect(results.last, expected);
      }
      await unmount(t);
    });
  });

  group('Walkout', () {
    testWidgets('sahne: ülke → mevki → kulüp → kart; DEVAM devam eder', (t) async {
      var continued = 0;
      await pump(t, V21WalkoutScreen(card: _legend, onContinue: () => continued++), const Size(390, 844), frames: 0);
      await t.pump(const Duration(milliseconds: 800));
      expect(find.text('ÜLKE'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 1000));
      expect(find.text('MEVKİ'), findsOneWidget);
      expect(find.text('MID'), findsWidgets);
      await t.pump(const Duration(milliseconds: 1000));
      expect(find.text('KULÜP'), findsOneWidget);
      expect(find.text('DEVAM'), findsNothing);
      await t.pump(const Duration(milliseconds: 1500));
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('EFSANE!'), findsWidgets);
      expect(find.text('EFSANE KAPTAN'), findsOneWidget);
      await t.tap(find.text('DEVAM'));
      expect(continued, 1);
      await unmount(t);
    });

    testWidgets('ilk dokunuş karta atlar, ikinci dokunuş devam eder', (t) async {
      var continued = 0;
      await pump(t, V21WalkoutScreen(card: _legend, onContinue: () => continued++), const Size(390, 844), frames: 3);
      expect(find.text('Atlamak için dokun'), findsOneWidget);
      await t.tapAt(const Offset(195, 200));
      await t.pump();
      await t.pump(const Duration(milliseconds: 1200));
      expect(continued, 0);
      expect(find.text('EFSANE!'), findsWidgets);
      await t.tapAt(const Offset(195, 200));
      expect(continued, 1);
      await unmount(t);
    });

    testWidgets('animasyon azaltılmış: sahne yok, kart ve DEVAM hemen', (t) async {
      await pump(t, V21WalkoutScreen(card: _legend, onContinue: () {}), const Size(390, 844), reduced: true, frames: 1);
      expect(find.text('ÜLKE'), findsNothing);
      expect(find.text('EFSANE!'), findsWidgets);
      expect(find.text('DEVAM'), findsOneWidget);
      await unmount(t);
    });
  });

  group('Açılış', () {
    testWidgets('yükleme görseli ve çubuk; çubuk ilerlemeyle dolar', (t) async {
      await pump(t, const Scaffold(body: V21SplashArt(progress: 1)), const Size(390, 844));
      final gorsel = t.widget<Image>(find.byType(Image)).image as AssetImage;
      expect(gorsel.assetName, V21Assets.loadingSplash);
      expect(find.text('YÜKLENİYOR'), findsOneWidget);
      expect(find.bySemanticsLabel('Futbol Card Arena yükleniyor'), findsOneWidget);
      double cubuk() => t.widget<FractionallySizedBox>(find.byKey(const Key('yukleme-cubugu'))).widthFactor!;
      expect(cubuk(), 1);
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: V21SplashArt(progress: 0))));
      expect(cubuk(), 0);
      await unmount(t);
    });

    testWidgets('tablette görselin tamamı görünür', (t) async {
      await pump(t, const Scaffold(body: V21SplashArt(progress: 1)), const Size(768, 1024));
      final fitler = t.widgetList<Image>(find.byType(Image)).map((i) => i.fit).toList();
      expect(fitler, containsAll([BoxFit.cover, BoxFit.contain]));
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Golden + duyarlılık', () {
    final screens = <String, (Widget Function(), bool)>{
      'tutorial_hint_1': (() => hintPage(1, phase: 'position', lead: true), false),
      'tutorial_hint_3': (() => hintPage(3, phase: 'pick'), false),
      'walkout_card': (() => V21WalkoutScreen(card: _legend, onContinue: () {}), true),
      'splash': (() => const Scaffold(body: V21SplashArt(progress: 1)), false),
    };
    for (final e in screens.entries) {
      for (final size in kV21Sizes) {
        testWidgets('${e.key} ${v21SizeName(size)}', (t) async {
          await pump(t, e.value.$1(), size, reduced: e.value.$2);
          expect(t.takeException(), isNull, reason: 'taşma olmamalı');
          if (skipGolden == null) {
            await expectLater(
              find.byKey(const Key('screen')),
              matchesGoldenFile('goldens/v21_${e.key}_${v21SizeName(size)}.png'),
            );
          }
          await unmount(t);
        });
      }
    }

    for (final size in kV21Sizes) {
      testWidgets('squad_warning ${v21SizeName(size)}', (t) async {
        await pump(
          t,
          Builder(
            builder: (context) => Scaffold(
              body: Stack(
                children: [
                  const Positioned.fill(child: V21Background()),
                  Center(
                    child: TextButton(
                      onPressed: () => V21SquadWarning.show(
                        context,
                        missing: const {CardPosition.defender: 1, CardPosition.forward: 2},
                      ),
                      child: const Text('aç'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          size,
        );
        await t.tap(find.text('aç'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 600));
        expect(t.takeException(), isNull, reason: 'taşma olmamalı');
        if (skipGolden == null) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('goldens/v21_squad_warning_${v21SizeName(size)}.png'),
          );
        }
        await unmount(t);
      });
    }
  });
}
