import 'package:flutter/material.dart';

/// Ekran genisligi sinifi.
///
/// Oyun hem telefonda hem tarayicida calisacak. Ayni ViewModel'i
/// paylasan IKI YERLESIM var; hangisinin cizilecegine bu enum karar
/// veriyor.
enum ScreenSize {
  /// Telefon. Tek sutun, alt sekme cubugu, bas parmak bolgesi.
  mobile,

  /// Tablet ve kucuk pencere. Genis tek sutun, yan panel yok.
  tablet,

  /// Masaustu tarayici. Sol kenar cubugu, cok sutunlu yerlesim.
  desktop;

  bool get isMobile => this == ScreenSize.mobile;
  bool get isTablet => this == ScreenSize.tablet;
  bool get isDesktop => this == ScreenSize.desktop;

  /// Kenar cubugu mu, alt sekme cubugu mu?
  bool get usesSidebar => this == ScreenSize.desktop;

  /// Cok sutunlu maç yerlesimi kullanilsin mi?
  bool get usesWideLayout => this != ScreenSize.mobile;
}

/// Kirilma noktalari ve ekrana gore olcu yardimcilari.
class AppBreakpoints {
  const AppBreakpoints._();

  /// Bu genisligin altinda telefon yerlesimi cizilir.
  static const double tablet = 600;

  /// Bu genisligin ustunde kenar cubuklu masaustu yerlesimi cizilir.
  static const double desktop = 1024;

  /// Genis ekranda icerigin en fazla ne kadar yayilacagi.
  /// Sinirsiz birakilirsa 27 inc bir monitorde satirlar okunamayacak
  /// kadar uzar ve arayuz bos gorunur.
  static const double maxContentWidth = 1320;

  /// Masaustu kenar cubugu genisligi
  static const double sidebarWidth = 248;

  static ScreenSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static ScreenSize fromWidth(double width) {
    if (width >= desktop) return ScreenSize.desktop;
    if (width >= tablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  /// Ekran boyutuna gore sayfa kenar boslugu
  static double pagePadding(ScreenSize size) => switch (size) {
        ScreenSize.mobile => 20,
        ScreenSize.tablet => 28,
        ScreenSize.desktop => 40,
      };

  /// Izgara sutun sayisi (karo listeleri icin)
  static int gridColumns(ScreenSize size) => switch (size) {
        ScreenSize.mobile => 2,
        ScreenSize.tablet => 3,
        ScreenSize.desktop => 4,
      };
}

/// Ekran boyutuna gore farkli widget cizen yardimci.
///
/// [mobile] zorunlu; digerleri verilmezse bir alt boyutunkini kullanir.
/// Boylece "tablet henuz tasarlanmadi" durumunda ekran bos kalmaz,
/// telefon yerlesimi genis halde cizilir.
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenSize size) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder kullaniliyor cunku bu widget bir yan panelin
    // icinde de olabilir; o zaman onemli olan PENCERE genisligi degil,
    // widget'a ayrilan alan.
    return LayoutBuilder(
      builder: (context, kisitlar) {
        final boyut = AppBreakpoints.fromWidth(kisitlar.maxWidth);
        return builder(context, boyut);
      },
    );
  }
}

/// Genis ekranda icerigi ortalayip genisligini sinirlar.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
