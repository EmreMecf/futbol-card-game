-- =====================================================================
-- 040 KURAL SURUMU 5 — SEVIYE GUCU (B2) + ETKIN GUCE GORE ESLESTIRME
--                      + LIG TAVANI (KAPALI GELIR)
-- =====================================================================
-- Onay: kullanici (12 Kasim 2026, "faz 2 ye gec"). Tasarim:
-- docs/OYUN_TASARIMI_V3.md §2. Olcum: tool/ekonomi/test_seviye_eslestirme.py
-- (etkin guce gore eslesmede seviyeli oyuncu %51-54; temel guce gore %89).
--
-- KURAL (yalniz surum 5 maclar):
--   * Seviye bonusu B2: seviye 1-3 +0, 4-6 +1, 7-9 +2, 10 +3; YALNIZ o kart.
--   * Lig tavani: Amator 4, Usta 7, Master ve Master Class 10. Tavanin
--     ustundeki seviye o ligde sayilmaz. Lig = MAC KURULURKEN oyuncunun puani.
--   * Bonus mac kurulurken match_hands.power'a eklenir (anlik goruntu):
--     mac icinde seviye atlansa ya da lig degisse de el ayni kalir.
--   * Efsane kurali DEGISMEZ: compare_cards once sinifa bakar.
--   * Eslestirme 'combined' (024) olur ve deck_power bonusu AYNI fonksiyonla
--     (card_level_bonus) icerir: seviyeli kadro daha guclu rakiple eslesir.
--   * Akis surum 4 ile ayni (es zamanli gizli secim, 12 kartta bitis,
--     duvar 2 enerji, oduller surum 3).
--
-- ETKINLESTIRME: 'card_level_power' (KAPALI) + duel_v4 + economy_v2_enabled
-- + ranked_rewards_v2 dordu acikken yeni maclar surum 5 kurulur.
--
-- DEGISMEYENLER: _create_match, play_card, _resolve_round, find_match,
-- taktikler, kimya, kart karsilastirmasi, MMR. Anahtar kapaliyken
-- deck_power ve matchmaking_mode bugunku degeri AYNEN doner.
-- Gecmis match_hands / matches / player_progress satirlarina DOKUNULMAZ
-- (match_hands'e sutun EKLENMEZ; bonus kaydi ayri tabloda).
-- =====================================================================

-- ---------------------------------------------------------------------
-- OZELLIK ANAHTARI (mevcut degerler korunur, yeni anahtar kapali)
-- ---------------------------------------------------------------------
insert into economy_config_versions (kind, version, payload, note)
select 'feature_flags', max(version) + 1,
       (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1)
         || '{"card_level_power": false}'::jsonb,
       '040: seviye gucu + etkin guce gore eslestirme (kapali)'
from economy_config_versions
where kind = 'feature_flags'
  and not ((select payload from economy_config_versions where kind = 'feature_flags'
            order by version desc limit 1) ? 'card_level_power')
having count(*) > 0;

-- ---------------------------------------------------------------------
-- KURAL SURUMU 5 = surum 4 + seviye gucu
-- ---------------------------------------------------------------------
alter table game_rule_versions add column if not exists level_power boolean not null default false;

insert into game_rule_versions
  (version, name, description, tactics_enabled, card_transfer, win_progress_copies, no_energy_chest,
   simultaneous, wall_cost, early_finish_cards, position_seconds, pick_seconds, level_power)
select 5, 'Seviye gucu',
       '040: surum 4 + seviye bonusu B2 (L4 +1, L7 +2, L10 +3), lig tavani 4/7/10, etkin guce gore eslestirme',
       tactics_enabled, card_transfer, win_progress_copies, no_energy_chest,
       simultaneous, wall_cost, early_finish_cards, position_seconds, pick_seconds, true
from game_rule_versions where version = 4
on conflict (version) do nothing;

create or replace function current_rules_version() returns int
language sql stable as $$
  select case
    when economy_flag('economy_v2_enabled') and economy_flag('ranked_rewards_v2') and economy_flag('duel_v4')
         and economy_flag('card_level_power') then 5
    when economy_flag('economy_v2_enabled') and economy_flag('ranked_rewards_v2') and economy_flag('duel_v4') then 4
    when economy_flag('economy_v2_enabled') and economy_flag('ranked_rewards_v2') then 3
    else 2 end
$$;

create or replace function rules_level_power(p_version int) returns boolean
language sql stable as $$
  select coalesce((select level_power from game_rule_versions where version = p_version), false)
$$;

-- ---------------------------------------------------------------------
-- BONUS: TEK KAYNAK (hem deck_power hem maç eli bunu kullanir)
-- ---------------------------------------------------------------------
-- B2 egrisi
create or replace function level_power_bonus(p_level int) returns int
language sql immutable as $$
  select case when p_level >= 10 then 3
              when p_level >= 7  then 2
              when p_level >= 4  then 1
              else 0 end
$$;

-- Lig tavani: puanin dustugu ligin en yuksek sayilan seviyesi
create or replace function league_level_cap(p_mmr int) returns int
language sql stable as $$
  select case (rank_for_mmr(p_mmr)).league_code
           when 'amateur' then 4
           when 'usta'    then 7
           else 10 end
$$;

-- Bir oyuncunun bir futbolcusu icin bonus (seviye kisiye + futbolcuya bagli)
create or replace function card_level_bonus(p_user_id uuid, p_card_id uuid, p_mmr int) returns int
language sql stable as $$
  select level_power_bonus(least(
    coalesce((select level from player_progress where user_id = p_user_id and card_id = p_card_id), 1),
    league_level_cap(p_mmr)))
$$;

-- ---------------------------------------------------------------------
-- MAC ELI: bonus mac KURULURKEN dondurulur (yalniz surum 5)
-- ---------------------------------------------------------------------
-- Denetim kaydi: hangi kart hangi seviye/tavanla ne bonus aldi.
-- match_hands'e sutun eklenmez (gecmis satirlar aynen kalsin).
create table if not exists match_hand_level_bonus (
  match_id      uuid not null references matches(id) on delete cascade,
  user_card_id  uuid not null,
  user_id       uuid not null references users(id) on delete cascade,
  card_id       uuid not null references cards(id),
  level         int  not null,
  level_cap     int  not null,
  bonus         int  not null check (bonus between 0 and 3),
  base_power    int  not null,
  primary key (match_id, user_card_id)
);

comment on table match_hand_level_bonus is
  'GIZLI VERI (match_hands gibi): surum 5 macta el kartlarinin seviye bonusu.';

create or replace function _match_hand_level_bonus()
returns trigger language plpgsql as $$
declare
  v_ver   int;
  v_mmr   int;
  v_level int;
  v_cap   int;
  v_bonus int;
begin
  select rules_version into v_ver from matches where id = new.match_id;
  if not rules_level_power(v_ver) then
    return new;                         -- surum 1-4: el AYNEN
  end if;

  select mmr into v_mmr from users where id = new.user_id;
  v_level := coalesce((select level from player_progress
                       where user_id = new.user_id and card_id = new.card_id), 1);
  v_cap   := league_level_cap(v_mmr);
  v_bonus := card_level_bonus(new.user_id, new.card_id, v_mmr);

  insert into match_hand_level_bonus
    (match_id, user_card_id, user_id, card_id, level, level_cap, bonus, base_power)
  values (new.match_id, new.user_card_id, new.user_id, new.card_id, v_level, v_cap, v_bonus, new.power)
  on conflict (match_id, user_card_id) do nothing;

  new.power := new.power + v_bonus;
  return new;
end;
$$;

drop trigger if exists trg_match_hand_level_bonus on match_hands;
create trigger trg_match_hand_level_bonus
  before insert on match_hands
  for each row execute function _match_hand_level_bonus();

-- ---------------------------------------------------------------------
-- KADRO GUCU: maca giren degerle ayni (guc + kimya [+ seviye bonusu])
-- Anahtar kapaliyken bonus 0: deger 024 ile ayni.
-- ---------------------------------------------------------------------
create or replace function deck_power(p_deck_id uuid) returns numeric
language sql stable as $$
  select round(avg(c.power + coalesce(ch.chemistry, 0)
                   + case when rules_level_power(current_rules_version())          -- 040
                          then card_level_bonus(uc.owner_id, c.id, u.mmr) else 0 end)::numeric, 2)
  from deck_cards dc
  join user_cards uc on uc.id = dc.user_card_id
  join users u on u.id = uc.owner_id                                                -- 040
  join cards c on c.id = uc.card_id
  left join calculate_deck_chemistry(p_deck_id) ch
    on ch.user_card_id = dc.user_card_id
  where dc.deck_id = p_deck_id
$$;

-- ---------------------------------------------------------------------
-- ESLESTIRME: surum 5'te 'combined' (MMR + etkin kadro gucu)
-- Anahtar kapaliyken matchmaking_settings.mode AYNEN (varsayilan 'mmr').
-- ---------------------------------------------------------------------
create or replace function matchmaking_mode() returns text
language sql stable as $$
  select case when rules_level_power(current_rules_version()) then 'combined'          -- 040
              else coalesce((select mode from matchmaking_settings where id = 1), 'mmr') end
$$;
