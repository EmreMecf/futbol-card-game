-- =====================================================================
-- 043 KUPA YOLU + SEZON SONU LIG SIFIRLAMASI — TESTLER (GERI ALINIR)
-- =====================================================================
--  0 anahtarlar kapali: hicbir sey degismez
--  1 yeni basamak: tablo odulu bir kez (sandik + altin [+ kozmetik])
--  2 birden cok basamak atlama: aradaki her basamak odullenir
--  3 dusup yeniden cikmak odul vermez
--  4 GERIYE DONUK ODUL YOK: acilistaki ve gecmiste ulasilan basamak sayilmaz
--  5 gercek mac galibiyeti basamak atlatir -> odul
--  6 botlar odul almaz
--  7 sezon sonu: lig odulu (yalniz o sezon oynayan), yumusak sifirlama,
--    tekrar calismaz, Amator'e dokunulmaz, botlar haric
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

create function pg_temp.oyuncu(p_ad text, p_mmr int default 1000) returns uuid
language plpgsql as $$
declare u uuid;
begin
  insert into users (email, password_hash, username, mmr) values (p_ad || '@test.local', 'x', p_ad, p_mmr) returning id into u;
  perform grant_starter_pack(u);
  return u;
end;
$$;

create function pg_temp.deste(p_u uuid) returns uuid
language sql as $$ select id from decks where owner_id = p_u and is_active $$;

create function pg_temp.bayrak(p_v int, p_json text) returns void
language sql as $$
  insert into economy_config_versions (kind, version, payload, note)
  select 'feature_flags', p_v,
         (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1) || p_json::jsonb,
         'test'
$$;

create function pg_temp.odul(p_u uuid) returns text
language sql as $$
  select coalesce(string_agg(tier_id::text, ',' order by tier_id), '-') from trophy_road_grants where user_id = p_u
$$;

create function pg_temp.mac_bitir(p_kazanan uuid, p_kaybeden uuid) returns uuid
language plpgsql as $$
declare v uuid;
begin
  v := _create_match(p_kazanan, pg_temp.deste(p_kazanan), '{}', p_kaybeden, pg_temp.deste(p_kaybeden), '{}');
  perform _finish_match(v, p_kazanan);
  return v;
end;
$$;

do $$
declare
  a uuid; b uuid; c uuid; d uuid; e uuid; f uuid; g uuid; bot uuid; w uuid; l uuid;
  v_altin int; v_sezon uuid; v_sezon2 uuid; v_mac uuid;
  n int;
  v jsonb;
begin
  -- ================== 0) KAPALI ==================
  perform pg_temp.beklenen('trophy_road kapali gelir', economy_flag('trophy_road'), false);
  perform pg_temp.beklenen('league_season_reset kapali gelir', economy_flag('league_season_reset'), false);
  a := pg_temp.oyuncu('kr_a');
  update users set mmr = 1500 where id = a;
  perform pg_temp.beklenen('kapali: odul yok', pg_temp.odul(a), '-');
  perform pg_temp.beklenen('kapali: kupa yolu kaydi yok', (select count(*)::int from user_trophy_road where user_id = a), 0);
  update users set mmr = 1000 where id = a;

  insert into seasons (number, name, starts_at, ends_at, rules_version)
  values (901, 'Test sezonu kapali', now() - interval '30 days', now() - interval '1 second', 1) returning id into v_sezon;
  e := pg_temp.oyuncu('kr_e', 1800);
  perform close_due_seasons();
  perform pg_temp.beklenen('kapali: sezon kapandi ama puan ayni', (select mmr from users where id = e), 1800);
  perform pg_temp.beklenen('kapali: sezon sonucu yazilmadi', (select count(*)::int from season_league_results where season_id = v_sezon), 0);

  -- ================== 1) YENI BASAMAK ==================
  perform pg_temp.bayrak(990, '{"trophy_road": true}');
  v_altin := (select coins from users where id = a);
  update users set mmr = 1150 where id = a;                      -- Amator 2
  perform pg_temp.beklenen('Amator 2 odulu', pg_temp.odul(a), '2');
  perform pg_temp.beklenen('Amator 2: Gumus sandik',
    (select chest_type::text from user_chests where user_id = a and source_type = 'trophy_road' and source_id = '2'), 'silver');
  perform pg_temp.beklenen('Amator 2: +50 altin', (select coins from users where id = a) - v_altin, 50);

  -- ================== 2) COK BASAMAK ==================
  update users set mmr = 1450 where id = a;                      -- Usta 2 (5)
  perform pg_temp.beklenen('Amator 3, Usta 1, Usta 2 odullendi', pg_temp.odul(a), '2,3,4,5');
  perform pg_temp.beklenen('Usta girisi: cerceve kozmetigi',
    (select count(*)::int from user_items where user_id = a and item_slug = 'frame_league_usta'), 1);
  perform pg_temp.beklenen('toplam altin 50+50+100+100',
    (select coins from users where id = a) - v_altin, 300);
  perform pg_temp.beklenen('her odul defterde tek',
    (select count(*)::int from economy_ledger where user_id = a and entry_type = 'trophy_road'), 4);

  -- ================== 3) DUSUP YENIDEN CIKMAK ==================
  update users set mmr = 1100 where id = a;
  update users set mmr = 1460 where id = a;
  perform pg_temp.beklenen('yeniden cikinca yeni odul yok', pg_temp.odul(a), '2,3,4,5');
  perform pg_temp.beklenen('Usta sandiklari tek', (select count(*)::int from user_chests where user_id = a and source_type = 'trophy_road'), 4);

  -- ================== 4) GERIYE DONUK ODUL YOK ==================
  perform pg_temp.bayrak(991, '{"trophy_road": false}');
  b := pg_temp.oyuncu('kr_b');
  update users set mmr = 1700 where id = b;                      -- kapaliyken Master 1
  perform pg_temp.bayrak(992, '{"trophy_road": true}');
  update users set mmr = 1710 where id = b;
  perform pg_temp.beklenen('acilista Master 1: gecmis basamaklar odulsuz', pg_temp.odul(b), '-');
  perform pg_temp.beklenen('baslangic basamagi Master 1', (select baseline_tier from user_trophy_road where user_id = b), 7);
  update users set mmr = 1760 where id = b;                      -- Master 2
  perform pg_temp.beklenen('yalniz yeni basamak (Master 2)', pg_temp.odul(b), '8');

  -- gecmiste (mac kaydinda) Usta 3'e cikmis, simdi Amator 1
  c := pg_temp.oyuncu('kr_c');
  d := pg_temp.oyuncu('kr_d');
  perform pg_temp.bayrak(993, '{"trophy_road": false}');
  v_mac := pg_temp.mac_bitir(d, c);
  update match_players set mmr_after = 1550 where match_id = v_mac and user_id = c;
  update users set mmr = 1000 where id = c;
  perform pg_temp.bayrak(994, '{"trophy_road": true}');
  update users set mmr = 1560 where id = c;                      -- yeniden Usta 3
  perform pg_temp.beklenen('gecmiste ulasilan Usta 3 odulsuz', pg_temp.odul(c), '-');
  update users set mmr = 1650 where id = c;                      -- Master 1
  perform pg_temp.beklenen('ilk kez Master 1: odul + cerceve', pg_temp.odul(c) || ':' ||
    (select count(*) from user_items where user_id = c and item_slug = 'frame_league_master'), '7:1');

  -- ================== 5) GERCEK MAC GALIBIYETI ==================
  w := pg_temp.oyuncu('kr_w', 1090);
  l := pg_temp.oyuncu('kr_l', 1090);
  perform pg_temp.mac_bitir(w, l);
  perform pg_temp.beklenen('galibiyet +25 -> Amator 2', (select mmr from users where id = w), 1115);
  perform pg_temp.beklenen('mac galibiyetiyle basamak odulu', pg_temp.odul(w), '2');
  perform pg_temp.beklenen('kaybeden odul almaz', pg_temp.odul(l), '-');
  perform pg_temp.beklenen('kupa yolu hatasi yok', (select count(*)::int from economy_errors where context = 'trophy_road'), 0);

  -- ================== 6) BOT ==================
  insert into users (email, password_hash, username, is_bot) values ('krbot@bot.invalid', '!', 'kr_bot', true) returning id into bot;
  update users set mmr = 2500 where id = bot;
  perform pg_temp.beklenen('bot odul almaz', pg_temp.odul(bot), '-');

  -- ================== 7) SEZON SONU ==================
  perform pg_temp.bayrak(995, '{"trophy_road": false, "league_season_reset": true}');
  insert into seasons (number, name, starts_at, ends_at, rules_version)
  values (902, 'Test sezonu', now() - interval '30 days', now() - interval '1 second', 1) returning id into v_sezon2;
  -- e: Master 2 ve bu sezon oynadi; f: Usta 1, oynamadi; g: Amator 2, oynadi
  f := pg_temp.oyuncu('kr_f');
  g := pg_temp.oyuncu('kr_g');
  perform pg_temp.mac_bitir(e, g);
  perform pg_temp.mac_bitir(g, e);
  update users set mmr = 1800 where id = e;
  update users set mmr = 1300 where id = f;
  update users set mmr = 1150 where id = g;
  v_altin := (select coins from users where id = e);

  perform close_due_seasons();
  perform pg_temp.beklenen('sezon kapandi', (select status from seasons where id = v_sezon2), 'closed');
  perform pg_temp.beklenen('Master 2 -> Master 1 tabani', (select mmr from users where id = e), 1625);
  perform pg_temp.beklenen('Master odulu: Altin sandik + 200 altin',
    (select chest_type::text from user_chests where user_id = e and source_type = 'season_league' and source_id = v_sezon2::text)
      || '+' || ((select coins from users where id = e) - v_altin), 'gold+200');
  perform pg_temp.beklenen('Usta 1 -> Amator 3 tabani (oynamasa da)', (select mmr from users where id = f), 1200);
  perform pg_temp.beklenen('bu sezon oynamayana odul yok',
    (select count(*)::int from user_chests where user_id = f and source_type = 'season_league'), 0);
  perform pg_temp.beklenen('Amator puani degismez', (select mmr from users where id = g), 1150);
  perform pg_temp.beklenen('Amator odulu Gumus',
    (select chest_type::text from user_chests where user_id = g and source_type = 'season_league'), 'silver');
  perform pg_temp.beklenen('bot sifirlanmaz', (select mmr from users where id = bot), 2500);
  perform pg_temp.beklenen('bot sonucu yok', (select count(*)::int from season_league_results where user_id = bot), 0);
  perform pg_temp.beklenen('denetim kaydi: once/sonra',
    (select tier_before || ':' || mmr_before || '->' || mmr_after from season_league_results where season_id = v_sezon2 and user_id = e),
    '8:1800->1625');
  perform pg_temp.beklenen('sezon sonu hatasi yok', (select count(*)::int from economy_errors where context = 'season_league'), 0);

  -- tekrar calistirma (ayni sezon): degisiklik yok
  n := _league_season_end(v_sezon2);
  perform pg_temp.beklenen('ikinci kez islenmez', n, 0);
  perform pg_temp.beklenen('puan yine 1625', (select mmr from users where id = e), 1625);
  perform pg_temp.beklenen('sandik yine tek',
    (select count(*)::int from user_chests where user_id = e and source_type = 'season_league'), 1);

  -- ================== GENEL BAKIS ==================
  v := trophy_road_overview(a);
  perform pg_temp.beklenen('genel bakis: 12 basamak', jsonb_array_length(v -> 'tiers'), 12);
  perform pg_temp.beklenen('genel bakis: Usta 2 verildi, Usta 3 kilitli',
    (select string_agg(x ->> 'status', ',' order by (x ->> 'tier_id')::int) from jsonb_array_elements(v -> 'tiers') x
      where (x ->> 'tier_id')::int in (5, 6)), 'granted,locked');
  v := trophy_road_overview(b);
  perform pg_temp.beklenen('genel bakis: acilistan once ulasilan basamak odulsuz gorunur',
    (select x ->> 'status' from jsonb_array_elements(v -> 'tiers') x where (x ->> 'tier_id')::int = 4), 'reached_before');
end $$;

rollback;
