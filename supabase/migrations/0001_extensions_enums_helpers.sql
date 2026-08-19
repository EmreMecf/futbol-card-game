-- =====================================================================
-- 0001 — EKLENTİLER, ENUM TİPLERİ VE YARDIMCI FONKSİYONLAR
-- =====================================================================
-- Bu dosya projenin temel taşlarını kurar. Diğer tüm migration
-- dosyaları buradaki tiplere ve fonksiyonlara bağımlıdır.
-- =====================================================================

-- UUID üretimi için (Supabase'de genelde hazır gelir, garanti olsun diye)
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- ENUM TİPLERİ
-- ---------------------------------------------------------------------

-- Kart seviyeleri (hiyerarşi: bronze < silver < gold < diamond < legend)
do $$ begin
  create type public.card_tier as enum ('bronze', 'silver', 'gold', 'diamond', 'legend');
exception when duplicate_object then null; end $$;

-- Saha pozisyonları: GK=Kaleci, DEF=Defans, MID=Orta Saha, FWD=Forvet
do $$ begin
  create type public.card_position as enum ('GK', 'DEF', 'MID', 'FWD');
exception when duplicate_object then null; end $$;

-- Maç durumları
do $$ begin
  create type public.match_status as enum ('active', 'finished', 'cancelled');
exception when duplicate_object then null; end $$;

-- Eşleştirme kuyruğu durumları
do $$ begin
  create type public.queue_status as enum ('searching', 'matched', 'cancelled');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- OYUN SABİTLERİ (tek yerden yönetilebilsin diye fonksiyon olarak)
-- ---------------------------------------------------------------------

-- Bir kadroda olması gereken toplam kart sayısı
create or replace function public.squad_size() returns int
language sql immutable as $$ select 11 $$;

-- Sıra bekleme süresi (saniye). Oyuncunun kart oynaması için verilen süre.
create or replace function public.turn_timeout_seconds() returns int
language sql immutable as $$ select 45 $$;

-- AFK toleransı (saniye). Tur süresi dolduktan SONRA bağlantısı kopan
-- oyuncuya tanınan ek süre. Bu da dolarsa maç HÜKMEN kaybedilir.
create or replace function public.afk_grace_seconds() returns int
language sql immutable as $$ select 15 $$;

-- Maç kaybedildiğinde kaptırılacak kart sayısı (Yüksek Risk Modu)
create or replace function public.penalty_card_count() returns int
language sql immutable as $$ select 3 $$;

-- Koruma hakkının başlangıç değeri ve üst sınırı
create or replace function public.base_protection_slots() returns int
language sql immutable as $$ select 3 $$;

create or replace function public.max_protection_slots() returns int
language sql immutable as $$ select 10 $$;  -- 11 kadronun tamamı korunamasın

-- ---------------------------------------------------------------------
-- KART SEVİYESİ SIRALAMASI
-- ---------------------------------------------------------------------
-- Enum'un kendi sıralaması zaten doğru ama sayısal karşılaştırma
-- yapmak istediğimiz yerlerde bu fonksiyonu kullanıyoruz.
create or replace function public.tier_rank(p_tier public.card_tier)
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
-- KART KARŞILAŞTIRMA — OYUNUN EN KRİTİK KURALI
-- ---------------------------------------------------------------------
-- Dönüş değeri:
--    1  -> A kartı kazanır
--   -1  -> B kartı kazanır
--    0  -> Beraberlik
--
-- KURALLAR:
--  1) Legend kart, Legend olmayan HER kartı gücüne bakılmaksızın yener.
--  2) İki Legend karşılaşırsa, gücü yüksek olan kazanır.
--  3) Legend olmayan iki kartta seviye değil, sadece GÜÇ (power) belirleyicidir.
--     (Zaten üst seviye kartların güç aralığı daha yüksektir.)
create or replace function public.compare_cards(
  p_a_tier  public.card_tier,
  p_a_power int,
  p_b_tier  public.card_tier,
  p_b_power int
)
returns int
language plpgsql
immutable
as $$
begin
  -- Kural 1: Legend üstünlüğü
  if p_a_tier = 'legend' and p_b_tier <> 'legend' then
    return 1;
  end if;

  if p_b_tier = 'legend' and p_a_tier <> 'legend' then
    return -1;
  end if;

  -- Kural 2 ve 3: Güç karşılaştırması
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
-- updated_at KOLONUNU OTOMATİK GÜNCELLEYEN TRIGGER FONKSİYONU
-- ---------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
