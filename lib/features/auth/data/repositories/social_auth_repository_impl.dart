import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_models/shared_models.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/social_auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// Google ve Apple SDK'larını sunucudaki `/auth/social` ucuna bağlar.
///
/// Düğmeler yalnız ilgili istemci kimliği ayarlıysa görünür. Apple, Android'de
/// sunmuyor: orada yalnız Google vardır.
class SocialAuthRepositoryImpl implements SocialAuthRepository {
  final AuthRemoteDataSource _remote;
  final SessionManager _session;
  final WebSocketService _socket;
  Future<void>? _googleInit;

  SocialAuthRepositoryImpl(this._remote, this._session, this._socket);

  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  bool get googleAvailable {
    if (_isIos) return AppConfig.googleIosClientId.isNotEmpty;
    return (kIsWeb || _isAndroid) && AppConfig.googleWebClientId.isNotEmpty;
  }

  @override
  bool get appleAvailable {
    if (_isIos) return AppConfig.appleSignInIos;
    return kIsWeb && AppConfig.appleServiceId.isNotEmpty && AppConfig.appleRedirectUri.isNotEmpty;
  }

  @override
  bool get usesWebGoogleButton => kIsWeb;

  @override
  Future<void> prepareGoogle() => _googleInit ??= GoogleSignIn.instance.initialize(
    clientId: kIsWeb
        ? AppConfig.googleWebClientId
        : _isIos
        ? AppConfig.googleIosClientId
        : null,
    serverClientId: kIsWeb ? null : AppConfig.googleWebClientId,
  );

  @override
  Stream<SocialCredential> get webGoogleCredentials async* {
    await prepareGoogle();
    // Oyuncunun vazgeçmesi de hata olarak gelir; Google düğmesi kendi durumunu gösterir
    final events = GoogleSignIn.instance.authenticationEvents.handleError((Object _) {});
    await for (final event in events) {
      if (event is! GoogleSignInAuthenticationEventSignIn) continue;
      final token = event.user.authentication.idToken;
      if (token != null) yield SocialCredential(provider: SocialProvider.google, idToken: token);
    }
  }

  @override
  Future<Result<SocialCredential?>> obtainCredential(SocialProvider provider) {
    return Result.guard(() => provider == SocialProvider.google ? _google() : _apple());
  }

  Future<SocialCredential?> _google() async {
    try {
      await prepareGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError);
      return SocialCredential(provider: SocialProvider.google, idToken: token);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AppException(
        message: 'Google ile giriş tamamlanamadı. Lütfen tekrar dene.',
        technicalDetail: e.toString(),
      );
    }
  }

  Future<SocialCredential?> _apple() async {
    final nonce = _randomNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email],
        nonce: sha256.convert(utf8.encode(nonce)).toString(),
        webAuthenticationOptions: kIsWeb
            ? WebAuthenticationOptions(
                clientId: AppConfig.appleServiceId,
                redirectUri: Uri.parse(AppConfig.appleRedirectUri),
              )
            : null,
      );
      final token = credential.identityToken;
      if (token == null) throw const SignInWithAppleCredentialsException(message: 'identityToken yok');
      return SocialCredential(provider: SocialProvider.apple, idToken: token, nonce: nonce);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw AppException(message: 'Apple ile giriş tamamlanamadı. Lütfen tekrar dene.', technicalDetail: e.toString());
    } on SignInWithAppleException catch (e) {
      throw AppException(message: 'Apple ile giriş tamamlanamadı. Lütfen tekrar dene.', technicalDetail: e.toString());
    }
  }

  @override
  Future<Result<bool>> exchange(SocialCredential credential, {String? username}) {
    return Result.guard(() async {
      final json = await _remote.socialSignIn(
        provider: credential.provider.name,
        idToken: credential.idToken,
        nonce: credential.nonce,
        username: username,
      );
      if (json['needs_username'] == true) return false;

      final cevap = AuthResponse.fromJson(json);
      await _session.save(tokens: cevap.tokens, user: cevap.user);
      await _socket.reconnect();
      return true;
    });
  }

  @override
  Future<Result<Set<SocialProvider>>> linkedProviders() {
    return Result.guard(() async {
      final json = await _remote.socialLinks();
      return {
        for (final p in (json['providers'] as List? ?? const []))
          for (final s in SocialProvider.values)
            if (s.name == p) s,
      };
    });
  }

  @override
  Future<Result<void>> link(SocialCredential credential) {
    return Result.guard(() async {
      await _remote.linkSocial(provider: credential.provider.name, idToken: credential.idToken, nonce: credential.nonce);
    });
  }

  static String _randomNonce() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256))).replaceAll('=', '');
  }
}
