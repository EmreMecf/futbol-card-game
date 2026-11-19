import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

import '../../features/auth/presentation/view/login_view.dart';
import '../../features/auth/presentation/view/register_view.dart';
import '../../features/auth/presentation/view/splash_view.dart';
import '../../features/friends/friend_room_view.dart';
import '../../ui_v21/screens/arena/v21_arena_screen.dart';
import '../../ui_v21/screens/arena/v21_matchmaking_screen.dart';
import '../../ui_v21/screens/collection/v21_collection_screen.dart';
import '../../ui_v21/screens/home/v21_home_screen.dart';
import '../../ui_v21/screens/inner/v21_inner_screens.dart';
import '../../ui_v21/screens/season/v21_season_screen.dart';
import '../../ui_v21/screens/store/v21_store_screen.dart';
import '../../ui_v21/screens/deck/v21_deck_screen.dart';
import '../../ui_v21/ui_v21.dart';
import '../auth/session_manager.dart';
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
        builder: (context, state) => const V21HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.collection,
        builder: (context, state) => const V21CollectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.deck,
        builder: (context, state) => const V21DeckScreen(),
      ),
      GoRoute(
        path: AppRoutes.friends,
        builder: (context, state) => const FriendRoomView(),
      ),
      GoRoute(
        path: '${AppRoutes.friendInvite}/:code',
        builder: (context, state) => FriendRoomView(inviteCode: state.pathParameters['code']),
      ),
      GoRoute(
        path: AppRoutes.matchmaking,
        builder: (context, state) => const V21MatchmakingScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.match}/:matchId',
        builder: (context, state) => V21ArenaScreen(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const V21ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.leaderboard,
        builder: (context, state) => const V21LeaderboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.leagueTiers,
        builder: (context, state) => const V21LeagueScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const V21SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.store,
        builder: (context, state) => const V21StoreScreen(),
      ),
      // Ekonomi V2 (FAZ 1): sandıklar ve olasılıklar
      GoRoute(
        path: AppRoutes.chests,
        builder: (context, state) => const V21ChestsScreen(),
      ),
      GoRoute(
        path: AppRoutes.chestOdds,
        builder: (context, state) => const V21ChestOddsScreen(),
      ),
      GoRoute(
        path: AppRoutes.progress,
        builder: (context, state) => const V21ProgressScreen(),
      ),
      GoRoute(
        path: AppRoutes.inventory,
        builder: (context, state) => const V21InventoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.season,
        builder: (context, state) => const V21SeasonScreen(),
      ),
      GoRoute(
        path: AppRoutes.sbc,
        builder: (context, state) => const V21SbcScreen(),
        routes: [
          GoRoute(
            path: ':challengeId',
            // Gorev nesnesi listeden `extra` ile geciriliyor: ayri bir
            // istek atmadan sartlari ve odulu biliyoruz.
            builder: (context, state) {
              final gorev = state.extra;
              if (gorev is! SbcChallenge) {
                // Dogrudan bu adrese gelinmisse (derin baglanti) listeye don
                return const V21SbcScreen();
              }
              return V21SbcBuilderScreen(challenge: gorev);
            },
          ),
        ],
      ),
    ],
    // Bilinmeyen adres (eski bağlantı, elle yazılmış yol): referans
    // dilinde boş durum + oyuncuyu çıkmazda bırakmayan ana sayfa düğmesi.
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: V21Colors.inkDeep,
      body: SafeArea(
        child: Center(
          child: V21EmptyState(
            icon: Icons.explore_off_rounded,
            title: 'SAYFA BULUNAMADI',
            message: 'Bu adreste bir ekran yok. Bağlantı eskimiş ya da yanlış yazılmış olabilir.',
            actionLabel: 'ANA SAYFAYA DÖN',
            onAction: () => context.go(AppRoutes.home),
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
    if (!girisYapildi && !girisEkranindaMi) return AppRoutes.loginFor(state.uri.path);

    // Giris yapilmis ama giris/kayit ekranina gidiliyorsa -> ana sayfa
    if (girisYapildi && girisEkranindaMi) return AppRoutes.afterAuth(state.uri);

    return null;
  }
}
