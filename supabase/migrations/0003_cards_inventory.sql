-- =====================================================================
-- 0003 — KART KATALOĞU (cards) VE OYUNCU ENVANTERİ (user_cards)
-- =====================================================================
-- MİMARİ KARAR:
--   cards      -> Oyundaki kart TANIMLARI (katalog). Herkes okuyabilir,
--                 kimse yazamaz. Örn: "Ronaldinho / Legend / 94 / MID"
--   user_cards -> Oyuncunun elindeki FİZİKSEL kart örnekleri.
--                 Her satır tek bir kart nesnesidir çünkü kartlar
--                 maç sonunda el değiştirir (sahiplik takibi şart).
-- =====================================================================

create table if not exists public.cards (
  id           uuid primary key default gen_random_uuid(),

  slug         text not null unique,        -- 'ronaldinho-legend' gibi
  full_name    text not null,
  position     public.card_position not null,
  tier         public.card_tier not null,

  -- Kart gücü. Legend kartların gücü sadece diğer Legend'lara karşı anlamlıdır.
  power        int  not null check (power between 1 and 99),

  nationality  text,
  club         text,

  -- Yapay zeka ile üretilmiş 3D Pixar tarzı görselin Supabase Storage yolu
  image_url    text,

  -- Kart havuzdan çekilebilir mi (dengeleme için kapatılabilir)
  is_active    boolean not null default true,
  -- Paketten çıkma ağırlığı (yüksek = daha sık çıkar)
  drop_weight  int not null default 100 check (drop_weight >= 0),

  created_at   timestamptz not null default now()
);

comment on table public.cards is 'Kart kataloğu (master data). Sadece admin/service_role yazabilir.';

create index if not exists idx_cards_position_tier on public.cards (position, tier);
create index if not exists idx_cards_active on public.cards (is_active) where is_active;

-- ---------------------------------------------------------------------
-- ENVANTER
-- ---------------------------------------------------------------------
create table if not exists public.user_cards (
  id              uuid primary key default gen_random_uuid(),

  owner_id        uuid not null references public.profiles(id) on delete cascade,
  card_id         uuid not null references public.cards(id)    on delete restrict,

  -- ANTI-HİLE / TUTARLILIK: Kart bir maçta kullanılıyorsa burası dolar.
  -- Böylece aynı kart aynı anda iki maçta ya da iki destede kullanılamaz,
  -- ayrıca maç sürerken satılamaz/takas edilemez.
  locked_match_id uuid,

  -- İzlenebilirlik: bu kart kimden kazanıldı?
  acquired_from   uuid references public.profiles(id) on delete set null,
  acquired_at     timestamptz not null default now()
);

comment on table public.user_cards is
  'Oyuncunun sahip olduğu tekil kart örnekleri. Maç kaybında owner_id değişir.';
comment on column public.user_cards.locked_match_id is
  'Dolu ise kart aktif bir maçta kilitlidir; deste değiştirilemez, kart elden çıkarılamaz.';

create index if not exists idx_user_cards_owner   on public.user_cards (owner_id);
create index if not exists idx_user_cards_card    on public.user_cards (card_id);
create index if not exists idx_user_cards_locked  on public.user_cards (locked_match_id)
  where locked_match_id is not null;

-- ---------------------------------------------------------------------
-- KART TRANSFER GEÇMİŞİ (Yüksek Risk Modu denetim kaydı)
-- ---------------------------------------------------------------------
-- Oyuncu "kartım haksız yere gitti" derse buradan ispatlanır.
create table if not exists public.card_transfers (
  id            bigint generated always as identity primary key,
  match_id      uuid,
  user_card_id  uuid not null,
  card_id       uuid not null references public.cards(id),
  from_user_id  uuid not null references public.profiles(id) on delete cascade,
  to_user_id    uuid not null references public.profiles(id) on delete cascade,
  reason        text not null default 'match_penalty',
  created_at    timestamptz not null default now()
);

create index if not exists idx_card_transfers_from on public.card_transfers (from_user_id, created_at desc);
create index if not exists idx_card_transfers_to   on public.card_transfers (to_user_id, created_at desc);
