-- =====================================================================
-- 030 EKONOMI V2 — FAZ 1: SANDIK TABLOLARI VE SURUM 1 KURALLARI
-- =====================================================================
-- Tasarim: docs/EKONOMI_V2_TASARIM.md §1, §2.1, §8.
--
-- PAKET SISTEMIYLE KARISMAZ: pack_types / pack_openings / open_pack
-- aynen; sandiklar ayri tablolarda, ayri fonksiyonlarla.
--
-- Kurallar ve olasiliklar 'chest_rules' ayar surumunde (028:
-- economy_config_versions; yayinlanan surum DEGISTIRILEMEZ). Her sandik
-- hangi surumle uretildigini saklar. Agirliklar binde (toplam 1000)
-- tamsayi: tasarimdaki %0,4 = 4.
--
-- Tekrar calistirilabilir.
-- =====================================================================

insert into economy_config_versions (kind, version, payload, note)
values ('chest_rules', 1, $json${
  "slots": 4,
  "mailbox_capacity": 8,
  "mailbox_days": 7,
  "min_rounds": 4,
  "pity": {"gold_after": 15, "legend_after": 60},
  "types": {
    "bronze": {"name": "Bronz",  "unlock_seconds": 0,     "coins": [10, 20],   "jokers": {"bronze": 1},               "compensation": 25,  "sort": 1},
    "silver": {"name": "Gümüş",  "unlock_seconds": 7200,  "coins": [30, 50],   "jokers": {"bronze": 2, "silver": 1},  "compensation": 70,  "sort": 2},
    "gold":   {"name": "Altın",  "unlock_seconds": 21600, "coins": [80, 120],  "jokers": {"silver": 2, "gold": 1},    "compensation": 180, "sort": 3},
    "legend": {"name": "Efsane", "unlock_seconds": 43200, "coins": [200, 300], "jokers": {"gold": 2, "diamond": 1},   "compensation": 450, "sort": 4}
  },
  "type_odds": {
    "win":  {"bronze": 520, "silver": 350, "gold": 110, "legend": 20},
    "draw": {"bronze": 700, "silver": 260, "gold": 40},
    "loss": {"bronze": 800, "silver": 180, "gold": 20}
  },
  "slot_odds": {
    "bronze": [{"bronze": 720, "silver": 240, "gold": 40},
               {"bronze": 720, "silver": 240, "gold": 40},
               {"bronze": 720, "silver": 240, "gold": 40}],
    "silver": [{"bronze": 500, "silver": 380, "gold": 110, "diamond": 10},
               {"bronze": 500, "silver": 380, "gold": 110, "diamond": 10},
               {"silver": 700, "gold": 260, "diamond": 36, "legend": 4}],
    "gold":   [{"bronze": 250, "silver": 420, "gold": 280, "diamond": 45, "legend": 5},
               {"bronze": 250, "silver": 420, "gold": 280, "diamond": 45, "legend": 5},
               {"gold": 820, "diamond": 160, "legend": 20}],
    "legend": [{"silver": 300, "gold": 520, "diamond": 160, "legend": 20},
               {"silver": 300, "gold": 520, "diamond": 160, "legend": 20},
               {"diamond": 850, "legend": 150}]
  },
  "squad_need": {"GK": 1, "DEF": 4, "MID": 4, "FWD": 2},
  "squad_spare": 1
}$json$::jsonb, '030: sandik kurallari surum 1 (tasarim §1)')
on conflict (kind, version) do nothing;

-- ---------------------------------------------------------------------
-- OYUNCUNUN SANDIKLARI
-- ---------------------------------------------------------------------
-- location:
--   instant : Bronz; yuvaya girmez, hemen acilabilir
--   slot    : 4 yuvadan biri (slot_no 1..4)
--   mailbox : yuvalar doluydu; bos yuvaya tasinmayi bekler
-- status:
--   sealed      : kilitli, sayac baslamadi
--   unlocking   : sayac calisiyor (unlock_ready_at <= now() ise ACILABILIR)
--   ready       : aninda acilabilir (Bronz)
--   opened      : acildi, sonuc result'ta (degismez)
--   compensated : posta kutusu dolu/suresi doldu -> telafi altini verildi
create table if not exists user_chests (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references users(id) on delete cascade,
  chest_type         text not null check (chest_type in ('bronze', 'silver', 'gold', 'legend')),
  rules_version      int  not null,
  source_type        text not null check (source_type ~ '^[a-z_]+$'),
  source_id          text not null,
  status             text not null default 'sealed'
                       check (status in ('sealed', 'unlocking', 'ready', 'opened', 'compensated')),
  location           text not null check (location in ('instant', 'slot', 'mailbox')),
  slot_no            int check (slot_no between 1 and 4),
  unlock_started_at  timestamptz,
  unlock_ready_at    timestamptz,
  opened_at          timestamptz,
  result             jsonb,
  created_at         timestamptz not null default now(),
  -- AYNI MACIN ODULU IKI KEZ ALINAMAZ
  unique (source_type, source_id, user_id)
);

create index if not exists idx_user_chests_user_active
  on user_chests (user_id, location, status)
  where status not in ('opened', 'compensated');

-- Ayni yuvada iki aktif sandik olamaz
create unique index if not exists uq_user_chests_slot
  on user_chests (user_id, slot_no)
  where location = 'slot' and status in ('sealed', 'unlocking');

-- Ayni anda yalniz BIR sandigin sayaci calisir (bitmis sayaclar da bu
-- satirdadir; open_chest acinca satir 'opened' olur ve kilit kalkar)
create unique index if not exists uq_user_chests_one_unlocking
  on user_chests (user_id)
  where status = 'unlocking';

comment on table user_chests is
  'Ekonomi V2 sandiklari. Sonuc acilista sunucuda cekilir ve result''a yazilir (degismez).';

-- Sanssizlik koruma sayaclari
create table if not exists user_chest_state (
  user_id        uuid primary key references users(id) on delete cascade,
  since_gold     int not null default 0 check (since_gold >= 0),
  since_legend   int not null default 0 check (since_legend >= 0),
  updated_at     timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- FUTBOLCU GELISIMI (seviye kisiye ve futbolcuya bagli; kopyaya degil)
-- ---------------------------------------------------------------------
-- FAZ 1: sandiktan gelen ve zaten sahip olunan futbolcu 'copies' + 1
-- olur. Seviye atlama FAZ 2'de acilir (level burada hep 1).
-- Kart kaybedilse bile bu satir kalir (K2).
create table if not exists player_progress (
  user_id     uuid not null references users(id) on delete cascade,
  card_id     uuid not null references cards(id) on delete restrict,
  level       int  not null default 1 check (level between 1 and 10),
  copies      int  not null default 0 check (copies >= 0),
  updated_at  timestamptz not null default now(),
  primary key (user_id, card_id)
);

-- Kayipsiz doldurma: sahip olunan her futbolcu seviye 1, 0 kopya.
-- Fiziksel kopyalara (user_cards) DOKUNULMAZ; hicbir kart silinmez.
insert into player_progress (user_id, card_id)
select distinct owner_id, card_id from user_cards
on conflict (user_id, card_id) do nothing;

-- Joker parcalar (nadirlige ozel). FAZ 3'te item envanterine kayipsiz
-- tasinacak.
create table if not exists user_joker_shards (
  user_id    uuid not null references users(id) on delete cascade,
  tier       card_tier not null,
  amount     int not null default 0 check (amount >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, tier)
);

-- Tetikleyicide sandik verilemezse mac BOZULMAZ; hata buraya yazilir
-- ve sonradan onarilir (repair_match_chests).
create table if not exists economy_errors (
  id          bigint generated always as identity primary key,
  context     text not null,
  user_id     uuid,
  source_id   text,
  error       text not null,
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);
