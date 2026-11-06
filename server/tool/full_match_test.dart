import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';

/// TAM MAC SIMULASYONU
///
/// Iki oyuncu olusturur, WebSocket ile baglar, eslestirir ve maci
/// SONUNA KADAR oynatir. Boylece su zincirin tamami dogrulanir:
///
///   REST -> PostgreSQL -> pg_notify -> LISTEN -> WebSocket -> istemci
///
/// Calistirmak icin (sunucu ayaktayken):
///   dart run tool/full_match_test.dart
Future<void> main() async {
  const base = 'http://localhost:8080/api';
  const wsBase = 'ws://localhost:8080/ws';

  final client = HttpClient();
  final damga = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

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
      throw Exception('HTTP ${res.statusCode} $yol: ${json['message']}');
    }
    return json;
  }

  void baslik(String metin) {
    print('');
    print('=' * 62);
    print(metin);
    print('=' * 62);
  }

  // ==================================================================
  baslik('1) IKI OYUNCU OLUSTURULUYOR');
  // ==================================================================
  final oyuncular = <String, Map<String, dynamic>>{};

  for (final ad in ['mac1', 'mac2']) {
    final kadi = '${ad}_$damga';
    final cevap = await istek('POST', '/auth/register', govde: {
      'email': '$kadi@test.com',
      'password': 'sifre123',
      'username': kadi,
    });

    final token = cevap['tokens']['access_token'] as String;
    final desteler = await istek('GET', '/game/decks', token: token);
    final deste = (desteler['decks'] as List).first as Map<String, dynamic>;

    // Kadronun kartlarini al (koruma secimi icin)
    final kartlar = await istek(
      'GET',
      '/game/decks/${deste['id']}/cards',
      token: token,
    );
    final kartListesi = (kartlar['cards'] as List)
        .map((k) => (k as Map<String, dynamic>)['user_card_id'] as String)
        .toList();

    oyuncular[ad] = {
      'username': kadi,
      'token': token,
      'id': cevap['user']['id'],
      'deck_id': deste['id'],
      // Ilk 3 karti korumaya al
      'protected': kartListesi.take(3).toList(),
      'events': <String>[],
    };

    print('  $kadi hazir  (${deste['card_count']} kartlik kadro, '
        '3 kart korumada)');
  }

  // ==================================================================
  baslik('2) WEBSOCKET BAGLANTILARI');
  // ==================================================================
  final soketler = <String, WebSocketChannel>{};

  for (final ad in oyuncular.keys) {
    final socket = WebSocketChannel.connect(
      Uri.parse('$wsBase?token=${oyuncular[ad]!['token']}'),
    );
    await socket.ready;

    socket.stream.listen((dynamic mesaj) {
      final veri = jsonDecode(mesaj as String) as Map<String, dynamic>;
      (oyuncular[ad]!['events'] as List<String>).add(veri['type'] as String);
    });

    soketler[ad] = socket;
    print('  ${oyuncular[ad]!['username']} baglandi');
  }

  await Future<void>.delayed(const Duration(milliseconds: 400));

  // ==================================================================
  baslik('3) ESLESTIRME');
  // ==================================================================
  Future<Map<String, dynamic>> macAra(String ad) {
    return istek('POST', '/match/find',
        govde: {
          'deck_id': oyuncular[ad]!['deck_id'],
          'protected_card_ids': oyuncular[ad]!['protected'],
        },
        token: oyuncular[ad]!['token'] as String);
  }

  final s1 = await macAra('mac1');
  print('  mac1 -> ${s1['status']}');

  final s2 = await macAra('mac2');
  print('  mac2 -> ${s2['status']}   mac: ${s2['match_id']}');

  final macId = s2['match_id'] as String;
  await Future<void>.delayed(const Duration(milliseconds: 600));

  // ==================================================================
  baslik('4) GIZLILIK KONTROLU');
  // ==================================================================
  final eller = <String, Set<String>>{};

  for (final ad in oyuncular.keys) {
    final el = await istek('GET', '/match/$macId/hand',
        token: oyuncular[ad]!['token'] as String);
    eller[ad] = (el['cards'] as List)
        .map((k) => (k as Map<String, dynamic>)['user_card_id'] as String)
        .toSet();
    print('  ${oyuncular[ad]!['username']}: ${eller[ad]!.length} kart goruyor');
  }

  final kesisim = eller['mac1']!.intersection(eller['mac2']!);
  if (kesisim.isNotEmpty) {
    print('  !!! GIZLILIK IHLALI: ${kesisim.length} ortak kart');
    exit(1);
  }
  print('  Ortak kart: 0  -> kimse rakibin elini goremiyor');

  // ==================================================================
  baslik('5) MAC OYNANIYOR');
  // ==================================================================
  var tur = 0;
  var hamleSayisi = 0;

  // ---- TAKTIK KONTROLLERI (021_tactics.sql) ----
  var taktikliHamle = 0;
  var gizlilikKontrolu = 0;
  var taktikHatasi = false;

  // Enerjinin yettigi en pahali taktigi sec (sirayla cesitlilik icin
  // bazen daha ucuzunu)
  String taktikSec(int enerji, int sira) {
    const secenekler = [
      ['high_press', 3],
      ['counter_attack', 2],
      ['defensive_wall', 1],
    ];
    final uygun =
        secenekler.where((t) => (t[1] as int) <= enerji).toList();
    if (uygun.isEmpty || sira % 4 == 3) return 'none';
    return uygun[sira % uygun.length][0] as String;
  }

  // Ilk hamlede enerji 2: pres (3) REDDEDILMELI
  {
    final d = await istek('GET', '/match/$macId/state',
        token: oyuncular['mac1']!['token'] as String);
    final ad = d['is_my_turn'] == true ? 'mac1' : 'mac2';
    final t = oyuncular[ad]!['token'] as String;
    final el = await istek('GET', '/match/$macId/hand', token: t);
    final k = (el['cards'] as List).first as Map<String, dynamic>;
    try {
      await istek('POST', '/match/$macId/play',
          govde: {'user_card_id': k['user_card_id'], 'tactic': 'high_press'},
          token: t);
      print('  !!! Enerji yetmedigi halde pres KABUL EDILDI');
      taktikHatasi = true;
    } on Exception catch (e) {
      print('  Enerji 2 iken pres reddedildi: $e');
    }
    if (d['my_energy'] != 2 || d['opponent_energy'] != 2) {
      print('  !!! Baslangic enerjisi 2 degil: $d');
      taktikHatasi = true;
    }
  }

  while (true) {
    if (hamleSayisi > 60) {
      print('  !!! Mac bitmedi, guvenlik siniri asildi');
      exit(1);
    }

    // Durumu mac1 gozunden oku
    final durum = await istek('GET', '/match/$macId/state',
        token: oyuncular['mac1']!['token'] as String);

    if (durum['status'] != 'active') break;

    final yeniTur = durum['round_number'] as int;
    if (yeniTur != tur) {
      tur = yeniTur;
      stdout.write('\n  Tur $tur: ');
    }

    // Sira kimde?
    final sirasiOlan = durum['is_my_turn'] == true ? 'mac1' : 'mac2';
    final token = oyuncular[sirasiOlan]!['token'] as String;

    // Zorunlu pozisyon var mi?
    final zorunlu = durum['required_position'] as String?;

    // Elden uygun kart sec
    final el = await istek('GET', '/match/$macId/hand', token: token);
    final kartlar = (el['cards'] as List).cast<Map<String, dynamic>>();

    final uygun = kartlar.where((k) {
      if (k['is_played'] == true) return false;
      if (zorunlu == null) return true;
      return k['position'] == zorunlu;
    }).toList();

    if (uygun.isEmpty) {
      // Pas gec
      await istek('POST', '/match/$macId/play', govde: {}, token: token);
      stdout.write('[${sirasiOlan == 'mac1' ? 'A' : 'B'}:PAS] ');
    } else {
      final kart = uygun.first;
      final enerji = (sirasiOlan == 'mac1'
          ? durum['my_energy']
          : durum['opponent_energy']) as int;
      final taktik = taktikSec(enerji, hamleSayisi);
      if (taktik != 'none') taktikliHamle++;

      await istek('POST', '/match/$macId/play',
          govde: {'user_card_id': kart['user_card_id'], 'tactic': taktik},
          token: token);
      stdout.write('[${sirasiOlan == 'mac1' ? 'A' : 'B'}:'
          '${kart['position']}${kart['power']}'
          '${taktik == 'none' ? '' : '+${taktik.split('_').first}'}] ');

      // GIZLILIK: turu ACTIYSAK, rakip bu taktigi GORMEMELI;
      // biz kendi taktigimizi gormeliyiz.
      if (zorunlu == null && taktik != 'none') {
        final rakip = sirasiOlan == 'mac1' ? 'mac2' : 'mac1';
        Future<Map<String, dynamic>?> sonHamle(String kim) async {
          final h = await istek('GET', '/match/$macId/moves',
              token: oyuncular[kim]!['token'] as String);
          return (h['moves'] as List)
              .cast<Map<String, dynamic>>()
              .where((m) => m['round_number'] == tur && m['is_lead'] == true)
              .firstOrNull;
        }

        final rakibinGordugu = await sonHamle(rakip);
        final benimGordugum = await sonHamle(sirasiOlan);
        gizlilikKontrolu++;
        if (rakibinGordugu?['tactic'] != null) {
          print('\n  !!! GIZLILIK IHLALI: rakip taktigi goruyor: '
              '${rakibinGordugu?['tactic']}');
          taktikHatasi = true;
        }
        if (benimGordugum?['tactic'] != taktik) {
          print('\n  !!! Kendi taktigimi goremiyorum: $benimGordugum');
          taktikHatasi = true;
        }
      }
    }

    hamleSayisi++;
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  print('');
  print('');
  print('  Toplam $hamleSayisi hamle oynandi.');
  print('  Taktikli hamle: $taktikliHamle, gizlilik kontrolu: '
      '$gizlilikKontrolu');

  // Mac bitince BUTUN taktikler herkese acik olmali ve bonuslar
  // sunucunun SQL kurallariyla tutarli olmali.
  {
    final h = await istek('GET', '/match/$macId/moves',
        token: oyuncular['mac1']!['token'] as String);
    final hamleler = (h['moves'] as List).cast<Map<String, dynamic>>();
    final gizli = hamleler.where((m) => m['tactic'] == null).length;
    final bonuslu =
        hamleler.where((m) => (m['tactic_bonus'] as int? ?? 0) > 0).length;
    print('  Mac sonunda gizli kalan taktik: $gizli, bonus alan hamle: '
        '$bonuslu');
    if (gizli > 0) taktikHatasi = true;
    if (taktikliHamle > 0 && bonuslu == 0) {
      print('  !!! Taktik oynandi ama hic bonus hesaplanmadi');
      taktikHatasi = true;
    }
  }

  await Future<void>.delayed(const Duration(seconds: 1));

  // ==================================================================
  baslik('6) MAC SONUCU');
  // ==================================================================
  for (final ad in oyuncular.keys) {
    final sonuc = await istek('GET', '/match/$macId/result',
        token: oyuncular[ad]!['token'] as String);

    final kaybedilen = (sonuc['cards_lost'] as List).length;
    final kazanilan = (sonuc['cards_won'] as List).length;
    final profil = sonuc['my_profile'] as Map<String, dynamic>;

    print('');
    print('  ${oyuncular[ad]!['username']}');
    print('    Sonuc  : ${sonuc['did_i_win'] == true ? "KAZANDI" : (sonuc['is_draw'] == true ? "BERABERE" : "KAYBETTI")}');
    print('    Skor   : ${sonuc['my_score']} - ${sonuc['opponent_score']}');
    print('    Kart   : -$kaybedilen / +$kazanilan');
    print('    Profil : ${profil['coins']} coin, ${profil['mmr']} puan, '
        '${profil['protection_slots']} koruma hakki');

    if (kaybedilen > 0) {
      for (final k in sonuc['cards_lost'] as List) {
        final kart = k as Map<String, dynamic>;
        print('      kaybedildi: ${kart['tier']} ${kart['power']} '
            '${kart['full_name']}');
      }
    }
  }

  // ==================================================================
  baslik('7) GERCEK ZAMANLI BILDIRIMLER');
  // ==================================================================
  var hepsiTamam = !taktikHatasi;
  if (taktikHatasi) print('  !!! TAKTIK KONTROLLERINDE HATA VAR (yukari bak)');

  for (final ad in oyuncular.keys) {
    final olaylar = oyuncular[ad]!['events'] as List<String>;
    final sayim = <String, int>{};
    for (final o in olaylar) {
      sayim[o] = (sayim[o] ?? 0) + 1;
    }

    print('  ${oyuncular[ad]!['username']}: ${olaylar.length} olay');
    sayim.forEach((tip, adet) => print('    $tip: $adet'));

    if (!olaylar.contains('match_finished')) {
      print('    !!! match_finished bildirimi ULASMADI');
      hepsiTamam = false;
    }
    if (!olaylar.contains('move_played')) {
      print('    !!! move_played bildirimi ULASMADI');
      hepsiTamam = false;
    }
  }

  // ==================================================================
  baslik(hepsiTamam ? 'TUM ZINCIR CALISIYOR' : 'BILDIRIMLERDE SORUN VAR');
  // ==================================================================

  for (final s in soketler.values) {
    await s.sink.close();
  }
  client.close();
  exit(hepsiTamam ? 0 : 1);
}
