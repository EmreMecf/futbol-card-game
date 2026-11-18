import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/v21_metrics.dart';

/// Pencere sınıfı: yerleşim kararları bu üç sınıfa göre verilir.
enum V21WindowClass {
  /// Telefon (600'den dar): tek sütun, alt menü
  compact,

  /// Dikey tablet (600-899): geniş tek sütun, alt menü
  medium,

  /// Yatay tablet ve masaüstü web (900+; ya da yatay kısa pencere): yan menü
  expanded,
}

/// 390×844 tasarım tuvalinden ekrana ölçek ve içerik genişliği.
///
/// Telefonda içerik genişliğe göre ölçeklenir. Tablet ve masaüstünde yazılar
/// büyümez; içerik genişler. Kısa ekranlarda ölçek yüksekliğe göre de kısılır.
@immutable
class V21Scale {
  /// Genel ölçek çarpanı (390 genişlikte 1.0)
  final double s;

  /// İçeriğin genişliği (geniş ekranda ortalanır)
  final double contentWidth;

  /// Pencere sınıfı
  final V21WindowClass windowClass;

  const V21Scale._(this.s, this.contentWidth, this.windowClass);

  /// Test ve önizleme için sabit ölçek
  const V21Scale.fixed(this.s, this.contentWidth) : windowClass = V21WindowClass.compact;

  factory V21Scale.of(BuildContext context) => V21Scale.forSize(MediaQuery.sizeOf(context));

  static V21WindowClass classOf(Size size) {
    if (size.width >= V21Metrics.expandedBreakpoint) return V21WindowClass.expanded;
    // Yatay kısa pencerede alt menü dikey alanı yer: yan menüye geçilir
    if (size.width >= V21Metrics.shortWideMinWidth && size.height < V21Metrics.shortWideMaxHeight) {
      return V21WindowClass.expanded;
    }
    return size.width >= V21Metrics.mediumBreakpoint ? V21WindowClass.medium : V21WindowClass.compact;
  }

  factory V21Scale.forSize(Size size) {
    final cls = classOf(size);
    // 844'ten kısa ekranlarda biraz küçült (568'de ~0.80)
    final byHeight = size.height / V21Metrics.designHeight * 1.2;
    switch (cls) {
      case V21WindowClass.compact:
        final width = math.min(size.width, V21Metrics.maxContentWidth);
        final s = math.min(width / V21Metrics.designWidth, byHeight).clamp(0.7, 1.3).toDouble();
        return V21Scale._(s, width, cls);
      case V21WindowClass.medium:
        final width = math.min(size.width, V21Metrics.mediumContentWidth);
        return V21Scale._(math.min(byHeight, 1.15).clamp(0.78, 1.15).toDouble(), width, cls);
      case V21WindowClass.expanded:
        final free = size.width - V21Metrics.sideNavWidth;
        final width = math.min(free, V21Metrics.expandedContentWidth);
        return V21Scale._(math.min(byHeight, 1.1).clamp(0.78, 1.1).toDouble(), width, cls);
    }
  }

  /// Yan menü kullanılan geniş yerleşim mi?
  bool get isExpanded => windowClass == V21WindowClass.expanded;

  double call(double designPx) => designPx * s;
}
