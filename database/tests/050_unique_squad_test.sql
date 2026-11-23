-- 050-053 testleri: islem sonunda geri alinir, hicbir veri kalici degismez.
begin;
do $$
declare
  u uuid; d uuid; i int; uc_a uuid; uc_b uuid; ch uuid; r jsonb; x jsonb;
  v_once uuid[]; v_dl timestamptz;
begin
  -- 050: baslangic paketi ayni futbolcuyu iki kez vermez, kadro gecerli
  for i in 1..20 loop
    insert into users (email, password_hash, username)
    values ('t050_' || i || '@test.local', 'x', 't050_' || i) returning id into u;
    perform grant_starter_pack(u);
    if (select count(*) - count(distinct card_id) from user_cards where owner_id = u) <> 0 then
      raise exception 'TEST BASARISIZ: 050 baslangic paketinde kopya futbolcu var';
    end if;
    select id into d from decks where owner_id = u and is_active;
    if validate_deck(u, d) is not null then
      raise exception 'TEST BASARISIZ: 050 baslangic kadrosu gecersiz: %', validate_deck(u, d);
    end if;
  end loop;

  -- 050: ayni futbolcunun iki kopyasi kadroda olamaz
  select dc.user_card_id into uc_a from deck_cards dc where dc.deck_id = d and dc.slot_index = 5;
  insert into user_cards (owner_id, card_id)
  select u, card_id from user_cards where id = uc_a returning id into uc_b;
  update deck_cards set user_card_id = uc_b where deck_id = d and slot_index = 6;
  update deck_cards set user_card_id = uc_a where deck_id = d and slot_index = 5;
  if coalesce(validate_deck(u, d), '') not like 'Bir futbolcu kadroda%' then
    raise exception 'TEST BASARISIZ: 050 tekrarli kadro reddedilmedi: %', validate_deck(u, d);
  end if;

  -- 050: _pick_unowned_card sahip olunmayan futbolcu verir
  for i in 1..30 loop
    if exists (select 1 from user_cards where owner_id = u
               and card_id = _pick_unowned_card(u, 'bronze', 'MID')) then
      raise exception 'TEST BASARISIZ: 050 _pick_unowned_card sahip olunan futbolcu verdi';
    end if;
  end loop;

  -- 052: sandik kadro korumasi sahip olunan futbolcuyu vermez
  for i in 1..15 loop
    delete from user_cards where id in (
      select uc.id from user_cards uc join cards c on c.id = uc.card_id
      where uc.owner_id = u and c.position in ('MID', 'DEF') order by random() limit 2);
    v_once := array(select card_id from user_cards where owner_id = u);
    ch := _grant_chest(u, 'bronze', 'test', 't050_' || i);
    update user_chests set status = 'ready', location = 'slot', slot_no = 1 where id = ch;
    r := open_chest(u, ch);
    for x in select * from jsonb_array_elements(r -> 'cards') loop
      if x ->> 'outcome' = 'squad_guard' and (x ->> 'card_id')::uuid = any (v_once) then
        raise exception 'TEST BASARISIZ: 052 kadro korumasi sahip olunan futbolcuyu verdi';
      end if;
    end loop;
    update user_chests set location = 'mailbox', slot_no = null where id = ch;
  end loop;

  -- 053: 20 sn sessiz kuyruk kaydi bayat sayilir
  delete from matchmaking_queue;
  insert into matchmaking_queue (user_id, deck_id, protected_card_ids, mmr, status, created_at, updated_at)
  select id, (select id from decks where owner_id = users.id and is_active), '{}', mmr, 'searching',
         now() - interval '40 seconds', now() - interval '25 seconds'
  from users where username = 't050_1';
  select u2.id, d2.id into u, d from users u2 join decks d2 on d2.owner_id = u2.id and d2.is_active
  where u2.username = 't050_2';
  perform find_match(u, d);
  if exists (select 1 from matchmaking_queue q join users x on x.id = q.user_id where x.username = 't050_1') then
    raise exception 'TEST BASARISIZ: 053 20 sn sessiz kayit silinmedi';
  end if;
  if get_active_match_id(u) is not null then
    raise exception 'TEST BASARISIZ: 053 bayat kayitla eslesildi';
  end if;
  delete from matchmaking_queue;

  -- 051: tur sonrasi mevki son ani = mevki suresi + sahne payi
  if clash_scene_seconds() <> 3 then
    raise exception 'TEST BASARISIZ: 051 sahne payi 3 sn olmali';
  end if;

  raise notice '050-053 testleri gecti';
end $$;
rollback;
