#!/usr/bin/env bash
# =====================================================================
# ES ZAMANLI DUELLO (039, kural surumu 4) — YARIS (CONCURRENCY) TESTI
# =====================================================================
# Ayni maci AYNI ANDA ilerletmeye calisan birden fazla oturum (birden
# fazla sunucu ornegi / zamanlayici, ya da iki kez basilan "oyna" dugmesi)
# bir turu IKI KEZ cozmemeli, bir oyuncuya bir turda iki kart oynatmamali
# ve odulu iki kez vermemeli.
#
# Gecici bir veritabani kurar, sonunda SILER; mevcut veritabanina dokunmaz.
#
#   PGHOST=127.0.0.1 PGUSER=futbol PGPASSWORD=... bash scripts/esz-zamanli-yaris-testi.sh
#
#   1. Mevki suresi gecmis: 8 oturum ayni anda advance -> tek mevki secimi
#   2. Secim suresi gecmis: 8 oturum ayni anda advance -> tek tur sonucu
#   3. Ayni oyuncu ayni turda 2 farkli karti AYNI ANDA oynar -> yalniz biri
#   4. Iki oyuncu ayni anda oynar -> tur bir kez cozulur
#   5. Mac 4 paralel "sunucu" zamanlayicisiyla sonuna kadar oynanir ->
#      her turda tam 2 hamle, tek sonuc, oyuncu basina tek mac sandigi
# =====================================================================
set -euo pipefail
PSQL="${PSQL:-psql}"
export PGHOST="${PGHOST:-127.0.0.1}" PGUSER="${PGUSER:-futbol}"
export PGOPTIONS="${PGOPTIONS:--c client_min_messages=warning}"
KOK="$(cd "$(dirname "$0")/.." && pwd)"
DB="futbol_yaris_$$"
sql() { "$PSQL" -d "$DB" -v ON_ERROR_STOP=1 -q -tA -c "$1"; }
trap '"$PSQL" -d postgres -q -c "drop database if exists $DB" >/dev/null 2>&1 || true' EXIT
"$PSQL" -d postgres -q -c "create database $DB" >/dev/null
for m in $(cd "$KOK" && git ls-files 'database/migrations/*.sql' | sort); do
  "$PSQL" -d "$DB" -v ON_ERROR_STOP=1 -q -1 -f "$KOK/$m" >/dev/null
done
sql "insert into users (email, password_hash, username) values ('y1@test.local','x','yaris_1'),('y2@test.local','x','yaris_2');
     select grant_starter_pack(id) from users where username like 'yaris_%';" >/dev/null
sql "insert into economy_config_versions (kind, version, payload, note)
     select 'feature_flags', max(version) + 1,
            (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1)
              || '{\"economy_v2_enabled\": true, \"ranked_rewards_v2\": true, \"duel_v4\": true}'::jsonb, 'yaris testi'
     from economy_config_versions where kind = 'feature_flags';" >/dev/null

HATA=0
kontrol() { if [ "$2" = "$3" ]; then echo "GECTI  $1"; else echo "KALDI  $1 -> beklenen $3, gelen $2"; HATA=1; fi; }
A=$(sql "select id from users where username = 'yaris_1'")
B=$(sql "select id from users where username = 'yaris_2'")
M=$(sql "select _create_match('$A', (select id from decks where owner_id = '$A' and is_active), '{}',
                              '$B', (select id from decks where owner_id = '$B' and is_active), '{}')")
kontrol "mac surum 4, mevki asamasinda" "$(sql "select rules_version || ':' || phase from matches where id = '$M'")" "4:position"

# N oturumu ayni anda calistirir (her biri ayri psql sureci = ayri baglanti)
paralel() {
  local n=$1 q=$2 i
  for i in $(seq "$n"); do "$PSQL" -d "$DB" -q -tA -c "$q" >/dev/null 2>&1 & done
  wait
}
suresi_gecti() { sql "update matches set turn_deadline = now() - interval '1 second' where id = '$M'" >/dev/null; }

# ---- 1) Mevki: 8 zamanlayici ayni anda ----
suresi_gecti
paralel 8 "select advance_simultaneous_match('$M')"
kontrol "8 paralel zamanlayici: tek mevki secimi, asama pick" "$(sql "select phase || ':' || round_number from matches where id = '$M'")" "pick:1"
kontrol "mevki secimi sayaca sayilmadi" "$(sql "select sum(auto_streak) from match_players where match_id = '$M'")" "0"

# ---- 2) Secim: 8 zamanlayici ayni anda ----
suresi_gecti
paralel 8 "select advance_simultaneous_match('$M')"
kontrol "8 paralel zamanlayici: tur 1 tek kez cozuldu" "$(sql "select count(*) from match_rounds where match_id = '$M'")" "1"
kontrol "tur 1'de tam 2 hamle" "$(sql "select count(*) from match_moves where match_id = '$M' and round_number = 1")" "2"
kontrol "otomatik kart sayaci her oyuncuda 1" "$(sql "select string_agg(auto_streak::text, ',' order by user_id) from match_players where match_id = '$M'")" "1,1"

# ---- 3) Ayni oyuncu ayni anda iki kart ----
L=$(sql "select lead_player_id from matches where id = '$M'")
POS=$(sql "select h.position from match_hands h where h.match_id = '$M' and h.user_id = '$L' and not h.is_played
           and exists (select 1 from match_hands o where o.match_id = '$M' and o.user_id <> '$L' and not o.is_played and o.position = h.position)
           group by h.position order by count(*) desc limit 1")
sql "select choose_position('$L', '$M', '$POS')" >/dev/null
D=$(sql "select case when player1_id = '$L' then player2_id else player1_id end from matches where id = '$M'")
TUR=$(sql "select round_number from matches where id = '$M'")
K1=$(sql "select user_card_id from match_hands where match_id = '$M' and user_id = '$D' and not is_played and position = '$POS' order by user_card_id limit 1")
K2=$(sql "select user_card_id from match_hands where match_id = '$M' and user_id = '$D' and not is_played and position = '$POS' order by user_card_id desc limit 1")
"$PSQL" -d "$DB" -q -tA -c "select play_card('$D', '$M', '$K1')" >/dev/null 2>&1 &
"$PSQL" -d "$DB" -q -tA -c "select play_card('$D', '$M', '$K2')" >/dev/null 2>&1 &
"$PSQL" -d "$DB" -q -tA -c "select play_card('$D', '$M', '$K1')" >/dev/null 2>&1 &
wait
kontrol "ayni oyuncu 3 paralel istek: turda tek hamle" "$(sql "select count(*) from match_moves where match_id = '$M' and round_number = $TUR and user_id = '$D'")" "1"
kontrol "elden yalniz 1 kart dustu" "$(sql "select count(*) from match_hands where match_id = '$M' and user_id = '$D' and played_round = $TUR")" "1"
kontrol "tur henuz cozulmedi (rakip oynamadi)" "$(sql "select count(*) from match_rounds where match_id = '$M' and round_number = $TUR")" "0"

# ---- 4) Diger oyuncu oynarken 4 zamanlayici da ayni anda calisir ----
KL=$(sql "select user_card_id from match_hands where match_id = '$M' and user_id = '$L' and not is_played and position = '$POS' limit 1")
"$PSQL" -d "$DB" -q -tA -c "select play_card('$L', '$M', '$KL')" >/dev/null 2>&1 &
sql "update matches set turn_deadline = now() - interval '1 second' where id = '$M' and round_number = $TUR and phase = 'pick'" >/dev/null 2>&1 || true
paralel 4 "select advance_simultaneous_match('$M')"
wait
kontrol "oyuncu + zamanlayicilar yarisinca tur $TUR tek kez cozuldu" "$(sql "select count(*) from match_rounds where match_id = '$M' and round_number = $TUR")" "1"
kontrol "tur $TUR'de tam 2 hamle" "$(sql "select count(*) from match_moves where match_id = '$M' and round_number = $TUR")" "2"

# ---- 5) Sonuna kadar: 4 paralel "sunucu" ----
for i in $(seq 40); do
  [ "$(sql "select status from matches where id = '$M'")" = "active" ] || break
  suresi_gecti
  paralel 4 "select advance_simultaneous_matches()"
done
DURUM=$(sql "select status from matches where id = '$M'")
kontrol "mac bitti" "$DURUM" "finished"
echo "       ($(sql "select count(*) from match_rounds where match_id = '$M'") tur; bitis: $(sql "select coalesce(winner_id::text, 'kazanan yok (iki taraf da sure asimi)') from matches where id = '$M'"))"
kontrol "her turda tam 2 hamle" "$(sql "select count(*) from (select round_number from match_moves where match_id = '$M' group by 1 having count(*) <> 2) x")" "0"
kontrol "her turun tek sonucu var (tur sayisi = hamle turu sayisi)" \
  "$(sql "select (select count(*) from match_rounds where match_id = '$M') = (select count(distinct round_number) from match_moves where match_id = '$M')")" "t"
kontrol "oyuncu basina tek mac sandigi" \
  "$(sql "select coalesce(max(n), 0) from (select count(*) n from user_chests where source_type = 'match' and source_id = '$M' group by user_id) x")" "1"
kontrol "zamanlayici hatasi kaydedilmedi" "$(sql "select count(*) from economy_errors where context = 'advance_simultaneous'")" "0"
kontrol "kart transferi yok" "$(sql "select count(*) from card_transfers where match_id = '$M'")" "0"

[ "$HATA" = 0 ] && echo "SONUC: yaris testleri gecti" || { echo "SONUC: KALDI"; exit 1; }
