-- =====================================================================
-- 041 BOT RAKIP + ANTRENMAN — TESTLER (GERI ALINIR)
-- =====================================================================
--  0 anahtarlar kapali: bot yok, antrenman reddedilir
--  1 eslestirme botu: 20 sn sonra gelir, rastgele ad, denk kadro,
--    mac sonuna kadar oynanir, PUAN + ODUL normal
--  2 20 sn dolmadan bot yok; gercek rakip varsa once o
--  3 kart transferli kural surumunde (2) bot gelmez
--  4 antrenman: odulsuz, puansiz, transfersiz; sirali kuralla da oynanir
--  5 liderlik tablosu botlari gostermez; bot havuzu yeniden kullanilir
--  6 eski maclar 'ranked'
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

create function pg_temp.kuyruk_bekledi(p_u uuid, p_sn int) returns void
language sql as $$
  update matchmaking_queue set created_at = now() - make_interval(secs => p_sn), updated_at = now() where user_id = p_u
$$;

create function pg_temp.rakip(p_match uuid, p_u uuid) returns uuid
language sql as $$
  select case when player1_id = p_u then player2_id else player1_id end from matches where id = p_match
$$;

-- Insan en guclu kartini oynar; bot bot_tick ile oynar. Sonuna kadar.
create function pg_temp.oyna(p_match uuid, p_insan uuid) returns int
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
    i := i + 1;
    -- bot "dusundu" say (updated_at tetikleyicisi bu islemde kapali)
    update matches set updated_at = now() - interval '1 minute' where id = p_match;

    if rules_simultaneous(m.rules_version) then
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
        order by power desc limit 1;
        perform play_card(p_insan, p_match, v_kart);
      else
        perform bot_tick();
      end if;
    else
      if m.current_turn_id = p_insan then
        select user_card_id into v_kart from match_hands
        where match_id = p_match and user_id = p_insan and not is_played
          and (m.required_position is null or position = m.required_position)
        order by power desc limit 1;
        perform play_card(p_insan, p_match, v_kart);
      else
        perform bot_tick();
      end if;
    end if;
  end loop;
  return i;
end;
$$;

alter table matches disable trigger trg_matches_updated_at;

do $$
declare
  h uuid; h2 uuid; h3 uuid; h4 uuid; h5 uuid; h6 uuid;
  r json;
  v_mac uuid; v_bot uuid;
  u_once users%rowtype; u_sonra users%rowtype;
  n int; v_bot_sayisi int; v_eski_mac int;
  v_ledger int;
begin
  v_eski_mac := (select count(*) from matches);
  h := pg_temp.oyuncu('bt_h1');

  -- ================== 0) VARSAYILAN KAPALI ==================
  perform pg_temp.beklenen('bots_v1 kapali gelir', economy_flag('bots_v1'), false);
  perform pg_temp.beklenen('training_mode kapali gelir', economy_flag('training_mode'), false);
  perform pg_temp.hata_bekle('antrenman kapaliyken reddedilir',
    format('select start_training_match(%L, %L)', h, pg_temp.deste(h)), 'training_disabled');
  r := find_match_or_bot(h, pg_temp.deste(h), '{}');
  perform pg_temp.kuyruk_bekledi(h, 30);
  r := find_match_or_bot(h, pg_temp.deste(h), '{}');
  perform pg_temp.beklenen('kapaliyken 30 sn sonra da bot yok', r ->> 'status', 'queued');
  delete from matchmaking_queue where user_id = h;
  perform pg_temp.beklenen('eski maclar ranked',
    (select count(*)::int from matches where mode <> 'ranked'), 0);

  -- ================== 1) ESLESTIRME BOTU (surum 4) ==================
  perform pg_temp.bayraklar(995, '{"economy_v2_enabled": true, "ranked_rewards_v2": true, "duel_v4": true, "bots_v1": true, "training_mode": true}');
  perform pg_temp.beklenen('surum 4', current_rules_version(), 4);
  v_bot_sayisi := (select count(*) from users where is_bot);

  r := find_match_or_bot(h, pg_temp.deste(h), '{}');
  perform pg_temp.beklenen('ilk istek: kuyrukta', r ->> 'status', 'queued');
  perform pg_temp.kuyruk_bekledi(h, 10);
  r := find_match_or_bot(h, pg_temp.deste(h), '{}');
  perform pg_temp.beklenen('10 sn: henuz bot yok', r ->> 'status', 'queued');
  perform pg_temp.kuyruk_bekledi(h, 21);
  r := find_match_or_bot(h, pg_temp.deste(h), '{}');
  perform pg_temp.beklenen('20 sn sonra bot geldi', r ->> 'status', 'matched');
  v_mac := (r ->> 'match_id')::uuid;
  v_bot := pg_temp.rakip(v_mac, h);
  perform pg_temp.beklenen('rakip bot hesabi', (select is_bot from users where id = v_bot), true);
  perform pg_temp.beklenen('bot adi "Bot" degil (rastgele)', (select username not ilike 'bot%' from users where id = v_bot), true);
  perform pg_temp.beklenen('mac dereceli, surum 4', (select mode || ':' || rules_version from matches where id = v_mac), 'ranked:4');
  perform pg_temp.beklenen('kuyruk eslesti', (select status from matchmaking_queue where user_id = h), 'matched');
  perform pg_temp.beklenen('bot eli 11 kart', (select count(*)::int from match_hands where match_id = v_mac and user_id = v_bot), 11);
  perform pg_temp.beklenen('bot kadrosu ayni dizilis',
    (select string_agg(position::text || ':' || tier::text, ',' order by position, tier) from match_hands where match_id = v_mac and user_id = v_bot),
    (select string_agg(position::text || ':' || tier::text, ',' order by position, tier) from match_hands where match_id = v_mac and user_id = h));
  perform pg_temp.beklenen('bot kadro gucu denk (ort. guc farki <= 3)',
    abs((select avg(power) from match_hands where match_id = v_mac and user_id = v_bot)
      - (select avg(power) from match_hands where match_id = v_mac and user_id = h)) <= 3, true);
  perform pg_temp.beklenen('bot puani oyuncuya yakin',
    abs((select mmr from users where id = v_bot) - (select mmr from users where id = h)) <= 50, true);

  select * into u_once from users where id = h;
  n := pg_temp.oyna(v_mac, h);
  select * into u_sonra from users where id = h;
  perform pg_temp.beklenen('bot macti sonuna kadar oynandi', (select status::text from matches where id = v_mac), 'finished');
  perform pg_temp.beklenen('bot her turda oynadi (otomatik hamle sayaci 0)',
    (select auto_streak from match_players where match_id = v_mac and user_id = v_bot), 0);
  perform pg_temp.beklenen('her turda 2 hamle',
    (select count(*)::int from (select round_number from match_moves where match_id = v_mac group by 1 having count(*) <> 2) x), 0);
  perform pg_temp.beklenen('dereceli bot maci PUAN normal (+-25 / beraberlik 0)',
    u_sonra.mmr - u_once.mmr,
    (select case when winner_id = h then 25 when loser_id = h then -25 else 0 end from matches where id = v_mac));
  perform pg_temp.beklenen('dereceli bot maci gecmiste (rastgele adla)',
    (select opponent_username from get_match_history(h, 100, 0) where match_id = v_mac),
    (select username from users where id = v_bot));
  perform pg_temp.beklenen('dereceli bot maci istatistik sayildi',
    (u_sonra.wins + u_sonra.losses + u_sonra.draws) - (u_once.wins + u_once.losses + u_once.draws), 1);
  perform pg_temp.beklenen('dereceli bot maci ODUL: oyuncuya mac sandigi',
    (select count(*)::int from user_chests where source_type = 'match' and source_id = v_mac::text and user_id = h), 1);
  perform pg_temp.beklenen('kart transferi yok', (select count(*)::int from card_transfers where match_id = v_mac), 0);
  perform pg_temp.beklenen('bot kartlarinin kilidi acildi',
    (select count(*)::int from user_cards where owner_id = v_bot and locked_match_id is not null), 0);
  perform pg_temp.beklenen('bot hatasi yok', (select count(*)::int from economy_errors where context = 'bot_tick'), 0);
  perform pg_temp.beklenen('bir bot uretildi', (select count(*)::int from users where is_bot) - v_bot_sayisi, 1);

  -- ================== 2) GERCEK RAKIP ONCE ==================
  h3 := pg_temp.oyuncu('bt_h3');
  h4 := pg_temp.oyuncu('bt_h4');
  r := find_match_or_bot(h3, pg_temp.deste(h3), '{}');
  perform pg_temp.kuyruk_bekledi(h3, 25);
  r := find_match_or_bot(h4, pg_temp.deste(h4), '{}');
  perform pg_temp.beklenen('bekleyen gercek oyuncu varken bot gelmez', r ->> 'status', 'matched');
  perform pg_temp.beklenen('rakip gercek oyuncu', pg_temp.rakip((r ->> 'match_id')::uuid, h4), h3);
  perform surrender_match(h3, (r ->> 'match_id')::uuid);

  -- ================== 5b) BOT HAVUZU YENIDEN KULLANILIR ==================
  h2 := pg_temp.oyuncu('bt_h2');
  v_bot_sayisi := (select count(*) from users where is_bot);
  r := find_match_or_bot(h2, pg_temp.deste(h2), '{}');
  perform pg_temp.kuyruk_bekledi(h2, 25);
  r := find_match_or_bot(h2, pg_temp.deste(h2), '{}');
  perform pg_temp.beklenen('ikinci bot maci', r ->> 'status', 'matched');
  perform pg_temp.beklenen('bos bot yeniden kullanildi (yeni bot yok)',
    (select count(*)::int from users where is_bot) - v_bot_sayisi, 0);
  perform pg_temp.beklenen('ayni bot kart kopyalarini yeniden kullanir (kart sayisi <= 22)',
    (select count(*) <= 22 from user_cards where owner_id = v_bot), true);
  perform surrender_match(h2, (r ->> 'match_id')::uuid);

  -- ================== 4) ANTRENMAN (surum 4) ==================
  h5 := pg_temp.oyuncu('bt_h5');
  select * into u_once from users where id = h5;
  v_ledger := (select count(*) from economy_ledger where user_id = h5);
  r := start_training_match(h5, pg_temp.deste(h5));
  v_mac := (r ->> 'match_id')::uuid;
  perform pg_temp.beklenen('antrenman maci kuruldu', (select mode from matches where id = v_mac), 'training');
  perform pg_temp.beklenen('antrenman rakibi bot', (select is_bot from users where id = pg_temp.rakip(v_mac, h5)), true);
  r := start_training_match(h5, pg_temp.deste(h5));
  perform pg_temp.beklenen('mac surerken ikinci antrenman acilmaz', r ->> 'status', 'in_match');
  n := pg_temp.oyna(v_mac, h5);
  select * into u_sonra from users where id = h5;
  perform pg_temp.beklenen('antrenman bitti', (select status::text from matches where id = v_mac), 'finished');
  perform pg_temp.beklenen('antrenman: puan degismedi', u_sonra.mmr, u_once.mmr);
  perform pg_temp.beklenen('antrenman: altin degismedi', u_sonra.coins, u_once.coins);
  perform pg_temp.beklenen('antrenman: G/M/B sayilmadi',
    u_sonra.wins || '/' || u_sonra.losses || '/' || u_sonra.draws, u_once.wins || '/' || u_once.losses || '/' || u_once.draws);
  perform pg_temp.beklenen('antrenman: sandik yok', (select count(*)::int from user_chests where source_id = v_mac::text), 0);
  perform pg_temp.beklenen('antrenman: defter (XP/odul) kaydi yok', (select count(*)::int from economy_ledger where user_id = h5), v_ledger);
  perform pg_temp.beklenen('antrenman: transfer yok', (select count(*)::int from card_transfers where match_id = v_mac), 0);
  perform pg_temp.beklenen('antrenman mac gecmisinde yok',
    (select count(*)::int from get_match_history(h5, 100, 0) where match_id = v_mac), 0);
  perform pg_temp.beklenen('antrenman: kart kilitleri acik',
    (select count(*)::int from user_cards where locked_match_id = v_mac), 0);

  -- teslim olma da odulsuz
  select * into u_once from users where id = h5;
  r := start_training_match(h5, pg_temp.deste(h5));
  perform surrender_match(h5, (r ->> 'match_id')::uuid);
  select * into u_sonra from users where id = h5;
  perform pg_temp.beklenen('antrenmanda teslim: puan ve maglubiyet yok',
    u_sonra.mmr || '/' || u_sonra.losses, u_once.mmr || '/' || u_once.losses);

  -- ================== 4b) ANTRENMAN SIRALI KURALLA (surum 3) ==================
  perform pg_temp.bayraklar(996, '{"economy_v2_enabled": true, "ranked_rewards_v2": true, "duel_v4": false, "bots_v1": true, "training_mode": true}');
  h6 := pg_temp.oyuncu('bt_h6');
  r := start_training_match(h6, pg_temp.deste(h6));
  v_mac := (r ->> 'match_id')::uuid;
  perform pg_temp.beklenen('sirali antrenman surum 3', (select rules_version from matches where id = v_mac), 3);
  n := pg_temp.oyna(v_mac, h6);
  perform pg_temp.beklenen('sirali kuralda bot sonuna kadar oynadi', (select status::text from matches where id = v_mac), 'finished');
  perform pg_temp.beklenen('sirali kuralda bot hatasi yok', (select count(*)::int from economy_errors where context = 'bot_tick'), 0);

  -- ================== 3) KART TRANSFERLI SURUMDE BOT YOK ==================
  perform pg_temp.bayraklar(997, '{"economy_v2_enabled": true, "ranked_rewards_v2": false, "duel_v4": false, "bots_v1": true, "training_mode": true}');
  perform pg_temp.beklenen('surum 2 (kart transferli)', rules_card_transfer(current_rules_version()), true);
  r := find_match_or_bot(h6, pg_temp.deste(h6), '{}');
  perform pg_temp.kuyruk_bekledi(h6, 40);
  r := find_match_or_bot(h6, pg_temp.deste(h6), '{}');
  perform pg_temp.beklenen('transferli kuralda bot gelmez', r ->> 'status', 'queued');
  delete from matchmaking_queue where user_id = h6;

  -- ================== 5) LIDERLIK TABLOSU ==================
  update users set mmr = 99999 where id = v_bot;
  perform pg_temp.beklenen('bot liderlik tablosunda yok',
    (select count(*)::int from get_leaderboard(200, 0) l join users u on u.id = l.user_id where u.is_bot), 0);
  perform pg_temp.beklenen('oyuncunun sirasi botu saymaz',
    get_my_leaderboard_position(h),
    (select count(*) + 1 from users u, users me where me.id = h and not u.is_banned and not u.is_bot
       and (u.mmr > me.mmr or (u.mmr = me.mmr and u.wins > me.wins)
            or (u.mmr = me.mmr and u.wins = me.wins and u.created_at < me.created_at))));

  -- ================== 6) ESKI MACLAR ==================
  perform pg_temp.beklenen('test oncesi maclar hala ranked',
    (select count(*)::int from (select * from matches order by created_at limit v_eski_mac) x where mode <> 'ranked'), 0);
end $$;

rollback;
