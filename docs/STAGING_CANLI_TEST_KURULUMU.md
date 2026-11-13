# Futbol Card Arena — Gercek sunucuya gecis ve iki Android telefonla PvP staging

Durum: **yalniz deployment iskeleti hazirlandi**. Herhangi bir Render kaynagi/sunucusu/veritabani olusturulmadi; APK uretilmedi; gercek telefon testi yapilmadi. Kodun kaynak surumu: `f8694ed`. Staging ile production verileri kesinlikle ayridir.

## 0. Mimari

- Render **paid always-on** Docker Web Service: tek calisan Dart/Shelf API + WebSocket + zamanlayici. Uygulama sunucusu islemi `ENVIRONMENT=production` ile baslar (test ortami olsa da sert guvenlik kontrolleri aktif).
- Render **paid managed PostgreSQL**, *ayni bolge*, *ayni workspace* ve ozel ic ag adresi. PostgreSQL 17 ile proje CI uyumlu. Restore/backup ve tutma politikasini panelde sec.
- Flutter Android APK: `--dart-define=API_BASE_URL=https://<staging-api-host>`. Varsayilan WebSocket otomatik `wss://<staging-api-host>/ws`.
- Staging sisteminde gecici/gercek production hesaplari/verisi KULLANMA.
- Baslangicta **1 instance**: sunucu her instance icin ayri zamanlayici kullaniyor. Yatay olcekleme ve leader election ayrica tasarlanmadan ikinci instance acma.

## 1. Deploy oncesi sorumluluklar ve guvenlik

1. Render hesabini sahibi olusturur/yonetir. Ucretli plan kaynaklari ancak acik onayla acilir.
2. Yalniz staging icin ayri PostgreSQL ve yalniz staging hesaplari kullan. Veritabani public access'i kapali/sinirli tut. DB 5432 portunu halka acma.
3. `JWT_SECRET` icin benzersiz, kriptografik olarak rastgele en az 32 baytlik secret olustur. Testte bile depodaki varsayilan JWT ve `futbol_dev_sifre_2026` sifresini kullanma.
4. Secrets'i **Render Environment** bolumune kaydet; source, GitHub, APK, dokumantasyon ve loglara koyma.
5. Backend `Env.productionProblems` kontrolu nedeniyle `ENVIRONMENT=production` iken zayif/missing JWT ya da default DB sifresi varsa BASLAMAZ.
6. Flutter uygulamasinda kayit/giris ayarlari, WebSocket reconnect ve uc nokta gizliligini kontrol et.

## 2. Render: kaynaklari olusturma (kullanici adimi)

1. Render Dashboard > PostgreSQL > New. Ornegin `futbol-card-staging-db`; **ucretli**, PostgreSQL 17 uyumlu bir plan, backup/PITR sec.
2. Backend icin New > Web Service; GitHub deposunu bagla; **Language/Runtime: Docker**, **Dockerfile path: `./Dockerfile.staging`**, **Root directory: repo root**. Staging icin **ucretli always-on** plan sec.
3. Health Check Path: `/api/health`. Bir adet instance. `autoDeploy` ilk kabul sirasinda tercihen kapali; main her commit'te otomatik yayina alinmasin.
4. Backend ile DB ayni region ve workspace icinde; DB'nin **internal** host/port/database/user/password degerlerini Dashboard'dan oku.
5. Web Service Environment bolumunde su degiskenleri gir:
   - `ENVIRONMENT=production` (staging'e ozel sert guvenlik kontrollerini acmak icin)
   - `HOST=0.0.0.0`
   - `PORT`: Render tarafindan saglanan portu koru; elle sabitlemen gerekirse 10000
   - `DB_HOST=<postgres-private-host>`
   - `DB_PORT=5432`
   - `DB_NAME=<staging-db-name>`
   - `DB_USER=<staging-db-user>`
   - `DB_PASSWORD=<staging-secret>`
   - `JWT_SECRET=<benzersiz-32+-byte-secret>`
   - `CORS_ORIGIN=<ileride-web-staging-kullanilirsa-o-adres>` (yalniz Android istemcisinde CORS zorunlu degil)
   - `TRUST_PROXY`: ters vekil IP basliklarinin guvenilirlik modeli incelenmeden otomatik `true` yapma.
6. Backend icindeki `Database._settings`, production'da `SslMode.require` kullanir. Render PostgreSQL internal baglantisi **opsiyonel TLS** destekler; bu ayar staging'de gercek baglantiyla dogrulanmali. Gerekirse uyum icin konfigurasyon ayri PR'da duzeltilmeli, genel SSL kontrolu gevsetilmemeli.
7. Render web servisi HTTPS verir, `/ws` ayni host uzerinde WSS olarak calisir. `/api/health` yanitinin DB bagli ve HTTP 200 oldugunu gor.

## 3. Veritabani migration'lari

**UYARI: migration ilk kez acilmis BOS staging DB uzerinde yapilmali.** Production DB'ye SQL calistirma, veri silme veya `docker compose down -v` yapma.

CI'daki staging temel sirasini koru: `database/migrations/*.sql` alfabetik sira, her dosya `psql -v ON_ERROR_STOP=1 -1`. Bu repo `docker-compose.yml` dosyasindaki sifreler YALNIZ YEREL GELISTIRME icindir; bu compose'u internete acma.

Staging DB migration icin: `psql` istemcisi kurulu guvenli yonetici ortamindan sadece **staging** veritabanina baglan. Dis baglanti gerekiyorsa TLS + gecici IP allowlist kullan; is bitince kapat. Secrets komut satirina/loglara basma.

Bash ve `psql` bulunan bir yonetici ortaminda, baglanti sadece ortam degiskeninden alinacak sekilde:

```bash
# STAGING_DATABASE_URL: yalniz staging DB'ye ait TLS-li, gizli baglanti bilgisi
test -n "${STAGING_DATABASE_URL:-}" || { echo "Staging DB URL eksik"; exit 1; }
for file in $(find database/migrations -maxdepth 1 -name '*.sql' | sort); do
  psql "$STAGING_DATABASE_URL" -X -v ON_ERROR_STOP=1 -q -1 -f "$file" || exit 1
done
```

Bundan sonra `/api/health` sorgusu, hesap olusturma ve ilk eslestirme ile schema uyumu dogrulanmali. Migration'lari **her web service restart'inda otomatik uygulama**; dagitim once onayli surumleme adimi olmali.

## 4. Iki telefona staging APK

Proje ana dizininde (Flutter SDK, Android SDK, JDK kuruluyken):

```bash
flutter pub get
cd packages/shared_models
dart pub get
dart run build_runner build --delete-conflicting-outputs
cd ../..
flutter build apk --release --dart-define=API_BASE_URL=https://<staging-api-host>
```

Uretilecek yol: `build/app/outputs/flutter-apk/app-release.apk`. Gercek staging host adini kullan: `ci.example.invalid` yalniz CI derleme testidir ve telefonda CALISMAZ.

Her iki telefona **ayni APK**, iki farkli test hesabi. Android paketinin imzasi degisirse mevcut uygulamayla cakisma olabilir. Release imzasinda debug fallback vardir; ilk test icin yeterli olabilir, Play Store imzasi degildir. APK herkese acik rastgele dosya paylasimlarinda dagitilmamali.

## 5. Iki telefon kabul testi

- API 200 ve DB bagli, giris/kayit ayri iki hesaptan.
- 11 kartlik kadrolar, iki oyuncu eslestirme, ayni mac id, gizli es zamanli kart secimi (flag acik ise).
- 5 saniye mevki, 15 saniye secim, gecikmede server-driven otomatik hamle.
- WebSocket ve REST'te rakibin kart secimi reveal oncesi gorunmez.
- Telefon 2'de mobil internet/Wi-Fi degisimi, uygulama kapat-ac, aktif mac resume, degerlerin veritabaninda tek kayit olmasi.
- Sonuc, MMR, sandik, XP, gunluk haklar tek sefer yazilir.
- Yalniz STAGING'de, birer birer `economy_v2_enabled`, `ranked_rewards_v2`, `duel_v4`, `card_level_power` ve bagimli ozellikleri acarak eski/yeni mac kural surumlerini kontrol et. Bot, tutorial ve gunluk dongu flaglerini ayri test et.
- Iki fiziksel cihazda test raporu ekran kaydi ve tarih/surum ile tutulur.

## 6. Isletim ve riskler

- Yedek/PITR aktivasyonu; test veritabaninda bos bir yedegi ayri bir DB'ye **gercekten geri yukleyerek** prova et.
- API durumu, p95 gecikme, veritabani havuzu, WebSocket baglantilari, match timeout/sweeper, economy_errors, iki kez verilen odul; izleme ve uyarilar kur.
- Tek instance yeniden baslayinca WebSocket dusmesi normal; istemci yeniden baglanip REST state ceker. Yedekli/zero-downtime olarak ilan etme.
- Dis baglantilar ve test kullanicilari icin erisim kisitlari gerekir; staging'i production trafik olarak kullanma.
- Bu hazirlik **bulut kaynagi olusturmaz**, staging alan adi vermez, APK olusturmaz ve fiziksel telefon testi gecti iddiasinda bulunmaz.
