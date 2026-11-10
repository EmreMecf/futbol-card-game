-- =====================================================================
-- 029-031 EKONOMI V2 FAZ 1 (SANDIK + ODUL ENERJISI) — VERITABANI TESTLERI
-- =====================================================================
--   psql -h 127.0.0.1 -U futbol -d futbol_card -v ON_ERROR_STOP=1 \
--        -f database/tests/031_chests_test.sql
-- Tek islemde calisir ve GERI ALINIR (ozellik anahtari da). Gereken:
-- aktif destesi olan, aktif maci olmayan en az 2 kullanici.
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

do $$
declare
  a uuid; b uuid; yeni uuid;
  v_mac uuid; v_mac2 uuid;
  n int; n2 int;
  v_id uuid; v_id2 uuid;
  v_sonuc jsonb; v_sonuc2 jsonb;
  altin_once int; altin_sonra int;
  e_once int; e_sonra int;
  kazanan uuid; kaybeden uuid;
  w_once int;
  i int;
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
  -- Temiz baslangic (islem sonunda geri alinir)
  delete from user_chests where user_id in (a, b);
  delete from reward_energy where user_id in (a, b);
  delete from user_chest_state where user_id in (a, b);

  -- ================== 1) ANAHTAR KAPALI: sandik yok ==================
  -- Ortamdan bagimsiz: acikca kapali surum (islem sonunda geri alinir)
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 990, '{"economy_v2_enabled": false}', 'test');
  perform pg_temp.beklenen('anahtar kapali', economy_flag('economy_v2_enabled'), false);
  v_mac := pg_temp.mac(a, b);
  perform pg_temp.oyna(v_mac);
  select count(*) into n from user_chests where source_id = v_mac::text;
  perform pg_temp.beklenen('kapaliyken mac sandik uretmez', n, 0);

  -- Anahtari ac (yeni surum; islem sonunda geri alinir)
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 999, '{"economy_v2_enabled": true}', 'test');
  perform pg_temp.beklenen('anahtar acildi', economy_flag('economy_v2_enabled'), true);

  -- ================== 2) MAC -> HER OYUNCUYA BIR SANDIK ==================
  select (reward_energy_state(a) ->> 'energy')::int into e_once;
  v_mac := pg_temp.tam_mac(a, b);
  w_once := (select coins from mac_oncesi where user_id = a);
  select count(*) into n from user_chests where source_type = 'match' and source_id = v_mac::text;
  perform pg_temp.beklenen('iki oyuncuya birer sandik', n, 2);
  select (reward_energy_state(a) ->> 'energy')::int into e_sonra;
  perform pg_temp.beklenen('odul enerjisi 1 azaldi', e_sonra, e_once - 1);

  -- Mevcut mac odulleri DEGISMEDI: kazanan +100 altin (sandik altini acilinca gelir)
  select winner_id, loser_id into kazanan, kaybeden from matches where id = v_mac;
  if kazanan = a then
    perform pg_temp.beklenen('galibiyet altini aynen +100', (select coins from users where id = a), w_once + 100);
  elsif kazanan is null then
    perform pg_temp.beklenen('beraberlikte altin degismez', (select coins from users where id = a), w_once);
  else
    perform pg_temp.beklenen('yenilgide altin degismez', (select coins from users where id = a), w_once);
  end if;

  -- ================== 3) AYNI MAC IKI KEZ ODUL VERMEZ ==================
  select id into v_id from user_chests where source_id = v_mac::text and user_id = a;
  v_id2 := _grant_match_chest(a, v_mac, 'win');
  perform pg_temp.beklenen('tetikleyici tekrari ayni sandik', v_id2, v_id);
  select count(*) into n from user_chests where source_id = v_mac::text and user_id = a;
  perform pg_temp.beklenen('hala tek sandik', n, 1);
  perform pg_temp.beklenen('tekrar enerji harcamadi', (reward_energy_state(a) ->> 'energy')::int, e_sonra);

  -- ================== 4) KISA MAC (4. turdan once teslim): sandik yok ==================
  v_mac2 := pg_temp.mac(a, b);
  perform pg_temp.oyna(v_mac2, 2);
  perform pg_temp.beklenen('erken teslim edilen mac bitti', (select status from matches where id = v_mac2), 'finished');
  select count(*) into n from user_chests where source_id = v_mac2::text;
  perform pg_temp.beklenen('erken biten macta sandik yok', n, 0);

  -- ================== 5) KILIT ACMA + ACMA (TEK SEFER) ==================
  delete from user_chests where user_id = a;
  v_id := _grant_chest(a, 'silver', 'test', 'gumus-1');
  perform pg_temp.beklenen('gumus yuvaya girdi', (select location from user_chests where id = v_id), 'slot');
  perform pg_temp.hata_bekle('kilitli sandik acilamaz',
    format('select open_chest(%L, %L)', a, v_id), 'chest_locked');
  perform start_chest_unlock(a, v_id);
  perform pg_temp.beklenen('sayac 2 saat',
    (select extract(epoch from unlock_ready_at - unlock_started_at)::int from user_chests where id = v_id), 7200);
  perform pg_temp.hata_bekle('sure dolmadan acilamaz',
    format('select open_chest(%L, %L)', a, v_id), 'chest_not_ready');

  v_id2 := _grant_chest(a, 'gold', 'test', 'altin-1');
  perform pg_temp.hata_bekle('ayni anda iki kilit acilamaz',
    format('select start_chest_unlock(%L, %L)', a, v_id2), 'chest_already_unlocking');
  perform pg_temp.beklenen('baska oyuncu acamaz: bulunamadi',
    (select count(*) from user_chests where id = v_id and user_id = b)::int, 0);
  perform pg_temp.hata_bekle('baskasinin sandigi acilamaz',
    format('select open_chest(%L, %L)', b, v_id), 'chest_not_found');

  -- Sureyi doldur (test: zamani ileri al)
  update user_chests set unlock_ready_at = now() - interval '1 second' where id = v_id;
  altin_once := (select coins from users where id = a);
  v_sonuc := open_chest(a, v_id);
  altin_sonra := (select coins from users where id = a);
  perform pg_temp.beklenen('tam 3 futbolcu', jsonb_array_length(v_sonuc -> 'cards'), 3);
  if (v_sonuc ->> 'coins')::int not between 30 and 50 then
    raise exception 'TEST BASARISIZ: gumus altini 30-50 disinda: %', v_sonuc ->> 'coins';
  end if;
  perform pg_temp.beklenen('altin deftere gore eklendi', altin_sonra, altin_once + (v_sonuc ->> 'coins')::int);
  v_sonuc2 := open_chest(a, v_id);
  perform pg_temp.beklenen('ikinci acma ayni sonuc', v_sonuc2, v_sonuc);
  perform pg_temp.beklenen('ikinci acma altin vermedi', (select coins from users where id = a), altin_sonra);
  select count(*) into n from economy_ledger where idempotency_key = 'chest_open:' || v_id;
  perform pg_temp.beklenen('defterde tek kayit', n, 1);
  perform pg_temp.beklenen('sandik surumunu sakliyor', (select rules_version from user_chests where id = v_id),
    economy_config_version('chest_rules'));

  -- Her kart sonucu ya yeni kart, ya kopya ya da kadro korumasi
  select count(*) into n from jsonb_array_elements(v_sonuc -> 'cards') x
  where x ->> 'outcome' not in ('new', 'copy', 'squad_guard');
  perform pg_temp.beklenen('kart sonuclari gecerli', n, 0);

  -- ================== 6) BRONZ ANINDA ==================
  v_id := _grant_chest(a, 'bronze', 'test', 'bronz-1');
  perform pg_temp.beklenen('bronz aninda hazir', (select status || '/' || location from user_chests where id = v_id),
    'ready/instant');
  perform pg_temp.beklenen('bronz acilir', jsonb_array_length(open_chest(a, v_id) -> 'cards'), 3);

  -- ================== 7) YUVA DOLU -> POSTA -> TELAFI ==================
  delete from user_chests where user_id = a and status <> 'opened';
  for i in 1..4 loop perform _grant_chest(a, 'silver', 'test', 'dolu-' || i); end loop;
  select count(*) into n from user_chests where user_id = a and location = 'slot' and status = 'sealed';
  perform pg_temp.beklenen('4 yuva doldu', n, 4);
  for i in 1..8 loop perform _grant_chest(a, 'gold', 'test', 'posta-' || i); end loop;
  select count(*) into n from user_chests where user_id = a and location = 'mailbox' and status = 'sealed';
  perform pg_temp.beklenen('8 sandik posta kutusunda', n, 8);
  altin_once := (select coins from users where id = a);
  v_id := _grant_chest(a, 'legend', 'test', 'tasma-1');
  perform pg_temp.beklenen('tasan sandik telafi edildi', (select status from user_chests where id = v_id), 'compensated');
  perform pg_temp.beklenen('telafi altini (efsane 450)', (select coins from users where id = a), altin_once + 450);
  perform pg_temp.hata_bekle('telafi edilen sandik acilamaz',
    format('select open_chest(%L, %L)', a, v_id), 'chest_compensated');

  -- Posta kutusundaki acilamaz; yuva bosalinca tasinir
  select id into v_id from user_chests where user_id = a and location = 'mailbox' and status = 'sealed' limit 1;
  perform pg_temp.hata_bekle('postadaki sandik acilamaz',
    format('select open_chest(%L, %L)', a, v_id), 'chest_in_mailbox');
  perform pg_temp.hata_bekle('yuva doluyken postadan alinmaz',
    format('select claim_mailbox_chest(%L, %L)', a, v_id), 'slots_full');
  select id into v_id2 from user_chests where user_id = a and location = 'slot' and slot_no = 2;
  perform start_chest_unlock(a, v_id2);
  update user_chests set unlock_ready_at = now() - interval '1 second' where id = v_id2;
  perform open_chest(a, v_id2);
  perform pg_temp.beklenen('postadan bos yuvaya (2) tasindi',
    (claim_mailbox_chest(a, v_id) ->> 'slot_no')::int, 2);

  -- Posta omru dolunca guvenli telafi
  update user_chests set created_at = now() - interval '8 days'
  where user_id = a and location = 'mailbox' and status = 'sealed';
  select count(*) into n2 from user_chests where user_id = a and location = 'mailbox' and status = 'sealed';
  altin_once := (select coins from users where id = a);
  n := expire_mailbox_chests();
  perform pg_temp.beklenen('omru dolan posta sandiklari telafi', n, n2);
  perform pg_temp.beklenen('altin sandik telafisi 180 x adet', (select coins from users where id = a),
    altin_once + 180 * n2);

  -- ================== 8) ENERJI BITINCE: mac normal, sandik yok ==================
  delete from user_chests where user_id in (a, b);
  update reward_energy set energy = 0, refill_anchor = now() where user_id = a;
  insert into reward_energy (user_id, energy) values (a, 0) on conflict (user_id) do nothing;
  v_mac := pg_temp.tam_mac(a, b);
  perform pg_temp.beklenen('enerjisiz mac yine bitti', (select status from matches where id = v_mac), 'finished');
  select count(*) into n from user_chests where source_id = v_mac::text and user_id = a;
  perform pg_temp.beklenen('enerjisiz oyuncuya sandik yok', n, 0);
  select count(*) into n from user_chests where source_id = v_mac::text and user_id = b;
  perform pg_temp.beklenen('rakibe (enerjili) sandik var', n, 1);
  perform pg_temp.beklenen('enerjisiz atlama deftere yazildi',
    (get_source_chest(a, 'match', v_mac::text) ->> 'skipped'), 'no_energy');

  -- Tembel dolum: 96 dakika sonra 1 enerji
  update reward_energy set refill_anchor = now() - interval '97 minutes', energy = 0 where user_id = a;
  perform pg_temp.beklenen('96 dakikada 1 dolar', (reward_energy_state(a) ->> 'energy')::int, 1);
  update reward_energy set refill_anchor = now() - interval '3 days', energy = 0 where user_id = a;
  perform pg_temp.beklenen('kapasite asilmaz', (reward_energy_state(a) ->> 'energy')::int, 10);

  -- ================== 9) KADRO KILIDI KORUMASI ==================
  insert into users (email, password_hash, username) values ('sandik-test@test.local', 'x', 'sandik_test_yeni')
  returning id into yeni;
  perform pg_temp.beklenen('kartsiz oyuncuda 4 mevki eksik', cardinality(_squad_missing_positions(yeni)), 4);
  v_id := _grant_chest(yeni, 'bronze', 'test', 'koruma-1');
  v_sonuc := open_chest(yeni, v_id);
  select count(*) into n from jsonb_array_elements(v_sonuc -> 'cards') x where x ->> 'outcome' in ('new', 'squad_guard');
  perform pg_temp.beklenen('eksik mevkide hep fiziksel kart', n, 3);
  select count(*) into n from user_cards where owner_id = yeni;
  perform pg_temp.beklenen('3 fiziksel kart eklendi', n, 3);

  -- ================== 10) OLASILIKLAR SURUMLU VE DEGISMEZ ==================
  perform pg_temp.beklenen('olasilik tablosu surumlu', (chest_odds_public() ->> 'version')::int,
    economy_config_version('chest_rules'));
  perform pg_temp.hata_bekle('yayinlanan kural surumu degistirilemez',
    'update economy_config_versions set payload = ''{}'' where kind = ''chest_rules'' and version = 1',
    'degistirilemez');
  -- Her tablodaki agirliklar 1000'e tamamlanir
  select count(*) into n from (
    select value from jsonb_each((select payload from economy_config_versions where kind='chest_rules' and version=1) -> 'type_odds')
    union all
    select y from jsonb_each((select payload from economy_config_versions where kind='chest_rules' and version=1) -> 'slot_odds') t,
           jsonb_array_elements(t.value) y
  ) w where (select sum(v::int) from jsonb_each_text(w.value) x(k, v)) <> 1000;
  perform pg_temp.beklenen('butun olasilik tablolari 1000', n, 0);

  -- ================== 11) DAGILIM: cekilis tabloya uyuyor ==================
  -- 20.000 galibiyet sandigi turu: Bronz %52, Gumus %35, Altin %11, Efsane %2
  -- (tolerans: 4 standart sapmadan genis, yanlis alarm olasiligi ihmal edilebilir)
  create temp table cekilis on commit drop as
    select _roll_key((select payload from economy_config_versions
                      where kind = 'chest_rules' and version = 1) -> 'type_odds' -> 'win') as tur
    from generate_series(1, 20000);
  if abs((select count(*) from cekilis where tur = 'bronze') / 20000.0 - 0.52) > 0.015
     or abs((select count(*) from cekilis where tur = 'silver') / 20000.0 - 0.35) > 0.015
     or abs((select count(*) from cekilis where tur = 'gold') / 20000.0 - 0.11) > 0.01
     or abs((select count(*) from cekilis where tur = 'legend') / 20000.0 - 0.02) > 0.005 then
    raise exception 'TEST BASARISIZ: dagilim tabloya uymuyor: %',
      (select jsonb_object_agg(tur, adet) from (select tur, count(*) adet from cekilis group by tur) t);
  end if;
  raise notice 'OK  20.000 cekilis tabloya uyuyor: %',
    (select jsonb_object_agg(tur, adet) from (select tur, count(*) adet from cekilis group by tur) t);

  raise notice '029-031 sandik ve odul enerjisi testleri: HEPSI GECTI';
end;
$$;

rollback;
