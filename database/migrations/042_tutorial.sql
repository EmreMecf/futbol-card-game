-- =====================================================================
-- 042 OGRETICI (FAZ 3b, KAPALI GELIR) + 041 ANTRENMAN DUZELTMESI
-- =====================================================================
-- Onay: kullanici (13 Kasim 2026, "devam"). Tasarim: docs/OYUN_TASARIMI_V3.md §4:
-- "3 kisa mac (mevki -> gizli secim -> taktik), sonunda bir Gumus sandik".
--
-- OGRETICI ('tutorial_v1', KAPALI):
--   Adim 1: MEVKI   — kural surumu 6 (taktiksiz); oyuncu ILK MEVKIYI kendisi secer
--   Adim 2: GIZLI SECIM — surum 6 (taktiksiz)
--   Adim 3: TAKTIK  — surum 7 (taktikli)
--   Surum 6/7 = surum 4 akisi, yalniz VERI farki: 6 kartta erken bitis,
--   mevki 15 sn, secim 30 sn (ogrenirken acele olmasin). Duello kodu
--   DEGISMEDI; game_rule_versions satirlariyla calisir.
--   Rakip: bot ("Bot" gorunur), kadrosu oyuncununkinden ~6 guc ZAYIF.
--   Odul: maclar antrenman gibi ODULSUZ ve PUANSIZ; 3. adim bitince TEK
--   SEFER Gumus sandik (kaynak 'tutorial').
--   Adim sayilir: mac bitti, en az 3 tur oynandi, oyuncu sure asimiyla
--   (ust uste 2 otomatik hamle) dusmedi. Kaybetmek de sayilir (ogrenmek icin).
--   Yalniz es zamanli kurallar canliyken (surum 4/5) acilir: sirali
--   oyunda es zamanli ogretici yaniltici olurdu.
--
-- 041 DUZELTMESI: galibiyet gelisim kopyasi tetikleyicisi (037, R3)
-- antrenman macinda da calisiyordu (oyuncu bota karsi KAZANIRSA +1 kopya).
-- Artik yalniz dereceli macta. Gecmis kayitlara dokunulmaz (anahtar
-- kapali oldugu icin uretimde hic olusmadi).
--
-- current_rules_version(): islem icinde 'futbol.rules_version_override'
-- ayarlanmissa onu doner (yalniz ogretici maci kurulurken, ayni islemde,
-- hemen sifirlanir); aksi halde 040 ile AYNI.
-- =====================================================================

insert into economy_config_versions (kind, version, payload, note)
select 'feature_flags', max(version) + 1,
       (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1)
         || '{"tutorial_v1": false}'::jsonb,
       '042: ogretici (kapali)'
from economy_config_versions
where kind = 'feature_flags'
  and not ((select payload from economy_config_versions where kind = 'feature_flags'
            order by version desc limit 1) ? 'tutorial_v1')
having count(*) > 0;

-- ---------------------------------------------------------------------
-- 0) 041 DUZELTMESI: galibiyet kopyasi yalniz dereceli macta
-- ---------------------------------------------------------------------
drop trigger if exists trg_economy_win_copy_finished on matches;
create trigger trg_economy_win_copy_finished
  after update of status on matches
  for each row
  when (new.status = 'finished' and old.status is distinct from 'finished' and new.mode = 'ranked')  -- 042
  execute function _economy_win_copy_on_match_finished();

-- ---------------------------------------------------------------------
-- 1) SEMA
-- ---------------------------------------------------------------------
alter table matches drop constraint if exists matches_mode_check;
alter table matches add constraint matches_mode_check check (mode in ('ranked', 'training', 'tutorial'));
alter table matches add column if not exists tutorial_step int check (tutorial_step between 1 and 3);

create table if not exists user_tutorial (
  user_id       uuid primary key references users(id) on delete cascade,
  step          int  not null default 0 check (step between 0 and 3),  -- tamamlanan adim
  completed_at  timestamptz,
  updated_at    timestamptz not null default now()
);

insert into game_rule_versions
  (version, name, description, tactics_enabled, card_transfer, win_progress_copies, no_energy_chest,
   simultaneous, wall_cost, early_finish_cards, position_seconds, pick_seconds, level_power)
values
  (6, 'Ogretici (taktiksiz)', '042: surum 4 akisi; 6 kartta bitis, mevki 15 sn, secim 30 sn, taktik yok',
   false, false, 0, 'bronze', true, 2, 6, 15, 30, false),
  (7, 'Ogretici (taktikli)',  '042: surum 4 akisi; 6 kartta bitis, mevki 15 sn, secim 30 sn, taktikli',
   true,  false, 0, 'bronze', true, 2, 6, 15, 30, false)
on conflict (version) do nothing;

create or replace function current_rules_version() returns int
language sql stable as $$
  select coalesce(
    nullif(current_setting('futbol.rules_version_override', true), '')::int,                -- 042
    case
      when economy_flag('economy_v2_enabled') and economy_flag('ranked_rewards_v2') and economy_flag('duel_v4')
           and economy_flag('card_level_power') then 5
      when economy_flag('economy_v2_enabled') and economy_flag('ranked_rewards_v2') and economy_flag('duel_v4') then 4
      when economy_flag('economy_v2_enabled') and economy_flag('ranked_rewards_v2') then 3
      else 2 end)
$$;

-- ---------------------------------------------------------------------
-- 2) BOT KADROSU: guc kaydirmali surum (041 govdesi + p_offset). 041'deki
--    _bot_build_deck ayni kalir ve kaydirmasiz (0) cagirir.
-- ---------------------------------------------------------------------
create or replace function _bot_build_deck2(p_bot uuid, p_against_deck uuid, p_against_user uuid, p_offset int)
returns uuid
language plpgsql as $$
declare
  v_deck   uuid;
  v_v5     boolean := rules_level_power(current_rules_version());
  v_mmr    int := (select mmr from users where id = p_against_user);
  r        record;
  v_card   uuid;
  v_uc     uuid;
  v_secili uuid[] := '{}';
begin
  select id into v_deck from decks where owner_id = p_bot and is_active;
  if v_deck is null then
    insert into decks (owner_id, name, is_active) values (p_bot, 'Kadro', true) returning id into v_deck;
  end if;
  delete from deck_cards where deck_id = v_deck;

  for r in
    select c.position, c.tier,
           c.power + case when v_v5 then card_level_bonus(p_against_user, c.id, v_mmr) else 0 end
             + p_offset as etkin   -- 042: ogretici botu icin guc kaydirma
    from deck_cards dc
    join user_cards uc on uc.id = dc.user_card_id
    join cards c on c.id = uc.card_id
    where dc.deck_id = p_against_deck
  loop
    -- ayni mevki + sinif, etkin guc +-3; yoksa ayni mevki + sinif en yakin; yoksa ayni mevki
    select c.id into v_card from cards c
    where c.position = r.position and c.tier = r.tier and abs(c.power - r.etkin) <= 3
    order by random() limit 1;
    if v_card is null then
      select c.id into v_card from cards c
      where c.position = r.position and c.tier = r.tier
      order by abs(c.power - r.etkin), random() limit 1;
    end if;
    if v_card is null then
      select c.id into v_card from cards c
      where c.position = r.position and c.tier <> 'legend'
      order by abs(c.power - r.etkin), random() limit 1;
    end if;

    select uc.id into v_uc from user_cards uc
    where uc.owner_id = p_bot and uc.card_id = v_card and uc.locked_match_id is null
      and not (uc.id = any (v_secili))
    limit 1;
    if v_uc is null then
      insert into user_cards (owner_id, card_id) values (p_bot, v_card) returning id into v_uc;
    end if;
    v_secili := v_secili || v_uc;
    insert into deck_cards (deck_id, user_card_id) values (v_deck, v_uc);
    v_card := null; v_uc := null;
  end loop;

  return v_deck;
end;
$$;

create or replace function _bot_build_deck(p_bot uuid, p_against_deck uuid, p_against_user uuid)
returns uuid
language sql as $$ select _bot_build_deck2(p_bot, p_against_deck, p_against_user, 0) $$;

-- ---------------------------------------------------------------------
-- 3) MAC SONU: ogretici de antrenman gibi odulsuz (041 govdesi, tek satir)
-- ---------------------------------------------------------------------
create or replace function _finish_match(
  p_match_id uuid,
  p_forced_winner uuid default null   -- teslim / AFK durumunda hukmen galip
)
returns void
language plpgsql
as $$
declare
  m           matches%rowtype;
  v_winner    uuid;
  v_loser     uuid;
  v_draw      boolean := false;
  v_protected uuid[];
  v_penalty   uuid[];
begin
  select * into m from matches where id = p_match_id for update;

  if m.status <> 'active' then
    return;  -- zaten bitmis, iki kez ceza uygulanmasin
  end if;

  -- 041: ANTRENMAN maci odulsuz ve puansiz biter: transfer, MMR, altin,
  -- galibiyet/maglubiyet sayaci, sandik, sezon XP'si YOK. Yalniz kartlarin
  -- kilidi acilir ve mac kapanir (kazanan gosterim icin yazilir).
  if m.mode in ('training', 'tutorial') then                             -- 041 / 042: ogretici de odulsuz
    if p_forced_winner is not null then                                  -- 041
      v_winner := p_forced_winner; v_loser := _opponent_of(m, p_forced_winner); -- 041
    elsif m.p1_captured_count > m.p2_captured_count then                 -- 041
      v_winner := m.player1_id; v_loser := m.player2_id;                 -- 041
    elsif m.p2_captured_count > m.p1_captured_count then                 -- 041
      v_winner := m.player2_id; v_loser := m.player1_id;                 -- 041
    else                                                                 -- 041
      v_draw := true;                                                    -- 041
    end if;                                                              -- 041
    update user_cards set locked_match_id = null where locked_match_id = p_match_id; -- 041
    update matches set status = 'finished', winner_id = v_winner, loser_id = v_loser, -- 041
                       is_draw = v_draw, finished_at = now() where id = p_match_id;   -- 041
    return;                                                              -- 041
  end if;                                                                -- 041

  -- ---- KAZANANI BELIRLE ----
  if p_forced_winner is not null then
    v_winner := p_forced_winner;
    v_loser  := _opponent_of(m, p_forced_winner);
  elsif m.p1_captured_count > m.p2_captured_count then
    v_winner := m.player1_id; v_loser := m.player2_id;
  elsif m.p2_captured_count > m.p1_captured_count then
    v_winner := m.player2_id; v_loser := m.player1_id;
  else
    v_draw := true;
  end if;

  -- ---- CEZA: Korumasiz 3 rastgele karti kazanana devret ----
  -- 037 (R2): yalniz macin KENDI kural surumu transferi aciyorsa
  -- (surum 1-2: evet; surum 3: hayir). Gecmis transferlere dokunulmaz.
  if not v_draw and rules_card_transfer(m.rules_version) then
    select mp.protected_card_ids into v_protected
    from match_players mp
    where mp.match_id = p_match_id and mp.user_id = v_loser;

    select coalesce(array_agg(t.user_card_id), '{}')
    into v_penalty
    from (
      select mh.user_card_id
      from match_hands mh
      join user_cards uc on uc.id = mh.user_card_id
      where mh.match_id = p_match_id
        and mh.user_id  = v_loser
        and uc.owner_id = v_loser                       -- hala onun mu?
        and not (mh.user_card_id = any (coalesce(v_protected, '{}'::uuid[])))
      order by random()
      limit penalty_card_count()
    ) t;

    if array_length(v_penalty, 1) > 0 then
      -- Denetim kaydi
      insert into card_transfers
        (match_id, user_card_id, card_id, from_user_id, to_user_id, reason)
      select p_match_id, uc.id, uc.card_id, v_loser, v_winner, 'match_penalty'
      from user_cards uc
      where uc.id = any (v_penalty);

      -- Kaybedenin destesinden cikar (kadro artik gecersiz olacak,
      -- oyuncu yeni maca girmeden once kadrosunu tamamlamak zorunda)
      delete from deck_cards where user_card_id = any (v_penalty);

      -- SAHIPLIK DEVRI
      update user_cards
      set owner_id      = v_winner,
          acquired_from = v_loser,
          acquired_at   = now()
      where id = any (v_penalty);
    end if;
  end if;

  -- ---- ISTATISTIK VE ODULLER ----
  if v_draw then
    update users set draws = draws + 1
    where id in (m.player1_id, m.player2_id);
  else
    update users
    set wins             = wins + 1,
        coins            = coins + 100,
        mmr              = mmr + 25,
        -- KART KORUMA HAKKI HER GALIBIYETTE +1 (037: transfersiz surumde
        -- koruma anlamsiz; deger silinmez, artmaz)
        protection_slots = case when rules_card_transfer(m.rules_version)
                                then least(protection_slots + 1, max_protection_slots())
                                else protection_slots end
    where id = v_winner;

    update users
    set losses = losses + 1,
        mmr    = greatest(mmr - 25, 0)
    where id = v_loser;
  end if;

  -- ---- KILITLERI AC ----
  update user_cards set locked_match_id = null
  where locked_match_id = p_match_id;

  -- ---- MACI KAPAT ----
  update matches
  set status      = 'finished',
      winner_id   = v_winner,
      loser_id    = v_loser,
      is_draw     = v_draw,
      finished_at = now()
  where id = p_match_id;

  -- Kuyruk kayitlarini temizle
  delete from matchmaking_queue
  where user_id in (m.player1_id, m.player2_id);
end;
$$;

-- ---------------------------------------------------------------------
-- 3b) TAKTIKSIZ SURUMDE TAKTIK REDDI (es zamanli akis icin)
-- ---------------------------------------------------------------------
-- 039'un es zamanli akisi taktik iznini sormaz (surum 4 hep taktikli).
-- Surum 6 taktiksiz oldugundan hamle KAYDEDILMEDEN reddedilir. Sirali akis
-- (surum 1-3) bunu play_card icinde zaten yapiyor; orada bu tetikleyici
-- hic devreye girmez.
create or replace function _move_tactic_allowed()
returns trigger language plpgsql as $$
begin
  if coalesce(new.tactic, 'none') <> 'none'
     and not rules_tactics_enabled((select rules_version from matches where id = new.match_id)) then
    raise exception 'Bu mac taktiksiz kurallarla oynaniyor.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_move_tactic_allowed on match_moves;
create trigger trg_move_tactic_allowed
  before insert on match_moves
  for each row execute function _move_tactic_allowed();

-- ---------------------------------------------------------------------
-- 4) OGRETICI DURUMU + BASLATMA
-- ---------------------------------------------------------------------
create or replace function tutorial_status(p_user_id uuid) returns json
language sql stable as $$
  select json_build_object(
    'enabled',      economy_flag('tutorial_v1') and rules_simultaneous(current_rules_version()),
    'step',         coalesce(t.step, 0),
    'next_step',    case when coalesce(t.step, 0) >= 3 then null else coalesce(t.step, 0) + 1 end,
    'completed',    t.completed_at is not null,
    'completed_at', t.completed_at,
    'reward_chest', 'silver')
  from (select 1) x
  left join user_tutorial t on t.user_id = p_user_id
$$;

create or replace function start_tutorial_match(p_user_id uuid, p_deck_id uuid)
returns json
language plpgsql as $$
declare
  v_err    text;
  v_active uuid;
  v_adim   int;
  v_bot    uuid;
  v_deck   uuid;
  v_match  uuid;
begin
  if not economy_flag('tutorial_v1') then
    raise exception 'tutorial_disabled: Ogretici kapali.';
  end if;
  if not rules_simultaneous(current_rules_version()) then
    raise exception 'tutorial_disabled: Ogretici yalniz es zamanli kurallarla acilir.';
  end if;
  v_active := get_active_match_id(p_user_id);
  if v_active is not null then
    return json_build_object('status', 'in_match', 'match_id', v_active);
  end if;
  v_adim := coalesce((select step from user_tutorial where user_id = p_user_id), 0) + 1;
  if v_adim > 3 then
    raise exception 'tutorial_done: Ogretici zaten tamamlandi.';
  end if;
  v_err := validate_deck(p_user_id, p_deck_id);
  if v_err is not null then
    raise exception '%', v_err;
  end if;

  perform pg_advisory_xact_lock(hashtext('futbol_card_matchmaking'));
  delete from matchmaking_queue where user_id = p_user_id;

  v_bot  := _bot_pick(p_user_id);
  v_deck := _bot_build_deck2(v_bot, p_deck_id, p_user_id, -6);   -- ogretici botu zayif

  -- Ogretici surumu yalniz BU mac kurulurken (ayni islem, hemen sifirlanir)
  perform set_config('futbol.rules_version_override', case when v_adim < 3 then '6' else '7' end, true);
  v_match := _create_match(v_bot, v_deck, '{}', p_user_id, p_deck_id, '{}');
  perform set_config('futbol.rules_version_override', '', true);

  update matches set mode = 'tutorial', tutorial_step = v_adim where id = v_match;
  -- Adim 1 mevki dersi: ilk mevkiyi oyuncu secer
  if v_adim = 1 then
    update matches set lead_player_id = p_user_id, current_turn_id = p_user_id where id = v_match;
  end if;

  insert into user_tutorial (user_id) values (p_user_id) on conflict (user_id) do nothing;
  return json_build_object('status', 'matched', 'match_id', v_match, 'mode', 'tutorial', 'tutorial_step', v_adim);
end;
$$;

-- ---------------------------------------------------------------------
-- 5) OGRETICI MACI BITINCE: adim + (3. adimda) tek sefer Gumus sandik
-- ---------------------------------------------------------------------
create or replace function _tutorial_on_match_finished()
returns trigger language plpgsql as $$
declare
  v_insan uuid;
  v_tur   int;
  v_afk   int;
  v_once  int;
begin
  select u.id into v_insan from users u
  where u.id in (new.player1_id, new.player2_id) and not u.is_bot;
  if v_insan is null or new.tutorial_step is null then
    return null;
  end if;
  select count(*) into v_tur from match_rounds where match_id = new.id;
  select auto_streak into v_afk from match_players where match_id = new.id and user_id = v_insan;
  if v_tur < 3 or coalesce(v_afk, 0) >= 2 then
    return null;   -- adim sayilmaz; oyuncu tekrar dener
  end if;

  select step into v_once from user_tutorial where user_id = v_insan for update;
  update user_tutorial
  set step = greatest(step, new.tutorial_step),
      completed_at = case when greatest(step, new.tutorial_step) >= 3 then coalesce(completed_at, now()) else completed_at end,
      updated_at = now()
  where user_id = v_insan;

  if new.tutorial_step = 3 then
    begin
      perform _grant_chest(v_insan, 'silver', 'tutorial', v_insan::text);   -- tek sefer (unique kaynak)
    exception when others then
      insert into economy_errors (context, user_id, source_id, error)
      values ('tutorial_chest', v_insan, new.id::text, sqlerrm);
    end;
  end if;
  return null;
end;
$$;

drop trigger if exists trg_tutorial_match_finished on matches;
create trigger trg_tutorial_match_finished
  after update of status on matches
  for each row
  when (new.status = 'finished' and old.status is distinct from 'finished' and new.mode = 'tutorial')
  execute function _tutorial_on_match_finished();
