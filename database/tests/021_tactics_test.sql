-- =====================================================================
-- 021 TAKTIK SISTEMI — VERITABANI TESTLERI
-- =====================================================================
-- Calistirma (veritabani acikken):
--   psql -h 127.0.0.1 -U futbol -d futbol_card -v ON_ERROR_STOP=1 \
--        -f database/tests/021_tactics_test.sql
--
-- Her sey tek bir islem icinde calisir ve sonunda GERI ALINIR
-- (rollback). Veritabaninda iz birakmaz.
--
-- Gereken: aktif destesi olan ve aktif maci olmayan en az 2 kullanici.
-- Bir test tutmazsa "TEST BASARISIZ" hatasiyla durur.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- YARDIMCI: kontrollu bir tur oynat
-- ---------------------------------------------------------------------
-- Turu acan ve cevap verenin o mevkideki ilk oynanmamis kartini
-- verilen seviye/guce ayarlar (kimya 0), sonra iki hamleyi oynatir.
-- Doner: 'lead' | 'resp' | 'draw'
create function pg_temp.tur(
  p_match uuid, p_pos card_position,
  p_lead_tier card_tier, p_lead_power int, p_lead_tactic text,
  p_resp_tier card_tier, p_resp_power int, p_resp_tactic text
) returns text language plpgsql as $$
declare
  m        matches%rowtype;
  v_lead   uuid;
  v_resp   uuid;
  v_lc     uuid;
  v_rc     uuid;
  v_round  match_rounds%rowtype;
begin
  select * into m from matches where id = p_match;
  v_lead := m.current_turn_id;
  v_resp := _opponent_of(m, v_lead);

  select user_card_id into v_lc from match_hands
  where match_id = p_match and user_id = v_lead and position = p_pos
    and not is_played limit 1;
  select user_card_id into v_rc from match_hands
  where match_id = p_match and user_id = v_resp and position = p_pos
    and not is_played limit 1;

  update match_hands set tier = p_lead_tier, power = p_lead_power, chemistry = 0
  where match_id = p_match and user_card_id = v_lc;
  update match_hands set tier = p_resp_tier, power = p_resp_power, chemistry = 0
  where match_id = p_match and user_card_id = v_rc;

  perform play_card(v_lead, p_match, v_lc, p_lead_tactic);
  perform play_card(v_resp, p_match, v_rc, p_resp_tactic);

  select * into v_round from match_rounds
  where match_id = p_match and round_number = m.round_number;

  return case
    when v_round.is_draw then 'draw'
    when v_round.winner_id = v_lead then 'lead'
    else 'resp'
  end;
end;
$$;

create function pg_temp.beklenen(p_ad text, p_gercek anyelement, p_beklenen anyelement)
returns void language plpgsql as $$
begin
  if p_gercek is distinct from p_beklenen then
    raise exception 'TEST BASARISIZ: % -> beklenen %, gelen %',
      p_ad, p_beklenen, p_gercek;
  end if;
  raise notice 'OK  %', p_ad;
end;
$$;

-- Bir ifadenin hata verdigini dogrular
create function pg_temp.hata_bekle(p_ad text, p_sql text, p_mesaj text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if position(p_mesaj in sqlerrm) = 0 then
      raise exception 'TEST BASARISIZ: % -> beklenmeyen hata: %', p_ad, sqlerrm;
    end if;
    raise notice 'OK  % (reddedildi: %)', p_ad, sqlerrm;
    return;
  end;
  raise exception 'TEST BASARISIZ: % -> hata bekleniyordu, ama kabul edildi', p_ad;
end;
$$;

do $$
declare
  v_a uuid; v_da uuid;
  v_b uuid; v_db uuid;
  v_match uuid;
  m matches%rowtype;
  v_lead uuid; v_resp uuid;
  v_card uuid;
  v_sonuc text;
  v_json json;
begin
  -- ================== 1) BONUS TABLOSU = PROTOTIP ==================
  perform pg_temp.beklenen('pres, rakip taktiksiz', tactic_bonus('high_press', 'none', true), 9);
  perform pg_temp.beklenen('pres kontraya yakalanir', tactic_bonus('high_press', 'counter_attack', true), 0);
  perform pg_temp.beklenen('pres duvari kirar', tactic_bonus('high_press', 'defensive_wall', false), 9);
  perform pg_temp.beklenen('kontra tek basina', tactic_bonus('counter_attack', 'none', true), 2);
  perform pg_temp.beklenen('kontra presi cezalandirir', tactic_bonus('counter_attack', 'high_press', false), 13);
  perform pg_temp.beklenen('kontra duvara carpar', tactic_bonus('counter_attack', 'defensive_wall', false), 0);
  perform pg_temp.beklenen('duvar savunurken', tactic_bonus('defensive_wall', 'none', false), 6);
  perform pg_temp.beklenen('duvar acarken', tactic_bonus('defensive_wall', 'counter_attack', true), 2);
  perform pg_temp.beklenen('duvar presle kirilir', tactic_bonus('defensive_wall', 'high_press', false), 0);
  perform pg_temp.beklenen('taktiksiz', tactic_bonus('none', 'high_press', true), 0);
  perform pg_temp.beklenen('maliyetler', array[tactic_cost('none'), tactic_cost('defensive_wall'),
    tactic_cost('counter_attack'), tactic_cost('high_press')], array[0, 1, 2, 3]);

  -- ================== 2) MAC KUR ==================
  select u.id, d.id into v_a, v_da
  from users u join decks d on d.owner_id = u.id and d.is_active
  where get_active_match_id(u.id) is null
    and (select count(*) from deck_cards dc where dc.deck_id = d.id) = 11
  order by u.created_at limit 1;

  select u.id, d.id into v_b, v_db
  from users u join decks d on d.owner_id = u.id and d.is_active
  where get_active_match_id(u.id) is null and u.id <> v_a
    and (select count(*) from deck_cards dc where dc.deck_id = d.id) = 11
  order by u.created_at limit 1;

  if v_a is null or v_b is null then
    raise exception 'TEST KURULAMADI: aktif destesi olan 2 kullanici yok';
  end if;

  v_match := _create_match(v_a, v_da, '{}', v_b, v_db, '{}');

  perform pg_temp.beklenen('baslangic enerjisi 2',
    (select array_agg(energy order by user_id) from match_players where match_id = v_match),
    array[2, 2]);

  select * into m from matches where id = v_match;
  v_lead := m.current_turn_id;
  v_resp := _opponent_of(m, v_lead);

  -- ================== 3) DOGRULAMA (istemciye guvenme) ==================
  select user_card_id into v_card from match_hands
  where match_id = v_match and user_id = v_lead and position = 'DEF' and not is_played limit 1;

  perform pg_temp.hata_bekle('enerji yetmezse pres reddedilir',
    format('select play_card(%L, %L, %L, %L)', v_lead, v_match, v_card, 'high_press'),
    'yeterli enerjiniz yok');

  perform pg_temp.hata_bekle('bilinmeyen taktik reddedilir',
    format('select play_card(%L, %L, %L, %L)', v_lead, v_match, v_card, 'hile'),
    'Gecersiz taktik');

  -- ================== 4) GIZLILIK: enerji tur cozulmeden dusmez ==================
  -- Turu acan duvar (1 enerji) ile acar; DEF gucleri esit, cevap kontra (2 enerji).
  update match_hands set power = 80, chemistry = 0, tier = 'gold'
  where match_id = v_match and position = 'DEF' and not is_played;

  perform play_card(v_lead, v_match, v_card, 'defensive_wall');

  v_json := get_match_state(v_resp, v_match);
  perform pg_temp.beklenen('acan oynadi ama enerjisi rakibe DEGISMEMIS gorunur',
    (v_json->>'opponent_energy')::int, 2);

  perform pg_temp.hata_bekle('pas gecerken taktik reddedilir',
    format('select play_card(%L, %L, null, %L)', v_resp, v_match, 'defensive_wall'),
    'Pas gecerken taktik');

  select user_card_id into v_card from match_hands
  where match_id = v_match and user_id = v_resp and position = 'DEF' and not is_played limit 1;
  perform play_card(v_resp, v_match, v_card, 'counter_attack');

  -- Duvar (acan) +2, kontra duvara carpti 0 -> 82 vs 80, acan kazanir
  perform pg_temp.beklenen('duvar kontrayi kirdi, acan kazandi',
    (select winner_id from match_rounds where match_id = v_match and round_number = m.round_number),
    v_lead);
  perform pg_temp.beklenen('bonuslar kaydedildi (acan +2, cevap 0)',
    (select array_agg(tactic_bonus order by is_lead desc) from match_moves
     where match_id = v_match and round_number = m.round_number),
    array[2, 0]);
  perform pg_temp.beklenen('enerji: acan 2-1+1=2, cevap 2-2+1=1',
    array[(select energy from match_players where match_id = v_match and user_id = v_lead),
          (select energy from match_players where match_id = v_match and user_id = v_resp)],
    array[2, 1]);

  -- ================== 5) KURALLAR ==================
  update match_players set energy = 5 where match_id = v_match;

  -- Pres zayif karti cevirir: 80+9 > 85
  v_sonuc := pg_temp.tur(v_match, 'MID', 'gold', 80, 'high_press', 'gold', 85, 'none');
  perform pg_temp.beklenen('pres 5 guc farkini cevirir', v_sonuc, 'lead');

  update match_players set energy = 5 where match_id = v_match;
  -- Kontra presi yakalar: acan 90+0, cevap 80+13=93
  v_sonuc := pg_temp.tur(v_match, 'MID', 'gold', 90, 'high_press', 'gold', 80, 'counter_attack');
  perform pg_temp.beklenen('kontra presi yakalar', v_sonuc, 'resp');

  update match_players set energy = 5 where match_id = v_match;
  -- LEGEND KURALI: 45 gucluk Legend, 99 + pres'e karsi kazanir
  v_sonuc := pg_temp.tur(v_match, 'MID', 'legend', 45, 'none', 'diamond', 99, 'high_press');
  perform pg_temp.beklenen('LEGEND: hicbir taktik Legend''i yenemez', v_sonuc, 'lead');

  update match_players set energy = 5 where match_id = v_match;
  -- Taktiksiz esitlik hala beraberlik
  v_sonuc := pg_temp.tur(v_match, 'MID', 'gold', 77, 'none', 'gold', 77, 'none');
  perform pg_temp.beklenen('taktiksiz esit guc = beraberlik', v_sonuc, 'draw');

  -- Enerji tavani: 5'te kalir (taktiksiz turdan sonra 5+1 -> 5)
  perform pg_temp.beklenen('enerji en fazla 5',
    (select max(energy) from match_players where match_id = v_match), 5);

  raise notice '';
  raise notice 'TUM TAKTIK TESTLERI GECTI';
end;
$$;

rollback;
