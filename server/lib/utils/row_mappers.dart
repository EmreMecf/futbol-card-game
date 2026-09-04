import 'dart:convert';

import 'package:shared_models/shared_models.dart';

/// Veritabani satirlarini PAYLASILAN modellere cevirir.
///
/// NEDEN BU KATMAN VAR?
/// Sunucu artik elle JSON haritasi kurmuyor; once modeli olusturuyor,
/// sonra `toJson()` ile gonderiyor. Uygulama da ayni modelin
/// `fromJson()`'unu kullaniyor. Boylece bir alanin adini degistirdiginde
/// iki taraf da derleme hatasi verir - calisma aninda sessizce null
/// donmez.
class RowMappers {
  const RowMappers._();

  // ------------------------------------------------------------------
  // KULLANICI
  // ------------------------------------------------------------------
  static UserModel user(Map<String, dynamic> row) {
    return UserModel(
      id: row['id'].toString(),
      username: row['username'] as String,
      email: row['email']?.toString() ?? '',
      avatarUrl: row['avatar_url'] as String?,
      coins: _int(row['coins']),
      protectionSlots: _int(row['protection_slots'], GameRules.baseProtectionSlots),
      mmr: _int(row['mmr'], 1000),
      wins: _int(row['wins']),
      losses: _int(row['losses']),
      draws: _int(row['draws']),
      createdAt: row['created_at'] as DateTime?,
    );
  }

  // ------------------------------------------------------------------
  // KART KATALOGU
  // ------------------------------------------------------------------
  static CardModel card(Map<String, dynamic> row) {
    return CardModel(
      cardId: (row['card_id'] ?? row['id']).toString(),
      fullName: row['full_name'] as String,
      position: CardPosition.fromCode(row['position'].toString()),
      tier: CardTier.fromCode(row['tier'].toString()),
      power: _int(row['power']),
      slug: row['slug'] as String?,
      nationality: row['nationality'] as String?,
      league: row['league'] as String?,
      club: row['club'] as String?,
      attributes: _attributes(row),
      imageUrl: row['image_url'] as String?,
    );
  }

  // ------------------------------------------------------------------
  // ENVANTER KARTI
  // ------------------------------------------------------------------
  static InventoryCard inventoryCard(Map<String, dynamic> row) {
    return InventoryCard(
      userCardId: row['user_card_id'].toString(),
      cardId: (row['card_id'] ?? row['id']).toString(),
      fullName: row['full_name'] as String,
      position: CardPosition.fromCode(row['position'].toString()),
      tier: CardTier.fromCode(row['tier'].toString()),
      power: _int(row['power']),
      slug: row['slug'] as String?,
      nationality: row['nationality'] as String?,
      league: row['league'] as String?,
      club: row['club'] as String?,
      attributes: _attributes(row),
      imageUrl: row['image_url'] as String?,
      inDeck: row['in_deck'] == true,
      isLocked: row['locked_match_id'] != null,
    );
  }

  // ------------------------------------------------------------------
  // DESTE
  // ------------------------------------------------------------------
  static DeckSummary deck(Map<String, dynamic> row) {
    return DeckSummary(
      id: row['id'].toString(),
      name: row['name'] as String,
      isActive: row['is_active'] == true,
      cardCount: _int(row['card_count']),
    );
  }

  // ------------------------------------------------------------------
  // MACTAKI EL
  // ------------------------------------------------------------------
  static HandCard handCard(Map<String, dynamic> row) {
    return HandCard(
      userCardId: row['user_card_id'].toString(),
      cardId: row['card_id'].toString(),
      fullName: row['full_name'] as String,
      position: CardPosition.fromCode(row['position'].toString()),
      tier: CardTier.fromCode(row['tier'].toString()),
      power: _int(row['power']),

      // Mac baslarken dondurulan kimya bonusu.
      // Kart masaya `power + chemistry` gucuyle cikar.
      chemistry: _int(row['chemistry']),
      nationality: row['nationality'] as String?,
      league: row['league'] as String?,
      club: row['club'] as String?,
      attributes: _attributes(row),

      imageUrl: row['image_url'] as String?,
      isPlayed: row['is_played'] == true,
      isProtected: row['is_protected'] == true,
    );
  }

  // ------------------------------------------------------------------
  // HAMLE
  // ------------------------------------------------------------------
  static MatchMove move(Map<String, dynamic> row, String requestingUserId) {
    final pozisyon = row['position']?.toString();
    final seviye = row['tier']?.toString();

    return MatchMove(
      roundNumber: _int(row['round_number']),
      userId: row['user_id'].toString(),
      isMine: row['user_id'].toString() == requestingUserId,
      isLead: row['is_lead'] == true,
      isPass: row['is_pass'] == true,
      position: pozisyon == null ? null : CardPosition.fromCode(pozisyon),
      tier: seviye == null ? null : CardTier.fromCode(seviye),
      power: row['power'] == null ? null : _int(row['power']),
      chemistry: _int(row['chemistry']),
      userCardId: row['user_card_id']?.toString(),
      fullName: row['full_name'] as String?,
      imageUrl: row['image_url'] as String?,
    );
  }

  // ------------------------------------------------------------------
  // TUR SONUCU
  // ------------------------------------------------------------------
  static MatchRound round(Map<String, dynamic> row) {
    final kartlar = row['cards_won'];
    return MatchRound(
      roundNumber: _int(row['round_number']),
      winnerId: row['winner_id']?.toString(),
      isDraw: row['is_draw'] == true,
      cardsWon: kartlar is List
          ? kartlar.map((e) => e.toString()).toList()
          : const [],
    );
  }

  // ------------------------------------------------------------------
  // PAKET TANIMI
  // ------------------------------------------------------------------
  static PackType pack(Map<String, dynamic> row) {
    final agirliklar = asMap(row['tier_weights']);

    // Ihtimalleri buyukten kucuge sirala (vitrinde boyle gosterecegiz)
    final oranlar = CardTier.values
        .map((t) => TierOdds(
              tier: t,
              weight: _int(agirliklar[t.code]),
            ))
        .where((o) => o.weight > 0)
        .toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));

    final kota = row['position_quota'];
    final maxTier = row['max_tier']?.toString();

    return PackType(
      slug: row['slug'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      cardCount: _int(row['card_count']),
      priceCoins: _int(row['price_coins']),
      isPurchasable: row['is_purchasable'] == true,
      maxTier: maxTier == null ? null : CardTier.fromCode(maxTier),
      odds: oranlar,
      positionQuota: kota == null
          ? null
          : asMap(kota).map((k, v) => MapEntry(k, _int(v))),
      sortOrder: _int(row['sort_order']),
    );
  }

  // ------------------------------------------------------------------
  // PAKET ACMA SONUCU
  // ------------------------------------------------------------------
  /// `open_pack()` fonksiyonunun JSON ciktisini modele cevirir.
  static PackOpenResult packResult(dynamic ham) {
    final json = asMap(ham);
    final paket = asMap(json['pack']);
    final kartlar = json['cards'];

    return PackOpenResult(
      packSlug: paket['slug'].toString(),
      packName: paket['name'].toString(),
      coinsSpent: _int(json['coins_spent']),
      coinsLeft: _int(json['coins_left']),
      cards: kartlar is List
          ? kartlar.map((k) => inventoryCard(asMap(k))).toList()
          : const [],
    );
  }

  // ------------------------------------------------------------------
  // KADRO KIMYASI
  // ------------------------------------------------------------------
  /// `deck_chemistry_summary()` JSON ciktisini modele cevirir.
  static DeckChemistry deckChemistry(dynamic ham) =>
      DeckChemistry.fromJson(asMap(ham));

  // ------------------------------------------------------------------
  // MAC SONUCU
  // ------------------------------------------------------------------
  /// `get_match_result()` JSON ciktisini modele cevirir.
  ///
  /// Modelden gecirmek bir dogrulama adimidir: SQL tarafinda bir alan
  /// adini degistirsek burada hemen hata alirdik.
  static MatchResultSummary matchResult(dynamic ham) =>
      MatchResultSummary.fromJson(asMap(ham));

  // ------------------------------------------------------------------
  // MAC GECMISI SATIRI
  // ------------------------------------------------------------------
  static MatchHistoryEntry matchHistoryEntry(Map<String, dynamic> satir) =>
      MatchHistoryEntry(
        matchId: satir['match_id'].toString(),
        opponentId: satir['opponent_id'].toString(),
        opponentUsername: satir['opponent_username'] as String? ?? 'Rakip',
        myScore: (satir['my_score'] as int?) ?? 0,
        opponentScore: (satir['opponent_score'] as int?) ?? 0,
        outcome: switch (satir['outcome'] as String?) {
          'win' => MatchOutcome.win,
          'loss' => MatchOutcome.loss,
          _ => MatchOutcome.draw,
        },
        cardsWon: (satir['cards_won'] as int?) ?? 0,
        cardsLost: (satir['cards_lost'] as int?) ?? 0,
        finishedAt: satir['finished_at'] as DateTime?,
      );

  // ------------------------------------------------------------------
  // SBC SONUCU
  // ------------------------------------------------------------------
  static SbcSubmitResult sbcResult(dynamic ham) =>
      SbcSubmitResult.fromJson(asMap(ham));

  // ------------------------------------------------------------------
  // POSTGRES JSON DEGERINI LISTEYE CEVIR
  // ------------------------------------------------------------------
  static List<dynamic> asList(dynamic deger) {
    if (deger is List) return deger;
    if (deger is String) {
      final cozulmus = jsonDecode(deger);
      if (cozulmus is List) return cozulmus;
    }
    throw StateError('JSON dizisi bekleniyordu: $deger');
  }

  // ------------------------------------------------------------------
  // POSTGRES JSON DEGERINI HARITAYA CEVIR
  // ------------------------------------------------------------------
  /// `json_build_object` donen fonksiyonlar (get_match_state, find_match)
  /// surucu ayarina gore Map ya da metin donebilir; ikisini de karsilar.
  static Map<String, dynamic> asMap(dynamic deger) {
    if (deger is Map<String, dynamic>) return deger;
    if (deger is Map) return Map<String, dynamic>.from(deger);
    if (deger is String) {
      final cozulmus = jsonDecode(deger);
      if (cozulmus is Map) return Map<String, dynamic>.from(cozulmus);
    }
    throw StateError('JSON nesnesi bekleniyordu: $deger');
  }

  // ------------------------------------------------------------------
  // KART OZELLIKLERI (SUT / HIZ / FIZIK / DEFANS / DRIBLING / HIZLANMA)
  // ------------------------------------------------------------------
  /// IKI FARKLI SEKLI DE KARSILAR:
  ///
  ///   1. DUZ KOLONLAR  — `select c.shooting, c.pace, ...` yapan
  ///      sorgulardan gelen satirlar.
  ///   2. IC ICE NESNE  — `card_attributes_json()` ile uretilen
  ///      JSON'lar (paket acma, mac sonucu). Orada alanlar
  ///      `attributes` altinda toplanir.
  ///
  /// Ikisini de tek yerde karsilamak, yeni bir uc nokta eklendiginde
  /// "ozellikler neden bos geliyor?" hatasini bastan kapatiyor.
  static CardAttributes? _attributes(Map<String, dynamic> row) {
    final icIce = row['attributes'];
    final kaynak = icIce == null ? row : asMap(icIce);

    // Sunucu ozellikleri henuz uretmemisse null donuyoruz; arayuz de
    // bolumu hic cizmiyor. Sifirlarla dolu bir kart gostermek
    // "bu oyuncunun sutu 0" gibi YANLIS bir bilgi olurdu.
    if (kaynak['shooting'] == null) return null;

    return CardAttributes(
      shooting: _int(kaynak['shooting']),
      pace: _int(kaynak['pace']),
      physical: _int(kaynak['physical']),
      defending: _int(kaynak['defending']),
      dribbling: _int(kaynak['dribbling']),
      acceleration: _int(kaynak['acceleration']),
    );
  }

  static int _int(dynamic deger, [int varsayilan = 0]) {
    if (deger is int) return deger;
    if (deger is num) return deger.toInt();
    return int.tryParse(deger?.toString() ?? '') ?? varsayilan;
  }
}
