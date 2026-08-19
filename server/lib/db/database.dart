import 'package:postgres/postgres.dart';

import '../config/env.dart';

/// PostgreSQL baglanti yoneticisi.
///
/// IKI AYRI BAGLANTI KULLANIYORUZ:
///   * [pool]   -> normal sorgular icin havuz (es zamanli istekleri karsilar)
///   * [listenConnection] -> SADECE LISTEN/NOTIFY icin ayri, tek baglanti
///
/// Neden ayri? LISTEN yapan bir baglanti bildirimleri beklerken mesgul
/// sayilir. Havuzdan alinan baglanti geri birakildiginda LISTEN kaydi da
/// kaybolur. Bu yuzden bildirimler icin omur boyu acik kalan ozel bir
/// baglanti tutuyoruz.
class Database {
  late final Pool _pool;
  Connection? _listenConnection;

  Pool get pool => _pool;
  Connection get listenConnection {
    final c = _listenConnection;
    if (c == null) {
      throw StateError('Dinleme baglantisi henuz acilmadi.');
    }
    return c;
  }

  Endpoint get _endpoint => Endpoint(
        host: Env.dbHost,
        port: Env.dbPort,
        database: Env.dbName,
        username: Env.dbUser,
        password: Env.dbPassword,
      );

  ConnectionSettings get _settings => ConnectionSettings(
        // Yerel Docker'da SSL yok. Uretimde sunucun SSL destekliyorsa
        // burayi SslMode.require yap.
        sslMode: Env.isProduction ? SslMode.require : SslMode.disable,
        connectTimeout: const Duration(seconds: 10),
        queryTimeout: const Duration(seconds: 20),
        timeZone: 'UTC',
      );

  /// Baglantilari acar. Veritabani henuz hazir degilse tekrar dener
  /// (Docker'da sunucu, veritabanindan once ayaga kalkabilir).
  Future<void> connect({int maxRetry = 15}) async {
    _pool = Pool.withEndpoints(
      [_endpoint],
      settings: PoolSettings(
        maxConnectionCount: 10,
        sslMode: _settings.sslMode,
        connectTimeout: _settings.connectTimeout,
        queryTimeout: _settings.queryTimeout,
        timeZone: 'UTC',
      ),
    );

    for (var deneme = 1; deneme <= maxRetry; deneme++) {
      try {
        await _pool.execute('select 1');
        _listenConnection = await Connection.open(_endpoint, settings: _settings);
        // ignore: avoid_print
        print('[DB] Veritabanina baglanildi: ${Env.dbHost}:${Env.dbPort}/${Env.dbName}');
        return;
      } catch (e) {
        // ignore: avoid_print
        print('[DB] Baglanti denemesi $deneme/$maxRetry basarisiz: $e');
        if (deneme == maxRetry) rethrow;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> close() async {
    await _listenConnection?.close();
    await _pool.close();
  }

  // ------------------------------------------------------------------
  // KISAYOLLAR
  // ------------------------------------------------------------------

  /// Sorguyu calistirir ve satirlari Map listesi olarak doner.
  Future<List<Map<String, dynamic>>> query(
    String sql, {
    Map<String, dynamic>? params,
  }) async {
    final result = await _pool.execute(
      Sql.named(sql),
      parameters: params ?? const {},
    );
    return result.map((row) => _normalize(row.toColumnMap())).toList();
  }

  /// PostgreSQL surucusu, tanimadigi tipleri (enum'larimiz, citext gibi)
  /// ham bayt olarak dondurur. Bu fonksiyon onlari metne cevirir.
  ///
  /// NEDEN BURADA? Alternatif her sorguda `position::text` yazmakti.
  /// Tek yerde cozunce yeni bir enum ekledigimizde hicbir sorguyu
  /// degistirmemiz gerekmiyor.
  Map<String, dynamic> _normalize(Map<String, dynamic> row) {
    return row.map((anahtar, deger) => MapEntry(anahtar, _normalizeValue(deger)));
  }

  dynamic _normalizeValue(dynamic deger) {
    if (deger is UndecodedBytes) return deger.asString;
    if (deger is List) return deger.map(_normalizeValue).toList();
    return deger;
  }

  /// Tek satir bekleyen sorgular icin (yoksa null).
  Future<Map<String, dynamic>?> queryOne(
    String sql, {
    Map<String, dynamic>? params,
  }) async {
    final rows = await query(sql, params: params);
    return rows.isEmpty ? null : rows.first;
  }

  /// Tek deger dondururen fonksiyon cagrilari icin (RPC'ler).
  Future<dynamic> scalar(String sql, {Map<String, dynamic>? params}) async {
    final rows = await query(sql, params: params);
    if (rows.isEmpty) return null;
    return rows.first.values.first;
  }
}
