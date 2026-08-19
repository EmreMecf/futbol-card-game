import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';
import '../../domain/repositories/deck_repository.dart';
import '../datasources/deck_remote_datasource.dart';

class DeckRepositoryImpl implements DeckRepository {
  final DeckRemoteDataSource _remote;

  DeckRepositoryImpl(this._remote);

  @override
  Future<Result<List<DeckSummary>>> fetchDecks() {
    return Result.guard(() async {
      final cevap = await _remote.decks();
      final ham = cevap['decks'] as List? ?? const [];
      return ham
          .map((d) => DeckSummary.fromJson(d as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<Result<List<InventoryCard>>> fetchDeckCards(String deckId) {
    return Result.guard(() async {
      final cevap = await _remote.deckCards(deckId);
      return _kartlar(cevap);
    });
  }

  @override
  Future<Result<Map<int, InventoryCard>>> fetchDeckSlots(String deckId) {
    return Result.guard(() async {
      return _slotHaritasi(await _remote.deckCards(deckId));
    });
  }

  @override
  Future<Result<List<InventoryCard>>> fetchInventory() {
    return Result.guard(() async {
      final cevap = await _remote.inventory();
      return _kartlar(cevap);
    });
  }

  @override
  Future<Result<DeckValidation>> validateDeck(String deckId) {
    return Result.guard(() async {
      return DeckValidation.fromJson(await _remote.validate(deckId));
    });
  }

  @override
  Future<Result<DeckValidation>> saveDeck({
    required String deckId,
    required List<String> userCardIds,
    bool setActive = true,
  }) {
    return Result.guard(() async {
      final cevap = await _remote.save(
        deckId: deckId,
        userCardIds: userCardIds,
        setActive: setActive,
      );

      // Sunucu kaydetme cevabinda dogrulama sonucunu da doner
      return DeckValidation(
        isValid: cevap['is_valid'] == true,
        message: cevap['validation_message'] as String?,
      );
    });
  }

  @override
  Future<Result<DeckChemistry>> fetchChemistry(String deckId) {
    return Result.guard(() async {
      return DeckChemistry.fromJson(await _remote.chemistry(deckId));
    });
  }

  @override
  Future<Result<DeckSummary>> createDeck(String name) {
    return Result.guard(() async {
      final cevap = await _remote.create(name);
      return DeckSummary.fromJson(cevap['deck'] as Map<String, dynamic>);
    });
  }

  List<InventoryCard> _kartlar(Map<String, dynamic> cevap) {
    final ham = cevap['cards'] as List? ?? const [];
    return ham
        .map((k) => InventoryCard.fromJson(k as Map<String, dynamic>))
        .toList();
  }

  /// Deste kartlarini SLOT NUMARASIYLA birlikte doner.
  ///
  /// slot_index modelde yok (envanter kartinin genel bir ozelligi degil,
  /// sadece bir destedeki yerini anlatiyor), bu yuzden ayri bir harita
  /// olarak tasiyoruz.
  Map<int, InventoryCard> _slotHaritasi(Map<String, dynamic> cevap) {
    final ham = cevap['cards'] as List? ?? const [];
    final harita = <int, InventoryCard>{};

    for (final k in ham) {
      final json = k as Map<String, dynamic>;
      final slot = json['slot_index'];
      if (slot is! int) continue;
      harita[slot] = InventoryCard.fromJson(json);
    }
    return harita;
  }
}
