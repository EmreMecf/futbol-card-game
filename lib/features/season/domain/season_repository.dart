import 'package:shared_models/shared_models.dart';

import '../../../core/utils/result.dart';
import '../../../core/l10n/app_language.dart';

/// Battle Pass ve görevler (Ekonomi V2, FAZ 4). Sezon XP'si ve ödüller
/// maçta güç vermez (K1); premium satın alma yok (K4).
abstract class SeasonRepository {
  Future<Result<SeasonOverview>> fetchOverview();
  Future<Result<MissionsOverview>> fetchMissions();
  Future<Result<MatchSeasonXp>> fetchMatchXp(String matchId);

  /// [track]: free | premium
  Future<Result<Map<String, dynamic>>> claim(int tier, String track, {required String idempotencyKey});
  Future<Result<Map<String, dynamic>>> claimAll({required String idempotencyKey});
}

/// Sunucu hata kodu -> Türkçe mesaj
String seasonErrorMessage(String? code, String fallback) => switch (code) {
      'economy_disabled' => 'Sezon yolu henüz açık değil.'.tr,
      'tier_not_found' => 'Kademe bulunamadı.'.tr,
      'tier_locked' => 'Bu kademeye henüz ulaşmadın.'.tr,
      'premium_required' => 'Premium yol kilitli.'.tr,
      'idempotency_in_progress' => 'İstek hâlâ işleniyor, birazdan tekrar dene.'.tr,
      _ => fallback,
    };
