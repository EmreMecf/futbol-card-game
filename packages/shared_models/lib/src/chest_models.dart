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

    /// 038: ek item ödülleri (item slug -> adet), ör. {"chest_key": 1}
    @Default({}) Map<String, int> extras,
    int? coinsAfter,
    int? ledgerId,

    /// 056: sandıktan çıkan elmas ve sonraki bakiye
    @Default(0) int gems,
    int? gemsAfter,

    /// 056: sandık elmasla hemen açıldıysa harcanan elmas
    @Default(0) int gemsSpent,
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

    /// 037 (R1): enerji yoktu, sandık yine verildi (Bronz)
    @Default(false) bool noEnergy,

    /// 037 (R3): galibiyet gelişim kopyası {card_id, full_name, tier, copies}
    Map<String, dynamic>? winCopy,
  }) = _SourceChest;

  factory SourceChest.fromJson(Map<String, dynamic> json) => _$SourceChestFromJson(json);

  bool get skippedNoEnergy => skipped == 'no_energy';

  /// Galibiyet kopyasının futbolcu adı (yoksa null)
  String? get winCopyName => winCopy?['full_name'] as String?;
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

// =====================================================================
// FAZ 2 (033): FUTBOLCU SEVİYESİ
// =====================================================================
/// Bir sonraki seviyenin maliyeti
@freezed
abstract class LevelCost with _$LevelCost {
  const factory LevelCost({required int copies, required int coins}) = _LevelCost;
  factory LevelCost.fromJson(Map<String, dynamic> json) => _$LevelCostFromJson(json);
}

/// Bir futbolcunun gelişimi (oyuncuya bağlı; K1: dereceli gücü etkilemez)
@freezed
abstract class PlayerProgressItem with _$PlayerProgressItem {
  const PlayerProgressItem._();

  const factory PlayerProgressItem({
    required String cardId,
    String? slug,
    required String fullName,
    required CardPosition position,
    required CardTier tier,
    required int power,
    String? club,
    String? nationality,
    String? imageUrl,
    @Default(1) int level,

    /// Biriken gelişim kopyası
    @Default(0) int copies,

    /// Koleksiyondaki fiziksel kopya (0: kart kaybedilmiş, seviye duruyor)
    @Default(0) int ownedCopies,

    /// Gönüllü dönüştürülebilecek fiziksel kopya
    @Default(0) int convertibleCopies,

    /// null: en yüksek seviye
    LevelCost? next,

    /// Bu nadirlikteki joker parça
    @Default(0) int jokersAvailable,

    /// Bu nadirlikteki ustalık kitabı (034)
    @Default(0) int booksAvailable,
  }) = _PlayerProgressItem;

  factory PlayerProgressItem.fromJson(Map<String, dynamic> json) => _$PlayerProgressItemFromJson(json);

  bool get isMax => next == null;
  bool get isOwned => ownedCopies > 0;
  int get missingCopies => next == null ? 0 : (next!.copies - copies).clamp(0, 1 << 30);

  /// Kopyayla (jokersiz) atlanabilir mi?
  bool canLevelUp(int coins) => isOwned && next != null && copies >= next!.copies && coins >= next!.coins;

  /// Joker parçayla tamamlanarak atlanabilir mi?
  bool canLevelWithJokers(int coins) =>
      isOwned && next != null && missingCopies > 0 && jokersAvailable >= missingCopies && coins >= next!.coins;

  /// Kopya ilerlemesi 0..1
  double get progress => next == null ? 1 : (copies / next!.copies).clamp(0, 1).toDouble();
}

/// `GET /api/progress`
@freezed
abstract class ProgressOverview with _$ProgressOverview {
  const ProgressOverview._();

  const factory ProgressOverview({
    @Default([]) List<PlayerProgressItem> items,
    @Default({}) Map<String, int> jokers,

    /// %25 gelişim indirimi adedi (034)
    @Default(0) int discounts,
    @Default(0) int coins,
    @Default(1) int rulesVersion,
    @Default(10) int maxLevel,
    @Default(2) int convertKeep,

    /// Seviye -> ödül (ör. "5": {"coins": 200})
    @Default({}) Map<String, Map<String, int>> mastery,
    @Default(false) bool affectsRankedPower,
    @Default(false) bool enabled,
  }) = _ProgressOverview;

  factory ProgressOverview.fromJson(Map<String, dynamic> json) => _$ProgressOverviewFromJson(json);

  PlayerProgressItem? item(String cardId) => items.where((i) => i.cardId == cardId).firstOrNull;

  /// Şu an (kopyayla) seviye atlanabilecek futbolcu sayısı
  int get readyCount => items.where((i) => i.canLevelUp(coins)).length;

  /// Listede "atlayabilir" sayılır mı? Jokerle atlama yalnız en az 1
  /// kopyası olan futbolcuda önerilir (aksi hâlde 1 joker, hiç kopyası
  /// olmayan onlarca futbolcuda ayrı ayrı "hazır" görünüyordu).
  bool isSuggested(PlayerProgressItem i) => i.canLevelUp(coins) || (i.copies > 0 && i.canLevelWithJokers(coins));
  int get suggestedCount => items.where(isSuggested).length;
}

/// `POST /api/progress/{cardId}/level-up`
@freezed
abstract class LevelUpResult with _$LevelUpResult {
  const factory LevelUpResult({
    required String cardId,
    required int level,
    @Default(0) int copies,
    @Default(0) int coinsSpent,
    @Default(0) int jokersUsed,
    @Default(0) int masteryCoins,

    /// Gelişim indirimiyle düşülen altın (034)
    @Default(0) int discount,
    LevelCost? next,
    int? coinsAfter,
  }) = _LevelUpResult;

  factory LevelUpResult.fromJson(Map<String, dynamic> json) => _$LevelUpResultFromJson(json);
}

/// `POST /api/progress/{cardId}/convert`
@freezed
abstract class ConvertCopiesResult with _$ConvertCopiesResult {
  const factory ConvertCopiesResult({
    required String cardId,
    required int converted,
    required int copies,
    required int ownedCopies,
    @Default(false) bool replay,
  }) = _ConvertCopiesResult;

  factory ConvertCopiesResult.fromJson(Map<String, dynamic> json) => _$ConvertCopiesResultFromJson(json);
}

// =====================================================================
// FAZ 3 (034): ITEM KATALOĞU VE ENVANTER
// =====================================================================
/// Item türü: stackable | consumable | timed | cosmetic
abstract final class ItemKinds {
  static const stackable = 'stackable';
  static const consumable = 'consumable';
  static const timed = 'timed';
  static const cosmetic = 'cosmetic';
}

@freezed
abstract class ItemDefinition with _$ItemDefinition {
  const ItemDefinition._();

  const factory ItemDefinition({
    required String slug,
    required String kind,
    required String category,
    required String name,
    required String description,
    int? maxStack,
    int? durationSeconds,
    String? cosmeticSlot,
    @Default(0) int overflowCoins,
    @Default({}) Map<String, dynamic> params,
    @Default(0) int sortOrder,
  }) = _ItemDefinition;

  factory ItemDefinition.fromJson(Map<String, dynamic> json) => _$ItemDefinitionFromJson(json);

  bool get isCosmetic => kind == ItemKinds.cosmetic;
  bool get isTimed => kind == ItemKinds.timed;

  /// Envanterden doğrudan kullanılabilir mi? (anahtar ve hızlandırıcı
  /// sandık ekranında, kitap gelişimde, indirim seviye atlarken kullanılır)
  bool get usableFromInventory => category == 'energy_drink';
}

/// Sahip olunan item (süreli itemlerde her bitiş ayrı satır)
@freezed
abstract class OwnedItem with _$OwnedItem {
  const factory OwnedItem({
    required String slug,
    required int quantity,
    DateTime? expiresAt,
  }) = _OwnedItem;

  factory OwnedItem.fromJson(Map<String, dynamic> json) => _$OwnedItemFromJson(json);
}

/// `GET /api/items`
@freezed
abstract class ItemInventory with _$ItemInventory {
  const ItemInventory._();

  const factory ItemInventory({
    @Default([]) List<ItemDefinition> catalog,
    @Default([]) List<OwnedItem> items,

    /// Kozmetik yuvası -> giyilen item
    @Default({}) Map<String, String> equipped,
    @Default(0) int energyDrinksToday,
    @Default(false) bool enabled,
    required DateTime serverTime,
  }) = _ItemInventory;

  factory ItemInventory.fromJson(Map<String, dynamic> json) => _$ItemInventoryFromJson(json);

  ItemDefinition? definition(String slug) => catalog.where((d) => d.slug == slug).firstOrNull;

  int quantity(String slug) => items.where((i) => i.slug == slug).fold(0, (a, b) => a + b.quantity);

  bool isEquipped(String slug) => equipped.values.contains(slug);
}
