-- =====================================================================
-- 014 - KIMYA (CHEMISTRY) SISTEMI
-- =====================================================================
-- AMAC: Sadece yuksek guclu kartlari yan yana dizmek yetmemeli.
-- Oyuncu, 11 kartini birbirine BAGLAYARAK ekstra guc kazanabilmeli.
--
-- KURALLAR:
--   Ayni Kulup  VEYA (Ayni Lig + Ayni Uyruk)  -> +2  (Yesil bag)
--   Ayni Uyruk  VEYA  Ayni Lig                -> +1  (Sari bag)
--   Ortak nokta yok                            ->  0  (Kirmizi bag)
--
-- Bir kartin kimyasi = o kartin TUM baglantilarindaki puanlarin toplami.
-- Mac sirasinda kart masaya `guc + kimya` ile cikar.
--
-- LEGEND KURALI BOZULMUYOR: Kimya sadece GUCU artirir. Legend kart hala
-- alttaki 4 seviyeyi gucune bakilmaksizin yener; kimyasi 8 olan bir
-- Diamond bile Legend'i yenemez. Kimya, AYNI sinif icindeki kartlar
-- arasinda fark yaratir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) YENI KART OZELLIGI: LIG
-- ---------------------------------------------------------------------
-- Uyruk (nationality) ve kulup (club) zaten vardi; lig eksikti.
alter table cards add column if not exists league text;

create index if not exists idx_cards_league on cards (league);
create index if not exists idx_cards_nationality on cards (nationality);

comment on column cards.league is
  'Kimya baglantilari icin lig. Uyruktan BAGIMSIZ olmali; aksi halde '
  '"ayni lig" ile "ayni uyruk" ayni sey olur ve +2 kurali anlamsizlasir.';

-- ---------------------------------------------------------------------
-- 2) KADRO DIZILISI: SLOT NUMARASI
-- ---------------------------------------------------------------------
-- Kimya hesabi icin kartlarin sahada NEREDE durdugunu bilmemiz gerek.
-- Artik her deste kartinin bir slot numarasi var (0-10).
--
-- FORMASYON (4-4-2):
--
--            [9]  [10]        <- Forvetler
--       [5] [6] [7] [8]       <- Orta saha
--       [1] [2] [3] [4]       <- Defans
--              [0]            <- Kaleci
--
alter table deck_cards add column if not exists slot_index int;

-- Ayni destede ayni slot iki kez kullanilamaz
create unique index if not exists uq_deck_cards_slot
  on deck_cards (deck_id, slot_index)
  where slot_index is not null;

-- ---------------------------------------------------------------------
-- 3) MACA DONDURULAN KIMYA
-- ---------------------------------------------------------------------
-- Kimya mac BASLARKEN hesaplanip donduruluyor.
--
-- NEDEN DONDURUYORUZ?
--   * Mac sirasinda oyuncu kadrosunu degistirip kimyasini artiramaz,
--   * kart katalogu dengelenirse devam eden macin sonucu degismez,
--   * her turda yeniden hesaplamak gereksiz is olurdu.
alter table match_hands add column if not exists chemistry int not null default 0;
alter table match_moves add column if not exists chemistry int not null default 0;

comment on column match_hands.chemistry is
  'Mac basinda dondurulan kimya bonusu. Efektif guc = power + chemistry.';

-- =====================================================================
-- 4) FORMASYON TANIMI
-- =====================================================================

-- Bir slotta hangi pozisyon olmali?
create or replace function formation_slot_position(p_slot int)
returns card_position
language sql
immutable
as $$
  select case
    when p_slot = 0                then 'GK'::card_position
    when p_slot between 1 and 4    then 'DEF'::card_position
    when p_slot between 5 and 8    then 'MID'::card_position
    when p_slot between 9 and 10   then 'FWD'::card_position
  end;
$$;

-- ---------------------------------------------------------------------
-- BAGLANTI HARITASI
-- ---------------------------------------------------------------------
-- Hangi slotlar birbirine bagli? Toplam 17 bag var.
--
-- Kaleci sadece iki stoperle (2 ve 3) bagli. Kanat oyuncularinin
-- forvetlerle, orta sahalarin kendi aralarinda ve defansla baglantisi var.
-- Bu harita degistirilirse kimya dengesi de degisir; tek yerden yonetiliyor.
create or replace function formation_links()
returns table (slot_a int, slot_b int)
language sql
immutable
as $$
  select * from (values
    -- Kaleci <-> stoperler
    (0, 2), (0, 3),
    -- Defans zinciri
    (1, 2), (2, 3), (3, 4),
    -- Defans <-> orta saha (dikey)
    (1, 5), (2, 6), (3, 7), (4, 8),
    -- Orta saha zinciri
    (5, 6), (6, 7), (7, 8),
    -- Orta saha <-> forvet
    (5, 9), (6, 9), (7, 10), (8, 10),
    -- Forvet ikilisi
    (9, 10)
  ) as t(slot_a, slot_b);
$$;

comment on function formation_links() is
  '4-4-2 formasyonundaki 17 kimya baglantisi. Denge ayari burada yapilir.';

-- =====================================================================
-- 5) BAGLANTI PUANI
-- =====================================================================

-- Iki degerin ikisi de dolu ve esit mi? (NULL = NULL eslesme SAYILMAZ)
create or replace function _ayni_mi(a text, b text)
returns boolean
language sql
immutable
as $$
  select a is not null and b is not null and a = b;
$$;

-- Iki kart arasindaki kimya puani: 0, 1 veya 2
create or replace function chemistry_link_score(
  p_a_nation text, p_a_league text, p_a_club text,
  p_b_nation text, p_b_league text, p_b_club text
)
returns int
language plpgsql
immutable
as $$
declare
  v_ulke  boolean := _ayni_mi(p_a_nation, p_b_nation);
  v_lig   boolean := _ayni_mi(p_a_league, p_b_league);
  v_kulup boolean := _ayni_mi(p_a_club,   p_b_club);
begin
  -- YESIL BAG (+2): ayni kulup, ya da ayni ligde ayni uyruk
  if v_kulup or (v_lig and v_ulke) then
    return 2;
  end if;

  -- SARI BAG (+1): ayni uyruk ya da ayni lig
  if v_ulke or v_lig then
    return 1;
  end if;

  -- KIRMIZI BAG: ortak nokta yok
  return 0;
end;
$$;

-- =====================================================================
-- 6) DESTE KIMYASI HESABI
-- =====================================================================
-- Her kart icin: baglantilarindaki puanlarin toplami.
create or replace function calculate_deck_chemistry(p_deck_id uuid)
returns table (
  slot_index   int,
  user_card_id uuid,
  chemistry    int
)
language sql
stable
as $$
  with kadro as (
    select dc.slot_index, dc.user_card_id,
           c.nationality, c.league, c.club
    from deck_cards dc
    join user_cards uc on uc.id = dc.user_card_id
    join cards c       on c.id  = uc.card_id
    where dc.deck_id = p_deck_id
      and dc.slot_index is not null
  ),
  baglar as (
    select l.slot_a, l.slot_b,
           chemistry_link_score(
             a.nationality, a.league, a.club,
             b.nationality, b.league, b.club
           ) as puan
    from formation_links() l
    join kadro a on a.slot_index = l.slot_a
    join kadro b on b.slot_index = l.slot_b
  )
  select k.slot_index,
         k.user_card_id,
         coalesce((
           select sum(b.puan)::int
           from baglar b
           where b.slot_a = k.slot_index or b.slot_b = k.slot_index
         ), 0)
  from kadro k
  order by k.slot_index;
$$;

-- ---------------------------------------------------------------------
-- KIMYA OZETI (arayuz icin)
-- ---------------------------------------------------------------------
-- Kartlarin kimyasi + baglarin renkleri + takim toplami.
create or replace function deck_chemistry_summary(p_deck_id uuid)
returns json
language sql
stable
as $$
  with kadro as (
    select dc.slot_index, dc.user_card_id,
           c.nationality, c.league, c.club
    from deck_cards dc
    join user_cards uc on uc.id = dc.user_card_id
    join cards c       on c.id  = uc.card_id
    where dc.deck_id = p_deck_id
      and dc.slot_index is not null
  ),
  baglar as (
    select l.slot_a, l.slot_b,
           chemistry_link_score(
             a.nationality, a.league, a.club,
             b.nationality, b.league, b.club
           ) as puan
    from formation_links() l
    join kadro a on a.slot_index = l.slot_a
    join kadro b on b.slot_index = l.slot_b
  )
  select json_build_object(
    'deck_id', p_deck_id,

    -- Takim toplami: tum baglarin puan toplami
    'total', coalesce((select sum(puan) from baglar), 0),

    -- Ulasilabilecek en yuksek puan (17 bag x 2)
    'max_total', (select count(*) * 2 from formation_links()),

    -- Kadro tam mi? (eksik kadroda kimya yanlis gorunur)
    'is_complete', (select count(*) from kadro) = squad_size(),

    'cards', coalesce((
      select json_agg(json_build_object(
        'slot_index',   c.slot_index,
        'user_card_id', c.user_card_id,
        'chemistry',    c.chemistry
      ) order by c.slot_index)
      from calculate_deck_chemistry(p_deck_id) c
    ), '[]'::json),

    'links', coalesce((
      select json_agg(json_build_object(
        'slot_a', slot_a,
        'slot_b', slot_b,
        'score',  puan
      ) order by slot_a, slot_b)
      from baglar
    ), '[]'::json)
  );
$$;

comment on function deck_chemistry_summary(uuid) is
  'Kadro kimyasinin tam dokumu: kart basina puan, bag renkleri ve toplam.';

-- =====================================================================
-- 7) KADRO DOGRULAMASI GUNCELLENDI
-- =====================================================================
-- Artik slot numaralari da kontrol ediliyor: her slot dolu olmali ve
-- slottaki kartin pozisyonu formasyona uymali.
create or replace function validate_deck(p_user_id uuid, p_deck_id uuid)
returns text
language plpgsql
stable
as $$
declare
  v_owner uuid;
  v_total int;
  v_not_owned int;
  v_locked int;
  v_slotsuz int;
  v_yanlis_slot int;
  v_eksik_slot int;
begin
  select owner_id into v_owner from decks where id = p_deck_id;

  if v_owner is null then
    return 'Deste bulunamadi.';
  end if;

  if v_owner <> p_user_id then
    return 'Bu deste size ait degil.';
  end if;

  select
    count(*),
    count(*) filter (where uc.owner_id <> p_user_id),
    count(*) filter (where uc.locked_match_id is not null),
    count(*) filter (where dc.slot_index is null),
    count(*) filter (
      where dc.slot_index is not null
        and c.position <> formation_slot_position(dc.slot_index)
    )
  into v_total, v_not_owned, v_locked, v_slotsuz, v_yanlis_slot
  from deck_cards dc
  join user_cards uc on uc.id = dc.user_card_id
  join cards c       on c.id  = uc.card_id
  where dc.deck_id = p_deck_id;

  if v_total <> squad_size() then
    return format('Kadroda %s kart olmali, su an %s kart var.',
                  squad_size(), v_total);
  end if;

  if v_not_owned > 0 then
    return 'Destedeki bazi kartlar artik size ait degil. Kadronuzu guncelleyin.';
  end if;

  if v_locked > 0 then
    return 'Destedeki bazi kartlar devam eden bir macta kilitli.';
  end if;

  if v_slotsuz > 0 then
    return 'Kadro dizilisi eksik. Kartlari formasyondaki yerlerine yerlestirin.';
  end if;

  if v_yanlis_slot > 0 then
    return 'Bazi kartlar formasyonda yanlis pozisyonda duruyor.';
  end if;

  -- 0'dan 10'a kadar tum slotlar dolu mu?
  select count(*) into v_eksik_slot
  from generate_series(0, squad_size() - 1) s
  where not exists (
    select 1 from deck_cards dc
    where dc.deck_id = p_deck_id and dc.slot_index = s
  );

  if v_eksik_slot > 0 then
    return format('Formasyonda %s bos yer var.', v_eksik_slot);
  end if;

  return null; -- Kadro gecerli
end;
$$;

-- =====================================================================
-- 8) MAC BASLARKEN KIMYAYI DONDUR
-- =====================================================================
create or replace function _create_match(
  p_user_a uuid, p_deck_a uuid, p_prot_a uuid[],
  p_user_b uuid, p_deck_b uuid, p_prot_b uuid[]
)
returns uuid
language plpgsql
as $$
declare
  v_match_id uuid;
  v_starter  uuid;
begin
  v_starter := case when random() < 0.5 then p_user_a else p_user_b end;

  insert into matches (
    player1_id, player2_id, current_turn_id, lead_player_id, turn_deadline
  )
  values (
    p_user_a, p_user_b, v_starter, v_starter,
    now() + make_interval(secs => turn_timeout_seconds())
  )
  returning id into v_match_id;

  insert into match_players (match_id, user_id, deck_id, protected_card_ids)
  values (v_match_id, p_user_a, p_deck_a, p_prot_a),
         (v_match_id, p_user_b, p_deck_b, p_prot_b);

  -- ELLERI DAGIT + KIMYAYI DONDUR
  --
  -- Kart degerleri (guc, seviye) ve kimya bonusu bu anda dondurulur.
  -- Mac boyunca degismezler; oyuncu kadrosunu degistirip kimyasini
  -- artiramaz.
  insert into match_hands (
    match_id, user_id, user_card_id, card_id, position, tier, power, chemistry
  )
  select v_match_id, uc.owner_id, uc.id, c.id, c.position, c.tier, c.power,
         coalesce(kim.chemistry, 0)
  from deck_cards dc
  join user_cards uc on uc.id = dc.user_card_id
  join cards c       on c.id  = uc.card_id
  left join lateral (
    select k.chemistry
    from calculate_deck_chemistry(dc.deck_id) k
    where k.user_card_id = dc.user_card_id
  ) kim on true
  where dc.deck_id in (p_deck_a, p_deck_b);

  -- Kartlari kilitle
  update user_cards uc
  set locked_match_id = v_match_id
  where uc.id in (
    select dc.user_card_id from deck_cards dc
    where dc.deck_id in (p_deck_a, p_deck_b)
  );

  return v_match_id;
end;
$$;

-- =====================================================================
-- 9) KART OYNAMA: KIMYAYI HAMLEYE YAZ
-- =====================================================================
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
       tier, power, chemistry, is_lead, is_pass)
    values
      (p_match_id, p_user_id, m.round_number, v_hand.user_card_id, v_hand.card_id,
       v_hand.position, v_hand.tier, v_hand.power, v_hand.chemistry, true, false);

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
       tier, power, chemistry, is_lead, is_pass)
    values
      (p_match_id, p_user_id, m.round_number, null, null,
       m.required_position, null, null, 0, false, true);
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
       tier, power, chemistry, is_lead, is_pass)
    values
      (p_match_id, p_user_id, m.round_number, v_hand.user_card_id, v_hand.card_id,
       v_hand.position, v_hand.tier, v_hand.power, v_hand.chemistry, false, false);
  end if;

  perform _resolve_round(p_match_id);

  return json_build_object('status', 'ok', 'phase', 'round_resolved');
end;
$$;

-- =====================================================================
-- 10) TUR COZUMU: EFEKTIF GUC = GUC + KIMYA
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
    -- KIMYA BURADA DEVREYE GIRIYOR.
    --
    -- Efektif guc = kartin gucu + kimya bonusu.
    -- compare_cards once seviyeye bakar (Legend kurali), sonra guce.
    -- Yani kimya bir Diamond'i Legend'e ustun kilamaz; sadece AYNI
    -- sinif icindeki karsilasmalarda fark yaratir.
    v_cmp := compare_cards(
      v_lead.tier, v_lead.power + coalesce(v_lead.chemistry, 0),
      v_resp.tier, v_resp.power + coalesce(v_resp.chemistry, 0)
    );

    if v_cmp = 1 then
      v_winner := v_lead.user_id;
    elsif v_cmp = -1 then
      v_winner := v_resp.user_id;
    else
      v_is_draw := true;
    end if;
  end if;

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

-- =====================================================================
-- 11) ELIMDEKI KARTLAR: KIMYA BILGISI EKLENDI
-- =====================================================================
-- Donus tipi degisti (chemistry + uyruk/lig/kulup eklendi), bu yuzden
-- once dusurmemiz gerekiyor: PostgreSQL "create or replace" ile bir
-- fonksiyonun donus tipini degistirmeye izin vermiyor.
drop function if exists get_my_hand(uuid, uuid);

create or replace function get_my_hand(p_user_id uuid, p_match_id uuid)
returns table (
  user_card_id uuid,
  card_id      uuid,
  full_name    text,
  "position"   card_position,
  tier         card_tier,
  power        int,
  chemistry    int,
  nationality  text,
  league       text,
  club         text,
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
         mh.chemistry,
         c.nationality,
         c.league,
         c.club,
         c.image_url,
         mh.is_played,
         (mh.user_card_id = any (mp.protected_card_ids)) as is_protected
  from match_hands mh
  join cards c          on c.id = mh.card_id
  join match_players mp on mp.match_id = mh.match_id and mp.user_id = mh.user_id
  where mh.match_id = p_match_id
    and mh.user_id  = p_user_id
  order by mh.position, (mh.power + mh.chemistry) desc;
end;
$$;

-- =====================================================================
-- 12) BASLANGIC PAKETI: SLOT ATAMASI EKLENDI
-- =====================================================================
create or replace function grant_starter_pack(p_user_id uuid)
returns json
language plpgsql
as $$
declare
  v_deck_id uuid;
  v_sonuc   json;
  v_toplam  int;
begin
  if not exists (select 1 from users where id = p_user_id) then
    raise exception 'Kullanici bulunamadi.';
  end if;

  if exists (select 1 from user_cards where owner_id = p_user_id) then
    raise exception 'Baslangic paketi zaten alinmis.';
  end if;

  v_sonuc := open_pack(p_user_id, 'starter', true);

  select count(*) into v_toplam from user_cards where owner_id = p_user_id;

  if v_toplam < squad_size() then
    raise exception 'Katalogda yeterli kart yok. Once seed verisini yukleyin.';
  end if;

  insert into decks (owner_id, name, is_active)
  values (p_user_id, 'Ilk Kadrom', true)
  returning id into v_deck_id;

  -- Formasyona yerlestir: her pozisyonun en guclu kartlari sirayla
  -- 0=GK, 1-4=DEF, 5-8=MID, 9-10=FWD slotlarina.
  insert into deck_cards (deck_id, user_card_id, slot_index)
  select v_deck_id, y.id, y.slot
  from (
    select uc.id,
           case c.position
             when 'GK'  then 0
             when 'DEF' then 0 + row_number() over (partition by c.position order by c.power desc)
             when 'MID' then 4 + row_number() over (partition by c.position order by c.power desc)
             when 'FWD' then 8 + row_number() over (partition by c.position order by c.power desc)
           end::int as slot,
           row_number() over (partition by c.position order by c.power desc) as sira,
           c.position
    from user_cards uc
    join cards c on c.id = uc.card_id
    where uc.owner_id = p_user_id
  ) y
  where (y.position = 'GK'  and y.sira <= 1)
     or (y.position = 'DEF' and y.sira <= 4)
     or (y.position = 'MID' and y.sira <= 4)
     or (y.position = 'FWD' and y.sira <= 2);

  return json_build_object(
    'status', 'ok',
    'card_count', v_toplam,
    'deck_id', v_deck_id,
    'cards', v_sonuc -> 'cards'
  );
end;
$$;

-- =====================================================================
-- 13) MEVCUT DESTELERE SLOT ATA (gecis)
-- =====================================================================
-- Kimya sisteminden onceki desteler slotsuz. Onlari formasyona
-- yerlestiriyoruz ki oyuncular kadrolarini kaybetmesin.
do $$
declare
  d record;
begin
  for d in select distinct deck_id from deck_cards where slot_index is null loop
    with siralama as (
      select dc.user_card_id,
             c.position,
             row_number() over (partition by c.position order by c.power desc) as sira
      from deck_cards dc
      join user_cards uc on uc.id = dc.user_card_id
      join cards c       on c.id  = uc.card_id
      where dc.deck_id = d.deck_id
    )
    update deck_cards dc
    set slot_index = case s.position
          when 'GK'  then 0
          when 'DEF' then 0 + s.sira
          when 'MID' then 4 + s.sira
          when 'FWD' then 8 + s.sira
        end::int
    from siralama s
    where dc.deck_id = d.deck_id
      and dc.user_card_id = s.user_card_id
      and (
        (s.position = 'GK'  and s.sira <= 1) or
        (s.position = 'DEF' and s.sira <= 4) or
        (s.position = 'MID' and s.sira <= 4) or
        (s.position = 'FWD' and s.sira <= 2)
      );
  end loop;
end $$;
