import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../components/v21_bottom_navigation.dart';
import '../../v21_flags.dart';

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

  static final List<V21NavItem> items = V21BottomNavigation.standardItems(
    cards: AppRoutes.collection,
    squad: AppRoutes.deck,
    arena: AppRoutes.home,
    store: AppRoutes.store,
    season: AppRoutes.season,
  );

  @override
  Widget build(BuildContext context) {
    final active = items.indexWhere((i) => i.route == (highlightRoute ?? currentRoute));
    return V21BottomNavigation(
      items: items,
      activeIndex: active,
      scale: scale,
      onSelect: (i) {
        final route = items[i].route;
        if (route == currentRoute) return;
        // V2.1'de Sezon da bir sekme (go); eski Sezon ekranı push ile açılıyordu
        if (route == AppRoutes.season && !kV21Season) {
          context.push(route);
        } else {
          context.go(route);
        }
      },
    );
  }
}
