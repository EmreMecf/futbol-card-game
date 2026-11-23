import 'package:flutter/material.dart';

/// Position-verified visual subset of the 550 illustrations.
/// UNKNOWN images MUST NOT be used until manually audited.
/// This prevents a GK illustration appearing on a midfielder card.
/// Remaining WebP assets are retained, not deleted.
abstract final class V21Characters {
  static const int count = 550;
  static const int _salt = 8937;

  /// Human-reviewed illustrations from original assets.
  /// Order and numbers intentionally fixed for consistent results on web/mobile.
  static const Map<String, List<int>> reviewedByPosition = {
    'GK': [1, 11, 12, 13, 14, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 121, 125, 130, 131, 132, 136, 251, 259, 261, 269],
    'DEF': [2, 15, 16, 17, 18, 20, 22, 23, 61, 62, 65, 71, 149, 151, 161],
    'MID': [7, 10, 25, 26, 27, 28, 30, 52, 53, 54, 55, 57, 60, 75, 80, 100, 105, 110, 115, 120, 150, 159, 181, 191, 199, 201, 209, 219, 221, 229, 231, 300, 400],
    'FWD': [3, 4, 5, 6, 8, 9, 19, 21, 24, 29, 38, 40, 56, 58, 59, 70, 81, 85, 90, 91, 101, 111, 141, 169, 179, 189, 200, 211, 239, 241, 249, 500, 550],
  };

  /// Full 550-file audit is outstanding; approved subset is intentionally
  /// conservative and will repeat illustrations until the remaining unreviewed images have been checked.
  static int get reviewedCount => reviewedByPosition.values
      .expand((v) => v)
      .toSet().length;

  static String assetAt(int index) =>
      'assets/v21/characters/c${(index + 1).toString().padLeft(3, '0')}.webp';

  static String _assetNumber(int number) =>
      'assets/v21/characters/c${number.toString().padLeft(3, '0')}.webp';

  /// Renaming one of the historical Legends must not change their portrait.
  static String canonicalKey(String key) {
    final normalized = key.toLowerCase().trim();
    return switch (normalized) {
      'aren solmar' || 'pele' || 'pelé' => 'legend-forvet-pele',
      'nerio valtan' || 'diego maradona' => 'legend-orta-diego-maradona',
      'elias veyron' || 'johan cruyff' => 'legend-orta-johan-cruyff',
      'borek kaldren' || 'franz beckenbauer' => 'legend-defans-franz-beckenbauer',
      'taren volsk' || 'lev yashin' => 'legend-kaleci-lev-yashin',
      'miran korvek' || 'ferenc puskas' => 'legend-forvet-ferenc-puskas',
      _ => normalized,
    };
  }

  /// Existing deterministic hash, used within a *position-approved* pool.
  static int indexFor(String key) {
    var h = 0x811c9dc5 ^ _salt;
    for (final unit in canonicalKey(key).codeUnits) {
      h ^= unit;
      h = (((h << 24) & 0xffffffff) + h * 0x193) & 0xffffffff;
    }
    return h % count;
  }

  /// Every rendered position must be one of GK, DEF, MID or FWD.
  /// Never fall back to the global 550-file pool.
  static String assetFor(String key, {required String position}) {
    final pool = reviewedByPosition[position.toUpperCase()];
    if (pool == null || pool.isEmpty) {
      throw ArgumentError.value(position, 'position', 'Invalid football position');
    }
    return _assetNumber(pool[indexFor(key) % pool.length]);
  }
}

/// Shared player illustration used by mobile cards and wide-screen Web cards.
class V21CharacterArt extends StatelessWidget {
  final String asset;
  final BoxFit fit;
  final Alignment alignment;

  const V21CharacterArt.asset(
    this.asset, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
  });

  V21CharacterArt({
    required String characterKey,
    required String position,
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
  }) : asset = V21Characters.assetFor(characterKey, position: position);

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      );
}
