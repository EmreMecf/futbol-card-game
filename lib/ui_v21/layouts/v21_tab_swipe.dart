import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/game_audio.dart';
import '../web/web_kit.dart';

/// ALT MENÜ SEKMELERİ ARASINDA KAYDIRARAK GEÇİŞ
///
/// KARTLAR · KADRO · ARENA · MAĞAZA · SEZON sekmeleri ayrı rotalardır.
/// Bu sarmalayıcı ekranın boş bir yerinde sağa/sola kaydırmayı yakalar ve
/// komşu sekmeye geçer. İçerideki yatay kaydırılan listeler, sürüklenen
/// kartlar ve düğmeler hareketi önce alır; boş alanda kaydırma sekme
/// değiştirir.
///
/// Geniş web düzeninde (yan menü) kaydırma kapalıdır.
class V21TabSwipe extends StatefulWidget {
  /// Sekme rotaları, alt menüdeki sırayla
  final List<String> tabs;
  final String route;
  final Widget child;

  const V21TabSwipe({super.key, required this.tabs, required this.route, required this.child});

  /// Geçişi tetikleyen en az parmak hızı (piksel/sn) ya da mesafe (piksel)
  static const double minVelocity = 320;
  static const double minDistance = 70;

  /// Kaydırmanın yönü (0 = geçiş yok). Yön her zaman parmağın gittiği
  /// MESAFEDEN alınır: hız tahmini bazı cihazlarda (ve fareyle yapılan
  /// ani sürüklemede) ters işaretli gelebiliyor. Hız yalnız mesafeyle aynı
  /// yöndeyse kısa ama hızlı bir fiske için kullanılır.
  static double direction(double dx, double velocity) {
    if (dx.abs() >= minDistance) return dx;
    if (dx.abs() >= 16 && velocity.abs() >= minVelocity && velocity.sign == dx.sign) return dx;
    return 0;
  }

  /// Kaydırma sonucu gidilecek sekme: sola kaydırma (dx < 0) sonraki,
  /// sağa kaydırma önceki sekme. Uçta null.
  static String? targetFor(List<String> tabs, String route, double dx) {
    final i = tabs.indexOf(route);
    if (i < 0 || dx == 0) return null;
    final j = dx < 0 ? i + 1 : i - 1;
    return (j < 0 || j >= tabs.length) ? null : tabs[j];
  }

  @override
  State<V21TabSwipe> createState() => _V21TabSwipeState();
}

class _V21TabSwipeState extends State<V21TabSwipe> {
  double _dx = 0;

  void _end(DragEndDetails d) {
    final yon = V21TabSwipe.direction(_dx, d.primaryVelocity ?? 0);
    _dx = 0;
    final hedef = V21TabSwipe.targetFor(widget.tabs, widget.route, yon);
    if (hedef == null || !mounted) return;
    GameAudio.sfx(Sfx.tab);
    context.go(hedef);
  }

  @override
  Widget build(BuildContext context) {
    if (v21IsWeb(context)) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.primaryDelta ?? 0,
      onHorizontalDragEnd: _end,
      child: widget.child,
    );
  }
}

/// Sekmeler arası sayfa geçişi: ileri giderken yeni sayfa sağdan, geri
/// giderken soldan kayar (kaydırma ve alt menü dokunuşu aynı yönü verir).
class V21TabPages {
  V21TabPages._();

  static int _son = -1;

  static Page<void> page({
    required GoRouterState state,
    required List<String> tabs,
    required String route,
    required Widget child,
  }) {
    final i = tabs.indexOf(route);
    final yon = (_son < 0 || i == _son) ? 0.0 : (i > _son ? 1.0 : -1.0);
    _son = i;
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      child: V21TabSwipe(tabs: tabs, route: route, child: child),
      transitionsBuilder: (context, animation, secondary, child) {
        if (yon == 0) return FadeTransition(opacity: animation, child: child);
        final egri = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: Offset(yon, 0), end: Offset.zero).animate(egri),
          child: child,
        );
      },
    );
  }
}
