# =====================================================================
# VERITABANINI BASLAT
# =====================================================================
# Kullanim:  .\scripts\veritabani-baslat.ps1
#
# PostgreSQL 17.5 tasinabilir surumu C:\Users\muhas\futbol-card-db
# klasorunde duruyor. Windows'a hicbir sey kurulmadi; bu klasoru
# silmek her seyi temizler.
#
# NOT: Veritabani kasitli olarak OneDrive DISINDA. OneDrive canli bir
# veritabani klasorunu senkronize etmeye calisirsa dosya kilitleri
# olusur ve veri bozulabilir.
# =====================================================================

$PgKok = "C:\Users\muhas\futbol-card-db"
$Bin   = "$PgKok\pgsql\bin"
$Data  = "$PgKok\data"
$Log   = "$PgKok\postgres.log"

if (-not (Test-Path "$Bin\pg_ctl.exe")) {
    Write-Host "HATA: PostgreSQL bulunamadi -> $Bin" -ForegroundColor Red
    exit 1
}

# Zaten calisiyor mu?
& "$Bin\pg_ctl.exe" -D $Data status *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Veritabani zaten calisiyor (port 5432)." -ForegroundColor Yellow
    exit 0
}

Write-Host "Veritabani baslatiliyor..." -ForegroundColor Cyan
& "$Bin\pg_ctl.exe" -D $Data -l $Log -o "-p 5432" -w start

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "  Veritabani hazir!" -ForegroundColor Green
    Write-Host "  Adres    : localhost:5432"
    Write-Host "  Veritabani: futbol_card"
    Write-Host "  Kullanici : futbol"
    Write-Host "  Log      : $Log"
} else {
    Write-Host "Baslatilamadi. Log dosyasina bak: $Log" -ForegroundColor Red
}
