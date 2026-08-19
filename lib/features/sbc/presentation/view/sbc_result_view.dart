import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';

/// Görev tamamlandıktan sonraki ödül ekranı.
class SbcResultView extends StatelessWidget {
  final SbcSubmitResult result;
  final VoidCallback onClose;

  const SbcResultView({
    super.key,
    required this.result,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final kartlar = result.rewardCards;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.verified,
                          size: 44, color: AppColors.success),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Görev Tamamlandı!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.challengeName,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ---- ERİTİLEN ----
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department,
                              color: AppColors.danger, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${result.burnedCount} kart eritildi',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (result.rewardCoins > 0)
                            Row(
                              children: [
                                const Icon(Icons.monetization_on,
                                    color: AppColors.accent, size: 17),
                                const SizedBox(width: 5),
                                Text(
                                  '+${result.rewardCoins}',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // ---- KAZANILAN KARTLAR ----
                    if (kartlar.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.card_giftcard,
                              color: AppColors.accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Kazandığın kartlar (${kartlar.length})',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 130,
                          childAspectRatio: 0.66,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: kartlar.length,
                        itemBuilder: (context, index) {
                          return LayoutBuilder(
                            builder: (context, kisitlar) {
                              return PremiumPlayerCard.fromInventory(
                                kartlar[index],
                                key: ValueKey(kartlar[index].userCardId),
                                width: kisitlar.maxWidth,
                                interactive: false,
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: AppButton(
                label: 'TAMAM',
                icon: Icons.check,
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
