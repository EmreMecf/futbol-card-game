import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_models/shared_models.dart';

import '../auth/session_manager.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';

/// Backend ile konusan tek istemci.
///
/// Supabase SDK'sinin yerini alir. Uygulamanin hicbir yerinde `Dio`
/// dogrudan kullanilmaz; her istek buradan gecer. Boylece jeton ekleme,
/// jeton yenileme ve loglama tek yerde toplanir.
class ApiClient {
  final SessionManager _session;
  late final Dio _dio;

  /// Oturum kurtarilamayacak sekilde gecersiz oldugunda tetiklenir.
  /// Uygulama bunu dinleyip kullaniciyi giris ekranina atar.
  final void Function()? onSessionExpired;

  ApiClient(this._session, {this.onSessionExpired}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${AppConfig.apiBaseUrl}/api',
        connectTimeout: Duration(seconds: AppConfig.requestTimeoutSeconds),
        receiveTimeout: Duration(seconds: AppConfig.requestTimeoutSeconds),
        sendTimeout: Duration(seconds: AppConfig.requestTimeoutSeconds),
        headers: const {'Content-Type': 'application/json'},
        // 4xx/5xx durumlarinda Dio hata firlatsin; ErrorMapper cevirsin.
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
        onResponse: _onResponse,
      ),
    );
  }

  Dio get raw => _dio;

  // ------------------------------------------------------------------
  // ISTEK ONCESI: Jetonu ekle
  // ------------------------------------------------------------------
  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _session.accessToken;
    if (token != null && !_isAuthEndpoint(options.path)) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    if (AppConfig.enableLogging) {
      AppLogger.info('--> ${options.method} ${options.path}', tag: 'AG');
    }
    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    if (AppConfig.enableLogging) {
      AppLogger.info(
        '<-- ${response.statusCode} ${response.requestOptions.path}',
        tag: 'AG',
      );
    }
    handler.next(response);
  }

  // ------------------------------------------------------------------
  // HATA: 401 gelirse jetonu yenileyip istegi TEKRAR dene
  // ------------------------------------------------------------------
  //
  // Access token 15 dakika yasiyor. Kullanici oyunun ortasinda "oturumunuz
  // doldu" mesaji gormesin diye, 401 alindiginda arka planda sessizce
  // yenileyip ayni istegi tekrar gonderiyoruz.
  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final durum = error.response?.statusCode;
    final yol = error.requestOptions.path;

    // Yenileme kosullari: 401 olmali, auth ucu olmamali, daha once
    // tekrar denenmemis olmali ve elimizde refresh token bulunmali.
    final tekrarDenendi = error.requestOptions.extra['__retried'] == true;

    if (durum != 401 ||
        _isAuthEndpoint(yol) ||
        tekrarDenendi ||
        _session.refreshToken == null) {
      return handler.next(error);
    }

    final yenilendi = await _refreshToken();

    if (!yenilendi) {
      // Yenileme de basarisiz -> oturum gercekten bitti
      await _session.clear();
      onSessionExpired?.call();
      return handler.next(error);
    }

    // Ayni istegi yeni jetonla tekrar gonder
    try {
      final istek = error.requestOptions;
      istek.extra['__retried'] = true;
      istek.headers['Authorization'] = 'Bearer ${_session.accessToken}';

      final cevap = await _dio.fetch<dynamic>(istek);
      return handler.resolve(cevap);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  // ------------------------------------------------------------------
  // JETON YENILEME (es zamanli isteklere karsi korumali)
  // ------------------------------------------------------------------
  //
  // Ekranda ayni anda 3 istek varsa ve ucu birden 401 alirsa, ucu birden
  // yenileme yapmaya calisirdi. Backend'de jeton rotasyonu oldugu icin
  // ilki basarili olur, digerleri "gecersiz jeton" alir ve kullanici
  // haksiz yere disari atilirdi. Bu Completer o yarisi engelliyor:
  // ilk cagri yeniler, digerleri onun sonucunu bekler.
  Completer<bool>? _yenilemeIslemi;

  Future<bool> _refreshToken() async {
    final mevcut = _yenilemeIslemi;
    if (mevcut != null) return mevcut.future;

    final islem = Completer<bool>();
    _yenilemeIslemi = islem;

    try {
      AppLogger.info('Access token yenileniyor...', tag: 'AG');

      // Yenileme istegi ana Dio ornegini kullanmaz ki araya giren
      // interceptor tekrar tetiklenmesin.
      final temizDio = Dio(BaseOptions(baseUrl: '${AppConfig.apiBaseUrl}/api'));
      final cevap = await temizDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': _session.refreshToken},
      );

      final jetonlar = cevap.data?['tokens'] as Map<String, dynamic>?;
      if (jetonlar == null) {
        islem.complete(false);
        return false;
      }

      // Paylasilan model: sunucunun gonderdigi bicimle birebir ayni.
      await _session.updateTokens(AuthTokens.fromJson(jetonlar));

      AppLogger.info('Jeton yenilendi.', tag: 'AG');
      islem.complete(true);
      return true;
    } catch (e) {
      AppLogger.warning('Jeton yenilenemedi: $e', tag: 'AG');
      islem.complete(false);
      return false;
    } finally {
      _yenilemeIslemi = null;
    }
  }

  bool _isAuthEndpoint(String yol) =>
      yol.contains('/auth/login') ||
      yol.contains('/auth/register') ||
      yol.contains('/auth/refresh');

  // ------------------------------------------------------------------
  // KISAYOLLAR
  // ------------------------------------------------------------------
  // Hepsi Map<String, dynamic> doner; backend her zaman JSON nesnesi gonderir.

  Future<Map<String, dynamic>> get(
    String yol, {
    Map<String, dynamic>? sorgu,
    CancelToken? iptal,
  }) async {
    final cevap = await _dio.get<dynamic>(
      yol,
      queryParameters: sorgu,
      cancelToken: iptal,
    );
    return _mapCevap(cevap);
  }

  Future<Map<String, dynamic>> post(
    String yol, {
    Object? govde,
    CancelToken? iptal,
  }) async {
    final cevap = await _dio.post<dynamic>(yol, data: govde, cancelToken: iptal);
    return _mapCevap(cevap);
  }

  Future<Map<String, dynamic>> put(
    String yol, {
    Object? govde,
    CancelToken? iptal,
  }) async {
    final cevap = await _dio.put<dynamic>(yol, data: govde, cancelToken: iptal);
    return _mapCevap(cevap);
  }

  Future<Map<String, dynamic>> delete(String yol, {CancelToken? iptal}) async {
    final cevap = await _dio.delete<dynamic>(yol, cancelToken: iptal);
    return _mapCevap(cevap);
  }

  Map<String, dynamic> _mapCevap(Response<dynamic> cevap) {
    final veri = cevap.data;
    if (veri is Map<String, dynamic>) return veri;
    if (veri is Map) return Map<String, dynamic>.from(veri);
    return <String, dynamic>{};
  }
}
