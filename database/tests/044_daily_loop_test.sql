-- =====================================================================
-- 044 GUNLUK DONGU + MAGAZA TEKLIFI + PAKET SADELESTIRMESI — TESTLER
-- (GERI ALINIR)
-- =====================================================================
--  0 anahtarlar kapali: gunluk sandik/teklif reddedilir, paket 011 gibi
--  1 gunluk sandik: Bronz; ayni gun ikinci kez yok; art arda 3. gun Gumus;
--    seri bozulursa bastan
--  2 gunun ilk dereceli galibiyeti: ek XP = o macin galibiyet XP'si
--    (cift); ayni gun ikinci galibiyette yok; antrenman/bot sayilmaz
--  3 gunluk teklif: %25 indirimli, gunde 1, altin yetmezse hicbir sey olmaz
--  4 paket sadelestirmesi: sahip olunan futbolcu -> gelisim kopyasi,
--    seviye 10 -> joker; baslangic paketi haric
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

create function pg_temp.bayrak(p_v int, p_json text) returns void
language sql as $$
  insert into economy_config_versions (kind, version, payload, note)
  select 'feature_flags', p_v,
         (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1) || p_json::jsonb,
         'test'
$$;

-- Gercek dereceli mac: 6 tur oynanir (K6), sonra kazanan hukmen
create function pg_temp.mac(p_kazanan uuid, p_kaybeden uuid, p_mod text default 'ranked') returns uuid
language plpgsql as $$
declare
  v uuid; m matches%rowtype; c uuid; i int;
begin
  v := _create_match(p_kazanan, pg_temp.deste(p_kazanan), '{}', p_kaybeden, pg_temp.deste(p_kaybeden), '{}');
  update matches set mode = p_mod where id = v;
  for i in 1..30 loop
    select * into m from matches where id = v;
    exit when m.status <> 'active' or (select count(*) from match_rounds where match_id = v) >= 6;
    select user_card_id into c from match_hands where match_id = v and user_id = m.current_turn_id
      and not is_played and (m.required_position is null or position = m.required_position) limit 1;
    perform play_card(m.current_turn_id, v, c);
  end loop;
  perform _finish_match(v, p_kazanan);
  return v;
end;
$$;

create function pg_temp.xp(p_key text) returns int
language sql as $$ select (items ->> 'xp')::int from economy_ledger where idempotency_key = 'sxp:' || p_key $$;

do $$
declare
  a uuid; b uuid; c uuid; d uuid; e uuid;
  r jsonb; o jsonb;
  v_mac uuid; v_mac2 uuid;
  v_altin int; v_kart int; v_kopya int; v_joker int;
begin
  a := pg_temp.oyuncu('gd_a');
  b := pg_temp.oyuncu('gd_b');

  -- ================== 0) KAPALI ==================
  perform pg_temp.beklenen('daily_loop kapali gelir', economy_flag('daily_loop'), false);
  perform pg_temp.beklenen('daily_shop kapali gelir', economy_flag('daily_shop'), false);
  perform pg_temp.beklenen('pack_duplicates_v2 kapali gelir', economy_flag('pack_duplicates_v2'), false);
  perform pg_temp.hata_bekle('kapali: gunluk sandik yok', format('select claim_daily_chest(%L)', a), 'daily_disabled');
  perform pg_temp.hata_bekle('kapali: gunluk teklif yok', format('select buy_daily_offer(%L)', a), 'shop_disabled');
  update users set coins = 100000 where id = a;
  v_kart := (select count(*) from user_cards where owner_id = a);
  r := open_pack(a, 'standard')::jsonb;
  perform pg_temp.beklenen('kapali: paket 5 fiziksel kart (011 gibi)', (select count(*)::int from user_cards where owner_id = a) - v_kart, 5);
  perform pg_temp.beklenen('kapali: ilerleme listesi bos', jsonb_array_length(r -> 'progress'), 0);
  perform pg_temp.beklenen('kapali: 500 altin', (r ->> 'coins_spent')::int, 500);

  -- ================== 1) GUNLUK SANDIK ==================
  perform pg_temp.bayrak(990, '{"economy_v2_enabled": true, "daily_loop": true, "daily_shop": true}');
  r := claim_daily_chest(a);
  perform pg_temp.beklenen('ilk gun: Bronz, seri 1', (r ->> 'chest_type') || ':' || (r ->> 'streak'), 'bronze:1');
  perform pg_temp.beklenen('sandik verildi', (select chest_type::text from user_chests where id = (r ->> 'chest_id')::uuid), 'bronze');
  r := claim_daily_chest(a);
  perform pg_temp.beklenen('ayni gun ikinci kez: zaten alindi', (r ->> 'already_claimed'), 'true');
  perform pg_temp.beklenen('ayni gun tek sandik', (select count(*)::int from user_chests where user_id = a and source_type = 'daily'), 1);
  perform pg_temp.beklenen('durum: bugun alindi', (daily_status(a) ->> 'claimed_today'), 'true');

  -- art arda 3. gun Gumus (onceki iki gun kaydi)
  insert into daily_chest_claims (user_id, day, streak, chest_type) values
    (b, game_day() - 2, 1, 'bronze'), (b, game_day() - 1, 2, 'bronze');
  perform pg_temp.beklenen('durum: bugunku sandik Gumus olacak', daily_status(b) ->> 'chest_type', 'silver');
  r := claim_daily_chest(b);
  perform pg_temp.beklenen('art arda 3. gun: Gumus, seri 3', (r ->> 'chest_type') || ':' || (r ->> 'streak'), 'silver:3');
  -- seri bozuldu (dun yok)
  c := pg_temp.oyuncu('gd_c');
  insert into daily_chest_claims (user_id, day, streak, chest_type) values (c, game_day() - 2, 2, 'bronze');
  r := claim_daily_chest(c);
  perform pg_temp.beklenen('seri bozulunca bastan: Bronz, seri 1', (r ->> 'chest_type') || ':' || (r ->> 'streak'), 'bronze:1');
  perform pg_temp.beklenen('gun siniri Turkiye saati', next_game_day_at() = ((game_day() + 1)::timestamp at time zone 'Europe/Istanbul'), true);

  -- ================== 2) GUNUN ILK GALIBIYETI ==================
  v_mac := pg_temp.mac(a, b);
  perform pg_temp.beklenen('ilk galibiyet kaydi', (select match_id from daily_first_wins where user_id = a and day = game_day()), v_mac);
  perform pg_temp.beklenen('ek XP = o macin galibiyet XP''si (cift)',
    pg_temp.xp('first_win:' || game_day() || ':' || a), pg_temp.xp('match:' || v_mac || ':' || a));
  perform pg_temp.beklenen('ek XP sifirdan buyuk', pg_temp.xp('first_win:' || game_day() || ':' || a) > 0, true);
  perform pg_temp.beklenen('kaybedene ek XP yok', (select count(*)::int from daily_first_wins where user_id = b), 0);
  v_mac2 := pg_temp.mac(a, b);
  perform pg_temp.beklenen('ayni gun ikinci galibiyette ek XP yok',
    (select count(*)::int from economy_ledger where user_id = a and source_type = 'first_win'), 1);
  d := pg_temp.oyuncu('gd_d');
  v_mac := pg_temp.mac(d, b, 'training');
  perform pg_temp.beklenen('antrenman galibiyeti sayilmaz', (select count(*)::int from daily_first_wins where user_id = d), 0);
  perform pg_temp.beklenen('ilk galibiyet hatasi yok', (select count(*)::int from economy_errors where context = 'first_win'), 0);

  -- ================== 3) GUNLUK TEKLIF ==================
  o := daily_shop_offer();
  perform pg_temp.beklenen('teklif %25 indirimli', (o ->> 'discounted_price')::int, (o ->> 'price')::int * 75 / 100);
  perform pg_temp.beklenen('teklif listeden', (o ->> 'pack_slug') in ('standard', 'premium', 'squad'), true);
  perform pg_temp.beklenen('ayni gun herkes icin ayni', daily_shop_offer() ->> 'pack_slug', o ->> 'pack_slug');
  v_altin := (select coins from users where id = a);
  v_kart := (select count(*) from user_cards where owner_id = a);
  r := buy_daily_offer(a);
  perform pg_temp.beklenen('indirimli fiyat odendi', v_altin - (select coins from users where id = a), (o ->> 'discounted_price')::int);
  perform pg_temp.beklenen('paket acildi (kart sayisi kadar)',
    (select count(*)::int from user_cards where owner_id = a) - v_kart, (o ->> 'card_count')::int);
  perform pg_temp.beklenen('defterde tek kayit', (select count(*)::int from economy_ledger where user_id = a and entry_type = 'daily_shop'), 1);
  perform pg_temp.hata_bekle('gunde ikinci alim yok', format('select buy_daily_offer(%L)', a), 'offer_used');
  e := pg_temp.oyuncu('gd_e');
  update users set coins = 10 where id = e;
  perform pg_temp.hata_bekle('altin yetmezse alinmaz', format('select buy_daily_offer(%L)', e), 'Yeterli altin yok');
  perform pg_temp.beklenen('yetmeyen alimda kayit/kart yok',
    (select count(*)::int from daily_shop_purchases where user_id = e) || ':' || (select coins from users where id = e), '0:10');

  -- ================== 4) PAKET SADELESTIRMESI ==================
  perform pg_temp.bayrak(991, '{"pack_duplicates_v2": true}');
  -- c: katalogdaki her futbolcuya sahip -> her cekilis tekrar
  insert into user_cards (owner_id, card_id) select c, id from cards
  where not exists (select 1 from user_cards uc where uc.owner_id = c and uc.card_id = cards.id);
  update users set coins = 100000 where id = c;
  v_kart := (select count(*) from user_cards where owner_id = c);
  v_kopya := (select coalesce(sum(copies), 0) from player_progress where user_id = c);
  r := open_pack(c, 'standard')::jsonb;
  perform pg_temp.beklenen('tekrar kartlar fiziksel kart OLMADI', (select count(*)::int from user_cards where owner_id = c) - v_kart, 0);
  perform pg_temp.beklenen('5 gelisim kopyasi', (select coalesce(sum(copies), 0)::int from player_progress where user_id = c) - v_kopya, 5);
  perform pg_temp.beklenen('yanitta 5 ilerleme (copy)',
    (select count(*)::int from jsonb_array_elements(r -> 'progress') x where x ->> 'outcome' = 'copy'), 5);
  perform pg_temp.beklenen('fiyat ayni (500)', (r ->> 'coins_spent')::int, 500);

  -- seviye 10: joker
  insert into player_progress (user_id, card_id, level) select c, id, 10 from cards
  on conflict (user_id, card_id) do update set level = 10;
  v_joker := (select coalesce(sum(quantity), 0) from user_items where user_id = c and item_slug like 'joker_%');
  r := open_pack(c, 'standard')::jsonb;
  perform pg_temp.beklenen('seviye 10: joker', (select count(*)::int from jsonb_array_elements(r -> 'progress') x where x ->> 'outcome' = 'joker'), 5);
  perform pg_temp.beklenen('joker parcalar envantere eklendi',
    (select coalesce(sum(quantity), 0) from user_items where user_id = c and item_slug like 'joker_%') > v_joker, true);

  -- baslangic paketi haric: yeni oyuncu 15 fiziksel kart
  d := pg_temp.oyuncu('gd_yeni');
  perform pg_temp.beklenen('baslangic paketi 15 fiziksel kart (kural disi)', (select count(*)::int from user_cards where owner_id = d), 15);
end $$;

rollback;
