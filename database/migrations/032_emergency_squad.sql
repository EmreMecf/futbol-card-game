-- =====================================================================
-- 032 EKONOMI V2 — FAZ 1: ACIL KADRO (kadro kilidi korumasinin 2. parcasi)
-- =====================================================================
-- Tasarim: docs/EKONOMI_V2_TASARIM.md §1.6 (K2, onayli).
--
-- SORUN (kabul testinde canli goruldu): yenilgide 3 kart kaybeden oyuncu
-- bir mevkide formasyonu kuramazsa mac oynayamaz -> sandik da kazanamaz.
-- Standart/Premium paketlerde mevki garantisi yok; mevki garantili
-- Kadro Paketi 4.000 altin. Altini biten oyuncu KALICI kilitlenir.
--
-- COZUM: Kadrosu formasyonu (1 GK, 4 DEF, 4 MID, 2 FWD) karsilamayan
-- oyuncu Bronz kart alir: her mevki "ihtiyac + 1 yedek"e tamamlanir.
-- 24 saatte en fazla 1 kez.
--
-- NEDEN +1 YEDEK? Ekonomi simulasyonu (tool/ekonomi/simulasyon.py,
-- gercekci paket modeli): yalniz eksik sayisi verilince gunde 20 mac
-- oynayan oyuncu 180 gunun 22,5'inde yine kilitleniyordu (acil kadroyu
-- kullaninca ayni gun bir kayipla tekrar kilit). +1 yedekle 0,1 gun.
-- Bronz kart verdigi icin suistimale degmez; duello kurallarina dokunmaz.
-- Ozellik anahtari 'economy_v2_enabled' arkasinda.
-- Tekrar calistirilabilir.
-- =====================================================================

create table if not exists emergency_squad_claims (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references users(id) on delete cascade,
  cards       jsonb not null,
  claimed_at  timestamptz not null default now()
);

create index if not exists idx_emergency_squad_user
  on emergency_squad_claims (user_id, claimed_at desc);

-- Formasyonu kurmak icin her mevkide kac kart EKSIK (fiziksel, maca
-- kilitli olmayan kartlar sayilir)
create or replace function squad_formation_shortage(p_user_id uuid)
returns jsonb
language sql stable as $$
  with ihtiyac as (
    select key::card_position as pos, value::int as gerek
    from jsonb_each_text(coalesce(_chest_rules() -> 'squad_need',
                                  '{"GK":1,"DEF":4,"MID":4,"FWD":2}'::jsonb))
  ), sahip as (
    select c.position as pos, count(*) as n
    from user_cards uc join cards c on c.id = uc.card_id
    where uc.owner_id = p_user_id and uc.locked_match_id is null
    group by c.position
  )
  select coalesce(jsonb_object_agg(i.pos, i.gerek - coalesce(s.n, 0))
                    filter (where coalesce(s.n, 0) < i.gerek), '{}'::jsonb)
  from ihtiyac i left join sahip s on s.pos = i.pos
$$;

-- Verilecek kartlar: her mevki "ihtiyac + yedek"e tamamlanir
create or replace function squad_emergency_grant(p_user_id uuid)
returns jsonb
language sql stable as $$
  with ihtiyac as (
    select key::card_position as pos,
           value::int + coalesce((_chest_rules() ->> 'squad_spare')::int, 1) as hedef
    from jsonb_each_text(coalesce(_chest_rules() -> 'squad_need',
                                  '{"GK":1,"DEF":4,"MID":4,"FWD":2}'::jsonb))
  ), sahip as (
    select c.position as pos, count(*) as n
    from user_cards uc join cards c on c.id = uc.card_id
    where uc.owner_id = p_user_id and uc.locked_match_id is null
    group by c.position
  )
  select coalesce(jsonb_object_agg(i.pos, i.hedef - coalesce(s.n, 0))
                    filter (where coalesce(s.n, 0) < i.hedef), '{}'::jsonb)
  from ihtiyac i left join sahip s on s.pos = i.pos
$$;

create or replace function emergency_squad_status(p_user_id uuid)
returns jsonb
language plpgsql stable as $$
declare
  v_eksik  jsonb := squad_formation_shortage(p_user_id);
  v_son    timestamptz;
  v_sonraki timestamptz;
begin
  select max(claimed_at) into v_son from emergency_squad_claims where user_id = p_user_id;
  v_sonraki := case when v_son is null then null else v_son + interval '24 hours' end;
  return jsonb_build_object(
    'enabled', economy_flag('economy_v2_enabled'),
    'missing', v_eksik,
    'grant', case when v_eksik = '{}'::jsonb then '{}'::jsonb else squad_emergency_grant(p_user_id) end,
    'eligible', economy_flag('economy_v2_enabled') and v_eksik <> '{}'::jsonb
                and (v_sonraki is null or v_sonraki <= now()),
    'next_at', case when v_sonraki > now() then v_sonraki end,
    'server_time', now());
end;
$$;

create or replace function claim_emergency_squad(p_user_id uuid)
returns jsonb
language plpgsql as $$
declare
  v_durum  jsonb;
  r        record;
  v_kart   uuid;
  c        cards%rowtype;
  v_kartlar jsonb := '[]'::jsonb;
  v_id     bigint;
  i        int;
begin
  perform pg_advisory_xact_lock(hashtext('emergency_squad:' || p_user_id::text));
  v_durum := emergency_squad_status(p_user_id);
  if not (v_durum ->> 'enabled')::boolean then
    raise exception 'economy_disabled: Bu ozellik henuz acik degil.';
  end if;
  if v_durum -> 'missing' = '{}'::jsonb then
    raise exception 'squad_complete: Kadron zaten kurulabiliyor.';
  end if;
  if not (v_durum ->> 'eligible')::boolean then
    raise exception 'emergency_cooldown: Acil kadro 24 saatte bir alinabilir.';
  end if;

  for r in select key::card_position as pos, value::int as n from jsonb_each_text(v_durum -> 'grant') loop
    for i in 1 .. r.n loop
      v_kart := _chest_pick_card('bronze', r.pos);
      select * into c from cards where id = v_kart;
      insert into user_cards (owner_id, card_id) values (p_user_id, v_kart);
      insert into player_progress (user_id, card_id) values (p_user_id, v_kart) on conflict do nothing;
      v_kartlar := v_kartlar || jsonb_build_object(
        'card_id', c.id, 'slug', c.slug, 'full_name', c.full_name, 'position', c.position,
        'tier', c.tier, 'power', c.power, 'club', c.club, 'nationality', c.nationality,
        'image_url', c.image_url, 'outcome', 'new');
    end loop;
  end loop;

  insert into emergency_squad_claims (user_id, cards) values (p_user_id, v_kartlar)
  returning id into v_id;
  perform _ledger_add(p_user_id, 'emergency_squad', 0, jsonb_build_object('cards', v_kartlar),
                      'emergency_squad', v_id::text, 'emergency_squad:' || v_id);
  return jsonb_build_object('cards', v_kartlar, 'status', emergency_squad_status(p_user_id));
end;
$$;
