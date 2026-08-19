import 'package:flutter/foundation.dart';

import '../error/app_exception.dart';
import '../utils/logger.dart';
import '../utils/result.dart';
import 'view_state.dart';

/// Tum ViewModel'lerin atasi.
///
/// MVVM'deki "VM" katmani burasi. Gorevi:
///   * Ekranin durumunu ([ViewState]) tutmak,
///   * hata mesajini tasimak,
///   * repository cagrilarini sarmalayip tekrar eden kodu ortadan kaldirmak.
///
/// View (Widget) katmani ASLA repository'yi dogrudan cagirmaz; hep
/// ViewModel uzerinden gider.
abstract class BaseViewModel extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  AppException? _error;
  bool _isDisposed = false;

  ViewState get state => _state;
  AppException? get error => _error;

  bool get isLoading => _state == ViewState.loading;
  bool get isBusy => _state == ViewState.busy;
  bool get hasError => _state == ViewState.error && _error != null;

  /// Kullaniciya gosterilecek hata mesaji (yoksa null)
  String? get errorMessage => _error?.message;

  /// Durumu degistirir ve dinleyicileri uyarir.
  void setState(ViewState newState) {
    if (_isDisposed || _state == newState) return;
    _state = newState;
    notifyListeners();
  }

  /// Hata durumuna gecer.
  void setError(AppException exception) {
    if (_isDisposed) return;
    _error = exception;
    _state = ViewState.error;
    notifyListeners();
  }

  /// Hatayi temizler (kullanici SnackBar'i kapatinca cagrilir).
  void clearError() {
    if (_isDisposed || _error == null) return;
    _error = null;
    if (_state == ViewState.error) _state = ViewState.idle;
    notifyListeners();
  }

  /// Guvenli notifyListeners: ViewModel yok edildikten sonra
  /// cagrilirsa Flutter hata firlatir; bu sarmalayici onu engeller.
  void safeNotify() {
    if (_isDisposed) return;
    notifyListeners();
  }

  /// Bir repository cagrisini calistirir ve durum yonetimini otomatik yapar.
  ///
  /// Ornek kullanim:
  /// ```dart
  /// Future<void> girisYap(String email, String sifre) async {
  ///   final kullanici = await run(() => _repo.signIn(email, sifre));
  ///   if (kullanici != null) _kullanici = kullanici;
  /// }
  /// ```
  ///
  /// [showLoading] false verilirse ekran spinner gostermez
  /// (arka plan yenilemelerinde kullanisli).
  Future<T?> run<T>(
    Future<Result<T>> Function() action, {
    bool showLoading = true,
    ViewState loadingState = ViewState.busy,
  }) async {
    if (_isDisposed) return null;

    _error = null;
    if (showLoading) setState(loadingState);

    final result = await action();

    if (_isDisposed) return null;

    return result.when(
      success: (data) {
        setState(ViewState.idle);
        return data;
      },
      failure: (err) {
        setError(err);
        return null;
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    AppLogger.info('$runtimeType kapatildi.', tag: 'VM');
    super.dispose();
  }
}
