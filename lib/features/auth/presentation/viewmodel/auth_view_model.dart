import 'package:shared_models/shared_models.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/auth_repository.dart';

/// Giris / kayit / profil ekranlarinin beyni.
class AuthViewModel extends BaseViewModel {
  final AuthRepository _repository;

  AuthViewModel(this._repository);

  UserModel? get currentUser => _repository.currentUser;
  bool get isSignedIn => _repository.isSignedIn;

  /// Devam eden mac kimligi (uygulama acilirken maca geri donmek icin)
  String? _activeMatchId;
  String? get activeMatchId => _activeMatchId;

  // ------------------------------------------------------------------
  // GIRIS
  // ------------------------------------------------------------------
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    final kullanici = await run(
      () => _repository.signIn(email: email, password: password),
    );
    return kullanici != null;
  }

  // ------------------------------------------------------------------
  // KAYIT
  // ------------------------------------------------------------------
  /// Backend kayit sirasinda baslangic paketini otomatik veriyor,
  /// bu yuzden burada ayrica istemeye gerek yok.
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final kullanici = await run(
      () => _repository.signUp(
        email: email,
        password: password,
        username: username,
      ),
    );
    return kullanici != null;
  }

  // ------------------------------------------------------------------
  // PROFIL
  // ------------------------------------------------------------------
  /// Ana sayfa acilirken cagrilir: guncel coin/koruma hakki ve
  /// devam eden mac bilgisini tazeler.
  Future<void> refreshProfile() async {
    final cevap = await run(
      () => _repository.fetchProfile(),
      showLoading: false,
    );

    _activeMatchId = cevap?.activeMatchId;
    safeNotify();
  }

  // ------------------------------------------------------------------
  // BASLANGIC PAKETI
  // ------------------------------------------------------------------
  /// Kayit sirasinda verilemediyse elle istenebilir.
  Future<bool> claimStarterPack() async {
    final sonuc = await _repository.grantStarterPack();

    return sonuc.when(
      success: (veri) {
        AppLogger.info('Baslangic paketi verildi: $veri');
        setState(ViewState.idle);
        return true;
      },
      failure: (hata) {
        setError(hata);
        return false;
      },
    );
  }

  // ------------------------------------------------------------------
  // CIKIS
  // ------------------------------------------------------------------
  Future<void> signOut() async {
    _activeMatchId = null;
    await run(() => _repository.signOut());
  }
}
