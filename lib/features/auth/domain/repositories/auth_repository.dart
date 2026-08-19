import 'package:shared_models/shared_models.dart';

import '../../../../core/utils/result.dart';

/// Kimlik dogrulama islemlerinin SOZLESMESI.
///
/// Donen tipler [UserModel] gibi PAYLASILAN modellerdir; sunucu da ayni
/// siniflari kullanir.
abstract interface class AuthRepository {
  /// Cihazda kayitli oturumu yukler (uygulama acilisinda).
  Future<void> restoreSession();

  bool get isSignedIn;

  UserModel? get currentUser;

  Future<Result<UserModel>> signUp({
    required String email,
    required String password,
    required String username,
  });

  Future<Result<UserModel>> signIn({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();

  /// Sunucudan guncel profili ve devam eden mac bilgisini ceker.
  Future<Result<MeResponse>> fetchProfile();

  /// Baslangic paketini ister (17 kart + hazir kadro).
  Future<Result<Map<String, dynamic>>> grantStarterPack();
}
