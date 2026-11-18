-- 048 testleri: işlem sonunda geri alınır, hiçbir veri kalıcı değişmez.
begin;
do $$
declare
  a uuid; b uuid; da uuid; dbb uuid; kod text; j json; kart uuid;
begin
  select u.id,d.id into a,da from users u join decks d on d.owner_id=u.id and d.is_active
  where get_active_match_id(u.id) is null and validate_deck(u.id,d.id) is null order by u.created_at limit 1;
  select u.id,d.id into b,dbb from users u join decks d on d.owner_id=u.id and d.is_active
  where u.id<>a and get_active_match_id(u.id) is null and validate_deck(u.id,d.id) is null order by u.created_at limit 1;
  if a is null or b is null then raise exception '048: iki geçerli oyuncu gerekli'; end if;

  -- Varsayılan ayarda davranış aynı kalır
  if matchmaking_mode() <> 'mmr' then raise exception '048: varsayılan mod mmr kalmalı'; end if;

  -- Kural sürümü 5
  insert into economy_config_versions(kind,version,payload,note)
  select 'feature_flags',max(version)+1,
         (select payload from economy_config_versions where kind='feature_flags' order by version desc limit 1)
         || '{"economy_v2_enabled":true,"ranked_rewards_v2":true,"duel_v4":true,"card_level_power":true}'::jsonb,'048 testi'
  from economy_config_versions where kind='feature_flags';
  if current_rules_version() <> 5 then raise exception '048: sürüm 5 bekleniyordu'; end if;
  if matchmaking_mode() <> 'combined' then raise exception '048: sürüm 5 varsayılanı combined kalmalı'; end if;

  update matchmaking_settings set mode='adaptive' where id=1;
  if matchmaking_mode() <> 'adaptive' then raise exception '048: adaptive sürüm 5te de geçerli olmalı'; end if;

  -- Büyük puan farkı + 35 sn: adaptive eşleştirir
  delete from matchmaking_queue;
  update users set mmr=1000 where id=a;
  update users set mmr=1900 where id=b;
  perform find_match(a,da);
  update matchmaking_queue set created_at=now()-interval '35 seconds', updated_at=now() where user_id=a;
  j := find_match(b,dbb);
  if j->>'status' <> 'matched' then raise exception '048: adaptive eşleştirmedi: %',j; end if;
  update user_cards set locked_match_id=null where locked_match_id=(j->>'match_id')::uuid;
  update matches set status='cancelled' where id=(j->>'match_id')::uuid;
  delete from matchmaking_queue;

  -- Kadro bozulunca hazır bayrağı sıfırlanır, hata fırlatılmaz
  kod := friend_room_create(a)->>'code';
  perform friend_room_join(b,kod);
  perform friend_room_ready(a,kod,da);
  select user_card_id into kart from deck_cards where deck_id=da limit 1;
  delete from deck_cards where deck_id=da and user_card_id=kart;
  j := friend_room_ready(b,kod,dbb);
  if j->>'status' <> 'waiting' or j->>'notice' is null then raise exception '048: notice bekleniyordu: %',j; end if;
  if (select host_ready from friend_rooms where invite_code=kod) then raise exception '048: host_ready sıfırlanmalı'; end if;
  raise notice '048 testleri geçti';
end $$;
rollback;
