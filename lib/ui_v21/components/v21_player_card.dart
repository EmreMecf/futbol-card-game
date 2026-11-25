import 'package:material_ui/material_ui.dart';
import 'package:shared_models/shared_models.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import 'v21_character.dart';
import 'v21_painters.dart';
import 'v21_tap.dart';
import '../../core/l10n/app_language.dart';

/// Nadirlik görünümü (referans Koleksiyon ekranı kenar ve zemin renkleri)
@immutable
class V21Rarity {
  final Color frame;
  final Color frameLight;
  final List<Color> art;
  final String name;
  const V21Rarity(this.frame, this.frameLight, this.art, this.name);

  static V21Rarity of(CardTier t) => switch (t) {
    CardTier.legend => V21Rarity(const Color(0xFFA35BEA), const Color(0xFFDDB0FF), [
      const Color(0xFF8E54E0),
      const Color(0xFF4B1D9C),
    ], 'EFSANE'.tr),
    CardTier.diamond => V21Rarity(const Color(0xFF37B5F0), const Color(0xFFA7EBFF), [
      const Color(0xFF58D2FF),
      const Color(0xFF1C7FC2),
    ], 'ELMAS'.tr),
    CardTier.gold => V21Rarity(const Color(0xFFF2B526), const Color(0xFFFFE38A), [
      const Color(0xFFFFD55A),
      const Color(0xFFE89A1A),
    ], 'ALTIN'.tr),
    CardTier.silver => V21Rarity(const Color(0xFFA9B8C8), const Color(0xFFE6EEF6), [
      const Color(0xFFC9D5E2),
      const Color(0xFF7D8DA3),
    ], 'GÜMÜŞ'.tr),
    CardTier.bronze => V21Rarity(const Color(0xFFCB7F4E), const Color(0xFFF5C49C), [
      const Color(0xFFE6A276),
      const Color(0xFF9B5530),
    ], 'BRONZ'.tr),
  };
}

/// V2.1 OYUNCU KARTI (referans Koleksiyon: 165×235, köşe 16).
///
///   (98)        [FWD]     ← güç dairesi + mevki hapı
///   ███ portre ███
///   ┌ Efsane Kaptan ┐     ← ad plakası
///   └ ★ EFSANE ★    ┘
///
/// Portre: mevkisi görsel olarak doğrulanmış karakter havuzundan seçilir.
/// Bütün ölçüler [width] / 165 oranında ölçeklenir.
class V21PlayerCard extends StatelessWidget {
  final String name;

  /// Kartın değişmeyen katalog kimliği (`slug`); görsel buna bağlanır
  final String? artKey;
  final CardPosition position;
  final CardTier tier;
  final int power;
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
    this.artKey,
    required this.position,
    required this.tier,
    required this.power,
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
    artKey: c.slug,
    position: c.position,
    tier: c.tier,
    power: c.power,
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
      label: '{label}, {name}, güç {power}, {name2}{p}{p2}'.trArgs({'label': position.label, 'name': r.name, 'power': power, 'name2': name, 'p': favorite ? ', favori'.tr : '', 'p2': locked ? ', kilitli'.tr : ''}),
      excludeSemantics: true,
      child: V21Tap(onTap: onTap, behavior: HitTestBehavior.opaque, child: full),
    );
  }

  /// Futbolcunun karakteri: aynı ad her ekranda aynı karakter
  Widget _portrait(double k) => Padding(
    padding: EdgeInsets.only(top: 4 * k, bottom: 40 * k),
    child: V21CharacterArt(characterKey: V21Characters.keyFor(name: name, slug: artKey), position: position.code),
  );
}
