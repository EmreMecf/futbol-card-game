import 'dart:async';

import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../social_sign_in_service.dart';

/// [AuthRepository] sozlesmesinin gerceklenmesi.
///
/// Isleri:
///   * veri kaynagini cagirmak,
///   * gelen JSON'u PAYLASILAN modele cevirmek,
///   * jetonlari [SessionManager]'a yazmak,
///   * giris/cikista WebSocket baglantisini acip kapatmak.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final SessionManager _session;
  final WebSocketService _socket;

  AuthRepositoryImpl(this._remote, this._session, this._socket);

  @override
  bool get isSignedIn => _session.isSignedIn;

  @override
  UserModel? get currentUser => _session.user;

  @override
  Future<void> restoreSession() async {
    await _session.restore();
    if (_session.isSignedIn) {
      // Oturum varsa gercek zamanli baglantiyi hemen ac
      unawaited(_socket.reconnect());
    }
  }

  @override
  Future<Result<UserModel>> signUp({
    required String email,
    required String password,
    required String username,
  }) {
    return Result.guard(() async {
      final json = await _remote.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        username: username.trim(),
      );
      return _oturumuKur(AuthResponse.fromJson(json));
    });
  }

  @override
  Future<Result<UserModel>> signIn({
    required String email,
    required String password,
  }) {
    return Result.guard(() async {
      final json = await _remote.signIn(
        email: email.trim().toLowerCase(),
        password: password,
      );
      return _oturumuKur(AuthResponse.fromJson(json));
    });
  }

  Future<SocialToken> _getToken(String provider) async {
    final service = SocialSignInService();
    return switch (provider) {
      'google' => service.google(),
      'apple' => service.apple(),
      _ => throw ArgumentError.value(provider, 'provider'),
    };
  }

  @override
  Future<Result<UserModel>> signInSocial(String provider) =>
      Result.guard(() async {
        final token = await _getToken(provider);
        final json = await _remote.socialSignIn(
          provider: token.provider, idToken: token.idToken,
          rawNonce: token.rawNonce,
        );
        return _oturumuKur(AuthResponse.fromJson(json));
      });

  @override
  Future<Result<void>> linkSocial(String provider) =>
      Result.guard(() async {
        if (!_session.isSignedIn) {
          throw StateError('Hesap baglamak icin giris yapin.');
        }
        final token = await _getToken(provider);
        await _remote.linkSocial(
          provider: token.provider, idToken: token.idToken,
          rawNonce: token.rawNonce,
        );
      });

  @override
  Future<Result<void>> signOut() {
    return Result.guard(() async {
      // Sunucudaki refresh token'i iptal etmeye calis. Basarisiz olsa
      // bile yerel oturumu temizliyoruz; kullanici cikis yapabilmeli.
      try {
        await _remote.signOut(_session.refreshToken);
      } catch (_) {}

      await _socket.disconnect();
      await _session.clear();
    });
  }

  @override
  Future<Result<MeResponse>> fetchProfile() {
    return Result.guard(() async {
      final cevap = MeResponse.fromJson(await _remote.me());
      await _session.updateUser(cevap.user);
      return cevap;
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> grantStarterPack() =>
      Result.guard(() => _remote.grantStarterPack());

  // ------------------------------------------------------------------
  /// Giris/kayit cevabindan jetonlari kaydeder ve WebSocket'i acar.
  Future<UserModel> _oturumuKur(AuthResponse cevap) async {
    await _session.save(tokens: cevap.tokens, user: cevap.user);
    await _socket.reconnect();
    return cevap.user;
  }
}
