import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Acik WebSocket baglantilarini yonetir.
///
/// Bir kullanicinin birden fazla baglantisi olabilir (telefon + tablet,
/// ya da uygulama yeniden baglanirken eski soket henuz kapanmamis olabilir).
/// Bu yuzden kullanici basina bir KUME tutuyoruz.
class WsHub {
  final Map<String, Set<WebSocketChannel>> _connections = {};

  int get connectedUserCount => _connections.length;
  int get socketCount =>
      _connections.values.fold(0, (toplam, kume) => toplam + kume.length);

  void add(String userId, WebSocketChannel socket) {
    _connections.putIfAbsent(userId, () => <WebSocketChannel>{}).add(socket);
    // ignore: avoid_print
    print('[WS] Baglandi: $userId (toplam soket: $socketCount)');
  }

  void remove(String userId, WebSocketChannel socket) {
    final kume = _connections[userId];
    if (kume == null) return;

    kume.remove(socket);
    if (kume.isEmpty) _connections.remove(userId);

    // ignore: avoid_print
    print('[WS] Ayrildi: $userId (toplam soket: $socketCount)');
  }

  /// Tek bir kullaniciya mesaj gonderir.
  void sendTo(String userId, Map<String, dynamic> payload) {
    final kume = _connections[userId];
    if (kume == null || kume.isEmpty) return;

    final mesaj = jsonEncode(payload);

    // Kopyasi uzerinde gez: gonderim sirasinda soket kapanabilir.
    for (final socket in kume.toList()) {
      try {
        socket.sink.add(mesaj);
      } catch (e) {
        // ignore: avoid_print
        print('[WS] Gonderilemedi ($userId): $e');
        remove(userId, socket);
      }
    }
  }

  /// Birden fazla kullaniciya ayni mesaji gonderir.
  void sendToMany(Iterable<String> userIds, Map<String, dynamic> payload) {
    for (final id in userIds) {
      sendTo(id, payload);
    }
  }

  /// Tum baglantilari kapatir (sunucu kapanirken).
  Future<void> closeAll() async {
    for (final kume in _connections.values.toList()) {
      for (final socket in kume.toList()) {
        try {
          await socket.sink.close();
        } catch (_) {}
      }
    }
    _connections.clear();
  }
}
