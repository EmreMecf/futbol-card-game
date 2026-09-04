import 'package:freezed_annotation/freezed_annotation.dart';

import 'card_model.dart';
import 'enums.dart';

part 'pack_models.freezed.dart';
part 'pack_models.g.dart';

/// Bir paketin seviye ihtimali (arayuzde gostermek icin).
///
/// Ihtimaller sunucuda ONBINDE (basis point) tutulur:
///   %55   -> 5500
///   %1.9  -> 190
///   %0.1  -> 10
///
/// NEDEN ONBINDE? Legend ihtimali %0.1. Tam sayi yuzde ile bunu
/// yazamayiz; ondalik sayi kullanirsak yuvarlama hatalari yuzunden
/// toplam tam 100 etmez. Onbinde tam sayi ile toplam her zaman 10000.
@freezed
abstract class TierOdds with _$TierOdds {
  const TierOdds._();

  const factory TierOdds({
    required CardTier tier,

    /// Onbinde cinsinden agirlik (5500 = %55)
    required int weight,
  }) = _TierOdds;

  factory TierOdds.fromJson(Map<String, dynamic> json) =>
      _$TierOddsFromJson(json);

  /// Yuzde degeri (5500 -> 55.0)
  double get percent => weight / 100.0;

  /// Ekranda gosterilecek metin: "%55", "%1,9", "%0,1"
  ///
  /// TURKCE ONDALIK AYRACI VIRGUL. Onceki surum nokta kullaniyordu
  /// ve gereksiz sifir birakiyordu: "%0.10" gibi. Turkce'de nokta
  /// binlik ayraci oldugu icin "%0.10" yuzde on olarak da okunabilir;
  /// bu, cikma ihtimali gibi bir sayida ciddi bir yanlis anlama.
  String get displayPercent {
    final yuzde = percent;

    // Tam sayiysa ondalik hic yazilmaz: "%55"
    if (yuzde == yuzde.roundToDouble()) return '%${yuzde.round()}';

    // Tek ondalik yeter: "%1,9". Daha kucukler icin iki basamak: "%0,05"
    final basamak = yuzde >= 1 ? 1 : 2;
    final metin = yuzde
        .toStringAsFixed(basamak)
        // Sondaki gereksiz sifirlari at: "0.10" -> "0.1"
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');

    return '%${metin.replaceAll('.', ',')}';
  }
}

/// Magazadaki bir paket tanimi
@freezed
abstract class PackType with _$PackType {
  const PackType._();

  const factory PackType({
    required String slug,
    required String name,
    String? description,
    required int cardCount,
    @Default(0) int priceCoins,
    @Default(true) bool isPurchasable,

    /// Bu seviyenin ustunde kart cikmaz (baslangic paketi icin 'gold')
    CardTier? maxTier,

    /// Seviye ihtimalleri, buyukten kucuge sirali
    @Default([]) List<TierOdds> odds,

    /// Pozisyon garantisi varsa: {"GK":1,"DEF":4,"MID":4,"FWD":2}
    Map<String, int>? positionQuota,

    @Default(0) int sortOrder,
  }) = _PackType;

  factory PackType.fromJson(Map<String, dynamic> json) =>
      _$PackTypeFromJson(json);

  /// Ucretsiz mi? (baslangic paketi)
  bool get isFree => priceCoins == 0;

  /// Pozisyon garantisi var mi?
  bool get hasGuaranteedFormation => positionQuota != null;

  /// En yuksek cikabilecek seviye (vitrin icin)
  CardTier get bestPossibleTier {
    if (maxTier != null) return maxTier!;
    final cikabilenler = odds.where((o) => o.weight > 0);
    if (cikabilenler.isEmpty) return CardTier.bronze;
    return cikabilenler
        .reduce((a, b) => a.tier.rank > b.tier.rank ? a : b)
        .tier;
  }

  /// Paketin KARAKTERINI veren seviye (vitrin rengi icin).
  ///
  /// NEDEN bestPossibleTier DEGIL?
  /// Neredeyse her pakette Legend cikma ihtimali sifirdan buyuk
  /// oldugu icin bestPossibleTier hepsi icin 'legend' donuyordu ve
  /// magazada UC PAKET DE AYNI mor kutuyla ciziliyordu. Oyuncu hangi
  /// paketin daha iyi oldugunu renkten anlayamiyordu.
  ///
  /// Bu getter EN COK CIKAN seviyeyi veriyor: oyuncunun gercekte ne
  /// bekleyebilecegini gosteriyor ve paketleri birbirinden ayiriyor.
  CardTier get signatureTier {
    if (odds.isEmpty) return maxTier ?? CardTier.bronze;

    final enAgir = odds.reduce((a, b) => a.weight >= b.weight ? a : b);
    final secilen = enAgir.tier;

    // Ust sinir varsa onu asamayiz (baslangic paketi gibi)
    final sinir = maxTier;
    if (sinir != null && secilen.rank > sinir.rank) return sinir;
    return secilen;
  }

  /// Legend cikma ihtimali (vitrinde one cikarilir)
  TierOdds? get legendOdds {
    for (final o in odds) {
      if (o.tier == CardTier.legend && o.weight > 0) return o;
    }
    return null;
  }
}

/// Paket acildiktan sonra donen sonuc
@freezed
abstract class PackOpenResult with _$PackOpenResult {
  const PackOpenResult._();

  const factory PackOpenResult({
    required String packSlug,
    required String packName,
    @Default(0) int coinsSpent,
    @Default(0) int coinsLeft,

    /// Cikan kartlar, en iyiden kotuye sirali.
    /// Acilis animasyonunda sondan basa gostermek carpici olur.
    @Default([]) List<InventoryCard> cards,
  }) = _PackOpenResult;

  factory PackOpenResult.fromJson(Map<String, dynamic> json) =>
      _$PackOpenResultFromJson(json);

  /// Paketten cikan en iyi kart (acilis ekraninin yildizi)
  InventoryCard? get bestCard {
    if (cards.isEmpty) return null;
    return cards.reduce((a, b) {
      if (a.tier.rank != b.tier.rank) {
        return a.tier.rank > b.tier.rank ? a : b;
      }
      return a.power >= b.power ? a : b;
    });
  }

  /// Nadir kart cikti mi? (Diamond veya Legend)
  /// Ciktiysa acilis animasyonu daha gosterisli olmali.
  bool get hasRareCard =>
      cards.any((k) => k.tier.rank >= CardTier.diamond.rank);
}
