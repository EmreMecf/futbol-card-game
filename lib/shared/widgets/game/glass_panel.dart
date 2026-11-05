import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/feedback/game_feedback.dart';
import '../../../core/theme/app_tokens.dart';

/// CAM PANEL — oyun arayüzünün temel kutusu.
///
/// ===================================================================
/// BLUR VARSAYILAN OLARAK KAPALI. NEDEN?
/// ===================================================================
/// Gerçek "buzlu cam" efekti `BackdropFilter` ile yapılır. Ama bu
/// filtre, panelin ARKASINDAKİ her pikseli her karede yeniden okuyup
/// bulanıklaştırır. Ekranda 5-6 cam panel varken orta seviye bir
/// Android telefonda 60 FPS'i tek başına düşürebilir. (MD madde 3:
/// "Düşük cihazlarda optimize edilmiş efektler".)
///
/// Cam hissinin %90'ı aslında bulanıklıktan değil şu üçünden geliyor:
///   1. Yarı saydam, köşeden köşeye hafif degrade zemin
///   2. Üst kenarda ince, açık bir "ışık çizgisi"
///   3. Yumuşak bir gölge
///
/// Bu üçü bedava. Bulanıklık sadece arkasında gerçekten hareketli
/// içerik olan yerlerde (ör. maç sahası üstündeki HUD) `blur: true` ile
/// açılmalı; o durumda bile oyuncu ayarlardan kart animasyonlarını
/// kapattıysa kendiliğinden kapanır.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Kenarlık rengi (vurgu: seçili, ödül, tehlike)
  final Color? accentColor;

  /// Gerçek arka plan bulanıklığı. Bkz. sınıf açıklaması — pahalı.
  final bool blur;

  /// Vurgu rengiyle hafif ışık saçar (seçili görev, aktif lig)
  final bool glow;

  final VoidCallback? onTap;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.lg,
    this.accentColor,
    this.blur = false,
    this.glow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final kenar = accentColor ?? AppColors.surfaceLight;
    final kose = BorderRadius.circular(radius);

    Widget panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: kose,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B2740).withValues(alpha: blur ? 0.72 : 0.96),
            AppColors.deepNavy.withValues(alpha: blur ? 0.66 : 0.96),
          ],
        ),
        border: Border.all(
          color: kenar.withValues(alpha: accentColor == null ? 1 : 0.55),
        ),
        boxShadow: [
          ...AppShadows.panel,
          if (glow && accentColor != null)
            ...AppShadows.glow(accentColor!, siddet: 0.5),
        ],
      ),
      child: child,
    );

    // ---- ÜST IŞIK ÇİZGİSİ ----
    // Camın tepesine vuran ışık. Tek başına "cam" hissinin yarısı.
    // passthrough: Stack, ebeveynin kisitlarini panele AYNEN gecirir.
    // Varsayilan (loose) ile panel icerigi kadar daraliyordu; kisa bir
    // yazi iceren panel ekranin yarisinda kaliyordu.
    panel = Stack(
      fit: StackFit.passthrough,
      children: [
        panel,
        Positioned(
          top: 0,
          left: radius,
          right: radius,
          height: 1,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (blur && GameFeedback.cardAnimationsEnabled) {
      panel = ClipRRect(
        borderRadius: kose,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: panel,
        ),
      );
    }

    if (onTap == null) return panel;

    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: kose, onTap: onTap, child: panel),
    );
  }
}
