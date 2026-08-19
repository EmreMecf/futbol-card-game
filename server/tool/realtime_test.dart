import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

/// GERCEK ZAMANLI BILDIRIM TESTI
///
/// Su zinciri uctan uca dogrular:
///   PostgreSQL trigger -> pg_notify -> sunucunun LISTEN'i -> WebSocket -> istemci
///
/// Calistirmak icin (sunucu ayaktayken):
///   dart run tool/realtime_test.dart
Future<void> main() async {
  const base = 'http://localhost:8080/api';
  const wsBase = 'ws://localhost:8080/ws';

  final client = HttpClient();
  final rastgele = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

  Future<Map<String, dynamic>> istek(
    String metot,
    String yol, {
    Map<String, dynamic>? govde,
    String? token,
  }) async {
    final req = await client.openUrl(metot, Uri.parse('$base$yol'));
    req.headers.set('content-type', 'application/json');
    if (token != null) req.headers.set('authorization', 'Bearer $token');
    if (govde != null) req.write(jsonEncode(govde));

    final res = await req.close();
    final metin = await res.transform(utf8.decoder).join();
    final json = jsonDecode(metin) as Map<String, dynamic>;

    if (res.statusCode >= 400) {
      throw Exception('HTTP ${res.statusCode}: ${json['message']}');
    }
    return json;
  }

  print('=' * 60);
  print('1) Iki test oyuncusu olusturuluyor');
  print('=' * 60);

  final oyuncular = <String, Map<String, dynamic>>{};

  for (final ad in ['ws1', 'ws2']) {
    final kadi = '${ad}_$rastgele';
    final cevap = await istek('POST', '/auth/register', govde: {
      'email': '$kadi@test.com',
      'password': 'sifre123',
      'username': kadi,
    });

    final token = cevap['tokens']['access_token'] as String;
    final desteler = await istek('GET', '/game/decks', token: token);

    oyuncular[ad] = {
      'username': kadi,
      'token': token,
      'id': cevap['user']['id'],
      'deck_id': desteler['decks'][0]['id'],
    };
    print('  $kadi hazir');
  }

  print('');
  print('=' * 60);
  print('2) ws1 WebSocket ile baglaniyor');
  print('=' * 60);

  final socket = WebSocketChannel.connect(
    Uri.parse('$wsBase?token=${oyuncular['ws1']!['token']}'),
  );
  await socket.ready;

  final gelenler = <Map<String, dynamic>>[];
  socket.stream.listen((dynamic mesaj) {
    final veri = jsonDecode(mesaj as String) as Map<String, dynamic>;
    gelenler.add(veri);
    print('  << ${veri['type']}  ${veri['match_id'] ?? veri['status'] ?? ''}');
  });

  await Future<void>.delayed(const Duration(milliseconds: 500));

  print('');
  print('=' * 60);
  print('3) ws1 kuyruga giriyor, ws2 eslesiyor');
  print('=' * 60);

  final s1 = await istek('POST', '/match/find',
      govde: {'deck_id': oyuncular['ws1']!['deck_id']},
      token: oyuncular['ws1']!['token'] as String);
  print('  ws1 -> ${s1['status']}');

  final s2 = await istek('POST', '/match/find',
      govde: {'deck_id': oyuncular['ws2']!['deck_id']},
      token: oyuncular['ws2']!['token'] as String);
  print('  ws2 -> ${s2['status']}  mac: ${s2['match_id']}');

  final macId = s2['match_id'] as String;

  // Bildirimlerin ulasmasi icin kisa bekleme
  await Future<void>.delayed(const Duration(seconds: 2));

  final eslesmeBildirimi = gelenler.any(
    (m) => m['type'] == 'queue_updated' && m['match_id'] == macId,
  );
  print('');
  print('  Eslesme bildirimi ws1\'e ulasti mi: '
      '${eslesmeBildirimi ? "EVET" : "HAYIR"}');

  print('');
  print('=' * 60);
  print('4) Sirasi gelen oyuncu kart oynuyor');
  print('=' * 60);

  final durum = await istek('GET', '/match/$macId/state',
      token: oyuncular['ws1']!['token'] as String);
  final sirasiOlan = durum['is_my_turn'] == true ? 'ws1' : 'ws2';
  print('  Sira: ${oyuncular[sirasiOlan]!['username']}');

  final el = await istek('GET', '/match/$macId/hand',
      token: oyuncular[sirasiOlan]!['token'] as String);
  final kart = (el['cards'] as List).first as Map<String, dynamic>;

  final oncekiSayi = gelenler.length;

  await istek('POST', '/match/$macId/play',
      govde: {'user_card_id': kart['user_card_id']},
      token: oyuncular[sirasiOlan]!['token'] as String);
  print('  Oynanan kart: ${kart['full_name']} (${kart['position']})');

  await Future<void>.delayed(const Duration(seconds: 2));

  final yeniBildirimler = gelenler.length - oncekiSayi;
  print('');
  print('  Hamle sonrasi ws1\'e ulasan bildirim sayisi: $yeniBildirimler');

  print('');
  print('=' * 60);
  final basarili = eslesmeBildirimi && yeniBildirimler > 0;
  print(basarili
      ? 'GERCEK ZAMANLI ZINCIR CALISIYOR'
      : 'SORUN VAR - bildirimler ulasmadi');
  print('=' * 60);
  print('Toplam alinan mesaj: ${gelenler.length}');
  for (final m in gelenler) {
    print('  - ${jsonEncode(m)}');
  }

  await socket.sink.close();
  client.close();
  exit(basarili ? 0 : 1);
}
