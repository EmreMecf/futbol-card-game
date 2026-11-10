-- =====================================================================
-- 033 EKONOMI V2 — FAZ 2: FUTBOLCU SEVIYESI, USTALIK, KOPYA DONUSUMU
-- =====================================================================
-- Tasarim: docs/EKONOMI_V2_TASARIM.md §2. Onayli kararlar:
--   K1: Seviye DERECELI MACTA KART GUCUNU DEGISTIRMEZ. Bu migration mac,
--       eslestirme, kimya ve kart kaybi fonksiyonlarina DOKUNMAZ.
--   K2: Seviye kisiye ve futbolcuya bagli (player_progress), fiziksel
--       kopyaya degil. Kart kaybedilse de seviye kalir.
--
-- Icerik:
--   1. 'level_rules' surum 1: seviye maliyetleri (tasarim §2.2), ustalik
--      odulleri, seviye 10 tasmasi -> joker parca, donusumde saklanan kopya
--   2. Sistem arsiv hesabi: donusturulen fiziksel kopyalar SILINMEZ,
--      bu hesaba devredilir (mac gecmisi ve denetim izi korunur;
--      user_cards silinseydi match_hands CASCADE ile silinirdi)
--   3. player_progress_overview / level_up_player / convert_extra_copies
--   4. open_chest: seviye 10'daki futbolcunun kopyasi -> joker parca
-- Tekrar calistirilabilir.
-- =====================================================================

insert into economy_config_versions (kind, version, payload, note)
values ('level_rules', 1, $json${
  "max_level": 10,
  "copies": {
    "bronze":  [1, 2, 3, 5, 8, 12, 16, 22, 30],
    "silver":  [1, 2, 3, 4, 6, 9, 13, 18, 24],
    "gold":    [1, 1, 2, 3, 5, 7, 10, 14, 18],
    "diamond": [1, 1, 1, 2, 3, 4, 6, 8, 11],
    "legend":  [1, 1, 1, 1, 2, 3, 4, 5, 7]
  },
  "coins": {
    "bronze":  [20, 50, 100, 200, 400, 700, 1000, 1500, 2500],
    "silver":  [30, 75, 150, 300, 600, 1000, 1500, 2200, 3500],
    "gold":    [50, 125, 250, 500, 900, 1500, 2200, 3200, 5000],
    "diamond": [100, 250, 500, 900, 1500, 2400, 3600, 5000, 7500],
    "legend":  [200, 500, 900, 1500, 2500, 4000, 6000, 8500, 12000]
  },
  "mastery": {"5": {"coins": 200}, "10": {"coins": 1000}},
  "overflow_jokers": {"bronze": 1, "silver": 2, "gold": 4, "diamond": 10, "legend": 25},
  "convert_keep": 2,
  "affects_ranked_power": false
}$json$::jsonb, '033: seviye kurallari surum 1 (tasarim §2.2). K1: dereceli gucu etkilemez.')
on conflict (kind, version) do nothing;

-- ---------------------------------------------------------------------
-- SISTEM ARSIV HESABI (giris yapilamaz, liderlikte ve eslesmede yok)
-- ---------------------------------------------------------------------
insert into users (id, email, password_hash, username, coins, is_banned, ban_reason)
values ('00000000-0000-4000-8000-0000000a2c41', 'sistem.arsiv@futbolcard.internal',
        '!giris-yok!', 'sistem_arsiv', 0, true,
        'Sistem hesabi: gelisim kopyasina donusturulen fiziksel kartlar (033)')
on conflict do nothing;

create or replace function _archive_user_id()
returns uuid language sql immutable as $$ select '00000000-0000-4000-8000-0000000a2c41'::uuid $$;

create or replace function _level_rules()
returns jsonb language sql stable as $$ select economy_config('level_rules') $$;

-- Bir sonraki seviyenin maliyeti (seviye 10'da null)
create or replace function _level_cost(p_tier card_tier, p_level int)
returns jsonb language sql stable as $$
  select case when p_level >= coalesce((_level_rules() ->> 'max_level')::int, 10) then null
         else jsonb_build_object(
           'copies', (_level_rules() -> 'copies' -> p_tier::text ->> (p_level - 1))::int,
           'coins',  (_level_rules() -> 'coins'  -> p_tier::text ->> (p_level - 1))::int)
         end
$$;

-- Donusturulebilir fiziksel kopyalar: macta kilitli degil, hicbir
-- destede degil; en az 'convert_keep' kopya oyuncuda kalir
create or replace function _convertible_copies(p_user_id uuid, p_card_id uuid)
returns int language sql stable as $$
  select greatest(0, least(
    (select count(*) from user_cards uc
     where uc.owner_id = p_user_id and uc.card_id = p_card_id and uc.locked_match_id is null
       and not exists (select 1 from deck_cards dc where dc.user_card_id = uc.id))::int,
    (select count(*) from user_cards uc where uc.owner_id = p_user_id and uc.card_id = p_card_id)::int
      - coalesce((_level_rules() ->> 'convert_keep')::int, 2)))
$$;

-- ---------------------------------------------------------------------
-- GELISIM LISTESI (sahip olunan + kaybedilmis ama ilerlemesi kalan)
-- ---------------------------------------------------------------------
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
    select coalesce(jsonb_object_agg(tier, amount), '{}'::jsonb) j from user_joker_shards where user_id = p_user_id
  )
  select jsonb_build_object(
    'items', coalesce((select jsonb_agg(jsonb_build_object(
        'card_id', s.id, 'slug', s.slug, 'full_name', s.full_name, 'position', s.position, 'tier', s.tier,
        'power', s.power, 'club', s.club, 'nationality', s.nationality, 'image_url', s.image_url,
        'level', s.level, 'copies', s.copies, 'owned_copies', s.owned,
        'convertible_copies', case when s.owned > 0 then _convertible_copies(p_user_id, s.id) else 0 end,
        'next', _level_cost(s.tier, s.level),
        'jokers_available', coalesce(((select j from joker) ->> s.tier::text)::int, 0))
      order by s.level desc, tier_rank(s.tier) desc, s.power desc) from satir s), '[]'::jsonb),
    'jokers', (select j from joker),
    'coins', (select coins from users where id = p_user_id),
    'rules_version', economy_config_version('level_rules'),
    'max_level', coalesce((_level_rules() ->> 'max_level')::int, 10),
    'convert_keep', coalesce((_level_rules() ->> 'convert_keep')::int, 2),
    'mastery', _level_rules() -> 'mastery',
    'affects_ranked_power', false,
    'enabled', economy_flag('economy_v2_enabled'))
$$;

-- ---------------------------------------------------------------------
-- SEVIYE ATLA (bir seviye). Idempotent: hedef seviye defter anahtarinda.
-- p_use_jokers: kopya eksigini ayni nadirlikteki joker parcalarla kapat.
-- ---------------------------------------------------------------------
create or replace function level_up_player(p_user_id uuid, p_card_id uuid, p_use_jokers boolean default false)
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
  v_var     int;
  v_hedef   int;
  v_usta    jsonb;
  v_odul    int := 0;
begin
  if not economy_flag('economy_v2_enabled') then
    raise exception 'economy_disabled: Bu ozellik henuz acik degil.';
  end if;
  perform pg_advisory_xact_lock(hashtext('player_progress:' || p_user_id::text));
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

  v_eksik := greatest(0, v_gerek - p.copies);
  if v_eksik > 0 then
    if not p_use_jokers then
      raise exception 'not_enough_copies: Yeterli gelisim kopyasi yok.';
    end if;
    select coalesce(amount, 0) into v_var from user_joker_shards where user_id = p_user_id and tier = c.tier for update;
    if coalesce(v_var, 0) < v_eksik then
      raise exception 'not_enough_jokers: Yeterli joker parca yok.';
    end if;
    v_joker := v_eksik;
  end if;
  if (select coins from users where id = p_user_id) < v_altin then
    raise exception 'not_enough_coins: Yeterli altin yok.';
  end if;

  -- Altin (defter; anahtar hedef seviyeyi icerir -> ayni seviye 2 kez odenmez)
  perform _ledger_add(p_user_id, 'level_up', -v_altin,
    jsonb_build_object('card_id', p_card_id, 'from', p.level, 'to', v_hedef,
                       'copies_used', v_gerek - v_joker, 'jokers_used', v_joker, 'tier', c.tier),
    'player_progress', p_card_id::text, 'level_up:' || p_user_id || ':' || p_card_id || ':' || v_hedef);

  update player_progress
  set level = v_hedef, copies = copies - (v_gerek - v_joker), updated_at = now()
  where user_id = p_user_id and card_id = p_card_id;
  if v_joker > 0 then
    update user_joker_shards set amount = amount - v_joker, updated_at = now()
    where user_id = p_user_id and tier = c.tier;
  end if;

  -- USTALIK ODULU (tek seferlik, seviye 5 ve 10)
  v_usta := _level_rules() -> 'mastery' -> v_hedef::text;
  if v_usta is not null then
    v_odul := coalesce((v_usta ->> 'coins')::int, 0);
    perform _ledger_add(p_user_id, 'mastery_reward', v_odul,
      jsonb_build_object('card_id', p_card_id, 'level', v_hedef),
      'player_progress', p_card_id::text, 'mastery:' || p_user_id || ':' || p_card_id || ':' || v_hedef);
  end if;

  return jsonb_build_object(
    'card_id', p_card_id, 'level', v_hedef, 'copies', p.copies - (v_gerek - v_joker),
    'coins_spent', v_altin, 'jokers_used', v_joker, 'mastery_coins', v_odul,
    'next', _level_cost(c.tier, v_hedef),
    'coins_after', (select coins from users where id = p_user_id));
end;
$$;

-- ---------------------------------------------------------------------
-- GONULLU KOPYA DONUSUMU (geri alinamaz). Fiziksel kopya SILINMEZ:
-- arsiv hesabina devredilir ve card_transfers'a yazilir.
-- p_request_key: istemcinin istek kimligi (tekrar istek ikinci kez donusturmez)
-- ---------------------------------------------------------------------
create or replace function convert_extra_copies(p_user_id uuid, p_card_id uuid, p_count int, p_request_key text)
returns jsonb
language plpgsql as $$
declare
  v_ids    uuid[];
  v_eski   economy_ledger%rowtype;
  v_yeni   int;
begin
  if not economy_flag('economy_v2_enabled') then
    raise exception 'economy_disabled: Bu ozellik henuz acik degil.';
  end if;
  perform pg_advisory_xact_lock(hashtext('player_progress:' || p_user_id::text));

  -- Tekrar istek: ilk sonucu don
  select * into v_eski from economy_ledger where idempotency_key = 'convert:' || p_user_id || ':' || p_request_key;
  if found then
    return v_eski.items || jsonb_build_object('replay', true);
  end if;

  if p_count is null or p_count < 1 then
    raise exception 'invalid_count: Gecersiz adet.';
  end if;
  if p_count > _convertible_copies(p_user_id, p_card_id) then
    raise exception 'not_convertible: Bu kadar kopya donusturulemez (destede/macta olanlar ve en az % kopya kalir).',
      coalesce((_level_rules() ->> 'convert_keep')::int, 2);
  end if;

  select array_agg(id) into v_ids from (
    select uc.id from user_cards uc
    where uc.owner_id = p_user_id and uc.card_id = p_card_id and uc.locked_match_id is null
      and not exists (select 1 from deck_cards dc where dc.user_card_id = uc.id)
    order by uc.acquired_at desc
    limit p_count
    for update) t;

  insert into card_transfers (match_id, user_card_id, card_id, from_user_id, to_user_id, reason)
  select null, uc.id, uc.card_id, p_user_id, _archive_user_id(), 'converted_to_progress'
  from user_cards uc where uc.id = any (v_ids);

  update user_cards set owner_id = _archive_user_id(), acquired_from = p_user_id, acquired_at = now()
  where id = any (v_ids);

  insert into player_progress (user_id, card_id, copies) values (p_user_id, p_card_id, p_count)
  on conflict (user_id, card_id) do update set copies = player_progress.copies + p_count, updated_at = now()
  returning copies into v_yeni;

  perform _ledger_add(p_user_id, 'copies_converted', 0,
    jsonb_build_object('card_id', p_card_id, 'converted', p_count, 'copies', v_yeni,
                       'owned_copies', (select count(*) from user_cards where owner_id = p_user_id and card_id = p_card_id)),
    'player_progress', p_card_id::text, 'convert:' || p_user_id || ':' || p_request_key);

  return jsonb_build_object('card_id', p_card_id, 'converted', p_count, 'copies', v_yeni,
    'owned_copies', (select count(*) from user_cards where owner_id = p_user_id and card_id = p_card_id));
end;
$$;

-- ---------------------------------------------------------------------
-- open_chest (031) — TEK DEGISIKLIK: seviye 10'daki futbolcunun kopyasi
-- 'joker' olur (tasma joker parcasi). Gerisi 031 ile AYNI.
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
begin
  perform pg_advisory_xact_lock(hashtext('user_chests:' || p_user_id::text));
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
      v_sonuc := 'joker';         -- 033: seviye 10 -> tasma joker parcasi
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
  -- Sandigin joker parcalari + seviye 10 tasmasi
  v_joker := coalesce(t -> 'jokers', '{}');
  for j in select key, value::int as n from jsonb_each_text(v_tasma) loop
    v_joker := jsonb_set(v_joker, array[j.key], to_jsonb(coalesce((v_joker ->> j.key)::int, 0) + j.n));
  end loop;
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
