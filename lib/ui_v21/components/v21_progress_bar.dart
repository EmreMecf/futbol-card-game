import 'package:flutter/material.dart';

import '../animations/v21_motion.dart';
import '../foundation/v21_colors.dart';

/// V2.1 ilerleme çubuğu: koyu yol + parlak yeşil dolgu (referans XP ve
/// lig çubukları). Değer değişince [V21Motion.fill] süresinde dolar.
class V21ProgressBar extends StatelessWidget {
  /// 0.0 – 1.0 (dışı kırpılır)
  final double value;
  final double height;
  final Color trackColor;
  final List<Color> fillColors;

  /// Ekran okuyucu metni ("Sezon kademesi yüzde 34")
  final String? semanticsLabel;

  const V21ProgressBar({
    super.key,
    required this.value,
    this.height = 9,
    this.trackColor = V21Colors.trackDark,
    this.fillColors = const [V21Colors.progressGreen, V21Colors.progressGreenDark],
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height);
    final reduced = V21Motion.reduced(context);
    return Semantics(
      label: semanticsLabel,
      value: '%${(v * 100).round()}',
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), offset: Offset(0, height * 0.12), blurRadius: 0),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: v),
              duration: reduced ? Duration.zero : V21Motion.fill,
              curve: V21Motion.standard,
              builder: (context, t, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: t,
                  heightFactor: 1,
                  child: t <= 0
                      ? const SizedBox.shrink()
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: fillColors,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: FractionallySizedBox(
                              heightFactor: 0.38,
                              widthFactor: 1,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: height * 0.4),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    borderRadius: radius,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
