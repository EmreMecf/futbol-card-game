-- =====================================================================
-- 023: OYUN KURALLARININ SURUMLENMESI (bagimsiz inceleme, madde 4)
-- =====================================================================
-- SORUN (deneyle gosterildi): 021 uygulandiginda SUREN maclar yarisinda
-- taktikli kurallara gecti. Macin hangi kurallarla basladigi hicbir
-- yerde kayitli degildi; bir sonraki mekanik degisikligi aktif maclari
-- yine ortasinda degistirecekti.
--
-- COZUM:
--   * game_rule_versions: her kural surumu bir satir (ozellik bayraklari).
--   * matches.rules_version: mac KURULURKEN guncel surum yazilir.
--   * _resolve_round ve play_card macin KENDI surumune bakar.
--
-- YENI BIR MEKANIK EKLERKEN:
--   1. game_rule_versions'a yeni satir (ve gerekiyorsa yeni bayrak sutunu)
--   2. current_rules_version() yeni numarayi donsun
--   3. _resolve_round'da yeni davranisi bayraga bagla
--   Suren maclar eski surumle biter; sadece yeni maclar yeni kurallarla.
--
-- MEVCUT MACLAR = SURUM 2: 021'den beri fiilen taktikli kurallarla
-- oynaniyorlar. Onlari simdi surum 1 yapmak, duzeltmeye calistigimiz
-- "mac ortasinda kural degisimi"ni bir kez daha yaratirdi.
--
-- Yeni maclar icin oyun davranisi DEGISMEDI (surum 2 = 021 kurallari).
-- Fonksiyon govdeleri 021'den programla turetildi; farklar sadece
-- "KURAL SURUMU (023)" yorumlu satirlar.
-- =====================================================================

create table if not exists game_rule_versions (
  version          int primary key,
  name             text not null,
  description      text not null,
  -- Ozellik bayraklari: yeni mekanik = yeni sutun
  tactics_enabled  boolean not null,
  created_at       timestamptz not null default now()
);

insert into game_rule_versions (version, name, description, tactics_enabled)
values
  (1, 'Klasik', 'Ayni mevki, Legend kurali, guc + kimya (001-020)', false),
  (2, 'Taktik', '021: Pres / Kontra / Duvar ve enerji', true)
on conflict (version) do nothing;

-- Yeni maclarin kullanacagi surum. TEK KAYNAK.
create or replace function current_rules_version() returns int
language sql immutable as $$ select 2 $$;

create or replace function rules_tactics_enabled(p_version int) returns boolean
language sql stable as $$
  select coalesce(
    (select tactics_enabled from game_rule_versions where version = p_version),
    false)
$$;

alter table matches add column if not exists rules_version int;
-- Mevcut maclar surum 2 (yukaridaki aciklama)
update matches set rules_version = 2 where rules_version is null;
alter table matches alter column rules_version set default current_rules_version();
alter table matches alter column rules_version set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'matches_rules_version_fkey') then
    alter table matches add constraint matches_rules_version_fkey
      foreign key (rules_version) references game_rule_versions(version);
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- KART OYNAMA (021 + surum kontrolu)
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

-- ---------------------------------------------------------------------
-- TUR COZUMU (021 + surum kontrolu)
-- ---------------------------------------------------------------------
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
        greatest(0, mp.energy - tactic_cost(mv.tactic)) + tactic_energy_per_round()
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

-- ---------------------------------------------------------------------
-- MAC DURUMU (021 + surum bilgisi)
-- ---------------------------------------------------------------------
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
    'opponent', (select json_build_object('id', u.id, 'username', u.username,
                                          'avatar_url', u.avatar_url, 'mmr', u.mmr)
                 from users u where u.id = v_opp),
    'winner_id',         m.winner_id,
    'is_draw',           m.is_draw
  );
end;
$$;
