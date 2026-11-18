import 'package:flutter/material.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_metrics.dart';
import '../utilities/v21_scale.dart';

/// V2.1 gece-stadyum zemini (referans üst #100B50 → alt #1B0F4B,
/// ortada mor ışık halkası).
class V21Background extends StatelessWidget {
  const V21Background({super.key});

  /// Sekme sayfası zemini (referans Koleksiyon: #391A79 → #2A1B70 → #151D63)
  static const Widget page = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF391A79), Color(0xFF2A1B70), Color(0xFF151D63)],
        stops: [0, 0.35, 1],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [V21Colors.skyTop, V21Colors.skyMid, V21Colors.floor, V21Colors.floor],
        stops: [0, 0.22, 0.7, 1],
      ),
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.62),
          radius: 0.9,
          colors: [Color(0x557A3BE0), Color(0x00000000)],
        ),
      ),
    ),
  );
}

/// Menü yan sütunda mı çiziliyor? [V21ScreenLayout] menü oluşturucusuna bildirir.
class V21NavPlacement extends InheritedWidget {
  final bool side;
  const V21NavPlacement({super.key, required this.side, required super.child});

  static bool isSide(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<V21NavPlacement>()?.side ?? false;

  @override
  bool updateShouldNotify(V21NavPlacement old) => old.side != side;
}

/// V2.1 ekran iskeleti: zemin + (üst güvenli alan) gövde + menü.
///
/// Telefon ve dikey tablette menü altta gövdenin ÜSTÜNE biner (referansta
/// etkin karo içeriğe 12 px taşar). Yatay tablet ve masaüstünde menü sol
/// sütuna geçer, içerik kalan alanda ortalanır. Zemin tam ekranı kaplar.
class V21ScreenLayout extends StatelessWidget {
  final Widget Function(BuildContext context, V21Scale scale) body;
  final Widget Function(BuildContext context, V21Scale scale)? bottomNavigation;

  /// Tam ekran zemin (varsayılan: ana sayfa gece göğü)
  final Widget background;

  const V21ScreenLayout({
    super.key,
    required this.body,
    this.bottomNavigation,
    this.background = const V21Background(),
  });

  @override
  Widget build(BuildContext context) {
    final scale = V21Scale.of(context);
    final navBuilder = bottomNavigation;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final content = SafeArea(
      bottom: false,
      child: Center(
        child: SizedBox(width: scale.contentWidth, child: body(context, scale)),
      ),
    );
    if (navBuilder != null && scale.isExpanded) {
      return Scaffold(
        backgroundColor: V21Colors.inkDeep,
        body: Stack(
          children: [
            Positioned.fill(child: background),
            Positioned.fill(
              child: Row(
                children: [
                  SizedBox(
                    width: V21Metrics.sideNavWidth,
                    child: V21NavPlacement(
                      side: true,
                      child: Builder(builder: (context) => navBuilder(context, scale)),
                    ),
                  ),
                  Expanded(
                    child: Padding(padding: EdgeInsets.only(bottom: bottomInset), child: content),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final navSpace = navBuilder == null ? bottomInset : V21Metrics.navHeight * scale.s + bottomInset;
    return Scaffold(
      backgroundColor: V21Colors.inkDeep,
      body: Stack(
        children: [
          Positioned.fill(child: background),
          Positioned.fill(bottom: navSpace, child: content),
          if (navBuilder != null) Positioned(left: 0, right: 0, bottom: 0, child: navBuilder(context, scale)),
        ],
      ),
    );
  }
}
