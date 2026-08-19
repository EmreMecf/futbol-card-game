-- =====================================================================
-- 0008 — OYUN İÇİ (GAMEPLAY) FONKSİYONLARI
-- =====================================================================
-- Bu dosya oyunun kalbidir. İstemci sadece "şu kartı oynamak istiyorum"
-- der; kartın gerçekten elinde olup olmadığı, sırasının gelip gelmediği,
-- pozisyonun uygun olup olmadığı ve turun kimin kazandığı BURADA belirlenir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- YARDIMCI: Maçtaki rakibin ID'si
-- ---------------------------------------------------------------------
create or replace function public._opponent_of(p_match public.matches, p_user_id uuid)
returns uuid
language sql
immutable
as $$
  select case when p_match.player1_id = p_user_id
              then p_match.player2_id
              else p_match.player1_id end;
$$;

-- =====================================================================
-- MAÇI BİTİR + YÜKSEK RİSK MODU CEZASINI UYGULA
-- =====================================================================
create or replace function public._finish_match(
  p_match_id uuid,
  p_forced_winner uuid default null   -- teslim / AFK durumunda hükmen galip
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m           public.matches%rowtype;
  v_winner    uuid;
  v_loser     uuid;
  v_draw      boolean := false;
  v_protected uuid[];
  v_penalty   uuid[];
begin
  select * into m from public.matches where id = p_match_id for update;

  if m.status <> 'active' then
    return;  -- zaten bitmiş, iki kez ceza uygulanmasın
  end if;

  -- ---- KAZANANI BELİRLE ----
  if p_forced_winner is not null then
    v_winner := p_forced_winner;
    v_loser  := public._opponent_of(m, p_forced_winner);
  elsif m.p1_captured_count > m.p2_captured_count then
    v_winner := m.player1_id; v_loser := m.player2_id;
  elsif m.p2_captured_count > m.p1_captured_count then
    v_winner := m.player2_id; v_loser := m.player1_id;
  else
    v_draw := true;
  end if;

  -- ---- CEZA: Korumasız 3 rastgele kartı kazanana devret ----
  if not v_draw then
    select mp.protected_card_ids into v_protected
    from public.match_players mp
    where mp.match_id = p_match_id and mp.user_id = v_loser;

    select coalesce(array_agg(t.user_card_id), '{}')
    into v_penalty
    from (
      select mh.user_card_id
      from public.match_hands mh
      join public.user_cards uc on uc.id = mh.user_card_id
      where mh.match_id = p_match_id
        and mh.user_id  = v_loser
        and uc.owner_id = v_loser                       -- hâlâ onun mu?
        and not (mh.user_card_id = any (coalesce(v_protected, '{}'::uuid[])))
      order by random()
      limit public.penalty_card_count()
    ) t;

    if array_length(v_penalty, 1) > 0 then
      -- Denetim kaydı
      insert into public.card_transfers
        (match_id, user_card_id, card_id, from_user_id, to_user_id, reason)
      select p_match_id, uc.id, uc.card_id, v_loser, v_winner, 'match_penalty'
      from public.user_cards uc
      where uc.id = any (v_penalty);

      -- Kaybedenin destesinden çıkar (kadro artık geçersiz olacak,
      -- oyuncu yeni maça girmeden önce kadrosunu tamamlamak zorunda)
      delete from public.deck_cards where user_card_id = any (v_penalty);

      -- SAHİPLİK DEVRİ
      update public.user_cards
      set owner_id      = v_winner,
          acquired_from = v_loser,
          acquired_at   = now()
      where id = any (v_penalty);
    end if;
  end if;

  -- ---- İSTATİSTİK VE ÖDÜLLER ----
  if v_draw then
    update public.profiles
    set draws = draws + 1
    where id in (m.player1_id, m.player2_id);
  else
    update public.profiles
    set wins             = wins + 1,
        coins            = coins + 100,
        mmr              = mmr + 25,
        -- KART KORUMA HAKKI HER GALİBİYETTE +1
        protection_slots = least(protection_slots + 1, public.max_protection_slots())
    where id = v_winner;

    update public.profiles
    set losses = losses + 1,
        mmr    = greatest(mmr - 25, 0)
    where id = v_loser;
  end if;

  -- ---- KİLİTLERİ AÇ ----
  update public.user_cards
  set locked_match_id = null
  where locked_match_id = p_match_id;

  -- ---- MAÇI KAPAT ----
  update public.matches
  set status      = 'finished',
      winner_id   = v_winner,
      loser_id    = v_loser,
      is_draw     = v_draw,
      finished_at = now()
  where id = p_match_id;

  -- Kuyruk kayıtlarını temizle
  delete from public.matchmaking_queue
  where user_id in (m.player1_id, m.player2_id);
end;
$$;

-- =====================================================================
-- TURU SONUÇLANDIR
-- =====================================================================
-- İki oyuncu da hamlesini yaptıktan sonra çağrılır.
create or replace function public._resolve_round(p_match_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m            public.matches%rowtype;
  v_lead       public.match_moves%rowtype;
  v_resp       public.match_moves%rowtype;
  v_cmp        int;
  v_winner     uuid;
  v_is_draw    boolean := false;
  v_cards_won  uuid[];
  v_remaining  int;
begin
  select * into m from public.matches where id = p_match_id for update;

  select * into v_lead
  from public.match_moves
  where match_id = p_match_id and round_number = m.round_number and is_lead;

  select * into v_resp
  from public.match_moves
  where match_id = p_match_id and round_number = m.round_number and not is_lead;

  -- ---- KAZANANI BELİRLE ----
  if v_lead.is_pass and not v_resp.is_pass then
    v_winner := v_resp.user_id;
  elsif v_resp.is_pass and not v_lead.is_pass then
    v_winner := v_lead.user_id;
  elsif v_lead.is_pass and v_resp.is_pass then
    v_is_draw := true;
  else
    -- compare_cards: Legend kuralı burada devreye girer
    v_cmp := public.compare_cards(v_lead.tier, v_lead.power, v_resp.tier, v_resp.power);
    if v_cmp = 1 then
      v_winner := v_lead.user_id;
    elsif v_cmp = -1 then
      v_winner := v_resp.user_id;
    else
      v_is_draw := true;
    end if;
  end if;

  -- ---- MASADAKİ KARTLAR ----
  -- Bu turda oynanan kartlar + önceki beraberliklerden kalan pot
  v_cards_won := m.pot_card_ids
                 || array_remove(array[v_lead.user_card_id, v_resp.user_card_id], null);

  if v_is_draw then
    -- BERABERLİK: kartlar masada kalır, sonraki turu alan hepsini toplar.
    -- KURAL: Beraberlikte turu açma hakkı KARŞI TARAFA geçer.
    update public.matches
    set pot_card_ids      = v_cards_won,
        round_number      = round_number + 1,
        required_position = null,
        lead_player_id    = public._opponent_of(m, m.lead_player_id),
        current_turn_id   = public._opponent_of(m, m.lead_player_id),
        turn_deadline     = now() + make_interval(secs => public.turn_timeout_seconds())
    where id = p_match_id;

    insert into public.match_rounds (match_id, round_number, winner_id, is_draw, cards_won)
    values (p_match_id, m.round_number, null, true, '{}');
  else
    -- KAZANAN MASADAKİ HER ŞEYİ ALIR VE SONRAKİ TURU AÇAR
    update public.match_players
    set captured_card_ids = captured_card_ids || v_cards_won
    where match_id = p_match_id and user_id = v_winner;

    update public.matches
    set pot_card_ids      = '{}',
        round_number      = round_number + 1,
        required_position = null,
        lead_player_id    = v_winner,
        current_turn_id   = v_winner,
        turn_deadline     = now() + make_interval(secs => public.turn_timeout_seconds()),
        p1_captured_count = p1_captured_count +
                            case when v_winner = m.player1_id
                                 then coalesce(array_length(v_cards_won, 1), 0) else 0 end,
        p2_captured_count = p2_captured_count +
                            case when v_winner = m.player2_id
                                 then coalesce(array_length(v_cards_won, 1), 0) else 0 end
    where id = p_match_id;

    insert into public.match_rounds (match_id, round_number, winner_id, is_draw, cards_won)
    values (p_match_id, m.round_number, v_winner, false, v_cards_won);
  end if;

  -- ---- MAÇ BİTTİ Mİ? ----
  select count(*) into v_remaining
  from public.match_hands
  where match_id = p_match_id and not is_played;

  if v_remaining = 0 then
    perform public._finish_match(p_match_id);
  end if;
end;
$$;

-- =====================================================================
-- ANA RPC: KART OYNA
-- =====================================================================
-- p_user_card_id NULL gönderilirse: "bu pozisyonda kartım yok" (PAS) demektir.
-- Sunucu bu iddiayı DOĞRULAR; kartın varsa pas geçemezsin.
create or replace function public.play_card(
  p_match_id uuid,
  p_user_card_id uuid default null
)
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  m         public.matches%rowtype;
  v_hand    public.match_hands%rowtype;
  v_is_lead boolean;
begin
  if v_uid is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  -- Satırı kilitle: aynı anda iki kart oynanmasını engeller
  select * into m from public.matches where id = p_match_id for update;

  if not found then
    raise exception 'Mac bulunamadi.';
  end if;

  if m.status <> 'active' then
    raise exception 'Bu mac sona ermis.';
  end if;

  if v_uid not in (m.player1_id, m.player2_id) then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  -- SIRA KONTROLÜ (istemci sırayı atlayamaz)
  if m.current_turn_id <> v_uid then
    raise exception 'Sira sizde degil.';
  end if;

  v_is_lead := (m.required_position is null);

  -- =========================== TURU AÇAN ===========================
  if v_is_lead then
    if p_user_card_id is null then
      raise exception 'Turu acan oyuncu pas gecemez, bir kart secmelisiniz.';
    end if;

    select * into v_hand
    from public.match_hands
    where match_id = p_match_id and user_id = v_uid
      and user_card_id = p_user_card_id and not is_played;

    if not found then
      raise exception 'Bu kart elinizde yok veya daha once oynandi.';
    end if;

    update public.match_hands
    set is_played = true, played_round = m.round_number
    where match_id = p_match_id and user_card_id = p_user_card_id;

    insert into public.match_moves
      (match_id, user_id, round_number, user_card_id, card_id, position, tier, power, is_lead, is_pass)
    values
      (p_match_id, v_uid, m.round_number, v_hand.user_card_id, v_hand.card_id,
       v_hand.position, v_hand.tier, v_hand.power, true, false);

    -- Sıra rakibe geçer, oynaması gereken pozisyon sabitlenir
    update public.matches
    set required_position = v_hand.position,
        current_turn_id   = public._opponent_of(m, v_uid),
        turn_deadline     = now() + make_interval(secs => public.turn_timeout_seconds())
    where id = p_match_id;

    return json_build_object('status', 'ok', 'phase', 'waiting_opponent');
  end if;

  -- ========================== CEVAP VEREN ==========================
  if p_user_card_id is null then
    -- PAS İDDİASI: gerçekten o pozisyonda kartı yok mu?
    if exists (
      select 1 from public.match_hands
      where match_id = p_match_id and user_id = v_uid
        and not is_played and position = m.required_position
    ) then
      raise exception 'Elinizde bu pozisyonda kart var, pas gecemezsiniz.';
    end if;

    insert into public.match_moves
      (match_id, user_id, round_number, user_card_id, card_id, position, tier, power, is_lead, is_pass)
    values
      (p_match_id, v_uid, m.round_number, null, null, m.required_position, null, null, false, true);
  else
    select * into v_hand
    from public.match_hands
    where match_id = p_match_id and user_id = v_uid
      and user_card_id = p_user_card_id and not is_played;

    if not found then
      raise exception 'Bu kart elinizde yok veya daha once oynandi.';
    end if;

    -- POZİSYON ZORUNLULUĞU
    if v_hand.position <> m.required_position then
      raise exception 'Bu turda % pozisyonunda kart oynamalisiniz.', m.required_position;
    end if;

    update public.match_hands
    set is_played = true, played_round = m.round_number
    where match_id = p_match_id and user_card_id = p_user_card_id;

    insert into public.match_moves
      (match_id, user_id, round_number, user_card_id, card_id, position, tier, power, is_lead, is_pass)
    values
      (p_match_id, v_uid, m.round_number, v_hand.user_card_id, v_hand.card_id,
       v_hand.position, v_hand.tier, v_hand.power, false, false);
  end if;

  -- İki hamle de tamam -> turu sonuçlandır
  perform public._resolve_round(p_match_id);

  return json_build_object('status', 'ok', 'phase', 'round_resolved');
end;
$$;

-- =====================================================================
-- SÜRE AŞIMI (AFK / bağlantı kopması) => HÜKMEN MAĞLUBİYET
-- =====================================================================
-- KURAL: Sırası gelen oyuncu, tur süresi (45 sn) + AFK toleransı (15 sn)
-- içinde hamle yapmazsa maçı HÜKMEN kaybeder ve 3 kart cezası uygulanır.
--
-- İki tetikleyici vardır:
--   1) claim_turn_timeout()      -> bekleyen oyuncunun uygulaması çağırır
--   2) sweep_timed_out_matches() -> pg_cron her 15 sn'de tarar
--      (iki oyuncunun da bağlantısı koptuysa maç asla askıda kalmaz)
-- Her ikisi de aynı sunucu saatini kullanır, istemci saatine güvenilmez.
-- =====================================================================
create or replace function public.claim_turn_timeout(p_match_id uuid)
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  m     public.matches%rowtype;
begin
  select * into m from public.matches where id = p_match_id for update;

  if not found or m.status <> 'active' then
    raise exception 'Aktif mac bulunamadi.';
  end if;

  if v_uid not in (m.player1_id, m.player2_id) then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  if m.current_turn_id = v_uid then
    raise exception 'Sira sizde, sure asimi talep edemezsiniz.';
  end if;

  -- Tur süresi + AFK toleransı dolmuş olmalı
  if now() < m.turn_deadline + make_interval(secs => public.afk_grace_seconds()) then
    raise exception 'Rakibin suresi henuz dolmadi.';
  end if;

  -- Süresini kullanmayan oyuncu maçı hükmen kaybeder (ceza dahil)
  perform public._finish_match(p_match_id, v_uid);

  return json_build_object(
    'status',    'opponent_timeout',
    'winner_id', v_uid,
    'loser_id',  m.current_turn_id
  );
end;
$$;

-- ---------------------------------------------------------------------
-- OTOMATİK TARAYICI (pg_cron tarafından çağrılır)
-- ---------------------------------------------------------------------
-- Bekleyen oyuncunun uygulaması da kapanmış olabilir. Bu fonksiyon
-- süresi dolmuş tüm maçları sunucu tarafında kendiliğinden kapatır.
create or replace function public.sweep_timed_out_matches()
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  m       public.matches%rowtype;
  v_count int := 0;
begin
  for m in
    select * from public.matches
    where status = 'active'
      and turn_deadline + make_interval(secs => public.afk_grace_seconds()) < now()
    order by turn_deadline
    limit 200
  loop
    perform public._finish_match(m.id, public._opponent_of(m, m.current_turn_id));
    v_count := v_count + 1;
  end loop;

  -- Bayat eşleştirme kuyruğu kayıtlarını da temizle
  delete from public.matchmaking_queue
  where status = 'searching' and updated_at < now() - interval '2 minutes';

  return v_count;
end;
$$;

-- =====================================================================
-- TESLİM OL
-- =====================================================================
create or replace function public.surrender_match(p_match_id uuid)
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  m     public.matches%rowtype;
begin
  select * into m from public.matches where id = p_match_id for update;

  if not found or m.status <> 'active' then
    raise exception 'Aktif mac bulunamadi.';
  end if;

  if v_uid not in (m.player1_id, m.player2_id) then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  -- Teslim olmak da maçı kaybetmektir; 3 kart cezası uygulanır.
  perform public._finish_match(p_match_id, public._opponent_of(m, v_uid));

  return json_build_object('status', 'surrendered');
end;
$$;

-- =====================================================================
-- KENDİ ELİNİ GÖR (rakip asla göremez)
-- =====================================================================
create or replace function public.get_my_hand(p_match_id uuid)
returns table (
  user_card_id uuid,
  card_id      uuid,
  full_name    text,
  position     public.card_position,
  tier         public.card_tier,
  power        int,
  image_url    text,
  is_played    boolean,
  is_protected boolean
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_uid uuid := auth.uid();
begin
  if not exists (
    select 1 from public.matches m
    where m.id = p_match_id and (m.player1_id = v_uid or m.player2_id = v_uid)
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
         c.image_url,
         mh.is_played,
         (mh.user_card_id = any (mp.protected_card_ids)) as is_protected
  from public.match_hands mh
  join public.cards c          on c.id = mh.card_id
  join public.match_players mp on mp.match_id = mh.match_id and mp.user_id = mh.user_id
  where mh.match_id = p_match_id
    and mh.user_id  = v_uid
  order by mh.position, mh.power desc;
end;
$$;

-- =====================================================================
-- MAÇIN GENEL DURUMU (tek çağrıda ekranı çizecek her şey)
-- =====================================================================
create or replace function public.get_match_state(p_match_id uuid)
returns json
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  m     public.matches%rowtype;
  v_opp uuid;
begin
  select * into m from public.matches where id = p_match_id;

  if not found or v_uid not in (m.player1_id, m.player2_id) then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  v_opp := public._opponent_of(m, v_uid);

  return json_build_object(
    'match_id',          m.id,
    'status',            m.status,
    'round_number',      m.round_number,
    'is_my_turn',        (m.current_turn_id = v_uid),
    'am_i_lead',         (m.lead_player_id = v_uid),
    'required_position', m.required_position,
    'turn_deadline',     m.turn_deadline,
    'pot_count',         coalesce(array_length(m.pot_card_ids, 1), 0),
    'my_score',          case when m.player1_id = v_uid
                              then m.p1_captured_count else m.p2_captured_count end,
    'opponent_score',    case when m.player1_id = v_uid
                              then m.p2_captured_count else m.p1_captured_count end,
    'my_cards_left',     (select count(*) from public.match_hands
                          where match_id = m.id and user_id = v_uid and not is_played),
    'opponent_cards_left', (select count(*) from public.match_hands
                          where match_id = m.id and user_id = v_opp and not is_played),
    'opponent', (select json_build_object('id', p.id, 'username', p.username,
                                          'avatar_url', p.avatar_url, 'mmr', p.mmr)
                 from public.profiles p where p.id = v_opp),
    'winner_id',         m.winner_id,
    'is_draw',           m.is_draw
  );
end;
$$;

-- ---------------------------------------------------------------------
-- YETKİLENDİRME
-- ---------------------------------------------------------------------
revoke all on function public._finish_match(uuid, uuid)        from public, anon, authenticated;
revoke all on function public._resolve_round(uuid)             from public, anon, authenticated;
-- Otomatik tarayıcıyı sadece cron/service_role çalıştırabilir
revoke all on function public.sweep_timed_out_matches()        from public, anon, authenticated;

grant execute on function public.play_card(uuid, uuid)      to authenticated;
grant execute on function public.claim_turn_timeout(uuid)   to authenticated;
grant execute on function public.surrender_match(uuid)      to authenticated;
grant execute on function public.get_my_hand(uuid)          to authenticated;
grant execute on function public.get_match_state(uuid)      to authenticated;
