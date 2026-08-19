import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../config/env.dart';

/// JWT uretimi ve dogrulamasi.
///
/// IKI JETON MANTIGI:
///   * access token  -> kisa omurlu (15 dk), her istekte gonderilir.
///     Calinirsa zarar sinirli olur.
///   * refresh token -> uzun omurlu (30 gun), sadece yeni access token
///     almak icin kullanilir. Veritabaninda SHA-256 ozeti saklanir,
///     boylece veritabani sizsa bile jetonlar kullanilamaz.
class JwtService {
  static const String _issuer = 'futbol-card';

  final _random = Random.secure();

  /// Access token uretir. Icinde kullanici kimligi (sub) vardir.
  String createAccessToken(String userId, {String? username}) {
    final jwt = JWT(
      {
        'sub': userId,
        if (username != null) 'username': username,
      },
      issuer: _issuer,
    );

    return jwt.sign(
      SecretKey(Env.jwtSecret),
      expiresIn: Duration(minutes: Env.accessTokenMinutes),
    );
  }

  /// Access token'i dogrular ve kullanici kimligini doner.
  /// Gecersiz/suresi dolmussa null doner.
  String? verifyAccessToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(Env.jwtSecret), issuer: _issuer);
      final payload = jwt.payload;
      if (payload is Map && payload['sub'] is String) {
        return payload['sub'] as String;
      }
      return null;
    } on JWTException {
      return null;
    }
  }

  /// Rastgele, tahmin edilemez refresh token uretir.
  String createRefreshToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Refresh token'in veritabaninda saklanacak ozeti.
  String hashRefreshToken(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }
}
