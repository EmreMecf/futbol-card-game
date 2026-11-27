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

## Faz 3 — Satın alma

| Paket | Sonuç | Not |
|---|---|---|
| `flutter analyze` / `dart analyze` (sunucu) | Temiz | simülatör uyarıları da giderildi |
| `flutter test` | **1209 geçti** (45 atlanan) | bayraklar kapalı, goldenlar aynı |
| `test/purchase_test.dart` (yeni) | 8 geçti | yalnız mağaza fiyatlı ürün, bayrak/mağaza kapalı, doğrula→tamamla, geçici hatada işlem açık kalır, kalıcı hata, sunucu pending, bekleyen/iptal, oturumsuz satın alma yok. Başarı mesajının hemen silinmesi hatası bu testle bulundu ve düzeltildi |
| `server: dart test` | **64 geçti** | yeni `purchase_verifier_test.dart`: Google/Apple yanıt denetimleri, hesap eşleşmesi, bekleyen, iade, test sağlayıcı |
| `database/tests/061_purchases_test.sql` (yeni) | Geçti | tekil ödül, tekrar, hesaplar arası engel, bekleyen→gerçek kimlik, iade + borç, katalog güç yasağı, sınır |
| Yerel uçtan uca (sunucu + PostgreSQL, test sağlayıcı) | 16/16 | katalog, doğrulama, tekrar, geçmiş, geri yükleme, reklam akışı |
| Üretim kapısı (`DEPLOY_STAGE=production`) | 4/4 | test sağlayıcı yok, anahtarsız 503, simülasyon ucu yok |
| Android release (CI) | Bekliyor | eklenti lint çökmesi için `checkReleaseBuilds = false`; CI'da doğrulanacak |

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
| Satın alma senaryoları | Faz 3 ✔ test sağlayıcıyla; gerçek mağaza sandbox testi **BLOCKED** (hesaplar) |
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
