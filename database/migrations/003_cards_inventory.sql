-- =====================================================================
-- 003 - KART KATALOGU VE OYUNCU ENVANTERI
-- =====================================================================
-- MIMARI KARAR:
--   cards      -> Oyundaki kart TANIMLARI (katalog).
--                 Ornek: "Ronaldinho / Legend / 94 / MID"
--   user_cards -> Oyuncunun elindeki FIZIKSEL kart ornekleri.
--                 Her satir tek bir kart nesnesidir, cunku kartlar mac
--                 sonunda el degistirir ve sahiplik takibi sarttir.
-- =====================================================================

create table if not exists cards (
  id           uuid primary key default gen_random_uuid(),

  slug         text not null unique,          -- 'ronaldinho-legend' gibi
  full_name    text not null,
  position     card_position not null,
  tier         card_tier not null,

  -- Kart gucu. Legend kartlarin gucu sadece diger Legend'lara karsi anlamlidir.
  power        int not null check (power between 1 and 99),

  -- -------------------------------------------------------------------
  -- OYUNCU OZELLIKLERI (SUT / HIZ / FIZIK / DEFANS / DRIBLING / HIZLANMA)
  -- -------------------------------------------------------------------
  -- DIKKAT - BUNLAR MACI BELIRLEMEZ:
  -- Turlari kazanan hala `power` (+ kimya). Bu alti deger su an sadece
  -- GOSTERIM icindir; kartin karakterini anlatir ("hizli ama zayif
  -- defans"). Ileride bir ozelligi mac kuralina baglamak istersek
  -- _resolve_round() icinde tek satirlik bir degisiklik yeter.
  --
  -- Degerler elle yazilmadi; 016_card_attributes.sql pozisyona gore
  -- uretiyor. Boylece 100 kart icin 600 sayiyi elle bakim etmiyoruz.
  shooting     int check (shooting     between 1 and 99),  -- SUT
  pace         int check (pace         between 1 and 99),  -- HIZ
  physical     int check (physical     between 1 and 99),  -- FIZIK
  defending    int check (defending    between 1 and 99),  -- DEFANS
  dribbling    int check (dribbling    between 1 and 99),  -- DRIBLING
  acceleration int check (acceleration between 1 and 99),  -- HIZLANMA

  nationality  text,

  -- KIMYA SISTEMI: lig ve kulup baglantilari icin.
  -- DIKKAT: lig, uyruktan BAGIMSIZ dagitilmali. Her ulkenin kendi ligi
  -- olursa "ayni lig" ile "ayni uyruk" ayni sey olur ve kimya kuralindaki
  -- "+2 = ayni lig + ayni uyruk" sarti hicbir zaman +1'den farkli
  -- davranmaz. Bkz. 014_chemistry.sql
  league       text,
  club         text,

  -- Yapay zeka ile uretilmis 3D Pixar tarzi gorselin dosya yolu
  image_url    text,

  is_active    boolean not null default true,
  -- Paketten cikma agirligi (yuksek = daha sik cikar)
  drop_weight  int not null default 100 check (drop_weight >= 0),

  created_at   timestamptz not null default now()
);

comment on table cards is 'Kart katalogu (master data). Sadece yonetici degistirir.';

-- ---------------------------------------------------------------------
-- OZELLIKLERI JSON'A CEVIREN YARDIMCI
-- ---------------------------------------------------------------------
-- NEDEN AYRI FONKSIYON?
-- Kart JSON'u uc ayri yerde uretiliyor (paket acma, mac sonucu, ...).
-- Alti alani her birine elle yazarsak birinde unutulur ve o ekranda
-- ozellikler sessizce kaybolur. Tek yerden uretiyoruz.
--
-- Ozellikler henuz uretilmemisse NULL doner; istemci de bolumu
-- gostermez (bos bir izgara cizmek yerine hic cizmemek dogrusu).
create or replace function card_attributes_json(
  p_shooting     int,
  p_pace         int,
  p_physical     int,
  p_defending    int,
  p_dribbling    int,
  p_acceleration int
)
returns json
language sql
immutable
as $$
  select case when p_shooting is null then null else json_build_object(
    'shooting',     p_shooting,
    'pace',         p_pace,
    'physical',     p_physical,
    'defending',    p_defending,
    'dribbling',    p_dribbling,
    'acceleration', p_acceleration
  ) end;
$$;

create index if not exists idx_cards_position_tier on cards (position, tier);
create index if not exists idx_cards_active on cards (is_active) where is_active;

-- ---------------------------------------------------------------------
-- ENVANTER
-- ---------------------------------------------------------------------
create table if not exists user_cards (
  id              uuid primary key default gen_random_uuid(),

  owner_id        uuid not null references users(id) on delete cascade,
  card_id         uuid not null references cards(id) on delete restrict,

  -- TUTARLILIK KILIDI: Kart bir macta kullaniliyorsa burasi dolar.
  -- Boylece ayni kart ayni anda iki macta ya da iki destede kullanilamaz,
  -- ayrica mac surerken satilamaz/takas edilemez.
  locked_match_id uuid,

  -- Izlenebilirlik: bu kart kimden kazanildi?
  acquired_from   uuid references users(id) on delete set null,
  acquired_at     timestamptz not null default now()
);

comment on table user_cards is
  'Oyuncunun sahip oldugu tekil kart ornekleri. Mac kaybinda owner_id degisir.';

create index if not exists idx_user_cards_owner  on user_cards (owner_id);
create index if not exists idx_user_cards_card   on user_cards (card_id);
create index if not exists idx_user_cards_locked on user_cards (locked_match_id)
  where locked_match_id is not null;

-- ---------------------------------------------------------------------
-- KART TRANSFER GECMISI (Yuksek Risk Modu denetim kaydi)
-- ---------------------------------------------------------------------
-- Oyuncu "kartim haksiz yere gitti" derse buradan ispatlanir.
create table if not exists card_transfers (
  id            bigint generated always as identity primary key,
  match_id      uuid,
  user_card_id  uuid not null,
  card_id       uuid not null references cards(id),
  from_user_id  uuid not null references users(id) on delete cascade,
  to_user_id    uuid not null references users(id) on delete cascade,
  reason        text not null default 'match_penalty',
  created_at    timestamptz not null default now()
);

create index if not exists idx_card_transfers_from on card_transfers (from_user_id, created_at desc);
create index if not exists idx_card_transfers_to   on card_transfers (to_user_id, created_at desc);
