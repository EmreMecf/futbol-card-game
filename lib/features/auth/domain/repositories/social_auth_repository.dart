import '../../../../core/utils/result.dart';

enum SocialProvider { google, apple }

/// Google ya da Apple'ın verdiği, sunucuda doğrulanacak kimlik.
class SocialCredential {
  final SocialProvider provider;
  final String idToken;

  /// Apple girişinde üretilen ham değer (jetonda SHA-256 özeti bulunur)
  final String? nonce;

  const SocialCredential({required this.provider, required this.idToken, this.nonce});
}

/// Google ve Apple ile giriş sözleşmesi.
abstract interface class SocialAuthRepository {
  bool get googleAvailable;
  bool get appleAvailable;

  /// Web'de Google kendi düğmesini çizer; kimlik [webGoogleCredentials] ile gelir.
  bool get usesWebGoogleButton;

  Future<void> prepareGoogle();
  Stream<SocialCredential> get webGoogleCredentials;

  /// Sağlayıcının giriş ekranını açar. Oyuncu vazgeçerse `null` döner.
  Future<Result<SocialCredential?>> obtainCredential(SocialProvider provider);

  /// Kimliği sunucuya gönderir. `true`: oturum açıldı, `false`: yeni oyuncu ad seçmeli.
  Future<Result<bool>> exchange(SocialCredential credential, {String? username});
}
