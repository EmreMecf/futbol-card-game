import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:shared_models/shared_models.dart';

import 'v21_compare.dart';
import 'v21_test_support.dart';

/// FAZ 2 — temel tasarım sistemi: yeni bileşenlerin davranışı, galeri
/// golden'ı (5 boyut) ve HTML referansındaki karşılık gelen öğelerle
/// piksel karşılaştırması.
void main() {
  final skipGolden = v21GoldenSkipReason;

  setUpAll(loadV21Fonts);

  tearDown(() => V21Motion.lowPower = false);

  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion, size: const Size(390, 844)),
      child: Scaffold(
        backgroundColor: V21Colors.floor,
        body: Center(child: child),
      ),
    ),
  );

  Future<void> precache(WidgetTester t) => t.runAsync(() async {
    final el = t.binding.rootElement!;
    for (final a in V21Assets.all) {
      await precacheImage(AssetImage(a), el);
    }
  });

  // ------------------------------------------------------------------
  // DAVRANIŞ
  // ------------------------------------------------------------------
  group('V21CardBack', () {
    testWidgets('oyuncu kartıyla aynı oran ve ekran okuyucu metni', (t) async {
      await t.pumpWidget(host(const V21CardBack(width: 165, semanticsLabel: 'Rakip kartı, gizli')));
      expect(t.getSize(find.byType(V21CardBack)), const Size(165, 235));
      expect(find.bySemanticsLabel('Rakip kartı, gizli'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('V21PlayerAvatar', () {
    testWidgets('seviye rozeti ve etiket', (t) async {
      await t.pumpWidget(host(const V21PlayerAvatar(seed: 'u1', semanticsLabel: 'Sen: testoyuncu', level: 12)));
      expect(find.bySemanticsLabel('Sen: testoyuncu, seviye 12'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });
  });

  group('V21EnergyBar', () {
    testWidgets('dolu hücre sayısı değere eşit, değer sınırlanır', (t) async {
      await t.pumpWidget(host(const V21EnergyBar(value: 7, max: 5)));
      expect(find.text('5/5'), findsOneWidget);
      expect(find.bySemanticsLabel('Enerji 5 / 5'), findsOneWidget);
      await t.pumpWidget(host(const V21EnergyBar(value: 3, max: 5)));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('3/5'), findsOneWidget);
    });
  });

  group('V21MatchTimer', () {
    testWidgets('kalan süreyi gösterir; son saniyelerde canlı bölge', (t) async {
      await t.pumpWidget(host(const V21MatchTimer(seconds: 11, total: 30)));
      expect(find.text('11'), findsOneWidget);
      expect(t.getSemantics(find.byType(V21MatchTimer)).flagsCollection.isLiveRegion, isFalse);
      await t.pumpWidget(host(const V21MatchTimer(seconds: 3, total: 30)));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('3'), findsOneWidget);
      expect(find.bySemanticsLabel('Kalan süre 3 saniye'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('animasyon azaltılmışsa acil durumda nabız yok (kare çizilmez)', (t) async {
      await t.pumpWidget(host(const V21MatchTimer(seconds: 2, total: 30), reduceMotion: true));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.hasScheduledFrame, isFalse);
    });
  });

  group('V21RewardCard', () {
    testWidgets('altın, kupa ve sandık ödülleri', (t) async {
      await t.pumpWidget(
        host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [V21RewardCard.coins(150), V21RewardCard.trophies(-25), V21RewardCard.chest('Gümüş')],
          ),
        ),
      );
      expect(find.text('+150'), findsOneWidget);
      expect(find.text('-25'), findsOneWidget, reason: 'kayıpta artı işareti yok');
      expect(find.text('GÜMÜŞ'), findsOneWidget, reason: 'Türkçe büyük harf');
      expect(find.bySemanticsLabel('+150 ALTIN'), findsOneWidget);
    });
  });

  group('V21ChestCard', () {
    testWidgets('durumlar ve dokunma', (t) async {
      var taps = 0;
      await t.pumpWidget(
        host(
          V21ChestCard(
            state: V21ChestSlotState.unlocking,
            name: 'GÜMÜŞ SANDIK',
            footer: '1:23:45',
            semanticsLabel: 'Gümüş sandık açılıyor',
            onTap: () => taps++,
          ),
        ),
      );
      await precache(t);
      await t.tap(find.byType(V21ChestCard));
      expect(taps, 1);
      expect(find.byIcon(Icons.timer_rounded), findsOneWidget);
      await t.pumpWidget(host(const V21ChestCard(state: V21ChestSlotState.empty, semanticsLabel: 'Boş yuva')));
      expect(find.text('BOŞ YUVA'), findsOneWidget);
    });
  });

  group('V21GameDialog', () {
    testWidgets('seçilen düğmenin sonucunu döndürür', (t) async {
      Object? result = 'açılmadı';
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await V21GameDialog.show<String>(
                      context,
                      subtitle: 'ONAY GEREKLİ',
                      title: 'KART TAKASI',
                      message: 'Kartların kalıcı olarak silinecek.',
                      actions: const [
                        V21DialogAction('TAKAS ET', result: 'evet'),
                        V21DialogAction('VAZGEÇ', tone: V21ButtonTone.blue, result: 'hayır'),
                      ],
                    );
                  },
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('aç'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('KART TAKASI'), findsOneWidget);
      expect(find.text('ONAY GEREKLİ'), findsOneWidget);
      await t.tap(find.text('VAZGEÇ'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(result, 'hayır');
      expect(find.text('KART TAKASI'), findsNothing);
    });
  });

  group('V21LoadingOverlay', () {
    testWidgets('açıkken alttaki düğmeye dokunulamaz', (t) async {
      var taps = 0;
      Widget page(bool loading) => host(
        SizedBox(
          width: 300,
          height: 300,
          child: V21LoadingOverlay(
            loading: loading,
            message: 'Paket açılıyor',
            child: Center(
              child: TextButton(onPressed: () => taps++, child: const Text('dokun')),
            ),
          ),
        ),
      );
      await t.pumpWidget(page(true));
      expect(find.text('Paket açılıyor'), findsOneWidget);
      await t.tap(find.text('dokun'), warnIfMissed: false);
      expect(taps, 0);
      await t.pumpWidget(page(false));
      await t.tap(find.text('dokun'));
      expect(taps, 1);
    });
  });

  group('V21NetworkStatus', () {
    testWidgets('bağlıyken gizli, kopunca görünür ve yeniden dener', (t) async {
      var retry = 0;
      await t.pumpWidget(host(const V21NetworkStatus(status: V21Connection.online)));
      expect(find.text('Bağlı'), findsNothing);
      await t.pumpWidget(host(V21NetworkStatus(status: V21Connection.offline, onRetry: () => retry++)));
      expect(find.text('Bağlantı yok'), findsOneWidget);
      await t.tap(find.byType(V21NetworkStatus));
      expect(retry, 1);
      await t.pumpWidget(host(const V21NetworkStatus(status: V21Connection.reconnecting)));
      expect(find.text('Yeniden bağlanıyor…'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    });
  });

  group('V21EmptyState', () {
    testWidgets('eylem düğmesi', (t) async {
      var taps = 0;
      await t.pumpWidget(
        host(
          SizedBox(
            width: 340,
            child: V21EmptyState(
              icon: Icons.style_rounded,
              title: 'HENÜZ KART YOK',
              message: 'Mağazadan paket aç.',
              actionLabel: 'MAĞAZAYA GİT',
              onAction: () => taps++,
            ),
          ),
        ),
      );
      await t.tap(find.text('MAĞAZAYA GİT'));
      await t.pump(const Duration(milliseconds: 200));
      expect(taps, 1);
    });
  });

  group('animasyon temelleri', () {
    testWidgets('V21CardFlip arka yüzden ön yüze döner; azaltılmışsa anında', (t) async {
      Widget flip(bool front, {bool reduce = false}) => host(
        V21CardFlip(showFront: front, back: const Text('ARKA'), front: const Text('ÖN')),
        reduceMotion: reduce,
      );
      await t.pumpWidget(flip(false));
      expect(find.text('ARKA'), findsOneWidget);
      await t.pumpWidget(flip(true));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('ARKA'), findsOneWidget, reason: 'dönüşün ilk yarısı');
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('ÖN'), findsOneWidget);

      await t.pumpWidget(flip(false, reduce: true));
      await t.pump();
      expect(find.text('ARKA'), findsOneWidget, reason: 'azaltılmış: anında');
    });

    testWidgets('V21CardLift seçiliyken kalkar', (t) async {
      await t.pumpWidget(host(const V21CardLift(child: SizedBox(width: 50, height: 50, key: Key('k')))));
      final before = t.getTopLeft(find.byKey(const Key('k')));
      await t.pumpWidget(host(const V21CardLift(lifted: true, child: SizedBox(width: 50, height: 50, key: Key('k')))));
      await t.pump(const Duration(milliseconds: 400));
      expect(t.getTopLeft(find.byKey(const Key('k'))).dy, lessThan(before.dy));
    });

    testWidgets('V21RarityGlow: azaltılmış ya da düşük güç modunda kare çizmez', (t) async {
      const glow = V21RarityGlow(color: V21Colors.rarityLegend, child: SizedBox(width: 100, height: 140));
      await t.pumpWidget(host(glow));
      await t.pump(const Duration(milliseconds: 50));
      expect(t.binding.hasScheduledFrame, isTrue, reason: 'normalde parlama döner');

      await t.pumpWidget(host(glow, reduceMotion: true));
      await t.pump(const Duration(milliseconds: 50));
      expect(t.binding.hasScheduledFrame, isFalse);

      V21Motion.lowPower = true;
      await t.pumpWidget(
        host(
          const V21RarityGlow(key: Key('lp'), color: V21Colors.rarityLegend, child: SizedBox(width: 100, height: 140)),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      expect(t.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('V21Transitions.fadeUp azaltılmışsa sarmalamaz', (t) async {
      late Widget out;
      await t.pumpWidget(
        host(
          Builder(
            builder: (c) {
              out = V21Transitions.fadeUp(c, kAlwaysCompleteAnimation, kAlwaysDismissedAnimation, const Text('x'));
              return out;
            },
          ),
          reduceMotion: true,
        ),
      );
      expect(out, isA<Text>());
    });
  });

  // ------------------------------------------------------------------
  // GALERİ: 390×844 golden + duyarlı boyutlar
  // ------------------------------------------------------------------
  Widget gallery() => const _Gallery();

  for (final size in kV21Sizes.take(5)) {
    testWidgets('galeri ${v21SizeName(size)} taşmaz ve golden', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(key: const Key('screen'), child: gallery()),
        ),
      );
      await precache(t);
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      if (skipGolden == null) {
        await expectLater(
          find.byKey(const Key('screen')),
          matchesGoldenFile('goldens/v21_phase2_gallery_${v21SizeName(size)}.png'),
        );
      }
      await t.pumpWidget(const SizedBox.shrink());
    });
  }

  // ------------------------------------------------------------------
  // HTML REFERANSI İLE ÖĞE KARŞILAŞTIRMASI
  // ------------------------------------------------------------------
  testWidgets('öğeler HTML referansıyla karşılaştırılır (fark raporu)', (t) async {
    final elements = <({String name, String screen, Rect rect, Widget widget})>[
      (
        name: 'Ödül kartı +150 ALTIN',
        screen: 'win',
        rect: const Rect.fromLTWH(23, 497, 108, 116),
        widget: V21RewardCard.coins(150),
      ),
      (
        name: 'Ödül kartı +25 KUPA',
        screen: 'win',
        rect: const Rect.fromLTWH(140, 497, 108, 116),
        widget: V21RewardCard.trophies(25),
      ),
      (
        name: 'Ödül kartı ALTIN SANDIK',
        screen: 'win',
        rect: const Rect.fromLTWH(259, 497, 108, 116),
        widget: V21RewardCard.chest('Altın'),
      ),
      (
        name: 'Maç sayacı 11',
        screen: 'arena',
        rect: const Rect.fromLTWH(167, 85, 55, 55),
        widget: const V21MatchTimer(seconds: 11, total: 11),
      ),
      (
        name: 'Enerji 3/5',
        screen: 'arena',
        rect: const Rect.fromLTWH(255, 674, 122, 72),
        widget: const Align(alignment: Alignment.topLeft, child: V21EnergyBar(value: 3, max: 5)),
      ),
      (
        name: 'Oyuncu avatarı',
        screen: 'arena',
        rect: const Rect.fromLTWH(16, 20, 44, 44),
        widget: const V21PlayerAvatar(seed: 'testoyuncu', semanticsLabel: 'Sen'),
      ),
      (
        name: 'Kart arka yüzü (4,7° eğik)',
        screen: 'arena',
        rect: const Rect.fromLTWH(186, 228, 176, 236),
        widget: Transform.rotate(angle: 0.082, child: const V21CardBack(width: 150)),
      ),
      (
        name: 'Sandık kartı (açılıyor)',
        screen: 'chests',
        rect: const Rect.fromLTWH(12, 228, 178, 184),
        widget: const V21ChestCard(
          state: V21ChestSlotState.unlocking,
          name: 'GÜMÜŞ SANDIK',
          footer: '1:23:45',
          semanticsLabel: 's',
        ),
      ),
      (
        name: 'Sandık kartı (kilitli)',
        screen: 'chests',
        rect: const Rect.fromLTWH(201, 228, 178, 184),
        widget: const V21ChestCard(
          state: V21ChestSlotState.sealed,
          name: 'ALTIN SANDIK',
          footer: '6 sa',
          semanticsLabel: 's',
        ),
      ),
      (
        name: 'Boş yuva kartı',
        screen: 'chests',
        rect: const Rect.fromLTWH(12, 428, 178, 184),
        widget: const V21ChestCard(state: V21ChestSlotState.empty, semanticsLabel: 's'),
      ),
      (
        name: 'Geri düğmesi',
        screen: 'chests',
        rect: const Rect.fromLTWH(15, 17, 43, 43),
        widget: V21BackButton(onPressed: () {}),
      ),
      (
        name: 'Oyuncu kartı (Altın Golcü)',
        screen: 'collection',
        rect: const Rect.fromLTWH(20, 458, 170, 240),
        widget: const Center(
          child: V21PlayerCard(
            name: 'Altın Golcü',
            position: CardPosition.forward,
            tier: CardTier.gold,
            power: 91,
            width: 165,
          ),
        ),
      ),
    ];

    final crops = <({String name, String screen, ui.Rect rect, ui.Image image})>[];
    for (final e in elements) {
      final ref = (await t.runAsync(() => loadReference(e.screen)))!;
      t.view.physicalSize = e.rect.size;
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: const Key('el'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Öğenin arkasındaki referans zemin: yalnız öğenin kendisi karşılaştırılsın
                ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    maxWidth: 390,
                    maxHeight: 844,
                    child: Transform.translate(
                      offset: -e.rect.topLeft,
                      child: RawImage(
                        image: ref,
                        width: 390,
                        height: 844,
                        fit: BoxFit.none,
                        alignment: Alignment.topLeft,
                      ),
                    ),
                  ),
                ),
                Material(
                  type: MaterialType.transparency,
                  child: Center(child: e.widget),
                ),
              ],
            ),
          ),
        ),
      );
      await precache(t);
      await t.pump(const Duration(milliseconds: 600));
      final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(const Key('el')));
      final img = (await t.runAsync(() => boundary.toImage()))!;
      crops.add((name: e.name, screen: e.screen, rect: e.rect, image: img));
    }
    t.view.reset();
    final report = (await t.runAsync(() => compareElements(crops, outName: 'phase2', title: 'Faz 2 bileşenleri')))!;
    for (final e in report.entries) {
      expect(e.value, lessThan(80), reason: e.key);
    }
  }, skip: skipGolden != null);
}

/// Faz 2 bileşen galerisi (390×844 tuvali; küçük ekranda kaydırılır)
class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final k = V21Scale.of(context).s;
    Widget title(String s) => Padding(
      padding: EdgeInsets.only(top: 10 * k, bottom: 6 * k),
      child: Text(
        s,
        style: V21Type.label(11 * k, weight: FontWeight.w900, color: V21Colors.textMuted, letterSpacing: 1.2),
      ),
    );
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: V21Background.page),
          SafeArea(
            child: Center(
              child: SizedBox(
                width: V21Scale.of(context).contentWidth,
                child: ListView(
                  padding: EdgeInsets.all(12 * k),
                  children: [
                    Row(
                      children: [
                        V21BackButton(onPressed: () {}, scale: k),
                        SizedBox(width: 10 * k),
                        Expanded(
                          child: V21PageTitle(title: 'FAZ 2', scale: k),
                        ),
                        const V21NetworkStatus(status: V21Connection.reconnecting),
                      ],
                    ),
                    title('MAÇ'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        V21PlayerAvatar(seed: 'testoyuncu', semanticsLabel: 'Sen', size: 44 * k, level: 12),
                        V21MatchTimer(seconds: 11, total: 30, size: 55 * k),
                        V21EnergyBar(value: 3, max: 5, scale: k),
                      ],
                    ),
                    title('KARTLAR'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        V21RarityGlow(
                          color: V21Colors.rarityLegend,
                          child: V21PlayerCard(
                            name: 'Efsane Kaptan',
                            position: CardPosition.forward,
                            tier: CardTier.legend,
                            power: 98,
                            width: 120 * k,
                          ),
                        ),
                        Transform.rotate(angle: 0.08, child: V21CardBack(width: 112 * k)),
                      ],
                    ),
                    title('ÖDÜLLER'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(child: FittedBox(child: V21RewardCard.coins(150))),
                        SizedBox(width: 6 * k),
                        Flexible(child: FittedBox(child: V21RewardCard.trophies(25))),
                        SizedBox(width: 6 * k),
                        Flexible(child: FittedBox(child: V21RewardCard.chest('Altın'))),
                      ],
                    ),
                    title('SANDIKLAR'),
                    Row(
                      children: [
                        const Expanded(
                          child: FittedBox(
                            child: V21ChestCard(
                              state: V21ChestSlotState.unlocking,
                              name: 'GÜMÜŞ SANDIK',
                              footer: '1:23:45',
                              semanticsLabel: 's',
                            ),
                          ),
                        ),
                        SizedBox(width: 8 * k),
                        const Expanded(
                          child: FittedBox(
                            child: V21ChestCard(
                              state: V21ChestSlotState.sealed,
                              name: 'ALTIN SANDIK',
                              footer: '6 sa',
                              semanticsLabel: 's',
                            ),
                          ),
                        ),
                      ],
                    ),
                    title('BOŞ DURUM'),
                    V21EmptyState(
                      icon: Icons.style_rounded,
                      title: 'HENÜZ KART YOK',
                      message: 'Mağazadan paket açarak koleksiyonuna başla.',
                      actionLabel: 'MAĞAZAYA GİT',
                      onAction: () {},
                      scale: k,
                    ),
                    title('YÜKLEME'),
                    SizedBox(
                      height: 120 * k,
                      child: const V21LoadingOverlay(
                        loading: true,
                        message: 'Paket açılıyor',
                        child: SizedBox.expand(),
                      ),
                    ),
                    title('DİYALOG'),
                    const SizedBox(
                      height: 420,
                      child: V21GameDialog(
                        subtitle: 'ONAY GEREKLİ',
                        title: 'KART TAKASI',
                        message: 'Kartların kalıcı olarak silinecek. Bu işlem geri alınamaz.',
                        actions: [
                          V21DialogAction('TAKAS ET'),
                          V21DialogAction('VAZGEÇ', tone: V21ButtonTone.blue),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
