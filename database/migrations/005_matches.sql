-- =====================================================================
-- 005 - ESLESTIRME KUYRUGU VE MAC TABLOLARI
-- =====================================================================
-- GUVENLIK NOTU (Supabase'den gecis):
-- Supabase'de oyuncunun eli (match_hands) RLS ile gizleniyordu, cunku
-- uygulama veritabanina DOGRUDAN baglaniyordu. Simdi araya kendi
-- backend'imiz girdi. Uygulama veritabanini hic gormuyor; sadece
-- backend'in verdigi cevabi goruyor.
--
-- Yani gizlilik sinirlari artik BACKEND'de:
--   * get_my_hand(p_user_id, p_match_id) sadece o oyuncunun kartlarini doner.
--   * Backend hicbir uc noktada rakibin elini gondermez.
-- Kural dogrulamalari (sira kontrolu, kart sahipligi, pozisyon zorunlulugu)
-- ise HALA burada, veritabaninda yapiliyor. "Istemciye guvenme" prensibi
-- aynen korunuyor, sadece kontrol noktasi degisti.
-- =====================================================================

create table if not exists matches (
  id                 uuid primary key default gen_random_uuid(),

  player1_id         uuid not null references users(id) on delete cascade,
  player2_id         uuid not null references users(id) on delete cascade,

  status             match_status not null default 'active',

  -- Sira kimde? (Bu kullanicidan hamle bekleniyor)
  current_turn_id    uuid not null references users(id),

  -- Turu ACAN oyuncu. Pozisyonu o belirler, rakip uymak zorundadir.
  lead_player_id     uuid not null references users(id),

  -- Cevap verecek oyuncunun oynamak zorunda oldugu pozisyon.
  -- NULL ise henuz tur acilmamistir.
  required_position  card_position,

  round_number       int not null default 1 check (round_number >= 1),

  -- Beraberlikte masada kalan kartlar. Sonraki turu alan hepsini toplar.
  pot_card_ids       uuid[] not null default '{}',

  -- Hizli skor gosterimi (toplanan kart sayisi)
  p1_captured_count  int not null default 0,
  p2_captured_count  int not null default 0,

  -- Sure asimi kontrolu (istemciye guvenmeden SUNUCU saatiyle)
  turn_deadline      timestamptz not null default now() + interval '45 seconds',

  -- Sonuc
  winner_id          uuid references users(id),
  loser_id           uuid references users(id),
  is_draw            boolean not null default false,

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  finished_at        timestamptz,

  constraint chk_different_players check (player1_id <> player2_id)
);

comment on table matches is 'Aktif ve bitmis maclar. Durum degisiklikleri sadece fonksiyonlarla yapilir.';

create index if not exists idx_matches_p1 on matches (player1_id) where status = 'active';
create index if not exists idx_matches_p2 on matches (player2_id) where status = 'active';
create index if not exists idx_matches_status on matches (status, updated_at desc);
-- Sure asimi taramasi icin
create index if not exists idx_matches_deadline on matches (turn_deadline) where status = 'active';

drop trigger if exists trg_matches_updated_at on matches;
create trigger trg_matches_updated_at
  before update on matches
  for each row execute function set_updated_at();

-- Envanterdeki kilit kolonuna artik yabanci anahtar verebiliriz
alter table user_cards
  drop constraint if exists fk_user_cards_locked_match;
alter table user_cards
  add constraint fk_user_cards_locked_match
  foreign key (locked_match_id) references matches(id) on delete set null;

-- ---------------------------------------------------------------------
-- MACTAKI OYUNCU BILGILERI
-- ---------------------------------------------------------------------
create table if not exists match_players (
  match_id            uuid not null references matches(id) on delete cascade,
  user_id             uuid not null references users(id)   on delete cascade,
  deck_id             uuid not null references decks(id),

  -- Maca girerken korumaya alinan kartlar (en fazla users.protection_slots kadar)
  protected_card_ids  uuid[] not null default '{}',

  -- Bu macta kazanilan (masadan toplanan) kartlar
  captured_card_ids   uuid[] not null default '{}',

  timeout_count       int not null default 0,

  primary key (match_id, user_id)
);

create index if not exists idx_match_players_user on match_players (user_id);

-- ---------------------------------------------------------------------
-- OYUNCUNUN ELI
-- ---------------------------------------------------------------------
-- Bu tabloya sadece backend erisir. Backend, bir oyuncuya ASLA rakibin
-- satirlarini gondermez (bkz. get_my_hand fonksiyonu).
create table if not exists match_hands (
  match_id      uuid not null references matches(id)    on delete cascade,
  user_id       uuid not null references users(id)      on delete cascade,
  user_card_id  uuid not null references user_cards(id) on delete cascade,

  -- Kart taniminin anlik kopyasi. Katalog sonradan dengelenirse
  -- devam eden macin sonucu degismesin diye burada dondurulur.
  card_id       uuid not null references cards(id),
  position      card_position not null,
  tier          card_tier not null,
  power         int not null,

  is_played     boolean not null default false,
  played_round  int,

  primary key (match_id, user_card_id)
);

comment on table match_hands is
  'GIZLI VERI: Oyuncularin eli. Backend disinda kimse okumaz.';

create index if not exists idx_match_hands_lookup
  on match_hands (match_id, user_id, is_played);

-- ---------------------------------------------------------------------
-- HAMLE GECMISI (acik bilgi - iki oyuncu da gorebilir)
-- ---------------------------------------------------------------------
create table if not exists match_moves (
  id            bigint generated always as identity primary key,
  match_id      uuid not null references matches(id) on delete cascade,
  user_id       uuid not null references users(id)   on delete cascade,
  round_number  int not null,

  -- NULL ise oyuncu "bu pozisyonda kartim yok" diyerek turu kaybetmistir
  user_card_id  uuid references user_cards(id),
  card_id       uuid references cards(id),
  position      card_position,
  tier          card_tier,
  power         int,

  is_lead       boolean not null,   -- turu bu hamle mi acti?
  is_pass       boolean not null default false,

  created_at    timestamptz not null default now(),

  unique (match_id, round_number, user_id)
);

create index if not exists idx_match_moves_match on match_moves (match_id, round_number);

-- ---------------------------------------------------------------------
-- TUR SONUCLARI (animasyon ve mac ozeti icin)
-- ---------------------------------------------------------------------
create table if not exists match_rounds (
  match_id      uuid not null references matches(id) on delete cascade,
  round_number  int not null,
  winner_id     uuid references users(id),   -- NULL = beraberlik
  is_draw       boolean not null default false,
  cards_won     uuid[] not null default '{}',
  resolved_at   timestamptz not null default now(),
  primary key (match_id, round_number)
);

-- ---------------------------------------------------------------------
-- ESLESTIRME KUYRUGU
-- ---------------------------------------------------------------------
-- user_id PRIMARY KEY oldugu icin bir oyuncu kuyruga iki kez giremez.
create table if not exists matchmaking_queue (
  user_id             uuid primary key references users(id) on delete cascade,
  deck_id             uuid not null references decks(id) on delete cascade,

  protected_card_ids  uuid[] not null default '{}',
  mmr                 int not null,

  status              queue_status not null default 'searching',

  -- Eslesme bulundugunda buraya mac ID'si yazilir.
  -- Backend bunu NOTIFY ile bekleyen oyuncuya WebSocket uzerinden bildirir.
  match_id            uuid references matches(id) on delete set null,

  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists idx_queue_searching
  on matchmaking_queue (status, mmr, created_at) where status = 'searching';

drop trigger if exists trg_queue_updated_at on matchmaking_queue;
create trigger trg_queue_updated_at
  before update on matchmaking_queue
  for each row execute function set_updated_at();
