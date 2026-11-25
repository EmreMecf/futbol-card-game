import 'package:futbol_card/core/config/app_config.dart';
import 'package:futbol_card/core/network/api_client.dart';

import 'friend_room_view_model.dart';

/// İki kişilik özel oda uçları.
class FriendRoomApi implements FriendRoomGateway {
  final ApiClient api;
  FriendRoomApi(this.api);

  @override
  Future<Map<String, dynamic>> create() => api.post('/friends/create');
  @override
  Future<Map<String, dynamic>> join(String code) =>
      api.post('/friends/join', govde: {'code': code});
  @override
  Future<Map<String, dynamic>> status(String code) =>
      api.get('/friends/$code');
  @override
  Future<Map<String, dynamic>> ready(String code, String? deckId) =>
      api.post('/friends/$code/ready', govde: {'deck_id': deckId});
  @override
  Future<Map<String, dynamic>> leave(String code) =>
      api.post('/friends/$code/leave');

  @override
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
  /// tıklanabilir yapar. Açılan sayfa oyunu açar (Android'de intent adresiyle).
  static String inviteUrl(String code) => inviteUrlFor(AppConfig.apiBaseUrl, code);

  static String inviteUrlFor(String baseUrl, String code) => '$baseUrl/invite/$code';

  /// Uygulamayı açan bağlantıdan davet kodu. Kabul edilen biçimler:
  ///   `futbolcard://davet/KOD`   (Android intent adresi, yeni sayfa)
  ///   `futbolcard:///davet/KOD`  (eski sayfa ve eski mesajlar)
  /// Geçersizse null.
  static String? inviteCodeFromUri(Uri uri) {
    if (uri.scheme.toLowerCase() != 'futbolcard') return null;
    final parts = [
      if (uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ];
    if (parts.length != 2 || parts[0].toLowerCase() != 'davet') return null;
    final code = parts[1].toLowerCase();
    return RegExp(r'^[0-9a-f]{30}$').hasMatch(code) ? code : null;
  }
}
