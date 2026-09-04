import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';

/// Lig ve liderlik islemlerinin sozlesmesi.
abstract interface class LeaderboardRepository {
  /// Siralanmis oyuncu listesi. Oyuncunun kendi sirasi da doner.
  Future<Result<Leaderboard>> fetchLeaderboard({int limit, int offset});

  /// Oyuncunun lig basamagi ve bir sonrakine ilerlemesi.
  Future<Result<PlayerRank>> fetchMyRank();
}
