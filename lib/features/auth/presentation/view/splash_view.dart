import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../ui_v21/foundation/v21_assets.dart';
import '../../../../ui_v21/screens/auth/v21_splash_art.dart';

/// Açılış ekranı (MD bölüm 4-A): stadyum ışıkları yanar, logo belirir,
/// sonra cihazdaki oturuma göre doğru ekrana geçilir.
///
/// ===================================================================
/// SÜRE
/// ===================================================================
/// V2.1 yükleme görseli 1,6 sn görünür: çubuk 1,4 sn'de dolar, görsel
/// fark edilecek kadar ekranda kalır.
///
/// Oyuncu ayarlardan kart animasyonlarını kapattıysa ışıklar ve logo
/// doğrudan son hâliyle çizilir.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  static const Duration bekleme = Duration(milliseconds: 1600);

  late final AnimationController _kontrolcu;

  @override
  void initState() {
    super.initState();
    _kontrolcu = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    if (GameFeedback.cardAnimationsEnabled) {
      _kontrolcu.forward();
    } else {
      _kontrolcu.value = 1;
    }

    _yonlendir();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Görsel ilk karede hazır olsun
    precacheImage(const AssetImage(V21Assets.loadingSplash), context);
  }

  @override
  void dispose() {
    _kontrolcu.dispose();
    super.dispose();
  }

  Future<void> _yonlendir() async {
    await Future<void>.delayed(bekleme);
    if (!mounted) return;

    final session = getIt<SessionManager>();
    context.go(session.isSignedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _kontrolcu,
        builder: (context, _) => V21SplashArt(progress: _kontrolcu.value),
      ),
    );
  }
}
