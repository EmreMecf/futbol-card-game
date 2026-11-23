// =====================================================================
// ROBOT OYUNCULARLA CANLI TEST
// =====================================================================
// İki robot oyuncu sunucuya gerçek bir oyuncu gibi bağlanır: kayıt olur
// (ya da giriş yapar), WebSocket açar, dereceli ve arkadaş maçlarını
// baştan sona oynar. Her adımda sunucunun cevabını denetler ve beklenmeyen
// her durumu HATA olarak yazar.
//
// Kullanım (proje klasöründen):
//   dart run tool/canli_test/robot_mac.dart --sunucu http://127.0.0.1:8090 --mac 5
//   dart run tool/canli_test/robot_mac.dart --sunucu https://...onrender.com --mac 2 --hesaplar hesaplar.txt
//
// --hesaplar verilmezse her çalıştırmada yeni iki hesap açılır (yerel test
// için). Dosya verilirse içindeki iki hesapla giriş yapılır; biçimi:
//   e-posta şifre
//   e-posta şifre
// Bu dosya gizlidir; depoya eklenmez.
//
// Çıkış kodu: hata yoksa 0, varsa 1.
// =====================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

final _rnd = Random();
final _hatalar = <String>[];
final _uyarilar = <String>[];
var _ayrintili = false;

void _log(String s) => stdout.writeln('${DateTime.now().toIso8601String().substring(11, 19)}  $s');
void _hata(String s) {
  _hatalar.add(s);
  _log('HATA: $s');
}

void _uyari(String s) {
  _uyarilar.add(s);
  _log('UYARI: $s');
}

class ApiHatasi implements Exception {
  final int durum;
  final String govde;
  ApiHatasi(this.durum, this.govde);
  @override
  String toString() => 'HTTP $durum: $govde';
}

class Robot {
  final String ad;
  final String sunucu;
  final HttpClient _http = HttpClient()..connectionTimeout = const Duration(seconds: 70);
  String? erisim;
  String? yenileme;
  String? kullaniciId;
  WebSocket? _ws;
  final olaylar = <Map<String, dynamic>>[];
  var wsBagli = false;

  Robot(this.ad, this.sunucu);

  Future<Map<String, dynamic>> istek(String yontem, String yol, [Map<String, dynamic>? govde]) async {
    final sure = Stopwatch()..start();
    final req = await _http.openUrl(yontem, Uri.parse('$sunucu/api$yol'));
    req.headers.contentType = ContentType.json;
    if (erisim != null) req.headers.set('authorization', 'Bearer $erisim');
    if (govde != null) req.write(jsonEncode(govde));
    final res = await req.close().timeout(const Duration(seconds: 70));
    final metin = await res.transform(utf8.decoder).join();
    sure.stop();
    if (sure.elapsedMilliseconds > 3000) _uyari('$ad $yontem $yol ${sure.elapsedMilliseconds} ms sürdü');
    if (_ayrintili) _log('  $ad $yontem $yol -> ${res.statusCode} (${sure.elapsedMilliseconds} ms)');
    if (res.statusCode == 401 && yenileme != null && yol != '/auth/refresh') {
      await jetonYenile();
      return istek(yontem, yol, govde);
    }
    if (res.statusCode >= 400) throw ApiHatasi(res.statusCode, metin);
    if (metin.isEmpty) return {};
    final j = jsonDecode(metin);
    return j is Map<String, dynamic> ? j : {'veri': j};
  }

  void _oturum(Map<String, dynamic> j) {
    final t = j['tokens'] as Map<String, dynamic>;
    erisim = t['access_token'] as String;
    yenileme = t['refresh_token'] as String;
    kullaniciId = (j['user'] as Map)['id'].toString();
  }

  Future<void> jetonYenile() async {
    final y = yenileme;
    erisim = null;
    _oturum(await istek('POST', '/auth/refresh', {'refresh_token': y}));
  }

  Future<void> kayit(String eposta, String sifre, String kullaniciAdi) async {
    _oturum(await istek('POST', '/auth/register', {'email': eposta, 'password': sifre, 'username': kullaniciAdi}));
  }

  Future<void> giris(String eposta, String sifre) async {
    _oturum(await istek('POST', '/auth/login', {'email': eposta, 'password': sifre}));
  }

  Future<void> wsBaglan() async {
    final wsAdres = sunucu.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    final ws = await WebSocket.connect('$wsAdres/ws?token=$erisim').timeout(const Duration(seconds: 70));
    _ws = ws;
    wsBagli = true;
    ws.listen(
      (m) {
        try {
          final j = jsonDecode(m as String) as Map<String, dynamic>;
          if (j['type'] != 'pong' && j['type'] != 'connected') olaylar.add(j);
        } catch (_) {}
      },
      onDone: () => wsBagli = false,
      onError: (_) => wsBagli = false,
    );
  }

  Future<void> kapat() async {
    await _ws?.close();
    _http.close(force: true);
  }

  Future<String> aktifKadro() async {
    final j = await istek('GET', '/game/decks');
    final kadrolar = (j['decks'] as List).cast<Map>();
    final aktif = kadrolar.firstWhere((d) => d['is_active'] == true, orElse: () => kadrolar.first);
    return aktif['id'].toString();
  }

  Future<String?> kadroSorunu(String kadroId) async {
    final j = await istek('GET', '/game/decks/$kadroId/validate');
    return j['is_valid'] == true ? null : (j['message']?.toString() ?? 'geçersiz');
  }

  Future<Map<String, dynamic>> durum(String macId) => istek('GET', '/match/$macId/state');

  Future<List<Map<String, dynamic>>> el(String macId) async {
    final j = await istek('GET', '/match/$macId/hand');
    return (j['cards'] as List).cast<Map<String, dynamic>>();
  }
}

// ---------------------------------------------------------------------
// MAÇ OYNATICI: iki robot aynı maçı sonuna kadar oynar
// ---------------------------------------------------------------------
const _taktikler = ['none', 'high_press', 'counter_attack', 'defensive_wall'];
const _mevkiler = ['GK', 'DEF', 'MID', 'FWD'];

Future<void> macOyna(String macId, Robot a, Robot b, {required String tur}) async {
  _log('[$tur] Maç başladı: $macId');
  final saat = Stopwatch()..start();
  var sonTur = 0;
  var degismeyen = 0;
  Map<String, dynamic>? sa;

  while (saat.elapsed < const Duration(minutes: 15)) {
    sa = await a.durum(macId);
    final sb = await b.durum(macId);

    // Tutarlılık: iki taraf aynı turu ve ters skoru görmeli
    if (sa['round_number'] != sb['round_number']) {
      // tur arası geçişte bir istek arayla değişebilir; tekrar oku
      final sa2 = await a.durum(macId);
      if (sa2['round_number'] != sb['round_number']) {
        _hata('[$tur] Tur numarası tutarsız: ${sa2['round_number']} / ${sb['round_number']}');
      }
    }
    if (sa['round_number'] == sb['round_number'] &&
        (sa['my_score'] != sb['opponent_score'] || sa['opponent_score'] != sb['my_score'])) {
      final sa2 = await a.durum(macId);
      final sb2 = await b.durum(macId);
      if (sa2['my_score'] != sb2['opponent_score'] || sa2['opponent_score'] != sb2['my_score']) {
        _hata('[$tur] Skor tutarsız: A ${sa2['my_score']}-${sa2['opponent_score']}, B ${sb2['my_score']}-${sb2['opponent_score']}');
      }
    }

    if (sa['status'] != 'active' && sa['status'] != 'waiting') break;

    final turNo = sa['round_number'] as int;
    if (turNo != sonTur) {
      sonTur = turNo;
      degismeyen = 0;
    } else {
      degismeyen++;
    }
    if (degismeyen > 120) {
      _hata('[$tur] Maç $turNo. turda takıldı (phase=${sa['phase']}, A oynadı=${sa['i_have_played']}, B oynadı=${sb['i_have_played']})');
      break;
    }

    var hamle = false;
    for (final (r, s) in [(a, sa), (b, sb)]) {
      if (s['status'] != 'active') continue;
      try {
        if (s['simultaneous'] == true) {
          if (s['phase'] == 'position' && s['am_i_lead'] == true) {
            final el = (await r.el(macId)).where((k) => k['is_played'] != true).toList();
            final eldekiler = el.map((k) => k['position']).toSet();
            final secenek = _mevkiler.where(eldekiler.contains).toList();
            if (secenek.isEmpty) {
              _hata('[$tur] ${r.ad} mevki seçmeli ama elinde kart yok');
              continue;
            }
            await r.istek('POST', '/match/$macId/position', {'position': secenek[_rnd.nextInt(secenek.length)]});
            hamle = true;
          } else if (s['phase'] == 'pick' && s['i_have_played'] != true) {
            await _kartOyna(r, s, macId, tur);
            hamle = true;
          }
        } else if (s['is_my_turn'] == true) {
          await _kartOyna(r, s, macId, tur);
          hamle = true;
        }
      } on ApiHatasi catch (e) {
        // Süre dolması ile hamle aynı anda olabilir; tek seferlik 400/409 normal
        if (e.durum >= 500) {
          _hata('[$tur] ${r.ad} hamlesinde sunucu hatası: $e');
        } else {
          _uyari('[$tur] ${r.ad} hamlesi reddedildi: $e');
        }
      }
    }
    await Future<void>.delayed(Duration(milliseconds: hamle ? 150 : 400));
  }

  final son = await a.durum(macId);
  final sonB = await b.durum(macId);
  if (son['status'] == 'active') {
    _hata('[$tur] Maç 15 dakikada bitmedi');
    return;
  }
  final kazanan = son['winner_id']?.toString();
  final berabere = son['is_draw'] == true;
  if (kazanan != (sonB['winner_id']?.toString())) _hata('[$tur] İki taraf farklı kazanan görüyor');
  if (!berabere && kazanan == null && son['status'] == 'finished') _hata('[$tur] Maç bitti ama kazanan yok ve berabere değil');

  // Sonuç ekranının verisi
  try {
    await a.istek('GET', '/match/$macId/result');
    await b.istek('GET', '/match/$macId/result');
  } on ApiHatasi catch (e) {
    _hata('[$tur] Sonuç okunamadı: $e');
  }
  final kim = berabere ? 'berabere' : (kazanan == a.kullaniciId ? a.ad : (kazanan == b.kullaniciId ? b.ad : '?'));
  _log('[$tur] Maç bitti (${saat.elapsed.inSeconds} sn): ${son['my_score']}-${son['opponent_score']}, kazanan: $kim, '
      'durum: ${son['status']}');
}

Future<void> _kartOyna(Robot r, Map<String, dynamic> s, String macId, String tur) async {
  final el = (await r.el(macId)).where((k) => k['is_played'] != true).toList();
  final gerekli = s['required_position'];
  final uygun = el.where((k) => gerekli == null || k['position'] == gerekli).toList();
  if (uygun.isEmpty) {
    // Uygun kart yoksa pas
    await r.istek('POST', '/match/$macId/play', {});
    return;
  }
  final kart = uygun[_rnd.nextInt(uygun.length)];
  final enerji = (s['my_energy'] as num?)?.toInt() ?? 0;
  final maliyetler = (s['tactic_costs'] as Map?)?.map((k, v) => MapEntry(k.toString(), (v as num).toInt())) ?? {};
  final taktikler = _taktikler.where((t) => t == 'none' || (maliyetler[t] ?? 99) <= enerji).toList();
  final taktik = taktikler[_rnd.nextInt(taktikler.length)];
  final sonuc = await r.istek('POST', '/match/$macId/play', {'user_card_id': kart['user_card_id'], 'tactic': taktik});
  if (sonuc.isEmpty) _uyari('[$tur] ${r.ad} hamlesine boş cevap geldi');
}

// ---------------------------------------------------------------------
// SENARYOLAR
// ---------------------------------------------------------------------
Future<void> derecelimac(Robot a, Robot b, int no) async {
  final tur = 'dereceli $no';
  for (final r in [a, b]) {
    final aktif = await r.istek('GET', '/match/active');
    if (aktif['match_id'] != null) {
      _uyari('[$tur] ${r.ad} önceki maçta kalmış, teslim oluyor');
      await r.istek('POST', '/match/${aktif['match_id']}/surrender', {});
    }
  }
  final kadroA = await a.aktifKadro();
  final kadroB = await b.aktifKadro();
  for (final (r, k) in [(a, kadroA), (b, kadroB)]) {
    final sorun = await r.kadroSorunu(k);
    if (sorun != null) {
      _hata('[$tur] ${r.ad} kadrosu geçersiz: $sorun');
      return;
    }
  }

  final ilk = await a.istek('POST', '/match/find', {'deck_id': kadroA});
  final ikinci = await b.istek('POST', '/match/find', {'deck_id': kadroB});
  String? macId = ikinci['match_id']?.toString() ?? ilk['match_id']?.toString();

  final saat = Stopwatch()..start();
  while (macId == null && saat.elapsed < const Duration(seconds: 60)) {
    await Future<void>.delayed(const Duration(seconds: 2));
    final x = await a.istek('POST', '/match/find', {'deck_id': kadroA});
    macId = x['match_id']?.toString() ?? (await a.istek('GET', '/match/active'))['match_id']?.toString();
  }
  if (macId == null) {
    _hata('[$tur] 60 saniyede eşleşme olmadı');
    await a.istek('POST', '/match/cancel', {});
    await b.istek('POST', '/match/cancel', {});
    return;
  }
  _log('[$tur] Eşleşme ${saat.elapsedMilliseconds} ms');

  final bAktif = (await b.istek('GET', '/match/active'))['match_id']?.toString();
  if (bAktif != macId) {
    // Uyarlanabilir eşleştirme robotu bota da eşleyebilir: o zaman B ayrı
    _uyari('[$tur] İki robot birbiriyle eşleşmedi (A: $macId, B: $bAktif); bota karşı oynanıyor olabilir');
    await b.istek('POST', '/match/cancel', {}).catchError((_) => <String, dynamic>{});
    // A'nın maçını bırak ki sonraki senaryolar "devam eden maçın var" almasın
    await a.istek('POST', '/match/$macId/surrender', {}).catchError((_) => <String, dynamic>{});
    return;
  }
  await macOyna(macId, a, b, tur: tur);
}

Future<void> arkadasMaci(Robot a, Robot b, int no) async {
  final tur = 'arkadaş $no';
  final oda = await a.istek('POST', '/friends/create');
  final kod = oda['code']?.toString();
  if (kod == null || !RegExp(r'^[0-9a-f]{30}$').hasMatch(kod)) {
    _hata('[$tur] Oda kodu geçersiz: $oda');
    return;
  }
  await b.istek('POST', '/friends/join', {'code': kod});
  final kadroA = await a.aktifKadro();
  final kadroB = await b.aktifKadro();
  await a.istek('POST', '/friends/$kod/ready', {'deck_id': kadroA});
  await b.istek('POST', '/friends/$kod/ready', {'deck_id': kadroB});

  String? macId;
  final saat = Stopwatch()..start();
  while (macId == null && saat.elapsed < const Duration(seconds: 20)) {
    final d = await a.istek('GET', '/friends/$kod');
    if (d['status'] == 'started') macId = d['match_id']?.toString();
    if (macId == null) await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  if (macId == null) {
    _hata('[$tur] İki oyuncu hazır olduğu halde maç başlamadı');
    return;
  }
  final mod = (await a.durum(macId))['mode'];
  if (mod != 'friendly') _hata('[$tur] Arkadaş maçının modu "$mod"');

  final oncekiA = await a.istek('GET', '/me');
  await macOyna(macId, a, b, tur: tur);
  final sonraA = await a.istek('GET', '/me');
  final mmr1 = (oncekiA['user'] as Map?)?['mmr'];
  final mmr2 = (sonraA['user'] as Map?)?['mmr'];
  if (mmr1 != mmr2) _hata('[$tur] Arkadaş maçı puanı değiştirdi ($mmr1 -> $mmr2)');
}

// ---------------------------------------------------------------------
// RAKİP MODU: elle oynayan bir oyuncuya rakip olur
// ---------------------------------------------------------------------
// dart run tool/canli_test/robot_mac.dart --rakip hesap.txt --dakika 20
// hesap.txt'nin ilk satırındaki hesapla sürekli dereceli rakip arar; maç
// bulunca insan gibi 2-4 sn düşünüp oynar. Maç bitince yeniden arar.
Future<void> rakipModu(String sunucu, String dosya, int dakika) async {
  final h = File(dosya).readAsLinesSync().first.trim().split(RegExp(r'\s+'));
  final r = Robot('Rakip', sunucu);
  await r.giris(h[0], h[1]);
  await r.wsBaglan();
  _log('Rakip hazır: ${h[0]} ($dakika dakika)');
  final bitis = DateTime.now().add(Duration(minutes: dakika));
  final kadro = await r.aktifKadro();
  var macSayisi = 0;

  while (DateTime.now().isBefore(bitis)) {
    try {
      final aktif = (await r.istek('GET', '/match/active'))['match_id']?.toString();
      if (aktif == null) {
        await r.istek('POST', '/match/find', {'deck_id': kadro});
        await Future<void>.delayed(const Duration(seconds: 3));
        continue;
      }
      final s = await r.durum(aktif);
      if (s['status'] != 'active') {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }
      if (s['round_number'] == 1 && s['i_have_played'] != true && s['phase'] == 'position') {
        _log('Maç bulundu: $aktif (rakip: ${(s['opponent'] as Map?)?['username']})');
      }
      final pozisyon = s['phase'] == 'position' && s['am_i_lead'] == true;
      final secim = s['phase'] == 'pick' && s['i_have_played'] != true;
      if (pozisyon || secim) {
        await Future<void>.delayed(Duration(milliseconds: 2000 + _rnd.nextInt(2000)));
        if (pozisyon) {
          final el = (await r.el(aktif)).where((k) => k['is_played'] != true).toList();
          final secenek = _mevkiler.where(el.map((k) => k['position']).toSet().contains).toList();
          if (secenek.isNotEmpty) {
            final m = secenek[_rnd.nextInt(secenek.length)];
            await r.istek('POST', '/match/$aktif/position', {'position': m});
            _log('Tur ${s['round_number']}: mevki $m');
          }
        } else {
          await _kartOyna(r, s, aktif, 'rakip');
          _log('Tur ${s['round_number']}: kart oynandı (skor ${s['my_score']}-${s['opponent_score']})');
        }
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      final son = await r.durum(aktif);
      if (son['status'] != 'active' && son['status'] != 'waiting') {
        macSayisi++;
        _log('Maç bitti: ${son['my_score']}-${son['opponent_score']} (${son['status']}). Toplam $macSayisi maç');
      }
    } on ApiHatasi catch (e) {
      _uyari('Rakip: $e');
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }
  await r.istek('POST', '/match/cancel', {}).catchError((_) => <String, dynamic>{});
  await r.kapat();
  _log('Rakip modu bitti.');
}

// ---------------------------------------------------------------------
Future<void> main(List<String> args) async {
  String arg(String ad, String vars) {
    final i = args.indexOf(ad);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : vars;
  }

  final sunucu = arg('--sunucu', 'http://127.0.0.1:8090');
  final rakipDosyasi = arg('--rakip', '');
  if (rakipDosyasi.isNotEmpty) {
    await rakipModu(sunucu, rakipDosyasi, int.parse(arg('--dakika', '20')));
    return;
  }
  final macSayisi = int.parse(arg('--mac', '3'));
  final hesapDosyasi = arg('--hesaplar', '');
  _ayrintili = args.contains('--ayrintili');

  _log('Sunucu: $sunucu');
  final a = Robot('Robot-A', sunucu);
  final b = Robot('Robot-B', sunucu);

  try {
    final saglik = await a.istek('GET', '/health');
    _log('Sağlık: ${saglik['status']}, veritabanı: ${saglik['database']}');

    if (hesapDosyasi.isNotEmpty && !File(hesapDosyasi).existsSync()) {
      // Dosya yoksa iki kalıcı test hesabı açılır ve dosyaya yazılır
      final ek = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      final sifreler = [for (var i = 0; i < 2; i++) 'Rb${_rnd.nextInt(1 << 30)}${_rnd.nextInt(1 << 30)}x'];
      final epostalar = ['robot-a-$ek@test.local', 'robot-b-$ek@test.local'];
      await a.kayit(epostalar[0], sifreler[0], 'TestA$ek'.substring(0, 12));
      await b.kayit(epostalar[1], sifreler[1], 'TestB$ek'.substring(0, 12));
      File(hesapDosyasi).writeAsStringSync('${epostalar[0]} ${sifreler[0]}\n${epostalar[1]} ${sifreler[1]}\n');
      _log('İki test hesabı açıldı ve $hesapDosyasi dosyasına yazıldı');
      for (final r in [a, b]) {
        final sorun = await r.kadroSorunu(await r.aktifKadro());
        if (sorun != null) _hata('${r.ad} yeni hesabın başlangıç kadrosu geçersiz: $sorun');
      }
    } else if (hesapDosyasi.isNotEmpty) {
      final satirlar = File(hesapDosyasi).readAsLinesSync().where((s) => s.trim().isNotEmpty).toList();
      final h1 = satirlar[0].trim().split(RegExp(r'\s+'));
      final h2 = satirlar[1].trim().split(RegExp(r'\s+'));
      await a.giris(h1[0], h1[1]);
      await b.giris(h2[0], h2[1]);
      _log('İki test hesabıyla giriş yapıldı');
    } else {
      final ek = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      final sifre = 'Rb${_rnd.nextInt(1 << 30)}x';
      await a.kayit('robot-a-$ek@test.local', sifre, 'RobotA$ek'.substring(0, 14));
      await b.kayit('robot-b-$ek@test.local', sifre, 'RobotB$ek'.substring(0, 14));
      _log('İki yeni hesap açıldı');
      for (final r in [a, b]) {
        final sorun = await r.kadroSorunu(await r.aktifKadro());
        if (sorun != null) _hata('${r.ad} yeni hesabın başlangıç kadrosu geçersiz: $sorun');
      }
    }

    await a.wsBaglan();
    await b.wsBaglan();

    for (var i = 1; i <= macSayisi; i++) {
      await derecelimac(a, b, i);
      await arkadasMaci(a, b, i);
    }
    for (final r in [a, b]) {
      if (!r.wsBagli) _hata('${r.ad} WebSocket bağlantısı test sırasında koptu');
      if (r.olaylar.isEmpty) _hata('${r.ad} test boyunca hiç gerçek zamanlı olay almadı');
      _log('${r.ad}: WebSocket ${r.wsBagli ? 'bağlı' : 'KOPUK'}, ${r.olaylar.length} olay alındı');
    }
  } catch (e, s) {
    _hata('Beklenmeyen hata: $e');
    if (_ayrintili) stderr.writeln(s);
  } finally {
    await a.kapat();
    await b.kapat();
  }

  stdout.writeln('\n========== SONUÇ ==========');
  stdout.writeln('Hata: ${_hatalar.length}, uyarı: ${_uyarilar.length}');
  for (final h in _hatalar) {
    stdout.writeln('  HATA  $h');
  }
  for (final u in _uyarilar.toSet()) {
    stdout.writeln('  UYARI $u');
  }
  exit(_hatalar.isEmpty ? 0 : 1);
}
