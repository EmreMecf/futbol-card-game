import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/di/injection.dart';
import '../../../core/router/app_routes.dart';
import '../../../features/auth/presentation/viewmodel/auth_view_model.dart';
import '../../../features/chests/presentation/viewmodel/chests_view_model.dart';
import '../../../features/chests/domain/chest_texts.dart';
import '../../../features/home/presentation/viewmodel/home_view_model.dart';
import '../../../features/season/presentation/viewmodel/season_view_model.dart';
import '../../ui_v21.dart';
import 'v21_daily_strip.dart';
import 'v21_home_nav.dart';
import '../../web/web_kit.dart';
import '../../web/web_screens.dart';

/// V2.1 ANA SAYFA (referans `assets/v21/screens/home.png`, 390×844).
///
///   üst başlık   sezon kademesi · kullanıcı adı · altın
///   lig rozeti   M2 · MASTER 2 · 1.825 · ilerleme
///   kahraman     stadyum + maskot (dekoratif görsel)
///   MAÇA BAŞLA   eşleşmeye götürür (devam eden maç varsa MAÇA DÖN)
///   sandıklar    4 yuva: sayaç / süre / boş
///   alt menü     KARTLAR · KADRO · ARENA · MAĞAZA · SEZON
///
/// VERİ — tamamı sunucudan, mevcut ViewModel'lerle:
///   * kullanıcı adı, altın          SessionManager (oturum, /api/auth/me)
///   * lig, puan, ilerleme           HomeViewModel → /api/leaderboard/rank
///   * seviye dairesi + çubuk        SeasonViewModel → /api/season (kademe)
///   * sandık yuvaları ve sayaçlar   ChestsViewModel → /api/chests (sunucu saati)
///   * devam eden maç                AuthViewModel.activeMatchId
/// Bir kaynak yoksa (kapalı ekonomi, hata, test) o parça yer tutucu çizer
/// ya da gizlenir; hiçbir sayı uydurulmaz.
class V21HomeScreen extends StatelessWidget {
  const V21HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<HomeViewModel>(create: (_) => getIt<HomeViewModel>()..load()),
        if (getIt.isRegistered<ChestsViewModel>())
          ChangeNotifierProvider<ChestsViewModel>(create: (_) => getIt<ChestsViewModel>()..load()),
        if (getIt.isRegistered<SeasonViewModel>())
          ChangeNotifierProvider<SeasonViewModel>(create: (_) => getIt<SeasonViewModel>()..load()),
      ],
      child: Theme(data: V21Theme.data(context), child: const _HomeBody()),
    );
  }
}

/// Sağlayıcı yoksa (test, kapalı servis) null
T? _maybeWatch<T>(BuildContext context) {
  try {
    return context.watch<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

T? _maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  @override
  void initState() {
    super.initState();
    chestInventoryChanged.addListener(_refreshChests);
    // Altın ve devam eden maç bilgisi maç/mağaza sonrası değişmiş olabilir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeRead<AuthViewModel>(context)?.refreshProfile();
    });
  }

  @override
  void dispose() {
    chestInventoryChanged.removeListener(_refreshChests);
    super.dispose();
  }

  void _refreshChests() {
    if (mounted) _maybeRead<ChestsViewModel>(context)?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (v21IsWeb(context)) return const WebHome();
    return V21ScreenLayout(
      body: (context, sc) => _HomeContent(scale: sc.s),
      bottomNavigation: (context, sc) => V21HomeNav(currentRoute: AppRoutes.home, scale: sc.s),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final double scale;
  const _HomeContent({required this.scale});

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final chests = _maybeWatch<ChestsViewModel>(context);
    final env = chests?.inventory;
    // Ekonomi kapalıysa ya da sandık servisi yoksa şerit hiç çizilmez
    final showChests = chests != null && (env == null ? chests.isLoading : env.enabled);

    // Yatay tablet ve masaüstü: solda kahraman ve düğme, sağda günlük + sandıklar
    if (V21Scale.of(context).isExpanded) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16 * k, 0, 16 * k, 16 * k),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Header(),
            SizedBox(height: 8 * k),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Align(alignment: Alignment.centerLeft, child: _League()),
                        SizedBox(height: 8 * k),
                        Expanded(
                          child: ClipRRect(borderRadius: BorderRadius.circular(16 * k), child: const _Hero()),
                        ),
                        SizedBox(height: 10 * k),
                        _PlayButton(scale: k),
                      ],
                    ),
                  ),
                  SizedBox(width: 16 * k),
                  SizedBox(
                    width: 350 * k,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            V21DailyStrip(scale: k, sidePadding: 0),
                            if (showChests) ...[SizedBox(height: 12 * k), _ChestRow(vm: chests, scale: k)],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(),
        SizedBox(height: 14 * k),
        Padding(
          padding: EdgeInsets.only(left: V21Metrics.leagueBadgeLeft * k),
          child: const Align(alignment: Alignment.centerLeft, child: _League()),
        ),
        SizedBox(height: 2 * k),
        const Expanded(child: _Hero()),
        // Düğmenin iki yanında stadyum zemini (referans x=5..35 sütunu)
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2E4A2B), Color(0xFF4C497E), Color(0xFF292F3D), Color(0xFF1F1D44)],
              stops: [0, 0.48, 0.72, 1],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: V21Metrics.primaryButtonSide * k),
            child: _PlayButton(scale: k),
          ),
        ),
        V21DailyStrip(scale: k),
        if (showChests) ...[
          SizedBox(height: 8 * k),
          _ChestRow(vm: chests, scale: k),
          SizedBox(height: 9 * k),
        ] else
          SizedBox(height: 16 * k),
      ],
    );
    return Stack(
      children: [
        // Gece göğü + projektörler (header ve lig rozetinin arkası)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 172 * k,
          child: V21StadiumSky(scale: k),
        ),
        Positioned.fill(child: column),
      ],
    );
  }
}

// ====================================================================
// Üst başlık: sezon kademesi + kullanıcı + altın
// ====================================================================
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final k = V21Scale.of(context).s;
    final user = _maybeWatch<SessionManager>(context)?.user;
    final season = _maybeWatch<SeasonViewModel>(context)?.overview;
    final hasSeason = season != null && season.enabled;
    return V21GameHeader(
      scale: k,
      username: user?.username ?? '',
      level: hasSeason ? season.tier : null,
      levelProgress: hasSeason ? season.tierProgress.clamp(0.0, 1.0) : null,
      levelMeaning: 'Sezon kademesi',
      onProfileTap: () => context.push(AppRoutes.profile),
      trailing: [
        // 056: elmas — mağazadaki elmas bölümüne götürür
        V21ResourcePill.gems(scale: k, gems: user?.gems, onTap: () => context.go(AppRoutes.store)),
        V21ResourcePill.coins(scale: k, coins: user?.coins, onTap: () => context.go(AppRoutes.store)),
      ],
    );
  }
}

// ====================================================================
// Lig rozeti (gerçek basamak)
// ====================================================================
class _League extends StatelessWidget {
  const _League();

  @override
  Widget build(BuildContext context) {
    final k = V21Scale.of(context).s;
    final PlayerRank? r = context.watch<HomeViewModel>().rank;
    String? detail;
    if (r != null) {
      detail = r.isTopTier || r.nextLabel == null ? 'En üst ligdesin' : '${r.pointsToNext} puan sonra ${r.nextLabel}';
    }
    return V21LeagueBadge(
      scale: k,
      code: r == null ? null : V21LeagueBadge.shortCode(r.leagueCode, r.division),
      title: r == null ? null : V21Format.upper(r.label),
      points: r?.mmr,
      progress: r == null ? 0 : (r.isTopTier ? 1 : r.progress),
      detail: detail,
      onTap: () => context.push(AppRoutes.leagueTiers),
    );
  }
}

// ====================================================================
// Kahraman görseli (dekoratif; dokunma alanı YOK)
// ====================================================================
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ShaderMask(
        // Üst kenar zeminle yumuşak birleşsin
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
          stops: [0, 0.07],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          V21Assets.homeHero,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.35),
          filterQuality: FilterQuality.medium,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }
}

// ====================================================================
// MAÇA BAŞLA / MAÇA DÖN
// ====================================================================
class _PlayButton extends StatelessWidget {
  final double scale;
  const _PlayButton({required this.scale});

  @override
  Widget build(BuildContext context) {
    final activeMatch = _maybeWatch<AuthViewModel>(context)?.activeMatchId;
    if (activeMatch != null) {
      return V21GameButton(
        label: 'MAÇA DÖN',
        size: V21ButtonSize.hero,
        tone: V21ButtonTone.green,
        scale: scale,
        semanticsLabel: 'Maça dön: devam eden maçın var',
        onPressed: () => context.push(AppRoutes.matchWithId(activeMatch)),
      );
    }
    return V21GameButton(
      label: 'MAÇA BAŞLA',
      size: V21ButtonSize.hero,
      scale: scale,
      onPressed: () => context.go(AppRoutes.matchmaking),
    );
  }
}

// ====================================================================
// Sandık yuvaları (sunucu saatine göre sayaç)
// ====================================================================
class _ChestRow extends StatelessWidget {
  final ChestsViewModel vm;
  final double scale;
  const _ChestRow({required this.vm, required this.scale});

  static Color accentFor(String type) => switch (type) {
    ChestTypes.legend => V21Colors.rarityLegend,
    ChestTypes.gold => V21Colors.rarityGold,
    ChestTypes.silver => V21Colors.raritySilver,
    _ => V21Colors.rarityBronze,
  };

  @override
  Widget build(BuildContext context) {
    final k = scale;
    final env = vm.inventory;
    final count = env?.slotCount ?? 4;
    void open() => context.push(AppRoutes.chests).then((_) => vm.refresh());

    Widget slot(int no) {
      if (env == null) {
        return V21ChestSlot(state: V21ChestSlotState.loading, semanticsLabel: 'Sandık yuvası $no yükleniyor', scale: k);
      }
      final c = env.slot(no);
      if (c == null) {
        return V21ChestSlot(
          state: V21ChestSlotState.empty,
          semanticsLabel: 'Sandık yuvası $no boş',
          onTap: open,
          scale: k,
        );
      }
      final type = V21Format.upper(c.typeName);
      if (c.isUnlocking) {
        final left = V21Format.countdown(vm.remaining(c) ?? Duration.zero);
        return V21ChestSlot(
          state: V21ChestSlotState.unlocking,
          label: 'AÇILIYOR',
          footer: left,
          accent: V21Colors.success,
          tier: c.chestType,
          semanticsLabel: '${c.typeName} sandık açılıyor, kalan $left',
          onTap: open,
          scale: k,
        );
      }
      if (c.isReady) {
        return V21ChestSlot(
          state: V21ChestSlotState.ready,
          label: 'HAZIR',
          footer: 'AÇ!',
          accent: accentFor(c.chestType),
          tier: c.chestType,
          semanticsLabel: '${c.typeName} sandık açılmaya hazır',
          onTap: open,
          scale: k,
        );
      }
      final sure = V21Format.shortDuration(c.unlockSeconds);
      return V21ChestSlot(
        state: V21ChestSlotState.sealed,
        label: type,
        footer: sure,
        accent: accentFor(c.chestType),
        tier: c.chestType,
        semanticsLabel: '${c.typeName} sandık, açılma süresi $sure',
        onTap: open,
        scale: k,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: V21Metrics.chestRowSide * k),
      child: Row(
        children: [
          for (var i = 1; i <= count; i++) ...[
            if (i > 1) SizedBox(width: V21Metrics.chestSlotGap * k),
            Expanded(child: slot(i)),
          ],
        ],
      ),
    );
  }
}
