import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/app_typography.dart';

/// Ana gezinme hedefi.
class NavDestination {
  final String label;
  final IconData icon;
  final String route;

  /// Sadece masaüstü kenar çubuğunda görünür.
  ///
  /// Telefonda alt çubuk 5 maddeyi geçmemeli; fazlası dokunma
  /// hedeflerini 44px'in altına düşürür.
  final bool sidebarOnly;

  const NavDestination({
    required this.label,
    required this.icon,
    required this.route,
    this.sidebarOnly = false,
  });
}

const kNavDestinations = <NavDestination>[
  NavDestination(
    label: 'Ana Sayfa',
    icon: Icons.home_rounded,
    route: AppRoutes.home,
  ),
  NavDestination(
    label: 'Kadrom',
    icon: Icons.grid_view_rounded,
    route: AppRoutes.deck,
  ),
  NavDestination(
    label: 'Maç',
    icon: Icons.sports_soccer_rounded,
    route: AppRoutes.matchmaking,
  ),
  NavDestination(
    label: 'Mağaza',
    icon: Icons.storefront_rounded,
    route: AppRoutes.store,
  ),
  NavDestination(
    label: 'Profil',
    icon: Icons.person_rounded,
    route: AppRoutes.profile,
  ),
  NavDestination(
    label: 'Koleksiyon',
    icon: Icons.style_rounded,
    route: AppRoutes.collection,
    sidebarOnly: true,
  ),
  NavDestination(
    label: 'Görevler',
    icon: Icons.checklist_rounded,
    route: AppRoutes.sbc,
    sidebarOnly: true,
  ),
  NavDestination(
    label: 'Liderlik',
    icon: Icons.emoji_events_rounded,
    route: AppRoutes.leaderboard,
    sidebarOnly: true,
  ),
];

/// Ana ekranların ortak çerçevesi.
///
/// ===================================================================
/// TEK WIDGET, İKİ YERLEŞİM
/// ===================================================================
/// Telefonda ALT SEKME ÇUBUĞU çizilir: beş madde, ortadaki maç butonu
/// yukarı taşar. Baş parmağın rahat ulaştığı bölge ekranın altıdır;
/// en çok basılan buton oraya konulmalı.
///
/// Masaüstünde SOL KENAR ÇUBUĞU çizilir: alt çubuk 1440px genişlikte
/// ekranın tamamına yayılıp absürt görünürdü. Kenar çubuğunda ayrıca
/// telefona sığmayan Koleksiyon ve Görevler de yer buluyor.
///
/// Tablet ikisinin arasında: alt çubuk, ama geniş içerik.
class AppShell extends StatelessWidget {
  /// Şu an açık olan rota. Hangi maddenin vurgulanacağını belirler.
  final String currentRoute;

  final Widget child;

  /// Üstte sabit duracak başlık şeridi (isteğe bağlı)
  final PreferredSizeWidget? appBar;

  /// Gezinme çubuğu gizlensin mi?
  /// İç ekranlarda (paket açılışı, maç) tam ekran gerekiyor.
  final bool showNavigation;

  const AppShell({
    super.key,
    required this.currentRoute,
    required this.child,
    this.appBar,
    this.showNavigation = true,
  });

  @override
  Widget build(BuildContext context) {
    final boyut = AppBreakpoints.of(context);

    if (!showNavigation) {
      return Scaffold(appBar: appBar, body: child);
    }

    if (boyut.usesSidebar) {
      return Scaffold(
        body: Row(
          children: [
            _KenarCubugu(currentRoute: currentRoute),
            Expanded(
              child: Column(
                children: [
                  ?appBar,
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      // extendBody: alt çubuk yuvarlak ve kenarlardan boşluklu olduğu
      // için arkasındaki içerik görünsün; kart listesi çubuğun altına
      // doğru kayarken kesilmiş gibi durmasın.
      extendBody: true,
      body: child,
      bottomNavigationBar: _AltCubuk(currentRoute: currentRoute),
    );
  }
}

// ====================================================================
// MASAÜSTÜ: SOL KENAR ÇUBUĞU
// ====================================================================
class _KenarCubugu extends StatelessWidget {
  final String currentRoute;

  const _KenarCubugu({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppBreakpoints.sidebarWidth,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.surfaceLight)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- LOGO ----
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sports_soccer,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'FUTBOL\nKART',
                      style: AppTypography.display(
                        size: 18,
                        weight: FontWeight.w900,
                        letterSpacing: 1.0,
                        height: 0.95,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---- MADDELER ----
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final hedef in kNavDestinations)
                    _KenarMaddesi(
                      destination: hedef,
                      isActive: currentRoute == hedef.route,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KenarMaddesi extends StatelessWidget {
  final NavDestination destination;
  final bool isActive;

  const _KenarMaddesi({required this.destination, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isActive ? null : () => context.go(destination.route),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  size: 20,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    style: AppTypography.body(
                      size: 14,
                      weight: isActive ? FontWeight.w800 : FontWeight.w700,
                      color: isActive
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// TELEFON: ALT SEKME ÇUBUĞU
// ====================================================================
class _AltCubuk extends StatelessWidget {
  final String currentRoute;

  const _AltCubuk({required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final maddeler = kNavDestinations.where((h) => !h.sidebarOnly).toList();

    // Ortadaki madde yükselen maç butonu olur.
    final ortaIndex = maddeler.length ~/ 2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: SafeArea(
        top: false,
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.surfaceLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < maddeler.length; i++)
                Expanded(
                  child: i == ortaIndex
                      ? _OrtaButon(
                          destination: maddeler[i],
                          isActive: currentRoute == maddeler[i].route,
                        )
                      : _AltMadde(
                          destination: maddeler[i],
                          isActive: currentRoute == maddeler[i].route,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AltMadde extends StatelessWidget {
  final NavDestination destination;
  final bool isActive;

  const _AltMadde({required this.destination, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final renk = isActive ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isActive ? null : () => context.go(destination.route),
      // 68px yükseklik + eşit genişlik: dokunma hedefi 44px'in üzerinde.
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(destination.icon, size: 22, color: renk),
          const SizedBox(height: 4),
          Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(
              size: 10,
              weight: isActive ? FontWeight.w800 : FontWeight.w700,
              color: renk,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ortadaki yükselen maç butonu.
///
/// Çubuğun dışına taştığı için [Stack] ile `clipBehavior: Clip.none`
/// kullanılıyor; aksi halde taşan yarım daire kesilirdi.
class _OrtaButon extends StatelessWidget {
  final NavDestination destination;
  final bool isActive;

  const _OrtaButon({required this.destination, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isActive ? null : () => context.go(destination.route),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -22,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.sports_soccer,
                size: 26,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            child: Text(
              destination.label,
              style: AppTypography.body(size: 10, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
