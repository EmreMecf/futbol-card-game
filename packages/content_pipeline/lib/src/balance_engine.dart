import 'package:shared_models/shared_models.dart';

import 'catalog_slot.dart';

/// DENGE MOTORU — güç ve özellikleri YAPAY ZEKÂ DEĞİL bu kod belirler.
///
/// Deterministik: aynı yuva + aynı slug her zaman aynı değerleri verir
/// (veritabanı her sıfırlandığında karakter değişmez).
///
///   güç       = seviye aralığında, slug'dan türetilen sabit bir nokta
///   özellik   = güç + mevki profili + oyun tarzı şekli + karta özel ±4
///               (016_card_attributes.sql formülü + tarz şekli)
///
/// Oyun tarzı şekli her özellikte en fazla ±6 ve TOPLAMI SIFIR: tarz
/// kartı güçlendirmez, sadece karakter verir.
class BalanceEngine {
  static const version = 'balance-v1';

  /// Katalogdaki gerçek seviye aralıkları (010_seed_cards.sql)
  static const tierRange = <CardTier, (int, int)>{
    CardTier.bronze: (45, 62),
    CardTier.silver: (63, 74),
    CardTier.gold: (75, 85),
    CardTier.diamond: (86, 92),
    CardTier.legend: (93, 99),
  };

  /// Mevki profili (016): ŞUT, HIZ, FİZİK, DEFANS, DRİBLİNG, HIZLANMA
  static const positionProfile = <CardPosition, List<int>>{
    CardPosition.goalkeeper: [-38, -20, 1, 2, -28, -22],
    CardPosition.defender: [-22, -5, 6, 8, -12, -6],
    CardPosition.midfielder: [-3, -2, -5, -7, 6, -2],
    CardPosition.forward: [6, 5, -6, -24, 5, 6],
  };

  /// Oyun tarzı şekli (toplamı sıfır, her değer |x| ≤ 6)
  static const playstyleShape = <Playstyle, List<int>>{
    Playstyle.fastWinger: [-2, 5, -4, -2, 0, 3],
    Playstyle.finisher: [6, 0, 0, -3, -2, -1],
    Playstyle.targetMan: [2, -3, 6, 1, -4, -2],
    Playstyle.creativeForward: [0, 0, -3, -2, 5, 0],
    Playstyle.playmaker: [0, -2, -3, 0, 5, 0],
    Playstyle.boxToBox: [-1, 1, 3, 1, -3, -1],
    Playstyle.ballWinner: [-4, 0, 3, 5, -3, -1],
    Playstyle.technician: [1, 0, -4, -2, 5, 0],
    Playstyle.stopper: [-2, -2, 4, 5, -3, -2],
    Playstyle.ballPlayingDefender: [0, -1, -2, 2, 3, -2],
    Playstyle.attackingFullback: [-1, 4, -3, -3, 1, 2],
    Playstyle.defensiveFullback: [-2, 1, 1, 4, -3, -1],
    Playstyle.lineKeeper: [0, -2, 3, 2, -2, -1],
    Playstyle.sweeperKeeper: [0, 3, -2, -2, 0, 1],
  };

  static const _ozellikAdi = ['shooting', 'pace', 'physical', 'defending', 'dribbling', 'acceleration'];

  /// FNV-1a 32 bit: platformdan bağımsız, deterministik
  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final b in s.codeUnits) {
      h ^= b;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  CharacterCardProposal propose({
    required String characterId,
    required String slug,
    required CatalogSlot slot,
    required Playstyle playstyle,
  }) {
    if (playstyle.position != slot.position) {
      throw ArgumentError('${playstyle.label} tarzı ${slot.position.label} yuvasına konamaz');
    }
    final (lo, hi) = tierRange[slot.tier]!;
    final guc = lo + _hash('$slug:power') % (hi - lo + 1);

    final profil = positionProfile[slot.position]!;
    final sekil = playstyleShape[playstyle]!;
    int ozellik(int i) {
      final sapma = _hash('$slug:${_ozellikAdi[i]}') % 9 - 4; // -4..+4
      return (guc + profil[i] + sekil[i] + sapma).clamp(1, 99);
    }

    return CharacterCardProposal(
      characterId: characterId,
      tier: slot.tier,
      power: guc,
      attributes: CardAttributes(
        shooting: ozellik(0),
        pace: ozellik(1),
        physical: ozellik(2),
        defending: ozellik(3),
        dribbling: ozellik(4),
        acceleration: ozellik(5),
      ),
      slot: slot.code,
      balanceEngineVersion: version,
    );
  }
}
