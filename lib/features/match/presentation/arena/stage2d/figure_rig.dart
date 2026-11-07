import 'dart:math' as math;
import 'dart:ui' show Offset, lerpDouble;

import 'package:flutter/animation.dart' show Curves;

// =====================================================================
// 2D FİGÜR İSKELETİ VE KLİPLER (yeni görsel yön, bölüm 5 ve 8)
// =====================================================================
// Arena figürü 11 parçalı basit bir 2D iskelet: kalça (kök), gövde,
// kafa, iki kol (üst + alt), iki bacak (uyluk + baldır). Her klip birkaç
// ANAHTAR POZ'dan oluşur; aradaki kareler yumuşak geçişle hesaplanır.
//
// Klipler KODDA VERİ olarak durur: dosya, model, iskelet bağlama veya
// ücretli üretim gerekmez. Klip adları 025'teki animation_clip_requirements
// ve [clipsFor] ile aynıdır.
//
// AÇI KURALI: 0 = aşağı sarkık. Pozitif = figürün baktığı yöne (ileri).
//   * Gövde: pozitif = öne eğik
//   * Baldır (shin*): dizden GÖRELİ; negatif = diz geriye bükük
//   * Ön kol (fore*): dirsekten GÖRELİ; pozitif = dirsek öne bükük
//   * ~2.9 = kol yukarı kalkık
// Birimler: kalça (0,0), ayak yerde y=30, kafa tepesi ~y=-60.
// "F" = izleyiciye yakın uzuv, "B" = uzak uzuv.

class Pose {
  final double x, y;
  final double torso, head;
  final double armF, foreF, armB, foreB;
  final double legF, shinF, legB, shinB;

  /// Top: figüre göre konum (kalça koordinatında), elde olma ağırlığı
  /// (1 = ön elde) ve görünürlük
  final double ballX, ballY, ballHand, ballAlpha;

  const Pose({
    this.x = 0,
    this.y = 0,
    this.torso = 0.05,
    this.head = 0,
    this.armF = 0.25,
    this.foreF = 0.35,
    this.armB = -0.2,
    this.foreB = 0.3,
    this.legF = 0.08,
    this.shinF = -0.05,
    this.legB = -0.08,
    this.shinB = -0.05,
    this.ballX = 14,
    this.ballY = 27,
    this.ballHand = 0,
    this.ballAlpha = 0,
  });

  List<double> get _v => [x, y, torso, head, armF, foreF, armB, foreB, legF, shinF, legB, shinB,
      ballX, ballY, ballHand, ballAlpha];

  static Pose _from(List<double> v) => Pose(
      x: v[0], y: v[1], torso: v[2], head: v[3], armF: v[4], foreF: v[5], armB: v[6], foreB: v[7],
      legF: v[8], shinF: v[9], legB: v[10], shinB: v[11],
      ballX: v[12], ballY: v[13], ballHand: v[14], ballAlpha: v[15]);

  static Pose lerp(Pose a, Pose b, double t) {
    final va = a._v, vb = b._v;
    return _from([for (var i = 0; i < va.length; i++) lerpDouble(va[i], vb[i], t)!]);
  }

  Pose copyWith({double? ballX, double? ballY, double? ballHand, double? ballAlpha, double? y}) =>
      _from([x, y ?? this.y, torso, head, armF, foreF, armB, foreB, legF, shinF, legB, shinB,
          ballX ?? this.ballX, ballY ?? this.ballY, ballHand ?? this.ballHand, ballAlpha ?? this.ballAlpha]);
}

/// Bir klibin anahtar pozu
class Keyframe {
  final double t;
  final Pose pose;
  const Keyframe(this.t, this.pose);
}

class FigureClip {
  final String name;
  final int durationMs;

  /// Klip boyunca figürün ileri kat ettiği yol (birim)
  final double travel;
  final List<Keyframe> keys;

  const FigureClip(this.name, this.durationMs, this.keys, {this.travel = 0});

  Pose poseAt(double t) {
    t = t.clamp(0.0, 1.0);
    for (var i = 0; i < keys.length - 1; i++) {
      final a = keys[i], b = keys[i + 1];
      if (t <= b.t) {
        final yerel = (t - a.t) / math.max(1e-6, b.t - a.t);
        return Pose.lerp(a.pose, b.pose, Curves.easeInOut.transform(yerel));
      }
    }
    return keys.last.pose;
  }
}

// ---------------------------------------------------------------------
// TEMEL POZLAR
// ---------------------------------------------------------------------
const _dur = Pose();

const _kosuA = Pose(y: 2, torso: 0.28, legF: 0.65, shinF: -0.25, legB: -0.55, shinB: -1.1,
    armF: -0.6, foreF: 1.3, armB: 0.7, foreB: 1.1);
const _kosuB = Pose(y: -2, torso: 0.28, legF: -0.1, shinF: -0.4, legB: 0.3, shinB: -1.5,
    armF: 0, foreF: 1.2, armB: 0, foreB: 1.2);
const _kosuC = Pose(y: 2, torso: 0.28, legF: -0.55, shinF: -1.1, legB: 0.65, shinB: -0.25,
    armF: 0.7, foreF: 1.1, armB: -0.6, foreB: 1.3);
const _kosuD = Pose(y: -2, torso: 0.28, legF: 0.3, shinF: -1.5, legB: -0.1, shinB: -0.4,
    armF: 0, foreF: 1.2, armB: 0, foreB: 1.2);

const _savunmaDurusu = Pose(y: 5, torso: 0.4, head: -0.35, legF: 0.55, shinF: -0.9, legB: -0.45,
    shinB: -0.6, armF: 0.5, foreF: 0.5, armB: -0.5, foreB: 0.5);

const _kaleciHazir = Pose(y: 4, torso: 0.3, head: -0.25, legF: 0.45, shinF: -0.8, legB: -0.35,
    shinB: -0.7, armF: 0.9, foreF: 0.6, armB: 0.7, foreB: 0.6);

const _plonjonHavada = Pose(y: -10, torso: 1.4, head: -0.3, armF: 1.75, foreF: 0, armB: 1.6, foreB: 0,
    legF: -0.5, shinF: -0.2, legB: -0.7, shinB: -0.4);
const _plonjonYerde = Pose(y: 14, torso: 1.5, head: -0.3, armF: 1.7, foreF: 0.1, armB: 1.6, foreB: 0.1,
    legF: -0.45, shinF: -0.2, legB: -0.6, shinB: -0.5);

Pose _topla(Pose p, double x, double y, [double alfa = 1]) =>
    p.copyWith(ballX: x, ballY: y, ballAlpha: alfa);

// ---------------------------------------------------------------------
// KLİP KÜTÜPHANESİ (17 klip)
// ---------------------------------------------------------------------
final Map<String, FigureClip> kFigureClips = {
  for (final c in <FigureClip>[
    const FigureClip('idle', 800, [
      Keyframe(0, _dur),
      Keyframe(0.5, Pose(y: 0.8, torso: 0.08, armF: 0.3, armB: -0.15)),
      Keyframe(1, _dur),
    ]),
    const FigureClip('walk', 900, travel: 18, [
      Keyframe(0, Pose(torso: 0.08, legF: 0.35, shinF: -0.15, legB: -0.3, shinB: -0.5, armF: -0.3, armB: 0.3)),
      Keyframe(0.5, Pose(y: -1, torso: 0.08, legF: -0.3, shinF: -0.5, legB: 0.35, shinB: -0.15, armF: 0.3, armB: -0.3)),
      Keyframe(1, Pose(torso: 0.08, legF: 0.35, shinF: -0.15, legB: -0.3, shinB: -0.5, armF: -0.3, armB: 0.3)),
    ]),
    const FigureClip('run', 640, travel: 46, [
      Keyframe(0, _kosuA), Keyframe(0.25, _kosuB), Keyframe(0.5, _kosuC), Keyframe(0.75, _kosuD),
      Keyframe(1, _kosuA),
    ]),
    FigureClip('dribble', 760, travel: 40, [
      Keyframe(0, _topla(_kosuA, 19, 27)),
      Keyframe(0.25, _topla(_kosuB, 24, 26)),
      Keyframe(0.5, _topla(_kosuC, 20, 27)),
      Keyframe(0.75, _topla(_kosuD, 24, 26)),
      Keyframe(1, _topla(_kosuA, 19, 27)),
    ]),
    FigureClip('shoot', 900, travel: 6, [
      Keyframe(0, _topla(const Pose(torso: 0.2, legF: 0.3, shinF: -0.4, legB: -0.3, shinB: -0.6), 18, 27)),
      Keyframe(0.3, _topla(const Pose(torso: -0.05, legB: 0.1, shinB: -0.1, legF: -0.9, shinF: -1.6,
          armF: -0.7, foreF: 0.5, armB: 1.4, foreB: 0.3), 16, 27)),
      Keyframe(0.45, _topla(const Pose(torso: -0.22, legF: 1.0, shinF: -0.15, legB: -0.05, shinB: -0.1,
          armF: -1.0, foreF: 0.4, armB: 1.2, foreB: 0.3), 22, 25)),
      Keyframe(0.65, _topla(const Pose(y: -2, torso: -0.3, legF: 1.6, shinF: 0, legB: -0.05, shinB: -0.1,
          armF: -1.1, foreF: 0.4, armB: 1.0, foreB: 0.3), 120, -24)),
      Keyframe(1, _topla(const Pose(torso: 0.1, legF: 0.3, shinF: -0.2, legB: -0.05), 230, -44, 0)),
    ]),
    FigureClip('pass', 750, travel: 4, [
      Keyframe(0, _topla(_dur, 16, 27)),
      Keyframe(0.35, _topla(const Pose(torso: 0.05, legF: -0.6, shinF: -1.2, armF: -0.4, armB: 0.6), 16, 27)),
      Keyframe(0.55, _topla(const Pose(torso: -0.05, legF: 0.8, shinF: -0.1, armF: -0.5, armB: 0.7), 22, 26)),
      Keyframe(0.8, _topla(const Pose(torso: 0.05, legF: 0.4, shinF: -0.1), 110, 24)),
      Keyframe(1, _topla(const Pose(legF: 0.2), 150, 24, 0)),
    ]),
    const FigureClip('celebrate', 1000, travel: 4, [
      Keyframe(0, _dur),
      Keyframe(0.3, Pose(y: 4, torso: 0.3, legF: 0.5, shinF: -1.0, legB: 0.3, shinB: -1.0, armF: -0.3, armB: -0.3)),
      Keyframe(0.55, Pose(y: -16, torso: -0.1, head: -0.2, legF: 0.2, shinF: -0.3, legB: -0.4, shinB: -0.9,
          armF: 2.9, foreF: 0.2, armB: 2.75, foreB: 0.2)),
      Keyframe(0.8, Pose(y: 2, legF: 0.3, shinF: -0.6, legB: -0.2, shinB: -0.6, armF: 2.6, foreF: 0.5,
          armB: 2.5, foreB: 0.5)),
      Keyframe(1, Pose(armF: 2.8, foreF: 1.6, armB: 0.3)),
    ]),
    const FigureClip('win', 900, [
      Keyframe(0, _dur),
      Keyframe(0.35, Pose(y: -4, armF: 2.9, foreF: 0.1, armB: 0.4, legF: 0.3, shinF: -0.6)),
      Keyframe(0.7, Pose(armF: 2.7, foreF: 0.9, armB: 0.3)),
      Keyframe(1, Pose(y: -2, armF: 2.9, foreF: 0.1, armB: 0.3)),
    ]),
    const FigureClip('lose', 900, [
      Keyframe(0, _dur),
      Keyframe(0.4, Pose(y: 2, torso: 0.55, head: 0.35, armF: 0.05, foreF: 0.1, armB: -0.05, foreB: 0.1,
          legF: 0.15, shinF: -0.25, legB: -0.1, shinB: -0.3)),
      Keyframe(1, Pose(y: 1, torso: 0.2, head: 0.3, armF: 2.4, foreF: 2.2, armB: 2.3, foreB: 2.2)),
    ]),
    const FigureClip('tackle', 720, travel: 26, [
      Keyframe(0, _kosuA),
      Keyframe(0.3, Pose(y: 8, torso: -0.6, legF: 1.4, shinF: -0.1, legB: 0.2, shinB: -1.6,
          armF: -0.9, foreF: 0.4, armB: -1.3, foreB: 0.5)),
      Keyframe(0.7, Pose(y: 12, torso: -0.9, legF: 1.55, shinF: 0, legB: 0.6, shinB: -2.0,
          armF: -0.9, foreF: 0.4, armB: -1.5, foreB: 0.5)),
      Keyframe(1, Pose(y: 12, torso: -0.9, legF: 1.55, shinF: 0, legB: 0.6, shinB: -2.0,
          armF: -0.9, foreF: 0.4, armB: -1.5, foreB: 0.5)),
    ]),
    const FigureClip('jockey', 900, travel: 10, [
      Keyframe(0, _savunmaDurusu),
      Keyframe(0.5, Pose(y: 6, torso: 0.4, head: -0.35, legF: 0.35, shinF: -0.8, legB: -0.25, shinB: -0.8,
          armF: 0.55, foreF: 0.5, armB: -0.45, foreB: 0.5)),
      Keyframe(1, _savunmaDurusu),
    ]),
    FigureClip('steal', 700, travel: 12, [
      Keyframe(0, _topla(_savunmaDurusu, 40, 27)),
      Keyframe(0.45, _topla(const Pose(y: 6, torso: 0.5, legF: 1.25, shinF: -0.15, legB: -0.4, shinB: -0.7,
          armF: 0.8, armB: -0.9), 25, 28)),
      Keyframe(0.75, _topla(const Pose(y: 2, torso: 0.3, legF: 0.6, shinF: -0.4), 12, 12)),
      Keyframe(1, _topla(const Pose(torso: 0.2), 15, 27)),
    ]),
    FigureClip('control', 700, travel: 4, [
      Keyframe(0, _topla(_dur, 60, -40)),
      Keyframe(0.5, _topla(const Pose(torso: 0.15, legF: 0.45, shinF: -0.9, armF: -0.4, armB: 0.5), 17, 25)),
      Keyframe(1, _topla(_dur, 15, 27)),
    ]),
    FigureClip('intercept', 700, travel: 10, [
      Keyframe(0, _topla(_dur, 60, 26)),
      Keyframe(0.5, _topla(const Pose(y: 5, torso: 0.1, legF: 1.3, shinF: -0.1, legB: -0.3, shinB: -0.6,
          armF: 0.9, armB: -0.8), 26, 28)),
      Keyframe(1, _topla(const Pose(torso: 0.15), 15, 27)),
    ]),
    const FigureClip('dive', 700, travel: 18, [
      Keyframe(0, _kaleciHazir),
      Keyframe(0.35, Pose(y: -6, torso: 0.9, armF: 2.0, foreF: 0.1, armB: 1.8, foreB: 0.1,
          legF: -0.2, shinF: -0.4, legB: -0.6, shinB: -0.9)),
      Keyframe(0.7, _plonjonHavada),
      Keyframe(1, _plonjonYerde),
    ]),
    FigureClip('save', 600, travel: 2, [
      Keyframe(0, _topla(_plonjonYerde, 80, -10)),
      Keyframe(0.5, _plonjonYerde.copyWith(ballHand: 1, ballAlpha: 1)),
      Keyframe(1, _plonjonYerde.copyWith(ballHand: 1, ballAlpha: 1)),
    ]),
    FigureClip('catch', 700, [
      Keyframe(0, _topla(_kaleciHazir, 70, -6)),
      const Keyframe(0.5, Pose(y: 1, torso: 0.15, armF: 1.4, foreF: 0.9, armB: 1.3, foreB: 0.9,
          ballHand: 1, ballAlpha: 1)),
      const Keyframe(1, Pose(torso: 0.1, armF: 1.1, foreF: 1.3, armB: 1.0, foreB: 1.3,
          ballHand: 1, ballAlpha: 1)),
    ]),
  ])
    c.name: c,
};

// ---------------------------------------------------------------------
// KLİP DİZİSİ OYNATICI
// ---------------------------------------------------------------------
/// [clipsFor]'un verdiği klip adlarını sırayla oynatır. Klipler arası
/// geçişte önceki klibin son pozundan yumuşakça karışır (sıçrama yok).
class ClipSequencePlayer {
  final List<FigureClip> clips;

  /// Her klibin başındaki karışım payı (klip süresine oran)
  static const double blend = 0.18;

  ClipSequencePlayer(List<String> names)
      : clips = [
          for (final n in names) kFigureClips[n] ?? (throw ArgumentError('Bilinmeyen klip: $n')),
        ];

  int get durationMs => clips.fold(0, (a, c) => a + c.durationMs);

  /// Zaman (ms) -> (klip sırası, klip içi 0..1)
  (int, double) _konum(double ms) {
    var bas = 0.0;
    for (var i = 0; i < clips.length; i++) {
      final d = clips[i].durationMs.toDouble();
      if (ms < bas + d || i == clips.length - 1) {
        return (i, ((ms - bas) / d).clamp(0.0, 1.0));
      }
      bas += d;
    }
    return (0, 0);
  }

  Pose poseAt(double ms) {
    if (clips.isEmpty) return _dur;
    final (i, t) = _konum(ms);
    final p = clips[i].poseAt(t);
    if (i == 0 || t >= blend) return p;
    final onceki = clips[i - 1].poseAt(1);
    return Pose.lerp(onceki, p, Curves.easeOut.transform(t / blend));
  }

  /// O ana kadar kat edilen toplam yol
  double travelAt(double ms) {
    if (clips.isEmpty) return 0;
    final (i, t) = _konum(ms);
    var yol = 0.0;
    for (var k = 0; k < i; k++) {
      yol += clips[k].travel;
    }
    return yol + clips[i].travel * Curves.easeInOut.transform(t);
  }

  /// Şu an oynayan klibin adı (test ve hata ayıklama)
  String clipAt(double ms) => clips.isEmpty ? '' : clips[_konum(ms).$1].name;
}

// ---------------------------------------------------------------------
// GEOMETRİ: pozdan eklem noktaları
// ---------------------------------------------------------------------
class FigureGeometry {
  static const double torsoLen = 24, thigh = 15, shin = 15, upperArm = 11, foreArm = 10;

  final Offset hip, neck, shoulder, headCenter;
  final Offset kneeF, footF, kneeB, footB;
  final Offset elbowF, handF, elbowB, handB;
  final Offset ball;

  /// Baldır yönleri (krampon yönü için)
  final double shinAngleF, shinAngleB;

  FigureGeometry._(this.hip, this.neck, this.shoulder, this.headCenter, this.kneeF, this.footF,
      this.kneeB, this.footB, this.elbowF, this.handF, this.elbowB, this.handB, this.ball,
      this.shinAngleF, this.shinAngleB);

  static Offset _asagi(double a, double l) => Offset(math.sin(a) * l, math.cos(a) * l);

  factory FigureGeometry.of(Pose p) {
    final hip = Offset(p.x, p.y);
    final yukari = Offset(math.sin(p.torso), -math.cos(p.torso));
    final neck = hip + yukari * torsoLen;
    final shoulder = hip + yukari * (torsoLen - 3);
    final ha = p.torso + p.head;
    final headCenter = neck + Offset(math.sin(ha), -math.cos(ha)) * 15;

    final kneeF = hip + _asagi(p.legF, thigh);
    final footF = kneeF + _asagi(p.legF + p.shinF, shin);
    final kneeB = hip + _asagi(p.legB, thigh);
    final footB = kneeB + _asagi(p.legB + p.shinB, shin);
    final elbowF = shoulder + _asagi(p.armF, upperArm);
    final handF = elbowF + _asagi(p.armF + p.foreF, foreArm);
    final elbowB = shoulder + _asagi(p.armB, upperArm);
    final handB = elbowB + _asagi(p.armB + p.foreB, foreArm);

    final serbest = hip + Offset(p.ballX, p.ballY);
    final ball = Offset.lerp(serbest, handF + const Offset(2, 0), p.ballHand)!;

    return FigureGeometry._(hip, neck, shoulder, headCenter, kneeF, footF, kneeB, footB, elbowF,
        handF, elbowB, handB, ball, p.legF + p.shinF, p.legB + p.shinB);
  }
}
