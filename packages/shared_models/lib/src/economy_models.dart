import 'package:freezed_annotation/freezed_annotation.dart';

part 'economy_models.freezed.dart';
part 'economy_models.g.dart';

/// EKONOMİ V2 (FAZ 0) — sunucunun aktif ekonomi ayarları.
///
/// `GET /api/economy/config`. İstemci yalnız GÖSTERİR; oranlar, süreler
/// ve ödüller her zaman sunucuda hesaplanır (docs/EKONOMI_V2_TASARIM.md).
@freezed
abstract class EconomyConfig with _$EconomyConfig {
  const EconomyConfig._();

  const factory EconomyConfig({
    /// Özellik anahtarları (ör. economy_v2_enabled). Tanımsız = kapalı.
    @Default({}) Map<String, bool> flags,

    /// Ayar türü -> aktif sürüm (ör. chest_odds: 1)
    @Default({}) Map<String, int> versions,

    /// Sunucu saati: istemci sayaçlarını buna göre düzeltir
    required DateTime serverTime,
  }) = _EconomyConfig;

  factory EconomyConfig.fromJson(Map<String, dynamic> json) => _$EconomyConfigFromJson(json);

  /// Ekonomi V2 açık mı? (sandık, ödül enerjisi...)
  bool get isV2Enabled => flags['economy_v2_enabled'] ?? false;

  bool flag(String name) => flags[name] ?? false;
}

/// Ekonomi defterindeki bir kayıt (oyuncunun kendi geçmişi).
@freezed
abstract class LedgerEntry with _$LedgerEntry {
  const factory LedgerEntry({
    required int id,
    required String entryType,
    @Default(0) int coinsDelta,
    int? coinsAfter,
    @Default({}) Map<String, dynamic> items,
    required String sourceType,
    required String sourceId,
    required DateTime createdAt,
  }) = _LedgerEntry;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => _$LedgerEntryFromJson(json);
}

/// 044: GÜNLÜK DÖNGÜ — günlük ücretsiz sandık (seri) + günün ilk galibiyeti.
@freezed
abstract class DailyStatus with _$DailyStatus {
  const DailyStatus._();

  const factory DailyStatus({
    @Default(false) bool enabled,
    @Default(false) bool shopEnabled,
    DateTime? nextResetAt,
    @Default(false) bool claimedToday,

    /// Art arda kaç gün alındı (bugün alınmadıysa dünkü seri)
    @Default(0) int streak,

    /// Bugün alınacak / alınan sandık ('bronze' | 'silver')
    @Default('bronze') String chestType,
    @Default(false) bool firstWinToday,
    @Default(2) int firstWinMultiplier,
  }) = _DailyStatus;

  factory DailyStatus.fromJson(Map<String, dynamic> json) => _$DailyStatusFromJson(json);
}

/// 044: GÜNÜN TEKLİFİ — herkes için aynı paket, indirimli, günde 1.
@freezed
abstract class DailyShopStatus with _$DailyShopStatus {
  const DailyShopStatus._();

  const factory DailyShopStatus({
    @Default(false) bool enabled,
    @Default('') String packSlug,
    @Default('') String name,
    @Default(0) int cardCount,
    @Default(0) int price,
    @Default(0) int discountPct,
    @Default(0) int discountedPrice,
    @Default(false) bool boughtToday,
    DateTime? nextResetAt,
  }) = _DailyShopStatus;

  factory DailyShopStatus.fromJson(Map<String, dynamic> json) => _$DailyShopStatusFromJson(json);
}
