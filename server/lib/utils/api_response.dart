import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Basarili JSON cevabi uretir.
///
/// [_toEncodable] guvenlik agi gorevi gorur: JSON'a dogrudan
/// cevrilemeyen tipler (DateTime gibi) sunucuyu cokertmek yerine
/// makul bir metne donusur.
Response jsonOk(Object? data, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(data, toEncodable: _toEncodable),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Object? _toEncodable(Object? nesne) {
  if (nesne is DateTime) return nesne.toUtc().toIso8601String();
  if (nesne is Duration) return nesne.inMilliseconds;
  return nesne.toString();
}

/// Hata cevabi uretir. Mesaj her zaman TURKCE'dir ve dogrudan
/// kullaniciya gosterilebilir.
Response jsonError(String message, {int status = 400, String? code}) {
  return Response(
    status,
    body: jsonEncode({
      'error': true,
      'message': message,
      if (code != null) 'code': code,
    }),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Is kurali ihlallerinde firlatilir. Middleware bunu yakalayip
/// uygun HTTP koduyla cevaba cevirir.
class ApiException implements Exception {
  final String message;
  final int status;
  final String? code;

  const ApiException(this.message, {this.status = 400, this.code});

  const ApiException.unauthorized([this.message = 'Oturum gecersiz. Lutfen tekrar giris yapin.'])
      : status = 401,
        code = 'unauthorized';

  const ApiException.notFound([this.message = 'Kayit bulunamadi.'])
      : status = 404,
        code = 'not_found';

  @override
  String toString() => 'ApiException($status): $message';
}

/// Istek govdesini JSON olarak okur.
Future<Map<String, dynamic>> readJsonBody(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return <String, dynamic>{};

  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Gecersiz istek govdesi.');
    }
    return decoded;
  } on FormatException {
    throw const ApiException('Istek govdesi gecerli JSON degil.');
  }
}

/// Zorunlu bir metin alani okur.
String requireString(Map<String, dynamic> body, String key, {String? label}) {
  final value = body[key];
  if (value is! String || value.trim().isEmpty) {
    throw ApiException('${label ?? key} alani zorunludur.');
  }
  return value.trim();
}
