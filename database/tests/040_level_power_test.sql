-- =====================================================================
-- 040 KURAL SURUMU 5 (SEVIYE GUCU B2 + ETKIN GUCE GORE ESLESTIRME +
-- LIG TAVANI) — KABUL TESTLERI (GERI ALINIR)
-- =====================================================================
-- docs/V3_UYGULAMA_VE_STAGING_PLANI.md §5'teki 7 kabul sarti:
--   1 anahtar kapali -> deck_power / el gucu / eslestirme bugunkuyle ayni
--   2 bonus tek kaynaktan (deck_power = maca giren el)
--   3 mac ortasinda seviye atlama eli degistirmez
--   4 lig tavani mac kurulurken (sonra lig degisse de el ayni)
--   5 Efsane kurali (+3 bonuslu Elmas Efsane'yi yenemez)
--   6 'combined' eslestirme etkin gucle
--   7 eski maclar (surum 1-4) bonus gormez
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

create function pg_temp.oyuncu(p_ad text, p_mmr int) returns uuid
language plpgsql as $$
declare u uuid;
begin
  insert into users (email, password_hash, username, mmr)
  values (p_ad || '@test.local', 'x', p_ad, p_mmr) returning id into u;
  perform grant_starter_pack(u);
  return u;
end;
$$;

create function pg_temp.deste(p_u uuid) returns uuid
language sql as $$ select id from decks where owner_id = p_u and is_active $$;

create function pg_temp.mac(p_a uuid, p_b uuid) returns uuid
language sql as $$
  select _create_match(p_a, pg_temp.deste(p_a), '{}', p_b, pg_temp.deste(p_b), '{}')
$$;

-- Destedeki her futbolcuyu verilen seviyeye getirir (yalniz bu islemde)
create function pg_temp.seviye(p_u uuid, p_level int) returns void
language sql as $$
  insert into player_progress (user_id, card_id, level)
  select distinct p_u, uc.card_id, p_level
  from deck_cards dc join user_cards uc on uc.id = dc.user_card_id
  where dc.deck_id = pg_temp.deste(p_u)
  on conflict (user_id, card_id) do update set level = excluded.level
$$;

-- 024'teki deck_power formulu (bonussuz): anahtar kapaliyken ayni olmali
create function pg_temp.deck_power_024(p_deck uuid) returns numeric
language sql as $$
  select round(avg(c.power + coalesce(ch.chemistry, 0))::numeric, 2)
  from deck_cards dc
  join user_cards uc on uc.id = dc.user_card_id
  join cards c on c.id = uc.card_id
  left join calculate_deck_chemistry(p_deck) ch on ch.user_card_id = dc.user_card_id
  where dc.deck_id = p_deck
$$;

-- Bir oyuncunun elinde katalog gucunden farki olan kart sayisi
create function pg_temp.bonuslu_kart(p_match uuid, p_u uuid) returns int
language sql as $$
  select count(*)::int from match_hands h join cards c on c.id = h.card_id
  where h.match_id = p_match and h.user_id = p_u and h.power <> c.power
$$;

create function pg_temp.el_farki(p_match uuid, p_u uuid) returns text
language sql as $$
  select string_agg(distinct (h.power - c.power)::text, ',')
  from match_hands h join cards c on c.id = h.card_id
  where h.match_id = p_match and h.user_id = p_u
$$;

do $$
declare
  a uuid; b uuid;
  v_eski2 uuid; v_eski4 uuid; v_mac uuid; v_mac2 uuid;
  v_dp_kapali numeric; v_dp_acik numeric;
  m matches%rowtype;
  v_pos card_position;
  k_elmas uuid; k_efsane uuid;
  sahip_elmas uuid;
  n int;
begin
  -- Usta-ustu puan: Master (tavan 10); B seviye 1
  a := pg_temp.oyuncu('sv_a', 1900);
  b := pg_temp.oyuncu('sv_b', 1900);
  perform pg_temp.seviye(a, 10);

  -- ================== 0) VARSAYILAN KAPALI ==================
  perform pg_temp.beklenen('migration anahtari kapali getirir',
    coalesce((economy_config('feature_flags') ->> 'card_level_power')::boolean, false), false);
  perform pg_temp.beklenen('B2: seviye 1-10',
    (select string_agg(level_power_bonus(i)::text, ',' order by i) from generate_series(1, 10) i),
    '0,0,0,1,1,1,2,2,2,3');
  perform pg_temp.beklenen('lig tavani amator/usta/master/master class',
    league_level_cap(1000) || ',' || league_level_cap(1300) || ',' || league_level_cap(1625) || ',' || league_level_cap(2475),
    '4,7,10,10');
  perform pg_temp.beklenen('baslangic puaninin altinda da amator tavani', league_level_cap(500), 4);

  -- ================== 1) ANAHTAR KAPALI: BUGUNKU DAVRANIS ==================
  perform pg_temp.beklenen('kapali: surum 2', current_rules_version(), 2);
  perform pg_temp.beklenen('kapali: deck_power 024 ile ayni (seviye 10 olsa da)',
    deck_power(pg_temp.deste(a)), pg_temp.deck_power_024(pg_temp.deste(a)));
  perform pg_temp.beklenen('kapali: eslestirme modu ayarda kalir (mmr)', matchmaking_mode(), 'mmr');
  v_eski2 := pg_temp.mac(a, b);
  perform pg_temp.beklenen('kapali: mac surum 2', (select rules_version from matches where id = v_eski2), 2);
  perform pg_temp.beklenen('kapali: el gucu katalogla ayni', pg_temp.bonuslu_kart(v_eski2, a), 0);

  -- duel_v4 acik, card_level_power kapali -> surum 4, bonus yok
  insert into economy_config_versions (kind, version, payload, note) values
    ('feature_flags', 990, '{"economy_v2_enabled": true, "ranked_rewards_v2": true, "duel_v4": true, "card_level_power": false}', 'test');
  perform pg_temp.beklenen('yalniz duel_v4: surum 4', current_rules_version(), 4);
  perform pg_temp.beklenen('surum 4: deck_power ayni', deck_power(pg_temp.deste(a)), pg_temp.deck_power_024(pg_temp.deste(a)));
  perform pg_temp.beklenen('surum 4: eslestirme mmr', matchmaking_mode(), 'mmr');
  v_eski4 := pg_temp.mac(a, b);
  perform pg_temp.beklenen('surum 4 mac', (select rules_version from matches where id = v_eski4), 4);
  perform pg_temp.beklenen('surum 4: el gucu katalogla ayni', pg_temp.bonuslu_kart(v_eski4, a), 0);

  -- Anahtar tek basina surum 5 acmaz (duel_v4 olmadan)
  insert into economy_config_versions (kind, version, payload, note) values
    ('feature_flags', 991, '{"economy_v2_enabled": true, "ranked_rewards_v2": true, "duel_v4": false, "card_level_power": true}', 'test');
  perform pg_temp.beklenen('duel_v4 kapaliyken seviye gucu ACILMAZ', current_rules_version(), 3);
  perform pg_temp.beklenen('surum 3: deck_power ayni', deck_power(pg_temp.deste(a)), pg_temp.deck_power_024(pg_temp.deste(a)));

  -- ================== 2) SURUM 5: BONUS TEK KAYNAKTAN ==================
  insert into economy_config_versions (kind, version, payload, note) values
    ('feature_flags', 992, '{"economy_v2_enabled": true, "ranked_rewards_v2": true, "duel_v4": true, "card_level_power": true}', 'test');
  perform pg_temp.beklenen('dort anahtar acik: surum 5', current_rules_version(), 5);
  perform pg_temp.beklenen('surum 5 es zamanli akisi korur', rules_simultaneous(5), true);
  perform pg_temp.beklenen('surum 5 duvar 2 enerji', tactic_cost_for(5, 'defensive_wall'), 2);
  perform pg_temp.beklenen('surum 5 kart transferi yok', rules_card_transfer(5), false);

  v_dp_kapali := pg_temp.deck_power_024(pg_temp.deste(a));
  v_dp_acik := deck_power(pg_temp.deste(a));
  perform pg_temp.beklenen('seviye 10 Master: deck_power +3', v_dp_acik, v_dp_kapali + 3);
  perform pg_temp.beklenen('seviye 1 rakip: deck_power ayni',
    deck_power(pg_temp.deste(b)), pg_temp.deck_power_024(pg_temp.deste(b)));

  v_mac := pg_temp.mac(a, b);
  select * into m from matches where id = v_mac;
  perform pg_temp.beklenen('yeni mac surum 5, mevki asamasi', m.rules_version::text || m.phase, '5position');
  perform pg_temp.beklenen('seviye 10 Master: her kartta +3', pg_temp.el_farki(v_mac, a), '3');
  perform pg_temp.beklenen('seviye 1: bonus yok', pg_temp.el_farki(v_mac, b), '0');
  perform pg_temp.beklenen('deck_power = maca giren el (guc + kimya)',
    (select round(avg(power + coalesce(chemistry, 0))::numeric, 2) from match_hands where match_id = v_mac and user_id = a),
    v_dp_acik);
  perform pg_temp.beklenen('bonus kaydi her el karti icin',
    (select count(*)::int from match_hand_level_bonus where match_id = v_mac),
    (select count(*)::int from match_hands where match_id = v_mac));
  perform pg_temp.beklenen('bonus kaydi: seviye/tavan/bonus',
    (select string_agg(distinct level || '/' || level_cap || '/' || bonus, ',') from match_hand_level_bonus where match_id = v_mac and user_id = a),
    '10/10/3');
  perform pg_temp.beklenen('bonus kaydi temel gucu katalogdan',
    (select count(*)::int from match_hand_level_bonus x join cards c on c.id = x.card_id
      where x.match_id = v_mac and x.base_power <> c.power), 0);

  -- ================== 3) MAC ORTASINDA SEVIYE / 4) LIG DEGISIMI ==================
  update player_progress set level = 1 where user_id = a;
  update users set mmr = 1000 where id = a;
  perform pg_temp.beklenen('mac icinde seviye/lig degisti: el ayni', pg_temp.el_farki(v_mac, a), '3');

  -- Lig tavani yeni macta: seviye 10 Amator'de +1, Usta'da +2
  perform pg_temp.seviye(a, 10);
  update users set mmr = 1000 where id = a;
  v_mac2 := pg_temp.mac(a, b);
  perform pg_temp.beklenen('Amator (tavan 4): seviye 10 -> +1', pg_temp.el_farki(v_mac2, a), '1');
  perform pg_temp.beklenen('Amator deck_power +1', deck_power(pg_temp.deste(a)), pg_temp.deck_power_024(pg_temp.deste(a)) + 1);
  update users set mmr = 1400 where id = a;
  v_mac2 := pg_temp.mac(a, b);
  perform pg_temp.beklenen('Usta (tavan 7): seviye 10 -> +2', pg_temp.el_farki(v_mac2, a), '2');
  perform pg_temp.seviye(a, 5);
  v_mac2 := pg_temp.mac(a, b);
  perform pg_temp.beklenen('Usta, seviye 5 (tavan alti) -> +1', pg_temp.el_farki(v_mac2, a), '1');

  -- Yalniz bir futbolcu seviyeli: bonus yalniz o karta
  update player_progress set level = 1 where user_id = a;
  update player_progress set level = 10
  where user_id = a and card_id = (select uc.card_id from deck_cards dc join user_cards uc on uc.id = dc.user_card_id
                                   where dc.deck_id = pg_temp.deste(a) order by uc.card_id limit 1);
  v_mac2 := pg_temp.mac(a, b);
  -- (baslangic paketinde ayni futbolcudan iki kopya olabilir: ikisi de o futbolcu)
  perform pg_temp.beklenen('tek seviyeli futbolcu: yalniz onun kartlari bonuslu',
    pg_temp.bonuslu_kart(v_mac2, a),
    (select count(*)::int from match_hands h join player_progress p on p.user_id = a and p.card_id = h.card_id
      where h.match_id = v_mac2 and h.user_id = a and p.level = 10));
  perform pg_temp.beklenen('tek seviyeli futbolcu: en az bir kart', pg_temp.bonuslu_kart(v_mac2, a) >= 1, true);

  -- ================== 5) EFSANE KURALI ==================
  -- v_mac: A her kartta +3. Ortak mevkide A'nin kartini Elmas 99, B'ninkini
  -- Efsane 1 yap (yalniz test icin), ikisi de oynasin: Efsane kazanir.
  select h.position into v_pos from match_hands h
  where h.match_id = v_mac and h.user_id = m.lead_player_id
    and exists (select 1 from match_hands o where o.match_id = v_mac and o.user_id <> m.lead_player_id and o.position = h.position)
  order by h.position limit 1;
  perform choose_position(m.lead_player_id, v_mac, v_pos);
  select user_card_id into k_elmas from match_hands where match_id = v_mac and user_id = a and position = v_pos limit 1;
  select user_card_id into k_efsane from match_hands where match_id = v_mac and user_id = b and position = v_pos limit 1;
  update match_hands set tier = 'diamond', power = 99 where match_id = v_mac and user_card_id = k_elmas;
  update match_hands set tier = 'legend', power = 1 where match_id = v_mac and user_card_id = k_efsane;
  perform play_card(a, v_mac, k_elmas);
  perform play_card(b, v_mac, k_efsane);
  perform pg_temp.beklenen('Elmas (+3 bonuslu, 99) Efsane''yi (1) yenemez',
    (select winner_id from match_rounds where match_id = v_mac and round_number = 1), b);

  -- ================== 6) 'combined' ESLESTIRME (etkin guc) ==================
  perform pg_temp.beklenen('surum 5: eslestirme combined', matchmaking_mode(), 'combined');
  declare
    c uuid := pg_temp.oyuncu('sv_c', 1900);
    d uuid := pg_temp.oyuncu('sv_d', 2050);
    e uuid := pg_temp.oyuncu('sv_e', 2050);
    r json;
  begin
    perform pg_temp.seviye(c, 10);
    r := find_match(c, pg_temp.deste(c), '{}');
    perform pg_temp.beklenen('C kuyrukta', r ->> 'status', 'queued');
    perform pg_temp.beklenen('kuyruktaki guc seviye bonusu dahil',
      (select deck_power from matchmaking_queue where user_id = c), pg_temp.deck_power_024(pg_temp.deste(c)) + 3);

    -- E: MMR farki 150 (1,5) ama etkin guc farki 4 (2,67): eslesmez
    update matchmaking_queue set deck_power = deck_power(pg_temp.deste(e)) + 4 where user_id = c;
    r := find_match(e, pg_temp.deste(e), '{}');
    perform pg_temp.beklenen('etkin guc farki buyuk: eslesmez', r ->> 'status', 'queued');
    delete from matchmaking_queue where user_id = e;

    -- D: MMR farki 150, etkin guc denk: eslesir (mmr modunda da 200 icinde)
    update matchmaking_queue set deck_power = deck_power(pg_temp.deste(d)) where user_id = c;
    r := find_match(d, pg_temp.deste(d), '{}');
    perform pg_temp.beklenen('etkin guc denk, MMR farkli: eslesir', r ->> 'status', 'matched');
    perform pg_temp.beklenen('eslesen mac surum 5', (select rules_version from matches where id = (r ->> 'match_id')::uuid), 5);
    perform pg_temp.beklenen('eslesen macta C +3 (Master tavani)', pg_temp.el_farki((r ->> 'match_id')::uuid, c), '3');
  end;

  -- ================== 7) ESKI MACLAR BONUS GORMEZ ==================
  perform pg_temp.beklenen('surum 2 mac eli hala bonussuz', pg_temp.bonuslu_kart(v_eski2, a), 0);
  perform pg_temp.beklenen('surum 4 mac eli hala bonussuz', pg_temp.bonuslu_kart(v_eski4, a), 0);
  perform pg_temp.beklenen('eski maclarda bonus kaydi yok',
    (select count(*)::int from match_hand_level_bonus where match_id in (v_eski2, v_eski4)), 0);
  perform pg_temp.beklenen('surum 1-4 seviye gucu kapali',
    (select count(*)::int from game_rule_versions where version < 5 and level_power), 0);

  -- ================== 8) SURUM 5 MACI SONUNA KADAR ==================
  -- (zamanlayici: her adimda sure dolmus sayilir; mevki/kart otomatik)
  for n in 1..80 loop
    exit when (select status from matches where id = v_mac2) <> 'active';
    update matches set turn_deadline = now() - interval '1 second' where id = v_mac2;
    perform advance_simultaneous_match(v_mac2);
  end loop;
  perform pg_temp.beklenen('surum 5 mac bitti', (select status from matches where id = v_mac2)::text, 'finished');
  perform pg_temp.beklenen('surum 5: kart transferi yok',
    (select count(*)::int from card_transfers where match_id = v_mac2), 0);
  perform pg_temp.beklenen('surum 5: her turun tek sonucu',
    (select count(*)::int from (select round_number from match_moves where match_id = v_mac2
                                group by 1 having count(*) <> 2) x), 0);
end $$;

rollback;
