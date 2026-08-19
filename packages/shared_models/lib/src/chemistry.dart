import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'game_rules.dart';

part 'chemistry.freezed.dart';
part 'chemistry.g.dart';

/// Bir bagin kalitesi (arayuzdeki renk)
enum ChemistryQuality {
  /// Ortak nokta yok — kirmizi
  none(0, 'Baglanti yok'),

  /// Ayni uyruk veya ayni lig — sari
  weak(1, 'Zayif bag'),

  /// Ayni kulup, ya da ayni ligde ayni uyruk — yesil
  strong(2, 'Guclu bag');

  final int score;
  final String label;

  const ChemistryQuality(this.score, this.label);

  static ChemistryQuality fromScore(int score) => switch (score) {
        >= 2 => ChemistryQuality.strong,
        1 => ChemistryQuality.weak,
        _ => ChemistryQuality.none,
      };
}

/// Formasyondaki iki slot arasindaki bag
class FormationLink {
  final int slotA;
  final int slotB;

  const FormationLink(this.slotA, this.slotB);

  bool touches(int slot) => slotA == slot || slotB == slot;
}

/// 4-4-2 FORMASYONU
///
///            [9]  [10]        <- Forvetler
///       [5] [6] [7] [8]       <- Orta saha
///       [1] [2] [3] [4]       <- Defans
///              [0]            <- Kaleci
///
/// Bu harita veritabanindaki `formation_links()` fonksiyonuyla BIREBIR
/// ayni olmali. Ikisi ayni kurali uygular ama biri digerine guvenmez:
/// buradaki hesap sadece kadro kurarken ONIZLEME icindir, macin gercek
/// sonucunu her zaman sunucu belirler.
const List<FormationLink> kFormationLinks = [
  // Kaleci <-> stoperler
  FormationLink(0, 2), FormationLink(0, 3),
  // Defans zinciri
  FormationLink(1, 2), FormationLink(2, 3), FormationLink(3, 4),
  // Defans <-> orta saha (dikey)
  FormationLink(1, 5), FormationLink(2, 6),
  FormationLink(3, 7), FormationLink(4, 8),
  // Orta saha zinciri
  FormationLink(5, 6), FormationLink(6, 7), FormationLink(7, 8),
  // Orta saha <-> forvet
  FormationLink(5, 9), FormationLink(6, 9),
  FormationLink(7, 10), FormationLink(8, 10),
  // Forvet ikilisi
  FormationLink(9, 10),
];

/// Ulasilabilecek en yuksek takim kimyasi (17 bag x 2 puan)
const int kMaxTeamChemistry = 34;

/// Bir slotta hangi pozisyon olmali?
CardPosition formationSlotPosition(int slot) {
  if (slot == 0) return CardPosition.goalkeeper;
  if (slot >= 1 && slot <= 4) return CardPosition.defender;
  if (slot >= 5 && slot <= 8) return CardPosition.midfielder;
  if (slot >= 9 && slot <= 10) return CardPosition.forward;
  throw ArgumentError('Gecersiz slot: $slot');
}

/// Bir pozisyonun slot numaralari (sirali)
List<int> slotsForPosition(CardPosition position) => switch (position) {
      CardPosition.goalkeeper => const [0],
      CardPosition.defender => const [1, 2, 3, 4],
      CardPosition.midfielder => const [5, 6, 7, 8],
      CardPosition.forward => const [9, 10],
    };

/// Kimya hesabi icin gereken asgari kart bilgisi.
///
/// Hem [InventoryCard] hem [HandCard] bu bilgileri tasidigi icin
/// arayuz olarak tanimlandi; kimya fonksiyonu ikisiyle de calisir.
abstract interface class ChemistrySource {
  String? get nationality;
  String? get league;
  String? get club;
}

/// Iki degerin ikisi de dolu ve esit mi?
///
/// NULL = NULL eslesme SAYILMAZ. Ligi belirsiz iki kart "ayni ligde"
/// sayilsaydi, eksik veri kimya kazandirirdi.
bool _ayniMi(String? a, String? b) => a != null && b != null && a == b;

/// Iki kart arasindaki kimya puani: 0, 1 veya 2.
///
/// KURALLAR:
///   Ayni Kulup VEYA (Ayni Lig + Ayni Uyruk) -> 2  (yesil)
///   Ayni Uyruk VEYA Ayni Lig                -> 1  (sari)
///   Ortak nokta yok                          -> 0  (kirmizi)
int chemistryLinkScore(ChemistrySource a, ChemistrySource b) {
  final ulke = _ayniMi(a.nationality, b.nationality);
  final lig = _ayniMi(a.league, b.league);
  final kulup = _ayniMi(a.club, b.club);

  if (kulup || (lig && ulke)) return 2;
  if (ulke || lig) return 1;
  return 0;
}

// =====================================================================
// MODELLER
// =====================================================================

/// Tek bir bagin sonucu
@freezed
abstract class ChemistryLink with _$ChemistryLink {
  const ChemistryLink._();

  const factory ChemistryLink({
    required int slotA,
    required int slotB,
    required int score,
  }) = _ChemistryLink;

  factory ChemistryLink.fromJson(Map<String, dynamic> json) =>
      _$ChemistryLinkFromJson(json);

  ChemistryQuality get quality => ChemistryQuality.fromScore(score);

  bool touches(int slot) => slotA == slot || slotB == slot;
}

/// Bir slottaki kartin kimya puani
@freezed
abstract class SlotChemistry with _$SlotChemistry {
  const factory SlotChemistry({
    required int slotIndex,
    String? userCardId,
    @Default(0) int chemistry,
  }) = _SlotChemistry;

  factory SlotChemistry.fromJson(Map<String, dynamic> json) =>
      _$SlotChemistryFromJson(json);
}

/// Bir kadronun tam kimya dokumu
@freezed
abstract class DeckChemistry with _$DeckChemistry {
  const DeckChemistry._();

  const factory DeckChemistry({
    @Default(0) int total,
    @Default(kMaxTeamChemistry) int maxTotal,
    @Default(false) bool isComplete,
    @Default([]) List<SlotChemistry> cards,
    @Default([]) List<ChemistryLink> links,
  }) = _DeckChemistry;

  factory DeckChemistry.fromJson(Map<String, dynamic> json) =>
      _$DeckChemistryFromJson(json);

  /// Bos kadro
  static const DeckChemistry empty = DeckChemistry();

  /// Belirli bir slottaki kartin kimyasi
  int chemistryAt(int slot) {
    for (final k in cards) {
      if (k.slotIndex == slot) return k.chemistry;
    }
    return 0;
  }

  /// Bir slota bagli tum baglar (cizgi cizerken kullanilir)
  List<ChemistryLink> linksAt(int slot) =>
      links.where((b) => b.touches(slot)).toList();

  /// Doluluk orani (0.0 - 1.0)
  double get ratio => maxTotal == 0 ? 0 : total / maxTotal;

  /// Yuzde olarak (ekranda gosterilir)
  int get percent => (ratio * 100).round();

  int get strongCount =>
      links.where((b) => b.quality == ChemistryQuality.strong).length;
  int get weakCount =>
      links.where((b) => b.quality == ChemistryQuality.weak).length;
  int get noneCount =>
      links.where((b) => b.quality == ChemistryQuality.none).length;

  /// Kimya seviyesini anlatan Turkce metin
  String get label {
    if (!isComplete) return 'Kadro eksik';
    final o = ratio;
    if (o >= 0.80) return 'Mukemmel uyum';
    if (o >= 0.55) return 'Guclu uyum';
    if (o >= 0.30) return 'Orta uyum';
    if (o > 0) return 'Zayif uyum';
    return 'Uyum yok';
  }

  // ------------------------------------------------------------------
  // YEREL HESAP (kadro kurarken anlik onizleme)
  // ------------------------------------------------------------------
  /// Slot -> kart haritasindan kimyayi hesaplar.
  ///
  /// ONEMLI: Bu hesap SADECE arayuz icindir. Macta kullanilan gercek
  /// kimya, mac baslarken sunucuda hesaplanip dondurulur. Buradaki
  /// kodu degistiren biri macin sonucunu degistiremez.
  ///
  /// Eksik slotlar (kart secilmemis) baglantiya girmez; oyuncu kadroyu
  /// doldururken kimya kademeli olarak artar.
  static DeckChemistry calculate(Map<int, ChemistrySource?> slots) {
    final baglar = <ChemistryLink>[];

    for (final bag in kFormationLinks) {
      final a = slots[bag.slotA];
      final b = slots[bag.slotB];

      // Iki uctan biri bossa bag hesaplanmaz
      if (a == null || b == null) continue;

      baglar.add(ChemistryLink(
        slotA: bag.slotA,
        slotB: bag.slotB,
        score: chemistryLinkScore(a, b),
      ));
    }

    final kartlar = <SlotChemistry>[];
    for (var slot = 0; slot < GameRules.squadSize; slot++) {
      if (slots[slot] == null) continue;

      final puan = baglar
          .where((b) => b.touches(slot))
          .fold<int>(0, (t, b) => t + b.score);

      kartlar.add(SlotChemistry(slotIndex: slot, chemistry: puan));
    }

    return DeckChemistry(
      total: baglar.fold<int>(0, (t, b) => t + b.score),
      maxTotal: kMaxTeamChemistry,
      isComplete: slots.values.where((k) => k != null).length ==
          GameRules.squadSize,
      cards: kartlar,
      links: baglar,
    );
  }
}
