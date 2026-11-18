import 'package:futbol_card/core/config/app_config.dart';
import 'package:futbol_card/core/network/api_client.dart';

/// İki kişilik özel oda uçları.
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

  /// Paylaşılan bağlantı HTTPS'tir: mesajlaşma uygulamaları yalnız bunu
  /// tıklanabilir yapar. Açılan sayfa oyunu `futbolcard:///davet/<kod>` ile açar.
  static String inviteUrl(String code) => inviteUrlFor(AppConfig.apiBaseUrl, code);

  static String inviteUrlFor(String baseUrl, String code) => '$baseUrl/invite/$code';
}
