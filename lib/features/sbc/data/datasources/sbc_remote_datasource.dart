import '../../../../core/network/api_client.dart';

class SbcRemoteDataSource {
  final ApiClient _api;

  SbcRemoteDataSource(this._api);

  Future<Map<String, dynamic>> challenges() => _api.get('/sbc');

  Future<Map<String, dynamic>> inventory() => _api.get('/game/inventory');

  Future<Map<String, dynamic>> evaluate(
    String challengeId,
    List<String> userCardIds,
  ) {
    return _api.post('/sbc/$challengeId/evaluate',
        govde: {'user_card_ids': userCardIds});
  }

  Future<Map<String, dynamic>> submit(
    String challengeId,
    List<String> userCardIds,
  ) {
    return _api.post('/sbc/$challengeId/submit',
        govde: {'user_card_ids': userCardIds});
  }
}
