import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';

/// Acilis ekrani. Cihazda kayitli oturum var mi diye bakip
/// dogru ekrana yonlendirir.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _yonlendir();
  }

  Future<void> _yonlendir() async {
    // Logonun bir an gorunmesi icin kisa bir bekleme
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final session = getIt<SessionManager>();
    context.go(session.isSignedIn ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_soccer, size: 88, color: AppColors.accent),
            SizedBox(height: 20),
            Text(
              'FUTBOL KART',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Efsaneler sahaya iniyor',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
