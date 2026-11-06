import 'dart:convert';

import 'package:shared_models/shared_models.dart';

import 'balance_engine.dart';
import 'blocklist.dart';
import 'catalog_slot.dart';
import 'generator.dart';
import 'validator.dart';

/// Hattın bir karakter için çıktısı
class PipelineResult {
  final ValidationResult validation;
  final Character? character;
  final CharacterCardProposal? proposal;

  const PipelineResult(this.validation, this.character, this.proposal);

  bool get ok => validation.ok;
}

/// Üret → doğrula → dengele → (taslak) katalog kaydı.
///
/// Çıktı her zaman TASLAK'tır (status: draft). Yayın için 025'teki
/// review_character akışı ve insan onayı gerekir.
class CharacterPipeline {
  final CharacterValidator validator;
  final BalanceEngine engine;

  CharacterPipeline({CharacterValidator? validator, BalanceEngine? engine})
      : validator = validator ?? CharacterValidator(),
        engine = engine ?? BalanceEngine();

  /// Yapay zekâdan (ya da elle) gelmiş ham kimliği işler.
  PipelineResult process(
    Map<String, dynamic> raw, {
    required CatalogSlot slot,
    required FictionalWorld world,
    required String characterId,
    required String catalogVersion,
    required String createdBy,
    required String generator,
    String? generatorModel,
    List<String> existingNames = const [],
  }) {
    final v = validator.validate(raw, slot, existingNames: existingNames);
    if (!v.ok) return PipelineResult(v, null, null);
    final c = v.clean!;

    final ad = c['given_name'] as String;
    final soyad = c['family_name'] as String;
    final slug = normalizeName('$ad $soyad').replaceAll(' ', '-');
    final tarz = Playstyle.tryParse(c['playstyle'] as String)!;
    final g = c['appearance'] as Map;

    final karakter = Character(
      id: characterId,
      slug: slug,
      catalogVersion: catalogVersion,
      givenName: ad,
      familyName: soyad,
      displayName: '$ad $soyad',
      regionCode: world.regionCode,
      clubCode: world.clubCode,
      primaryPosition: slot.position,
      secondaryPosition: c['secondary_position'] == null
          ? null
          : CardPosition.fromCode(c['secondary_position'] as String),
      playstyle: tarz,
      personality: (c['personality'] as List).cast<String>(),
      bioShort: c['bio_short'] as String,
      bioLong: c['bio_long'] as String,
      appearance: CharacterAppearance(
        skinTone: g['skin_tone'] as String,
        hair: g['hair'] as String,
        face: g['face'] as String,
        build: g['build'] as String,
        accessory: g['accessory'] as String,
        shirtNumber: g['shirt_number'] as int,
      ),
      visualPrompt: c['visual_prompt'] as String,
      animationProfile: AnimationProfile.values.firstWhere(
          (p) => _profilKodu(p) == c['animation_profile']),
      status: CharacterStatus.draft,
      createdBy: createdBy,
      generator: generator,
      generatorModel: generatorModel,
    );

    final oneri = engine.propose(
        characterId: characterId, slug: slug, slot: slot, playstyle: tarz);
    return PipelineResult(v, karakter, oneri);
  }

  static String _profilKodu(AnimationProfile p) => switch (p) {
        AnimationProfile.calm => 'sakin',
        AnimationProfile.balanced => 'dengeli',
        AnimationProfile.showman => 'gosterisci',
        AnimationProfile.leader => 'lider',
      };

  // ------------------------------------------------------------------
  // KATALOG SQL'İ (taslak migration)
  // ------------------------------------------------------------------
  static String _q(String? s) =>
      s == null ? 'null' : "'${s.replaceAll("'", "''")}'";

  /// Taslak katalog SQL'i: kurgu dünya + karakter + Denge Motoru önerisi.
  /// `on conflict do nothing`: tekrar çalıştırılabilir. KARTLARA dokunmaz.
  static String toSql(PipelineResult r, FictionalWorld w, {required String note}) {
    final c = r.character!;
    final p = r.proposal!;
    final a = p.attributes;
    final g = c.appearance;
    final gorunus = jsonEncode({
      'skin_tone': g.skinTone,
      'hair': g.hair,
      'face': g.face,
      'build': g.build,
      'accessory': g.accessory,
      'shirt_number': g.shirtNumber,
    });
    return '''
-- $note
-- Bu dosya packages/content_pipeline tarafından ÜRETİLDİ (elle düzenlemeyin).
-- Doğrulayıcı: geçti. Güç/özellikler: ${BalanceEngine.version}. Durum: TASLAK.
-- Hiçbir karta (cards) bağlanmaz; oyunda görünmez.

insert into fictional_regions (code, name, catalog_version)
values (${_q(w.regionCode)}, ${_q(w.regionName)}, ${_q(c.catalogVersion)})
on conflict (code) do nothing;

insert into fictional_leagues (code, name, region_code, catalog_version)
values (${_q(w.leagueCode)}, ${_q(w.leagueName)}, ${_q(w.regionCode)}, ${_q(c.catalogVersion)})
on conflict (code) do nothing;

insert into fictional_clubs (code, name, league_code, primary_color, secondary_color, catalog_version)
values (${_q(w.clubCode)}, ${_q(w.clubName)}, ${_q(w.leagueCode)}, ${_q(w.primaryColor)}, ${_q(w.secondaryColor)}, ${_q(c.catalogVersion)})
on conflict (code) do nothing;

insert into characters (
  id, slug, catalog_version, given_name, family_name, display_name,
  region_code, club_code, primary_position, secondary_position, playstyle,
  personality, bio_short, bio_long, appearance, visual_prompt,
  animation_profile, status, created_by, generator, generator_model, prompt_version)
values (
  ${_q(c.id)}, ${_q(c.slug)}, ${_q(c.catalogVersion)},
  ${_q(c.givenName)}, ${_q(c.familyName)}, ${_q(c.displayName)},
  ${_q(c.regionCode)}, ${_q(c.clubCode)}, ${_q(c.primaryPosition.code)},
  ${c.secondaryPosition == null ? 'null' : _q(c.secondaryPosition!.code)}, ${_q(c.playstyle.code)},
  ${_q(jsonEncode(c.personality))}::jsonb,
  ${_q(c.bioShort)},
  ${_q(c.bioLong)},
  ${_q(gorunus)}::jsonb,
  ${_q(c.visualPrompt)},
  ${_q(_profilKodu(c.animationProfile))}, 'draft', ${_q(c.createdBy)}, ${_q(c.generator)},
  ${_q(c.generatorModel)}, ${_q(CharacterGenerator.promptVersion)})
on conflict (slug) do nothing;

insert into character_card_proposals (
  character_id, tier, power, shooting, pace, physical, defending, dribbling,
  acceleration, slot, balance_engine_version)
values (
  ${_q(c.id)}, ${_q(p.tier.code)}, ${p.power}, ${a.shooting}, ${a.pace}, ${a.physical},
  ${a.defending}, ${a.dribbling}, ${a.acceleration}, ${_q(p.slot)}, ${_q(p.balanceEngineVersion)})
on conflict (character_id) do nothing;
''';
  }
}
