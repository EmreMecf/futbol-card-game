import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../avatar2d/avatar_spec.dart';
import '../avatar2d/concept_characters.dart';
import '../ref_card/ref_player_card.dart';

/// Uygulamanın oyuncu kartı — ARTIK referans tasarımın ortak kartıdır.
///
/// Bu sınıf geriye uyumluluk için duruyor: maç eli, kadro, paket ve
/// koleksiyon onu `PremiumPlayerCard.fromInventory(...)` gibi çağırıyor.
/// Çizimin TAMAMI [RefPlayerCard]'da (referans `.revealcard` oranı, 0.70'e
/// yakın: 205 x 295). Eski FIFA tarzı çerçeve, eğilme ve holografik
/// katmanlar kaldırıldı; yerine referanstaki koyu lacivert kart ve
/// karaktere özel 2D yüz geldi.
///
/// Görsel yoksa artık siluet ÇİZİLMEZ: kartın kalıcı kimliğinden
/// deterministik bir 2D yüz üretilir ([AvatarSpec.generate]).
class PremiumPlayerCard extends StatelessWidget {
  final String fullName;
  final CardPosition position;
  final CardTier tier;
  final int power;
  final String? imageUrl;
  final String? nationality;
  final String? club;

  /// Eski arayüzden kalan alan; yeni kart özellik ızgarası çizmez
  /// (referans kartında yok). Detay penceresi özellikleri ayrıca gösterir.
  final CardAttributes? attributes;

  final double width;
  final bool isProtected;
  final bool isLocked;
  final bool isPlayed;
  final bool isSelected;
  final bool isFavorite;

  /// Hareketli nadirlik ışıkları (listelerde kapalı tutulmalı)
  final bool interactive;

  /// Eski arayüzden; yeni kartta jiroskop eğilmesi yok
  final bool useGyroscope;
  final VoidCallback? onTap;

  /// Özgün karakterin oyun tarzı (eski arayüzden; kart göstermiyor)
  final String? playstyleLabel;

  /// Eski arayüzden; artık eksik portre yerine üretilmiş yüz çizilir
  final bool flagMissingPortrait;

  /// Yüz kimliği. Null ise ad + mevki kullanılır.
  final String? avatarSeed;

  /// Hazır karakter tanımı (özgün karakterler)
  final AvatarSpec? avatar;

  const PremiumPlayerCard({
    super.key,
    required this.fullName,
    required this.position,
    required this.tier,
    required this.power,
    this.imageUrl,
    this.nationality,
    this.club,
    this.attributes,
    this.width = 200,
    this.isProtected = false,
    this.isLocked = false,
    this.isPlayed = false,
    this.isSelected = false,
    this.isFavorite = false,
    this.interactive = true,
    this.useGyroscope = false,
    this.onTap,
    this.playstyleLabel,
    this.flagMissingPortrait = false,
    this.avatarSeed,
    this.avatar,
  });

  /// Özgün karakterden (025) ve Denge Motoru önerisinden kart.
  factory PremiumPlayerCard.fromCharacter(
    Character karakter,
    CharacterCardProposal oneri, {
    Key? key,
    String? portraitUri,
    String? clubName,
    double width = 200,
    bool interactive = true,
    bool useGyroscope = false,
    VoidCallback? onTap,
  }) {
    return PremiumPlayerCard(
      key: key,
      fullName: karakter.displayName,
      position: karakter.primaryPosition,
      tier: oneri.tier,
      power: oneri.power,
      imageUrl: portraitUri,
      nationality: karakter.regionCode,
      club: clubName,
      attributes: oneri.attributes,
      width: width,
      interactive: interactive,
      onTap: onTap,
      playstyleLabel: karakter.playstyle.label,
      avatarSeed: karakter.slug,
      avatar: resolveAvatar(karakter).$1,
    );
  }

  /// Envanterdeki bir karttan
  factory PremiumPlayerCard.fromInventory(
    InventoryCard kart, {
    Key? key,
    double width = 200,
    bool isSelected = false,
    bool isFavorite = false,
    bool interactive = true,
    bool useGyroscope = false,
    VoidCallback? onTap,
  }) {
    return PremiumPlayerCard(
      key: key,
      fullName: kart.fullName,
      position: kart.position,
      tier: kart.tier,
      power: kart.power,
      imageUrl: kart.imageUrl,
      nationality: kart.nationality,
      club: kart.club,
      attributes: kart.attributes,
      width: width,
      isLocked: kart.isLocked,
      isSelected: isSelected,
      isFavorite: isFavorite,
      interactive: interactive,
      onTap: onTap,
      avatarSeed: kart.cardId,
    );
  }

  /// Maçtaki elden bir karttan
  factory PremiumPlayerCard.fromHand(
    HandCard kart, {
    Key? key,
    double width = 140,
    bool interactive = true,
    VoidCallback? onTap,
  }) {
    return PremiumPlayerCard(
      key: key,
      fullName: kart.fullName,
      position: kart.position,
      tier: kart.tier,
      power: kart.power,
      imageUrl: kart.imageUrl,
      nationality: kart.nationality,
      club: kart.club,
      attributes: kart.attributes,
      width: width,
      isProtected: kart.isProtected,
      isPlayed: kart.isPlayed,
      interactive: interactive,
      onTap: onTap,
      avatarSeed: kart.cardId,
    );
  }

  /// Kartın en/boy oranı (referans .revealcard 205 x 295)
  static double get aspectRatio => RefCardLayout.reveal.aspectRatio;

  @override
  Widget build(BuildContext context) => RefPlayerCard(
        name: fullName,
        position: position,
        tier: tier,
        power: power,
        seed: avatarSeed ?? '$fullName|${position.code}',
        kitSeed: club ?? nationality,
        spec: avatar,
        imageUrl: imageUrl,
        width: width,
        layout: RefCardLayout.reveal,
        isFavorite: isFavorite,
        isProtected: isProtected,
        isLocked: isLocked,
        isPlayed: isPlayed,
        isSelected: isSelected,
        animate: interactive,
        onTap: onTap,
      );
}
