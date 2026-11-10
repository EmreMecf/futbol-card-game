import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import 'api_response.dart';

/// Veritabanı kural hatası "kod: mesaj" biçiminde gelir (Ekonomi V2:
/// 031, 032). Bu yardımcı onu 409 + makine koduna çevirir; istemci koda
/// göre Türkçe mesaj gösterir. `*_not_found` kodları 404 olur.
Future<Response> withRuleCodes(Future<Response> Function() handler) async {
  try {
    return await handler();
  } on ServerException catch (e) {
    if (e.code == 'P0001') {
      final m = RegExp(r'^([a-z_]+): (.*)$').firstMatch(e.message);
      if (m != null) {
        final kod = m.group(1)!;
        throw ApiException(m.group(2)!, status: kod.endsWith('_not_found') ? 404 : 409, code: kod);
      }
    }
    rethrow;
  }
}
