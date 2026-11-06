-- =====================================================================
-- 025 OZGUN KARAKTER KATALOGU — VERITABANI TESTLERI
-- =====================================================================
-- Tek islem icinde calisir, sonunda GERI ALINIR.
-- =====================================================================

begin;

create function pg_temp.beklenen(p_ad text, p_gercek anyelement, p_beklenen anyelement)
returns void language plpgsql as $$
begin
  if p_gercek is distinct from p_beklenen then
    raise exception 'TEST BASARISIZ: % -> beklenen %, gelen %', p_ad, p_beklenen, p_gercek;
  end if;
  raise notice 'OK  %', p_ad;
end;
$$;

-- Bir ifadenin VERITABANI tarafindan reddedildigini dogrular
create function pg_temp.reddedilmeli(p_ad text, p_sql text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    raise notice 'OK  % (reddedildi: %)', p_ad, sqlerrm;
    return;
  end;
  raise exception 'TEST BASARISIZ: % -> kabul edildi', p_ad;
end;
$$;

do $$
declare
  v_c   uuid;
  v_a   uuid;
  j     jsonb;
  v_ins text;
begin
  -- ================= 1) MEVCUT OYUN DEGISMEDI =================
  perform pg_temp.beklenen('her kartin kimligi arsivde',
    (select count(*) from cards), (select count(*) from cards_identity_archive));

  perform pg_temp.beklenen('arsiv ile kartlar birebir ayni (guc, mevki, seviye, ad)',
    (select count(*) from cards c join cards_identity_archive a on a.card_id = c.id
     where (c.slug, c.full_name, c.position, c.tier, c.power,
            coalesce(c.nationality, ''), coalesce(c.league, ''), coalesce(c.club, ''))
       is distinct from
           (a.slug, a.full_name, a.position, a.tier, a.power,
            coalesce(a.nationality, ''), coalesce(a.league, ''), coalesce(a.club, ''))),
    0::bigint);

  perform pg_temp.beklenen('hicbir karta karakter baglanmadi',
    (select count(*) from cards where character_id is not null), 0::bigint);

  -- ================= 2) YAPAY ZEKA GUC BELIRLEYEMEZ =================
  perform pg_temp.beklenen('characters tablosunda guc/ozellik sutunu YOK',
    (select count(*) from information_schema.columns
     where table_name = 'characters'
       and column_name in ('power', 'tier', 'shooting', 'pace', 'physical',
                           'defending', 'dribbling', 'acceleration')),
    0::bigint);

  -- ================= 3) KURGU DUNYA + KARAKTER KURALLARI =================
  insert into fictional_regions (code, name, catalog_version) values ('TST', 'Test Kiyilari', 'v2-ozgun');
  insert into fictional_leagues (code, name, region_code, catalog_version) values ('TST_L', 'Test Ligi', 'TST', 'v2-ozgun');
  insert into fictional_clubs (code, name, league_code, primary_color, secondary_color, catalog_version)
  values ('TST_C', 'Test Kulubu', 'TST_L', '#10B981', '#0A0C10', 'v2-ozgun');

  v_ins := $q$insert into characters (slug, catalog_version, given_name, family_name, display_name,
      region_code, club_code, primary_position, secondary_position, playstyle, personality,
      bio_short, bio_long, appearance, visual_prompt, animation_profile, created_by, generator)
    values (%L, 'v2-ozgun', 'Testa', 'Deneme', %L, 'TST', 'TST_C', 'FWD', %s, %L,
      '["sakin","hirsli"]', 'Kisa ama yeterince uzun bir test hikayesi burada.',
      repeat('Uzun hikaye cumlesi. ', 6), '{"sac":"kisa"}',
      repeat('Stilize 3B karakter tanimi. ', 3), 'dengeli', 'human', 'test')$q$;

  perform pg_temp.reddedilmeli('ikincil mevki birincille ayni olamaz',
    format(v_ins, 'tst-a', 'Testa A', '''FWD''', 'bitirici_golcu'));
  perform pg_temp.reddedilmeli('tanimsiz oyun tarzi reddedilir',
    format(v_ins, 'tst-b', 'Testa B', 'null', 'sihirli_tarz'));
  perform pg_temp.reddedilmeli('gecersiz slug reddedilir',
    format(v_ins, 'Tst B!', 'Testa C', 'null', 'bitirici_golcu'));

  execute format(v_ins, 'tst-ok', 'Testa Deneme', '''MID''', 'bitirici_golcu');
  select id into v_c from characters where slug = 'tst-ok';
  perform pg_temp.beklenen('gecerli karakter taslak olarak girer',
    (select status from characters where id = v_c), 'draft');

  -- ================= 4) INCELEME AKISI =================
  perform pg_temp.reddedilmeli('taslak dogrudan onaylanamaz',
    format('select review_character(%L, %L, %L)', v_c, 'approve', 'test'));
  perform review_character(v_c, 'submit', 'test');
  perform pg_temp.reddedilmeli('gerekcesiz ret reddedilir',
    format('select review_character(%L, %L, %L)', v_c, 'reject', 'test'));
  perform review_character(v_c, 'approve', 'test');
  perform pg_temp.reddedilmeli('Denge Motoru onerisi yokken yayin reddedilir',
    format('select review_character(%L, %L, %L)', v_c, 'publish', 'test'));
  perform pg_temp.beklenen('her adim inceleme kaydina yazildi',
    (select count(*) from content_review_log where entity_id = v_c), 2::bigint);

  -- ================= 5) VARLIKLAR =================
  perform pg_temp.reddedilmeli('lisanssiz varlik reddedilir',
    format($q$insert into character_assets (character_id, kind, version, uri, sha256, mime, generator, license)
              values (%L, 'portrait', 1, 'x/y.png', repeat('a', 64), 'image/png', 'test', '')$q$, v_c));
  perform pg_temp.reddedilmeli('adsiz animasyon klibi reddedilir',
    format($q$insert into character_assets (character_id, kind, version, uri, sha256, mime, generator, license)
              values (%L, 'anim_clip', 1, 'x/y.glb', repeat('a', 64), 'model/gltf-binary', 'test', 'CC0')$q$, v_c));

  -- Sunum modu: hic varlik yokken 2.5B yedek + eksikler listelenir
  j := character_presentation(v_c);
  perform pg_temp.beklenen('varlik yokken sunum modu 2.5B yedek', j->>'mode', '2.5d');
  perform pg_temp.beklenen('eksik varliklar listelenir',
    (j->'missing_assets')::text, '["portrait", "model_glb", "rig"]');
  perform pg_temp.beklenen('ana mevkinin (FWD) eksik klipleri listelenir',
    (j->'missing_clips')::text,
    (select jsonb_agg(clip_name order by clip_name)::text
     from animation_clip_requirements where position = 'FWD'));

  -- Onaylanmamis model 3B moda gecirmez
  insert into character_assets (character_id, kind, version, uri, sha256, mime, generator, license)
  values (v_c, 'model_glb', 1, 'models/test.glb', repeat('b', 64), 'model/gltf-binary', 'test', 'CC0');
  perform pg_temp.beklenen('ONAYSIZ model 3B moda gecirmez',
    character_presentation(v_c)->>'mode', '2.5d');

  -- Model + rig + butun klipler onayli -> 3B
  update character_assets set status = 'approved' where character_id = v_c and kind = 'model_glb';
  insert into character_assets (character_id, kind, version, uri, sha256, mime, generator, license, status)
  values (v_c, 'rig', 1, 'models/test-rig.glb', repeat('c', 64), 'model/gltf-binary', 'test', 'CC0', 'approved');
  insert into character_assets (character_id, kind, version, clip_name, uri, sha256, mime, generator, license, status)
  select v_c, 'anim_clip', 1, r.clip_name, 'anim/' || r.clip_name || '.glb',
         md5(r.clip_name) || md5(r.clip_name), 'model/gltf-binary', 'test', 'CC0', 'approved'
  from animation_clip_requirements r where r.position = 'MID';
  perform pg_temp.beklenen('BASKA mevkinin klipleri yetmez (ana mevki FWD)',
    character_presentation(v_c)->>'mode', '2.5d');
  insert into character_assets (character_id, kind, version, clip_name, uri, sha256, mime, generator, license, status)
  select v_c, 'anim_clip', 1, r.clip_name, 'anim/' || r.clip_name || '.glb',
         md5(r.clip_name || 'f') || md5(r.clip_name || 'f'), 'model/gltf-binary', 'test', 'CC0', 'approved'
  from animation_clip_requirements r
  where r.position = 'FWD'
    and r.clip_name not in (select clip_name from animation_clip_requirements where position = 'MID');
  perform pg_temp.beklenen('model + rig + butun klipler onayliyken 3B',
    character_presentation(v_c)->>'mode', '3d');

  -- Onayli varlik degistirilemez / silinemez
  select id into v_a from character_assets where character_id = v_c and kind = 'model_glb';
  perform pg_temp.reddedilmeli('onayli varligin dosyasi degistirilemez',
    format($q$update character_assets set uri = 'baska.glb' where id = %L$q$, v_a));
  perform pg_temp.reddedilmeli('onayli varlik silinemez',
    format($q$delete from character_assets where id = %L$q$, v_a));

  -- ================= 6) ORNEK KARAKTER (026) =================
  if to_regclass('character_card_proposals') is not null
     and exists (select 1 from characters where slug = 'kaelen-brisvoy') then
    perform pg_temp.beklenen('ornek forvet taslak katalogda',
      (select catalog_version from characters where slug = 'kaelen-brisvoy'), 'v2-ozgun');
    perform pg_temp.beklenen('ornek forvet hicbir karta bagli degil',
      (select count(*) from cards c join characters ch on ch.id = c.character_id
       where ch.slug = 'kaelen-brisvoy'), 0::bigint);
    perform pg_temp.beklenen('ornek forvetin Denge Motoru onerisi var',
      exists (select 1 from character_card_proposals p join characters ch on ch.id = p.character_id
              where ch.slug = 'kaelen-brisvoy'), true);
    perform pg_temp.beklenen('ornek forvetin portresi YOK (uydurulmadi)',
      character_presentation((select id from characters where slug = 'kaelen-brisvoy'))->>'portrait_uri',
      null::text);
  end if;

  raise notice '';
  raise notice 'TUM KARAKTER KATALOGU TESTLERI GECTI';
end;
$$;

rollback;
