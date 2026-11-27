-- =====================================================================
-- 036 SEZON ODUL ONARIMI — VERITABANI TESTLERI (GERI ALINIR)
-- =====================================================================
begin;

-- 063 sezon kuralini surum 2'ye gecirdi; bu test 035 tablosuyla (surum 1)
-- yazildi: islem icinde surum 1 icerigi en yeni test surumu olur (geri alinir).
insert into economy_config_versions (kind, version, payload, note)
select 'season_rules', 990, payload, 'test: 035 tablosu'
from economy_config_versions where kind = 'season_rules' and version = 1;

create function pg_temp.beklenen(p_ad text, p_gercek anyelement, p_beklenen anyelement)
returns void language plpgsql as $$
begin
  if p_gercek is distinct from p_beklenen then
    raise exception 'TEST BASARISIZ: % -> beklenen %, gelen %', p_ad, p_beklenen, p_gercek;
  end if;
  raise notice 'OK  %', p_ad;
end;
$$;

do $$
declare
  u uuid; w uuid; s1 uuid;
  n int;
  altin_u int; altin_w int;
  defter int;
  r jsonb;
begin
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 992, '{"economy_v2_enabled": true}', 'test');
  insert into users (email, password_hash, username) values ('onarim-1@test.local', 'x', 'onarim_1') returning id into u;
  insert into users (email, password_hash, username) values ('onarim-2@test.local', 'x', 'onarim_2') returning id into w;

  s1 := (_current_season()).id;
  perform dev_season_add_xp(u, 5000);        -- u: 5 kademe, premium
  perform dev_set_season_premium(u, true);
  perform claim_season_reward(u, 1, 'free');
  perform dev_season_add_xp(w, 2000);        -- w: 2 kademe, ucretsiz

  -- Kapanista premium 1. kademe (forma) verilemesin: item gecici pasif
  update item_definitions set is_active = false where slug = 'kit_season1';
  update seasons set ends_at = now() - interval '1 second', starts_at = now() - interval '30 days' where id = s1;
  n := close_due_seasons();
  perform pg_temp.beklenen('kapanis: forma disindaki oduller verildi (u: free 2-5 + premium 2-5, w: free 1-2)', n, 10);
  perform pg_temp.beklenen('forma verilemedi, hata kaydi var',
    (select count(*)::int from economy_errors where context = 'season_close' and user_id = u and resolved_at is null), 1);
  perform pg_temp.beklenen('forma kaydi yok (eskiden KALICI kayipti)', (select count(*)::int from season_claims
    where user_id = u and season_id = s1 and tier = 1 and track = 'premium'), 0);
  perform pg_temp.beklenen('sezon kapandi', (select status from seasons where id = s1), 'closed');

  -- Sorun surerken onarim: hicbir sey vermez, yeni hata satiri yazmaz
  perform pg_temp.beklenen('sorun surerken onarim 0', repair_season_rewards(), 0);
  perform pg_temp.beklenen('yeni hata satiri yazilmadi',
    (select count(*)::int from economy_errors where context = 'season_close' and user_id = u), 1);

  -- Sorun giderildi: onarim formayi tek sefer verir
  update item_definitions set is_active = true where slug = 'kit_season1';
  altin_u := (select coins from users where id = u);
  altin_w := (select coins from users where id = w);
  defter := (select count(*)::int from economy_ledger where user_id in (u, w));
  perform pg_temp.beklenen('onarim 1 odul verdi', repair_season_rewards(), 1);
  perform pg_temp.beklenen('forma verildi', _item_qty(u, 'kit_season1'), 1);
  perform pg_temp.beklenen('kayit otomatik isaretli', (select auto from season_claims
    where user_id = u and season_id = s1 and tier = 1 and track = 'premium'), true);
  perform pg_temp.beklenen('hata kapandi',
    (select count(*)::int from economy_errors where context = 'season_close' and user_id = u and resolved_at is null), 0);

  -- Iki kez dagitilmaz
  perform pg_temp.beklenen('ikinci onarim 0', repair_season_rewards(), 0);
  perform pg_temp.beklenen('kapanis tekrar 0', close_due_seasons(), 0);
  perform pg_temp.beklenen('forma hala 1', _item_qty(u, 'kit_season1'), 1);
  perform pg_temp.beklenen('u altini degismedi (forma altin degil)', (select coins from users where id = u), altin_u);
  perform pg_temp.beklenen('w altini degismedi', (select coins from users where id = w), altin_w);
  perform pg_temp.beklenen('defterde yalniz forma kaydi eklendi',
    (select count(*)::int from economy_ledger where user_id in (u, w)), defter + 1);
  perform pg_temp.beklenen('her kademe/yol tek kayit', (select count(*)::int from (
    select user_id, tier, track from season_claims where season_id = s1 group by 1, 2, 3 having count(*) > 1) x), 0);
  perform pg_temp.beklenen('u: 5 ucretsiz + 5 premium', (select count(*)::int from season_claims
    where user_id = u and season_id = s1), 10);
  perform pg_temp.beklenen('w: 2 ucretsiz, premium yok', (select count(*)::int from season_claims
    where user_id = w and season_id = s1), 2);

  -- Hata kaydi yazilamamis bosluk: kayit elle silinmis gibi -> onarim yakalar
  delete from season_claims where user_id = w and season_id = s1 and tier = 2 and track = 'free';
  altin_w := (select coins from users where id = w);
  perform pg_temp.beklenen('hata kaydi olmayan bosluk da onarilir', repair_season_rewards(), 1);
  -- 2. kademe ucretsiz odul altin: defter anahtari ayni oldugu icin altin IKINCI KEZ eklenmez
  perform pg_temp.beklenen('defter anahtari ikinci altini engeller', (select coins from users where id = w), altin_w);

  -- 60 GUNDEN ESKI SEZON: saatlik onarim dokunmaz; yonetici (037) guvenli onarir
  update seasons set closed_at = now() - interval '90 days' where id = s1;
  delete from season_claims where user_id = w and season_id = s1 and tier = 1 and track = 'free';
  perform pg_temp.beklenen('saatlik onarim 60 gunden eskiye dokunmaz', repair_season_rewards(), 0);
  r := admin_repair_season_rewards(s1);
  perform pg_temp.beklenen('yonetici kuru calisma: 1 eksik, 0 verildi',
    (r ->> 'missing')::int * 10 + (r ->> 'granted')::int, 10);
  perform pg_temp.beklenen('kuru calisma kayit eklemez', (select count(*)::int from season_claims
    where user_id = w and season_id = s1 and tier = 1 and track = 'free'), 0);
  r := admin_repair_season_rewards(s1, false);
  perform pg_temp.beklenen('yonetici uygular: 1 verildi', (r ->> 'granted')::int, 1);
  perform pg_temp.beklenen('yonetici tekrar: eksik 0', (admin_repair_season_rewards(s1, false) ->> 'missing')::int, 0);
  perform pg_temp.beklenen('her kademe/yol hala tek kayit', (select count(*)::int from (
    select user_id, tier, track from season_claims where season_id = s1 group by 1, 2, 3 having count(*) > 1) x), 0);
  begin
    perform admin_repair_season_rewards((_current_season()).id, false);
    raise exception 'TEST BASARISIZ: acik sezon onarilmamaliydi';
  exception when others then
    if position('season_not_closed' in sqlerrm) = 0 then raise; end if;
    raise notice 'OK  acik sezon yonetici onarimini reddeder';
  end;

  raise notice '036 sezon onarim testleri: HEPSI GECTI';
end;
$$;

rollback;
