import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';

/// Hamle sayaci.
///
/// SUNUCU SAATIYLE CALISIR: Gelen [remaining] degeri ViewModel'de
/// sunucunun gonderdigi saat farki kullanilarak hesaplaniyor. Oyuncunun
/// telefon saati yanlis olsa bile sayac dogru ilerler.
class TurnTimer extends StatelessWidget {
  final Duration remaining;
  final bool isMyTurn;

  /// Son 10 saniye: kirmiziya doner
  final bool isUrgent;

  const TurnTimer({
    super.key,
    required this.remaining,
    required this.isMyTurn,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final toplam = GameRules.turnDuration.inMilliseconds;
    final kalan = remaining.inMilliseconds.clamp(0, toplam);
    final oran = toplam == 0 ? 0.0 : kalan / toplam;

    final renk = !isMyTurn
        ? AppColors.textSecondary
        : (isUrgent ? AppColors.danger : AppColors.primary);

    return Column(
      children: [
        // Ince ilerleme cubugu
        SizedBox(
          height: 4,
          child: LinearProgressIndicator(
            value: oran,
            backgroundColor: AppColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation(renk),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, size: 14, color: renk),
              const SizedBox(width: 6),
              Text(
                '${remaining.inSeconds} sn',
                style: TextStyle(
                  color: renk,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  // Rakamlar esit genislikte olsun ki sayac zipla­masin
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
