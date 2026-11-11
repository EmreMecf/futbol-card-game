-- =====================================================================
-- 038 KAYNAKSIZ ITEMLERIN ODUL KAYNAKLARI — VERITABANI TESTLERI (GERI ALINIR)
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

-- Hazir (acilabilir) sandik ver ve ac
create function pg_temp.ac(p_user uuid, p_tur text, p_kaynak text, p_surum int default null) returns jsonb
language plpgsql as $$
declare
  ch uuid;
begin
  ch := _grant_chest(p_user, p_tur, 'test', p_kaynak);
  update user_chests set status = 'unlocking', unlock_started_at = now() - interval '1 day',
                         unlock_ready_at = now() - interval '1 second',
                         rules_version = coalesce(p_surum, rules_version)
  where id = ch and status = 'sealed';
  return open_chest(p_user, ch);
end;
$$;

do $$
declare
  u uuid; w uuid;
  r jsonb; r2 jsonb;
  i int; n_anahtar int := 0; n_kitap int := 0; n_ekstra int;
  ch uuid;
  altin int;
begin
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 987, '{"economy_v2_enabled": true, "item_sources_v2": false}', 'test');
  insert into users (email, password_hash, username) values ('kaynak-1@test.local', 'x', 'kaynak_1') returning id into u;
  insert into users (email, password_hash, username) values ('kaynak-2@test.local', 'x', 'kaynak_2') returning id into w;

  -- 0) Kurallar
  perform pg_temp.beklenen('chest_rules surum 2 aktif', economy_config_version('chest_rules'), 2);
  perform pg_temp.beklenen('surum 1 ekstrasiz kaldi (degismedi)',
    (select payload ? 'extras' from economy_config_versions where kind = 'chest_rules' and version = 1), false);
  perform pg_temp.beklenen('etkinlik bileti pasif', (select is_active from item_definitions where slug = 'event_ticket'), false);
  perform pg_temp.beklenen('etkinlik bileti katalogda gorunmez', exists (
    select 1 from jsonb_array_elements(item_inventory(u) -> 'catalog') x where x ->> 'slug' = 'event_ticket'), false);

  -- 1) Anahtar KAPALI: Efsane sandik hic ekstra vermez
  n_ekstra := 0;
  for i in 1..30 loop
    r := pg_temp.ac(u, 'legend', 'kapali-' || i);
    n_ekstra := n_ekstra + (select count(*) from jsonb_object_keys(r -> 'extras'));
  end loop;
  perform pg_temp.beklenen('anahtar kapali: 30 Efsane sandikta ekstra yok', n_ekstra, 0);

  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 988, '{"economy_v2_enabled": true, "item_sources_v2": true}', 'test');

  -- 2) Eski surumlu sandik (rules_version 1) anahtar acikken de ekstrasiz
  n_ekstra := 0;
  for i in 1..30 loop
    r := pg_temp.ac(u, 'legend', 'eski-' || i, 1);
    n_ekstra := n_ekstra + (select count(*) from jsonb_object_keys(r -> 'extras'));
  end loop;
  perform pg_temp.beklenen('eski surum sandik: ekstra yok', n_ekstra, 0);

  -- 3) Efsane sandik: anahtar %40, kitap %30 (300 sandik, genis tolerans)
  for i in 1..300 loop
    r := pg_temp.ac(w, 'legend', 'efsane-' || i);
    if r -> 'extras' ? 'chest_key' then n_anahtar := n_anahtar + 1; end if;
    if exists (select 1 from jsonb_object_keys(r -> 'extras') k where k like 'mastery_book_%') then
      n_kitap := n_kitap + 1;
    end if;
  end loop;
  raise notice 'Efsane x300: anahtar %, kitap %', n_anahtar, n_kitap;
  perform pg_temp.beklenen('anahtar orani ~%40 (300 sandik, 90-150)', n_anahtar between 90 and 150, true);
  perform pg_temp.beklenen('kitap orani ~%30 (300 sandik, 60-120)', n_kitap between 60 and 120, true);
  perform pg_temp.beklenen('Altin kitap sandiktan gelmez (BP kaynakli)',
    (select count(*)::int from economy_ledger where user_id = w and entry_type = 'item_grant'
       and items ->> 'slug' = 'mastery_book_gold'), 0);
  perform pg_temp.beklenen('anahtar yigin siniri 10 (tasan altina)', _item_qty(w, 'chest_key'), 10);
  perform pg_temp.beklenen('tasan anahtarlar altin olarak deftere', (select count(*)::int from economy_ledger
    where user_id = w and entry_type = 'item_grant' and items ->> 'slug' = 'chest_key' and coins_delta > 0) > 0, true);
  perform pg_temp.beklenen('her kitap nadirligi kaynakli', (select count(distinct items ->> 'slug')::int from economy_ledger
    where user_id = w and entry_type = 'item_grant' and items ->> 'slug' like 'mastery_book_%') >= 3, true);

  -- 4) Ayni sandigi tekrar acmak ekstrayi tekrar vermez
  ch := _grant_chest(u, 'legend', 'test', 'tekrar');
  update user_chests set status = 'unlocking', unlock_ready_at = now() - interval '1 second' where id = ch;
  r := open_chest(u, ch);
  altin := (select coins from users where id = u);
  r2 := open_chest(u, ch);
  perform pg_temp.beklenen('tekrar acilis ayni sonuc', r2 -> 'extras', r -> 'extras');
  perform pg_temp.beklenen('tekrar acilis altin vermez', (select coins from users where id = u), altin);
  perform pg_temp.beklenen('ekstra defterde tek', (select count(*)::int from economy_ledger
    where idempotency_key like 'item_grant:chest_extra:' || ch || ':%'), (select count(*)::int from jsonb_object_keys(r -> 'extras')));

  -- 5) Altin sandik yalniz anahtar (%10) verir, kitap vermez
  n_kitap := 0;
  for i in 1..60 loop
    r := pg_temp.ac(u, 'gold', 'altin-' || i);
    if exists (select 1 from jsonb_object_keys(r -> 'extras') k where k like 'mastery_book_%') then n_kitap := n_kitap + 1; end if;
  end loop;
  perform pg_temp.beklenen('Altin sandik kitap vermez', n_kitap, 0);
  perform pg_temp.beklenen('Gumus sandik ekstra vermez',
    (select count(*) from jsonb_object_keys(pg_temp.ac(u, 'silver', 'gumus-1') -> 'extras'))::int, 0);

  -- 6) Haftalik 10 galibiyet -> gelisim indirimi, tek sefer
  perform pg_temp.beklenen('gorev odulu tanimli', _mission_reward_items('weekly_win_10') ->> 'level_discount_25', '1');
  for i in 1..12 loop perform _mission_event(u, 'match_won', 1); end loop;
  perform pg_temp.beklenen('10 galibiyet: 1 gelisim indirimi', _item_qty(u, 'level_discount_25'), 1);
  perform pg_temp.beklenen('indirim 7 gun gecerli', exists (select 1 from user_items where user_id = u
    and item_slug = 'level_discount_25' and expires_at between now() + interval '6 days 23 hours' and now() + interval '7 days 1 hour'), true);

  -- Anahtar kapaliyken gorev itemi verilmez (XP aynen)
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 989, '{"economy_v2_enabled": true, "item_sources_v2": false}', 'test');
  for i in 1..10 loop perform _mission_event(w, 'match_won', 1); end loop;
  perform pg_temp.beklenen('anahtar kapali: gorev tamam ama indirim yok', _item_qty(w, 'level_discount_25'), 0);
  perform pg_temp.beklenen('anahtar kapali: gorev XP''si verildi', (select count(*)::int from economy_ledger
    where user_id = w and entry_type = 'season_xp' and source_type = 'mission'
      and source_id like 'weekly_win_10:%'), 1);

  raise notice '038 item kaynaklari testleri: HEPSI GECTI';
end;
$$;

rollback;
