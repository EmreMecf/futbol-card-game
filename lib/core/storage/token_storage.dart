import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Oturum jetonlarinin cihazda saklandigi yer.
///
/// NEDEN flutter_secure_storage?
/// Jetonlar SharedPreferences'a duz metin olarak yazilirsa, kok (root)
/// erisimi olan bir cihazda ya da yedekten okunarak calinabilir.
/// Bu paket Android'de AES-GCM + Android KeyStore, iOS'ta Keychain
/// kullanir; sifreleme anahtari isletim sisteminin donaniminda durur.
///
/// NOT: Paketin 11. surumunde sifreleme VARSAYILAN olarak acik geliyor;
/// eski surumlerdeki `encryptedSharedPreferences: true` ayari kaldirildi.
class TokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userKey = 'current_user';

  final FlutterSecureStorage _storage;

  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  /// Kullanici bilgisini onbellekte tutar; uygulama acilirken profil
  /// istegi donmeden once ekranda isim/avatar gosterebilmek icin.
  Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: _userKey, value: jsonEncode(user));

  Future<Map<String, dynamic>?> readUser() async {
    final ham = await _storage.read(key: _userKey);
    if (ham == null || ham.isEmpty) return null;
    try {
      return jsonDecode(ham) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userKey);
  }
}
