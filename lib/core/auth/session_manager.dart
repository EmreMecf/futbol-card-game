import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';

import '../storage/token_storage.dart';
import '../utils/logger.dart';

/// Oturumun tek kaynagi (single source of truth).
///
/// Hem yonlendirme (router) hem de ag katmani buradaki duruma bakar:
///   * ApiClient  -> istege eklenecek jetonu buradan alir
///   * AppRouter  -> giris yapilmis mi diye buraya bakar
///   * ViewModel'ler -> kullanici bilgisini buradan okur
class SessionManager extends ChangeNotifier {
  final TokenStorage _storage;

  AuthTokens? _tokens;
  UserModel? _user;
  bool _hazir = false;

  SessionManager(this._storage);

  /// Uygulama acilisinda cihazdaki oturum okundu mu?
  bool get isReady => _hazir;

  bool get isSignedIn => _tokens != null;

  String? get accessToken => _tokens?.accessToken;
  String? get refreshToken => _tokens?.refreshToken;

  /// Su anki oyuncu (giris yapilmamissa null)
  UserModel? get user => _user;

  String? get userId => _user?.id;
  String? get username => _user?.username;

  /// Kart koruma hakki (ekranda gostermek icin)
  int get protectionSlots => _user?.protectionSlots ?? GameRules.baseProtectionSlots;

  /// Uygulama acilirken cihazda kayitli oturumu yukler.
  Future<void> restore() async {
    final erisim = await _storage.readAccessToken();
    final yenileme = await _storage.readRefreshToken();

    if (erisim != null && yenileme != null) {
      _tokens = AuthTokens(accessToken: erisim, refreshToken: yenileme);
    }

    final kullaniciJson = await _storage.readUser();
    if (kullaniciJson != null) {
      try {
        _user = UserModel.fromJson(kullaniciJson);
      } catch (e) {
        // Model degistiyse eski kayit okunamayabilir; sorun degil,
        // profil sunucudan tekrar cekilir.
        AppLogger.warning('Kayitli profil okunamadi: $e', tag: 'OTURUM');
      }
    }

    _hazir = true;
    AppLogger.info(
      isSignedIn ? 'Kayitli oturum bulundu: $username' : 'Kayitli oturum yok.',
      tag: 'OTURUM',
    );
    notifyListeners();
  }

  /// Giris/kayit sonrasi cagrilir.
  Future<void> save({required AuthTokens tokens, UserModel? user}) async {
    _tokens = tokens;
    if (user != null) _user = user;

    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    if (user != null) await _storage.saveUser(user.toJson());

    notifyListeners();
  }

  /// Jeton yenilendiginde cagrilir (kullanici bilgisi degismez).
  Future<void> updateTokens(AuthTokens tokens) async {
    _tokens = tokens;
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    // Jeton yenilemesi ekrani ilgilendirmez; gereksiz yeniden cizim olmasin.
  }

  /// Profil guncellendiginde (mac sonrasi coin/koruma hakki degisir)
  Future<void> updateUser(UserModel user) async {
    _user = user;
    await _storage.saveUser(user.toJson());
    notifyListeners();
  }

  /// Cikis / oturum gecersiz oldugunda.
  Future<void> clear() async {
    _tokens = null;
    _user = null;
    await _storage.clear();
    AppLogger.info('Oturum temizlendi.', tag: 'OTURUM');
    notifyListeners();
  }
}
