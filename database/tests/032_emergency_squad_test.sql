-- =====================================================================
-- 032 ACIL KADRO — VERITABANI TESTLERI (tek islem, GERI ALINIR)
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
  tam uuid;
  v jsonb;
  n int;
begin
  insert into users (email, password_hash, username) values ('acil-test@test.local', 'x', 'acil_kadro_test')
  returning id into u;
  -- 1 GK, 4 DEF, 2 MID, 1 FWD -> eksik: MID 2, FWD 1
  insert into user_cards (owner_id, card_id)
  select u, id from (
    (select id from cards where position = 'GK'  order by power limit 1) union all
    (select id from cards where position = 'DEF' order by power limit 4) union all
    (select id from cards where position = 'MID' order by power limit 2) union all
    (select id from cards where position = 'FWD' order by power limit 1)) t;

  -- Anahtar kapali (ortamdan bagimsiz: acikca kapali surum)
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 997, '{"economy_v2_enabled": false}', 'test');
  perform pg_temp.hata_bekle('anahtar kapaliyken alinmaz',
    format('select claim_emergency_squad(%L)', u), 'economy_disabled');
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 998, '{"economy_v2_enabled": true}', 'test');

  perform pg_temp.beklenen('eksik mevkiler dogru', squad_formation_shortage(u), '{"MID": 2, "FWD": 1}'::jsonb);
  perform pg_temp.beklenen('hak sahibi', (emergency_squad_status(u) ->> 'eligible')::boolean, true);

  -- Hedef: ihtiyac + 1 yedek -> GK 1->2 (+1), DEF 4->5 (+1), MID 2->5 (+3), FWD 1->3 (+2)
  perform pg_temp.beklenen('verilecek: ihtiyac + 1 yedek', emergency_squad_status(u) -> 'grant',
    '{"GK": 1, "DEF": 1, "MID": 3, "FWD": 2}'::jsonb);
  v := claim_emergency_squad(u);
  perform pg_temp.beklenen('ihtiyac + 1 yedege tamamlandi', jsonb_array_length(v -> 'cards'), 7);
  select count(*) into n from jsonb_array_elements(v -> 'cards') x where x ->> 'tier' <> 'bronze';
  perform pg_temp.beklenen('hepsi Bronz', n, 0);
  perform pg_temp.beklenen('artik eksik yok', squad_formation_shortage(u), '{}'::jsonb);
  select count(*) into n from economy_ledger where user_id = u and entry_type = 'emergency_squad';
  perform pg_temp.beklenen('deftere yazildi', n, 1);

  -- 24 saat kurali: tekrar eksik olsa bile bekler
  delete from user_cards where owner_id = u and card_id in (select id from cards where position = 'FWD');
  perform pg_temp.hata_bekle('24 saat dolmadan tekrar alinmaz',
    format('select claim_emergency_squad(%L)', u), 'emergency_cooldown');
  update emergency_squad_claims set claimed_at = now() - interval '25 hours' where user_id = u;
  perform pg_temp.beklenen('24 saat sonra tekrar hak', (emergency_squad_status(u) ->> 'eligible')::boolean, true);

  -- Kadrosu kurulabilen oyuncu alamaz
  select u2.id into tam from users u2 join decks d on d.owner_id = u2.id and d.is_active
  where validate_deck(u2.id, d.id) is null limit 1;
  perform pg_temp.hata_bekle('kadrosu tam olan alamaz',
    format('select claim_emergency_squad(%L)', tam), 'squad_complete');

  raise notice '032 acil kadro testleri: HEPSI GECTI';
end;
$$;

rollback;
