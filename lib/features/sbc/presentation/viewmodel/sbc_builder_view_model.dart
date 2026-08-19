import 'package:shared_models/shared_models.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../domain/repositories/sbc_repository.dart';

/// Gorev kadrosu kurma ekraninin beyni.
///
/// KADRO EKRANINDAN FARKI NE?
/// Kadro ekraninda kartlar SENDE KALIR; burada GONDERINCE SILINIR.
/// Bu yuzden iki onemli fark var:
///
///   1. Kadrondaki kartlar burada SECILEMEZ. Yanlislikla oynayacagin
///      kadroyu eritip maca giremez hale gelmeni engelliyor.
///      (Sunucu da ayni kontrolu yapiyor.)
///
///   2. Sartlar oyuncu kart yerlestirdikce ANLIK degerlendiriliyor.
///      "Gonder"e basip reddedilmek kotu bir deneyim olurdu.
class SbcBuilderViewModel extends BaseViewModel {
  final SbcRepository _repository;
  final SbcChallenge challenge;

  SbcBuilderViewModel(this._repository, {required this.challenge});

  // ------------------------------------------------------------------
  // DURUM
  // ------------------------------------------------------------------
  List<InventoryCard> _envanter = [];
  List<InventoryCard> get inventory => _envanter;

  /// Formasyon: slot -> kart
  final Map<int, InventoryCard> _slotlar = {};

  bool _gonderiliyor = false;
  bool get isSubmitting => _gonderiliyor;

  SbcSubmitResult? _sonuc;
  SbcSubmitResult? get result => _sonuc;

  // ------------------------------------------------------------------
  // ANLIK DEGERLENDIRME
  // ------------------------------------------------------------------
  /// Sartlarin o anki durumu. Kart yerlestirildikce guncellenir.
  SbcEvaluation get evaluation => SbcEvaluation.calculate(
        requirements: challenge.requirements,
        slots: {for (var s = 0; s < GameRules.squadSize; s++) s: _slotlar[s]},
      );

  DeckChemistry get chemistry => DeckChemistry.calculate(
        {for (var s = 0; s < GameRules.squadSize; s++) s: _slotlar[s]},
      );

  InventoryCard? cardAt(int slot) => _slotlar[slot];

  int get totalSelected => _slotlar.length;

  bool get isComplete => _slotlar.length == GameRules.squadSize;

  bool get canSubmit =>
      isComplete && evaluation.isValid && !_gonderiliyor;

  bool isSelected(String userCardId) =>
      _slotlar.values.any((k) => k.userCardId == userCardId);

  /// Bu slota konabilecek kartlar.
  ///
  /// Kadroda olan ve macta kilitli kartlar LISTEDE GORUNMEZ; sunucu
  /// zaten reddederdi, oyuncuyu bosuna ugrastirmayalim.
  List<InventoryCard> availableForSlot(int slot) {
    final pozisyon = formationSlotPosition(slot);
    final mevcut = _slotlar[slot];

    final liste = _envanter
        .where((k) =>
            k.position == pozisyon &&
            !k.isLocked &&
            !k.inDeck &&
            (!isSelected(k.userCardId) || k.userCardId == mevcut?.userCardId))
        .toList();

    // En dusuk guclu kartlar ustte: gorevin amaci zaten
    // "kullanmadigin kartlari eritmek".
    liste.sort((a, b) {
      if (a.tier.rank != b.tier.rank) return a.tier.rank.compareTo(b.tier.rank);
      return a.power.compareTo(b.power);
    });
    return liste;
  }

  /// Bir kart bu slota konursa kimya kac olur?
  int chemistryIfPlaced(int slot, InventoryCard aday) {
    final deneme = <int, ChemistrySource?>{
      for (var s = 0; s < GameRules.squadSize; s++) s: _slotlar[s],
    };
    deneme[slot] = aday;
    return DeckChemistry.calculate(deneme).chemistryAt(slot);
  }

  /// Eritilecek kartlarin toplam degeri (oyuncuya ne kaybettigini gostermek icin)
  int get burnValue =>
      _slotlar.values.fold<int>(0, (t, k) => t + k.power);

  // ------------------------------------------------------------------
  // YUKLEME
  // ------------------------------------------------------------------
  Future<void> load() async {
    final envanter = await run(
      () => _repository.fetchInventory(),
      loadingState: ViewState.loading,
    );

    if (envanter != null) {
      _envanter = envanter;
      safeNotify();
    }
  }

  // ------------------------------------------------------------------
  // SLOT ISLEMLERI
  // ------------------------------------------------------------------
  bool placeCard(int slot, InventoryCard kart) {
    if (kart.isLocked || kart.inDeck) return false;
    if (formationSlotPosition(slot) != kart.position) return false;

    // Kart baska slottaysa oradan al
    int? eskiSlot;
    _slotlar.forEach((s, k) {
      if (k.userCardId == kart.userCardId) eskiSlot = s;
    });

    if (eskiSlot != null && eskiSlot != slot) {
      final hedefteki = _slotlar[slot];
      if (hedefteki != null) {
        _slotlar[eskiSlot!] = hedefteki;
      } else {
        _slotlar.remove(eskiSlot);
      }
    }

    _slotlar[slot] = kart;
    safeNotify();
    return true;
  }

  void removeAt(int slot) {
    if (_slotlar.remove(slot) == null) return;
    safeNotify();
  }

  void clearAll() {
    _slotlar.clear();
    safeNotify();
  }

  /// Bos slotlari uygun kartlarla doldurur.
  ///
  /// Sartlari GARANTI ETMEZ; sadece hizli bir baslangic verir.
  /// Oyuncu sonra kimya ve seviye sartlarina gore ince ayar yapar.
  void autoFill() {
    for (var slot = 0; slot < GameRules.squadSize; slot++) {
      if (_slotlar[slot] != null) continue;

      final adaylar = availableForSlot(slot);
      if (adaylar.isEmpty) continue;

      _slotlar[slot] = adaylar.first;
    }
    safeNotify();
  }

  /// Kimyayi artiracak sekilde otomatik doldurur.
  ///
  /// Cogu gorevde kimya sarti oldugu icin en cok kullanilan buton bu.
  /// Tepe tirmanisi ile calisir: once doldur, sonra tek tek degisiklik
  /// deneyerek kimyayi yukselt.
  void autoFillByChemistry() {
    autoFill();

    const enFazlaTur = 15;
    var tur = 0;
    var iyilesme = true;

    while (iyilesme && tur < enFazlaTur) {
      iyilesme = false;
      tur++;

      for (var slot = 0; slot < GameRules.squadSize; slot++) {
        final oncekiKimya = chemistry.total;
        final mevcut = _slotlar[slot];

        InventoryCard? enIyi;
        var enIyiKimya = oncekiKimya;

        for (final aday in availableForSlot(slot)) {
          if (aday.userCardId == mevcut?.userCardId) continue;

          _slotlar[slot] = aday;
          if (chemistry.total > enIyiKimya) {
            enIyiKimya = chemistry.total;
            enIyi = aday;
          }
        }

        if (mevcut != null) {
          _slotlar[slot] = mevcut;
        } else {
          _slotlar.remove(slot);
        }

        if (enIyi != null) {
          _slotlar[slot] = enIyi;
          iyilesme = true;
        }
      }
    }

    safeNotify();
  }

  // ------------------------------------------------------------------
  // GONDERME
  // ------------------------------------------------------------------
  /// Kartlari eritir ve odulu alir.
  ///
  /// GERI ALINAMAZ. Arayuz bu cagriyi yapmadan once onay almali.
  Future<bool> submit() async {
    if (!isComplete) return false;

    _gonderiliyor = true;
    safeNotify();

    final sirali = <String>[
      for (var s = 0; s < GameRules.squadSize; s++) _slotlar[s]!.userCardId,
    ];

    final sonuc = await _repository.submit(
      challengeId: challenge.id,
      userCardIds: sirali,
    );

    _gonderiliyor = false;

    final hata = sonuc.errorOrNull;
    if (hata != null) {
      setError(hata);
      safeNotify();
      return false;
    }

    _sonuc = sonuc.dataOrNull;
    _slotlar.clear();
    safeNotify();
    return true;
  }

  void clearResult() {
    _sonuc = null;
    safeNotify();
  }
}
