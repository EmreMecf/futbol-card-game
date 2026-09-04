import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_typography.dart';

/// Ekranların üst başlığı.
///
/// ===================================================================
/// NEDEN AppBar DEĞİL?
/// ===================================================================
/// Material'ın [AppBar]'ı sabit yükseklikte ve başlığı küçük tutar.
/// Tasarımda başlık ekranın kimliği: telefonda 30, masaüstünde 34
/// punto, altında bir satır açıklama ve sağda sayaç hapları var.
/// Bunu AppBar'a sığdırmaya çalışmak her ekranda ayrı ayrı
/// `toolbarHeight` ve `flexibleSpace` ayarı demekti.
///
/// Bu widget içeriğin İÇİNDE, kaydırma alanının en üstünde duruyor.
/// Böylece uzun listelerde başlık da yukarı kayıyor ve ekranın
/// tamamı içeriğe kalıyor.
class ScreenHeader extends StatelessWidget {
  final String title;

  /// Başlığın altındaki tek satırlık açıklama
  final String? subtitle;

  /// Sağa yaslanan öğeler (sayaç hapları, buton)
  final List<Widget> actions;

  /// Geri okunu göster. İç ekranlarda (görev kurma) gerekiyor.
  final bool showBack;

  /// Geri okunun üstündeki küçük yol bilgisi ("Görevler")
  final String? breadcrumb;

  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
    this.breadcrumb,
  });

  @override
  Widget build(BuildContext context) {
    final boyut = AppBreakpoints.of(context);
    final genis = boyut.usesSidebar;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBack) _GeriSatiri(breadcrumb: breadcrumb),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(
                  size: genis ? 34 : 30,
                  weight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: 0.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    size: genis ? 13 : 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        for (final aksiyon in actions) ...[
          const SizedBox(width: 8),
          aksiyon,
        ],
      ],
    );
  }
}

class _GeriSatiri extends StatelessWidget {
  final String? breadcrumb;

  const _GeriSatiri({this.breadcrumb});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (context.canPop()) {
            context.pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                breadcrumb ?? 'Geri',
                style: AppTypography.bodyS,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir bölümün başlığı: "SON MAÇLAR", "ŞARTLAR" gibi.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

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

/// Uygulamanın standart yüzeyi: koyu kutu, ince kenarlık, yuvarlak köşe.
///
/// Bütün ekranlarda aynı kutu tekrar ediyordu. Tek yerde tutulunca
/// köşe yarıçapı ya da kenarlık rengi değiştiğinde her ekran birlikte
/// değişiyor.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final Color? color;
  final VoidCallback? onTap;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.borderColor,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final govde = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.surfaceLight),
      ),
      child: child,
    );

    if (onTap == null) return govde;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: govde,
      ),
    );
  }
}

/// Bir uyarı şeridi: bilgi, uyarı ya da tehlike.
class NoticeBar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final String? title;

  const NoticeBar({
    super.key,
    required this.icon,
    required this.color,
    required this.message,
    this.title,
  });

  /// Kart kaybı, kalıcı silme gibi geri alınamaz şeyler
  factory NoticeBar.danger(String message, {String? title}) => NoticeBar(
        icon: Icons.warning_amber_rounded,
        color: AppColors.danger,
        message: message,
        title: title,
      );

  /// Açıklayıcı bilgi
  factory NoticeBar.info(String message, {String? title}) => NoticeBar(
        icon: Icons.info_outline_rounded,
        color: AppColors.tierDiamond,
        message: message,
        title: title,
      );

  factory NoticeBar.warning(String message, {String? title}) => NoticeBar(
        icon: Icons.schedule_rounded,
        color: AppColors.warning,
        message: message,
        title: title,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: AppTypography.body(
                      size: 13,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: AppTypography.body(
                    size: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
