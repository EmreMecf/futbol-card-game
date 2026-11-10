import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';

import '../auth/auth_middleware.dart';
import '../db/database.dart';
import 'api_response.dart';

/// IDEMPOTENCY (Ekonomi V2, FAZ 0) — tekrar gelen isteğe AYNI cevap.
///
/// ===================================================================
/// NEDEN?
/// ===================================================================
/// Ödül veren bir istek (sandık aç, ödül al) yolda kaybolabilir: istemci
/// cevabı alamaz ve tekrar dener. Sunucu isteği iki kez işlerse oyuncu
/// iki ödül alır. İstemci her değiştirici istekte benzersiz bir
/// `Idempotency-Key` gönderir; sunucu ilk cevabı saklar ve aynı anahtarla
/// gelen her tekrara onu döner.
///
///   * aynı anahtar + aynı gövde  -> saklanan cevap (işlem tekrar yapılmaz)
///   * aynı anahtar + farklı gövde -> 409 `idempotency_mismatch`
///   * ilk istek hâlâ işleniyorsa  -> 409 `idempotency_in_progress`
///   * 5xx cevaplar saklanmaz (geçici hata; tekrar denenebilsin)
///
/// Veritabanı tarafındaki tek seferlik garanti (unique kısıt, defter)
/// bunun YERİNE değil, ÜSTÜNE gelir: iki katman.
const String kIdempotencyHeader = 'idempotency-key';

/// Saklanan cevap
class StoredResponse {
  final int statusCode;
  final String body;
  const StoredResponse(this.statusCode, this.body);
}

/// Anahtar deposunun sonucu
sealed class ReserveResult {
  const ReserveResult();
}

/// Yeni anahtar: işlem yapılabilir
class Reserved extends ReserveResult {
  const Reserved();
}

/// Aynı anahtar ve gövde ile tamamlanmış istek
class Replay extends ReserveResult {
  final StoredResponse response;
  const Replay(this.response);
}

/// Aynı anahtar başka bir gövdeyle kullanılmış
class Mismatch extends ReserveResult {
  const Mismatch();
}

/// Aynı anahtarla bir istek hâlâ işleniyor
class InProgress extends ReserveResult {
  const InProgress();
}

/// Anahtar deposu (veritabanı ya da testte bellek)
abstract class IdempotencyStore {
  Future<ReserveResult> reserve(String userId, String key, String endpoint, String requestHash);
  Future<void> complete(String userId, String key, StoredResponse response);

  /// İşlem 5xx ile bittiyse anahtar bırakılır (tekrar denenebilsin)
  Future<void> release(String userId, String key);
}

/// PostgreSQL deposu (028: idempotency_keys)
class DbIdempotencyStore implements IdempotencyStore {
  final Database db;
  DbIdempotencyStore(this.db);

  @override
  Future<ReserveResult> reserve(String userId, String key, String endpoint, String requestHash) async {
    final eklenen = await db.queryOne(
      '''
      insert into idempotency_keys (user_id, key, endpoint, request_hash)
      values (@u::uuid, @k, @e, @h)
      on conflict (user_id, key) do nothing
      returning key
      ''',
      params: {'u': userId, 'k': key, 'e': endpoint, 'h': requestHash},
    );
    if (eklenen != null) return const Reserved();

    final varOlan = await db.queryOne(
      'select endpoint, request_hash, status, status_code, response '
      'from idempotency_keys where user_id = @u::uuid and key = @k',
      params: {'u': userId, 'k': key},
    );
    if (varOlan == null) return const Reserved(); // arada temizlendi
    if (varOlan['endpoint'] != endpoint || varOlan['request_hash'] != requestHash) {
      return const Mismatch();
    }
    if (varOlan['status'] != 'done') return const InProgress();
    return Replay(StoredResponse(varOlan['status_code'] as int, varOlan['response'] as String? ?? ''));
  }

  @override
  Future<void> complete(String userId, String key, StoredResponse response) => db.query(
        '''
        update idempotency_keys
        set status = 'done', status_code = @s, response = @r
        where user_id = @u::uuid and key = @k
        ''',
        params: {'u': userId, 'k': key, 's': response.statusCode, 'r': response.body},
      );

  @override
  Future<void> release(String userId, String key) => db.query(
        'delete from idempotency_keys where user_id = @u::uuid and key = @k and status = \'processing\'',
        params: {'u': userId, 'k': key},
      );
}

/// Bellek deposu (birim testleri için)
class MemoryIdempotencyStore implements IdempotencyStore {
  final Map<String, ({String endpoint, String hash, StoredResponse? response})> _kayit = {};

  @override
  Future<ReserveResult> reserve(String userId, String key, String endpoint, String requestHash) async {
    final id = '$userId/$key';
    final v = _kayit[id];
    if (v == null) {
      _kayit[id] = (endpoint: endpoint, hash: requestHash, response: null);
      return const Reserved();
    }
    if (v.endpoint != endpoint || v.hash != requestHash) return const Mismatch();
    if (v.response == null) return const InProgress();
    return Replay(v.response!);
  }

  @override
  Future<void> complete(String userId, String key, StoredResponse response) async {
    final id = '$userId/$key';
    final v = _kayit[id]!;
    _kayit[id] = (endpoint: v.endpoint, hash: v.hash, response: response);
  }

  @override
  Future<void> release(String userId, String key) async => _kayit.remove('$userId/$key');
}

/// Değiştirici isteklerde (POST/PUT/PATCH/DELETE) `Idempotency-Key`
/// başlığını uygular. [required] ise başlıksız istek 400 alır.
///
/// `requireAuth` SONRASINDA kullanılmalı: anahtar oyuncuya özeldir.
Middleware idempotency(IdempotencyStore store, {bool required = true}) {
  const degistirici = {'POST', 'PUT', 'PATCH', 'DELETE'};
  return (Handler inner) {
    return (Request request) async {
      if (!degistirici.contains(request.method)) return inner(request);

      final key = request.headers[kIdempotencyHeader]?.trim();
      if (key == null || key.isEmpty) {
        if (!required) return inner(request);
        return jsonError('Istek kimligi (Idempotency-Key) eksik.', status: 400, code: 'idempotency_key_required');
      }
      if (key.length < 8 || key.length > 128) {
        return jsonError('Istek kimligi gecersiz.', status: 400, code: 'idempotency_key_invalid');
      }

      final userId = requireUserId(request);
      final govde = await request.read().fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      if (govde.length > maxBodyBytes) {
        return jsonError('Istek govdesi cok buyuk.', status: 413);
      }
      final endpoint = '${request.method} /${request.url.path}';
      final ozet = sha256.convert(govde).toString();

      switch (await store.reserve(userId, key, endpoint, ozet)) {
        case Replay(:final response):
          return Response(response.statusCode,
              body: response.body,
              headers: {'content-type': 'application/json; charset=utf-8', 'idempotent-replay': 'true'});
        case Mismatch():
          return jsonError('Bu istek kimligi baska bir istekte kullanildi.', status: 409, code: 'idempotency_mismatch');
        case InProgress():
          return jsonError('Ayni istek hala isleniyor; biraz sonra tekrar dene.',
              status: 409, code: 'idempotency_in_progress');
        case Reserved():
          break;
      }

      Response cevap;
      try {
        cevap = await inner(request.change(body: govde));
      } on ApiException catch (e) {
        // İş kuralı reddi (4xx) kesin bir cevaptır: saklanır, tekrarı
        // aynı reddi alır. (Dıştaki hata ara katmanı da aynı biçimi üretir.)
        cevap = jsonError(e.message, status: e.status, code: e.code);
      } catch (_) {
        await store.release(userId, key);
        rethrow;
      }
      if (cevap.statusCode >= 500) {
        await store.release(userId, key);
        return cevap;
      }
      final metin = await cevap.readAsString();
      await store.complete(userId, key, StoredResponse(cevap.statusCode, metin));
      return cevap.change(body: metin);
    };
  };
}

/// Yardımcı: JSON gövde özetini dışarıdan da hesaplamak için
String bodyHash(Object? json) => sha256.convert(utf8.encode(jsonEncode(json))).toString();
