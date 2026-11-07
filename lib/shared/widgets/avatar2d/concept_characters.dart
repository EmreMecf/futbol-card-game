import 'package:flutter/painting.dart';
import 'package:shared_models/shared_models.dart';

import 'avatar_spec.dart';

// =====================================================================
// 10 ÖRNEK STİLİZE FUTBOLCU KONSEPTİ (yeni 2D görsel yön)
// =====================================================================
// Hepsi KURGUSAL: adlar, kulüpler ve görünüşler özgün. Gerçek bir
// futbolcuyu taklit etmez.
//
// DURUM: Sadece #1 (Kaelen Brisvoy) veritabanında var (026, taslak).
// Diğer 9'u yalnızca GÖRSEL KONSEPT: kart değeri, gücü ve oyunda karşılığı
// YOK. Güç ve özellikler eklenirken Denge Motoru'ndan geçmeleri gerekir.

class ConceptCharacter {
  final String slug;
  final String name;
  final CardPosition position;
  final Playstyle playstyle;
  final String clubName;
  final String concept;
  final AvatarSpec spec;

  /// Veritabanında kaydı var mı? (sadece Kaelen)
  final bool inDatabase;

  const ConceptCharacter({
    required this.slug,
    required this.name,
    required this.position,
    required this.playstyle,
    required this.clubName,
    required this.concept,
    required this.spec,
    this.inDatabase = false,
  });
}

// Kurgusal kulüp renkleri
const _lrf = (Color(0xFF1FB5A8), Color(0xFF0E2A47)); // Liman Rüzgârı FK
const _kfs = (Color(0xFFD6334A), Color(0xFFF7F3EE)); // Kuzey Fener SK
const _mkf = (Color(0xFF2E6BD8), Color(0xFFF2C94C)); // Mavi Koy FK
const _bzk = (Color(0xFF7A5230), Color(0xFFF2E3C6)); // Bozkır Kartalları
const _tyz = (Color(0xFFF08A24), Color(0xFF14213D)); // Tepe Yıldızı

const List<ConceptCharacter> kConceptCharacters = [
  ConceptCharacter(
    slug: 'kaelen-brisvoy',
    name: 'Kaelen Brisvoy',
    position: CardPosition.forward,
    playstyle: Playstyle.fastWinger,
    clubName: 'Liman Rüzgârı FK',
    concept: 'Bakır saçlı, çilli, ince yapılı kanat. Turkuaz bileklik.',
    inDatabase: true,
    spec: AvatarSpec(
      skin: SkinTone.wheat,
      head: HeadShape.oval,
      hair: HairStyle.sidePart,
      hairColor: Color(0xFFC0622B),
      eyes: EyeStyle.dot,
      brows: BrowStyle.soft,
      mouth: MouthStyle.smirk,
      freckles: true,
      wristband: Color(0xFF2EC4B6),
      build: BodyBuild.slim,
      jersey: Color(0xFF1FB5A8),
      jerseyTrim: Color(0xFF0E2A47),
      shirtNumber: 17,
    ),
  ),
  ConceptCharacter(
    slug: 'oru-tamessa',
    name: 'Oru Tamessa',
    position: CardPosition.defender,
    playstyle: Playstyle.stopper,
    clubName: 'Kuzey Fener SK',
    concept: 'Kısa kazınmış saç, dolgun sakal, kalın kaş. Duvar gibi stoper.',
    spec: AvatarSpec(
      skin: SkinTone.deep,
      head: HeadShape.square,
      hair: HairStyle.buzz,
      hairColor: Color(0xFF16110F),
      brows: BrowStyle.thick,
      mouth: MouthStyle.serious,
      facialHair: FacialHair.beard,
      build: BodyBuild.stocky,
      jersey: Color(0xFFD6334A),
      jerseyTrim: Color(0xFFF7F3EE),
      shirtNumber: 4,
    ),
  ),
  ConceptCharacter(
    slug: 'ilyas-venkor',
    name: 'Ilyas Venkor',
    position: CardPosition.midfielder,
    playstyle: Playstyle.playmaker,
    clubName: 'Mavi Koy FK',
    concept: 'Topuz saç, saç bandı, yeşil gözler. Sakin oyun kurucu.',
    spec: AvatarSpec(
      skin: SkinTone.light,
      head: HeadShape.long,
      hair: HairStyle.bun,
      hairColor: Color(0xFF4A2E1C),
      eyes: EyeStyle.almond,
      eyeColor: Color(0xFF3E8F5A),
      mouth: MouthStyle.smile,
      headAccessory: HeadAccessory.headband,
      jersey: Color(0xFF2E6BD8),
      jerseyTrim: Color(0xFFF2C94C),
      shirtNumber: 8,
    ),
  ),
  ConceptCharacter(
    slug: 'teo-marrakan',
    name: 'Teo Marrakan',
    position: CardPosition.goalkeeper,
    playstyle: Playstyle.lineKeeper,
    clubName: 'Bozkır Kartalları',
    concept: 'Uzun dalgalı siyah saç, keskin kaşlar. Çizgide refleks ustası.',
    spec: AvatarSpec(
      skin: SkinTone.tan,
      head: HeadShape.oval,
      hair: HairStyle.longWavy,
      hairColor: Color(0xFF1C1716),
      brows: BrowStyle.angled,
      mouth: MouthStyle.grin,
      jersey: Color(0xFF9BD93A),
      jerseyTrim: Color(0xFF1B2A12),
      shorts: Color(0xFF1B2A12),
      shirtNumber: 1,
    ),
  ),
  ConceptCharacter(
    slug: 'jun-halvik',
    name: 'Jun Halvik',
    position: CardPosition.forward,
    playstyle: Playstyle.finisher,
    clubName: 'Kuzey Fener SK',
    concept: 'Sarı ibik, göz altı siyah boya. Ceza sahası tilkisi.',
    spec: AvatarSpec(
      skin: SkinTone.porcelain,
      head: HeadShape.round,
      hair: HairStyle.mohawk,
      hairColor: Color(0xFFE8C26A),
      eyes: EyeStyle.dot,
      eyeColor: Color(0xFF3A6FD8),
      brows: BrowStyle.angled,
      mouth: MouthStyle.smirk,
      headAccessory: HeadAccessory.eyeBlack,
      jersey: Color(0xFFD6334A),
      jerseyTrim: Color(0xFFF7F3EE),
      shirtNumber: 9,
    ),
  ),
  ConceptCharacter(
    slug: 'amaru-seldi',
    name: 'Amaru Seldi',
    position: CardPosition.midfielder,
    playstyle: Playstyle.boxToBox,
    clubName: 'Tepe Yıldızı',
    concept: 'Büyük afro, kocaman gülüş. Bitmeyen enerji.',
    spec: AvatarSpec(
      skin: SkinTone.brown,
      head: HeadShape.round,
      hair: HairStyle.afro,
      hairColor: Color(0xFF2A1A12),
      mouth: MouthStyle.grin,
      jersey: Color(0xFFF08A24),
      jerseyTrim: Color(0xFF14213D),
      shirtNumber: 6,
    ),
  ),
  ConceptCharacter(
    slug: 'dario-fenwyck',
    name: 'Dario Fenwyck',
    position: CardPosition.defender,
    playstyle: Playstyle.attackingFullback,
    clubName: 'Mavi Koy FK',
    concept: 'Kıvırcık kahve saç, altın küpe. Çizgide durmayan bek.',
    spec: AvatarSpec(
      skin: SkinTone.wheat,
      head: HeadShape.oval,
      hair: HairStyle.curlyTop,
      hairColor: Color(0xFF5A3A22),
      eyes: EyeStyle.almond,
      eyeColor: Color(0xFF6B4423),
      mouth: MouthStyle.smile,
      headAccessory: HeadAccessory.earring,
      build: BodyBuild.slim,
      jersey: Color(0xFF2E6BD8),
      jerseyTrim: Color(0xFFF2C94C),
      shirtNumber: 2,
    ),
  ),
  ConceptCharacter(
    slug: 'sami-kortel',
    name: 'Sami Kortel',
    position: CardPosition.midfielder,
    playstyle: Playstyle.technician,
    clubName: 'Liman Rüzgârı FK',
    concept: 'Kısa siyah saç, bıyık, uykulu bakış. Topu ayağına yapıştıran teknisyen.',
    spec: AvatarSpec(
      skin: SkinTone.light,
      head: HeadShape.square,
      hair: HairStyle.crop,
      hairColor: Color(0xFF1E1A1A),
      eyes: EyeStyle.sleepy,
      mouth: MouthStyle.smirk,
      facialHair: FacialHair.mustache,
      jersey: Color(0xFF1FB5A8),
      jerseyTrim: Color(0xFF0E2A47),
      shirtNumber: 10,
    ),
  ),
  ConceptCharacter(
    slug: 'nayo-breck',
    name: 'Nayo Breck',
    position: CardPosition.forward,
    playstyle: Playstyle.targetMan,
    clubName: 'Tepe Yıldızı',
    concept: 'Örgülü saç, geniş omuzlar. Hava toplarının sahibi.',
    spec: AvatarSpec(
      skin: SkinTone.deep,
      head: HeadShape.long,
      hair: HairStyle.cornrows,
      hairColor: Color(0xFF16110F),
      brows: BrowStyle.thick,
      mouth: MouthStyle.serious,
      facialHair: FacialHair.stubble,
      build: BodyBuild.stocky,
      jersey: Color(0xFFF08A24),
      jerseyTrim: Color(0xFF14213D),
      shirtNumber: 19,
    ),
  ),
  ConceptCharacter(
    slug: 'elian-rusk',
    name: 'Elian Rusk',
    position: CardPosition.goalkeeper,
    playstyle: Playstyle.sweeperKeeper,
    clubName: 'Bozkır Kartalları',
    concept: 'Saçsız, kızıl sakal, geniş gülüş. Kalesinden çıkmayı seven libero.',
    spec: AvatarSpec(
      skin: SkinTone.light,
      head: HeadShape.round,
      hair: HairStyle.bald,
      hairColor: Color(0xFFB4441F),
      eyes: EyeStyle.almond,
      eyeColor: Color(0xFF4A7FB5),
      mouth: MouthStyle.grin,
      facialHair: FacialHair.beard,
      jersey: Color(0xFF8B5CF6),
      jerseyTrim: Color(0xFFF2E3C6),
      shirtNumber: 23,
    ),
  ),
];

/// Slug ile konsept (yoksa null)
ConceptCharacter? conceptBySlug(String slug) {
  for (final c in kConceptCharacters) {
    if (c.slug == slug) return c;
  }
  return null;
}

/// Bir karakterin çizim tanımı. Önce tasarlanmış konsept, yoksa
/// veritabanındaki serbest metinli görünüşten tahmini tanım.
/// İkinci bilgi ekranda "kaynak" olarak gösterilir.
(AvatarSpec, String) resolveAvatar(Character c) {
  final k = conceptBySlug(c.slug);
  if (k != null) return (k.spec, 'Tasarlanmış konsept tanımı (uygulama içinde)');
  return (
    AvatarSpec.fromAppearance(c.slug, c.appearance, jersey: _lrf.$1, jerseyTrim: _lrf.$2),
    'Veritabanındaki görünüş metninden tahmini tanım',
  );
}

// Kullanılmayan kulüp sabitleri analiz uyarısı vermesin diye listede
// tutulur; ileride kulüp tablosuna taşınacak.
const kConceptClubColors = {
  'LRF': _lrf,
  'KFS': _kfs,
  'MKF': _mkf,
  'BZK': _bzk,
  'TYZ': _tyz,
};
