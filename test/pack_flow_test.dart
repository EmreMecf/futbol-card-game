import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/store/presentation/viewmodel/pack_opening_view_model.dart';
import 'package:futbol_card/features/store/presentation/widgets/pack_reveal_view.dart';
import 'package:futbol_card/features/store/presentation/widgets/pack_seal_scene.dart';
import 'package:shared_models/shared_models.dart';

/// FAZ 6 — Mühürlü paket (dokunarak açma) ve paket sonucu ekranı.
void main() {
  InventoryCard kart(String id, CardTier t, int g) => InventoryCard(
        userCardId: id,
        cardId: 'c$id',
        fullName: 'Oyuncu $id',
        position: CardPosition.midfielder,
        tier: t,
        power: g,
      );

  // Sunucu sırası: en iyiden kötüye
  PackOpenResult paket([List<InventoryCard>? kartlar]) => PackOpenResult(
        packSlug: 'standart',
        packName: 'Kadro Paketi',
        coinsLeft: 400,
        cards: kartlar ??
            [
              kart('1', CardTier.gold, 84),
              kart('2', CardTier.silver, 72),
              kart('3', CardTier.bronze, 60),
            ],
      );

  group('PackOpeningViewModel mühür', () {
    test('paket mühürlü başlar, unseal ile açılır', () {
      final vm = PackOpeningViewModel(paket());
      expect(vm.isSealed, isTrue);
      vm.unseal();
      expect(vm.isSealed, isFalse);
      expect(vm.revealedCount, 0, reason: 'Mühür kart harcamaz');
    });

    test('mühürlüyken "hepsini göster" doğrudan özete gider', () {
      final vm = PackOpeningViewModel(paket())..revealAll();
      expect(vm.isSealed, isFalse);
      expect(vm.isFinished, isTrue);
    });

    test('boş pakette mühür sahnesi yok', () {
      expect(PackOpeningViewModel(paket(const [])).isSealed, isFalse);
    });
  });

  Future<void> ac(WidgetTester t, Widget w, {Size boyut = const Size(390, 844)}) async {
    t.view.physicalSize = boyut;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(theme: AppTheme.dark, home: w));
    await t.pump();
  }

  group('Akış', () {
    testWidgets('mühürlü paket -> dokun -> ilk kart açılır', (t) async {
      await ac(t, PackRevealView(result: paket(), onClose: () {}));

      expect(find.byType(PackSealScene), findsOneWidget);
      expect(find.text('AÇMAK İÇİN DOKUN'), findsOneWidget);
      expect(find.text('3 kart seni bekliyor'), findsOneWidget);

      await t.tap(find.byType(PackSealScene));
      await t.pump(); // animasyon bu karede başlar
      await t.pump(PackSealScene.openDuration);
      await t.pump(const Duration(milliseconds: 50));

      expect(find.byType(PackSealScene), findsNothing);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('mühürlüyken "Hepsini göster" paket sonucuna atlar',
        (t) async {
      var kapandi = 0;
      await ac(t, PackRevealView(result: paket(), onClose: () => kapandi++));

      await t.tap(find.text('Hepsini göster'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));

      expect(find.byType(PackSummaryView), findsOneWidget);
      expect(find.text('PAKET AÇILDI'), findsOneWidget);
      expect(find.text('KADRO PAKETİ'), findsOneWidget,
          reason: 'Türkçe büyük harf: i -> İ');
      expect(find.text('EN İYİ KART'), findsOneWidget);
      expect(find.text('3 kart koleksiyonuna eklendi · kalan 400 coin'),
          findsOneWidget);

      await t.tap(find.text('TAMAM'));
      expect(kapandi, 1);
    });
  });

  group('Paket sonucu ekranı', () {
    testWidgets('seviye dağılımı en yüksekten sayılır', (t) async {
      await ac(
        t,
        PackSummaryView(
          result: paket([
            kart('1', CardTier.legend, 93),
            kart('2', CardTier.gold, 80),
            kart('3', CardTier.gold, 78),
            kart('4', CardTier.bronze, 55),
          ]),
          onClose: () {},
        ),
      );
      await t.pump(const Duration(milliseconds: 400));

      expect(find.text('1 ×'), findsNWidgets(2)); // Legend ve Bronz
      expect(find.text('2 ×'), findsOneWidget); // Altın
      expect(t.takeException(), isNull);
    });

    testWidgets('15 kartlık paket küçük telefonda taşmaz', (t) async {
      await ac(
        t,
        PackSummaryView(
          result: paket([
            for (var i = 0; i < 15; i++)
              kart('$i', CardTier.values[i % 4], 60 + i),
          ]),
          onClose: () {},
        ),
        boyut: const Size(360, 640),
      );
      await t.pump(const Duration(milliseconds: 400));
      expect(t.takeException(), isNull);
    });
  });
}
