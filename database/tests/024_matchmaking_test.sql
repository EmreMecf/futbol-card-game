-- =====================================================================
-- 024 KADRO GUCU ESLESTIRMESI — VERITABANI TESTLERI
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
  j json;
  v_fark numeric;
begin
  select u.id, d.id into v_a, v_da
  from users u join decks d on d.owner_id = u.id and d.is_active
  where get_active_match_id(u.id) is null
    and validate_deck(u.id, d.id) is null
  order by u.created_at limit 1;
  select u.id, d.id into v_b, v_db
  from users u join decks d on d.owner_id = u.id and d.is_active
  where get_active_match_id(u.id) is null and u.id <> v_a
    and validate_deck(u.id, d.id) is null
  order by u.created_at limit 1;
  if v_a is null or v_b is null then
    raise exception 'TEST KURULAMADI: gecerli kadrosu olan 2 kullanici yok';
  end if;

  delete from matchmaking_queue;
  update users set mmr = 1000 where id in (v_a, v_b);

  -- B'nin kadrosunu cok guclendir (sadece bu islemde; sonunda geri alinir)
  update cards set power = least(99, power + 20)
  where id in (select uc.card_id from deck_cards dc
               join user_cards uc on uc.id = dc.user_card_id
               where dc.deck_id = v_db)
    and id not in (select uc.card_id from deck_cards dc
                   join user_cards uc on uc.id = dc.user_card_id
                   where dc.deck_id = v_da);
  v_fark := deck_power(v_db) - deck_power(v_da);
  raise notice 'kadro gucu farki: %', v_fark;
  if v_fark < 6 then
    raise exception 'TEST KURULAMADI: kadro farki yetersiz (%)', v_fark;
  end if;

  -- 1) Varsayilan mod bugunku kural
  perform pg_temp.beklenen('varsayilan mod bugunku kural (mmr)', matchmaking_mode(), 'mmr');

  j := find_match(v_a, v_da);
  perform pg_temp.beklenen('A kuyruga girer', j->>'status', 'queued');
  perform pg_temp.beklenen('kuyrukta kadro gucu kayitli',
    (select deck_power from matchmaking_queue where user_id = v_a), deck_power(v_da));
  j := find_match(v_b, v_db);
  perform pg_temp.beklenen('MMR modu: kadro farkina BAKMADAN eslestirir', j->>'status', 'matched');
  -- Maci CEZASIZ kapat (teslim olmak 3 kart kaybettirip kadroyu bozar)
  update user_cards set locked_match_id = null
  where locked_match_id = (j->>'match_id')::uuid;
  update matches set status = 'cancelled' where id = (j->>'match_id')::uuid;
  delete from matchmaking_queue;
  update users set mmr = 1000 where id in (v_a, v_b);

  -- 2) Alternatif mod
  update matchmaking_settings set mode = 'combined';
  j := find_match(v_a, v_da);
  perform pg_temp.beklenen('combined: A kuyruga girer', j->>'status', 'queued');
  j := find_match(v_b, v_db);
  perform pg_temp.beklenen('combined: buyuk kadro farkiyla HEMEN eslesmez', j->>'status', 'queued');

  -- 3) Bekleme uzadikca sinir genisler. Bu testteki fark (~36 guc)
  -- gercekci degil; uzaklik ~24. 5 dakikada sinir 17 (eslesmez, dogru),
  -- 10 dakikada 32 (eslesir).
  update matchmaking_queue set created_at = now() - interval '10 minutes',
                               updated_at = now()
  where user_id = v_a;
  j := find_match(v_b, v_db);
  perform pg_temp.beklenen('combined: uzun beklemeden sonra eslesir', j->>'status', 'matched');

  raise notice '';
  raise notice 'TUM ESLESTIRME TESTLERI GECTI';
end;
$$;

rollback;
