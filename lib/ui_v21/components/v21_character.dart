import 'package:flutter/material.dart';

/// KART KARAKTERLERİ: `assets/v21/characters/c001.webp` … `c550.webp`.
///
/// Bu 550 karakter yalnız futbolcu kartlarında kullanılır. Aynı futbolcu adı
/// her ekranda ve cihazda aynı karakteri verir. Maskot Efsane Kaptan ayrıdır
/// ([V21MascotHead], `V21Assets`).
abstract final class V21Characters {
  static const int count = 550;

  /// Katalogdaki 100 futbolcunun karakterleri çakışmasın diye seçildi
  static const int _salt = 8937;

  static String assetFor(String key) => assetAt(indexFor(key));

  static String assetAt(int index) => 'assets/v21/characters/c${(index + 1).toString().padLeft(3, '0')}.webp';

  /// FNV-1a: platformdan bağımsız, her açılışta aynı sonuç (String.hashCode değil)
  static int indexFor(String key) {
    var h = 0x811c9dc5 ^ _salt;
    for (final unit in key.toLowerCase().trim().codeUnits) {
      h ^= unit;
      // h * 0x01000193 (mod 2^32): webde de aynı sonuç için parçalı çarpım
      h = (((h << 24) & 0xffffffff) + h * 0x193) & 0xffffffff;
    }
    return h % count;
  }
}

/// Karakter görseli. Üstten hizalanır: dar çerçevede yüz kesilmez.
class V21CharacterArt extends StatelessWidget {
  final String asset;
  final BoxFit fit;
  final Alignment alignment;

  const V21CharacterArt.asset(this.asset, {super.key, this.fit = BoxFit.cover, this.alignment = Alignment.topCenter});

  V21CharacterArt({
    required String characterKey,
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
  }) : asset = V21Characters.assetFor(characterKey);

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
