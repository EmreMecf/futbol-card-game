import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth/session_manager.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_breakpoints.dart';
import '../../core/theme/ref_tokens.dart';
import 'ref/ref_ui.dart';

/// Ana gezinme hedefi.
class NavDestination {
  final String label;

  /// Referanstaki sembol (⌂ ▣ ♟ ⚔ ▤)
  final RefGlyph glyph;

  /// Masaüstü kenar çubuğundaki emoji/sembol (referans .navbtn .ico)
  final String sideIcon;
  final String route;

  /// Sadece masaüstü kenar çubuğunda görünür (telefonda 5 madde sınırı)
  final bool sidebarOnly;

  const NavDestination({
    required this.label,
    required this.glyph,
    required this.sideIcon,
    required this.route,
    this.sidebarOnly = false,
  });
}

/// Referans .bottom-nav sırası: Ana Sayfa, Kartlar, Kadrom, Arena, Mağaza.
/// Profil telefonda üst başlıktaki ☻ düğmesinden açılır (referanstaki gibi).
const kNavDestinations = <NavDestination>[
  NavDestination(label: 'Ana Sayfa', glyph: RefGlyph.home, sideIcon: '⌂', route: AppRoutes.home),
  NavDestination(label: 'Kartlar', glyph: RefGlyph.cards, sideIcon: '▣', route: AppRoutes.collection),
  NavDestination(label: 'Kadrom', glyph: RefGlyph.pawn, sideIcon: '♟', route: AppRoutes.deck),
  NavDestination(label: 'Arena', glyph: RefGlyph.swords, sideIcon: '⚔', route: AppRoutes.matchmaking),
  NavDestination(label: 'Mağaza', glyph: RefGlyph.shop, sideIcon: '▤', route: AppRoutes.store),
  NavDestination(
      label: 'Ligler / Sıralama', glyph: RefGlyph.sparkle, sideIcon: '♛', route: AppRoutes.leaderboard, sidebarOnly: true),
  NavDestination(label: 'Görevler', glyph: RefGlyph.sparkle, sideIcon: '✓', route: AppRoutes.sbc, sidebarOnly: true),
  NavDestination(label: 'Profil', glyph: RefGlyph.smile, sideIcon: '♙', route: AppRoutes.profile, sidebarOnly: true),
];

/// Ana ekranların ortak çerçevesi — referans telefon kabuğu.
///
/// TELEFON / TABLET (referans .phone):
///   .phone-header  logo + para birimi + profil düğmesi
///   .screen        sayfa (dikey kaydırılır)
///   .bottom-nav    5 eşit sütun, etkin madde yeşil zeminli
///
/// MASAÜSTÜ: referans tasarım stüdyosunun sol kenar çubuğu (.sidebar,
/// .navbtn) + aynı üst başlık. Telefon çerçevesi ÇİZİLMEZ (kullanıcının
/// kuralı: çerçeve sadece önizleme aracı).
class AppShell extends StatelessWidget {
  final String currentRoute;
  final Widget child;
  final PreferredSizeWidget? appBar;

  /// İç ekranlarda (paket açılışı, maç) tam ekran gerekiyor
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
      return Scaffold(backgroundColor: Ref.phoneBg, appBar: appBar, body: child);
    }

    final govde = Column(
      children: [
        ?appBar,
        Expanded(child: child),
      ],
    );

    if (boyut.usesSidebar) {
      return Scaffold(
        backgroundColor: Ref.workspaceBg,
        body: Row(
          children: [
            RefSidebar(currentRoute: currentRoute),
            Expanded(
              child: Column(
                children: [
                  RefPhoneHeader(currentRoute: currentRoute, showLogo: false),
                  Expanded(child: govde),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Ref.phoneBg,
      body: Column(
        children: [
          RefPhoneHeader(currentRoute: currentRoute),
          Expanded(child: govde),
        ],
      ),
      bottomNavigationBar: RefBottomNav(currentRoute: currentRoute),
    );
  }
}

/// Oturum yoksa (testler, giriş öncesi) null
SessionManager? _oturum(BuildContext c) {
  try {
    return Provider.of<SessionManager>(c);
  } on ProviderNotFoundException {
    return null;
  }
}

// ====================================================================
// .phone-header { padding:10px 15px; background:linear-gradient(#101f31,#0b1728) }
// ====================================================================
class RefPhoneHeader extends StatelessWidget {
  final String currentRoute;
  final bool showLogo;

  const RefPhoneHeader({super.key, required this.currentRoute, this.showLogo = true});

  @override
  Widget build(BuildContext context) {
    final kullanici = _oturum(context)?.user;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Ref.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            children: [
              if (showLogo)
                // .logo-small { font: italic 900 20px Barlow; line-height:1 }
                Expanded(
                  child: GestureDetector(
                    onTap: currentRoute == AppRoutes.home ? null : () => context.go(AppRoutes.home),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Em('⚽', size: 20),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'FUTBOL CARD',
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: Ref.heading(20, weight: FontWeight.w900, height: 1)
                                .copyWith(fontStyle: FontStyle.italic, letterSpacing: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!showLogo) const Spacer(),
              // .currencies { gap:5px }
              Semantics(
                label: 'Altın: ${kullanici?.coins ?? 0}',
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.store),
                  child: Container(
                    // .currency { padding:5px 7px; border-radius:8px }
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    decoration: BoxDecoration(
                      color: Ref.currencyBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Ref.currencyBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CoinGlyph(size: 11),
                        const SizedBox(width: 4),
                        Text(trThousands(kullanici?.coins ?? 0),
                            style: Ref.bodyText(10, color: Ref.gold, weight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              RefNeutralButton(
                padding: const EdgeInsets.all(5),
                semanticLabel: 'Profil',
                onTap: currentRoute == AppRoutes.profile ? null : () => context.go(AppRoutes.profile),
                child: const RefGlyphIcon(RefGlyph.smile, size: 12, color: Ref.neutralText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// .bottom-nav { background:#091523; border-top:1px solid #334258;
//   padding:7px 7px 11px; grid 5 sütun; gap:2px }
// ====================================================================
class RefBottomNav extends StatelessWidget {
  final String currentRoute;
  const RefBottomNav({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final maddeler = kNavDestinations.where((h) => !h.sidebarOnly).toList();
    return Container(
      decoration: const BoxDecoration(
        color: Ref.navBg,
        border: Border(top: BorderSide(color: Ref.navBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 7, 7, 11),
          child: Row(
            children: [
              for (var i = 0; i < maddeler.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(child: _AltMadde(hedef: maddeler[i], etkin: currentRoute == maddeler[i].route)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AltMadde extends StatelessWidget {
  final NavDestination hedef;
  final bool etkin;
  const _AltMadde({required this.hedef, required this.etkin});

  @override
  Widget build(BuildContext context) {
    // .bottom-nav button { border-radius:9px; color:#8194ad; padding:5px 1px;
    //   gap:3px; font-size:9px; font-weight:800 } .navicon { font-size:19px }
    // .current { background:#164539; color:#5ff5c3 }
    final renk = etkin ? Ref.navCurrentText : Ref.navText;
    return Semantics(
      button: true,
      selected: etkin,
      label: hedef.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: etkin ? null : () => context.go(hedef.route),
        child: AnimatedContainer(
          duration: Ref.cardHover,
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
          decoration: BoxDecoration(
            color: etkin ? Ref.navCurrentBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 26, child: Center(child: RefGlyphIcon(hedef.glyph, size: 19, color: renk))),
              const SizedBox(height: 3),
              Text(hedef.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: Ref.bodyText(9, color: renk, weight: FontWeight.w800, height: 1.36)),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// .sidebar { border-right:1px solid #28364c; background:linear-gradient(#0e192b,#080e19);
//   padding:25px 15px; gap:20px } (masaüstü)
// ====================================================================
class RefSidebar extends StatelessWidget {
  final String currentRoute;
  const RefSidebar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppBreakpoints.sidebarWidth,
      decoration: const BoxDecoration(
        gradient: Ref.sidebarGradient,
        border: Border(right: BorderSide(color: Ref.sidebarBorder)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 25, 15, 25),
          children: [
            // .brandmark { padding:10px 9px 18px; gap:4px }
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 10, 9, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Em('🏆', size: 36),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'FUTBOL\n'),
                      TextSpan(text: 'CARD ARENA', style: Ref.heading(27, color: Ref.gold, weight: FontWeight.w900)),
                    ]),
                    style: Ref.heading(27, weight: FontWeight.w900, height: 0.94).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // .sectionlabel { font-size:10px; color:#6c829b; font-weight:900;
            //   letter-spacing:.16em; padding:0 11px }
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Text('EKRANLAR',
                  style: Ref.bodyText(10, color: Ref.sectionLabel, weight: FontWeight.w900)
                      .copyWith(letterSpacing: 1.6)),
            ),
            const SizedBox(height: 20),
            for (final h in kNavDestinations) ...[
              _KenarMaddesi(hedef: h, etkin: currentRoute == h.route),
              const SizedBox(height: 5),
            ],
          ],
        ),
      ),
    );
  }
}

class _KenarMaddesi extends StatefulWidget {
  final NavDestination hedef;
  final bool etkin;
  const _KenarMaddesi({required this.hedef, required this.etkin});

  @override
  State<_KenarMaddesi> createState() => _KenarMaddesiState();
}

class _KenarMaddesiState extends State<_KenarMaddesi> {
  bool _uzerinde = false;

  @override
  Widget build(BuildContext context) {
    final etkin = widget.etkin;
    // .navbtn { padding:11px 12px; border-radius:10px; font-size:12px;
    //   font-weight:800; gap:11px; color:#adc0d7 } .ico { 17px; width:23px }
    // :hover { background:#1e3046; color:white }
    // .active { background:linear-gradient(90deg,#11604788,#12392f);
    //   color:#9af7d7; border-color:#25e4ad77; box-shadow:0 0 18px #0fcf8f25 }
    final renk = etkin ? Ref.sideNavActiveText : (_uzerinde ? Colors.white : Ref.sideNavText);
    return MouseRegion(
      onEnter: (_) => setState(() => _uzerinde = true),
      onExit: (_) => setState(() => _uzerinde = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        selected: etkin,
        label: widget.hedef.label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: etkin ? null : () => context.go(widget.hedef.route),
          child: AnimatedContainer(
            key: etkin ? const ValueKey('kenar-etkin') : null,
            duration: Ref.cardHover,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              gradient: etkin ? Ref.sideNavActive : null,
              color: etkin ? null : (_uzerinde ? Ref.sideNavHover : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: etkin ? Ref.sideNavActiveBorder : Colors.transparent),
              boxShadow: etkin ? const [BoxShadow(color: Color(0x250FCF8F), blurRadius: 18)] : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 23,
                  child: Center(child: RefGlyphIcon(widget.hedef.glyph, size: 17, color: renk)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(widget.hedef.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ref.bodyText(12, color: renk, weight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
