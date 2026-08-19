-- =====================================================================
-- 002 - KULLANICILAR VE OTURUM YONETIMI
-- =====================================================================
-- DEGISIKLIK NOTU (Supabase'den gecis):
-- Supabase'de kimlik dogrulama auth.users tablosunda tutuluyordu ve
-- oyun verisi ayri bir "profiles" tablosundaydi. Kendi sunucumuzda
-- boyle bir ayrima gerek yok; tek "users" tablosu kullaniyoruz.
--
-- SIFRELER: Veritabani sifreyi ASLA duz metin gormez. Backend bcrypt
-- ile hash'leyip buraya sadece hash'i yazar.
-- =====================================================================

create table if not exists users (
  id                uuid primary key default gen_random_uuid(),

  -- ---- KIMLIK BILGILERI ----
  email             citext not null unique,
  password_hash     text   not null,

  -- ---- OYUN PROFILI ----
  username          text not null unique
                    check (char_length(username) between 3 and 20),
  avatar_url        text,

  coins             int not null default 1000 check (coins >= 0),

  -- Kart koruma hakki. Baslangic 3, her galibiyette +1 (ust sinir: 10)
  protection_slots  int not null default 3
                    check (protection_slots between 0 and 11),

  -- Eslestirme puani (Matchmaking Rating)
  mmr               int not null default 1000,

  wins              int not null default 0,
  losses            int not null default 0,
  draws             int not null default 0,

  -- ---- MODERASYON ----
  is_banned         boolean not null default false,
  ban_reason        text,

  last_seen_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table users is
  'Oyuncu hesabi. Hem kimlik dogrulama hem oyun profili bilgilerini tutar.';
comment on column users.password_hash is
  'bcrypt hash. Duz sifre ASLA saklanmaz.';
comment on column users.protection_slots is
  'Maca girerken korumaya alinabilecek maksimum kart sayisi. Her galibiyette +1.';

create index if not exists idx_users_mmr on users (mmr desc);

drop trigger if exists trg_users_updated_at on users;
create trigger trg_users_updated_at
  before update on users
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------
-- YENILEME JETONLARI (Refresh Tokens)
-- ---------------------------------------------------------------------
-- Access token kisa omurludur (15 dakika). Suresi dolunca uygulama
-- refresh token ile yenisini alir. Boylece kullanici surekli sifre
-- girmek zorunda kalmaz ama calinmis bir jeton da uzun sure kullanilamaz.
--
-- Jetonun KENDISI degil, SHA-256 ozeti saklanir. Veritabani sizsa bile
-- jetonlar kullanilamaz.
create table if not exists refresh_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references users(id) on delete cascade,

  token_hash  text not null unique,
  expires_at  timestamptz not null,
  revoked_at  timestamptz,

  -- Hangi cihazdan giris yapildi (istege bagli, guvenlik gunlugu icin)
  device_info text,
  ip_address  inet,

  created_at  timestamptz not null default now()
);

create index if not exists idx_refresh_tokens_user on refresh_tokens (user_id);
create index if not exists idx_refresh_tokens_expiry on refresh_tokens (expires_at);

-- Suresi dolmus jetonlari temizleyen yardimci
-- (backend belirli araliklarla cagirir)
create or replace function cleanup_expired_tokens()
returns int
language plpgsql
as $$
declare
  v_count int;
begin
  delete from refresh_tokens
  where expires_at < now() - interval '7 days';

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
