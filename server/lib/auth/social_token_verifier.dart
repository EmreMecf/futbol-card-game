import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart' as pc;

import '../config/env.dart';
import '../utils/api_response.dart';

enum SocialProvider {
  google,
  apple;

  static SocialProvider? fromName(String name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Imzasi ve icerigi dogrulanmis dis kimlik.
class SocialIdentity {
  final SocialProvider provider;
  final String subject;
  final String? email;
  final bool emailVerified;

  const SocialIdentity({
    required this.provider,
    required this.subject,
    required this.email,
    required this.emailVerified,
  });
}

typedef JwksFetcher = Future<Map<String, dynamic>> Function(Uri url);

/// Google ve Apple kimlik jetonlarini (RS256 JWT) dogrular.
///
/// Istemciden gelen hicbir alana guvenilmez: imza saglayicinin yayinladigi
/// anahtarla, `iss`, `aud`, `exp` ve Apple icin `nonce` burada kontrol edilir.
class SocialTokenVerifier {
  static final Uri _googleKeys = Uri.parse('https://www.googleapis.com/oauth2/v3/certs');
  static final Uri _appleKeys = Uri.parse('https://appleid.apple.com/auth/keys');
  static const _googleIssuers = {'accounts.google.com', 'https://accounts.google.com'};
  static const _appleIssuers = {'https://appleid.apple.com'};

  /// Saat farki toleransi
  static const _skew = Duration(minutes: 1);
  static const _keyTtl = Duration(hours: 1);

  /// Bilinmeyen `kid` ile saglayiciya istek yagdirilamasin diye en kisa yenileme araligi
  static const _minRefresh = Duration(minutes: 1);

  final Set<String> googleClientIds;
  final Set<String> appleClientIds;
  final JwksFetcher _fetch;
  final DateTime Function() _now;
  final _cache = <SocialProvider, _KeySet>{};

  SocialTokenVerifier({
    required this.googleClientIds,
    required this.appleClientIds,
    JwksFetcher? fetchKeys,
    DateTime Function()? now,
  }) : _fetch = fetchKeys ?? _fetchJson,
       _now = now ?? DateTime.now;

  factory SocialTokenVerifier.fromEnv() =>
      SocialTokenVerifier(googleClientIds: Env.googleClientIds, appleClientIds: Env.appleClientIds);

  /// [rawNonce]: Apple girisinde istemcinin urettigi ham deger; jetonda SHA-256 ozeti bulunur.
  Future<SocialIdentity> verify(SocialProvider provider, String idToken, {String? rawNonce}) async {
    final audiences = provider == SocialProvider.google ? googleClientIds : appleClientIds;
    if (audiences.isEmpty) {
      throw const ApiException('Bu giris yontemi henuz acik degil.', status: 503, code: 'social_disabled');
    }

    final parts = idToken.split('.');
    if (parts.length != 3) throw _invalid();

    final Map<String, dynamic> header;
    final Map<String, dynamic> claims;
    final Uint8List signature;
    try {
      header = jsonDecode(utf8.decode(_b64(parts[0]))) as Map<String, dynamic>;
      claims = jsonDecode(utf8.decode(_b64(parts[1]))) as Map<String, dynamic>;
      signature = _b64(parts[2]);
    } catch (_) {
      throw _invalid();
    }

    // Yalniz RS256: "alg: none" ve anahtar karistirma saldirilari burada kapanir
    final kid = header['kid'];
    if (header['alg'] != 'RS256' || kid is! String) throw _invalid();

    final key = await _keyFor(provider, kid);
    if (key == null || !_signatureValid(key, utf8.encode('${parts[0]}.${parts[1]}'), signature)) {
      throw _invalid();
    }

    final issuers = provider == SocialProvider.google ? _googleIssuers : _appleIssuers;
    if (!issuers.contains(claims['iss'])) throw _invalid();
    if (!audiences.contains(claims['aud'])) throw _invalid();

    final exp = claims['exp'];
    if (exp is! num) throw _invalid();
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    if (!expiresAt.add(_skew).isAfter(_now().toUtc())) throw _invalid();

    if (provider == SocialProvider.apple) {
      if (rawNonce == null || rawNonce.isEmpty) throw _invalid();
      if (claims['nonce'] != sha256.convert(utf8.encode(rawNonce)).toString()) throw _invalid();
    }

    final sub = claims['sub'];
    if (sub is! String || sub.isEmpty || sub.length > 255) throw _invalid();

    final email = claims['email'];
    final verified = claims['email_verified'];
    return SocialIdentity(
      provider: provider,
      subject: sub,
      email: email is String && email.contains('@') ? email.trim().toLowerCase() : null,
      // Apple bu alani metin olarak da gonderebiliyor
      emailVerified: verified == true || verified == 'true',
    );
  }

  ApiException _invalid() =>
      const ApiException('Giris dogrulanamadi. Lutfen tekrar deneyin.', status: 401, code: 'invalid_social_token');

  Future<pc.RSAPublicKey?> _keyFor(SocialProvider provider, String kid) async {
    final now = _now();
    final cached = _cache[provider];
    if (cached != null && now.difference(cached.fetchedAt) < _keyTtl) {
      final key = cached.keys[kid];
      // Saglayici anahtar dondurdugunde yeni kid gelir: bir kez tazelenir
      if (key != null || now.difference(cached.fetchedAt) < _minRefresh) return key;
    }

    try {
      final json = await _fetch(provider == SocialProvider.google ? _googleKeys : _appleKeys);
      final keys = <String, pc.RSAPublicKey>{};
      for (final k in (json['keys'] as List).cast<Map<String, dynamic>>()) {
        if (k['kty'] != 'RSA') continue;
        keys[k['kid'] as String] = pc.RSAPublicKey(
          _bigInt(_b64(k['n'] as String)),
          _bigInt(_b64(k['e'] as String)),
        );
      }
      _cache[provider] = _KeySet(keys, now);
      return keys[kid];
    } catch (_) {
      // Eski anahtarlar hala gecerliyse saglayici kesintisinde giris durmasin
      final key = cached?.keys[kid];
      if (key != null) return key;
      throw const ApiException('Giris servisine ulasilamadi. Lutfen tekrar deneyin.', status: 503);
    }
  }

  static bool _signatureValid(pc.RSAPublicKey key, List<int> message, Uint8List signature) {
    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201')
      ..init(false, pc.PublicKeyParameter<pc.RSAPublicKey>(key));
    try {
      return signer.verifySignature(Uint8List.fromList(message), pc.RSASignature(signature));
    } catch (_) {
      return false;
    }
  }

  static Uint8List _b64(String value) => base64Url.decode(base64Url.normalize(value));

  static BigInt _bigInt(Uint8List bytes) =>
      bytes.fold(BigInt.zero, (sum, b) => (sum << 8) | BigInt.from(b));

  static Future<Map<String, dynamic>> _fetchJson(Uri url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(url);
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) throw HttpException('JWKS ${response.statusCode}', uri: url);
      final body = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 5));
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }
}

class _KeySet {
  final Map<String, pc.RSAPublicKey> keys;
  final DateTime fetchedAt;
  const _KeySet(this.keys, this.fetchedAt);
}
