-- =====================================================================
-- 042 OGRETICI + 041 ANTRENMAN DUZELTMESI — TESTLER (GERI ALINIR)
-- =====================================================================
--  0 anahtar kapali / sirali kurallarda ogretici acilmaz
--  1 adim 1: surum 6, taktiksiz, 6 kartta bitis, ilk mevki oyuncuda, bot zayif
--  2 adimlar sirayla; 3. adim surum 7 (taktikli); bitince TEK Gumus sandik
--  3 ogretici odulsuz/puansiz; gecmise girmez; tamamlaninca tekrar baslamaz
--  4 sure asimiyla dusen oyuncunun adimi sayilmaz
--  5 041 duzeltmesi: antrenmanda KAZANAN oyuncu gelisim kopyasi ALMAZ;
--    dereceli macta alir
--  6 current_rules_version ogretici disinda 040 ile ayni
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

create function pg_temp.hata_bekle(p_ad text, p_sql text, p_mesaj text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if position(p_mesaj in sqlerrm) = 0 then
      raise exception 'TEST BASARISIZ: % -> beklenmeyen hata: %', p_ad, sqlerrm;
    end if;
    raise notice 'OK  % (reddedildi)', p_ad;
    return;
  end;
  raise exception 'TEST BASARISIZ: % -> hata bekleniyordu, ama kabul edildi', p_ad;
end;
$$;

create function pg_temp.oyuncu(p_ad text) returns uuid
language plpgsql as $$
declare u uuid;
begin
  insert into users (email, password_hash, username) values (p_ad || '@test.local', 'x', p_ad) returning id into u;
  perform grant_starter_pack(u);
  return u;
end;
$$;

create function pg_temp.deste(p_u uuid) returns uuid
language sql as $$ select id from decks where owner_id = p_u and is_active $$;

create function pg_temp.bayraklar(p_v int, p_json text) returns void
language sql as $$
  insert into economy_config_versions (kind, version, payload, note) values ('feature_flags', p_v, p_json::jsonb, 'test')
$$;

-- Insan en guclu kartini oynar (p_tur_siniri kadar tur; null = sonuna kadar);
-- bot bot_tick ile oynar.
create function pg_temp.oyna(p_match uuid, p_insan uuid, p_tur_siniri int default null) returns void
language plpgsql as $$
declare
  m matches%rowtype;
  v_pos card_position;
  v_kart uuid;
  i int := 0;
begin
  loop
    select * into m from matches where id = p_match;
    exit when m.status <> 'active' or i > 200;
    exit when p_tur_siniri is not null
          and (select count(*) from match_rounds where match_id = p_match) >= p_tur_siniri;
    i := i + 1;
    update matches set updated_at = now() - interval '1 minute' where id = p_match;
    if m.phase = 'position' and m.lead_player_id = p_insan then
      select h.position into v_pos from match_hands h
      where h.match_id = p_match and h.user_id = p_insan and not h.is_played
        and exists (select 1 from match_hands o where o.match_id = p_match and o.user_id <> p_insan
                    and not o.is_played and o.position = h.position)
      order by h.position limit 1;
      perform choose_position(p_insan, p_match, v_pos);
    elsif m.phase = 'pick' and not exists (select 1 from match_moves where match_id = p_match
                                            and round_number = m.round_number and user_id = p_insan) then
      select user_card_id into v_kart from match_hands
      where match_id = p_match and user_id = p_insan and not is_played and position = m.required_position
      order by power desc, user_card_id limit 1;
      perform play_card(p_insan, p_match, v_kart);
    else
      perform bot_tick();
    end if;
  end loop;
end;
$$;

alter table matches disable trigger trg_matches_updated_at;

do $$
declare
  h uuid; h2 uuid; h3 uuid; h4 uuid;
  r json;
  v_mac uuid;
  u_once users%rowtype; u_sonra users%rowtype;
  m matches%rowtype;
  v_ledger int;
  i int;
begin
  h := pg_temp.oyuncu('tu_h1');

  -- ================== 0) KAPALI ==================
  perform pg_temp.beklenen('tutorial_v1 kapali gelir', economy_flag('tutorial_v1'), false);
  perform pg_temp.beklenen('durum: kapali, adim 0', (tutorial_status(h) ->> 'enabled') || '/' || (tutorial_status(h) ->> 'step'), 'false/0');
  perform pg_temp.hata_bekle('kapaliyken baslamaz', format('select start_tutorial_match(%L, %L)', h, pg_temp.deste(h)), 'tutorial_disabled');
  perform pg_temp.bayraklar(990, '{"economy_v2_enabled": true, "ranked_rewards_v2": true, "duel_v4": false, "tutorial_v1": true}');
  perform pg_temp.beklenen('sirali kurallarda (surum 3) ogretici kapali', (tutorial_status(h) ->> 'enabled'), 'false');
  perform pg_temp.hata_bekle('sirali kurallarda baslamaz', format('select start_tutorial_match(%L, %L)', h, pg_temp.deste(h)), 'es zamanli');

  -- ================== 6) SURUM SECIMI DEGISMEDI ==================
  perform pg_temp.beklenen('ayar yokken surum 3 (040 ile ayni)', current_rules_version(), 3);
  perform set_config('futbol.rules_version_override', '', true);
  perform pg_temp.beklenen('bos ayar yok sayilir', current_rules_version(), 3);

  -- ================== 1) ADIM 1 ==================
  perform pg_temp.bayraklar(991, '{"economy_v2_enabled": true, "ranked_rewards_v2": true, "duel_v4": true, "tutorial_v1": true}');
  perform pg_temp.beklenen('es zamanli: ogretici acik, siradaki adim 1',
    (tutorial_status(h) ->> 'enabled') || '/' || (tutorial_status(h) ->> 'next_step'), 'true/1');
  select * into u_once from users where id = h;
  v_ledger := (select count(*) from economy_ledger where user_id = h);

  r := start_tutorial_match(h, pg_temp.deste(h));
  v_mac := (r ->> 'match_id')::uuid;
  select * into m from matches where id = v_mac;
  perform pg_temp.beklenen('adim 1 maci: ogretici, adim 1, surum 6', m.mode || ':' || m.tutorial_step || ':' || m.rules_version, 'tutorial:1:6');
  perform pg_temp.beklenen('ayar mac kurulduktan sonra sifirlandi', current_rules_version(), 4);
  perform pg_temp.beklenen('adim 1: ilk mevkiyi OYUNCU secer', m.lead_player_id::text || m.phase, h::text || 'position');
  perform pg_temp.beklenen('surum 6 taktiksiz, 6 kartta bitis, secim 30 sn',
    rules_tactics_enabled(6)::text || '/' || (select early_finish_cards || '/' || pick_seconds from game_rule_versions where version = 6), 'false/6/30');
  perform pg_temp.beklenen('ogretici botu ZAYIF (ortalama guc en az 3 dusuk)',
    (select avg(power) from match_hands where match_id = v_mac and user_id <> h) <=
    (select avg(power) from match_hands where match_id = v_mac and user_id = h) - 3, true);
  -- oyuncu mevkiyi secer, sonra taktikle oynamayi dener -> reddedilir
  select h2.position into m.required_position from match_hands h2
  where h2.match_id = v_mac and h2.user_id = h and not h2.is_played
    and exists (select 1 from match_hands o where o.match_id = v_mac and o.user_id <> h and o.position = h2.position)
  order by h2.position limit 1;
  perform choose_position(h, v_mac, m.required_position);
  -- enerji yetse bile taktik reddedilir: 042 korumasi
  update match_players set energy = 5 where match_id = v_mac and user_id = h;
  perform pg_temp.hata_bekle('adim 1/2 (surum 6) taktik kullanilamaz',
    format('select play_card(%L, %L, %L, %L)', h, v_mac,
           (select user_card_id from match_hands where match_id = v_mac and user_id = h and position = m.required_position limit 1),
           'high_press'), 'taktiksiz');
  perform pg_temp.beklenen('reddedilen taktikli hamle kaydedilmedi',
    (select count(*)::int from match_moves where match_id = v_mac and user_id = h), 0);
  perform pg_temp.oyna(v_mac, h);
  perform pg_temp.beklenen('adim 1 bitti', (select status::text from matches where id = v_mac), 'finished');
  -- Kısa maç: biri 6 karta ulaşınca biter. Beraberlikte kartlar masada
  -- birikir ve sonraki turu kazanan hepsini alır; bu yüzden skor 6'yı
  -- aşabilir (ör. 5 -> 8). Doğru ölçüt: 6'ya ulaşan var ya da kart kalmadı.
  perform pg_temp.beklenen('kisa mac: 6 karta ulasan olunca biter',
    (select greatest(p1_captured_count, p2_captured_count) >= 6
         or (select count(*) from match_hands where match_id = v_mac and not is_played) = 0 from matches where id = v_mac), true);
  perform pg_temp.beklenen('adim 1 tamamlandi', (tutorial_status(h) ->> 'step'), '1');

  -- ================== 2) ADIM 2 + 3 ==================
  r := start_tutorial_match(h, pg_temp.deste(h));
  v_mac := (r ->> 'match_id')::uuid;
  perform pg_temp.beklenen('adim 2: surum 6', (select tutorial_step || ':' || rules_version from matches where id = v_mac), '2:6');
  perform pg_temp.oyna(v_mac, h);
  perform pg_temp.beklenen('adim 2 tamamlandi', (tutorial_status(h) ->> 'step'), '2');
  perform pg_temp.beklenen('henuz sandik yok', (select count(*)::int from user_chests where user_id = h and source_type = 'tutorial'), 0);

  r := start_tutorial_match(h, pg_temp.deste(h));
  v_mac := (r ->> 'match_id')::uuid;
  perform pg_temp.beklenen('adim 3: surum 7 (taktikli)',
    (select tutorial_step || ':' || rules_version from matches where id = v_mac) || ':' || rules_tactics_enabled(7), '3:7:true');
  perform pg_temp.oyna(v_mac, h);
  perform pg_temp.beklenen('ogretici tamamlandi', (tutorial_status(h) ->> 'completed'), 'true');
  perform pg_temp.beklenen('3. adimda TEK Gumus sandik',
    (select string_agg(chest_type::text, ',') from user_chests where user_id = h and source_type = 'tutorial'), 'silver');
  perform pg_temp.beklenen('sandik hatasi yok', (select count(*)::int from economy_errors where context = 'tutorial_chest'), 0);

  -- ================== 3) ODULSUZ / TEKRAR YOK ==================
  select * into u_sonra from users where id = h;
  perform pg_temp.beklenen('ogretici: puan/altin/G-M-B degismedi',
    u_sonra.mmr || '/' || u_sonra.coins || '/' || u_sonra.wins || '/' || u_sonra.losses || '/' || u_sonra.draws,
    u_once.mmr || '/' || u_once.coins || '/' || u_once.wins || '/' || u_once.losses || '/' || u_once.draws);
  perform pg_temp.beklenen('ogretici maclarinda mac sandigi yok',
    (select count(*)::int from user_chests where user_id = h and source_type = 'match'), 0);
  perform pg_temp.beklenen('defterde yalniz ogretici sandigi (mac odulu yok)',
    (select count(*)::int from economy_ledger where user_id = h and source_type = 'match'), 0);
  perform pg_temp.beklenen('ogretici gecmise girmez', (select count(*)::int from get_match_history(h, 100, 0)), 0);
  perform pg_temp.hata_bekle('tamamlaninca tekrar baslamaz', format('select start_tutorial_match(%L, %L)', h, pg_temp.deste(h)), 'tutorial_done');

  -- ================== 4) SURE ASIMIYLA DUSEN SAYILMAZ ==================
  h2 := pg_temp.oyuncu('tu_h2');
  r := start_tutorial_match(h2, pg_temp.deste(h2));
  v_mac := (r ->> 'match_id')::uuid;
  for i in 1..60 loop
    exit when (select status from matches where id = v_mac) <> 'active';
    update matches set turn_deadline = now() - interval '1 second', updated_at = now() - interval '1 minute' where id = v_mac;
    perform bot_tick();
    perform advance_simultaneous_match(v_mac);
  end loop;
  perform pg_temp.beklenen('oyuncu hic oynamadi: mac bitti', (select status::text from matches where id = v_mac), 'finished');
  perform pg_temp.beklenen('sure asimiyla dusen oyuncunun adimi sayilmadi', (tutorial_status(h2) ->> 'step'), '0');

  -- ================== 5) 041 DUZELTMESI: ANTRENMAN GALIBIYETI KOPYA VERMEZ ==================
  perform pg_temp.bayraklar(992, '{"economy_v2_enabled": true, "ranked_rewards_v2": true, "duel_v4": true, "training_mode": true, "bots_v1": true}');
  h3 := pg_temp.oyuncu('tu_h3');
  r := start_training_match(h3, pg_temp.deste(h3));
  v_mac := (r ->> 'match_id')::uuid;
  perform pg_temp.oyna(v_mac, h3, 4);                       -- K6: en az 4 tur
  perform _finish_match(v_mac, h3);                          -- oyuncu KAZANDI
  perform pg_temp.beklenen('antrenman: oyuncu kazandi', (select winner_id from matches where id = v_mac), h3);
  perform pg_temp.beklenen('antrenman galibiyeti gelisim kopyasi VERMEZ',
    (select count(*)::int from economy_ledger where user_id = h3 and entry_type = 'win_progress_copy'), 0);

  -- Kontrol: ayni durum DERECELIDE kopya verir (tetikleyici calisiyor)
  h4 := pg_temp.oyuncu('tu_h4');
  insert into matchmaking_queue (user_id, deck_id, protected_card_ids, mmr, status, created_at)
  values (h4, pg_temp.deste(h4), '{}', 1000, 'searching', now() - interval '30 seconds');
  r := find_match_or_bot(h4, pg_temp.deste(h4), '{}');
  v_mac := (r ->> 'match_id')::uuid;
  perform pg_temp.beklenen('dereceli bot maci', (select mode from matches where id = v_mac), 'ranked');
  perform pg_temp.oyna(v_mac, h4, 4);
  perform _finish_match(v_mac, h4);
  perform pg_temp.beklenen('dereceli galibiyet gelisim kopyasi VERIR',
    (select count(*)::int from economy_ledger where user_id = h4 and entry_type = 'win_progress_copy'), 1);
end $$;

rollback;
