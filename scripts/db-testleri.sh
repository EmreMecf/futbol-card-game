#!/usr/bin/env bash
# =====================================================================
# VERITABANI TESTLERI (yerelde ve GitHub Actions'ta ayni betik)
# =====================================================================
# Kullanim:
#   PGHOST=127.0.0.1 PGUSER=futbol PGPASSWORD=... bash scripts/db-testleri.sh
#
# Gecici veritabanlari olusturur ve sonunda SILER; mevcut veritabanina
# dokunmaz. Sadece git'e KAYITLI migration'lari kullanir (yarim kalmis,
# commitlenmemis dosyalar teste girmez).
#
#   1. Sifirdan kurulum   : butun migration'lar, her biri TEK ISLEMDE (-1)
#   2. Kural testleri     : database/tests/*.sql
#   3. Tekrar calistirma  : migration'lar ikinci kez uygulanabilmeli
#   4. Yukseltme          : eski surumde baslayan mac, son migration
#                           uygulandiktan sonra hatasiz bitmeli ve kendi
#                           kural surumunu korumali
# =====================================================================
set -euo pipefail

PSQL="${PSQL:-psql}"
export PGHOST="${PGHOST:-127.0.0.1}"
export PGUSER="${PGUSER:-futbol}"
KOK="$(cd "$(dirname "$0")/.." && pwd)"
ONEK="futbol_test_$$"

mapfile -t MIGRATIONLAR < <(cd "$KOK" && git ls-files 'database/migrations/*.sql' | sort)
SON="${MIGRATIONLAR[-1]}"

sql()  { "$PSQL" -d "$1" -v ON_ERROR_STOP=1 -q -tA -c "$2"; }
dosya(){ "$PSQL" -d "$1" -v ON_ERROR_STOP=1 -q -1 -f "$KOK/$2" >/dev/null 2>&1 || { echo "HATA: $2 ($1)"; "$PSQL" -d "$1" -v ON_ERROR_STOP=1 -q -1 -f "$KOK/$2" 2>&1 | grep -i error | head -3; return 1; }; }
yeni_db() { "$PSQL" -d postgres -q -c "drop database if exists $1" >/dev/null 2>&1; "$PSQL" -d postgres -q -c "create database $1" >/dev/null; }
temizle() { for d in "${ONEK}_a" "${ONEK}_b"; do "$PSQL" -d postgres -q -c "drop database if exists $d" >/dev/null 2>&1 || true; done; }
trap temizle EXIT

# Iki test oyuncusu + baslangic kadrolari (testler bunlari kullanir)
oyuncular() {
  sql "$1" "insert into users (email, password_hash, username) values
            ('t1@test.local','x','dbtest_1'),('t2@test.local','x','dbtest_2')
            on conflict do nothing;" >/dev/null
  sql "$1" "select grant_starter_pack(id) from users where username like 'dbtest_%';" >/dev/null
}

echo "== 1) Sifirdan kurulum (${#MIGRATIONLAR[@]} migration, her biri tek islemde)"
A="${ONEK}_a"; yeni_db "$A"
for m in "${MIGRATIONLAR[@]}"; do dosya "$A" "$m"; done
oyuncular "$A"
echo "   GECTI"

echo "== 2) Kural testleri"
for t in "$KOK"/database/tests/*.sql; do
  cikti="$("$PSQL" -d "$A" -v ON_ERROR_STOP=1 -q -f "$t" 2>&1)" || { echo "   KALDI: $(basename "$t")"; echo "$cikti" | grep -E "BASARISIZ|ERROR" | head -3; exit 1; }
  echo "   GECTI: $(basename "$t")"
done

echo "== 3) Tekrar calistirma (migration'lar ikinci kez)"
for m in "${MIGRATIONLAR[@]}"; do
  if ! "$PSQL" -d "$A" -v ON_ERROR_STOP=1 -q -1 -f "$KOK/$m" >/dev/null 2>&1; then
    echo "   UYARI: $m ikinci kez uygulanamiyor (tekrar calistirilamaz)"
    TEKRAR_SORUNU=1
  fi
done
[ -z "${TEKRAR_SORUNU:-}" ] && echo "   GECTI"

echo "== 4) Yukseltme: mac SURERKEN son migration ($SON)"
B="${ONEK}_b"; yeni_db "$B"
for m in "${MIGRATIONLAR[@]}"; do [ "$m" = "$SON" ] || dosya "$B" "$m"; done
oyuncular "$B"
MAC="$(sql "$B" "select _create_match(
  (select id from users where username='dbtest_1'),
  (select id from decks where owner_id=(select id from users where username='dbtest_1') and is_active), '{}',
  (select id from users where username='dbtest_2'),
  (select id from decks where owner_id=(select id from users where username='dbtest_2') and is_active), '{}');")"
TUR="do \$\$ declare m matches%rowtype; c uuid; begin
  select * into m from matches where id = '$MAC';
  if m.status <> 'active' then return; end if;
  select user_card_id into c from match_hands where match_id = m.id and user_id = m.current_turn_id
    and not is_played and (m.required_position is null or position = m.required_position) limit 1;
  perform play_card(m.current_turn_id, m.id, c);
end \$\$;"
for _ in 1 2 3 4 5 6 7 8; do sql "$B" "$TUR" >/dev/null; done
SURUM_ONCE="$(sql "$B" "select coalesce((select to_jsonb(m)->>'rules_version' from matches m where id='$MAC'),'yok')")"
dosya "$B" "$SON"
for _ in $(seq 1 30); do sql "$B" "$TUR" >/dev/null; done
DURUM="$(sql "$B" "select status from matches where id='$MAC'")"
SURUM_SONRA="$(sql "$B" "select coalesce((select to_jsonb(m)->>'rules_version' from matches m where id='$MAC'),'yok')")"
echo "   mac: $DURUM, kural surumu once=$SURUM_ONCE sonra=$SURUM_SONRA"
[ "$DURUM" = "finished" ] || { echo "   KALDI: mac bitmedi"; exit 1; }
if [ "$SURUM_ONCE" != "yok" ] && [ "$SURUM_ONCE" != "$SURUM_SONRA" ]; then
  echo "   KALDI: suren macin kural surumu degisti"; exit 1
fi
echo "   GECTI"

if [ -n "${TEKRAR_SORUNU:-}" ]; then
  echo ""
  echo "SONUC: testler gecti; tekrar calistirma UYARILARI var (yukarida)."
else
  echo ""
  echo "SONUC: butun veritabani testleri gecti."
fi
