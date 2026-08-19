import 'package:shared_models/shared_models.dart';

import '../../../../core/base/base_view_model.dart';
import '../../../../core/base/view_state.dart';
import '../../domain/repositories/deck_repository.dart';

/// Kadro düzenleme ekranının beyni.
///
/// KİMYA SİSTEMİ GELİNCE NE DEĞİŞTİ?
/// Eskiden kadro "11 kartlık bir küme"ydi; kartların hangi sırada
/// durduğu önemsizdi. Artık her kartın formasyonda bir YERİ var
/// (slot 0-10) ve kimya bu yerleşime göre hesaplanıyor.
///
/// Aynı 11 kart, farklı dizilişlerde farklı kimya verir. Oyuncunun
/// asıl stratejik kararı bu.
///
/// KİMYA NEREDE HESAPLANIYOR?
///   * Burada (yerel)  -> oyuncu kartı sürüklerken ANLIK önizleme
///   * Sunucuda        -> maçın gerçek sonucunu belirleyen değer
///
/// İkisi aynı kuralı uygular ama biri diğerine güvenmez. Bu dosyadaki
/// hesabı değiştiren biri maçın sonucunu değiştiremez.
class DeckViewModel extends BaseViewModel {
  final DeckRepository _repository;

  DeckViewModel(this._repository);

  // ------------------------------------------------------------------
  // DURUM
  // ------------------------------------------------------------------
  List<DeckSummary> _desteler = [];
  List<DeckSummary> get decks => _desteler;

  DeckSummary? _aktifDeste;
  DeckSummary? get activeDeck => _aktifDeste;

  List<InventoryCard> _envanter = [];
  List<InventoryCard> get inventory => _envanter;

  /// Formasyon: slot numarası -> kart
  final Map<int, InventoryCard> _slotlar = {};

  bool _degisiklikVar = false;
  bool get hasUnsavedChanges => _degisiklikVar;

  bool _kaydediliyor = false;
  bool get isSaving => _kaydediliyor;

  String? _kayitMesaji;
  String? get saveMessage => _kayitMesaji;

  /// Sunucudan gelen kimya (kaydedilmiş kadronun gerçek değeri)
  DeckChemistry? _sunucuKimyasi;
  DeckChemistry? get serverChemistry => _sunucuKimyasi;

  // ------------------------------------------------------------------
  // KİMYA (yerel, anlık)
  // ------------------------------------------------------------------
  /// Ekranda gösterilen kimya. Oyuncu kart değiştirdikçe anında güncellenir.
  DeckChemistry get chemistry => DeckChemistry.calculate(
        {for (var s = 0; s < GameRules.squadSize; s++) s: _slotlar[s]},
      );

  /// Bir slottaki kartın kimya puanı
  int chemistryAt(int slot) => chemistry.chemistryAt(slot);

  /// Bir slota bağlı bağlar (çizgileri çizmek için)
  List<ChemistryLink> linksAt(int slot) => chemistry.linksAt(slot);

  /// Tüm bağlar
  List<ChemistryLink> get links => chemistry.links;

  // ------------------------------------------------------------------
  // TÜRETİLMİŞ
  // ------------------------------------------------------------------
  InventoryCard? cardAt(int slot) => _slotlar[slot];

  List<InventoryCard> get selectedCards {
    final liste = <InventoryCard>[];
    for (var s = 0; s < GameRules.squadSize; s++) {
      final k = _slotlar[s];
      if (k != null) liste.add(k);
    }
    return liste;
  }

  int get totalSelected => _slotlar.length;

  int countFor(CardPosition pozisyon) =>
      slotsForPosition(pozisyon).where((s) => _slotlar[s] != null).length;

  bool get isComplete => _slotlar.length == GameRules.squadSize;

  bool get canSave => isComplete && _degisiklikVar && !_kaydediliyor;

  String? get missingMessage {
    final eksikler = <String>[];
    for (final p in CardPosition.values) {
      final eksik = p.requiredCount - countFor(p);
      if (eksik > 0) eksikler.add('$eksik ${p.label.toLowerCase()}');
    }
    return eksikler.isEmpty ? null : 'Eksik: ${eksikler.join(', ')}';
  }

  bool isSelected(String userCardId) =>
      _slotlar.values.any((k) => k.userCardId == userCardId);

  /// Bir slota konabilecek envanter kartları.
  ///
  /// Slotun pozisyonuna uyan, kilitli olmayan ve kadroda bulunmayan
  /// kartlar. Yani listede görünen her kart geçerlidir.
  List<InventoryCard> availableForSlot(int slot) {
    final pozisyon = formationSlotPosition(slot);
    final mevcut = _slotlar[slot];

    final liste = _envanter
        .where((k) =>
            k.position == pozisyon &&
            !k.isLocked &&
            (!isSelected(k.userCardId) ||
                k.userCardId == mevcut?.userCardId))
        .toList();

    liste.sort((a, b) {
      if (a.tier.rank != b.tier.rank) return b.tier.rank.compareTo(a.tier.rank);
      return b.power.compareTo(a.power);
    });
    return liste;
  }

  /// Bir kart bu slota konursa kimya kaç olur? (önizleme)
  ///
  /// Kart seçim ekranında her kartın yanında "+5" gibi göstererek
  /// oyuncunun doğru tercihi yapmasını sağlıyoruz. Kimyayı görmeden
  /// seçim yapmak zorunda kalmak sistemi anlaşılmaz kılardı.
  int chemistryIfPlaced(int slot, InventoryCard aday) {
    final deneme = <int, ChemistrySource?>{
      for (var s = 0; s < GameRules.squadSize; s++) s: _slotlar[s],
    };
    deneme[slot] = aday;

    return DeckChemistry.calculate(deneme).chemistryAt(slot);
  }

  /// Kart bu slota konursa TAKIM kimyası kaç olur?
  int teamChemistryIfPlaced(int slot, InventoryCard aday) {
    final deneme = <int, ChemistrySource?>{
      for (var s = 0; s < GameRules.squadSize; s++) s: _slotlar[s],
    };
    deneme[slot] = aday;

    return DeckChemistry.calculate(deneme).total;
  }

  int get averagePower {
    final kartlar = selectedCards;
    if (kartlar.isEmpty) return 0;
    return (kartlar.fold<int>(0, (t, k) => t + k.power) / kartlar.length)
        .round();
  }

  /// Kimya bonusu dahil ortalama güç.
  /// Maçta kartlar bu güçle oynanır.
  int get averageEffectivePower {
    final kartlar = selectedCards;
    if (kartlar.isEmpty) return 0;

    var toplam = 0;
    for (var s = 0; s < GameRules.squadSize; s++) {
      final k = _slotlar[s];
      if (k != null) toplam += k.power + chemistryAt(s);
    }
    return (toplam / kartlar.length).round();
  }

  // ------------------------------------------------------------------
  // YÜKLEME
  // ------------------------------------------------------------------
  Future<void> load() async {
    setState(ViewState.loading);

    final desteler = await _repository.fetchDecks();
    final liste = desteler.dataOrNull;

    if (liste == null) {
      setError(desteler.errorOrNull!);
      return;
    }

    _desteler = liste;
    final aktif = liste.where((d) => d.isActive);
    _aktifDeste = aktif.isNotEmpty ? aktif.first : liste.firstOrNull;

    if (_aktifDeste == null) {
      final yeni = await _repository.createDeck('Kadrom');
      _aktifDeste = yeni.dataOrNull;
      if (_aktifDeste == null) {
        setError(yeni.errorOrNull!);
        return;
      }
      _desteler = [..._desteler, _aktifDeste!];
    }

    // Envanter ve kadro dizilişini paralel çek
    final envanterIstegi = _repository.fetchInventory();
    final slotIstegi = _repository.fetchDeckSlots(_aktifDeste!.id);

    final envanter = (await envanterIstegi).dataOrNull;
    final slotlar = (await slotIstegi).dataOrNull;

    if (envanter != null) _envanter = envanter;

    _slotlar
      ..clear()
      ..addAll(slotlar ?? const {});

    _degisiklikVar = false;
    _kayitMesaji = null;

    setState(ViewState.idle);
    safeNotify();

    // Sunucudaki kimyayı arka planda çek (yerel hesabı doğrulamak için)
    unawaited(_sunucuKimyasiniGetir());
  }

  Future<void> _sunucuKimyasiniGetir() async {
    final deste = _aktifDeste;
    if (deste == null) return;

    final sonuc = await _repository.fetchChemistry(deste.id);
    _sunucuKimyasi = sonuc.dataOrNull;
    safeNotify();
  }

  // ------------------------------------------------------------------
  // SLOT İŞLEMLERİ
  // ------------------------------------------------------------------
  /// Bir slota kart yerleştirir.
  ///
  /// Kart başka bir slotta duruyorsa oradan alınır (yer değiştirme).
  bool placeCard(int slot, InventoryCard kart) {
    if (kart.isLocked) return false;
    if (formationSlotPosition(slot) != kart.position) return false;

    // Kart zaten başka bir slottaysa oradan çıkar
    int? eskiSlot;
    _slotlar.forEach((s, k) {
      if (k.userCardId == kart.userCardId) eskiSlot = s;
    });

    if (eskiSlot != null && eskiSlot != slot) {
      // Yer değiştirme: hedefteki kart eski slota gitsin
      final hedeftekiKart = _slotlar[slot];
      if (hedeftekiKart != null) {
        _slotlar[eskiSlot!] = hedeftekiKart;
      } else {
        _slotlar.remove(eskiSlot);
      }
    }

    _slotlar[slot] = kart;
    _degisiklikVar = true;
    _kayitMesaji = null;
    safeNotify();
    return true;
  }

  void removeAt(int slot) {
    if (_slotlar.remove(slot) == null) return;
    _degisiklikVar = true;
    _kayitMesaji = null;
    safeNotify();
  }

  /// İki slottaki kartların yerini değiştirir.
  ///
  /// Aynı pozisyondaki kartları (örn. iki forvet) yer değiştirerek
  /// kimyayı artırmak, oyuncunun en sık yapacağı işlem.
  void swapSlots(int a, int b) {
    if (a == b) return;
    if (formationSlotPosition(a) != formationSlotPosition(b)) return;
    if (_slotlar[a] == null && _slotlar[b] == null) return;

    _yerDegistir(a, b);

    _degisiklikVar = true;
    _kayitMesaji = null;
    safeNotify();
  }

  // ------------------------------------------------------------------
  // OTOMATİK DOLDURMA
  // ------------------------------------------------------------------
  /// Boş slotları en güçlü kartlarla doldurur (kimyaya bakmaz).
  void autoFillBest() {
    for (var slot = 0; slot < GameRules.squadSize; slot++) {
      if (_slotlar[slot] != null) continue;

      final adaylar = availableForSlot(slot);
      if (adaylar.isEmpty) continue;

      _slotlar[slot] = adaylar.first;
    }

    _degisiklikVar = true;
    _kayitMesaji = null;
    safeNotify();
  }

  // ------------------------------------------------------------------
  // KİMYA ODAKLI DİZİLİM
  // ------------------------------------------------------------------

  /// Kadronun MAÇTAKİ toplam gücü.
  ///
  /// Her kart masaya `güç + kimya` ile çıktığı için, kadronun gerçek
  /// değeri bu toplamdır. Şu eşitlik geçerli:
  ///
  ///   toplam etkin güç = toplam güç + 2 × takım kimyası
  ///
  /// Çünkü her bağ, puanını bağladığı İKİ karta birden ekler.
  /// Bu yüzden 1 takım kimyası puanı = 2 güç puanı eder; otomatik
  /// dizilim bu dönüşüm oranını kullanarak karar veriyor.
  int _toplamEtkinGuc() {
    final kimya = chemistry;
    var toplam = 0;
    for (var s = 0; s < GameRules.squadSize; s++) {
      final k = _slotlar[s];
      if (k != null) toplam += k.power + kimya.chemistryAt(s);
    }
    return toplam;
  }

  /// KİMYAYA GÖRE otomatik dizilim.
  ///
  /// İKİ FARKLI BAŞLANGIÇTAN TIRMANIP İYİSİNİ SEÇİYOR.
  ///
  /// Neden tek başlangıç yetmiyor? "Tepe tırmanışı" her adımda tek bir
  /// değişiklik dener ve sadece durumu iyileştiren değişiklikleri kabul
  /// eder. Ama kimya kurmak için en az İKİ kartı birden değiştirmek
  /// gerekir: tek başına uyumlu bir kart koymak, bağlanacağı kimse
  /// olmadığı için sadece güç kaybettirir. Algoritma bu yüzden güçlü
  /// ama kimyasız bir kadroda "yerel optimum"a saplanıp kalıyordu.
  ///
  /// Çözüm: iki aday üretip karşılaştırmak.
  ///   A) Güçlü kartlarla başla, iyileştir
  ///   B) Uyumlu kartlarla başla, iyileştir
  ///
  /// Hangisi daha yüksek etkin güç veriyorsa o kazanır. Böylece
  /// kimyanın işe yaradığı durumda kimya, yaramadığı durumda güç
  /// tercih ediliyor — karar oyuncuya değil hesaba bırakılıyor.
  void autoFillByChemistry() {
    // ---- ADAY A: güç öncelikli ----
    _gucleDoldur();
    _iyilestir();
    final adayA = Map<int, InventoryCard>.from(_slotlar);
    final puanA = _toplamEtkinGuc();

    // ---- ADAY B: kimya öncelikli ----
    _kimyaGrubuylaDoldur();
    _iyilestir();
    final puanB = _toplamEtkinGuc();

    // Kazananı uygula
    if (puanA > puanB) {
      _slotlar
        ..clear()
        ..addAll(adayA);
    }

    _degisiklikVar = true;
    _kayitMesaji = null;
    safeNotify();
  }

  /// Boş slotları en güçlü kartlarla doldurur (bildirim göndermeden)
  void _gucleDoldur() {
    _slotlar.clear();
    for (var slot = 0; slot < GameRules.squadSize; slot++) {
      final adaylar = availableForSlot(slot);
      if (adaylar.isNotEmpty) _slotlar[slot] = adaylar.first;
    }
  }

  /// Kadroyu, envanterde EN ÇOK TEKRAR EDEN kimya kimliği etrafında kurar.
  ///
  /// Örnek: envanterinde 7 tane "Anadolu SK" kartı varsa, kadroyu onların
  /// etrafında toplamak en yüksek kimyayı verir. Bu kartlar aynı kulüpten
  /// olduğu için aralarındaki her bağ +2 (yeşil) olur.
  ///
  /// Kulüp bulunamazsa lige, o da olmazsa uyruğa bakılır: kulüp +2,
  /// lig ve uyruk +1 verdiği için öncelik sırası budur.
  void _kimyaGrubuylaDoldur() {
    _slotlar.clear();

    final uygunKartlar = _envanter.where((k) => !k.isLocked);

    // Her kimlik değerinin kaç kartta geçtiğini say
    final kulupSayim = <String, int>{};
    final ligSayim = <String, int>{};
    final ulkeSayim = <String, int>{};

    for (final k in uygunKartlar) {
      if (k.club != null) kulupSayim[k.club!] = (kulupSayim[k.club!] ?? 0) + 1;
      if (k.league != null) {
        ligSayim[k.league!] = (ligSayim[k.league!] ?? 0) + 1;
      }
      if (k.nationality != null) {
        ulkeSayim[k.nationality!] = (ulkeSayim[k.nationality!] ?? 0) + 1;
      }
    }

    String? enCok(Map<String, int> sayim) {
      if (sayim.isEmpty) return null;
      var enIyi = sayim.entries.first;
      for (final e in sayim.entries) {
        if (e.value > enIyi.value) enIyi = e;
      }
      return enIyi.value >= 2 ? enIyi.key : null;
    }

    final hedefKulup = enCok(kulupSayim);
    final hedefLig = enCok(ligSayim);
    final hedefUlke = enCok(ulkeSayim);

    /// Kartın hedef kimliğe ne kadar uyduğu (yüksek = daha uyumlu)
    int uyumPuani(InventoryCard k) {
      if (hedefKulup != null && k.club == hedefKulup) return 3;
      if (hedefLig != null && k.league == hedefLig) return 2;
      if (hedefUlke != null && k.nationality == hedefUlke) return 1;
      return 0;
    }

    for (var slot = 0; slot < GameRules.squadSize; slot++) {
      final adaylar = availableForSlot(slot);
      if (adaylar.isEmpty) continue;

      // Önce uyum, eşitlikte güç
      final sirali = [...adaylar]..sort((a, b) {
          final fark = uyumPuani(b).compareTo(uyumPuani(a));
          return fark != 0 ? fark : b.power.compareTo(a.power);
        });

      _slotlar[slot] = sirali.first;
    }
  }

  /// TEPE TIRMANIŞI: kadroyu küçük adımlarla iyileştirir.
  ///
  /// İki tür değişiklik dener:
  ///   a) Bir slottaki kartı yedekten biriyle değiştirmek
  ///   b) Aynı pozisyondaki iki kartın yerini değiştirmek
  ///
  /// (b) adımı özellikle değerli: elindeki kartları hiç değiştirmeden,
  /// SADECE dizilişi düzelterek kimya kazandırıyor.
  void _iyilestir() {
    const enFazlaTur = 20;
    var tur = 0;
    var iyilesmeVar = true;

    while (iyilesmeVar && tur < enFazlaTur) {
      iyilesmeVar = false;
      tur++;

      // ---- a) Yedekten değiştirme ----
      for (var slot = 0; slot < GameRules.squadSize; slot++) {
        final oncekiPuan = _toplamEtkinGuc();
        final mevcut = _slotlar[slot];

        InventoryCard? enIyiAday;
        var enIyiPuan = oncekiPuan;

        for (final aday in availableForSlot(slot)) {
          if (aday.userCardId == mevcut?.userCardId) continue;

          _slotlar[slot] = aday;
          final puan = _toplamEtkinGuc();

          if (puan > enIyiPuan) {
            enIyiPuan = puan;
            enIyiAday = aday;
          }
        }

        // Denemeleri geri al
        if (mevcut != null) {
          _slotlar[slot] = mevcut;
        } else {
          _slotlar.remove(slot);
        }

        if (enIyiAday != null) {
          _slotlar[slot] = enIyiAday;
          iyilesmeVar = true;
        }
      }

      // ---- b) Aynı pozisyondaki kartların yerini değiştirme ----
      for (final pozisyon in CardPosition.values) {
        final slotlar = slotsForPosition(pozisyon);

        for (var i = 0; i < slotlar.length; i++) {
          for (var j = i + 1; j < slotlar.length; j++) {
            final oncekiPuan = _toplamEtkinGuc();

            _yerDegistir(slotlar[i], slotlar[j]);

            if (_toplamEtkinGuc() > oncekiPuan) {
              iyilesmeVar = true;
            } else {
              _yerDegistir(slotlar[i], slotlar[j]);
            }
          }
        }
      }
    }
  }

  /// İki slotun içeriğini takas eder (bildirim göndermeden).
  /// Otomatik dizilim yüzlerce deneme yaptığı için her denemede
  /// ekranı yeniden çizmek israf olurdu.
  void _yerDegistir(int a, int b) {
    final kartA = _slotlar[a];
    final kartB = _slotlar[b];

    if (kartB == null) {
      _slotlar.remove(a);
    } else {
      _slotlar[a] = kartB;
    }

    if (kartA == null) {
      _slotlar.remove(b);
    } else {
      _slotlar[b] = kartA;
    }
  }

  void clearAll() {
    _slotlar.clear();
    _degisiklikVar = true;
    _kayitMesaji = null;
    safeNotify();
  }

  // ------------------------------------------------------------------
  // KAYDETME
  // ------------------------------------------------------------------
  Future<bool> save() async {
    final deste = _aktifDeste;
    if (deste == null || !isComplete) return false;

    _kaydediliyor = true;
    _kayitMesaji = null;
    safeNotify();

    // SIRA ÖNEMLİ: sunucu listenin sırasından slot numarasını çıkarıyor.
    final sirali = <String>[
      for (var s = 0; s < GameRules.squadSize; s++) _slotlar[s]!.userCardId,
    ];

    final sonuc = await _repository.saveDeck(
      deckId: deste.id,
      userCardIds: sirali,
    );

    _kaydediliyor = false;

    final hata = sonuc.errorOrNull;
    if (hata != null) {
      setError(hata);
      safeNotify();
      return false;
    }

    final dogrulama = sonuc.dataOrNull!;

    if (!dogrulama.isValid) {
      _kayitMesaji = dogrulama.message;
      safeNotify();
      return false;
    }

    _degisiklikVar = false;
    _kayitMesaji = 'Kadro kaydedildi';
    safeNotify();

    // Sunucudaki kimyayı tazele: yerel hesapla uyuşmalı
    unawaited(_sunucuKimyasiniGetir());
    return true;
  }
}

/// Sonucu beklemeden çalıştır
void unawaited(Future<void> future) {
  future.ignore();
}
