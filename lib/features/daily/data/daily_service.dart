import 'package:shared_models/shared_models.dart';

import '../../../core/network/api_client.dart';

/// 044: GÜNLÜK DÖNGÜ ve GÜNÜN TEKLİFİ uçları.
///
/// Anahtarlar kapalıysa ya da sunucu eskiyse null döner; arayüz bu
/// bölümleri hiç göstermez (bugünkü görünüm).
class DailyLoopService {
  final ApiClient _api;
  DailyLoopService(this._api);

  Future<DailyStatus?> status() async {
    try {
      return DailyStatus.fromJson(await _api.get('/economy/daily'));
    } catch (_) {
      return null;
    }
  }

  /// Bugünün sandığını al. Aynı gün tekrar çağrılırsa sunucu aynı sandığı döner.
  Future<Map<String, dynamic>> claim() =>
      _api.postIdempotent('/economy/daily/claim', anahtar: ApiClient.newIdempotencyKey());

  Future<DailyShopStatus?> shop() async {
    try {
      return DailyShopStatus.fromJson(await _api.get('/economy/daily-shop'));
    } catch (_) {
      return null;
    }
  }

  /// Günün teklifini al: paket açılır, sonuç açılış animasyonuna gider.
  Future<PackOpenResult> buyOffer() async {
    final cevap = await _api.postIdempotent('/economy/daily-shop/buy', anahtar: ApiClient.newIdempotencyKey());
    return PackOpenResult.fromJson(cevap['pack'] as Map<String, dynamic>);
  }
}
