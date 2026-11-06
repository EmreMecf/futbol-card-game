# Rekabet Analizi Raporu

**Tarih:** 6 Kasım 2026 · **Önceki rapor:** [BAGIMSIZ_INCELEME_RAPORU.md](BAGIMSIZ_INCELEME_RAPORU.md)

**Hedef:** Yeni oyuncuların da şansı olan, ustaların doğru stratejiyle
avantaj kazandığı, uzun vadeli rekabet sunan bir oyun.

**Kurallar:**
- Canlı kurallar **değiştirilmedi**.
- Her alternatif önce bugünkü motorla **aynı tohum ve aynı kadrolarla**
  karşılaştırıldı.
- Veritabanına eklenen tek alternatif (eşleştirme) **varsayılanı kapalı**
  bir ayarın arkasında duruyor.

**Bütün sayıları yeniden üretmek için:**

```bash
cd packages/tactics_prototype
dart run bin/karsilastir.dart   # -> KARSILASTIRMA.md (A–D bölümleri, ~35 sn)
dart test                       # 37 test (12'si yeni)
```

> **Simülasyonun sınırları:** Yapay oyuncular gerçek oyuncu değil;
> ekonomi modeli basitleştirilmiş (aşağıda). Sayılar **yön** gösterir.
> Canlıya alınan her değişiklik gerçek maç verisiyle izlenmeli.

---

## Özet

| # | Konu | Bulgu | Durum |
|---|---|---|---|
| 1 | Eşleştirme | Yeni gelenin ilk maçlarının **%49'u umutsuz**; sıralama beceriyi değil kadroyu ölçüyor | Alternatif hazır (024, **kapalı**), **onay bekliyor** |
| 2 | İlk açan | %44,4; en iyi aday **"sadece ilk tur kör cevap"** (%48,7) | Simüle edildi, **onay bekliyor** |
| 3 | Özellik → taktik (sürüm 3) | Güvenli ama **stratejik etkisi gürültü düzeyinde** | Prototipte; canlıya **önerilmiyor** |
| 4 | Kalıcı kart kaybı | 🔴 **Ekonomide kilitlenme hatası:** oyuncuların ~%55–59'u kalıcı olarak oynayamaz hale geliyor | **Onay bekliyor** |
| 5 | GitHub Actions | 4/5 iş geçti; `Flutter analyze` yapılandırma hatası | ✅ Düzeltildi (**push bekliyor**) |

---

## 1. Eşleştirme: başlangıç kadrosu %0 problemi

**Mevcut davranış:** `find_match` sadece MMR'a bakıyor
(`|ΔMMR| ≤ 200 + 50 × bekleme/10 sn`). Nüfus simülasyonunda:
- Sistem oturduktan sonra 1000 MMR ve başlangıç kadrosuyla gelen yeni
  oyuncunun **ilk 20 maçının %49'u umutsuz**; puanı **%28**.
- Zamanla sıralama kadroyu ölçmeye başlıyor: kıdemli kadrolar 1711
  MMR'a çıkıyor, başlangıç kadroları becerilerinden bağımsız 561'e
  iniyor. Becerinin sıralamaya etkisi kadronunkinin **dörtte biri**
  (0,25).

**Kod konumu:** `database/migrations/006_rpc_matchmaking.sql` (`find_match`)

**Risk:** **Yüksek.** Yeni oyuncu kaçıran bir deneyim; kart kaybıyla
birleşince (madde 4) daha da ağırlaşıyor.

**Karşılaştırma** (`KARSILASTIRMA.md` bölüm C):

| Nüfus 240 | Bugün | MMR + kadro bandı | **Birleşik puan** |
|---|---|---|---|
| Yeni gelen: umutsuz maç | %48,8 | %0 | **%0** |
| Yeni gelen: puan (ilk 20) | %28,1 | %50,7 | **%51,9** |
| Sıralamada beceri ÷ kadro | 0,25 | 3,59 | **4,64** |
| Bekleme ort / p90 | 1 / 0 sn | 4 / 10 sn | 6 / 20 sn |

| Nüfus 40 (ilk aylar) | Bugün | MMR + kadro bandı | **Birleşik puan** |
|---|---|---|---|
| Yeni gelen: umutsuz maç | %46,7 | %9,2 | **%0,8** |
| Yeni gelen: puan | %27,1 | %41,3 | **%44,2** |
| Bekleme ort / p90 | 5 / 10 sn | 15 / 40 sn | 18 / 50 sn |

**Önerilen çözüm: Birleşik puan.** Uzaklık = |ΔMMR|/100 + |Δkadro gücü|/1,5.
Sınır 2 + 0,5 × bekleme adımı (iki tarafın uzun bekleyeni esas alınır).
Kadro gücü = kadronun ortalama güç + kimyası.

**Uygulandı, ama kapalı:** `024_matchmaking_deck_power.sql`. Varsayılan
mod `'mmr'`, yani bugünkü kural. Onay verirsen tek satırla açılır, geri
almak da tek satır:

```sql
update matchmaking_settings set mode = 'combined';  -- aç
update matchmaking_settings set mode = 'mmr';       -- geri al
```

**Test yöntemi:**
- `database/tests/024_matchmaking_test.sql`: `mmr` modu kadroya
  bakmadan eşleştirir (eski davranış); `combined` büyük farkta hemen
  eşleştirmez, bekleme uzayınca eşleştirir.
- `scripts/db-testleri.sh`: 4/4 geçti.
- Canlı sunucuda tam maç ve gerçek zamanlı zincir: geçti (mod `mmr`).
- Prototip testi: birleşik puanda yeni gelenin umutsuz maçı ve puanı
  iyileşiyor, sıralama beceriyi daha çok yansıtıyor.

**Beklenen sonuç:** Yeni gelen ilk maçlarında ~%50 şans bulur; sıralama
ustalığı ölçer. Bedeli birkaç saniye, az oyuncuda ~50 saniyeye kadar
ek bekleme.

---

## 2. İlk turu açan dezavantajı (%44,4)

**Mevcut davranış:** Cevap veren, rakibin kartını görüp seçiyor. Turu
kazanan bir sonrakini açtığı için bu bilgi avantajı sürekli el
değiştiriyor ve ilk açan %44,4'te kalıyor.

**Kod konumu:** `play_card` / `get_match_state` (açanın kartı rakibe
görünür)

**Risk:** Orta. Maçlar arası adil (ilk açan rastgele seçiliyor), ama tek
maç içinde yazı-tura etkisi var.

**Karşılaştırma** (`KARSILASTIRMA.md` bölüm A):

| Varyant | İlk açan (Akıllı) | İlk açan (Taktiksiz) | Beceri ödülü | Not |
|---|---|---|---|---|
| Bugün | %44,4 | %44,5 | %66,5 | — |
| S1: ilk açana +1 enerji | %44,6 | %44,3 | %66,8 | **etkisiz** |
| S1b: +2 enerji | %45,7 | %44,3 | %66,4 | sadece taktik kullananlara |
| S2: her turda kör cevap | **%50,0** | **%50,0** | **%59,6** ↓ | beceri ödülünü düşürüyor |
| **S2b: sadece ilk tur kör** | **%48,7** | **%51,6** | **%66,2** | **en iyi denge** |
| S3: açma sırası dönüşümlü | %44,0 | %47,5 | %66,9 | yetersiz |
| S4: turu kaybeden açar | %43,1 | %41,3 | %65,4 | kötüleştiriyor |

**Önerilen çözüm: S2b.** İlk turda cevap veren, açanın kartının **mevkisini**
görür ama **gücünü** görmez (kart kapalı oynanır, birlikte açılır).
Sonraki turlar bugünkü gibi.
- Neden S2 değil? Rakibin kartını okuyup ona göre cevap vermek ustalığın
  bir parçası; S2 bunu tamamen kaldırıp beceri ödülünü %66,5'ten
  %59,6'ya düşürüyor.
- S2b sadece ilk turdaki bilgi asimetrisini kaldırıyor; beceri ve güç
  ödülleri korunuyor.

**Uygulanırsa:** Bu bir **temel kural değişikliği**. Kural sürümü 3
olarak (`game_rule_versions`) eklenir; süren maçlar etkilenmez.
Arayüzde ilk turda rakip kartı ters görünür.

**Test yöntemi:** `compareFirstLeader` (prototip testi: S2b ilk açanı
%50'ye yaklaştırır, beceri ödülü en fazla 4 puan düşer). Uygulanırsa:
SQL testi (ilk turda rakibin gücü durum ucunda gizli) ve denge
raporundaki "İlk açan" izlenen hedefi.

**Beklenen sonuç:** İlk açan %45–55 hedefinin içine girer (%48,7–51,6).

---

## 3. Kural sürümü 3: futbolcu özellikleri → taktik bonusu

**Tasarım (prototipte uygulandı):**
- Özellik **gücü artırmaz**; sadece taktik bonusunu ±%20 ölçekler.
- Ölçek, özelliğin **kendisine** değil, kartın kendi gücünden
  **sapmasına** bağlı. Sebep: oyunda özellik = güç + mevki sapması ± 4
  (`016_card_attributes.sql`). Özelliğin kendisine bağlansaydı güçlü
  kart her zaman büyük bonus alır ve güç farkı büyürdü.

| Taktik | Oyuncu tipi (sapma) | En uygun |
|---|---|---|
| Yüksek Pres | (fizik + hızlanma)/2 − güç | — (mevkiler dengeli) |
| Kontra Atak | (hız + dribling)/2 − güç | Forvet |
| Savunma Duvarı | (defans + fizik)/2 − güç | Defans |

Çarpan = 1 + sapma × 0,025, ±0,20'ye kırpılır. Kırılan taktik yine 0;
taktik yoksa özellik hiçbir şey yapmaz; Legend kuralı korunur.

**Kod konumu:** `packages/tactics_prototype/lib/src/tactics.dart`
(`TacticAffinity`, `AttributeScaling`, `TacticRules.v3Attributes`)

**Karşılaştırma** (`KARSILASTIRMA.md` bölüm B):

| | Sürüm 2 | Sürüm 3 |
|---|---|---|
| Zorunlu denge hedefleri (4 tohum) | ✅ | ✅ |
| Güç farkı kayması (4 tohum) | %1,1–2,5 | %2,0–3,0 |
| Mevkiler arası fark (pres / kontra / duvar) | %1,0 / %4,6 / %1,8 | %3,5 / %4,2 / %2,7 |
| Oyuncu tipini kullanan vs kullanmayan | %54,6 | %55,9 |

**Dürüst sonuç:** Sürüm 3 **güvenli** (hiçbir hedefi bozmuyor) ama
**stratejik etkisi gürültü düzeyinde**. Oyuncu tipini bilmenin katkısı
+1,3 puan. ±%35 ve ±%50 ölçekler de denendi; anlamlı fark yaratmadı.
Sebep: ±%20, +9'luk bir bonusta en fazla ±2 güç ediyor.

**Öneri:** Bu haliyle **canlıya alınmasın**. Oyuncu tipinin gerçek bir
seçim yaratması için etkinin güce değil başka bir kaynağa bağlanması
gerekiyor. Denenecek adaylar (henüz simüle edilmedi):
- **Tipe uygun oyuncuyla taktik 1 enerji ucuz.** Enerji ekonomisi, ±2
  güçten daha belirleyici olabilir.
- **İmza taktiği:** belirgin tipteki oyuncu, kendi taktiğinde karşı
  taktiğe yakalanınca bonusunun yarısını korur.

Hangisinin deneneceğine sen karar ver; önce simülasyon, sonra sürüm 3.

---

## 4. Kalıcı kart kaybı ve ekonomi

**Mevcut davranış:** Kaybeden, korumadığı kadro kartlarından 3'ünü
kalıcı olarak kazanana kaptırır. Kaybeden coin kazanmaz. Commitli
oyunda coin kaynakları **sadece galibiyet ve SBC** (SBC de kart
harcatıyor).

**Kod konumu:** `007_rpc_gameplay.sql` (`_finish_match`)

### 🔴 Bulgu: kilitlenme (soft-lock)

Kaybedilen kartlar bir mevkinin son kartını götürürse kadro geçersiz
kalıyor. Geçersiz kadroyla maç aranamıyor (`validate_deck`), maç
oynayamayan coin kazanamıyor, coin kazanamayan paket alamıyor. **Oyuncu
kalıcı olarak oynayamaz hale geliyor.**

Simülasyonda, canlı kural için **en iyimser** oyuncu davranışıyla bile
(önce yedeği olmayan mevkileri, sonra en güçlüleri korur):

| Kural | Kilitlenen (120 maç) | Yeni gelen puanı* | Oyuncu başına kart | Kadro gücü ort |
|---|---|---|---|---|
| **Bugün: 3 kart** | **%59 / %55** | %26 / %39 | 50 | 82,4 |
| 1 kart | %10 / %4,5 | %23 / %39 | 76 | 81,5 |
| **Kayıp yok** | **%0 / %0** | %28 / **%45** | 79 | 82,8 |
| Kayıp yok + kazanana 1 kart | %0 / %0 | %23 / %42 | **135** | 86,3 |

\*Önce bugünkü eşleştirmeyle, sonra kadro gücü eşleştirmesiyle.

**Ekonomi etkisi (kayıp kaldırılırsa):**
- **Kilitlenme tamamen ortadan kalkıyor.**
- Ortalama kadro gücü **değişmiyor** (82,4 → 82,8). Güç artışını
  kayıp değil paket alımı belirliyor.
- Kartlar kazananlarda toplanmıyor; oyuncu başına kart sayısı artıyor
  (50 → 79). Ama bu yeni kart **basılması** değil, kartlar el
  değiştirmiyor.
- **"Kazanana ödül kartı" telafisi önerilmez:** kart enflasyonu (135
  kart/oyuncu) ve güç tırmanması (+3,5).
- **Kaybedilen ne olur?** Maçın riski ve "Yüksek Risk Modu" kimliği.
  Kod yorumları kart kaybını "oyunun kalbi" olarak tanımlıyor; bu bir
  ürün kararı.

**Risk:** **Yüksek.** Kilitlenme, oyuncunun oyunu tamamen bırakmasına
yol açar.

**Önerilen çözüm (onay bekliyor):**
1. **Normal dereceli maçta kalıcı kayıp yok.**
2. **Yüksek Risk** ayrı ve **isteğe bağlı** bir mod olarak kalsın:
   kart kaybı devam etsin, karşılığında daha yüksek coin/MMR ödülü.
   Ayrıca o modda bile kadroyu kurulamaz hale getirecek kart **alınmasın**.
3. Hangi seçenek olursa olsun **kilitlenme güvencesi**: kadrosu geçersiz
   ve coin'i 500'ün altındaysa, eksik mevki için ücretsiz bir Bronz kart
   verilsin. Bu bir hata düzeltmesi, ama ekonomiye kart eklediği için
   onayını istiyorum.

**Test yöntemi:**
- `simulateEconomy` (prototip testi: kayıpsız kuralda kilitlenme 0;
  bugünkü kuralda %10'un üstünde).
- Uygulanırsa SQL testleri: kayıpsız modda kart devri olmaz; Yüksek
  Risk'te kadroyu bozacak kart alınmaz; kilitlenmiş oyuncu kurtarma
  kartı alır.

**Beklenen sonuç:** Kilitlenen oyuncu %59'dan %0'a iner. Yeni gelen,
birleşik eşleştirmeyle %45 puan alır.

**Model sınırları:** Oyuncular coin yettikçe sadece Standart Paket alıyor
(Premium/Kadro paketi, SBC ve senin yarım kalan kart satma işin modelde
yok). Kart satma oyuna girerse kilitlenmeyi **azaltabilir**; ama satacak
kartı kalmayan oyuncu yine kilitlenir.

---

## 5. GitHub Actions

**Mevcut davranış (ilk çalışma, `f80014f`):**

| İş | Sonuç |
|---|---|
| Veritabanı (izole PostgreSQL) | ✅ |
| Uçtan uca (gerçek sunucu) | ✅ |
| Dart paketleri + sunucu | ✅ |
| Android release derleme | ✅ |
| Flutter analyze + test | ❌ `flutter analyze` |

**Kök neden:** Kökteki `flutter analyze`, `server/` ve `packages/*`
altındaki ayrı Dart projelerini de tarıyordu. Temiz klonda bu
projelerin bağımlılıkları yüklenmediği için 596 sahte "tanımsız" hatası
çıktı. Yerelde görünmüyordu, çünkü bağımlılıklar daha önce yüklenmişti.
İş günlüğünü okumak için yönetici yetkisi gerektiğinden, hata **temiz
bir git klonunda CI adımları birebir tekrarlanarak** bulundu.

**Kod konumu:** `analysis_options.yaml`

**Düzeltme:** Alt projeler kök analizden çıkarıldı. Bu projeler CI'ın
`paketler` işinde kendi klasörlerinde zaten analiz ediliyor.

**Test yöntemi:** Temiz klonda CI adımları: analiz temiz, 410 test
geçti, 9 test atlandı (canlı sunucu ister; o zincir `uctan_uca`
işinde geçiyor).

**Beklenen sonuç:** Gönderildikten sonra 5/5 yeşil. **Henüz
gönderilmedi; CI'da doğrulanmadı.**

---

## Onayını bekleyen kararlar

| # | Karar | Önerim |
|---|---|---|
| 1 | Eşleştirmeyi `combined` moda almak | **Evet**: en büyük adalet kazancı, tek satır, geri alınabilir |
| 2 | İlk tur kör cevap (S2b) → kural sürümü 3 | Evet, ama arayüz tasarımıyla birlikte |
| 3 | Özellik sistemi için hangi tasarım denensin | Enerji indirimi önce simüle edilsin |
| 4a | Normal derecelide kalıcı kart kaybını kaldırmak | **Evet** |
| 4b | Yüksek Risk'i isteğe bağlı mod yapmak | Evet (ürün kararı) |
| 4c | Kilitlenme güvencesi (ücretsiz eksik mevki kartı) | **Evet** (hata düzeltmesi) |
| 5 | GitHub'a göndermek (CI'ı doğrulamak için) | Evet |
