-- =====================================================================
-- 007 - OYUN ICI (GAMEPLAY) FONKSIYONLARI
-- =====================================================================
-- Bu dosya oyunun kalbidir. Backend sadece "su oyuncu su karti oynamak
-- istiyor" der; kartin gercekten elinde olup olmadigi, sirasinin gelip
-- gelmedigi, pozisyonun uygun olup olmadigi ve turu kimin kazandigi
-- BURADA belirlenir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- YARDIMCI: Mactaki rakibin kimligi
-- ---------------------------------------------------------------------
create or replace function _opponent_of(p_match matches, p_user_id uuid)
returns uuid
language sql
immutable
as $$
  select case when p_match.player1_id = p_user_id
              then p_match.player2_id
              else p_match.player1_id end;
$$;

-- =====================================================================
-- MACI BITIR + YUKSEK RISK MODU CEZASINI UYGULA
-- =====================================================================
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
  if not v_draw then
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
        -- KART KORUMA HAKKI HER GALIBIYETTE +1
        protection_slots = least(protection_slots + 1, max_protection_slots())
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

-- =====================================================================
-- TURU SONUCLANDIR
-- =====================================================================
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
begin
  select * into m from matches where id = p_match_id for update;

  select * into v_lead
  from match_moves
  where match_id = p_match_id and round_number = m.round_number and is_lead;

  select * into v_resp
  from match_moves
  where match_id = p_match_id and round_number = m.round_number and not is_lead;

  -- ---- KAZANANI BELIRLE ----
  if v_lead.is_pass and not v_resp.is_pass then
    v_winner := v_resp.user_id;
  elsif v_resp.is_pass and not v_lead.is_pass then
    v_winner := v_lead.user_id;
  elsif v_lead.is_pass and v_resp.is_pass then
    v_is_draw := true;
  else
    -- compare_cards: Legend kurali burada devreye girer
    v_cmp := compare_cards(v_lead.tier, v_lead.power, v_resp.tier, v_resp.power);
    if v_cmp = 1 then
      v_winner := v_lead.user_id;
    elsif v_cmp = -1 then
      v_winner := v_resp.user_id;
    else
      v_is_draw := true;
    end if;
  end if;

  -- ---- MASADAKI KARTLAR ----
  -- Bu turda oynanan kartlar + onceki beraberliklerden kalan pot
  v_cards_won := m.pot_card_ids
                 || array_remove(array[v_lead.user_card_id, v_resp.user_card_id], null);

  if v_is_draw then
    -- BERABERLIK: kartlar masada kalir, sonraki turu alan hepsini toplar.
    -- KURAL: Beraberlikte turu acma hakki KARSI TARAFA gecer.
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
    -- KAZANAN MASADAKI HER SEYI ALIR VE SONRAKI TURU ACAR
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

  -- ---- MAC BITTI MI? ----
  select count(*) into v_remaining
  from match_hands
  where match_id = p_match_id and not is_played;

  if v_remaining = 0 then
    perform _finish_match(p_match_id);
  end if;
end;
$$;

-- =====================================================================
-- ANA FONKSIYON: KART OYNA
-- =====================================================================
-- p_user_card_id NULL gonderilirse: "bu pozisyonda kartim yok" (PAS) demektir.
-- Sunucu bu iddiayi DOGRULAR; kartin varsa pas gecemezsin.
create or replace function play_card(
  p_user_id uuid,
  p_match_id uuid,
  p_user_card_id uuid default null
)
returns json
language plpgsql
as $$
declare
  m         matches%rowtype;
  v_hand    match_hands%rowtype;
  v_is_lead boolean;
begin
  -- Satiri kilitle: ayni anda iki kart oynanmasini engeller
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

  -- SIRA KONTROLU (istemci sirayi atlayamaz)
  if m.current_turn_id <> p_user_id then
    raise exception 'Sira sizde degil.';
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
      (match_id, user_id, round_number, user_card_id, card_id, position, tier, power, is_lead, is_pass)
    values
      (p_match_id, p_user_id, m.round_number, v_hand.user_card_id, v_hand.card_id,
       v_hand.position, v_hand.tier, v_hand.power, true, false);

    -- Sira rakibe gecer, oynamasi gereken pozisyon sabitlenir
    update matches
    set required_position = v_hand.position,
        current_turn_id   = _opponent_of(m, p_user_id),
        turn_deadline     = now() + make_interval(secs => turn_timeout_seconds())
    where id = p_match_id;

    return json_build_object('status', 'ok', 'phase', 'waiting_opponent');
  end if;

  -- ========================== CEVAP VEREN ==========================
  if p_user_card_id is null then
    -- PAS IDDIASI: gercekten o pozisyonda karti yok mu?
    if exists (
      select 1 from match_hands
      where match_id = p_match_id and user_id = p_user_id
        and not is_played and position = m.required_position
    ) then
      raise exception 'Elinizde bu pozisyonda kart var, pas gecemezsiniz.';
    end if;

    insert into match_moves
      (match_id, user_id, round_number, user_card_id, card_id, position, tier, power, is_lead, is_pass)
    values
      (p_match_id, p_user_id, m.round_number, null, null, m.required_position, null, null, false, true);
  else
    select * into v_hand
    from match_hands
    where match_id = p_match_id and user_id = p_user_id
      and user_card_id = p_user_card_id and not is_played;

    if not found then
      raise exception 'Bu kart elinizde yok veya daha once oynandi.';
    end if;

    -- POZISYON ZORUNLULUGU
    if v_hand.position <> m.required_position then
      raise exception 'Bu turda % pozisyonunda kart oynamalisiniz.', m.required_position;
    end if;

    update match_hands
    set is_played = true, played_round = m.round_number
    where match_id = p_match_id and user_card_id = p_user_card_id;

    insert into match_moves
      (match_id, user_id, round_number, user_card_id, card_id, position, tier, power, is_lead, is_pass)
    values
      (p_match_id, p_user_id, m.round_number, v_hand.user_card_id, v_hand.card_id,
       v_hand.position, v_hand.tier, v_hand.power, false, false);
  end if;

  -- Iki hamle de tamam -> turu sonuclandir
  perform _resolve_round(p_match_id);

  return json_build_object('status', 'ok', 'phase', 'round_resolved');
end;
$$;

-- =====================================================================
-- SURE ASIMI (AFK / baglanti kopmasi) => HUKMEN MAGLUBIYET
-- =====================================================================
-- KURAL: Sirasi gelen oyuncu, tur suresi (45 sn) + AFK toleransi (15 sn)
-- icinde hamle yapmazsa maci HUKMEN kaybeder ve 3 kart cezasi uygulanir.
--
-- Iki tetikleyici vardir:
--   1) claim_turn_timeout()      -> bekleyen oyuncunun istegi uzerine
--   2) sweep_timed_out_matches() -> backend'deki zamanlayici her 15 sn'de
--      (iki oyuncunun da baglantisi koptuysa mac askida kalmaz)
-- Her ikisi de SUNUCU saatini kullanir, istemci saatine guvenilmez.
create or replace function claim_turn_timeout(p_user_id uuid, p_match_id uuid)
returns json
language plpgsql
as $$
declare
  m matches%rowtype;
begin
  select * into m from matches where id = p_match_id for update;

  if not found or m.status <> 'active' then
    raise exception 'Aktif mac bulunamadi.';
  end if;

  if p_user_id not in (m.player1_id, m.player2_id) then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  if m.current_turn_id = p_user_id then
    raise exception 'Sira sizde, sure asimi talep edemezsiniz.';
  end if;

  if now() < m.turn_deadline + make_interval(secs => afk_grace_seconds()) then
    raise exception 'Rakibin suresi henuz dolmadi.';
  end if;

  perform _finish_match(p_match_id, p_user_id);

  return json_build_object(
    'status',    'opponent_timeout',
    'winner_id', p_user_id,
    'loser_id',  m.current_turn_id
  );
end;
$$;

-- ---------------------------------------------------------------------
-- OTOMATIK TARAYICI (backend zamanlayicisi cagirir)
-- ---------------------------------------------------------------------
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

-- =====================================================================
-- TESLIM OL
-- =====================================================================
create or replace function surrender_match(p_user_id uuid, p_match_id uuid)
returns json
language plpgsql
as $$
declare
  m matches%rowtype;
begin
  select * into m from matches where id = p_match_id for update;

  if not found or m.status <> 'active' then
    raise exception 'Aktif mac bulunamadi.';
  end if;

  if p_user_id not in (m.player1_id, m.player2_id) then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  -- Teslim olmak da maci kaybetmektir; 3 kart cezasi uygulanir.
  perform _finish_match(p_match_id, _opponent_of(m, p_user_id));

  return json_build_object('status', 'surrendered');
end;
$$;

-- =====================================================================
-- KENDI ELINI GOR
-- =====================================================================
-- Backend bu fonksiyonu SADECE istegi yapan oyuncunun kimligiyle cagirir.
-- Rakibin kartlari hicbir uc noktadan disari cikmaz.
-- DONUS TIPI DEGISTI (016 ile ozellikler eklendi). PostgreSQL bir
-- fonksiyonun donus tipini "create or replace" ile degistirmeye izin
-- vermez; once dusurmek sart.
drop function if exists get_my_hand(uuid, uuid);

create or replace function get_my_hand(p_user_id uuid, p_match_id uuid)
returns table (
  user_card_id uuid,
  card_id      uuid,
  full_name    text,
  -- "position" PostgreSQL'de ayrilmis bir kelimedir (position(x in y)
  -- fonksiyonu icin). Kolon adi olarak kullanmak icin tirnak sart.
  "position"   card_position,
  tier         card_tier,
  power        int,

  -- Kart ozellikleri (sadece gosterim; tur sonucunu etkilemez)
  shooting     int,
  pace         int,
  physical     int,
  defending    int,
  dribbling    int,
  acceleration int,

  image_url    text,
  is_played    boolean,
  is_protected boolean
)
language plpgsql
stable
as $$
#variable_conflict use_column
begin
  if not exists (
    select 1 from matches m
    where m.id = p_match_id
      and (m.player1_id = p_user_id or m.player2_id = p_user_id)
  ) then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  return query
  select mh.user_card_id,
         mh.card_id,
         c.full_name,
         mh.position,
         mh.tier,
         mh.power,
         c.shooting,
         c.pace,
         c.physical,
         c.defending,
         c.dribbling,
         c.acceleration,
         c.image_url,
         mh.is_played,
         (mh.user_card_id = any (mp.protected_card_ids)) as is_protected
  from match_hands mh
  join cards c        on c.id = mh.card_id
  join match_players mp on mp.match_id = mh.match_id and mp.user_id = mh.user_id
  where mh.match_id = p_match_id
    and mh.user_id  = p_user_id
  order by mh.position, mh.power desc;
end;
$$;

-- =====================================================================
-- MACIN GENEL DURUMU (tek cagrida ekrani cizecek her sey)
-- =====================================================================
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
    'opponent', (select json_build_object('id', u.id, 'username', u.username,
                                          'avatar_url', u.avatar_url, 'mmr', u.mmr)
                 from users u where u.id = v_opp),
    'winner_id',         m.winner_id,
    'is_draw',           m.is_draw
  );
end;
$$;
