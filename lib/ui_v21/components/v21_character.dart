import 'package:material_ui/material_ui.dart';

/// Visually curated positional illustration pools covering 550 artworks.
/// GK is determined from depicted keeper gloves; other roles are artistic
/// interpretations of posture and ball action, not canon player metadata.
/// This prevents a GK illustration appearing on a midfielder card.
/// All original WebP assets are retained and mapped to one role.
abstract final class V21Characters {
  static const int count = 550;
  static const int _salt = 8937;

  /// Human-reviewed illustrations from original assets.
  /// Order and numbers intentionally fixed for consistent results on web/mobile.
  static const Map<String, List<int>> reviewedByPosition = {
    'GK': [
      1, 11, 12, 13, 14, 41, 42, 43, 44, 45, 46, 47,
      48, 49, 50, 121, 122, 123, 124, 125, 126, 127, 128, 129,
      130, 131, 132, 133, 134, 135, 136, 251, 252, 253, 254, 255,
      256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267,
      268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279,
      280, 281, 282, 283, 284, 285, 286,
    ],
    'DEF': [
      2, 15, 16, 17, 18, 20, 22, 23, 61, 62, 69, 137,
      138, 142, 149, 156, 161, 163, 171, 175, 287, 288, 289, 290,
      291, 292, 296, 301, 307, 309, 314, 320, 323, 324, 325, 326,
      330, 337, 339, 343, 346, 349, 353, 354, 356, 357, 359, 360,
      363, 365, 451,
    ],
    'MID': [
      7, 10, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35,
      36, 37, 39, 51, 52, 53, 54, 55, 57, 60, 63, 64,
      65, 66, 67, 68, 71, 72, 73, 74, 75, 76, 77, 78,
      79, 80, 82, 83, 84, 86, 87, 88, 89, 92, 93, 94,
      95, 96, 98, 99, 100, 102, 103, 105, 106, 110, 113, 115,
      117, 118, 119, 120, 139, 140, 141, 143, 144, 145, 146, 147,
      150, 151, 152, 154, 155, 157, 158, 159, 160, 162, 164, 165,
      166, 167, 168, 170, 172, 173, 174, 176, 180, 181, 182, 183,
      185, 186, 187, 188, 190, 191, 192, 193, 194, 195, 196, 198,
      199, 201, 203, 204, 205, 206, 207, 208, 209, 210, 212, 213,
      214, 215, 216, 217, 218, 219, 220, 221, 222, 225, 227, 229,
      231, 232, 233, 234, 235, 236, 237, 238, 242, 243, 246, 247,
      248, 250, 294, 295, 297, 299, 300, 303, 304, 305, 306, 308,
      310, 311, 312, 315, 316, 317, 318, 319, 321, 322, 328, 329,
      331, 332, 333, 334, 335, 336, 338, 340, 341, 344, 345, 347,
      348, 350, 351, 352, 358, 361, 362, 364, 367, 368, 370, 371,
      372, 373, 374, 375, 376, 383, 385, 386, 387, 390, 391, 393,
      395, 396, 398, 399, 400, 401, 408, 410, 411, 412, 413, 415,
      416, 417, 418, 421, 423, 424, 426, 427, 429, 431, 434, 435,
      436, 437, 439, 440, 441, 443, 444, 446, 449, 452, 453, 455,
      456, 457, 458, 459, 460, 461, 462, 463, 464, 465, 467, 468,
      469, 470, 471, 472, 474, 475, 481, 482, 485, 486, 487, 489,
      492, 494, 499, 501, 503, 506, 508, 509, 512, 519, 520, 523,
      526, 527, 528, 529, 531, 532, 533, 535, 536, 537, 540, 545,
      547, 548, 549,
    ],
    'FWD': [
      3, 4, 5, 6, 8, 9, 19, 21, 24, 29, 38, 40,
      56, 58, 59, 70, 81, 85, 90, 91, 97, 101, 104, 107,
      108, 109, 111, 112, 114, 116, 148, 153, 169, 177, 178, 179,
      184, 189, 197, 200, 202, 211, 223, 224, 226, 228, 230, 239,
      240, 241, 244, 245, 249, 293, 298, 302, 313, 327, 342, 355,
      366, 369, 377, 378, 379, 380, 381, 382, 384, 388, 389, 392,
      394, 397, 402, 403, 404, 405, 406, 407, 409, 414, 419, 420,
      422, 425, 428, 430, 432, 433, 438, 442, 445, 447, 448, 450,
      454, 466, 473, 476, 477, 478, 479, 480, 483, 484, 488, 490,
      491, 493, 495, 496, 497, 498, 500, 502, 504, 505, 507, 510,
      511, 513, 514, 515, 516, 517, 518, 521, 522, 524, 525, 530,
      534, 538, 539, 541, 542, 543, 544, 546, 550,
    ],
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
