import 'package:freezed_annotation/freezed_annotation.dart';

import 'user_model.dart';

part 'auth_models.freezed.dart';
part 'auth_models.g.dart';

/// Giris/kayit sonrasi donen jeton cifti.
///
/// access token kisa omurlu (15 dk), her istekte gonderilir.
/// refresh token uzun omurlu (30 gun), sadece yeni access token almak
/// icin kullanilir.
@freezed
abstract class AuthTokens with _$AuthTokens {
  const AuthTokens._();

  const factory AuthTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? accessExpiresAt,
    DateTime? refreshExpiresAt,
  }) = _AuthTokens;

  factory AuthTokens.fromJson(Map<String, dynamic> json) =>
      _$AuthTokensFromJson(json);

  /// Access token'in suresi doldu mu? (30 saniye pay birakilir)
  bool get isAccessExpired {
    final son = accessExpiresAt;
    if (son == null) return false;
    return DateTime.now().toUtc().isAfter(
          son.toUtc().subtract(const Duration(seconds: 30)),
        );
  }
}

/// `/auth/login` ve `/auth/register` cevabi
@freezed
abstract class AuthResponse with _$AuthResponse {
  const factory AuthResponse({
    required UserModel user,
    required AuthTokens tokens,
  }) = _AuthResponse;

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
}

/// `/me` cevabi: profil + varsa devam eden mac
@freezed
abstract class MeResponse with _$MeResponse {
  const factory MeResponse({
    required UserModel user,

    /// Devam eden mac varsa kimligi; yoksa null.
    /// Uygulama acilirken oyuncuyu maca geri dondurmek icin kullanilir.
    String? activeMatchId,
  }) = _MeResponse;

  factory MeResponse.fromJson(Map<String, dynamic> json) =>
      _$MeResponseFromJson(json);
}
