-- =====================================================================
-- 058 - ARKADAŞINI DOSTLUK MAÇINA ÇAĞIR
-- =====================================================================
-- Oyuncu arkadaş listesinden bir arkadaşını maça çağırır:
--   1. Çağıranın özel odası açılır (047 arkadaş odası; ödülsüz, kart
--      kaybı yok) ve oyuncu odada bekler.
--   2. Çağrılan oyuncuya anlık bildirim gider (social_events kanalı).
--      Uygulama açıksa ekranın üstünde bir davet kutucuğu kayarak gelir.
--   3. Kabul ederse aynı odaya katılır; iki taraf kadrosunu seçip HAZIR
--      deyince maç başlar (mevcut oda akışı).
--   4. Reddederse, süre dolarsa (60 sn) ya da çağıran odadan çıkarsa
--      davet kapanır; iki tarafa da bildirim gider.
--
-- KURALLAR
--   * Yalnız arkadaşlar (056 friendships, kabul edilmiş) çağrılabilir.
--   * Aynı arkadaşa bekleyen davet varken yenisi açılmaz (aynısı döner).
--   * Dakikada en fazla 6 davet gönderilebilir (taciz/spam önlemi).
--   * Bir oyuncuya aynı anda gelen bekleyen davetlerin hepsi listelenir;
--     uygulama en yenisini gösterir.
--
-- KULLANICI VERİSİ: yalnız yeni tablo; mevcut veriye dokunulmaz.
-- Tekrar çalıştırılabilir.
-- =====================================================================

create table if not exists friend_challenges (
  id            uuid primary key default gen_random_uuid(),
  from_id       uuid not null references users(id) on delete cascade,
  to_id         uuid not null references users(id) on delete cascade,
  room_id       uuid not null references friend_rooms(id) on delete cascade,
  status        text not null default 'pending'
                check (status in ('pending', 'accepted', 'declined', 'cancelled', 'expired')),
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default now() + interval '60 seconds',
  responded_at  timestamptz,
  check (from_id <> to_id)
);
create index if not exists idx_friend_challenges_to_pending on friend_challenges (to_id, created_at desc) where status = 'pending';
create index if not exists idx_friend_challenges_from on friend_challenges (from_id, created_at desc);
comment on table friend_challenges is '058: arkadaşı dostluk maçına çağırma. Oda 047 friend_rooms; davet 60 sn geçerli.';

create or replace function _friend_challenge_seconds() returns int
language sql immutable as $$ select 60 $$;

-- Bildirim: yalnız kimlik ve durum gider (ayrıntıyı istemci sorar)
create or replace function _friend_challenge_notify(p_user uuid, p_event text, c friend_challenges) returns void
language plpgsql as $$
begin
  perform pg_notify('social_events', json_build_object(
    'event', p_event, 'user_id', p_user, 'challenge_id', c.id, 'status', c.status, 'at', now())::text);
end;
$$;

-- Süresi dolan, odası kapanan davetleri kapat (tembel temizlik)
create or replace function _friend_challenges_expire(p_user uuid) returns void
language plpgsql as $$
declare
  c friend_challenges%rowtype;
begin
  for c in
    update friend_challenges fc set status = 'expired', responded_at = now()
    from friend_rooms r
    where fc.room_id = r.id and fc.status = 'pending' and p_user in (fc.from_id, fc.to_id)
      and (fc.expires_at <= now() or r.status <> 'waiting' or r.expires_at <= now() or r.guest_id is not null)
    returning fc.*
  loop
    perform _friend_challenge_notify(c.from_id, 'friend_challenge_update', c);
    perform _friend_challenge_notify(c.to_id, 'friend_challenge_update', c);
  end loop;
end;
$$;

-- Bir daveti oyuncuya gösterilecek biçimde
create or replace function _friend_challenge_json(c friend_challenges) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'id', c.id,
    'status', c.status,
    'code', (select invite_code from friend_rooms where id = c.room_id),
    'from', (select jsonb_build_object('id', u.id, 'username', u.username, 'avatar_url', u.avatar_url, 'mmr', u.mmr)
             from users u where u.id = c.from_id),
    'to', (select jsonb_build_object('id', u.id, 'username', u.username) from users u where u.id = c.to_id),
    'created_at', c.created_at,
    'expires_at', c.expires_at,
    'seconds_left', greatest(0, ceil(extract(epoch from (c.expires_at - now()))))::int);
$$;

-- ---------------------------------------------------------------------
-- ÇAĞIR
-- ---------------------------------------------------------------------
create or replace function friend_challenge_send(p_user_id uuid, p_friend uuid) returns jsonb
language plpgsql as $$
declare
  c       friend_challenges%rowtype;
  v_oda   json;
  v_room  friend_rooms%rowtype;
begin
  if p_user_id = p_friend then
    raise exception 'challenge_self: Kendini maça çağıramazsın.';
  end if;
  if _friend_status(p_user_id, p_friend) <> 'friends' then
    raise exception 'challenge_not_friend: Yalnız arkadaşlarını maça çağırabilirsin.';
  end if;
  if exists (select 1 from users where id = p_friend and is_banned) then
    raise exception 'player_not_found: Oyuncu bulunamadi.';
  end if;
  perform pg_advisory_xact_lock(hashtext('friend_challenge:' || p_user_id::text));
  perform _friend_challenges_expire(p_user_id);

  -- Aynı arkadaşa bekleyen davet varsa aynısı
  select * into c from friend_challenges
  where from_id = p_user_id and to_id = p_friend and status = 'pending' and expires_at > now()
  order by created_at desc limit 1;
  if found then
    return _friend_challenge_json(c);
  end if;

  if (select count(*) from friend_challenges
      where from_id = p_user_id and created_at > now() - interval '1 minute') >= 6 then
    raise exception 'challenge_rate_limit: Çok sık davet gönderdin. Biraz bekle.';
  end if;

  -- Özel oda (açık odası varsa o kullanılır; maçtaysa hata verir)
  v_oda := friend_room_create(p_user_id);
  select * into v_room from friend_rooms where invite_code = v_oda ->> 'code';
  if v_room.guest_id is not null then
    raise exception 'challenge_room_full: Odanda zaten bir oyuncu var.';
  end if;

  -- Aynı odadan başka arkadaşlara giden eski davetler kapanır (oda tek kişilik)
  for c in
    update friend_challenges set status = 'cancelled', responded_at = now()
    where room_id = v_room.id and status = 'pending'
    returning *
  loop
    perform _friend_challenge_notify(c.to_id, 'friend_challenge_update', c);
  end loop;

  insert into friend_challenges (from_id, to_id, room_id, expires_at)
  values (p_user_id, p_friend, v_room.id,
          least(now() + make_interval(secs => _friend_challenge_seconds()), v_room.expires_at))
  returning * into c;
  perform _friend_challenge_notify(p_friend, 'friend_challenge', c);
  return _friend_challenge_json(c);
end;
$$;

-- ---------------------------------------------------------------------
-- BANA GELENLER (en yeni önce)
-- ---------------------------------------------------------------------
create or replace function friend_challenge_incoming(p_user_id uuid) returns jsonb
language plpgsql as $$
begin
  perform _friend_challenges_expire(p_user_id);
  return coalesce((
    select jsonb_agg(_friend_challenge_json(c) order by c.created_at desc)
    from friend_challenges c
    where c.to_id = p_user_id and c.status = 'pending' and c.expires_at > now()
  ), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------
-- KABUL / RET
-- ---------------------------------------------------------------------
create or replace function friend_challenge_respond(p_user_id uuid, p_challenge uuid, p_accept boolean) returns jsonb
language plpgsql as $$
declare
  c friend_challenges%rowtype;
begin
  perform _friend_challenges_expire(p_user_id);
  select * into c from friend_challenges where id = p_challenge and to_id = p_user_id for update;
  if not found then
    raise exception 'challenge_not_found: Davet bulunamadı.';
  end if;
  if c.status <> 'pending' then
    raise exception 'challenge_closed: Bu davet artık geçerli değil.';
  end if;
  if p_accept then
    -- Odaya katıl (maçta ya da başka odadaysa hata verir; davet açık kalır)
    perform friend_room_join(p_user_id, (select invite_code from friend_rooms where id = c.room_id));
    update friend_challenges set status = 'accepted', responded_at = now() where id = c.id returning * into c;
  else
    update friend_challenges set status = 'declined', responded_at = now() where id = c.id returning * into c;
  end if;
  perform _friend_challenge_notify(c.from_id, 'friend_challenge_update', c);
  perform _friend_challenge_notify(c.to_id, 'friend_challenge_update', c);
  return _friend_challenge_json(c);
end;
$$;

-- ---------------------------------------------------------------------
-- GERİ ÇEK (çağıran vazgeçti ya da odadan çıktı)
-- ---------------------------------------------------------------------
create or replace function friend_challenge_cancel(p_user_id uuid, p_challenge uuid) returns jsonb
language plpgsql as $$
declare
  c friend_challenges%rowtype;
begin
  update friend_challenges set status = 'cancelled', responded_at = now()
  where id = p_challenge and from_id = p_user_id and status = 'pending'
  returning * into c;
  if not found then
    select * into c from friend_challenges where id = p_challenge and from_id = p_user_id;
    if not found then
      raise exception 'challenge_not_found: Davet bulunamadı.';
    end if;
    return _friend_challenge_json(c);
  end if;
  perform _friend_challenge_notify(c.to_id, 'friend_challenge_update', c);
  return _friend_challenge_json(c);
end;
$$;
