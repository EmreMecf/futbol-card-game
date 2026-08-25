import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/constants/app_colors.dart';
import 'card_tier_theme.dart';

/// KARTIN UZERINDEKI OZELLIK IZGARASI (SUT / HIZ / DRP / HZL / DEF / FIZ)
///
/// Iki sutun, uc satir. Sol sutun hucum ve atletiklik, sag sutun
/// savunma tarafi. FIFA kartlarindaki duzen; oyuncu bu yerlesimi zaten
/// taniyor, ogrenmesi gerekmiyor.
///
/// ---------------------------------------------------------------
/// NEDEN HER KARTTA GOSTERMIYORUZ?
/// ---------------------------------------------------------------
/// Koleksiyon izgarasindaki kartlar ~100 piksel genisliginde. Orada
/// alti sayi daha sikistirmak, yazilari okunmaz yapip kartin asil
/// bilgisini (guc + isim) da bogardi. Bu yuzden [PremiumPlayerCard]
/// izgarayi sadece kart yeterince buyukken ciziyor.
class CardAttributesGrid extends StatelessWidget {
  final CardAttributes attributes;

  /// Kartin seviye temasi (yazi renkleri buradan gelir)
  final CardTierTheme theme;

  /// Olcek referansi: kartin genisligi. Butun boyutlar buna oranli.
  final double scale;

  const CardAttributesGrid({
    super.key,
    required this.attributes,
    required this.theme,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final girdiler = attributes.entries;

    // entries sirasi: SUT, HIZ, DRP, HZL, DEF, FIZ
    // Sol sutun ilk uc, sag sutun son uc.
    final sol = girdiler.take(3).toList();
    final sag = girdiler.skip(3).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _sutun(sol)),
        SizedBox(width: scale * 0.04),

        // Ince ayirac: iki sutunun tek bir blok gibi gorunmesini engeller
        Container(
          width: 1,
          height: scale * 0.22,
          color: theme.mutedTextColor.withValues(alpha: 0.25),
        ),

        SizedBox(width: scale * 0.04),
        Expanded(child: _sutun(sag)),
      ],
    );
  }

  Widget _sutun(List<CardAttributeEntry> girdiler) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final g in girdiler)
          Padding(
            padding: EdgeInsets.only(bottom: scale * 0.012),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${g.value}',
                  style: TextStyle(
                    fontSize: scale * 0.075,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: theme.textColor,
                    // Sayilar sabit genislikte olsun ki "9" ve "88"
                    // alt alta geldiginde sutun kaymasin.
                    fontFeatures: const [FontFeature.tabularFigures()],
                    shadows: const [
                      Shadow(color: Colors.black45, blurRadius: 2),
                    ],
                  ),
                ),
                SizedBox(width: scale * 0.022),
                Text(
                  g.label,
                  style: TextStyle(
                    fontSize: scale * 0.058,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: theme.mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// DETAY EKRANI ICIN GENIS OZELLIK PANELI
///
/// Kartin uzerindeki izgara sayilari gosterir; burasi onlari
/// KARSILASTIRILABILIR yapar. Cubuk uzunlugu ve rengi sayesinde
/// "bu oyuncu hizli ama defansi zayif" tek bakista anlasilir —
/// alti sayiyi okuyup kafada siralamaya gerek kalmaz.
class CardAttributesPanel extends StatelessWidget {
  final CardAttributes attributes;

  const CardAttributesPanel({super.key, required this.attributes});

  @override
  Widget build(BuildContext context) {
    final girdiler = attributes.entries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.insights, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 7),
            const Text(
              'Özellikler',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            Text(
              'Ort. ${attributes.average}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final g in girdiler) _satir(g),
      ],
    );
  }

  Widget _satir(CardAttributeEntry girdi) {
    final renk = _renk(girdi.ratio);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // ---- ETIKET ----
          SizedBox(
            width: 62,
            child: Text(
              _uzunEtiket(girdi.label),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // ---- CUBUK ----
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 7, color: AppColors.surfaceLight),
                  FractionallySizedBox(
                    widthFactor: girdi.ratio.clamp(0.02, 1.0),
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [renk.withValues(alpha: 0.65), renk],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ---- SAYI ----
          SizedBox(
            width: 26,
            child: Text(
              '${girdi.value}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: renk,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kart uzerinde yer dar oldugu icin kisaltma kullaniyoruz;
  /// detayda yer var, tam adini yaziyoruz.
  static String _uzunEtiket(String kisa) => switch (kisa) {
        'SUT' => 'Şut',
        'HIZ' => 'Hız',
        'DRP' => 'Dribling',
        'HZL' => 'Hızlanma',
        'DEF' => 'Defans',
        'FIZ' => 'Fizik',
        _ => kisa,
      };

  /// Zayiftan gucluye: kirmizi -> turuncu -> sari -> yesil.
  ///
  /// Esikler kasitli olarak yuksek: kartlarin cogu orta bantta
  /// toplandigi icin daha alcak esiklerde her sey yesil gorunur ve
  /// renk hicbir sey anlatmaz olurdu.
  static Color _renk(double oran) {
    if (oran >= 0.78) return AppColors.success;
    if (oran >= 0.55) return const Color(0xFFB6D94C);
    if (oran >= 0.32) return AppColors.warning;
    return AppColors.danger;
  }
}
