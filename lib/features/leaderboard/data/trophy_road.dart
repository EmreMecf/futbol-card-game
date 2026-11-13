import 'package:shared_models/shared_models.dart';

import '../../../core/network/api_client.dart';

/// 043: KUPA YOLU — basamak ödülleri ve oyuncunun durumu.
/// Okunamazsa null: Ligler ekranı bugünkü gibi (ödülsüz) görünür.
Future<TrophyRoad?> fetchTrophyRoad(ApiClient api) async {
  try {
    return TrophyRoad.fromJson(await api.get('/leaderboard/trophy-road'));
  } catch (_) {
    return null;
  }
}
