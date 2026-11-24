-- =====================================================================
-- 056 - ELMAS, ARKADAŞLIK, AÇIK PROFİL, RAKİP KADROSU
-- =====================================================================
-- 1) ELMAS (oyunun nadir para birimi)
--    * Her oyuncu 50 elmasla başlar (mevcut oyuncular dahil).
--    * Kazanma: sandık açınca türüne göre birkaç elmas (bronz 1-3 ...
--      efsane 15-25). Gerçek para ile satın alma YOK (ödeme altyapısı yok).
--    * Harcama: (a) yuvadaki sandığı beklemeden aç — kalan her 10 dakika
--      için 1 elmas, en az 1; (b) mağazada elmasla altın paketi.
--    * Her değişiklik gem_ledger'a yazılır; aynı anahtar iki kez işlemez.
--
-- 2) ARKADAŞLIK: istek gönder / kabul et / reddet / sil, oyuncu ara.
--    Karşılıklı istekte ikisi de istek attıysa otomatik arkadaş olunur.
--
-- 3) AÇIK PROFİL: herkes herkesin profilini görür. GÖRÜNEN: ad, lig,
--    kupa, G/M/B, kazanma oranı, son 5 maç formu, koleksiyon sayısı,
--    en güçlü 3 kartı, giydiği çerçeve/rozet, katılma tarihi, çevrimiçi
--    durumu, aranızdaki maç sonucu ve arkadaşlık durumu.
--    GİZLİ: e-posta, altın, elmas, eşyalar, kadronun tamamı, maç rakipleri.
--
-- 4) RAKİP KADROSU: bitmiş bir maçın oyuncusu, rakibinin o maça soktuğu
--    11 kartı görebilir (maç sırasında gizli olan el, maç bitince açılır).
--
-- KULLANICI VERİSİ: yalnız yeni "gems" sütunu eklenir; kart, kadro, altın,
-- maç kayıtlarına dokunulmaz. Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) ELMAS
-- ---------------------------------------------------------------------
alter table users add column if not exists gems int not null default 50;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'users_gems_nonnegative') then
    alter table users add constraint users_gems_nonnegative check (gems >= 0);
  end if;
end $$;

create table if not exists gem_ledger (
  id               bigint generated always as identity primary key,
  user_id          uuid not null references users(id) on delete cascade,
  delta            int  not null,
  gems_after       int  not null,
  reason           text not null check (reason ~ '^[a-z_]+$'),
  source_id        text not null,
  idempotency_key  text not null unique,
  created_at       timestamptz not null default now()
);
create index if not exists idx_gem_ledger_user on gem_ledger (user_id, created_at desc);
comment on table gem_ledger is '056: elmas defteri. Her kazanma/harcama bir satir; anahtar tekil.';

-- Kurallar tek yerde
create or replace function _gem_rules() returns jsonb
language sql immutable as $$
  select '{
    "starting": 50,
    "chest": {"bronze": [1, 3], "silver": [2, 5], "gold": [5, 10], "legend": [15, 25]},
    "open_seconds_per_gem": 600,
    "exchange": [
      {"slug": "gold_small",  "gems": 10,  "coins": 250},
      {"slug": "gold_medium", "gems": 50,  "coins": 1400},
      {"slug": "gold_large",  "gems": 120, "coins": 3600}
    ]
  }'::jsonb;
$$;

-- Elmas ekle/düş. Aynı anahtar ikinci kez gelirse ilk sonucu döner.
create or replace function _gem_add(p_user_id uuid, p_delta int, p_reason text, p_source text, p_key text)
returns int
language plpgsql as $$
declare
  v_gems int;
  v_eski gem_ledger%rowtype;
begin
  select * into v_eski from gem_ledger where idempotency_key = p_key;
  if found then
    return v_eski.gems_after;
  end if;
  select gems into v_gems from users where id = p_user_id for update;
  if not found then
    raise exception 'user_not_found: Oyuncu bulunamadi.';
  end if;
  if v_gems + p_delta < 0 then
    raise exception 'not_enough_gems: Yeterli elmas yok. Gerekli: %, mevcut: %', -p_delta, v_gems;
  end if;
  update users set gems = gems + p_delta where id = p_user_id;
  insert into gem_ledger (user_id, delta, gems_after, reason, source_id, idempotency_key)
  values (p_user_id, p_delta, v_gems + p_delta, p_reason, p_source, p_key);
  return v_gems + p_delta;
end;
$$;

-- Sandık açılınca elmas: open_chest durumu 'opened' yaptığı anda.
-- Sonuç (result) içine "gems" ve "gems_after" eklenir; sunucu açılış
-- cevabını bu kayıttan okur.
create or replace function _chest_gems_on_open() returns trigger
language plpgsql as $$
declare
  r      jsonb := _gem_rules() -> 'chest' -> new.chest_type;
  v_n    int;
  v_son  int;
begin
  if new.status = 'opened' and old.status is distinct from 'opened' and r is not null then
    v_n := _rand_between((r ->> 0)::int, (r ->> 1)::int);
    v_son := _gem_add(new.user_id, v_n, 'chest', new.id::text, 'chest_gems:' || new.id);
    new.result := coalesce(new.result, '{}'::jsonb) || jsonb_build_object('gems', v_n, 'gems_after', v_son);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_chest_gems_on_open on user_chests;
create trigger trg_chest_gems_on_open
  before update of status on user_chests
  for each row execute function _chest_gems_on_open();

-- open_chest'in İLK cevabı da elmaslı olsun: asıl gövde _open_chest_core
-- adını alır, open_chest kayıtlı sonucu (tetikleyicinin elmas eklediği)
-- döndüren ince bir sarmalayıcı olur. Migration'lar baştan tekrar
-- çalıştırılınca 052 open_chest'i yeniden yazar; işaret yoksa yeniden
-- sarılır (tekrar çalıştırılabilir).
do $$
begin
  if position('056-sarmalayici' in pg_get_functiondef('open_chest(uuid,uuid)'::regprocedure)) = 0 then
    drop function if exists _open_chest_core(uuid, uuid);
    alter function open_chest(uuid, uuid) rename to _open_chest_core;
  end if;
end $$;

create or replace function open_chest(p_user_id uuid, p_chest_id uuid)
returns jsonb
language plpgsql as $$
declare
  v jsonb;
begin
  -- 056-sarmalayici
  v := _open_chest_core(p_user_id, p_chest_id);
  return coalesce((select result from user_chests
                   where id = p_chest_id and user_id = p_user_id and status = 'opened'), v);
end;
$$;

-- Yuvadaki sandığı hemen açmanın elmas bedeli (null: açılamaz)
create or replace function gem_open_cost(c user_chests) returns int
language sql stable as $$
  select case
    when c.location <> 'slot' then null
    when c.status = 'sealed' then
      greatest(1, ceil((_chest_rules() -> 'types' -> c.chest_type ->> 'unlock_seconds')::numeric
                       / (_gem_rules() ->> 'open_seconds_per_gem')::numeric)::int)
    when c.status = 'unlocking' and c.unlock_ready_at > now() then
      greatest(1, ceil(extract(epoch from (c.unlock_ready_at - now()))
                       / (_gem_rules() ->> 'open_seconds_per_gem')::numeric)::int)
    else null
  end;
$$;

-- Elmasla hemen aç. p_expected_cost: oyuncunun ekranda gördüğü bedel;
-- bedel bundan YÜKSEKSE işlem yapılmaz (fazla elmas alınmaz).
create or replace function open_chest_with_gems(p_user_id uuid, p_chest_id uuid, p_expected_cost int)
returns jsonb
language plpgsql as $$
declare
  c       user_chests%rowtype;
  v_cost  int;
  v_son   int;
  v_sonuc jsonb;
begin
  perform pg_advisory_xact_lock(hashtext('user_chests:' || p_user_id::text));
  select * into c from user_chests where id = p_chest_id and user_id = p_user_id for update;
  if not found then
    raise exception 'chest_not_found: Sandik bulunamadi.';
  end if;
  if c.status = 'opened' then
    return c.result;
  end if;
  v_cost := gem_open_cost(c);
  if v_cost is null then
    raise exception 'chest_not_gem_openable: Bu sandik elmasla acilamaz.';
  end if;
  if p_expected_cost is not null and v_cost > p_expected_cost then
    raise exception 'gem_cost_changed: Bedel degisti, tekrar dene.';
  end if;
  v_son := _gem_add(p_user_id, -v_cost, 'chest_instant_open', c.id::text, 'gem_open:' || c.id);
  update user_chests
  set status = 'unlocking', unlocked_by_item = true,
      unlock_started_at = coalesce(unlock_started_at, now()), unlock_ready_at = now()
  where id = c.id;
  perform open_chest(p_user_id, c.id);
  select result into v_sonuc from user_chests where id = c.id;
  return v_sonuc || jsonb_build_object('gems_spent', v_cost,
                                       'gems_after', (select gems from users where id = p_user_id));
end;
$$;

-- Elmasla altın paketi
create or replace function buy_coins_with_gems(p_user_id uuid, p_offer text, p_request_key text)
returns jsonb
language plpgsql as $$
declare
  o       jsonb;
  v_key   text := 'gem_exchange:' || p_user_id || ':' || p_request_key;
  v_eski  economy_ledger%rowtype;
  v_gems  int;
begin
  perform pg_advisory_xact_lock(hashtext('gems:' || p_user_id::text));
  select * into v_eski from economy_ledger where idempotency_key = v_key;
  if found then
    return v_eski.items || jsonb_build_object('coins_after', v_eski.coins_after,
      'gems_after', (select gems from users where id = p_user_id), 'replay', true);
  end if;
  select x into o from jsonb_array_elements(_gem_rules() -> 'exchange') x where x ->> 'slug' = p_offer;
  if o is null then
    raise exception 'offer_not_found: Teklif bulunamadi.';
  end if;
  v_gems := _gem_add(p_user_id, -(o ->> 'gems')::int, 'gold_exchange', p_offer, v_key);
  perform _ledger_add(p_user_id, 'gem_exchange', (o ->> 'coins')::int,
                      jsonb_build_object('offer', p_offer, 'gems', (o ->> 'gems')::int, 'coins', (o ->> 'coins')::int),
                      'gem_exchange', p_offer, v_key);
  return jsonb_build_object('offer', p_offer, 'gems', (o ->> 'gems')::int, 'coins', (o ->> 'coins')::int,
                            'coins_after', (select coins from users where id = p_user_id), 'gems_after', v_gems);
end;
$$;

create or replace function gem_status(p_user_id uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'gems', (select gems from users where id = p_user_id),
    'exchange', _gem_rules() -> 'exchange',
    'chest_gems', _gem_rules() -> 'chest',
    'open_seconds_per_gem', (_gem_rules() ->> 'open_seconds_per_gem')::int,
    'open_costs', coalesce((
      select jsonb_object_agg(c.id::text, gem_open_cost(c))
      from user_chests c
      where c.user_id = p_user_id and c.location = 'slot' and gem_open_cost(c) is not null
    ), '{}'::jsonb));
$$;

-- ---------------------------------------------------------------------
-- 2) ARKADAŞLIK
-- ---------------------------------------------------------------------
create table if not exists friendships (
  user_low      uuid not null references users(id) on delete cascade,
  user_high     uuid not null references users(id) on delete cascade,
  requested_by  uuid not null references users(id) on delete cascade,
  status        text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at    timestamptz not null default now(),
  accepted_at   timestamptz,
  primary key (user_low, user_high),
  check (user_low < user_high),
  check (requested_by in (user_low, user_high))
);
create index if not exists idx_friendships_high on friendships (user_high);
comment on table friendships is '056: arkadaslik. Cift bir kez (kucuk id, buyuk id); istek veya kabul.';

create or replace function _friend_status(p_me uuid, p_other uuid) returns text
language sql stable as $$
  select case
    when p_me = p_other then 'self'
    when f.status = 'accepted' then 'friends'
    when f.status = 'pending' and f.requested_by = p_me then 'outgoing'
    when f.status = 'pending' then 'incoming'
    else 'none' end
  from (select 1) d
  left join friendships f on f.user_low = least(p_me, p_other) and f.user_high = greatest(p_me, p_other);
$$;

-- Liste satırı (arkadaş / istek / arama sonucu): yalnız açık bilgiler
create or replace function _player_card(p_me uuid, u users) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'id', u.id, 'username', u.username, 'avatar_url', u.avatar_url,
    'mmr', u.mmr, 'wins', u.wins, 'losses', u.losses, 'draws', u.draws,
    'online', coalesce(u.last_seen_at > now() - interval '10 minutes', false),
    'last_seen_at', u.last_seen_at,
    'friend_status', _friend_status(p_me, u.id));
$$;

create or replace function friend_request(p_user_id uuid, p_target uuid) returns jsonb
language plpgsql as $$
declare
  f       friendships%rowtype;
  t       users%rowtype;
  v_low   uuid := least(p_user_id, p_target);
  v_high  uuid := greatest(p_user_id, p_target);
begin
  if p_user_id = p_target then
    raise exception 'friend_self: Kendine arkadaslik istegi gonderemezsin.';
  end if;
  select * into t from users where id = p_target;
  if not found or t.is_banned then
    raise exception 'player_not_found: Oyuncu bulunamadi.';
  end if;
  perform pg_advisory_xact_lock(hashtext('friends:' || v_low || ':' || v_high));
  select * into f from friendships where user_low = v_low and user_high = v_high for update;
  if found then
    if f.status = 'pending' and f.requested_by = p_target then
      -- Karşı taraf zaten istemişti: kabul edilmiş say
      update friendships set status = 'accepted', accepted_at = now()
      where user_low = v_low and user_high = v_high;
    end if;
    return jsonb_build_object('friend_status', _friend_status(p_user_id, p_target));
  end if;
  if (select count(*) from friendships where status = 'accepted' and p_user_id in (user_low, user_high)) >= 100 then
    raise exception 'friend_limit: En fazla 100 arkadas olabilir.';
  end if;
  if (select count(*) from friendships where status = 'pending' and requested_by = p_user_id) >= 50 then
    raise exception 'friend_request_limit: Bekleyen cok fazla istegin var.';
  end if;
  insert into friendships (user_low, user_high, requested_by) values (v_low, v_high, p_user_id);
  return jsonb_build_object('friend_status', 'outgoing');
end;
$$;

create or replace function friend_respond(p_user_id uuid, p_other uuid, p_accept boolean) returns jsonb
language plpgsql as $$
declare
  f friendships%rowtype;
begin
  select * into f from friendships
  where user_low = least(p_user_id, p_other) and user_high = greatest(p_user_id, p_other) for update;
  if not found or f.status <> 'pending' or f.requested_by = p_user_id then
    raise exception 'friend_request_not_found: Bekleyen istek bulunamadi.';
  end if;
  if p_accept then
    update friendships set status = 'accepted', accepted_at = now()
    where user_low = f.user_low and user_high = f.user_high;
  else
    delete from friendships where user_low = f.user_low and user_high = f.user_high;
  end if;
  return jsonb_build_object('friend_status', _friend_status(p_user_id, p_other));
end;
$$;

-- Arkadaşlıktan çıkar ya da gönderilen isteği geri çek
create or replace function friend_remove(p_user_id uuid, p_other uuid) returns jsonb
language sql as $$
  delete from friendships
  where user_low = least(p_user_id, p_other) and user_high = greatest(p_user_id, p_other);
  select jsonb_build_object('friend_status', 'none');
$$;

create or replace function friend_list(p_user_id uuid) returns jsonb
language sql stable as $$
  with iliski as (
    select f.*, case when f.user_low = p_user_id then f.user_high else f.user_low end as other
    from friendships f
    where p_user_id in (f.user_low, f.user_high)
  )
  select jsonb_build_object(
    'friends', coalesce((
      select jsonb_agg(_player_card(p_user_id, u) order by (u.last_seen_at > now() - interval '10 minutes') desc nulls last,
                                                              u.mmr desc)
      from iliski i join users u on u.id = i.other where i.status = 'accepted'), '[]'::jsonb),
    'incoming', coalesce((
      select jsonb_agg(_player_card(p_user_id, u) order by i.created_at desc)
      from iliski i join users u on u.id = i.other
      where i.status = 'pending' and i.requested_by <> p_user_id), '[]'::jsonb),
    'outgoing', coalesce((
      select jsonb_agg(_player_card(p_user_id, u) order by i.created_at desc)
      from iliski i join users u on u.id = i.other
      where i.status = 'pending' and i.requested_by = p_user_id), '[]'::jsonb));
$$;

-- Ad ile oyuncu ara (baştan eşleşme, en fazla 20). Botlar ve banlılar
-- aramada çıkmaz (sıralamada da yoklar).
create or replace function search_players(p_user_id uuid, p_query text) returns jsonb
language sql stable as $$
  select coalesce(jsonb_agg(_player_card(p_user_id, u) order by length(u.username), u.username), '[]'::jsonb)
  from (
    select x.id from users x
    where char_length(trim(p_query)) >= 2
      and x.username ilike replace(replace(replace(trim(p_query), '\', '\\'), '%', '\%'), '_', '\_') || '%'
      and x.id <> p_user_id and not x.is_bot and not x.is_banned
    order by length(x.username), x.username
    limit 20
  ) s
  join users u on u.id = s.id;
$$;

-- ---------------------------------------------------------------------
-- 3) AÇIK PROFİL
-- ---------------------------------------------------------------------
create or replace function public_profile(p_viewer uuid, p_target uuid) returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'id', u.id,
    'username', u.username,
    'avatar_url', u.avatar_url,
    'mmr', u.mmr,
    'wins', u.wins, 'losses', u.losses, 'draws', u.draws,
    'rank', get_player_rank(u.id),
    'joined_at', u.created_at,
    'online', coalesce(u.last_seen_at > now() - interval '10 minutes', false),
    'last_seen_at', u.last_seen_at,
    'friend_status', _friend_status(p_viewer, u.id),
    'friend_count', (select count(*) from friendships f where f.status = 'accepted' and u.id in (f.user_low, f.user_high)),
    'collection_count', (select count(distinct uc.card_id) from user_cards uc where uc.owner_id = u.id),
    'equipped', coalesce((select jsonb_object_agg(slot, item_slug) from user_equipped e
                          where e.user_id = u.id and e.slot in ('frame', 'badge')), '{}'::jsonb),
    'top_cards', coalesce((
      select jsonb_agg(jsonb_build_object('card_id', t.id, 'full_name', t.full_name, 'position', t.position,
                                          'tier', t.tier, 'power', t.power) order by t.rnk, t.power desc)
      from (
        select * from (
          select distinct on (c.id) c.id, c.full_name, c.position, c.tier, c.power,
                 case c.tier when 'legend' then 1 when 'diamond' then 2 when 'gold' then 3
                             when 'silver' then 4 else 5 end as rnk
          from user_cards uc join cards c on c.id = uc.card_id
          where uc.owner_id = u.id
          order by c.id
        ) d
        order by d.rnk, d.power desc
        limit 3
      ) t
    ), '[]'::jsonb),
    -- Son 5 dereceli maçın sonucu (rakip adı yok)
    'recent_form', coalesce((
      select jsonb_agg(h.outcome order by h.finished_at desc)
      from (select outcome, finished_at from get_match_history(u.id, 5, 0)) h
    ), '[]'::jsonb),
    -- Aranızdaki dereceli maçlar
    'head_to_head', (
      select jsonb_build_object(
        'matches', count(*),
        'my_wins', count(*) filter (where m.winner_id = p_viewer),
        'their_wins', count(*) filter (where m.winner_id = u.id),
        'draws', count(*) filter (where m.is_draw))
      from matches m
      where m.status = 'finished' and m.mode = 'ranked' and p_viewer <> u.id
        and ((m.player1_id = p_viewer and m.player2_id = u.id) or (m.player1_id = u.id and m.player2_id = p_viewer))))
  from users u
  where u.id = p_target and not u.is_banned;
$$;

-- ---------------------------------------------------------------------
-- 4) RAKİP KADROSU (bitmiş maç)
-- ---------------------------------------------------------------------
create or replace function match_opponent_squad(p_user_id uuid, p_match_id uuid) returns jsonb
language plpgsql stable as $$
declare
  m        matches%rowtype;
  v_rakip  uuid;
begin
  select * into m from matches where id = p_match_id;
  if not found or p_user_id not in (m.player1_id, m.player2_id) then
    raise exception 'match_not_found: Mac bulunamadi.';
  end if;
  if m.status <> 'finished' then
    raise exception 'match_not_finished: Rakibin kadrosu mac bitince gorunur.';
  end if;
  v_rakip := case when m.player1_id = p_user_id then m.player2_id else m.player1_id end;
  return jsonb_build_object(
    'match_id', m.id,
    'opponent', (select jsonb_build_object('id', u.id, 'username', u.username, 'mmr', u.mmr)
                 from users u where u.id = v_rakip),
    'outcome', case when m.is_draw then 'draw' when m.winner_id = p_user_id then 'win' else 'loss' end,
    'finished_at', m.finished_at,
    'cards', coalesce((
      select jsonb_agg(jsonb_build_object(
               'card_id', h.card_id, 'full_name', c.full_name, 'position', h.position,
               'tier', h.tier, 'power', h.power, 'played', h.is_played)
             order by case h.position when 'GK' then 1 when 'DEF' then 2 when 'MID' then 3 else 4 end,
                      h.power desc)
      from match_hands h join cards c on c.id = h.card_id
      where h.match_id = m.id and h.user_id = v_rakip), '[]'::jsonb));
end;
$$;
