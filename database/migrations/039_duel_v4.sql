-- =====================================================================
-- 039 DUELLO KURAL SURUMU 4 — ES ZAMANLI GIZLI SECIM (KAPALI GELIR)
-- =====================================================================
-- Onay: kullanici (11 Kasim 2026). Tasarim: docs/OYUN_TASARIMI_V3.md §1.
-- Olcum: tool/ekonomi/duello_v3.md (ilk inisiyatif %43 -> %48; en uzun
-- mac 16,5 dk -> 3,7 dk).
-- Bu dosya tool/ekonomi/migration_uret_039.py ile mevcut govdelerden
-- URETILDI; play_card / _resolve_round / sweep / get_match_state icindeki
-- farklar yalniz "039" yorumlu satirlar. Surum 1-3 maclarin davranisi
-- DEGISMEZ.
--
-- SURUM 4 TUR AKISI
--   1. MEVKI (5 sn; ilk tur 15 sn): inisiyatif sahibi (lead_player_id)
--      yalniz mevkiyi secer -> choose_position().
--   2. SECIM (15 sn): iki oyuncu o mevkiden kart + taktigi GIZLI oynar ->
--      play_card(). Ikisi de oynayinca tur cozulur (_resolve_round aynen:
--      Efsane kurali, kimya, taktik bonusu, beraberlikte pot ve inisiyatif
--      degisimi).
--   3. Bir oyuncu 12 kart topladiginda mac ERKEN biter.
--   Sure dolarsa: mevki otomatik secilir / o mevkideki EN ZAYIF kart
--   taktiksiz oynanir. Ayni oyuncu UST USTE 2 TURDA karti otomatik
--   oynanirsa hukmen kaybeder (ikisi de ise mac o anki skorla biter).
--   Otomatik mevki secimi sayilmaz; elle mevki secimi sayaci sifirlar.
--   Savunma Duvari 2 enerji (surum 1-3'te 1): es zamanli duzende 1 enerjili
--   duvar her stratejiyi yeniyordu (tool/ekonomi/denge_ara.py).
--
-- ETKINLESTIRME: 'duel_v4' anahtari (KAPALI) + economy_v2_enabled +
-- ranked_rewards_v2 acikken yeni maclar surum 4 kurulur. Odul kurallari
-- surum 3 ile ayni (kart transferi yok, enerjisiz Bronz, galibiyet kopyasi).
-- =====================================================================

insert into economy_config_versions (kind, version, payload, note)
select 'feature_flags', max(version) + 1,
       (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1)
         || '{"duel_v4": false}'::jsonb,
       '039: es zamanli duello (kapali)'
from economy_config_versions
where kind = 'feature_flags'
  and not ((select payload from economy_config_versions where kind = 'feature_flags'
            order by version desc limit 1) ? 'duel_v4')
having count(*) > 0;

alter table game_rule_versions add column if not exists simultaneous boolean not null default false;
alter table game_rule_versions add column if not exists wall_cost int not null default 1;
alter table game_rule_versions add column if not exists early_finish_cards int;
alter table game_rule_versions add column if not exists position_seconds int;
alter table game_rule_versions add column if not exists pick_seconds int;

insert into game_rule_versions
  (version, name, description, tactics_enabled, card_transfer, win_progress_copies, no_energy_chest,
   simultaneous, wall_cost, early_finish_cards, position_seconds, pick_seconds)
values (4, 'Es zamanli duello',
        '039: mevki secimi + gizli es zamanli kart/taktik; 12 kartta erken bitis; duvar 2 enerji; oduller surum 3',
        true, false, 1, 'bronze', true, 2, 12, 5, 15)
on conflict (version) do nothing;

create or replace function current_rules_version() returns int
language sql stable as $$
  select case
    when economy_flag('economy_v2_enabled') and economy_flag('ranked_rewards_v2') and economy_flag('duel_v4') then 4
    when economy_flag('economy_v2_enabled') and economy_flag('ranked_rewards_v2') then 3
    else 2 end
$$;

create or replace function rules_simultaneous(p_version int) returns boolean
language sql stable as $$
  select coalesce((select simultaneous from game_rule_versions where version = p_version), false)
$$;

create or replace function tactic_cost_for(p_version int, p_tactic text) returns int
language sql stable as $$
  select case when p_tactic = 'defensive_wall'
              then coalesce((select wall_cost from game_rule_versions where version = p_version), 1)
              else tactic_cost(p_tactic) end
$$;

alter table matches add column if not exists phase text check (phase in ('position', 'pick'));
alter table match_players add column if not exists auto_streak int not null default 0;

-- Surum 4 maci MEVKI asamasinda baslar (ilk tur: ekran yuklenirken 15 sn)
create or replace function _match_init_simultaneous()
returns trigger language plpgsql as $$
begin
  if rules_simultaneous(new.rules_version) then
    new.phase := 'position';
    new.turn_deadline := now() + interval '15 seconds';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_match_init_simultaneous on matches;
create trigger trg_match_init_simultaneous
  before insert on matches
  for each row execute function _match_init_simultaneous();

-- ---------------------------------------------------------------------
-- 1) MEVKI SECIMI
-- ---------------------------------------------------------------------
create or replace function _choose_position(p_user_id uuid, p_match_id uuid, p_position card_position, p_auto boolean)
returns json
language plpgsql as $$
declare
  m      matches%rowtype;
  v_opp  uuid;
  v_sure int;
begin
  select * into m from matches where id = p_match_id for update;
  if not found then
    raise exception 'Mac bulunamadi.';
  end if;
  if m.status <> 'active' then
    raise exception 'Bu mac sona ermis.';
  end if;
  if not rules_simultaneous(m.rules_version) then
    raise exception 'Bu macta mevki secimi yok.';
  end if;
  if m.phase <> 'position' then
    raise exception 'Mevki zaten secildi.';
  end if;
  if m.lead_player_id <> p_user_id then
    raise exception 'Mevkiyi inisiyatif sahibi secer.';
  end if;
  if not exists (select 1 from match_hands where match_id = p_match_id and user_id = p_user_id
                 and not is_played and position = p_position) then
    raise exception 'Elinizde bu mevkide kart yok.';
  end if;
  v_opp := _opponent_of(m, p_user_id);
  select pick_seconds into v_sure from game_rule_versions where version = m.rules_version;

  update matches
  set required_position = p_position,
      phase             = 'pick',
      turn_deadline     = now() + make_interval(secs => coalesce(v_sure, 15))
  where id = p_match_id;
  -- Otomatik mevki SAYILMAZ (ayni turdaki otomatik kart zaten sayilir;
  -- ikisi birden sayilsaydi tek turluk gecikme hukmen yenilgi olurdu).
  -- Elle mevki secmek "buradayim" demektir: sayac sifirlanir.
  if not p_auto then
    update match_players set auto_streak = 0 where match_id = p_match_id and user_id = p_user_id;
  end if;

  -- Rakibin bu mevkide karti yoksa (esit dizilis oldugu icin beklenmez)
  -- pas kaydi: tur yalniz inisiyatif sahibinin kartiyla cozulur.
  if not exists (select 1 from match_hands where match_id = p_match_id and user_id = v_opp
                 and not is_played and position = p_position) then
    insert into match_moves
      (match_id, user_id, round_number, user_card_id, card_id, position,
       tier, power, chemistry, is_lead, is_pass, tactic)
    values (p_match_id, v_opp, m.round_number, null, null, p_position, null, null, 0, false, true, 'none');
  end if;
  return json_build_object('status', 'ok', 'phase', 'pick', 'position', p_position);
end;
$$;

create or replace function choose_position(p_user_id uuid, p_match_id uuid, p_position card_position)
returns json
language sql as $$ select _choose_position(p_user_id, p_match_id, p_position, false) $$;

-- ---------------------------------------------------------------------
-- 2) GIZLI KART + TAKTIK
-- ---------------------------------------------------------------------
create or replace function _after_round_simultaneous(p_match_id uuid)
returns void
language plpgsql as $$
declare
  m      matches%rowtype;
  g      game_rule_versions%rowtype;
begin
  select * into m from matches where id = p_match_id for update;
  if m.status <> 'active' then
    return;   -- eller bitti, _resolve_round maci kapatti
  end if;
  select * into g from game_rule_versions where version = m.rules_version;
  if g.early_finish_cards is not null
     and greatest(m.p1_captured_count, m.p2_captured_count) >= g.early_finish_cards then
    perform _finish_match(p_match_id);
    return;
  end if;
  -- Inisiyatif sahibinin eli bittiyse (esit dizilisle olmaz; savunma):
  -- rakibin karti varsa inisiyatif ona gecer, yoksa mac biter.
  if not exists (select 1 from match_hands where match_id = p_match_id
                 and user_id = m.lead_player_id and not is_played) then
    if exists (select 1 from match_hands where match_id = p_match_id
               and user_id = _opponent_of(m, m.lead_player_id) and not is_played) then
      update matches set lead_player_id  = _opponent_of(m, m.lead_player_id),
                         current_turn_id = _opponent_of(m, m.lead_player_id)
      where id = p_match_id;
    else
      perform _finish_match(p_match_id);
      return;
    end if;
  end if;
  update matches
  set phase = 'position',
      turn_deadline = now() + make_interval(secs => coalesce(g.position_seconds, 5))
  where id = p_match_id;
end;
$$;

create or replace function _play_card_simultaneous(
  p_user_id uuid, p_match_id uuid, p_user_card_id uuid, p_tactic text, p_auto boolean)
returns json
language plpgsql as $$
declare
  m        matches%rowtype;
  v_hand   match_hands%rowtype;
  v_energy int;
begin
  select * into m from matches where id = p_match_id for update;
  if m.phase <> 'pick' then
    raise exception 'Once mevki secilmeli.';
  end if;
  if p_user_card_id is null then
    raise exception 'Bir kart secmelisiniz.';
  end if;
  if exists (select 1 from match_moves where match_id = p_match_id
             and round_number = m.round_number and user_id = p_user_id) then
    raise exception 'Bu turda kartinizi zaten oynadiniz.';
  end if;
  if not is_valid_tactic(p_tactic) then
    raise exception 'Gecersiz taktik.';
  end if;
  select energy into v_energy from match_players where match_id = p_match_id and user_id = p_user_id;
  if tactic_cost_for(m.rules_version, p_tactic) > coalesce(v_energy, 0) then
    raise exception 'Bu taktik icin yeterli enerjiniz yok.';
  end if;
  select * into v_hand from match_hands
  where match_id = p_match_id and user_id = p_user_id
    and user_card_id = p_user_card_id and not is_played;
  if not found then
    raise exception 'Bu kart elinizde yok veya daha once oynandi.';
  end if;
  if v_hand.position <> m.required_position then
    raise exception 'Bu turda % pozisyonunda kart oynamalisiniz.', m.required_position;
  end if;

  update match_hands set is_played = true, played_round = m.round_number
  where match_id = p_match_id and user_card_id = p_user_card_id;
  insert into match_moves
    (match_id, user_id, round_number, user_card_id, card_id, position,
     tier, power, chemistry, is_lead, is_pass, tactic)
  values
    (p_match_id, p_user_id, m.round_number, v_hand.user_card_id, v_hand.card_id,
     v_hand.position, v_hand.tier, v_hand.power, v_hand.chemistry,
     (m.lead_player_id = p_user_id), false, p_tactic);
  update match_players set auto_streak = case when p_auto then auto_streak + 1 else 0 end
  where match_id = p_match_id and user_id = p_user_id;

  if (select count(*) from match_moves
      where match_id = p_match_id and round_number = m.round_number) < 2 then
    return json_build_object('status', 'ok', 'phase', 'waiting_opponent');
  end if;
  perform _resolve_round(p_match_id);
  perform _after_round_simultaneous(p_match_id);
  return json_build_object('status', 'ok', 'phase', 'round_resolved');
end;
$$;

-- ---------------------------------------------------------------------
-- 3) SURE ASIMI: otomatik mevki / en zayif kart; ust uste 2 -> hukmen
-- ---------------------------------------------------------------------
create or replace function advance_simultaneous_match(p_match_id uuid)
returns text
language plpgsql as $$
declare
  m      matches%rowtype;
  p      uuid;
  v_pos  card_position;
  v_card uuid;
  v_afk  uuid[];
begin
  select * into m from matches where id = p_match_id for update;
  if not found or m.status <> 'active' or not rules_simultaneous(m.rules_version)
     or m.turn_deadline > now() then
    return 'bekliyor';
  end if;

  if m.phase = 'position' then
    -- en cok karti kalan mevki (esitlikte enum sirasi)
    select position into v_pos from match_hands
    where match_id = m.id and user_id = m.lead_player_id and not is_played
    group by position order by count(*) desc, position limit 1;
    perform _choose_position(m.lead_player_id, m.id, v_pos, true);
  else
    foreach p in array array[m.player1_id, m.player2_id] loop
      if not exists (select 1 from match_moves where match_id = m.id
                     and round_number = m.round_number and user_id = p) then
        select user_card_id into v_card from match_hands
        where match_id = m.id and user_id = p and not is_played and position = m.required_position
        order by power + coalesce(chemistry, 0), user_card_id limit 1;
        perform _play_card_simultaneous(p, m.id, v_card, 'none', true);
      end if;
    end loop;
  end if;

  -- Ust uste 2 otomatik hamle: hukmen (mac hala suruyorsa)
  if (select status from matches where id = m.id) = 'active' then
    select array_agg(user_id) into v_afk from match_players where match_id = m.id and auto_streak >= 2;
    if cardinality(v_afk) = 1 then
      perform _finish_match(m.id, _opponent_of(m, v_afk[1]));
      return 'hukmen';
    elsif cardinality(v_afk) = 2 then
      perform _finish_match(m.id);
      return 'ikisi_de_yok';
    end if;
  end if;
  return 'ilerledi';
end;
$$;

-- Zamanlayici (sunucu 1-2 saniyede bir cagirir)
create or replace function advance_simultaneous_matches()
returns int
language plpgsql as $$
declare
  v_id uuid;
  n    int := 0;
begin
  for v_id in select id from matches
              where status = 'active' and phase is not null and turn_deadline <= now()
              order by turn_deadline limit 200 loop
    -- Tek bir bozuk mac butun turu durdurmasin: hata kaydedilir, devam edilir
    begin
      if advance_simultaneous_match(v_id) <> 'bekliyor' then
        n := n + 1;
      end if;
    exception when others then
      insert into economy_errors (context, user_id, source_id, error)
      values ('advance_simultaneous', null, v_id::text, sqlerrm);
    end;
  end loop;
  return n;
end;
$$;

create index if not exists idx_matches_simultaneous_deadline
  on matches (turn_deadline) where status = 'active' and phase is not null;

-- ---------------------------------------------------------------------
-- MEVCUT FONKSIYONLAR (yalniz 039 satirlari eklendi)
-- ---------------------------------------------------------------------
create or replace function play_card(
  p_user_id uuid,
  p_match_id uuid,
  p_user_card_id uuid default null,
  p_tactic text default 'none'
)
returns json
language plpgsql
as $$
declare
  m         matches%rowtype;
  v_hand    match_hands%rowtype;
  v_is_lead boolean;
  v_tactic  text := coalesce(nullif(trim(p_tactic), ''), 'none');
  v_energy  int;
begin
  select * into m from matches where id = p_match_id for update;

  if not found then
    raise exception 'Mac bulunamadi.';
  end if;

  if m.status <> 'active' then
    raise exception 'Bu mac sona ermis.';
  end if;

  if p_user_id not in (m.player1_id, m.player2_id) then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  -- 039: es zamanli kural surumunde (4) ayri akis; eski surumler AYNEN
  if rules_simultaneous(m.rules_version) then
    return _play_card_simultaneous(p_user_id, p_match_id, p_user_card_id, v_tactic, false);
  end if;

  if m.current_turn_id <> p_user_id then
    raise exception 'Sira sizde degil.';
  end if;

  -- ---- TAKTIK DOGRULAMASI (istemciye guvenilmez) ----
  if not is_valid_tactic(v_tactic) then
    raise exception 'Gecersiz taktik.';
  end if;

  if p_user_card_id is null and v_tactic <> 'none' then
    raise exception 'Pas gecerken taktik kullanilamaz.';
  end if;

  -- KURAL SURUMU (023): mac taktiksiz bir surumle basladiysa taktik yok
  if v_tactic <> 'none' and not rules_tactics_enabled(m.rules_version) then
    raise exception 'Bu mac taktiksiz kurallarla oynaniyor.';
  end if;

  select energy into v_energy
  from match_players
  where match_id = p_match_id and user_id = p_user_id;

  if tactic_cost(v_tactic) > coalesce(v_energy, 0) then
    raise exception 'Bu taktik icin yeterli enerjiniz yok.';
  end if;

  v_is_lead := (m.required_position is null);

  -- =========================== TURU ACAN ===========================
  if v_is_lead then
    if p_user_card_id is null then
      raise exception 'Turu acan oyuncu pas gecemez, bir kart secmelisiniz.';
    end if;

    select * into v_hand
    from match_hands
    where match_id = p_match_id and user_id = p_user_id
      and user_card_id = p_user_card_id and not is_played;

    if not found then
      raise exception 'Bu kart elinizde yok veya daha once oynandi.';
    end if;

    update match_hands
    set is_played = true, played_round = m.round_number
    where match_id = p_match_id and user_card_id = p_user_card_id;

    insert into match_moves
      (match_id, user_id, round_number, user_card_id, card_id, position,
       tier, power, chemistry, is_lead, is_pass, tactic)
    values
      (p_match_id, p_user_id, m.round_number, v_hand.user_card_id, v_hand.card_id,
       v_hand.position, v_hand.tier, v_hand.power, v_hand.chemistry, true, false,
       v_tactic);

    update matches
    set required_position = v_hand.position,
        current_turn_id   = _opponent_of(m, p_user_id),
        turn_deadline     = now() + make_interval(secs => turn_timeout_seconds())
    where id = p_match_id;

    return json_build_object('status', 'ok', 'phase', 'waiting_opponent');
  end if;

  -- ========================== CEVAP VEREN ==========================
  if p_user_card_id is null then
    if exists (
      select 1 from match_hands
      where match_id = p_match_id and user_id = p_user_id
        and not is_played and position = m.required_position
    ) then
      raise exception 'Elinizde bu pozisyonda kart var, pas gecemezsiniz.';
    end if;

    insert into match_moves
      (match_id, user_id, round_number, user_card_id, card_id, position,
       tier, power, chemistry, is_lead, is_pass, tactic)
    values
      (p_match_id, p_user_id, m.round_number, null, null,
       m.required_position, null, null, 0, false, true, 'none');
  else
    select * into v_hand
    from match_hands
    where match_id = p_match_id and user_id = p_user_id
      and user_card_id = p_user_card_id and not is_played;

    if not found then
      raise exception 'Bu kart elinizde yok veya daha once oynandi.';
    end if;

    if v_hand.position <> m.required_position then
      raise exception 'Bu turda % pozisyonunda kart oynamalisiniz.',
        m.required_position;
    end if;

    update match_hands
    set is_played = true, played_round = m.round_number
    where match_id = p_match_id and user_card_id = p_user_card_id;

    insert into match_moves
      (match_id, user_id, round_number, user_card_id, card_id, position,
       tier, power, chemistry, is_lead, is_pass, tactic)
    values
      (p_match_id, p_user_id, m.round_number, v_hand.user_card_id, v_hand.card_id,
       v_hand.position, v_hand.tier, v_hand.power, v_hand.chemistry, false, false,
       v_tactic);
  end if;

  perform _resolve_round(p_match_id);

  return json_build_object('status', 'ok', 'phase', 'round_resolved');
end;
$$;

create or replace function _resolve_round(p_match_id uuid)
returns void
language plpgsql
as $$
declare
  m            matches%rowtype;
  v_lead       match_moves%rowtype;
  v_resp       match_moves%rowtype;
  v_cmp        int;
  v_winner     uuid;
  v_is_draw    boolean := false;
  v_cards_won  uuid[];
  v_remaining  int;
  v_lead_bonus int := 0;
  v_resp_bonus int := 0;
  v_taktik     boolean;
begin
  select * into m from matches where id = p_match_id for update;

  -- KURAL SURUMU (023): bu mac hangi kurallarla BASLADIYSA onlarla biter.
  v_taktik := rules_tactics_enabled(m.rules_version);

  select * into v_lead from match_moves
  where match_id = p_match_id and round_number = m.round_number and is_lead;

  select * into v_resp from match_moves
  where match_id = p_match_id and round_number = m.round_number and not is_lead;

  -- ---- KAZANANI BELIRLE ----
  if v_lead.is_pass and not v_resp.is_pass then
    v_winner := v_resp.user_id;
  elsif v_resp.is_pass and not v_lead.is_pass then
    v_winner := v_lead.user_id;
  elsif v_lead.is_pass and v_resp.is_pass then
    v_is_draw := true;
  else
    -- TAKTIK BONUSU (pas varsa karsilastirma yok, bonus da yok;
    -- taktiksiz surumde de yok)
    if v_taktik then
      v_lead_bonus := tactic_bonus(v_lead.tactic, v_resp.tactic, true);
      v_resp_bonus := tactic_bonus(v_resp.tactic, v_lead.tactic, false);
    end if;

    -- Efektif guc = guc + kimya + taktik bonusu.
    -- compare_cards ONCE seviyeye bakar (Legend kurali), sonra guce.
    -- Bu yuzden ne kimya ne taktik bir kartin Legend'i yenmesini
    -- saglayamaz; sadece ayni sinif icinde fark yaratir.
    v_cmp := compare_cards(
      v_lead.tier, v_lead.power + coalesce(v_lead.chemistry, 0) + v_lead_bonus,
      v_resp.tier, v_resp.power + coalesce(v_resp.chemistry, 0) + v_resp_bonus
    );

    if v_cmp = 1 then
      v_winner := v_lead.user_id;
    elsif v_cmp = -1 then
      v_winner := v_resp.user_id;
    else
      v_is_draw := true;
    end if;
  end if;

  -- Bonuslari gosterim icin kaydet
  update match_moves set tactic_bonus = v_lead_bonus where id = v_lead.id;
  update match_moves set tactic_bonus = v_resp_bonus where id = v_resp.id;

  -- ENERJI: bu turun maliyetini dus, sonraki tur icin +1 ekle (en fazla 5).
  -- Maliyet play_card'da zaten dogrulandi, eksiye dusmez.
  update match_players mp
  set energy = case when not v_taktik then mp.energy else least(
        tactic_max_energy(),
        greatest(0, mp.energy - tactic_cost_for(m.rules_version, mv.tactic)) + tactic_energy_per_round()
      ) end
  from match_moves mv
  where mp.match_id = p_match_id
    and mv.match_id = p_match_id
    and mv.round_number = m.round_number
    and mv.user_id = mp.user_id;

  v_cards_won := m.pot_card_ids
                 || array_remove(array[v_lead.user_card_id, v_resp.user_card_id], null);

  if v_is_draw then
    update matches
    set pot_card_ids      = v_cards_won,
        round_number      = round_number + 1,
        required_position = null,
        lead_player_id    = _opponent_of(m, m.lead_player_id),
        current_turn_id   = _opponent_of(m, m.lead_player_id),
        turn_deadline     = now() + make_interval(secs => turn_timeout_seconds())
    where id = p_match_id;

    insert into match_rounds (match_id, round_number, winner_id, is_draw, cards_won)
    values (p_match_id, m.round_number, null, true, '{}');
  else
    update match_players
    set captured_card_ids = captured_card_ids || v_cards_won
    where match_id = p_match_id and user_id = v_winner;

    update matches
    set pot_card_ids      = '{}',
        round_number      = round_number + 1,
        required_position = null,
        lead_player_id    = v_winner,
        current_turn_id   = v_winner,
        turn_deadline     = now() + make_interval(secs => turn_timeout_seconds()),
        p1_captured_count = p1_captured_count +
                            case when v_winner = m.player1_id
                                 then coalesce(array_length(v_cards_won, 1), 0) else 0 end,
        p2_captured_count = p2_captured_count +
                            case when v_winner = m.player2_id
                                 then coalesce(array_length(v_cards_won, 1), 0) else 0 end
    where id = p_match_id;

    insert into match_rounds (match_id, round_number, winner_id, is_draw, cards_won)
    values (p_match_id, m.round_number, v_winner, false, v_cards_won);
  end if;

  select count(*) into v_remaining
  from match_hands where match_id = p_match_id and not is_played;

  if v_remaining = 0 then
    perform _finish_match(p_match_id);
  end if;
end;
$$;

create or replace function sweep_timed_out_matches()
returns int
language plpgsql
as $$
declare
  m       matches%rowtype;
  v_count int := 0;
begin
  for m in
    select * from matches
    where status = 'active'
      and not rules_simultaneous(rules_version)   -- 039: surum 4'u advance_simultaneous_matches yurutur
      and turn_deadline + make_interval(secs => afk_grace_seconds()) < now()
    order by turn_deadline
    limit 200
  loop
    perform _finish_match(m.id, _opponent_of(m, m.current_turn_id));
    v_count := v_count + 1;
  end loop;

  -- Bayat eslestirme kuyrugu kayitlarini da temizle
  delete from matchmaking_queue
  where status = 'searching' and updated_at < now() - interval '2 minutes';

  return v_count;
end;
$$;

create or replace function get_match_state(p_user_id uuid, p_match_id uuid)
returns json
language plpgsql
stable
as $$
declare
  m     matches%rowtype;
  v_opp uuid;
begin
  select * into m from matches where id = p_match_id;

  if not found or p_user_id not in (m.player1_id, m.player2_id) then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  v_opp := _opponent_of(m, p_user_id);

  return json_build_object(
    'match_id',          m.id,
    'status',            m.status,
    'round_number',      m.round_number,
    'is_my_turn',        (m.current_turn_id = p_user_id),
    'am_i_lead',         (m.lead_player_id = p_user_id),
    'required_position', m.required_position,
    'turn_deadline',     m.turn_deadline,
    'server_time',       now(),
    'pot_count',         coalesce(array_length(m.pot_card_ids, 1), 0),
    'my_score',          case when m.player1_id = p_user_id
                              then m.p1_captured_count else m.p2_captured_count end,
    'opponent_score',    case when m.player1_id = p_user_id
                              then m.p2_captured_count else m.p1_captured_count end,
    'my_cards_left',     (select count(*) from match_hands
                          where match_id = m.id and user_id = p_user_id and not is_played),
    'opponent_cards_left', (select count(*) from match_hands
                          where match_id = m.id and user_id = v_opp and not is_played),
    'my_energy',         (select energy from match_players
                          where match_id = m.id and user_id = p_user_id),
    'opponent_energy',   (select energy from match_players
                          where match_id = m.id and user_id = v_opp),
    'max_energy',        tactic_max_energy(),
    'rules_version',     m.rules_version,
    'tactics_enabled',   rules_tactics_enabled(m.rules_version),
    -- 039: es zamanli duello bilgileri (eski surumlerde simultaneous=false)
    'simultaneous',      rules_simultaneous(m.rules_version),
    'phase',             m.phase,
    'i_have_played',     exists (select 1 from match_moves mv where mv.match_id = m.id
                                 and mv.round_number = m.round_number and mv.user_id = p_user_id),
    'opponent_has_played', exists (select 1 from match_moves mv where mv.match_id = m.id
                                 and mv.round_number = m.round_number and mv.user_id = v_opp),
    'tactic_costs',      json_build_object(
                           'high_press', tactic_cost_for(m.rules_version, 'high_press'),
                           'counter_attack', tactic_cost_for(m.rules_version, 'counter_attack'),
                           'defensive_wall', tactic_cost_for(m.rules_version, 'defensive_wall')),
    'early_finish_cards', (select early_finish_cards from game_rule_versions where version = m.rules_version),
    'opponent', (select json_build_object('id', u.id, 'username', u.username,
                                          'avatar_url', u.avatar_url, 'mmr', u.mmr)
                 from users u where u.id = v_opp),
    'winner_id',         m.winner_id,
    'is_draw',           m.is_draw
  );
end;
$$;
