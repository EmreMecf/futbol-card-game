import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';
import 'game_audio.dart';

/// Hangi ekranda hangi müziğin çalacağı (tek yer).
///
///   /eslesme   → rakip arama döngüsü
///   /mac/...   → maç müziği (maç sonu jingle'ı müziği kendisi durdurur)
///   diğerleri  → menü müziği
Music? musicForPath(String path) {
  if (path.startsWith('${AppRoutes.match}/')) return Music.match;
  if (path == AppRoutes.matchmaking) return Music.search;
  return Music.menu;
}

/// Rota değiştikçe [GameAudio]'ya doğru müziği söyler.
///
/// Yalnız ADRES değişince tepki verir: aynı ekranda yeniden çizim
/// (ör. maç sonu jingle'ından sonra) müziği yeniden başlatmaz.
class AudioRouteListener {
  AudioRouteListener(this._router);

  final GoRouter _router;
  String? _lastPath;

  void attach() {
    _router.routerDelegate.addListener(_onChange);
    _onChange();
  }

  void detach() => _router.routerDelegate.removeListener(_onChange);

  void _onChange() {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    if (path == _lastPath) return;
    _lastPath = path;
    GameAudio.music(musicForPath(path));
  }
}
