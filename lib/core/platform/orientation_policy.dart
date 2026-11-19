import 'dart:ui' show Size;

/// Cihazın ekran yönü kuralı.
enum OrientationPolicy {
  /// Telefon: yalnız dikey
  portraitOnly,

  /// Tablet ve web: her yön
  free,

  /// Ekran ölçüsü henüz gelmedi: ilk kare çizilince yeniden bakılır
  unknown,
}

/// Bu kısa kenardan (mantıksal piksel) geniş cihaz tablet sayılır
const double kTabletShortestSide = 600;

/// [physicalSize] açılışta sıfır gelebilir (motor ölçüyü ilk kareden önce
/// bildirmeyebilir). Sıfırı "telefon" saymak tableti dikey kilitlerdi.
OrientationPolicy orientationPolicyFor(Size physicalSize, double devicePixelRatio, {required bool isWeb}) {
  if (isWeb) return OrientationPolicy.free;
  if (physicalSize.isEmpty || devicePixelRatio <= 0) return OrientationPolicy.unknown;
  return physicalSize.shortestSide / devicePixelRatio < kTabletShortestSide
      ? OrientationPolicy.portraitOnly
      : OrientationPolicy.free;
}
