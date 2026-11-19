import 'package:shared_models/shared_models.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/utils/logger.dart';
import '../../../items/cosmetics/equipped_cosmetics.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/social_auth_repository.dart';

/// Google/Apple girisi denemesinin sonucu.
enum SocialAuthOutcome { signedIn, needsUsername, cancelled, failed }

/// Giris / kayit / profil ekranlarinin beyni.
class AuthViewModel extends BaseViewModel {
  final AuthRepository _repository;

  final SocialAuthRepository? _social;

  AuthViewModel(this._repository, {SocialAuthRepository? social}) : _social = social;

  UserModel? get currentUser => _repository.currentUser;
  bool get isSignedIn => _repository.isSignedIn;

  /// Devam eden mac kimligi (uygulama acilirken maca geri donmek icin)
  String? _activeMatchId;
  String? get activeMatchId => _activeMatchId;

  // ------------------------------------------------------------------
  // GIRIS
  // ------------------------------------------------------------------
  Future<bool> signIn({required String email, required String password}) async {
    final kullanici = await run(() => _repository.signIn(email: email, password: password));
    return kullanici != null;
  }

  // ------------------------------------------------------------------
  // KAYIT
  // ------------------------------------------------------------------
  /// Backend kayit sirasinda baslangic paketini otomatik veriyor,
  /// bu yuzden burada ayrica istemeye gerek yok.
  Future<bool> signUp({required String email, required String password, required String username}) async {
    final kullanici = await run(() => _repository.signUp(email: email, password: password, username: username));
    return kullanici != null;
  }

  // ------------------------------------------------------------------
  // GOOGLE / APPLE
  // ------------------------------------------------------------------
  bool get googleAvailable => _social?.googleAvailable ?? false;
  bool get appleAvailable => _social?.appleAvailable ?? false;
  bool get usesWebGoogleButton => _social?.usesWebGoogleButton ?? false;
  Future<void> prepareGoogle() => _social?.prepareGoogle() ?? Future<void>.value();
  Stream<SocialCredential> get webGoogleCredentials => _social?.webGoogleCredentials ?? const Stream.empty();

  /// Ad secimi bitene kadar saklanan kimlik
  SocialCredential? _pendingCredential;

  Future<SocialAuthOutcome> continueWith(SocialProvider provider) async {
    final social = _social;
    if (social == null) return SocialAuthOutcome.cancelled;

    setState(ViewState.busy);
    final sonuc = await social.obtainCredential(provider);
    final hata = sonuc.errorOrNull;
    if (hata != null) {
      setError(hata);
      return SocialAuthOutcome.failed;
    }

    final kimlik = sonuc.dataOrNull;
    if (kimlik == null) {
      setState(ViewState.idle);
      return SocialAuthOutcome.cancelled;
    }
    return submitCredential(kimlik);
  }

  Future<SocialAuthOutcome> submitCredential(SocialCredential credential) {
    _pendingCredential = credential;
    return _exchange(credential);
  }

  Future<SocialAuthOutcome> finishWithUsername(String username) async {
    final kimlik = _pendingCredential;
    if (kimlik == null) return SocialAuthOutcome.cancelled;
    return _exchange(kimlik, username: username.trim());
  }

  void cancelSocial() => _pendingCredential = null;

  Future<SocialAuthOutcome> _exchange(SocialCredential credential, {String? username}) async {
    final acildi = await run(() => _social!.exchange(credential, username: username));
    if (acildi == null) return SocialAuthOutcome.failed;
    if (!acildi) return SocialAuthOutcome.needsUsername;
    _pendingCredential = null;
    return SocialAuthOutcome.signedIn;
  }

  // ------------------------------------------------------------------
  // PROFIL
  // ------------------------------------------------------------------
  /// Ana sayfa acilirken cagrilir: guncel coin/koruma hakki ve
  /// devam eden mac bilgisini tazeler.
  Future<void> refreshProfile() async {
    final cevap = await run(() => _repository.fetchProfile(), showLoading: false);

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
    EquippedCosmetics.current?.clear();
    await run(() => _repository.signOut());
  }
}
