import '../../../../core/network/api_client.dart';

/// Eslestirme uc noktalariyla ham iletisim.
class MatchmakingRemoteDataSource {
  final ApiClient _api;

  MatchmakingRemoteDataSource(this._api);

  Future<Map<String, dynamic>> decks() => _api.get('/game/decks');

  Future<Map<String, dynamic>> deckCards(String deckId) =>
      _api.get('/game/decks/$deckId/cards');

  Future<Map<String, dynamic>> validateDeck(String deckId) =>
      _api.get('/game/decks/$deckId/validate');

  Future<Map<String, dynamic>> findMatch({
    required String deckId,
    required List<String> protectedCardIds,
  }) {
    return _api.post('/match/find', govde: {
      'deck_id': deckId,
      'protected_card_ids': protectedCardIds,
    });
  }

  Future<Map<String, dynamic>> cancel() => _api.post('/match/cancel');

  Future<Map<String, dynamic>> active() => _api.get('/match/active');
}
