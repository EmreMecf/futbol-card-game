-- =====================================================================
-- 037 DERECELI ODUL KURALLARI R1 / R2 / R3 — VERITABANI TESTLERI (GERI ALINIR)
-- =====================================================================
-- ESKI (surum 2) ve YENI (surum 3) kurallarla baslayan maclar AYRI test
-- edilir; gecmis transferler ve kart sahiplikleri degismemeli.
-- Yardimcilar 031 testinden (pg_temp.oyna / mac / tam_mac).
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

-- Maci sonuna kadar oynatir: sirasi gelen, zorunlu mevkideki ilk kartini
-- oynar ya da pas gecer. p_tur_siniri kadar tur oynayip teslim de edebilir.
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
      -- Turu acanin karti kalmadi (onceki maclarda kart kaybeden oyuncu
      -- eksik desteyle girdi; gercek oyunda kadro dogrulamasi bunu
      -- engeller). Gercekci son: teslim.
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
create temp table mac_oncesi (user_id uuid primary key, coins int, mmr int, protection_slots int, wins int);

create function pg_temp.tam_mac(p_a uuid, p_b uuid) returns uuid
language plpgsql as $$
declare
  v uuid;
  i int;
begin
  for i in 1..15 loop
    delete from mac_oncesi;
    insert into mac_oncesi select id, coins, mmr, protection_slots, wins from users where id in (p_a, p_b);
    v := pg_temp.mac(p_a, p_b);
    perform pg_temp.oyna(v);
    if (select count(*) from match_rounds where match_id = v) >= 4 then
      return v;
    end if;
  end loop;
  raise exception 'TEST BASARISIZ: 15 denemede 4+ turlu mac cikmadi';
end;
$$;

-- Ortak durum fotografi: butun kart sahiplikleri + transfer gecmisi
create function pg_temp.sahiplik() returns text
language sql as $$
  select md5(coalesce(string_agg(id::text || ':' || owner_id::text, ',' order by id), '')) from user_cards
$$;
create function pg_temp.transfer_ozeti() returns text
language sql as $$
  select count(*) || ':' || md5(coalesce(string_agg(t::text, ',' order by t::text), '')) from card_transfers t
$$;

do $$
declare
  a uuid; b uuid;
  v_mac uuid; v_eski uuid; v_kisa uuid;
  m matches%rowtype;
  kazanan uuid; kaybeden uuid;
  n int;
  sahip_once text; transfer_once text;
  koruma_once int; mmr_k int; mmr_y int; altin_k int; altin_y int; w_once int; l_once int;
  kopya_once int;
  r jsonb;
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

  -- ================== 0) VARSAYILAN KAPALI ==================
  perform pg_temp.beklenen('migration anahtari kapali getirir',
    coalesce((economy_config('feature_flags') ->> 'ranked_rewards_v2')::boolean, false), false);
  perform pg_temp.beklenen('kapaliyken yeni maclar surum 2', current_rules_version(), 2);

  -- Ekonomi acik, yeni kurallar kapali (bugunku davranis)
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 988, '{"economy_v2_enabled": true, "ranked_rewards_v2": false}', 'test');
  perform pg_temp.beklenen('ekonomi acik, yeni kurallar kapali: surum 2', current_rules_version(), 2);

  -- ================== 1) ESKI KURALLA MAC (surum 2): transfer AYNEN ==================
  transfer_once := pg_temp.transfer_ozeti();
  v_mac := pg_temp.tam_mac(a, b);
  select * into m from matches where id = v_mac;
  perform pg_temp.beklenen('eski mac surum 2', m.rules_version, 2);
  if not m.is_draw then
    perform pg_temp.beklenen('eski kural: kaybeden kart verdi',
      (select count(*)::int from card_transfers where match_id = v_mac) > 0, true);
  end if;
  perform pg_temp.beklenen('eski kural: enerjili sandiklar', (select count(*)::int from user_chests
    where source_type = 'match' and source_id = v_mac::text), 2);
  perform pg_temp.beklenen('eski kural: galibiyet kopyasi YOK',
    (select count(*)::int from economy_ledger where idempotency_key like 'wincopy:' || v_mac || ':%'), 0);

  -- ================== 2) ACILMADAN ONCE BASLAYAN MAC eski kurallarla biter ==================
  v_eski := pg_temp.mac(a, b);
  perform pg_temp.beklenen('acilistan once kurulan mac surum 2', (select rules_version from matches where id = v_eski), 2);
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 989, '{"economy_v2_enabled": true, "ranked_rewards_v2": true}', 'test');
  perform pg_temp.beklenen('anahtar acik: yeni maclar surum 3', current_rules_version(), 3);
  perform pg_temp.oyna(v_eski);
  select * into m from matches where id = v_eski;
  perform pg_temp.beklenen('suren mac surumunu korudu', m.rules_version, 2);
  if not m.is_draw then
    perform pg_temp.beklenen('suren eski mac: transfer eski kuralla yapildi',
      (select count(*)::int from card_transfers where match_id = v_eski) > 0, true);
  end if;

  -- ================== 3) YENI KURALLA MAC (surum 3): transfer YOK ==================
  sahip_once := pg_temp.sahiplik();
  transfer_once := pg_temp.transfer_ozeti();
  v_mac := pg_temp.tam_mac(a, b);
  select * into m from matches where id = v_mac;
  perform pg_temp.beklenen('yeni mac surum 3', m.rules_version, 3);
  perform pg_temp.beklenen('yeni kural: bu macta transfer yok',
    (select count(*)::int from card_transfers where match_id = v_mac), 0);
  perform pg_temp.beklenen('gecmis transferler degismedi', pg_temp.transfer_ozeti(), transfer_once);
  perform pg_temp.beklenen('butun kart sahiplikleri ayni', pg_temp.sahiplik(), sahip_once);
  perform pg_temp.beklenen('yeni kural: enerjili sandiklar', (select count(*)::int from user_chests
    where source_type = 'match' and source_id = v_mac::text), 2);

  -- ================== 4) MMR / ALTIN / ISTATISTIK surum 2 ile AYNI; koruma artmaz ==================
  -- (degerler son denemeden HEMEN once mac_oncesi'nde: kisa maclar karismaz)
  loop
    v_mac := pg_temp.tam_mac(a, b);
    select * into m from matches where id = v_mac;
    exit when not m.is_draw;
  end loop;
  kazanan := m.winner_id; kaybeden := m.loser_id;
  perform pg_temp.beklenen('surum 3: kazanan +25 MMR', (select mmr from users where id = kazanan),
    (select mmr from mac_oncesi where user_id = kazanan) + 25);
  perform pg_temp.beklenen('surum 3: kaybeden -25 MMR', (select mmr from users where id = kaybeden),
    greatest((select mmr from mac_oncesi where user_id = kaybeden) - 25, 0));
  perform pg_temp.beklenen('surum 3: kazanan +100 altin (sandik altini acilinca)', (select coins from users where id = kazanan),
    (select coins from mac_oncesi where user_id = kazanan) + 100);
  perform pg_temp.beklenen('surum 3: kaybeden altin ayni', (select coins from users where id = kaybeden),
    (select coins from mac_oncesi where user_id = kaybeden));
  perform pg_temp.beklenen('surum 3: koruma hakki artmaz (silinmez)', (select protection_slots from users where id = kazanan),
    (select protection_slots from mac_oncesi where user_id = kazanan));
  perform pg_temp.beklenen('surum 3: galibiyet sayisi +1', (select wins from users where id = kazanan),
    (select wins from mac_oncesi where user_id = kazanan) + 1);

  -- ================== 5) R3: galibiyette +1 gelisim kopyasi, tek sefer ==================
  perform pg_temp.beklenen('kazanana tek galibiyet kopyasi',
    (select count(*)::int from economy_ledger where idempotency_key = 'wincopy:' || v_mac || ':' || kazanan), 1);
  perform pg_temp.beklenen('kaybedene kopya yok',
    (select count(*)::int from economy_ledger where idempotency_key = 'wincopy:' || v_mac || ':' || kaybeden), 0);
  r := (select items from economy_ledger where idempotency_key = 'wincopy:' || v_mac || ':' || kazanan);
  perform pg_temp.beklenen('kopya aktif destedeki karta', exists (
    select 1 from decks d join deck_cards dc on dc.deck_id = d.id join user_cards uc on uc.id = dc.user_card_id
    where d.owner_id = kazanan and d.is_active and uc.card_id = (r ->> 'card_id')::uuid), true);
  kopya_once := (select copies from player_progress where user_id = kazanan and card_id = (r ->> 'card_id')::uuid);
  r := _grant_win_progress_copy(kazanan, v_mac);
  perform pg_temp.beklenen('ikinci cagri kopya eklemez',
    (select copies from player_progress where user_id = kazanan and card_id = (r ->> 'card_id')::uuid), kopya_once);
  perform pg_temp.beklenen('mac sonu ekrani kopyayi gosterir',
    (get_source_chest(kazanan, 'match', v_mac::text) -> 'win_copy' ->> 'card_id') is not null, true);
  perform pg_temp.beklenen('kopya fiziksel kart eklemez', pg_temp.sahiplik(), sahip_once);

  -- ================== 6) R1: enerjisiz yeni mac -> Bronz sandik, XP %25 ==================
  update reward_energy set energy = 0, refill_anchor = now(), updated_at = now() where user_id in (a, b);
  v_mac := pg_temp.tam_mac(a, b);
  perform pg_temp.beklenen('enerjisiz: iki oyuncuya Bronz', (select count(*)::int from user_chests
    where source_type = 'match' and source_id = v_mac::text and chest_type = 'bronze' and location = 'instant'), 2);
  perform pg_temp.beklenen('enerjisiz: atlama kaydi (XP %25 icin)', (select count(*)::int from economy_ledger
    where entry_type = 'chest_skipped_no_energy' and source_id = v_mac::text), 2);
  perform pg_temp.beklenen('enerjisiz: ekranda no_energy', (get_source_chest(a, 'match', v_mac::text) ->> 'no_energy')::boolean, true);
  perform pg_temp.beklenen('enerjisiz: sezon XP %25', (season_match_xp(a, v_mac) ->> 'no_energy')::boolean, true);
  perform pg_temp.beklenen('enerji negatife inmedi', (reward_energy_state(a) ->> 'energy')::int, 0);

  -- Ayni eski kuralli enerjisiz mac sandik vermez (karsilastirma)
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 990, '{"economy_v2_enabled": true, "ranked_rewards_v2": false}', 'test');
  v_mac := pg_temp.tam_mac(a, b);
  perform pg_temp.beklenen('eski kural enerjisiz: sandik yok', (select count(*)::int from user_chests
    where source_type = 'match' and source_id = v_mac::text), 0);
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 991, '{"economy_v2_enabled": true, "ranked_rewards_v2": true}', 'test');

  -- ================== 7) K6: kisa yeni mac -> sandik da kopya da yok ==================
  v_kisa := pg_temp.mac(a, b);
  perform pg_temp.oyna(v_kisa, 2);
  perform pg_temp.beklenen('kisa mac: sandik yok', (select count(*)::int from user_chests
    where source_type = 'match' and source_id = v_kisa::text), 0);
  perform pg_temp.beklenen('kisa mac: kopya yok', (select count(*)::int from economy_ledger
    where idempotency_key like 'wincopy:' || v_kisa || ':%'), 0);

  -- ================== 8) DUELLO / MMR KODU DEGISMEDI ==================
  select count(*) into n from pg_proc where proname = '_finish_match'
    and prosrc like '%mmr              = mmr + 25%' and prosrc like '%greatest(mmr - 25, 0)%'
    and prosrc like '%coins            = coins + 100%';
  perform pg_temp.beklenen('_finish_match MMR ve altin satirlari aynen', n, 1);
  perform pg_temp.beklenen('surum 3 duellosu taktikli (surum 2 ile ayni)', rules_tactics_enabled(3), true);
  select count(*) into n from pg_proc
  where proname in ('play_card', '_resolve_round', '_create_match')
    and (prosrc ilike '%card_transfer%' or prosrc ilike '%win_progress%' or prosrc ilike '%ranked_rewards%');
  perform pg_temp.beklenen('duello fonksiyonlari yeni kurallari okumaz', n, 0);

  -- ================== 9) GERI ALINABILIR: anahtar kapaninca surum 2 ==================
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 992, '{"economy_v2_enabled": true, "ranked_rewards_v2": false}', 'test');
  perform pg_temp.beklenen('anahtar kapaninca yeni maclar surum 2', current_rules_version(), 2);
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 993, '{"economy_v2_enabled": false, "ranked_rewards_v2": true}', 'test');
  perform pg_temp.beklenen('ekonomi kapaliyken yeni kural ACILMAZ', current_rules_version(), 2);

  raise notice '037 dereceli odul kurallari testleri: HEPSI GECTI';
end;
$$;

rollback;
