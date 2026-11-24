import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/feedback/game_feedback.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';

/// EKONOMİ V2 (FAZ 6) — kozmetiklerin ÇİZİMİ.
///
/// Hepsi yalnız görsel: kart gücü, kimya, maç kuralı ve kart/yüz
/// kimliği DEĞİŞMEZ (K1). Kozmetik kimlikleri (slug) sunucudaki
/// `item_definitions` ile aynı; bilinmeyen slug hiçbir şey çizmez.

// ---------------------------------------------------------------------
// FORMA (profil karakteri): yalnız forma renkleri, yüz aynı
// ---------------------------------------------------------------------
/// (forma, şerit) ya da null
(Color, Color)? cosmeticKitColors(String? slug) => switch (slug) {
      'kit_season1' => (const Color(0xFF0E7A64), V21Colors.goldTop),
      _ => null,
    };

// ---------------------------------------------------------------------
// PROFİL ÇERÇEVESİ
// ---------------------------------------------------------------------
/// Avatarın çevresine sezon halkası çizer. [slug] null ise yalnız
/// [fallbackBorder] ile düz çerçeve (eski görünüm).
class CosmeticFrame extends StatelessWidget {
  final String? slug;
  final double size;
  final Widget child;
  final Color fallbackBorder;

  const CosmeticFrame({
    super.key,
    required this.slug,
    required this.size,
    required this.child,
    this.fallbackBorder = V21Colors.pillBorder,
  });

  @override
  Widget build(BuildContext context) {
    if (slug != 'frame_season1') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0B1424),
          border: Border.all(color: fallbackBorder, width: 2),
        ),
        child: ClipOval(child: child),
      );
    }
    final kalinlik = math.max(3.0, size * 0.05);
    return SizedBox(
      width: size + kalinlik * 2,
      height: size + kalinlik * 2 + 8,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Container(
          width: size + kalinlik * 2,
          height: size + kalinlik * 2,
          padding: EdgeInsets.all(kalinlik),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(colors: [
              Color(0xFFF8C665),
              Color(0xFF21DFAA),
              Color(0xFFFFF1C4),
              Color(0xFF21DFAA),
              Color(0xFFF8C665),
            ]),
            boxShadow: [BoxShadow(color: V21Colors.goldTop.withValues(alpha: 0.35), blurRadius: 14)],
          ),
          child: Container(
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0B1424)),
            child: ClipOval(child: child),
          ),
        ),
        // Sezon plakası
        Positioned(
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1205),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: V21Colors.goldTop, width: 1.2),
            ),
            child: Text('S1', style: V21Type.title(11, color: V21Colors.goldTop, height: 1)),
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------
// KAPTAN BANDI (karakter kozmetiği)
// ---------------------------------------------------------------------
class CaptainBandBadge extends StatelessWidget {
  final double size;
  const CaptainBandBadge({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Kaptan bandı',
        child: Container(
          width: size * 1.3,
          height: size * 0.8,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFD43B),
            borderRadius: BorderRadius.circular(size * 0.22),
            border: Border.all(color: const Color(0xFF3A2A00), width: 1.2),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Text('C', style: V21Type.title(size * 0.62, color: const Color(0xFF241A00), height: 1)),
        ),
      );
}

// ---------------------------------------------------------------------
// SEZON ROZETİ
// ---------------------------------------------------------------------
class SeasonBadgeChip extends StatelessWidget {
  final String slug;
  const SeasonBadgeChip(this.slug, {super.key});

  @override
  Widget build(BuildContext context) {
    final (renk, ad) = switch (slug) {
      'badge_s1_gold' => (V21Colors.goldTop, 'SEZON 1 · ALTIN'),
      'badge_s1_bronze' => (const Color(0xFFD8945A), 'SEZON 1 · BRONZ'),
      _ => (V21Colors.textMuted, 'SEZON ROZETİ'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withValues(alpha: 0.8)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.military_tech_rounded, size: 14, color: renk),
        const SizedBox(width: 4),
        Text(ad, style: V21Type.label(10, weight: FontWeight.w900, color: renk, letterSpacing: 0.8)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------
// KART GÖRÜNÜMÜ: "Gece Işığı" zemini (nadirlik halesi ve çerçevesi korunur)
// ---------------------------------------------------------------------
/// Kartın zeminini çizer; true dönerse varsayılan zemin ÇİZİLMEZ.
/// Nadirlik halesi, deseni ve çerçevesi bunun üstüne aynen gelir.
bool paintCardSkinBase(Canvas c, Size s, double k, String? slug) {
  if (slug != 'card_skin_night') return false;
  final rect = Offset.zero & s;
  c.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1030), Color(0xFF161A4A), Color(0xFF0B0F24)],
          stops: [0, 0.6, 1],
        ).createShader(rect));
  // Hilal (sağ üst)
  final ay = Offset(s.width * 0.8, s.height * 0.14);
  final r = 9 * k;
  c.saveLayer(rect, Paint());
  c.drawCircle(ay, r, Paint()..color = const Color(0x55FFF3C4));
  c.drawCircle(ay + Offset(r * 0.45, -r * 0.2), r, Paint()..blendMode = BlendMode.clear);
  c.restore();
  // Yıldızlar (sabit konumlar: her kartta aynı desen)
  final yildiz = Paint()..color = const Color(0x88FFFFFF);
  for (final (x, y, b) in _yildizlar) {
    c.drawCircle(Offset(s.width * x, s.height * y), b * k, yildiz);
  }
  // Alt ufuk ışığı
  final alt = Rect.fromLTWH(0, s.height * 0.72, s.width, s.height * 0.28);
  c.drawRect(
      alt,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0x005A7CFF), const Color(0xFF5A7CFF).withValues(alpha: 0.16)],
        ).createShader(alt));
  return true;
}

const _yildizlar = <(double, double, double)>[
  (0.12, 0.08, 0.9), (0.27, 0.19, 0.6), (0.44, 0.06, 0.7), (0.62, 0.22, 0.5), (0.92, 0.31, 0.7),
  (0.08, 0.36, 0.5), (0.35, 0.33, 0.4), (0.71, 0.05, 0.6), (0.18, 0.55, 0.5), (0.88, 0.58, 0.6),
  (0.55, 0.47, 0.4), (0.05, 0.74, 0.6), (0.95, 0.80, 0.5),
];

// ---------------------------------------------------------------------
// ARENA GÖRÜNÜMÜ: "Yağmurlu Gece" (yalnız kendi ekranında)
// ---------------------------------------------------------------------
/// Stadyumun üstüne gece tonu + yağmur. Animasyonlar kapalıysa
/// (Ayarlar) yağmur durağan çizilir.
class RainyNightOverlay extends StatefulWidget {
  const RainyNightOverlay({super.key});

  @override
  State<RainyNightOverlay> createState() => _RainyNightOverlayState();
}

class _RainyNightOverlayState extends State<RainyNightOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ak;

  @override
  void initState() {
    super.initState();
    _ak = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    if (GameFeedback.cardAnimationsEnabled) _ak.repeat();
  }

  @override
  void dispose() {
    _ak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Stack(fit: StackFit.expand, children: [
          // Gece tonu + sis (durağan katman)
          const RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99040A1E), Color(0x33061430), Color(0x6610213F)],
                ),
              ),
            ),
          ),
          // Yağmur (her karede yalnız ince çizgiler)
          RepaintBoundary(child: CustomPaint(painter: _Yagmur(_ak))),
        ]),
      );
}

class _Yagmur extends CustomPainter {
  final Animation<double> t;
  _Yagmur(this.t) : super(repaint: t);

  static final _damlalar = () {
    final r = math.Random(7);
    return List.generate(70, (_) => (r.nextDouble(), r.nextDouble(), 0.6 + r.nextDouble() * 0.6));
  }();

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0x55BFD9FF)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    for (final (x, y, hiz) in _damlalar) {
      final yy = ((y + t.value * hiz) % 1.0) * (s.height + 20) - 10;
      final xx = x * s.width - yy * 0.18;
      final boy = 9 + hiz * 6;
      c.drawLine(Offset(xx, yy), Offset(xx - boy * 0.18, yy + boy), p);
    }
  }

  @override
  bool shouldRepaint(_Yagmur old) => false;
}

// ---------------------------------------------------------------------
// ZAFER ANİMASYONU: "Havai Fişek"
// ---------------------------------------------------------------------
class FireworksOverlay extends StatefulWidget {
  final bool active;
  const FireworksOverlay({super.key, required this.active});

  @override
  State<FireworksOverlay> createState() => _FireworksOverlayState();
}

class _FireworksOverlayState extends State<FireworksOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _ak;

  @override
  void initState() {
    super.initState();
    _ak = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
    if (widget.active && GameFeedback.cardAnimationsEnabled) _ak.forward();
  }

  @override
  void dispose() {
    _ak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || !GameFeedback.cardAnimationsEnabled) return const SizedBox.shrink();
    return IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: _Fisek(_ak), size: Size.infinite)));
  }
}

class _Fisek extends CustomPainter {
  final Animation<double> t;
  _Fisek(this.t) : super(repaint: t);

  /// (x, y, başlangıç 0..1, renk)
  static const _patlamalar = <(double, double, double, Color)>[
    (0.25, 0.22, 0.00, V21Colors.goldTop),
    (0.72, 0.16, 0.12, V21Colors.navActiveBorder),
    (0.50, 0.30, 0.26, V21Colors.goldTop),
    (0.18, 0.40, 0.40, Color(0xFFFF6B8B)),
    (0.80, 0.36, 0.52, V21Colors.goldTop),
  ];
  static const _parca = 40;
  static const _omur = 0.42;

  /// Parçacık başına sabit hız çarpanı (halka değil, dağınık patlama)
  static final _hizlar = () {
    final r = math.Random(11);
    return List.generate(_parca, (_) => 0.55 + r.nextDouble() * 0.45);
  }();

  @override
  void paint(Canvas c, Size s) {
    for (final (x, y, bas, renk) in _patlamalar) {
      final yerel = (t.value - bas) / _omur;
      if (yerel <= 0 || yerel >= 1) continue;
      final merkez = Offset(s.width * x, s.height * y);
      final tam = math.min(s.width, s.height) * 0.24;
      final ilerleme = Curves.easeOutCubic.transform(yerel);
      final dusme = 46 * yerel * yerel;
      final alfa = (1 - yerel).clamp(0.0, 1.0);
      final iz = Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final nokta = Paint()..color = Color.lerp(renk, Colors.white, 0.35)!.withValues(alpha: alfa);
      // Parçacık başına bulanıklık YOK (her karede 200 bulanık daire
      // web'de kare süresini uzatır): yarı saydam düz hale yeterli
      final hale = Paint()..color = renk.withValues(alpha: alfa * 0.3);
      for (var i = 0; i < _parca; i++) {
        final a = i / _parca * math.pi * 2 + (i.isEven ? 0.04 : -0.04);
        final yon = Offset(math.cos(a), math.sin(a));
        final r = tam * _hizlar[i] * ilerleme;
        final uc = merkez + yon * r + Offset(0, dusme);
        final kuyruk = merkez + yon * (r * 0.62) + Offset(0, dusme * 0.6);
        iz.shader = LinearGradient(colors: [renk.withValues(alpha: 0), renk.withValues(alpha: alfa)])
            .createShader(Rect.fromPoints(kuyruk, uc));
        c.drawLine(kuyruk, uc, iz);
        c.drawCircle(uc, 4.2 * (1 - yerel * 0.6), hale);
        c.drawCircle(uc, 1.9 * (1 - yerel * 0.5), nokta);
      }
      // Merkez parlaması
      if (yerel < 0.22) {
        final g = 1 - yerel / 0.22;
        c.drawCircle(
            merkez,
            16 * g,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.75 * g)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
    }
  }

  @override
  bool shouldRepaint(_Fisek old) => false;
}
