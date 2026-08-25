import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/premium_card/premium_card.dart';

/// Karta dokununca acilan detay penceresi.
///
/// BURASI KARTIN VITRINI:
/// Listede kartlar `interactive: false` ile ciziliyor (performans icin).
/// Burada ise tek bir kart var, dolayisiyla tum efektleri aciyoruz:
/// 3B egilme, jiroskop, holografik parlama ve kayan yuzey yansimasi.
class CardDetailSheet extends StatelessWidget {
  final InventoryCard card;

  const CardDetailSheet({super.key, required this.card});

  /// Alttan acilan pencereyi gosterir
  static Future<void> show(BuildContext context, InventoryCard card) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CardDetailSheet(card: card),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ekranGenisligi = MediaQuery.sizeOf(context).width;
    // Kart ekranin %62'si kadar genis olsun ama 280 pikseli gecmesin
    final kartGenisligi = (ekranGenisligi * 0.62).clamp(180.0, 280.0);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        // Ozellik paneli eklendikten sonra icerik kucuk ekranlarda
        // tasabiliyor; kaydirilabilir olmasi sart.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tutamac
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // ---- KART (tum efektler acik) ----
              PremiumPlayerCard.fromInventory(
                card,
                width: kartGenisligi,
                interactive: true,
                useGyroscope: true,
              ),

              const SizedBox(height: 20),

              Text(
                'Karti tut ve hareket ettir',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),

              const SizedBox(height: 20),

              // ---- BILGILER ----
              _bilgiSatiri('Seviye', card.tier.label),
              _bilgiSatiri('Pozisyon', card.position.label),
              _bilgiSatiri('Guc', '${card.power}'),

              // ---- OZELLIKLER ----
              // Guc "kart turu kazanir mi?" sorusunu yanitliyor;
              // asagidaki panel "bu oyuncu nasil bir oyuncu?" sorusunu.
              if (card.attributes?.isNotEmpty ?? false) ...[
                const SizedBox(height: 18),
                CardAttributesPanel(attributes: card.attributes!),
                const SizedBox(height: 6),
                const Text(
                  'Özellikler kartın karakterini gösterir; '
                  'turu kazanan hâlâ güç + kimyadır.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (card.nationality != null)
                _bilgiSatiri('Ulke', card.nationality!),
              if (card.club != null) _bilgiSatiri('Kulup', card.club!),

              if (card.isLocked) ...[
                const SizedBox(height: 16),
                _uyari(
                  Icons.lock,
                  AppColors.warning,
                  'Bu kart devam eden bir macta kilitli. '
                  'Mac bitene kadar kadrondan cikaramazsin.',
                ),
              ],

              if (card.isLegend) ...[
                const SizedBox(height: 16),
                _uyari(
                  Icons.auto_awesome,
                  AppColors.tierLegend,
                  'Legend kart: Gucu ne olursa olsun alttaki 4 seviyeyi yener. '
                  'Sadece gucu daha yuksek bir Legend yenebilir.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bilgiSatiri(String etiket, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            etiket,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            deger,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _uyari(IconData ikon, Color renk, String metin) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: renk, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              metin,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
