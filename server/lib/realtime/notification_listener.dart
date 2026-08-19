import 'dart:async';
import 'dart:convert';

import '../db/database.dart';
import 'ws_hub.dart';

/// PostgreSQL'in NOTIFY bildirimlerini dinler ve ilgili oyunculara
/// WebSocket uzerinden iletir.
///
/// AKIS:
///   1. Veritabaninda bir sey degisir (sira rakibe gecer)
///   2. Trigger  -> pg_notify('match_events', {...})
///   3. BU SINIF -> bildirimi alir
///   4. WsHub    -> iki oyuncuya da mesaj gonderir
///   5. Flutter  -> get_match_state cagirip ekrani gunceller
///
/// NEDEN DETAY GONDERMIYORUZ?
/// Bildirim sadece "hangi macta ne oldu" der. Uygulamanin detayi ayrica
/// istemesi gerekir. Bunun iki faydasi var:
///   * pg_notify'in 8000 baytlik siniri asilmaz,
///   * bildirim kanalindan yanlislikla gizli veri (rakibin eli) sizamaz.
class NotificationListener {
  final Database _db;
  final WsHub _hub;

  StreamSubscription<String>? _macAboneligi;
  StreamSubscription<String>? _kuyrukAboneligi;

  NotificationListener(this._db, this._hub);

  Future<void> start() async {
    final conn = _db.listenConnection;

    // ---- MAC OLAYLARI ----
    _macAboneligi = conn.channels['match_events'].listen(
      _handleMatchEvent,
      onError: (Object e) {
        // ignore: avoid_print
        print('[NOTIFY] match_events hatasi: $e');
      },
    );

    // ---- ESLESTIRME OLAYLARI ----
    _kuyrukAboneligi = conn.channels['queue_events'].listen(
      _handleQueueEvent,
      onError: (Object e) {
        // ignore: avoid_print
        print('[NOTIFY] queue_events hatasi: $e');
      },
    );

    // ignore: avoid_print
    print('[NOTIFY] Veritabani bildirimleri dinleniyor.');
  }

  void _handleMatchEvent(String payload) {
    try {
      final veri = jsonDecode(payload) as Map<String, dynamic>;

      final p1 = veri['player1']?.toString();
      final p2 = veri['player2']?.toString();

      final mesaj = {
        'type': veri['event'],
        'match_id': veri['match_id'],
        'at': veri['at'],
      };

      _hub.sendToMany([if (p1 != null) p1, if (p2 != null) p2], mesaj);
    } catch (e) {
      // ignore: avoid_print
      print('[NOTIFY] match_events cozulemedi: $e | $payload');
    }
  }

  void _handleQueueEvent(String payload) {
    try {
      final veri = jsonDecode(payload) as Map<String, dynamic>;
      final userId = veri['user_id']?.toString();
      if (userId == null) return;

      _hub.sendTo(userId, {
        'type': 'queue_updated',
        'status': veri['status'],
        'match_id': veri['match_id'],
        'at': veri['at'],
      });
    } catch (e) {
      // ignore: avoid_print
      print('[NOTIFY] queue_events cozulemedi: $e | $payload');
    }
  }

  Future<void> stop() async {
    await _macAboneligi?.cancel();
    await _kuyrukAboneligi?.cancel();
  }
}
