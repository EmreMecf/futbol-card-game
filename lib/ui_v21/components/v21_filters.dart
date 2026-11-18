import 'package:flutter/material.dart';

import '../animations/v21_motion.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import 'v21_match_widgets.dart';
import 'v21_tap.dart';

/// V2.1 SAYFA BAŞLIĞI (referans Koleksiyon: "KARTLARIM" 16..180 × 22..53,
/// sağda kaynak hapı). Sekme sayfalarında geri düğmesi yok.
class V21PageTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double scale;

  /// Verilirse başlığın solunda mavi geri düğmesi (referans Kadrom, Sandıklar)
  final VoidCallback? onBack;
  const V21PageTitle({super.key, required this.title, this.trailing, this.scale = 1, this.onBack});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Row(
      children: [
        if (onBack != null) ...[V21BackButton(onPressed: onBack!, scale: k), SizedBox(width: 10 * k)],
        Expanded(
          child: Semantics(
            header: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                style: V21Type.title(42 * k, letterSpacing: 0.4, shadows: V21Type.inkShadow(k * 1.4)),
              ),
            ),
          ),
        ),
        if (trailing != null) ...[SizedBox(width: 8 * k), trailing!],
      ],
    );
  }
}

/// Mor küre (koleksiyon sayacı simgesi)
class V21OrbIcon extends StatelessWidget {
  final double size;
  final Color color;
  const V21OrbIcon({super.key, this.size = 24, this.color = const Color(0xFFB170E4)});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: [Color.lerp(color, Colors.white, 0.55)!, color, Color.lerp(color, Colors.black, 0.35)!],
        stops: const [0, 0.55, 1],
      ),
    ),
  );
}

/// Filtre hapı.
///
///   * [color] null: altın dolgu ("TÜMÜ", seçiliyken parlak, değilken koyu)
///   * [color] verili: renkli kenarlı koyu hap ("GK", "DEF"…); seçiliyken
///     o renkle dolar
class V21FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  final String? semanticsLabel;
  final double scale;
  final double width;
  final double height;

  const V21FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.semanticsLabel,
    this.scale = 1,
    this.width = 81,
    this.height = 34,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final gold = color == null;
    final Color border;
    final Color textColor;
    final Gradient? gradient;
    final Color? fill;
    if (gold) {
      border = V21Colors.ink;
      textColor = selected ? Colors.white : V21Colors.textMuted;
      gradient = selected
          ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFED54C), Color(0xFFFF9B11)],
            )
          : null;
      fill = selected ? null : V21Colors.panel;
    } else {
      border = color!;
      textColor = selected ? Colors.white : color!;
      gradient = null;
      fill = selected ? color : const Color(0xFF2A1460);
    }
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      child: V21Tap(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: V21Motion.release,
          width: width * k,
          height: height * k,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            gradient: gradient,
            borderRadius: BorderRadius.circular(height * k),
            border: Border.all(color: border, width: 3 * k),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * k),
              child: Text(
                label,
                maxLines: 1,
                style: V21Type.title(
                  17 * k,
                  color: textColor,
                  letterSpacing: 0.6,
                  shadows: gold && selected
                      ? [Shadow(color: V21Colors.goldShadow, offset: Offset(0, 1.5 * k))]
                      : (selected ? V21Type.inkShadow(k * 0.5) : null),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nadirlik dairesi (referans çap 42, 3 px koyu halka, parlak merkez).
/// Seçiliyken halka beyaz olur ve hafif büyür.
class V21RarityChip extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String semanticsLabel;
  final double scale;
  const V21RarityChip({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.semanticsLabel,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final d = 42 * k;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: V21Tap(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: selected ? 1.08 : 1,
          duration: V21Motion.release,
          curve: V21Motion.bounce,
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? Colors.white : V21Colors.ink, width: 3 * k),
              gradient: RadialGradient(
                colors: [Colors.white, Color.lerp(color, Colors.white, 0.25)!, color],
                stops: const [0, 0.3, 1],
              ),
              boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 12 * k)] : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// V2.1 ARAMA KUTUSU: koyu hap, büyüteç, temizleme düğmesi.
/// (Referansta yok; kaynak hapı görünümü örnek alındı.)
class V21SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final double scale;
  final double height;

  const V21SearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.scale = 1,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final h = height * k;
    return Container(
      height: h,
      padding: EdgeInsets.only(left: 12 * k, right: 4 * k),
      decoration: BoxDecoration(
        color: V21Colors.pill,
        borderRadius: BorderRadius.circular(h),
        border: Border.all(color: V21Colors.pillBorder, width: 2 * k),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20 * k, color: V21Colors.textMuted),
          SizedBox(width: 6 * k),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: V21Colors.goldTop,
              style: V21Type.label(14 * k, weight: FontWeight.w700),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: V21Type.label(14 * k, weight: FontWeight.w600, color: V21Colors.textDim),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Aramayı temizle',
                    visualDensity: VisualDensity.compact,
                    iconSize: 18 * k,
                    color: V21Colors.textMuted,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Simgeli kare-hap düğme (favori filtresi, sıralama). Seçiliyken altın.
class V21IconPill extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String semanticsLabel;

  /// Simgenin yanında kısa sayı/metin ("3")
  final String? badge;
  final Color? iconColor;
  final double scale;
  final double height;

  const V21IconPill({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticsLabel,
    this.selected = false,
    this.badge,
    this.iconColor,
    this.scale = 1,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final h = height * k;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: V21Tap(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: V21Motion.release,
          height: h,
          constraints: BoxConstraints(minWidth: h * 1.15),
          padding: EdgeInsets.symmetric(horizontal: 10 * k),
          decoration: BoxDecoration(
            color: selected ? null : V21Colors.pill,
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFED54C), Color(0xFFFF9B11)],
                  )
                : null,
            borderRadius: BorderRadius.circular(h),
            border: Border.all(color: selected ? V21Colors.ink : V21Colors.pillBorder, width: 2 * k),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19 * k, color: selected ? Colors.white : (iconColor ?? V21Colors.textMuted)),
              if (badge != null) ...[
                SizedBox(width: 4 * k),
                Text(
                  badge!,
                  style: V21Type.title(
                    16 * k,
                    color: selected ? Colors.white : V21Colors.textMuted,
                    shadows: selected ? [Shadow(color: V21Colors.goldShadow, offset: Offset(0, 1.5 * k))] : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
