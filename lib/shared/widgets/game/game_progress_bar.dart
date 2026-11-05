import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// İlerleme çubuğunun anlamı (rengi anlamdan gelir, keyfi seçilmez).
enum ProgressKind {
  /// Görev ilerlemesi
  task,

  /// Sezon yolu
  season,

  /// Coin / ödül
  reward,

  /// Enerji, zaman, bağlantı
  energy,
}

/// İLERLEME ÇUBUĞU — görev, sezon, lig ve enerji için tek bileşen.
///
/// ===================================================================
/// NEDEN `LinearProgressIndicator` DEĞİL?
/// ===================================================================
/// Material'in çubuğu düz tek renk çiziyor ve değer değişince ZIPLIYOR.
/// Oyunlarda ilerleme "dolmalı": görev 2/3'ten 3/3'e geçtiğinde çubuğun
/// akarak dolduğunu görmek, ödülü kazanma hissinin parçası.
///
/// `TweenAnimationBuilder` sadece değer değiştiğinde çalışır; çubuk
/// dururken hiç kare harcamaz.
class GameProgressBar extends StatelessWidget {
  /// 0.0 - 1.0 arası (dışındaki değerler kırpılır)
  final double value;

  final ProgressKind kind;

  final double height;

  /// Ekran okuyucu için açıklama ("Görev ilerlemesi: 2 / 3")
  final String? semanticLabel;

  const GameProgressBar({
    super.key,
    required this.value,
    this.kind = ProgressKind.task,
    this.height = 8,
    this.semanticLabel,
  });

  LinearGradient get _degrade => switch (kind) {
    ProgressKind.task => AppGradients.progressEmerald,
    ProgressKind.season => AppGradients.progressPurple,
    ProgressKind.reward => AppGradients.progressGold,
    ProgressKind.energy => AppGradients.progressCyan,
  };

  @override
  Widget build(BuildContext context) {
    final hedef = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);

    return Semantics(
      label: semanticLabel,
      value: '%${(hedef * 100).round()}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: AppColors.surfaceLight),
              TweenAnimationBuilder<double>(
                tween: Tween(end: hedef),
                duration: AppDurations.progress,
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: _degrade),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
