# Uçtan Uca Test (Gerçek Tarayıcı)

Uygulama **gerçek Chrome'da** açılır, **gerçek API sunucusuna** bağlanır ve
sunucu **gerçek bir PostgreSQL veritabanına** yazar. Hiçbir şey taklit
edilmez.

## Senaryo

`integration_test/uctan_uca_test.dart` tek akışta şunları yapar:

1. Giriş ekranı açılır → **KAYDOL** → yeni hesap oluşturulur
2. Ana sayfa gelir (başlangıç kadrosu sunucudan verilmiştir)
3. Menüden **KARTLAR** → koleksiyonda kartlar görünür
4. **Ayarlar** → dil İngilizce yapılır, sonra Türkçeye döndürülür
5. **ÇIKIŞ YAP** → onay penceresi → giriş ekranı
6. Aynı e-posta ve şifreyle tekrar giriş
7. **MAÇA BAŞLA** → **BOTLA ANTRENMAN** → maç sonuna kadar oynanır
   (test her turda elden bir kart seçip **OYNA!** der, bot hamlelerini
   sunucu yapar) → sonuç ekranı → **ANA MENÜ**

Test iki pencere boyutunda çalışır: telefon düzeni (430×900) ve geniş
web düzeni (1366×860).

## Bilgisayarda çalıştırma

Gerekenler: PostgreSQL çalışıyor olmalı (`scripts/veritabani-baslat.ps1`),
Chrome kurulu olmalı ve Chrome sürümüyle **aynı sürüm** chromedriver
olmalı (Chrome for Testing sayfasından: googlechromelabs.github.io/chrome-for-testing).

```bash
PGPASSWORD=futbol_dev_sifre_2026 \
PSQL=/c/Users/muhas/futbol-card-db/pgsql/bin/psql.exe \
CHROMEDRIVER=/yol/chromedriver.exe \
bash scripts/uctan-uca-test.sh
```

Seçenekler:

| Değişken | Anlamı | Varsayılan |
|---|---|---|
| `E2E_BOYUT` | Pencere boyutu | `430,900` |
| `E2E_HEADLESS` | `1` ise Chrome görünmez çalışır | `0` |
| `E2E_PORT` | Test sunucusunun portu | `8099` |
| `FLUTTER` | flutter komutu | `flutter` |

## Betik ne yapar?

1. **Geçici** bir veritabanı kurar (`futbol_e2e_<sayı>`), git'e kayıtlı
   bütün migration'ları uygular. Senin `futbol_card` veritabanına
   **dokunmaz**.
2. Antrenman modunu **yalnız bu geçici veritabanında** açar.
3. API sunucusunu bu veritabanıyla 8099 portunda başlatır.
4. chromedriver'ı başlatır ve testi Chrome'da çalıştırır.
5. Bitince sunucuyu ve chromedriver'ı kapatır, geçici veritabanını siler.

Test başarısız olursa hangi adımda takıldığı, o anki sayfa ve ekrandaki
yazılar raporlanır; ardından sunucu günlüğünün sonu yazdırılır.

## GitHub CI

`ci.yml` içindeki **tarayici** işi aynı betiği iki pencere boyutunda,
görünmez Chrome ile çalıştırır. GitHub'ın Ubuntu makinesinde Chrome ve ona
uygun chromedriver hazır gelir.
