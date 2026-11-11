-- =====================================================================
-- 038 EKONOMI V2 — KAYNAKSIZ 7 ITEM ICIN ODUL KAYNAKLARI (KAPALI GELIR)
-- =====================================================================
-- Onay: kullanici (10 Kasim 2026). Plan: docs/EKONOMI_V2_UYGULAMA_PLANI.md (A)
-- Denetim bulgusu: sandik anahtari, ustalik kitabi (Bronz/Gumus/Elmas/
-- Efsane), gelisim indirimi ve etkinlik bileti yalniz gelistirme ucuyla
-- veriliyordu. Bu dosya mevcut govdelerden URETILDI (migration_uret.py).
--
--   * chest_rules SURUM 2 = surum 1 + 'extras': Altin sandik %10 anahtar,
--     Efsane sandik %40 anahtar + %30 ustalik kitabi (Bronz 35 / Gumus 35 /
--     Elmas 25 / Efsane 5). Sandik kendi surumunu sakladigi icin eski
--     sandiklar ekstrasiz acilir.
--   * Haftalik "10 galibiyet" gorevi: +1 gelisim indirimi (%25, 7 gun).
--   * Etkinlik bileti: etkinlik modu gelene kadar PASIF (satir silinmez,
--     sahip olunan satirlar silinmez).
--   * Hepsi 'item_sources_v2' anahtarina bagli (037'de KAPALI eklendi).
--   * Tek sefer: grant_item defter anahtarlari (chest_extra:/mission_item:).
-- =====================================================================

insert into economy_config_versions (kind, version, payload, note)
select 'chest_rules', 2,
       payload || '{"extras": {"gold": {"chest_key": 100},
                                 "legend": {"chest_key": 400, "mastery_book": 300}},
                    "extras_book_tiers": {"bronze": 35, "silver": 35, "diamond": 25, "legend": 5}}'::jsonb,
       '038: sandik ek item odulleri (item_sources_v2 ile)'
from economy_config_versions where kind = 'chest_rules' and version = 1
on conflict (kind, version) do nothing;

alter table missions add column if not exists reward_items jsonb not null default '{}'::jsonb;
update missions set reward_items = '{"level_discount_25": 1}'::jsonb
where slug = 'weekly_win_10' and reward_items = '{}'::jsonb;

update item_definitions set is_active = false where slug = 'event_ticket' and is_active;

-- ---------------------------------------------------------------------
-- Sandik acilisi (034'ten; yalniz 038 blogu)
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
  v_tasma    jsonb := '{}'::jsonb;
  v_tasma_n  int;
  j          record;
  v_ledger   bigint;
  v_result   jsonb;
  v_ekstra   jsonb := '{}'::jsonb;   -- 038
  v_slug     text;                   -- 038
  e          record;                 -- 038
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

  -- 038: ek item odulleri (anahtar / ustalik kitabi). Yalniz sandigin
  -- KENDI kural surumunde 'extras' varsa (eski sandiklar eski kurallarla)
  -- ve 'item_sources_v2' aciksa. Tasma grant_item ile altina doner.
  if economy_flag('item_sources_v2') and k ? 'extras' then
    for e in select key, value::int as n from jsonb_each_text(coalesce(k -> 'extras' -> c.chest_type, '{}')) loop
      if secure_random_int(1000) <= e.n then
        v_slug := case when e.key = 'mastery_book'
                       then 'mastery_book_' || _roll_key(k -> 'extras_book_tiers')
                       else e.key end;
        perform grant_item(p_user_id, v_slug, 1, 'chest', c.id::text, 'chest_extra:' || c.id || ':' || e.key);
        v_ekstra := v_ekstra || jsonb_build_object(v_slug, 1);
      end if;
    end loop;
  end if;

  v_ledger := _ledger_add(p_user_id, 'chest_open', v_altin,
                          jsonb_build_object('chest_type', c.chest_type, 'jokers', v_joker,
                                             'cards', (select jsonb_agg(jsonb_build_object(
                                                        'card_id', x ->> 'card_id', 'outcome', x ->> 'outcome'))
                                                       from jsonb_array_elements(v_kartlar) x)),
                          'chest', c.id::text, 'chest_open:' || c.id);

  v_result := jsonb_build_object(
    'chest_id', c.id, 'chest_type', c.chest_type, 'rules_version', c.rules_version,
    'cards', v_kartlar, 'coins', v_altin, 'jokers', v_joker, 'extras', v_ekstra,
    'coins_after', (select coins from users where id = p_user_id),
    'ledger_id', v_ledger);

  update user_chests
  set status = 'opened', opened_at = now(), result = v_result
  where id = c.id;

  return v_result;
end;
$$;

-- ---------------------------------------------------------------------
-- Gorev olayi (035'ten; yalniz 038 blogu)
-- ---------------------------------------------------------------------
create or replace function _mission_event(p_user_id uuid, p_metric text, p_value int,
                                          p_mode text default 'add')
returns void
language plpgsql as $$
declare
  s      seasons%rowtype := _current_season();
  m      missions%rowtype;
  um     user_missions%rowtype;
  v_key  text;
  r      record;   -- 038
begin
  for m in select * from missions where metric = p_metric and is_active order by sort_order loop
    v_key := _mission_period_key(m.period, s.id);
    insert into user_missions (user_id, mission_slug, period_key)
    values (p_user_id, m.slug, v_key) on conflict do nothing;
    select * into um from user_missions
    where user_id = p_user_id and mission_slug = m.slug and period_key = v_key for update;
    if um.completed_at is not null then
      continue;
    end if;
    update user_missions
    set progress = least(m.target, case when p_mode = 'max' then greatest(progress, p_value)
                                        else progress + p_value end),
        updated_at = now()
    where user_id = p_user_id and mission_slug = m.slug and period_key = v_key
    returning * into um;
    if um.progress >= m.target then
      update user_missions set completed_at = now()
      where user_id = p_user_id and mission_slug = m.slug and period_key = v_key;
      perform _season_add_xp(p_user_id, m.xp, 'mission', m.slug || ':' || v_key,
                             'mission:' || p_user_id || ':' || m.slug || ':' || v_key);
      -- 038: gorevin item odulu (or. haftalik 10 galibiyet -> gelisim indirimi)
      if economy_flag('item_sources_v2') and m.reward_items <> '{}'::jsonb then
        for r in select key, value::int as n from jsonb_each_text(m.reward_items) loop
          perform grant_item(p_user_id, r.key, r.n, 'mission', m.slug || ':' || v_key,
                             'mission_item:' || p_user_id || ':' || m.slug || ':' || v_key || ':' || r.key);
        end loop;
      end if;
    end if;
  end loop;
end;
$$;

-- Gorevler: odul itemleri istemciye
create or replace function _mission_reward_items(p_slug text) returns jsonb
language sql stable as $$ select reward_items from missions where slug = p_slug $$;
