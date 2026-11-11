"""037 ve 038 migration'larını mevcut fonksiyon gövdelerinden ÜRETİR.

023'teki yöntem: değişen fonksiyonlar elle yeniden yazılmaz; en son
tanımları migration dosyalarından okunur, yalnız işaretli bloklar eklenir.
Böylece düello, sandık ve görev mantığının geri kalanı birebir aynı kalır.
Her ekleme TAM BİR KEZ eşleşmek zorunda (yoksa betik durur).

Kullanım: python -I tool/ekonomi/migration_uret.py
"""
from __future__ import annotations

import pathlib
import re

KOK = pathlib.Path(__file__).resolve().parents[2]
MIG = KOK / 'database' / 'migrations'


def fonksiyon(dosya: str, ad: str) -> str:
    s = (MIG / dosya).read_text(encoding='utf-8')
    m = list(re.finditer(rf'create or replace function {re.escape(ad)}\(', s))
    assert m, (dosya, ad)
    bas = m[-1].start()
    son = s.index('\n$$;', bas) + len('\n$$;')
    return s[bas:son]


def ekle(govde: str, sonra: str, yeni: str, once: bool = False) -> str:
    assert govde.count(sonra) == 1, (govde.count(sonra), sonra[:70])
    return govde.replace(sonra, yeni + sonra if once else sonra + yeni)


def degistir(govde: str, eski: str, yeni: str) -> str:
    assert govde.count(eski) == 1, (govde.count(eski), eski[:70])
    return govde.replace(eski, yeni)


# =====================================================================
# 037: R1 + R2 + R3 + yönetici onarımı
# =====================================================================
finish = fonksiyon('007_rpc_gameplay.sql', '_finish_match')
finish = degistir(finish, """  -- ---- CEZA: Korumasiz 3 rastgele karti kazanana devret ----
  if not v_draw then""", """  -- ---- CEZA: Korumasiz 3 rastgele karti kazanana devret ----
  -- 037 (R2): yalniz macin KENDI kural surumu transferi aciyorsa
  -- (surum 1-2: evet; surum 3: hayir). Gecmis transferlere dokunulmaz.
  if not v_draw and rules_card_transfer(m.rules_version) then""")
finish = degistir(finish, """        -- KART KORUMA HAKKI HER GALIBIYETTE +1
        protection_slots = least(protection_slots + 1, max_protection_slots())""", """        -- KART KORUMA HAKKI HER GALIBIYETTE +1 (037: transfersiz surumde
        -- koruma anlamsiz; deger silinmez, artmaz)
        protection_slots = case when rules_card_transfer(m.rules_version)
                                then least(protection_slots + 1, max_protection_slots())
                                else protection_slots end""")

grant = fonksiyon('031_chest_functions.sql', '_grant_match_chest')
grant = degistir(grant, """                        'match', p_match_id::text, 'chest_skip:' || p_match_id || ':' || p_user_id);
    return null;
  end if;""", """                        'match', p_match_id::text, 'chest_skip:' || p_match_id || ':' || p_user_id);
    -- 037 (R1): kural surumu enerjisiz sandik veriyorsa (surum 3: Bronz,
    -- aninda acilir, yuvaya girmez). Sanssizlik sayaclari ilerlemez;
    -- chest_skip kaydi yukarida yazildi -> sezon XP'si %25 (035 ayni).
    if _match_no_energy_chest(p_match_id) is not null then
      return _grant_chest(p_user_id, _match_no_energy_chest(p_match_id), 'match', p_match_id::text);
    end if;
    return null;
  end if;""")

MIG037 = f"""-- =====================================================================
-- 037 EKONOMI V2 — DERECELI ODUL KURALLARI R1 / R2 / R3 (KAPALI GELIR)
-- =====================================================================
-- Onay: kullanici (10 Kasim 2026). Plan: docs/EKONOMI_V2_UYGULAMA_PLANI.md
-- Bu dosya tool/ekonomi/migration_uret.py ile mevcut fonksiyon
-- govdelerinden URETILDI; farklar yalniz "037" yorumlu satirlar.
--
--   R1  Her mesru dereceli mac (>= 4 tur, K6) sandik verir; odul enerjisi
--       yoksa sandik Bronz (aninda), XP %25 (035 ayni).
--   R2  Normal dereceli macta kalici kart transferi YOK; galibiyette koruma
--       hakki artmaz (deger silinmez).
--   R3  Galibiyette kazananin aktif destesinden seviyesi < 10 rastgele bir
--       futbolcuya +1 gelisim kopyasi (fiziksel kart degil), tek sefer.
--
-- ETKINLESTIRME: yeni oyun kural surumu 3. current_rules_version() yalniz
-- 'economy_v2_enabled' VE 'ranked_rewards_v2' aciksa 3 doner. Surum mac
-- KURULURKEN matches.rules_version'a yazilir (023): suren maclar eski
-- kurallarla biter. Anahtar migration'da KAPALI; uretimde acilmaz.
--
-- DEGISMEYENLER: play_card, _resolve_round, taktikler (021), kimya (014),
-- kart karsilastirmasi, eslestirme (024), MMR +/-25, galibiyet +100 altin.
-- Gecmis card_transfers / user_cards / match_hands satirlarina DOKUNULMAZ.
-- =====================================================================

-- ---------------------------------------------------------------------
-- OZELLIK ANAHTARLARI: mevcut degerleri KORUYARAK yeni anahtarlar (kapali)
-- (economy_flag en yuksek surumun payload'ini okur; yalniz yeni anahtar
-- eklenseydi economy_v2_enabled kapanirdi.)
-- ---------------------------------------------------------------------
insert into economy_config_versions (kind, version, payload, note)
select 'feature_flags', max(version) + 1,
       (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1)
         || '{{"ranked_rewards_v2": false, "item_sources_v2": false}}'::jsonb,
       '037/038: dereceli odul kurallari ve item kaynaklari (kapali)'
from economy_config_versions
where kind = 'feature_flags'
  and not ((select payload from economy_config_versions where kind = 'feature_flags'
            order by version desc limit 1) ? 'ranked_rewards_v2')
having count(*) > 0;

-- ---------------------------------------------------------------------
-- OYUN KURAL SURUMU 3 (duello surum 2 ile AYNI: taktikli)
-- ---------------------------------------------------------------------
alter table game_rule_versions add column if not exists card_transfer boolean not null default true;
alter table game_rule_versions add column if not exists win_progress_copies int not null default 0;
alter table game_rule_versions add column if not exists no_energy_chest text;

insert into game_rule_versions (version, name, description, tactics_enabled, card_transfer, win_progress_copies, no_energy_chest)
values (3, 'Taktik + yeni odul', '037: surum 2 duellosu; kart transferi yok, enerjisiz Bronz sandik, galibiyette +1 gelisim kopyasi',
        true, false, 1, 'bronze')
on conflict (version) do nothing;

create or replace function current_rules_version() returns int
language sql stable as $$
  select case when economy_flag('economy_v2_enabled') and economy_flag('ranked_rewards_v2') then 3 else 2 end
$$;

create or replace function rules_card_transfer(p_version int) returns boolean
language sql stable as $$
  select coalesce((select card_transfer from game_rule_versions where version = p_version), true)
$$;

create or replace function _match_no_energy_chest(p_match_id uuid) returns text
language sql stable as $$
  select g.no_energy_chest from matches m join game_rule_versions g on g.version = m.rules_version
  where m.id = p_match_id
$$;

-- ---------------------------------------------------------------------
-- R2: mac bitisi (007'den; yalniz CEZA blogu ve koruma +1 surume bagli)
-- ---------------------------------------------------------------------
{finish}

-- ---------------------------------------------------------------------
-- R1: mac sandigi (031'den; enerjisizse surumun sandigi)
-- ---------------------------------------------------------------------
{grant}

-- ---------------------------------------------------------------------
-- R3: galibiyette +1 gelisim kopyasi
-- ---------------------------------------------------------------------
create or replace function _grant_win_progress_copy(p_user_id uuid, p_match_id uuid)
returns jsonb
language plpgsql as $$
declare
  v_adet  int;
  v_kart  cards%rowtype;
  v_max   int := coalesce((_level_rules() ->> 'max_level')::int, 10);
  v_eski  economy_ledger%rowtype;
begin
  select g.win_progress_copies into v_adet
  from matches m join game_rule_versions g on g.version = m.rules_version where m.id = p_match_id;
  if coalesce(v_adet, 0) < 1 then
    return null;
  end if;
  perform pg_advisory_xact_lock(hashtext('wincopy:' || p_user_id::text));
  select * into v_eski from economy_ledger where idempotency_key = 'wincopy:' || p_match_id || ':' || p_user_id;
  if found then
    return v_eski.items;
  end if;

  -- Aktif destedeki, hala sahip olunan, seviyesi < max olan kartlardan biri
  select c.* into v_kart
  from decks d
  join deck_cards dc on dc.deck_id = d.id
  join user_cards uc on uc.id = dc.user_card_id and uc.owner_id = p_user_id
  join cards c on c.id = uc.card_id
  left join player_progress pp on pp.user_id = p_user_id and pp.card_id = c.id
  where d.owner_id = p_user_id and d.is_active and coalesce(pp.level, 1) < v_max
  order by random()
  limit 1;
  if not found then
    return null;
  end if;

  insert into player_progress (user_id, card_id, copies) values (p_user_id, v_kart.id, v_adet)
  on conflict (user_id, card_id) do update
    set copies = player_progress.copies + v_adet, updated_at = now();
  perform _ledger_add(p_user_id, 'win_progress_copy', 0,
                      jsonb_build_object('card_id', v_kart.id, 'full_name', v_kart.full_name,
                                         'tier', v_kart.tier, 'copies', v_adet),
                      'match', p_match_id::text, 'wincopy:' || p_match_id || ':' || p_user_id);
  return jsonb_build_object('card_id', v_kart.id, 'full_name', v_kart.full_name, 'tier', v_kart.tier,
                            'copies', v_adet);
end;
$$;

create or replace function _economy_win_copy_on_match_finished()
returns trigger
language plpgsql as $$
declare
  v_tur int;
begin
  if not economy_flag('economy_v2_enabled') or new.winner_id is null or new.is_draw then
    return null;
  end if;
  select count(*) into v_tur from match_rounds where match_id = new.id;
  if v_tur < coalesce((_chest_rules() ->> 'min_rounds')::int, 4) then
    return null;   -- K6
  end if;
  begin
    perform _grant_win_progress_copy(new.winner_id, new.id);
  exception when others then
    insert into economy_errors (context, user_id, source_id, error)
    values ('win_progress_copy', new.winner_id, new.id::text, sqlerrm);
  end;
  return null;
end;
$$;

drop trigger if exists trg_economy_win_copy_finished on matches;
create trigger trg_economy_win_copy_finished
  after update of status on matches
  for each row
  when (new.status = 'finished' and old.status is distinct from 'finished')
  execute function _economy_win_copy_on_match_finished();

-- ---------------------------------------------------------------------
-- Mac sonu ekrani: sandik + enerjisiz bilgisi + galibiyet kopyasi
-- ---------------------------------------------------------------------
create or replace function get_source_chest(p_user_id uuid, p_source_type text, p_source_id text)
returns jsonb
language sql stable as $$
  select coalesce(
    (select _chest_json(c)
            || jsonb_build_object('no_energy', exists (
                 select 1 from economy_ledger l where l.user_id = p_user_id
                   and l.entry_type = 'chest_skipped_no_energy'
                   and l.source_type = p_source_type and l.source_id = p_source_id))
     from user_chests c
     where c.user_id = p_user_id and c.source_type = p_source_type and c.source_id = p_source_id),
    case when exists (select 1 from economy_ledger l
                      where l.user_id = p_user_id and l.entry_type = 'chest_skipped_no_energy'
                        and l.source_type = p_source_type and l.source_id = p_source_id)
         then jsonb_build_object('skipped', 'no_energy') end,
    '{{}}'::jsonb)
  || coalesce((select jsonb_build_object('win_copy', l.items) from economy_ledger l
               where p_source_type = 'match'
                 and l.idempotency_key = 'wincopy:' || p_source_id || ':' || p_user_id), '{{}}'::jsonb)
$$;

-- ---------------------------------------------------------------------
-- YONETICI: 60 gunden eski sezonlar icin guvenli onarim (036'nin eki)
-- ---------------------------------------------------------------------
-- Varsayilan KURU CALISMA: yalniz eksikleri listeler, hicbir sey vermez.
-- p_dry_run => false ile verir. Tek sefer guvencesi 036 ile ayni
-- (season_claims birincil anahtari + defter anahtari). Yalniz KAPANMIS
-- sezonlarda calisir. Kullanim (psql, yonetici):
--   select admin_repair_season_rewards('<sezon id>');           -- rapor
--   select admin_repair_season_rewards('<sezon id>', false);    -- uygula
create or replace function admin_repair_season_rewards(p_season_id uuid, p_dry_run boolean default true)
returns jsonb
language plpgsql as $$
declare
  k       jsonb := _season_rules();
  s       seasons%rowtype;
  us      user_seasons%rowtype;
  t       season_tiers%rowtype;
  v_eksik jsonb := '[]'::jsonb;
  v_n     int := 0;
  v_hata  int := 0;
begin
  select * into s from seasons where id = p_season_id;
  if not found then
    raise exception 'season_not_found: Sezon bulunamadi.';
  end if;
  if s.status <> 'closed' then
    raise exception 'season_not_closed: Yalniz kapanmis sezon onarilir (once close_due_seasons).';
  end if;
  for us in select * from user_seasons where season_id = s.id loop
    for t in select st.* from season_tiers st
             where st.season_id = s.id and st.tier <= _season_tier_of(us.xp, k)
               and (st.track = 'free' or us.premium)
               and not exists (select 1 from season_claims c
                               where c.user_id = us.user_id and c.season_id = s.id
                                 and c.tier = st.tier and c.track = st.track)
             order by st.tier, st.track loop
      v_eksik := v_eksik || jsonb_build_object('user_id', us.user_id, 'tier', t.tier, 'track', t.track);
      if not p_dry_run then
        begin
          perform _season_grant(us.user_id, s.id, t.tier, t.track, true);
          v_n := v_n + 1;
        exception when others then
          v_hata := v_hata + 1;
        end;
      end if;
    end loop;
  end loop;
  if not p_dry_run then
    update economy_errors e set resolved_at = now()
    where e.context = 'season_close' and e.resolved_at is null
      and split_part(e.source_id, ':', 1) = s.id::text
      and exists (select 1 from season_claims c
                  where c.user_id = e.user_id and c.season_id = s.id
                    and c.tier::text = split_part(e.source_id, ':', 2)
                    and c.track = split_part(e.source_id, ':', 3));
  end if;
  return jsonb_build_object('season', s.name, 'dry_run', p_dry_run, 'missing', jsonb_array_length(v_eksik),
                            'granted', v_n, 'failed', v_hata, 'items', v_eksik);
end;
$$;
"""

(MIG / '037_ranked_rewards_v2.sql').write_text(MIG037, encoding='utf-8')

# =====================================================================
# 038: kaynaksız 7 item
# =====================================================================
ac = fonksiyon('034_items.sql', 'open_chest')
ac = degistir(ac, """  v_result   jsonb;
begin""", """  v_result   jsonb;
  v_ekstra   jsonb := '{}'::jsonb;   -- 038
  v_slug     text;                   -- 038
  e          record;                 -- 038
begin""")
ac = ekle(ac, """  v_ledger := _ledger_add(p_user_id, 'chest_open', v_altin,""", """  -- 038: ek item odulleri (anahtar / ustalik kitabi). Yalniz sandigin
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

""", once=True)
ac = degistir(ac, """    'cards', v_kartlar, 'coins', v_altin, 'jokers', v_joker,""",
              """    'cards', v_kartlar, 'coins', v_altin, 'jokers', v_joker, 'extras', v_ekstra,""")

gorev = fonksiyon('035_season_pass.sql', '_mission_event')
gorev = ekle(gorev, """      perform _season_add_xp(p_user_id, m.xp, 'mission', m.slug || ':' || v_key,
                             'mission:' || p_user_id || ':' || m.slug || ':' || v_key);""", """
      -- 038: gorevin item odulu (or. haftalik 10 galibiyet -> gelisim indirimi)
      if economy_flag('item_sources_v2') and m.reward_items <> '{}'::jsonb then
        for r in select key, value::int as n from jsonb_each_text(m.reward_items) loop
          perform grant_item(p_user_id, r.key, r.n, 'mission', m.slug || ':' || v_key,
                             'mission_item:' || p_user_id || ':' || m.slug || ':' || v_key || ':' || r.key);
        end loop;
      end if;""")
gorev = degistir(gorev, """  v_key  text;
begin""", """  v_key  text;
  r      record;   -- 038
begin""")

MIG038 = f"""-- =====================================================================
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
       payload || '{{"extras": {{"gold": {{"chest_key": 100}},
                                 "legend": {{"chest_key": 400, "mastery_book": 300}}}},
                    "extras_book_tiers": {{"bronze": 35, "silver": 35, "diamond": 25, "legend": 5}}}}'::jsonb,
       '038: sandik ek item odulleri (item_sources_v2 ile)'
from economy_config_versions where kind = 'chest_rules' and version = 1
on conflict (kind, version) do nothing;

alter table missions add column if not exists reward_items jsonb not null default '{{}}'::jsonb;
update missions set reward_items = '{{"level_discount_25": 1}}'::jsonb
where slug = 'weekly_win_10' and reward_items = '{{}}'::jsonb;

update item_definitions set is_active = false where slug = 'event_ticket' and is_active;

-- ---------------------------------------------------------------------
-- Sandik acilisi (034'ten; yalniz 038 blogu)
-- ---------------------------------------------------------------------
{ac}

-- ---------------------------------------------------------------------
-- Gorev olayi (035'ten; yalniz 038 blogu)
-- ---------------------------------------------------------------------
{gorev}

-- Gorevler: odul itemleri istemciye
create or replace function _mission_reward_items(p_slug text) returns jsonb
language sql stable as $$ select reward_items from missions where slug = p_slug $$;
"""
(MIG / '038_item_sources.sql').write_text(MIG038, encoding='utf-8')
print('037 ve 038 uretildi')
