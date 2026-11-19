import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/auth/session_manager.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/ui_v21/screens/deck/v21_deck_screen.dart';
import 'package:futbol_card/features/deck/presentation/viewmodel/deck_view_model.dart';
import 'package:futbol_card/features/season/presentation/viewmodel/season_view_model.dart';
import 'package:futbol_card/features/store/presentation/viewmodel/store_view_model.dart';
import 'package:futbol_card/ui_v21/screens/season/v21_season_screen.dart';
import 'package:futbol_card/ui_v21/screens/store/v21_store_screen.dart';
import 'package:futbol_card/ui_v21/screens/rewards/v21_card_sheets.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../goldens/sahte_sezon.dart';
import '../goldens/sahte_veri.dart';
import 'v21_compare.dart';
import 'v21_test_support.dart';

/// FAZ 3 — alt menünün kalan sekmeleri: Kadrom, Mağaza, Sezon Yolu.
/// Gerçek ViewModel'ler + sahte depolar (referans ekranlardaki örnek veri).
class _DeckRepo extends GoldenDeckRepo {
  _DeckRepo([super.s]);

  /// Envanter her zaman tam bir kadro kurabilecek kartları içerir
  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async => Success([...kGoldenSquad.values, ...kGoldenCards]);
  final saved = <List<String>>[];

  @override
  Future<Result<DeckValidation>> saveDeck({
    required String deckId,
    required List<String> userCardIds,
    bool setActive = true,
  }) async {
    saved.add(userCardIds);
    return const Success(DeckValidation(isValid: true));
  }
}

/// Sunucu doğrulaması reddeder (ör. kilitli kart)
class _RejectingDeckRepo extends _DeckRepo {
  _RejectingDeckRepo() : super(const {});

  @override
  Future<Result<DeckValidation>> saveDeck({
    required String deckId,
    required List<String> userCardIds,
    bool setActive = true,
  }) async => const Success(DeckValidation(isValid: false, message: 'Kadroda kilitli kart var'));
}

class _StoreRepo extends GoldenStoreRepo {
  final opened = <String>[];
  @override
  Future<Result<PackOpenResult>> openPack(String slug) async {
    opened.add(slug);
    return super.openPack(slug);
  }
}

const _offer = DailyShopStatus(
  enabled: true,
  packSlug: 'premium',
  name: 'Altın Paket',
  cardCount: 5,
  price: 2000,
  discountPct: 25,
  discountedPrice: 1500,
);

void main() {
  final skipGolden = v21GoldenSkipReason;
  late SessionManager session;
  late _DeckRepo deck;
  late _StoreRepo store;
  late GoldenSeasonRepo season;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await loadV21Fonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    session = await goldenSession();
    deck = _DeckRepo();
    store = _StoreRepo();
    season = GoldenSeasonRepo();
    getIt
      ..registerFactory<DeckViewModel>(() => DeckViewModel(deck))
      ..registerFactory<StoreViewModel>(
        () => StoreViewModel(store, session, dailyOffer: () async => _offer, buyDailyOffer: () async => kGoldenOpening),
      )
      ..registerFactory<SeasonViewModel>(() => SeasonViewModel(season));
  });

  Future<void> pump(WidgetTester t, Widget screen, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ChangeNotifierProvider<SessionManager>.value(
        value: session,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: RepaintBoundary(key: const Key('screen'), child: screen),
        ),
      ),
    );
    await t.runAsync(() async {
      for (final a in V21Assets.all) {
        await precacheImage(AssetImage(a), t.binding.rootElement!);
      }
    });
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester t) => t.pumpWidget(const SizedBox.shrink());

  // ------------------------------------------------------------------
  group('Sezon Yolu', () {
    testWidgets('kademe, kalan süre, TÜMÜNÜ AL ve görevler sunucudan', (t) async {
      await pump(t, const V21SeasonScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('SEZON YOLU'), findsOneWidget);
      expect(find.text('KADEME 7 / 50'), findsOneWidget);
      expect(find.text('22g 14s'), findsOneWidget, reason: 'endsAt - serverTime');
      expect(find.text('660 XP sonra kademe 8'), findsOneWidget);
      expect(find.text('TÜMÜNÜ AL (3)'), findsOneWidget, reason: 'kademe 5-7 alınabilir');
      expect(find.text('1 maç oyna'), findsOneWidget);
      expect(find.text('ALINDI'), findsWidgets, reason: 'tamamlanan görev');
      expect(find.text('+200 XP'), findsOneWidget);
      final nav = t.widget<V21BottomNavigation>(find.byType(V21BottomNavigation));
      expect(nav.items[nav.activeIndex].label, 'SEZON');
      await unmount(t);
    });

    testWidgets('TÜMÜNÜ AL sunucuya gider (idempotency anahtarıyla)', (t) async {
      await pump(t, const V21SeasonScreen(), const Size(390, 844));
      await t.tap(find.text('TÜMÜNÜ AL (3)'));
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
      expect(season.anahtarlar, isNotEmpty);
      await unmount(t);
    });

    testWidgets('kademe düğümü: ayrıntı diyaloğu ve ödülü alma', (t) async {
      await pump(t, const V21SeasonScreen(), const Size(390, 844));
      final node = find.bySemanticsLabel(RegExp(r'^Kademe 6: .*alınabilir'));
      expect(node, findsOneWidget);
      await t.tap(node);
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KADEME 6'), findsOneWidget);
      await t.tap(find.text('ÜCRETSİZ ÖDÜLÜ AL'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(season.alinan, contains('free:6'));
      await unmount(t);
    });

    testWidgets('sezon kapalıysa boş durum (uydurma kademe yok)', (t) async {
      season.sezon = const SeasonOverview(enabled: false);
      await pump(t, const V21SeasonScreen(), const Size(390, 844));
      expect(find.text('SEZON YAKINDA'), findsOneWidget);
      expect(find.textContaining('KADEME'), findsNothing);
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Mağaza', () {
    testWidgets('günün teklifi, paketler, eksik altın ve oranlar', (t) async {
      await pump(t, const V21StoreScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.descendant(of: find.byType(V21PageTitle), matching: find.text('MAĞAZA')), findsOneWidget);
      expect(find.text('2.450'), findsOneWidget, reason: 'oturumdaki altın');
      expect(find.text('GÜNÜN TEKLİFİ'), findsOneWidget);
      expect(find.text('Altın Paket'), findsOneWidget);
      expect(find.text('%25'), findsOneWidget);
      expect(find.text('STANDART PAKET'), findsOneWidget);
      expect(find.text('50 altın eksik'), findsOneWidget, reason: '2500 - 2450');
      expect(find.text('1.550 altın eksik'), findsOneWidget, reason: '4000 - 2450');
      // Varsayılan seçili paket: Efsane oranı en yüksek alınabilir paket (premium)
      expect(find.text('ÇIKMA İHTİMALİ · PREMİUM PAKET'), findsOneWidget);
      final nav = t.widget<V21BottomNavigation>(find.byType(V21BottomNavigation));
      expect(nav.items[nav.activeIndex].label, 'MAĞAZA');
      await unmount(t);
    });

    testWidgets('pakete dokununca oranlar değişir; parası yetmeyen paket alınamaz', (t) async {
      await pump(t, const V21StoreScreen(), const Size(390, 844));
      await t.tap(find.text('STANDART PAKET'));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('ÇIKMA İHTİMALİ · STANDART PAKET'), findsOneWidget);
      expect(find.text('%55'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('2.500 altın ile satın al'), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 200));
      expect(store.opened, isEmpty);
      await unmount(t);
    });

    testWidgets('satın alma sunucuya gider ve açılış gösterilir', (t) async {
      await pump(t, const V21StoreScreen(), const Size(390, 844));
      await t.tap(find.bySemanticsLabel('500 altın ile satın al'));
      await t.pump(const Duration(milliseconds: 300));
      await t.pump(const Duration(milliseconds: 300));
      expect(store.opened, ['standard']);
      expect(find.byType(V21PageTitle), findsNothing, reason: 'paket açılış ekranı');
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('Kadrom', () {
    testWidgets('Kadrom: saha, istatistikler, otomatik diz', (t) async {
      await pump(t, const V21DeckScreen(), const Size(390, 844));
      expect(t.takeException(), isNull);
      expect(find.text('KADROM'), findsOneWidget);
      expect(find.byType(V21PlayerCard), findsNWidgets(11));
      expect(find.text('11/11'), findsOneWidget);
      expect(find.text('OTOMATİK DİZ'), findsOneWidget);
      final nav = t.widget<V21BottomNavigation>(find.byType(V21BottomNavigation));
      expect(nav.items[nav.activeIndex].label, 'KADRO');
      await unmount(t);
    });

    testWidgets('boş kadroda otomatik diz → kaydet sunucuya 11 kart gönderir', (t) async {
      deck = _DeckRepo(const {});
      await pump(t, const V21DeckScreen(), const Size(390, 844));
      expect(find.byType(V21PlayerCard), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'yuvası boş')), findsNWidgets(11));
      await t.tap(find.text('OTOMATİK DİZ'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(V21PlayerCard), findsNWidgets(11));
      expect(find.text('KAYDET'), findsOneWidget, reason: 'kaydedilmemiş değişiklik');
      await t.tap(find.text('KAYDET'));
      await t.pump(const Duration(milliseconds: 400));
      expect(deck.saved.single, hasLength(11));
      expect(find.text('Kadro kaydedildi'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('hf17: eksik kadroda KAYDET → KADRO EKSİK; KADROYU DÜZENLE boş yuvayı açar', (t) async {
      deck = _DeckRepo(const {});
      await pump(t, const V21DeckScreen(), const Size(390, 844));
      // Yalnız kaleciyi koy: 1/11, kaydedilmemiş değişiklik
      await t.tap(find.bySemanticsLabel('Kaleci yuvası boş, kart seç'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.descendant(of: find.byType(V21CardPickerSheet), matching: find.byType(V21PlayerCard)).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.byType(V21PlayerCard), findsOneWidget);

      await t.tap(find.text('KAYDET'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KADRO EKSİK'), findsOneWidget);
      expect(find.text('EKSİK MEVKİLER'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Eksik mevkiler: 4 defans, 4 orta saha, 2 forvet')), findsOneWidget);
      expect(deck.saved, isEmpty, reason: 'eksik kadro sunucuya gitmez');

      await t.tap(find.text('KADROYU DÜZENLE'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KADRO EKSİK'), findsNothing);
      expect(find.byType(V21CardPickerSheet), findsOneWidget, reason: 'ilk boş yuvanın seçicisi');
      await unmount(t);
    });

    testWidgets('hf17: sunucu reddederse KADRO GEÇERSİZ, sunucunun mesajıyla', (t) async {
      deck = _RejectingDeckRepo();
      await pump(t, const V21DeckScreen(), const Size(390, 844));
      await t.tap(find.text('OTOMATİK DİZ'));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('KAYDET'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KADRO GEÇERSİZ'), findsOneWidget);
      expect(find.text('Kadroda kilitli kart var'), findsWidgets);
      await t.tap(find.text('KAPAT'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KADRO GEÇERSİZ'), findsNothing);
      await unmount(t);
    });

    testWidgets('kaydedilmemiş değişiklikle geri: onay diyaloğu', (t) async {
      deck = _DeckRepo(const {});
      await pump(t, const V21DeckScreen(), const Size(390, 844));
      await t.tap(find.text('OTOMATİK DİZ'));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.bySemanticsLabel('Geri'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KADRODAN ÇIK?'), findsOneWidget);
      await t.tap(find.text('VAZGEÇ'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('KADROM'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('sürükleme yalnız aynı mevkideki yuvaya bırakır', (t) async {
      await pump(t, const V21DeckScreen(), const Size(390, 844));
      final def1 = find.bySemanticsLabel(RegExp(r'^Defans: '));
      expect(def1, findsNWidgets(4));
      final before = (t.widget(def1.first) as Semantics).properties.label;
      // Defans kartını kaleciye sürükle: kabul edilmez, yerinde kalır
      final gk = find.bySemanticsLabel(RegExp(r'^Kaleci: '));
      final g = await t.startGesture(t.getCenter(def1.first));
      await t.pump(const Duration(milliseconds: 600));
      await g.moveTo(t.getCenter(gk));
      await t.pump(const Duration(milliseconds: 200));
      await g.up();
      await t.pump(const Duration(milliseconds: 400));
      expect((t.widget(find.bySemanticsLabel(RegExp(r'^Defans: ')).first) as Semantics).properties.label, before);
      await unmount(t);
    });
  });

  // ------------------------------------------------------------------
  group('duyarlı yerleşim + golden', () {
    final screens = <String, Widget Function()>{
      'season': () => const V21SeasonScreen(),
      'store': () => const V21StoreScreen(),
      'deck': () => const V21DeckScreen(),
    };
    for (final e in screens.entries) {
      for (final size in kV21AllSizes) {
        testWidgets('${e.key} ${v21SizeName(size)}', (t) async {
          await pump(t, e.value(), size);
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
    Future<void> compare(
      WidgetTester t,
      Widget screen,
      String name,
      String title,
      Map<String, (int, int)> regions,
    ) async {
      await pump(t, screen, const Size(390, 844));
      final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(const Key('screen')));
      final r = await t.runAsync(() => compareWithReference(boundary, screen: name, title: title, regions: regions));
      expect(r!['overall']!, lessThan(70));
      await unmount(t);
    }

    testWidgets('Sezon Yolu', (t) async {
      await compare(t, const V21SeasonScreen(), 'season', 'Sezon Yolu', const {
        'başlık (0-70)': (0, 70),
        'kademe kartı (70-225)': (70, 225),
        'ödül yolu (225-325)': (225, 325),
        'görevler (325-760)': (325, 760),
        'menü (760-844)': (760, 844),
      });
    }, skip: skipGolden != null);

    testWidgets('Mağaza', (t) async {
      await compare(t, const V21StoreScreen(), 'store', 'Mağaza', const {
        'başlık (0-70)': (0, 70),
        'günün teklifi (70-250)': (70, 250),
        'paketler (250-540)': (250, 540),
        'oranlar + sekmeler (540-700)': (540, 700),
        'menü (760-844)': (760, 844),
      });
    }, skip: skipGolden != null);

    testWidgets('Kadrom', (t) async {
      await compare(t, const V21DeckScreen(), 'deck', 'Kadrom', const {
        'başlık (0-70)': (0, 70),
        'saha (70-530)': (70, 530),
        'istatistik (530-640)': (530, 640),
        'ipucu + düğme (640-760)': (640, 760),
        'menü (760-844)': (760, 844),
      });
    }, skip: skipGolden != null);
  });
}
