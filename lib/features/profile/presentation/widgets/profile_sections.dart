import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/game/game_ui.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../../domain/achievements.dart';
import '../viewmodel/profile_view_model.dart';

// ====================================================================
// BAŞARIMLAR
// ====================================================================
/// Gerçek sayaçlardan hesaplanan, ödülsüz başarım rozetleri.
class AchievementsSection extends StatelessWidget {
  final ProfileViewModel viewModel;

  /// Izgaradaki sütun sayısı (telefonda 2, masaüstünde 3)
  final int columns;

  const AchievementsSection({
    super.key,
    required this.viewModel,
    this.columns = 2,
  });

  @override
  Widget build(BuildContext context) {
    final liste = viewModel.achievements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Başarımlar',
          trailing: Text(
            '${viewModel.unlockedAchievementCount} / ${liste.length}',
            style: AppTypography.body(
              size: 12,
              weight: FontWeight.w800,
              color: AppColors.emerald,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 112,
          ),
          itemCount: liste.length,
          itemBuilder: (context, i) => AchievementTile(achievement: liste[i]),
        ),
      ],
    );
  }
}

class AchievementTile extends StatelessWidget {
  final Achievement achievement;

  const AchievementTile({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final acik = a.isUnlocked;
    final renk = acik ? a.color : AppColors.textSecondary;

    return Semantics(
      label:
          '${a.title}: ${a.description}. '
          '${acik ? 'Açıldı' : 'Kilitli, ${a.progressText}'}',
      excludeSemantics: true,
      child: GlassPanel(
        accentColor: acik ? a.color : null,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs + 2),
                  decoration: BoxDecoration(
                    color: renk.withValues(alpha: acik ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(a.icon, size: 20, color: renk),
                ),
                const Spacer(),
                Icon(
                  acik ? Icons.check_circle_rounded : Icons.lock_rounded,
                  size: 16,
                  color: acik ? a.color : AppColors.textSecondary,
                ),
              ],
            ),
            const Spacer(),
            Text(
              a.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 13,
                weight: FontWeight.w900,
                color: acik ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            Text(
              a.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyXS,
            ),
            // Tek adımlık hedeflerde ("Usta ligine yüksel") çubuk
            // anlamsız; sadece birden fazla adımlıklarda gösteriliyor.
            if (!acik && a.target > 1) ...[
              const SizedBox(height: AppSpacing.xs),
              GameProgressBar(value: a.progress, height: 5),
            ],
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// FAVORİ KARTLAR
// ====================================================================
class FavoriteCardsSection extends StatelessWidget {
  final ProfileViewModel viewModel;

  const FavoriteCardsSection({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (!viewModel.supportsFavorites) return const SizedBox.shrink();
    final kartlar = viewModel.favoriteCards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Favori kartlar',
          trailing: TextButton(
            onPressed: () => context.go(AppRoutes.collection),
            child: Text(
              'Koleksiyon',
              style: AppTypography.body(
                size: 12,
                weight: FontWeight.w800,
                color: AppColors.emerald,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (kartlar.isEmpty)
          GlassPanel(
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_border_rounded,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Koleksiyonda bir karta dokunup kalbe basarak '
                    'favorilerine ekleyebilirsin.',
                    style: AppTypography.bodyS,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kartlar.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) => PremiumPlayerCard.fromInventory(
                kartlar[i],
                key: ValueKey('favori-${kartlar[i].cardId}'),
                width: 88,
                interactive: false,
              ),
            ),
          ),
      ],
    );
  }
}
