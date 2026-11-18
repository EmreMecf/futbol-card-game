import 'package:flutter/material.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_metrics.dart';
import '../foundation/v21_typography.dart';
import '../utilities/v21_format.dart';
import 'v21_painters.dart';
import 'v21_tap.dart';

/// Kaynak hapı (altın, elmas, kart sayısı…). Referans (268..388 × 18..54).
///
/// [value] null ise sayı yerine "—" (yükleniyor / bilinmiyor): uydurma
/// sayı gösterilmez.
class V21ResourcePill extends StatelessWidget {
  final Widget icon;
  final int? value;
  final String semanticsName;
  final VoidCallback? onTap;
  final double scale;

  /// Hap genişliği (390 tuvalde). Null: içeriğe göre.
  final double? width;

  /// Sayı yerine hazır metin ("12 / 100"). Verilirse [value] kullanılmaz.
  final String? text;

  /// Ekran okuyucu metni ([text] verildiğinde)
  final String? semanticsLabel;

  const V21ResourcePill({
    super.key,
    required this.icon,
    required this.value,
    required this.semanticsName,
    this.onTap,
    this.scale = 1,
    this.width,
    this.text,
    this.semanticsLabel,
  });

  /// Altın parası hapı
  factory V21ResourcePill.coins({Key? key, required int? coins, VoidCallback? onTap, double scale = 1}) =>
      V21ResourcePill(
        key: key,
        icon: V21CoinIcon(size: 24 * scale),
        value: coins,
        semanticsName: 'altın',
        onTap: onTap,
        scale: scale,
        width: 117,
      );

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final h = V21Metrics.resourcePillHeight * k;
    final text = this.text ?? (value == null ? '—' : V21Format.thousands(value!));
    return Semantics(
      button: onTap != null,
      label:
          semanticsLabel ?? (this.text == null && value == null ? '$semanticsName yükleniyor' : '$text $semanticsName'),
      excludeSemantics: true,
      child: V21Tap(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: h,
          width: width == null ? null : width! * k,
          padding: EdgeInsets.only(left: 6 * k, right: 12 * k),
          decoration: BoxDecoration(
            color: V21Colors.pill,
            borderRadius: BorderRadius.circular(h),
            border: Border.all(color: V21Colors.pillBorder, width: 2 * k),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6 * k, offset: Offset(0, 2 * k)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 2 * k),
              icon,
              SizedBox(width: 8 * k),
              Expanded(
                flex: width == null ? 0 : 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    text,
                    maxLines: 1,
                    style: V21Type.title(22 * k, letterSpacing: 0.4, shadows: V21Type.inkShadow(k * 0.7)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
