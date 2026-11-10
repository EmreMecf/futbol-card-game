import 'dart:async';

import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/utils/result.dart';
import '../../domain/chest_messages.dart';
import '../../domain/chest_repository.dart';

/// Sandıklar (Ekonomi V2, FAZ 1) — ana sayfa şeridi ve sandık ekranı.
///
/// ===================================================================
/// SAAT: SUNUCU SAATİ
/// ===================================================================
/// Sayaçlar cihaz saatiyle değil, sunucunun gönderdiği `serverTime`
/// ile hesaplanır: cihaz saati ileri alınsa da sandık erken açılmaz
/// (zaten sunucu reddeder) ve ekran yanlış süre göstermez.
///
/// ===================================================================
/// PERFORMANS
/// ===================================================================
/// Saniyelik zamanlayıcı YALNIZ sayacı çalışan bir sandık varken açıktır.
/// Boştaki ekran kare çizmez (bkz. faz8_performans_test).
///
/// ===================================================================
/// TEKRAR İSTEK
/// ===================================================================
/// Her kullanıcı eylemi bir idempotency anahtarı alır; ağ hatasında
/// aynı eylem tekrar denenirse AYNI anahtar gider ve sunucu ödülü ikinci
/// kez vermez.
class ChestsViewModel extends BaseViewModel {
  final ChestRepository _repository;
  final WebSocketService? _socket;
  final SessionManager? _session;

  // Özel adlı parametre yazımı projede kullanılmıyor (bkz. ProfileViewModel)
  // ignore: prefer_initializing_formals
  ChestsViewModel(this._repository, {WebSocketService? socket, SessionManager? session})
      // ignore: prefer_initializing_formals
      : _socket = socket,
        // ignore: prefer_initializing_formals
        _session = session;

  ChestInventory? _envanter;
  ChestInventory? get inventory => _envanter;
  bool get isEnabled => _envanter?.enabled ?? false;

  ChestOdds? _oranlar;
  ChestOdds? get odds => _oranlar;

  /// Son açılan sandığın sonucu (açılış sahnesi)
  ChestOpenResult? _sonAcilis;
  ChestOpenResult? get lastOpening => _sonAcilis;

  /// İşlem süren sandık (düğme kilidi)
  String? _islenen;
  String? get busyChestId => _islenen;

  /// Kullanıcıya gösterilecek son hata (Türkçe)
  String? _hata;
  String? get actionError => _hata;

  // Sunucu saati - cihaz saati farkı
  Duration _saatFarki = Duration.zero;
  DateTime get serverNow => DateTime.now().toUtc().add(_saatFarki);

  Timer? _sayac;
  StreamSubscription<RealtimeEvent>? _abonelik;

  // Eylem başına idempotency anahtarı: "unlock:<id>" -> anahtar
  final Map<String, String> _anahtarlar = {};
  String _anahtar(String eylem) => _anahtarlar.putIfAbsent(eylem, ApiClient.newIdempotencyKey);

  Future<void> load() async {
    final sonuc = await run(() => _repository.fetchInventory(), loadingState: ViewState.loading);
    if (sonuc != null) _envanterAyarla(sonuc);
    _abonelik ??= _socket?.events.listen((olay) {
      if (olay.isChestGranted) refresh();
    });
  }

  /// Sessiz tazeleme (sandık verildi bildirimi, ekrana dönüş)
  Future<void> refresh() async {
    final sonuc = await _repository.fetchInventory();
    final env = sonuc.dataOrNull;
    if (env != null) _envanterAyarla(env);
  }

  Future<void> loadOdds({int? version}) async {
    final sonuc = await _repository.fetchOdds(version: version);
    _oranlar = sonuc.dataOrNull ?? _oranlar;
    safeNotify();
  }

  void _envanterAyarla(ChestInventory env) {
    _envanter = env;
    _saatFarki = env.serverTime.toUtc().difference(DateTime.now().toUtc());
    _sayaciAyarla();
    safeNotify();
  }

  void _sayaciAyarla() {
    final sayacVar = _envanter?.slots.any((c) => c.isUnlocking) ?? false;
    if (!sayacVar) {
      _sayac?.cancel();
      _sayac = null;
      return;
    }
    _sayac ??= Timer.periodic(const Duration(seconds: 1), (_) {
      // Süresi dolan sandık "hazır" görünsün diye sunucudan tazele
      final biten = _envanter?.slots.any((c) => c.isUnlocking && (c.remaining(serverNow) ?? Duration.zero) == Duration.zero);
      if (biten ?? false) {
        refresh();
      } else {
        safeNotify();
      }
    });
  }

  /// Sayacı çalışan sandığın kalan süresi
  Duration? remaining(Chest c) => c.remaining(serverNow);

  // ------------------------------------------------------------------
  // EYLEMLER
  // ------------------------------------------------------------------
  Future<bool> startUnlock(Chest c) => _eylem(c.id, 'unlock:${c.id}',
      (k) => _repository.startUnlock(c.id, idempotencyKey: k), (_) => refresh());

  Future<bool> claimMailbox(Chest c) => _eylem(c.id, 'mailbox:${c.id}',
      (k) => _repository.claimMailbox(c.id, idempotencyKey: k), (_) => refresh());

  /// Sandığı açar; sonuç [lastOpening]'de (açılış sahnesi gösterir)
  Future<bool> open(Chest c) => _eylem(c.id, 'open:${c.id}', (k) => _repository.open(c.id, idempotencyKey: k),
      (sonuc) async {
    _sonAcilis = sonuc;
    // Altın değişti: üst bantta doğru görünsün
    final kullanici = _session?.user;
    if (kullanici != null && sonuc.coinsAfter != null) {
      await _session!.updateUser(kullanici.copyWith(coins: sonuc.coinsAfter!));
    }
    await refresh();
  });

  void clearOpening() {
    _sonAcilis = null;
    safeNotify();
  }

  void clearActionError() {
    _hata = null;
    safeNotify();
  }

  Future<bool> _eylem<T>(
    String chestId,
    String eylem,
    Future<Result<T>> Function(String anahtar) is_,
    FutureOr<void> Function(T sonuc) basarili,
  ) async {
    if (_islenen != null) return false;
    _islenen = chestId;
    _hata = null;
    safeNotify();
    final sonuc = await is_(_anahtar(eylem));
    _islenen = null;
    final hata = sonuc.errorOrNull;
    if (hata != null) {
      // Ağ hatasında anahtar KORUNUR (tekrar aynı anahtarla); kesin
      // red (kural) gelirse yeni eylem yeni anahtar alır.
      if (hata.type != AppErrorType.network) _anahtarlar.remove(eylem);
      _hata = chestErrorMessage(hata);
      safeNotify();
      return false;
    }
    _anahtarlar.remove(eylem);
    await basarili(sonuc.dataOrNull as T);
    safeNotify();
    return true;
  }

  @override
  void dispose() {
    _sayac?.cancel();
    _abonelik?.cancel();
    super.dispose();
  }
}
