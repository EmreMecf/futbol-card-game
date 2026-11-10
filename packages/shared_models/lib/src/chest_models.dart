import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'chest_models.freezed.dart';
part 'chest_models.g.dart';

/// EKONOMİ V2 (FAZ 1) — SANDIK modelleri.
///
/// Sandığın içeriği, süresi ve olasılıkları YALNIZ sunucuda belirlenir
/// (docs/EKONOMI_V2_TASARIM.md §1). İstemci gösterir; süreleri sunucu
/// saatine (`serverTime`) göre sayar.
///
/// Sandık türü kartların nadirliğinden AYRI bir kavramdır: 'bronze',
/// 'silver', 'gold', 'legend' sandık türleridir (Bronz, Gümüş, Altın,
/// Efsane sandık).
abstract final class ChestTypes {
  static const bronze = 'bronze';
  static const silver = 'silver';
  static const gold = 'gold';
  static const legend = 'legend';
  static const all = [bronze, silver, gold, legend];

  /// Türkçe ad (sunucu kuralları gelmeden önce de gösterilebilsin)
  static String name(String type) => switch (type) {
        bronze => 'Bronz',
        silver => 'Gümüş',
        gold => 'Altın',
        legend => 'Efsane',
        _ => type,
      };
}

/// Sandık durumu (sunucu, süresi dolan 'unlocking' sandığı 'ready' döner)
abstract final class ChestStatus {
  static const sealed = 'sealed';
  static const unlocking = 'unlocking';
  static const ready = 'ready';
  static const opened = 'opened';
  static const compensated = 'compensated';
}

/// Sandıktan çıkan kartın sonucu
abstract final class ChestCardOutcome {
  /// Koleksiyonda yoktu: yeni kart
  static const isNew = 'new';

  /// Vardı: gelişim kopyası (+1)
  static const copy = 'copy';

  /// Kadro kilidi koruması: eksik mevkiden fiziksel kart
  static const squadGuard = 'squad_guard';

  /// Seviye 10'daki futbolcunun kopyası -> joker parça (FAZ 2)
  static const joker = 'joker';
}

@freezed
abstract class Chest with _$Chest {
  const Chest._();

  const factory Chest({
    required String id,
    required String chestType,
    @Default(1) int rulesVersion,
    required String status,

    /// instant (Bronz) | slot | mailbox
    required String location,
    int? slotNo,
    required String sourceType,
    required String sourceId,
    @Default(0) int unlockSeconds,
    DateTime? unlockStartedAt,
    DateTime? unlockReadyAt,
    DateTime? openedAt,

    /// Açılmışsa ChestOpenResult biçimi; telafi edildiyse
    /// {compensation_coins, reason}
    Map<String, dynamic>? result,
    required DateTime createdAt,
  }) = _Chest;

  factory Chest.fromJson(Map<String, dynamic> json) => _$ChestFromJson(json);

  String get typeName => ChestTypes.name(chestType);
  bool get isReady => status == ChestStatus.ready;
  bool get isUnlocking => status == ChestStatus.unlocking;
  bool get isSealed => status == ChestStatus.sealed;
  bool get isInMailbox => location == 'mailbox';

  /// Sunucu saatine göre kalan süre (null: sayaç yok)
  Duration? remaining(DateTime serverNow) {
    if (!isUnlocking || unlockReadyAt == null) return null;
    final kalan = unlockReadyAt!.difference(serverNow);
    return kalan.isNegative ? Duration.zero : kalan;
  }

  ChestOpenResult? get openResult =>
      result != null && result!['cards'] is List ? ChestOpenResult.fromJson(result!) : null;
}

/// Sandıktan çıkan kart
@freezed
abstract class ChestCard with _$ChestCard {
  const ChestCard._();

  const factory ChestCard({
    required String cardId,
    required String slug,
    required String fullName,
    required CardPosition position,
    required CardTier tier,
    required int power,
    String? club,
    String? nationality,
    String? imageUrl,

    /// new | copy | squad_guard | joker (bkz. [ChestCardOutcome])
    required String outcome,
  }) = _ChestCard;

  factory ChestCard.fromJson(Map<String, dynamic> json) => _$ChestCardFromJson(json);

  bool get isNew => outcome == ChestCardOutcome.isNew;
  bool get isCopy => outcome == ChestCardOutcome.copy;
  bool get isSquadGuard => outcome == ChestCardOutcome.squadGuard;
}

/// `POST /api/chests/{id}/open` cevabı (tekrar açmada AYNI)
@freezed
abstract class ChestOpenResult with _$ChestOpenResult {
  const factory ChestOpenResult({
    required String chestId,
    required String chestType,
    @Default(1) int rulesVersion,
    @Default([]) List<ChestCard> cards,
    @Default(0) int coins,

    /// Nadirlik -> joker parça adedi
    @Default({}) Map<String, int> jokers,
    int? coinsAfter,
    int? ledgerId,
  }) = _ChestOpenResult;

  factory ChestOpenResult.fromJson(Map<String, dynamic> json) => _$ChestOpenResultFromJson(json);
}

/// Ödül enerjisi (maç içi TAKTİK enerjisinden AYRI)
@freezed
abstract class RewardEnergy with _$RewardEnergy {
  const RewardEnergy._();

  const factory RewardEnergy({
    required int energy,
    required int max,
    @Default(96) int refillMinutes,
    DateTime? nextAt,
    required DateTime serverTime,
  }) = _RewardEnergy;

  factory RewardEnergy.fromJson(Map<String, dynamic> json) => _$RewardEnergyFromJson(json);

  bool get isFull => energy >= max;
  bool get isEmpty => energy <= 0;
}

/// `GET /api/chests`
@freezed
abstract class ChestInventory with _$ChestInventory {
  const ChestInventory._();

  const factory ChestInventory({
    @Default([]) List<Chest> slots,
    @Default([]) List<Chest> instant,
    @Default([]) List<Chest> mailbox,
    @Default(4) int slotCount,
    @Default(8) int mailboxCapacity,
    @Default(7) int mailboxDays,
    @Default(1) int rulesVersion,

    /// Ekonomi V2 açık mı? Kapalıysa ekranlar gizlenir.
    @Default(false) bool enabled,
    required RewardEnergy energy,
    required DateTime serverTime,
  }) = _ChestInventory;

  factory ChestInventory.fromJson(Map<String, dynamic> json) => _$ChestInventoryFromJson(json);

  /// Yuva numarasına göre sandık (boşsa null)
  Chest? slot(int no) => slots.where((c) => c.slotNo == no).firstOrNull;

  /// Sayacı çalışan (ya da süresi dolmuş, açılmayı bekleyen) sandık
  Chest? get unlocking => slots.where((c) => c.isUnlocking || (c.isReady && c.unlockStartedAt != null)).firstOrNull;

  bool get hasFreeSlot => slots.length < slotCount;
  int get readyCount => instant.length + slots.where((c) => c.isReady).length;
}

/// Sandık türü kuralı (olasılık sayfası)
@freezed
abstract class ChestTypeRule with _$ChestTypeRule {
  const factory ChestTypeRule({
    required String name,
    @Default(0) int unlockSeconds,
    @Default([0, 0]) List<int> coins,
    @Default({}) Map<String, int> jokers,
    @Default(0) int compensation,
    @Default(0) int sort,
  }) = _ChestTypeRule;

  factory ChestTypeRule.fromJson(Map<String, dynamic> json) => _$ChestTypeRuleFromJson(json);
}

/// `GET /api/chests/odds` — sürümlü olasılıklar (ağırlıklar binde)
@freezed
abstract class ChestOdds with _$ChestOdds {
  const ChestOdds._();

  const factory ChestOdds({
    required int version,
    DateTime? activeFrom,
    @Default({}) Map<String, ChestTypeRule> types,

    /// win | draw | loss -> sandık türü -> ağırlık
    @Default({}) Map<String, Map<String, int>> typeOdds,

    /// sandık türü -> 3 yuva -> kart nadirliği -> ağırlık
    @Default({}) Map<String, List<Map<String, int>>> slotOdds,
    @Default({}) Map<String, int> pity,
    @Default(1000) int weightTotal,
  }) = _ChestOdds;

  factory ChestOdds.fromJson(Map<String, dynamic> json) => _$ChestOddsFromJson(json);

  /// Ağırlığı yüzde metnine çevirir (ör. 4 -> "%0,4")
  String percent(int weight) {
    final y = weight * 100 / weightTotal;
    final metin = y == y.roundToDouble() ? y.toStringAsFixed(0) : y.toStringAsFixed(1);
    return '%${metin.replaceAll('.', ',')}';
  }
}

/// Bir maçın sandığı (maç sonu ekranı): sandık ya da enerjisiz atlama
@freezed
abstract class SourceChest with _$SourceChest {
  const SourceChest._();

  const factory SourceChest({
    Chest? chest,

    /// 'no_energy': ödül enerjisi yoktu, sandık çıkmadı
    String? skipped,
  }) = _SourceChest;

  factory SourceChest.fromJson(Map<String, dynamic> json) => _$SourceChestFromJson(json);

  bool get skippedNoEnergy => skipped == 'no_energy';
}

/// Acil kadro durumu (032): kadrosu formasyonu karşılamayan oyuncu
/// eksik sayıda Bronz kart alabilir, 24 saatte bir.
@freezed
abstract class EmergencySquadStatus with _$EmergencySquadStatus {
  const EmergencySquadStatus._();

  const factory EmergencySquadStatus({
    @Default(false) bool enabled,

    /// Mevki kodu (GK/DEF/MID/FWD) -> eksik kart sayısı
    @Default({}) Map<String, int> missing,

    /// Alınırsa verilecek kartlar: her mevki "ihtiyaç + 1 yedek"e
    /// tamamlanır (hemen tekrar kilitlenmesin diye)
    @Default({}) Map<String, int> grant,
    @Default(false) bool eligible,
    DateTime? nextAt,
    required DateTime serverTime,
  }) = _EmergencySquadStatus;

  factory EmergencySquadStatus.fromJson(Map<String, dynamic> json) => _$EmergencySquadStatusFromJson(json);

  bool get isSquadBroken => missing.isNotEmpty;
  int get missingCount => missing.values.fold(0, (a, b) => a + b);
  int get grantCount => grant.values.fold(0, (a, b) => a + b);
}

/// `POST /api/economy/emergency-squad/claim` cevabı
@freezed
abstract class EmergencySquadClaim with _$EmergencySquadClaim {
  const factory EmergencySquadClaim({
    @Default([]) List<ChestCard> cards,
    required EmergencySquadStatus status,
  }) = _EmergencySquadClaim;

  factory EmergencySquadClaim.fromJson(Map<String, dynamic> json) => _$EmergencySquadClaimFromJson(json);
}
