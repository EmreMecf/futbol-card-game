import 'dart:async';

import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/repositories/matchmaking_repository.dart';

/// Eslestirme ekraninin asamalari
enum MatchmakingStage {
  /// Kadro ve koruma secimi
  preparing,

  /// Kuyrukta rakip bekleniyor
  searching,

  /// Rakip bulundu, oyun ekranina geciliyor
  found,
}

/// Eslestirme ekraninin beyni.
///
/// RAKIP NASIL BULUNUYOR? (iki kanal birden)
///
///   1. WebSocket  -> Rakip bulundugunda sunucu ANINDA haber verir.
///                    Normal durumda eslesme bu kanaldan gelir.
///
///   2. Yoklama    -> Her 4 saniyede bir find_match tekrar cagrilir.
///                    Iki isi birden yapar:
///                      a) WebSocket koptuysa yedek kanal olur,
///                      b) kuyruk kaydinin `updated_at` alanini tazeler.
///                         Sunucu 2 dakikadir guncellenmeyen kayitlari
///                         "bayat" sayip siliyor; yoklama olmasa uzun
///                         bekleyen oyuncu kuyruktan dusederdi.
class MatchmakingViewModel extends BaseViewModel {
  final MatchmakingRepository _repository;
  final WebSocketService _socket;
  final SessionManager _session;

  StreamSubscription<RealtimeEvent>? _olayAboneligi;
  Timer? _yoklamaZamanlayici;

  MatchmakingViewModel(this._repository, this._socket, this._session);

  // ------------------------------------------------------------------
  // DURUM
  // ------------------------------------------------------------------
  MatchmakingStage _asama = MatchmakingStage.preparing;
  MatchmakingStage get stage => _asama;

  List<DeckSummary> _desteler = [];
  List<DeckSummary> get decks => _desteler;

  DeckSummary? _seciliDeste;
  DeckSummary? get selectedDeck => _seciliDeste;

  List<InventoryCard> _desteKartlari = [];
  List<InventoryCard> get deckCards => _desteKartlari;

  DeckValidation? _dogrulama;
  DeckValidation? get validation => _dogrulama;

  final Set<String> _korunanlar = {};
  Set<String> get protectedCardIds => Set.unmodifiable(_korunanlar);

  String? _bulunanMacId;
  String? get foundMatchId => _bulunanMacId;

  DateTime? _aramaBaslangici;

  /// Kuyrukta ne kadardir bekliyoruz?
  Duration get searchDuration {
    final baslangic = _aramaBaslangici;
    if (baslangic == null) return Duration.zero;
    return DateTime.now().difference(baslangic);
  }

  /// Maca girerken en fazla kac kart korunabilir?
  int get maxProtection => _session.protectionSlots
      .clamp(0, GameRules.maxProtectionSlots);

  /// Daha kart korumaya alinabilir mi?
  bool get canProtectMore => _korunanlar.length < maxProtection;

  /// Mac aranabilir mi?
  bool get canSearch =>
      _seciliDeste != null &&
      (_dogrulama?.isValid ?? false) &&
      _asama == MatchmakingStage.preparing;

  // ------------------------------------------------------------------
  // HAZIRLIK
  // ------------------------------------------------------------------
  Future<void> initialize() async {
    // Once devam eden mac var mi diye bak; varsa dogrudan oraya git.
    final aktif = await _repository.activeMatchId();
    final macId = aktif.dataOrNull;

    if (macId != null) {
      AppLogger.info('Devam eden mac bulundu: $macId', tag: 'ESLESME');
      _bulunanMacId = macId;
      _asama = MatchmakingStage.found;
      safeNotify();
      return;
    }

    await loadDecks();
  }

  Future<void> loadDecks() async {
    final liste = await run(
      () => _repository.fetchDecks(),
      loadingState: ViewState.loading,
    );

    if (liste == null) return;

    _desteler = liste;

    // Aktif desteyi sec, yoksa ilkini
    final aktif = liste.where((d) => d.isActive);
    await selectDeck(aktif.isNotEmpty ? aktif.first : liste.firstOrNull);
  }

  Future<void> selectDeck(DeckSummary? deste) async {
    _seciliDeste = deste;
    _korunanlar.clear();
    _desteKartlari = [];
    _dogrulama = null;
    safeNotify();

    if (deste == null) return;

    // Kadro gecerli mi + kartlari getir (koruma secimi icin)
    final kartlar = await run(
      () => _repository.fetchDeckCards(deste.id),
      showLoading: false,
    );
    if (kartlar != null) _desteKartlari = kartlar;

    final sonuc = await run(
      () => _repository.validateDeck(deste.id),
      showLoading: false,
    );
    _dogrulama = sonuc;

    safeNotify();
  }

  // ------------------------------------------------------------------
  // KART KORUMA
  // ------------------------------------------------------------------
  /// Kartin korumasini ac/kapat.
  ///
  /// KURAL: Maci kaybedersen korumaya ALMADIGIN kartlardan 3 tanesi
  /// rastgele secilip kalici olarak rakibe gecer. Koruma hakki her
  /// galibiyette 1 artar.
  void toggleProtection(String userCardId) {
    if (_korunanlar.contains(userCardId)) {
      _korunanlar.remove(userCardId);
    } else {
      if (!canProtectMore) return;
      _korunanlar.add(userCardId);
    }
    safeNotify();
  }

  bool isProtected(String userCardId) => _korunanlar.contains(userCardId);

  /// En degerli kartlari otomatik korumaya al (kolaylik butonu)
  void autoProtectBest() {
    _korunanlar.clear();

    final sirali = [..._desteKartlari]..sort((a, b) {
        if (a.tier.rank != b.tier.rank) {
          return b.tier.rank.compareTo(a.tier.rank);
        }
        return b.power.compareTo(a.power);
      });

    for (final kart in sirali.take(maxProtection)) {
      _korunanlar.add(kart.userCardId);
    }
    safeNotify();
  }

  // ------------------------------------------------------------------
  // MAC ARAMA
  // ------------------------------------------------------------------
  Future<void> startSearch() async {
    final deste = _seciliDeste;
    if (deste == null) return;

    _asama = MatchmakingStage.searching;
    _aramaBaslangici = DateTime.now();
    safeNotify();

    _olaylariDinle();

    final sonuc = await run(
      () => _repository.findMatch(
        deckId: deste.id,
        protectedCardIds: _korunanlar.toList(),
      ),
      showLoading: false,
    );

    if (sonuc == null) {
      // Hata olustu (ornek: kadro gecersiz) -> hazirliga geri don
      _asama = MatchmakingStage.preparing;
      _durdur();
      safeNotify();
      return;
    }

    if (sonuc.shouldEnterMatch) {
      _macBulundu(sonuc.matchId!);
      return;
    }

    // Kuyruga alindik: yoklamayi baslat
    _yoklamayiBaslat();
  }

  Future<void> cancelSearch() async {
    _durdur();

    final sonuc = await run(
      () => _repository.cancelMatchmaking(),
      showLoading: false,
    );

    // Iptal ederken bu arada eslesmis olabiliriz
    if (sonuc != null && sonuc.shouldEnterMatch) {
      _macBulundu(sonuc.matchId!);
      return;
    }

    _asama = MatchmakingStage.preparing;
    _aramaBaslangici = null;
    safeNotify();
  }

  // ------------------------------------------------------------------
  // KANAL 1: WEBSOCKET
  // ------------------------------------------------------------------
  void _olaylariDinle() {
    _olayAboneligi?.cancel();
    _olayAboneligi = _socket.events.listen((olay) {
      if (olay.isMatchFound) {
        AppLogger.info('Eslesme bildirimi geldi: ${olay.matchId}',
            tag: 'ESLESME');
        _macBulundu(olay.matchId!);
      }
    });
  }

  // ------------------------------------------------------------------
  // KANAL 2: YOKLAMA
  // ------------------------------------------------------------------
  void _yoklamayiBaslat() {
    _yoklamaZamanlayici?.cancel();
    _yoklamaZamanlayici = Timer.periodic(
      GameRules.matchmakingPollInterval,
      (_) => _yokla(),
    );
  }

  Future<void> _yokla() async {
    if (_asama != MatchmakingStage.searching) return;

    final deste = _seciliDeste;
    if (deste == null) return;

    final sonuc = await _repository.findMatch(
      deckId: deste.id,
      protectedCardIds: _korunanlar.toList(),
    );

    final veri = sonuc.dataOrNull;
    if (veri != null && veri.shouldEnterMatch) {
      _macBulundu(veri.matchId!);
    } else {
      // Sayacin ekranda ilerlemesi icin
      safeNotify();
    }
  }

  void _macBulundu(String macId) {
    if (_bulunanMacId != null) return; // iki kanaldan birden gelebilir

    _bulunanMacId = macId;
    _asama = MatchmakingStage.found;
    _durdur();
    safeNotify();
  }

  void _durdur() {
    _yoklamaZamanlayici?.cancel();
    _yoklamaZamanlayici = null;
    _olayAboneligi?.cancel();
    _olayAboneligi = null;
  }

  /// Oyun ekranina gecildikten sonra cagrilir
  void consumeFoundMatch() {
    _bulunanMacId = null;
    _asama = MatchmakingStage.preparing;
    _aramaBaslangici = null;
  }

  @override
  void dispose() {
    _durdur();
    super.dispose();
  }
}
