import 'package:freezed_annotation/freezed_annotation.dart';

import 'card_attributes.dart';
import 'enums.dart';

part 'character_models.freezed.dart';
part 'character_models.g.dart';

// =====================================================================
// ÖZGÜN KARAKTER MODELLERİ (025_character_catalog.sql)
// =====================================================================
// Sunucu, uygulama ve içerik hattı (packages/content_pipeline) AYNI
// tanımları kullanır.
//
// GÜÇ BURADA YOK: [Character] kimliktir. Oyun değerleri Denge Motoru'nun
// [CharacterCardProposal]'ında; yapay zekâ onları yazamaz.

/// Oyun tarzı. Değerler veritabanındaki CHECK kısıtıyla birebir aynı.
@JsonEnum()
enum Playstyle {
  @JsonValue('hizli_kanat')
  fastWinger('hizli_kanat', 'Hızlı Kanat', CardPosition.forward),
  @JsonValue('bitirici_golcu')
  finisher('bitirici_golcu', 'Bitirici Golcü', CardPosition.forward),
  @JsonValue('hedef_santrafor')
  targetMan('hedef_santrafor', 'Hedef Santrafor', CardPosition.forward),
  @JsonValue('yaratici_forvet')
  creativeForward('yaratici_forvet', 'Yaratıcı Forvet', CardPosition.forward),
  @JsonValue('oyun_kurucu')
  playmaker('oyun_kurucu', 'Oyun Kurucu', CardPosition.midfielder),
  @JsonValue('box_to_box')
  boxToBox('box_to_box', 'Box-to-Box', CardPosition.midfielder),
  @JsonValue('top_kesici')
  ballWinner('top_kesici', 'Top Kesici', CardPosition.midfielder),
  @JsonValue('teknik_orta_saha')
  technician('teknik_orta_saha', 'Teknik Orta Saha', CardPosition.midfielder),
  @JsonValue('kurt_stoper')
  stopper('kurt_stoper', 'Kurt Stoper', CardPosition.defender),
  @JsonValue('oyun_kuran_stoper')
  ballPlayingDefender('oyun_kuran_stoper', 'Oyun Kuran Stoper', CardPosition.defender),
  @JsonValue('hucumcu_bek')
  attackingFullback('hucumcu_bek', 'Hücumcu Bek', CardPosition.defender),
  @JsonValue('savunmaci_bek')
  defensiveFullback('savunmaci_bek', 'Savunmacı Bek', CardPosition.defender),
  @JsonValue('cizgi_kalecisi')
  lineKeeper('cizgi_kalecisi', 'Çizgi Kalecisi', CardPosition.goalkeeper),
  @JsonValue('libero_kaleci')
  sweeperKeeper('libero_kaleci', 'Libero Kaleci', CardPosition.goalkeeper);

  final String code;
  final String label;

  /// Bu tarzın ait olduğu mevki (doğrulayıcı uyumu buna göre denetler)
  final CardPosition position;

  const Playstyle(this.code, this.label, this.position);

  static Playstyle? tryParse(String? code) {
    for (final p in values) {
      if (p.code == code) return p;
    }
    return null;
  }

  static List<Playstyle> forPosition(CardPosition p) =>
      values.where((s) => s.position == p).toList();
}

@JsonEnum()
enum CharacterStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('in_review')
  inReview,
  @JsonValue('approved')
  approved,
  @JsonValue('published')
  published,
  @JsonValue('retired')
  retired;

  /// Oyunculara görünür mü?
  bool get isPlayable => this == CharacterStatus.published;
}

@JsonEnum()
enum AnimationProfile {
  @JsonValue('sakin')
  calm,
  @JsonValue('dengeli')
  balanced,
  @JsonValue('gosterisci')
  showman,
  @JsonValue('lider')
  leader;
}

/// Karakterin görünüşü (görsel üretim tanımı buradan şablonla kurulur)
@freezed
abstract class CharacterAppearance with _$CharacterAppearance {
  const factory CharacterAppearance({
    required String skinTone,
    required String hair,
    required String face,
    required String build,
    required String accessory,
    required int shirtNumber,
  }) = _CharacterAppearance;

  factory CharacterAppearance.fromJson(Map<String, dynamic> json) =>
      _$CharacterAppearanceFromJson(json);
}

/// Özgün futbolcu karakteri (kimlik). GÜÇ YOK.
@freezed
abstract class Character with _$Character {
  const Character._();

  const factory Character({
    required String id,
    required String slug,
    required String catalogVersion,
    required String givenName,
    required String familyName,
    required String displayName,
    required String regionCode,
    required String clubCode,
    required CardPosition primaryPosition,
    CardPosition? secondaryPosition,
    required Playstyle playstyle,
    @Default([]) List<String> personality,
    required String bioShort,
    required String bioLong,
    required CharacterAppearance appearance,
    required String visualPrompt,
    @Default(AnimationProfile.balanced) AnimationProfile animationProfile,
    @Default(CharacterStatus.draft) CharacterStatus status,
    required String createdBy,
    required String generator,
    String? generatorModel,
  }) = _Character;

  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);

  /// Baş harfler (portre yokken siluetin üstünde). runes: Türkçe
  /// harfler (İ, Ş, Ğ) tek karakter olarak alınır.
  String get initials => String.fromCharCodes(
      [givenName.runes.first, familyName.runes.first]);
}

/// Denge Motoru'nun önerdiği oyun değerleri (oyuna GİRMEMİŞ öneri)
@freezed
abstract class CharacterCardProposal with _$CharacterCardProposal {
  const factory CharacterCardProposal({
    required String characterId,
    required CardTier tier,
    required int power,
    required CardAttributes attributes,
    required String slot,
    required String balanceEngineVersion,
  }) = _CharacterCardProposal;

  factory CharacterCardProposal.fromJson(Map<String, dynamic> json) =>
      _$CharacterCardProposalFromJson(json);
}

@JsonEnum()
enum CharacterAssetKind {
  @JsonValue('reference_sheet')
  referenceSheet,
  @JsonValue('portrait')
  portrait,
  @JsonValue('card_art')
  cardArt,
  @JsonValue('model_glb')
  modelGlb,
  @JsonValue('rig')
  rig,
  @JsonValue('anim_clip')
  animClip,
  @JsonValue('sprite_sheet')
  spriteSheet;
}

/// Arenada karakter nasıl gösterilebilir? (sunucu `character_presentation`)
@JsonEnum()
enum PresentationMode {
  /// Onaylı model + rig + mevkinin bütün klipleri
  @JsonValue('3d')
  threeD,

  /// Onaylı sprite sayfası
  @JsonValue('sprite')
  sprite,

  /// Yedek: mevcut 2.5B arena (ArenaBackdrop / ClashScene)
  @JsonValue('2.5d')
  fallback25d;
}

/// Sunucunun `character_presentation()` cevabı.
///
/// Eksik olan her şey listelenir; arayüz hiçbir şeyi "hazır" gibi
/// göstermemek için bunu kullanır.
@freezed
abstract class CharacterPresentation with _$CharacterPresentation {
  const CharacterPresentation._();

  const factory CharacterPresentation({
    required String characterId,
    required PresentationMode mode,
    String? portraitUri,
    String? modelUri,
    String? rigUri,
    String? spriteUri,
    @Default([]) List<String> approvedClips,
    @Default([]) List<String> missingClips,
    @Default([]) List<String> missingAssets,
  }) = _CharacterPresentation;

  factory CharacterPresentation.fromJson(Map<String, dynamic> json) =>
      _$CharacterPresentationFromJson(json);

  bool get hasPortrait => portraitUri != null;
  bool get isFullyAnimated => mode == PresentationMode.threeD;
}
