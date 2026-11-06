import 'package:shared_models/shared_models.dart';

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

  /// Oyuncunun BITMIS maclari (profil ekrani).
  /// Tek bir macin degil, tum gecmisin listesi.
  Future<Map<String, dynamic>> matchHistoryList({
    int limit = 20,
    int offset = 0,
  }) =>
      _api.get('/match/history', sorgu: {
        'limit': '$limit',
        'offset': '$offset',
      });

  /// [tactic] "taktik yok" ise hiç gönderilmez (sunucu varsayılanı).
  Future<Map<String, dynamic>> play(
    String matchId,
    String? userCardId, {
    MatchTactic tactic = MatchTactic.none,
  }) {
    return _api.post('/match/$matchId/play', govde: {
      'user_card_id': ?userCardId,
      if (!tactic.isNone) 'tactic': tactic.code,
    });
  }

  Future<Map<String, dynamic>> timeout(String matchId) =>
      _api.post('/match/$matchId/timeout');

  Future<Map<String, dynamic>> surrender(String matchId) =>
      _api.post('/match/$matchId/surrender');
}
