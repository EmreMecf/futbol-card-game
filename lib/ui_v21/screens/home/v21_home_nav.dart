import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/router/app_routes.dart';
import '../../components/v21_bottom_navigation.dart';
import '../../components/v21_side_navigation.dart';
import '../../layouts/v21_screen_layout.dart';
import '../../../core/l10n/app_language.dart';

/// V2.1 alt menüsünün uygulama rotalarına bağlanmış hâli.
///
/// Referans: KARTLAR · KADRO · ARENA · MAĞAZA · SEZON. "ARENA" ana
/// sayfadır (maça başlama düğmesi orada).
class V21HomeNav extends StatelessWidget {
  final String currentRoute;
  final double scale;

  /// İç ekranlarda vurgulanacak üst sekme (ör. Gelişim → KARTLAR). Null ise
  /// [currentRoute] bir sekmeyse o vurgulanır, değilse hiçbiri.
  final String? highlightRoute;
  const V21HomeNav({super.key, required this.currentRoute, this.scale = 1, this.highlightRoute});

  /// Getter: etiketler her çizimde oyuncunun dilinde okunur
  static List<V21NavItem> get items => V21BottomNavigation.standardItems(
    cards: AppRoutes.collection,
    squad: AppRoutes.deck,
    arena: AppRoutes.home,
    store: AppRoutes.store,
    season: AppRoutes.season,
  );

  /// Geniş ekranda yan menüde görünen ek sayfalar
  static List<V21SideLink> get sideLinks => [
    V21SideLink(label: 'SANDIKLAR'.tr, icon: Icons.inventory_2_rounded, route: AppRoutes.chests),
    V21SideLink(label: 'SIRALAMA'.tr, icon: Icons.leaderboard_rounded, route: AppRoutes.leaderboard),
    V21SideLink(label: 'KART TAKASI'.tr, icon: Icons.swap_horiz_rounded, route: AppRoutes.sbc),
    V21SideLink(label: 'ARKADAŞLAR'.tr, icon: Icons.people_alt_rounded, route: AppRoutes.social),
    V21SideLink(label: 'ARKADAŞ MAÇI'.tr, icon: Icons.group_add_rounded, route: AppRoutes.friends),
    V21SideLink(label: 'PROFİL'.tr, icon: Icons.person_rounded, route: AppRoutes.profile),
    V21SideLink(label: 'AYARLAR'.tr, icon: Icons.settings_rounded, route: AppRoutes.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final active = items.indexWhere((i) => i.route == (highlightRoute ?? currentRoute));
    void select(int i) {
      final route = items[i].route;
      if (route == currentRoute) return;
      GameAudio.sfx(Sfx.tab);
      context.go(route);
    }

    if (V21NavPlacement.isSide(context)) {
      return V21SideNavigation(
        items: items,
        activeIndex: active,
        onSelect: select,
        links: sideLinks,
        activeLink: currentRoute,
        onLink: (l) {
          if (l.route == currentRoute) return;
          GameAudio.sfx(Sfx.tab);
          context.go(l.route);
        },
      );
    }
    return V21BottomNavigation(items: items, activeIndex: active, scale: scale, onSelect: select);
  }
}
