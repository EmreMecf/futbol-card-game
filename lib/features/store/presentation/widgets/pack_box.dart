import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';

/// Mağazadaki paketin 3B görünümlü kutusu.
///
/// ===================================================================
/// NEDEN GÖRSEL DOSYASI DEĞİL?
/// ===================================================================
/// Her paket için ayrı bir PNG hazırlamak dört ayrı dosya, dört ayrı
/// çözünürlük ve her yeni pakette bir tasarım işi demekti. Kutu
/// paketin EN ÇOK ÇIKAN seviyesinden türetiliyor: standart paket
/// bronz, premium paket altın çerçeveyle çiziliyor. Böylece üç
/// paket birbirinden ayırt edilebiliyor.
///
/// Yeni bir paket eklendiğinde tek yapılacak veritabanına satır
/// eklemek; kutusu kendiliğinden doğru renkte çıkıyor.
class PackBox extends StatelessWidget {
  final PackType pack;
  final double width;

  const PackBox({super.key, required this.pack, required this.width});

  @override
  Widget build(BuildContext context) {
    final tema = CardTierTheme.of(pack.signatureTier);
    final yukseklik = width * 1.38;

    return Transform.rotate(
      // Hafif eğim kutuyu düz bir dikdörtgen olmaktan çıkarıp
      // elle tutulabilir bir nesneye çeviriyor.
      angle: -0.09,
      child: Container(
        width: width,
        height: yukseklik,
        padding: EdgeInsets.all(width * 0.035),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: tema.frameGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(width * 0.12),
          boxShadow: [
            BoxShadow(
              color: tema.glowColor,
              blurRadius: width * 0.34,
              offset: Offset(0, width * 0.14),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: tema.panelGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(width * 0.09),
          ),
          child: Stack(
            children: [
              // Üstten gelen ışık: kutuya hacim veriyor
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(width * 0.09),
                    gradient: RadialGradient(
                      center: const Alignment(0, -1),
                      radius: 1.1,
                      colors: [
                        tema.specularColor.withValues(alpha: 0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.card_giftcard_rounded,
                      size: width * 0.32,
                      color: tema.textColor,
                    ),
                    SizedBox(height: width * 0.07),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: width * 0.08),
                      child: Text(
                        _kutuEtiketi(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.display(
                          size: width * 0.13,
                          weight: FontWeight.w900,
                          color: tema.textColor,
                          letterSpacing: 1.2,
                          height: 1.05,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Paket adının ilk kelimesi: "Kadro Paketi" -> "KADRO"
  String _kutuEtiketi() {
    final parcalar = pack.name.trim().split(RegExp(r'\s+'));
    return (parcalar.isEmpty ? pack.slug : parcalar.first).toUpperCase();
  }
}

/// Çıkma ihtimali çipi: renkli nokta + seviye + yüzde.
class OddsChip extends StatelessWidget {
  final TierOdds odds;
  final bool compact;

  const OddsChip({super.key, required this.odds, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final renk = CardTierTheme.of(odds.tier).frameGradient[1];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          odds.tier.label,
          style: AppTypography.body(
            size: compact ? 10.5 : 11.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          odds.displayPercent,
          style: AppTypography.display(
            size: compact ? 12 : 13,
            weight: FontWeight.w800,
            color: renk,
          ),
        ),
      ],
    );
  }

}
