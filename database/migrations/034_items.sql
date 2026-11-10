-- =====================================================================
-- 034 EKONOMI V2 — FAZ 3: ITEM KATALOGU VE ENVANTER
-- =====================================================================
-- Tasarim: docs/EKONOMI_V2_TASARIM.md §4.
--
-- Tur (kind) kurallari:
--   stackable  : miktar >= 0, max_stack asilamaz; fazlasi altina doner
--   consumable : kullanim tek islem: miktar -1 + etki + defter (idempotent)
--   timed      : expires_at sunucu saatiyle; suresi dolan kullanilamaz,
--                gosterilmez ama SILINMEZ (denetim)
--   cosmetic   : kalici, miktar 1; tekrar gelirse altina doner; giyilir
--
-- HICBIR ITEM DERECELI MACTA GUC VERMEZ (K1). Mac fonksiyonlarina
-- dokunulmaz.
--
-- Joker parcalar (030: user_joker_shards) item envanterine KAYIPSIZ
-- tasinir; eski tablo SILINMEZ, user_joker_shards_legacy adiyla kalir.
-- Tekrar calistirilabilir.
-- =====================================================================

create table if not exists item_definitions (
  slug              text primary key check (slug ~ '^[a-z0-9_]+$'),
  kind              text not null check (kind in ('stackable', 'consumable', 'timed', 'cosmetic')),
  category          text not null check (category ~ '^[a-z_]+$'),
  name              text not null,
  description       text not null,
  max_stack         int  check (max_stack is null or max_stack > 0),
  duration_seconds  int  check (duration_seconds is null or duration_seconds > 0),
  -- Kozmetik: giyildigi yuva (frame, kit, card_skin, arena, victory, character, badge)
  cosmetic_slot     text,
  -- Kapasite tasmasi / tekrar kozmetik icin birim basina telafi altini
  overflow_coins    int not null default 0 check (overflow_coins >= 0),
  params            jsonb not null default '{}'::jsonb,
  sort_order        int not null default 0,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  check (kind <> 'cosmetic' or cosmetic_slot is not null),
  check (kind <> 'timed' or duration_seconds is not null)
);

comment on table item_definitions is 'Ekonomi V2 item katalogu (034). Hicbir item dereceli guc vermez.';

insert into item_definitions (slug, kind, category, name, description, max_stack, duration_seconds, cosmetic_slot, overflow_coins, params, sort_order) values
  ('chest_key', 'consumable', 'chest_key', 'Sandık anahtarı',
   'Yuvadaki bir sandığın kilidini anında açar. Efsane sandık 2 anahtar ister.', 10, null, null, 60, '{"legend_cost": 2}', 10),
  ('chest_speedup_2h', 'consumable', 'chest_speedup', 'Sandık hızlandırıcı (2 sa)',
   'Kilidi açılan sandığın kalan süresinden 2 saat düşer.', 20, null, null, 30, '{"seconds": 7200}', 20),
  ('energy_drink', 'consumable', 'energy_drink', 'Enerji içeceği',
   '+3 ödül enerjisi. Günde en fazla 2 kez kullanılır.', 10, null, null, 20, '{"energy": 3, "daily_limit": 2}', 30),
  ('mastery_book_bronze',  'consumable', 'mastery_book', 'Ustalık kitabı (Bronz)',
   'Bir Bronz futbolcuya bir seviyelik gelişim kopyası verir; altın yine ödenir.', 50, null, null, 20,  '{"tier": "bronze"}', 40),
  ('mastery_book_silver',  'consumable', 'mastery_book', 'Ustalık kitabı (Gümüş)',
   'Bir Gümüş futbolcuya bir seviyelik gelişim kopyası verir; altın yine ödenir.', 50, null, null, 40,  '{"tier": "silver"}', 41),
  ('mastery_book_gold',    'consumable', 'mastery_book', 'Ustalık kitabı (Altın)',
   'Bir Altın futbolcuya bir seviyelik gelişim kopyası verir; altın yine ödenir.', 50, null, null, 80,  '{"tier": "gold"}', 42),
  ('mastery_book_diamond', 'consumable', 'mastery_book', 'Ustalık kitabı (Elmas)',
   'Bir Elmas futbolcuya bir seviyelik gelişim kopyası verir; altın yine ödenir.', 50, null, null, 150, '{"tier": "diamond"}', 43),
  ('mastery_book_legend',  'consumable', 'mastery_book', 'Ustalık kitabı (Efsane)',
   'Bir Efsane futbolcuya bir seviyelik gelişim kopyası verir; altın yine ödenir.', 50, null, null, 300, '{"tier": "legend"}', 44),
  ('joker_bronze',  'stackable', 'joker', 'Joker parça (Bronz)',  'Bronz futbolcularda eksik gelişim kopyasının yerine geçer.',  9999, null, null, 0, '{"tier": "bronze"}', 50),
  ('joker_silver',  'stackable', 'joker', 'Joker parça (Gümüş)',  'Gümüş futbolcularda eksik gelişim kopyasının yerine geçer.',  9999, null, null, 0, '{"tier": "silver"}', 51),
  ('joker_gold',    'stackable', 'joker', 'Joker parça (Altın)',  'Altın futbolcularda eksik gelişim kopyasının yerine geçer.',  9999, null, null, 0, '{"tier": "gold"}', 52),
  ('joker_diamond', 'stackable', 'joker', 'Joker parça (Elmas)',  'Elmas futbolcularda eksik gelişim kopyasının yerine geçer.',  9999, null, null, 0, '{"tier": "diamond"}', 53),
  ('joker_legend',  'stackable', 'joker', 'Joker parça (Efsane)', 'Efsane futbolcularda eksik gelişim kopyasının yerine geçer.', 9999, null, null, 0, '{"tier": "legend"}', 54),
  ('level_discount_25', 'timed', 'level_discount', 'Gelişim indirimi (%25)',
   'Sonraki seviye atlamanın altınına %25 indirim. Tek kullanım, 7 gün geçerli.', null, 604800, null, 0, '{"percent": 25}', 60),
  ('event_ticket', 'timed', 'event_ticket', 'Etkinlik bileti',
   'Etkinlik moduna 1 giriş (etkinlikler yakında). 30 gün geçerli.', null, 2592000, null, 0, '{}', 70),
  ('frame_season1', 'cosmetic', 'profile_frame', 'Profil çerçevesi: Sezon 1', 'Profil avatarının çevresinde sezon çerçevesi.', null, null, 'frame', 150, '{}', 80),
  ('kit_season1', 'cosmetic', 'kit', 'Forma: Sezon 1', '2D karakterlerin forması (yüz kimliği değişmez).', null, null, 'kit', 150, '{}', 81),
  ('card_skin_night', 'cosmetic', 'card_skin', 'Kart görünümü: Gece Işığı', 'Kart arka planı; nadirlik rengi korunur.', null, null, 'card_skin', 200, '{}', 82),
  ('arena_rainy_night', 'cosmetic', 'arena_skin', 'Arena görünümü: Yağmurlu Gece', 'Stadyum teması (yalnız kendi ekranında).', null, null, 'arena', 200, '{}', 83),
  ('victory_fireworks', 'cosmetic', 'victory_anim', 'Zafer animasyonu: Havai Fişek', 'Maç sonu zafer efekti.', null, null, 'victory', 200, '{}', 84),
  ('captain_band', 'cosmetic', 'character_cosmetic', 'Karakter kozmetiği: Kaptan Bandı', 'Kaptan bandı (2D karakter).', null, null, 'character', 150, '{}', 85),
  ('badge_s1_bronze', 'cosmetic', 'season_badge', 'Sezon 1 rozeti (bronz)', 'Profil rozeti.', null, null, 'badge', 100, '{"season": 1}', 90),
  ('badge_s1_gold', 'cosmetic', 'season_badge', 'Sezon 1 rozeti (altın)', 'Profil rozeti.', null, null, 'badge', 200, '{"season": 1}', 91)
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------
-- ENVANTER
-- ---------------------------------------------------------------------
create table if not exists user_items (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references users(id) on delete cascade,
  item_slug     text not null references item_definitions(slug),
  quantity      int  not null default 0 check (quantity >= 0),
  -- Yalniz 'timed': her kazanim ayri satir, kendi suresiyle
  expires_at    timestamptz,
  acquired_via  text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Sureli olmayanlar oyuncu basina TEK satir (miktar)
create unique index if not exists uq_user_items_stack
  on user_items (user_id, item_slug) where expires_at is null;
create index if not exists idx_user_items_user on user_items (user_id);

-- Giyilen kozmetikler (yuva basina bir)
create table if not exists user_equipped (
  user_id      uuid not null references users(id) on delete cascade,
  slot         text not null,
  item_slug    text not null references item_definitions(slug),
  equipped_at  timestamptz not null default now(),
  primary key (user_id, slot)
);

-- ---------------------------------------------------------------------
-- JOKER PARCALARINI KAYIPSIZ TASI (030 user_joker_shards -> user_items)
-- ---------------------------------------------------------------------
do $$
begin
  if to_regclass('public.user_joker_shards') is not null then
    insert into user_items (user_id, item_slug, quantity, acquired_via)
    select user_id, 'joker_' || tier::text, amount, 'migration_034'
    from user_joker_shards where amount > 0
    on conflict (user_id, item_slug) where expires_at is null
      do update set quantity = user_items.quantity + excluded.quantity, updated_at = now();

    if to_regclass('public.user_joker_shards_legacy') is null then
      -- Ilk kez: tablo SILINMEZ, eski adla saklanir (denetim)
      alter table user_joker_shards rename to user_joker_shards_legacy;
      comment on table user_joker_shards_legacy is
        '034 ile user_items''a tasindi. SADECE denetim icin; yazilmaz.';
    else
      -- Migration'lar ikinci kez calistirildiginda 030 tabloyu bos yeniden
      -- olusturur; satirlari yukarida tasindi, bos kabuk kaldirilir.
      drop table user_joker_shards;
    end if;
  end if;
end;
$$;

-- ---------------------------------------------------------------------
-- YARDIMCILAR
-- ---------------------------------------------------------------------
create or replace function _item_qty(p_user_id uuid, p_slug text)
returns int language sql stable as $$
  select coalesce(sum(quantity), 0)::int from user_items
  where user_id = p_user_id and item_slug = p_slug
    and (expires_at is null or expires_at > now())
$$;

-- Item ekle (tur kurallariyla). Doner: {added, overflow_coins}
-- Defter kaydini CAGIRAN yazar (kaynak ve anahtar onda).
create or replace function _item_add(p_user_id uuid, p_slug text, p_qty int, p_via text)
returns jsonb
language plpgsql as $$
declare
  d        item_definitions%rowtype;
  v_var    int;
  v_eklenen int;
  v_tasan  int := 0;
begin
  select * into d from item_definitions where slug = p_slug and is_active;
  if not found then
    raise exception 'item_not_found: Item bulunamadi: %', p_slug;
  end if;
  if p_qty is null or p_qty < 1 then
    raise exception 'invalid_count: Gecersiz adet.';
  end if;

  if d.kind = 'timed' then
    insert into user_items (user_id, item_slug, quantity, expires_at, acquired_via)
    select p_user_id, p_slug, 1, now() + make_interval(secs => d.duration_seconds), p_via
    from generate_series(1, p_qty);
    return jsonb_build_object('added', p_qty, 'overflow_coins', 0);
  end if;

  if d.kind = 'cosmetic' then
    if exists (select 1 from user_items where user_id = p_user_id and item_slug = p_slug and quantity > 0) then
      v_tasan := p_qty;   -- tekrar kozmetik: hepsi altina
      v_eklenen := 0;
    else
      insert into user_items (user_id, item_slug, quantity, acquired_via) values (p_user_id, p_slug, 1, p_via)
      on conflict (user_id, item_slug) where expires_at is null do update set quantity = 1, updated_at = now();
      v_eklenen := 1;
      v_tasan := p_qty - 1;
    end if;
  else
    insert into user_items (user_id, item_slug, quantity, acquired_via) values (p_user_id, p_slug, 0, p_via)
    on conflict (user_id, item_slug) where expires_at is null do nothing;
    select quantity into v_var from user_items
    where user_id = p_user_id and item_slug = p_slug and expires_at is null for update;
    v_eklenen := least(p_qty, greatest(coalesce(d.max_stack, 2147483647) - v_var, 0));
    v_tasan := p_qty - v_eklenen;
    update user_items set quantity = quantity + v_eklenen, updated_at = now()
    where user_id = p_user_id and item_slug = p_slug and expires_at is null;
  end if;

  return jsonb_build_object('added', v_eklenen, 'overflow', v_tasan,
                            'overflow_coins', v_tasan * d.overflow_coins);
end;
$$;

-- Item dus (yetersizse hata). Sureli itemlerde en erken bitecek once.
create or replace function _item_take(p_user_id uuid, p_slug text, p_qty int)
returns void
language plpgsql as $$
declare
  r    record;
  v_kalan int := p_qty;
  v_al int;
begin
  if _item_qty(p_user_id, p_slug) < p_qty then
    raise exception 'not_enough_items: Yeterli item yok.';
  end if;
  for r in select id, quantity from user_items
           where user_id = p_user_id and item_slug = p_slug and quantity > 0
             and (expires_at is null or expires_at > now())
           order by expires_at nulls last, id
           for update loop
    exit when v_kalan <= 0;
    v_al := least(r.quantity, v_kalan);
    update user_items set quantity = quantity - v_al, updated_at = now() where id = r.id;
    v_kalan := v_kalan - v_al;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- ITEM VER (Battle Pass, etkinlik, yonetici). Idempotent: p_key.
-- ---------------------------------------------------------------------
create or replace function grant_item(p_user_id uuid, p_slug text, p_qty int,
                                      p_source_type text, p_source_id text, p_key text)
returns jsonb
language plpgsql as $$
declare
  v_sonuc jsonb;
  v_eski  economy_ledger%rowtype;
begin
  perform pg_advisory_xact_lock(hashtext('user_items:' || p_user_id::text));
  select * into v_eski from economy_ledger where idempotency_key = 'item_grant:' || p_key;
  if found then
    return v_eski.items || jsonb_build_object('replay', true);
  end if;
  v_sonuc := _item_add(p_user_id, p_slug, p_qty, p_source_type);
  perform _ledger_add(p_user_id, 'item_grant', coalesce((v_sonuc ->> 'overflow_coins')::int, 0),
    jsonb_build_object('slug', p_slug, 'qty', p_qty) || v_sonuc,
    p_source_type, p_source_id, 'item_grant:' || p_key);
  return jsonb_build_object('slug', p_slug, 'qty', p_qty) || v_sonuc;
end;
$$;

-- ---------------------------------------------------------------------
-- SANDIK ANAHTARI ICIN: anahtarla acilan sandik "tek kilit" sayimina
-- girmez (baska sandigin sayaci calisirken de anahtar kullanilabilsin)
-- ---------------------------------------------------------------------
alter table user_chests add column if not exists unlocked_by_item boolean not null default false;
drop index if exists uq_user_chests_one_unlocking;
create unique index if not exists uq_user_chests_one_unlocking
  on user_chests (user_id)
  where status = 'unlocking' and not unlocked_by_item;

create or replace function start_chest_unlock(p_user_id uuid, p_chest_id uuid)
returns jsonb
language plpgsql as $$
declare
  c        user_chests%rowtype;
  v_saniye int;
begin
  perform pg_advisory_xact_lock(hashtext('user_chests:' || p_user_id::text));
  select * into c from user_chests where id = p_chest_id and user_id = p_user_id for update;
  if not found then
    raise exception 'chest_not_found: Sandik bulunamadi.';
  end if;
  if c.status = 'unlocking' then
    return _chest_json(c);
  end if;
  if c.location <> 'slot' or c.status <> 'sealed' then
    raise exception 'chest_not_lockable: Bu sandigin kilidi acilamaz.';
  end if;
  if exists (select 1 from user_chests where user_id = p_user_id and status = 'unlocking' and not unlocked_by_item) then
    raise exception 'chest_already_unlocking: Ayni anda yalniz bir sandigin kilidi acilir.';
  end if;
  v_saniye := (_chest_rules() -> 'types' -> c.chest_type ->> 'unlock_seconds')::int;
  update user_chests
  set status = 'unlocking', unlock_started_at = now(),
      unlock_ready_at = now() + make_interval(secs => v_saniye)
  where id = c.id
  returning * into c;
  return _chest_json(c);
end;
$$;

-- ---------------------------------------------------------------------
-- ITEM KULLAN. p_target: {"chest_id": ...} | {"card_id": ...} | {}
-- p_request_key: istemcinin istek kimligi (tekrar istek ikinci kez kullanmaz)
-- ---------------------------------------------------------------------
create or replace function use_item(p_user_id uuid, p_slug text, p_target jsonb, p_request_key text)
returns jsonb
language plpgsql as $$
declare
  d        item_definitions%rowtype;
  v_eski   economy_ledger%rowtype;
  c        user_chests%rowtype;
  v_kart   cards%rowtype;
  p        player_progress%rowtype;
  v_adet   int := 1;
  v_sonuc  jsonb;
  v_bugun  int;
  v_maliyet jsonb;
begin
  if not economy_flag('economy_v2_enabled') then
    raise exception 'economy_disabled: Bu ozellik henuz acik degil.';
  end if;
  perform pg_advisory_xact_lock(hashtext('user_items:' || p_user_id::text));
  select * into v_eski from economy_ledger where idempotency_key = 'item_use:' || p_user_id || ':' || p_request_key;
  if found then
    return v_eski.items -> 'result' || jsonb_build_object('replay', true);
  end if;

  select * into d from item_definitions where slug = p_slug and is_active;
  if not found then
    raise exception 'item_not_found: Item bulunamadi.';
  end if;

  case d.category
  when 'chest_key' then
    perform pg_advisory_xact_lock(hashtext('user_chests:' || p_user_id::text));
    select * into c from user_chests where id = (p_target ->> 'chest_id')::uuid and user_id = p_user_id for update;
    if not found then
      raise exception 'chest_not_found: Sandik bulunamadi.';
    end if;
    if c.location <> 'slot' or c.status not in ('sealed', 'unlocking')
       or (c.status = 'unlocking' and c.unlock_ready_at <= now()) then
      raise exception 'item_not_applicable: Bu sandiga anahtar kullanilamaz.';
    end if;
    v_adet := case when c.chest_type = 'legend' then coalesce((d.params ->> 'legend_cost')::int, 2) else 1 end;
    perform _item_take(p_user_id, p_slug, v_adet);
    update user_chests
    set status = 'unlocking', unlocked_by_item = true,
        unlock_started_at = coalesce(unlock_started_at, now()), unlock_ready_at = now()
    where id = c.id;
    v_sonuc := jsonb_build_object('chest_id', c.id, 'chest_ready', true);

  when 'chest_speedup' then
    perform pg_advisory_xact_lock(hashtext('user_chests:' || p_user_id::text));
    select * into c from user_chests
    where user_id = p_user_id and status = 'unlocking' and unlock_ready_at > now()
      and (p_target ->> 'chest_id' is null or id = (p_target ->> 'chest_id')::uuid)
    order by unlock_ready_at limit 1 for update;
    if not found then
      raise exception 'item_not_applicable: Kilidi acilan bir sandik yok.';
    end if;
    perform _item_take(p_user_id, p_slug, 1);
    update user_chests
    set unlock_ready_at = greatest(now(), unlock_ready_at - make_interval(secs => (d.params ->> 'seconds')::int))
    where id = c.id
    returning * into c;
    v_sonuc := jsonb_build_object('chest_id', c.id, 'unlock_ready_at', c.unlock_ready_at,
                                  'chest_ready', c.unlock_ready_at <= now());

  when 'energy_drink' then
    select count(*) into v_bugun from economy_ledger
    where user_id = p_user_id and entry_type = 'item_use' and items ->> 'slug' = p_slug
      and created_at >= date_trunc('day', now());
    if v_bugun >= coalesce((d.params ->> 'daily_limit')::int, 2) then
      raise exception 'daily_limit: Bugun bu itemi en fazla % kez kullanabilirsin.', (d.params ->> 'daily_limit');
    end if;
    perform _item_take(p_user_id, p_slug, 1);
    v_sonuc := jsonb_build_object('energy', _reward_energy_add(p_user_id, (d.params ->> 'energy')::int));

  when 'mastery_book' then
    select * into v_kart from cards where id = (p_target ->> 'card_id')::uuid;
    if not found or v_kart.tier::text <> (d.params ->> 'tier') then
      raise exception 'item_not_applicable: Bu kitap bu futbolcuya kullanilamaz (nadirlik).';
    end if;
    if not exists (select 1 from user_cards where owner_id = p_user_id and card_id = v_kart.id) then
      raise exception 'card_not_owned: Bu futbolcu koleksiyonunda yok.';
    end if;
    insert into player_progress (user_id, card_id) values (p_user_id, v_kart.id) on conflict do nothing;
    select * into p from player_progress where user_id = p_user_id and card_id = v_kart.id for update;
    v_maliyet := _level_cost(v_kart.tier, p.level);
    if v_maliyet is null then
      raise exception 'max_level: Futbolcu en yuksek seviyede.';
    end if;
    perform _item_take(p_user_id, p_slug, 1);
    update player_progress set copies = copies + (v_maliyet ->> 'copies')::int, updated_at = now()
    where user_id = p_user_id and card_id = v_kart.id;
    v_sonuc := jsonb_build_object('card_id', v_kart.id, 'copies_added', (v_maliyet ->> 'copies')::int);

  else
    -- Joker (seviye atlarken), indirim (seviye atlarken), etkinlik bileti
    -- (etkinlikler yok), kozmetik (giyilir) dogrudan kullanilmaz
    raise exception 'item_not_usable: Bu item dogrudan kullanilmaz.';
  end case;

  perform _ledger_add(p_user_id, 'item_use', 0,
    jsonb_build_object('slug', p_slug, 'qty', v_adet, 'target', coalesce(p_target, '{}'::jsonb), 'result', v_sonuc),
    'item', p_slug, 'item_use:' || p_user_id || ':' || p_request_key);
  return v_sonuc;
end;
$$;

-- ---------------------------------------------------------------------
-- KOZMETIK GIY / CIKAR
-- ---------------------------------------------------------------------
create or replace function equip_cosmetic(p_user_id uuid, p_slug text)
returns jsonb
language plpgsql as $$
declare
  d item_definitions%rowtype;
begin
  select * into d from item_definitions where slug = p_slug;
  if not found or d.kind <> 'cosmetic' then
    raise exception 'item_not_applicable: Bu item giyilemez.';
  end if;
  if _item_qty(p_user_id, p_slug) < 1 then
    raise exception 'not_enough_items: Bu kozmetige sahip degilsin.';
  end if;
  insert into user_equipped (user_id, slot, item_slug) values (p_user_id, d.cosmetic_slot, p_slug)
  on conflict (user_id, slot) do update set item_slug = excluded.item_slug, equipped_at = now();
  return jsonb_build_object('slot', d.cosmetic_slot, 'item_slug', p_slug);
end;
$$;

create or replace function unequip_cosmetic(p_user_id uuid, p_slot text)
returns jsonb
language plpgsql as $$
begin
  delete from user_equipped where user_id = p_user_id and slot = p_slot;
  return jsonb_build_object('slot', p_slot, 'item_slug', null);
end;
$$;

-- ---------------------------------------------------------------------
-- ENVANTER GORUNUMU (katalog + sahip olunanlar + giyilenler)
-- ---------------------------------------------------------------------
create or replace function item_inventory(p_user_id uuid)
returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'catalog', coalesce((select jsonb_agg(jsonb_build_object(
        'slug', d.slug, 'kind', d.kind, 'category', d.category, 'name', d.name, 'description', d.description,
        'max_stack', d.max_stack, 'duration_seconds', d.duration_seconds, 'cosmetic_slot', d.cosmetic_slot,
        'overflow_coins', d.overflow_coins, 'params', d.params, 'sort_order', d.sort_order)
      order by d.sort_order) from item_definitions d where d.is_active), '[]'::jsonb),
    'items', coalesce((select jsonb_agg(jsonb_build_object(
        'slug', x.item_slug, 'quantity', x.q, 'expires_at', x.e) order by x.item_slug, x.e)
      from (select item_slug, sum(quantity)::int q, expires_at e from user_items
            where user_id = p_user_id and quantity > 0 and (expires_at is null or expires_at > now())
            group by item_slug, expires_at) x), '[]'::jsonb),
    'equipped', coalesce((select jsonb_object_agg(slot, item_slug) from user_equipped where user_id = p_user_id), '{}'::jsonb),
    'energy_drinks_today', (select count(*)::int from economy_ledger
      where user_id = p_user_id and entry_type = 'item_use' and items ->> 'slug' = 'energy_drink'
        and created_at >= date_trunc('day', now())),
    'enabled', economy_flag('economy_v2_enabled'),
    'server_time', now())
$$;

-- Gelistirme: yerel test icin item ver (sunucu yalniz production DISINDA cagirir)
create or replace function dev_grant_item(p_user_id uuid, p_slug text, p_qty int)
returns jsonb
language sql as $$
  select grant_item(p_user_id, p_slug, p_qty, 'dev', 'dev', 'dev:' || gen_random_uuid())
$$;

-- =====================================================================
-- JOKER OKUYAN / YAZAN FONKSIYONLAR: user_items'a gecis
-- (open_chest, level_up_player, player_progress_overview — 033'ten AYNEN,
--  yalniz joker kaynagi degisti; level_up_player'a %25 indirim eklendi)
-- =====================================================================
create or replace function _joker_qty(p_user_id uuid, p_tier card_tier)
returns int language sql stable as $$ select _item_qty(p_user_id, 'joker_' || p_tier::text) $$;

create or replace function player_progress_overview(p_user_id uuid)
returns jsonb
language sql stable as $$
  with sahip as (
    select card_id, count(*)::int as n from user_cards where owner_id = p_user_id group by card_id
  ), satir as (
    select c.id, c.slug, c.full_name, c.position, c.tier, c.power, c.club, c.nationality, c.image_url,
           coalesce(pp.level, 1) as level, coalesce(pp.copies, 0) as copies, coalesce(s.n, 0) as owned
    from cards c
    left join player_progress pp on pp.card_id = c.id and pp.user_id = p_user_id
    left join sahip s on s.card_id = c.id
    where s.n is not null or pp.user_id is not null
  ), joker as (
    select coalesce(jsonb_object_agg(t::text, _joker_qty(p_user_id, t)) filter (where _joker_qty(p_user_id, t) > 0),
                    '{}'::jsonb) j
    from unnest(enum_range(null::card_tier)) t
  )
  select jsonb_build_object(
    'items', coalesce((select jsonb_agg(jsonb_build_object(
        'card_id', s.id, 'slug', s.slug, 'full_name', s.full_name, 'position', s.position, 'tier', s.tier,
        'power', s.power, 'club', s.club, 'nationality', s.nationality, 'image_url', s.image_url,
        'level', s.level, 'copies', s.copies, 'owned_copies', s.owned,
        'convertible_copies', case when s.owned > 0 then _convertible_copies(p_user_id, s.id) else 0 end,
        'next', _level_cost(s.tier, s.level),
        'jokers_available', coalesce(((select j from joker) ->> s.tier::text)::int, 0),
        'books_available', _item_qty(p_user_id, 'mastery_book_' || s.tier::text))
      order by s.level desc, tier_rank(s.tier) desc, s.power desc) from satir s), '[]'::jsonb),
    'jokers', (select j from joker),
    'discounts', _item_qty(p_user_id, 'level_discount_25'),
    'coins', (select coins from users where id = p_user_id),
    'rules_version', economy_config_version('level_rules'),
    'max_level', coalesce((_level_rules() ->> 'max_level')::int, 10),
    'convert_keep', coalesce((_level_rules() ->> 'convert_keep')::int, 2),
    'mastery', _level_rules() -> 'mastery',
    'affects_ranked_power', false,
    'enabled', economy_flag('economy_v2_enabled'))
$$;

drop function if exists level_up_player(uuid, uuid, boolean);
create or replace function level_up_player(p_user_id uuid, p_card_id uuid, p_use_jokers boolean default false,
                                           p_use_discount boolean default false)
returns jsonb
language plpgsql as $$
declare
  c         cards%rowtype;
  p         player_progress%rowtype;
  v_maliyet jsonb;
  v_gerek   int;
  v_altin   int;
  v_eksik   int;
  v_joker   int := 0;
  v_hedef   int;
  v_usta    jsonb;
  v_odul    int := 0;
  v_indirim int := 0;
begin
  if not economy_flag('economy_v2_enabled') then
    raise exception 'economy_disabled: Bu ozellik henuz acik degil.';
  end if;
  perform pg_advisory_xact_lock(hashtext('player_progress:' || p_user_id::text));
  perform pg_advisory_xact_lock(hashtext('user_items:' || p_user_id::text));
  select * into c from cards where id = p_card_id;
  if not found then
    raise exception 'card_not_found: Futbolcu bulunamadi.';
  end if;
  if not exists (select 1 from user_cards where owner_id = p_user_id and card_id = p_card_id) then
    raise exception 'card_not_owned: Bu futbolcu koleksiyonunda yok.';
  end if;

  insert into player_progress (user_id, card_id) values (p_user_id, p_card_id) on conflict do nothing;
  select * into p from player_progress where user_id = p_user_id and card_id = p_card_id for update;

  v_maliyet := _level_cost(c.tier, p.level);
  if v_maliyet is null then
    raise exception 'max_level: Futbolcu en yuksek seviyede.';
  end if;
  v_gerek := (v_maliyet ->> 'copies')::int;
  v_altin := (v_maliyet ->> 'coins')::int;
  v_hedef := p.level + 1;

  -- %25 gelisim indirimi (034): tek kullanim, suresi dolmamis
  if p_use_discount then
    if _item_qty(p_user_id, 'level_discount_25') < 1 then
      raise exception 'not_enough_items: Gelisim indirimi yok.';
    end if;
    v_indirim := v_altin * (select coalesce((params ->> 'percent')::int, 25) from item_definitions
                            where slug = 'level_discount_25') / 100;
    v_altin := v_altin - v_indirim;
  end if;

  v_eksik := greatest(0, v_gerek - p.copies);
  if v_eksik > 0 then
    if not p_use_jokers then
      raise exception 'not_enough_copies: Yeterli gelisim kopyasi yok.';
    end if;
    if _joker_qty(p_user_id, c.tier) < v_eksik then
      raise exception 'not_enough_jokers: Yeterli joker parca yok.';
    end if;
    v_joker := v_eksik;
  end if;
  if (select coins from users where id = p_user_id) < v_altin then
    raise exception 'not_enough_coins: Yeterli altin yok.';
  end if;

  perform _ledger_add(p_user_id, 'level_up', -v_altin,
    jsonb_build_object('card_id', p_card_id, 'from', p.level, 'to', v_hedef,
                       'copies_used', v_gerek - v_joker, 'jokers_used', v_joker, 'tier', c.tier,
                       'discount', v_indirim),
    'player_progress', p_card_id::text, 'level_up:' || p_user_id || ':' || p_card_id || ':' || v_hedef);

  update player_progress
  set level = v_hedef, copies = copies - (v_gerek - v_joker), updated_at = now()
  where user_id = p_user_id and card_id = p_card_id;
  if v_joker > 0 then
    perform _item_take(p_user_id, 'joker_' || c.tier::text, v_joker);
  end if;
  if v_indirim > 0 then
    perform _item_take(p_user_id, 'level_discount_25', 1);
  end if;

  v_usta := _level_rules() -> 'mastery' -> v_hedef::text;
  if v_usta is not null then
    v_odul := coalesce((v_usta ->> 'coins')::int, 0);
    perform _ledger_add(p_user_id, 'mastery_reward', v_odul,
      jsonb_build_object('card_id', p_card_id, 'level', v_hedef),
      'player_progress', p_card_id::text, 'mastery:' || p_user_id || ':' || p_card_id || ':' || v_hedef);
  end if;

  return jsonb_build_object(
    'card_id', p_card_id, 'level', v_hedef, 'copies', p.copies - (v_gerek - v_joker),
    'coins_spent', v_altin, 'jokers_used', v_joker, 'mastery_coins', v_odul, 'discount', v_indirim,
    'next', _level_cost(c.tier, v_hedef),
    'coins_after', (select coins from users where id = p_user_id));
end;
$$;

create or replace function open_chest(p_user_id uuid, p_chest_id uuid)
returns jsonb
language plpgsql as $$
declare
  k          jsonb := _chest_rules();
  c          user_chests%rowtype;
  t          jsonb;
  v_yuva     jsonb;
  v_tier     card_tier;
  v_eksik    card_position[];
  v_pos      card_position;
  v_kart     uuid;
  v_kart_row cards%rowtype;
  v_sonuc    text;
  v_kartlar  jsonb := '[]'::jsonb;
  v_altin    int;
  v_joker    jsonb;
  v_tasma    jsonb := '{}'::jsonb;
  v_tasma_n  int;
  j          record;
  v_ledger   bigint;
  v_result   jsonb;
begin
  perform pg_advisory_xact_lock(hashtext('user_chests:' || p_user_id::text));
  perform pg_advisory_xact_lock(hashtext('user_items:' || p_user_id::text));
  select * into c from user_chests where id = p_chest_id and user_id = p_user_id for update;
  if not found then
    raise exception 'chest_not_found: Sandik bulunamadi.';
  end if;
  if c.status = 'opened' then
    return c.result;
  end if;
  if c.status = 'compensated' then
    raise exception 'chest_compensated: Bu sandik telafi altinina donustu.';
  end if;
  if c.location = 'mailbox' then
    raise exception 'chest_in_mailbox: Once posta kutusundan bos bir yuvaya tasi.';
  end if;
  if c.status = 'sealed' then
    raise exception 'chest_locked: Once kilidi ac.';
  end if;
  if c.status = 'unlocking' and c.unlock_ready_at > now() then
    raise exception 'chest_not_ready: Sandik henuz hazir degil.';
  end if;

  select payload into k from economy_config_versions
  where kind = 'chest_rules' and version = c.rules_version;
  t := k -> 'types' -> c.chest_type;

  for v_yuva in select value from jsonb_array_elements(k -> 'slot_odds' -> c.chest_type) loop
    v_tier  := _roll_key(v_yuva)::card_tier;
    v_eksik := _squad_missing_positions(p_user_id);
    v_pos   := case when cardinality(v_eksik) > 0
                    then v_eksik[secure_random_int(cardinality(v_eksik))] end;
    v_kart  := _chest_pick_card(v_tier, v_pos);
    select * into v_kart_row from cards where id = v_kart;

    if not exists (select 1 from user_cards where owner_id = p_user_id and card_id = v_kart) then
      v_sonuc := 'new';
    elsif v_pos is not null then
      v_sonuc := 'squad_guard';
    elsif coalesce((select level from player_progress where user_id = p_user_id and card_id = v_kart), 1)
          >= coalesce((_level_rules() ->> 'max_level')::int, 10) then
      v_sonuc := 'joker';
    else
      v_sonuc := 'copy';
    end if;

    if v_sonuc in ('new', 'squad_guard') then
      insert into user_cards (owner_id, card_id) values (p_user_id, v_kart);
      insert into player_progress (user_id, card_id) values (p_user_id, v_kart)
      on conflict do nothing;
    elsif v_sonuc = 'joker' then
      v_tasma_n := coalesce((_level_rules() -> 'overflow_jokers' ->> v_kart_row.tier::text)::int, 1);
      v_tasma := jsonb_set(v_tasma, array[v_kart_row.tier::text],
                           to_jsonb(coalesce((v_tasma ->> v_kart_row.tier::text)::int, 0) + v_tasma_n));
    else
      insert into player_progress (user_id, card_id, copies) values (p_user_id, v_kart, 1)
      on conflict (user_id, card_id) do update
        set copies = player_progress.copies + 1, updated_at = now();
    end if;

    v_kartlar := v_kartlar || jsonb_build_object(
      'card_id', v_kart, 'slug', v_kart_row.slug, 'full_name', v_kart_row.full_name,
      'position', v_kart_row.position, 'tier', v_kart_row.tier, 'power', v_kart_row.power,
      'club', v_kart_row.club, 'nationality', v_kart_row.nationality,
      'image_url', v_kart_row.image_url, 'outcome', v_sonuc);
  end loop;

  v_altin := _rand_between((t -> 'coins' ->> 0)::int, (t -> 'coins' ->> 1)::int);
  v_joker := coalesce(t -> 'jokers', '{}');
  for j in select key, value::int as n from jsonb_each_text(v_tasma) loop
    v_joker := jsonb_set(v_joker, array[j.key], to_jsonb(coalesce((v_joker ->> j.key)::int, 0) + j.n));
  end loop;
  -- 034: joker parcalar item envanterine
  for j in select key, value::int as n from jsonb_each_text(v_joker) loop
    perform _item_add(p_user_id, 'joker_' || j.key, j.n, 'chest');
  end loop;

  v_ledger := _ledger_add(p_user_id, 'chest_open', v_altin,
                          jsonb_build_object('chest_type', c.chest_type, 'jokers', v_joker,
                                             'cards', (select jsonb_agg(jsonb_build_object(
                                                        'card_id', x ->> 'card_id', 'outcome', x ->> 'outcome'))
                                                       from jsonb_array_elements(v_kartlar) x)),
                          'chest', c.id::text, 'chest_open:' || c.id);

  v_result := jsonb_build_object(
    'chest_id', c.id, 'chest_type', c.chest_type, 'rules_version', c.rules_version,
    'cards', v_kartlar, 'coins', v_altin, 'jokers', v_joker,
    'coins_after', (select coins from users where id = p_user_id),
    'ledger_id', v_ledger);

  update user_chests
  set status = 'opened', opened_at = now(), result = v_result
  where id = c.id;

  return v_result;
end;
$$;
