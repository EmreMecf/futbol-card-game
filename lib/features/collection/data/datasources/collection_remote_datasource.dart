import '../../../../core/network/api_client.dart';

/// Koleksiyon uc noktalariyla ham iletisim.
class CollectionRemoteDataSource {
  final ApiClient _api;

  CollectionRemoteDataSource(this._api);

  Future<Map<String, dynamic>> inventory() => _api.get('/game/inventory');

  Future<Map<String, dynamic>> catalog() => _api.get('/game/cards');

  /// SADECE GELISTIRME
  Future<Map<String, dynamic>> grantAllCards() =>
      _api.post('/game/dev/grant-all-cards');
}
