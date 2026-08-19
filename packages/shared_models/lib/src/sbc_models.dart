import 'package:freezed_annotation/freezed_annotation.dart';

import 'card_model.dart';
import 'chemistry.dart';
import 'enums.dart';
import 'game_rules.dart';

part 'sbc_models.freezed.dart';
part 'sbc_models.g.dart';

/// Bir görevin şart tipi.
///
/// Sunucudaki `evaluate_sbc_squad()` bu tiplerin aynısını değerlendirir.
/// Buradaki hesap SADECE anlık önizleme içindir; gönderim sırasında
/// sunucu her şeyi baştan doğrular.
@JsonEnum()
enum SbcRequirementType {
  /// Tüm kartlar tam olarak bu seviyede
  @JsonValue('exact_tier')
  exactTier,

  /// Tüm kartlar en az bu seviyede
  @JsonValue('min_tier')
  minTier,

  /// Hiçbir kart bu seviyeyi geçemez
  @JsonValue('max_tier')
  maxTier,

  @JsonValue('min_chemistry')
  minChemistry,

  @JsonValue('min_avg_power')
  minAvgPower,

  @JsonValue('min_distinct_nations')
  minDistinctNations,

  @JsonValue('min_distinct_leagues')
  minDistinctLeagues,

  @JsonValue('min_distinct_clubs')
  minDistinctClubs,

  @JsonValue('min_cards_of_tier')
  minCardsOfTier,

  @JsonValue('min_cards_of_league')
  minCardsOfLeague,

  @JsonValue('min_cards_of_nation')
  minCardsOfNation,

  /// İleride sunucuya yeni şart tipi eklenirse eski uygulama çökmesin
  @JsonValue('unknown')
  unknown;
}

/// Görevin ham şartı (sunucudan geldiği hali)
@freezed
abstract class SbcRequirement with _$SbcRequirement {
  const SbcRequirement._();

  const factory SbcRequirement({
    @JsonKey(unknownEnumValue: SbcRequirementType.unknown)
    required SbcRequirementType type,

    /// Sayısal hedef (kimya, güç, adet...)
    @JsonKey(name: 'value') num? targetValue,

    /// Seviye şartları için
    CardTier? tier,

    /// Lig/uyruk şartları için
    String? league,
    String? nation,
  }) = _SbcRequirement;

  factory SbcRequirement.fromJson(Map<String, dynamic> json) =>
      _$SbcRequirementFromJson(json);

  /// Ekranda gösterilecek Türkçe açıklama
  String get label => switch (type) {
        SbcRequirementType.exactTier =>
          'Tüm kartlar ${tier?.label ?? ''} seviyesinde olmalı',
        SbcRequirementType.minTier =>
          'Tüm kartlar en az ${tier?.label ?? ''} seviyesinde olmalı',
        SbcRequirementType.maxTier =>
          'Hiçbir kart ${tier?.label ?? ''} seviyesini geçmemeli',
        SbcRequirementType.minChemistry =>
          'En az ${_int(targetValue)} takım kimyası',
        SbcRequirementType.minAvgPower =>
          'En az ${_int(targetValue)} ortalama güç',
        SbcRequirementType.minDistinctNations =>
          'En az ${_int(targetValue)} farklı uyruk',
        SbcRequirementType.minDistinctLeagues =>
          'En az ${_int(targetValue)} farklı lig',
        SbcRequirementType.minDistinctClubs =>
          'En az ${_int(targetValue)} farklı kulüp',
        SbcRequirementType.minCardsOfTier =>
          'En az ${_int(targetValue)} adet ${tier?.label ?? ''} kart',
        SbcRequirementType.minCardsOfLeague =>
          '$league liginden en az ${_int(targetValue)} kart',
        SbcRequirementType.minCardsOfNation =>
          '$nation uyruklu en az ${_int(targetValue)} kart',
        SbcRequirementType.unknown => 'Bilinmeyen şart',
      };

  static int _int(num? v) => (v ?? 0).round();
}

/// Bir şartın değerlendirilmiş hali (yeşil tik / kırmızı çarpı)
@freezed
abstract class SbcRequirementResult with _$SbcRequirementResult {
  const SbcRequirementResult._();

  const factory SbcRequirementResult({
    required String label,
    required num target,
    required num current,
    @JsonKey(name: 'is_met') required bool isMet,
    String? type,
  }) = _SbcRequirementResult;

  factory SbcRequirementResult.fromJson(Map<String, dynamic> json) =>
      _$SbcRequirementResultFromJson(json);

  /// "8/11" gibi ilerleme metni
  String get progressText =>
      '${_kisalt(current)}/${_kisalt(target)}';

  /// İlerleme oranı (çubuk için)
  double get ratio =>
      target == 0 ? 1 : (current / target).clamp(0.0, 1.0).toDouble();

  static String _kisalt(num v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// Görev ödülü
@freezed
abstract class SbcReward with _$SbcReward {
  const SbcReward._();

  const factory SbcReward({
    /// coins | pack | card
    required String type,
    int? amount,
    String? packSlug,
    String? cardSlug,

    /// Ödül verildikten sonra dolu gelir
    @Default([]) List<InventoryCard> cards,
  }) = _SbcReward;

  factory SbcReward.fromJson(Map<String, dynamic> json) =>
      _$SbcRewardFromJson(json);

  String get label => switch (type) {
        'coins' => '${amount ?? 0} coin',
        'pack' => 'Paket',
        'card' => 'Özel kart',
        _ => 'Ödül',
      };
}

/// Kadro kurma görevi
@freezed
abstract class SbcChallenge with _$SbcChallenge {
  const SbcChallenge._();

  const factory SbcChallenge({
    required String id,
    required String slug,
    required String name,
    String? description,
    @Default('genel') String category,
    @Default([]) List<SbcRequirement> requirements,
    @Default([]) List<SbcReward> rewards,

    /// null = sınırsız tekrar
    int? maxCompletions,
    DateTime? expiresAt,
    @Default(0) int completedCount,
    @Default(false) bool isCompleted,
  }) = _SbcChallenge;

  factory SbcChallenge.fromJson(Map<String, dynamic> json) =>
      _$SbcChallengeFromJson(json);

  /// Tekrar tekrar yapılabilir mi?
  bool get isRepeatable => maxCompletions == null;

  /// Kalan hak (sınırsızsa null)
  int? get remainingAttempts =>
      maxCompletions == null ? null : maxCompletions! - completedCount;

  /// Kategori etiketi
  String get categoryLabel => switch (category) {
        'baslangic' => 'Başlangıç',
        'gunluk' => 'Günlük',
        'ozel' => 'Özel',
        _ => 'Genel',
      };

  /// Ödüllerin özet metni: "Paket + 500 coin"
  String get rewardSummary =>
      rewards.isEmpty ? '-' : rewards.map((o) => o.label).join(' + ');
}

/// Bir kadronun görev şartlarına göre değerlendirilmesi
@freezed
abstract class SbcEvaluation with _$SbcEvaluation {
  const SbcEvaluation._();

  const factory SbcEvaluation({
    @JsonKey(name: 'is_valid') @Default(false) bool isValid,

    /// Şartlara bakmadan önce takılan engel (eksik kart, başkasının kartı...)
    String? blockingError,

    @Default(0) int chemistry,
    @Default(0) num avgPower,
    @Default([]) List<SbcRequirementResult> requirements,
  }) = _SbcEvaluation;

  factory SbcEvaluation.fromJson(Map<String, dynamic> json) =>
      _$SbcEvaluationFromJson(json);

  static const SbcEvaluation empty = SbcEvaluation();

  int get metCount => requirements.where((s) => s.isMet).length;
  int get totalCount => requirements.length;

  /// Kaç şart karşılandı? "2/3"
  String get progressText => '$metCount/$totalCount';

  bool get canSubmit => isValid && blockingError == null;

  // ------------------------------------------------------------------
  // YEREL DEĞERLENDİRME (anlık önizleme)
  // ------------------------------------------------------------------
  /// Kadroyu şartlara göre YEREL olarak değerlendirir.
  ///
  /// Oyuncu kart yerleştirdikçe yeşil tik / kırmızı çarpı anında
  /// güncellenmeli; her dokunuşta sunucuya gitmek hem yavaş olur hem
  /// gereksiz yük yaratır.
  ///
  /// GÜVENLİK: Bu hesap SADECE arayüz içindir. Gönderim sırasında
  /// sunucu `evaluate_sbc_squad()` ile her şeyi baştan doğrular.
  /// Buradaki kodu değiştiren biri görevi haksız yere tamamlayamaz.
  static SbcEvaluation calculate({
    required List<SbcRequirement> requirements,
    required Map<int, InventoryCard?> slots,
  }) {
    final kartlar = <InventoryCard>[];
    for (var s = 0; s < GameRules.squadSize; s++) {
      final k = slots[s];
      if (k != null) kartlar.add(k);
    }

    // Kadro tamamlanmadan şartları değerlendirmek yanıltıcı olur
    if (kartlar.length < GameRules.squadSize) {
      return SbcEvaluation(
        isValid: false,
        blockingError:
            '${GameRules.squadSize - kartlar.length} kart daha yerleştir',
        chemistry: DeckChemistry.calculate(slots).total,
        requirements: requirements
            .map((s) => _degerlendir(s, kartlar, slots))
            .toList(),
      );
    }

    final kimya = DeckChemistry.calculate(slots).total;
    final sonuclar =
        requirements.map((s) => _degerlendir(s, kartlar, slots)).toList();

    return SbcEvaluation(
      isValid: sonuclar.every((s) => s.isMet),
      chemistry: kimya,
      avgPower: kartlar.isEmpty
          ? 0
          : kartlar.fold<int>(0, (t, k) => t + k.power) / kartlar.length,
      requirements: sonuclar,
    );
  }

  static SbcRequirementResult _degerlendir(
    SbcRequirement sart,
    List<InventoryCard> kartlar,
    Map<int, InventoryCard?> slots,
  ) {
    final hedefSayi = (sart.targetValue ?? 0);
    num mevcut;
    num hedef = hedefSayi;

    switch (sart.type) {
      case SbcRequirementType.minChemistry:
        mevcut = DeckChemistry.calculate(slots).total;

      case SbcRequirementType.minAvgPower:
        mevcut = kartlar.isEmpty
            ? 0
            : kartlar.fold<int>(0, (t, k) => t + k.power) / kartlar.length;

      case SbcRequirementType.exactTier:
        mevcut = kartlar.where((k) => k.tier == sart.tier).length;
        hedef = GameRules.squadSize;

      case SbcRequirementType.minTier:
        final esik = sart.tier?.rank ?? 0;
        mevcut = kartlar.where((k) => k.tier.rank >= esik).length;
        hedef = GameRules.squadSize;

      case SbcRequirementType.maxTier:
        final tavan = sart.tier?.rank ?? 99;
        mevcut = kartlar.where((k) => k.tier.rank <= tavan).length;
        hedef = GameRules.squadSize;

      case SbcRequirementType.minCardsOfTier:
        mevcut = kartlar.where((k) => k.tier == sart.tier).length;

      case SbcRequirementType.minDistinctNations:
        mevcut = kartlar
            .map((k) => k.nationality)
            .whereType<String>()
            .toSet()
            .length;

      case SbcRequirementType.minDistinctLeagues:
        mevcut =
            kartlar.map((k) => k.league).whereType<String>().toSet().length;

      case SbcRequirementType.minDistinctClubs:
        mevcut = kartlar.map((k) => k.club).whereType<String>().toSet().length;

      case SbcRequirementType.minCardsOfLeague:
        mevcut = kartlar.where((k) => k.league == sart.league).length;

      case SbcRequirementType.minCardsOfNation:
        mevcut = kartlar.where((k) => k.nationality == sart.nation).length;

      case SbcRequirementType.unknown:
        // Bilinmeyen şartı "karşılandı" saymak tehlikeli olurdu:
        // oyuncu ekranda yeşil görüp gönderir, sunucu reddeder.
        mevcut = 0;
        hedef = 1;
    }

    return SbcRequirementResult(
      label: sart.label,
      target: hedef,
      current: mevcut is double ? num.parse(mevcut.toStringAsFixed(1)) : mevcut,
      isMet: mevcut >= hedef,
      type: sart.type.name,
    );
  }
}

/// Görev gönderiminin sonucu
@freezed
abstract class SbcSubmitResult with _$SbcSubmitResult {
  const SbcSubmitResult._();

  const factory SbcSubmitResult({
    required String challengeSlug,
    required String challengeName,
    @Default(0) int burnedCount,
    @Default([]) List<SbcReward> rewards,
    @Default(0) int coins,
  }) = _SbcSubmitResult;

  factory SbcSubmitResult.fromJson(Map<String, dynamic> json) =>
      _$SbcSubmitResultFromJson(json);

  /// Ödül olarak gelen tüm kartlar
  List<InventoryCard> get rewardCards =>
      [for (final o in rewards) ...o.cards];

  int get rewardCoins =>
      rewards.where((o) => o.type == 'coins').fold(0, (t, o) => t + (o.amount ?? 0));
}
