# Ekonomi V2 — Kalite kontrolü ve öneriler (10 Kasım 2026)

FAZ 0, 1, 2, 3, 4 ve 6 korunarak yapıldı. Maç motoruna dokunulmadı. **Bu belgedeki
kurallar ONAY BEKLİYOR**: oyuncu ekonomisini değiştiren hiçbir kural henüz uygulanmadı.

## 1. CI hatası (GitHub Actions 42822383188) — düzeltildi

- **Gerçek log:** `KALDI: 031_chests_test.sql` /
  `031_chests_test.sql:308: TEST BASARISIZ: rakibe (enerjili) sandik var -> beklenen 1, gelen 0`
- **Kök neden:** test, rastgele dağıtılan ellerle oynanan maçın her zaman en az 4 tur
  süreceğini varsayıyordu. Aynı başlangıçla 60 koşuda maç 5–9 tur sürdü; CI'da 4. turdan
  önce bitti ve **K6** gereği iki oyuncuya da sandık verilmedi (A'nın "sandık yok"
  kontrolü tesadüfen geçti). **Oyun kodunda hata yok.**
- **Düzeltme (`381e933`):** `pg_temp.tam_mac` — 4+ turlu maç çıkana kadar yeniden dener.
  K6 gereği kısa maçta sandık, XP, görev ve enerji harcaması olmadığı için ölçülen değerler
  bozulmaz. Aynı varsayım 031 (bölüm 2 ve 8) ve 035'te (enerjili / enerjisiz XP) giderildi.
  CI durumu zorla üretilerek doğrulandı (ilk maç 2. turda biter → yardımcı tam maçı döndürür,
  B'ye 1 sandık, enerji yalnız 1 azalır).

| Kontrol | Sonuç |
|---|---|
| Veritabanı (35 migration, 11 test dosyası, tekrar, maç sürerken yükseltme; UTC) | ✅ |
| Dart: ortak modeller 63, taktik prototipi 37, içerik hattı 30, sunucu 29 | ✅ analiz temiz, hepsi geçti |
| Flutter analyze + 700 test | ✅ |
| Android release APK | ⚠️ yerelde derlenemedi: OneDrive, derleme ara klasörlerini kilitliyor (`AccessDeniedException`). Aynı commit'te CI'daki Android işi **başarılı**; sonraki değişiklik yalnız DB test dosyaları |

## 2. Simülasyon

`tool/ekonomi/karsilastirma.py` (10 tekrar / hücre), `simulasyon.py` modelini aynen
kullanır: saat saat 4 yuva + tek kilit + posta kutusu (8 / 7 gün) + telafi, ödül enerjisi
(10, 96 dk), kart kaybı + koruma, Acil Kadro, seviye, Battle Pass + görevler. Gerçekçi
oyuncu: günlük maç ~N(ortalama, %35), günlerin %15'i boş, maçların %3'ü 4. turdan önce
biter (K6). Ham sonuç: `tool/ekonomi/karsilastirma.md` / `.json`.

| Senaryo | Kural |
|---|---|
| S0 Mevcut | Sandık yalnız enerjili maçta; yenilgide korumasız 3 kart kalıcı kaybı |
| S1 Kayıpsız | S0 + dereceli maçta kalıcı kart kaybı yok |
| S2 Her maça tam sandık | S1 + her meşru maça sonuç tablosundan sandık (enerji yalnız XP) |
| S3 Öneri | S1 + her meşru maça sandık; enerjiliyse sonuç tablosu, enerjisizse **Bronz** (anında, kuyruğa girmez) |
| S4 Öneri + gelişim | S3 + galibiyette kadrodaki rastgele futbolcuya **+1 gelişim kopyası** |

**180 gün** (sandık / telafi adedi / altın geliri günde / kalıcı kart kaybı / kadro ort. seviye):

| Senaryo | Günde 2 maç | Günde 5 | Günde 10 | Günde 20 |
|---|---|---|---|---|
| S0 Mevcut | 321 / 0 / 197 / 164 / 4,59 | 804 / 1 / 470 / 384 / 5,64 | 1529 / 10 / 823 / 741 / 6,48 | 2218 / 59 / 1373 / 1466 / 6,98 |
| S2 Her maça tam | 328 / 0 / 205 / 0 / 3,00 | 785 / 1 / 461 / 0 / 3,68 | 1516 / 11 / 810 / 0 / 4,74 | 2742 / **275** / 1588 / 0 / 5,55 |
| S3 Öneri | 328 / 0 / 205 / 0 / 3,00 | 785 / 1 / 461 / 0 / 3,68 | 1498 / 11 / 801 / 0 / 4,67 | 3010 / 63 / 1476 / 0 / 5,15 |
| **S4 Öneri + gelişim** | 329 / 0 / 202 / 0 / **4,96** | 795 / 2 / 466 / 0 / **5,85** | 1532 / 9 / 812 / 0 / **6,57** | 2925 / 59 / 1433 / 0 / **7,25** |

**Kadro ortalama seviyesi 30 / 90 / 180 gün:**

| Senaryo | Günde 2 | Günde 5 | Günde 10 | Günde 20 |
|---|---|---|---|---|
| S0 | 2,14 / 3,65 / 4,59 | 3,14 / 4,91 / 5,64 | 4,31 / 5,82 / 6,48 | 5,14 / 6,73 / 6,98 |
| S3 | 2,30 / 2,65 / 3,00 | 2,45 / 2,95 / 3,68 | 2,65 / 3,39 / 4,67 | 2,71 / 3,93 / 5,15 |
| S4 | 2,94 / 4,42 / 4,96 | 3,65 / 5,34 / 5,85 | 4,36 / 6,18 / 6,57 | 5,25 / 6,86 / 7,25 |

## 3. Sekiz konunun değerlendirmesi

**1. Her meşru maça sandık, enerji yalnız bonus.** Enerji (günde 15 dolum) günde 15 maçın
altında hiç bitmiyor: 2–10 maç profillerinde S0 = S2 = S3. Fark yalnız ağır oyuncuda: günde
20 maçta S0 maçların ~%23'ünde sandık vermiyor (180 günde 709). Enerjisiz maça **tam**
sandık (S2) yuva kuyruğunu taşırıyor: **275 telafi ≈ 34.600 altın** (S0'ın 4,6 katı;
enflasyon + "sandık kaybettim" hissi). **S3** her maça sandık verir ama enerjisiz sandık
Bronz olduğu için kuyruğa girmez: telafi S0 ile aynı (63 / 59), altın geliri +%7.

**2. Dereceli maçta kalıcı kart kaybının kaldırılması.** S0'da 180 günde 164–1466 kart el
değiştiriyor. Kaldırılınca kilitli gün ve Acil Kadro ihtiyacı sıfıra iniyor; koleksiyon
çeşitliliği hafif artıyor (90 → 94–100). **Yan etki:** kazanılan kartlar fazla kopya →
gelişim kopyası olarak seviyeyi besliyordu; kayıp kalkınca kadro seviyesi %25–35 düşüyor
(S3). S4'teki galibiyet kopyası bunu telafi ediyor (S0'ın biraz üstü). Koruma hakkı
(+1 / galibiyet, en fazla 10) dereceli maçta anlamını yitirir.

**3. Acil Kadro.** S0'da 180 günde 0,1–0,6 kez devreye giriyor; kayıp kalkınca 0. Yeni
hesap ve kopya dönüşümü gibi uç durumlar için güvenlik ağı olarak **kalmalı**; kurallarında
değişiklik gerekmiyor (eksik mevki önceliği ve 24 saat sınırı uyumlu).

**4. Seviye ilerlemesi ve Ranked dengesi.** K1 korunuyor: hiçbir senaryoda seviye maç
gücüne girmiyor. S4'te ilk 5. seviye: günde 2 maçta medyan 24. gün (30 günde oyuncuların
%60'ı; S0 %40), günde 5 maçta 10,5. gün (S0 18). Haftalık seviye atlama günde 2 maçta ~9,9,
günde 20'de ~22.

**5. Battle Pass (50 kademe, 30 gün).** Değer dağılımı dengeli: ücretsiz yolda her 10 kademe
toplamın %17–27'si. Gerçekçi değişkenlikle tamamlama: günde 2 maç **%0** (ort. 26 kademe,
ücretsiz değerin %49'u), 3 maç %2 (39), 5 maç **%95** (medyan son gün), 10 maç %100 (26. gün).
Kademe 900 XP'ye inse günde 3 maçta %8 / 45, günde 5'te 28. gün — sınırlı fark.
**Öneri: değiştirmeyin** (tasarım hedefi "günde 2 maç bitiremez, 5 maç bitirir" tutuyor;
belgedeki 32 kademe değişkenliksiz hesaptı, gerçekçisi ~26).

**6. 23 item** (`database/audits/ekonomi_v2_denetim.sql`): verme tek sefer, kullanım tek
sefer, süre dolumu (görünmez, kullanılamaz, denetim için saklanır), yeniden verme ve tekrar
kozmetiğin altına dönmesi ✅. **Bulgu:** 7 itemin oyunda kaynağı yok — sandık anahtarı,
ustalık kitabı (Bronz / Gümüş / Elmas / Efsane), gelişim indirimi, etkinlik bileti (yalnız
geliştirme ucu). Etkinlik biletini kullanan bir mod da yok.

**7. Sezon kapanışı.** ✅ **036 ile düzeltildi:** `repair_season_rewards()` saatlik işte
kapanıştan hemen sonra çalışır; hata alan ödülü sorun giderilince tek sefer verir
(`036_season_repair_test.sql`). Önceki bulgu: alınmamış ücretsiz/premium ödüller otomatik veriliyor, tekrar
çalıştırma çift vermiyor ✅. **Bulgu (gerçek açık):** kapanışta bir ödül hata verirse
`economy_errors`'a yazılıyor ama sezon "kapandı" işaretleniyor ve **yeniden deneme yok** —
denetimde premium 1. kademe forması kalıcı kayboldu.

**8. Sandık kuyruğu / posta / telafi.** 4 yuva + 8 posta dolu → telafi (kaynak başına tek,
defter anahtarı tek), posta ömrü dolunca telafi (tekrar 0), aynı sandığı ikinci açış ödül
vermez, dolu yuvaya postadan alma reddedilir ve sandık postada kalır, dolu kutuda sezon
sandığı telafiye döner ve tekrar alma çift telafi vermez ✅. Kaynak kaybı ya da çift ödül yok.

## 4. Önerilen kesin kurallar (ONAY BEKLİYOR)

| # | Kural | Gerekçe |
|---|---|---|
| R1 | **Her meşru dereceli maç (≥ 4 tur, K6) iki oyuncuya da 1 sandık verir.** Ödül enerjisi varsa (1 harcanır) sandık türü sonuç tablosundan (§1.2) çekilir ve sezon XP'si tam; yoksa sandık **Bronz** (anında açılır, yuvaya girmez) ve XP %25. | S3: her maç ödüllü, kuyruk taşması S0 kadar; S2'nin 34.600 altınlık telafi enflasyonu yok |
| R2 | **Dereceli maçta kalıcı kart transferi kaldırılır.** MMR, galibiyet +100 altın aynen. Koruma hakkı dereceli maçta kullanılmaz (veri silinmez; ileride ayrı bir "riskli mod" için saklanır). | Kayıp 180 günde 164–1466 kart; kilit ve Acil Kadro ihtiyacı 0 |
| R3 | **Galibiyette kadrodaki rastgele bir futbolcuya +1 gelişim kopyası** (fiziksel kart değil; seviye 10'daki karta düşmez). +1 koruma hakkının yerine geçer. | S4: R2'nin kestiği seviye ilerlemesi geri gelir (S0'ın biraz üstü); K1 korunur |
| R4 | **Acil Kadro aynen kalır** (güvenlik ağı). | Uç durumlar |
| R5 | **Battle Pass değişmez** (50 × 1000 XP). | Hedefler tutuyor |
| R6 | **Kaynaksız itemler:** sandık anahtarı ve 4 ustalık kitabı Efsane / Altın sandığa düşük olasılıklı ek ödül olarak, gelişim indirimi haftalık görev ödülü olarak eklenir; etkinlik bileti, etkinlik modu gelene kadar katalogda **pasif** yapılır. Kesin oranlar onaydan sonra simülasyonla belirlenir. | 7 itemin kaynağı yok |
| R7 ✅ | **(036 ile uygulandı)** **Sezon kapanışı onarımı (hata düzeltmesi, ekonomi değişikliği değil):** `repair_season_rewards()` — `season_close` hatalarını sezon kapandıktan sonra da yeniden dener (sandıklardaki `repair_match_chests` gibi); saatlik işe eklenir. | §3 kuralı "ödül kaybolmaz" — denetimde kayıp bulundu |

**Dokunulan kod:** R1–R3 maç sonu ödül katmanı (031 tetikleyicisi ve maç bitiş kart
transferi). **Düello motoru, tur çözümü, MMR ve eşleştirme değişmez.** R2 kart transferini
kaldırdığı için "temel kart düellosu" kapsamında ayrıca açık onayınızı istiyorum.

## 5. Sonraki adım

- R6 (item kaynakları) ve R1–R3 için migration planı: `docs/EKONOMI_V2_UYGULAMA_PLANI.md`.
- CI 42832383837: Android işi NDK indirmesindeki bozuk arşiv yüzünden kaldı (kod hatası değil);
  CI'a yeniden denemeli NDK kurulum adımı eklendi.
