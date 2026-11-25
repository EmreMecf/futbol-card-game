-- =====================================================================
-- 057 - ARKADAŞ SINIRI KABULDE DE GEÇERLİ, ELMAS DEFTERİ YARIŞA DAYANIKLI,
--       PROFİL VE RAKİP KADROSUNDA KART KİMLİĞİ (slug)
-- =====================================================================
-- 056'nın kod incelemesinde bulunan sorunlar. 056 değiştirilmez (staging'e
-- uygulanmış olabilir); fonksiyonlar burada yeniden tanımlanır.
--
-- 1) ARKADAŞ SINIRI (100) yalnız yeni istek gönderirken bakılıyordu.
--    100 arkadaşı olan oyuncu bekleyen istekleri kabul ederek (ya da
--    karşılıklı istekle otomatik kabulde) sınırı aşabiliyordu. Artık her
--    kabulde İKİ oyuncu için de bakılır. İki oyuncunun arkadaşlık işlemleri
--    oyuncu başına kilitle sıraya girer (kimlik sırasıyla; kilitlenme
--    olmaz), böylece aynı anda yapılan iki kabul sınırı birlikte aşamaz.
--      friend_limit        : senin listen dolu
--      friend_limit_other  : karşı tarafın listesi dolu
--
-- 2) ELMAS DEFTERİ: _gem_add tekrar anahtarına kilitten ÖNCE bakıyordu.
--    Aynı anahtarla aynı anda gelen iki çağrının ikincisi, birincinin
--    yazdığını görmeden kilidi bekleyip benzersizlik hatasıyla düşüyordu
--    (çift elmas yoktu, ama hata vardı). Artık kilitten SONRA yeniden
--    bakılır: ikinci çağrı ilk sonucu döndürür.
--
-- 3) KART GÖRSELİ futbolcunun adına bağlıydı. Uygulama artık görseli
--    değişmeyen katalog kimliğine (cards.slug) bağlıyor; açık profil ve
--    rakip kadrosu kartlarına slug eklendi.
--
-- KULLANICI VERİSİ: değişmez. Yalnız fonksiyonlar yeniden tanımlanır.
-- Tekrar çalıştırılabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) ARKADAŞ SINIRI
-- ---------------------------------------------------------------------
create or replace function _friend_limit() returns int
language sql immutable as $$ select 100 $$;

create or replace function _friend_count(p_user_id uuid) returns int
language sql stable as $$
  select count(*)::int from friendships
  where status = 'accepted' and p_user_id in (user_low, user_high);
$$;

-- İki oyuncunun arkadaşlık işlemlerini sıraya sokar. Kilitler her zaman
-- küçük kimlikten büyüğe alınır: iki işlem birbirini beklemez (deadlock yok).
create or replace function _friend_lock_users(p_a uuid, p_b uuid) returns void
language plpgsql as $$
begin
  perform pg_advisory_xact_lock(hashtext('friends_user:' || least(p_a, p_b)::text));
  perform pg_advisory_xact_lock(hashtext('friends_user:' || greatest(p_a, p_b)::text));
end;
$$;

-- Kabul öncesi iki taraf için sınır denetimi (kilitler alınmış olmalı)
create or replace function _friend_check_accept(p_me uuid, p_other uuid) returns void
language plpgsql as $$
begin
  if _friend_count(p_me) >= _friend_limit() then
    raise exception 'friend_limit: En fazla % arkadas olabilir.', _friend_limit();
  end if;
  if _friend_count(p_other) >= _friend_limit() then
    raise exception 'friend_limit_other: Bu oyuncunun arkadas listesi dolu.';
  end if;
end;
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
  perform _friend_lock_users(p_user_id, p_target);
  perform pg_advisory_xact_lock(hashtext('friends:' || v_low || ':' || v_high));
  select * into f from friendships where user_low = v_low and user_high = v_high for update;
  if found then
    if f.status = 'pending' and f.requested_by = p_target then
      -- Karşı taraf zaten istemişti: kabul sayılır, sınır iki taraf için denetlenir
      perform _friend_check_accept(p_user_id, p_target);
      update friendships set status = 'accepted', accepted_at = now()
      where user_low = v_low and user_high = v_high;
    end if;
    return jsonb_build_object('friend_status', _friend_status(p_user_id, p_target));
  end if;
  if _friend_count(p_user_id) >= _friend_limit() then
    raise exception 'friend_limit: En fazla % arkadas olabilir.', _friend_limit();
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
  perform _friend_lock_users(p_user_id, p_other);
  perform pg_advisory_xact_lock(hashtext('friends:' || least(p_user_id, p_other) || ':' || greatest(p_user_id, p_other)));
  select * into f from friendships
  where user_low = least(p_user_id, p_other) and user_high = greatest(p_user_id, p_other) for update;
  if not found or f.status <> 'pending' or f.requested_by = p_user_id then
    raise exception 'friend_request_not_found: Bekleyen istek bulunamadi.';
  end if;
  if p_accept then
    perform _friend_check_accept(p_user_id, p_other);
    update friendships set status = 'accepted', accepted_at = now()
    where user_low = f.user_low and user_high = f.user_high;
  else
    delete from friendships where user_low = f.user_low and user_high = f.user_high;
  end if;
  return jsonb_build_object('friend_status', _friend_status(p_user_id, p_other));
end;
$$;

-- ---------------------------------------------------------------------
-- 2) ELMAS DEFTERİ: kilitten sonra yeniden bak
-- ---------------------------------------------------------------------
create or replace function _gem_add(p_user_id uuid, p_delta int, p_reason text, p_source text, p_key text)
returns int
language plpgsql as $$
declare
  v_gems int;
  v_eski gem_ledger%rowtype;
begin
  -- Hızlı yol: anahtar zaten işlenmişse kilit almadan ilk sonucu döndür
  select * into v_eski from gem_ledger where idempotency_key = p_key;
  if found then
    return v_eski.gems_after;
  end if;
  select gems into v_gems from users where id = p_user_id for update;
  if not found then
    raise exception 'user_not_found: Oyuncu bulunamadi.';
  end if;
  -- Kilidi beklerken aynı anahtarla başka bir işlem bitmiş olabilir:
  -- READ COMMITTED'da bu sorgu yeni anlık görüntüyle onu görür.
  select * into v_eski from gem_ledger where idempotency_key = p_key;
  if found then
    return v_eski.gems_after;
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

-- ---------------------------------------------------------------------
-- 3) KART KİMLİĞİ (slug): açık profil ve rakip kadrosu
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
      select jsonb_agg(jsonb_build_object('card_id', t.id, 'slug', t.slug, 'full_name', t.full_name,
                                          'position', t.position, 'tier', t.tier, 'power', t.power)
                       order by t.rnk, t.power desc)
      from (
        select * from (
          select distinct on (c.id) c.id, c.slug, c.full_name, c.position, c.tier, c.power,
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
               'card_id', h.card_id, 'slug', c.slug, 'full_name', c.full_name, 'position', h.position,
               'tier', h.tier, 'power', h.power, 'played', h.is_played)
             order by case h.position when 'GK' then 1 when 'DEF' then 2 when 'MID' then 3 else 4 end,
                      h.power desc)
      from match_hands h join cards c on c.id = h.card_id
      where h.match_id = m.id and h.user_id = v_rakip), '[]'::jsonb));
end;
$$;
