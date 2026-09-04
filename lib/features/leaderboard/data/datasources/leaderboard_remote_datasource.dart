import '../../../../core/network/api_client.dart';

/// Lig ve liderlik uc noktalariyla ham iletisim.
class LeaderboardRemoteDataSource {
  final ApiClient _api;

  LeaderboardRemoteDataSource(this._api);

  /// Siralanmis oyuncu listesi + oyuncunun kendi sirasi
  Future<Map<String, dynamic>> leaderboard({
    int limit = 50,
    int offset = 0,
  }) =>
      _api.get('/leaderboard', sorgu: {
        'limit': '$limit',
        'offset': '$offset',
      });

  /// Oyuncunun lig basamagi ve ilerlemesi
  Future<Map<String, dynamic>> myRank() => _api.get('/leaderboard/rank');

  /// Butun lig basamaklarinin tanimi (Ligler tanitim ekrani)
  Future<Map<String, dynamic>> tiers() => _api.get('/leaderboard/tiers');
}
