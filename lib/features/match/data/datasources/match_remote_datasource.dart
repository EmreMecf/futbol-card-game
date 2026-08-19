import '../../../../core/network/api_client.dart';

/// Mac uc noktalariyla ham iletisim.
class MatchRemoteDataSource {
  final ApiClient _api;

  MatchRemoteDataSource(this._api);

  Future<Map<String, dynamic>> state(String matchId) =>
      _api.get('/match/$matchId/state');

  Future<Map<String, dynamic>> hand(String matchId) =>
      _api.get('/match/$matchId/hand');

  Future<Map<String, dynamic>> history(String matchId) =>
      _api.get('/match/$matchId/moves');

  Future<Map<String, dynamic>> result(String matchId) =>
      _api.get('/match/$matchId/result');

  Future<Map<String, dynamic>> play(String matchId, String? userCardId) {
    return _api.post('/match/$matchId/play', govde: {
      'user_card_id': ?userCardId,
    });
  }

  Future<Map<String, dynamic>> timeout(String matchId) =>
      _api.post('/match/$matchId/timeout');

  Future<Map<String, dynamic>> surrender(String matchId) =>
      _api.post('/match/$matchId/surrender');
}
