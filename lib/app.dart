import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:provider/provider.dart';

import 'core/audio/audio_route_listener.dart';
import 'core/auth/session_manager.dart';
import 'core/di/injection.dart';
import 'core/l10n/app_language.dart';
import 'core/l10n/language_rebuilder.dart';
import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/viewmodel/auth_view_model.dart';
import 'features/friends/friend_room_api.dart';
import 'ui_v21/theme/v21_scroll_behavior.dart';

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
  late final AudioRouteListener _music = AudioRouteListener(getIt<AppRouter>().router);

  @override
  void initState() {
    super.initState();
    AppLanguageController.instance.addListener(_dilDegisti);
    // Ekran değiştikçe doğru müzik (menü / arama / maç)
    _music.attach();
    // Webde davet adresi doğrudan rotaya gelir; uygulama bağlantısı eklentisi yok
    if (kIsWeb) return;
    _inviteSubscription = AppLinks().uriLinkStream.listen((uri) {
      final code = FriendRoomApi.inviteCodeFromUri(uri);
      if (code == null) return;
      getIt<AppRouter>().router.go(AppRoutes.friendInviteWithCode(code));
    });
  }

  /// Dil değişti: MaterialApp yeni dille kurulur (tarih seçici gibi
  /// Flutter metinleri). Ekranların kendisini [LanguageRebuilder] çizer.
  void _dilDegisti() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppLanguageController.instance.removeListener(_dilDegisti);
    _music.detach();
    _inviteSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appRouter = getIt<AppRouter>();

    return MultiProvider(
      providers: [
        // Oturum durumu: her ekran kullanici adini, coin'ini buradan okur
        ChangeNotifierProvider<SessionManager>.value(value: getIt<SessionManager>()),
        ChangeNotifierProvider<AuthViewModel>(create: (_) => getIt<AuthViewModel>()),
      ],
      child: MaterialApp.router(
        title: 'Futbol Card Arena',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: appRouter.router,
        scrollBehavior: const V21ScrollBehavior(),
        // Sistem yazı boyutu çok büyükse yerleşim taşmasın
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.2,
          child: LanguageRebuilder(child: child ?? const SizedBox.shrink()),
        ),

        // Uygulama dili: Ayarlar > DİL (Türkçe / English)
        locale: AppLanguageController.instance.value.locale,
        supportedLocales: [for (final l in AppLanguage.values) l.locale],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
