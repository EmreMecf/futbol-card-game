import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/error/app_exception.dart';
import '../../core/l10n/app_language.dart';

/// Sunucunun kural mesajını gösterir ('Oda dolu.' gibi); bağlantı hatası ayrıdır.
String friendRoomErrorText(Object e) => e is AppException
    ? e.message
    : 'İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene.'.tr;

/// Arkadaş odası uçları (FriendRoomApi uygular; testlerde sahtesi verilir)
abstract interface class FriendRoomGateway {
  Future<Map<String, dynamic>> create();
  Future<Map<String, dynamic>> join(String code);
  Future<Map<String, dynamic>> status(String code);
  Future<Map<String, dynamic>> ready(String code, String? deckId);
  Future<Map<String, dynamic>> leave(String code);
  Future<String?> activeDeck();
}

/// İKİ KİŞİLİK ÖZEL ODA — durum ve kurallar
///
/// Geçerli durum her zaman sunucudan gelir. Oda beklemedeyken 2 saniyede
/// bir yoklanır; iki taraf hazır olup maç başlayınca [startedMatchId]
/// dolar ve ekran maça geçer. Geçici ağ hatası odayı kapatmaz.
class FriendRoomViewModel extends ChangeNotifier {
  FriendRoomViewModel(
    FriendRoomGateway Function() gateway, {
    this._onLeaveRoom,
    this._pollEvery = const Duration(seconds: 2),
  }) : _gatewayFactory = gateway;

  final FriendRoomGateway Function() _gatewayFactory;
  final Future<void> Function(String code)? _onLeaveRoom;
  final Duration _pollEvery;

  /// Sunucu bağlantısı ilk ihtiyaçta kurulur (ekran çizilirken değil)
  late final FriendRoomGateway _api = _gatewayFactory();

  static final _kodBicimi = RegExp(r'^[0-9a-f]{30}$');
  static String get _baglantiKesildi => 'Bağlantı kesildi, yeniden deneniyor.'.tr;

  String? _code;
  Map<String, dynamic>? _room;
  String? _error;
  bool _busy = false;
  String? _startedMatchId;
  Timer? _poll;
  bool _kapandi = false;

  String? get code => _code;
  Map<String, dynamic>? get room => _room;
  String? get error => _error;
  bool get busy => _busy;

  /// Maç başladı: ekran bu maça geçer (bir kez dolar)
  String? get startedMatchId => _startedMatchId;

  String? get status => _room?['status']?.toString();
  bool get isHost => _room?['is_host'] == true;
  bool get myReady => isHost ? (_room?['host_ready'] == true) : (_room?['guest_ready'] == true);
  bool get guestPresent => _room?['guest_name'] != null;
  String? get hostName => _room?['host_name']?.toString();
  String? get guestName => _room?['guest_name']?.toString();

  /// HAZIRIM düğmesi basılabilir mi?
  bool get canReady => !_busy && status == 'waiting' && (isHost || guestPresent) && !myReady;

  void _haber() {
    if (!_kapandi) notifyListeners();
  }

  /// Davet bağlantısıyla açıldıysa odaya katıl
  Future<void> start(String? inviteCode) async {
    if (inviteCode == null) return;
    // Bağlantıyla gelindi: kod baştan bilinir (katılma başarısız olsa da)
    _code = inviteCode.trim().toLowerCase();
    _haber();
    await join(inviteCode);
  }

  Future<void> create() => _yap(_api.create);

  Future<void> join(String raw) async {
    final kod = raw.trim().toLowerCase();
    if (!_kodBicimi.hasMatch(kod)) {
      _error = '30 karakterlik davet kodunu gir.'.tr;
      _haber();
      return;
    }
    // Kod, sunucu odayı döndürünce yazılır (elle girilen yanlış kodda form açık kalır)
    await _yap(() => _api.join(kod));
  }

  Future<void> ready() async {
    final kod = _code;
    if (kod == null || _busy) return;
    await _yap(() async {
      final deste = await _api.activeDeck();
      if (deste == null) throw const _AktifKadroYok();
      return _api.ready(kod, deste);
    });
  }

  /// Odadan çık (bekleyen dostluk daveti de geri çekilir)
  Future<void> leave() async {
    final kod = _code;
    _durdur();
    if (kod != null) {
      final cik = _onLeaveRoom;
      if (cik != null) unawaited(cik(kod));
      try {
        await _api.leave(kod);
      } catch (_) {
        // Çıkış iletilemezse oda süresi dolunca kendiliğinden kapanır
      }
    }
    _code = null;
    _room = null;
    _error = null;
    _haber();
  }

  Future<void> _yap(Future<Map<String, dynamic>> Function() eylem) async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _haber();
    try {
      _odaGeldi(await eylem());
    } on _AktifKadroYok {
      _error = 'Önce 11 kartlık aktif bir kadro hazırla.'.tr;
    } catch (e) {
      _error = friendRoomErrorText(e);
    } finally {
      _busy = false;
      _haber();
    }
  }

  void _odaGeldi(Map<String, dynamic> oda) {
    if (_kapandi) return;
    final kod = oda['code']?.toString();
    if (kod != null && kod.isNotEmpty) _code = kod;
    final mac = oda['match_id']?.toString();
    if (oda['status'] == 'started' && mac != null) {
      _durdur();
      _startedMatchId ??= mac;
      _haber();
      return;
    }
    final uyari = oda['notice']?.toString();
    _room = oda;
    if (uyari != null) {
      _error = uyari;
    } else if (_error == _baglantiKesildi) {
      _error = null;
    }
    if (_code != null && oda['status'] == 'waiting') {
      _poll ??= Timer.periodic(_pollEvery, (_) => refresh());
    } else {
      _durdur();
    }
    _haber();
  }

  /// Oda durumunu sunucudan yeniden sor (yoklama)
  Future<void> refresh() async {
    final kod = _code;
    if (kod == null || _busy || _startedMatchId != null || _kapandi) return;
    try {
      _odaGeldi(await _api.status(kod));
    } catch (_) {
      // Geçici ağ hatası daveti iptal etmez: oda açık kalır
      _error = _baglantiKesildi;
      _haber();
    }
  }

  void _durdur() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  void dispose() {
    _kapandi = true;
    _durdur();
    super.dispose();
  }
}

class _AktifKadroYok implements Exception {
  const _AktifKadroYok();
}
