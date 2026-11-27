import '../../core/network/api_client.dart';
import 'monetization_models.dart';

/// 060 — Monetizasyon sunucu uçları. Platform ve sürüm her istekte
/// gönderilir (sunucu eski sürüme / desteklenmeyen platforma reklam açmaz).
class MonetizationApi {
  final ApiClient api;
  MonetizationApi(this.api);

  Map<String, dynamic> get _istemci => {'platform': clientPlatform, 'app_version': kAppVersion};

  Future<Map<String, dynamic>> config() => api.get('/monetization/config', sorgu: _istemci);

  Future<AdStatus> status() async => AdStatus.fromJson(await api.get('/monetization/ads/status', sorgu: _istemci));

  Future<AdSession> createSession(AdPlacement p, {String? targetId}) async => AdSession.fromJson(
    await api.post('/monetization/ads/sessions', govde: {..._istemci, 'placement': p.code, 'target_id': ?targetId}),
  );

  Future<AdSessionState> sessionState(String id) async =>
      AdSessionState.fromJson(await api.get('/monetization/ads/sessions/$id'));

  /// shown | earned | closed | failed — ödül VERMEZ
  Future<AdSessionState> event(String id, String event) async =>
      AdSessionState.fromJson(await api.post('/monetization/ads/sessions/$id/event', govde: {'event': event}));

  Future<AdSessionState> applyCredit(String id, String chestId) async =>
      AdSessionState.fromJson(await api.post('/monetization/ads/sessions/$id/apply', govde: {'chest_id': chestId}));
}
