import 'package:flutter/material.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_metrics.dart';
import 'v21_painters.dart';

/// Panel görünümü
enum V21PanelStyle {
  /// Mor oyun paneli, alt dudaklı (referans `.gameCard`)
  raised,

  /// Düz koyu yuva (sandık yuvası, liste satırı)
  slot,

  /// Kesikli kenar: boş yuva / eklenebilir alan
  empty,
}

/// V2.1 OYUN PANELİ — kartların, yuvaların ve kutuların ortak zemini.
///
/// [accent] verilirse kenar o renkte kalınlaşır (seçili, durum rengi).
class V21GamePanel extends StatelessWidget {
  final Widget? child;
  final V21PanelStyle style;
  final Color? accent;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double scale;

  /// Dış parıltı (hazır sandık nabzı gibi) 0..1
  final double glow;

  const V21GamePanel({
    super.key,
    this.child,
    this.style = V21PanelStyle.raised,
    this.accent,
    this.radius = V21Metrics.radiusM,
    this.padding = EdgeInsets.zero,
    this.scale = 1,
    this.glow = 0,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final r = radius * k;
    if (style == V21PanelStyle.empty) {
      return CustomPaint(
        painter: V21DashedRRectPainter(
          color: accent ?? V21Colors.dash,
          radius: r,
          strokeWidth: 2.5 * k,
          dash: 7 * k,
          gap: 5 * k,
        ),
        child: Container(
          margin: EdgeInsets.all(2.5 * k),
          padding: padding,
          decoration: BoxDecoration(color: V21Colors.panelEmpty, borderRadius: BorderRadius.circular(r - 2 * k)),
          child: child,
        ),
      );
    }

    final raised = style == V21PanelStyle.raised;
    final border = accent ?? (raised ? const Color(0xFF7B56C9) : V21Colors.ink);
    final glowShadow = glow > 0 && accent != null
        ? BoxShadow(
            color: accent!.withValues(alpha: 0.55 * glow),
            blurRadius: 14 * k,
            spreadRadius: 1 * k,
          )
        : null;
    final face = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: border, width: (accent != null ? 3 : 2) * k),
        gradient: raised
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xF24E2FA7), Color(0xED291365)],
              )
            : null,
        color: raised ? null : V21Colors.panel,
        boxShadow: raised ? null : [?glowShadow],
      ),
      child: child,
    );
    if (!raised) return face;
    // Yükseltilmiş panel: 5 px koyu alt dudak (referans border-bottom:5px)
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF271463),
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(color: const Color(0x80180B3F), blurRadius: 20 * k, offset: Offset(0, 12 * k)),
          ?glowShadow,
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: 4 * k),
        child: face,
      ),
    );
  }
}
