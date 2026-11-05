import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';

/// Kart seviyesinin EKRANDA görünen Türkçe adı ve rengi.
///
/// NEDEN `CardTier.label` KULLANILMIYOR?
/// `shared_models` paketi sunucuyla ortak ve oradaki etiketler
/// ASCII ("Gumus", "Altin"). Oyuncuya "Gümüş", "Altın" göstermek
/// gerekiyor. Sunucu modelini değiştirmek yerine görünen ad burada,
/// arayüz katmanında çözülüyor; sunucu bu adı hiç bilmek zorunda değil.
extension CardTierDisplay on CardTier {
  String get displayName => switch (this) {
    CardTier.bronze => 'Bronz',
    CardTier.silver => 'Gümüş',
    CardTier.gold => 'Altın',
    // Diamond ve Legend Türkçeleştirilmedi: oyun kurallarında ve
    // uygulamanın geri kalanında (walkout "LEGEND" yazısı dahil)
    // bu adlar geçiyor. Prototipteki "Elmas/Efsane" ile karışırsa
    // oyuncu aynı seviyeyi iki farklı adla görürdü.
    CardTier.diamond => 'Diamond',
    CardTier.legend => 'Legend',
  };

  Color get color => switch (this) {
    CardTier.bronze => AppColors.tierBronze,
    CardTier.silver => AppColors.tierSilver,
    CardTier.gold => AppColors.tierGold,
    CardTier.diamond => AppColors.tierDiamond,
    CardTier.legend => AppColors.tierLegend,
  };
}

/// NADİRLİK ROZETİ: "✧ LEGEND ✧" (yıldızlar simge olarak çizilir)
///
/// Filtrelerde, kart detayında ve paket ihtimallerinde aynı rozet.
/// Legend rozeti mor -> altın degrade alıyor; diğerleri düz renk.
/// Fark kasıtlı: en nadir seviye ekranda tek bakışta ayırt edilmeli.
class TierBadge extends StatelessWidget {
  final CardTier tier;

  /// Küçük (liste) ya da normal (detay)
  final bool compact;

  const TierBadge(this.tier, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final legend = tier == CardTier.legend;
    final renk = tier.color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? AppSpacing.xxs : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        gradient: legend ? AppColors.legendGradient : null,
        color: legend ? null : renk.withValues(alpha: 0.14),
        border: legend ? null : Border.all(color: renk.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "✦" KARAKTERİ KULLANILMIYOR: Barlow Condensed'de bu glif yok,
          // ekranda kutu olarak çiziliyordu. Simge her yerde aynı görünür.
          if (legend) ...[
            Icon(
              Icons.auto_awesome,
              size: compact ? 10 : 12,
              color: Colors.white,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            tier.displayName.toUpperCase(),
            style: AppTypography.display(
              size: compact ? 11 : 13,
              weight: FontWeight.w900,
              letterSpacing: 1.2,
              color: legend ? Colors.white : renk,
            ),
          ),
          if (legend) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.auto_awesome,
              size: compact ? 10 : 12,
              color: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}
