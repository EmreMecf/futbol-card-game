import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

import '../../features/characters/presentation/character_preview_view.dart';
import '../../features/characters/presentation/style_prototype_view.dart';
import '../../features/auth/presentation/view/login_view.dart';
import '../../features/auth/presentation/view/register_view.dart';
import '../../features/auth/presentation/view/splash_view.dart';
import '../../features/chests/presentation/view/chest_odds_view.dart';
import '../../features/chests/presentation/view/chests_view.dart';
import '../../features/collection/presentation/view/collection_view.dart';
import '../../features/deck/presentation/view/deck_view.dart';
import '../../features/home/presentation/view/home_view.dart';
import '../../features/items/presentation/view/inventory_view.dart';
import '../../features/leaderboard/presentation/view/leaderboard_view.dart';
import '../../features/season/presentation/view/season_view.dart';
import '../../features/leaderboard/presentation/view/league_tiers_view.dart';
import '../../features/match/presentation/view/match_view.dart';
import '../../features/matchmaking/presentation/view/matchmaking_view.dart';
import '../../features/profile/presentation/view/profile_view.dart';
import '../../features/progress/presentation/view/progress_view.dart';
import '../../features/sbc/presentation/view/sbc_builder_view.dart';
import '../../features/sbc/presentation/view/sbc_list_view.dart';
import '../../features/settings/presentation/view/design_system_view.dart';
import '../../features/settings/presentation/view/settings_view.dart';
import '../../features/store/presentation/view/store_view.dart';
import '../../shared/widgets/ref/ref_ui.dart';
import '../auth/session_manager.dart';
import '../theme/ref_tokens.dart';
import 'app_routes.dart';

/// Uygulamanin yonlendirme (navigasyon) yapisi.
///
/// Oturum durumu [SessionManager]'dan okunur. Jeton gecersiz oldugunda
/// (ornek: refresh token da suresi dolmus) SessionManager kendini
/// temizler, dinleyicileri uyarir ve kullanici otomatik olarak giris
/// ekranina yonlendirilir.
class AppRouter {
  final SessionManager _session;

  AppRouter(this._session);

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    // Oturum degisince yonlendirme yeniden hesaplansin
    refreshListenable: _session,
    redirect: _handleRedirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterView(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeView(),
      ),
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, state) => const CollectionView(),
      ),
      GoRoute(
        path: AppRoutes.deck,
        builder: (context, state) => const DeckView(),
      ),
      GoRoute(
        path: AppRoutes.matchmaking,
        builder: (context, state) => const MatchmakingView(),
      ),
      GoRoute(
        path: '${AppRoutes.match}/:matchId',
        builder: (context, state) => MatchView(
          matchId: state.pathParameters['matchId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileView(),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        builder: (context, state) => const LeaderboardView(),
      ),
      GoRoute(
        path: AppRoutes.leagueTiers,
        builder: (context, state) => const LeagueTiersView(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsView(),
      ),
      GoRoute(
        path: AppRoutes.designSystem,
        builder: (context, state) => const DesignSystemView(),
      ),
      GoRoute(
        path: AppRoutes.characterPreview,
        builder: (context, state) => const CharacterPreviewView(),
      ),
      GoRoute(
        path: AppRoutes.stylePrototype,
        builder: (context, state) => const StylePrototypeView(),
      ),
      GoRoute(
        path: AppRoutes.store,
        builder: (context, state) => const StoreView(),
      ),
      // Ekonomi V2 (FAZ 1): sandıklar ve olasılıklar
      GoRoute(
        path: AppRoutes.chests,
        builder: (context, state) => const ChestsView(),
      ),
      GoRoute(
        path: AppRoutes.chestOdds,
        builder: (context, state) => const ChestOddsView(),
      ),
      GoRoute(
        path: AppRoutes.progress,
        builder: (context, state) => const ProgressView(),
      ),
      GoRoute(
        path: AppRoutes.inventory,
        builder: (context, state) => const InventoryView(),
      ),
      GoRoute(
        path: AppRoutes.season,
        builder: (context, state) => const SeasonView(),
      ),
      GoRoute(
        path: AppRoutes.sbc,
        builder: (context, state) => const SbcListView(),
        routes: [
          GoRoute(
            path: ':challengeId',
            // Gorev nesnesi listeden `extra` ile geciriliyor: ayri bir
            // istek atmadan sartlari ve odulu biliyoruz.
            builder: (context, state) {
              final gorev = state.extra;
              if (gorev is! SbcChallenge) {
                // Dogrudan bu adrese gelinmisse (derin baglanti) listeye don
                return const SbcListView();
              }
              return SbcBuilderView(challenge: gorev);
            },
          ),
        ],
      ),
    ],
    // Bilinmeyen adres (eski bağlantı, elle yazılmış yol): referans
    // dilinde boş durum + oyuncuyu çıkmazda bırakmayan ana sayfa düğmesi.
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: Ref.phoneBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            // Kaydırılabilir alan: panel içeriği kadar yer kaplar (Center
            // içinde tam ekrana uzuyordu) ve çok küçük ekranda taşmaz.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: RefCardPanel(
                padding: const EdgeInsets.all(20),
                children: [
                  const Center(child: Em('🧭', size: 46)),
                  Text('SAYFA BULUNAMADI', textAlign: TextAlign.center, style: Ref.h2()),
                  Text(
                    'Bu adreste bir ekran yok. Bağlantı eskimiş ya da yanlış yazılmış olabilir.',
                    textAlign: TextAlign.center,
                    style: Ref.bodyText(12, color: Ref.muted),
                  ),
                  RefCta('ANA SAYFAYA DÖN', fontSize: 19, onTap: () => context.go(AppRoutes.home)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// Oturum durumuna gore yonlendirme karari
  String? _handleRedirect(BuildContext context, GoRouterState state) {
    final konum = state.matchedLocation;

    // Acilis ekrani kendi yonlendirmesini yapar
    if (konum == AppRoutes.splash) return null;

    // Cihazdaki oturum henuz okunmadiysa karar verme
    if (!_session.isReady) return null;

    final girisYapildi = _session.isSignedIn;
    final girisEkranindaMi =
        konum == AppRoutes.login || konum == AppRoutes.register;

    // Giris yapilmamis ve korunan bir ekrana gidiliyorsa -> giris
    if (!girisYapildi && !girisEkranindaMi) return AppRoutes.login;

    // Giris yapilmis ama giris/kayit ekranina gidiliyorsa -> ana sayfa
    if (girisYapildi && girisEkranindaMi) return AppRoutes.home;

    return null;
  }
}
