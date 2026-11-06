-- =====================================================================
-- 025: OZGUN KARAKTER KATALOGU (Asama A1)
-- =====================================================================
-- Plan: docs/KARAKTER_SISTEMI_PLANI.md
--
-- BU MIGRATION MEVCUT OYUNU DEGISTIRMEZ:
--   * Hicbir kartin kimligi, gucu, mevkisi, seviyesi degismez.
--   * Sahiplik (user_cards), kadrolar (deck_cards), maclar dokunulmaz.
--   * cards.character_id eklenir ama HICBIR karta deger atanmaz.
--   * Mevcut kart kimlikleri, ilerideki gecis icin ARSIVLENIR (kopya).
--
-- TEMEL GUVENCE: characters tablosunda GUC SUTUNU YOK.
-- Yapay zeka karakterin kimligini ve oyun tarzini onerir; guc ve
-- ozellikleri deterministik Denge Motoru belirler ve sadece
-- character_card_proposals tablosuna ONERI olarak yazilir. Bir onerinin
-- oyuna (cards) girmesi ayri bir gecis migration'i ve kullanici onayi
-- gerektirir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) KATALOG SURUMLERI
-- ---------------------------------------------------------------------
create table if not exists catalog_versions (
  version       text primary key check (version ~ '^v[0-9]+(-[a-z0-9]+)*$'),
  status        text not null check (status in ('draft', 'review', 'published', 'retired')),
  notes         text not null default '',
  created_at    timestamptz not null default now(),
  published_at  timestamptz
);

insert into catalog_versions (version, status, notes, published_at) values
  ('v1', 'published',
   'Mevcut 100 kart. 6 Legend gercek kisi adi tasiyor; gecis bekliyor.', now()),
  ('v2-ozgun', 'draft',
   'Ozgun karakter katalogu (taslak, oyunda gorunmez).', null)
on conflict (version) do nothing;

-- ---------------------------------------------------------------------
-- 2) KURGU DUNYA (gercek lig/kulup markalari yerine)
-- ---------------------------------------------------------------------
create table if not exists fictional_regions (
  code             text primary key check (code ~ '^[A-Z]{3}$'),
  name             text not null unique check (length(name) between 2 and 40),
  catalog_version  text not null references catalog_versions(version),
  created_at       timestamptz not null default now()
);

create table if not exists fictional_leagues (
  code             text primary key check (code ~ '^[A-Z0-9_]{2,16}$'),
  name             text not null unique check (length(name) between 2 and 40),
  region_code      text not null references fictional_regions(code),
  catalog_version  text not null references catalog_versions(version),
  created_at       timestamptz not null default now()
);

create table if not exists fictional_clubs (
  code             text primary key check (code ~ '^[A-Z0-9_]{2,16}$'),
  name             text not null unique check (length(name) between 2 and 40),
  league_code      text not null references fictional_leagues(code),
  primary_color    text not null check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  secondary_color  text not null check (secondary_color ~ '^#[0-9A-Fa-f]{6}$'),
  catalog_version  text not null references catalog_versions(version),
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3) KARAKTERLER — GUC SUTUNU YOK (bilincli)
-- ---------------------------------------------------------------------
create table if not exists characters (
  id                  uuid primary key default gen_random_uuid(),
  slug                text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug) <= 60),
  catalog_version     text not null references catalog_versions(version),

  given_name          text not null check (length(given_name) between 2 and 20),
  family_name         text not null check (length(family_name) between 2 and 24),
  display_name        text not null unique check (length(display_name) between 3 and 40),

  region_code         text not null references fictional_regions(code),
  club_code           text not null references fictional_clubs(code),

  primary_position    card_position not null,
  secondary_position  card_position check (secondary_position is distinct from primary_position),

  playstyle           text not null check (playstyle in (
    'hizli_kanat', 'bitirici_golcu', 'hedef_santrafor', 'yaratici_forvet',
    'oyun_kurucu', 'box_to_box', 'top_kesici', 'teknik_orta_saha',
    'kurt_stoper', 'oyun_kuran_stoper', 'hucumcu_bek', 'savunmaci_bek',
    'cizgi_kalecisi', 'libero_kaleci')),

  personality         jsonb not null check (jsonb_typeof(personality) = 'array'
                                            and jsonb_array_length(personality) between 2 and 5),
  bio_short           text not null check (length(bio_short) between 20 and 160),
  bio_long            text not null check (length(bio_long) between 80 and 1200),
  appearance          jsonb not null check (jsonb_typeof(appearance) = 'object'),
  visual_prompt       text not null check (length(visual_prompt) between 40 and 1500),
  animation_profile   text not null check (animation_profile in ('sakin', 'dengeli', 'gosterisci', 'lider')),

  status              text not null default 'draft'
                      check (status in ('draft', 'in_review', 'approved', 'published', 'retired')),

  -- Kim/ne uretti (izlenebilirlik)
  created_by          text not null check (created_by in ('ai', 'ai_assisted', 'human')),
  generator           text not null,
  generator_model     text,
  prompt_version      text,

  reviewed_by         text,
  reviewed_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists idx_characters_status on characters (status, catalog_version);

-- ---------------------------------------------------------------------
-- 4) DENGE MOTORU ONERISI (oyuna GIRMEMIS)
-- ---------------------------------------------------------------------
-- Guc ve ozellikleri yapay zeka degil packages/content_pipeline
-- icindeki deterministik BalanceEngine uretir. Bu tablo sadece onerdir;
-- cards tablosuna gecis ayri migration + onay gerektirir.
create table if not exists character_card_proposals (
  character_id            uuid primary key references characters(id) on delete cascade,
  tier                    card_tier not null,
  power                   int not null check (power between 1 and 99),
  shooting                int not null check (shooting between 1 and 99),
  pace                    int not null check (pace between 1 and 99),
  physical                int not null check (physical between 1 and 99),
  defending               int not null check (defending between 1 and 99),
  dribbling               int not null check (dribbling between 1 and 99),
  acceleration            int not null check (acceleration between 1 and 99),
  slot                    text not null,
  balance_engine_version  text not null,
  created_at              timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 5) GORSEL / 3B VARLIKLAR
-- ---------------------------------------------------------------------
create table if not exists character_assets (
  id                  uuid primary key default gen_random_uuid(),
  character_id        uuid not null references characters(id) on delete cascade,
  kind                text not null check (kind in (
    'reference_sheet', 'portrait', 'card_art', 'model_glb', 'rig', 'anim_clip', 'sprite_sheet')),
  version             int not null check (version >= 1),
  -- Animasyon klibinin adi (kind = 'anim_clip' icin zorunlu)
  clip_name           text,
  skeleton_id         text,

  uri                 text not null check (length(uri) between 3 and 500),
  sha256              text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  mime                text not null,
  width               int,
  height              int,
  bytes               bigint check (bytes is null or bytes > 0),

  -- Uretim izi (tekrar uretimde kimlik kaymasini onlemek icin)
  generator           text not null,
  generator_model     text,
  prompt              text,
  negative_prompt     text,
  seed                bigint,
  params              jsonb not null default '{}'::jsonb,
  style_ref_version   text,
  reference_asset_id  uuid references character_assets(id),

  -- Lisans ZORUNLU: kaynagi belli olmayan varlik oyuna giremez
  license             text not null check (length(license) >= 3),

  status              text not null default 'generated'
                      check (status in ('generated', 'in_review', 'approved', 'rejected')),
  reviewed_by         text,
  reviewed_at         timestamptz,
  rejection_reason    text,
  created_at          timestamptz not null default now(),

  check (kind <> 'anim_clip' or clip_name is not null),
  check (status <> 'rejected' or rejection_reason is not null)
);

create unique index if not exists uq_character_assets_version
  on character_assets (character_id, kind, coalesce(clip_name, ''), version);

-- Pozisyon basina gereken animasyon klipleri (plan bolum 8)
create table if not exists animation_clip_requirements (
  position   card_position not null,
  clip_name  text not null,
  primary key (position, clip_name)
);

insert into animation_clip_requirements (position, clip_name)
select p::card_position, c
from (values
  ('GK', 'idle'), ('GK', 'walk'), ('GK', 'run'), ('GK', 'win'), ('GK', 'lose'),
  ('GK', 'save'), ('GK', 'dive'), ('GK', 'catch'),
  ('DEF', 'idle'), ('DEF', 'walk'), ('DEF', 'run'), ('DEF', 'win'), ('DEF', 'lose'),
  ('DEF', 'jockey'), ('DEF', 'tackle'), ('DEF', 'steal'),
  ('MID', 'idle'), ('MID', 'walk'), ('MID', 'run'), ('MID', 'win'), ('MID', 'lose'),
  ('MID', 'pass'), ('MID', 'control'), ('MID', 'dribble'), ('MID', 'intercept'),
  ('FWD', 'idle'), ('FWD', 'walk'), ('FWD', 'run'), ('FWD', 'win'), ('FWD', 'lose'),
  ('FWD', 'dribble'), ('FWD', 'shoot'), ('FWD', 'celebrate'), ('FWD', 'tackle')
) as t(p, c)
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 6) INCELEME KAYDI
-- ---------------------------------------------------------------------
create table if not exists content_review_log (
  id         bigserial primary key,
  entity     text not null check (entity in ('character', 'asset')),
  entity_id  uuid not null,
  action     text not null,
  actor      text not null,
  reason     text,
  at         timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 7) MEVCUT KARTLAR: baglanti sutunu + kimlik arsivi (DEGISIKLIK YOK)
-- ---------------------------------------------------------------------
alter table cards add column if not exists character_id uuid references characters(id);

create table if not exists cards_identity_archive (
  card_id      uuid primary key references cards(id),
  slug         text not null,
  full_name    text not null,
  position     card_position not null,
  tier         card_tier not null,
  power        int not null,
  nationality  text,
  league       text,
  club         text,
  image_url    text,
  archived_at  timestamptz not null default now()
);

-- Yalnizca KOPYA: kartlarin kendisine dokunulmaz
insert into cards_identity_archive
  (card_id, slug, full_name, position, tier, power, nationality, league, club, image_url)
select id, slug, full_name, position, tier, power, nationality, league, club, image_url
from cards
on conflict (card_id) do nothing;

-- ---------------------------------------------------------------------
-- 8) KURALLAR: onayli varlik ve yayinlanmis kimlik DEGISTIRILEMEZ
-- ---------------------------------------------------------------------
create or replace function _guard_approved_asset()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if old.status = 'approved' then
      raise exception 'Onayli varlik silinemez; yeni surum ekleyin.';
    end if;
    return old;
  end if;

  if old.status = 'approved' and (
       new.uri, new.sha256, new.kind, new.version, new.character_id,
       coalesce(new.clip_name, ''), coalesce(new.prompt, ''),
       coalesce(new.seed, 0), new.params, new.license)
     is distinct from (
       old.uri, old.sha256, old.kind, old.version, old.character_id,
       coalesce(old.clip_name, ''), coalesce(old.prompt, ''),
       coalesce(old.seed, 0), old.params, old.license)
  then
    raise exception 'Onayli varlik degistirilemez; yeni surum ekleyin.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_approved_asset on character_assets;
create trigger trg_guard_approved_asset
  before update or delete on character_assets
  for each row execute function _guard_approved_asset();

create or replace function _guard_published_character()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  if old.status in ('published', 'retired') and (
       new.slug, new.given_name, new.family_name, new.display_name,
       new.primary_position, new.region_code, new.club_code, new.playstyle)
     is distinct from (
       old.slug, old.given_name, old.family_name, old.display_name,
       old.primary_position, old.region_code, old.club_code, old.playstyle)
  then
    raise exception 'Yayinlanmis karakterin kimligi degistirilemez.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_guard_published_character on characters;
create trigger trg_guard_published_character
  before update on characters
  for each row execute function _guard_published_character();

-- ---------------------------------------------------------------------
-- 9) INCELEME AKISI (durum makinesi)
-- ---------------------------------------------------------------------
--   draft --submit--> in_review --approve--> approved --publish--> published --retire--> retired
--                     in_review --reject (gerekce zorunlu)--> draft
create or replace function review_character(
  p_character_id uuid,
  p_action       text,
  p_actor        text,
  p_reason       text default null
)
returns text
language plpgsql
as $$
declare
  v_status text;
  v_yeni   text;
begin
  select status into v_status from characters where id = p_character_id for update;
  if v_status is null then
    raise exception 'Karakter bulunamadi.';
  end if;
  if coalesce(trim(p_actor), '') = '' then
    raise exception 'Inceleyen belirtilmeli.';
  end if;

  v_yeni := case
    when p_action = 'submit'  and v_status = 'draft'     then 'in_review'
    when p_action = 'approve' and v_status = 'in_review' then 'approved'
    when p_action = 'reject'  and v_status = 'in_review' then 'draft'
    when p_action = 'publish' and v_status = 'approved'  then 'published'
    when p_action = 'retire'  and v_status = 'published' then 'retired'
  end;

  if v_yeni is null then
    raise exception 'Gecersiz gecis: % durumundaki karakter icin %.', v_status, p_action;
  end if;
  if p_action = 'reject' and coalesce(trim(p_reason), '') = '' then
    raise exception 'Reddetmek icin gerekce zorunlu.';
  end if;
  if p_action = 'publish' and not exists (
       select 1 from character_card_proposals where character_id = p_character_id) then
    raise exception 'Denge Motoru onerisi olmayan karakter yayinlanamaz.';
  end if;
  if p_action = 'publish' and not exists (
       select 1 from character_assets
       where character_id = p_character_id and kind = 'portrait' and status = 'approved') then
    raise exception 'Onayli portresi olmayan karakter yayinlanamaz.';
  end if;

  update characters
  set status = v_yeni,
      reviewed_by = p_actor,
      reviewed_at = now()
  where id = p_character_id;

  insert into content_review_log (entity, entity_id, action, actor, reason)
  values ('character', p_character_id, p_action, p_actor, p_reason);

  return v_yeni;
end;
$$;

-- ---------------------------------------------------------------------
-- 10) SUNUM MODU: karakter arenada NASIL gosterilebilir?
-- ---------------------------------------------------------------------
-- '3d'     : onayli model + rig + pozisyonun BUTUN klipleri onayli
-- 'sprite' : onayli sprite sayfasi var
-- '2.5d'   : yedek (mevcut ArenaBackdrop / ClashScene)
-- Eksik olan her sey listelenir; hicbir sey "tamam" gibi gosterilmez.
create or replace function character_presentation(p_character_id uuid)
returns jsonb
language plpgsql
stable
as $$
declare
  c          characters%rowtype;
  v_portre   text;
  v_model    text;
  v_rig      text;
  v_sprite   text;
  v_klipler  text[];
  v_eksik    text[];
  v_mod      text;
begin
  select * into c from characters where id = p_character_id;
  if not found then
    raise exception 'Karakter bulunamadi.';
  end if;

  select uri into v_portre from character_assets
  where character_id = c.id and kind = 'portrait' and status = 'approved'
  order by version desc limit 1;

  select uri into v_model from character_assets
  where character_id = c.id and kind = 'model_glb' and status = 'approved'
  order by version desc limit 1;

  select uri into v_rig from character_assets
  where character_id = c.id and kind = 'rig' and status = 'approved'
  order by version desc limit 1;

  select uri into v_sprite from character_assets
  where character_id = c.id and kind = 'sprite_sheet' and status = 'approved'
  order by version desc limit 1;

  select coalesce(array_agg(distinct clip_name order by clip_name), '{}') into v_klipler
  from character_assets
  where character_id = c.id and kind = 'anim_clip' and status = 'approved';

  select coalesce(array_agg(r.clip_name order by r.clip_name), '{}') into v_eksik
  from animation_clip_requirements r
  where r.position = c.primary_position
    and not (r.clip_name = any (v_klipler));

  v_mod := case
    when v_model is not null and v_rig is not null and cardinality(v_eksik) = 0 then '3d'
    when v_sprite is not null then 'sprite'
    else '2.5d'
  end;

  return jsonb_build_object(
    'character_id',   c.id,
    'mode',           v_mod,
    'portrait_uri',   v_portre,
    'model_uri',      v_model,
    'rig_uri',        v_rig,
    'sprite_uri',     v_sprite,
    'approved_clips', to_jsonb(v_klipler),
    'missing_clips',  to_jsonb(v_eksik),
    'missing_assets', to_jsonb(array_remove(array[
        case when v_portre is null then 'portrait' end,
        case when v_model  is null then 'model_glb' end,
        case when v_rig    is null then 'rig' end], null))
  );
end;
$$;
