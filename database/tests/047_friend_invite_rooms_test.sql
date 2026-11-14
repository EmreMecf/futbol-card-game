-- 047 friend room integration tests. Runs in an isolated transaction, never persists.
begin;
do $$
declare
  a uuid; b uuid; da uuid; dbb uuid; code text; j json;
  match_id uuid; before_wins int; before_mmr int; before_coins bigint;
  old_mode text;
begin
  select u.id,d.id into a,da from users u
  join decks d on d.owner_id=u.id and d.is_active
  where get_active_match_id(u.id) is null and validate_deck(u.id,d.id) is null
  order by u.created_at limit 1;
  select u.id,d.id into b,dbb from users u
  join decks d on d.owner_id=u.id and d.is_active
  where u.id<>a and get_active_match_id(u.id) is null
    and validate_deck(u.id,d.id) is null
  order by u.created_at limit 1;
  if a is null or b is null then raise exception '047 needs two valid players'; end if;
  delete from matchmaking_queue;
  select wins,mmr,coins into before_wins,before_mmr,before_coins from users where id=a;
  j:=friend_room_create(a);
  code:=j->>'code';
  if j->>'status'<>'waiting' or length(code)<>30 then
    raise exception 'room create failed: %',j;
  end if;
  if (friend_room_create(a)->>'code')<>code then raise exception 'create must be idempotent'; end if;
  if (friend_room_info(b,code)->>'status')<>'not_member' then
    raise exception 'nonmember must not inspect lobby';
  end if;
  begin
    perform friend_room_join(a,code);
  exception when others then
    raise exception 'host should be able to reopen own invite';
  end;
  j:=friend_room_join(b,code);
  if j->>'status'<>'waiting' or j->>'guest_name' is null then
    raise exception 'guest join failed: %',j;
  end if;
  j:=friend_room_ready(a,code,da);
  if j->>'status'<>'waiting' or j->>'host_ready'<>'true' then
    raise exception 'host ready must wait for guest: %',j;
  end if;
  j:=friend_room_ready(b,code,dbb);
  if j->>'status'<>'started' or j->>'match_id' is null then
    raise exception 'both ready must start: %',j;
  end if;
  match_id:=(j->>'match_id')::uuid;
  if (select count(*) from matches where id=match_id and mode='friendly' and status='active')<>1 then
    raise exception 'private match must have friendly mode';
  end if;
  if (friend_room_ready(a,code,da)->>'match_id')<>match_id::text then
    raise exception 'repeat ready must return same match';
  end if;
  perform _finish_match(match_id,a);
  if (select wins from users where id=a)<>before_wins or
     (select mmr from users where id=a)<>before_mmr or
     (select coins from users where id=a)<>before_coins then
    raise exception 'friendly match must have no ranked rewards/score';
  end if;
  if exists(select 1 from user_cards where locked_match_id=match_id) then
    raise exception 'friendly completion must release card locks';
  end if;
  raise notice '047 private friend room and friendly reward-isolation tests pass';
end $$;
rollback;
