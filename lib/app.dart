import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/auth/session_manager.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/viewmodel/auth_view_model.dart';

/// Uygulamanin kok widget'i.
///
/// PROVIDER KULLANIMI:
/// Sadece uygulama boyunca yasamasi gereken nesneler burada tanimlanir.
/// Tek bir ekrana ait ViewModel'ler ilgili ekranin icinde
/// ChangeNotifierProvider ile olusturulur ki ekran kapaninca bellekten
/// silinsinler.
class FutbolCardApp extends StatelessWidget {
  const FutbolCardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = getIt<AppRouter>();

    return MultiProvider(
      providers: [
        // Oturum durumu: her ekran kullanici adini, coin'ini buradan okur
        ChangeNotifierProvider<SessionManager>.value(
          value: getIt<SessionManager>(),
        ),
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => getIt<AuthViewModel>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Futbol Kart',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: appRouter.router,

        // Uygulama dili Turkce
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
