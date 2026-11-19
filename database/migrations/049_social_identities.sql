-- =====================================================================
-- 049: GOOGLE VE APPLE ILE GIRIS
-- =====================================================================
-- Bir oyuncunun dis saglayicidaki kimligi burada tutulur. E-posta degisebilir
-- (Apple gizli adres de verebilir); kalici anahtar saglayicinin "sub" degeridir.
--
-- users.password_hash zorunlu kalir: sosyal hesaplara kimsenin bilmedigi rastgele
-- bir sifrenin ozeti yazilir, bu yuzden mevcut sifreli giris akisi degismez.

create table if not exists user_identities (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references users (id) on delete cascade,
  provider          text not null check (provider in ('google', 'apple')),
  provider_subject  text not null check (char_length(provider_subject) between 1 and 255),
  email             citext,
  created_at        timestamptz not null default now(),

  unique (provider, provider_subject),
  unique (user_id, provider)
);

comment on table user_identities is
  'Oyuncunun Google/Apple kimlikleri. Giris, kimlik jetonundaki sub ile eslesir.';
