import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Platform authorization only; the Render backend verifies signed tokens.
class SocialToken {
  const SocialToken(this.provider, this.idToken, {this.rawNonce});
  final String provider;
  final String idToken;
  final String? rawNonce;
}

class SocialSignInService {
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const appleServiceId = String.fromEnvironment('APPLE_SERVICE_ID');
  static const appleRedirectUri = String.fromEnvironment('APPLE_REDIRECT_URI');

  static bool get appleAvailable => !kIsWeb &&
      (Platform.isIOS ||
      (Platform.isAndroid && appleServiceId.isNotEmpty &&
          appleRedirectUri.isNotEmpty));
  static bool get googleAvailable => !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS);

  Future<SocialToken> google() async {
    if (googleWebClientId.isEmpty) {
      throw StateError('Google Web OAuth Client ID ayarlanmadi.');
    }
    final google = GoogleSignIn.instance;
    await google.initialize(
      serverClientId: googleWebClientId,
      clientId: Platform.isIOS && googleIosClientId.isNotEmpty
          ? googleIosClientId : null,
    );
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google kimlik jetonu alinamadi. OAuth ayarlarini kontrol edin.');
    }
    return SocialToken('google', idToken);
  }

  Future<SocialToken> apple() async {
    if (!appleAvailable) {
      throw StateError('Apple girisi icin Apple Developer Services ID gerekli.');
    }
    final nonce = generateNonce();
    final hashed = sha256.convert(utf8.encode(nonce)).toString();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashed,
      webAuthenticationOptions: Platform.isAndroid
          ? WebAuthenticationOptions(
              clientId: appleServiceId,
              redirectUri: Uri.parse(appleRedirectUri),
            )
          : null,
    );
    final token = credential.identityToken;
    if (token == null || token.isEmpty) {
      throw StateError('Apple kimlik jetonu alinamadi.');
    }
    return SocialToken('apple', token, rawNonce: nonce);
  }
}
