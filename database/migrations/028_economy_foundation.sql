-- =====================================================================
-- 028 EKONOMI V2 — FAZ 0: TEMEL ALTYAPI
-- =====================================================================
-- Tasarim: docs/EKONOMI_V2_TASARIM.md (§8, §13). K1-K6 kullanici
-- tarafindan onaylandi (10 Kasim 2026).
--
-- BU MIGRATION OYUN DAVRANISINI DEGISTIRMEZ:
--   * Var olan hicbir tabloya kolon eklenmez, hicbir fonksiyon
--     degistirilmez (mac, paket, SBC, kart kaybi aynen).
--   * Ekonomi V2 bir ozellik anahtari arkasinda ve KAPALI baslar
--     (economy_v2_enabled = false).
--
-- Icerik:
--   1. economy_config_versions : surumlu ayarlar (oranlar, anahtarlar)
--   2. economy_ledger           : her odul / harcama / telafinin
--                                 degismez kaydi (denetim gunlugu)
--   3. idempotency_keys         : tekrar gelen istege ayni cevap
--   4. _ledger_add(...)          : altin degisimini deftere yazarak ve
--                                 TEK SEFER uygulayan yardimci
--
-- Tekrar calistirilabilir (if not exists / create or replace).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. SURUMLU EKONOMI AYARLARI
-- ---------------------------------------------------------------------
-- Bir ayar ASLA yerinde guncellenmez; degisiklik yeni surumdur. Boylece
-- "bu sandik hangi oranlarla acildi?" sorusunun cevabi her zaman
-- bulunur. Aktif surum: active_from <= now() olan en buyuk surum.
create table if not exists economy_config_versions (
  kind         text not null check (kind ~ '^[a-z_]+$'),
  version      int  not null check (version > 0),
  payload      jsonb not null,
  active_from  timestamptz not null default now(),
  note         text,
  created_at   timestamptz not null default now(),
  primary key (kind, version)
);

comment on table economy_config_versions is
  'Ekonomi V2 surumlu ayarlari. Yerinde UPDATE yapilmaz; yeni surum eklenir.';

-- Yayinlanmis bir surumun icerigi degistirilemez (silme de yok)
create or replace function _economy_config_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'Ekonomi ayar surumu degistirilemez; yeni surum ekleyin (% v%).',
    old.kind, old.version;
end;
$$;

drop trigger if exists trg_economy_config_immutable on economy_config_versions;
create trigger trg_economy_config_immutable
  before update or delete on economy_config_versions
  for each row execute function _economy_config_immutable();

-- Aktif ayar (yoksa null)
create or replace function economy_config(p_kind text)
returns jsonb
language sql stable as $$
  select payload from economy_config_versions
  where kind = p_kind and active_from <= now()
  order by version desc
  limit 1
$$;

create or replace function economy_config_version(p_kind text)
returns int
language sql stable as $$
  select version from economy_config_versions
  where kind = p_kind and active_from <= now()
  order by version desc
  limit 1
$$;

-- Ozellik anahtari. Tanimsiz anahtar = KAPALI (guvenli varsayilan).
create or replace function economy_flag(p_name text)
returns boolean
language sql stable as $$
  select coalesce((economy_config('feature_flags') ->> p_name)::boolean, false)
$$;

insert into economy_config_versions (kind, version, payload, note)
values ('feature_flags', 1, '{"economy_v2_enabled": false}',
        '028: Ekonomi V2 kapali baslar')
on conflict (kind, version) do nothing;

-- ---------------------------------------------------------------------
-- 2. EKONOMI DEFTERI (denetim gunlugu)
-- ---------------------------------------------------------------------
-- Her altin / item / sandik hareketi bir satir. Satirlar DEGISTIRILEMEZ
-- (UPDATE yasak). Silme yalniz hesap silinirken (users cascade) olur.
--
-- idempotency_key: ayni olay ikinci kez yazilmaya calisilirsa unique
-- kisit reddeder; _ledger_add bunu "zaten uygulanmis" olarak doner.
create table if not exists economy_ledger (
  id               bigint generated always as identity primary key,
  user_id          uuid not null references users(id) on delete cascade,
  entry_type       text not null check (entry_type ~ '^[a-z_]+$'),
  coins_delta      int  not null default 0,
  coins_after      int,
  items            jsonb not null default '{}'::jsonb,
  source_type      text not null check (source_type ~ '^[a-z_]+$'),
  source_id        text not null,
  idempotency_key  text not null unique,
  created_at       timestamptz not null default now()
);

create index if not exists idx_economy_ledger_user
  on economy_ledger (user_id, created_at desc);
create index if not exists idx_economy_ledger_source
  on economy_ledger (source_type, source_id);

comment on table economy_ledger is
  'Ekonomi V2 denetim defteri: her odul/harcama/telafi. UPDATE yasak.';

create or replace function _economy_ledger_no_update()
returns trigger language plpgsql as $$
begin
  raise exception 'Ekonomi defteri degistirilemez (kayit %).', old.id;
end;
$$;

drop trigger if exists trg_economy_ledger_no_update on economy_ledger;
create trigger trg_economy_ledger_no_update
  before update on economy_ledger
  for each row execute function _economy_ledger_no_update();

-- ---------------------------------------------------------------------
-- 3. IDEMPOTENCY ANAHTARLARI
-- ---------------------------------------------------------------------
-- Istemci degistirici her istekte Idempotency-Key gonderir. Sunucu:
--   * ilk istekte satiri 'processing' acar, isler, cevabi saklar
--   * ayni anahtar + ayni govde -> saklanan cevap
--   * ayni anahtar + farkli govde -> 409
--   * hala isleniyorsa -> 409 (istemci kisa sure sonra tekrar dener)
create table if not exists idempotency_keys (
  user_id       uuid not null references users(id) on delete cascade,
  key           text not null check (length(key) between 8 and 128),
  endpoint      text not null,
  request_hash  text not null,
  status        text not null default 'processing'
                  check (status in ('processing', 'done')),
  status_code   int,
  response      text,
  created_at    timestamptz not null default now(),
  primary key (user_id, key)
);

create index if not exists idx_idempotency_keys_created
  on idempotency_keys (created_at);

comment on table idempotency_keys is
  'Tekrar gelen degistirici istege ayni cevap (48 saat saklanir).';

-- 48 saatten eski anahtarlari temizler; sunucu zamanlayicisi cagirir
create or replace function purge_idempotency_keys()
returns int
language plpgsql as $$
declare
  v int;
begin
  delete from idempotency_keys where created_at < now() - interval '48 hours';
  get diagnostics v = row_count;
  return v;
end;
$$;

-- ---------------------------------------------------------------------
-- 4. DEFTERE YAZARAK ALTIN UYGULA (TEK SEFER)
-- ---------------------------------------------------------------------
-- Doner: defter satirinin kimligi. Ayni idempotency_key ile ikinci
-- cagri altini TEKRAR uygulamaz, ilk kaydin kimligini doner.
--
-- Sira onemli: once oyuncu satiri kilitlenir (ayni oyuncunun iki odulu
-- birbirini ezmesin), sonra defter satiri "on conflict do nothing" ile
-- eklenir; yalniz eklendiyse altin degisir.
create or replace function _ledger_add(
  p_user_id      uuid,
  p_entry_type   text,
  p_coins_delta  int,
  p_items        jsonb,
  p_source_type  text,
  p_source_id    text,
  p_key          text
)
returns bigint
language plpgsql as $$
declare
  v_coins  int;
  v_id     bigint;
  v_eski   economy_ledger%rowtype;
begin
  select coins into v_coins from users where id = p_user_id for update;
  if not found then
    raise exception 'Oyuncu bulunamadi: %', p_user_id;
  end if;

  if v_coins + coalesce(p_coins_delta, 0) < 0 then
    raise exception 'Yeterli altin yok. Gerekli: %, mevcut: %', -p_coins_delta, v_coins;
  end if;

  insert into economy_ledger
    (user_id, entry_type, coins_delta, coins_after, items, source_type, source_id, idempotency_key)
  values
    (p_user_id, p_entry_type, coalesce(p_coins_delta, 0), v_coins + coalesce(p_coins_delta, 0),
     coalesce(p_items, '{}'::jsonb), p_source_type, p_source_id, p_key)
  on conflict (idempotency_key) do nothing
  returning id into v_id;

  if v_id is null then
    -- Zaten uygulanmis. Baska bir oyuncunun/olayin anahtariyla
    -- carpisma ise bu bir programlama hatasidir: sessiz gecme.
    select * into v_eski from economy_ledger where idempotency_key = p_key;
    if v_eski.user_id <> p_user_id or v_eski.entry_type <> p_entry_type then
      raise exception 'Idempotency anahtari baska bir kayitta kullanilmis: %', p_key;
    end if;
    return v_eski.id;
  end if;

  if coalesce(p_coins_delta, 0) <> 0 then
    update users set coins = coins + p_coins_delta, updated_at = now()
    where id = p_user_id;
  end if;

  return v_id;
end;
$$;

comment on function _ledger_add is
  'Altin/item hareketini deftere yazar ve TEK SEFER uygular (idempotency_key).';
