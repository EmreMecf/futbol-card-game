import 'package:flutter/material.dart';

import '../foundation/v21_assets.dart';
import '../foundation/v21_colors.dart';
import '../foundation/v21_metrics.dart';
import '../foundation/v21_typography.dart';
import 'v21_painters.dart';

/// Alt menü maddesi
@immutable
class V21NavItem {
  final String label;

  /// Simge (boyut verilir). Etkin karoda daha büyük çizilir.
  final Widget Function(double size) icon;
  final String route;

  const V21NavItem({required this.label, required this.icon, required this.route});
}

/// V2.1 ALT MENÜ (referans 764..844; etkin karo 752'den başlar).
///
/// Referans sırası: KARTLAR · KADRO · ARENA · MAĞAZA · SEZON. Ana sayfa
/// = ARENA (ortadaki karo). Etkin madde mavi, menü çizgisinin 12 px
/// üstüne taşan karo olarak çizilir.
class V21BottomNavigation extends StatelessWidget {
  final List<V21NavItem> items;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final double scale;

  const V21BottomNavigation({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onSelect,
    this.scale = 1,
  });

  /// Referanstaki beş madde. Rotalar çağırandan gelir (bağımsız katman).
  static List<V21NavItem> standardItems({
    required String cards,
    required String squad,
    required String arena,
    required String store,
    required String season,
  }) => [
    V21NavItem(
      label: 'KARTLAR',
      route: cards,
      icon: (s) => V21CardStackIcon(size: s * 1.2),
    ),
    V21NavItem(label: 'KADRO', route: squad, icon: (s) => _RoundArt(V21Assets.navSquadPortrait, s)),
    V21NavItem(label: 'ARENA', route: arena, icon: (s) => _RoundArt(V21Assets.navArenaStadium, s)),
    V21NavItem(
      label: 'MAĞAZA',
      route: store,
      icon: (s) => Image.asset(V21Assets.chestGold, width: s * 1.3, height: s * 1.15, fit: BoxFit.contain),
    ),
    V21NavItem(
      label: 'SEZON',
      route: season,
      icon: (s) => V21StarIcon(size: s * 0.8),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barH = V21Metrics.navHeight * k;
    final rise = V21Metrics.navActiveRise * k;

    return SizedBox(
      height: barH + rise + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Zemin + üst çizgi
          Positioned(
            left: 0,
            right: 0,
            top: rise,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: V21Colors.navLine, width: 3 * k),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [V21Colors.navTop, V21Colors.navBottom],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: bottomInset,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: V21Metrics.maxContentWidth * k),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _NavButton(item: items[i], active: i == activeIndex, scale: k, onTap: () => onSelect(i)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final V21NavItem item;
  final bool active;
  final double scale;
  final VoidCallback onTap;

  const _NavButton({required this.item, required this.active, required this.scale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final rise = V21Metrics.navActiveRise * k;
    final labelStyle = V21Type.label(
      (active ? 12 : 10) * k,
      weight: FontWeight.w900,
      color: active ? Colors.white : V21Colors.navLabel,
      letterSpacing: 0.2,
      shadows: active ? V21Type.inkShadow(k * 0.6, color: const Color(0xFF123E9A)) : null,
    );

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: (active ? 48 : 44) * k,
          child: Center(child: item.icon((active ? 46 : 36) * k)),
        ),
        SizedBox(height: (active ? 4 : 6) * k),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(item.label, maxLines: 1, style: labelStyle),
        ),
      ],
    );

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: active
            ? Padding(
                padding: EdgeInsets.fromLTRB(1 * k, 0, 1 * k, 6 * k),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14 * k),
                    border: Border.all(color: V21Colors.navActiveBorder, width: 2 * k),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [V21Colors.navActiveTop, V21Colors.navActiveBottom],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8 * k,
                        offset: Offset(0, 3 * k),
                      ),
                    ],
                  ),
                  child: content,
                ),
              )
            : Padding(
                padding: EdgeInsets.only(top: rise + 4 * k, bottom: 6 * k),
                child: content,
              ),
      ),
    );
  }
}

/// Daire kırpılmış görsel + koyu halka (KADRO, ARENA)
class _RoundArt extends StatelessWidget {
  final String asset;
  final double size;
  const _RoundArt(this.asset, this.size);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: EdgeInsets.all(size * 0.06),
    decoration: const BoxDecoration(color: V21Colors.ink, shape: BoxShape.circle),
    child: ClipOval(
      child: Image.asset(asset, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
    ),
  );
}
