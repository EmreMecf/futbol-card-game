import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';
import '../../domain/repositories/match_repository.dart';
import '../datasources/match_remote_datasource.dart';

class MatchRepositoryImpl implements MatchRepository {
  final MatchRemoteDataSource _remote;

  MatchRepositoryImpl(this._remote);

  @override
  Future<Result<MatchState>> fetchState(String matchId) {
    return Result.guard(() async {
      return MatchState.fromJson(await _remote.state(matchId));
    });
  }

  @override
  Future<Result<List<HandCard>>> fetchHand(String matchId) {
    return Result.guard(() async {
      final cevap = await _remote.hand(matchId);
      final ham = cevap['cards'] as List? ?? const [];
      return ham
          .map((k) => HandCard.fromJson(k as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<Result<List<MatchHistoryEntry>>> fetchMatchHistoryList({
    int limit = 20,
    int offset = 0,
  }) {
    return Result.guard(() async {
      final cevap = await _remote.matchHistoryList(
        limit: limit,
        offset: offset,
      );
      final ham = cevap['matches'] as List? ?? const [];
      return ham
          .map((m) => MatchHistoryEntry.fromJson(m as Map<String, dynamic>))
          .toList();
    });
  }

  @override
  Future<Result<MatchHistory>> fetchHistory(String matchId) {
    return Result.guard(() async {
      return MatchHistory.fromJson(await _remote.history(matchId));
    });
  }

  @override
  Future<Result<PlayCardResult>> playCard({
    required String matchId,
    String? userCardId,
  }) {
    return Result.guard(() async {
      return PlayCardResult.fromJson(
        await _remote.play(matchId, userCardId),
      );
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> claimTimeout(String matchId) =>
      Result.guard(() => _remote.timeout(matchId));

  @override
  Future<Result<Map<String, dynamic>>> surrender(String matchId) =>
      Result.guard(() => _remote.surrender(matchId));

  @override
  Future<Result<MatchResultSummary>> fetchResult(String matchId) {
    return Result.guard(() async {
      return MatchResultSummary.fromJson(await _remote.result(matchId));
    });
  }
}
