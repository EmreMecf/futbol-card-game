import '../../../../core/network/api_client.dart';

class StoreRemoteDataSource {
  final ApiClient _api;

  StoreRemoteDataSource(this._api);

  Future<Map<String, dynamic>> packs() => _api.get('/game/packs');

  Future<Map<String, dynamic>> open(String slug) =>
      _api.post('/game/packs/$slug/open');
}
