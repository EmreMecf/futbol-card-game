import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/walkout/spotlight_backdrop.dart';

/// Giriş ve kayıt ekranlarının ortak iskeleti: gece stadyumu zemini,
/// ortalanmış ve genişliği sınırlanmış içerik.
///
/// ZEMİN NEDEN ANİMASYONSUZ?
/// Walkout sahnesindeki ışık huzmeleri burada SABİT (ilerleme 1,
/// salınım sabit). Oyuncu bu ekranda yazı yazıyor; arkada sürekli
/// kıpırdayan ışık dikkat dağıtır ve klavye açıkken boşuna kare
/// harcar. Zemin bir kez çizilip `RepaintBoundary` içinde kalıyor.
class AuthScaffold extends StatelessWidget {
  final Widget child;

  /// Üstte geri butonu (kayıt ekranında)
  final bool showBack;

  const AuthScaffold({super.key, required this.child, this.showBack = false});

  /// Formun en fazla genişliği. Tablet ve masaüstünde form ekranın
  /// tamamına yayılırsa satırlar okunmaz uzunluğa çıkar.
  static const double maxFormWidth = 420;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const SpotlightBackdrop(
            progress: 1,
            sway: 0.25,
            color: AppColors.emerald,
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.xxxl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: maxFormWidth),
                  child: child,
                ),
              ),
            ),
          ),
          // Align ŞART: Stack(fit: expand) konumlanmamış çocukları TAM
          // EKRANA yayar. Align olmadan geri butonu bütün ekranı kaplıyor,
          // formdaki her dokunuş "geri" oluyordu.
          if (showBack)
            Align(
              alignment: Alignment.topLeft,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: IconButton(
                    tooltip: 'Geri',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Formun içindeki hata şeridi. SnackBar yerine formun İÇİNDE:
/// SnackBar birkaç saniye sonra kaybolur ve klavye açıkken çoğu zaman
/// klavyenin arkasında kalıyordu; oyuncu neden giriş yapamadığını
/// göremiyordu.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  /// Bağlantı hatası mı? (farklı simge ve ek açıklama)
  final bool isConnection;

  const AuthErrorBanner({
    super.key,
    required this.message,
    this.isConnection = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isConnection
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              color: AppColors.danger,
              size: 18,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                isConnection
                    ? '$message\nİnternet bağlantını kontrol edip tekrar dene.'
                    : message,
                style: AppTypography.body(size: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
