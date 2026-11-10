-- =====================================================================
-- 036 SEZON ODUL ONARIMI (HATA DUZELTMESI; EKONOMI KURALI DEGISMEZ)
-- =====================================================================
-- Sorun (docs/EKONOMI_V2_KALITE_KONTROLU.md, konu 7): close_due_seasons()
-- bir odulu verirken hata alirsa hatayi economy_errors'a yaziyor ama
-- sezonu yine "closed" isaretliyordu; yeniden deneme yoktu. Odul KALICI
-- olarak kayboluyordu (denetimde premium 1. kademe formasi).
--
-- Cozum: repair_season_rewards()
--   * Son 60 gunde kapanan sezonlari tarar; ulasilmis ama season_claims
--     kaydi olmayan her odulu verir (ucretsiz yol; premium sahibiyse
--     premium yol) — close_due_seasons ile AYNI uygunluk kurali.
--   * Yalniz economy_errors'a bagli degildir: hata kaydi yazilamamis
--     bosluklari da yakalar.
--   * Tek sefer: season_claims birincil anahtari + _season_grant'in
--     "zaten verildi" yolu. Verilmis odul tekrar verilmez.
--   * Basarili olunca ilgili 'season_close' hatalari resolved_at alir.
--   * Yine hata alirsa yeni hata satiri YAZMAZ (ilk kayit yeter); bir
--     sonraki saatlik calismada tekrar denenir.
-- Sunucu: saatlik zamanlayici close_due_seasons()'tan hemen sonra cagirir.
-- =====================================================================

create or replace function repair_season_rewards(p_days int default 60)
returns int
language plpgsql as $$
declare
  k    jsonb := _season_rules();
  s    seasons%rowtype;
  us   user_seasons%rowtype;
  t    season_tiers%rowtype;
  n    int := 0;
begin
  if k is null then
    return 0;
  end if;
  for s in select * from seasons
           where status = 'closed' and closed_at > now() - make_interval(days => p_days)
           order by number loop
    for us in select * from user_seasons where season_id = s.id loop
      for t in select st.* from season_tiers st
               where st.season_id = s.id and st.tier <= _season_tier_of(us.xp, k)
                 and (st.track = 'free' or us.premium)
                 and not exists (select 1 from season_claims c
                                 where c.user_id = us.user_id and c.season_id = s.id
                                   and c.tier = st.tier and c.track = st.track)
               order by st.tier, st.track loop
        begin
          perform _season_grant(us.user_id, s.id, t.tier, t.track, true);
          n := n + 1;
        exception when others then
          null;  -- ilk hata kaydi economy_errors'ta; sonraki calismada tekrar
        end;
      end loop;
    end loop;
  end loop;

  -- Odulu artik verilmis (onarimla ya da elle) hatalari kapat
  update economy_errors e
  set resolved_at = now()
  where e.context = 'season_close' and e.resolved_at is null
    and exists (select 1 from season_claims c
                where c.user_id = e.user_id
                  and c.season_id::text = split_part(e.source_id, ':', 1)
                  and c.tier::text = split_part(e.source_id, ':', 2)
                  and c.track = split_part(e.source_id, ':', 3));
  return n;
end;
$$;

comment on function repair_season_rewards is
  'Kapanmis sezonlarda hata yuzunden verilemeyen odulleri tek sefer verir (036).';
