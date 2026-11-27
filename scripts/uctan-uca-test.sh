#!/usr/bin/env bash
# =====================================================================
# UÇTAN UCA TEST (gerçek Chrome + gerçek sunucu + gerçek veritabanı)
# =====================================================================
# Kullanım (yerelde ve GitHub Actions'ta aynı betik):
#   PGHOST=127.0.0.1 PGUSER=futbol PGPASSWORD=... \
#   CHROMEDRIVER=/yol/chromedriver bash scripts/uctan-uca-test.sh
#
# Ne yapar?
#   1. GEÇİCİ bir veritabanı kurar (git'e kayıtlı bütün migration'lar);
#      senin veritabanına dokunmaz, sonunda siler.
#   2. Yalnız bu geçici veritabanında antrenman modunu açar.
#   3. API sunucusunu bu veritabanıyla ayrı bir portta başlatır.
#   4. chromedriver'ı başlatır ve testi Chrome'da çalıştırır:
#      integration_test/uctan_uca_test.dart
#   5. Sunucuyu, chromedriver'ı ve veritabanını kapatır/siler.
#
# Ayarlar (isteğe bağlı):
#   FLUTTER       flutter komutu (varsayılan: flutter)
#   PSQL          psql komutu (varsayılan: psql)
#   CHROMEDRIVER  chromedriver yolu (varsayılan: PATH'teki chromedriver)
#   E2E_PORT      API portu (varsayılan: 8099)
#   E2E_BOYUT     tarayıcı penceresi (varsayılan: 430,900 → telefon düzeni)
#   E2E_HEADLESS  1 ise Chrome görünmez çalışır (CI)
# =====================================================================
set -euo pipefail

KOK="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="${FLUTTER:-flutter}"
PSQL="${PSQL:-psql}"
CHROMEDRIVER="${CHROMEDRIVER:-chromedriver}"
PORT="${E2E_PORT:-8099}"
BOYUT="${E2E_BOYUT:-430,900}"
export PGHOST="${PGHOST:-127.0.0.1}"
export PGUSER="${PGUSER:-futbol}"
export PGCLIENTENCODING=UTF8
DB="futbol_e2e_$$"
GUNLUK="$(mktemp -d)"
SUNUCU_PID=""
SURUCU_PID=""

temizle() {
  [ -n "$SUNUCU_PID" ] && kill "$SUNUCU_PID" 2>/dev/null || true
  [ -n "$SURUCU_PID" ] && kill "$SURUCU_PID" 2>/dev/null || true
  # Windows'ta "dart run" alt süreç açar: portu tutan süreç de kapatılır
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "$PORT/tcp" 4444/tcp >/dev/null 2>&1 || true
  elif command -v taskkill >/dev/null 2>&1; then
    for pid in $(netstat -ano 2>/dev/null | grep -E "[:.]($PORT|4444) .*LISTEN" | awk '{print $NF}' | sort -u); do
      taskkill //F //PID "$pid" >/dev/null 2>&1 || true
    done
  fi
  sleep 1
  "$PSQL" -d postgres -q -c "drop database if exists $DB" >/dev/null 2>&1 || true
}
trap temizle EXIT

echo "== 1) Geçici veritabanı: $DB"
"$PSQL" -d postgres -q -c "create database $DB" >/dev/null
mapfile -t MIGRATIONLAR < <(cd "$KOK" && git ls-files 'database/migrations/*.sql' | sort)
for m in "${MIGRATIONLAR[@]}"; do
  "$PSQL" -d "$DB" -v ON_ERROR_STOP=1 -q -1 -f "$KOK/$m" >/dev/null 2>"$GUNLUK/mig.txt" \
    || { echo "HATA: $m"; head -5 "$GUNLUK/mig.txt"; exit 1; }
done
echo "   ${#MIGRATIONLAR[@]} migration uygulandı"

echo "== 2) Antrenman modu (yalnız bu geçici veritabanında)"
"$PSQL" -d "$DB" -v ON_ERROR_STOP=1 -q -c "
  insert into economy_config_versions(kind, version, payload, note)
  select 'feature_flags', version + 1, payload || '{\"training_mode\": true}'::jsonb, 'e2e: antrenman acik'
  from economy_config_versions where kind = 'feature_flags'
  order by version desc limit 1;" >/dev/null

echo "== 3) API sunucusu (port $PORT)"
(
  cd "$KOK/server"
  DB_HOST="$PGHOST" DB_NAME="$DB" DB_USER="$PGUSER" DB_PASSWORD="${PGPASSWORD:-}" \
  PORT="$PORT" ENVIRONMENT=development AUTH_RATE_LIMIT=1000 SWEEP_INTERVAL_SECONDS=1 \
    dart run bin/server.dart >"$GUNLUK/sunucu.txt" 2>&1
) &
SUNUCU_PID=$!
for _ in $(seq 1 90); do
  curl -sf "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1 && break
  sleep 2
done
curl -sf "http://127.0.0.1:$PORT/api/health" >/dev/null || { echo "HATA: sunucu açılmadı"; tail -20 "$GUNLUK/sunucu.txt"; exit 1; }
echo "   hazır"

echo "== 4) chromedriver"
"$CHROMEDRIVER" --port=4444 >"$GUNLUK/chromedriver.txt" 2>&1 &
SURUCU_PID=$!
for _ in $(seq 1 30); do
  curl -sf http://127.0.0.1:4444/status >/dev/null 2>&1 && break
  sleep 1
done
curl -sf http://127.0.0.1:4444/status >/dev/null || { echo "HATA: chromedriver açılmadı"; cat "$GUNLUK/chromedriver.txt"; exit 1; }
echo "   hazır ($("$CHROMEDRIVER" --version | head -1))"

echo "== 5) Test Chrome'da çalışıyor (pencere $BOYUT)"
CIHAZ=(-d chrome)
[ "${E2E_HEADLESS:-0}" = "1" ] && CIHAZ=(-d web-server --browser-name=chrome --headless)
cd "$KOK"
rm -f build/integration_response_data.json
if "$FLUTTER" drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/uctan_uca_test.dart \
    "${CIHAZ[@]}" --browser-dimension="$BOYUT" \
    --dart-define=API_BASE_URL="http://127.0.0.1:$PORT" 2>&1 | tee "$GUNLUK/test.txt" | grep -E "BEKLENEN|Adımlar|Ekran|Rota|All tests passed|Some tests failed|Error" ; then :; fi
if grep -q "All tests passed" "$GUNLUK/test.txt"; then
  echo "   GEÇTİ"
  [ -f build/integration_response_data.json ] && cat build/integration_response_data.json
  exit 0
fi
echo "   KALDI — test çıktısının sonu:"
tail -40 "$GUNLUK/test.txt"
echo "--- sunucu günlüğünün sonu:"
tail -20 "$GUNLUK/sunucu.txt"
exit 1
