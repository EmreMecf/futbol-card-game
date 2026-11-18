import 'package:flutter/material.dart';

import '../foundation/v21_assets.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_typography.dart';
import '../utilities/v21_format.dart';
import 'v21_chest_slot.dart';
import 'v21_game_panel.dart';
import 'v21_painters.dart';

/// V2.1 ÖDÜL KARTI (referans Zafer "ÖDÜLLERİN": 108×116 karo).
///
///   simge (çap 46)
///   +150          ← [value] (büyük beyaz; sandıkta altın "ALTIN")
///   ALTIN         ← [label] (soluk)
class V21RewardCard extends StatelessWidget {
  final Widget icon;
  final String value;
  final String label;
  final Color valueColor;
  final double scale;

  const V21RewardCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor = V21Colors.text,
    this.scale = 1,
  });

  /// Altın ödülü: "+150 ALTIN"
  factory V21RewardCard.coins(int amount, {Key? key, double scale = 1}) => V21RewardCard(
    key: key,
    icon: V21CoinIcon(size: 46 * scale),
    value: '+$amount',
    label: 'ALTIN',
    scale: scale,
  );

  /// Kupa (lig puanı) ödülü: "+25 KUPA"
  factory V21RewardCard.trophies(int amount, {Key? key, double scale = 1}) => V21RewardCard(
    key: key,
    icon: V21StarIcon(size: 46 * scale, color: const Color(0xFFFFD45E)),
    value: amount >= 0 ? '+$amount' : '$amount',
    label: 'KUPA',
    scale: scale,
  );

  /// Sandık ödülü: "ALTIN / SANDIK" ([typeName] sunucudan, ör. "Altın")
  factory V21RewardCard.chest(String typeName, {Key? key, double scale = 1}) => V21RewardCard(
    key: key,
    icon: Image.asset(V21Assets.chestGoldLarge, height: 54 * scale, fit: BoxFit.contain),
    value: V21Format.upper(typeName),
    label: 'SANDIK',
    valueColor: const Color(0xFFFFC832),
    scale: scale,
  );

  @override
  Widget build(BuildContext context) {
    final k = scale;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: SizedBox(
        width: 108 * k,
        height: 116 * k,
        child: V21GamePanel(
          scale: k,
          radius: 14,
          padding: EdgeInsets.fromLTRB(4 * k, 6 * k, 4 * k, 4 * k),
          child: Column(
            children: [
              SizedBox(
                height: 50 * k,
                child: Center(child: icon),
              ),
              SizedBox(height: 4 * k),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: V21Type.title(27 * k, color: valueColor, shadows: V21Type.inkShadow(k)),
                ),
              ),
              SizedBox(height: 2 * k),
              Text(
                label,
                maxLines: 1,
                style: V21Type.label(12 * k, weight: FontWeight.w700, color: const Color(0xFFB9A8E8)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// V2.1 SANDIK KARTI (referans Sandıklar yuvaları: 178×184).
///
///   büyük sandık görseli
///   GÜMÜŞ SANDIK       ← [name]
///   (⏱ 1:23:45)       ← [footer]: sayaçta yeşil hap, kilitliyken koyu hap
///
/// Ana sayfadaki küçük [V21ChestSlot] ile aynı durum kümesini kullanır.
class V21ChestCard extends StatelessWidget {
  final V21ChestSlotState state;
  final String? name;
  final String? footer;
  final VoidCallback? onTap;
  final String semanticsLabel;
  final double scale;

  const V21ChestCard({
    super.key,
    required this.state,
    required this.semanticsLabel,
    this.name,
    this.footer,
    this.onTap,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final Widget body;
    if (state == V21ChestSlotState.empty || state == V21ChestSlotState.loading) {
      body = V21GamePanel(
        style: state == V21ChestSlotState.empty ? V21PanelStyle.empty : V21PanelStyle.slot,
        radius: 14,
        scale: k,
        child: state == V21ChestSlotState.loading
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 40 * k, color: V21Colors.dash),
                  SizedBox(height: 8 * k),
                  Text(
                    'BOŞ YUVA',
                    style: V21Type.label(12 * k, weight: FontWeight.w800, color: V21Colors.textDim),
                  ),
                ],
              ),
      );
    } else {
      final unlocking = state == V21ChestSlotState.unlocking;
      final ready = state == V21ChestSlotState.ready;
      final pillColor = unlocking
          ? const Color(0xFF3CC24E)
          : ready
          ? const Color(0xFFFFB01B)
          : V21Colors.ink;
      final pillIcon = unlocking
          ? Icons.timer_rounded
          : ready
          ? Icons.lock_open_rounded
          : Icons.lock_rounded;
      body = Container(
        padding: EdgeInsets.fromLTRB(8 * k, 8 * k, 8 * k, 10 * k),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * k),
          border: Border.all(
            color: unlocking
                ? const Color(0xFF8BE38A)
                : ready
                ? V21Colors.goldTop
                : V21Colors.ink,
            width: 3 * k,
          ),
          gradient: const RadialGradient(
            center: Alignment(0, -0.3),
            radius: 0.9,
            colors: [Color(0xFF4A2BA8), Color(0xFF2A1470)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Image.asset(V21Assets.chestGoldLarge, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
            ),
            if (name != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(name!, maxLines: 1, style: V21Type.title(17 * k, shadows: V21Type.inkShadow(k * 0.8))),
              ),
            SizedBox(height: 6 * k),
            if (footer != null)
              Container(
                height: 27 * k,
                constraints: BoxConstraints(minWidth: 110 * k),
                padding: EdgeInsets.symmetric(horizontal: 12 * k),
                decoration: BoxDecoration(color: pillColor, borderRadius: BorderRadius.circular(27 * k)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(pillIcon, size: 15 * k, color: Colors.white.withValues(alpha: 0.9)),
                    SizedBox(width: 5 * k),
                    Text(footer!, style: V21Type.title(17 * k)),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(width: 178 * k, height: 184 * k, child: body),
      ),
    );
  }
}
