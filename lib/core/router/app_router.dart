import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_models/shared_models.dart';

import '../../features/auth/presentation/view/login_view.dart';
import '../../features/auth/presentation/view/register_view.dart';
import '../../features/auth/presentation/view/splash_view.dart';
import '../../features/collection/presentation/view/collection_view.dart';
import '../../features/deck/presentation/view/deck_view.dart';
import '../../features/home/presentation/view/home_view.dart';
import '../../features/match/presentation/view/match_view.dart';
import '../../features/matchmaking/presentation/view/matchmaking_view.dart';
import '../../features/profile/presentation/view/profile_view.dart';
import '../../features/sbc/presentation/view/sbc_builder_view.dart';
import '../../features/sbc/presentation/view/sbc_list_view.dart';
import '../../features/settings/presentation/view/settings_view.dart';
import '../../features/store/presentation/view/store_view.dart';
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
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsView(),
      ),
      GoRoute(
        path: AppRoutes.store,
        builder: (context, state) => const StoreView(),
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
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sayfa bulunamadi:\n${state.uri}',
            textAlign: TextAlign.center,
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
