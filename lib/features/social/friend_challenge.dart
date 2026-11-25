import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';

import '../../core/error/app_exception.dart';
import '../../core/l10n/app_language.dart';

/// 058 — ARKADAŞINI DOSTLUK MAÇINA ÇAĞIR
///
/// Akış:
///   1. Oyuncu arkadaş listesinde MAÇA ÇAĞIR'a basar: sunucu onun özel
///      odasını açar, arkadaşına anlık bildirim gönderir. Çağıran odaya
///      geçip bekler.
///   2. Arkadaşın uygulaması bildirimi alır, davetleri sorar ve ekranın
///      üstünde davet kutucuğunu gösterir (60 sn geri sayım).
///   3. KABUL: sunucu onu aynı odaya katar; uygulama odaya geçer.
///      REDDET / süre dolar: davet kapanır, çağırana haber gider.
///
/// Bağlantı koparsa davet kaybolmaz: bağlantı geri gelince ve oturum
/// açılınca bekleyen davetler yeniden sorulur.
class FriendChallenge {
  final String id;
  final String code;
  final String status;
  final String fromId;
  final String fromName;
  final int fromMmr;
  final String toName;

  /// Cihaz saatine göre bitiş (sunucunun "kalan saniye" bilgisinden)
  final DateTime expiresAt;

  /// Davetin toplam süresi (geri sayım çubuğu için)
  static const Duration lifetime = Duration(seconds: 60);

  const FriendChallenge({
    required this.id,
    required this.code,
    required this.status,
    required this.fromId,
    required this.fromName,
    required this.fromMmr,
    required this.toName,
    required this.expiresAt,
  });

  factory FriendChallenge.fromJson(Map<String, dynamic> j, {DateTime? now}) {
    final from = (j['from'] as Map?)?.cast<String, dynamic>() ?? const {};
    final to = (j['to'] as Map?)?.cast<String, dynamic>() ?? const {};
    final kalan = (j['seconds_left'] as num?)?.toInt() ?? 0;
    return FriendChallenge(
      id: j['id'].toString(),
      code: j['code']?.toString() ?? '',
      status: j['status']?.toString() ?? 'pending',
      fromId: from['id']?.toString() ?? '',
      fromName: from['username']?.toString() ?? 'Oyuncu'.tr,
      fromMmr: (from['mmr'] as num?)?.toInt() ?? 0,
      toName: to['username']?.toString() ?? '',
      expiresAt: (now ?? DateTime.now()).add(Duration(seconds: kalan)),
    );
  }

  Duration remaining(DateTime now) {
    final d = expiresAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}

/// Sunucu uçları (SocialApi uygular; testlerde sahtesi verilir)
abstract interface class FriendChallengeApi {
  Future<FriendChallenge> sendChallenge(String friendId);
  Future<List<FriendChallenge>> incomingChallenges();
  Future<FriendChallenge> acceptChallenge(String id);
  Future<FriendChallenge> declineChallenge(String id);
  Future<FriendChallenge> cancelChallenge(String id);
}

/// Davet kutucuğunun durumu. Uygulama boyunca tek örnek.
class FriendChallengeController extends ChangeNotifier {
  final FriendChallengeApi _api;
  final Stream<RealtimeEvent> _events;
  final Stream<bool> _connection;
  final bool Function() _isSignedIn;
  final Listenable? _sessionChanges;
  final DateTime Function() _now;

  FriendChallengeController(
    this._api, {
    required Stream<RealtimeEvent> events,
    required Stream<bool> connection,
    required bool Function() isSignedIn,
    Listenable? sessionChanges,
    DateTime Function()? now,
  })  : _events = events,
        _connection = connection,
        _isSignedIn = isSignedIn,
        _sessionChanges = sessionChanges,
        _now = now ?? DateTime.now;

  FriendChallenge? _current;

  /// Geri sayım için saat (testlerde sahte saat verilir)
  DateTime now() => _now();

  /// Gösterilen daveti ve sayacı temizle (oturum kapanınca, testlerde)
  void clear() => _goster(null);

  /// Ekranda gösterilecek davet (en yenisi). Yoksa null.
  FriendChallenge? get current => _current;

  bool _busy = false;
  bool get busy => _busy;

  /// Oyuncunun kapattığı (kaydırıp gizlediği) davetler: yeniden gösterilmez
  final Set<String> _gizli = {};

  /// Benim gönderdiğim, yanıt beklenen davetler: kimlik -> arkadaş adı
  final Map<String, String> _gonderilen = {};
  final Map<String, String> _gonderilenOda = {};

  final _mesajlar = StreamController<String>.broadcast();

  /// Kısa bilgi mesajları ("X davetini reddetti")
  Stream<String> get messages => _mesajlar.stream;

  StreamSubscription<RealtimeEvent>? _olayAboneligi;
  StreamSubscription<bool>? _baglantiAboneligi;
  Timer? _sureSayaci;
  bool _basladi = false;
  bool _oturumAcikti = false;

  /// Dinlemeye başla (birden çok çağrı zararsız)
  void start() {
    if (_basladi) return;
    _basladi = true;
    _olayAboneligi = _events.listen(_olay);
    _baglantiAboneligi = _connection.listen((bagli) {
      if (bagli) unawaited(refresh());
    });
    _sessionChanges?.addListener(_oturumDegisti);
    _oturumAcikti = _isSignedIn();
    if (_oturumAcikti) unawaited(refresh());
  }

  void _oturumDegisti() {
    final acik = _isSignedIn();
    if (acik == _oturumAcikti) return;
    _oturumAcikti = acik;
    if (acik) {
      unawaited(refresh());
    } else {
      _gizli.clear();
      _gonderilen.clear();
      _gonderilenOda.clear();
      _goster(null);
    }
  }

  void _olay(RealtimeEvent e) {
    if (!e.isFriendChallenge) return;
    final id = e.challengeId;
    if (e.type == RealtimeEventType.friendChallengeUpdate && id != null && _gonderilen.containsKey(id)) {
      final ad = _gonderilen[id]!;
      final mesaj = switch (e.status) {
        'accepted' => '{name} davetini kabul etti!'.trArgs({'name': ad}),
        'declined' => '{name} davetini reddetti.'.trArgs({'name': ad}),
        'expired' => '{name} davete yanıt vermedi.'.trArgs({'name': ad}),
        _ => null,
      };
      if (e.status != 'pending') {
        _gonderilen.remove(id);
        _gonderilenOda.remove(id);
      }
      if (mesaj != null) _mesajlar.add(mesaj);
    }
    // Gelen davet ya da gösterilenin durumu değişti: listeyi yeniden sor
    if (e.type == RealtimeEventType.friendChallenge || id == null || id == _current?.id) {
      unawaited(refresh());
    }
  }

  /// Bekleyen davetleri sunucudan sor
  Future<void> refresh() async {
    if (!_isSignedIn()) {
      _goster(null);
      return;
    }
    try {
      final liste = await _api.incomingChallenges();
      final simdi = _now();
      FriendChallenge? sec;
      for (final c in liste) {
        if (_gizli.contains(c.id) || c.remaining(simdi) == Duration.zero) continue;
        sec = c;
        break;
      }
      _goster(sec);
    } catch (_) {
      // Ağ hatası: mevcut durum korunur, bağlantı gelince yeniden sorulur
    }
  }

  void _goster(FriendChallenge? c) {
    _sureSayaci?.cancel();
    _current = c;
    if (c != null) {
      // Süre dolunca kutucuk kendiliğinden kapanır
      _sureSayaci = Timer(c.remaining(_now()) + const Duration(milliseconds: 300), () {
        if (_current?.id == c.id) {
          _current = null;
          notifyListeners();
          unawaited(refresh());
        }
      });
    }
    notifyListeners();
  }

  /// KABUL: odaya katılır. Başarılıysa oda kodunu döndürür.
  Future<String?> accept() async {
    final c = _current;
    if (c == null || _busy) return null;
    _busy = true;
    notifyListeners();
    try {
      final sonuc = await _api.acceptChallenge(c.id);
      _goster(null);
      return sonuc.code.isNotEmpty ? sonuc.code : c.code;
    } on AppException catch (e) {
      _mesajlar.add(e.message);
      _gizli.add(c.id);
      unawaited(refresh());
      return null;
    } catch (_) {
      _mesajlar.add('İşlem tamamlanamadı. Bağlantını kontrol edip tekrar dene.'.tr);
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// REDDET: çağırana haber gider
  Future<void> decline() async {
    final c = _current;
    if (c == null || _busy) return;
    _gizli.add(c.id);
    _goster(null);
    try {
      await _api.declineChallenge(c.id);
    } catch (_) {
      // Ret iletilemezse davet 60 sn içinde kendiliğinden kapanır
    }
    unawaited(refresh());
  }

  /// Kaydırıp kapat: davet açık kalır ama bu cihazda bir daha gösterilmez
  void dismiss() {
    final c = _current;
    if (c == null) return;
    _gizli.add(c.id);
    _goster(null);
    unawaited(refresh());
  }

  /// Arkadaşı çağır. Oda kodunu döndürür (çağıran odaya geçer).
  Future<FriendChallenge> send(String friendId, String friendName) async {
    final c = await _api.sendChallenge(friendId);
    _gonderilen[c.id] = friendName;
    _gonderilenOda[c.id] = c.code;
    return c;
  }

  /// Çağıran odadan çıktı: o odadan giden bekleyen daveti geri çek
  Future<void> cancelForRoom(String code) async {
    final idler = [for (final e in _gonderilenOda.entries) if (e.value == code) e.key];
    for (final id in idler) {
      _gonderilen.remove(id);
      _gonderilenOda.remove(id);
      try {
        await _api.cancelChallenge(id);
      } catch (_) {
        // Geri çekilemezse davet süresi dolunca kapanır
      }
    }
  }

  @override
  void dispose() {
    _olayAboneligi?.cancel();
    _baglantiAboneligi?.cancel();
    _sessionChanges?.removeListener(_oturumDegisti);
    _sureSayaci?.cancel();
    _mesajlar.close();
    super.dispose();
  }
}
