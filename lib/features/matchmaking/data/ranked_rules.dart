import '../../../core/network/api_client.dart';

/// EKONOMİ V2 (037, R2): dereceli maçta kalıcı kart kaybı açık mı?
///
/// Sunucu kuralı: yeni maçlar kural sürümü 3 ile kurulur (kart transferi
/// YOK) ancak `economy_v2_enabled` ve `ranked_rewards_v2` ikisi de açıksa.
/// Asıl karar sunucuda maç kurulurken verilir; bu yalnız maç hazırlığı
/// ekranında koruma bölümünü göstermek / gizlemek için. Okunamazsa
/// güvenli taraf: kayıp AÇIK sayılır (koruma bölümü görünür).
Future<bool> fetchRankedCardLossEnabled(ApiClient api) async {
  try {
    final c = await api.get('/economy/config');
    final f = c['flags'] is Map ? c['flags'] as Map : const {};
    return !(f['economy_v2_enabled'] == true && f['ranked_rewards_v2'] == true);
  } catch (_) {
    return true;
  }
}

/// 041: antrenman modu (bota karşı, ödülsüz) açık mı? Okunamazsa kapalı:
/// düğme görünmez, dereceli akış değişmez.
Future<bool> fetchTrainingEnabled(ApiClient api) async {
  try {
    final c = await api.get('/economy/config');
    final f = c['flags'] is Map ? c['flags'] as Map : const {};
    return f['training_mode'] == true;
  } catch (_) {
    return false;
  }
}
