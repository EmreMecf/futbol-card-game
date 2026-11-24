import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../animations/v21_motion.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';

/// V2.1 kutlama parçaları (referans Paket Mührü, Efsane Açılış, Zafer).
///
/// Hepsi tek CustomPaint ile çizilir, RepaintBoundary içindedir; bulanıklık
/// yok. Işın dönmesi [V21Motion.cardEffects] kapalıysa durur.

/// Işın patlaması arka planı (referans Efsane Açılış / Zafer).
class V21RaysBackground extends StatefulWidget {
  /// Işınların merkezi (Alignment)
  final Alignment center;
  final Color rayColor;
  final List<Color> background;
  final int rays;

  const V21RaysBackground({
    super.key,
    this.center = const Alignment(0, -0.35),
    this.rayColor = const Color(0x33FFD27A),
    this.background = const [Color(0xFF8A3FD8), Color(0xFF3A1680), Color(0xFF16082F)],
    this.rays = 14,
  });

  @override
  State<V21RaysBackground> createState() => _V21RaysBackgroundState();
}

class _V21RaysBackgroundState extends State<V21RaysBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 40));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = V21Motion.cardEffects(context) && TickerMode.valuesOf(context).enabled;
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _RaysPainter(widget.center, widget.rayColor, widget.background, widget.rays, _c.value),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

class _RaysPainter extends CustomPainter {
  final Alignment center;
  final Color ray;
  final List<Color> bg;
  final int rays;
  final double t;
  const _RaysPainter(this.center, this.ray, this.bg, this.rays, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final c = center.alongSize(size);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: center,
          radius: 1.0,
          colors: bg,
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
    final r = size.longestSide * 1.2;
    final paint = Paint()..color = ray;
    final step = math.pi * 2 / rays;
    for (var i = 0; i < rays; i++) {
      final a = i * step + t * math.pi * 2;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - step * 0.16) * r, c.dy + math.sin(a - step * 0.16) * r)
        ..lineTo(c.dx + math.cos(a + step * 0.16) * r, c.dy + math.sin(a + step * 0.16) * r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => old.t != t || old.center != center;
}

/// Dört köşeli parıltılar (sabit konumlar; referans Paket Mührü)
class V21Sparkles extends StatelessWidget {
  final Color color;
  const V21Sparkles({super.key, this.color = const Color(0xFFE8FFF6)});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(child: CustomPaint(painter: _SparklePainter(color))),
  );
}

class _SparklePainter extends CustomPainter {
  final Color color;
  const _SparklePainter(this.color);

  // (x, y, boyut) — 390×844 tuvaline göre oranlar
  static const _spots = [
    (0.18, 0.28, 13.0),
    (0.86, 0.33, 17.0),
    (0.15, 0.57, 10.0),
    (0.88, 0.61, 12.0),
    (0.2, 0.16, 9.0),
    (0.9, 0.22, 10.0),
    (0.08, 0.63, 11.0),
    (0.94, 0.58, 15.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 390;
    final p = Paint()..color = color;
    for (final (x, y, s) in _spots) {
      final c = Offset(x * size.width, y * size.height);
      final r = s * k;
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}

/// Altın-turuncu degrade dev başlık ("EFSANE!", "ZAFER!", "DOKUN!")
class V21HeroTitle extends StatelessWidget {
  final String text;
  final double size;
  final List<Color> colors;

  const V21HeroTitle(
    this.text, {
    super.key,
    this.size = 64,
    this.colors = const [Color(0xFFFFF1A8), Color(0xFFFFC21F), Color(0xFFFF7A00)],
  });

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    label: text,
    excludeSemantics: true,
    child: Stack(
      children: [
        // Koyu kontur hissi: aynı metin aşağı kaydırılmış koyu gölge
        Transform.translate(
          offset: Offset(0, size * 0.06),
          child: Text(text, style: V21Type.title(size, color: const Color(0xFF6A2A00), letterSpacing: 0.5)),
        ),
        ShaderMask(
          shaderCallback: (r) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: const [0, 0.5, 1],
          ).createShader(r),
          blendMode: BlendMode.srcIn,
          child: Text(text, style: V21Type.title(size, letterSpacing: 0.5)),
        ),
      ],
    ),
  );
}

/// Dokunma göstergesi: beyaz halka + nokta, nabız atar (referans Paket Mührü)
class V21TapHint extends StatelessWidget {
  final double size;
  const V21TapHint({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: V21Pulse(
      enabled: V21Motion.cardEffects(context),
      builder: (context, t) => Transform.scale(
        scale: 0.94 + 0.08 * t,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x55120933),
            border: Border.all(color: Colors.white, width: size * 0.06),
          ),
          alignment: Alignment.center,
          child: Container(
            width: size * 0.45,
            height: size * 0.45,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: V21Colors.ink, width: size * 0.04),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Sayfa noktaları ("●●●●○", referans Efsane Açılış)
class V21PageDots extends StatelessWidget {
  final int count;
  final int current;
  final double scale;
  const V21PageDots({super.key, required this.count, required this.current, this.scale = 1});

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${current + 1} / $count',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) SizedBox(width: 8 * scale),
          Container(
            width: (i == current ? 16 : 12) * scale,
            height: (i == current ? 16 : 12) * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == current ? const Color(0xFFFFC832) : const Color(0x66B9A8E8),
            ),
          ),
        ],
      ],
    ),
  );
}
