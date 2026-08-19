-- =====================================================================
-- 001 - EKLENTILER, ENUM TIPLERI VE YARDIMCI FONKSIYONLAR
-- =====================================================================
-- Bu dosya SAF PostgreSQL'dir. Supabase'e ozel hicbir sey icermez.
-- Kendi sunucunda, Docker'da veya herhangi bir PostgreSQL 14+ uzerinde
-- oldugu gibi calisir.
-- =====================================================================

-- UUID uretimi ve sifreleme fonksiyonlari icin
create extension if not exists "pgcrypto";

-- Buyuk/kucuk harf duyarsiz metin (e-posta karsilastirmasi icin)
create extension if not exists "citext";

-- ---------------------------------------------------------------------
-- ENUM TIPLERI
-- ---------------------------------------------------------------------

-- Kart seviyeleri (hiyerarsi: bronze < silver < gold < diamond < legend)
do $$ begin
  create type card_tier as enum ('bronze', 'silver', 'gold', 'diamond', 'legend');
exception when duplicate_object then null; end $$;

-- Saha pozisyonlari: GK=Kaleci, DEF=Defans, MID=Orta Saha, FWD=Forvet
do $$ begin
  create type card_position as enum ('GK', 'DEF', 'MID', 'FWD');
exception when duplicate_object then null; end $$;

-- Mac durumlari
do $$ begin
  create type match_status as enum ('active', 'finished', 'cancelled');
exception when duplicate_object then null; end $$;

-- Eslestirme kuyrugu durumlari
do $$ begin
  create type queue_status as enum ('searching', 'matched', 'cancelled');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- OYUN SABITLERI
-- ---------------------------------------------------------------------
-- Tek yerden yonetilebilsin diye fonksiyon olarak tanimlandi.
-- Dengeleme yaparken sadece burayi degistirmen yeterli.

create or replace function squad_size() returns int
language sql immutable as $$ select 11 $$;

-- Bir oyuncunun kart oynamasi icin verilen sure (saniye)
create or replace function turn_timeout_seconds() returns int
language sql immutable as $$ select 45 $$;

-- Tur suresi dolduktan SONRA taninan ek sure. Bu da dolarsa HUKMEN maglubiyet.
create or replace function afk_grace_seconds() returns int
language sql immutable as $$ select 15 $$;

-- Mac kaybedildiginde kaptirilacak kart sayisi (Yuksek Risk Modu)
create or replace function penalty_card_count() returns int
language sql immutable as $$ select 3 $$;

-- Koruma hakkinin baslangic degeri ve ust siniri
create or replace function base_protection_slots() returns int
language sql immutable as $$ select 3 $$;

create or replace function max_protection_slots() returns int
language sql immutable as $$ select 10 $$;  -- 11'in tamami korunamasin

-- ---------------------------------------------------------------------
-- KART SEVIYESI SIRALAMASI
-- ---------------------------------------------------------------------
create or replace function tier_rank(p_tier card_tier)
returns int
language sql
immutable
as $$
  select case p_tier
    when 'bronze'  then 1
    when 'silver'  then 2
    when 'gold'    then 3
    when 'diamond' then 4
    when 'legend'  then 5
  end;
$$;

-- ---------------------------------------------------------------------
-- KART KARSILASTIRMA - OYUNUN EN KRITIK KURALI
-- ---------------------------------------------------------------------
-- Donus degeri:
--    1  -> A karti kazanir
--   -1  -> B karti kazanir
--    0  -> Beraberlik
--
-- KURALLAR:
--  1) Legend kart, Legend olmayan HER karti gucune bakilmaksizin yener.
--  2) Iki Legend karsilasirsa, gucu yuksek olan kazanir.
--  3) Legend olmayan iki kartta seviye degil, sadece GUC belirleyicidir.
create or replace function compare_cards(
  p_a_tier  card_tier,
  p_a_power int,
  p_b_tier  card_tier,
  p_b_power int
)
returns int
language plpgsql
immutable
as $$
begin
  -- Kural 1: Legend ustunlugu
  if p_a_tier = 'legend' and p_b_tier <> 'legend' then
    return 1;
  end if;

  if p_b_tier = 'legend' and p_a_tier <> 'legend' then
    return -1;
  end if;

  -- Kural 2 ve 3: Guc karsilastirmasi
  if p_a_power > p_b_power then
    return 1;
  elsif p_a_power < p_b_power then
    return -1;
  else
    return 0;
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- updated_at KOLONUNU OTOMATIK GUNCELLEYEN TRIGGER
-- ---------------------------------------------------------------------
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
