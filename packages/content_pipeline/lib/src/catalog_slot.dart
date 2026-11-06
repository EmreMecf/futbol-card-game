import 'package:shared_models/shared_models.dart';

/// Katalogda bir YUVA: "Altın FWD #1".
///
/// Seviye ve mevki katalog planından gelir (KARAKTER_SISTEMI_PLANI.md
/// bölüm 5); yapay zekâ bunları seçmez.
class CatalogSlot {
  final CardPosition position;
  final CardTier tier;
  final int index;

  const CatalogSlot(this.position, this.tier, this.index);

  String get code => '${tier.code}-${position.code}-$index';

  @override
  String toString() => code;
}

/// Kurgu dünya: karakterin bölgesi ve kulübü (gerçek marka yok)
class FictionalWorld {
  final String regionCode;
  final String regionName;
  final String leagueCode;
  final String leagueName;
  final String clubCode;
  final String clubName;
  final String primaryColor;
  final String secondaryColor;

  const FictionalWorld({
    required this.regionCode,
    required this.regionName,
    required this.leagueCode,
    required this.leagueName,
    required this.clubCode,
    required this.clubName,
    required this.primaryColor,
    required this.secondaryColor,
  });
}
