import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/premium_card/card_tier_theme.dart';
import '../viewmodel/collection_view_model.dart';

/// Koleksiyon filtreleri: seviye, pozisyon, arama ve siralama.
///
/// TASARIM NOTU:
/// Seviye rozetleri kartin gercek renklerini kullaniyor. Boylece
/// oyuncu "Altin" yazisini okumadan da hangi filtreyi sectigini
/// renkten anliyor - koleksiyon ekraninda goz zaten renklere aliskin.
class CollectionFilterBar extends StatelessWidget {
  final CollectionViewModel viewModel;

  const CollectionFilterBar({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- ARAMA ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: viewModel.setSearch,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Futbolcu, kulup veya ulke ara...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              suffixIcon: viewModel.search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => viewModel.setSearch(''),
                    ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ---- SEVIYE FILTRELERI ----
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final seviye in CardTier.values.reversed)
                _SeviyeRozeti(
                  tier: seviye,
                  adet: viewModel.tierCounts[seviye] ?? 0,
                  secili: viewModel.tierFilter == seviye,
                  onTap: () => viewModel.setTierFilter(seviye),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ---- POZISYON FILTRELERI + SIRALAMA ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final pozisyon in CardPosition.values)
                _PozisyonRozeti(
                  position: pozisyon,
                  adet: viewModel.positionCounts[pozisyon] ?? 0,
                  secili: viewModel.positionFilter == pozisyon,
                  onTap: () => viewModel.setPositionFilter(pozisyon),
                ),

              const Spacer(),

              // ---- SIRALAMA ----
              PopupMenuButton<CollectionSort>(
                tooltip: 'Sirala',
                icon: const Icon(Icons.sort, color: AppColors.textSecondary),
                color: AppColors.surface,
                onSelected: viewModel.setSort,
                itemBuilder: (context) => [
                  for (final s in CollectionSort.values)
                    PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          Icon(
                            viewModel.sort == s
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: viewModel.sort == s
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              if (viewModel.hasActiveFilter)
                IconButton(
                  tooltip: 'Filtreleri temizle',
                  icon: const Icon(Icons.filter_alt_off,
                      color: AppColors.warning, size: 20),
                  onPressed: viewModel.clearFilters,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Seviye filtre rozeti - kartin gercek renkleriyle
class _SeviyeRozeti extends StatelessWidget {
  final CardTier tier;
  final int adet;
  final bool secili;
  final VoidCallback onTap;

  const _SeviyeRozeti({
    required this.tier,
    required this.adet,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tema = CardTierTheme.of(tier);
    // Kartin cerceve degradesinin en parlak rengi
    final renk = tema.frameGradient[1];

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: secili ? renk.withValues(alpha: 0.22) : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: adet == 0 ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: secili ? renk : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: tema.frame,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  tier.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: secili ? FontWeight.w800 : FontWeight.w600,
                    color: adet == 0
                        ? AppColors.textSecondary.withValues(alpha: 0.4)
                        : (secili ? renk : AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$adet',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pozisyon filtre rozeti
class _PozisyonRozeti extends StatelessWidget {
  final CardPosition position;
  final int adet;
  final bool secili;
  final VoidCallback onTap;

  const _PozisyonRozeti({
    required this.position,
    required this.adet,
    required this.secili,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Tooltip(
        message: '${position.label} ($adet kart)',
        child: Material(
          color: secili
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: adet == 0 ? null : onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: secili ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                position.shortLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: adet == 0
                      ? AppColors.textSecondary.withValues(alpha: 0.4)
                      : (secili ? AppColors.primary : AppColors.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
