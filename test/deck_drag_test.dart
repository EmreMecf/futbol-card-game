import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/di/injection.dart';
import 'package:futbol_card/core/theme/app_theme.dart';
import 'package:futbol_card/core/utils/result.dart';
import 'package:futbol_card/features/deck/domain/repositories/deck_repository.dart';
import 'package:futbol_card/features/deck/presentation/view/deck_view.dart';
import 'package:futbol_card/features/deck/presentation/viewmodel/deck_view_model.dart';
import 'package:shared_models/shared_models.dart';

/// FAZ 3 — Kadro ekranında sürükle-bırak (MD bölüm 4-E).
///
/// En önemli beklenti: Sürükle-bırak OYUN KURALINI DELMEMELİ.
/// Bir forvet defans yuvasına bırakılamaz; aynı mevki zorunluluğu
/// arayüzden de korunuyor.
void main() {
  InventoryCard kart(String id, CardPosition p, int guc) => InventoryCard(
        userCardId: id,
        cardId: 'c-$id',
        fullName: 'Oyuncu $id',
        position: p,
        tier: CardTier.bronze,
        power: guc,
      );

  /// Tam 4-4-2 kadro: slot -> kart
  Map<int, InventoryCard> tamKadro() => {
        0: kart('kl', CardPosition.goalkeeper, 60),
        for (var s = 1; s <= 4; s++) s: kart('df$s', CardPosition.defender, 50 + s),
        for (var s = 5; s <= 8; s++) s: kart('os$s', CardPosition.midfielder, 50 + s),
        9: kart('fv9', CardPosition.forward, 70),
        10: kart('fv10', CardPosition.forward, 80),
      };

  late DeckViewModel vm;

  // ViewModel kapanırken log yazıyor; log ayarı .env'den okunuyor.
  setUpAll(() => dotenv.loadFromString(envString: 'ENABLE_LOGGING=false'));

  setUp(() async {
    await getIt.reset();
    final kadro = tamKadro();
    final repo = _SahteRepo()
      ..slotlar = kadro
      ..envanter = kadro.values.toList();
    vm = DeckViewModel(repo);
    getIt.registerFactory<DeckViewModel>(() => vm);
  });

  tearDown(() => getIt.reset());

  Future<void> ac(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const DeckView()),
    );
    await tester.pumpAndSettle();
  }

  /// Bir slottaki kartın ekrandaki merkezi
  Offset kartMerkezi(WidgetTester tester, String userCardId) {
    final bul = find.byWidgetPredicate(
      (w) =>
          w is SquadSlotTile &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.endsWith('-$userCardId'),
    );
    return tester.getCenter(bul.first);
  }

  Future<void> surukle(WidgetTester tester, Offset bas, Offset bit) async {
    final parmak = await tester.startGesture(bas);
    await tester.pump(const Duration(milliseconds: 50));
    // Küçük adımlarla: Draggable kayma eşiğini aşsın
    for (var i = 1; i <= 10; i++) {
      await parmak.moveTo(Offset.lerp(bas, bit, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await parmak.up();
    await tester.pumpAndSettle();
  }

  testWidgets('aynı mevkiye bırakınca iki forvet YER DEĞİŞTİRİR',
      (tester) async {
    await ac(tester);
    expect(vm.cardAt(9)!.userCardId, 'fv9');
    expect(vm.cardAt(10)!.userCardId, 'fv10');

    await surukle(
      tester,
      kartMerkezi(tester, 'fv9'),
      kartMerkezi(tester, 'fv10'),
    );

    expect(tester.takeException(), isNull);
    expect(vm.cardAt(9)!.userCardId, 'fv10');
    expect(vm.cardAt(10)!.userCardId, 'fv9');
    expect(vm.hasUnsavedChanges, isTrue,
        reason: 'Değişiklik kaydedilmeye hazır olmalı');
  });

  testWidgets('FARKLI mevkiye bırakmak REDDEDİLİR (aynı mevki kuralı)',
      (tester) async {
    await ac(tester);

    // Forveti bir defans yuvasına sürükle
    await surukle(
      tester,
      kartMerkezi(tester, 'fv9'),
      kartMerkezi(tester, 'df2'),
    );

    expect(vm.cardAt(9)!.userCardId, 'fv9', reason: 'Forvet yerinde kalmalı');
    expect(vm.cardAt(2)!.userCardId, 'df2', reason: 'Defans yerinde kalmalı');
    expect(vm.hasUnsavedChanges, isFalse);
  });

  testWidgets('orta sahalar kendi aralarında yer değiştirir', (tester) async {
    await ac(tester);

    await surukle(
      tester,
      kartMerkezi(tester, 'os5'),
      kartMerkezi(tester, 'os8'),
    );

    expect(vm.cardAt(5)!.userCardId, 'os8');
    expect(vm.cardAt(8)!.userCardId, 'os5');
  });

  testWidgets('dokunmak hâlâ kart seçme penceresini açar', (tester) async {
    await ac(tester);

    await tester.tapAt(kartMerkezi(tester, 'kl'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
  });
}

class _SahteRepo implements DeckRepository {
  List<InventoryCard> envanter = const [];
  Map<int, InventoryCard> slotlar = const {};

  @override
  Future<Result<List<DeckSummary>>> fetchDecks() async => const Success([
        DeckSummary(id: 'd1', name: 'Kadrom', isActive: true, cardCount: 11),
      ]);

  @override
  Future<Result<Map<int, InventoryCard>>> fetchDeckSlots(String deckId) async =>
      Success(slotlar);

  @override
  Future<Result<List<InventoryCard>>> fetchDeckCards(String deckId) async =>
      Success(slotlar.values.toList());

  @override
  Future<Result<DeckChemistry>> fetchChemistry(String deckId) async =>
      const Success(DeckChemistry());

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() async =>
      Success(envanter);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('Bu test için gerekmiyor');
}
