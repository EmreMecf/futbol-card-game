import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';
import '../../domain/repositories/leaderboard_repository.dart';
import '../datasources/leaderboard_remote_datasource.dart';

class LeaderboardRepositoryImpl implements LeaderboardRepository {
  final LeaderboardRemoteDataSource _remote;

  LeaderboardRepositoryImpl(this._remote);

  @override
  Future<Result<Leaderboard>> fetchLeaderboard({
    int limit = 50,
    int offset = 0,
  }) {
    return Result.guard(() async {
      final cevap = await _remote.leaderboard(limit: limit, offset: offset);
      final ham = cevap['entries'] as List? ?? const [];

      return Leaderboard(
        entries: ham
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        myPosition: (cevap['my_position'] as num?)?.toInt(),
        amIInList: cevap['am_i_in_list'] as bool? ?? false,
      );
    });
  }

  @override
  Future<Result<PlayerRank>> fetchMyRank() {
    return Result.guard(() async {
      return PlayerRank.fromJson(await _remote.myRank());
    });
  }
}
