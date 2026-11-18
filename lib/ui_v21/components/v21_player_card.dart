import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../shared/widgets/avatar2d/avatar_painter.dart';
import '../../shared/widgets/avatar2d/avatar_spec.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import 'v21_painters.dart';
import 'v21_tap.dart';

/// Nadirlik görünümü (referans Koleksiyon ekranı kenar ve zemin renkleri)
@immutable
class V21Rarity {
  final Color frame;
  final Color frameLight;
  final List<Color> art;
  final String name;
  const V21Rarity(this.frame, this.frameLight, this.art, this.name);

  static V21Rarity of(CardTier t) => switch (t) {
    CardTier.legend => const V21Rarity(Color(0xFFA35BEA), Color(0xFFDDB0FF), [
      Color(0xFF8E54E0),
      Color(0xFF4B1D9C),
    ], 'EFSANE'),
    CardTier.diamond => const V21Rarity(Color(0xFF37B5F0), Color(0xFFA7EBFF), [
      Color(0xFF58D2FF),
      Color(0xFF1C7FC2),
    ], 'ELMAS'),
    CardTier.gold => const V21Rarity(Color(0xFFF2B526), Color(0xFFFFE38A), [
      Color(0xFFFFD55A),
      Color(0xFFE89A1A),
    ], 'ALTIN'),
    CardTier.silver => const V21Rarity(Color(0xFFA9B8C8), Color(0xFFE6EEF6), [
      Color(0xFFC9D5E2),
      Color(0xFF7D8DA3),
    ], 'GÜMÜŞ'),
    CardTier.bronze => const V21Rarity(Color(0xFFCB7F4E), Color(0xFFF5C49C), [
      Color(0xFFE6A276),
      Color(0xFF9B5530),
    ], 'BRONZ'),
  };
}

/// V2.1 OYUNCU KARTI (referans Koleksiyon: 165×235, köşe 16).
///
///   (98)        [FWD]     ← güç dairesi + mevki hapı
///   ███ portre ███
///   ┌ Efsane Kaptan ┐     ← ad plakası
///   └ ★ EFSANE ★    ┘
///
/// Portre: onaylı görsel ([imageUrl]) varsa o; yoksa projedeki 2D
/// karakter çizicisi ([AvatarPortrait]) kartın kimliğinden üretilir.
/// Bütün ölçüler [width] / 165 oranında ölçeklenir.
class V21PlayerCard extends StatelessWidget {
  final String name;
  final CardPosition position;
  final CardTier tier;
  final int power;
  final String seed;
  final String? kitSeed;
  final String? imageUrl;
  final AvatarSpec? spec;
  final double width;
  final bool selected;

  /// Kart şu an kullanılamaz (sunucu `is_locked`: ör. süren maçta)
  final bool locked;

  /// Oyuncunun favorisi (bu cihazda saklanır): mevki hapının altında kalp
  final bool favorite;
  final VoidCallback? onTap;

  static const double baseWidth = 165;
  static const double baseHeight = 235;

  const V21PlayerCard({
    super.key,
    required this.name,
    required this.position,
    required this.tier,
    required this.power,
    required this.seed,
    this.kitSeed,
    this.imageUrl,
    this.spec,
    this.width = baseWidth,
    this.selected = false,
    this.locked = false,
    this.favorite = false,
    this.onTap,
  });

  /// Sunucu kart modelinden
  factory V21PlayerCard.fromCard(
    CardModel c, {
    Key? key,
    double width = baseWidth,
    VoidCallback? onTap,
    bool selected = false,
  }) => V21PlayerCard(
    key: key,
    name: c.fullName,
    position: c.position,
    tier: c.tier,
    power: c.power,
    seed: c.cardId,
    kitSeed: c.club,
    imageUrl: c.imageUrl,
    width: width,
    onTap: onTap,
    selected: selected,
  );

  @override
  Widget build(BuildContext context) {
    final k = width / baseWidth;
    final h = baseHeight * k;
    final r = V21Rarity.of(tier);
    final radius = BorderRadius.circular(16 * k);

    final art = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(center: const Alignment(0, -0.3), radius: 0.9, colors: r.art),
      ),
      child: _portrait(k),
    );

    final card = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: V21Colors.ink,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 10 * k, offset: Offset(0, 5 * k)),
          if (selected) BoxShadow(color: r.frameLight.withValues(alpha: 0.8), blurRadius: 16 * k, spreadRadius: 2 * k),
        ],
      ),
      padding: EdgeInsets.all(2.5 * k),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * k),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [r.frameLight, r.frame],
          ),
        ),
        padding: EdgeInsets.all(4 * k),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11 * k),
          child: Stack(
            fit: StackFit.expand,
            children: [
              art,
              // Ad plakası
              Positioned(
                left: 4 * k,
                right: 4 * k,
                bottom: 4 * k,
                height: 50 * k,
                child: Container(
                  decoration: BoxDecoration(
                    color: V21Colors.ink.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(9 * k),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 6 * k),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(name, maxLines: 1, style: V21Type.title(17 * k, letterSpacing: 0.1)),
                      ),
                      SizedBox(height: 2 * k),
                      // Yıldızlar simge: gövde yazı tipinde ★ glifi yok
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          V21StarIcon(size: 8 * k, color: r.frameLight),
                          SizedBox(width: 3 * k),
                          Text(
                            r.name,
                            maxLines: 1,
                            style: V21Type.label(
                              9 * k,
                              weight: FontWeight.w800,
                              color: r.frameLight,
                              letterSpacing: 0.4,
                            ),
                          ),
                          SizedBox(width: 3 * k),
                          V21StarIcon(size: 8 * k, color: r.frameLight),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Güç dairesi ve mevki hapı çerçevenin üstüne taşar (referans)
    final full = SizedBox(
      width: width,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            left: -2 * k,
            top: -2 * k,
            child: Container(
              width: 46 * k,
              height: 46 * k,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: V21Colors.ink,
                border: Border.all(color: r.frameLight, width: 3 * k),
              ),
              alignment: Alignment.center,
              child: Text('$power', style: V21Type.title(24 * k)),
            ),
          ),
          Positioned(
            right: 8 * k,
            top: 9 * k,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 7 * k, vertical: 1.5 * k),
              decoration: BoxDecoration(
                color: V21Colors.ink,
                borderRadius: BorderRadius.circular(8 * k),
                border: Border.all(color: r.frameLight, width: 1.5 * k),
              ),
              child: Text(position.code, style: V21Type.label(11 * k, weight: FontWeight.w900)),
            ),
          ),
          if (favorite)
            Positioned(
              right: 8 * k,
              top: 33 * k,
              child: Container(
                width: 24 * k,
                height: 24 * k,
                decoration: const BoxDecoration(color: V21Colors.ink, shape: BoxShape.circle),
                child: Icon(Icons.favorite_rounded, size: 15 * k, color: V21Colors.danger),
              ),
            ),
          if (locked)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: V21Colors.ink.withValues(alpha: 0.55), borderRadius: radius),
                child: Align(
                  alignment: const Alignment(0, -0.15),
                  child: Icon(Icons.lock_rounded, size: 40 * k, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '${position.label}, ${r.name}, güç $power, $name${favorite ? ', favori' : ''}${locked ? ', kilitli' : ''}',
      excludeSemantics: true,
      child: V21Tap(onTap: onTap, behavior: HitTestBehavior.opaque, child: full),
    );
  }

  Widget _portrait(double k) {
    final url = imageUrl;
    final avatar = Align(
      alignment: const Alignment(0, -0.2),
      child: AvatarPortrait(
        spec: spec ?? AvatarSpec.generate(seed, kitSeed: kitSeed),
        size: 150 * k,
      ),
    );
    if (url != null && (url.startsWith('http://') || url.startsWith('https://'))) {
      return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, _, _) => avatar);
    }
    return avatar;
  }
}
