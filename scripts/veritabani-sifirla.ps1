# =====================================================================
# VERITABANINI SIFIRDAN KUR
# =====================================================================
# TUM VERIYI SILER ve migration dosyalarini bastan calistirir.
# Sema degistirdiginde bunu kullan.
#
# Kullanim:  .\scripts\veritabani-sifirla.ps1
# =====================================================================

$PgKok  = "C:\Users\muhas\futbol-card-db"
$Bin    = "$PgKok\pgsql\bin"
$Proje  = Split-Path -Parent $PSScriptRoot
$env:PGPASSWORD = "futbol_dev_sifre_2026"

Write-Host "DIKKAT: 'futbol_card' veritabanindaki TUM VERI silinecek." -ForegroundColor Yellow
$onay = Read-Host "Devam etmek icin 'evet' yazin"
if ($onay -ne 'evet') {
    Write-Host "Iptal edildi."
    exit 0
}

Write-Host "Veritabani yeniden olusturuluyor..." -ForegroundColor Cyan
& "$Bin\psql.exe" -h 127.0.0.1 -U futbol -d postgres -c "drop database if exists futbol_card;" | Out-Null
& "$Bin\psql.exe" -h 127.0.0.1 -U futbol -d postgres -c "create database futbol_card;" | Out-Null

$dosyalar = Get-ChildItem "$Proje\database\migrations\*.sql" | Sort-Object Name
foreach ($d in $dosyalar) {
    Write-Host "  -> $($d.Name)" -ForegroundColor DarkGray
    & "$Bin\psql.exe" -h 127.0.0.1 -U futbol -d futbol_card -v ON_ERROR_STOP=1 -q -f $d.FullName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "HATA: $($d.Name) calistirilamadi." -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "  Veritabani hazir. Tum migration'lar calisti." -ForegroundColor Green
