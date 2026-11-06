import 'dart:async';

import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/session_manager.dart';
import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/clash_event.dart';
import '../../domain/repositories/match_repository.dart';

/// Maç ekranının beyni.
///
/// ÜÇ ÖNEMLİ TASARIM KARARI:
///
/// 1) SUNUCU SAATİYLE SAYAÇ
///    Oyuncunun telefon saati yanlış (hatta kasıtlı değiştirilmiş)
///    olabilir. Sunucu her durum güncellemesinde hem son anı hem de
///    KENDİ o anki saatini gönderiyor. Aradaki farkı bir kez ölçüp
///    saklıyoruz; sayaç bundan sonra cihaz saatinden bağımsız çalışıyor.
///
/// 2) OLAY GELİNCE TAZELEME, OLAYDAN VERİ OKUMA DEĞİL
///    WebSocket mesajları kasıtlı olarak küçük: sadece "şu maçta bir
///    şey oldu" diyor. Detayı REST ile çekiyoruz. Böylece bildirim
///    kanalından yanlışlıkla gizli veri (rakibin eli) sızması imkânsız.
///
/// 3) TAZELEME GECİKTİRİLİYOR (debounce)
///    Tek bir hamle üç olay üretebiliyor (move_played, round_resolved,
///    match_updated). Her biri için ayrı istek atmak yerine kısa bir
///    süre bekleyip TEK istek atıyoruz.
class MatchViewModel extends BaseViewModel {
  final MatchRepository _repository;
  final WebSocketService _socket;
  final SessionManager _session;

  final String matchId;

  StreamSubscription<RealtimeEvent>? _olayAboneligi;
  StreamSubscription<bool>? _baglantiAboneligi;
  Timer? _sayacZamanlayici;
  Timer? _tazelemeGecikmesi;

  /// Bağlantı kopukken geçen saniye (sayaç vuruşlarıyla sayılır).
  ///
  /// NEDEN DateTime.now() DEĞİL? Cihaz saati değiştirilebilir; sayaç
  /// vuruşu saymak saatten bağımsız ve daha basit.
  int _kopukSaniye = 0;

  /// WebSocket kopukken maç durumu bu aralıkla REST'ten çekilir.
  static const offlinePollInterval = Duration(seconds: 5);

  MatchViewModel(
    this._repository,
    this._socket,
    this._session, {
    required this.matchId,
  });

  // ------------------------------------------------------------------
  // DURUM
  // ------------------------------------------------------------------
  MatchState? _durum;

  /// Macin o anki durumu.
  ///
  /// NOT: `state` degil `matchState` denmesinin sebebi, BaseViewModel'de
  /// zaten ekranin yuklenme durumunu tutan bir `state` alani olmasi.
  MatchState? get matchState => _durum;

  List<HandCard> _el = [];
  List<HandCard> get hand => _el;

  MatchHistory _gecmis = const MatchHistory();
  MatchHistory get history => _gecmis;

  MatchResultSummary? _sonuc;
  MatchResultSummary? get result => _sonuc;

  MatchRewardDelta? _odulFarki;

  /// Maçın coin / puan / koruma hakkına etkisi (sonuç ekranı için).
  ///
  /// Sunucu maç sonrası YENİ profili gönderiyor ama farkı göndermiyor.
  /// Fark, oturumu güncellemeden hemen önceki (maç öncesi) değerle
  /// sunucunun gönderdiği yeni değer arasından çıkarılıyor; iki sayı
  /// da sunucudan, istemci hiçbir ödül hesaplamıyor.
  ///
  /// Maç öncesi profil bilinmiyorsa (oturum boş) null: sonuç ekranı
  /// o zaman ödül kutularını hiç göstermez, yanlış "+0" yazmaz.
  MatchRewardDelta? get rewardDelta => _odulFarki;

  /// Kart oynanırken buton kilitlensin diye
  bool _hamleGonderiliyor = false;
  bool get isSubmittingMove => _hamleGonderiliyor;

  /// Sunucu saati ile cihaz saati arasındaki fark
  Duration _saatFarki = Duration.zero;

  String? get myUserId => _session.userId;

  // ------------------------------------------------------------------
  // TÜRETİLMİŞ DEĞERLER
  // ------------------------------------------------------------------
  bool get isMyTurn => _durum?.isMyTurn ?? false;
  bool get isOver => _durum?.isOver ?? false;

  /// Turu ben mi açıyorum? (açıyorsam istediğim pozisyonu seçebilirim)
  bool get canChoosePosition => _durum?.canChoosePosition ?? false;

  /// Rakip turu açtıysa, oynamak ZORUNDA olduğum pozisyon
  CardPosition? get requiredPosition => _durum?.requiredPosition;

  /// Elimdeki oynanabilir kartlar
  List<HandCard> get playableCards {
    final zorunlu = requiredPosition;
    return _el.where((k) {
      if (k.isPlayed) return false;
      if (zorunlu == null) return true;
      return k.position == zorunlu;
    }).toList();
  }

  /// Bu turda oynayabileceğim kart var mı?
  ///
  /// Yoksa "pas geçmek" zorundayım ve turu kaybederim. Zorunlu 1-4-4-2
  /// formasyonunda iki oyuncunun pozisyon dağılımı aynı olduğu için bu
  /// durum normalde oluşmaz; ama kural gereği ele alınıyor.
  bool get mustPass =>
      isMyTurn && requiredPosition != null && playableCards.isEmpty;

  // ------------------------------------------------------------------
  // TAKTİK VE ENERJİ (021_tactics.sql)
  // ------------------------------------------------------------------
  // İstemci sadece SEÇİMİ tutar. Enerjinin yetip yetmediğini, bonusu ve
  // turun sonucunu sunucu belirler. Buradaki "yetiyor mu" kontrolü
  // yalnızca düğmeyi pasif göstermek için.
  MatchTactic _secilenTaktik = MatchTactic.none;

  /// Bir sonraki kartla birlikte gönderilecek taktik
  MatchTactic get selectedTactic {
    // Enerji düştüyse (ör. tur çözüldü) seçim artık geçersiz olabilir
    if (!_secilenTaktik.isAffordable(myEnergy)) return MatchTactic.none;
    return _secilenTaktik;
  }

  int get myEnergy => _durum?.myEnergy ?? 0;
  int get opponentEnergy => _durum?.opponentEnergy ?? 0;
  int get maxEnergy => _durum?.maxEnergy ?? 5;

  /// Taktik seçilebilir mi? (sıra bende, pas zorunlu değil, enerji yetiyor)
  bool canUseTactic(MatchTactic t) =>
      isMyTurn && !isOver && !mustPass && t.isAffordable(myEnergy);

  /// Taktiği seçer; aynı taktiğe tekrar dokunmak seçimi kaldırır.
  void selectTactic(MatchTactic t) {
    if (!t.isNone && !canUseTactic(t)) return;
    _secilenTaktik = (_secilenTaktik == t) ? MatchTactic.none : t;
    safeNotify();
  }

  /// Masadaki (henüz sonuçlanmamış) hamleler
  List<MatchMove> get tableMoves => _gecmis.currentTableMoves;

  /// Rakibin bu turda oynadığı kart
  MatchMove? get opponentTableMove {
    for (final h in tableMoves) {
      if (!h.isMine) return h;
    }
    return null;
  }

  /// Benim bu turda oynadığım kart
  MatchMove? get myTableMove {
    for (final h in tableMoves) {
      if (h.isMine) return h;
    }
    return null;
  }

  /// Son sonuçlanan tur (animasyon için)
  MatchRound? get lastResolvedRound =>
      _gecmis.rounds.isEmpty ? null : _gecmis.rounds.last;

  // ------------------------------------------------------------------
  // ÇATIŞMA SAHNESİ KUYRUĞU
  // ------------------------------------------------------------------
  // Sunucu bir turu sonuçlandırdığında o tur geçmişe eklenir. Daha önce
  // gösterilmemiş her tur için bir çatışma sahnesi KUYRUĞA alınır.
  //
  // NEDEN KUYRUK? İki tur art arda sonuçlanabilir (oyuncu bir an
  // bağlantıyı kaybetti, döndüğünde iki tur ilerlemiş). Tek bir alan
  // olsaydı ilk sahne ikincinin üstüne yazılıp kaybolurdu.
  final Set<int> _gosterilenTurlar = {};
  bool _turlarIsaretlendi = false;
  final List<ClashEvent> _cakismaKuyrugu = [];

  /// Şu an oynatılması gereken çatışma sahnesi (yoksa null)
  ClashEvent? get currentClash =>
      _cakismaKuyrugu.isEmpty ? null : _cakismaKuyrugu.first;

  /// Sahne bitti ya da oyuncu atladı: sıradakine geç
  void finishCurrentClash() {
    if (_cakismaKuyrugu.isEmpty) return;
    _cakismaKuyrugu.removeAt(0);
    safeNotify();
  }

  void _yeniTurlariKuyrugaAl(MatchHistory gecmis) {
    // İLK YÜKLEME: maça geri dönüldüğünde eski turlar tekrar
    // oynatılmasın (7 turu art arda izlemek zorunda kalınırdı).
    if (!_turlarIsaretlendi) {
      _gosterilenTurlar.addAll(gecmis.rounds.map((r) => r.roundNumber));
      _turlarIsaretlendi = true;
      return;
    }

    final yeniler = findNewClashes(
      history: gecmis,
      alreadyShown: _gosterilenTurlar,
      myUserId: myUserId,
    );
    for (final c in yeniler) {
      _gosterilenTurlar.add(c.roundNumber);
      _cakismaKuyrugu.add(c);
    }
  }

  // ------------------------------------------------------------------
  // SAYAÇ
  // ------------------------------------------------------------------
  /// Hamle için kalan süre. Cihaz saatinden BAĞIMSIZ.
  Duration get remainingTime {
    final d = _durum;
    if (d == null || d.isOver) return Duration.zero;

    final son = d.turnDeadline;
    if (son == null) return GameRules.turnDuration;

    // Cihaz saatini sunucu saatine çeviriyoruz
    final sunucuSimdi = DateTime.now().add(_saatFarki);
    final kalan = son.difference(sunucuSimdi);

    return kalan.isNegative ? Duration.zero : kalan;
  }

  int get remainingSeconds => remainingTime.inSeconds;

  /// Süre bitmek üzere mi? (arayüz kırmızıya döner)
  bool get isTimeRunningOut => remainingSeconds <= 10 && !isOver;

  /// Rakibin süresi doldu mu? (AFK toleransı dahil)
  ///
  /// Dolduysa maçı hükmen talep edebiliriz.
  bool get canClaimTimeout {
    final d = _durum;
    if (d == null || d.isOver || d.isMyTurn) return false;

    final son = d.turnDeadline;
    if (son == null) return false;

    final sunucuSimdi = DateTime.now().add(_saatFarki);
    return sunucuSimdi.isAfter(son.add(GameRules.afkGrace));
  }

  // ------------------------------------------------------------------
  // BAŞLATMA
  // ------------------------------------------------------------------
  Future<void> initialize() async {
    setState(ViewState.loading);
    await _tazele(showLoading: true);
    _olaylariDinle();
    _sayaciBaslat();
  }

  void _olaylariDinle() {
    _olayAboneligi?.cancel();
    _olayAboneligi = _socket.events.listen((olay) {
      // Başka bir maçın olayı bizi ilgilendirmez
      if (olay.matchId != matchId) return;
      if (!olay.requiresMatchRefresh) return;

      AppLogger.info('Maç olayı: ${olay.type.name}', tag: 'MAC');
      _gecikmeliTazele();
    });

    // ================================================================
    // BAĞLANTI KOPMASINDAN KURTARMA (FAZ 7'de bulunan hata)
    // ================================================================
    // Bağlantı koptuğu sırada gelen olaylar (ör. rakibin hamlesi)
    // KAYBOLUR; sunucu onları yeniden göndermez. Eskiden bağlantı geri
    // geldiğinde ekran tazelenmiyordu: oyuncu "Sıra rakipte" görüp
    // beklerken aslında sıra ondaydı, süresi dolup hükmen kaybediyordu.
    //
    // Artık bağlantı geri geldiği AN durum yeniden çekiliyor. Kopukken
    // de sayaç her [offlinePollInterval]'da bir REST'ten yokluyor.
    _baglantiAboneligi?.cancel();
    _baglantiAboneligi = _socket.connectionState.listen((bagli) {
      if (!bagli) return;
      AppLogger.info('Bağlantı geri geldi, maç tazeleniyor.', tag: 'MAC');
      _gecikmeliTazele();
    });
  }

  /// Aynı hamle birkaç olay üretebilir; hepsi için ayrı istek atmayalım.
  void _gecikmeliTazele() {
    _tazelemeGecikmesi?.cancel();
    _tazelemeGecikmesi = Timer(
      const Duration(milliseconds: 180),
      () => _tazele(),
    );
  }

  void _sayaciBaslat() {
    _sayacZamanlayici?.cancel();
    _sayacZamanlayici = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isOver) return;

      // Yedek kanal: WebSocket kopuksa olay gelmeyecek, kendimiz yoklayalım
      if (_socket.isConnected) {
        _kopukSaniye = 0;
      } else if (++_kopukSaniye >= offlinePollInterval.inSeconds) {
        _kopukSaniye = 0;
        _tazele();
        return;
      }
      safeNotify();
    });
  }

  // ------------------------------------------------------------------
  // VERİ TAZELEME
  // ------------------------------------------------------------------
  Future<void> _tazele({bool showLoading = false}) async {
    final durumSonucu = await _repository.fetchState(matchId);

    final yeniDurum = durumSonucu.dataOrNull;
    if (yeniDurum == null) {
      final hata = durumSonucu.errorOrNull;
      if (hata != null && _durum == null) setError(hata);
      return;
    }

    // Sunucu saatiyle cihaz saati arasındaki farkı güncelle
    final sunucuSaati = yeniDurum.serverTime;
    if (sunucuSaati != null) {
      _saatFarki = sunucuSaati.difference(DateTime.now());
    }

    _durum = yeniDurum;

    // El ve geçmişi PARALEL çek: iki isteği de başlatıp sonra bekliyoruz,
    // böylece biri diğerini beklemiyor (toplam süre ~tek istek kadar).
    final elIstegi = _repository.fetchHand(matchId);
    final gecmisIstegi = _repository.fetchHistory(matchId);

    final el = (await elIstegi).dataOrNull;
    if (el != null) _el = el;

    final gecmis = (await gecmisIstegi).dataOrNull;
    if (gecmis != null) {
      _gecmis = gecmis;
      _yeniTurlariKuyrugaAl(gecmis);
    }

    if (yeniDurum.isOver && _sonuc == null) {
      await _sonucuGetir();
    }

    if (showLoading) setState(ViewState.idle);
    safeNotify();
  }

  Future<void> _sonucuGetir() async {
    final sonuc = await _repository.fetchResult(matchId);
    final veri = sonuc.dataOrNull;

    if (veri != null) {
      _sonuc = veri;
      // Maç sonrası coin / MMR / koruma hakkı değişti
      final profil = veri.myProfile;
      if (profil != null) {
        // ÖNCE farkı al: güncellemeden sonra eski değer kaybolur
        final once = _session.user;
        if (once != null) {
          _odulFarki = MatchRewardDelta(
            coins: profil.coins - once.coins,
            rating: profil.mmr - once.mmr,
            protectionSlots: profil.protectionSlots - once.protectionSlots,
          );
        }
        await _session.updateUser(profil);
      }
    }
  }

  /// Ekranı elle tazelemek için (bağlantı koptuysa)
  Future<void> refresh() => _tazele();

  // ------------------------------------------------------------------
  // HAMLELER
  // ------------------------------------------------------------------
  /// Kart oynar. Başarılıysa true döner.
  Future<bool> playCard(HandCard kart) async {
    if (!isMyTurn || _hamleGonderiliyor || isOver) return false;

    _hamleGonderiliyor = true;
    safeNotify();

    final sonuc = await _repository.playCard(
      matchId: matchId,
      userCardId: kart.userCardId,
      tactic: selectedTactic,
    );

    _hamleGonderiliyor = false;

    final hata = sonuc.errorOrNull;
    if (hata != null) {
      setError(hata);
      // Sunucu reddettiyse ekran gerçeği yansıtmıyor demektir;
      // doğru durumu yeniden çekelim.
      _gecikmeliTazele();
      return false;
    }

    // Taktik bu kartla kullanıldı; sonraki hamle sıfırdan seçilir
    _secilenTaktik = MatchTactic.none;
    await _tazele();
    return true;
  }

  /// "Bu pozisyonda kartım yok" der ve turu kaybeder.
  /// Sunucu bu iddiayı DOĞRULAR; kartın varsa reddedilirsin.
  Future<bool> pass() async {
    if (!isMyTurn || _hamleGonderiliyor || isOver) return false;

    _hamleGonderiliyor = true;
    safeNotify();

    final sonuc = await _repository.playCard(matchId: matchId);
    _hamleGonderiliyor = false;

    final hata = sonuc.errorOrNull;
    if (hata != null) {
      setError(hata);
      return false;
    }

    await _tazele();
    return true;
  }

  /// Rakip AFK ise maçı hükmen talep eder.
  Future<bool> claimTimeout() async {
    if (!canClaimTimeout) return false;

    final sonuc = await _repository.claimTimeout(matchId);

    final hata = sonuc.errorOrNull;
    if (hata != null) {
      // "Rakibin süresi henüz dolmadı" hatası normaldir (saat farkı
      // yüzünden birkaç yüz milisaniye erken talep etmiş olabiliriz).
      // Kullanıcıyı rahatsız etmeden sessizce tazeleyelim.
      AppLogger.warning('Süre aşımı talebi reddedildi: ${hata.message}',
          tag: 'MAC');
      _gecikmeliTazele();
      return false;
    }

    await _tazele();
    return true;
  }

  /// Teslim ol. Maçı kaybetmiş sayılırsın ve 3 kart cezası uygulanır.
  Future<bool> surrender() async {
    final sonuc = await _repository.surrender(matchId);

    final hata = sonuc.errorOrNull;
    if (hata != null) {
      setError(hata);
      return false;
    }

    await _tazele();
    return true;
  }

  @override
  void dispose() {
    _sayacZamanlayici?.cancel();
    _tazelemeGecikmesi?.cancel();
    _olayAboneligi?.cancel();
    _baglantiAboneligi?.cancel();
    super.dispose();
  }
}

/// Maçın oyuncunun sayaçlarına etkisi (maç sonrası - maç öncesi).
class MatchRewardDelta {
  final int coins;
  final int rating;
  final int protectionSlots;

  const MatchRewardDelta({
    required this.coins,
    required this.rating,
    required this.protectionSlots,
  });
}
