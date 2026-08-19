import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

void main() {
  // ==================================================================
  // LEGEND KURALI
  // ==================================================================
  group('Legend kurali (compareCards)', () {
    test('Zayif Legend, guclu Diamond kartini YENER', () {
      final sonuc = compareCards(
        aTier: CardTier.legend,
        aPower: 60,
        bTier: CardTier.diamond,
        bPower: 99,
      );
      expect(sonuc, CardDuelResult.win);
    });

    test('Legend, Bronze/Silver/Gold/Diamond kartlarinin hepsini yener', () {
      for (final seviye in [
        CardTier.bronze,
        CardTier.silver,
        CardTier.gold,
        CardTier.diamond,
      ]) {
        expect(
          compareCards(
            aTier: CardTier.legend,
            aPower: 1,
            bTier: seviye,
            bPower: 99,
          ),
          CardDuelResult.win,
          reason: 'Legend, ${seviye.label} kartini yenmeliydi',
        );
      }
    });

    test('Iki Legend karsilasirsa gucu yuksek olan kazanir', () {
      expect(
        compareCards(
          aTier: CardTier.legend,
          aPower: 94,
          bTier: CardTier.legend,
          bPower: 97,
        ),
        CardDuelResult.lose,
      );
    });

    test('Legend olmayan kartlarda SADECE guc belirleyici', () {
      // Dusuk seviye ama yuksek guc, yuksek seviye dusuk gucu yener
      expect(
        compareCards(
          aTier: CardTier.bronze,
          aPower: 90,
          bTier: CardTier.diamond,
          bPower: 85,
        ),
        CardDuelResult.win,
      );
    });

    test('Esit guc beraberlik verir (kartlar masada kalir)', () {
      expect(
        compareCards(
          aTier: CardTier.gold,
          aPower: 80,
          bTier: CardTier.silver,
          bPower: 80,
        ),
        CardDuelResult.draw,
      );
    });
  });

  // ==================================================================
  // SUNUCU BICIMI <-> MODEL UYUMU
  // ==================================================================
  // Asagidaki JSON ornekleri sunucunun GERCEKTEN gonderdigi bicimdir.
  // Bir alan adi degisirse bu testler kirilir.
  group('Sunucudan gelen JSON dogru okunuyor', () {
    test('UserModel', () {
      final json = {
        'id': 'abc-123',
        'username': 'testci',
        'email': 'a@b.com',
        'avatar_url': null,
        'coins': 1500,
        'protection_slots': 5,
        'mmr': 1100,
        'wins': 4,
        'losses': 2,
        'draws': 1,
        'created_at': '2026-08-19T09:00:00.000Z',
      };

      final kullanici = UserModel.fromJson(json);

      expect(kullanici.username, 'testci');
      expect(kullanici.protectionSlots, 5);
      expect(kullanici.totalMatches, 7);
      expect(kullanici.winRate, closeTo(4 / 7, 0.001));
      expect(kullanici.hasMaxProtection, isFalse);

      // Geri cevirince ayni bicim cikmali (sunucu bunu gonderiyor)
      expect(kullanici.toJson()['protection_slots'], 5);
    });

    test('HandCard - pozisyon ve seviye enum olarak okunur', () {
      final json = {
        'user_card_id': 'uc-1',
        'card_id': 'c-1',
        'full_name': 'Diego Maradona',
        'position': 'MID',
        'tier': 'legend',
        'power': 97,
        'image_url': 'cards/mid_legend_1.png',
        'is_played': false,
        'is_protected': true,
      };

      final kart = HandCard.fromJson(json);

      expect(kart.position, CardPosition.midfielder);
      expect(kart.position.label, 'Orta Saha');
      expect(kart.tier, CardTier.legend);
      expect(kart.isLegend, isTrue);
      expect(kart.isProtected, isTrue);
      expect(kart.isPlayable, isTrue);
    });

    test('MatchState - kalan sure CIHAZ saatinden bagimsiz hesaplanir', () {
      final json = {
        'match_id': 'm-1',
        'status': 'active',
        'round_number': 3,
        'is_my_turn': true,
        'am_i_lead': false,
        'required_position': 'FWD',
        // Sunucu hem son ani hem kendi saatini gonderiyor
        'turn_deadline': '2026-08-19T10:00:30.000Z',
        'server_time': '2026-08-19T10:00:00.000Z',
        'pot_count': 4,
        'my_score': 6,
        'opponent_score': 2,
        'my_cards_left': 8,
        'opponent_cards_left': 8,
        'opponent': {
          'id': 'u-2',
          'username': 'rakip',
          'avatar_url': null,
          'mmr': 1050,
        },
        'winner_id': null,
        'is_draw': false,
      };

      final durum = MatchState.fromJson(json);

      expect(durum.status, MatchStatus.active);
      expect(durum.requiredPosition, CardPosition.forward);
      expect(durum.isMyTurn, isTrue);
      expect(durum.amILead, isFalse);
      expect(durum.canChoosePosition, isFalse,
          reason: 'Zorunlu pozisyon varken oyuncu secim yapamaz');
      expect(durum.opponent?.username, 'rakip');
      expect(durum.scoreDifference, 4);

      // Cihaz saati ne olursa olsun 30 saniye kalmis olmali
      expect(durum.remainingTurnTime, const Duration(seconds: 30));
      expect(durum.isTurnExpired, isFalse);
    });

    test('MatchState - sure dolmussa sifir doner', () {
      final durum = MatchState.fromJson({
        'match_id': 'm-1',
        'status': 'active',
        'round_number': 1,
        'turn_deadline': '2026-08-19T10:00:00.000Z',
        'server_time': '2026-08-19T10:00:45.000Z',
      });

      expect(durum.remainingTurnTime, Duration.zero);
      expect(durum.isTurnExpired, isTrue);
    });

    test('MatchFindResult - kuyruk ve eslesme durumlari', () {
      final kuyrukta = MatchFindResult.fromJson({
        'status': 'queued',
        'match_id': null,
      });
      expect(kuyrukta.isWaiting, isTrue);
      expect(kuyrukta.shouldEnterMatch, isFalse);

      final eslesti = MatchFindResult.fromJson({
        'status': 'matched',
        'match_id': 'm-9',
      });
      expect(eslesti.shouldEnterMatch, isTrue);

      final devamEden = MatchFindResult.fromJson({
        'status': 'in_match',
        'match_id': 'm-7',
      });
      expect(devamEden.status, MatchmakingStatus.inMatch);
      expect(devamEden.shouldEnterMatch, isTrue);
    });

    test('RealtimeEvent - bilinmeyen olay COKMEZ', () {
      // Ileride sunucuya yeni bir olay tipi eklenirse, eski uygulama
      // surumleri cokmeden 'unknown' olarak okumali.
      final olay = RealtimeEvent.fromJson({
        'type': 'gelecekte_eklenecek_olay',
        'match_id': 'm-1',
      });

      expect(olay.type, RealtimeEventType.unknown);
      expect(olay.requiresMatchRefresh, isFalse);
    });

    test('RealtimeEvent - mac olaylari tazeleme gerektirir', () {
      for (final tip in ['match_updated', 'move_played', 'round_resolved', 'match_finished']) {
        final olay = RealtimeEvent.fromJson({'type': tip, 'match_id': 'm-1'});
        expect(olay.requiresMatchRefresh, isTrue, reason: '$tip tazeleme istemeli');
      }

      final pong = RealtimeEvent.fromJson({'type': 'pong'});
      expect(pong.isNoise, isTrue);
    });
  });

  // ==================================================================
  // KADRO KURMA MANTIGI
  // ==================================================================
  group('DeckBuilderState - 4-4-2 formasyonu', () {
    InventoryCard kart(CardPosition pozisyon, int no) => InventoryCard(
          userCardId: 'uc-$no',
          cardId: 'c-$no',
          fullName: 'Oyuncu $no',
          position: pozisyon,
          tier: CardTier.bronze,
          power: 50,
        );

    test('bos kadro tamamlanmamis sayilir ve eksikleri listeler', () {
      const durum = DeckBuilderState();

      expect(durum.isComplete, isFalse);
      expect(durum.missingMessage, contains('kaleci'));
      expect(durum.missingMessage, contains('defans'));
    });

    test('pozisyon siniri asilamaz', () {
      final durum = DeckBuilderState(selectedCards: [
        kart(CardPosition.goalkeeper, 1),
      ]);

      expect(durum.countFor(CardPosition.goalkeeper), 1);
      expect(durum.canAdd(CardPosition.goalkeeper), isFalse,
          reason: 'Kadroda sadece 1 kaleci olabilir');
      expect(durum.canAdd(CardPosition.defender), isTrue);
    });

    test('tam kadro (1-4-4-2) gecerli sayilir', () {
      var no = 0;
      final kartlar = <InventoryCard>[
        for (var i = 0; i < 1; i++) kart(CardPosition.goalkeeper, no++),
        for (var i = 0; i < 4; i++) kart(CardPosition.defender, no++),
        for (var i = 0; i < 4; i++) kart(CardPosition.midfielder, no++),
        for (var i = 0; i < 2; i++) kart(CardPosition.forward, no++),
      ];

      final durum = DeckBuilderState(selectedCards: kartlar);

      expect(kartlar.length, GameRules.squadSize);
      expect(durum.isComplete, isTrue);
      expect(durum.missingMessage, isNull);
      expect(durum.userCardIds.length, 11);
    });

    test('fazla kart uyari verir', () {
      var no = 0;
      final durum = DeckBuilderState(selectedCards: [
        for (var i = 0; i < 3; i++) kart(CardPosition.forward, no++),
      ]);

      expect(durum.missingMessage, contains('fazla kart'));
    });
  });

  // ==================================================================
  // KIMYA SISTEMI
  // ==================================================================
  chemistryTests();

  // ==================================================================
  // KADRO DOGRULAMA MESAJI
  // ==================================================================
  test('DeckValidation sunucunun Turkce mesajini tasir', () {
    final gecersiz = DeckValidation.fromJson({
      'is_valid': false,
      'message': 'Kadroda tam 4 defans olmali (su an: 3).',
    });

    expect(gecersiz.isValid, isFalse);
    expect(gecersiz.displayMessage, contains('4 defans'));

    final gecerli = DeckValidation.fromJson({'is_valid': true, 'message': null});
    expect(gecerli.displayMessage, 'Kadro hazir');
  });
}

// ======================================================================
// KIMYA SISTEMI
// ======================================================================
// Bu kurallar veritabanindaki chemistry_link_score() ile BIREBIR ayni
// olmali. Ikisi ayni kurali uygular ama biri digerine guvenmez:
// buradaki hesap arayuz onizlemesi, oradaki mac sonucudur.

class _TestKart implements ChemistrySource {
  @override
  final String? nationality;
  @override
  final String? league;
  @override
  final String? club;

  const _TestKart({this.nationality, this.league, this.club});
}

void chemistryTests() {
  group('Kimya bag puani', () {
    test('ayni kulup -> +2 (yesil)', () {
      expect(
        chemistryLinkScore(
          const _TestKart(nationality: 'TUR', league: 'Super Lig', club: 'Anadolu SK'),
          const _TestKart(nationality: 'BRA', league: 'Super Lig', club: 'Anadolu SK'),
        ),
        2,
      );
    });

    test('ayni lig + ayni uyruk -> +2 (yesil)', () {
      expect(
        chemistryLinkScore(
          const _TestKart(nationality: 'TUR', league: 'Super Lig', club: 'Anadolu SK'),
          const _TestKart(nationality: 'TUR', league: 'Super Lig', club: 'Kartal SK'),
        ),
        2,
      );
    });

    test('sadece ayni uyruk -> +1 (sari)', () {
      expect(
        chemistryLinkScore(
          const _TestKart(nationality: 'TUR', league: 'Super Lig', club: 'Anadolu SK'),
          const _TestKart(nationality: 'TUR', league: 'La Liga', club: 'Madrid Real'),
        ),
        1,
      );
    });

    test('sadece ayni lig -> +1 (sari)', () {
      expect(
        chemistryLinkScore(
          const _TestKart(nationality: 'TUR', league: 'Super Lig', club: 'Anadolu SK'),
          const _TestKart(nationality: 'BRA', league: 'Super Lig', club: 'Kartal SK'),
        ),
        1,
      );
    });

    test('ortak nokta yok -> 0 (kirmizi)', () {
      expect(
        chemistryLinkScore(
          const _TestKart(nationality: 'TUR', league: 'Super Lig', club: 'Anadolu SK'),
          const _TestKart(nationality: 'BRA', league: 'La Liga', club: 'Madrid Real'),
        ),
        0,
      );
    });

    test('NULL degerler eslesme SAYILMAZ', () {
      // Ligi belirsiz iki kart "ayni ligde" sayilsaydi, eksik veri
      // kimya kazandirirdi.
      expect(chemistryLinkScore(const _TestKart(), const _TestKart()), 0);
      expect(
        chemistryLinkScore(
          const _TestKart(nationality: 'TUR'),
          const _TestKart(league: 'Super Lig'),
        ),
        0,
      );
    });
  });

  group('Formasyon', () {
    test('17 bag var, en yuksek kimya 34', () {
      expect(kFormationLinks.length, 17);
      expect(kMaxTeamChemistry, 34);
    });

    test('slot pozisyonlari 1-4-4-2 formasyonuna uyuyor', () {
      expect(formationSlotPosition(0), CardPosition.goalkeeper);
      for (var s = 1; s <= 4; s++) {
        expect(formationSlotPosition(s), CardPosition.defender);
      }
      for (var s = 5; s <= 8; s++) {
        expect(formationSlotPosition(s), CardPosition.midfielder);
      }
      for (var s = 9; s <= 10; s++) {
        expect(formationSlotPosition(s), CardPosition.forward);
      }
    });

    test('her slotun en az bir bagi var (olu slot yok)', () {
      for (var s = 0; s < GameRules.squadSize; s++) {
        final bagSayisi = kFormationLinks.where((l) => l.touches(s)).length;
        expect(bagSayisi, greaterThan(0),
            reason: '$s numarali slotun hic bagi yok');
      }
    });

    test('slotsForPosition ile formationSlotPosition tutarli', () {
      for (final p in CardPosition.values) {
        final slotlar = slotsForPosition(p);
        expect(slotlar.length, p.requiredCount);
        for (final s in slotlar) {
          expect(formationSlotPosition(s), p);
        }
      }
    });
  });

  group('Kadro kimyasi hesabi', () {
    const anadolu = _TestKart(
        nationality: 'TUR', league: 'Super Lig', club: 'Anadolu SK');
    const yabanci =
        _TestKart(nationality: 'JPN', league: 'J-Lig', club: 'Tokyo Blue');

    test('bos kadroda kimya sifir', () {
      final k = DeckChemistry.calculate({});
      expect(k.total, 0);
      expect(k.isComplete, isFalse);
    });

    test('tamami ayni kuluptense kimya EN YUKSEK degere ulasir', () {
      final k = DeckChemistry.calculate({
        for (var s = 0; s < GameRules.squadSize; s++) s: anadolu,
      });

      expect(k.total, kMaxTeamChemistry);
      expect(k.percent, 100);
      expect(k.isComplete, isTrue);
      expect(k.strongCount, 17);
      expect(k.noneCount, 0);
      expect(k.label, 'Mukemmel uyum');
    });

    test('tamami farkliysa kimya sifir ama kadro tam', () {
      final k = DeckChemistry.calculate({
        for (var s = 0; s < GameRules.squadSize; s++)
          s: _TestKart(nationality: 'U$s', league: 'L$s', club: 'K$s'),
      });

      expect(k.total, 0);
      expect(k.isComplete, isTrue);
      expect(k.noneCount, 17);
      expect(k.label, 'Uyum yok');
    });

    test('eksik kadroda bos slotlarin baglari sayilmaz', () {
      final k = DeckChemistry.calculate({0: anadolu, 2: anadolu});

      // Slot 0 ile 2 arasinda bag var -> +2
      expect(k.total, 2);
      expect(k.links.length, 1, reason: 'Sadece dolu slotlar arasi bag sayilir');
      expect(k.isComplete, isFalse);
    });

    test('kart kimyasi baglarinin TOPLAMI', () {
      // Slot 2'nin baglari: (0,2), (1,2), (2,3), (2,6) -> 4 bag
      final k = DeckChemistry.calculate({
        0: anadolu, 1: anadolu, 2: anadolu, 3: anadolu, 6: anadolu,
      });

      expect(k.chemistryAt(2), 8, reason: '4 bag x 2 puan');
      expect(k.linksAt(2).length, 4);
    });

    test('BAGLI OLMAYAN slotlar birbirini etkilemez', () {
      // Slot 1 ile 4 formasyonda bagli degil
      final k = DeckChemistry.calculate({1: anadolu, 4: anadolu});
      expect(k.total, 0);
    });

    test('bag kalitesi dogru siniflandirilir', () {
      final k = DeckChemistry.calculate({1: anadolu, 2: yabanci});
      expect(k.links.first.quality, ChemistryQuality.none);

      final k2 = DeckChemistry.calculate({1: anadolu, 2: anadolu});
      expect(k2.links.first.quality, ChemistryQuality.strong);
    });
  });
}
