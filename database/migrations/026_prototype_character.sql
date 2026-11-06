-- 026: ÖRNEK ÖZGÜN FORVET (tek karakter prototipi, Aşama A1)
-- Bu dosya packages/content_pipeline tarafından ÜRETİLDİ (elle düzenlemeyin).
-- Doğrulayıcı: geçti. Güç/özellikler: balance-v1. Durum: TASLAK.
-- Hiçbir karta (cards) bağlanmaz; oyunda görünmez.

insert into fictional_regions (code, name, catalog_version)
values ('SLV', 'Selvarra Kıyıları', 'v2-ozgun')
on conflict (code) do nothing;

insert into fictional_leagues (code, name, region_code, catalog_version)
values ('SLV_L', 'Selvarra Ligi', 'SLV', 'v2-ozgun')
on conflict (code) do nothing;

insert into fictional_clubs (code, name, league_code, primary_color, secondary_color, catalog_version)
values ('LRF', 'Liman Rüzgârı FK', 'SLV_L', '#22D3EE', '#0F172A', 'v2-ozgun')
on conflict (code) do nothing;

insert into characters (
  id, slug, catalog_version, given_name, family_name, display_name,
  region_code, club_code, primary_position, secondary_position, playstyle,
  personality, bio_short, bio_long, appearance, visual_prompt,
  animation_profile, status, created_by, generator, generator_model, prompt_version)
values (
  '6b1f2c4e-0a3d-4f5e-9c7b-1d2e3f4a5b6c', 'kaelen-brisvoy', 'v2-ozgun',
  'Kaelen', 'Brisvoy', 'Kaelen Brisvoy',
  'SLV', 'LRF', 'FWD',
  'MID', 'hizli_kanat',
  '["sabırsız","cesur","şakacı","takım ruhlu"]'::jsonb,
  'Liman mahallesinde rüzgâra karşı koşarak büyüyen, topu bırakmayan kanat.',
  'Selvarra Kıyıları''nın fırtınalı liman kasabası Tuzkapı''da, balıkçı teknelerinin arasındaki dar iskelelerde top sürerek büyüdü. Çocukken rüzgâra karşı koşma yarışlarını kimseye kaptırmazdı; mahalle onu bu yüzden ''Rüzgârkıran'' diye çağırır. Liman Rüzgârı FK''nın altyapısına on dört yaşında, bir maçta üç kez aynı stoperi geçtikten sonra alındı. Sabırsızdır, bazen pası geciktirip tek başına bitirmeye çalışır; ama kaybettiği her topun peşinden ilk koşan da odur.',
  '{"skin_tone":"açık buğday, güneşten hafif yanık","hair":"kısa, yanları kazınmış bakır rengi, tepede dağınık","face":"çilli, keskin çene hattı, gülümserken tek gamze","build":"ince, uzun bacaklı sprinter yapısı","accessory":"sol bilekte örgülü turkuaz ip bileklik","shirt_number":17}'::jsonb,
  'Original stylized 3D mobile game footballer character, lean long-legged sprinter build, light olive skin with a slight tan, short copper undercut hair messy on top, freckles, sharp jawline, single dimple when smiling, braided turquoise rope bracelet on left wrist, original kit in cyan and deep navy with no logos or real-world branding, number 17, confident playful expression, premium mobile game art style, clean silhouette, transparent background, full body front view.',
  'gosterisci', 'draft', 'ai_assisted', 'claude-code-oturumu (API cagrisi yok; hat dogrulamasindan gecti)',
  'claude-opus-5-5', 'kimlik-v1')
on conflict (slug) do nothing;

insert into character_card_proposals (
  character_id, tier, power, shooting, pace, physical, defending, dribbling,
  acceleration, slot, balance_engine_version)
values (
  '6b1f2c4e-0a3d-4f5e-9c7b-1d2e3f4a5b6c', 'gold', 83, 86, 95, 75,
  56, 89, 89, 'gold-FWD-1', 'balance-v1')
on conflict (character_id) do nothing;
