-- =====================================================================
-- 052: SANDIK KADRO KORUMASI DA FARKLI FUTBOLCU VERSIN
-- =====================================================================
-- 050 paketlerdeki kadro korumasini duzeltti; sandiklar (open_chest) ayni
-- korumayi kendi icinde yapiyor ve hala sahip olunan futbolcunun ikinci
-- fiziksel kopyasini veriyordu (canli test: eksik orta saha icin zaten
-- kadroda olan futbolcu geldi). Bir futbolcu kadroda bir kez olabildigi
-- icin bu kopya eksigi kapatmiyordu.
--
-- Simdi: kadro korumasi devreye girerse ayni mevki ve siniftan sahip
-- olunmayan bir futbolcu verilir (_pick_unowned_card, 050). Katalogda
-- yoksa eski davranis surer. 050'den sonra calistirilmalidir.
-- =====================================================================

create or replace function open_chest(p_user_id uuid, p_chest_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $$
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
      -- 052: ayni futbolcunun ikinci kopyasi kadroda ise yaramaz; ayni
      -- mevki ve siniftan sahip olunmayan bir futbolcu verilir
      v_kart := coalesce(_pick_unowned_card(p_user_id, v_kart_row.tier, v_pos), v_kart);
      select * into v_kart_row from cards where id = v_kart;
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
$$

;
