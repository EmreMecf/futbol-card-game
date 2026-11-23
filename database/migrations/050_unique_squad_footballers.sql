-- =====================================================================
-- 050: BIR FUTBOLCU KADRODA YALNIZ BIR KEZ
-- =====================================================================
-- Kural: ayni futbolcunun (cards.id) iki kopyasi ayni kadroda olamaz.
-- Istemci bunu zaten uyguluyor; bu migration sunucuyu ve veriyi uyumlu
-- hale getirir:
--
--   1. Baslangic paketi ayni futbolcuyu iki kez vermez. Eskiden rastgele
--      cekim yuzunden yeni oyuncunun elinde ornegin 3 farkli orta saha
--      kaliyor, 4 orta saha yerli kadroyu hic kuramiyordu.
--   2. Kadro korumasi (044) eksik mevki icin ayni futbolcunun ikinci
--      fiziksel kopyasini degil, sahip olunmayan bir futbolcuyu verir.
--      Eksik mevki hesabi farkli futbolcu sayisina bakar.
--   3. Baslangic kadrosu yalniz farkli futbolculardan kurulur.
--   4. validate_deck ayni futbolcuyu iki kez iceren kadroyu reddeder.
--   5. BIR KERELIK ONARIM (yalniz gercek oyuncular, botlar haric):
--      a. Bir mevkide kadroya yetecek kadar farkli futbolcusu olmayan
--         oyuncunun, macta hic kullanilmamis fazla kopyasi ayni sinif ve
--         mevkiden sahip olmadigi bir futbolcuya cevrilir. Cevrilecek kopya
--         yoksa o mevkiden bronz bir futbolcu verilir.
--      b. Kadrolarda kalan tekrarlar, oyuncunun bos duran en guclu uygun
--         kartiyla degistirilir; uygun kart yoksa o yer bosaltilir (oyuncu
--         kadro ekraninda doldurur).
--
-- Bot kadrolari (_bot_build_deck2) validate_deck'ten gecmez; dokunulmadi.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Oyuncunun sahip olmadigi, verilen mevkide bir futbolcu. Once ayni sinif,
-- sonra en yakin alt sinif, en son ust sinif denenir. Yoksa null.
-- ---------------------------------------------------------------------
create or replace function _pick_unowned_card(p_user_id uuid, p_tier card_tier, p_position card_position)
returns uuid
language sql
volatile
as $$
  select c.id
  from cards c
  where c.is_active
    and c.position = p_position
    and not exists (select 1 from user_cards uc where uc.owner_id = p_user_id and uc.card_id = c.id)
  order by abs(tier_rank(c.tier) - tier_rank(p_tier)),
           tier_rank(c.tier) > tier_rank(p_tier),
           -ln(random()) / greatest(c.drop_weight, 1)
  limit 1
$$;

-- ---------------------------------------------------------------------
-- 2. Eksik mevki: farkli futbolcu sayisi (kopyalar kadroda ise yaramaz)
-- ---------------------------------------------------------------------
create or replace function _squad_missing_positions(p_user_id uuid)
returns card_position[]
language sql
stable
as $$
  with ihtiyac as (
    select key::card_position as pos,
           value::int + coalesce((_chest_rules() ->> 'squad_spare')::int, 1) as gerek
    from jsonb_each_text(_chest_rules() -> 'squad_need')
  ), sahip as (
    select c.position as pos, count(distinct uc.card_id) as n   -- 050
    from user_cards uc join cards c on c.id = uc.card_id
    where uc.owner_id = p_user_id
    group by c.position
  )
  select coalesce(array_agg(i.pos order by i.pos), '{}')
  from ihtiyac i left join sahip s on s.pos = i.pos
  where coalesce(s.n, 0) < i.gerek
$$;

-- ---------------------------------------------------------------------
-- 1 ve 2. Paket acma (044 surumu + iki 050 degisikligi)
-- ---------------------------------------------------------------------
create or replace function open_pack(p_user_id uuid, p_pack_slug text, p_free boolean DEFAULT false)
 RETURNS json
 LANGUAGE plpgsql
AS $$
declare
  v_pack       pack_types%rowtype;
  v_coins      int;
  v_pozisyonlar card_position[];
  v_pozisyon   card_position;
  v_tier       card_tier;
  v_card_id    uuid;
  v_user_card  uuid;
  v_kart_idler uuid[] := '{}';
  v_seviyeler  text[] := '{}';
  v_i          int;
  v_ucret      int;
  v_sonuc      text;                                  -- 044
  v_kart_row   cards%rowtype;                         -- 044
  v_ilerleme   jsonb := '[]'::jsonb;                  -- 044: kopya / joker olanlar
  v_tasma      jsonb := '{}'::jsonb;                  -- 044
  v_yeni_kural boolean := economy_flag('pack_duplicates_v2') and p_pack_slug <> 'starter';  -- 044
  j            record;                                -- 044
begin
  -- ---- PAKETI BUL ----
  select * into v_pack from pack_types
  where slug = p_pack_slug and is_active;

  if not found then
    raise exception 'Boyle bir paket yok: %', p_pack_slug;
  end if;

  if not v_pack.is_purchasable and not p_free then
    raise exception 'Bu paket magazadan satin alinamaz.';
  end if;

  -- ---- KULLANICIYI KILITLE (coin dusumu icin) ----
  select coins into v_coins from users where id = p_user_id for update;

  if not found then
    raise exception 'Kullanici bulunamadi.';
  end if;

  v_ucret := case when p_free then 0 else v_pack.price_coins end;

  if v_coins < v_ucret then
    raise exception 'Yeterli coin yok. Gerekli: %, mevcut: %', v_ucret, v_coins;
  end if;

  -- ---- POZISYONLARI BELIRLE ----
  v_pozisyonlar := _build_position_list(v_pack.position_quota, v_pack.card_count);

  -- ---- KARTLARI CEK ----
  for v_i in 1..v_pack.card_count loop
    v_pozisyon := v_pozisyonlar[v_i];
    v_tier := _roll_tier(v_pack.tier_weights, v_pack.max_tier);
    v_card_id := _pick_card(v_tier, v_pozisyon);

    -- 050: baslangic paketinde ayni futbolcu iki kez gelmez; kadro
    -- yalniz farkli futbolculardan kurulabildigi icin kopya ise yaramaz
    if p_pack_slug = 'starter' then
      v_card_id := coalesce(_pick_unowned_card(p_user_id, v_tier, v_pozisyon), v_card_id);
    end if;

    -- 044: SANDIK KURALI (anahtar 'pack_duplicates_v2'): sahip olunan
    -- futbolcu fiziksel kopya yerine gelisim kopyasi; seviye 10 ise joker;
    -- kadroda o mevki eksikse fiziksel kart (kadro korumasi).
    v_sonuc := 'new';
    if v_yeni_kural and exists (select 1 from user_cards where owner_id = p_user_id and card_id = v_card_id) then
      select * into v_kart_row from cards where id = v_card_id;
      if v_kart_row.position = any (_squad_missing_positions(p_user_id)) then
        v_sonuc := 'squad_guard';
        -- 050: kadro korumasi ayni futbolcunun ikinci kopyasini degil,
        -- ayni mevki ve siniftan sahip olunmayan bir futbolcuyu verir
        v_card_id := coalesce(_pick_unowned_card(p_user_id, v_kart_row.tier, v_kart_row.position), v_card_id);
      elsif coalesce((select level from player_progress where user_id = p_user_id and card_id = v_card_id), 1)
            >= coalesce((_level_rules() ->> 'max_level')::int, 10) then
        v_sonuc := 'joker';
      else
        v_sonuc := 'copy';
      end if;
    end if;

    if v_sonuc in ('new', 'squad_guard') then
      insert into user_cards (owner_id, card_id)
      values (p_user_id, v_card_id)
      returning id into v_user_card;

      v_kart_idler := v_kart_idler || v_user_card;
      if v_yeni_kural then
        insert into player_progress (user_id, card_id) values (p_user_id, v_card_id) on conflict do nothing;
      end if;
    elsif v_sonuc = 'copy' then
      insert into player_progress (user_id, card_id, copies) values (p_user_id, v_card_id, 1)
      on conflict (user_id, card_id) do update
        set copies = player_progress.copies + 1, updated_at = now();
    else
      v_tasma := jsonb_set(v_tasma, array[v_kart_row.tier::text],
                   to_jsonb(coalesce((v_tasma ->> v_kart_row.tier::text)::int, 0)
                            + coalesce((_level_rules() -> 'overflow_jokers' ->> v_kart_row.tier::text)::int, 1)));
    end if;
    if v_sonuc in ('copy', 'joker') then
      v_ilerleme := v_ilerleme || jsonb_build_object(
        'card_id', v_kart_row.id, 'slug', v_kart_row.slug, 'full_name', v_kart_row.full_name,
        'position', v_kart_row.position, 'tier', v_kart_row.tier, 'power', v_kart_row.power,
        'club', v_kart_row.club, 'nationality', v_kart_row.nationality,
        'image_url', v_kart_row.image_url, 'outcome', v_sonuc);
    end if;
    -- Gercekte hangi seviye verildi? (_pick_card alt seviyeye inmis olabilir)
    v_seviyeler := v_seviyeler || (select tier::text from cards where id = v_card_id);
  end loop;

  -- 044: seviye 10 tasmasi joker parca olarak
  for j in select key, value::int as n from jsonb_each_text(v_tasma) loop
    perform _item_add(p_user_id, 'joker_' || j.key, j.n, 'pack');
  end loop;

  -- ---- COIN DUS ----
  if v_ucret > 0 then
    update users set coins = coins - v_ucret where id = p_user_id
    returning coins into v_coins;
  end if;

  -- ---- DENETIM KAYDI ----
  insert into pack_openings (user_id, pack_slug, card_ids, tiers, coins_spent)
  values (p_user_id, p_pack_slug, v_kart_idler, v_seviyeler, v_ucret);

  -- ---- SONUCU DON ----
  return json_build_object(
    'pack', json_build_object(
      'slug', v_pack.slug,
      'name', v_pack.name,
      'card_count', v_pack.card_count
    ),
    'coins_spent', v_ucret,
    'coins_left', v_coins,
    -- 044: fiziksel kart yerine gelisim kopyasi / joker olanlar
    'progress', v_ilerleme,
    'cards', (
      select coalesce(json_agg(
        json_build_object(
          'user_card_id', uc.id,
          'card_id', c.id,
          'slug', c.slug,
          'full_name', c.full_name,
          'position', c.position,
          'tier', c.tier,
          'power', c.power,
          'nationality', c.nationality,
          -- 'league' eksikti: paketten cikan kart koleksiyona duserken
          -- ligi bos geliyor, kimya onizlemesi yanlis hesapliyordu.
          'league', c.league,
          'club', c.club,
          'attributes', card_attributes_json(
            c.shooting, c.pace, c.physical,
            c.defending, c.dribbling, c.acceleration
          ),
          'image_url', c.image_url
        ) order by tier_rank(c.tier) desc, c.power desc
      ), '[]'::json)
      from user_cards uc
      join cards c on c.id = uc.card_id
      where uc.id = any (v_kart_idler)
    )
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Baslangic kadrosu: her futbolcunun tek kopyasi
-- ---------------------------------------------------------------------
create or replace function grant_starter_pack(p_user_id uuid)
returns json
language plpgsql
as $$
declare
  v_deck_id uuid;
  v_sonuc   json;
  v_toplam  int;
begin
  if not exists (select 1 from users where id = p_user_id) then
    raise exception 'Kullanici bulunamadi.';
  end if;

  if exists (select 1 from user_cards where owner_id = p_user_id) then
    raise exception 'Baslangic paketi zaten alinmis.';
  end if;

  v_sonuc := open_pack(p_user_id, 'starter', true);

  select count(*) into v_toplam from user_cards where owner_id = p_user_id;

  if v_toplam < squad_size() then
    raise exception 'Katalogda yeterli kart yok. Once seed verisini yukleyin.';
  end if;

  insert into decks (owner_id, name, is_active)
  values (p_user_id, 'Ilk Kadrom', true)
  returning id into v_deck_id;

  -- Formasyona yerlestir: her pozisyonun en guclu FARKLI futbolculari
  -- sirayla 0=GK, 1-4=DEF, 5-8=MID, 9-10=FWD slotlarina.
  insert into deck_cards (deck_id, user_card_id, slot_index)
  select v_deck_id, y.id, y.slot
  from (
    select t.id,
           case t.position
             when 'GK'  then 0
             when 'DEF' then 0 + row_number() over (partition by t.position order by t.power desc)
             when 'MID' then 4 + row_number() over (partition by t.position order by t.power desc)
             when 'FWD' then 8 + row_number() over (partition by t.position order by t.power desc)
           end::int as slot,
           row_number() over (partition by t.position order by t.power desc) as sira,
           t.position
    from (
      -- 050: ayni futbolcunun yalniz bir kopyasi
      select distinct on (uc.card_id) uc.id, c.position, c.power
      from user_cards uc
      join cards c on c.id = uc.card_id
      where uc.owner_id = p_user_id
      order by uc.card_id, uc.acquired_at, uc.id
    ) t
  ) y
  where (y.position = 'GK'  and y.sira <= 1)
     or (y.position = 'DEF' and y.sira <= 4)
     or (y.position = 'MID' and y.sira <= 4)
     or (y.position = 'FWD' and y.sira <= 2);

  return json_build_object(
    'status', 'ok',
    'card_count', v_toplam,
    'deck_id', v_deck_id,
    'cards', v_sonuc -> 'cards'
  );
end;
$$;

-- ---------------------------------------------------------------------
-- 4. Kadro dogrulamasi: ayni futbolcu iki kez olamaz
-- ---------------------------------------------------------------------
create or replace function validate_deck(p_user_id uuid, p_deck_id uuid)
returns text
language plpgsql
stable
as $$
declare
  v_owner uuid;
  v_total int;
  v_not_owned int;
  v_locked int;
  v_slotsuz int;
  v_yanlis_slot int;
  v_eksik_slot int;
  v_tekrar int;   -- 050
begin
  select owner_id into v_owner from decks where id = p_deck_id;

  if v_owner is null then
    return 'Deste bulunamadi.';
  end if;

  if v_owner <> p_user_id then
    return 'Bu deste size ait degil.';
  end if;

  select
    count(*),
    count(*) filter (where uc.owner_id <> p_user_id),
    count(*) filter (where uc.locked_match_id is not null),
    count(*) filter (where dc.slot_index is null),
    count(*) filter (
      where dc.slot_index is not null
        and c.position <> formation_slot_position(dc.slot_index)
    ),
    count(*) - count(distinct uc.card_id)
  into v_total, v_not_owned, v_locked, v_slotsuz, v_yanlis_slot, v_tekrar
  from deck_cards dc
  join user_cards uc on uc.id = dc.user_card_id
  join cards c       on c.id  = uc.card_id
  where dc.deck_id = p_deck_id;

  if v_total <> squad_size() then
    return format('Kadroda %s kart olmali, su an %s kart var.',
                  squad_size(), v_total);
  end if;

  if v_not_owned > 0 then
    return 'Destedeki bazi kartlar artik size ait degil. Kadronuzu guncelleyin.';
  end if;

  if v_locked > 0 then
    return 'Destedeki bazi kartlar devam eden bir macta kilitli.';
  end if;

  if v_slotsuz > 0 then
    return 'Kadro dizilisi eksik. Kartlari formasyondaki yerlerine yerlestirin.';
  end if;

  if v_yanlis_slot > 0 then
    return 'Bazi kartlar formasyonda yanlis pozisyonda duruyor.';
  end if;

  -- 050
  if v_tekrar > 0 then
    return 'Bir futbolcu kadroda yalnız bir kez olabilir. Kadronu düzenle.';
  end if;

  -- 0'dan 10'a kadar tum slotlar dolu mu?
  select count(*) into v_eksik_slot
  from generate_series(0, squad_size() - 1) s
  where not exists (
    select 1 from deck_cards dc
    where dc.deck_id = p_deck_id and dc.slot_index = s
  );

  if v_eksik_slot > 0 then
    return format('Formasyonda %s bos yer var.', v_eksik_slot);
  end if;

  return null; -- Kadro gecerli
end;
$$;

-- ---------------------------------------------------------------------
-- 5. BIR KERELIK ONARIM
-- ---------------------------------------------------------------------
do $$
declare
  r        record;
  d        record;
  v_farkli int;
  v_eksik  int;
  v_uc     uuid;
  v_tier   card_tier;
  v_yeni   uuid;
  v_dolgu  uuid;
  v_pos    card_position;
  v_cevrilen int := 0;
  v_verilen  int := 0;
  v_kadro    int := 0;
begin
  -- 5a. Her mevkide kadroya yetecek kadar farkli futbolcu
  for r in
    select u.id as user_id, n.key::card_position as pos, n.value::int as gerek
    from users u
    cross join jsonb_each_text(_chest_rules() -> 'squad_need') n
    where not u.is_bot
      and exists (select 1 from user_cards uc where uc.owner_id = u.id)
  loop
    select count(distinct uc.card_id) into v_farkli
    from user_cards uc join cards c on c.id = uc.card_id
    where uc.owner_id = r.user_id and c.position = r.pos;

    v_eksik := r.gerek - v_farkli;
    while v_eksik > 0 loop
      -- Ayni futbolcunun ilk kopyasindan sonra gelen, kilitsiz ve hicbir
      -- macta kullanilmamis (gecmis bozulmasin) en zayif kopya
      v_uc := null;
      select uc.id, c.tier into v_uc, v_tier
      from user_cards uc join cards c on c.id = uc.card_id
      where uc.owner_id = r.user_id
        and c.position = r.pos
        and uc.locked_match_id is null
        and exists (
          select 1 from user_cards o
          where o.owner_id = uc.owner_id and o.card_id = uc.card_id
            and (o.acquired_at, o.id) < (uc.acquired_at, uc.id))
        and not exists (select 1 from match_hands h where h.user_card_id = uc.id)
        and not exists (select 1 from match_moves m where m.user_card_id = uc.id)
      order by c.power, uc.acquired_at desc
      limit 1;

      if v_uc is not null then
        v_yeni := _pick_unowned_card(r.user_id, v_tier, r.pos);
        exit when v_yeni is null;
        update user_cards set card_id = v_yeni where id = v_uc;
        v_cevrilen := v_cevrilen + 1;
      else
        v_yeni := _pick_unowned_card(r.user_id, 'bronze', r.pos);
        exit when v_yeni is null;
        insert into user_cards (owner_id, card_id) values (r.user_id, v_yeni);
        v_verilen := v_verilen + 1;
      end if;
      insert into player_progress (user_id, card_id) values (r.user_id, v_yeni) on conflict do nothing;
      v_eksik := v_eksik - 1;
    end loop;
  end loop;

  -- 5b. Kadrolarda kalan tekrarlar (ayni futbolcunun ilk yerdeki kopyasi kalir)
  for d in
    select dc.deck_id, dc.user_card_id, dc.slot_index, dk.owner_id, uc.card_id
    from deck_cards dc
    join decks dk      on dk.id = dc.deck_id
    join users u       on u.id = dk.owner_id
    join user_cards uc on uc.id = dc.user_card_id
    where not u.is_bot
      and exists (
        select 1 from deck_cards dc2 join user_cards uc2 on uc2.id = dc2.user_card_id
        where dc2.deck_id = dc.deck_id and uc2.card_id = uc.card_id
          and (coalesce(dc2.slot_index, 99), dc2.user_card_id) < (coalesce(dc.slot_index, 99), dc.user_card_id))
  loop
    select c.position into v_pos from cards c where c.id = d.card_id;
    if d.slot_index is not null then
      v_pos := formation_slot_position(d.slot_index);
    end if;

    v_dolgu := null;
    select uc.id into v_dolgu
    from user_cards uc join cards c on c.id = uc.card_id
    where uc.owner_id = d.owner_id
      and uc.locked_match_id is null
      and c.position = v_pos
      and not exists (select 1 from deck_cards x where x.user_card_id = uc.id)
      and not exists (
        select 1 from deck_cards x join user_cards y on y.id = x.user_card_id
        where x.deck_id = d.deck_id and y.card_id = uc.card_id)
    order by c.power desc
    limit 1;

    if v_dolgu is not null then
      update deck_cards set user_card_id = v_dolgu
      where deck_id = d.deck_id and user_card_id = d.user_card_id;
    else
      delete from deck_cards where deck_id = d.deck_id and user_card_id = d.user_card_id;
    end if;
    v_kadro := v_kadro + 1;
  end loop;

  raise notice '050 onarim: % kopya farkli futbolcuya cevrildi, % futbolcu verildi, % kadro yeri duzeltildi',
    v_cevrilen, v_verilen, v_kadro;
end $$;
