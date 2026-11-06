-- =====================================================================
-- 022 MAC SONRASI LIG DEGISIMI — VERITABANI TESTLERI
-- =====================================================================
-- Calistirma:
--   psql -h 127.0.0.1 -U futbol -d futbol_card -v ON_ERROR_STOP=1 \
--        -f database/tests/022_league_change_test.sql
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
  v_match uuid;
  v_esik int;
  j jsonb;
begin
  -- Usta 1'in alt siniri (tablodan; sayi koda gomulu degil)
  select min_mmr into v_esik from league_tiers
  where league_code = 'usta' and division = 1;

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

  -- A esigin 10 altinda, B tam esikte
  update users set mmr = v_esik - 10 where id = v_a;
  update users set mmr = v_esik      where id = v_b;

  v_match := _create_match(v_a, v_da, '{}', v_b, v_db, '{}');

  perform pg_temp.beklenen('mac basi puani kaydedildi',
    (select array_agg(mmr_before order by mmr_before) from match_players where match_id = v_match),
    array[v_esik - 10, v_esik]);

  perform pg_temp.beklenen('bitmemis macta lig degisimi YOK (null)',
    get_match_league_change(v_a, v_match), null::jsonb);

  -- B teslim olur -> A kazanir (+25), B kaybeder (-25)
  perform surrender_match(v_b, v_match);

  j := get_match_league_change(v_a, v_match);
  perform pg_temp.beklenen('kazanan: puan farki +25', (j->>'mmr_delta')::int, 25);
  perform pg_temp.beklenen('kazanan: YUKSELDI', j->>'direction', 'promoted');
  perform pg_temp.beklenen('kazanan: yeni lig Usta 1',
    (j->'rank_after'->>'league_code') || (j->'rank_after'->>'division'), 'usta1');
  perform pg_temp.beklenen('kazanan: eski lig Amator 3',
    (j->'rank_before'->>'league_code') || (j->'rank_before'->>'division'), 'amateur3');

  j := get_match_league_change(v_b, v_match);
  perform pg_temp.beklenen('kaybeden: puan farki -25', (j->>'mmr_delta')::int, -25);
  perform pg_temp.beklenen('kaybeden: DUSTU', j->>'direction', 'demoted');

  perform pg_temp.beklenen('mac sonu puani users ile ayni',
    (select mmr_after from match_players where match_id = v_match and user_id = v_a),
    (select mmr from users where id = v_a));

  -- get_player_rank davranisi degismedi
  perform pg_temp.beklenen('get_player_rank = rank_json_for_mmr',
    get_player_rank(v_a), rank_json_for_mmr((select mmr from users where id = v_a)));

  -- Yetkisiz oyuncu
  begin
    perform get_match_league_change(gen_random_uuid(), v_match);
    raise exception 'TEST BASARISIZ: yabanci oyuncu sonucu gordu';
  exception when others then
    if sqlerrm like 'TEST BASARISIZ%' then raise; end if;
    raise notice 'OK  yabanci oyuncu reddedildi (%)', sqlerrm;
  end;

  raise notice '';
  raise notice 'TUM LIG DEGISIMI TESTLERI GECTI';
end;
$$;

rollback;
