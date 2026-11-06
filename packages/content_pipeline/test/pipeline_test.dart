import 'dart:convert';
import 'dart:io';

import 'package:content_pipeline/content_pipeline.dart';
import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

const forvet = CatalogSlot(CardPosition.forward, CardTier.gold, 1);

const dunya = FictionalWorld(
  regionCode: 'SLV',
  regionName: 'Selvarra Kıyıları',
  leagueCode: 'SLV_L',
  leagueName: 'Selvarra Ligi',
  clubCode: 'LRF',
  clubName: 'Liman Rüzgârı FK',
  primaryColor: '#22D3EE',
  secondaryColor: '#0F172A',
);

Map<String, dynamic> gecerli() => {
      'given_name': 'Kaelen',
      'family_name': 'Brisvoy',
      'secondary_position': 'MID',
      'playstyle': 'hizli_kanat',
      'personality': ['sabırsız', 'cesur', 'şakacı'],
      'bio_short': 'Liman mahallesinin rüzgârla yarışan çocuğu.',
      'bio_long': 'Selvarra Kıyıları\'nın fırtınalı liman kasabasında, '
          'balıkçı teknelerinin arasında top sürerek büyüdü. Rüzgâra karşı '
          'koşmayı alışkanlık edindi.',
      'appearance': {
        'skin_tone': 'açık buğday',
        'hair': 'kısa, yanları kazınmış bakır rengi',
        'face': 'çilli, keskin çene',
        'build': 'ince ve uzun bacaklı',
        'accessory': 'turkuaz bileklik',
        'shirt_number': 17,
      },
      'visual_prompt': 'Stylized 3D mobile game footballer, lean sprinter, '
          'copper undercut hair, freckles, turquoise wristband.',
      'animation_profile': 'gosterisci',
    };

class SahteAg implements ClaudeTransport {
  final Map<String, dynamic> cevap;
  Map<String, dynamic>? sonGovde;
  Map<String, String>? sonBasliklar;
  SahteAg(this.cevap);

  @override
  Future<Map<String, dynamic>> send(Map<String, dynamic> body, Map<String, String> headers) async {
    sonGovde = body;
    sonBasliklar = headers;
    return cevap;
  }
}

Map<String, dynamic> modelCevabi(Map<String, dynamic> json) => {
      'stop_reason': 'end_turn',
      'content': [
        {'type': 'thinking', 'thinking': ''},
        {'type': 'text', 'text': jsonEncode(json)},
      ],
    };

void main() {
  final v = CharacterValidator();

  group('Doğrulayıcı: yapay zekâ GÜÇ BELİRLEYEMEZ', () {
    for (final alan in ['power', 'rating', 'tier', 'shooting', 'attributes']) {
      test('"$alan" gönderilirse reddedilir', () {
        final r = v.validate({...gecerli(), alan: 99}, forvet);
        expect(r.ok, isFalse);
        expect(r.errors.join(), contains('oyun değeri'));
      });
    }

    test('iç içe gizlenmiş güç de yakalanır', () {
      final ham = gecerli();
      (ham['appearance'] as Map)['power'] = 99;
      expect(v.validate(ham, forvet).errors.join(), contains('appearance.power'));
    });

    test('kimlik şemasında oyun değeri alanı YOK', () {
      final s = jsonEncode(identitySchema(CardPosition.forward));
      for (final yasak in ['power', 'tier', 'rating', 'shooting']) {
        expect(s, isNot(contains('"$yasak"')));
      }
    });
  });

  group('Doğrulayıcı: alanlar', () {
    test('geçerli kimlik geçer', () {
      final r = v.validate(gecerli(), forvet);
      expect(r.errors, isEmpty);
      expect(r.ok, isTrue);
    });

    test('beklenmeyen ve eksik alanlar reddedilir', () {
      expect(v.validate({...gecerli(), 'takma_ad': 'x'}, forvet).ok, isFalse);
      expect(v.validate(gecerli()..remove('bio_long'), forvet).ok, isFalse);
    });

    test('oyun tarzı mevkiye uymalı (stoper tarzı forvete olmaz)', () {
      final r = v.validate({...gecerli(), 'playstyle': 'kurt_stoper'}, forvet);
      expect(r.errors.join(), contains('uymuyor'));
    });

    test('ikincil mevki ana mevkiyle aynı olamaz', () {
      expect(v.validate({...gecerli(), 'secondary_position': 'FWD'}, forvet).ok, isFalse);
    });

    test('uzunluk, forma numarası ve kişilik sınırları', () {
      expect(v.validate({...gecerli(), 'bio_short': 'kısa'}, forvet).ok, isFalse);
      final g = gecerli();
      (g['appearance'] as Map)['shirt_number'] = 120;
      expect(v.validate(g, forvet).ok, isFalse);
      expect(v.validate({...gecerli(), 'personality': ['tek']}, forvet).ok, isFalse);
    });

    test('adda rakam/simge olamaz', () {
      expect(v.validate({...gecerli(), 'given_name': 'K4elen'}, forvet).ok, isFalse);
    });
  });

  group('Doğrulayıcı: gerçek kişi ve marka', () {
    test('mevcut katalogdaki gerçek Legend adları reddedilir', () {
      for (final (ad, soyad) in [('Diego', 'Maradona'), ('Johan', 'Cruyff'), ('Pele', 'Silva')]) {
        final r = v.validate({...gecerli(), 'given_name': ad, 'family_name': soyad}, forvet);
        expect(r.ok, isFalse, reason: '$ad $soyad');
      }
    });

    test('aksan ve küçük yazım hilesi yakalanır (Kylían Mbappé → mbappe)', () {
      final r = v.validate({...gecerli(), 'given_name': 'Kylían', 'family_name': 'Mbappé'}, forvet);
      expect(r.ok, isFalse);
    });

    test('bulanık benzerlik yakalanır (Lionell Messy)', () {
      final r = v.validate({...gecerli(), 'given_name': 'Lionell', 'family_name': 'Messy'}, forvet);
      expect(r.errors.join(), contains('benziyor'));
    });

    test('hikâyede ve görünüşte marka yakalanır', () {
      expect(v.validate({...gecerli(), 'bio_short': 'Çocukken Real Madrid formasıyla uyurdu.'}, forvet).ok, isFalse);
      final g = gecerli();
      (g['appearance'] as Map)['accessory'] = 'Nike bileklik';
      expect(v.validate(g, forvet).ok, isFalse);
    });

    test('katalogdaki adın aynısı reddedilir, çok benzeri uyarı verir', () {
      expect(v.validate(gecerli(), forvet, existingNames: ['Kaelen Brisvoy']).ok, isFalse);
      final r = v.validate(gecerli(), forvet, existingNames: ['Kaelen Brisvoi']);
      expect(r.ok, isTrue);
      expect(r.warnings, isNotEmpty);
    });

    test('normalize: Türkçe harfler', () {
      expect(normalizeName('İlkan ŞAHİN-Öz'), 'ilkan sahin oz');
    });
  });

  group('Denge Motoru', () {
    final e = BalanceEngine();

    test('deterministik: aynı girdi aynı değerler', () {
      final a = e.propose(characterId: 'x', slug: 'kaelen-brisvoy', slot: forvet, playstyle: Playstyle.fastWinger);
      final b = e.propose(characterId: 'x', slug: 'kaelen-brisvoy', slot: forvet, playstyle: Playstyle.fastWinger);
      expect(a, b);
    });

    test('güç seviyenin gerçek aralığında; bütün özellikler 1-99', () {
      for (final t in CardTier.values) {
        for (final p in CardPosition.values) {
          for (var i = 0; i < 40; i++) {
            final r = e.propose(
                characterId: 'x',
                slug: 'kisi-$i',
                slot: CatalogSlot(p, t, i),
                playstyle: Playstyle.forPosition(p).first);
            final (lo, hi) = BalanceEngine.tierRange[t]!;
            expect(r.power, inInclusiveRange(lo, hi));
            final a = r.attributes;
            for (final x in [a.shooting, a.pace, a.physical, a.defending, a.dribbling, a.acceleration]) {
              expect(x, inInclusiveRange(1, 99));
            }
          }
        }
      }
    });

    test('oyun tarzı şekilleri toplamı sıfır, her biri ±6 içinde (güç vermez)', () {
      for (final e in BalanceEngine.playstyleShape.entries) {
        expect(e.value.reduce((a, b) => a + b), 0, reason: e.key.name);
        expect(e.value.every((x) => x.abs() <= 6), isTrue, reason: e.key.name);
      }
      expect(BalanceEngine.playstyleShape.keys.toSet(), Playstyle.values.toSet());
    });

    test('tarz karakter verir: hızlı kanat, bitiriciden daha hızlı', () {
      double ort(Playstyle s, int Function(CardAttributes) f) {
        var t = 0;
        for (var i = 0; i < 200; i++) {
          t += f(e.propose(characterId: 'x', slug: 's$i', slot: forvet, playstyle: s).attributes);
        }
        return t / 200;
      }

      expect(ort(Playstyle.fastWinger, (a) => a.pace), greaterThan(ort(Playstyle.finisher, (a) => a.pace)));
      expect(ort(Playstyle.finisher, (a) => a.shooting), greaterThan(ort(Playstyle.fastWinger, (a) => a.shooting)));
    });

    test('mevkiye uymayan tarz reddedilir', () {
      expect(() => e.propose(characterId: 'x', slug: 's', slot: forvet, playstyle: Playstyle.stopper),
          throwsArgumentError);
    });

    test('profiller veritabanındaki 016 formülüyle aynı', () {
      final sql = File('../../database/migrations/016_card_attributes.sql').readAsStringSync();
      for (final e in BalanceEngine.positionProfile.entries) {
        final satir = "('${e.key.code}'::card_position, ${e.value.map((x) => x.toString().padLeft(4)).join(',')})";
        expect(sql.replaceAll(RegExp(r' +'), ' '),
            contains(satir.replaceAll(RegExp(r' +'), ' ')), reason: e.key.code);
      }
    });
  });

  group('Üretici (sahte ağ, ücretsiz)', () {
    test('istek: güncel model, JSON şema, yedek model, başlıklar', () async {
      final ag = SahteAg(modelCevabi(gecerli()));
      await CharacterGenerator(ag).generate(forvet, dunya, existingNames: ['A B']);
      final g = ag.sonGovde!;
      expect(g['model'], 'claude-opus-5-5');
      expect(g['fallbacks'], 'default');
      expect((g['output_config'] as Map)['format']['type'], 'json_schema');
      expect(ag.sonBasliklar!['anthropic-beta'], 'server-side-fallback-2026-07-01');
      expect(ag.sonBasliklar!['anthropic-version'], '2026-10-21');
      expect(jsonEncode(g), contains('Selvarra'));
    });

    test('düşünme bloğu atlanır, metin JSON okunur', () async {
      final r = await CharacterGenerator(SahteAg(modelCevabi(gecerli()))).generate(forvet, dunya);
      expect(r['given_name'], 'Kaelen');
    });

    test('ret (refusal) içerik okunmadan hata verir', () async {
      final ag = SahteAg({'stop_reason': 'refusal', 'stop_details': {'category': 'x'}, 'content': []});
      await expectLater(CharacterGenerator(ag).generate(forvet, dunya), throwsA(isA<GenerationRefused>()));
    });
  });

  group('Hat uçtan uca', () {
    final hat = CharacterPipeline();

    test('model güç gönderse bile karakter OLUŞMAZ', () async {
      final ham = await CharacterGenerator(SahteAg(modelCevabi({...gecerli(), 'power': 99})))
          .generate(forvet, dunya);
      final r = hat.process(ham,
          slot: forvet, world: dunya, characterId: 'id', catalogVersion: 'v2-ozgun',
          createdBy: 'ai', generator: 'claude');
      expect(r.ok, isFalse);
      expect(r.character, isNull);
      expect(r.proposal, isNull);
    });

    test('geçerli kimlik → taslak karakter + Denge Motoru önerisi + SQL', () {
      final r = hat.process(gecerli(),
          slot: forvet, world: dunya,
          characterId: '6b1f2c4e-0a3d-4f5e-9c7b-1d2e3f4a5b6c',
          catalogVersion: 'v2-ozgun', createdBy: 'ai_assisted', generator: 'test');
      expect(r.ok, isTrue);
      expect(r.character!.status, CharacterStatus.draft);
      expect(r.character!.slug, 'kaelen-brisvoy');
      expect(r.proposal!.tier, CardTier.gold);
      final sql = CharacterPipeline.toSql(r, dunya, note: 'test');
      expect(sql, contains("'draft'"));
      expect(sql, isNot(contains('insert into cards')), reason: 'Kartlara dokunmaz');
    });
  });
}
