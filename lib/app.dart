import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/auth/session_manager.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/viewmodel/auth_view_model.dart';

/// Uygulamanin kok widget'i.
///
/// PROVIDER KULLANIMI:
/// Sadece uygulama boyunca yasamasi gereken nesneler burada tanimlanir.
/// Tek bir ekrana ait ViewModel'ler ilgili ekranin icinde
/// ChangeNotifierProvider ile olusturulur ki ekran kapaninca bellekten
/// silinsinler.
class FutbolCardApp extends StatefulWidget {
  const FutbolCardApp({super.key});

  @override
  State<FutbolCardApp> createState() => _FutbolCardAppState();
}

class _FutbolCardAppState extends State<FutbolCardApp> {
  StreamSubscription<Uri>? _inviteSubscription;

  @override
  void initState() {
    super.initState();
    _inviteSubscription = AppLinks().uriLinkStream.listen((uri) {
      if (uri.scheme != 'futbolcard' || uri.pathSegments.length != 2 ||
          uri.pathSegments[0] != 'davet') {
        return;
      }
      final code = uri.pathSegments[1].toLowerCase();
      const allowed = '0123456789abcdef';
      if (code.length != 30 ||
          code.split('').any((ch) => !allowed.contains(ch))) {
        return;
      }
      getIt<AppRouter>().router.go(AppRoutes.friendInviteWithCode(code));
    });
  }

  @override
  void dispose() {
    _inviteSubscription?.cancel();
    super.dispose();
  }

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
