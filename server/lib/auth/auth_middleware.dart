import 'package:shelf/shelf.dart';

import '../utils/api_response.dart';
import 'jwt_service.dart';

/// Istek baglaminda kullanici kimliginin saklandigi anahtar
const String kUserIdKey = 'userId';

/// Istegi yapan kullanicinin kimligini doner.
///
/// GUVENLIK NOTU: Bu deger JWT'den cozulur. Istemci govdede ya da
/// sorgu parametresinde "ben su kullaniciyim" diyemez. Veritabani
/// fonksiyonlarina gecirilen p_user_id her zaman buradan gelir.
String requireUserId(Request request) {
  final id = request.context[kUserIdKey];
  if (id is! String) {
    throw const ApiException.unauthorized();
  }
  return id;
}

/// Korumali uc noktalar icin: gecerli bir access token zorunlu kilar.
Middleware requireAuth(JwtService jwt) {
  return (Handler innerHandler) {
    return (Request request) async {
      final header = request.headers['authorization'];

      if (header == null || !header.toLowerCase().startsWith('bearer ')) {
        return jsonError(
          'Bu islem icin giris yapmalisiniz.',
          status: 401,
          code: 'unauthorized',
        );
      }

      final token = header.substring(7).trim();
      final userId = jwt.verifyAccessToken(token);

      if (userId == null) {
        return jsonError(
          'Oturumunuzun suresi doldu. Lutfen tekrar giris yapin.',
          status: 401,
          code: 'token_expired',
        );
      }

      return innerHandler(
        request.change(context: {...request.context, kUserIdKey: userId}),
      );
    };
  };
}
