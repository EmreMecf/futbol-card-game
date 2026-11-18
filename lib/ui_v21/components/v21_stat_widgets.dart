import 'package:flutter/material.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';

/// V2.1 İSTATİSTİK DAİRESİ (referans Kadrom: GÜÇ · KİMYA · KADRO, çap 70,
/// 4 px lacivert halka, renkli dolgu, altında etiket).
class V21StatOrb extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final double scale;

  const V21StatOrb({super.key, required this.value, required this.label, required this.color, this.scale = 1});

  /// Referans renkleri
  static const Color red = Color(0xFFFF5A6E);
  static const Color green = Color(0xFF3DD15A);
  static const Color blue = Color(0xFF5FB4FF);

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final d = 70 * k;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: V21Colors.ink, width: 4 * k),
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.4),
                colors: [Color.lerp(color, Colors.white, 0.35)!, color, Color.lerp(color, Colors.black, 0.18)!],
                stops: const [0, 0.55, 1],
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), offset: Offset(0, 3 * k))],
            ),
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.all(6 * k),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, maxLines: 1, style: V21Type.title(28 * k, shadows: V21Type.inkShadow(k))),
              ),
            ),
          ),
          SizedBox(height: 6 * k),
          Text(
            label,
            style: V21Type.label(12 * k, weight: FontWeight.w800, color: V21Colors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Küçük renkli etiket hapı ("GÜNLÜK", "HAFTALIK", "GÜNÜN TEKLİFİ")
class V21Tag extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final double scale;
  final double fontSize;

  const V21Tag({
    super.key,
    required this.text,
    required this.background,
    this.foreground = const Color(0xFF14361A),
    this.scale = 1,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 9 * scale, vertical: 3 * scale),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20 * scale)),
    child: Text(
      text,
      maxLines: 1,
      style: V21Type.label(fontSize * scale, weight: FontWeight.w900, color: foreground, letterSpacing: 0.3),
    ),
  );
}

/// V2.1 AÇMA-KAPAMA ANAHTARI (referans Ayarlar: 58×30, açıkken yeşil,
/// kapalıyken koyu mor; beyaz topuz). [onChanged] null ise pasif.
class V21Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticsLabel;
  final double scale;

  const V21Toggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticsLabel,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enabled ? () => onChanged!(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 58 * k,
            height: 32 * k,
            padding: EdgeInsets.all(3 * k),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32 * k),
              border: Border.all(color: V21Colors.ink, width: 2 * k),
              color: value ? const Color(0xFF3DD15A) : const Color(0xFF2E2260),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22 * k,
                height: 22 * k,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? Colors.white : const Color(0xFF6B5A9C),
                  border: Border.all(color: V21Colors.ink, width: 1.5 * k),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Altıgen (joker parça simgesi, referans Gelişim üst paneli)
class V21HexIcon extends StatelessWidget {
  final Color color;
  final double size;
  const V21HexIcon({super.key, required this.color, this.size = 34});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * 0.88,
    height: size,
    child: ClipPath(
      clipper: const _HexClipper(),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: V21Colors.ink),
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: ClipPath(
            clipper: const _HexClipper(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.2, -0.3),
                  colors: [Colors.white, color],
                  stops: const [0, 0.65],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width / 2, 0)
    ..lineTo(s.width, s.height * 0.25)
    ..lineTo(s.width, s.height * 0.75)
    ..lineTo(s.width / 2, s.height)
    ..lineTo(0, s.height * 0.75)
    ..lineTo(0, s.height * 0.25)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
