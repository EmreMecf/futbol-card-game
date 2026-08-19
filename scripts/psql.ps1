# =====================================================================
# VERITABANINA psql ILE BAGLAN
# =====================================================================
# Kullanim:  .\scripts\psql.ps1
#
# Faydali komutlar:
#   \dt              -> tablolari listele
#   \df              -> fonksiyonlari listele
#   \d users         -> users tablosunun yapisi
#   \q               -> cik
# =====================================================================

$Bin = "C:\Users\muhas\futbol-card-db\pgsql\bin"
$env:PGPASSWORD = "futbol_dev_sifre_2026"
& "$Bin\psql.exe" -h 127.0.0.1 -U futbol -d futbol_card
