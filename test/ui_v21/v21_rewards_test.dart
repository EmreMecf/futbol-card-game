import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/match/presentation/viewmodel/match_view_model.dart' show MatchRewardDelta;
import 'package:futbol_card/ui_v21/screens/rewards/v21_match_result.dart';
import 'package:futbol_card/ui_v21/screens/rewards/v21_walkout.dart';
import 'package:futbol_card/ui_v21/screens/rewards/v21_card_sheets.dart';
import 'package:futbol_card/ui_v21/screens/rewards/v21_chest_opening.dart';
import 'package:futbol_card/ui_v21/screens/rewards/v21_pack_opening.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/sahte_veri.dart';
import 'v21_compare.dart';
import 'v21_test_support.dart';

/// FAZ 5 — ödül ve kart akışları: paket açılışı, sandık açılışı, kart
/// ayrıntısı, kart seçici, maç sonucu.

InventoryCard _card(int i) => kGoldenCards[i];

/// Referans Efsane Açılış için: iki Efsane. Sıra ters açılır; en iyi kart
/// (98) walkout alır, diğeri (96) normal açılışla "EFSANE!" gösterir.
final _legendOpening = PackOpenResult(
  packSlug: 'premium',
  packName: 'Premium Paket',
  coinsSpent: 2500,
  coinsLeft: 0,
  cards: [_card(8), _card(0)],
);

final _win = MatchResultSummary(
  matchId: 'm1',
  didIWin: true,
  myScore: 7,
  opponentScore: 4,
  opponent: const OpponentInfo(id: 'o1', username: 'StormFC'),
  cardsWon: [_card(9), _card(7)],
);

const _delta = MatchRewardDelta(coins: 150, rating: 25, protectionSlots: 1);

void main() {
  final skipGolden = v21GoldenSkipReason;
  late SessionManager session;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await loadV21Fonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    session = await goldenSession();
  });

  Future<void> pump(WidgetTester t, Widget screen, {Size size = const Size(390, 844), bool reduce = false}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ChangeNotifierProvider<SessionManager>.value(
        value: session,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
            child: child!,
          ),
          home: RepaintBoundary(key: const Key('screen'), child: screen),
        ),
      ),
    );
    await t.runAsync(() async {
      for (final a in V21Assets.all) {
        await precacheImage(AssetImage(a), t.binding.rootElement!);
      }
    });
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester t) => t.pumpWidget(const SizedBox.shrink());

  // ------------------------------------------------------------------
  group('Paket açılışı', () {
    testWidgets('mühür → kart kart açılış → walkout (en iyi kart) → özet', (t) async {
      await pump(t, V21PackOpening(result: kGoldenOpening, onClose: () {}));
      expect(t.takeException(), isNull);
      expect(find.text('PREMİUM PAKET'), findsOneWidget);
      expect(find.text('DOKUN!'), findsWidgets);
      expect(find.text('5 kart seni bekliyor'), findsOneWidget);

      await t.tap(find.bySemanticsLabel(RegExp('^Paketi açmak için dokun')));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(V21CardFlip), findsOneWidget, reason: 'ilk kart açılıyor');
      expect(find.text('Koleksiyonuna eklendi · 1 / 5'), findsOneWidget);
      for (var n = 0; n < 4; n++) {
        await t.tap(find.text('DEVAM'));
        for (var i = 0; i < 6; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
      }
      expect(find.byType(V21WalkoutScreen), findsOneWidget, reason: 'en iyi kart (Efsane) walkout ile');
      expect(find.text('Atlamak için dokun'), findsOneWidget);
      // Dokun: sahne karta atlar; vuruş bitince DEVAM
      await t.tapAt(const Offset(195, 300));
      for (var i = 0; i < 14; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('EFSANE!'), findsWidgets);
      await t.tap(find.text('DEVAM'));
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(V21WalkoutScreen), findsNothing, reason: 'DEVAM sahneyi kapatır');
      await unmount(t);
    });

    testWidgets('HEPSİNİ GÖSTER doğrudan özete geçer', (t) async {
      var closed = 0;
      await pump(t, V21PackOpening(result: kGoldenOpening, onClose: () => closed++));
      await t.tap(find.text('HEPSİNİ GÖSTER'));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('PAKET AÇILDI'), findsOneWidget);
      expect(find.text('EN İYİ KART'), findsOneWidget);
      await t.scrollUntilVisible(find.text('MAĞAZAYA DÖN'), 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.text('MAĞAZAYA DÖN'));
      await t.pump();
      await t.tap(find.text('MAĞAZAYA DÖN'));
      await t.pump(const Duration(milliseconds: 300));
      expect(closed, 1);
      await unmount(t);
    });

    testWidgets('animasyon azaltılmışsa mühür anında açılır', (t) async {
      await pump(t, V21PackOpening(result: kGoldenOpening, onClose: () {}), reduce: true);
      await t.tap(find.bySemanticsLabel(RegExp('^Paketi açmak için dokun')));
      await t.pump();
      await t.pump();
      expect(find.byType(V21CardFlip), findsOneWidget);
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Sandık açılışı', () {
    testWidgets('sandık türü, kart sonuçları, ödüller, TAMAM', (t) async {
      var closed = 0;
      await pump(t, V21ChestOpening(result: kGoldenChestOpen, onClose: () => closed++));
      await t.pump(const Duration(seconds: 3));
      expect(t.takeException(), isNull);
      expect(find.bySemanticsLabel('ALTIN!'), findsOneWidget);
      expect(find.text('YENİ'), findsOneWidget);
      expect(find.text('+1 GELİŞİM'), findsOneWidget);
      expect(find.text('KADRO KORUMASI'), findsOneWidget);
      expect(find.text('+104'), findsOneWidget, reason: 'sunucunun verdiği altın');
      await t.scrollUntilVisible(find.text('TAMAM'), 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.text('TAMAM'));
      await t.pump();
      await t.tap(find.text('TAMAM'));
      await t.pump(const Duration(milliseconds: 200));
      expect(closed, 1);
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Kart ayrıntısı ve kart seçici', () {
    testWidgets('ayrıntı: güç, nadirlik, mevki, özellikler, favori, kapat', (t) async {
      var favorite = false;
      await pump(
        t,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => V21CardDetailSheet.show(
                context,
                _card(8),
                onToggleFavorite: () async {
                  favorite = !favorite;
                  return true;
                },
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      );
      await t.tap(find.text('aç'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 700));
      expect(find.text('OYUNCU KARTI'), findsOneWidget);
      expect(find.bySemanticsLabel('GÜÇ 98'), findsOneWidget);
      expect(find.bySemanticsLabel('NADİRLİK EFSANE'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^ŞUT \d+')), findsOneWidget);
      expect(find.textContaining('Efsane kart: gücü ne olursa olsun'), findsOneWidget);
      await t.scrollUntilVisible(find.text('FAVORİLERE EKLE'), 200, scrollable: find.byType(Scrollable).last);
      await t.ensureVisible(find.text('FAVORİLERE EKLE'));
      await t.pump();
      await t.tap(find.text('FAVORİLERE EKLE'));
      await t.pump(const Duration(milliseconds: 200));
      expect(favorite, isTrue);
      expect(find.text('FAVORİDEN ÇIKAR'), findsOneWidget);
      await t.tap(find.text('KAPAT'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('OYUNCU KARTI'), findsNothing);
      await unmount(t);
    });

    testWidgets('seçici: mevkideki kartlar kimya+güce göre; dokununca seçilir', (t) async {
      InventoryCard? picked;
      final defenders = kGoldenCards.where((c) => c.position == CardPosition.defender).toList();
      await pump(
        t,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => picked = await V21CardPickerSheet.show(
                context,
                position: CardPosition.defender,
                cards: defenders,
                chemistryPreview: (c) => c.fullName == 'Çelik Bek' ? 6 : 0,
              ),
              child: const Text('seç'),
            ),
          ),
        ),
      );
      await t.tap(find.text('seç'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('DEFANS SEÇ'), findsOneWidget);
      expect(find.text('${defenders.length} KART'), findsOneWidget);
      final first = t.widget<V21PlayerCard>(find.byType(V21PlayerCard).first);
      expect(first.name, 'Çelik Bek', reason: 'kimya 6 → en üstte');
      expect(find.text('+6 KİMYA'), findsOneWidget);
      await t.tap(find.text('Çelik Bek'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(picked?.fullName, 'Çelik Bek');
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Maç sonucu', () {
    testWidgets('zafer: skor, ödüller, kazanılan kartlar, düğmeler', (t) async {
      var closed = 0, again = 0;
      await pump(
        t,
        V21MatchResultView(result: _win, rewardDelta: _delta, onClose: () => closed++, onNewMatch: () => again++),
      );
      expect(t.takeException(), isNull);
      expect(find.bySemanticsLabel('ZAFER!'), findsOneWidget);
      expect(find.text('7 : 4'), findsOneWidget);
      expect(find.text('ÖDÜLLERİN'), findsOneWidget);
      expect(find.text('+150'), findsOneWidget);
      expect(find.text('+25'), findsOneWidget);
      expect(find.text('+2 KART KAZANDIN'), findsOneWidget);
      await t.scrollUntilVisible(find.text('YENİ MAÇ'), 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.text('YENİ MAÇ'));
      await t.pump();
      await t.tap(find.text('YENİ MAÇ'));
      await t.tap(find.text('ANA MENÜ'));
      expect((again, closed), (1, 1));
      await unmount(t);
    });

    testWidgets('antrenman: ödül kartı yok, "ÖDÜL VE PUAN YOK"', (t) async {
      await pump(
        t,
        V21MatchResultView(
          result: _win.copyWith(mode: 'training', cardsWon: const []),
          rewardDelta: _delta,
          onClose: () {},
        ),
      );
      expect(find.text('ANTRENMAN · ÖDÜL VE PUAN YOK'), findsOneWidget);
      expect(find.text('ÖDÜLLERİN'), findsNothing);
      expect(find.text('YENİ MAÇ'), findsNothing, reason: 'onNewMatch verilmedi');
      await unmount(t);
    });

    testWidgets('mağlubiyet: kırmızı başlık, kaybedilen kartlar, eksi kupa', (t) async {
      await pump(
        t,
        V21MatchResultView(
          result: MatchResultSummary(matchId: 'm2', myScore: 3, opponentScore: 6, cardsLost: [_card(5)]),
          rewardDelta: const MatchRewardDelta(coins: 20, rating: -25, protectionSlots: 0),
          onClose: () {},
        ),
      );
      expect(find.bySemanticsLabel('MÜCADELE BİTTİ'), findsOneWidget);
      expect(find.text('-25'), findsOneWidget);
      expect(find.text('-1 KART KAYBETTİN'), findsOneWidget);
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('duyarlı yerleşim + golden', () {
    final screens = <String, Widget Function()>{
      'pack_seal': () => V21PackOpening(result: kGoldenOpening, onClose: () {}),
      'pack_summary': () => _SummaryHost(result: kGoldenOpening),
      'chest_opening': () => V21ChestOpening(result: kGoldenChestOpen, onClose: () {}),
      'match_win': () => V21MatchResultView(result: _win, rewardDelta: _delta, onClose: () {}, onNewMatch: () {}),
    };
    for (final e in screens.entries) {
      for (final size in kV21AllSizes) {
        testWidgets('${e.key} ${v21SizeName(size)}', (t) async {
          await pump(t, e.value(), size: size, reduce: true);
          await t.pump(const Duration(milliseconds: 300));
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

  // ------------------------------------------------------------------
  group('390×844 referans karşılaştırması', () {
    Future<void> compare(WidgetTester t, String screen, String title) async {
      final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(const Key('screen')));
      final r = await t.runAsync(
        () => compareWithReference(
          boundary,
          screen: screen,
          title: title,
          regions: const {'üst (0-200)': (0, 200), 'orta (200-600)': (200, 600), 'alt (600-844)': (600, 844)},
        ),
      );
      expect(r!['overall']!, lessThan(75));
      await unmount(t);
    }

    testWidgets('Paket Mührü', (t) async {
      await pump(t, V21PackOpening(result: kGoldenOpening, onClose: () {}), reduce: true);
      await compare(t, 'packSeal', 'Paket Mührü');
    }, skip: skipGolden != null);

    testWidgets('Efsane Açılış', (t) async {
      await pump(t, V21PackOpening(result: _legendOpening, onClose: () {}), reduce: true);
      await t.tap(find.bySemanticsLabel(RegExp('^Paketi açmak için dokun')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel('EFSANE!'), findsOneWidget);
      await compare(t, 'packLegend', 'Efsane Açılış');
    }, skip: skipGolden != null);

    testWidgets('Zafer', (t) async {
      await pump(
        t,
        V21MatchResultView(result: _win, rewardDelta: _delta, onClose: () {}, onNewMatch: () {}),
        reduce: true,
      );
      await compare(t, 'win', 'Zafer');
    }, skip: skipGolden != null);
  });
}

/// Özet ekranını doğrudan göstermek için: açar ve "hepsini göster"e basar
class _SummaryHost extends StatefulWidget {
  final PackOpenResult result;
  const _SummaryHost({required this.result});

  @override
  State<_SummaryHost> createState() => _SummaryHostState();
}

class _SummaryHostState extends State<_SummaryHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = context;
      if (!ctx.mounted) return;
      // Mühür ekranındaki HEPSİNİ GÖSTER düğmesinin yaptığı
      final finder = find.text('HEPSİNİ GÖSTER');
      final el = finder.evaluate().firstOrNull;
      if (el != null) (el.findAncestorWidgetOfExactType<V21GameButton>()?.onPressed)?.call();
    });
  }

  @override
  Widget build(BuildContext context) => V21PackOpening(result: widget.result, onClose: () {});
}
