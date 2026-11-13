-- =====================================================================
-- 041 BOT RAKIP + ANTRENMAN MODU (FAZ 3a, KAPALI GELIR)
-- =====================================================================
-- Onay: kullanici (13 Kasim 2026, "faz 3 gec"). Kullanici karari:
--   * IKI TUR BOT:
--     1. ANTRENMAN botu: oyuncu kendisi baslatir; ODULSUZ ve PUANSIZ;
--        rakip adi "Bot" olarak gorunur (sunucu gosterir).
--     2. ESLESTIRME botu: derecelide 20 sn rakip bulunamazsa gelir;
--        rastgele kullanici adi; PUAN VE ODUL NORMAL (gercek mac gibi).
--   * Tasarimdaki "ilk 5 mac bot" kurali UYGULANMADI (kullanici yalniz
--     "rakip bulunamazsa" dedi).
--
-- ANAHTARLAR (ikisi de KAPALI):
--   'training_mode' : start_training_match() calisir
--   'bots_v1'       : find_match_or_bot() 20 sn sonra bot verir
-- Eslestirme botu yalniz kart TRANSFERI OLMAYAN kural surumunde (3+)
-- devreye girer: bota kart kaybetmek / bottan uretilmis kart kazanmak
-- ekonomiyi bozardi.
--
-- BOT NASIL OYNAR: sunucu zamanlayicisi saniyede bir bot_tick() cagirir.
-- Bot yalniz KENDI elini gorur (rakibin elini okumaz); insan gibi 2-5 sn
-- dusunur. Kadrosu her macta rakibin kadrosuna gore kurulur: ayni mevki
-- ve sinifta, etkin gucu (guc + seviye bonusu) +-3 icinde kartlar.
--
-- DEGISMEYENLER: find_match, _create_match, play_card, _resolve_round,
-- choose_position, taktikler, kimya, MMR (+-25), oduller. _finish_match
-- 037 govdesinden AYNEN alindi; tek fark "041" yorumlu antrenman blogu.
-- Gecmis maclar mode='ranked' (varsayilan) kalir; hicbir satir silinmez.
-- =====================================================================

insert into economy_config_versions (kind, version, payload, note)
select 'feature_flags', max(version) + 1,
       (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1)
         || '{"bots_v1": false, "training_mode": false}'::jsonb,
       '041: bot rakip + antrenman (kapali)'
from economy_config_versions
where kind = 'feature_flags'
  and not ((select payload from economy_config_versions where kind = 'feature_flags'
            order by version desc limit 1) ? 'bots_v1')
having count(*) > 0;

alter table users   add column if not exists is_bot boolean not null default false;
alter table matches add column if not exists mode text not null default 'ranked'
  check (mode in ('ranked', 'training'));

create index if not exists idx_users_bots on users (id) where is_bot;

create or replace function bot_wait_seconds() returns int
language sql immutable as $$ select 20 $$;

-- ---------------------------------------------------------------------
-- 1) BOT HESABI (havuzdan; bos bot yoksa yeni)
-- ---------------------------------------------------------------------
create or replace function _bot_random_username() returns text
language plpgsql volatile as $$
declare
  v_adlar text[] := array['Emir','Yusuf','Kerem','Arda','Mert','Efe','Burak','Deniz','Baris','Onur',
                          'Kaan','Ozan','Tolga','Selin','Ece','Zeynep','Elif','Ada','Eren','Umut',
                          'Cem','Hakan','Serkan','Volkan','Ayse','Defne','Ilker','Sinan','Tuna','Alp'];
  v_ekler text[] := array['', '_fc', 'gol', '_10', '07', '_34', 'tr', '_kral', '1905', '_09', 'x', '_ist'];
  v_ad text;
  i int;
begin
  for i in 1..50 loop
    v_ad := v_adlar[1 + floor(random() * array_length(v_adlar, 1))::int]
         || v_ekler[1 + floor(random() * array_length(v_ekler, 1))::int]
         || case when random() < 0.6 then (floor(random() * 99) + 1)::int::text else '' end;
    if char_length(v_ad) between 3 and 20
       and not exists (select 1 from users where lower(username) = lower(v_ad)) then
      return v_ad;
    end if;
  end loop;
  return 'Oyuncu' || (floor(random() * 900000) + 100000)::int::text;
end;
$$;

-- Rakibin kadrosuna denk bot kadrosu kurar; botun aktif deste kimligini doner.
-- Bot kartlari yeniden kullanilir (bos kopya varsa yenisi uretilmez).
create or replace function _bot_build_deck(p_bot uuid, p_against_deck uuid, p_against_user uuid)
returns uuid
language plpgsql as $$
declare
  v_deck   uuid;
  v_v5     boolean := rules_level_power(current_rules_version());
  v_mmr    int := (select mmr from users where id = p_against_user);
  r        record;
  v_card   uuid;
  v_uc     uuid;
  v_secili uuid[] := '{}';
begin
  select id into v_deck from decks where owner_id = p_bot and is_active;
  if v_deck is null then
    insert into decks (owner_id, name, is_active) values (p_bot, 'Kadro', true) returning id into v_deck;
  end if;
  delete from deck_cards where deck_id = v_deck;

  for r in
    select c.position, c.tier,
           c.power + case when v_v5 then card_level_bonus(p_against_user, c.id, v_mmr) else 0 end as etkin
    from deck_cards dc
    join user_cards uc on uc.id = dc.user_card_id
    join cards c on c.id = uc.card_id
    where dc.deck_id = p_against_deck
  loop
    -- ayni mevki + sinif, etkin guc +-3; yoksa ayni mevki + sinif en yakin; yoksa ayni mevki
    select c.id into v_card from cards c
    where c.position = r.position and c.tier = r.tier and abs(c.power - r.etkin) <= 3
    order by random() limit 1;
    if v_card is null then
      select c.id into v_card from cards c
      where c.position = r.position and c.tier = r.tier
      order by abs(c.power - r.etkin), random() limit 1;
    end if;
    if v_card is null then
      select c.id into v_card from cards c
      where c.position = r.position and c.tier <> 'legend'
      order by abs(c.power - r.etkin), random() limit 1;
    end if;

    select uc.id into v_uc from user_cards uc
    where uc.owner_id = p_bot and uc.card_id = v_card and uc.locked_match_id is null
      and not (uc.id = any (v_secili))
    limit 1;
    if v_uc is null then
      insert into user_cards (owner_id, card_id) values (p_bot, v_card) returning id into v_uc;
    end if;
    v_secili := v_secili || v_uc;
    insert into deck_cards (deck_id, user_card_id) values (v_deck, v_uc);
    v_card := null; v_uc := null;
  end loop;

  return v_deck;
end;
$$;

-- Bos bir bot secer (bu oyuncunun son 5 rakibinden olmayan), yoksa uretir.
-- Puani rakibe yakin ayarlanir (gosterim ve lig tavani icin; botun puani
-- siralamaya girmez).
create or replace function _bot_pick(p_user uuid) returns uuid
language plpgsql as $$
declare
  v_bot uuid;
  v_mmr int := (select mmr from users where id = p_user);
begin
  select u.id into v_bot from users u
  where u.is_bot
    and get_active_match_id(u.id) is null
    and u.id not in (select mp2.user_id from match_players mp
                     join match_players mp2 on mp2.match_id = mp.match_id and mp2.user_id <> mp.user_id
                     join matches m on m.id = mp.match_id
                     where mp.user_id = p_user order by m.created_at desc limit 5)
  order by random() limit 1
  for update skip locked;

  if v_bot is null then
    insert into users (email, password_hash, username, is_bot)
    values ('bot-' || gen_random_uuid() || '@bot.invalid', '!bot-giris-yok', _bot_random_username(), true)
    returning id into v_bot;
  end if;

  update users set mmr = greatest(v_mmr + (floor(random() * 101) - 50)::int, 0) where id = v_bot;
  return v_bot;
end;
$$;

-- ---------------------------------------------------------------------
-- 2) ESLESTIRME: 20 sn rakip yoksa bot (find_match AYNEN cagrilir)
-- ---------------------------------------------------------------------
create or replace function find_match_or_bot(
  p_user_id uuid,
  p_deck_id uuid,
  p_protected_card_ids uuid[] default '{}'
)
returns json
language plpgsql as $$
declare
  r        json;
  v_bot    uuid;
  v_deck   uuid;
  v_match  uuid;
begin
  r := find_match(p_user_id, p_deck_id, p_protected_card_ids);

  if r ->> 'status' <> 'queued'
     or not economy_flag('bots_v1')
     or rules_card_transfer(current_rules_version()) then
    return r;
  end if;

  perform pg_advisory_xact_lock(hashtext('futbol_card_matchmaking'));
  if not exists (select 1 from matchmaking_queue
                 where user_id = p_user_id and status = 'searching'
                   and created_at <= now() - make_interval(secs => bot_wait_seconds())) then
    return r;
  end if;

  v_bot   := _bot_pick(p_user_id);
  v_deck  := _bot_build_deck(v_bot, p_deck_id, p_user_id);
  v_match := _create_match(v_bot, v_deck, '{}', p_user_id, p_deck_id, p_protected_card_ids);

  update matchmaking_queue set status = 'matched', match_id = v_match where user_id = p_user_id;
  return json_build_object('status', 'matched', 'match_id', v_match);
end;
$$;

-- ---------------------------------------------------------------------
-- 3) ANTRENMAN: oyuncu bota karsi, odulsuz
-- ---------------------------------------------------------------------
create or replace function start_training_match(p_user_id uuid, p_deck_id uuid)
returns json
language plpgsql as $$
declare
  v_err    text;
  v_active uuid;
  v_bot    uuid;
  v_deck   uuid;
  v_match  uuid;
begin
  if not economy_flag('training_mode') then
    raise exception 'training_disabled: Antrenman modu kapali.';
  end if;
  if (select is_banned from users where id = p_user_id) then
    raise exception 'Hesabiniz askiya alinmis.';
  end if;
  v_active := get_active_match_id(p_user_id);
  if v_active is not null then
    return json_build_object('status', 'in_match', 'match_id', v_active);
  end if;
  v_err := validate_deck(p_user_id, p_deck_id);
  if v_err is not null then
    raise exception '%', v_err;
  end if;

  perform pg_advisory_xact_lock(hashtext('futbol_card_matchmaking'));
  -- kuyrukta bekliyorsa cikar (ayni anda iki mac olmasin)
  delete from matchmaking_queue where user_id = p_user_id;

  v_bot   := _bot_pick(p_user_id);
  v_deck  := _bot_build_deck(v_bot, p_deck_id, p_user_id);
  v_match := _create_match(v_bot, v_deck, '{}', p_user_id, p_deck_id, '{}');
  update matches set mode = 'training' where id = v_match;

  return json_build_object('status', 'matched', 'match_id', v_match, 'mode', 'training');
end;
$$;

-- ---------------------------------------------------------------------
-- 4) BOTUN HAMLESI (yalniz kendi elini gorur)
-- ---------------------------------------------------------------------
-- Turun "dusunme suresi" (2-5 sn): mac + tur + asamaya gore sabit, boylece
-- her saniyelik cagrida degismez.
create or replace function _bot_think_seconds(p_match uuid, p_round int, p_phase text) returns int
language sql immutable as $$
  select 2 + abs(hashtext(p_match::text || ':' || p_round || ':' || coalesce(p_phase, 'seq'))) % 4
$$;

-- Bu mevkiden oynanacak kart: inisiyatif bendeyse en guclu; savunurken
-- %65 en guclu, %35 en zayif (guclu karti saklar).
create or replace function _bot_card(p_match uuid, p_bot uuid, p_pos card_position, p_lead boolean) returns uuid
language sql volatile as $$
  select user_card_id from match_hands
  where match_id = p_match and user_id = p_bot and not is_played
    and (p_pos is null or position = p_pos)
  order by case when p_lead or random() < 0.65
                then -(power + coalesce(chemistry, 0)) else power + coalesce(chemistry, 0) end,
           user_card_id
  limit 1
$$;

-- Taktik: enerjiye gore; acarken pres/kontra, savunurken duvar/kontra agirlikli
create or replace function _bot_tactic(p_version int, p_energy int, p_lead boolean) returns text
language plpgsql volatile as $$
declare
  v_secenek text[];
  t text;
begin
  if not rules_tactics_enabled(p_version) or random() < 0.4 then
    return 'none';
  end if;
  foreach t in array case when p_lead
                          then array['high_press', 'counter_attack', 'high_press', 'defensive_wall']
                          else array['defensive_wall', 'counter_attack', 'defensive_wall', 'high_press'] end loop
    if tactic_cost_for(p_version, t) <= coalesce(p_energy, 0) then
      v_secenek := v_secenek || t;
    end if;
  end loop;
  if v_secenek is null then
    return 'none';
  end if;
  return v_secenek[1 + floor(random() * array_length(v_secenek, 1))::int];
end;
$$;

create or replace function _bot_act(p_match_id uuid) returns boolean
language plpgsql as $$
declare
  m       matches%rowtype;
  v_bot   uuid;
  v_lead  boolean;
  v_pos   card_position;
  v_card  uuid;
  v_enerji int;
begin
  select * into m from matches where id = p_match_id and status = 'active' for update skip locked;
  if not found then
    return false;
  end if;
  select u.id into v_bot from users u where u.id in (m.player1_id, m.player2_id) and u.is_bot;
  if v_bot is null then
    return false;
  end if;
  -- insan gibi dusun (son degisiklikten bu yana)
  if now() - m.updated_at < make_interval(secs => _bot_think_seconds(m.id, m.round_number, m.phase)) then
    return false;
  end if;

  v_lead := (m.lead_player_id = v_bot);
  select energy into v_enerji from match_players where match_id = m.id and user_id = v_bot;

  if rules_simultaneous(m.rules_version) then
    if m.phase = 'position' then
      if not v_lead then
        return false;
      end if;
      -- iki tarafin da karti olan mevkilerden, %75 en guclu kartimin mevkii
      select h.position into v_pos from match_hands h
      where h.match_id = m.id and h.user_id = v_bot and not h.is_played
        and exists (select 1 from match_hands o where o.match_id = m.id and o.user_id <> v_bot
                    and not o.is_played and o.position = h.position)
      order by case when random() < 0.75 then -(h.power + coalesce(h.chemistry, 0)) else random() * 100 end
      limit 1;
      if v_pos is null then
        return false;   -- zamanlayici otomatik secer
      end if;
      perform choose_position(v_bot, m.id, v_pos);
      return true;
    end if;
    -- secim asamasi
    if exists (select 1 from match_moves where match_id = m.id and round_number = m.round_number and user_id = v_bot) then
      return false;
    end if;
    v_card := _bot_card(m.id, v_bot, m.required_position, v_lead);
    if v_card is null then
      return false;
    end if;
    perform play_card(v_bot, m.id, v_card, _bot_tactic(m.rules_version, v_enerji, v_lead));
    return true;
  end if;

  -- sirali kurallar (surum 1-3)
  if m.current_turn_id <> v_bot then
    return false;
  end if;
  v_lead := (m.required_position is null);
  v_card := _bot_card(m.id, v_bot, m.required_position, v_lead);
  if v_card is null and v_lead then
    return false;
  end if;
  perform play_card(v_bot, m.id, v_card,
                    case when v_card is null then 'none' else _bot_tactic(m.rules_version, v_enerji, v_lead) end);
  return true;
end;
$$;

-- Sunucu saniyede bir cagirir. Bir macin hatasi digerlerini durdurmaz.
create or replace function bot_tick() returns int
language plpgsql as $$
declare
  r record;
  n int := 0;
begin
  for r in
    select m.id from matches m
    join users u on u.id in (m.player1_id, m.player2_id) and u.is_bot
    where m.status = 'active'
  loop
    begin
      if _bot_act(r.id) then
        n := n + 1;
      end if;
    exception when others then
      insert into economy_errors (context, user_id, source_id, error)
      values ('bot_tick', null, r.id::text, sqlerrm);
    end;
  end loop;
  return n;
end;
$$;

-- ---------------------------------------------------------------------
-- 5) ANTRENMAN MACI ODUL TETIKLEYICILERINI CALISTIRMAZ
-- ---------------------------------------------------------------------
drop trigger if exists trg_economy_match_finished on matches;
create trigger trg_economy_match_finished
  after update of status on matches
  for each row
  when (new.status = 'finished' and old.status is distinct from 'finished' and new.mode = 'ranked')  -- 041
  execute function _economy_on_match_finished();

drop trigger if exists trg_economy_season_match_finished on matches;
create trigger trg_economy_season_match_finished
  after update of status on matches
  for each row
  when (new.status = 'finished' and old.status is distinct from 'finished' and new.mode = 'ranked')  -- 041
  execute function _economy_season_on_match_finished();

-- ---------------------------------------------------------------------
-- 6) LIDERLIK TABLOSU BOTLARI GOSTERMEZ (019 govdeleri + "041" satirlari)
-- ---------------------------------------------------------------------
create or replace function get_leaderboard(
  p_limit  int default 50,
  p_offset int default 0
)
returns table (
  rank_position bigint,
  user_id      uuid,
  username     text,
  mmr          int,
  wins         int,
  losses       int,
  draws        int,
  league_name  text,
  division     smallint,
  color        text
)
language sql
stable
as $$
  with siralanmis as (
    select
      row_number() over (order by u.mmr desc, u.wins desc, u.created_at asc)
        as sira,
      u.id, u.username, u.mmr, u.wins, u.losses, u.draws
    from users u
    where not u.is_banned
      and not u.is_bot                                                   -- 041
  )
  select
    s.sira,
    s.id,
    s.username,
    s.mmr,
    s.wins,
    s.losses,
    s.draws,
    t.league_name,
    t.division,
    t.color
  from siralanmis s
  cross join lateral rank_for_mmr(s.mmr) t
  order by s.sira
  limit greatest(1, least(p_limit, 200))
  offset greatest(0, p_offset);
$$;

create or replace function get_my_leaderboard_position(p_user_id uuid)
returns bigint
language sql
stable
as $$
  select count(*) + 1
  from users u
  join users me on me.id = p_user_id
  where not u.is_banned
    and not u.is_bot                                                     -- 041
    and (
      u.mmr > me.mmr
      or (u.mmr = me.mmr and u.wins > me.wins)
      or (u.mmr = me.mmr and u.wins = me.wins and u.created_at < me.created_at)
    );
$$;

-- ---------------------------------------------------------------------
-- 6b) MAC GECMISI ANTRENMANI GOSTERMEZ (017 govdesi + "041" satiri)
-- ---------------------------------------------------------------------
create or replace function get_match_history(
  p_user_id uuid,
  p_limit   int default 20,
  p_offset  int default 0
)
returns table (
  match_id          uuid,
  opponent_id       uuid,
  opponent_username text,
  my_score          int,
  opponent_score    int,

  -- 'win' | 'loss' | 'draw'
  outcome           text,

  -- Bu macta el degistiren kart sayisi (kazandigim / kaptirdigim)
  cards_won         int,
  cards_lost        int,

  finished_at       timestamptz
)
language sql
stable
as $$
  select
    m.id,
    case when m.player1_id = p_user_id then m.player2_id else m.player1_id end,
    u.username,

    -- Skor: kim hangi tarafsa onun toplanan kart sayisi
    case when m.player1_id = p_user_id then m.p1_captured_count
         else m.p2_captured_count end,
    case when m.player1_id = p_user_id then m.p2_captured_count
         else m.p1_captured_count end,

    case when m.is_draw            then 'draw'
         when m.winner_id = p_user_id then 'win'
         else 'loss' end,

    -- Kart transferleri card_transfers tablosunda tutuluyor
    coalesce((
      select count(*)::int from card_transfers t
      where t.match_id = m.id and t.to_user_id = p_user_id
    ), 0),
    coalesce((
      select count(*)::int from card_transfers t
      where t.match_id = m.id and t.from_user_id = p_user_id
    ), 0),

    m.finished_at
  from matches m
  join users u
    on u.id = case when m.player1_id = p_user_id
                   then m.player2_id else m.player1_id end
  where (m.player1_id = p_user_id or m.player2_id = p_user_id)
    and m.status = 'finished'
    and m.mode = 'ranked'                                              -- 041: antrenman gecmise girmez
  order by m.finished_at desc nulls last
  limit greatest(1, least(p_limit, 100))
  offset greatest(0, p_offset);
$$;

-- ---------------------------------------------------------------------
-- 7) MAC SONU: antrenman blogu (gerisi 037 ile AYNI)
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

  -- 041: ANTRENMAN maci odulsuz ve puansiz biter: transfer, MMR, altin,
  -- galibiyet/maglubiyet sayaci, sandik, sezon XP'si YOK. Yalniz kartlarin
  -- kilidi acilir ve mac kapanir (kazanan gosterim icin yazilir).
  if m.mode = 'training' then                                            -- 041
    if p_forced_winner is not null then                                  -- 041
      v_winner := p_forced_winner; v_loser := _opponent_of(m, p_forced_winner); -- 041
    elsif m.p1_captured_count > m.p2_captured_count then                 -- 041
      v_winner := m.player1_id; v_loser := m.player2_id;                 -- 041
    elsif m.p2_captured_count > m.p1_captured_count then                 -- 041
      v_winner := m.player2_id; v_loser := m.player1_id;                 -- 041
    else                                                                 -- 041
      v_draw := true;                                                    -- 041
    end if;                                                              -- 041
    update user_cards set locked_match_id = null where locked_match_id = p_match_id; -- 041
    update matches set status = 'finished', winner_id = v_winner, loser_id = v_loser, -- 041
                       is_draw = v_draw, finished_at = now() where id = p_match_id;   -- 041
    return;                                                              -- 041
  end if;                                                                -- 041

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
