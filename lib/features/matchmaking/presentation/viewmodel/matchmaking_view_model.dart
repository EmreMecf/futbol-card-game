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
  // Polling errors must not leave both devices on an endlessly silent screen.
  bool _pollInFlight = false;
  int _consecutivePollFailures = 0;
  String? _searchWarning;
  String? get searchWarning => _searchWarning;


  MatchmakingViewModel(
    this._repository,
    this._socket,
    this._session, {
    Future<bool> Function()? cardLossEnabled,
    Future<bool> Function()? trainingEnabled,
    Future<TutorialStatus?> Function()? tutorialStatus,
  })  // ignore: prefer_initializing_formals
      : _kartKaybiSor = cardLossEnabled,
        // ignore: prefer_initializing_formals
        _antrenmanSor = trainingEnabled,
        // ignore: prefer_initializing_formals
        _ogreticiSor = tutorialStatus;

  /// 042: öğretici durumu. Kayıt yoksa (testler) yok sayılır.
  final Future<TutorialStatus?> Function()? _ogreticiSor;
  TutorialStatus? _ogretici;
  TutorialStatus? get tutorial => _ogretici;

  /// 041: antrenman modu açık mı? Kayıt yoksa (testler) kapalı.
  final Future<bool> Function()? _antrenmanSor;
  bool _antrenman = false;
  bool get trainingEnabled => _antrenman;

  /// 037 (R2): dereceli maçta kalıcı kart kaybı açık mı? Kayıt yoksa
  /// (testler) bugünkü davranış: açık.
  final Future<bool> Function()? _kartKaybiSor;
  bool _kartKaybi = true;
  bool get cardLossEnabled => _kartKaybi;

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

    final sor = _kartKaybiSor;
    if (sor != null) {
      _kartKaybi = await sor();
      if (!_kartKaybi) _korunanlar.clear();
    }
    final antrenman = _antrenmanSor;
    if (antrenman != null) _antrenman = await antrenman();
    final ogretici = _ogreticiSor;
    if (ogretici != null) _ogretici = await ogretici();
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
    _consecutivePollFailures = 0;
    _searchWarning = null;
    _aramaBaslangici = DateTime.now();
    safeNotify();

    _olaylariDinle();

    final sonuc = await run(
      () => _repository.findMatch(
        deckId: deste.id,
        protectedCardIds: _kartKaybi ? _korunanlar.toList() : const [],
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

  /// 041: bota karşı antrenman (ödülsüz, puansız). Kuyruğa girilmez;
  /// sunucu maçı hemen kurar.
  Future<void> startTraining() async {
    final deste = _seciliDeste;
    if (deste == null || !_antrenman || !canSearch) return;

    final sonuc = await run(
      () => _repository.startTraining(deckId: deste.id),
      showLoading: false,
    );
    if (sonuc != null && sonuc.shouldEnterMatch) {
      _macBulundu(sonuc.matchId!);
    }
  }

  /// 042: öğreticinin sıradaki adımı (bota karşı kısa maç, ödülsüz;
  /// 3. adım bitince Gümüş sandık). Kuyruğa girilmez.
  Future<void> startTutorial() async {
    final deste = _seciliDeste;
    if (deste == null || !(_ogretici?.shouldOffer ?? false) || !canSearch) return;

    final sonuc = await run(
      () => _repository.startTutorial(deckId: deste.id),
      showLoading: false,
    );
    if (sonuc != null && sonuc.shouldEnterMatch) {
      _macBulundu(sonuc.matchId!);
    }
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
    if (_asama != MatchmakingStage.searching || _pollInFlight) return;
    final deste = _seciliDeste;
    if (deste == null) return;

    _pollInFlight = true;
    try {
      final sonuc = await _repository.findMatch(
        deckId: deste.id,
        protectedCardIds: _kartKaybi ? _korunanlar.toList() : const [],
      );

      // HTTP may complete after websocket has already navigated to a match.
      if (_asama != MatchmakingStage.searching) return;
      final veri = sonuc.dataOrNull;
      if (veri != null) {
        _consecutivePollFailures = 0;
        _searchWarning = null;
        if (veri.shouldEnterMatch) {
          _macBulundu(veri.matchId!);
          return;
        }
      } else {
        _consecutivePollFailures++;
        AppLogger.warning(
          'Eslestirme kontrolu basarisiz ($_consecutivePollFailures)',
          tag: 'ESLESME',
        );
        if (_consecutivePollFailures >= 2) {
          _searchWarning =
              'Sunucuya baglanti kontrol ediliyor. Rakip arama otomatik suruyor.';
        }
        // Recover from a missed WebSocket notification after a timeout/
        // failed find request. Never clear or recreate the queue here.
        final active = await _repository.activeMatchId();
        if (_asama == MatchmakingStage.searching &&
            active.dataOrNull != null) {
          _macBulundu(active.dataOrNull!);
          return;
        }
      }
      safeNotify();
    } finally {
      _pollInFlight = false;
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
