import 'dart:io';

import 'package:shared_models/shared_models.dart';
import 'package:test/test.dart';

/// 025_character_catalog.sql ile ortak karakter modelleri.
void main() {
  test('oyun tarzı kodları veritabanı CHECK listesiyle BİREBİR aynı', () {
    final sql = File('../../database/migrations/025_character_catalog.sql')
        .readAsStringSync();
    final blok = RegExp(r"playstyle\s+text not null check \(playstyle in \(([^)]*)\)\)")
        .firstMatch(sql);
    expect(blok, isNotNull);
    final dbKodlari = RegExp(r"'([a-z_]+)'")
        .allMatches(blok!.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();
    expect(Playstyle.values.map((p) => p.code).toSet(), dbKodlari);
  });

  test('her mevkinin en az iki oyun tarzı var', () {
    for (final p in CardPosition.values) {
      expect(Playstyle.forPosition(p).length, greaterThanOrEqualTo(2), reason: p.name);
    }
  });

  test('karakter JSON gidiş-dönüş; Türkçe baş harfler', () {
    const c = Character(
      id: 'c1',
      slug: 'ilkan-sahin',
      catalogVersion: 'v2-ozgun',
      givenName: 'İlkan',
      familyName: 'Şahin',
      displayName: 'İlkan Şahin',
      regionCode: 'SLV',
      clubCode: 'LRF',
      primaryPosition: CardPosition.forward,
      playstyle: Playstyle.fastWinger,
      personality: ['sabırsız', 'cesur'],
      bioShort: 'kısa',
      bioLong: 'uzun',
      appearance: CharacterAppearance(
        skinTone: 'esmer',
        hair: 'kısa kıvırcık',
        face: 'keskin',
        build: 'atletik',
        accessory: 'bileklik',
        shirtNumber: 11,
      ),
      visualPrompt: 'tanım',
      createdBy: 'ai_assisted',
      generator: 'test',
    );
    final json = c.toJson();
    expect(json['primary_position'], 'FWD');
    expect(json['playstyle'], 'hizli_kanat');
    expect(json.containsKey('power'), isFalse, reason: 'Kimlikte güç YOK');
    expect(Character.fromJson(json), c);
    expect(c.initials, 'İŞ');
  });

  test('sunucu sunum cevabı okunur; eksikler listelenir', () {
    final p = CharacterPresentation.fromJson({
      'character_id': 'c1',
      'mode': '2.5d',
      'portrait_uri': null,
      'approved_clips': <String>[],
      'missing_clips': ['celebrate', 'shoot'],
      'missing_assets': ['portrait', 'model_glb', 'rig'],
    });
    expect(p.mode, PresentationMode.fallback25d);
    expect(p.hasPortrait, isFalse);
    expect(p.isFullyAnimated, isFalse);
    expect(p.missingAssets, contains('model_glb'));
  });

  test('sadece yayınlanmış karakter oynanabilir', () {
    expect(CharacterStatus.published.isPlayable, isTrue);
    for (final s in CharacterStatus.values.where((s) => s != CharacterStatus.published)) {
      expect(s.isPlayable, isFalse, reason: s.name);
    }
  });
}
