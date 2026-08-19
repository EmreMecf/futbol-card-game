import '../../../../core/network/api_client.dart';

class DeckRemoteDataSource {
  final ApiClient _api;

  DeckRemoteDataSource(this._api);

  Future<Map<String, dynamic>> decks() => _api.get('/game/decks');

  Future<Map<String, dynamic>> deckCards(String deckId) =>
      _api.get('/game/decks/$deckId/cards');

  Future<Map<String, dynamic>> inventory() => _api.get('/game/inventory');

  Future<Map<String, dynamic>> validate(String deckId) =>
      _api.get('/game/decks/$deckId/validate');

  Future<Map<String, dynamic>> save({
    required String deckId,
    required List<String> userCardIds,
    required bool setActive,
  }) {
    return _api.put('/game/decks/$deckId', govde: {
      'user_card_ids': userCardIds,
      'set_active': setActive,
    });
  }

  Future<Map<String, dynamic>> create(String name) =>
      _api.post('/game/decks', govde: {'name': name});

  Future<Map<String, dynamic>> chemistry(String deckId) =>
      _api.get('/game/decks/$deckId/chemistry');
}
