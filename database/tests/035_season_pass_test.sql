-- =====================================================================
-- 035 BATTLE PASS + GOREVLER — VERITABANI TESTLERI (GERI ALINIR)
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

-- Maci sonuna kadar oynatir (031 testindeki ile ayni); istenirse erken teslim
create function pg_temp.oyna(p_match uuid, p_teslim_tur int default null) returns void
language plpgsql as $$
declare
  m matches%rowtype;
  c uuid;
  i int := 0;
begin
  loop
    select * into m from matches where id = p_match;
    exit when m.status <> 'active';
    if p_teslim_tur is not null and m.round_number >= p_teslim_tur then
      perform surrender_match(m.player1_id, p_match);
      exit;
    end if;
    select user_card_id into c from match_hands
    where match_id = p_match and user_id = m.current_turn_id and not is_played
      and (m.required_position is null or position = m.required_position)
    limit 1;
    if c is null and m.required_position is null then
      perform surrender_match(m.current_turn_id, p_match);
      exit;
    end if;
    perform play_card(m.current_turn_id, p_match, c);
    i := i + 1;
    exit when i > 200;
  end loop;
end;
$$;

create function pg_temp.mac(p_a uuid, p_b uuid) returns uuid
language sql as $$
  select _create_match(
    p_a, (select id from decks where owner_id = p_a and is_active), '{}',
    p_b, (select id from decks where owner_id = p_b and is_active), '{}')
$$;

-- K6 ile uyumlu TAM MAC: rastgele dagitilan ellerle mac bazen 4. turdan
-- once biter (5-9 tur tipik, nadiren daha kisa). K6 geregi kisa macta
-- sandik / XP / gorev / enerji harcamasi YOKTUR; bu yuzden en az 4 turlu
-- bir mac cikana kadar yeniden denemek testin olctugu degerleri bozmaz.
-- (GitHub Actions 42822383188: 031 bolum 8 bu varsayim yuzunden kaldi.)
-- Son denemeden HEMEN ONCEKI altinlar pg_temp mac_oncesi tablosunda.
create temp table mac_oncesi (user_id uuid primary key, coins int);

create function pg_temp.tam_mac(p_a uuid, p_b uuid) returns uuid
language plpgsql as $$
declare
  v uuid;
  i int;
begin
  for i in 1..15 loop
    delete from mac_oncesi;
    insert into mac_oncesi select id, coins from users where id in (p_a, p_b);
    v := pg_temp.mac(p_a, p_b);
    perform pg_temp.oyna(v);
    if (select count(*) from match_rounds where match_id = v) >= 4 then
      return v;
    end if;
  end loop;
  raise exception 'TEST BASARISIZ: 15 denemede 4+ turlu mac cikmadi';
end;
$$;

create function pg_temp.xp(p_user uuid) returns int
language sql as $$ select coalesce((season_overview(p_user) ->> 'xp')::int, 0) $$;

create function pg_temp.gorev(p_user uuid, p_slug text) returns jsonb
language sql as $$
  select m from jsonb_array_elements(missions_overview(p_user) -> 'missions') m where m ->> 'slug' = p_slug
$$;

do $$
declare
  a uuid; b uuid;
  v_mac uuid;
  m matches%rowtype;
  kazanan uuid; kaybeden uuid;
  xa int; xb int; x int;
  v jsonb;
  altin int;
  n int;
  s1 uuid;
  kart uuid;
begin
  select u.id into a from users u join decks d on d.owner_id = u.id and d.is_active
  where get_active_match_id(u.id) is null and validate_deck(u.id, d.id) is null
  order by u.created_at limit 1;
  select u.id into b from users u join decks d on d.owner_id = u.id and d.is_active
  where get_active_match_id(u.id) is null and validate_deck(u.id, d.id) is null and u.id <> a
  order by u.created_at limit 1;
  if a is null or b is null then
    raise exception 'TEST BASARISIZ: gecerli destesi olan 2 kullanici yok';
  end if;
  delete from user_chests where user_id in (a, b);
  delete from reward_energy where user_id in (a, b);

  -- ================== 1) KAPALI: XP yok ==================
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 993, '{"economy_v2_enabled": false}', 'test');
  perform pg_temp.beklenen('kapaliyken overview enabled=false',
    (season_overview(a) ->> 'enabled')::boolean, false);
  v_mac := pg_temp.mac(a, b);
  perform pg_temp.oyna(v_mac);
  perform pg_temp.beklenen('kapaliyken XP defteri yok',
    (select count(*)::int from economy_ledger where entry_type = 'season_xp' and source_id = v_mac::text), 0);

  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 994, '{"economy_v2_enabled": true}', 'test');

  -- ================== 2) SEZON ==================
  v := season_overview(a);
  perform pg_temp.beklenen('sezon olustu', v -> 'season' ->> 'name' is not null, true);
  perform pg_temp.beklenen('50 kademe', jsonb_array_length(v -> 'tiers'), 50);
  s1 := (v -> 'season' ->> 'id')::uuid;
  perform pg_temp.beklenen('ucretsiz yol altini 3000',
    (select sum((reward ->> 'amount')::int)::int from season_tiers where season_id = s1 and track = 'free'), 3000);
  perform pg_temp.beklenen('premium yol altini 4500',
    (select sum((reward ->> 'amount')::int)::int from season_tiers where season_id = s1 and track = 'premium'), 4500);
  perform pg_temp.beklenen('premium satin alma kapali (K4)',
    (v ->> 'premium_purchase_enabled')::boolean, false);
  perform pg_temp.beklenen('ayni sezon tekrar olusmaz', (_current_season()).id, s1);

  -- ================== 3) ENERJILI MAC: XP + gunluk gorev ==================
  v_mac := pg_temp.tam_mac(a, b);
  select * into m from matches where id = v_mac;
  perform pg_temp.beklenen('mac bitti', m.status::text, 'finished');
  if m.is_draw then
    xa := 70 + 150; xb := 70 + 150;
  else
    kazanan := m.winner_id; kaybeden := case when kazanan = a then b else a end;
    xa := case when kazanan = a then 100 else 60 end + 150;
    xb := case when kazanan = b then 100 else 60 end + 150;
  end if;
  perform pg_temp.beklenen('A: mac XP + 1 mac gorevi', pg_temp.xp(a), xa);
  perform pg_temp.beklenen('B: mac XP + 1 mac gorevi', pg_temp.xp(b), xb);
  perform pg_temp.beklenen('mac sonu ekrani XP', (season_match_xp(a, v_mac) ->> 'xp')::int, xa - 150);
  perform pg_temp.beklenen('gunluk 1 mac tamam', (pg_temp.gorev(a, 'daily_play_1') ->> 'completed')::boolean, true);
  perform pg_temp.beklenen('gunluk 2 mac 1/2', (pg_temp.gorev(a, 'daily_play_2') ->> 'progress')::int, 1);
  perform pg_temp.beklenen('ayni mac XP anahtari ikinci kez vermez',
    _season_add_xp(a, 100, 'match', v_mac::text, 'match:' || v_mac || ':' || a), 0);

  -- ================== 4) ENERJISIZ MAC: XP %25 ==================
  update reward_energy set energy = 0, refill_anchor = now(), updated_at = now() where user_id in (a, b);
  xa := pg_temp.xp(a);
  v_mac := pg_temp.tam_mac(a, b);
  select * into m from matches where id = v_mac;
  x := case when m.is_draw then 17 when m.winner_id = a then 25 else 15 end;
  perform pg_temp.beklenen('enerjisiz mac XP %25', (season_match_xp(a, v_mac) ->> 'xp')::int, x);
  perform pg_temp.beklenen('enerjisiz bilgisi', (season_match_xp(a, v_mac) ->> 'no_energy')::boolean, true);
  perform pg_temp.beklenen('gunluk 2 mac tamam (+200)', pg_temp.xp(a), xa + x + 200);

  -- ================== 5) K6: 4. turdan once biten mac ==================
  xa := pg_temp.xp(a);
  v_mac := pg_temp.mac(a, b);
  perform pg_temp.oyna(v_mac, 2);
  perform pg_temp.beklenen('kisa mac XP vermez', pg_temp.xp(a), xa);
  perform pg_temp.beklenen('kisa mac gorev ilerletmez', (pg_temp.gorev(a, 'daily_play_3') ->> 'progress')::int, 2);

  -- ================== 6) ODUL ALMA ==================
  perform pg_temp.hata_bekle('ulasilmamis kademe',
    format('select claim_season_reward(%L, 5, %L)', a, 'free'), 'tier_locked');
  perform dev_season_add_xp(a, 5000);
  altin := (select coins from users where id = a);
  v := claim_season_reward(a, 1, 'free');
  perform pg_temp.beklenen('kademe 1: 93 altin', (select coins from users where id = a), altin + 93);
  v := claim_season_reward(a, 1, 'free');
  perform pg_temp.beklenen('tekrar alma = replay', (v ->> 'replay')::boolean, true);
  perform pg_temp.beklenen('tekrar altin vermez', (select coins from users where id = a), altin + 93);
  perform pg_temp.hata_bekle('premium kilitli',
    format('select claim_season_reward(%L, 1, %L)', a, 'premium'), 'premium_required');
  v := claim_season_reward(a, 3, 'free');
  perform pg_temp.beklenen('kademe 3: gumus sandik', (v ->> 'chest_type'), 'silver');
  perform pg_temp.beklenen('sandik kaydi', (select count(*)::int from user_chests
    where user_id = a and source_type = 'season_tier'), 1);
  v := claim_all_season_rewards(a);
  perform pg_temp.beklenen('kalan ucretsiz 2,4,5 (ve fazlasi) alindi', (v ->> 'count')::int >= 3, true);
  perform pg_temp.beklenen('hepsini al tekrar = 0', (claim_all_season_rewards(a) ->> 'count')::int, 0);

  perform dev_set_season_premium(a, true);
  v := claim_all_season_rewards(a);
  perform pg_temp.beklenen('premium acilinca premium kademeleri alinir', (v ->> 'count')::int >= 5, true);
  perform pg_temp.beklenen('premium kademe 1: forma', _item_qty(a, 'kit_season1'), 1);
  perform pg_temp.beklenen('premium kademe 2: 3 altin joker', _item_qty(a, 'joker_gold') >= 3, true);

  -- ================== 7) DIGER GOREVLER ==================
  select id into kart from user_chests where user_id = a and source_type = 'season_tier' limit 1;
  update user_chests set status = 'opened', opened_at = now() where id = kart;
  perform pg_temp.beklenen('sandik acma gorevi 1/3', (pg_temp.gorev(a, 'weekly_chests_3') ->> 'progress')::int, 1);

  xa := pg_temp.xp(a);
  select card_id into kart from user_cards where owner_id = a limit 1;
  insert into player_progress (user_id, card_id, level) values (a, kart, 1)
  on conflict (user_id, card_id) do update set level = 1;
  update player_progress set level = 5 where user_id = a and card_id = kart;
  perform pg_temp.beklenen('5. seviye gorevi tamam', (pg_temp.gorev(a, 'season_level_5') ->> 'completed')::boolean, true);
  perform pg_temp.beklenen('seviye gorevi +2000 XP', pg_temp.xp(a), xa + 2000);

  insert into sbc_completions (user_id, challenge_id, burned_card_ids)
  select a, id, '{}' from sbc_challenges limit 3;
  perform pg_temp.beklenen('3 SBC gorevi tamam', (pg_temp.gorev(a, 'season_sbc_3') ->> 'completed')::boolean, true);
  perform pg_temp.beklenen('gorev XP kayitlari tek sefer',
    (select count(*)::int from economy_ledger where user_id = a and entry_type = 'season_xp' and source_type = 'mission'),
    (select count(*)::int from user_missions where user_id = a and completed_at is not null));

  -- ================== 8) SEZON KAPANISI ==================
  perform dev_season_add_xp(b, 3000);   -- B hic odul almadi: 3+ kademe
  update seasons set ends_at = now() - interval '1 second', starts_at = now() - interval '30 days' where id = s1;
  n := close_due_seasons();
  perform pg_temp.beklenen('kapanista alinmamis oduller verildi', n > 0, true);
  perform pg_temp.beklenen('B kademe 1 otomatik', (select auto from season_claims
    where user_id = b and season_id = s1 and tier = 1 and track = 'free'), true);
  perform pg_temp.beklenen('B premium yok -> premium otomatik verilmez', (select count(*)::int from season_claims
    where user_id = b and season_id = s1 and track = 'premium'), 0);
  perform pg_temp.beklenen('kapanis tekrar = 0', close_due_seasons(), 0);
  perform pg_temp.beklenen('sezon kapandi', (select status from seasons where id = s1), 'closed');
  v := season_overview(a);
  perform pg_temp.beklenen('yeni sezon 2', (v -> 'season' ->> 'number')::int, 2);
  perform pg_temp.beklenen('yeni sezonda XP 0', (v ->> 'xp')::int, 0);
  perform pg_temp.beklenen('kozmetik kalici', _item_qty(a, 'kit_season1'), 1);

  -- ================== 9) K1: mac/eslestirme sezonu OKUMAZ ==================
  select count(*) into n from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
  where ns.nspname = 'public'
    and p.prosrc ~* '(user_seasons|season_claims|season_xp|user_missions)'
    and p.proname !~ '^(_season|_mission|_current_season|_economy_season|season_|missions_|claim_season|claim_all_season|close_due_seasons|repair_season_rewards|dev_season|dev_set_season)';
  perform pg_temp.beklenen('K1: sezon verisini okuyan baska fonksiyon yok', n, 0);

  raise notice '035 battle pass testleri: HEPSI GECTI';
end;
$$;

rollback;
