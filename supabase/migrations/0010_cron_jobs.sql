-- =====================================================================
-- 0010 — ZAMANLANMIŞ GÖREVLER (pg_cron)
-- =====================================================================
-- AMAÇ: Süresi dolmuş maçları oyuncuların uygulaması kapalı olsa bile
-- sunucu kendiliğinden kapatsın. Böylece hiçbir maç sonsuza kadar
-- "aktif" kalmaz ve kartlar sonsuza kadar kilitli kalmaz.
--
-- NOT: Supabase Dashboard'da Database -> Extensions bölümünden
-- "pg_cron" eklentisini AÇMAN gerekiyor. Açık değilse bu dosya hata
-- vermeden geçer, ama otomatik kapatma çalışmaz (o durumda sadece
-- claim_turn_timeout devreye girer).
-- =====================================================================

do $$
begin
  create extension if not exists pg_cron with schema extensions;
exception when others then
  raise notice 'pg_cron eklentisi kurulamadi. Dashboard -> Database -> Extensions bolumunden manuel olarak acin.';
end $$;

do $$
begin
  -- Aynı isimli eski görev varsa kaldır (migration tekrar çalıştırılabilsin)
  perform cron.unschedule('futbol_card_timeout_sweep');
exception when others then
  null;
end $$;

do $$
begin
  -- Her 15 saniyede bir süresi dolmuş maçları tara ve hükmen sonuçlandır
  perform cron.schedule(
    'futbol_card_timeout_sweep',
    '15 seconds',
    $cron$ select public.sweep_timed_out_matches(); $cron$
  );
exception when others then
  raise notice 'Cron gorevi olusturulamadi: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------
-- Çalışıyor mu kontrol etmek için:
--   select * from cron.job;
--   select * from cron.job_run_details order by start_time desc limit 20;
--
-- Görevi durdurmak için:
--   select cron.unschedule('futbol_card_timeout_sweep');
-- ---------------------------------------------------------------------
