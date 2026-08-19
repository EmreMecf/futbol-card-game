import 'dart:async';
import 'dart:convert';

import 'package:shared_models/shared_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/session_manager.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';

/// Sunucuyla kalici WebSocket baglantisini yonetir.
///
/// SORUMLULUKLARI:
///   * Baglanti kurmak ve jetonu iletmek
///   * Baglanti koptugunda ARTAN GECIKMEYLE tekrar denemek
///   * Gelen olaylari tek bir yayin (broadcast) akisina donusturmek
///
/// Uygulama boyunca TEK ornek yasar (Get_It'te singleton). Boylece
/// ekranlar arasi gecerken baglanti kopmaz.
///
/// Gelen olay tipi [RealtimeEvent] paylasilan pakettedir; sunucu da
/// ayni tanimi kullanir.
class WebSocketService {
  final SessionManager _session;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _abonelik;
  Timer? _yenidenBaglanmaZamanlayici;
  Timer? _pingZamanlayici;

  final _olaylar = StreamController<RealtimeEvent>.broadcast();
  final _baglantiDurumu = StreamController<bool>.broadcast();

  bool _kapatildi = false;
  bool _bagli = false;
  int _denemeSayisi = 0;

  WebSocketService(this._session);

  /// Sunucudan gelen tum olaylar (teknik gurultu ayiklanmis)
  Stream<RealtimeEvent> get events => _olaylar.stream;

  /// true = bagli, false = kopuk
  Stream<bool> get connectionState => _baglantiDurumu.stream;

  bool get isConnected => _bagli;

  // ------------------------------------------------------------------
  // BAGLAN
  // ------------------------------------------------------------------
  Future<void> connect() async {
    if (_kapatildi) return;

    final token = _session.accessToken;
    if (token == null) {
      AppLogger.warning('Jeton yok, WebSocket baglanmiyor.', tag: 'WS');
      return;
    }

    await _temizle();

    try {
      final adres = Uri.parse('${AppConfig.wsUrl}?token=$token');
      AppLogger.info('Baglaniliyor: ${AppConfig.wsUrl}', tag: 'WS');

      final channel = WebSocketChannel.connect(adres);
      _channel = channel;

      // ready, el sikismasi tamamlanana kadar bekler
      await channel.ready;

      _bagli = true;
      _denemeSayisi = 0;
      _baglantiDurumu.add(true);
      AppLogger.info('Baglandi.', tag: 'WS');

      _abonelik = channel.stream.listen(
        _mesajGeldi,
        onDone: _baglantiKapandi,
        onError: (Object hata) {
          AppLogger.warning('Baglanti hatasi: $hata', tag: 'WS');
          _baglantiKapandi();
        },
        cancelOnError: true,
      );

      _pingBaslat();
    } catch (e) {
      AppLogger.warning('Baglanilamadi: $e', tag: 'WS');
      _baglantiKapandi();
    }
  }

  void _mesajGeldi(dynamic mesaj) {
    try {
      final json = jsonDecode(mesaj as String) as Map<String, dynamic>;
      final olay = RealtimeEvent.fromJson(json);

      // pong ve connected sadece baglantiyi ilgilendirir, ekrani degil
      if (olay.isNoise) return;

      AppLogger.info('Olay: ${olay.type.name} (mac: ${olay.matchId})', tag: 'WS');
      _olaylar.add(olay);
    } catch (e) {
      AppLogger.warning('Mesaj cozulemedi: $e', tag: 'WS');
    }
  }

  // ------------------------------------------------------------------
  // BAGLANTI KOPTU -> ARTAN GECIKMEYLE TEKRAR DENE
  // ------------------------------------------------------------------
  //
  // Sunucu kapaliyken saniyede bir denemek hem pili tuketir hem de
  // sunucu ayaga kalkarken onu bogar. Bu yuzden gecikme her denemede
  // ikiye katlanir: 1sn, 2sn, 4sn, 8sn... en fazla 30 saniye.
  void _baglantiKapandi() {
    if (_bagli) {
      _bagli = false;
      _baglantiDurumu.add(false);
    }

    _pingZamanlayici?.cancel();

    if (_kapatildi || _session.accessToken == null) return;

    _denemeSayisi++;
    final saniye = _denemeSayisi > 5 ? 30 : (1 << (_denemeSayisi - 1));

    AppLogger.info(
      'Baglanti koptu. $saniye saniye sonra tekrar denenecek '
      '(deneme $_denemeSayisi).',
      tag: 'WS',
    );

    _yenidenBaglanmaZamanlayici?.cancel();
    _yenidenBaglanmaZamanlayici = Timer(Duration(seconds: saniye), connect);
  }

  /// Bazi ag donanimlari 60 saniye sessiz kalan baglantiyi kapatir.
  /// Duzenli ping bunu engeller.
  void _pingBaslat() {
    _pingZamanlayici?.cancel();
    _pingZamanlayici = Timer.periodic(const Duration(seconds: 25), (_) {
      try {
        _channel?.sink.add('ping');
      } catch (_) {
        _baglantiKapandi();
      }
    });
  }

  Future<void> _temizle() async {
    _pingZamanlayici?.cancel();
    await _abonelik?.cancel();
    _abonelik = null;

    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Cikis yapildiginda cagrilir.
  Future<void> disconnect() async {
    _kapatildi = true;
    _yenidenBaglanmaZamanlayici?.cancel();
    await _temizle();

    if (_bagli) {
      _bagli = false;
      _baglantiDurumu.add(false);
    }
    AppLogger.info('Baglanti kapatildi.', tag: 'WS');
  }

  /// Yeniden giris yapildiginda cagrilir.
  Future<void> reconnect() async {
    _kapatildi = false;
    _denemeSayisi = 0;
    await connect();
  }

  Future<void> dispose() async {
    await disconnect();
    await _olaylar.close();
    await _baglantiDurumu.close();
  }
}
