import 'package:flutter/foundation.dart';

import '../../core/l10n/app_language.dart';

/// 060 — Monetizasyon alan modelleri (sunucu sözleşmesiyle birebir).
///
/// Ödülü İSTEMCİ VERMEZ: reklam bitince durum yalnız "doğrulanıyor" olur;
/// ödül sunucudaki imzalı AdMob geri çağrısıyla verilir.

/// Uygulama sürümü (pubspec `version` ile aynı tutulur; sunucu eski sürüme
/// reklam açmaz). Derlemede `--dart-define=APP_VERSION=` ile ezilebilir.
const String kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');

/// Sunucuya bildirilen platform: android | ios | web | other
String get clientPlatform {
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    _ => 'other',
  };
}

/// Ödüllü reklam yerleri
enum AdPlacement {
  dailyReward('daily_reward'),
  chestSpeedup('chest_speedup'),
  postMatch('post_match');

  final String code;
  const AdPlacement(this.code);
}

int _i(Object? v, [int d = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? d;

/// Ödül: {"type": "coins", "amount": 40} | {"type": "chest_minutes", "amount": 10}
class AdReward {
  final String type;
  final int amount;
  const AdReward({required this.type, required this.amount});

  factory AdReward.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return AdReward(type: m['type']?.toString() ?? '', amount: _i(m['amount']));
  }

  bool get isCoins => type == 'coins';
  bool get isChestMinutes => type == 'chest_minutes';

  /// "40 altın", "Sandık süresi −10 dk"
  String get label => isCoins
      ? '{n} altın'.trArgs({'n': amount})
      : (isChestMinutes ? 'Sandık süresi −{n} dk'.trArgs({'n': amount}) : '$amount');
}

/// Bir yerleşimin şu anki uygunluğu (sunucu hesaplar)
class AdEligibility {
  final String placement;
  final bool eligible;
  final String? reason;
  final AdReward reward;
  final int remainingToday;
  final int placementLimit;
  final int usedToday;
  final int globalLimit;

  const AdEligibility({
    required this.placement,
    required this.eligible,
    this.reason,
    this.reward = const AdReward(type: '', amount: 0),
    this.remainingToday = 0,
    this.placementLimit = 0,
    this.usedToday = 0,
    this.globalLimit = 0,
  });

  factory AdEligibility.fromJson(Map<String, dynamic> j) => AdEligibility(
    placement: j['placement']?.toString() ?? '',
    eligible: j['eligible'] == true,
    reason: j['reason']?.toString(),
    reward: AdReward.fromJson(j['reward']),
    remainingToday: _i(j['remaining_today']),
    placementLimit: _i(j['placement_limit']),
    usedToday: _i(j['used_today']),
    globalLimit: _i(j['global_limit']),
  );

  /// Özellik bu oyuncuya hiç açık değil (düğme hiç gösterilmez)
  bool get featureOff => const {
    'config_unavailable',
    'monetization_disabled',
    'feature_disabled',
    'platform_not_supported',
    'app_version_too_old',
    'not_in_rollout',
    'unknown_placement',
    'account_not_eligible',
  }.contains(reason);

  /// Oyuncuya kısa açıklama (düğme pasifken)
  String get reasonText => switch (reason) {
    null => '',
    'in_match' => 'Maç sürerken reklam yok.'.tr,
    'first_session' => 'İlk gün reklam gösterilmez.'.tr,
    'daily_limit' => 'Bugünkü reklam hakkın doldu.'.tr,
    'placement_limit' => 'Bugünkü hakkını kullandın.'.tr,
    'chest_not_eligible' => 'Bu sandık hızlandırılamaz.'.tr,
    'match_not_eligible' => 'Bu maç için teklif yok.'.tr,
    _ => 'Şu an kullanılamıyor.'.tr,
  };
}

/// Ekran özeti (her yerleşim + kullanılmamış sandık kredileri)
class AdStatus {
  final Map<String, AdEligibility> placements;
  final List<String> creditSessionIds;
  final DateTime? resetsAt;
  const AdStatus({this.placements = const {}, this.creditSessionIds = const [], this.resetsAt});

  AdEligibility? of(AdPlacement p) => placements[p.code];

  factory AdStatus.fromJson(Map<String, dynamic> j) {
    final p = j['placements'] is Map ? Map<String, dynamic>.from(j['placements'] as Map) : const <String, dynamic>{};
    return AdStatus(
      placements: {
        for (final e in p.entries)
          if (e.value is Map) e.key: AdEligibility.fromJson(Map<String, dynamic>.from(e.value as Map)),
      },
      creditSessionIds: [
        for (final c in j['credits'] as List? ?? const [])
          if (c is Map) c['session_id'].toString(),
      ],
      resetsAt: DateTime.tryParse('${j['resets_at']}')?.toLocal(),
    );
  }
}

/// Sunucunun açtığı reklam oturumu (süreli hak rezervasyonu)
class AdSession {
  final String sessionId;
  final String ssvUserId;
  final String customData;
  final AdReward reward;
  const AdSession({required this.sessionId, required this.ssvUserId, required this.customData, required this.reward});

  factory AdSession.fromJson(Map<String, dynamic> j) => AdSession(
    sessionId: j['session_id'].toString(),
    ssvUserId: j['ssv_user_id'].toString(),
    customData: j['custom_data'].toString(),
    reward: AdReward.fromJson(j['reward']),
  );
}

/// Oturum durumu: reserved | verifying | granted | credit | rejected | cancelled
class AdSessionState {
  final String status;
  final String? rejectReason;
  final int? coinsAfter;
  const AdSessionState({required this.status, this.rejectReason, this.coinsAfter});

  factory AdSessionState.fromJson(Map<String, dynamic> j) => AdSessionState(
    status: j['status']?.toString() ?? 'reserved',
    rejectReason: j['reject_reason']?.toString(),
    coinsAfter: j['coins_after'] is num ? (j['coins_after'] as num).toInt() : null,
  );

  bool get isFinal => const {'granted', 'credit', 'rejected', 'cancelled'}.contains(status);
}

/// Reklam yaşam döngüsü (durum makinesi)
enum AdLifecycleState {
  idle,
  eligibilityChecking,
  loading,
  ready,
  showing,
  awaitingVerification,
  rewardGranted,
  cancelled,
  failed,
  disposed,
}
