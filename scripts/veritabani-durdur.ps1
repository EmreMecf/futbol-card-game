# =====================================================================
# VERITABANINI DURDUR
# =====================================================================
$PgKok = "C:\Users\muhas\futbol-card-db"
$Bin   = "$PgKok\pgsql\bin"
$Data  = "$PgKok\data"

Write-Host "Veritabani durduruluyor..." -ForegroundColor Cyan
& "$Bin\pg_ctl.exe" -D $Data -m fast -w stop

if ($LASTEXITCODE -eq 0) {
    Write-Host "Durduruldu." -ForegroundColor Green
} else {
    Write-Host "Zaten calismiyor olabilir." -ForegroundColor Yellow
}
