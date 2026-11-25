import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/auth/session_manager.dart';
import '../../core/di/injection.dart';
import '../../core/router/app_routes.dart';
import '../../features/home/presentation/viewmodel/home_view_model.dart';
import '../../features/season/presentation/viewmodel/season_view_model.dart';
import '../ui_v21.dart';
import '../../core/l10n/app_language.dart';

/// WEB TASARIMI: bütün ekranlar 1672×941 tuvale çizilir ve pencereye sığacak
/// şekilde ölçeklenir. Böylece her masaüstü boyutunda tasarımla aynı yerleşim
/// korunur, hiçbir öğe kaymaz ya da taşmaz. Ölçüler `design-reference/web`.
const Size kWebCanvas = Size(1672, 941);

/// Web tasarımı kullanılacak kadar geniş pencere mi?
bool v21IsWeb(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  return s.width >= 1100 && s.height >= 600;
}

/// Tasarım koordinatıyla yerleştirir (sol, üst, sağ, alt)
Widget wBox(double l, double t, double r, double b, Widget child) =>
    Positioned(left: l, top: t, width: r - l, height: b - t, child: child);

String wAsset(String ad) => 'assets/v21/web/$ad.webp';

Widget wImage(String ad, {BoxFit fit = BoxFit.cover}) =>
    Image.asset(wAsset(ad), fit: fit, filterQuality: FilterQuality.medium, gaplessPlayback: true);

T? wWatch<T>(BuildContext context) {
  try {
    return Provider.of<T>(context);
  } on ProviderNotFoundException {
    return null;
  }
}

const wPanelTop = Color(0xFF43249A);
const wPanelBottom = Color(0xFF2A1567);
const wPanelBorder = Color(0xFF6A48C8);
const wInset = Color(0xFF251258);

/// Kalın oyun yazısı
TextStyle wTitle(double size, {Color color = Colors.white}) =>
    V21Type.title(size, color: color, shadows: V21Type.inkShadow(size / 28));

TextStyle wBody(double size, {Color color = Colors.white, FontWeight weight = FontWeight.w700}) =>
    V21Type.label(size, weight: weight, color: color);

/// Sol menü ve üst çubuklu web iskeleti
class WebShell extends StatelessWidget {
  final String route;

  /// Yalnız kendi sayfasında görünen altıncı madde
  final WebExtraNav? extra;
  final List<Widget> children;

  /// Tuvalin üstünde tam ekran katmanlar (maç sahnesi, bağlantı uyarısı)
  final List<Widget> overlays;

  const WebShell({
    super.key,
    required this.route,
    required this.children,
    this.extra,
    this.overlays = const [],
  });

  static bool _onbellek = false;

  /// Büyük görseller ilk açılışta geç belirmesin
  static void _onYukle(BuildContext context) {
    if (_onbellek) return;
    _onbellek = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      for (final a in const ['logo', 'home_hero', 'ready_bg', 'arena_bg', 'friends_bg', 'chest_hero', 'offer_bg']) {
        precacheImage(AssetImage(wAsset(a)), context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _onYukle(context);
    final mq = MediaQuery.of(context);
    return Theme(
      data: V21Theme.data(context),
      child: Scaffold(
        backgroundColor: const Color(0xFF1B0B52),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A1272), Color(0xFF3A1C8C), Color(0xFF1B0B52)],
                ),
              ),
            ),
            Center(
              child: FittedBox(
                child: SizedBox.fromSize(
                  size: kWebCanvas,
                  child: MediaQuery(
                    data: mq.copyWith(size: kWebCanvas, padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                    child: ClipRect(
                      child: Stack(
                        children: [
                          ...children,
                          _Sidebar(route: route, extra: extra),
                          const _TopBar(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ...overlays,
          ],
        ),
      ),
    );
  }
}

enum WebExtraNav { progress, chests }

class _Sidebar extends StatelessWidget {
  final String route;
  final WebExtraNav? extra;
  const _Sidebar({required this.route, this.extra});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String, String, String?)>[
      ('ARENA'.tr, AppRoutes.home, 'nav_arena', 'nav_arena_on'),
      ('KARTLAR'.tr, AppRoutes.collection, 'nav_cards', 'nav_cards_on'),
      ('KADRO'.tr, AppRoutes.deck, 'nav_squad', 'nav_squad_on'),
      ('MAĞAZA'.tr, AppRoutes.store, 'nav_store', 'nav_store_on'),
      ('SEZON'.tr, AppRoutes.season, 'nav_season', null),
      if (extra == WebExtraNav.progress) ('GELİŞİM'.tr, AppRoutes.progress, 'nav_progress_on', 'nav_progress_on'),
      if (extra == WebExtraNav.chests) ('SANDIKLAR'.tr, AppRoutes.chests, 'nav_chests_on', 'nav_chests_on'),
    ];
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: 264,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xFF4A2FA0), width: 2)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2B1370), Color(0xFF3B1D8E), Color(0xFF241060)],
          ),
        ),
        child: Stack(
          children: [
            wBox(12, 8, 252, 226, wImage('logo', fit: BoxFit.contain)),
            for (final (i, it) in items.indexed)
              wBox(14, 250 + i * 97.0, 252, 328 + i * 97.0, _NavTile(item: it, active: it.$2 == route)),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final (String, String, String, String?) item;
  final bool active;
  const _NavTile({required this.item, required this.active});

  @override
  Widget build(BuildContext context) {
    final asset = active ? (item.$4 ?? item.$3) : item.$3;
    return Semantics(
      button: true,
      selected: active,
      label: item.$1,
      excludeSemantics: true,
      child: V21Tap(
        onTap: () {
          if (!active) context.go(item.$2);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? const Color(0xFFFFE9A0) : const Color(0xFF55399F), width: 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: active
                  ? const [Color(0xFFFFCE45), Color(0xFFFF9A12)]
                  : const [Color(0xFF3D2486), Color(0xFF2E1868)],
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 56, height: 46, child: wImage(asset, fit: BoxFit.contain)),
              const SizedBox(width: 12),
              Expanded(child: Text(item.$1, maxLines: 1, overflow: TextOverflow.fade, style: wTitle(33))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Üst çubuk: sezon kademesi, oyuncu, lig, altın, bildirim, ayarlar
class _TopBar extends StatefulWidget {
  const _TopBar();

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  // Sayfa değişince üst çubuk boşalmasın
  static PlayerRank? _rank;
  static int? _tier;
  static double _tierProgress = 0;

  HomeViewModel? _home;
  SeasonViewModel? _season;

  @override
  void initState() {
    super.initState();
    if (getIt.isRegistered<HomeViewModel>()) _home = getIt<HomeViewModel>()..addListener(_update)..load();
    if (getIt.isRegistered<SeasonViewModel>()) _season = getIt<SeasonViewModel>()..addListener(_update)..load();
  }

  void _update() {
    final s = _season?.overview;
    if (!mounted) return;
    setState(() {
      _rank = _home?.rank ?? _rank;
      if (s != null && s.enabled) {
        _tier = s.tier;
        _tierProgress = s.tierProgress.clamp(0.0, 1.0);
      }
    });
  }

  @override
  void dispose() {
    _home?.removeListener(_update);
    _season?.removeListener(_update);
    _home?.dispose();
    _season?.dispose();
    super.dispose();
  }

  Widget _plus(VoidCallback onTap, String label) => Semantics(
    button: true,
    label: label,
    child: V21Tap(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6CF05C), Color(0xFF16A838)],
          ),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 34),
      ),
    ),
  );

  Widget _pill(Widget icon, String value, VoidCallback onPlus, String label) => Container(
    padding: const EdgeInsets.fromLTRB(10, 0, 7, 0),
    decoration: BoxDecoration(
      color: const Color(0xFF1C0D4C),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFF4B3C7F), width: 2),
    ),
    child: Row(
      children: [
        SizedBox(width: 44, height: 44, child: icon),
        const SizedBox(width: 12),
        Expanded(child: Text(value, maxLines: 1, style: wTitle(32))),
        _plus(onPlus, label),
      ],
    ),
  );

  Widget _square(IconData icon, String label, VoidCallback onTap) => Semantics(
    button: true,
    label: label,
    child: V21Tap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF39238A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF5B45A8), width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 36),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final user = wWatch<SessionManager>(context)?.user;
    final r = _rank ?? _home?.rank;
    final code = r == null ? '-' : V21LeagueBadge.shortCode(r.leagueCode, r.division);
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Stack(
          children: [
            Positioned(
              left: 264,
              right: 0,
              top: 0,
              height: 92,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF241066),
                  border: Border(bottom: BorderSide(color: Color(0xFF4A2FA0), width: 2)),
                ),
              ),
            ),
            wBox(
              300,
              12,
              372,
              84,
              V21Tap(
                onTap: () => context.go(AppRoutes.season),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF17205E), width: 4),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3FA4FF), Color(0xFF1656D6)],
                    ),
                  ),
                  child: Text('${_tier ?? 1}', style: wTitle(38)),
                ),
              ),
            ),
            wBox(
              386,
              12,
              600,
              84,
              V21Tap(
                onTap: () => context.go(AppRoutes.profile),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.username ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: wTitle(30)),
                    const SizedBox(height: 10),
                    _Bar(value: _tierProgress, height: 18),
                  ],
                ),
              ),
            ),
            wBox(
              626,
              12,
              990,
              88,
              V21Tap(
                onTap: () => context.push(AppRoutes.leagueTiers),
                child: Stack(
                  children: [
                    Positioned(
                      left: 34,
                      right: 0,
                      top: 4,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(52, 4, 20, 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE27A), width: 2),
                          gradient: const LinearGradient(colors: [Color(0xFFE9A52C), Color(0xFFFFC94F)]),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    r == null ? 'LİG'.tr : V21Format.upper(r.label),
                                    maxLines: 1,
                                    style: wTitle(28),
                                  ),
                                ),
                                Text(r == null ? '' : V21Format.thousands(r.mmr), style: wTitle(25)),
                              ],
                            ),
                            const Spacer(),
                            _Bar(value: r == null ? 0 : (r.isTopTier ? 1 : r.progress), height: 16),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 72,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFD9A2F8), Color(0xFF7B3CCB)],
                          ),
                        ),
                        child: FittedBox(child: Padding(padding: const EdgeInsets.all(8), child: Text(code, style: wTitle(32)))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            wBox(
              1282,
              20,
              1510,
              78,
              _pill(
                const V21CoinIcon(size: 44),
                V21Format.thousands(user?.coins ?? 0),
                () => context.go(AppRoutes.store),
                'Altın al: mağaza'.tr,
              ),
            ),
            wBox(1526, 16, 1588, 80, _square(Icons.notifications_rounded, 'Görevler'.tr, () => context.go(AppRoutes.season))),
            wBox(1600, 16, 1662, 80, _square(Icons.settings_rounded, 'Ayarlar'.tr, () => context.push(AppRoutes.settings))),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double height;
  const _Bar({required this.value, required this.height});

  @override
  Widget build(BuildContext context) => WBar(value: value, height: height);
}

/// Yeşil ilerleme çubuğu
class WBar extends StatelessWidget {
  final double value;
  final double height;
  final List<Color> colors;
  const WBar({
    super.key,
    required this.value,
    this.height = 16,
    this.colors = const [Color(0xFF34C94B), Color(0xFF86F36D)],
  });

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(color: const Color(0xFF1B1045), borderRadius: BorderRadius.circular(height / 2)),
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: value.clamp(0.0, 1.0),
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    ),
  );
}

/// Başlıklı mor panel
class WPanel extends StatelessWidget {
  final String? title;
  final Widget? icon;
  final Widget? trailing;
  final Widget child;
  final double headerHeight;
  final double titleSize;
  const WPanel({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.headerHeight = 58,
    this.titleSize = 31,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: wPanelBorder, width: 2),
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [wPanelTop, wPanelBottom],
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Container(
            height: headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFF5733B4),
            child: Row(
              children: [
                if (icon != null) ...[SizedBox(width: 44, height: 44, child: icon), const SizedBox(width: 12)],
                Expanded(child: Text(title!, maxLines: 1, overflow: TextOverflow.fade, style: wTitle(titleSize))),
                ?trailing,
              ],
            ),
          ),
        Expanded(child: child),
      ],
    ),
  );
}

/// 3B oyun düğmesi
class WButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final V21ButtonTone tone;
  final double fontSize;
  final IconData? icon;

  /// Yazının solundaki özel simge (altın sikkesi)
  final Widget? leading;
  final Widget? trailing;
  final bool busy;
  final String? semantics;
  const WButton(
    this.label, {
    super.key,
    required this.onTap,
    this.tone = V21ButtonTone.gold,
    this.fontSize = 36,
    this.icon,
    this.leading,
    this.trailing,
    this.busy = false,
    this.semantics,
  });

  @override
  State<WButton> createState() => _WButtonState();
}

class _WButtonState extends State<WButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null && !widget.busy;
    final t = widget.tone;
    return Semantics(
      button: true,
      enabled: on,
      label: widget.semantics ?? widget.label,
      excludeSemantics: true,
      child: V21Tap(
        onTap: on ? widget.onTap : null,
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapUp: on ? (_) => setState(() => _down = false) : null,
        onTapCancel: on ? () => setState(() => _down = false) : null,
        child: Opacity(
          opacity: on || widget.busy ? 1 : 0.62,
          child: Container(
          padding: EdgeInsets.only(bottom: _down ? 2 : 7, top: _down ? 5 : 0),
          decoration: BoxDecoration(color: t.lip, borderRadius: BorderRadius.circular(18)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.edge.withValues(alpha: 0.8), width: 2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [t.top, t.bottom],
              ),
            ),
            child: widget.busy
                ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: Colors.white))
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: Colors.white, size: widget.fontSize * 1.1),
                          SizedBox(width: widget.fontSize * 0.35),
                        ],
                        if (widget.leading != null) ...[widget.leading!, SizedBox(width: widget.fontSize * 0.3)],
                        Text(widget.label, maxLines: 1, style: wTitle(widget.fontSize)),
                        if (widget.trailing != null) ...[const SizedBox(width: 18), widget.trailing!],
                      ],
                    ),
                  ),
          ),
          ),
        ),
      ),
    );
  }
}

Color wTierColor(CardTier t) => switch (t) {
  CardTier.bronze => const Color(0xFFFFAB76),
  CardTier.silver => const Color(0xFFE8EEF6),
  CardTier.gold => const Color(0xFFFFD45A),
  CardTier.diamond => const Color(0xFF7FE9FF),
  CardTier.legend => const Color(0xFFD9A2F8),
};

/// Tasarımdaki oyuncu kartı: kademe görseli + gerçek güç, mevki ve ad
class WCard extends StatelessWidget {
  final String name;
  final CardTier tier;
  final int power;
  final String position;
  final bool selected;
  final bool dim;
  final VoidCallback? onTap;
  const WCard({
    super.key,
    required this.name,
    required this.tier,
    required this.power,
    required this.position,
    this.selected = false,
    this.dim = false,
    this.onTap,
  });

  factory WCard.of(InventoryCard c, {bool selected = false, VoidCallback? onTap}) => WCard(
    name: c.fullName,
    tier: c.tier,
    power: c.power,
    position: c.position.code,
    selected: selected,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final accent = wTierColor(tier);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: '{name}, {position}, {power} güç'.trArgs({'name': name, 'position': position, 'power': power}),
      excludeSemantics: true,
      child: V21Tap(
        onTap: onTap,
        child: Opacity(
          opacity: dim ? 0.45 : 1,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final h = box.maxHeight;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(w * 0.1),
                  boxShadow: selected
                      ? const [BoxShadow(color: Color(0xFFFFE27A), blurRadius: 14, spreadRadius: 3)]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(w * 0.1),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: V21Rarity.of(tier).art,
                          ),
                          border: Border.all(color: accent, width: w * 0.03),
                          borderRadius: BorderRadius.circular(w * 0.1),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(w * 0.05, w * 0.05, w * 0.05, h * 0.2),
                        child: V21CharacterArt(characterKey: name, position: position),
                      ),
                      Positioned(
                        left: w * 0.03,
                        top: w * 0.03,
                        width: w * 0.3,
                        height: w * 0.3,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF1B0E3A), width: w * 0.022),
                          ),
                          child: FittedBox(
                            child: Padding(
                              padding: EdgeInsets.all(w * 0.02),
                              child: Text('$power', style: V21Type.title(w * 0.18, color: const Color(0xFF1B0E3A))),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: w * 0.04,
                        top: w * 0.05,
                        width: w * 0.32,
                        height: w * 0.16,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2A63),
                            borderRadius: BorderRadius.circular(w * 0.08),
                            border: Border.all(color: accent, width: w * 0.012),
                          ),
                          child: FittedBox(
                            child: Padding(
                              padding: EdgeInsets.all(w * 0.012),
                              child: Text(position, style: V21Type.title(w * 0.1)),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: w * 0.05,
                        right: w * 0.05,
                        bottom: h * 0.035,
                        height: h * 0.25,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: w * 0.03),
                          decoration: BoxDecoration(
                            color: const Color(0xF2241446),
                            borderRadius: BorderRadius.circular(w * 0.07),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(name, maxLines: 1, style: V21Type.title(w * 0.125)),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: WTierLabel(tier: tier, size: w * 0.075),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// "★ EFSANE ★" etiketi (yıldızlar her yazı tipinde görünsün diye simge)
class WTierLabel extends StatelessWidget {
  final CardTier tier;
  final double size;
  const WTierLabel({super.key, required this.tier, required this.size});

  @override
  Widget build(BuildContext context) {
    final c = wTierColor(tier);
    final star = Icon(Icons.star_rounded, size: size * 1.15, color: c);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        star,
        SizedBox(width: size * 0.3),
        Text(V21Format.upper(V21Rarity.of(tier).name), maxLines: 1, style: V21Type.label(size, weight: FontWeight.w900, color: c)),
        SizedBox(width: size * 0.3),
        star,
      ],
    );
  }
}

/// Kapalı kart (rakip seçimi, boş el)
class WHiddenCard extends StatelessWidget {
  final IconData? icon;
  const WHiddenCard({super.key, this.icon});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(box.maxWidth * 0.1),
        border: Border.all(color: const Color(0xFF281360), width: 5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6A3BD4), Color(0xFF4A25A8), Color(0xFF6A3BD4), Color(0xFF4A25A8)],
          stops: [0, 0.4, 0.6, 1],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: box.maxWidth * 0.5,
        height: box.maxWidth * 0.5,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF341B85),
          border: Border.all(color: V21Colors.goldTop, width: 5),
        ),
        child: icon == null
            ? Text('?', style: wTitle(box.maxWidth * 0.34, color: V21Colors.goldTop))
            : Icon(icon, color: V21Colors.goldTop, size: box.maxWidth * 0.26),
      ),
    ),
  );
}
