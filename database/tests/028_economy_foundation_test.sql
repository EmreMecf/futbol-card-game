-- =====================================================================
-- 028 EKONOMI V2 TEMEL — VERITABANI TESTLERI
-- =====================================================================
--   psql -h 127.0.0.1 -U futbol -d futbol_card -v ON_ERROR_STOP=1 \
--        -f database/tests/028_economy_foundation_test.sql
-- Tek islemde calisir ve GERI ALINIR. Gereken: en az 1 kullanici.
-- =====================================================================
begin;

do $$
declare
  u        uuid;
  once     int;
  sonra    int;
  id1      bigint;
  id2      bigint;
  n        int;
  hata     boolean;
begin
  select id into u from users order by created_at limit 1;
  select coins into once from users where id = u;

  -- 1) Migration anahtari KAPALI yazar (surum 1); tanimsiz anahtar KAPALI.
  --    (Yerel ortamda daha yeni bir surumle acilmis olabilir; o yuzden
  --    etkin deger degil, migration'in yazdigi surum kontrol edilir.)
  if (select payload ->> 'economy_v2_enabled' from economy_config_versions
      where kind = 'feature_flags' and version = 1) <> 'false' then
    raise exception 'TEST BASARISIZ: economy_v2_enabled acik basladi';
  end if;
  if economy_flag('olmayan_anahtar') then
    raise exception 'TEST BASARISIZ: tanimsiz anahtar acik sayildi';
  end if;

  -- 2) Defter: ayni anahtar iki kez -> altin TEK SEFER
  id1 := _ledger_add(u, 'test_odul', 150, '{}', 'test', 't1', 'test-028-anahtar-1');
  id2 := _ledger_add(u, 'test_odul', 150, '{}', 'test', 't1', 'test-028-anahtar-1');
  select coins into sonra from users where id = u;
  if id1 <> id2 then
    raise exception 'TEST BASARISIZ: ayni anahtar iki farkli defter satiri uretti';
  end if;
  if sonra <> once + 150 then
    raise exception 'TEST BASARISIZ: altin % beklenirken %', once + 150, sonra;
  end if;
  select count(*) into n from economy_ledger where idempotency_key = 'test-028-anahtar-1';
  if n <> 1 then
    raise exception 'TEST BASARISIZ: defterde % satir', n;
  end if;
  if (select coins_after from economy_ledger where id = id1) <> once + 150 then
    raise exception 'TEST BASARISIZ: coins_after yanlis';
  end if;

  -- 3) Eksi bakiye yok
  hata := false;
  begin
    perform _ledger_add(u, 'test_harcama', -(sonra + 1), '{}', 'test', 't2', 'test-028-anahtar-2');
  exception when others then hata := true;
  end;
  if not hata then
    raise exception 'TEST BASARISIZ: bakiye eksiye dustu';
  end if;

  -- 4) Ayni anahtar baska tur/oyuncu icin kullanilamaz
  hata := false;
  begin
    perform _ledger_add(u, 'baska_tur', 1, '{}', 'test', 't1', 'test-028-anahtar-1');
  exception when others then hata := true;
  end;
  if not hata then
    raise exception 'TEST BASARISIZ: anahtar carpismasi sessiz gecti';
  end if;

  -- 5) Defter degistirilemez
  hata := false;
  begin
    update economy_ledger set coins_delta = 999999 where id = id1;
  exception when others then hata := true;
  end;
  if not hata then
    raise exception 'TEST BASARISIZ: defter satiri guncellenebildi';
  end if;

  -- 6) Ayar surumleri: yeni surum aktif olur, eski degistirilemez
  insert into economy_config_versions (kind, version, payload)
  values ('test_ayar', 1, '{"x": 1}'), ('test_ayar', 2, '{"x": 2}');
  insert into economy_config_versions (kind, version, payload, active_from)
  values ('test_ayar', 3, '{"x": 3}', now() + interval '1 day');  -- gelecekte
  if (economy_config('test_ayar') ->> 'x') <> '2' or economy_config_version('test_ayar') <> 2 then
    raise exception 'TEST BASARISIZ: aktif surum 2 olmali (3 henuz yayinda degil)';
  end if;
  hata := false;
  begin
    update economy_config_versions set payload = '{"x": 9}' where kind = 'test_ayar' and version = 1;
  exception when others then hata := true;
  end;
  if not hata then
    raise exception 'TEST BASARISIZ: yayinlanmis ayar surumu degistirilebildi';
  end if;

  -- 7) Idempotency anahtari temizligi: 48 saatten eskiler silinir
  insert into idempotency_keys (user_id, key, endpoint, request_hash, created_at)
  values (u, 'test-eski-anahtar-1', '/x', 'h', now() - interval '3 days'),
         (u, 'test-yeni-anahtar-1', '/x', 'h', now());
  perform purge_idempotency_keys();
  if exists (select 1 from idempotency_keys where key = 'test-eski-anahtar-1') then
    raise exception 'TEST BASARISIZ: eski anahtar silinmedi';
  end if;
  if not exists (select 1 from idempotency_keys where key = 'test-yeni-anahtar-1') then
    raise exception 'TEST BASARISIZ: yeni anahtar silindi';
  end if;

  raise notice '028 ekonomi temel testleri: HEPSI GECTI';
end;
$$;

rollback;
