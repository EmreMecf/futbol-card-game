#!/usr/bin/env bash
# =====================================================================
# GECMIS KULLANICI VERISI DEGISMEDI MI? (SINIR=037: 037 ve sonrasi)
# =====================================================================
# 1. Gecici veritabani: 036'ya kadar migration'lar + iki oyuncu
# 2. Ekonomi acik, ESKI kurallarla gercek maclar oynanir (kart transferi,
#    sandik, XP, seviye kayitlari olusur)
# 3. Kullanici verisinin parmak izi alinir
# 4. 037 ve 038 uygulanir
# 5. Parmak izi tekrar alinir: AYNI olmali (yalniz ayar tablolarina
#    yeni surum satirlari eklenir; kullanici verisi degismez)
#
#   PGHOST=127.0.0.1 PGUSER=futbol PGPASSWORD=... bash scripts/gecmis-veri-kontrolu.sh
# =====================================================================
set -euo pipefail
PSQL="${PSQL:-psql}"
KOK="$(cd "$(dirname "$0")/.." && pwd)"
DB="futbol_gecmis_$$"
sql() { "$PSQL" -d "$DB" -v ON_ERROR_STOP=1 -q -tA -c "$1"; }
trap '"$PSQL" -d postgres -q -c "drop database if exists $DB" >/dev/null 2>&1 || true' EXIT
"$PSQL" -d postgres -q -c "create database $DB" >/dev/null

# Sinir: bu numaradan ONCEKI migration'lar "eski surum", sonrakiler "yeni"
SINIR="${SINIR:-037}"
eski_mi() { local n; n=$(basename "$1" | cut -c1-3); [ "$((10#$n))" -lt "$((10#$SINIR))" ]; }
for m in $(cd "$KOK" && git ls-files 'database/migrations/*.sql' | sort); do
  eski_mi "$m" || continue
  "$PSQL" -d "$DB" -v ON_ERROR_STOP=1 -q -1 -f "$KOK/$m" >/dev/null
done
sql "insert into users (email, password_hash, username) values ('g1@test.local','x','gecmis_1'),('g2@test.local','x','gecmis_2');
     select grant_starter_pack(id) from users where username like 'gecmis_%';" >/dev/null
sql "insert into economy_config_versions (kind, version, payload, note) values ('feature_flags', 2, '{\"economy_v2_enabled\": true}', 'kontrol');" >/dev/null

# Eski kurallarla 6 mac (031 testindeki oynatici ile ayni mantik)
sql "do \$\$
declare a uuid; b uuid; v uuid; m matches%rowtype; c uuid; i int; j int;
begin
  select id into a from users where username = 'gecmis_1';
  select id into b from users where username = 'gecmis_2';
  for i in 1..6 loop
    exit when get_active_match_id(a) is not null;
    v := _create_match(a, (select id from decks where owner_id = a and is_active), '{}',
                       b, (select id from decks where owner_id = b and is_active), '{}');
    j := 0;
    loop
      select * into m from matches where id = v;
      exit when m.status <> 'active' or j > 200;
      select user_card_id into c from match_hands
      where match_id = v and user_id = m.current_turn_id and not is_played
        and (m.required_position is null or position = m.required_position) limit 1;
      if c is null and m.required_position is null then
        perform surrender_match(m.current_turn_id, v); exit;
      end if;
      perform play_card(m.current_turn_id, v, c);
      j := j + 1;
    end loop;
  end loop;
end \$\$;" >/dev/null

IZ="select md5(string_agg(x, '|' order by x)) from (
  select 'u:' || md5(string_agg(id || ':' || coins || ':' || mmr || ':' || protection_slots || ':' || wins || ':' || losses || ':' || draws, ',' order by id)) x from users
  union all select 'uc:' || md5(coalesce(string_agg(id || ':' || owner_id || ':' || card_id, ',' order by id), '')) from user_cards
  union all select 'ct:' || md5(coalesce(string_agg(t::text, ',' order by t::text), '')) from card_transfers t
  union all select 'm:' || md5(coalesce(string_agg(id || ':' || status || ':' || rules_version || ':' || coalesce(winner_id::text, '-'), ',' order by id), '')) from matches
  union all select 'mh:' || md5(coalesce(string_agg(t::text, ',' order by t::text), '')) from match_hands t
  union all select 'ch:' || md5(coalesce(string_agg(t::text, ',' order by t::text), '')) from user_chests t
  union all select 'pp:' || md5(coalesce(string_agg(t::text, ',' order by t::text), '')) from player_progress t
  union all select 'el:' || md5(coalesce(string_agg(t::text, ',' order by t::text), '')) from economy_ledger t
  union all select 'us:' || md5(coalesce(string_agg(t::text, ',' order by t::text), '')) from user_seasons t
  union all select 'ui:' || md5(coalesce(string_agg(t::text, ',' order by t::text), '')) from user_items t
) z"
OZET="select (select count(*) from matches where status = 'finished') || ' mac, ' ||
             (select count(*) from card_transfers) || ' transfer, ' ||
             (select count(*) from user_chests) || ' sandik, ' ||
             (select count(*) from economy_ledger) || ' defter kaydi'"

ONCE=$(sql "$IZ"); echo "once : $(sql "$OZET")  iz=$ONCE"
for m in $(cd "$KOK" && git ls-files 'database/migrations/*.sql' | sort); do
  eski_mi "$m" && continue
  "$PSQL" -d "$DB" -v ON_ERROR_STOP=1 -q -1 -f "$KOK/$m" >/dev/null 2>&1
done
SONRA=$(sql "$IZ"); echo "sonra: $(sql "$OZET")  iz=$SONRA"
echo "yeni kural surumu (anahtar kapali): $(sql 'select current_rules_version()')"
if [ "$ONCE" = "$SONRA" ]; then echo "GECTI: gecmis kullanici verisi degismedi"; else echo "KALDI: kullanici verisi degisti"; exit 1; fi
