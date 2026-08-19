-- =====================================================================
-- 009 - BASLANGIC PAKETI
-- =====================================================================
-- Yeni oyuncuya 17 kart verir ve gecerli bir 4-4-2 kadro
-- (1 GK, 4 DEF, 4 MID, 2 FWD) otomatik olusturur.
-- Backend, kayit isleminin hemen ardindan bunu cagirir.
-- =====================================================================

create or replace function grant_starter_pack(p_user_id uuid)
returns json
language plpgsql
as $$
declare
  v_deck_id uuid;
  v_total   int;
begin
  if not exists (select 1 from users where id = p_user_id) then
    raise exception 'Kullanici bulunamadi.';
  end if;

  -- Sadece bir kez verilir
  if exists (select 1 from user_cards where owner_id = p_user_id) then
    raise exception 'Baslangic paketi zaten alinmis.';
  end if;

  -- Pozisyon basina rastgele bronz/gumus kart dagit
  insert into user_cards (owner_id, card_id)
  select p_user_id, x.id from (
    (select id from cards where position = 'GK'  and tier in ('bronze','silver') and is_active order by random() limit 2)
    union all
    (select id from cards where position = 'DEF' and tier in ('bronze','silver') and is_active order by random() limit 6)
    union all
    (select id from cards where position = 'MID' and tier in ('bronze','silver') and is_active order by random() limit 6)
    union all
    (select id from cards where position = 'FWD' and tier in ('bronze','silver') and is_active order by random() limit 3)
  ) x;

  select count(*) into v_total from user_cards where owner_id = p_user_id;

  if v_total < squad_size() then
    raise exception 'Kart katalogunda yeterli kart yok. Once seed verisini yukleyin.';
  end if;

  -- Varsayilan aktif deste
  insert into decks (owner_id, name, is_active)
  values (p_user_id, 'Ilk Kadrom', true)
  returning id into v_deck_id;

  -- Gecerli formasyonu otomatik kur: 1 GK + 4 DEF + 4 MID + 2 FWD
  insert into deck_cards (deck_id, user_card_id)
  select v_deck_id, y.id from (
    (select uc.id from user_cards uc join cards c on c.id = uc.card_id
      where uc.owner_id = p_user_id and c.position = 'GK'  order by c.power desc limit 1)
    union all
    (select uc.id from user_cards uc join cards c on c.id = uc.card_id
      where uc.owner_id = p_user_id and c.position = 'DEF' order by c.power desc limit 4)
    union all
    (select uc.id from user_cards uc join cards c on c.id = uc.card_id
      where uc.owner_id = p_user_id and c.position = 'MID' order by c.power desc limit 4)
    union all
    (select uc.id from user_cards uc join cards c on c.id = uc.card_id
      where uc.owner_id = p_user_id and c.position = 'FWD' order by c.power desc limit 2)
  ) y;

  return json_build_object('status', 'ok', 'card_count', v_total, 'deck_id', v_deck_id);
end;
$$;
