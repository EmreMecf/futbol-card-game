import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/feedback/game_feedback.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/game/game_ui.dart';
import '../../../../shared/widgets/walkout/spotlight_backdrop.dart';
import '../../../../ui_v21/foundation/v21_assets.dart';
import '../../../../ui_v21/screens/auth/v21_splash_art.dart';
import '../../../../ui_v21/v21_flags.dart';

/// Açılış ekranı (MD bölüm 4-A): stadyum ışıkları yanar, logo belirir,
/// sonra cihazdaki oturuma göre doğru ekrana geçilir.
///
/// ===================================================================
/// SÜRE
/// ===================================================================
/// V2.1 yükleme görseli 1,6 sn görünür: çubuk 1,4 sn'de dolar, görsel
/// fark edilecek kadar ekranda kalır. Eski görünümde süre 900 ms'dir.
///
/// Oyuncu ayarlardan kart animasyonlarını kapattıysa ışıklar ve logo
/// doğrudan son hâliyle çizilir.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  static const Duration bekleme = Duration(milliseconds: kV21Splash ? 1600 : 900);

  late final AnimationController _kontrolcu;

  @override
  void initState() {
    super.initState();
    _kontrolcu = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kV21Splash ? 1400 : 700),
    );

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
    if (kV21Splash) precacheImage(const AssetImage(V21Assets.loadingSplash), context);
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
    // V2.1 görünüm: yalnız çizim değişir, süre ve yönlendirme aynı
    if (kV21Splash) {
      return Scaffold(
        body: AnimatedBuilder(
          animation: _kontrolcu,
          builder: (context, _) => V21SplashArt(progress: _kontrolcu.value),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        animation: _kontrolcu,
        // Logo bir kez kuruluyor; her karede sadece dönüşüm değişiyor
        child: const GameLogo(size: 46),
        builder: (context, logo) {
          final t = _kontrolcu.value;
          // Işıklar ilk %60'ta yanar, logo %25'ten sonra belirir
          final isik = Curves.easeOut.transform((t / 0.6).clamp(0.0, 1.0));
          final logoT = Curves.easeOutBack.transform(
            ((t - 0.25) / 0.75).clamp(0.0, 1.0),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              SpotlightBackdrop(
                progress: isik,
                sway: 0.25,
                color: AppColors.emerald,
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: logoT.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.82 + 0.18 * logoT,
                        child: logo,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: AppColors.victoryGold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
