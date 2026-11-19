import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/collection/domain/repositories/collection_repository.dart';
import 'package:futbol_card/features/collection/presentation/viewmodel/collection_view_model.dart';
import 'package:shared_models/shared_models.dart';

/// Koleksiyon ekraninin 100 kartlik kadro ile dogru calistigini dogrular.
void main() {
  // ==================================================================
  // 100 KARTLIK SAHTE KADRO
  // ==================================================================
  // Gercek katalogla ayni dagilimi kullaniyoruz ki testler gercek
  // veriyi temsil etsin.
  List<InventoryCard> testKadrosu() {
    const dagilim = {
      CardTier.bronze: {
        CardPosition.goalkeeper: 4,
        CardPosition.defender: 9,
        CardPosition.midfielder: 10,
        CardPosition.forward: 7,
      },
      CardTier.silver: {
        CardPosition.goalkeeper: 3,
        CardPosition.defender: 9,
        CardPosition.midfielder: 9,
        CardPosition.forward: 7,
      },
      CardTier.gold: {
        CardPosition.goalkeeper: 3,
        CardPosition.defender: 7,
        CardPosition.midfielder: 8,
        CardPosition.forward: 6,
      },
      CardTier.diamond: {
        CardPosition.goalkeeper: 1,
        CardPosition.defender: 4,
        CardPosition.midfielder: 4,
        CardPosition.forward: 3,
      },
      CardTier.legend: {
        CardPosition.goalkeeper: 1,
        CardPosition.defender: 1,
        CardPosition.midfielder: 2,
        CardPosition.forward: 2,
      },
    };

    const gucAraliklari = {
      CardTier.bronze: [45, 62],
      CardTier.silver: [63, 74],
      CardTier.gold: [75, 85],
      CardTier.diamond: [86, 92],
      CardTier.legend: [94, 99],
    };

    final kartlar = <InventoryCard>[];
    var sayac = 0;

    dagilim.forEach((seviye, pozisyonlar) {
      pozisyonlar.forEach((pozisyon, adet) {
        final aralik = gucAraliklari[seviye]!;
        for (var i = 0; i < adet; i++) {
          final guc = aralik[0] + (i % (aralik[1] - aralik[0] + 1));
          kartlar.add(InventoryCard(
            userCardId: 'uc-$sayac',
            cardId: 'c-$sayac',
            fullName: 'Oyuncu $sayac',
            position: pozisyon,
            tier: seviye,
            power: guc,
            club: 'Test FC',
            nationality: 'TUR',
          ));
          sayac++;
        }
      });
    });

    return kartlar;
  }

  group('CollectionViewModel', () {
    late CollectionViewModel vm;

    setUp(() async {
      vm = CollectionViewModel(_SahteRepository(testKadrosu()));
      await vm.load();
    });

    test('100 kart yuklenir', () {
      expect(vm.totalCards, 100);
      expect(vm.filteredCards.length, 100);
    });

    test('seviye dagilimi dogru sayilir', () {
      expect(vm.tierCounts[CardTier.bronze], 30);
      expect(vm.tierCounts[CardTier.silver], 28);
      expect(vm.tierCounts[CardTier.gold], 24);
      expect(vm.tierCounts[CardTier.diamond], 12);
      expect(vm.tierCounts[CardTier.legend], 6);

      final toplam = vm.tierCounts.values.reduce((a, b) => a + b);
      expect(toplam, 100);
    });

    test('pozisyon dagilimi kadro kurmaya yeter', () {
      expect(vm.positionCounts[CardPosition.goalkeeper], 12);
      expect(vm.positionCounts[CardPosition.defender], 30);
      expect(vm.positionCounts[CardPosition.midfielder], 33);
      expect(vm.positionCounts[CardPosition.forward], 25);

      expect(vm.canBuildSquad, isTrue,
          reason: '1 GK + 4 DEF + 4 MID + 2 FWD kurulabilmeli');
    });

    test('en guclu kart Legend olmali', () {
      expect(vm.bestCard, isNotNull);
      expect(vm.bestCard!.tier, CardTier.legend);
    });

    test('seviye filtresi calisir ve ayni tusa basinca kalkar', () {
      vm.setTierFilter(CardTier.legend);
      expect(vm.filteredCards.length, 6);
      expect(vm.hasActiveFilter, isTrue);

      // Ayni seviyeye tekrar basmak filtreyi kaldirir
      vm.setTierFilter(CardTier.legend);
      expect(vm.filteredCards.length, 100);
      expect(vm.hasActiveFilter, isFalse);
    });

    test('seviye ve pozisyon filtreleri birlikte calisir', () {
      vm.setTierFilter(CardTier.gold);
      vm.setPositionFilter(CardPosition.goalkeeper);

      expect(vm.filteredCards.length, 3);
      expect(
        vm.filteredCards.every(
          (k) => k.tier == CardTier.gold &&
              k.position == CardPosition.goalkeeper,
        ),
        isTrue,
      );
    });

    test('arama isim icinde gecer', () {
      vm.setSearch('Oyuncu 5');
      // "Oyuncu 5", "Oyuncu 50".."Oyuncu 59" -> 11 sonuc
      expect(vm.filteredCards.length, 11);

      vm.setSearch('bulunmayan');
      expect(vm.filteredCards, isEmpty);
    });

    test('siralama secenekleri dogru calisir', () {
      vm.setSort(CollectionSort.powerDesc);
      var liste = vm.filteredCards;
      expect(liste.first.power, greaterThanOrEqualTo(liste.last.power));

      vm.setSort(CollectionSort.powerAsc);
      liste = vm.filteredCards;
      expect(liste.first.power, lessThanOrEqualTo(liste.last.power));

      vm.setSort(CollectionSort.tierDesc);
      liste = vm.filteredCards;
      expect(liste.first.tier, CardTier.legend);
      expect(liste.last.tier, CardTier.bronze);
    });

    test('filtreleri temizle hepsini sifirlar', () {
      vm.setTierFilter(CardTier.diamond);
      vm.setPositionFilter(CardPosition.forward);
      vm.setSearch('Oyuncu');
      expect(vm.hasActiveFilter, isTrue);

      vm.clearFilters();
      expect(vm.hasActiveFilter, isFalse);
      expect(vm.filteredCards.length, 100);
    });
  });

}

/// Testlerde gercek sunucu yerine bellekten veri veren sahte repository
class _SahteRepository implements CollectionRepository {
  final List<InventoryCard> _kartlar;

  _SahteRepository(this._kartlar);

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async =>
      Success(_kartlar);

  @override
  Future<Result<List<CardModel>>> fetchCatalog() async =>
      Success(_kartlar.map((k) => k.toCardModel()).toList());

  @override
  Future<Result<int>> devGrantAllCards() async => Success(_kartlar.length);
}
