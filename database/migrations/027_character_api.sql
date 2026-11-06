-- =====================================================================
-- 027: KARAKTER KARTI UCU (Asama A1 prototipi)
-- =====================================================================
-- GET /api/characters/<slug> bu fonksiyonu cagirir. Cevap, ortak
-- modellerle (shared_models: Character, CharacterCardProposal,
-- CharacterPresentation) birebir ayni alan adlarini kullanir.
--
-- Yayinlanmamis (taslak) karakterler SADECE p_allow_unpublished = true
-- iken doner; sunucu bunu yalnizca gelistirme ortaminda acar.
-- Oyuna ve kartlara dokunmaz (salt okuma).
-- =====================================================================

create or replace function get_character_card(
  p_slug              text,
  p_allow_unpublished boolean default false
)
returns jsonb
language plpgsql
stable
as $$
declare
  c   characters%rowtype;
  p   character_card_proposals%rowtype;
begin
  select * into c from characters where slug = p_slug;
  if not found or (c.status <> 'published' and not p_allow_unpublished) then
    raise exception 'Karakter bulunamadi.' using errcode = 'P0001';
  end if;

  select * into p from character_card_proposals where character_id = c.id;

  return jsonb_build_object(
    'character', jsonb_build_object(
      'id', c.id,
      'slug', c.slug,
      'catalog_version', c.catalog_version,
      'given_name', c.given_name,
      'family_name', c.family_name,
      'display_name', c.display_name,
      'region_code', c.region_code,
      'club_code', c.club_code,
      'primary_position', c.primary_position,
      'secondary_position', c.secondary_position,
      'playstyle', c.playstyle,
      'personality', c.personality,
      'bio_short', c.bio_short,
      'bio_long', c.bio_long,
      'appearance', c.appearance,
      'visual_prompt', c.visual_prompt,
      'animation_profile', c.animation_profile,
      'status', c.status,
      'created_by', c.created_by,
      'generator', c.generator,
      'generator_model', c.generator_model),
    'proposal', case when p.character_id is null then null else jsonb_build_object(
      'character_id', p.character_id,
      'tier', p.tier,
      'power', p.power,
      'attributes', jsonb_build_object(
        'shooting', p.shooting, 'pace', p.pace, 'physical', p.physical,
        'defending', p.defending, 'dribbling', p.dribbling,
        'acceleration', p.acceleration),
      'slot', p.slot,
      'balance_engine_version', p.balance_engine_version) end,
    'presentation', character_presentation(c.id),
    'club_name', (select name from fictional_clubs where code = c.club_code),
    'region_name', (select name from fictional_regions where code = c.region_code)
  );
end;
$$;
