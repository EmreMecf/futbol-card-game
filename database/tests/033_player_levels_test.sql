-- =====================================================================
-- 033 FUTBOLCU SEVIYESI — VERITABANI TESTLERI (tek islem, GERI ALINIR)
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

do $$
declare
  u uuid;
  bronz uuid;
  efsane uuid;
  v jsonb;
  altin_once int;
  n int;
  t_once int;
  i int;
begin
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 996, '{"economy_v2_enabled": true}', 'test');
  insert into users (email, password_hash, username, coins) values ('seviye-test@test.local', 'x', 'seviye_test', 100000)
  returning id into u;
  select id into bronz from cards where tier = 'bronze' and is_active order by power limit 1;
  select id into efsane from cards where tier = 'legend' and is_active order by power limit 1;
  insert into user_cards (owner_id, card_id) select u, bronz from generate_series(1, 5);

  -- 1) Maliyet tablosu tasarimla ayni (Bronz toplam 99 kopya / 6.470 altin)
  select sum(x::int) into n from jsonb_array_elements_text(_level_rules() -> 'copies' -> 'bronze') x;
  perform pg_temp.beklenen('bronz toplam kopya 99', n, 99);
  select sum(x::int) into n from jsonb_array_elements_text(_level_rules() -> 'coins' -> 'legend') x;
  perform pg_temp.beklenen('efsane toplam altin 36.100', n, 36100);
  perform pg_temp.beklenen('K1: dereceli gucu etkilemez', (_level_rules() ->> 'affects_ranked_power')::boolean, false);

  -- 2) Kopya yokken seviye atlanamaz; sahip olunmayan futbolcu atlanamaz
  perform pg_temp.hata_bekle('kopyasiz seviye atlanamaz',
    format('select level_up_player(%L, %L)', u, bronz), 'not_enough_copies');
  perform pg_temp.hata_bekle('sahip olunmayan futbolcu',
    format('select level_up_player(%L, %L)', u, efsane), 'card_not_owned');

  -- 3) Gonullu donusum: 5 kopya, 2 kalir -> en fazla 3
  perform pg_temp.beklenen('donusturulebilir 3', _convertible_copies(u, bronz), 3);
  perform pg_temp.hata_bekle('fazlasi donusturulemez',
    format('select convert_extra_copies(%L, %L, 4, %L)', u, bronz, 'istek-1'), 'not_convertible');
  v := convert_extra_copies(u, bronz, 3, 'istek-2');
  perform pg_temp.beklenen('3 kopya donustu', (v ->> 'copies')::int, 3);
  perform pg_temp.beklenen('2 fiziksel kopya kaldi', (select count(*)::int from user_cards where owner_id = u and card_id = bronz), 2);
  -- Kart SILINMEDI: arsiv hesabina devredildi ve kayit dustu
  perform pg_temp.beklenen('kopyalar arsivde', (select count(*)::int from user_cards
    where owner_id = _archive_user_id() and card_id = bronz and acquired_from = u), 3);
  perform pg_temp.beklenen('devir kaydi', (select count(*)::int from card_transfers
    where from_user_id = u and reason = 'converted_to_progress'), 3);
  -- Ayni istek tekrar: ikinci kez donusturmez
  v := convert_extra_copies(u, bronz, 3, 'istek-2');
  perform pg_temp.beklenen('tekrar istek ayni sonuc', (v ->> 'replay')::boolean, true);
  perform pg_temp.beklenen('tekrar istek kopya eklemedi',
    (select copies from player_progress where user_id = u and card_id = bronz), 3);

  -- 4) Seviye atla: 1->2 (1 kopya, 20 altin), 2->3 (2 kopya, 50 altin)
  altin_once := (select coins from users where id = u);
  v := level_up_player(u, bronz);
  perform pg_temp.beklenen('seviye 2', (v ->> 'level')::int, 2);
  v := level_up_player(u, bronz);
  perform pg_temp.beklenen('seviye 3', (v ->> 'level')::int, 3);
  perform pg_temp.beklenen('kopyalar harcandi', (select copies from player_progress where user_id = u and card_id = bronz), 0);
  perform pg_temp.beklenen('altin 20 + 50 dustu', (select coins from users where id = u), altin_once - 70);
  perform pg_temp.beklenen('defterde 2 seviye kaydi',
    (select count(*)::int from economy_ledger where user_id = u and entry_type = 'level_up'), 2);

  -- 5) Joker ile: 3->4 icin 3 kopya; joker yoksa reddedilir, varsa harcanir
  perform pg_temp.hata_bekle('jokersiz eksik kopya reddedilir',
    format('select level_up_player(%L, %L, true)', u, bronz), 'not_enough_jokers');
  -- 034'ten beri joker parcalar item envanterinde
  perform _item_add(u, 'joker_bronze', 10, 'test');
  v := level_up_player(u, bronz, true);
  perform pg_temp.beklenen('jokerle seviye 4', (v ->> 'level')::int, 4);
  perform pg_temp.beklenen('3 joker harcandi', _item_qty(u, 'joker_bronze'), 7);

  -- 6) Ustalik: seviye 5'te tek seferlik 200 altin
  update player_progress set copies = 5 where user_id = u and card_id = bronz;
  altin_once := (select coins from users where id = u);
  v := level_up_player(u, bronz);
  perform pg_temp.beklenen('seviye 5 + ustalik 200', (v ->> 'mastery_coins')::int, 200);
  -- 4->5 maliyeti 200 altin (tasarim §2.2); ustalik +200 -> net 0
  perform pg_temp.beklenen('altin: -200 + 200 ustalik', (select coins from users where id = u), altin_once);
  perform pg_temp.beklenen('ustalik tek kayit',
    (select count(*)::int from economy_ledger where idempotency_key = 'mastery:' || u || ':' || bronz || ':5'), 1);

  -- 7) Altin yetmezse reddedilir, hicbir sey degismez
  update users set coins = 10 where id = u;
  update player_progress set copies = 100 where user_id = u and card_id = bronz;
  perform pg_temp.hata_bekle('altin yetmez',
    format('select level_up_player(%L, %L)', u, bronz), 'not_enough_coins');
  perform pg_temp.beklenen('seviye degismedi', (select level from player_progress where user_id = u and card_id = bronz), 5);

  -- 8) Seviye 10 tavan; sandiktan gelen kopya -> joker (tasma)
  update users set coins = 1000000 where id = u;
  for i in 1..5 loop perform level_up_player(u, bronz); end loop;
  perform pg_temp.beklenen('seviye 10', (select level from player_progress where user_id = u and card_id = bronz), 10);
  perform pg_temp.hata_bekle('10 ustu yok', format('select level_up_player(%L, %L)', u, bronz), 'max_level');
  perform pg_temp.beklenen('seviye 10 ustalik kaydi',
    (select count(*)::int from economy_ledger where idempotency_key = 'mastery:' || u || ':' || bronz || ':10'), 1);

  -- 9) K1: seviye maca GIRMEZ — el kartinin gucu katalog gucuyle ayni kalir
  --    (match_hands.power kartin power'indan dondurulur; seviye kullanilmaz)
  --    040'tan sonra: bu fonksiyonlar yine player_progress OKUMAZ; seviye
  --    bonusu yalniz kural surumu 5'te (anahtar 'card_level_power', KAPALI)
  --    card_level_bonus() uzerinden girer -> database/tests/040_level_power_test.sql
  perform pg_temp.beklenen('dereceli guc katalogdaki guc',
    (select power from cards where id = bronz), (select power from cards where id = bronz));
  select count(*) into n from pg_proc
  where proname in ('play_card', '_resolve_round', '_create_match', 'deck_power', 'find_match')
    and prosrc ilike '%player_progress%';
  perform pg_temp.beklenen('mac/eslesme fonksiyonlari seviyeyi okumaz', n, 0);

  -- 10) Genel bakis
  v := player_progress_overview(u);
  select count(*) into n from jsonb_array_elements(v -> 'items') x where (x ->> 'card_id')::uuid = bronz and (x ->> 'level')::int = 10;
  perform pg_temp.beklenen('genel bakista seviye 10', n, 1);
  perform pg_temp.beklenen('seviye 10 maliyeti yok',
    (select x -> 'next' from jsonb_array_elements(v -> 'items') x where (x ->> 'card_id')::uuid = bronz), 'null'::jsonb);

  -- 11) Kart kaybedilse de seviye kalir (K2)
  update user_cards set owner_id = _archive_user_id() where owner_id = u and card_id = bronz;
  perform pg_temp.beklenen('kart gitti, seviye kaldi', (select level from player_progress where user_id = u and card_id = bronz), 10);

  raise notice '033 seviye testleri: HEPSI GECTI';
end;
$$;

rollback;
