import 'package:futbol_card/core/network/api_client.dart';

/// Small API client for private 2-player rooms.
class FriendRoomApi {
  final ApiClient api;
  FriendRoomApi(this.api);

  Future<Map<String, dynamic>> create() => api.post('/friends/create');
  Future<Map<String, dynamic>> join(String code) =>
      api.post('/friends/join', govde: {'code': code});
  Future<Map<String, dynamic>> status(String code) =>
      api.get('/friends/$code');
  Future<Map<String, dynamic>> ready(String code, String? deckId) =>
      api.post('/friends/$code/ready', govde: {'deck_id': deckId});
  Future<Map<String, dynamic>> leave(String code) =>
      api.post('/friends/$code/leave');

  Future<String?> activeDeck() async {
    final response = await api.get('/game/decks');
    for (final entry in response['decks'] as List? ?? const []) {
      if (entry is Map && entry['is_active'] == true) {
        return entry['id']?.toString();
      }
    }
    return null;
  }

  // A plain HTTPS API URL cannot open the app until verified App Links are set up.
  // The Android/iOS manifests register this custom scheme for test builds.
  static String inviteUrl(String code) => 'futbolcard:///davet/$code';
}
