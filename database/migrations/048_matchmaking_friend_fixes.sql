-- 048: EŞLEŞTİRME MODU ve ARKADAŞ ODASI DÜZELTMELERİ
--
-- 1) matchmaking_mode(): kural sürümü 5'te (seviye gücü) ayar yok sayılıp hep
--    'combined' dönüyordu; 046'nın 'adaptive' modu V3 açıkken hiç çalışmıyordu.
--    Artık 'adaptive' AÇIKÇA seçildiyse o kullanılır. Varsayılan ayar 'mmr'
--    olduğu için bu migration tek başına hiçbir oyuncunun eşleşmesini değiştirmez:
--    sürüm 5'te yine 'combined', önceki sürümlerde yine ayardaki mod geçerlidir.
--    Açmak: update matchmaking_settings set mode='adaptive' where id=1;
--    Geri almak: update matchmaking_settings set mode='mmr' where id=1;
--
-- 2) friend_room_ready: kadro bozulunca atılan hata, hazır bayrağını sıfırlayan
--    güncellemeyi de geri alıyordu. Bayrak artık sıfırlanır, mesaj 'notice' ile döner.
--
-- 3) Arkadaş odası hata mesajları Türkçe karakterli oldu.
--
-- 046 ve 047 DEĞİŞTİRİLMEDİ: staging kurulumu uygulanmış dosyanın parmak izini denetler.
-- Maç, kart, altın, puan ve kullanıcı verisine dokunulmaz.

create or replace function matchmaking_mode() returns text
language sql stable as $$
  select case
    when (select mode from matchmaking_settings where id = 1) = 'adaptive' then 'adaptive'   -- 048
    when rules_level_power(current_rules_version()) then 'combined'                          -- 040
    else coalesce((select mode from matchmaking_settings where id = 1), 'mmr')
  end
$$;

create or replace function friend_room_create(p_actor uuid)
returns json language plpgsql as $$
declare
  r friend_rooms%rowtype;
begin
  perform pg_advisory_xact_lock(hashtext('futbol_card_matchmaking'));
  if not exists (select 1 from users where id=p_actor and not is_banned) then
    raise exception 'Oyuncu bulunamadı veya engellendi.';
  end if;
  if get_active_match_id(p_actor) is not null then
    raise exception 'Devam eden maçın var. Önce onu tamamla.';
  end if;
  -- Hesap başına tek açık davet: tekrar istek aynı kodu döner
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
  if not found then raise exception 'Davet bulunamadı.'; end if;
  if r.status<>'waiting' or r.expires_at<=now() then raise exception 'Davetin süresi doldu veya maç başladı.'; end if;
  if r.host_id=p_actor then return friend_room_info(p_actor,r.invite_code); end if;
  if r.guest_id is not null and r.guest_id<>p_actor then raise exception 'Oda dolu.'; end if;
  if not exists(select 1 from users where id=p_actor and not is_banned) then
    raise exception 'Oyuncu bulunamadı veya engellendi.';
  end if;
  if get_active_match_id(p_actor) is not null then raise exception 'Devam eden maçın var.'; end if;
  if exists (select 1 from friend_rooms where status='waiting' and expires_at>now()
             and host_id<>r.host_id and (host_id=p_actor or guest_id=p_actor)) then
    raise exception 'Başka bir açık odadasın. Önce çık.';
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
    raise exception 'Oda bulunamadı.';
  end if;
  if r.status='started' then return friend_room_info(p_actor,r.invite_code); end if;
  if r.status<>'waiting' or r.expires_at<=now() then raise exception 'Davetin süresi doldu.'; end if;
  if get_active_match_id(p_actor) is not null then raise exception 'Devam eden maçın var.'; end if;
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
    -- 048: kadro bozulduysa hata FIRLATILMAZ (hata, hazır bayrağının sıfırlanmasını da
    -- geri alıyordu); bayrak sıfırlanır ve mesaj 'notice' alanıyla döner.
    v_err:=validate_deck(r.host_id,r.host_deck_id);
    if v_err is not null then
      update friend_rooms set host_ready=false where id=r.id;
      return (friend_room_info(p_actor,r.invite_code)::jsonb
              || jsonb_build_object('notice','Oda sahibinin kadrosu değişti: '||v_err))::json;
    end if;
    v_err:=validate_deck(r.guest_id,r.guest_deck_id);
    if v_err is not null then
      update friend_rooms set guest_ready=false where id=r.id;
      return (friend_room_info(p_actor,r.invite_code)::jsonb
              || jsonb_build_object('notice','Konuğun kadrosu değişti: '||v_err))::json;
    end if;
    if get_active_match_id(r.host_id) is not null or get_active_match_id(r.guest_id) is not null then
      raise exception 'Oyunculardan biri başka maçta.';
    end if;
    -- İki oyuncu dereceli kuyruktan çıkar: aynı anda iki maça giremesinler
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
    raise exception 'Bu odanın üyesi değilsin.';
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
