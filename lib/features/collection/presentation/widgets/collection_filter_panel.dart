import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';
import '../../../../shared/widgets/screen_header.dart';
import '../viewmodel/collection_view_model.dart';

/// Masaüstü koleksiyon ekranının sol filtre sütunu.
///
/// ===================================================================
/// NEDEN AYRI BİR WIDGET?
/// ===================================================================
/// Telefonda filtreler yatay kaydırılan çipler halinde ([CollectionFilterBar]).
/// 1440 piksellik bir ekranda o çip şeridi ekranın üstünde ince bir
/// şerit olarak kalıp yanında koca bir boşluk bırakıyordu.
///
/// Masaüstünde filtreler dikey bir sütun: hepsi aynı anda görünüyor,
/// hangi seviyeden kaç kart olduğu tek bakışta okunuyor ve seçim
/// yapmak için yatay kaydırma gerekmiyor.
class CollectionFilterPanel extends StatelessWidget {
  final CollectionViewModel viewModel;

  const CollectionFilterPanel({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- SEVİYE ----
          const SectionTitle('Seviye'),
          const SizedBox(height: 10),
          _SeviyeSatiri(
            label: 'Tümü',
            color: AppColors.textSecondary,
            count: viewModel.totalCards,
            selected: viewModel.tierFilter == null,
            onTap: () => viewModel.setTierFilter(null),
          ),
          for (final seviye in CardTier.values.reversed)
            _SeviyeSatiri(
              label: seviye.label,
              color: CardTierTheme.of(seviye).frameGradient[1],
              count: viewModel.tierCounts[seviye] ?? 0,
              selected: viewModel.tierFilter == seviye,
              onTap: () => viewModel.setTierFilter(
                viewModel.tierFilter == seviye ? null : seviye,
              ),
            ),

          const SizedBox(height: 22),

          // ---- POZİSYON ----
          const SectionTitle('Pozisyon'),
          const SizedBox(height: 10),
          _PozisyonIzgarasi(viewModel: viewModel),

          const SizedBox(height: 22),

          // ---- SIRALAMA ----
          const SectionTitle('Sıralama'),
          const SizedBox(height: 10),
          _SiralamaSecici(viewModel: viewModel),

          if (viewModel.hasActiveFilter) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: viewModel.clearFilters,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Filtreleri temizle'),
            ),
          ],

          const SizedBox(height: 22),
          _TamamlamaKutusu(viewModel: viewModel),
        ],
      ),
    );
  }
}

class _SeviyeSatiri extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SeviyeSatiri({
    required this.label,
    required this.color,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.surfaceLight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: selected ? Border.all(color: color) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w800,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: AppTypography.display(
                    size: 15,
                    weight: FontWeight.w800,
                    color: color,
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

class _PozisyonIzgarasi extends StatelessWidget {
  final CollectionViewModel viewModel;

  const _PozisyonIzgarasi({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final hedefler = <(String, CardPosition?)>[
      ('Tümü', null),
      for (final p in CardPosition.values) (p.label, p),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (etiket, pozisyon) in hedefler)
          _PozisyonDugmesi(
            label: etiket,
            selected: viewModel.positionFilter == pozisyon,
            onTap: () => viewModel.setPositionFilter(
              viewModel.positionFilter == pozisyon ? null : pozisyon,
            ),
          ),
      ],
    );
  }
}

class _PozisyonDugmesi extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PozisyonDugmesi({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.16)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.surfaceLight,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTypography.display(
              size: 14,
              weight: FontWeight.w800,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SiralamaSecici extends StatelessWidget {
  final CollectionViewModel viewModel;

  const _SiralamaSecici({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CollectionSort>(
          value: viewModel.sort,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          style: AppTypography.body(size: 13),
          items: [
            for (final s in CollectionSort.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (yeni) {
            if (yeni != null) viewModel.setSort(yeni);
          },
        ),
      ),
    );
  }
}

/// "63 / 100 farklı kart" ilerleme kutusu.
class _TamamlamaKutusu extends StatelessWidget {
  final CollectionViewModel viewModel;

  const _TamamlamaKutusu({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    // Katalogdaki AYRI kart sayısı: aynı futbolcudan iki tane varsa
    // koleksiyon tamamlama açısından bir sayılır.
    final farkli =
        viewModel.allCards.map((k) => k.cardId).toSet().length;

    return SurfaceCard(
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Katalog tamamlama',
            style: AppTypography.body(size: 12.5, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$farkli',
                style: AppTypography.display(
                  size: 26,
                  weight: FontWeight.w900,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 6),
              Text('farklı kart', style: AppTypography.bodyXS),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              // Katalog boyutu sunucudan gelmiyor; oran yerine
              // sahip olunan kart sayısına göre dolduruyoruz.
              value: viewModel.totalCards == 0
                  ? 0
                  : farkli / viewModel.totalCards,
              minHeight: 6,
              backgroundColor: AppColors.surfaceLight,
              valueColor: const AlwaysStoppedAnimation(AppColors.success),
            ),
          ),
        ],
      ),
    );
  }
}
