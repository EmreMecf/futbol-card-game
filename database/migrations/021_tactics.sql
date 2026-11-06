-- =====================================================================
-- 021: TAKTIK VE ENERJI SISTEMI (FAZ 5 prototipinden oyuna alindi)
-- =====================================================================
-- Prototip: packages/tactics_prototype (denge raporu RAPOR.md).
-- Sayilar prototipteki TacticRules.balanced ile BIREBIR aynidir.
--
-- KURALLAR
--   * Her oyuncu maca 2 enerjiyle baslar, her yeni turda +1 kazanir,
--     en fazla 5 enerji biriktirebilir.
--   * Kart oynarken istege bagli bir taktik secilir:
--       high_press      (3 enerji)  +9
--       counter_attack  (2 enerji)  +2, rakip pres yaptiysa +13
--       defensive_wall  (1 enerji)  savunurken +6, turu acarken +2
--   * Tas-kagit-makas: pres duvari, duvar kontrayi, kontra presi kirar.
--     Kirilan taktigin bonusu SIFIRLANIR.
--   * Bonus gucun ustune eklenir. compare_cards() Legend kuralina ONCE
--     baktigi icin hicbir taktik Legend olmayan bir kartin Legend'i
--     yenmesini saglayamaz.
--
-- GIZLILIK
--   * Turu acanin taktigi, tur cozulene kadar rakibe GOSTERILMEZ
--     (bkz. server/lib/routes/match_routes.dart -> /moves).
--   * Enerji kart oynanirken DUSULMEZ, sadece "yeterli mi" diye bakilir.
--     Harcama tur cozulurken yapilir. Boylece cevap veren oyuncu rakibin
--     enerjisinin azaldigini gorup gizli taktigi tahmin edemez.
--
-- Mevcut kurallar (ayni mevki, Legend, beraberlik/pot, mac sonu)
-- DEGISMEDI.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) SABITLER (tek kaynak: bu fonksiyonlar)
-- ---------------------------------------------------------------------
create or replace function tactic_start_energy() returns int
language sql immutable as $$ select 2 $$;

create or replace function tactic_energy_per_round() returns int
language sql immutable as $$ select 1 $$;

create or replace function tactic_max_energy() returns int
language sql immutable as $$ select 5 $$;

-- Gecerli taktik kodlari
create or replace function is_valid_tactic(p_tactic text) returns boolean
language sql immutable as $$
  select p_tactic in ('none', 'high_press', 'counter_attack', 'defensive_wall')
$$;

-- Taktigin enerji maliyeti
create or replace function tactic_cost(p_tactic text) returns int
language sql immutable as $$
  select case p_tactic
    when 'high_press'     then 3
    when 'counter_attack' then 2
    when 'defensive_wall' then 1
    else 0
  end
$$;

-- Bir oyuncunun bu turdaki taktik bonusu.
-- p_mine: benim taktigim, p_theirs: rakibin taktigi,
-- p_i_am_lead: turu ben mi actim?
create or replace function tactic_bonus(
  p_mine text,
  p_theirs text,
  p_i_am_lead boolean
) returns int
language sql immutable as $$
  select case p_mine
    -- Pres: kontraya yakalanirsa bonus sifir
    when 'high_press' then
      case when p_theirs = 'counter_attack' then 0 else 9 end
    -- Kontra: duvara carparsa sifir, pres yakalarsa +13, yoksa +2
    when 'counter_attack' then
      case p_theirs
        when 'defensive_wall' then 0
        when 'high_press'     then 13
        else 2
      end
    -- Duvar: presle kirilirsa sifir; savunurken +6, acarken +2
    when 'defensive_wall' then
      case
        when p_theirs = 'high_press' then 0
        when p_i_am_lead             then 2
        else 6
      end
    else 0
  end
$$;

-- ---------------------------------------------------------------------
-- 2) SEMA
-- ---------------------------------------------------------------------
alter table match_players
  add column if not exists energy int not null default 2;

alter table match_moves
  add column if not exists tactic text not null default 'none';

-- Tur cozulurken hesaplanan bonus (gosterim icin saklanir; istemci
-- kendisi hesaplamaz).
alter table match_moves
  add column if not exists tactic_bonus int not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'match_moves_tactic_check'
  ) then
    alter table match_moves
      add constraint match_moves_tactic_check check (is_valid_tactic(tactic));
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'match_players_energy_check'
  ) then
    alter table match_players
      add constraint match_players_energy_check
      check (energy between 0 and 5);
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- 3) KART OYNAMA: TAKTIK PARAMETRESI
-- ---------------------------------------------------------------------
-- Parametre sayisi degistigi icin eski surumu dusuruyoruz; yoksa iki
-- surum birlikte kalir ve 3 parametreli cagri belirsiz olur.
drop function if exists play_card(uuid, uuid, uuid);

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
-- 4) TUR COZUMU: EFEKTIF GUC = GUC + KIMYA + TAKTIK BONUSU
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
begin
  select * into m from matches where id = p_match_id for update;

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
    -- TAKTIK BONUSU (pas varsa karsilastirma yok, bonus da yok)
    v_lead_bonus := tactic_bonus(v_lead.tactic, v_resp.tactic, true);
    v_resp_bonus := tactic_bonus(v_resp.tactic, v_lead.tactic, false);

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
  set energy = least(
        tactic_max_energy(),
        greatest(0, mp.energy - tactic_cost(mv.tactic)) + tactic_energy_per_round()
      )
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
-- 5) MAC DURUMU: ENERJI BILGISI
-- ---------------------------------------------------------------------
-- Enerji sadece tur cozulurken degistigi icin rakibin enerjisini
-- gostermek gizli taktigi ele VERMEZ.
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
    'opponent', (select json_build_object('id', u.id, 'username', u.username,
                                          'avatar_url', u.avatar_url, 'mmr', u.mmr)
                 from users u where u.id = v_opp),
    'winner_id',         m.winner_id,
    'is_draw',           m.is_draw
  );
end;
$$;
