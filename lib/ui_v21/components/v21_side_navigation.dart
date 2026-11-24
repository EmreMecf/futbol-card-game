import 'package:material_ui/material_ui.dart';

import '../foundation/v21_colors.dart';
import '../foundation/v21_metrics.dart';
import '../foundation/v21_typography.dart';
import 'v21_bottom_navigation.dart';
import 'v21_tap.dart';

/// Yan menünün ikincil maddesi (Sandıklar, Sıralama, Profil...)
@immutable
class V21SideLink {
  final String label;
  final IconData icon;
  final String route;
  const V21SideLink({required this.label, required this.icon, required this.route});
}

/// V2.1 YAN MENÜ: yatay tablet ve masaüstü webde alt menünün yerini alır.
/// Kısa pencerede kaydırılır; hiçbir madde kesilmez.
class V21SideNavigation extends StatelessWidget {
  final List<V21NavItem> items;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final List<V21SideLink> links;
  final String? activeLink;
  final ValueChanged<V21SideLink> onLink;

  const V21SideNavigation({
    super.key,
    required this.items,
    required this.activeIndex,
    required this.onSelect,
    required this.links,
    required this.onLink,
    this.activeLink,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: V21Colors.navLine, width: 2)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [V21Colors.navTop, V21Colors.navBottom],
        ),
      ),
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          children: [
            Text('FUTBOL', textAlign: TextAlign.center, style: V21Type.title(25, shadows: V21Type.inkShadow(1))),
            Text(
              'CARD ARENA',
              textAlign: TextAlign.center,
              style: V21Type.title(20, color: V21Colors.goldTop, shadows: V21Type.inkShadow(1)),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < items.length; i++)
              _Satir(
                label: items[i].label,
                icon: SizedBox(width: 34, height: 34, child: Center(child: items[i].icon(30))),
                active: i == activeIndex,
                onTap: () => onSelect(i),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: V21Colors.pillBorder),
            ),
            for (final l in links)
              _Satir(
                label: l.label,
                icon: SizedBox(width: 34, height: 28, child: Icon(l.icon, size: 22, color: V21Colors.navLabel)),
                active: l.route == activeLink,
                onTap: () => onLink(l),
              ),
          ],
        ),
      ),
    );
  }
}

class _Satir extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool active;
  final VoidCallback onTap;
  const _Satir({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: V21Tap(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(V21Metrics.radiusM),
            border: active ? Border.all(color: V21Colors.navActiveBorder, width: 2) : null,
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [V21Colors.navActiveTop, V21Colors.navActiveBottom],
                  )
                : null,
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V21Type.label(13, weight: FontWeight.w900, color: active ? Colors.white : V21Colors.navLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
