# =====================================================================
# BUTUN TESTLERI CALISTIR (FAZ 7 - kalite kontrol)
# =====================================================================
# Kullanim:  .\scripts\testleri-calistir.ps1
#
# Sirayla calisir ve sonunda bir ozet basar:
#   1. Flutter analyze
#   2. Flutter testleri (uygulama)
#   3. Ortak modeller (packages/shared_models)
#   4. Taktik prototipi + denge (packages/tactics_prototype)
#   5. Sunucu analyze + testleri (server)
#   6. Veritabani testleri (database/tests/*.sql)   -> veritabani acik olmali
#   7. Uctan uca mac + gercek zamanli (server/tool)  -> sunucu acik olmali
#
# Veritabani veya sunucu kapaliysa o adimlar "ATLANDI" yazilir;
# "GECTI" sayilmaz.
# =====================================================================

$Proje = Split-Path -Parent $PSScriptRoot
$Bin   = "C:\Users\muhas\futbol-card-db\pgsql\bin"
$env:PGPASSWORD = "futbol_dev_sifre_2026"

$sonuclar = [System.Collections.Generic.List[object]]::new()

function Adim([string]$ad, [string]$klasor, [scriptblock]$komut) {
    Write-Host ""
    Write-Host "=== $ad ===" -ForegroundColor Cyan
    Push-Location $klasor
    try {
        & $komut
        $durum = if ($LASTEXITCODE -eq 0) { "GECTI" } else { "KALDI" }
    } catch {
        Write-Host $_ -ForegroundColor Red
        $durum = "KALDI"
    } finally {
        Pop-Location
    }
    $sonuclar.Add([pscustomobject]@{ Adim = $ad; Durum = $durum })
}

function Atla([string]$ad, [string]$sebep) {
    Write-Host ""
    Write-Host "=== $ad === ATLANDI: $sebep" -ForegroundColor Yellow
    $sonuclar.Add([pscustomobject]@{ Adim = $ad; Durum = "ATLANDI ($sebep)" })
}

Adim "Flutter analyze"      $Proje { flutter analyze }
Adim "Flutter testleri"     $Proje { flutter test }
Adim "Ortak modeller"       "$Proje\packages\shared_models" { dart test }
Adim "Taktik prototipi"     "$Proje\packages\tactics_prototype" { dart test }
Adim "Icerik uretim hatti"  "$Proje\packages\content_pipeline" { dart test }
Adim "Sunucu analyze"       "$Proje\server" { dart analyze }
Adim "Sunucu testleri"      "$Proje\server" { dart test }

# ---- Veritabani ----
& "$Bin\pg_isready.exe" -h 127.0.0.1 -q
if ($LASTEXITCODE -eq 0) {
    foreach ($dosya in Get-ChildItem "$Proje\database\tests\*.sql" | Sort-Object Name) {
        Adim "SQL: $($dosya.Name)" $Proje {
            & "$Bin\psql.exe" -h 127.0.0.1 -U futbol -d futbol_card -v ON_ERROR_STOP=1 -q -f $dosya.FullName
        }
    }
} else {
    Atla "SQL testleri" "veritabani kapali (.\scripts\veritabani-baslat.ps1)"
}

# ---- Canli sunucu ----
$sunucuAcik = $false
try {
    $cevap = Invoke-WebRequest -Uri "http://localhost:8080/api/health" -UseBasicParsing -TimeoutSec 3
    $sunucuAcik = ($cevap.StatusCode -eq 200)
} catch {}

if ($sunucuAcik) {
    Adim "Uctan uca mac"        "$Proje\server" { dart run tool/full_match_test.dart }
    Adim "Gercek zamanli zincir" "$Proje\server" { dart run tool/realtime_test.dart }
} else {
    Atla "Uctan uca testler" "sunucu kapali (.\scripts\sunucu-baslat.ps1)"
}

# ---- Ozet ----
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " OZET" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
foreach ($s in $sonuclar) {
    $renk = switch -Wildcard ($s.Durum) { "GECTI" { "Green" } "KALDI" { "Red" } default { "Yellow" } }
    Write-Host ("  {0,-30} {1}" -f $s.Adim, $s.Durum) -ForegroundColor $renk
}

$kalan = @($sonuclar | Where-Object { $_.Durum -eq "KALDI" }).Count
if ($kalan -gt 0) {
    Write-Host ""
    Write-Host "  $kalan adim KALDI." -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "  Kalan adim yok." -ForegroundColor Green
exit 0
