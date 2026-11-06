-- =====================================================================
-- 023 KURAL SURUMLEMESI — VERITABANI TESTLERI
-- =====================================================================
-- Tek islem icinde calisir, sonunda GERI ALINIR.
-- =====================================================================

begin;

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

do $$
declare
  v_a uuid; v_da uuid;
  v_b uuid; v_db uuid;
  v_yeni uuid; v_eski uuid;
  m matches%rowtype;
  v_lead uuid; v_resp uuid; v_lc uuid; v_rc uuid;
begin
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

  -- 1) Yeni mac guncel surumle kurulur
  v_yeni := _create_match(v_a, v_da, '{}', v_b, v_db, '{}');
  perform pg_temp.beklenen('yeni mac guncel surumle kurulur',
    (select rules_version from matches where id = v_yeni), current_rules_version());
  perform pg_temp.beklenen('durum ucu surumu bildirir',
    (get_match_state(v_a, v_yeni)->>'tactics_enabled')::boolean, true);

  -- Yeni maci kapat, eski surumlu maci kurmak icin oyuncular bosalsin
  perform surrender_match(v_b, v_yeni);

  -- 2) SURUM 1 (taktiksiz) ile kurulmus bir mac (eski mac taklidi)
  v_eski := _create_match(v_a, v_da, '{}', v_b, v_db, '{}');
  update matches set rules_version = 1 where id = v_eski;
  update match_players set energy = 5 where match_id = v_eski;
  select * into m from matches where id = v_eski;
  v_lead := m.current_turn_id;
  v_resp := _opponent_of(m, v_lead);

  select user_card_id into v_lc from match_hands
  where match_id = v_eski and user_id = v_lead and position = 'MID' and not is_played limit 1;
  select user_card_id into v_rc from match_hands
  where match_id = v_eski and user_id = v_resp and position = 'MID' and not is_played limit 1;
  update match_hands set power = 80, chemistry = 0, tier = 'gold' where match_id = v_eski and user_card_id = v_lc;
  update match_hands set power = 85, chemistry = 0, tier = 'gold' where match_id = v_eski and user_card_id = v_rc;

  perform pg_temp.beklenen('durum ucu: eski macta taktik kapali',
    (get_match_state(v_a, v_eski)->>'tactics_enabled')::boolean, false);

  begin
    perform play_card(v_lead, v_eski, v_lc, 'high_press');
    raise exception 'TEST BASARISIZ: taktiksiz macta pres kabul edildi';
  exception when others then
    if sqlerrm like 'TEST BASARISIZ%' then raise; end if;
    raise notice 'OK  taktiksiz macta taktik reddedildi (%)', sqlerrm;
  end;

  -- Taktiksiz oynanir: 80 vs 85 -> cevap veren kazanir, bonus yok, enerji degismez
  perform play_card(v_lead, v_eski, v_lc);
  perform play_card(v_resp, v_eski, v_rc);
  perform pg_temp.beklenen('eski kurallar: guclu kart kazanir',
    (select winner_id from match_rounds where match_id = v_eski and round_number = m.round_number), v_resp);
  perform pg_temp.beklenen('eski kurallar: enerji degismez',
    (select array_agg(energy) from match_players where match_id = v_eski), array[5, 5]);

  -- 3) Surum tablosu tutarli
  perform pg_temp.beklenen('guncel surum tabloda kayitli',
    exists (select 1 from game_rule_versions where version = current_rules_version()), true);
  perform pg_temp.beklenen('her macin surumu dolu',
    (select count(*) from matches where rules_version is null), 0::bigint);

  raise notice '';
  raise notice 'TUM KURAL SURUMU TESTLERI GECTI';
end;
$$;

rollback;
