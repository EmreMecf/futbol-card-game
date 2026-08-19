-- =====================================================================
-- 004 - DESTELER (decks / deck_cards)
-- =====================================================================
-- FORMASYON ZORUNLULUGU: 1 GK + 4 DEF + 4 MID + 2 FWD = 11 kart
-- =====================================================================

create table if not exists decks (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null references users(id) on delete cascade,
  name        text not null default 'Kadrom' check (char_length(name) between 1 and 30),

  is_active   boolean not null default false,

  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Bir oyuncunun ayni anda yalnizca TEK aktif destesi olabilir
create unique index if not exists uq_decks_one_active_per_user
  on decks (owner_id) where is_active;

create index if not exists idx_decks_owner on decks (owner_id);

drop trigger if exists trg_decks_updated_at on decks;
create trigger trg_decks_updated_at
  before update on decks
  for each row execute function set_updated_at();

-- ---------------------------------------------------------------------
-- DESTEDEKI KARTLAR
-- ---------------------------------------------------------------------
create table if not exists deck_cards (
  deck_id       uuid not null references decks(id)      on delete cascade,
  user_card_id  uuid not null references user_cards(id) on delete cascade,
  created_at    timestamptz not null default now(),

  primary key (deck_id, user_card_id)
);

-- Ayni kart iki farkli destede olamaz
create unique index if not exists uq_deck_cards_user_card
  on deck_cards (user_card_id);

create index if not exists idx_deck_cards_deck on deck_cards (deck_id);

-- ---------------------------------------------------------------------
-- DESTE DOGRULAMA
-- ---------------------------------------------------------------------
-- Donus: NULL ise deste gecerlidir. Degilse Turkce hata mesaji doner.
create or replace function validate_deck(p_user_id uuid, p_deck_id uuid)
returns text
language plpgsql
stable
as $$
declare
  v_owner uuid;
  v_gk int; v_def int; v_mid int; v_fwd int;
  v_total int;
  v_not_owned int;
  v_locked int;
begin
  select owner_id into v_owner from decks where id = p_deck_id;

  if v_owner is null then
    return 'Deste bulunamadi.';
  end if;

  if v_owner <> p_user_id then
    return 'Bu deste size ait degil.';
  end if;

  select
    count(*) filter (where c.position = 'GK'),
    count(*) filter (where c.position = 'DEF'),
    count(*) filter (where c.position = 'MID'),
    count(*) filter (where c.position = 'FWD'),
    count(*),
    count(*) filter (where uc.owner_id <> p_user_id),
    count(*) filter (where uc.locked_match_id is not null)
  into v_gk, v_def, v_mid, v_fwd, v_total, v_not_owned, v_locked
  from deck_cards dc
  join user_cards uc on uc.id = dc.user_card_id
  join cards c       on c.id  = uc.card_id
  where dc.deck_id = p_deck_id;

  if v_total <> squad_size() then
    return format('Kadroda %s kart olmali, su an %s kart var.', squad_size(), v_total);
  end if;

  if v_not_owned > 0 then
    return 'Destedeki bazi kartlar artik size ait degil. Kadronuzu guncelleyin.';
  end if;

  if v_locked > 0 then
    return 'Destedeki bazi kartlar devam eden bir macta kilitli.';
  end if;

  if v_gk <> 1 then
    return format('Kadroda tam 1 kaleci olmali (su an: %s).', v_gk);
  end if;

  if v_def <> 4 then
    return format('Kadroda tam 4 defans olmali (su an: %s).', v_def);
  end if;

  if v_mid <> 4 then
    return format('Kadroda tam 4 orta saha olmali (su an: %s).', v_mid);
  end if;

  if v_fwd <> 2 then
    return format('Kadroda tam 2 forvet olmali (su an: %s).', v_fwd);
  end if;

  return null; -- Deste gecerli
end;
$$;

comment on function validate_deck(uuid, uuid) is
  '4-4-2 formasyon kuralini dogrular. NULL donerse deste gecerlidir.';
