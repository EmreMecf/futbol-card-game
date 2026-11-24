import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:shared_models/shared_models.dart';

import 'v21_test_support.dart';

/// V2.1 bileşen vitrini: her bileşen ve durum tek görselde (golden) +
/// davranış denetimleri.
void main() {
  final skipGolden = v21GoldenSkipReason;

  setUpAll(loadV21Fonts);

  Widget host(Widget child, {Size size = const Size(390, 900)}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: V21Colors.floor,
      body: RepaintBoundary(key: const Key('gallery'), child: child),
    ),
  );

  group('V21GameButton', () {
    testWidgets('normal durumda dokunma çağrılır, basılıyken yüz aşağı iner', (t) async {
      var taps = 0;
      await t.pumpWidget(
        host(
          Center(
            child: V21GameButton(label: 'OYNA', onPressed: () => taps++),
          ),
        ),
      );
      final before = t.getRect(find.text('OYNA'));
      final g = await t.startGesture(t.getCenter(find.byType(V21GameButton)));
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 200));
      final pressed = t.getRect(find.text('OYNA'));
      expect(pressed.top, greaterThan(before.top), reason: 'pressed: yüz dudağa iner');
      await g.up();
      await t.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
    });

    for (final s in [V21ButtonStatus.disabled, V21ButtonStatus.loading]) {
      testWidgets('${s.name} durumunda dokunulmaz', (t) async {
        var taps = 0;
        await t.pumpWidget(
          host(
            Center(
              child: V21GameButton(label: 'OYNA', status: s, onPressed: () => taps++),
            ),
          ),
        );
        await t.tap(find.byType(V21GameButton), warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 200));
        expect(taps, 0);
        final sem = t.getSemantics(find.byType(V21GameButton));
        expect(sem.flagsCollection.isEnabled, ui.Tristate.isFalse);
      });
    }

    testWidgets('success ve error simge gösterir; error sallanır', (t) async {
      Widget b(V21ButtonStatus s) => host(
        Center(
          child: V21GameButton(label: 'KAYDET', status: s, onPressed: () {}),
        ),
      );
      await t.pumpWidget(b(V21ButtonStatus.success));
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await t.pumpWidget(b(V21ButtonStatus.error));
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
      await t.pump(const Duration(milliseconds: 100));
      final mid = t.getRect(find.text('KAYDET')).left;
      await t.pump(const Duration(milliseconds: 400));
      final end = t.getRect(find.text('KAYDET')).left;
      expect(mid, isNot(end), reason: 'hata titreşimi');
    });
  });

  testWidgets('V21ProgressBar değeri 0..1 aralığına kırpar', (t) async {
    await t.pumpWidget(host(const SizedBox(width: 200, child: V21ProgressBar(value: 1.7, semanticsLabel: 'xp'))));
    await t.pump(const Duration(seconds: 1));
    expect(t.getSemantics(find.byType(V21ProgressBar)).value, '%100');
  });

  testWidgets('V21LeagueBadge kodu sunucu lig kodundan üretir', (t) async {
    expect(V21LeagueBadge.shortCode('master', 2), 'M2');
    expect(V21LeagueBadge.shortCode('master_class', 1), 'MC1');
    expect(V21LeagueBadge.shortCode('amateur', 3), 'A3');
    expect(V21LeagueBadge.shortCode('usta', 1), 'U1');
  });

  test('V21Format', () {
    expect(V21Format.thousands(2450), '2.450');
    expect(V21Format.thousands(1234567), '1.234.567');
    expect(V21Format.countdown(const Duration(hours: 1, minutes: 23, seconds: 45)), '1:23:45');
    expect(V21Format.countdown(const Duration(minutes: 5, seconds: 3)), '05:03');
    expect(V21Format.shortDuration(21600), '6 sa');
    expect(V21Format.shortDuration(2700), '45 dk');
    expect(V21Format.shortDuration(5400), '1 sa 30 dk');
    expect(V21Format.upper('Altın'), 'ALTIN');
    expect(V21Format.upper('gümüş'), 'GÜMÜŞ');
    expect(V21Format.upper('Efsane İlk'), 'EFSANE İLK');
  });

  testWidgets('V21 bileşen vitrini golden', (t) async {
    t.view.physicalSize = const Size(390, 1180);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    Widget btn(String l, V21ButtonStatus s, {V21ButtonTone tone = V21ButtonTone.gold, bool pressed = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: V21GameButton(
        label: l,
        status: s,
        tone: tone,
        size: V21ButtonSize.medium,
        debugPressed: pressed,
        onPressed: () {},
      ),
    );
    await t.pumpWidget(
      host(
        SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const V21GameHeader(username: 'oyuncu', level: 7, levelProgress: 0.4),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: V21LeagueBadge(code: 'U3', title: 'USTA 3', points: 1520, progress: 0.2),
              ),
              const SizedBox(height: 12),
              btn('NORMAL', V21ButtonStatus.normal),
              btn('PRESSED', V21ButtonStatus.normal, pressed: true),
              btn('DISABLED', V21ButtonStatus.disabled),
              btn('LOADING', V21ButtonStatus.loading, tone: V21ButtonTone.blue),
              btn('SUCCESS', V21ButtonStatus.success),
              btn('ERROR', V21ButtonStatus.error),
              const SizedBox(height: 6),
              SizedBox(
                height: 105,
                child: Row(
                  children: [
                    for (final (st, l, f, c) in const [
                      (V21ChestSlotState.unlocking, 'AÇILIYOR', '0:12:09', V21Colors.success),
                      (V21ChestSlotState.sealed, 'GÜMÜŞ', '2 sa', V21Colors.raritySilver),
                      (V21ChestSlotState.empty, null, null, V21Colors.dash),
                      (V21ChestSlotState.loading, null, null, V21Colors.dash),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: V21ChestSlot(state: st, label: l, footer: f, accent: c, semanticsLabel: 'yuva'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  for (final (tier, name, pos, pw) in const [
                    (CardTier.legend, 'Efsane Kaptan', CardPosition.forward, 98),
                    (CardTier.diamond, 'Usta Kaleci', CardPosition.goalkeeper, 93),
                    (CardTier.gold, 'Altın Golcü', CardPosition.forward, 91),
                    (CardTier.silver, 'Sert Stoper', CardPosition.defender, 85),
                    (CardTier.bronze, 'Genç Yetenek', CardPosition.midfielder, 78),
                  ])
                    V21PlayerCard(name: name, position: pos, tier: tier, power: pw, width: 110),
                ],
              ),
              const SizedBox(height: 14),
              V21ResourcePill.coins(coins: null),
              const SizedBox(height: 8),
              const V21GamePanel(
                padding: EdgeInsets.all(12),
                child: Text(
                  'V21GamePanel (raised)',
                  style: TextStyle(fontFamily: 'Nunito', color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Sandıklar artık vektör; görüntü yalnız kart portrelerinden gelir.
    // Hepsi çözülmeden karşılaştırılırsa yük altında sonuç değişir.
    await t.runAsync(() async {
      final el = t.element(find.byKey(const Key('gallery')));
      for (final img in t.widgetList<Image>(find.byType(Image))) {
        await precacheImage(img.image, el);
      }
    });
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    await expectLater(find.byKey(const Key('gallery')), matchesGoldenFile('goldens/v21_components.png'));
  }, skip: skipGolden != null);
}
