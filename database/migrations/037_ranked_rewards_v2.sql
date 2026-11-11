-- =====================================================================
-- 037 EKONOMI V2 — DERECELI ODUL KURALLARI R1 / R2 / R3 (KAPALI GELIR)
-- =====================================================================
-- Onay: kullanici (10 Kasim 2026). Plan: docs/EKONOMI_V2_UYGULAMA_PLANI.md
-- Bu dosya tool/ekonomi/migration_uret.py ile mevcut fonksiyon
-- govdelerinden URETILDI; farklar yalniz "037" yorumlu satirlar.
--
--   R1  Her mesru dereceli mac (>= 4 tur, K6) sandik verir; odul enerjisi
--       yoksa sandik Bronz (aninda), XP %25 (035 ayni).
--   R2  Normal dereceli macta kalici kart transferi YOK; galibiyette koruma
--       hakki artmaz (deger silinmez).
--   R3  Galibiyette kazananin aktif destesinden seviyesi < 10 rastgele bir
--       futbolcuya +1 gelisim kopyasi (fiziksel kart degil), tek sefer.
--
-- ETKINLESTIRME: yeni oyun kural surumu 3. current_rules_version() yalniz
-- 'economy_v2_enabled' VE 'ranked_rewards_v2' aciksa 3 doner. Surum mac
-- KURULURKEN matches.rules_version'a yazilir (023): suren maclar eski
-- kurallarla biter. Anahtar migration'da KAPALI; uretimde acilmaz.
--
-- DEGISMEYENLER: play_card, _resolve_round, taktikler (021), kimya (014),
-- kart karsilastirmasi, eslestirme (024), MMR +/-25, galibiyet +100 altin.
-- Gecmis card_transfers / user_cards / match_hands satirlarina DOKUNULMAZ.
-- =====================================================================

-- ---------------------------------------------------------------------
-- OZELLIK ANAHTARLARI: mevcut degerleri KORUYARAK yeni anahtarlar (kapali)
-- (economy_flag en yuksek surumun payload'ini okur; yalniz yeni anahtar
-- eklenseydi economy_v2_enabled kapanirdi.)
-- ---------------------------------------------------------------------
insert into economy_config_versions (kind, version, payload, note)
select 'feature_flags', max(version) + 1,
       (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1)
         || '{"ranked_rewards_v2": false, "item_sources_v2": false}'::jsonb,
       '037/038: dereceli odul kurallari ve item kaynaklari (kapali)'
from economy_config_versions
where kind = 'feature_flags'
  and not ((select payload from economy_config_versions where kind = 'feature_flags'
            order by version desc limit 1) ? 'ranked_rewards_v2')
having count(*) > 0;

-- ---------------------------------------------------------------------
-- OYUN KURAL SURUMU 3 (duello surum 2 ile AYNI: taktikli)
-- ---------------------------------------------------------------------
alter table game_rule_versions add column if not exists card_transfer boolean not null default true;
alter table game_rule_versions add column if not exists win_progress_copies int not null default 0;
alter table game_rule_versions add column if not exists no_energy_chest text;

insert into game_rule_versions (version, name, description, tactics_enabled, card_transfer, win_progress_copies, no_energy_chest)
values (3, 'Taktik + yeni odul', '037: surum 2 duellosu; kart transferi yok, enerjisiz Bronz sandik, galibiyette +1 gelisim kopyasi',
        true, false, 1, 'bronze')
on conflict (version) do nothing;

create or replace function current_rules_version() returns int
language sql stable as $$
  select case when economy_flag('economy_v2_enabled') and economy_flag('ranked_rewards_v2') then 3 else 2 end
$$;

create or replace function rules_card_transfer(p_version int) returns boolean
language sql stable as $$
  select coalesce((select card_transfer from game_rule_versions where version = p_version), true)
$$;

create or replace function _match_no_energy_chest(p_match_id uuid) returns text
language sql stable as $$
  select g.no_energy_chest from matches m join game_rule_versions g on g.version = m.rules_version
  where m.id = p_match_id
$$;

-- ---------------------------------------------------------------------
-- R2: mac bitisi (007'den; yalniz CEZA blogu ve koruma +1 surume bagli)
-- ---------------------------------------------------------------------
create or replace function _finish_match(
  p_match_id uuid,
  p_forced_winner uuid default null   -- teslim / AFK durumunda hukmen galip
)
returns void
language plpgsql
as $$
declare
  m           matches%rowtype;
  v_winner    uuid;
  v_loser     uuid;
  v_draw      boolean := false;
  v_protected uuid[];
  v_penalty   uuid[];
begin
  select * into m from matches where id = p_match_id for update;

  if m.status <> 'active' then
    return;  -- zaten bitmis, iki kez ceza uygulanmasin
  end if;

  -- ---- KAZANANI BELIRLE ----
  if p_forced_winner is not null then
    v_winner := p_forced_winner;
    v_loser  := _opponent_of(m, p_forced_winner);
  elsif m.p1_captured_count > m.p2_captured_count then
    v_winner := m.player1_id; v_loser := m.player2_id;
  elsif m.p2_captured_count > m.p1_captured_count then
    v_winner := m.player2_id; v_loser := m.player1_id;
  else
    v_draw := true;
  end if;

  -- ---- CEZA: Korumasiz 3 rastgele karti kazanana devret ----
  -- 037 (R2): yalniz macin KENDI kural surumu transferi aciyorsa
  -- (surum 1-2: evet; surum 3: hayir). Gecmis transferlere dokunulmaz.
  if not v_draw and rules_card_transfer(m.rules_version) then
    select mp.protected_card_ids into v_protected
    from match_players mp
    where mp.match_id = p_match_id and mp.user_id = v_loser;

    select coalesce(array_agg(t.user_card_id), '{}')
    into v_penalty
    from (
      select mh.user_card_id
      from match_hands mh
      join user_cards uc on uc.id = mh.user_card_id
      where mh.match_id = p_match_id
        and mh.user_id  = v_loser
        and uc.owner_id = v_loser                       -- hala onun mu?
        and not (mh.user_card_id = any (coalesce(v_protected, '{}'::uuid[])))
      order by random()
      limit penalty_card_count()
    ) t;

    if array_length(v_penalty, 1) > 0 then
      -- Denetim kaydi
      insert into card_transfers
        (match_id, user_card_id, card_id, from_user_id, to_user_id, reason)
      select p_match_id, uc.id, uc.card_id, v_loser, v_winner, 'match_penalty'
      from user_cards uc
      where uc.id = any (v_penalty);

      -- Kaybedenin destesinden cikar (kadro artik gecersiz olacak,
      -- oyuncu yeni maca girmeden once kadrosunu tamamlamak zorunda)
      delete from deck_cards where user_card_id = any (v_penalty);

      -- SAHIPLIK DEVRI
      update user_cards
      set owner_id      = v_winner,
          acquired_from = v_loser,
          acquired_at   = now()
      where id = any (v_penalty);
    end if;
  end if;

  -- ---- ISTATISTIK VE ODULLER ----
  if v_draw then
    update users set draws = draws + 1
    where id in (m.player1_id, m.player2_id);
  else
    update users
    set wins             = wins + 1,
        coins            = coins + 100,
        mmr              = mmr + 25,
        -- KART KORUMA HAKKI HER GALIBIYETTE +1 (037: transfersiz surumde
        -- koruma anlamsiz; deger silinmez, artmaz)
        protection_slots = case when rules_card_transfer(m.rules_version)
                                then least(protection_slots + 1, max_protection_slots())
                                else protection_slots end
    where id = v_winner;

    update users
    set losses = losses + 1,
        mmr    = greatest(mmr - 25, 0)
    where id = v_loser;
  end if;

  -- ---- KILITLERI AC ----
  update user_cards set locked_match_id = null
  where locked_match_id = p_match_id;

  -- ---- MACI KAPAT ----
  update matches
  set status      = 'finished',
      winner_id   = v_winner,
      loser_id    = v_loser,
      is_draw     = v_draw,
      finished_at = now()
  where id = p_match_id;

  -- Kuyruk kayitlarini temizle
  delete from matchmaking_queue
  where user_id in (m.player1_id, m.player2_id);
end;
$$;

-- ---------------------------------------------------------------------
-- R1: mac sandigi (031'den; enerjisizse surumun sandigi)
-- ---------------------------------------------------------------------
create or replace function _grant_match_chest(p_user_id uuid, p_match_id uuid, p_result text)
returns uuid
language plpgsql as $$
declare
  k       jsonb := _chest_rules();
  v_tur   text;
  s       user_chest_state%rowtype;
  v_id    uuid;
begin
  -- Zaten verildiyse (tetikleyici tekrari) hicbir sey harcama
  select id into v_id from user_chests
  where source_type = 'match' and source_id = p_match_id::text and user_id = p_user_id;
  if v_id is not null then
    return v_id;
  end if;

  -- ODUL ENERJISI: yoksa sandik yok (mac ve diger oduller aynen)
  if not _reward_energy_spend(p_user_id) then
    perform _ledger_add(p_user_id, 'chest_skipped_no_energy', 0,
                        jsonb_build_object('match_id', p_match_id),
                        'match', p_match_id::text, 'chest_skip:' || p_match_id || ':' || p_user_id);
    -- 037 (R1): kural surumu enerjisiz sandik veriyorsa (surum 3: Bronz,
    -- aninda acilir, yuvaya girmez). Sanssizlik sayaclari ilerlemez;
    -- chest_skip kaydi yukarida yazildi -> sezon XP'si %25 (035 ayni).
    if _match_no_energy_chest(p_match_id) is not null then
      return _grant_chest(p_user_id, _match_no_energy_chest(p_match_id), 'match', p_match_id::text);
    end if;
    return null;
  end if;

  v_tur := _roll_key(k -> 'type_odds' -> p_result);

  -- Sanssizlik korumasi
  insert into user_chest_state (user_id) values (p_user_id) on conflict do nothing;
  select * into s from user_chest_state where user_id = p_user_id for update;
  if s.since_legend + 1 >= (k -> 'pity' ->> 'legend_after')::int then
    v_tur := 'legend';
  elsif s.since_gold + 1 >= (k -> 'pity' ->> 'gold_after')::int and v_tur in ('bronze', 'silver') then
    v_tur := 'gold';
  end if;
  update user_chest_state
  set since_legend = case when v_tur = 'legend' then 0 else since_legend + 1 end,
      since_gold   = case when v_tur in ('gold', 'legend') then 0 else since_gold + 1 end,
      updated_at   = now()
  where user_id = p_user_id;

  return _grant_chest(p_user_id, v_tur, 'match', p_match_id::text);
end;
$$;

-- ---------------------------------------------------------------------
-- R3: galibiyette +1 gelisim kopyasi
-- ---------------------------------------------------------------------
create or replace function _grant_win_progress_copy(p_user_id uuid, p_match_id uuid)
returns jsonb
language plpgsql as $$
declare
  v_adet  int;
  v_kart  cards%rowtype;
  v_max   int := coalesce((_level_rules() ->> 'max_level')::int, 10);
  v_eski  economy_ledger%rowtype;
begin
  select g.win_progress_copies into v_adet
  from matches m join game_rule_versions g on g.version = m.rules_version where m.id = p_match_id;
  if coalesce(v_adet, 0) < 1 then
    return null;
  end if;
  perform pg_advisory_xact_lock(hashtext('wincopy:' || p_user_id::text));
  select * into v_eski from economy_ledger where idempotency_key = 'wincopy:' || p_match_id || ':' || p_user_id;
  if found then
    return v_eski.items;
  end if;

  -- Aktif destedeki, hala sahip olunan, seviyesi < max olan kartlardan biri
  select c.* into v_kart
  from decks d
  join deck_cards dc on dc.deck_id = d.id
  join user_cards uc on uc.id = dc.user_card_id and uc.owner_id = p_user_id
  join cards c on c.id = uc.card_id
  left join player_progress pp on pp.user_id = p_user_id and pp.card_id = c.id
  where d.owner_id = p_user_id and d.is_active and coalesce(pp.level, 1) < v_max
  order by random()
  limit 1;
  if not found then
    return null;
  end if;

  insert into player_progress (user_id, card_id, copies) values (p_user_id, v_kart.id, v_adet)
  on conflict (user_id, card_id) do update
    set copies = player_progress.copies + v_adet, updated_at = now();
  perform _ledger_add(p_user_id, 'win_progress_copy', 0,
                      jsonb_build_object('card_id', v_kart.id, 'full_name', v_kart.full_name,
                                         'tier', v_kart.tier, 'copies', v_adet),
                      'match', p_match_id::text, 'wincopy:' || p_match_id || ':' || p_user_id);
  return jsonb_build_object('card_id', v_kart.id, 'full_name', v_kart.full_name, 'tier', v_kart.tier,
                            'copies', v_adet);
end;
$$;

create or replace function _economy_win_copy_on_match_finished()
returns trigger
language plpgsql as $$
declare
  v_tur int;
begin
  if not economy_flag('economy_v2_enabled') or new.winner_id is null or new.is_draw then
    return null;
  end if;
  select count(*) into v_tur from match_rounds where match_id = new.id;
  if v_tur < coalesce((_chest_rules() ->> 'min_rounds')::int, 4) then
    return null;   -- K6
  end if;
  begin
    perform _grant_win_progress_copy(new.winner_id, new.id);
  exception when others then
    insert into economy_errors (context, user_id, source_id, error)
    values ('win_progress_copy', new.winner_id, new.id::text, sqlerrm);
  end;
  return null;
end;
$$;

drop trigger if exists trg_economy_win_copy_finished on matches;
create trigger trg_economy_win_copy_finished
  after update of status on matches
  for each row
  when (new.status = 'finished' and old.status is distinct from 'finished')
  execute function _economy_win_copy_on_match_finished();

-- ---------------------------------------------------------------------
-- Mac sonu ekrani: sandik + enerjisiz bilgisi + galibiyet kopyasi
-- ---------------------------------------------------------------------
create or replace function get_source_chest(p_user_id uuid, p_source_type text, p_source_id text)
returns jsonb
language sql stable as $$
  select coalesce(
    (select _chest_json(c)
            || jsonb_build_object('no_energy', exists (
                 select 1 from economy_ledger l where l.user_id = p_user_id
                   and l.entry_type = 'chest_skipped_no_energy'
                   and l.source_type = p_source_type and l.source_id = p_source_id))
     from user_chests c
     where c.user_id = p_user_id and c.source_type = p_source_type and c.source_id = p_source_id),
    case when exists (select 1 from economy_ledger l
                      where l.user_id = p_user_id and l.entry_type = 'chest_skipped_no_energy'
                        and l.source_type = p_source_type and l.source_id = p_source_id)
         then jsonb_build_object('skipped', 'no_energy') end,
    '{}'::jsonb)
  || coalesce((select jsonb_build_object('win_copy', l.items) from economy_ledger l
               where p_source_type = 'match'
                 and l.idempotency_key = 'wincopy:' || p_source_id || ':' || p_user_id), '{}'::jsonb)
$$;

-- ---------------------------------------------------------------------
-- YONETICI: 60 gunden eski sezonlar icin guvenli onarim (036'nin eki)
-- ---------------------------------------------------------------------
-- Varsayilan KURU CALISMA: yalniz eksikleri listeler, hicbir sey vermez.
-- p_dry_run => false ile verir. Tek sefer guvencesi 036 ile ayni
-- (season_claims birincil anahtari + defter anahtari). Yalniz KAPANMIS
-- sezonlarda calisir. Kullanim (psql, yonetici):
--   select admin_repair_season_rewards('<sezon id>');           -- rapor
--   select admin_repair_season_rewards('<sezon id>', false);    -- uygula
create or replace function admin_repair_season_rewards(p_season_id uuid, p_dry_run boolean default true)
returns jsonb
language plpgsql as $$
declare
  k       jsonb := _season_rules();
  s       seasons%rowtype;
  us      user_seasons%rowtype;
  t       season_tiers%rowtype;
  v_eksik jsonb := '[]'::jsonb;
  v_n     int := 0;
  v_hata  int := 0;
begin
  select * into s from seasons where id = p_season_id;
  if not found then
    raise exception 'season_not_found: Sezon bulunamadi.';
  end if;
  if s.status <> 'closed' then
    raise exception 'season_not_closed: Yalniz kapanmis sezon onarilir (once close_due_seasons).';
  end if;
  for us in select * from user_seasons where season_id = s.id loop
    for t in select st.* from season_tiers st
             where st.season_id = s.id and st.tier <= _season_tier_of(us.xp, k)
               and (st.track = 'free' or us.premium)
               and not exists (select 1 from season_claims c
                               where c.user_id = us.user_id and c.season_id = s.id
                                 and c.tier = st.tier and c.track = st.track)
             order by st.tier, st.track loop
      v_eksik := v_eksik || jsonb_build_object('user_id', us.user_id, 'tier', t.tier, 'track', t.track);
      if not p_dry_run then
        begin
          perform _season_grant(us.user_id, s.id, t.tier, t.track, true);
          v_n := v_n + 1;
        exception when others then
          v_hata := v_hata + 1;
        end;
      end if;
    end loop;
  end loop;
  if not p_dry_run then
    update economy_errors e set resolved_at = now()
    where e.context = 'season_close' and e.resolved_at is null
      and split_part(e.source_id, ':', 1) = s.id::text
      and exists (select 1 from season_claims c
                  where c.user_id = e.user_id and c.season_id = s.id
                    and c.tier::text = split_part(e.source_id, ':', 2)
                    and c.track = split_part(e.source_id, ':', 3));
  end if;
  return jsonb_build_object('season', s.name, 'dry_run', p_dry_run, 'missing', jsonb_array_length(v_eksik),
                            'granted', v_n, 'failed', v_hata, 'items', v_eksik);
end;
$$;
