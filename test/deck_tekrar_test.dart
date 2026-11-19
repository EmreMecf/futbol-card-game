import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/deck/presentation/viewmodel/deck_view_model.dart';
import 'package:futbol_card/features/matchmaking/presentation/viewmodel/matchmaking_view_model.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'goldens/sahte_veri.dart';

/// Bir futbolcu kadroda yalnız bir kez olabilir: aynı futbolcunun iki kopyası
/// farklı `userCardId`, aynı `cardId` taşır.
InventoryCard _kopya(InventoryCard k, String id, {int? guc}) =>
    k.copyWith(userCardId: id, power: guc ?? k.power, inDeck: false);

class _Repo extends GoldenDeckRepo {
  final List<InventoryCard> envanter;
  final kayitlar = <List<String>>[];
  _Repo(Map<int, InventoryCard> super.slotlar, this.envanter);

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async => Success(envanter);

  @override
  Future<Result<DeckValidation>> saveDeck({
    required String deckId,
    required List<String> userCardIds,
    bool setActive = true,
  }) async {
    kayitlar.add(userCardIds);
    return const Success(DeckValidation(isValid: true));
  }
}

class _Eslesme extends GoldenMatchmakingRepo {
  final List<InventoryCard> kartlar;
  _Eslesme(this.kartlar);
  @override
  Future<Result<List<InventoryCard>>> fetchDeckCards(String deckId) async => Success(kartlar);
}

void main() {
  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final forvet = kGoldenSquad[9]!;
  final ikinciForvet = kGoldenSquad[10]!;

  Future<DeckViewModel> kur(Map<int, InventoryCard> slotlar, List<InventoryCard> envanter) async {
    final vm = DeckViewModel(_Repo(slotlar, envanter));
    await vm.load();
    return vm;
  }

  test('kadrodaki futbolcunun kopyası diğer yuvanın listesinde çıkmaz', () async {
    final kopya = _kopya(forvet, 'kopya');
    final vm = await kur({9: forvet}, [forvet, kopya, ikinciForvet]);
    expect(vm.availableForSlot(10).map((k) => k.userCardId), [ikinciForvet.userCardId]);
  });

  test('kendi yuvasında aynı futbolcunun kopyasıyla değiştirilebilir', () async {
    final kopya = _kopya(forvet, 'kopya');
    final vm = await kur({9: forvet}, [forvet, kopya]);
    expect(vm.availableForSlot(9).map((k) => k.userCardId), containsAll([forvet.userCardId, 'kopya']));
    expect(vm.placeCard(9, kopya), isTrue);
    expect(vm.cardAt(9)!.userCardId, 'kopya');
  });

  test('kopya başka yuvaya konamaz; aynı kart yer değiştirebilir', () async {
    final kopya = _kopya(forvet, 'kopya');
    final vm = await kur({9: forvet}, [forvet, kopya, ikinciForvet]);
    expect(vm.placeCard(10, kopya), isFalse);
    expect(vm.cardAt(10), isNull);
    expect(vm.placeCard(10, forvet), isTrue);
    expect(vm.cardAt(10)!.userCardId, forvet.userCardId);
    expect(vm.cardAt(9), isNull);
  });

  test('otomatik dizilimler aynı futbolcuyu iki kez koymaz', () async {
    final envanter = [
      ...kGoldenSquad.values,
      for (final k in kGoldenSquad.values) _kopya(k, 'kopya-${k.userCardId}', guc: k.power + 3),
    ];
    final vm = await kur(const {}, envanter);
    vm.autoFillBest();
    expect(vm.selectedCards.map((k) => k.cardId).toSet(), hasLength(11));
    vm.clearAll();
    vm.autoFillByChemistry();
    expect(vm.selectedCards.map((k) => k.cardId).toSet(), hasLength(11));
    expect(vm.duplicateMessage, isNull);
  });

  test('eski tekrarlı kadro kaydedilemez; otomatik diz düzeltir', () async {
    final kopya = _kopya(forvet, 'kopya', guc: forvet.power + 5).copyWith(position: CardPosition.forward);
    final slotlar = {...kGoldenSquad, 10: kopya};
    final repo = _Repo(slotlar, [...kGoldenSquad.values, kopya]);
    final vm = DeckViewModel(repo);
    await vm.load();
    expect(vm.duplicateMessage, contains(forvet.fullName));
    expect(vm.firstDuplicateSlot, isNotNull);
    expect(await vm.save(), isFalse);
    expect(repo.kayitlar, isEmpty);

    vm.autoFillBest();
    expect(vm.duplicateMessage, isNull);
    expect(vm.isComplete, isTrue);
    expect(vm.selectedCards.where((k) => k.cardId == forvet.cardId).single.userCardId, 'kopya');
    expect(await vm.save(), isTrue);
    expect(repo.kayitlar, hasLength(1));
  });

  test('tekrarlı kadroyla maç aranamaz', () async {
    final oturum = await goldenSession();
    final kartlar = [...kGoldenSquad.values.take(10), _kopya(forvet, 'kopya')];
    final vm = MatchmakingViewModel(_Eslesme(kartlar), GoldenSocket(), oturum);
    await vm.initialize();
    expect(vm.validation?.isValid, isFalse);
    expect(vm.validation?.message, contains(forvet.fullName));
    expect(vm.canSearch, isFalse);
    vm.dispose();
  });
}
