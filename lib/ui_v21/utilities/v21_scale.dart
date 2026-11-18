import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/v21_metrics.dart';

/// 390×844 tasarım tuvalinden ekrana ölçek.
///
/// Telefon içeriği genişliğe göre ölçeklenir ([V21Metrics.maxContentWidth]
/// ile sınırlı). Kısa ekranlarda (320×568) dikey sığma için ölçek
/// yüksekliğe göre de kısılır; böylece hiçbir boyutta taşma olmaz.
@immutable
class V21Scale {
  /// Genel ölçek çarpanı (390 genişlikte 1.0)
  final double s;

  /// Telefon içeriğinin genişliği (tablette ortalanır)
  final double contentWidth;

  const V21Scale._(this.s, this.contentWidth);

  /// Test ve önizleme için sabit ölçek
  const V21Scale.fixed(this.s, this.contentWidth);

  factory V21Scale.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return V21Scale.forSize(size);
  }

  factory V21Scale.forSize(Size size) {
    final width = math.min(size.width, V21Metrics.maxContentWidth);
    final byWidth = width / V21Metrics.designWidth;
    // 844'ten kısa ekranlarda biraz küçült (568'de ~0.80)
    final byHeight = size.height / V21Metrics.designHeight * 1.2;
    final s = math.min(byWidth, byHeight).clamp(0.78, 1.3).toDouble();
    return V21Scale._(s, width);
  }

  double call(double designPx) => designPx * s;
}
