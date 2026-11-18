import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/collection/domain/repositories/collection_repository.dart';
import 'package:futbol_card/features/collection/presentation/viewmodel/collection_view_model.dart';
import 'package:futbol_card/ui_v21/screens/rewards/v21_card_sheets.dart';
import 'package:futbol_card/ui_v21/screens/collection/v21_collection_screen.dart';
import 'package:futbol_card/ui_v21/ui_v21.dart';
import 'package:futbol_card/ui_v21/web/web_kit.dart' show WCard;
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'v21_compare.dart';
import 'v21_test_support.dart';

/// Referans Koleksiyon ekranındaki örnek kartlar (yalnız test verisi):
/// ilk dördü ekranda görünenler, toplam 12 farklı kart, katalog 100.
const _reference = [
  ('Efsane Kaptan', CardPosition.forward, 98, CardTier.legend),
  ('Usta Kaleci', CardPosition.goalkeeper, 93, CardTier.diamond),
  ('Altın Golcü', CardPosition.forward, 91, CardTier.gold),
  ('Sert Stoper', CardPosition.defender, 85, CardTier.silver),
  ('Genç Yetenek', CardPosition.forward, 78, CardTier.bronze),
  ('Hızlı Kanat', CardPosition.midfielder, 76, CardTier.silver),
  ('Çelik Bek', CardPosition.defender, 74, CardTier.bronze),
  ('Oyun Kurucu', CardPosition.midfielder, 72, CardTier.gold),
  ('Demir Duvar', CardPosition.defender, 70, CardTier.bronze),
  ('Saha Generali', CardPosition.midfielder, 69, CardTier.silver),
  ('Liman Kalecisi', CardPosition.goalkeeper, 66, CardTier.bronze),
  ('Kuzey Yıldızı', CardPosition.forward, 64, CardTier.bronze),
];

final _cards = [
  for (var i = 0; i < _reference.length; i++)
    InventoryCard(
      userCardId: 'uc-$i',
      cardId: 'c-$i',
      fullName: _reference[i].$1,
      position: _reference[i].$2,
      power: _reference[i].$3,
      tier: _reference[i].$4,
      club: 'Mavi Şimşek',
    ),
  // Aynı karttan ikinci kopya (kilitli): "farklı kart" sayısını değiştirmemeli
  const InventoryCard(
    userCardId: 'uc-dup',
    cardId: 'c-11',
    fullName: 'Kuzey Yıldızı',
    position: CardPosition.forward,
    power: 64,
    tier: CardTier.bronze,
    isLocked: true,
  ),
];

class _Repo implements CollectionRepository {
  List<InventoryCard> cards = _cards;
  bool catalogFails = false;

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async => Success(cards);

  @override
  Future<Result<List<CardModel>>> fetchCatalog() async => catalogFails
      ? const Failure(AppException.network())
      : Success([
          for (var i = 0; i < 100; i++)
            CardModel(
              cardId: 'c-$i',
              fullName: 'Kart $i',
              position: CardPosition.midfielder,
              tier: CardTier.bronze,
              power: 50,
            ),
        ]);

  @override
  Future<Result<int>> devGrantAllCards() async => const Success(0);
}

void main() {
  final skipGolden = v21GoldenSkipReason;
  late _Repo repo;

  setUpAll(() async {
    dotenv.loadFromString(envString: 'ENABLE_LOGGING=false');
    await loadV21Fonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    repo = _Repo();
    getIt.registerFactory<CollectionViewModel>(() => CollectionViewModel(repo));
  });

  Future<void> pump(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const RepaintBoundary(key: Key('screen'), child: V21CollectionScreen()),
      ),
    );
    await t.runAsync(() async {
      for (final a in V21Assets.all) {
        await precacheImage(AssetImage(a), t.element(find.byType(V21CollectionScreen)));
      }
    });
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('başlık, farklı kart / katalog sayısı ve kartlar sunucudan', (t) async {
    await pump(t, const Size(390, 844));
    expect(t.takeException(), isNull);
    expect(find.text('KARTLARIM'), findsOneWidget);
    expect(find.text('12 / 100'), findsOneWidget, reason: '13 kart, 12 farklı; katalog 100');
    expect(find.text('Efsane Kaptan'), findsOneWidget);
    expect(find.text('Usta Kaleci'), findsOneWidget);
    for (final p in ['GK', 'DEF', 'MID', 'FWD', 'TÜMÜ']) {
      expect(find.text(p), findsWidgets);
    }
    // KARTLAR sekmesi etkin
    final nav = t.widget<V21BottomNavigation>(find.byType(V21BottomNavigation));
    expect(nav.items[nav.activeIndex].label, 'KARTLAR');
  });

  testWidgets('nadirlik ve mevki filtreleri, TÜMÜ temizler', (t) async {
    await pump(t, const Size(390, 844));
    await t.tap(find.bySemanticsLabel(RegExp('^Efsane kartlar')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(V21PlayerCard), findsOneWidget);
    expect(find.text('Efsane Kaptan'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Tüm kartlar'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.widgetWithText(V21FilterPill, 'GK'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Usta Kaleci'), findsOneWidget);
    expect(find.text('Efsane Kaptan'), findsNothing);
  });

  testWidgets('katalog alınamazsa yalnız sahip olunan sayı (uydurma toplam yok)', (t) async {
    repo.catalogFails = true;
    await pump(t, const Size(390, 844));
    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining('/ 100'), findsNothing);
    expect(find.text('Efsane Kaptan'), findsOneWidget, reason: 'kartlar yine görünür');
  });

  testWidgets('arama metni süzer, FİLTRELERİ TEMİZLE kutuyu da boşaltır', (t) async {
    await pump(t, const Size(390, 844));
    await t.enterText(find.byType(TextField), 'kaleci');
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Usta Kaleci'), findsOneWidget);
    expect(find.text('Efsane Kaptan'), findsNothing);

    await t.enterText(find.byType(TextField), 'yokboyle');
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('FİLTRELERİ TEMİZLE'));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(find.text('Efsane Kaptan'), findsOneWidget);
  });

  testWidgets('favoriler: kalp işareti ve yalnız favoriler filtresi', (t) async {
    SharedPreferences.setMockInitialValues({
      'favori_kartlar': ['c-1'],
    });
    await pump(t, const Size(390, 844));
    expect(find.bySemanticsLabel(RegExp('Usta Kaleci, favori')), findsOneWidget);
    await t.tap(find.bySemanticsLabel(RegExp('^Yalnız favorileri göster')));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(V21PlayerCard), findsOneWidget);
    expect(find.text('Usta Kaleci'), findsOneWidget);
    // TÜMÜ favori filtresini de kaldırır
    await t.tap(find.bySemanticsLabel('Tüm kartlar'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Efsane Kaptan'), findsOneWidget);
  });

  testWidgets('sıralama sayfası: isme göre', (t) async {
    await pump(t, const Size(390, 844));
    await t.tap(find.bySemanticsLabel(RegExp('^Sıralama')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('SIRALA'), findsOneWidget);
    await t.tap(find.text(CollectionSort.nameAsc.label));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('SIRALA'), findsNothing, reason: 'sayfa kapandı');
    // İsme göre ilk kart: Altın Golcü
    final first = t.widget<V21PlayerCard>(find.byType(V21PlayerCard).first);
    expect(first.name, 'Altın Golcü');
    expect(find.bySemanticsLabel('Sıralama: ${CollectionSort.nameAsc.label}'), findsOneWidget);
  });

  testWidgets('boş koleksiyon mağazaya yönlendirir', (t) async {
    repo.cards = const [];
    await pump(t, const Size(390, 844));
    expect(find.text('MAĞAZAYA GİT'), findsOneWidget);
  });

  testWidgets('kilitli kart ekran okuyucuya bildirilir', (t) async {
    await pump(t, const Size(390, 844));
    await t.drag(find.byType(GridView), const Offset(0, -2000));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel(RegExp('kilitli\$')), findsOneWidget);
  });

  testWidgets('karta dokununca kart ayrıntısı açılır', (t) async {
    await pump(t, const Size(390, 844));
    await t.tap(find.text('Efsane Kaptan'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(V21CardDetailSheet), findsOneWidget);
  });

  group('duyarlı yerleşim', () {
    for (final size in kV21AllSizes) {
      testWidgets('${v21SizeName(size)} taşmaz', (t) async {
        await pump(t, size);
        expect(t.takeException(), isNull);
        expect(find.byType(size.width >= 1100 && size.height >= 600 ? WCard : V21PlayerCard), findsWidgets);
      });

      testWidgets('${v21SizeName(size)} golden', (t) async {
        await pump(t, size);
        await expectLater(
          find.byKey(const Key('screen')),
          matchesGoldenFile('goldens/v21_collection_${v21SizeName(size)}.png'),
        );
      }, skip: skipGolden != null || !v21GoldenFor(size));
    }
  });

  testWidgets('390×844 referans karşılaştırması (fark raporu)', (t) async {
    await pump(t, const Size(390, 844));
    final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(const Key('screen')));
    final report = await t.runAsync(
      () => compareWithReference(
        boundary,
        screen: 'collection',
        title: 'Koleksiyon',
        regions: const {
          'başlık (0-95)': (0, 95),
          'filtreler (95-195)': (95, 195),
          'kartlar (195-760)': (195, 760),
          'menü (760-844)': (760, 844),
        },
      ),
    );
    expect(report!['overall']!, lessThan(70));
  }, skip: skipGolden != null);
}
