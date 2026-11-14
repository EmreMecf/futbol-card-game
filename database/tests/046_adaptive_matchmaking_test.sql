-- 046 acceptance checks; transaction fully rolled back (no player data changes).
begin;
do $$
declare
  a uuid; da uuid; bb uuid; dbb uuid;
  v json;
begin
  select u.id, d.id into a, da
  from users u join decks d on d.owner_id=u.id and d.is_active
  where get_active_match_id(u.id) is null and validate_deck(u.id,d.id) is null
  order by u.created_at limit 1;
  select u.id, d.id into bb, dbb
  from users u join decks d on d.owner_id=u.id and d.is_active
  where u.id <> a and get_active_match_id(u.id) is null
    and validate_deck(u.id,d.id) is null
  order by u.created_at limit 1;
  if a is null or bb is null then raise exception 'Need two valid players'; end if;
  if matchmaking_mode() <> 'mmr' then
    raise exception 'Migration must leave existing default mmr mode unchanged';
  end if;
  update matchmaking_settings set mode='adaptive' where id=1;
  delete from matchmaking_queue;
  update users set mmr=1000 where id=a;
  update users set mmr=1000 where id=bb;
  v := find_match(a,da);
  if v->>'status'<>'queued' then raise exception 'First new player must queue'; end if;
  v := find_match(bb,dbb);
  if v->>'status'<>'matched' then raise exception 'Two same-MMR new players must instantly match, got %',v; end if;
  if (select count(*) from matches where id=(v->>'match_id')::uuid
      and status='active' and player1_id<>player2_id)<>1 then
    raise exception 'A real active match must be created'; end if;
  if (find_match(a,da)->>'status') <> 'in_match' then
    raise exception 'Repeat matchmaking must recover active match'; end if;
  -- Cleanup only test transaction state, then retry wide skill disparity.
  update user_cards set locked_match_id=null where locked_match_id=(v->>'match_id')::uuid;
  update matches set status='cancelled' where id=(v->>'match_id')::uuid;
  delete from matchmaking_queue;
  update users set mmr=1750 where id=bb;
  v := find_match(a,da);
  if v->>'status'<>'queued' then raise exception 'Player A should queue'; end if;
  v := find_match(bb,dbb);
  if v->>'status'<>'queued' then raise exception 'Large gap should not instantly match'; end if;
  update matchmaking_queue set created_at=now()-interval '20 seconds', updated_at=now() where user_id=a;
  v := find_match(bb,dbb);
  if v->>'status'<>'matched' then
    raise exception 'Low population must widen MMR gap by 20s; got %',v;
  end if;
  raise notice '046 adaptive matchmaking: newborn pair, wide gap and idempotent rematch pass';
end $$;
rollback;
