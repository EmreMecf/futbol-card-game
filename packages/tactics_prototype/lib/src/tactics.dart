/// TAKTİK KURALLARI — PROTOTİP (MD bölüm 7, FAZ 5)
///
/// ===================================================================
/// BU KOD GERÇEK MAÇLARI ETKİLEMİYOR
/// ===================================================================
/// Ne Flutter uygulaması ne Dart sunucusu bu paketi kullanıyor.
/// Gerçek maçların kuralları hâlâ PostgreSQL'deki `_resolve_round()`
/// ve `compare_cards()` fonksiyonlarında ve DEĞİŞMEDİ. Burası, taktik
/// fikrinin dengeli olup olmadığını binlerce simüle maçla ölçmek için
/// ayrı bir laboratuvar. Oyuna alınıp alınmayacağına kullanıcı karar
/// verecek.
///
/// ===================================================================
/// TASARIM: TAŞ - KÂĞIT - MAKAS
/// ===================================================================
/// Her taktiğin yendiği bir taktik ve yenildiği bir taktik var:
///
///   YÜKSEK PRES     -> Savunma Duvarı'nı kırar (duvarın bonusu iptal)
///   SAVUNMA DUVARI  -> Kontra Atak'ı keser   (kontranın bonusu iptal)
///   KONTRA ATAK     -> Yüksek Pres'i cezalandırır (büyük bonus)
///
/// Hiçbir taktik "her zaman iyi" değil (MD: "bütün taktiklerin daima
/// pozitif bonus vermesi gibi dengesiz sistemlerden kaçın"):
///   * Pres en pahalısı ve Kontra'ya yakalanırsa hiçbir şey kazandırmaz
///   * Kontra tek başına zayıf; sadece rakip pres yaparsa parlar
///   * Duvar sadece SAVUNURKEN (turu rakip açtığında) güçlü
///
/// ===================================================================
/// BİLGİ MODELİ (stratejinin kaynağı)
/// ===================================================================
/// Turu açan oyuncu kartını ve taktiğini GİZLİ seçer. Cevap veren,
/// rakibin KARTINI görür (gerçek oyundaki gibi) ama TAKTİĞİNİ görmez.
/// İki taktik tur çözülürken aynı anda açılır. Enerji miktarları iki
/// tarafa da açık; "rakibimin 3 enerjisi var, pres yapabilir" diye
/// düşünmek oyunun derinliği.
///
/// ===================================================================
/// TEMEL KURALLAR KORUNUYOR
/// ===================================================================
///   * Aynı mevki zorunluluğu: simülasyonda da geçerli
///   * LEGEND KURALI MUTLAK: Taktik bonusu, Legend olmayan bir kartın
///     Legend'ı yenmesini SAĞLAYAMAZ. Bonus sadece güç karşılaştırmasına
///     eklenir; Legend üstünlüğü ondan önce uygulanır (compare_cards ile
///     aynı sıra). Testle kilitli.
///   * Beraberlik, pot, sıra kuralları değişmedi
library;

/// Taktikler. [none] = taktik kullanmamak (enerji harcanmaz).
enum Tactic {
  none('Taktik yok', '—'),
  highPress('Yüksek Pres', 'pres'),
  counterAttack('Kontra Atak', 'kontra'),
  defensiveWall('Savunma Duvarı', 'duvar');

  final String label;
  final String shortCode;

  const Tactic(this.label, this.shortCode);

  /// Bu taktiğin kırdığı taktik (taş-kâğıt-makas)
  Tactic? get beats => switch (this) {
        Tactic.highPress => Tactic.defensiveWall,
        Tactic.defensiveWall => Tactic.counterAttack,
        Tactic.counterAttack => Tactic.highPress,
        Tactic.none => null,
      };

  /// Bu taktiği kıran taktik
  Tactic? get beatenBy => switch (this) {
        Tactic.highPress => Tactic.counterAttack,
        Tactic.defensiveWall => Tactic.highPress,
        Tactic.counterAttack => Tactic.defensiveWall,
        Tactic.none => null,
      };
}

// ====================================================================
// KURAL SÜRÜMÜ 3 ADAYI: ÖZELLİK → TAKTİK ÇARPANI (oyunda YOK)
// ====================================================================
/// Kartın "oyuncu tipi": ilgili özelliklerin kartın KENDİ GÜCÜNDEN
/// sapması.
///
/// NEDEN SAPMA, ÖZELLİĞİN KENDİSİ DEĞİL?
/// Oyunda özellik = güç + mevki sapması ± 4 (016_card_attributes.sql).
/// Bonus özelliğin kendisine bağlansaydı güçlü kart her zaman daha
/// büyük bonus alır ve güç farkı BÜYÜRDÜ. Sapma ise kartın ne kadar
/// güçlü olduğunu değil, NE TÜR bir oyuncu olduğunu ölçer.
class TacticAffinity {
  /// (fizik + hızlanma) / 2 − güç
  final int press;

  /// (hız + dribling) / 2 − güç
  final int counter;

  /// (defans + fizik) / 2 − güç
  final int wall;

  const TacticAffinity(this.press, this.counter, this.wall);

  static const neutral = TacticAffinity(0, 0, 0);

  int forTactic(Tactic t) => switch (t) {
        Tactic.highPress => press,
        Tactic.counterAttack => counter,
        Tactic.defensiveWall => wall,
        Tactic.none => 0,
      };

  @override
  String toString() => 'P$press/K$counter/D$wall';
}

/// Taktik bonusunun oyuncu tipine göre ölçeklenmesi.
///
/// çarpan = 1 + sapma × [perPoint], [-cap, +cap] aralığına kırpılır.
/// Varsayılan: sapma başına %2,5, en fazla ±%20. Yani en uygun oyuncu
/// bile bonusu en fazla %20 artırır; taktik yoksa özellik HİÇBİR ŞEY
/// yapmaz (sınırsız güç yok).
class AttributeScaling {
  final double perPoint;
  final double cap;

  const AttributeScaling({this.perPoint = 0.025, this.cap = 0.20});

  double multiplier(int deviation) =>
      1 + (deviation * perPoint).clamp(-cap, cap);

  int scale(int baseBonus, int deviation) =>
      baseBonus <= 0 ? 0 : (baseBonus * multiplier(deviation)).round();
}

/// Dengeleme sayıları. Hepsi tek yerde, simülasyonla ayarlanıyor.
///
/// [TacticRules.balanced] simülasyon raporundaki hedefleri sağlayan
/// değerler (bkz. RAPOR.md). Değiştirilirse `dart run bin/simulate.dart`
/// tekrar çalıştırılıp rapor yenilenmeli.
class TacticRules {
  // ---- ENERJİ ----
  final int startEnergy;
  final int energyPerRound;
  final int maxEnergy;

  // ---- MALİYET ----
  final int pressCost;
  final int counterCost;
  final int wallCost;

  // ---- BONUS ----
  /// Pres'in düz bonusu
  final int pressBonus;

  /// Kontra'nın düz bonusu (rakip pres yapmadıysa)
  final int counterBaseBonus;

  /// Kontra'nın rakip PRES yaptığında aldığı bonus
  final int counterVsPressBonus;

  /// Duvar'ın savunurken (cevap veren taraf) bonusu
  final int wallDefendBonus;

  /// Duvar'ın turu açarken bonusu (bilerek düşük)
  final int wallLeadBonus;

  /// null = canlı kurallar (sürüm 2). Doluysa sürüm 3 adayı:
  /// bonus oyuncu tipine göre ölçeklenir.
  final AttributeScaling? attributeScaling;

  const TacticRules({
    required this.startEnergy,
    required this.energyPerRound,
    required this.maxEnergy,
    required this.pressCost,
    required this.counterCost,
    required this.wallCost,
    required this.pressBonus,
    required this.counterBaseBonus,
    required this.counterVsPressBonus,
    required this.wallDefendBonus,
    required this.wallLeadBonus,
    this.attributeScaling,
  });

  /// Simülasyonla ayarlanmış değerler (RAPOR.md'deki hedefleri sağlar)
  ///
  /// AYAR GEÇMİŞİ (tohum 7, çift başına 2500 maç):
  ///   İlk tahmin (pres +6, kontra +1/+9, duvar +4/+1):
  ///     bütün hedefler tuttu AMA turu çevirme oranı %5,2 — alt sınıra
  ///     yapışık. Taktikler neredeyse süs; oyuncu "enerji harcadım,
  ///     hiçbir şey olmadı" der.
  ///   Bonuslar büyütüldükçe çevirme %10'a çıkıyor AMA taktik
  ///   kullanmayan oyuncu eziliyor ("hep pres" taktiksizi %75 yeniyor,
  ///   beceri hedefi aşılıyor).
  ///   Pres maliyeti 4: pres duvara karşı yazı-turaya düşüyor (%52),
  ///   taş-kâğıt-makas üçgeni bozuluyor.
  ///   SEÇİLEN (aşağıda): çevirme ~%7,5, beceri ~%67, üçgenin üç
  ///   kenarı da %56-66 — bütün hedeflerin içinde, payla.
  static const balanced = TacticRules(
    startEnergy: 2,
    energyPerRound: 1,
    maxEnergy: 5,
    pressCost: 3,
    counterCost: 2,
    wallCost: 1,
    pressBonus: 9,
    counterBaseBonus: 2,
    counterVsPressBonus: 13,
    wallDefendBonus: 6,
    wallLeadBonus: 2,
  );

  /// KURAL SÜRÜMÜ 3 ADAYI (oyunda YOK): [balanced] + özellik çarpanı.
  /// Sayılar aynı; sadece bonus oyuncu tipine göre ±%20 ölçeklenir.
  static const v3Attributes = TacticRules(
    startEnergy: 2,
    energyPerRound: 1,
    maxEnergy: 5,
    pressCost: 3,
    counterCost: 2,
    wallCost: 1,
    pressBonus: 9,
    counterBaseBonus: 2,
    counterVsPressBonus: 13,
    wallDefendBonus: 6,
    wallLeadBonus: 2,
    attributeScaling: AttributeScaling(),
  );

  int costOf(Tactic t) => switch (t) {
        Tactic.none => 0,
        Tactic.highPress => pressCost,
        Tactic.counterAttack => counterCost,
        Tactic.defensiveWall => wallCost,
      };

  /// [mine] taktiğinin, rakip [theirs] kullanırken bana verdiği bonus.
  ///
  /// [iAmLead] turu ben mi açtım? (Duvar sadece savunurken güçlü)
  ///
  /// [affinity] kartın oyuncu tipi; sadece [attributeScaling] doluysa
  /// (sürüm 3 adayı) kullanılır.
  int bonus(
    Tactic mine,
    Tactic theirs, {
    required bool iAmLead,
    TacticAffinity affinity = TacticAffinity.neutral,
  }) {
    final temel = _temelBonus(mine, theirs, iAmLead: iAmLead);
    final olcek = attributeScaling;
    if (olcek == null) return temel;
    return olcek.scale(temel, affinity.forTactic(mine));
  }

  int _temelBonus(Tactic mine, Tactic theirs, {required bool iAmLead}) {
    return switch (mine) {
      Tactic.none => 0,

      // Kontra'ya yakalanan pres hiçbir şey kazandırmaz
      Tactic.highPress => theirs == Tactic.counterAttack ? 0 : pressBonus,

      // Duvar kontrayı keser; pres yapan rakibi ise ağır cezalandırır
      Tactic.counterAttack => switch (theirs) {
          Tactic.defensiveWall => 0,
          Tactic.highPress => counterVsPressBonus,
          _ => counterBaseBonus,
        },

      // Pres duvarı kırar; duvar sadece SAVUNURKEN güçlü
      Tactic.defensiveWall => theirs == Tactic.highPress
          ? 0
          : (iAmLead ? wallLeadBonus : wallDefendBonus),
    };
  }
}

/// Simülasyondaki tek bir kart
class SimCard {
  /// 'GK' | 'DEF' | 'MID' | 'FWD'
  final String position;

  /// Legend mi? (Legend kuralı için yeterli bilgi)
  final bool isLegend;

  /// Güç + kimya (gerçek oyunda masaya çıkan değer)
  final int effectivePower;

  /// Oyuncu tipi (sadece sürüm 3 adayında kullanılır)
  final TacticAffinity affinity;

  const SimCard(
    this.position,
    this.effectivePower, {
    this.isLegend = false,
    this.affinity = TacticAffinity.neutral,
  });

  @override
  String toString() =>
      '$position:$effectivePower${isLegend ? 'L' : ''}';
}

/// Bir turun sonucu: 1 = turu açan kazandı, -1 = cevap veren, 0 = berabere
///
/// SIRA, sunucudaki `compare_cards()` ile birebir aynı:
///   1. Legend kuralı (mutlak, taktik bunu değiştiremez)
///   2. Güç karşılaştırması — taktik bonusu SADECE burada eklenir
int resolveRound({
  required SimCard lead,
  required SimCard response,
  Tactic leadTactic = Tactic.none,
  Tactic responseTactic = Tactic.none,
  TacticRules rules = TacticRules.balanced,
}) {
  // 1) Legend kuralı
  if (lead.isLegend && !response.isLegend) return 1;
  if (response.isLegend && !lead.isLegend) return -1;

  // 2) Güç + taktik bonusu
  final a = lead.effectivePower +
      rules.bonus(leadTactic, responseTactic,
          iAmLead: true, affinity: lead.affinity);
  final b = response.effectivePower +
      rules.bonus(responseTactic, leadTactic,
          iAmLead: false, affinity: response.affinity);
  return a.compareTo(b);
}
