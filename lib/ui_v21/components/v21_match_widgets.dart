import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/avatar2d/avatar_painter.dart';
import '../../shared/widgets/avatar2d/avatar_spec.dart';
import '../animations/v21_motion.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';

/// V2.1 OYUNCU AVATARI (referans Arena "SEN" / "RAKİP": çap 44, 3 px
/// lacivert halka). Onaylı görsel ([imageUrl]) yoksa projenin 2D
/// karakter çizicisi [seed]'den üretir. [level] verilirse sağ altta rozet.
class V21PlayerAvatar extends StatelessWidget {
  final String seed;
  final String? imageUrl;
  final AvatarSpec? spec;
  final double size;

  /// Halka rengi (varsayılan lacivert; rakip/kendin vurgusu için)
  final Color ringColor;

  /// Arka zemin (mavi "SEN", kırmızı "RAKİP")
  final Color background;
  final int? level;
  final String semanticsLabel;

  const V21PlayerAvatar({
    super.key,
    required this.seed,
    required this.semanticsLabel,
    this.imageUrl,
    this.spec,
    this.size = 44,
    this.ringColor = V21Colors.ink,
    this.background = const Color(0xFF7FC0FF),
    this.level,
  });

  @override
  Widget build(BuildContext context) {
    final ring = math.max(2.0, size * 0.07);
    final url = imageUrl;
    final face = AvatarPortrait(spec: spec ?? AvatarSpec.generate(seed), size: size, headshot: true);
    final Widget portrait = url != null && (url.startsWith('http://') || url.startsWith('https://'))
        ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, _, _) => face)
        : face;
    return Semantics(
      label: level == null ? semanticsLabel : '$semanticsLabel, seviye $level',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              padding: EdgeInsets.all(ring),
              decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
              child: ClipOval(
                child: ColoredBox(
                  color: background,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox.square(dimension: size, child: portrait),
                  ),
                ),
              ),
            ),
            if (level != null)
              Positioned(
                right: -size * 0.08,
                bottom: -size * 0.06,
                child: Container(
                  constraints: BoxConstraints(minWidth: size * 0.42),
                  height: size * 0.42,
                  padding: EdgeInsets.symmetric(horizontal: size * 0.06),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: V21Colors.levelBlue,
                    borderRadius: BorderRadius.circular(size),
                    border: Border.all(color: V21Colors.ink, width: ring * 0.8),
                  ),
                  child: Text('$level', style: V21Type.title(size * 0.26)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// V2.1 ENERJİ ÇUBUĞU (referans Arena: "ENERJİ", 5 hücre 20×25, "3/5").
class V21EnergyBar extends StatelessWidget {
  final int value;
  final int max;
  final double scale;
  final bool showLabel;

  const V21EnergyBar({super.key, required this.value, required this.max, this.scale = 1, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final v = value.clamp(0, max);
    return Semantics(
      label: 'Enerji $v / $max',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Text(
              'ENERJİ',
              style: V21Type.label(11 * k, weight: FontWeight.w800, color: const Color(0xFFB9A3F0), letterSpacing: 0.4),
            ),
            SizedBox(height: 6 * k),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < max; i++) ...[
                if (i > 0) SizedBox(width: 4 * k),
                AnimatedContainer(
                  duration: V21Motion.reduced(context) ? Duration.zero : V21Motion.release,
                  width: 20 * k,
                  height: 25 * k,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6 * k),
                    border: Border.all(color: V21Colors.ink, width: 2 * k),
                    color: i < v ? null : const Color(0xFF2A1660),
                    gradient: i < v
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF9EDCFF), Color(0xFF3FA2F5)],
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
          if (showLabel) ...[
            SizedBox(height: 7 * k),
            Text('$v/$max', style: V21Type.title(19 * k, color: const Color(0xFF6FD8FF))),
          ],
        ],
      ),
    );
  }
}

/// V2.1 MAÇ SAYACI (referans Arena "11": çap 55, altın daire, 4 px
/// lacivert halka). Halkanın üstünde kalan süre yayı çizilir; son
/// [urgentAt] saniyede kırmızıya döner ve (animasyon azaltılmamışsa) nabız
/// atar.
///
/// Süre SUNUCUDAN gelir; bu bileşen yalnız gösterir (sayacı kendisi
/// azaltmaz).
class V21MatchTimer extends StatelessWidget {
  final int seconds;
  final int total;
  final double size;
  final int urgentAt;

  const V21MatchTimer({super.key, required this.seconds, required this.total, this.size = 55, this.urgentAt = 5});

  @override
  Widget build(BuildContext context) {
    final s = seconds.clamp(0, 9999);
    final urgent = s <= urgentAt;
    final ratio = total <= 0 ? 0.0 : (s / total).clamp(0.0, 1.0);
    final colors = urgent ? const [Color(0xFFFF9AA8), Color(0xFFE5294B)] : const [Color(0xFFFFE070), Color(0xFFFF9F1C)];

    Widget dial(double pulse) => Transform.scale(
      scale: 1 + pulse * 0.06,
      child: CustomPaint(
        size: Size.square(size),
        painter: _TimerRing(ratio, urgent),
        child: SizedBox.square(
          dimension: size,
          child: Padding(
            padding: EdgeInsets.all(size * 0.08),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
              ),
              child: Center(
                child: Text('$s', style: V21Type.title(size * 0.46, shadows: V21Type.inkShadow(size / 55))),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: 'Kalan süre $s saniye',
      liveRegion: urgent,
      excludeSemantics: true,
      child: urgent ? V21Pulse(builder: (context, t) => dial(t)) : dial(0),
    );
  }
}

class _TimerRing extends CustomPainter {
  final double ratio;
  final bool urgent;
  const _TimerRing(this.ratio, this.urgent);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = V21Colors.ink);
    // Referans: 4 px lacivert halka; kalan süre halkanın içinde ince açık yay
    final w = r * 0.07;
    final arc = Rect.fromCircle(center: c, radius: r - r * 0.07);
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * ratio,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w
        ..color = urgent ? const Color(0xCCFF8A9B) : const Color(0x88FFF3C4),
    );
  }

  @override
  bool shouldRepaint(covariant _TimerRing old) => old.ratio != ratio || old.urgent != urgent;
}

/// V2.1 GERİ DÜĞMESİ (referans Sandıklar: çap 43, mavi daire, ←).
class V21BackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double scale;
  const V21BackButton({super.key, required this.onPressed, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final d = 43 * scale;
    return Semantics(
      button: true,
      label: 'Geri',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: d,
          height: d,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: V21Colors.ink, width: 3 * scale),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF64B5FF), Color(0xFF1F7EEB)],
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), offset: Offset(0, 3 * scale))],
          ),
          child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: d * 0.5),
        ),
      ),
    );
  }
}
