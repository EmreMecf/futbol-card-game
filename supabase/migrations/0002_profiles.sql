-- =====================================================================
-- 0002 — KULLANICI PROFİLLERİ (profiles)
-- =====================================================================
-- Supabase'in auth.users tablosuna DOKUNULMAZ. Oyunla ilgili tüm
-- kullanıcı verisi bu tabloda tutulur ve auth.users ile 1-1 bağlıdır.
-- =====================================================================

create table if not exists public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,

  username          text not null unique
                    check (char_length(username) between 3 and 20),
  avatar_url        text,

  -- Ekonomi
  coins             int  not null default 1000 check (coins >= 0),

  -- Kart koruma hakkı. Başlangıç 3, her galibiyette +1 (üst sınır: 10)
  protection_slots  int  not null default 3
                    check (protection_slots between 0 and 11),

  -- Eşleştirme puanı (Matchmaking Rating)
  mmr               int  not null default 1000,

  -- İstatistikler
  wins              int  not null default 0,
  losses            int  not null default 0,
  draws             int  not null default 0,

  -- Moderasyon / anti-hile
  is_banned         boolean not null default false,
  ban_reason        text,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table public.profiles is
  'Oyuncu profili. auth.users ile 1-1 ilişkilidir. Kart koruma hakkı ve MMR burada tutulur.';
comment on column public.profiles.protection_slots is
  'Maça girerken korumaya alınabilecek maksimum kart sayısı. Her galibiyette +1 artar.';

-- Liderlik tablosu / eşleştirme sorguları için index
create index if not exists idx_profiles_mmr on public.profiles (mmr desc);

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- YENİ KULLANICI KAYDOLDUĞUNDA OTOMATİK PROFİL AÇMA
-- ---------------------------------------------------------------------
-- Flutter tarafında signUp yapıldığında raw_user_meta_data içine
-- 'username' göndermelisin. Gönderilmezse rastgele bir isim atanır.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_username text;
begin
  v_username := coalesce(
    nullif(new.raw_user_meta_data ->> 'username', ''),
    'oyuncu_' || substr(replace(new.id::text, '-', ''), 1, 8)
  );

  -- Aynı kullanıcı adı varsa sonuna sayı ekleyerek benzersizleştir
  while exists (select 1 from public.profiles p where p.username = v_username) loop
    v_username := v_username || floor(random() * 10)::text;
  end loop;

  insert into public.profiles (id, username, protection_slots)
  values (new.id, v_username, public.base_protection_slots());

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
