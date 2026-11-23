-- =====================================================================
-- 039 DUELLO KURAL SURUMU 4 (ES ZAMANLI GIZLI SECIM) — TESTLER (GERI ALINIR)
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

create function pg_temp.mac(p_a uuid, p_b uuid) returns uuid
language sql as $$
  select _create_match(
    p_a, (select id from decks where owner_id = p_a and is_active), '{}',
    p_b, (select id from decks where owner_id = p_b and is_active), '{}')
$$;

-- Bir oyuncunun mevkideki en guclu / en zayif oynanmamis karti
create function pg_temp.kart(p_match uuid, p_user uuid, p_pos card_position, p_en_guclu boolean) returns uuid
language sql as $$
  select user_card_id from match_hands
  where match_id = p_match and user_id = p_user and not is_played and position = p_pos
  order by case when p_en_guclu then -(power + coalesce(chemistry, 0)) else power + coalesce(chemistry, 0) end, user_card_id
  limit 1
$$;

-- Iki oyuncunun da kartinin oldugu mevki (inisiyatif sahibinin elinden)
create function pg_temp.ortak_mevki(p_match uuid, p_lead uuid) returns card_position
language sql as $$
  select h.position from match_hands h
  where h.match_id = p_match and h.user_id = p_lead and not h.is_played
    and exists (select 1 from match_hands o where o.match_id = p_match and o.user_id <> p_lead
                and not o.is_played and o.position = h.position)
  order by h.position limit 1
$$;

-- Surum 4 macini sonuna kadar oynatir (herkes en guclu kartini, taktiksiz)
create function pg_temp.oyna4(p_match uuid) returns void
language plpgsql as $$
declare
  m matches%rowtype;
  v_pos card_position;
  i int := 0;
begin
  loop
    select * into m from matches where id = p_match;
    exit when m.status <> 'active' or i > 60;
    i := i + 1;
    if m.phase = 'position' then
      select position into v_pos from match_hands
      where match_id = p_match and user_id = m.lead_player_id and not is_played limit 1;
      perform choose_position(m.lead_player_id, p_match, v_pos);
    else
      -- Pas kaydi olan (mevkide karti olmayan) oyuncu oynamaz
      if not exists (select 1 from match_moves where match_id = p_match and round_number = m.round_number and user_id = m.player1_id) then
        perform play_card(m.player1_id, p_match, pg_temp.kart(p_match, m.player1_id, m.required_position, true));
      end if;
      if (select status from matches where id = p_match) = 'active'
         and not exists (select 1 from match_moves where match_id = p_match and round_number = m.round_number and user_id = m.player2_id) then
        perform play_card(m.player2_id, p_match, pg_temp.kart(p_match, m.player2_id, m.required_position, true));
      end if;
    end if;
  end loop;
end;
$$;

do $$
declare
  a uuid; b uuid; ini uuid; diger uuid;
  v_mac uuid; v_eski uuid;
  m matches%rowtype;
  r json;
  n int; e_once int;
  v_pos card_position;
  transfer_once int;
begin
  select u.id into a from users u join decks d on d.owner_id = u.id and d.is_active
  where get_active_match_id(u.id) is null and validate_deck(u.id, d.id) is null order by u.created_at limit 1;
  select u.id into b from users u join decks d on d.owner_id = u.id and d.is_active
  where get_active_match_id(u.id) is null and validate_deck(u.id, d.id) is null and u.id <> a order by u.created_at limit 1;
  if a is null or b is null then
    raise exception 'TEST BASARISIZ: gecerli destesi olan 2 kullanici yok';
  end if;

  -- ================== 0) VARSAYILAN KAPALI ==================
  perform pg_temp.beklenen('migration anahtari kapali getirir',
    coalesce((economy_config('feature_flags') ->> 'duel_v4')::boolean, false), false);
  insert into economy_config_versions (kind, version, payload, note) values
    ('feature_flags', 980, '{"economy_v2_enabled": true, "ranked_rewards_v2": true, "duel_v4": false}', 'test');
  perform pg_temp.beklenen('duel_v4 kapali: surum 3', current_rules_version(), 3);
  insert into economy_config_versions (kind, version, payload, note) values
    ('feature_flags', 981, '{"economy_v2_enabled": true, "ranked_rewards_v2": false, "duel_v4": true}', 'test');
  perform pg_temp.beklenen('odul kurallari kapaliyken surum 4 ACILMAZ', current_rules_version(), 2);

  -- ================== 1) ESKI MAC (surum 2) AYNEN: sirali akis ==================
  v_eski := pg_temp.mac(a, b);
  select * into m from matches where id = v_eski;
  perform pg_temp.beklenen('eski mac surum 2, asama yok', m.rules_version::text || coalesce(m.phase, '-'), '2-');
  perform pg_temp.hata_bekle('eski macta mevki secimi yok',
    format('select choose_position(%L, %L, %L)', m.lead_player_id, v_eski, 'MID'), 'mevki secimi yok');
  ini := m.current_turn_id;
  perform play_card(ini, v_eski, (select user_card_id from match_hands where match_id = v_eski and user_id = ini limit 1));
  perform pg_temp.beklenen('eski mac: acan oynayinca sira rakipte',
    (select current_turn_id from matches where id = v_eski), _opponent_of(m, ini));
  perform pg_temp.beklenen('eski kuralda duvar 1 enerji', tactic_cost_for(2, 'defensive_wall'), 1);

  -- ================== 2) SURUM 4: MEVKI -> GIZLI SECIM -> COZUM ==================
  insert into economy_config_versions (kind, version, payload, note) values
    ('feature_flags', 982, '{"economy_v2_enabled": true, "ranked_rewards_v2": true, "duel_v4": true}', 'test');
  perform pg_temp.beklenen('uc anahtar acik: surum 4', current_rules_version(), 4);
  perform surrender_match(a, v_eski);   -- acilistan once baslayan mac eski kuralla biter
  perform pg_temp.beklenen('suren eski mac surum 2 ile bitti', (select rules_version from matches where id = v_eski), 2);

  delete from reward_energy where user_id in (a, b);
  v_mac := pg_temp.mac(a, b);
  select * into m from matches where id = v_mac;
  perform pg_temp.beklenen('yeni mac surum 4, mevki asamasi', m.rules_version::text || m.phase, '4position');
  ini := m.lead_player_id; diger := _opponent_of(m, ini);

  perform pg_temp.hata_bekle('mevki secilmeden kart oynanamaz',
    format('select play_card(%L, %L, %L)', ini, v_mac, pg_temp.kart(v_mac, ini, 'MID', true)), 'Once mevki secilmeli');
  perform pg_temp.hata_bekle('mevkiyi yalniz inisiyatif sahibi secer',
    format('select choose_position(%L, %L, %L)', diger, v_mac, 'MID'), 'inisiyatif sahibi');
  r := choose_position(ini, v_mac, 'MID');
  select * into m from matches where id = v_mac;
  perform pg_temp.beklenen('mevki secildi: secim asamasi', m.phase || ':' || m.required_position, 'pick:MID');
  perform pg_temp.beklenen('secim suresi ~15 sn', m.turn_deadline between now() + interval '14 seconds' and now() + interval '16 seconds', true);
  perform pg_temp.hata_bekle('mevki iki kez secilemez',
    format('select choose_position(%L, %L, %L)', ini, v_mac, 'DEF'), 'zaten secildi');
  perform pg_temp.hata_bekle('baska mevkiden kart oynanamaz',
    format('select play_card(%L, %L, %L)', diger, v_mac, pg_temp.kart(v_mac, diger, 'DEF', true)), 'pozisyonunda');

  -- INISIYATIFSIZ oyuncu ONCE oynayabilir (sira yok)
  r := play_card(diger, v_mac, pg_temp.kart(v_mac, diger, 'MID', true));
  perform pg_temp.beklenen('ilk oynayan bekler', r ->> 'phase', 'waiting_opponent');
  perform pg_temp.beklenen('durum: ben oynadim, rakip oynamadi',
    (get_match_state(diger, v_mac) ->> 'i_have_played') || (get_match_state(diger, v_mac) ->> 'opponent_has_played'), 'truefalse');
  perform pg_temp.hata_bekle('ayni turda iki kart oynanamaz',
    format('select play_card(%L, %L, %L)', diger, v_mac, pg_temp.kart(v_mac, diger, 'MID', true)), 'zaten oynadiniz');
  r := play_card(ini, v_mac, pg_temp.kart(v_mac, ini, 'MID', true));
  perform pg_temp.beklenen('ikinci oynayinca tur cozulur', r ->> 'phase', 'round_resolved');
  select * into m from matches where id = v_mac;
  perform pg_temp.beklenen('2. tur, yeniden mevki asamasi', m.round_number::text || m.phase, '2position');
  -- 051: tur sonucu sahnesi payi (3 sn) + mevki suresi (5 sn)
  perform pg_temp.beklenen('mevki suresi ~5 sn + sahne payi', m.turn_deadline between now() + interval '7 seconds' and now() + interval '9 seconds', true);
  perform pg_temp.beklenen('tur kaydi', (select count(*)::int from match_rounds where match_id = v_mac), 1);
  perform pg_temp.beklenen('hamle bayraklari: 1 acan + 1 cevap',
    (select count(*) filter (where is_lead) || '+' || count(*) filter (where not is_lead) from match_moves
     where match_id = v_mac and round_number = 1), '1+1');
  perform pg_temp.beklenen('enerji 2 -> 3 (taktiksiz tur)', (select min(energy) from match_players where match_id = v_mac), 3);

  -- ================== 3) DUVAR 2 ENERJI ==================
  perform pg_temp.beklenen('surum 4 duvar 2 enerji', tactic_cost_for(4, 'defensive_wall'), 2);
  perform pg_temp.beklenen('pres ve kontra ayni (3 / 2)', tactic_cost_for(4, 'high_press') * 10 + tactic_cost_for(4, 'counter_attack'), 32);
  ini := m.lead_player_id; diger := _opponent_of(m, ini);
  v_pos := pg_temp.ortak_mevki(v_mac, ini);
  perform choose_position(ini, v_mac, v_pos);
  perform play_card(ini, v_mac, pg_temp.kart(v_mac, ini, v_pos, true), 'defensive_wall');
  perform play_card(diger, v_mac, pg_temp.kart(v_mac, diger, v_pos, true));
  perform pg_temp.beklenen('duvar kullanan: 3 - 2 + 1 = 2 enerji',
    (select energy from match_players where match_id = v_mac and user_id = ini), 2);
  perform pg_temp.beklenen('kullanmayan: 3 + 1 = 4 enerji',
    (select energy from match_players where match_id = v_mac and user_id = diger), 4);
  select * into m from matches where id = v_mac;
  ini := m.lead_player_id;
  v_pos := pg_temp.ortak_mevki(v_mac, ini);
  perform choose_position(ini, v_mac, v_pos);
  update match_players set energy = 1 where match_id = v_mac and user_id = ini;
  perform pg_temp.hata_bekle('1 enerjiyle duvar kullanilamaz',
    format('select play_card(%L, %L, %L, %L)', ini, v_mac, pg_temp.kart(v_mac, ini, v_pos, true), 'defensive_wall'),
    'yeterli enerjiniz yok');

  -- ================== 4) SURE ASIMI: otomatik en zayif kart ==================
  perform pg_temp.beklenen('sure dolmadan ilerlemez', advance_simultaneous_match(v_mac), 'bekliyor');
  update matches set turn_deadline = now() - interval '1 second' where id = v_mac;
  n := (select round_number from matches where id = v_mac);
  perform pg_temp.beklenen('sure dolunca ilerler', advance_simultaneous_match(v_mac), 'ilerledi');
  perform pg_temp.beklenen('iki oyuncu icin otomatik hamle, taktiksiz',
    (select count(*)::int from match_moves where match_id = v_mac and round_number = n and tactic = 'none'), 2);
  perform pg_temp.beklenen('otomatik sayaci 1', (select min(auto_streak) from match_players where match_id = v_mac), 1);
  -- Elle oynayan sayaci sifirlar. Mevkiyi elle secmek de "buradayim"
  -- demektir; bu yuzden AFK kalan oyuncu inisiyatif sahibi OLMAYAN taraf.
  select * into m from matches where id = v_mac;
  ini := m.lead_player_id; diger := _opponent_of(m, ini);
  v_pos := pg_temp.ortak_mevki(v_mac, ini);
  perform choose_position(ini, v_mac, v_pos);
  perform play_card(ini, v_mac, pg_temp.kart(v_mac, ini, v_pos, false));
  perform pg_temp.beklenen('elle oynayinca sayac 0', (select auto_streak from match_players where match_id = v_mac and user_id = ini), 0);
  perform pg_temp.beklenen('oynamayanin sayaci hala 1', (select auto_streak from match_players where match_id = v_mac and user_id = diger), 1);
  -- Diger oynamaz: sure dolar -> 2. otomatik -> hukmen
  update matches set turn_deadline = now() - interval '1 second' where id = v_mac;
  perform pg_temp.beklenen('ust uste 2 otomatik: hukmen', advance_simultaneous_match(v_mac), 'hukmen');
  select * into m from matches where id = v_mac;
  perform pg_temp.beklenen('oynamayan kaybetti', m.status::text || (m.winner_id = ini)::text, 'finishedtrue');

  -- TEK BOS TUR hukmen degildir (gercek sunucu testinde bulundu): inisiyatif
  -- sahibi hic oynamazsa otomatik mevki + otomatik kart = 1 sayilir.
  v_mac := pg_temp.mac(a, b);
  update matches set turn_deadline = now() - interval '1 second' where id = v_mac;
  perform advance_simultaneous_match(v_mac);           -- otomatik mevki
  update matches set turn_deadline = now() - interval '1 second' where id = v_mac;
  perform pg_temp.beklenen('bos tur sonrasi mac suruyor', advance_simultaneous_match(v_mac), 'ilerledi');
  perform pg_temp.beklenen('iki oyuncunun da sayaci 1', (select string_agg(auto_streak::text, ',') from match_players
    where match_id = v_mac), '1,1');
  -- Ikinci bos tur: ikisi de 2 -> mac o anki skorla biter
  update matches set turn_deadline = now() - interval '1 second' where id = v_mac;
  perform advance_simultaneous_match(v_mac);
  update matches set turn_deadline = now() - interval '1 second' where id = v_mac;
  perform pg_temp.beklenen('iki bos tur, ikisi de yok: mac biter', advance_simultaneous_match(v_mac), 'ikisi_de_yok');

  -- Mevki asamasinda sure asimi: otomatik mevki
  v_mac := pg_temp.mac(a, b);
  update matches set turn_deadline = now() - interval '1 second' where id = v_mac;
  perform advance_simultaneous_match(v_mac);
  perform pg_temp.beklenen('mevki otomatik secildi', (select phase from matches where id = v_mac), 'pick');
  perform pg_temp.beklenen('zamanlayici suresi dolmayana dokunmaz', advance_simultaneous_matches(), 0);
  perform surrender_match(a, v_mac);

  -- Eski zamanlayici surum 4 macina dokunmaz
  v_mac := pg_temp.mac(a, b);
  update matches set turn_deadline = now() - interval '5 minutes' where id = v_mac;
  perform sweep_timed_out_matches();
  perform pg_temp.beklenen('eski sure taramasi surum 4 macini bitirmez', (select status::text from matches where id = v_mac), 'active');
  perform surrender_match(a, v_mac);

  -- ================== 5) TAM MAC: erken bitis, transfer yok, oduller ==================
  delete from user_chests where user_id in (a, b);
  transfer_once := (select count(*) from card_transfers);
  v_mac := pg_temp.mac(a, b);
  perform pg_temp.oyna4(v_mac);
  select * into m from matches where id = v_mac;
  perform pg_temp.beklenen('mac bitti', m.status::text, 'finished');
  n := (select count(*) from match_rounds where match_id = v_mac);
  perform pg_temp.beklenen('6-11 tur', n between 6 and 11, true);
  if greatest(m.p1_captured_count, m.p2_captured_count) >= 12 then
    perform pg_temp.beklenen('12 kartta erken bitti (oynanmamis kart kaldi ya da tam 11 tur)',
      n < 11 or (select count(*) from match_hands where match_id = v_mac and not is_played) = 0, true);
    perform pg_temp.beklenen('kazanan 12+ kart toplayan', m.winner_id,
      case when m.p1_captured_count > m.p2_captured_count then m.player1_id else m.player2_id end);
  end if;
  perform pg_temp.beklenen('kart kilitleri acildi', (select count(*)::int from user_cards where locked_match_id = v_mac), 0);
  perform pg_temp.beklenen('surum 4: kart transferi yok', (select count(*)::int from card_transfers), transfer_once);
  perform pg_temp.beklenen('surum 4: iki oyuncuya sandik', (select count(*)::int from user_chests
    where source_type = 'match' and source_id = v_mac::text), 2);
  if not m.is_draw then
    perform pg_temp.beklenen('surum 4: galibiyet kopyasi', (select count(*)::int from economy_ledger
      where idempotency_key = 'wincopy:' || v_mac || ':' || m.winner_id), 1);
  end if;

  -- ================== 5b) ESIT OLMAYAN ELLER (savunma): mac takilmaz ==================
  -- A eski kurallı macta kart kaybetti (bolum 2): eli kisa. Mevkide karti
  -- olmayana pas yazilir; inisiyatif sahibinin eli biterse inisiyatif gecer.
  v_mac := pg_temp.mac(a, b);
  perform pg_temp.beklenen('eller esit degil (test kurgusu)',
    (select count(*) from match_hands where match_id = v_mac and user_id = a)
      <> (select count(*) from match_hands where match_id = v_mac and user_id = b), true);
  for n in 1..40 loop
    exit when (select status from matches where id = v_mac) <> 'active';
    update matches set turn_deadline = now() - interval '1 second' where id = v_mac;
    perform advance_simultaneous_matches();
    update match_players set auto_streak = 0 where match_id = v_mac;   -- hukmen olmasin
  end loop;
  perform pg_temp.beklenen('esit olmayan ellerle mac zamanlayiciyla sonuna kadar gider',
    (select status::text from matches where id = v_mac), 'finished');
  perform pg_temp.beklenen('zamanlayici hata kaydetmedi',
    (select count(*)::int from economy_errors where context = 'advance_simultaneous' and source_id = v_mac::text), 0);

  -- ================== 6) GIZLILIK ICIN DURUM ALANLARI ==================
  v_mac := pg_temp.mac(a, b);
  r := get_match_state(a, v_mac);
  perform pg_temp.beklenen('durum: es zamanli + asama + maliyetler',
    (r ->> 'simultaneous') || (r ->> 'phase') || (r -> 'tactic_costs' ->> 'defensive_wall') || (r ->> 'early_finish_cards'),
    'trueposition212');
  perform surrender_match(a, v_mac);

  raise notice '039 duello surum 4 testleri: HEPSI GECTI';
end;
$$;

rollback;
