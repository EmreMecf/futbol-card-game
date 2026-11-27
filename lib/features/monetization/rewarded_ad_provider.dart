import 'rewarded_ad_provider_stub.dart' if (dart.library.io) 'rewarded_ad_provider_admob.dart' as impl;

/// Reklam sağlayıcı arayüzü. AdMob dışında bir ağ eklenecekse yalnız bu
/// arayüzün yeni bir uygulaması yazılır; denetleyici ve ekranlar değişmez.
abstract class RewardedAdProvider {
  /// Gizlilik rızası (AEA/UK'de UMP formu). false: reklam İSTENMEZ.
  Future<bool> ensureConsent();

  /// Reklamı yükler. [ssvUserId] ve [customData] AdMob SSV geri çağrısına
  /// aynen gider (sunucu oturumu bunlarla eşleştirir).
  Future<bool> load({required String ssvUserId, required String customData});

  /// Gösterir. Sonuç: oyuncu ödülü hak etti mi (yalnız İPUCU; ödülü
  /// sunucu doğrular)
  Future<AdShowResult> show();

  /// Gizlilik seçenekleri formu gerekiyorsa (ayarlardan açılır)
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();

  void dispose();

  /// Platforma uygun sağlayıcı: mobilde AdMob, web'de reklam yok
  static RewardedAdProvider create() => impl.createRewardedAdProvider();
}

enum AdShowResult { earned, closedWithoutReward, failed }

/// Reklam hiç gösterilmeyen sağlayıcı (web, testler, desteklenmeyen platform)
class NoAdProvider implements RewardedAdProvider {
  const NoAdProvider();
  @override
  Future<bool> ensureConsent() async => false;
  @override
  Future<bool> load({required String ssvUserId, required String customData}) async => false;
  @override
  Future<AdShowResult> show() async => AdShowResult.failed;
  @override
  Future<bool> privacyOptionsRequired() async => false;
  @override
  Future<void> showPrivacyOptions() async {}
  @override
  void dispose() {}
}
