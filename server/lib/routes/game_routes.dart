import 'package:shared_models/shared_models.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth/auth_middleware.dart';
import '../config/env.dart';
import '../db/database.dart';
import '../utils/api_response.dart';
import '../utils/row_mappers.dart';

/// Kart, envanter ve deste uc noktalari. Hepsi jeton gerektirir.
///
///   GET    /api/game/cards               -> Kart katalogu
///   GET    /api/game/inventory           -> Kendi kartlarim
///   POST   /api/game/starter-pack        -> Baslangic paketini al
///   GET    /api/game/decks               -> Destelerim
///   POST   /api/game/decks               -> Yeni deste olustur
///   PUT    `/api/game/decks/<deckId>`      -> Destenin kartlarini degistir
///   GET    `/api/game/decks/<deckId>/validate` -> Kadro gecerli mi?
///   GET    `/api/game/packs`             -> Magazadaki paketler
///   POST   `/api/game/packs/<slug>/open` -> Paket ac (SUNUCUDA cekilis)
Router gameRoutes(Database db) {
  final router = Router();

  // ------------------------------------------------------------------
  // KART KATALOGU
  // ------------------------------------------------------------------
  router.get('/cards', (Request request) async {
    final kartlar = await db.query(
      '''
      select id, slug, full_name, position, tier, power,
             nationality, league, club, image_url
      from cards
      where is_active
      order by tier desc, power desc
      ''',
    );

    return jsonOk({
      'cards': kartlar.map((r) => RowMappers.card(r).toJson()).toList(),
    });
  });

  // ------------------------------------------------------------------
  // ENVANTER
  // ------------------------------------------------------------------
  router.get('/inventory', (Request request) async {
    final userId = requireUserId(request);

    final kartlar = await db.query(
      '''
      select uc.id as user_card_id,
             uc.locked_match_id,
             uc.acquired_at,
             c.id as card_id, c.slug, c.full_name, c.position, c.tier,
             c.power, c.nationality, c.league, c.club, c.image_url,
             (dc.deck_id is not null) as in_deck
      from user_cards uc
      join cards c on c.id = uc.card_id
      left join deck_cards dc on dc.user_card_id = uc.id
      where uc.owner_id = @userId::uuid
      order by c.tier desc, c.power desc
      ''',
      params: {'userId': userId},
    );

    return jsonOk({
      'cards':
          kartlar.map((r) => RowMappers.inventoryCard(r).toJson()).toList(),
    });
  });

  // ------------------------------------------------------------------
  // BASLANGIC PAKETI
  // ------------------------------------------------------------------
  router.post('/starter-pack', (Request request) async {
    final userId = requireUserId(request);
    final sonuc = await db.scalar(
      'select grant_starter_pack(@id::uuid)',
      params: {'id': userId},
    );
    return jsonOk(sonuc);
  });

  // ------------------------------------------------------------------
  // MAGAZA: PAKETLER
  // ------------------------------------------------------------------
  router.get('/packs', (Request request) async {
    final paketler = await db.query(
      '''
      select slug, name, description, card_count, price_coins,
             is_purchasable, tier_weights, max_tier, position_quota, sort_order
      from pack_types
      where is_active and is_purchasable
      order by sort_order, price_coins
      ''',
    );

    return jsonOk({
      'packs': paketler.map((p) => RowMappers.pack(p).toJson()).toList(),
    });
  });

  // ------------------------------------------------------------------
  // PAKET AC
  // ------------------------------------------------------------------
  // ANTI-HILE: Cekilis TAMAMEN veritabaninda yapilir. Istemci sadece
  // "su paketi acmak istiyorum" der; hangi kartlarin ciktigina
  // karisamaz. Rastgeleligi bile sunucu uretir (secure_random_int).
  //
  // Ucretsiz baslangic paketi bu uctan ACILAMAZ; open_pack() icindeki
  // is_purchasable kontrolu engeller.
  router.post('/packs/<slug>/open', (Request request, String slug) async {
    final userId = requireUserId(request);

    final sonuc = await db.scalar(
      'select open_pack(@userId::uuid, @slug)',
      params: {'userId': userId, 'slug': slug},
    );

    return jsonOk(RowMappers.packResult(sonuc).toJson());
  });

  // ------------------------------------------------------------------
  // PAKET ACMA GECMISI (seffaflik)
  // ------------------------------------------------------------------
  // Oyuncu kendi cekilis gecmisini gorebilir. "Hile yapiyorsunuz"
  // sikayetlerine karsi en iyi savunma seffafliktir.
  router.get('/packs/history', (Request request) async {
    final userId = requireUserId(request);

    final gecmis = await db.query(
      '''
      select pack_slug, tiers, coins_spent, created_at
      from pack_openings
      where user_id = @userId::uuid
      order by created_at desc
      limit 50
      ''',
      params: {'userId': userId},
    );

    return jsonOk({
      'openings': gecmis.map((g) => {
            'pack_slug': g['pack_slug'],
            'tiers': (g['tiers'] as List?)?.map((e) => e.toString()).toList() ?? [],
            'coins_spent': g['coins_spent'],
            'created_at': g['created_at'],
          }).toList(),
    });
  });

  // ------------------------------------------------------------------
  // GELISTIRME UC NOKTALARI
  // ------------------------------------------------------------------
  // SADECE TEST ICIN. Uretimde (ENVIRONMENT=production) 404 doner.
  //
  // Neden 403 degil de 404? 403 "bu uc nokta var ama yetkin yok" der ve
  // saldirgana sistemin yapisi hakkinda bilgi verir. 404 ise ucun
  // varligini bile gizler.
  router.post('/dev/grant-all-cards', (Request request) async {
    if (Env.isProduction) {
      return jsonError('Boyle bir uc nokta yok.', status: 404);
    }

    final userId = requireUserId(request);
    final sonuc = await db.scalar(
      'select dev_grant_all_cards(@id::uuid)',
      params: {'id': userId},
    );
    return jsonOk(RowMappers.asMap(sonuc));
  });

  router.post('/dev/add-coins', (Request request) async {
    if (Env.isProduction) {
      return jsonError('Boyle bir uc nokta yok.', status: 404);
    }

    final userId = requireUserId(request);
    final body = await readJsonBody(request);
    final miktar = (body['amount'] as num?)?.toInt() ?? 10000;

    final sonuc = await db.scalar(
      'select dev_add_coins(@id::uuid, @miktar)',
      params: {'id': userId, 'miktar': miktar},
    );
    return jsonOk(RowMappers.asMap(sonuc));
  });

  // ------------------------------------------------------------------
  // DESTELER
  // ------------------------------------------------------------------
  router.get('/decks', (Request request) async {
    final userId = requireUserId(request);

    final desteler = await db.query(
      '''
      select d.id, d.name, d.is_active, d.created_at,
             count(dc.user_card_id) as card_count
      from decks d
      left join deck_cards dc on dc.deck_id = d.id
      where d.owner_id = @userId::uuid
      group by d.id
      order by d.is_active desc, d.created_at
      ''',
      params: {'userId': userId},
    );

    return jsonOk({
      'decks': desteler.map((d) => RowMappers.deck(d).toJson()).toList(),
    });
  });

  router.post('/decks', (Request request) async {
    final userId = requireUserId(request);
    final body = await readJsonBody(request);
    final name = (body['name'] as String?)?.trim();

    final deste = await db.queryOne(
      '''
      insert into decks (owner_id, name, is_active)
      values (@userId::uuid, coalesce(@name, 'Kadrom'), false)
      returning id, name, is_active
      ''',
      params: {
        'userId': userId,
        'name': (name == null || name.isEmpty) ? null : name,
      },
    );

    return jsonOk({
      'deck': RowMappers.deck({...deste!, 'card_count': 0}).toJson(),
    }, status: 201);
  });

  /// Destenin kartlarini toptan degistirir.
  /// Govde: { "user_card_ids": ["...", "..."], "set_active": true }
  router.put('/decks/<deckId>', (Request request, String deckId) async {
    final userId = requireUserId(request);
    final body = await readJsonBody(request);

    final ham = body['user_card_ids'];
    if (ham is! List) {
      throw const ApiException('user_card_ids alani bir liste olmali.');
    }
    final kartIdleri = ham.map((e) => e.toString()).toList();

    // Deste bu kullaniciya mi ait?
    final deste = await db.queryOne(
      'select id from decks where id = @deckId::uuid and owner_id = @userId::uuid',
      params: {'deckId': deckId, 'userId': userId},
    );
    if (deste == null) throw const ApiException.notFound('Deste bulunamadi.');

    // Kartlarin hepsi bu kullaniciya ait ve kilitsiz mi?
    if (kartIdleri.isNotEmpty) {
      final sayim = await db.queryOne(
        '''
        select count(*) filter (where owner_id = @userId::uuid and locked_match_id is null) as uygun,
               count(*) as toplam
        from user_cards
        where id = any(string_to_array(@ids, ',')::uuid[])
        ''',
        params: {'userId': userId, 'ids': kartIdleri.join(',')},
      );

      if (sayim!['toplam'] != kartIdleri.length) {
        throw const ApiException('Gonderilen kartlardan bazilari bulunamadi.');
      }
      if (sayim['uygun'] != kartIdleri.length) {
        throw const ApiException(
          'Kartlardan bazilari size ait degil veya devam eden bir macta kilitli.',
        );
      }
    }

    // Eski kartlari sil, yenilerini ekle
    await db.query(
      'delete from deck_cards where deck_id = @deckId::uuid',
      params: {'deckId': deckId},
    );

    if (kartIdleri.isNotEmpty) {
      // SLOT ATAMASI: Listenin SIRASI formasyondaki yeri belirler.
      //   0        -> kaleci
      //   1-4      -> defans
      //   5-8      -> orta saha
      //   9-10     -> forvet
      //
      // `with ordinality` her satira sira numarasi verir; 1'den
      // basladigi icin 1 cikariyoruz.
      //
      // Slottaki pozisyonun karta uygun olup olmadigini validate_deck()
      // kontrol ediyor; istemcinin gonderdigi siraya guvenmiyoruz.
      await db.query(
        '''
        insert into deck_cards (deck_id, user_card_id, slot_index)
        select @deckId::uuid, x.card_id, (x.ord - 1)::int
        from unnest(string_to_array(@ids, ',')::uuid[])
             with ordinality as x(card_id, ord)
        ''',
        params: {'deckId': deckId, 'ids': kartIdleri.join(',')},
      );
    }

    if (body['set_active'] == true) {
      await db.query(
        'update decks set is_active = (id = @deckId::uuid) where owner_id = @userId::uuid',
        params: {'deckId': deckId, 'userId': userId},
      );
    }

    // Kadro gecerli mi? (gecersizse hata degil, uyari doneriz)
    final hata = await db.scalar(
      'select validate_deck(@userId::uuid, @deckId::uuid)',
      params: {'userId': userId, 'deckId': deckId},
    );

    return jsonOk({
      'status': 'ok',
      'card_count': kartIdleri.length,
      'is_valid': hata == null,
      'validation_message': hata,
    });
  });

  router.get('/decks/<deckId>/validate', (Request request, String deckId) async {
    final userId = requireUserId(request);

    final hata = await db.scalar(
      'select validate_deck(@userId::uuid, @deckId::uuid)',
      params: {'userId': userId, 'deckId': deckId},
    );

    return jsonOk(
      DeckValidation(isValid: hata == null, message: hata as String?).toJson(),
    );
  });

  /// Destedeki kartlarin detayi
  router.get('/decks/<deckId>/cards', (Request request, String deckId) async {
    final userId = requireUserId(request);

    final kartlar = await db.query(
      '''
      select uc.id as user_card_id,
             dc.slot_index,
             c.id as card_id, c.slug, c.full_name, c.position, c.tier,
             c.power, c.nationality, c.league, c.club, c.image_url
      from deck_cards dc
      join decks d      on d.id = dc.deck_id
      join user_cards uc on uc.id = dc.user_card_id
      join cards c       on c.id = uc.card_id
      where dc.deck_id = @deckId::uuid and d.owner_id = @userId::uuid
      order by dc.slot_index nulls last, c.position, c.power desc
      ''',
      params: {'deckId': deckId, 'userId': userId},
    );

    // Slot numarasini da gonderiyoruz: kadro ekrani kartlari
    // formasyondaki dogru yerlerine yerlestirebilsin.
    return jsonOk({
      'cards': kartlar.map((r) {
        final json = RowMappers.inventoryCard(r).toJson();
        json['slot_index'] = r['slot_index'];
        return json;
      }).toList(),
    });
  });

  // ------------------------------------------------------------------
  // KADRO KIMYASI
  // ------------------------------------------------------------------
  // Kart basina kimya puani, bag renkleri ve takim toplami.
  //
  // Uygulama kadro kurarken kimyayi YEREL olarak da hesapliyor (anlik
  // onizleme icin). Bu uc nokta, kaydedilmis kadronun sunucudaki
  // GERCEK degerini doner; ikisi arasinda fark olusursa sunucu hakli.
  router.get('/decks/<deckId>/chemistry', (Request request, String deckId) async {
    final userId = requireUserId(request);

    final deste = await db.queryOne(
      'select id from decks where id = @deckId::uuid and owner_id = @userId::uuid',
      params: {'deckId': deckId, 'userId': userId},
    );
    if (deste == null) throw const ApiException.notFound('Deste bulunamadi.');

    final ozet = await db.scalar(
      'select deck_chemistry_summary(@deckId::uuid)',
      params: {'deckId': deckId},
    );

    return jsonOk(RowMappers.deckChemistry(ozet).toJson());
  });

  return router;
}
