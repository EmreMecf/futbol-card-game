import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Üst şeritteki sayaç hapı: coin, puan, koruma hakkı.
///
/// Değer [AppTypography.display] ile yazılıyor. Rakamlar dar olduğu
/// için "2.450" gibi dört haneli değerler hapı şişirmiyor ve üst
/// şeritte yan yana üç hap rahat duruyor.
class StatChip extends StatelessWidget {
  final Widget icon;
  final String value;

  /// Değerin yanına soluk yazılan ek bilgi ("/10" gibi)
  final String? suffix;

  final VoidCallback? onTap;

  const StatChip({
    super.key,
    required this.icon,
    required this.value,
    this.suffix,
    this.onTap,
  });

  /// Coin hapı
  factory StatChip.coins(int amount, {VoidCallback? onTap}) => StatChip(
        icon: const _CoinIcon(),
        value: _binlikAyir(amount),
        onTap: onTap,
      );

  /// Puan (MMR) hapı
  factory StatChip.rating(int mmr) => StatChip(
        icon: const Icon(
          Icons.emoji_events_rounded,
          size: 16,
          color: AppColors.accent,
        ),
        value: _binlikAyir(mmr),
      );

  /// Koruma hakkı hapı
  factory StatChip.protection(int used, int max) => StatChip(
        icon: const Icon(
          Icons.shield_rounded,
          size: 16,
          color: AppColors.tierDiamond,
        ),
        value: '$used',
        suffix: '/$max',
      );

  /// 2450 -> "2.450". Türkçe binlik ayracı nokta.
  static String _binlikAyir(int sayi) {
    final metin = sayi.abs().toString();
    final tampon = StringBuffer(sayi < 0 ? '-' : '');
    for (var i = 0; i < metin.length; i++) {
      if (i > 0 && (metin.length - i) % 3 == 0) tampon.write('.');
      tampon.write(metin[i]);
    }
    return tampon.toString();
  }

  @override
  Widget build(BuildContext context) {
    final govde = Container(
      padding: const EdgeInsets.fromLTRB(8, 7, 12, 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            value,
            style: AppTypography.display(size: 15, weight: FontWeight.w800),
          ),
          if (suffix != null)
            Text(
              suffix!,
              style: AppTypography.display(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return govde;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: govde,
      ),
    );
  }
}

/// Coin simgesi. Görsel dosyası yerine çizim: her boyutta net kalır
/// ve uygulama paketini büyütmez.
class _CoinIcon extends StatelessWidget {
  const _CoinIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFB8860B),
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bölüm başlığı: "SON MAÇLAR", "ŞARTLAR" gibi küçük büyük-harf etiket.
class SectionLabel extends StatelessWidget {
  final String text;

  /// Sağa hizalı ek (bir buton ya da sayaç)
  final Widget? trailing;

  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text.toUpperCase(), style: AppTypography.label),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
