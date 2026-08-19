import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';

/// Görev şartlarının canlı kontrol listesi.
///
/// Oyuncu kart yerleştirdikçe her şart yeşil tik veya kırmızı çarpıya
/// dönüşüyor. Bu geri bildirim olmadan oyuncu "neden gönderemiyorum?"
/// diye sorardı; sistemin öğrenilebilir olmasının anahtarı bu liste.
class RequirementChecklist extends StatelessWidget {
  final SbcEvaluation evaluation;

  /// Kadro henüz tamamlanmadıysa şartlar soluk gösterilir
  final bool isSquadComplete;

  const RequirementChecklist({
    super.key,
    required this.evaluation,
    this.isSquadComplete = true,
  });

  @override
  Widget build(BuildContext context) {
    if (evaluation.requirements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- BAŞLIK ----
        Row(
          children: [
            Icon(
              evaluation.isValid ? Icons.verified : Icons.rule,
              size: 16,
              color: evaluation.isValid
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 7),
            const Text(
              'Şartlar',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Text(
              evaluation.progressText,
              style: TextStyle(
                color: evaluation.isValid
                    ? AppColors.success
                    : AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ---- ŞARTLAR ----
        for (final sart in evaluation.requirements)
          _SartSatiri(result: sart, soluk: !isSquadComplete),
      ],
    );
  }
}

class _SartSatiri extends StatelessWidget {
  final SbcRequirementResult result;
  final bool soluk;

  const _SartSatiri({required this.result, required this.soluk});

  @override
  Widget build(BuildContext context) {
    final karsilandi = result.isMet;
    final renk = karsilandi ? AppColors.success : AppColors.danger;

    return Opacity(
      opacity: soluk ? 0.55 : 1.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            // ---- TİK / ÇARPI ----
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(color: renk.withValues(alpha: 0.6)),
              ),
              child: Icon(
                karsilandi ? Icons.check : Icons.close,
                size: 12,
                color: renk,
              ),
            ),

            const SizedBox(width: 9),

            // ---- AÇIKLAMA ----
            Expanded(
              child: Text(
                result.label,
                style: TextStyle(
                  color: karsilandi
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: karsilandi ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ---- İLERLEME ----
            Text(
              result.progressText,
              style: TextStyle(
                color: renk,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Görev kartındaki kompakt şart özeti (liste ekranında kullanılır)
class RequirementSummary extends StatelessWidget {
  final List<SbcRequirement> requirements;

  const RequirementSummary({super.key, required this.requirements});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final sart in requirements)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              sart.label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }
}
