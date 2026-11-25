// ARKADAŞ ODASI ViewModel'i: oda kurma, katılma, hazır, yoklama, çıkış, maça geçiş
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_card/core/error/app_exception.dart';
import 'package:futbol_card/features/friends/friend_room_view_model.dart';

const _kod = '0123456789abcdef0123456789abcd';

class _SahteOda implements FriendRoomGateway {
  Map<String, dynamic> oda = {'status': 'waiting', 'code': _kod, 'is_host': true, 'host_ready': false};
  String? deste = 'deste-1';
  Object? hata;
  bool baglantiYok = false;
  int durumSorgusu = 0;
  final cikilan = <String>[];
  final hazir = <String?>[];

  Future<Map<String, dynamic>> _cevap() async {
    if (hata != null) throw hata!;
    return Map.of(oda);
  }

  @override
  Future<Map<String, dynamic>> create() => _cevap();
  @override
  Future<Map<String, dynamic>> join(String code) => _cevap();
  @override
  Future<Map<String, dynamic>> status(String code) async {
    durumSorgusu++;
    if (baglantiYok) throw Exception('ag');
    return _cevap();
  }

  @override
  Future<Map<String, dynamic>> ready(String code, String? deckId) {
    hazir.add(deckId);
    return _cevap();
  }

  @override
  Future<Map<String, dynamic>> leave(String code) async {
    cikilan.add(code);
    return {'status': 'left'};
  }

  @override
  Future<String?> activeDeck() async => deste;
}

void main() {
  late _SahteOda api;
  late FriendRoomViewModel vm;
  final geriCekilen = <String>[];

  setUp(() {
    api = _SahteOda();
    geriCekilen.clear();
    vm = FriendRoomViewModel(() => api, onLeaveRoom: (k) async => geriCekilen.add(k));
  });

  tearDown(() => vm.dispose());

  test('oda kurulunca kod ve durum gelir', () async {
    await vm.create();
    expect(vm.code, _kod);
    expect(vm.status, 'waiting');
    expect(vm.isHost, isTrue);
    expect(vm.busy, isFalse);
  });

  test('elle girilen geçersiz kod sunucuya gitmez, form açık kalır', () async {
    await vm.join('kisa');
    expect(vm.error, '30 karakterlik davet kodunu gir.');
    expect(vm.code, isNull);
  });

  test('katılma reddedilirse sunucu mesajı gösterilir, form açık kalır', () async {
    api.hata = const AppException(message: 'Oda dolu.');
    await vm.join(_kod);
    expect(vm.error, 'Oda dolu.');
    expect(vm.code, isNull);
  });

  test('davet bağlantısıyla gelince kod baştan bilinir', () async {
    api.hata = const AppException(message: 'Davetin süresi doldu.');
    await vm.start(_kod.toUpperCase());
    expect(vm.code, _kod);
    expect(vm.error, 'Davetin süresi doldu.');
  });

  test('hazır: aktif kadro gönderilir; kadro yoksa uyarı', () async {
    await vm.create();
    await vm.ready();
    expect(api.hazir, ['deste-1']);

    api.deste = null;
    await vm.ready();
    expect(vm.error, 'Önce 11 kartlık aktif bir kadro hazırla.');
  });

  test('beklerken yoklanır; ağ hatası odayı kapatmaz; maç başlayınca durur', () {
    fakeAsync((zaman) {
      vm = FriendRoomViewModel(() => api);
      vm.create();
      zaman.flushMicrotasks();
      zaman.elapse(const Duration(seconds: 4));
      expect(api.durumSorgusu, 2);

      api.baglantiYok = true;
      zaman.elapse(const Duration(seconds: 2));
      expect(vm.error, 'Bağlantı kesildi, yeniden deneniyor.');
      expect(vm.code, _kod, reason: 'oda açık kalır');

      api.baglantiYok = false;
      api.oda = {'status': 'started', 'code': _kod, 'match_id': 'mac-1'};
      zaman.elapse(const Duration(seconds: 2));
      expect(vm.startedMatchId, 'mac-1');
      final sorgu = api.durumSorgusu;
      zaman.elapse(const Duration(seconds: 10));
      expect(api.durumSorgusu, sorgu, reason: 'maç başlayınca yoklama durur');
    });
  });

  test('çıkış: sunucuya iletilir, bekleyen davet geri çekilir, durum temizlenir', () async {
    await vm.create();
    await vm.leave();
    expect(api.cikilan, [_kod]);
    expect(geriCekilen, [_kod]);
    expect(vm.code, isNull);
    expect(vm.room, isNull);
  });

  test('HAZIRIM yalnız uygunken basılabilir', () async {
    api.oda = {'status': 'waiting', 'code': _kod, 'is_host': false, 'guest_ready': false};
    await vm.create();
    expect(vm.canReady, isFalse, reason: 'misafir, oda sahibi gelmeden hazır olamaz (guest_name yok)');
    api.oda = {'status': 'waiting', 'code': _kod, 'is_host': true, 'host_ready': true};
    await vm.create();
    expect(vm.canReady, isFalse, reason: 'zaten hazır');
  });
}
