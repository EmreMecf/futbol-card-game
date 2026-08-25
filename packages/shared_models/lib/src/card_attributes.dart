import 'package:freezed_annotation/freezed_annotation.dart';

part 'card_attributes.freezed.dart';
part 'card_attributes.g.dart';

/// Bir kartin alti oyuncu ozelligi.
///
/// SUT, HIZ, FIZIK, DEFANS, DRIBLING, HIZLANMA.
///
/// ---------------------------------------------------------------
/// BU DEGERLER MACI BELIRLEMEZ
/// ---------------------------------------------------------------
/// Turu kazanan hala `power + chemistry`. Ozellikler su an sadece
/// kartin karakterini anlatir: ayni 78 gucteki iki kart, biri hizli
/// ve dribbling'i yuksek, digeri fizigi guclu ve defansif olabilir.
///
/// Bir ozelligi mac kuralina baglamaya karar verirsek degisecek yer
/// veritabanindaki `_resolve_round()` olacak; burasi degil. Kurallar
/// istemcide yasamaz.
///
/// ---------------------------------------------------------------
/// NEDEN AYRI SINIF, NEDEN 6 AYRI ALAN DEGIL?
/// ---------------------------------------------------------------
/// Alti alan `CardModel`, `InventoryCard` ve `HandCard` icine ayri
/// ayri yazilsaydi ayni alti alan uc kez tekrarlanir, arayuzde de
/// "hangi kart tipi olursa olsun ozellikleri ciz" diyen tek bir
/// widget yazilamazdi. Tek nesne halinde tasimak her ucunu de ayni
/// widget'a verebilmemizi sagliyor.
@freezed
abstract class CardAttributes with _$CardAttributes {
  const CardAttributes._();

  const factory CardAttributes({
    /// SUT
    @Default(0) int shooting,

    /// HIZ
    @Default(0) int pace,

    /// FIZIK
    @Default(0) int physical,

    /// DEFANS
    @Default(0) int defending,

    /// DRIBLING
    @Default(0) int dribbling,

    /// HIZLANMA
    @Default(0) int acceleration,
  }) = _CardAttributes;

  factory CardAttributes.fromJson(Map<String, dynamic> json) =>
      _$CardAttributesFromJson(json);

  /// Ekranda gosterilecek sira ve Turkce etiketleri.
  ///
  /// Sira KASITLI: once hucum (sut, dribling), sonra atletiklik
  /// (hiz, hizlanma), sonra savunma (defans, fizik). Boylece iki
  /// sutunlu izgarada solda hucum, sagda savunma toplaniyor.
  List<CardAttributeEntry> get entries => [
        CardAttributeEntry('SUT', shooting),
        CardAttributeEntry('HIZ', pace),
        CardAttributeEntry('DRP', dribbling),
        CardAttributeEntry('HZL', acceleration),
        CardAttributeEntry('DEF', defending),
        CardAttributeEntry('FIZ', physical),
      ];

  /// Alti ozelligin ortalamasi.
  ///
  /// DIKKAT: Bu `power` DEGILDIR ve ona esit olmasi da beklenmez.
  /// Bir kalecinin sutu cok dusuk oldugu icin ortalamasi gucunun
  /// altinda kalir; bu normaldir. Sadece "kart genel olarak nasil?"
  /// sorusuna kaba bir cevap verir.
  int get average =>
      ((shooting + pace + physical + defending + dribbling + acceleration) / 6)
          .round();

  /// Kartin en guclu ozelligi ("HIZ 92" rozeti icin)
  CardAttributeEntry get best =>
      entries.reduce((a, b) => b.value > a.value ? b : a);

  /// Butun degerler sifirsa sunucudan veri gelmemis demektir;
  /// arayuz bos bir izgara cizmek yerine bolumu hic gostermemeli.
  bool get isEmpty =>
      shooting == 0 &&
      pace == 0 &&
      physical == 0 &&
      defending == 0 &&
      dribbling == 0 &&
      acceleration == 0;

  bool get isNotEmpty => !isEmpty;
}

/// Tek bir ozelligin etiketi ve degeri (arayuzde satir cizmek icin)
class CardAttributeEntry {
  /// Kisa etiket: 'SUT', 'HIZ', 'DRP', 'HZL', 'DEF', 'FIZ'
  final String label;
  final int value;

  const CardAttributeEntry(this.label, this.value);

  /// Deger ne kadar iyi? (0.0 - 1.0) Renk ve bar uzunlugu icin.
  ///
  /// 30'un altini 0 sayiyoruz: pratikte hicbir kartin ozelligi
  /// 1-30 araliginda "kotu"dan baska bir sey ifade etmiyor ve
  /// tum bari 0-99'a yaymak farklari goze carpmaz hale getiriyordu.
  double get ratio => ((value - 30) / 69).clamp(0.0, 1.0);
}
