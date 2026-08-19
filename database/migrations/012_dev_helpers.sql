-- =====================================================================
-- 012 - GELISTIRME YARDIMCILARI
-- =====================================================================
-- DIKKAT: Bu dosyadaki fonksiyonlar SADECE test icindir.
--
-- Sunucu tarafinda bu fonksiyonlari cagiran uc noktalar
-- ENVIRONMENT=production iken KAPALIDIR. Yayina cikarken bu dosyayi
-- migration listesinden cikarabilirsin; oyunun calismasi icin gerekli
-- degil.
-- =====================================================================

-- ---------------------------------------------------------------------
-- TUM KARTLARI VER
-- ---------------------------------------------------------------------
-- Katalogdaki her karttan birer adet verir. Koleksiyon ekranini,
-- kart tasarimlarini ve filtreleri test etmek icin.
--
-- Zaten sahip olunan kartlar TEKRAR verilmez; fonksiyonu birden fazla
-- kez cagirsan bile envanter sismez.
create or replace function dev_grant_all_cards(p_user_id uuid)
returns json
language plpgsql
as $$
declare
  v_eklenen int;
  v_toplam  int;
begin
  if not exists (select 1 from users where id = p_user_id) then
    raise exception 'Kullanici bulunamadi.';
  end if;

  insert into user_cards (owner_id, card_id)
  select p_user_id, c.id
  from cards c
  where c.is_active
    and not exists (
      select 1 from user_cards uc
      where uc.owner_id = p_user_id and uc.card_id = c.id
    );

  get diagnostics v_eklenen = row_count;

  select count(*) into v_toplam from user_cards where owner_id = p_user_id;

  return json_build_object(
    'status', 'ok',
    'added', v_eklenen,
    'total', v_toplam
  );
end;
$$;

comment on function dev_grant_all_cards(uuid) is
  'SADECE GELISTIRME: Katalogdaki tum kartlari kullaniciya verir.';

-- ---------------------------------------------------------------------
-- COIN EKLE
-- ---------------------------------------------------------------------
-- Paket acma akisini test ederken coin bitmesin diye.
create or replace function dev_add_coins(p_user_id uuid, p_amount int)
returns json
language plpgsql
as $$
declare
  v_coins int;
begin
  if p_amount < 0 then
    raise exception 'Miktar negatif olamaz.';
  end if;

  update users set coins = coins + p_amount
  where id = p_user_id
  returning coins into v_coins;

  if not found then
    raise exception 'Kullanici bulunamadi.';
  end if;

  return json_build_object('status', 'ok', 'coins', v_coins);
end;
$$;

comment on function dev_add_coins(uuid, int) is
  'SADECE GELISTIRME: Kullaniciya coin ekler.';

-- ---------------------------------------------------------------------
-- KATALOG OZETI
-- ---------------------------------------------------------------------
-- Kart dagilimini hizlica gormek icin. psql'de:
--   select * from catalog_summary;
create or replace view catalog_summary as
select
  tier,
  count(*) filter (where position = 'GK')  as gk,
  count(*) filter (where position = 'DEF') as def,
  count(*) filter (where position = 'MID') as mid,
  count(*) filter (where position = 'FWD') as fwd,
  count(*)                                  as toplam,
  min(power)                                as en_dusuk_guc,
  max(power)                                as en_yuksek_guc
from cards
where is_active
group by tier
order by tier_rank(tier);
