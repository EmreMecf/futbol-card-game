# Test Raporu — Faz 1–2

Tarih: 27 Kasım 2026 · Yerel: Flutter 3.50.1 / Dart 3.14, PostgreSQL 17

| Paket | Sonuç | Not |
|---|---|---|
| `flutter analyze` | Temiz | |
| `flutter test` | **1201 geçti** (45 atlanan golden-dışı) | Bayraklar kapalı: hiçbir golden değişmedi |
| `test/monetization_test.dart` (yeni) | 12 geçti | durum makinesi, gecikmiş doğrulama, ret, yüklenmeme, yarıda kapatma, rıza yok, aktif maç, eşzamanlı ikinci istek, hap görünürlüğü ve açık onay |
| `test/l10n_test.dart` | Geçti | yeni metinlerin İngilizcesi eklendi |
| `server: dart analyze` | Temiz | |
| `server: dart test` | **51 geçti** | yeni `ad_ssv_verifier_test.dart` (6): gerçek ECDSA imzası, kurcalanmış ödül/kullanıcı, yanlış anahtar, imzasız, önbellek, PEM biçimi |
| `scripts/db-testleri.sh` | Geçti | sıfırdan kurulum (58 migration), kural testleri, tekrar çalıştırma, maç sürerken yükseltme |
| `database/tests/060_monetization_core_test.sql` (yeni) | Geçti | varsayılan kapalı, ayar doğrulama, denetim kaydı, ilk gün/platform/sürüm/yüzde kapıları, rezervasyon, SSV tekilliği, başka kullanıcı, kredi ve tek kullanım, sürenin negatife düşmemesi, günlük tavan (geç gelen geri çağrı dahil), aktif maçta engel, maç sonu tek teklif, acil kapatma, ücretli elmas 0 |
| `scripts/gecmis-veri-kontrolu.sh` | Geçti | 060 mevcut kullanıcı verisini değiştirmiyor |
| Web derlemesi (release) | Geçti | `google_mobile_ads` web'de koşullu içe aktarma ile dışarıda (reklam yok) |
| Android derlemesi | **Yerelde yapılamadı** | Bu bilgisayarda Java 8 var, Gradle 9.5 Java 17+ istiyor; Android derlemesini GitHub CI doğrular. AdMob test uygulama kimliği bildirimde |

## Brif uçtan uca senaryoları

| Senaryo | Durum |
|---|---|
| Reklam tamamlanır, tek ödül | SQL + istemci testi ✔ |
| Yarıda kapatılır, ödül yok | istemci testi ✔ (rezervasyon bırakılır) |
| SSV iki kez gelir, tek ödül | SQL ✔ |
| Günlük 3 tavan aşılamaz | SQL ✔ |
| Aktif PvP'de reklam yok | SQL ✔ |
| Reklam yüklenmezse oyun devam | istemci ✔ |
| Bayrak kapalıyken eski davranış | 1201 test, golden aynı ✔ |
| Satın alma senaryoları | Faz 3 — **BLOCKED** (mağaza hesapları) |
| Gerçek cihazda gerçek AdMob test reklamı | Yapılmadı: AdMob hesabı ve cihaz gerekiyor |

## Ekonomi simülasyonu (`dart run tool/ekonomi/monetizasyon_simulasyonu.dart`)

Varsayım: günde 8 maç, %47 galibiyet, günde 16 saat sayaç.

| Profil (30 gün) | Altın | Sandık | Kart | Güç farkı |
|---|---:|---:|---:|---:|
| Reklamsız ücretsiz | 7.014 | 240 | 790 | 0 |
| Günde 1 reklam | 8.214 | 240 | 802 | +1,5% |
| Günde 3 reklam | 9.414 | 240 | 814 | +3,0% |
| Düşük / orta / yüksek harcama | 7.014 | 240 | 790 | **0** |
| Yalnız kozmetik | 7.014 | 240 | 790 | 0 |
| KARŞI-OLGU: ayrım olmasa, yüksek harcama | 49.014 | 240 | 1.210 | **+53,2%** |

Sonuç: ücretli/ücretsiz elmas ayrımı olmadan gerçek para satışı açılamaz
(R1). Reklam ödülü küçük (≈%3) ve enflasyon yaratmıyor.
