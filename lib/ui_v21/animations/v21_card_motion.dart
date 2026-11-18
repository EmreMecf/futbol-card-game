import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'v21_motion.dart';

/// V2.1 kart ve ekran hareketleri.
///
/// KURALLAR
///   * "Animasyonları azalt" açıksa ([V21Motion.reduced]) hareket yok:
///     son duruma doğrudan geçilir.
///   * [V21Motion.lowPower] açıksa (eski cihaz) sürekli çalışan efektler
///     (nadirlik parlaması) çizilmez; tek seferlik geçişler kalır.
///   * Bulanıklık (BackdropFilter, MaskFilter.blur) KULLANILMAZ; dönüşler
///     Transform ile, parlama tek CustomPaint ile yapılır ve
///     RepaintBoundary içinde kalır.

/// KART YÜKSELME: seçili ya da üstüne gelinen kart 8 px kalkar, %3 büyür,
/// gölgesi uzar (referans Arena elindeki seçili kart).
class V21CardLift extends StatefulWidget {
  final Widget child;

  /// Dışarıdan zorla yükseltilmiş (seçili kart)
  final bool lifted;

  /// İşaretçi üstüne gelince de yükselsin (iPad fare/trackpad)
  final bool liftOnHover;
  final double distance;

  const V21CardLift({super.key, required this.child, this.lifted = false, this.liftOnHover = true, this.distance = 8});

  @override
  State<V21CardLift> createState() => _V21CardLiftState();
}

class _V21CardLiftState extends State<V21CardLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final up = widget.lifted || (_hover && widget.liftOnHover);
    final reduced = V21Motion.reduced(context);
    final content = AnimatedContainer(
      duration: reduced ? Duration.zero : V21Motion.release,
      curve: V21Motion.standard,
      transform: Matrix4.translationValues(0, up ? -widget.distance : 0, 0)
        ..scaleByDouble(up ? 1.03 : 1, up ? 1.03 : 1, 1, 1),
      transformAlignment: Alignment.bottomCenter,
      child: widget.child,
    );
    if (!widget.liftOnHover) return content;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: content,
    );
  }
}

/// KART ÇEVİRME: [showFront] değişince kart Y ekseninde döner (arka yüz →
/// ön yüz). Paket açılışı ve maçta rakip kartının açılması için.
///
/// Animasyon azaltılmışsa çevirme yerine anında değişir.
class V21CardFlip extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool showFront;
  final Duration duration;
  final VoidCallback? onFlipped;

  const V21CardFlip({
    super.key,
    required this.front,
    required this.back,
    required this.showFront,
    this.duration = const Duration(milliseconds: 520),
    this.onFlipped,
  });

  @override
  State<V21CardFlip> createState() => _V21CardFlipState();
}

class _V21CardFlipState extends State<V21CardFlip> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.showFront ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant V21CardFlip old) {
    super.didUpdateWidget(old);
    if (old.showFront == widget.showFront) return;
    if (V21Motion.reduced(context)) {
      _c.value = widget.showFront ? 1 : 0;
      widget.onFlipped?.call();
      return;
    }
    final run = widget.showFront ? _c.forward() : _c.reverse();
    run.whenComplete(() {
      if (mounted) widget.onFlipped?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_c.value);
        final angle = t * math.pi;
        final frontVisible = angle > math.pi / 2;
        final m = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(frontVisible ? angle - math.pi : angle);
        return Transform(alignment: Alignment.center, transform: m, child: frontVisible ? widget.front : widget.back);
      },
    );
  }
}

/// NADİRLİK PARLAMASI: kartın kenarında dönen ışık yayı (Efsane/Elmas).
///
/// Tek CustomPaint + RepaintBoundary; döngü süresi 3 sn. Animasyon
/// azaltılmışsa ya da [V21Motion.lowPower] açıksa sabit, hafif bir hâle
/// çizilir (kare başına çizim yok).
class V21RarityGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double radius;
  final bool enabled;

  const V21RarityGlow({super.key, required this.child, required this.color, this.radius = 16, this.enabled = true});

  @override
  State<V21RarityGlow> createState() => _V21RarityGlowState();
}

class _V21RarityGlowState extends State<V21RarityGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  bool get _animate => widget.enabled && V21Motion.cardEffects(context) && TickerMode.valuesOf(context).enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant V21RarityGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_animate && !_c.isAnimating) {
      _c.repeat();
    } else if (!_animate && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: _animate
                  ? AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) =>
                          CustomPaint(painter: _GlowPainter(widget.color, widget.radius, _c.value, moving: true)),
                    )
                  : CustomPaint(painter: _GlowPainter(widget.color, widget.radius, 0, moving: false)),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double t;
  final bool moving;
  const _GlowPainter(this.color, this.radius, this.t, {required this.moving});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    if (!moving) {
      paint.color = color.withValues(alpha: 0.55);
      canvas.drawRRect(rr, paint);
      return;
    }
    paint.shader = SweepGradient(
      transform: GradientRotation(t * math.pi * 2),
      colors: [color.withValues(alpha: 0), Colors.white, color, color.withValues(alpha: 0), color.withValues(alpha: 0)],
      stops: const [0, 0.06, 0.14, 0.24, 1],
    ).createShader(rect);
    canvas.drawRRect(rr, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) => old.t != t || old.color != color || old.moving != moving;
}

/// EKRAN GEÇİŞLERİ: GoRouter için V2.1 sayfa geçişi (220 ms solma + 16 px
/// yukarı kayma). Animasyon azaltılmışsa geçiş yok.
///
/// Kullanım: `GoRoute(pageBuilder: (c, s) => V21Transitions.page(s, const Ekran()))`
abstract final class V21Transitions {
  static const Duration duration = Duration(milliseconds: 220);

  static CustomTransitionPage<T> page<T>(GoRouterState state, Widget child) => CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: fadeUp,
  );

  /// Diğer rota türlerinde de kullanılabilen geçiş
  static Widget fadeUp(BuildContext context, Animation<double> a, Animation<double> secondary, Widget child) {
    if (V21Motion.reduced(context)) return child;
    final t = CurvedAnimation(parent: a, curve: V21Motion.standard);
    return FadeTransition(
      opacity: t,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(t),
        child: child,
      ),
    );
  }
}

/// Material rotaları (GoRouter'ın `builder` rotaları dahil) için V2.1
/// geçişi. Uygulama temasında `pageTransitionsTheme` olarak verilir; böylece
/// rota dosyasına dokunmadan bütün ekranlarda aynı geçiş kullanılır.
class V21PageTransitionsBuilder extends PageTransitionsBuilder {
  const V21PageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => V21Transitions.fadeUp(context, animation, secondaryAnimation, child);

  /// Bütün platformlarda V2.1 geçişi
  static PageTransitionsTheme get theme =>
      PageTransitionsTheme(builders: {for (final p in TargetPlatform.values) p: const V21PageTransitionsBuilder()});
}
