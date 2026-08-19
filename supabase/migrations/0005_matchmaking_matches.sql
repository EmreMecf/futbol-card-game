-- =====================================================================
-- 0005 — EŞLEŞTİRME KUYRUĞU VE MAÇ TABLOLARI
-- =====================================================================
-- MİMARİ KARAR — EN ÖNEMLİ ANTİ-HİLE NOKTASI:
--   Oyuncunun ELİ (hand) 'match_hands' tablosunda tutulur ve bu tabloya
--   RLS ile HİÇBİR kullanıcı doğrudan erişemez. Kendi elini bile
--   sadece get_my_hand() RPC'si üzerinden görebilir.
--   Böylece rakip, Supabase client'ı ile senin kartlarını okuyamaz.
-- =====================================================================

create table if not exists public.matches (
  id                 uuid primary key default gen_random_uuid(),

  player1_id         uuid not null references public.profiles(id) on delete cascade,
  player2_id         uuid not null references public.profiles(id) on delete cascade,

  status             public.match_status not null default 'active',

  -- Sıra kimde? (Bu kullanıcıdan hamle bekleniyor)
  current_turn_id    uuid not null references public.profiles(id),

  -- Turu AÇAN oyuncu. Pozisyonu o belirler, rakip uymak zorundadır.
  lead_player_id     uuid not null references public.profiles(id),

  -- Turu açan kart oynadıysa, cevap verecek oyuncunun oynamak
  -- zorunda olduğu pozisyon. NULL ise henüz tur açılmamıştır.
  required_position  public.card_position,

  round_number       int  not null default 1 check (round_number >= 1),

  -- Beraberlikte masada kalan kartlar. Sonraki turu alan hepsini toplar.
  pot_card_ids       uuid[] not null default '{}',

  -- Hızlı skor gösterimi (toplanan kart sayısı)
  p1_captured_count  int not null default 0,
  p2_captured_count  int not null default 0,

  -- Süre aşımı kontrolü (istemciye güvenmeden sunucu saatiyle)
  turn_deadline      timestamptz not null default now() + interval '45 seconds',

  -- Sonuç
  winner_id          uuid references public.profiles(id),
  loser_id           uuid references public.profiles(id),
  is_draw            boolean not null default false,

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  finished_at        timestamptz,

  constraint chk_different_players check (player1_id <> player2_id)
);

comment on table public.matches is 'Aktif ve bitmis maclar. Tum durum degisiklikleri SECURITY DEFINER RPC ile yapilir.';

create index if not exists idx_matches_p1 on public.matches (player1_id) where status = 'active';
create index if not exists idx_matches_p2 on public.matches (player2_id) where status = 'active';
create index if not exists idx_matches_status on public.matches (status, updated_at desc);

drop trigger if exists trg_matches_updated_at on public.matches;
create trigger trg_matches_updated_at
  before update on public.matches
  for each row execute function public.set_updated_at();

-- Envanterdeki kilit kolonuna artik FK verebiliriz (matches tablosu olustu)
alter table public.user_cards
  drop constraint if exists fk_user_cards_locked_match;
alter table public.user_cards
  add constraint fk_user_cards_locked_match
  foreign key (locked_match_id) references public.matches(id) on delete set null;

-- ---------------------------------------------------------------------
-- MAÇTAKİ OYUNCU BİLGİLERİ
-- ---------------------------------------------------------------------
create table if not exists public.match_players (
  match_id            uuid not null references public.matches(id)  on delete cascade,
  user_id             uuid not null references public.profiles(id) on delete cascade,
  deck_id             uuid not null references public.decks(id),

  -- Maça girerken korumaya alınan kartlar (en fazla profiles.protection_slots kadar)
  protected_card_ids  uuid[] not null default '{}',

  -- Bu maçta kazanılan (masadan toplanan) kartlar
  captured_card_ids   uuid[] not null default '{}',

  -- Bağlantı kopması / süre aşımı sayacı
  timeout_count       int not null default 0,

  primary key (match_id, user_id)
);

create index if not exists idx_match_players_user on public.match_players (user_id);

-- ---------------------------------------------------------------------
-- OYUNCUNUN ELİ — GİZLİ TABLO (hiçbir istemci okuyamaz)
-- ---------------------------------------------------------------------
create table if not exists public.match_hands (
  match_id      uuid not null references public.matches(id)     on delete cascade,
  user_id       uuid not null references public.profiles(id)    on delete cascade,
  user_card_id  uuid not null references public.user_cards(id)  on delete cascade,

  -- Kart tanımının anlık kopyası. Katalog sonradan dengelenirse
  -- devam eden maçın sonucu değişmesin diye burada dondurulur.
  card_id       uuid not null references public.cards(id),
  position      public.card_position not null,
  tier          public.card_tier not null,
  power         int  not null,

  is_played     boolean not null default false,
  played_round  int,

  primary key (match_id, user_card_id)
);

comment on table public.match_hands is
  'ANTI-HILE: Oyuncularin eli. RLS ile hicbir kullaniciya okuma izni YOKTUR. Sadece get_my_hand() RPC uzerinden erisilir.';

create index if not exists idx_match_hands_lookup
  on public.match_hands (match_id, user_id, is_played);

-- ---------------------------------------------------------------------
-- HAMLE GEÇMİŞİ (açık bilgi — iki oyuncu da görebilir)
-- ---------------------------------------------------------------------
create table if not exists public.match_moves (
  id            bigint generated always as identity primary key,
  match_id      uuid not null references public.matches(id)  on delete cascade,
  user_id       uuid not null references public.profiles(id) on delete cascade,
  round_number  int  not null,

  -- NULL ise oyuncu "bu pozisyonda kartim yok" diyerek turu kaybetmistir (pas)
  user_card_id  uuid references public.user_cards(id),
  card_id       uuid references public.cards(id),
  position      public.card_position,
  tier          public.card_tier,
  power         int,

  is_lead       boolean not null,   -- turu bu hamle mi acti?
  is_pass       boolean not null default false,

  created_at    timestamptz not null default now(),

  unique (match_id, round_number, user_id)
);

create index if not exists idx_match_moves_match on public.match_moves (match_id, round_number);

-- ---------------------------------------------------------------------
-- TUR SONUÇLARI (animasyon ve maç özeti için)
-- ---------------------------------------------------------------------
create table if not exists public.match_rounds (
  match_id        uuid not null references public.matches(id) on delete cascade,
  round_number    int  not null,
  winner_id       uuid references public.profiles(id),   -- NULL = beraberlik
  is_draw         boolean not null default false,
  cards_won       uuid[] not null default '{}',          -- masadan toplanan kartlar
  resolved_at     timestamptz not null default now(),
  primary key (match_id, round_number)
);

-- ---------------------------------------------------------------------
-- EŞLEŞTİRME KUYRUĞU
-- ---------------------------------------------------------------------
-- user_id PRIMARY KEY olduğu için bir oyuncu kuyruğa iki kez giremez.
create table if not exists public.matchmaking_queue (
  user_id             uuid primary key references public.profiles(id) on delete cascade,
  deck_id             uuid not null references public.decks(id) on delete cascade,

  protected_card_ids  uuid[] not null default '{}',
  mmr                 int not null,

  status              public.queue_status not null default 'searching',

  -- Eşleşme bulunduğunda buraya maç ID'si yazılır.
  -- Flutter tarafı bu satırı Realtime ile dinleyip oyun ekranına geçer.
  match_id            uuid references public.matches(id) on delete set null,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists idx_queue_searching
  on public.matchmaking_queue (status, mmr, created_at) where status = 'searching';

drop trigger if exists trg_queue_updated_at on public.matchmaking_queue;
create trigger trg_queue_updated_at
  before update on public.matchmaking_queue
  for each row execute function public.set_updated_at();
