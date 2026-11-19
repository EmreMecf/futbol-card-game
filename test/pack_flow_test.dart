import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/features/store/presentation/viewmodel/pack_opening_view_model.dart';
import 'package:futbol_card/features/store/domain/pack_texts.dart';
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

  });

  group('Paket sonucu ekranı', () {

  });
}
