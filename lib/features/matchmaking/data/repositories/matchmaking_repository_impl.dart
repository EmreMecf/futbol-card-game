import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';
import '../../domain/repositories/matchmaking_repository.dart';
import '../datasources/matchmaking_remote_datasource.dart';

class MatchmakingRepositoryImpl implements MatchmakingRepository {
  final MatchmakingRemoteDataSource _remote;

  MatchmakingRepositoryImpl(this._remote);

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
      final ham = cevap['cards'] as List? ?? const [];
      return ham
          .map((k) => InventoryCard.fromJson(k as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<Result<DeckValidation>> validateDeck(String deckId) {
    return Result.guard(() async {
      return DeckValidation.fromJson(await _remote.validateDeck(deckId));
    });
  }

  @override
  Future<Result<MatchFindResult>> findMatch({
    required String deckId,
    List<String> protectedCardIds = const [],
  }) {
    return Result.guard(() async {
      final cevap = await _remote.findMatch(
        deckId: deckId,
        protectedCardIds: protectedCardIds,
      );
      return MatchFindResult.fromJson(cevap);
    });
  }

  @override
  Future<Result<MatchFindResult>> cancelMatchmaking() {
    return Result.guard(() async {
      return MatchFindResult.fromJson(await _remote.cancel());
    });
  }

  @override
  Future<Result<String?>> activeMatchId() {
    return Result.guard(() async {
      final cevap = await _remote.active();
      return cevap['match_id']?.toString();
    });
  }
}
