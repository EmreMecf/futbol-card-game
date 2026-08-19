# =====================================================================
# BACKEND SUNUCUSUNU BASLAT
# =====================================================================
# Kullanim:  .\scripts\sunucu-baslat.ps1
#
# Once veritabaninin calistigindan emin ol:
#   .\scripts\veritabani-baslat.ps1
# =====================================================================

$Proje = Split-Path -Parent $PSScriptRoot

# ---- Ortam degiskenleri ----
# Uretimde JWT_SECRET'i MUTLAKA degistir!
$env:DB_HOST     = "localhost"
$env:DB_PORT     = "5432"
$env:DB_NAME     = "futbol_card"
$env:DB_USER     = "futbol"
$env:DB_PASSWORD = "futbol_dev_sifre_2026"
$env:PORT        = "8080"
$env:ENVIRONMENT = "development"

Set-Location "$Proje\server"
dart run bin/server.dart
