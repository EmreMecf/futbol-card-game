import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/game/game_ui.dart';
import '../../../../shared/widgets/stat_chip.dart';
import '../../../auth/presentation/viewmodel/auth_view_model.dart';
import '../viewmodel/home_view_model.dart';
import '../widgets/home_panels.dart';

/// Ana sayfa — oyunun giriş noktası (MD bölüm 4-C).
///
/// ===================================================================
/// HİYERARŞİ
/// ===================================================================
/// Ekranın tamamı tek bir karara hizmet ediyor: "maça gir". Bu yüzden
/// ARENA paneli ve altın "MAÇA BAŞLA" butonu en büyük, en parlak ve en
/// üstteki öğe. Kısayollar, son maçlar ve "yakında" bölümü görünür
/// biçimde ondan daha sönük.
///
/// ===================================================================
/// İKİ YERLEŞİM, TEK VERİ
/// ===================================================================
/// Telefonda tek sütun + alt sekme çubuğu; masaüstünde kenar çubuğu +
/// iki sütun. İkisi de aynı [HomeViewModel] ve [SessionManager]
/// verisini okuyor.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeViewModel>(
      create: (_) => getIt<HomeViewModel>()..load(),
      child: const _HomeBody(),
    );
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
    // Coin, MMR ve koruma hakkı maç sonrası değişmiş olabilir;
    // ayrıca devam eden maç varsa oraya dönebilmek için tazeliyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().refreshProfile();
    });
  }

  Future<void> _yenile() async {
    await Future.wait([
      context.read<AuthViewModel>().refreshProfile(),
      context.read<HomeViewModel>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: AppRoutes.home,
      child: ResponsiveBuilder(
        builder: (context, boyut) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _yenile,
          child: boyut.usesSidebar
              ? _GenisYerlesim(size: boyut)
              : _DarYerlesim(size: boyut),
        ),
      ),
    );
  }
}

// ====================================================================
// TELEFON / TABLET
// ====================================================================
class _DarYerlesim extends StatelessWidget {
  final ScreenSize size;

  const _DarYerlesim({required this.size});

  @override
  Widget build(BuildContext context) {
    final kenar = AppBreakpoints.pagePadding(size);
    final vm = context.watch<HomeViewModel>();
    final kullanici = context.watch<SessionManager>().user;

    return SafeArea(
      bottom: false,
      child: ListView(
        // Alt boşluk: alt sekme çubuğunun ve ortadaki maç butonunun
        // altında içerik kalmasın
        padding: EdgeInsets.fromLTRB(kenar, AppSpacing.lg, kenar, 110),
        children: [
          const _OyuncuSeridi(),
          const SizedBox(height: AppSpacing.lg),
          const _DevamEdenMac(),
          ArenaHeroPanel(
            user: kullanici,
            rank: vm.rank,
            winStreak: vm.winStreak,
            isStreakCapped: vm.isStreakCapped,
          ),
          const SizedBox(height: AppSpacing.md),
          const HomeShortcutGrid(columns: 2),
          const SizedBox(height: AppSpacing.xl),
          RecentMatchesPanel(
            matches: vm.recentMatches,
            isLoaded: vm.isLoaded,
          ),
          const SizedBox(height: AppSpacing.xl),
          const HomeSectionHeader(title: 'Yakında'),
          const SizedBox(height: AppSpacing.sm),
          const ComingSoonPanel(),
        ],
      ),
    );
  }
}

// ====================================================================
// MASAÜSTÜ
// ====================================================================
class _GenisYerlesim extends StatelessWidget {
  final ScreenSize size;

  const _GenisYerlesim({required this.size});

  @override
  Widget build(BuildContext context) {
    final kenar = AppBreakpoints.pagePadding(size);
    final vm = context.watch<HomeViewModel>();
    final kullanici = context.watch<SessionManager>().user;

    return SafeArea(
      child: ContentWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(kenar, AppSpacing.xxxl, kenar, 40),
          children: [
            const _MasaustuBasligi(),
            const SizedBox(height: AppSpacing.xxl),
            const _DevamEdenMac(),
            // Arena solda geniş, son maçlar sağda dar. 3:2 oranı hangi
            // öğenin asıl olduğunu tek bakışta anlatıyor.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      ArenaHeroPanel(
                        user: kullanici,
                        rank: vm.rank,
                        winStreak: vm.winStreak,
                        isStreakCapped: vm.isStreakCapped,
                        large: true,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      HomeShortcutGrid(
                        columns: AppBreakpoints.gridColumns(size),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RecentMatchesPanel(
                        matches: vm.recentMatches,
                        isLoaded: vm.isLoaded,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const HomeSectionHeader(title: 'Yakında'),
                      const SizedBox(height: AppSpacing.sm),
                      const ComingSoonPanel(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// ÜST ŞERİTLER
// ====================================================================

/// Telefon üst şeridi: avatar, ad, coin ve kupa hapları.
class _OyuncuSeridi extends StatelessWidget {
  const _OyuncuSeridi();

  @override
  Widget build(BuildContext context) {
    final kullanici = context.watch<SessionManager>().user;

    return Row(
      children: [
        _Avatar(username: kullanici?.username),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kullanici?.username ?? 'Oyuncu',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.name,
              ),
              const SizedBox(height: AppSpacing.xxs),
              _MacOzeti(user: kullanici),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        StatChip.coins(
          kullanici?.coins ?? 0,
          onTap: () => context.go(AppRoutes.store),
        ),
      ],
    );
  }
}

/// Masaüstü başlığı: karşılama ve sayaç hapları.
class _MasaustuBasligi extends StatelessWidget {
  const _MasaustuBasligi();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionManager>();
    final kullanici = session.user;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoş geldin, ${kullanici?.username ?? 'Oyuncu'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.display(
                  size: 36,
                  weight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _MacOzeti(user: kullanici, dense: false),
            ],
          ),
        ),
        StatChip.coins(
          kullanici?.coins ?? 0,
          onTap: () => context.go(AppRoutes.store),
        ),
        const SizedBox(width: AppSpacing.sm),
        StatChip.protection(
          session.protectionSlots,
          GameRules.maxProtectionSlots,
        ),
      ],
    );
  }
}

/// "12 galibiyet · 4 mağlubiyet · 2 beraberlik"
class _MacOzeti extends StatelessWidget {
  final UserModel? user;
  final bool dense;

  const _MacOzeti({required this.user, this.dense = true});

  @override
  Widget build(BuildContext context) {
    final g = user?.wins ?? 0;
    final m = user?.losses ?? 0;
    final b = user?.draws ?? 0;

    final metin = g + m + b == 0
        ? 'Henüz maç oynamadın'
        : '$g galibiyet · $m mağlubiyet · $b beraberlik';

    return Text(
      metin,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.body(
        size: dense ? 12 : 14,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? username;

  const _Avatar({this.username});

  @override
  Widget build(BuildContext context) {
    final harf = (username?.trim().isNotEmpty ?? false)
        ? username!.trim()[0].toUpperCase()
        : '?';

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => context.go(AppRoutes.profile),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: AppShadows.glow(AppColors.primary, siddet: 0.6),
        ),
        child: Center(
          child: Text(
            harf,
            style: AppTypography.display(
              size: 20,
              weight: FontWeight.w900,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// DEVAM EDEN MAÇ UYARISI
// ====================================================================
class _DevamEdenMac extends StatelessWidget {
  const _DevamEdenMac();

  @override
  Widget build(BuildContext context) {
    final macId = context.watch<AuthViewModel>().activeMatchId;
    if (macId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GlassPanel(
        accentColor: AppColors.warning,
        glow: true,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        onTap: () => context.push(AppRoutes.matchWithId(macId)),
        child: Row(
          children: [
            const Icon(Icons.sports_soccer, color: AppColors.warning, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Devam eden maçın var',
                    style: AppTypography.body(
                      size: 13.5,
                      weight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Sıra sende olabilir. Süren dolarsa hükmen yenik '
                    'sayılırsın.',
                    style: AppTypography.bodyXS,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.warning,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
