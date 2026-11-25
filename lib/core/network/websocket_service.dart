import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_models/shared_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/session_manager.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';
import '../l10n/server_text.dart';

/// Kanal ureten fonksiyon (testlerde sahte kanal verilebilir)
typedef WebSocketConnector = WebSocketChannel Function(Uri uri);

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
///
/// SAGLAMLIK KURALLARI (telefonda "surekli yeniden baglaniyor" hatasi):
///   * Ayni anda tek baglanti denemesi yasar. Yeni deneme eskisini
///     iptal eder; eski kanalin gec gelen kapanis bildirimi yeni
///     baglantiyi "kopuk" gostermez ([_nesil]).
///   * El sikisma sonsuza kadar beklenmez ([handshakeTimeout]).
///   * Suresi dolmus jetonla denenmez: gerekirse once jeton yenilenir.
///     Sunucu jetonu yalniz baglanirken dogruladigi icin eski jetonla
///     yapilan her deneme 401 alir ve sonsuza dek tekrarlanir.
///   * Sessizce olen baglanti (yarim acik TCP) [staleAfter] sonra
///     kapatilip yeniden kurulur.
///   * Uygulama one gelince kopuksa beklemeden yeniden denenir.
class WebSocketService {
  final SessionManager _session;
  final Future<bool> Function()? refreshToken;
  final WebSocketConnector _connector;

  /// Render gibi uyuyan sunucular ilk istekte ~30 sn uyanir
  final Duration handshakeTimeout;

  /// Bu kadar suredir sunucudan hic mesaj (pong dahil) gelmediyse
  /// baglanti olu sayilir
  final Duration staleAfter;

  /// Tekrar denemeler arasindaki en uzun bekleme
  static const maxRetryDelay = Duration(seconds: 10);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _abonelik;
  Timer? _yenidenBaglanmaZamanlayici;
  Timer? _pingZamanlayici;
  AppLifecycleListener? _yasamDongusu;

  final _olaylar = StreamController<RealtimeEvent>.broadcast();
  final _baglantiDurumu = StreamController<bool>.broadcast();

  bool _kapatildi = false;
  bool _bagli = false;
  int _denemeSayisi = 0;

  /// Her baglanti denemesinin kimligi. Eski denemelerin gec gelen
  /// sonuclari bu sayiyla ayiklanir.
  int _nesil = 0;

  /// Son el sikisma reddedildi: sonraki denemeden once jetonu yenile
  bool _jetonYenilensin = false;

  DateTime _sonMesaj = DateTime.now();

  WebSocketService(
    this._session, {
    this.refreshToken,
    WebSocketConnector? connector,
    this.handshakeTimeout = const Duration(seconds: 40),
    this.staleAfter = const Duration(seconds: 70),
  }) : _connector = connector ?? WebSocketChannel.connect;

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
    _yasamDongusunuDinle();

    final nesil = ++_nesil;
    _yenidenBaglanmaZamanlayici?.cancel();
    await _temizle();
    if (nesil != _nesil) return;

    // Suresi dolmus (ya da reddedilmis) jetonla denemenin anlami yok
    if (_jetonYenilensin || _jetonBitiyor(_session.accessToken)) {
      final yenile = refreshToken;
      if (yenile != null) {
        try {
          await yenile();
        } catch (_) {}
        if (nesil != _nesil) return;
      }
      _jetonYenilensin = false;
    }

    final token = _session.accessToken;
    if (token == null) {
      AppLogger.warning('Jeton yok, WebSocket baglanmiyor.', tag: 'WS');
      return;
    }

    WebSocketChannel? channel;
    try {
      final adres = Uri.parse('${AppConfig.wsUrl}?token=$token');
      AppLogger.info('Baglaniliyor: ${AppConfig.wsUrl}', tag: 'WS');

      channel = _connector(adres);
      _channel = channel;

      // ready, el sikismasi tamamlanana kadar bekler
      await channel.ready.timeout(handshakeTimeout);
      if (nesil != _nesil) {
        // Bu arada yeni bir deneme basladi; bu kanal artik fazlalik
        unawaited(_kanaliKapat(channel));
        return;
      }

      _bagli = true;
      _denemeSayisi = 0;
      _sonMesaj = DateTime.now();
      _baglantiDurumu.add(true);
      AppLogger.info('Baglandi.', tag: 'WS');

      _abonelik = channel.stream.listen(
        _mesajGeldi,
        onDone: () => _baglantiKapandi(nesil),
        onError: (Object hata) {
          AppLogger.warning('Baglanti hatasi: $hata', tag: 'WS');
          _baglantiKapandi(nesil);
        },
        cancelOnError: true,
      );

      _pingBaslat(nesil);
    } catch (e) {
      if (nesil != _nesil) return;
      AppLogger.warning('Baglanilamadi: $e', tag: 'WS');
      // El sikisma reddedildi: buyuk ihtimalle jeton suresi doldu
      if (e is! TimeoutException) _jetonYenilensin = true;
      if (channel != null) unawaited(_kanaliKapat(channel));
      if (identical(_channel, channel)) _channel = null;
      _baglantiKapandi(nesil);
    }
  }

  void _mesajGeldi(dynamic mesaj) {
    _sonMesaj = DateTime.now();
    try {
      final json = ServerText.translateJson(jsonDecode(mesaj as String)) as Map<String, dynamic>;
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
  // Gecikme her denemede ikiye katlanir: 1sn, 2sn, 4sn, 8sn, en fazla
  // 10 saniye. Mac sirasinda 30 saniye beklemek oyunu durdurur.
  void _baglantiKapandi(int nesil) {
    // Eski bir kanalin gec gelen kapanisi yeni baglantiyi etkilemez
    if (nesil != _nesil) return;

    if (_bagli) {
      _bagli = false;
      _baglantiDurumu.add(false);
    }

    _pingZamanlayici?.cancel();

    if (_kapatildi || _session.accessToken == null) return;

    _denemeSayisi++;
    final bekle = retryDelay(_denemeSayisi);

    AppLogger.info(
      'Baglanti koptu. ${bekle.inSeconds} saniye sonra tekrar denenecek '
      '(deneme $_denemeSayisi).',
      tag: 'WS',
    );

    _yenidenBaglanmaZamanlayici?.cancel();
    _yenidenBaglanmaZamanlayici = Timer(bekle, connect);
  }

  /// [deneme]. denemeden once beklenecek sure
  @visibleForTesting
  static Duration retryDelay(int deneme) {
    final saniye = deneme <= 1 ? 1 : 1 << (deneme - 1).clamp(0, 4);
    final d = Duration(seconds: saniye);
    return d > maxRetryDelay ? maxRetryDelay : d;
  }

  /// Bazi ag donanimlari 60 saniye sessiz kalan baglantiyi kapatir.
  /// Duzenli ping bunu engeller; pong gelmiyorsa baglanti oludur.
  void _pingBaslat(int nesil) {
    _pingZamanlayici?.cancel();
    _pingZamanlayici = Timer.periodic(const Duration(seconds: 25), (_) {
      if (nesil != _nesil) return;
      if (DateTime.now().difference(_sonMesaj) > staleAfter) {
        AppLogger.warning('Sunucu cevap vermiyor, baglanti yenileniyor.', tag: 'WS');
        final eski = _channel;
        if (eski != null) unawaited(_kanaliKapat(eski));
        _baglantiKapandi(nesil);
        return;
      }
      try {
        _channel?.sink.add('ping');
      } catch (_) {
        _baglantiKapandi(nesil);
      }
    });
  }

  /// "Tekrar dene" ve uygulama one geldiginde: beklemeden baglan
  Future<void> retryNow() async {
    if (_kapatildi || _bagli) return;
    _denemeSayisi = 0;
    await connect();
  }

  void _yasamDongusunuDinle() {
    if (_yasamDongusu != null) return;
    try {
      _yasamDongusu = AppLifecycleListener(
        onResume: () {
          if (_bagli) {
            // Arka planda olmus olabilir: ilk pingde anlasilir
            if (DateTime.now().difference(_sonMesaj) > staleAfter) {
              final eski = _channel;
              if (eski != null) unawaited(_kanaliKapat(eski));
              _baglantiKapandi(_nesil);
            }
          } else {
            unawaited(retryNow());
          }
        },
      );
    } catch (_) {
      // Flutter baglami yoksa (saf Dart testi) yasam dongusu dinlenmez
    }
  }

  Future<void> _kanaliKapat(WebSocketChannel channel) async {
    try {
      await channel.sink.close();
    } catch (_) {}
  }

  Future<void> _temizle() async {
    _pingZamanlayici?.cancel();
    final abonelik = _abonelik;
    _abonelik = null;
    await abonelik?.cancel();

    final channel = _channel;
    _channel = null;
    if (channel != null) await _kanaliKapat(channel);
  }

  /// JWT'nin suresi 30 saniye icinde doluyor mu? Cozulemiyorsa hayir.
  static bool _jetonBitiyor(String? token) {
    if (token == null) return false;
    try {
      final parcalar = token.split('.');
      if (parcalar.length != 3) return false;
      final govde = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parcalar[1]))));
      final exp = (govde as Map<String, dynamic>)['exp'];
      if (exp is! num) return false;
      final bitis = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return bitis.isBefore(DateTime.now().add(const Duration(seconds: 30)));
    } catch (_) {
      return false;
    }
  }

  /// Cikis yapildiginda cagrilir.
  Future<void> disconnect() async {
    _kapatildi = true;
    _nesil++;
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
    _jetonYenilensin = false;
    // Eski oturumun baglantisi acik kaldiysa once kopuk say
    if (_bagli) {
      _bagli = false;
      _baglantiDurumu.add(false);
    }
    await connect();
  }

  Future<void> dispose() async {
    await disconnect();
    _yasamDongusu?.dispose();
    _yasamDongusu = null;
    await _olaylar.close();
    await _baglantiDurumu.close();
  }
}
