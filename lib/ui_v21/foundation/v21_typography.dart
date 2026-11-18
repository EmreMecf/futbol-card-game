import 'package:flutter/painting.dart';

import 'v21_colors.dart';

/// V2.1 yazı stilleri.
///
/// Referanstaki iki aile projede zaten var:
///   * Başlık / düğme / sayı: kalın, dar "oyun" yazısı → Barlow Condensed 900
///   * Etiket / ad / gövde: yuvarlak hatlı → Nunito (değişken font)
///
/// Bütün boyutlar 390 px tasarım genişliğinde; ekrana göre ölçek
/// [V21Scale] ile çarpılarak verilir.
abstract final class V21Type {
  static const String display = 'BarlowCondensed';
  static const String body = 'Nunito';

  static const List<String> _displayFallback = ['Arial Narrow', 'Roboto Condensed', 'sans-serif'];
  static const List<String> _bodyFallback = ['Roboto', 'sans-serif'];

  /// Oyun başlığı: "MAÇA BAŞLA", "MASTER 2"
  static TextStyle title(
    double size, {
    FontWeight weight = FontWeight.w900,
    Color color = V21Colors.text,
    double height = 1.0,
    double letterSpacing = 0.3,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontFamily: display,
    fontFamilyFallback: _displayFallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    shadows: shadows,
  );

  /// Gövde / etiket (Nunito, ağırlık değişken eksenle)
  static TextStyle label(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color color = V21Colors.text,
    double height = 1.15,
    double letterSpacing = 0,
    List<Shadow>? shadows,
  }) => TextStyle(
    fontFamily: body,
    fontFamilyFallback: _bodyFallback,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    shadows: shadows,
  );

  /// Koyu kontur hissi veren alt gölge (referanstaki beyaz başlıklar)
  static List<Shadow> inkShadow(double s, {Color color = V21Colors.inkDeep}) => [
    Shadow(color: color, offset: Offset(0, 2 * s)),
    Shadow(color: color.withValues(alpha: 0.6), blurRadius: 3 * s),
  ];
}
