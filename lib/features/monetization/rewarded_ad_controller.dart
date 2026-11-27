import 'dart:async';

import 'package:material_ui/material_ui.dart' show ChangeNotifier;

import '../../core/auth/session_manager.dart';
import '../../core/l10n/app_language.dart';
import '../../core/utils/result.dart';
import 'monetization_api.dart';
import 'monetization_models.dart';
import 'rewarded_ad_provider.dart';

/// 060 — ÖDÜLLÜ REKLAM DURUM MAKİNESİ.
///
///   idle → eligibilityChecking → loading → ready → showing
///        → awaitingVerification → rewardGranted
///                               ↘ cancelled / failed
///
/// Kurallar:
///  * Aynı anda tek reklam (meşgulken yeni istek yok sayılır).
///  * Uygunluğu SUNUCU söyler (bayrak, limit, aktif maç, ilk gün...).
///  * Reklam yüklenmezse oyuncu cezalandırılmaz: oturum "failed" olur,
///    rezervasyon bırakılır, hak düşmez. Otomatik yeniden deneme YOK.
///  * Reklam bitince istemci ödül VERMEZ: "doğrulanıyor" durumuna geçer,
///    sunucu imzalı AdMob geri çağrısıyla ödülü verince "verildi" olur.
///    Geri çağrı gecikirse ödül kaybolmaz; oyuncuya "hazırlanıyor" denir.
class RewardedAdController extends ChangeNotifier {
  final MonetizationApi _api;
  final RewardedAdProvider _provider;
  final SessionManager? _session;
  final Duration pollEvery;
  final Duration pollFor;

  RewardedAdController(
    this._api,
    this._provider, {
    SessionManager? session,
    this.pollEvery = const Duration(seconds: 2),
    this.pollFor = const Duration(seconds: 40),
  })
    // ignore: prefer_initializing_formals
    : _session = session;

  AdLifecycleState _durum = AdLifecycleState.idle;
  AdLifecycleState get state => _durum;

  AdStatus? _ozet;
  AdStatus? get status => _ozet;

  String? _mesaj;

  /// Oyuncuya gösterilecek son bilgi/hata
  String? get message => _mesaj;

  AdReward? _sonOdul;
  AdReward? get lastReward => _sonOdul;

  /// Doğrulama hâlâ bekleniyor (ödül sonra hesaba geçecek)
  bool _bekleyen = false;
  bool get verificationPending => _bekleyen;

  bool get busy => const {
    AdLifecycleState.eligibilityChecking,
    AdLifecycleState.loading,
    AdLifecycleState.ready,
    AdLifecycleState.showing,
    AdLifecycleState.awaitingVerification,
  }.contains(_durum);

  bool _kapandi = false;

  void _git(AdLifecycleState s, [String? mesaj]) {
    if (_kapandi) return;
    _durum = s;
    _mesaj = mesaj;
    notifyListeners();
  }

  Future<void> refreshStatus() async {
    final s = (await Result.guard(_api.status)).dataOrNull;
    if (s != null && !_kapandi) {
      _ozet = s;
      notifyListeners();
    }
  }

  /// Bu yerleşim için düğme gösterilmeli mi (özellik açık mı)
  bool visible(AdPlacement p) {
    final e = _ozet?.of(p);
    return e != null && !e.featureOff;
  }

  /// Reklamı izlet. Döndürülen değer son durum.
  Future<AdLifecycleState> watch(AdPlacement p, {String? targetId}) async {
    if (busy || _kapandi) return _durum;
    _sonOdul = null;
    _bekleyen = false;
    _git(AdLifecycleState.eligibilityChecking);

    final rizaVar = await _provider.ensureConsent();
    if (!rizaVar) {
      _git(AdLifecycleState.failed, 'Reklam için gizlilik tercihin gerekli. Ayarlar > Gizlilik seçeneklerinden değiştirebilirsin.'.tr);
      return _durum;
    }

    final oturum = await Result.guard(() => _api.createSession(p, targetId: targetId));
    final s = oturum.dataOrNull;
    if (s == null) {
      await refreshStatus();
      final neden = _ozet?.of(p)?.reasonText;
      _git(AdLifecycleState.failed, (neden == null || neden.isEmpty) ? 'Şu an reklam açılamıyor.'.tr : neden);
      return _durum;
    }

    _git(AdLifecycleState.loading);
    final yuklendi = await _provider.load(ssvUserId: s.ssvUserId, customData: s.customData);
    if (!yuklendi) {
      await Result.guard(() => _api.event(s.sessionId, 'failed'));
      _git(AdLifecycleState.failed, 'Şu an reklam yok, birazdan tekrar dene. Hakkın düşmedi.'.tr);
      await refreshStatus();
      return _durum;
    }

    _git(AdLifecycleState.ready);
    _git(AdLifecycleState.showing);
    await Result.guard(() => _api.event(s.sessionId, 'shown'));
    final sonuc = await _provider.show();

    switch (sonuc) {
      case AdShowResult.closedWithoutReward:
        await Result.guard(() => _api.event(s.sessionId, 'closed'));
        _git(AdLifecycleState.cancelled, 'Reklam tamamlanmadı; ödül verilmedi, hakkın düşmedi.'.tr);
        await refreshStatus();
        return _durum;
      case AdShowResult.failed:
        await Result.guard(() => _api.event(s.sessionId, 'failed'));
        _git(AdLifecycleState.failed, 'Reklam gösterilemedi. Hakkın düşmedi.'.tr);
        await refreshStatus();
        return _durum;
      case AdShowResult.earned:
        break;
    }

    await Result.guard(() => _api.event(s.sessionId, 'earned'));
    _git(AdLifecycleState.awaitingVerification, 'Ödülün doğrulanıyor…'.tr);
    final son = await _dogrula(s.sessionId);
    if (son == null) {
      _bekleyen = true;
      _git(AdLifecycleState.awaitingVerification, 'Ödülün hazırlanıyor; doğrulanınca hesabına geçecek.'.tr);
    } else if (son.status == 'granted' || son.status == 'credit') {
      _sonOdul = s.reward;
      final u = _session?.user;
      if (u != null && son.coinsAfter != null && son.coinsAfter != u.coins) {
        await _session!.updateUser(u.copyWith(coins: son.coinsAfter!));
      }
      _git(
        AdLifecycleState.rewardGranted,
        son.status == 'credit'
            ? 'Sandık bu sırada açıldı. Hızlandırma hakkın saklandı; başka bir sandıkta kullanabilirsin.'.tr
            : 'Ödül hesabına geçti: {r}'.trArgs({'r': s.reward.label}),
      );
    } else {
      _git(AdLifecycleState.failed, 'Ödül doğrulanamadı ({r}).'.trArgs({'r': son.rejectReason ?? son.status}));
    }
    await refreshStatus();
    return _durum;
  }

  /// Sunucu kesin sonucu verene kadar yokla (null: süre doldu, bekliyor)
  Future<AdSessionState?> _dogrula(String id) async {
    final bitis = DateTime.now().add(pollFor);
    while (!_kapandi && DateTime.now().isBefore(bitis)) {
      final d = (await Result.guard(() => _api.sessionState(id))).dataOrNull;
      if (d != null && d.isFinal) return d;
      await Future<void>.delayed(pollEvery);
    }
    return null;
  }

  /// Sandık reklam sırasında açıldıysa saklanan hızlandırmayı uygula
  Future<bool> applyCredit(String chestId) async {
    final id = _ozet?.creditSessionIds.firstOrNull;
    if (id == null) return false;
    final r = await Result.guard(() => _api.applyCredit(id, chestId));
    await refreshStatus();
    return r.dataOrNull?.status == 'granted';
  }

  void reset() {
    if (busy) return;
    _git(AdLifecycleState.idle);
  }

  @override
  void dispose() {
    _kapandi = true;
    _durum = AdLifecycleState.disposed;
    _provider.dispose();
    super.dispose();
  }
}
