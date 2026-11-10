-- =====================================================================
-- 031 EKONOMI V2 — FAZ 1: SANDIK FONKSIYONLARI + MAC SONU TETIKLEYICISI
-- =====================================================================
-- Tasarim: docs/EKONOMI_V2_TASARIM.md §1, §6, §7, §9.
--
-- DOKUNULMAYANLAR: _finish_match (007), play_card / _resolve_round,
-- kart kaybi, galibiyet altini, MMR, koruma hakki, paketler.
-- Sandik, matches.status -> 'finished' gecisinde AYRI bir AFTER UPDATE
-- tetikleyicisiyle verilir (022'deki MMR fotografiyla ayni yontem).
-- Tetikleyicide hata olursa mac sonucu ETKILENMEZ (economy_errors).
--
-- Ozellik anahtari 'economy_v2_enabled' kapaliyken hicbir sandik
-- uretilmez.
-- Tekrar calistirilabilir.
-- =====================================================================

-- ---------------------------------------------------------------------
-- YARDIMCILAR
-- ---------------------------------------------------------------------
create or replace function _chest_rules()
returns jsonb language sql stable as $$ select economy_config('chest_rules') $$;

-- Agirlikli anahtar sec (secure_random_int; sira: anahtar adina gore,
-- tekrarlanabilir)
create or replace function _roll_key(p_weights jsonb)
returns text
language plpgsql volatile as $$
declare
  v_toplam  int;
  v_zar     int;
  v_birikim int := 0;
  r         record;
begin
  select coalesce(sum(value::int), 0) into v_toplam from jsonb_each_text(p_weights);
  if v_toplam <= 0 then
    raise exception 'Agirlik tablosu gecersiz: %', p_weights;
  end if;
  v_zar := secure_random_int(v_toplam);
  for r in select key, value::int as w from jsonb_each_text(p_weights) where value::int > 0 order by key loop
    v_birikim := v_birikim + r.w;
    if v_zar <= v_birikim then
      return r.key;
    end if;
  end loop;
  return null;  -- ulasilamaz
end;
$$;

-- Aralikta guvenli rastgele tamsayi [lo, hi]
create or replace function _rand_between(p_lo int, p_hi int)
returns int language sql volatile as $$
  select p_lo + secure_random_int(greatest(p_hi - p_lo + 1, 1)) - 1
$$;

-- KADRO KILIDI KORUMASI: formasyon ihtiyaci + yedek altinda kalan
-- mevkiler (fiziksel kart sayisina gore)
create or replace function _squad_missing_positions(p_user_id uuid)
returns card_position[]
language sql stable as $$
  with ihtiyac as (
    select key::card_position as pos,
           value::int + coalesce((_chest_rules() ->> 'squad_spare')::int, 1) as gerek
    from jsonb_each_text(_chest_rules() -> 'squad_need')
  ), sahip as (
    select c.position as pos, count(*) as n
    from user_cards uc join cards c on c.id = uc.card_id
    where uc.owner_id = p_user_id
    group by c.position
  )
  select coalesce(array_agg(i.pos order by i.pos), '{}')
  from ihtiyac i left join sahip s on s.pos = i.pos
  where coalesce(s.n, 0) < i.gerek
$$;

-- Nadirlikte (istege bagli mevkide) kart sec; drop_weight agirlikli
-- (paketlerin _pick_card'i ile ayni yontem, ayri fonksiyon)
create or replace function _chest_pick_card(p_tier card_tier, p_position card_position)
returns uuid
language plpgsql volatile as $$
declare
  v uuid;
begin
  select id into v from cards
  where is_active and tier = p_tier and (p_position is null or position = p_position)
  order by -ln(random()) / greatest(drop_weight, 1)
  limit 1;
  if v is null and p_position is not null then
    -- O nadirlikte o mevkiden kart yoksa: mevkiyi koru, nadirligi birak
    select id into v from cards
    where is_active and position = p_position
    order by abs(tier_rank(tier) - tier_rank(p_tier)), -ln(random()) / greatest(drop_weight, 1)
    limit 1;
  end if;
  return v;
end;
$$;

-- ---------------------------------------------------------------------
-- SANDIK VER (mac, Battle Pass, etkinlik...). Doner: sandik kimligi.
-- Ayni kaynak iki kez sandik uretmez (unique).
-- ---------------------------------------------------------------------
create or replace function _grant_chest(
  p_user_id     uuid,
  p_type        text,
  p_source_type text,
  p_source_id   text
)
returns uuid
language plpgsql as $$
declare
  k         jsonb := _chest_rules();
  v_surum   int   := economy_config_version('chest_rules');
  v_id      uuid;
  v_yuva    int;
  v_posta   int;
  v_telafi  int;
begin
  if k -> 'types' -> p_type is null then
    raise exception 'Bilinmeyen sandik turu: %', p_type;
  end if;

  select id into v_id from user_chests
  where source_type = p_source_type and source_id = p_source_id and user_id = p_user_id;
  if v_id is not null then
    return v_id;  -- zaten verilmis
  end if;

  -- Ayni oyuncunun yuva hesabini sirala (iki odul ayni yuvaya dusmesin)
  perform pg_advisory_xact_lock(hashtext('user_chests:' || p_user_id::text));

  if p_type = 'bronze' then
    insert into user_chests (user_id, chest_type, rules_version, source_type, source_id, status, location)
    values (p_user_id, p_type, v_surum, p_source_type, p_source_id, 'ready', 'instant')
    on conflict (source_type, source_id, user_id) do nothing
    returning id into v_id;
  else
    select min(n) into v_yuva
    from generate_series(1, (k ->> 'slots')::int) n
    where not exists (select 1 from user_chests
                      where user_id = p_user_id and location = 'slot' and slot_no = n
                        and status in ('sealed', 'unlocking'));
    if v_yuva is not null then
      insert into user_chests (user_id, chest_type, rules_version, source_type, source_id, status, location, slot_no)
      values (p_user_id, p_type, v_surum, p_source_type, p_source_id, 'sealed', 'slot', v_yuva)
      on conflict (source_type, source_id, user_id) do nothing
      returning id into v_id;
    else
      select count(*) into v_posta from user_chests
      where user_id = p_user_id and location = 'mailbox' and status = 'sealed';
      if v_posta < (k ->> 'mailbox_capacity')::int then
        insert into user_chests (user_id, chest_type, rules_version, source_type, source_id, status, location)
        values (p_user_id, p_type, v_surum, p_source_type, p_source_id, 'sealed', 'mailbox')
        on conflict (source_type, source_id, user_id) do nothing
        returning id into v_id;
      else
        -- GUVENLI TELAFI: sandik kaybolmaz, altina doner (deftere yazilir)
        v_telafi := (k -> 'types' -> p_type ->> 'compensation')::int;
        insert into user_chests (user_id, chest_type, rules_version, source_type, source_id, status, location,
                                 result, opened_at)
        values (p_user_id, p_type, v_surum, p_source_type, p_source_id, 'compensated', 'mailbox',
                jsonb_build_object('compensation_coins', v_telafi, 'reason', 'mailbox_full'), now())
        on conflict (source_type, source_id, user_id) do nothing
        returning id into v_id;
        if v_id is not null then
          perform _ledger_add(p_user_id, 'chest_compensation', v_telafi,
                              jsonb_build_object('chest_type', p_type, 'reason', 'mailbox_full'),
                              'chest', v_id::text, 'chest_comp:' || v_id);
        end if;
      end if;
    end if;
  end if;

  if v_id is null then
    -- Yaris: ayni anda baska bir islem verdi
    select id into v_id from user_chests
    where source_type = p_source_type and source_id = p_source_id and user_id = p_user_id;
    return v_id;
  end if;

  -- Gercek zamanli bildirim (kopan baglanti GET /api/chests ile toparlar)
  perform pg_notify('economy_events', json_build_object(
    'event', 'chest_granted', 'user_id', p_user_id, 'chest_id', v_id,
    'chest_type', p_type, 'source_type', p_source_type, 'source_id', p_source_id,
    'at', now())::text);
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------
-- MAC SANDIGI: enerji + sanssizlik korumasi + tur secimi
-- ---------------------------------------------------------------------
create or replace function _grant_match_chest(p_user_id uuid, p_match_id uuid, p_result text)
returns uuid
language plpgsql as $$
declare
  k       jsonb := _chest_rules();
  v_tur   text;
  s       user_chest_state%rowtype;
  v_id    uuid;
begin
  -- Zaten verildiyse (tetikleyici tekrari) hicbir sey harcama
  select id into v_id from user_chests
  where source_type = 'match' and source_id = p_match_id::text and user_id = p_user_id;
  if v_id is not null then
    return v_id;
  end if;

  -- ODUL ENERJISI: yoksa sandik yok (mac ve diger oduller aynen)
  if not _reward_energy_spend(p_user_id) then
    perform _ledger_add(p_user_id, 'chest_skipped_no_energy', 0,
                        jsonb_build_object('match_id', p_match_id),
                        'match', p_match_id::text, 'chest_skip:' || p_match_id || ':' || p_user_id);
    return null;
  end if;

  v_tur := _roll_key(k -> 'type_odds' -> p_result);

  -- Sanssizlik korumasi
  insert into user_chest_state (user_id) values (p_user_id) on conflict do nothing;
  select * into s from user_chest_state where user_id = p_user_id for update;
  if s.since_legend + 1 >= (k -> 'pity' ->> 'legend_after')::int then
    v_tur := 'legend';
  elsif s.since_gold + 1 >= (k -> 'pity' ->> 'gold_after')::int and v_tur in ('bronze', 'silver') then
    v_tur := 'gold';
  end if;
  update user_chest_state
  set since_legend = case when v_tur = 'legend' then 0 else since_legend + 1 end,
      since_gold   = case when v_tur in ('gold', 'legend') then 0 else since_gold + 1 end,
      updated_at   = now()
  where user_id = p_user_id;

  return _grant_chest(p_user_id, v_tur, 'match', p_match_id::text);
end;
$$;

-- ---------------------------------------------------------------------
-- MAC BITINCE (AFTER UPDATE tetikleyicisi)
-- ---------------------------------------------------------------------
create or replace function _economy_on_match_finished()
returns trigger
language plpgsql as $$
declare
  v_tur    int;
  p        uuid;
  v_sonuc  text;
begin
  if not economy_flag('economy_v2_enabled') then
    return null;
  end if;

  -- K6: 4. turdan once biten macta (erken teslim, AFK) sandik yok
  select count(*) into v_tur from match_rounds where match_id = new.id;
  if v_tur < coalesce((_chest_rules() ->> 'min_rounds')::int, 4) then
    return null;
  end if;

  foreach p in array array[new.player1_id, new.player2_id] loop
    v_sonuc := case when new.is_draw then 'draw'
                    when new.winner_id = p then 'win'
                    else 'loss' end;
    begin
      perform _grant_match_chest(p, new.id, v_sonuc);
    exception when others then
      -- Mac sonucu ASLA bozulmaz; hata kaydedilir, sonra onarilir
      insert into economy_errors (context, user_id, source_id, error)
      values ('grant_match_chest', p, new.id::text, sqlerrm);
    end;
  end loop;
  return null;
end;
$$;

drop trigger if exists trg_economy_match_finished on matches;
create trigger trg_economy_match_finished
  after update of status on matches
  for each row
  when (new.status = 'finished' and old.status is distinct from 'finished')
  execute function _economy_on_match_finished();

-- Hatali kalan mac sandiklarini yeniden dener (yonetici / zamanlayici)
create or replace function repair_match_chests()
returns int
language plpgsql as $$
declare
  e   economy_errors%rowtype;
  m   matches%rowtype;
  n   int := 0;
begin
  for e in select * from economy_errors
           where context = 'grant_match_chest' and resolved_at is null
           order by id limit 100 loop
    select * into m from matches where id = e.source_id::uuid;
    begin
      perform _grant_match_chest(e.user_id, m.id,
        case when m.is_draw then 'draw' when m.winner_id = e.user_id then 'win' else 'loss' end);
      update economy_errors set resolved_at = now() where id = e.id;
      n := n + 1;
    exception when others then
      null;  -- bir sonraki denemede
    end;
  end loop;
  return n;
end;
$$;

-- ---------------------------------------------------------------------
-- SANDIK LISTESI
-- ---------------------------------------------------------------------
create or replace function _chest_json(c user_chests)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'id', c.id, 'chest_type', c.chest_type, 'rules_version', c.rules_version,
    'status', case when c.status = 'unlocking' and c.unlock_ready_at <= now() then 'ready' else c.status end,
    'location', c.location, 'slot_no', c.slot_no,
    'source_type', c.source_type, 'source_id', c.source_id,
    'unlock_seconds', (_chest_rules() -> 'types' -> c.chest_type ->> 'unlock_seconds')::int,
    'unlock_started_at', c.unlock_started_at, 'unlock_ready_at', c.unlock_ready_at,
    'opened_at', c.opened_at, 'result', c.result, 'created_at', c.created_at)
$$;

create or replace function list_chests(p_user_id uuid)
returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'slots', coalesce((select jsonb_agg(_chest_json(c) order by c.slot_no)
                       from user_chests c
                       where c.user_id = p_user_id and c.location = 'slot'
                         and c.status in ('sealed', 'unlocking')), '[]'),
    'instant', coalesce((select jsonb_agg(_chest_json(c) order by c.created_at)
                         from user_chests c
                         where c.user_id = p_user_id and c.location = 'instant' and c.status = 'ready'), '[]'),
    'mailbox', coalesce((select jsonb_agg(_chest_json(c) order by c.created_at)
                         from user_chests c
                         where c.user_id = p_user_id and c.location = 'mailbox' and c.status = 'sealed'), '[]'),
    'slot_count', (_chest_rules() ->> 'slots')::int,
    'mailbox_capacity', (_chest_rules() ->> 'mailbox_capacity')::int,
    'mailbox_days', (_chest_rules() ->> 'mailbox_days')::int,
    'rules_version', economy_config_version('chest_rules'),
    'enabled', economy_flag('economy_v2_enabled'),
    'energy', reward_energy_state(p_user_id),
    'server_time', now())
$$;

-- Belirli bir kaynagin (mac) sandigi: mac sonu ekrani icin
create or replace function get_source_chest(p_user_id uuid, p_source_type text, p_source_id text)
returns jsonb
language sql stable as $$
  select coalesce(
    (select _chest_json(c) from user_chests c
     where c.user_id = p_user_id and c.source_type = p_source_type and c.source_id = p_source_id),
    case when exists (select 1 from economy_ledger l
                      where l.user_id = p_user_id and l.entry_type = 'chest_skipped_no_energy'
                        and l.source_type = p_source_type and l.source_id = p_source_id)
         then jsonb_build_object('skipped', 'no_energy') end)
$$;

-- ---------------------------------------------------------------------
-- KILIT ACMAYI BASLAT (ayni anda tek sandik)
-- ---------------------------------------------------------------------
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
    return _chest_json(c);  -- zaten basladi (tekrar istek)
  end if;
  if c.location <> 'slot' or c.status <> 'sealed' then
    raise exception 'chest_not_lockable: Bu sandigin kilidi acilamaz.';
  end if;
  if exists (select 1 from user_chests where user_id = p_user_id and status = 'unlocking') then
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
-- SANDIGI AC: sonuc SUNUCUDA cekilir, satira yazilir, TEK SEFER
-- ---------------------------------------------------------------------
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
  j          record;
  v_ledger   bigint;
  v_result   jsonb;
begin
  perform pg_advisory_xact_lock(hashtext('user_chests:' || p_user_id::text));
  select * into c from user_chests where id = p_chest_id and user_id = p_user_id for update;
  if not found then
    raise exception 'chest_not_found: Sandik bulunamadi.';
  end if;
  if c.status = 'opened' then
    return c.result;  -- TEKRAR ACMA: ayni sonuc
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

  -- Sandik, URETILDIGI surumun kurallariyla acilir
  select payload into k from economy_config_versions
  where kind = 'chest_rules' and version = c.rules_version;
  t := k -> 'types' -> c.chest_type;

  -- ---- 3 FUTBOLCU ----
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
      v_sonuc := 'squad_guard';   -- kadro kilidi korumasi: fiziksel kart
    else
      v_sonuc := 'copy';
    end if;

    if v_sonuc in ('new', 'squad_guard') then
      insert into user_cards (owner_id, card_id) values (p_user_id, v_kart);
      insert into player_progress (user_id, card_id) values (p_user_id, v_kart)
      on conflict do nothing;
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

  -- ---- ALTIN + JOKER ----
  v_altin := _rand_between((t -> 'coins' ->> 0)::int, (t -> 'coins' ->> 1)::int);
  v_joker := coalesce(t -> 'jokers', '{}');
  for j in select key, value::int as n from jsonb_each_text(v_joker) loop
    insert into user_joker_shards (user_id, tier, amount) values (p_user_id, j.key::card_tier, j.n)
    on conflict (user_id, tier) do update
      set amount = user_joker_shards.amount + j.n, updated_at = now();
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

-- ---------------------------------------------------------------------
-- POSTA KUTUSUNDAN YUVAYA TASI
-- ---------------------------------------------------------------------
create or replace function claim_mailbox_chest(p_user_id uuid, p_chest_id uuid)
returns jsonb
language plpgsql as $$
declare
  c      user_chests%rowtype;
  v_yuva int;
begin
  perform pg_advisory_xact_lock(hashtext('user_chests:' || p_user_id::text));
  select * into c from user_chests where id = p_chest_id and user_id = p_user_id for update;
  if not found then
    raise exception 'chest_not_found: Sandik bulunamadi.';
  end if;
  if c.location = 'slot' then
    return _chest_json(c);  -- zaten tasinmis (tekrar istek)
  end if;
  if c.location <> 'mailbox' or c.status <> 'sealed' then
    raise exception 'chest_not_in_mailbox: Bu sandik posta kutusunda degil.';
  end if;
  select min(n) into v_yuva
  from generate_series(1, (_chest_rules() ->> 'slots')::int) n
  where not exists (select 1 from user_chests
                    where user_id = p_user_id and location = 'slot' and slot_no = n
                      and status in ('sealed', 'unlocking'));
  if v_yuva is null then
    raise exception 'slots_full: Bos yuva yok. Once bir sandik ac.';
  end if;
  update user_chests set location = 'slot', slot_no = v_yuva where id = c.id returning * into c;
  return _chest_json(c);
end;
$$;

-- ---------------------------------------------------------------------
-- POSTA OMRU DOLANLAR -> GUVENLI TELAFI (zamanlayici saatte bir)
-- ---------------------------------------------------------------------
create or replace function expire_mailbox_chests()
returns int
language plpgsql as $$
declare
  c       user_chests%rowtype;
  v_altin int;
  n       int := 0;
begin
  for c in select * from user_chests
           where location = 'mailbox' and status = 'sealed'
             and created_at < now() - make_interval(days => coalesce((_chest_rules() ->> 'mailbox_days')::int, 7))
           order by created_at
           limit 500
           for update skip locked loop
    select (payload -> 'types' -> c.chest_type ->> 'compensation')::int into v_altin
    from economy_config_versions where kind = 'chest_rules' and version = c.rules_version;
    update user_chests
    set status = 'compensated', opened_at = now(),
        result = jsonb_build_object('compensation_coins', v_altin, 'reason', 'mailbox_expired')
    where id = c.id;
    perform _ledger_add(c.user_id, 'chest_compensation', v_altin,
                        jsonb_build_object('chest_type', c.chest_type, 'reason', 'mailbox_expired'),
                        'chest', c.id::text, 'chest_comp:' || c.id);
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- Kullaniciya gosterilecek olasilik tablosu (aktif ya da istenen surum)
create or replace function chest_odds_public(p_version int default null)
returns jsonb
language sql stable as $$
  select jsonb_build_object(
    'version', v.version, 'active_from', v.active_from,
    'types', v.payload -> 'types', 'type_odds', v.payload -> 'type_odds',
    'slot_odds', v.payload -> 'slot_odds', 'pity', v.payload -> 'pity',
    'weight_total', 1000)
  from economy_config_versions v
  where v.kind = 'chest_rules'
    and v.version = coalesce(p_version, economy_config_version('chest_rules'))
$$;
