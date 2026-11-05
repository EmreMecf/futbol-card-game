import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';

/// Oyun butonunun görsel türü.
enum GameButtonVariant {
  /// Altın, 3B, en büyük: "MAÇA BAŞLA", "PAKET AÇ". Ekranda EN FAZLA bir tane.
  primary,

  /// Koyu yeşil: "KARTI OYNA", "KAYDET"
  secondary,

  /// Nötr lacivert: "İPTAL", "TAKTİĞİ SIFIRLA"
  neutral,
}

/// OYUN BUTONU — basıldığında gerçekten "çöken" 3B buton.
///
/// ===================================================================
/// 3B BASMA NASIL ÇALIŞIYOR?
/// ===================================================================
/// Butonun altında [_kalinlik] piksellik koyu bir "kenar" var. Normalde
/// yüzey bu kenarın üstünde durur; parmak değince yüzey aşağı kayar ve
/// kenar görünmez olur. Göz bunu fiziksel bir tuşa basmak gibi algılar.
///
/// Material'in dalga (ripple) efekti burada kullanılmıyor: dalga
/// "uygulama" hissi verir, çöken tuş "oyun" hissi. Clash Royale ve
/// benzeri oyunların ortak dili bu.
///
/// ===================================================================
/// NEDEN AnimatedContainer DEĞİL DE TEK BİR Transform?
/// ===================================================================
/// Basma bir yerleşim (layout) değişikliği değil, sadece görsel kayma.
/// `Transform.translate` layout'u hiç tetiklemez; butonun etrafındaki
/// widget'lar yeniden ölçülmez. 140 ms'lik bir animasyon için önemsiz
/// görünür ama ekranda çok buton olduğunda fark eder.
///
/// ===================================================================
/// ERİŞİLEBİLİRLİK
/// ===================================================================
/// * En az 48 piksel yükseklik (parmakla isabet)
/// * `Semantics(button: true)`: ekran okuyucu "buton" der
/// * Pasifken soluk VE dokunulmaz; sadece soluk olsaydı oyuncu
///   neden çalışmadığını anlamazdı, o yüzden [disabledReason] var
class GameButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final GameButtonVariant variant;
  final IconData? icon;

  /// Yazının sonundaki ok/işaret (prototipteki "▶")
  final IconData? trailingIcon;

  /// İşlem sürüyor: buton kilitlenir, yazının yerine gösterge gelir
  final bool isLoading;

  /// Buton neden pasif? (uzun basınca ipucu olarak gösterilir)
  final String? disabledReason;

  /// Tam genişlik mi? (varsayılan: evet, telefon düzeni)
  final bool expand;

  const GameButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = GameButtonVariant.primary,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.disabledReason,
    this.expand = true,
  });

  const GameButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.disabledReason,
    this.expand = true,
  }) : variant = GameButtonVariant.secondary;

  const GameButton.neutral({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.disabledReason,
    this.expand = true,
  }) : variant = GameButtonVariant.neutral;

  bool get isEnabled => onPressed != null && !isLoading;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _basili = false;

  double get _kalinlik => widget.variant == GameButtonVariant.primary ? 4 : 3;

  void _bas(bool basili) {
    if (!widget.isEnabled || _basili == basili) return;
    setState(() => _basili = basili);
  }

  void _tikla() {
    if (!widget.isEnabled) return;
    GameFeedback.haptic(HapticStrength.selection);
    widget.onPressed!();
  }

  _Gorunum get _gorunum => switch (widget.variant) {
    GameButtonVariant.primary => const _Gorunum(
      gradient: AppGradients.cta,
      kenar: AppGradients.ctaEdge,
      yazi: Color(0xFF261705),
      cerceve: null,
      yaziBoyutu: 22,
      yukseklik: 56,
    ),
    GameButtonVariant.secondary => const _Gorunum(
      gradient: AppGradients.secondary,
      kenar: Color(0xFF022C22),
      yazi: Color(0xFFD1FAE5),
      cerceve: Color(0xFF10B981),
      yaziBoyutu: 17,
      yukseklik: 50,
    ),
    GameButtonVariant.neutral => const _Gorunum(
      gradient: LinearGradient(
        colors: [Color(0xFF1E293B), Color(0xFF162032)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      kenar: Color(0xFF0B1220),
      yazi: AppColors.textPrimary,
      cerceve: Color(0xFF334155),
      yaziBoyutu: 16,
      yukseklik: 48,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final g = _gorunum;
    final aktif = widget.isEnabled;
    final kayma = _basili ? _kalinlik : 0.0;

    Widget buton = SizedBox(
      height: g.yukseklik + _kalinlik,
      width: widget.expand ? double.infinity : null,
      child: Stack(
        children: [
          // ---- ALT KENAR (3B kalınlık) ----
          Positioned.fill(
            top: _kalinlik,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: g.kenar,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),

          // ---- YÜZEY ----
          AnimatedPositioned(
            duration: AppDurations.button,
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            top: kayma,
            height: g.yukseklik,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: g.gradient,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: g.cerceve == null
                    ? null
                    : Border.all(color: g.cerceve!.withValues(alpha: 0.6)),
                // Sadece altın buton parlıyor: ekrandaki "asıl eylem" o
                boxShadow: widget.variant == GameButtonVariant.primary && aktif
                    ? AppShadows.glow(AppColors.victoryGold, siddet: 0.6)
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Center(child: _icerik(g)),
              ),
            ),
          ),
        ],
      ),
    );

    buton = Opacity(opacity: aktif ? 1 : 0.42, child: buton);

    if (!aktif && widget.disabledReason != null && !widget.isLoading) {
      buton = Tooltip(message: widget.disabledReason!, child: buton);
    }

    return Semantics(
      button: true,
      enabled: aktif,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _bas(true),
        onTapUp: (_) => _bas(false),
        onTapCancel: () => _bas(false),
        onTap: _tikla,
        child: buton,
      ),
    );
  }

  Widget _icerik(_Gorunum g) {
    if (widget.isLoading) {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.6, color: g.yazi),
      );
    }

    final yaziStili = AppTypography.display(
      size: g.yaziBoyutu,
      weight: FontWeight.w900,
      color: g.yazi,
      letterSpacing: 1.0,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: g.yaziBoyutu, color: g.yazi),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: yaziStili,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Icon(widget.trailingIcon, size: g.yaziBoyutu, color: g.yazi),
        ],
      ],
    );
  }
}

/// Bir buton türünün görsel değerleri
class _Gorunum {
  final Gradient gradient;
  final Color kenar;
  final Color yazi;
  final Color? cerceve;
  final double yaziBoyutu;
  final double yukseklik;

  const _Gorunum({
    required this.gradient,
    required this.kenar,
    required this.yazi,
    required this.cerceve,
    required this.yaziBoyutu,
    required this.yukseklik,
  });
}
