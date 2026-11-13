import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:jose/jose.dart';

/// Only a verified external id_token may reach the account mapper.
/// Rejects unsigned / symmetric tokens, wrong audience or issuer and expired tokens.
class VerifiedSocialIdentity {
  const VerifiedSocialIdentity({required this.provider, required this.subject, this.email});
  final String provider;
  final String subject;
  final String? email;
}

class SocialTokenVerifier {
  SocialTokenVerifier({Map<String, String>? environment})
      : _env = environment ?? Platform.environment;

  final Map<String, String> _env;

  Future<VerifiedSocialIdentity> verify({
    required String provider,
    required String idToken,
    String? appleRawNonce,
  }) async {
    if (provider != 'google' && provider != 'apple') {
      throw const FormatException('Unknown provider');
    }
    final audiencesAllowed = provider == 'google'
        ? <String>[_env['GOOGLE_WEB_CLIENT_ID'] ?? '']
        : <String>[
            _env['APPLE_BUNDLE_ID'] ?? '',
            _env['APPLE_SERVICE_ID'] ?? '',
          ].where((v) => v.isNotEmpty).toList();
    if (audiencesAllowed.every((v) => v.isEmpty)) {
      throw StateError('Social login provider not configured');
    }
    if (idToken.length > 12000 || idToken.split('.').length != 3) {
      throw const FormatException('Invalid token format');
    }
    final headers = jsonDecode(utf8.decode(base64Url.decode(
      base64Url.normalize(idToken.split('.').first),
    )));
    if (headers is! Map<String, dynamic> ||
        headers['alg'] != 'RS256' ||
        headers['kid'] is! String) {
      throw const FormatException('Unsupported token algorithm');
    }

    final keysUrl = provider == 'google'
        ? 'https://www.googleapis.com/oauth2/v3/certs'
        : 'https://appleid.apple.com/auth/keys';
    final keys = await _fetchKeys(Uri.parse(keysUrl));
    final keyStore = JsonWebKeyStore();
    var found = false;
    for (final item in keys) {
      if (item['kid'] == headers['kid'] &&
          item['kty'] == 'RSA' &&
          (item['alg'] == null || item['alg'] == 'RS256') &&
          (item['use'] == null || item['use'] == 'sig')) {
        keyStore.addKey(JsonWebKey.fromJson(item));
        found = true;
      }
    }
    if (!found) throw const FormatException('Signing key not found');
    final jws = JsonWebSignature.fromCompactSerialization(idToken);
    if (!await jws.verify(keyStore)) {
      throw const FormatException('Invalid token signature');
    }

    final decoded = jsonDecode(jws.unverifiedPayload.stringContent);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid token claims');
    }
    final issuer = decoded['iss'];
    final goodIssuer = provider == 'google'
        ? (issuer == 'accounts.google.com' || issuer == 'https://accounts.google.com')
        : issuer == 'https://appleid.apple.com';
    final audiences = decoded['aud'] is String
        ? <String>[decoded['aud'] as String]
        : (decoded['aud'] is List
            ? List<String>.from(decoded['aud'] as List)
            : <String>[]);
    final expiry = decoded['exp'];
    final issuedAt = decoded['iat'];
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if (!goodIssuer ||
        !audiences.any(audiencesAllowed.contains) ||
        (audiences.length > 1 &&
         !audiencesAllowed.contains(decoded['azp'])) ||
        expiry is! num || expiry.toInt() <= now ||
        issuedAt is! num || issuedAt.toInt() > now + 60 ||
        decoded['sub'] is! String ||
        (decoded['sub'] as String).isEmpty) {
      throw const FormatException('Token claims invalid');
    }

    if (provider == 'apple') {
      if (appleRawNonce == null || appleRawNonce.length < 16 ||
          appleRawNonce.length > 256) {
        throw const FormatException('Apple nonce is required');
      }
      final hashed = sha256.convert(utf8.encode(appleRawNonce)).toString();
      // Some native Apple integrations return raw nonce; requiring hashed
      // form also binds authentication to this exact client request.
      if (decoded['nonce'] != hashed) {
        throw const FormatException('Apple nonce mismatch');
      }
    }

    // Provider-signed claims only. NEVER trust a client-supplied email.
    final emailVerified = decoded['email_verified'] == true ||
        decoded['email_verified'] == 'true';
    final email = decoded['email'];
    return VerifiedSocialIdentity(
      provider: provider,
      subject: decoded['sub'] as String,
      email: emailVerified && email is String && email.contains('@')
          ? email.trim().toLowerCase()
          : null,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchKeys(Uri url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(url).timeout(const Duration(seconds: 7));
      final response = await request.close().timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) {
        throw const FormatException('Provider keys unavailable');
      }
      final raw = await utf8.decoder.bind(response).join()
          .timeout(const Duration(seconds: 7));
      if (raw.length > 100000) {
        throw const FormatException('Provider keys too large');
      }
      final payload = jsonDecode(raw);
      if (payload is! Map || payload['keys'] is! List) {
        throw const FormatException('Malformed provider keys');
      }
      return (payload['keys'] as List)
          .whereType<Map<String, dynamic>>().toList();
    } finally {
      client.close(force: true);
    }
  }
}
