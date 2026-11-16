-- 047: Invite-only, two-player FRIENDLY rooms. No MMR, card transfer or reward.
-- This migration is additive; existing ranked matchmaking is unchanged.
-- Codes use 120 random bits encoded as hex, not sequential predictable IDs.
alter table matches drop constraint if exists matches_mode_check;
alter table matches add constraint matches_mode_check
  check (mode in ('ranked','training','tutorial','friendly'));

create table if not exists friend_rooms (
  id uuid primary key default gen_random_uuid(),
  invite_code text not null unique default encode(gen_random_bytes(15), 'hex'),
  host_id uuid not null references users(id) on delete cascade,
  guest_id uuid references users(id) on delete set null,
  host_deck_id uuid references decks(id),
  guest_deck_id uuid references decks(id),
  host_ready boolean not null default false,
  guest_ready boolean not null default false,
  status text not null default 'waiting'
    check (status in ('waiting','started','cancelled','expired')),
  match_id uuid references matches(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '15 minutes',
  constraint friend_room_distinct_users check (guest_id is null or guest_id <> host_id),
  constraint friend_room_valid_code check (invite_code ~ '^[0-9a-f]{30}$')
);
create index if not exists idx_friend_rooms_host_open on friend_rooms(host_id, created_at desc) where status = 'waiting';
create index if not exists idx_friend_rooms_guest_open on friend_rooms(guest_id, created_at desc) where status = 'waiting';

-- The only public lookup key is the cryptographically random invite code.
-- All read/write RPCs require a JWT-derived player id from the application server.
create or replace function friend_room_info(p_actor uuid, p_code text)
returns json
language plpgsql stable as $$
declare
  r friend_rooms%rowtype;
begin
  select * into r from friend_rooms where invite_code = lower(p_code);
  if not found then return json_build_object('status','not_found'); end if;
  if r.host_id <> p_actor and r.guest_id is distinct from p_actor then
    return json_build_object('status','not_member');
  end if;
  return json_build_object(
    'status', case when r.status='waiting' and r.expires_at <= now() then 'expired' else r.status end,
    'code', r.invite_code, 'host_ready', r.host_ready, 'guest_ready', r.guest_ready,
    'is_host', r.host_id=p_actor, 'host_name', (select username from users where id=r.host_id),
    'guest_name', (select username from users where id=r.guest_id),
    'match_id',r.match_id,'expires_at',r.expires_at
  );
end;
$$;

create or replace function friend_room_create(p_actor uuid)
returns json language plpgsql as $$
declare
  r friend_rooms%rowtype;
begin
  perform pg_advisory_xact_lock(hashtext('futbol_card_matchmaking'));
  if not exists (select 1 from users where id=p_actor and not is_banned) then
    raise exception 'Oyuncu bulunamadi veya engellendi.';
  end if;
  if get_active_match_id(p_actor) is not null then
    raise exception 'Devam eden macin var. Once onu tamamla.';
  end if;
  -- Limit an account to one open invitation. Idempotent create, preserving code.
  select * into r from friend_rooms where host_id=p_actor and status='waiting'
    and expires_at>now() order by created_at desc limit 1 for update;
  if not found then
    insert into friend_rooms(host_id) values(p_actor) returning * into r;
  end if;
  return friend_room_info(p_actor,r.invite_code);
end;
$$;

create or replace function friend_room_join(p_actor uuid,p_code text)
returns json language plpgsql as $$
declare
  r friend_rooms%rowtype;
begin
  perform pg_advisory_xact_lock(hashtext('futbol_card_matchmaking'));
  select * into r from friend_rooms where invite_code=lower(p_code) for update;
  if not found then raise exception 'Davet bulunamadi.'; end if;
  if r.status<>'waiting' or r.expires_at<=now() then raise exception 'Davetin suresi doldu veya mac basladi.'; end if;
  if r.host_id=p_actor then return friend_room_info(p_actor,r.invite_code); end if;
  if r.guest_id is not null and r.guest_id<>p_actor then raise exception 'Oda dolu.'; end if;
  if not exists(select 1 from users where id=p_actor and not is_banned) then
    raise exception 'Oyuncu bulunamadi veya engellendi.';
  end if;
  if get_active_match_id(p_actor) is not null then raise exception 'Devam eden macin var.'; end if;
  if exists (select 1 from friend_rooms where status='waiting' and expires_at>now()
             and host_id<>r.host_id and (host_id=p_actor or guest_id=p_actor)) then
    raise exception 'Baska bir acik odadasin. Once cik.';
  end if;
  update friend_rooms set guest_id=p_actor, guest_ready=false where id=r.id;
  return friend_room_info(p_actor,r.invite_code);
end;
$$;

create or replace function friend_room_ready(p_actor uuid,p_code text,p_deck uuid)
returns json language plpgsql as $$
declare
  r friend_rooms%rowtype;
  v_err text;
  v_match uuid;
begin
  perform pg_advisory_xact_lock(hashtext('futbol_card_matchmaking'));
  select * into r from friend_rooms where invite_code=lower(p_code) for update;
  if not found or (r.host_id<>p_actor and r.guest_id is distinct from p_actor) then
    raise exception 'Oda bulunamadi.';
  end if;
  if r.status='started' then return friend_room_info(p_actor,r.invite_code); end if;
  if r.status<>'waiting' or r.expires_at<=now() then raise exception 'Davetin suresi doldu.'; end if;
  if get_active_match_id(p_actor) is not null then raise exception 'Devam eden macin var.'; end if;
  if p_deck is not null then
    v_err:=validate_deck(p_actor,p_deck);
    if v_err is not null then raise exception '%',v_err; end if;
  end if;
  if r.host_id=p_actor then
    update friend_rooms set host_ready=(p_deck is not null),host_deck_id=p_deck where id=r.id;
  else
    update friend_rooms set guest_ready=(p_deck is not null),guest_deck_id=p_deck where id=r.id;
  end if;
  select * into r from friend_rooms where id=r.id for update;
  if r.host_ready and r.guest_ready and r.guest_id is not null then
    -- Revalidate both decks *inside* the single matching lock.
    v_err:=validate_deck(r.host_id,r.host_deck_id);
    if v_err is not null then
      update friend_rooms set host_ready=false where id=r.id;
      raise exception 'Oda sahibinin kadrosu degisti: %',v_err;
    end if;
    v_err:=validate_deck(r.guest_id,r.guest_deck_id);
    if v_err is not null then
      update friend_rooms set guest_ready=false where id=r.id;
      raise exception 'Konugun kadrosu degisti: %',v_err;
    end if;
    if get_active_match_id(r.host_id) is not null or get_active_match_id(r.guest_id) is not null then
      raise exception 'Oyunculardan biri baska macta.';
    end if;
    -- Remove both players from public ranked queue so they cannot double-match.
    delete from matchmaking_queue where user_id in (r.host_id,r.guest_id);
    v_match:=_create_match(r.host_id,r.host_deck_id,'{}',r.guest_id,r.guest_deck_id,'{}');
    update matches set mode='friendly' where id=v_match;
    update friend_rooms set status='started',match_id=v_match where id=r.id;
  end if;
  return friend_room_info(p_actor,r.invite_code);
end;
$$;

create or replace function friend_room_leave(p_actor uuid,p_code text)
returns json language plpgsql as $$
declare
  r friend_rooms%rowtype;
begin
  perform pg_advisory_xact_lock(hashtext('futbol_card_matchmaking'));
  select * into r from friend_rooms where invite_code=lower(p_code) for update;
  if not found then return json_build_object('status','not_found'); end if;
  if r.host_id<>p_actor and r.guest_id is distinct from p_actor then
    raise exception 'Bu odanin uyesi degilsin.';
  end if;
  if r.status='started' then return friend_room_info(p_actor,r.invite_code); end if;
  if r.status<>'waiting' then return friend_room_info(p_actor,r.invite_code); end if;
  if r.host_id=p_actor then
    update friend_rooms set status='cancelled' where id=r.id;
  else
    update friend_rooms set guest_id=null,guest_deck_id=null,guest_ready=false,
      host_ready=false,host_deck_id=null where id=r.id;
  end if;
  return json_build_object('status','left');
end;
$$;

-- Friendly matches use training/tutorial reward suppression without bot logic.
-- This existing 042 function is copied with ONLY mode list extended to friendly.
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
  if m.mode in ('training', 'tutorial', 'friendly') then                             -- 041 / 042: ogretici de odulsuz
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
