import 'package:material_ui/material_ui.dart';

import '../animations/v21_motion.dart';
import '../foundation/v21_assets.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_metrics.dart';
import '../foundation/v21_typography.dart';
import 'v21_game_panel.dart';
import 'v21_tap.dart';

/// Sandık yuvasının görünür durumu (sunucu durumundan türetilir)
enum V21ChestSlotState {
  /// Yuva boş: kesikli kenar + "+"
  empty,

  /// Kapalı; açmak için süre başlatılabilir
  sealed,

  /// Sayaç çalışıyor
  unlocking,

  /// Açılmaya hazır (nabız)
  ready,

  /// Veri yükleniyor (iskelet)
  loading,
}

/// V2.1 SANDIK YUVASI (referans 87×91, üstünde 12 px etiket).
///
///   AÇILIYOR        ← [label]
///  ┌─────────┐
///  │ sandık  │      ← kenar rengi: [accent]
///  │ 1:23:45 │      ← [footer] (sayaç yeşil, süre beyaz)
///  └─────────┘
class V21ChestSlot extends StatelessWidget {
  final V21ChestSlotState state;

  /// Yuvanın üstündeki büyük harf etiket ("ALTIN", "AÇILIYOR")
  final String? label;

  /// Alt hap metni ("1:23:45", "6 sa", "AÇ!")
  final String? footer;

  /// Kenar rengi (sandık türü / durum)
  final Color accent;
  final VoidCallback? onTap;
  final String semanticsLabel;
  final double scale;

  const V21ChestSlot({
    super.key,
    required this.state,
    required this.semanticsLabel,
    this.label,
    this.footer,
    this.accent = V21Colors.rarityGold,
    this.onTap,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final labelH = V21Metrics.chestLabelHeight * k;
    final slotH = V21Metrics.chestSlotHeight * k;

    final Widget slot = switch (state) {
      V21ChestSlotState.empty => V21GamePanel(
        style: V21PanelStyle.empty,
        scale: k,
        child: Center(
          child: Icon(Icons.add_rounded, size: 26 * k, color: V21Colors.dash),
        ),
      ),
      V21ChestSlotState.loading => V21GamePanel(style: V21PanelStyle.slot, scale: k, accent: V21Colors.panelHigh),
      V21ChestSlotState.ready => V21Pulse(
        builder: (context, t) => _filled(k, glow: 0.4 + 0.6 * t, footerColor: V21Colors.goldTop),
      ),
      V21ChestSlotState.unlocking => _filled(k, footerColor: V21Colors.successText),
      V21ChestSlotState.sealed => _filled(k, footerColor: V21Colors.text),
    };

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: V21Tap(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: labelH,
              child: label == null
                  ? null
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label!,
                        maxLines: 1,
                        style: V21Type.label(
                          10 * k,
                          weight: FontWeight.w900,
                          color: const Color(0xFFE8E0FF),
                          letterSpacing: 0.2,
                          shadows: V21Type.inkShadow(k * 0.5),
                        ),
                      ),
                    ),
            ),
            SizedBox(height: 2 * k),
            SizedBox(height: slotH, child: slot),
          ],
        ),
      ),
    );
  }

  Widget _filled(double k, {double glow = 0, required Color footerColor}) => V21GamePanel(
    style: V21PanelStyle.slot,
    accent: accent,
    glow: glow,
    scale: k,
    padding: EdgeInsets.fromLTRB(4 * k, 1 * k, 4 * k, 5 * k),
    child: Column(
      children: [
        Expanded(
          child: Image.asset(
            V21Assets.chestGold,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            // Türlere göre ton: gümüş/bronz sandık için hafif renk süzgeci
            color: _tint,
            colorBlendMode: _tint == null ? null : BlendMode.modulate,
          ),
        ),
        Container(
          height: 25 * k,
          width: double.infinity,
          decoration: BoxDecoration(color: V21Colors.ink, borderRadius: BorderRadius.circular(6 * k)),
          alignment: Alignment.center,
          child: footer == null
              ? null
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    footer!,
                    maxLines: 1,
                    style: V21Type.label(13 * k, weight: FontWeight.w900, color: footerColor),
                  ),
                ),
        ),
      ],
    ),
  );

  /// Referansta yalnız altın sandık görseli var; diğer türler renk süzgeci
  /// ile ayrışır (tasarımcıdan tür başına görsel bekleniyor).
  Color? get _tint => switch (accent) {
    V21Colors.raritySilver => const Color(0xFFD8E4F0),
    V21Colors.rarityBronze => const Color(0xFFE8B48E),
    _ => null,
  };
}
