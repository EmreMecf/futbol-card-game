import '../../../../core/network/api_client.dart';

/// Backend ile HAM iletisim katmani.
///
/// Burada hata yakalama YAPILMAZ; hatalar oldugu gibi yukari firlar ve
/// repository katmaninda [Result] icine sarilir. Her katmanin tek bir
/// sorumlulugu olsun diye boyle ayrildi.
class AuthRemoteDataSource {
  final ApiClient _api;

  AuthRemoteDataSource(this._api);

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String username,
  }) {
    return _api.post('/auth/register', govde: {
      'email': email,
      'password': password,
      'username': username,
    });
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) {
    return _api.post('/auth/login', govde: {
      'email': email,
      'password': password,
    });
  }

  Future<void> signOut(String? refreshToken) async {
    await _api.post('/auth/logout', govde: {
      'refresh_token': ?refreshToken,
    });
  }

  /// Profil + devam eden mac bilgisi
  Future<Map<String, dynamic>> me() => _api.get('/me');

  Future<Map<String, dynamic>> grantStarterPack() =>
      _api.post('/game/starter-pack');
}
