# Bağımsız Kod İncelemesi — İyileştirme Raporu

**Tarih:** 6 Kasım 2026 · **Kapsam:** taktik dengesi, Legend üstünlüğü,
futbolcu özellikleri, oyun motoru sürümleme, arena, CI.

**Yöntem:** Önce koda dokunmadan analiz yapıldı. Simülasyonlar geçici
bir pakette, uyumluluk deneyi ayrı bir geçici veritabanında çalıştı.
Sonra **oyun dengesini ve temel kuralları değiştirmeyen** kritik
düzeltmeler aşama aşama uygulandı. Denge ve kural değişiklikleri
**öneri** olarak bırakıldı ve onay bekliyor.

Analizleri yeniden üretmek için:

```bash
cd packages/tactics_prototype
dart run tool/inceleme/genel.dart 3000     # strateji matrisi, güç farkı, nadirlik, Legend modları
dart run tool/inceleme/ranked.dart 3000    # Ranked seçenekleri, ilk açan
dart run tool/inceleme/ilk_acan.dart 12000 # ilk açan çözüm seçenekleri
dart run bin/simulate.dart                 # RAPOR.md (zorunlu + izlenen hedefler)
```

> **Simülasyonun sınırları:** Turu açan kartını rastgele seçiyor
> (gerçek oyuncu bilerek seçer). Cevap veren kartını taktiği hesaba
> katmadan seçiyor. Yapay oyuncular gerçek oyuncu değil. Sayılar
> **yön** gösterir; kesin değerler gerçek maç verisiyle doğrulanmalı.

---

## Özet

| # | Sorun | Risk | Durum |
|---|---|---|---|
| 1 | Denge ölçütleri yetersizdi | Orta | ✅ Düzeltildi (sayılar değişmedi) |
| 2 | Başlangıç kadrosu kıdemliye karşı **%0** (eşleştirme sadece MMR'a bakıyor) | **Yüksek** | ⏳ Onay bekliyor |
| 3 | İlk turu açan dezavantajlı (**%44,5**) | Orta | ⏳ Onay bekliyor |
| 4 | Taktik kullanmayan oyuncu en kötü eşleşmede %32 | Orta | ⏳ Onay bekliyor |
| 5 | Legend kuralı neredeyse hiç devreye girmiyor (%0,1 tur) | Düşük | ⏳ Ranked önerisi |
| 6 | Futbolcu özellikleri oyunu etkilemiyor | Tasarım | ⏳ Tasarım önerisi |
| 7 | Kural güncellemesi süren maçları ortasında değiştiriyordu | **Yüksek** | ✅ Düzeltildi |
| 8 | Migration'lar tek işlemde çalışmıyordu | Orta | ✅ Düzeltildi |
| 9 | Arena gerçek 3B değil | Ürün | 📋 Yol haritası |
| 10 | CI yoktu | Orta | ✅ Eklendi (**henüz çalıştırılmadı**) |

---

## 1. Denge ölçütleri yetersizdi — ✅ DÜZELTİLDİ

**Mevcut davranış (önce):**
- "Tek numara herkesi ezmiyor" testi, bir taktiğin herkesi **%59** ile
  yenmesine izin veriyordu. Tek şartı, en az bir eşleşmede %60'ın
  altında kalmasıydı.
- Taş-kâğıt-makas sadece "Hep X" tarzları arasında kontrol ediliyordu.
- Bütün maçlar **eşit kadrolarla** oynanıyordu. Güç farkı, nadirlik,
  ilk açan ve enerji davranışları ölçülmüyordu.

**Kod konumu:** `packages/tactics_prototype/lib/src/balance.dart`,
`simulation.dart`

**Risk:** Orta. Dengesiz bir sistem "dengeli" görünebilirdi.

**Yapılan:**
- 2 yeni enerji tarzı eklendi: **Biriktirici** (enerji dolunca pres)
  ve **Harcayıcı** (her fırsatta harcar).
- Kadro profilleri eklendi: Başlangıç / Orta / Kıdemli ve +g güç.
- Hedefler ikiye ayrıldı. **Zorunlu** hedef tutmazsa test kırılır.
  **İzlenen** hedef raporda ❌ olarak görünür, "geçti" sayılmaz ve
  kullanıcı kararı bekler.
- İlk açan ölçümü 4 kat maçla yapılıyor. Tek tohumda şans eseri %45,0
  çıkıp **yanlışlıkla geçti** görünüyordu; 4 tohumla kontrol edilince
  fark edildi.

**Test yöntemi:** `dart test` (25 test). 4 farklı tohumla
`dart run tool/tohumlar.dart`.

**Sonuç (ölçüldü):**

| Zorunlu hedef | Sonuç |
|---|---|
| Hiçbir basit tarz herkesi yenmiyor (9 tarz, 36 eşleşme) | ✅ yok |
| Her tek-taktik / enerji tarzının iyi bir cevabı var (en kötü ≤ %45) | ✅ %32–41 |
| Taş-kâğıt-makas: Kontra > Pres > Duvar > Kontra | ✅ %57–68 |
| Güç farkı arttıkça güçlü taraf daha çok kazanır | ✅ +0: %51, +2: %59, +4: %70, +8: %86 |
| Taktikler kart gücü farkını büyütmüyor / silmiyor | ✅ en fazla %2,9 kayma |
| Legend ihlali | ✅ 0 / 792.000 tur |

"Akıllı" tarz herkesi yeniyor (%58–68). Bu tarz rakibin kartını görüp
hesap yapıyor; yani bu **beceri ödülü**, bir "tarif" değil.

---

## 2. Başlangıç kadrosu kıdemli kadroya karşı %0 — ⏳ ONAY BEKLİYOR

**Mevcut davranış:** Eşleştirme sadece puana (MMR) bakıyor, kadro
gücüne bakmıyor. Gerçek veritabanında başlangıç kadrosunun ortalama
gücü **62**. Altın, Diamond ve Legend ağırlıklı bir kadronun ortalaması
**~85**. Simülasyonda başlangıç kadrosu, **taktik ne olursa olsun**,
**%0** kazanıyor. Taktikleri ustaca kullanıp rakip taktiksiz oynasa
bile sonuç %0.

**Kod konumu:** `database/migrations/006_rpc_matchmaking.sql`
(`find_match`: `abs(q.mmr - v_mmr)`)

**Risk:** **Yüksek.** Aynı puandaki yeni bir oyuncu, kadrosunu
geliştirmiş biriyle eşleşince hiç şansı olmadan **3 kartını kaybeder**.
Yeni oyuncuyu kaçıran türden bir deneyim.

**Önerilen çözüm (simülasyonla karşılaştırıldı):**

| Seçenek | Zayıf kadronun puanı | "Umutsuz" maç oranı* |
|---|---|---|
| Bugün (sınırsız) | %7,3 | %75,9 |
| R1: kart gücü tavanı 75 | başlangıç %0,5 | — (işe yaramıyor) |
| **R2: kadro gücü ±5 bandı** | %24,6 | %18,4 |
| **R2: kadro gücü ±3 bandı** | **%32,3** | **%0** |

\*4 puan ve üzeri ortalama güç farkı. Bu fark simülasyonda yaklaşık
%70'e %30 sonuca denk geliyor.

**Öneri:** Eşleştirme MMR'ın **yanında** kadro gücünü de kullansın.
Bekleme uzadıkça bant genişlesin (bugün MMR bandı nasıl genişliyorsa
öyle). Kart gücü tavanı (R1) sorunu çözmüyor, çünkü başlangıç kadrosu
tavanın zaten altında.

**Test yöntemi:** `tool/inceleme/ranked.dart`; uygulanırsa
`find_match` için SQL testi (bant dışı rakiple eşleşmez, bekleme
uzayınca eşleşir).

**Beklenen sonuç:** Umutsuz maç oranı %76'dan **%0–18**'e iner. Kuyrukta
bekleme süresi biraz uzar; gerçek oyuncu sayısıyla ölçülmeli.

---

## 3. İlk turu açan dezavantajlı — ⏳ ONAY BEKLİYOR (temel kural)

**Mevcut davranış:** İlk turu açanın maç puanı **%44,5**; beş ölçümde
%44,0 ile %44,8 arasında. Sebep yapısal: cevap veren, rakibin kartını
**görüp** seçiyor. Turu kazanan bir sonraki turu açtığı için bu
avantaj sürekli el değiştiriyor. Açan en güçlü kartıyla açsa bile
sonuç %43.

**Kod konumu:** `play_card` / `_resolve_round` (sıra kuralı),
`get_match_state` (açanın kartı rakibe görünür)

**Risk:** Orta. Sunucu ilk açanı rastgele seçtiği için maçlar arası
adil, ama tek maç içinde yazı-tura etkisi var.

**Önerilen çözüm (simülasyonla karşılaştırıldı):**

| Seçenek | Taktiksiz | Akıllı | Kural değişikliği |
|---|---|---|---|
| Bugün | %45,4 | %43,9 | — |
| S1: ilk açana +1 başlangıç enerjisi | %45,4 | %45,2 | Küçük (taktik) |
| S2: cevap veren, kartın **gücünü** görmeden seçer | **%50,4** | **%48,6** | **Büyük (temel kural)** |

**Öneri:** Kısa vadede **S1** (ucuz, düşük riskli). S2 dengeyi tam
düzeltiyor ama oyunun temel hissini değiştiriyor ("rakibin kartına
cevap vermek"). Ayrı bir mod olarak denenebilir.

**Test yöntemi:** `tool/inceleme/ilk_acan.dart`; uygulanırsa denge
raporundaki "İlk açan" izlenen hedefi.

**Beklenen sonuç:** S1 ile Akıllı oyuncuda %45'e çıkar (hedefin alt
sınırı); S2 ile %48–50.

---

## 4. Taktik kullanmayan oyuncu dezavantajlı — ⏳ ONAY BEKLİYOR

**Mevcut davranış:** Taktiksiz oyuncunun ortalaması %39. En kötü
eşleşmesi Akıllı'ya karşı **%32,3**.

**Kod konumu:** Taktik sayıları `021_tactics.sql` ve
`TacticRules.balanced` içinde.

**Risk:** Orta. Taktiği öğrenmemiş yeni oyuncu fark etmeden
dezavantajlı oynuyor.

**Önerilen çözüm:** Sayıları değiştirmeden, **arayüzle**:
1. İlk maçlarda kısa bir taktik öğreticisi.
2. Enerji dolu ve rakip kart güçlüyse taktik düğmesinin hafifçe
   parlaması (karar oyuncuda kalır).

**Test yöntemi:** Gerçek maç verisinde "hiç taktik kullanmayan
oyuncuların kazanma oranı" izlenmeli. Veritabanında `match_moves.tactic`
zaten kayıtlı.

**Beklenen sonuç:** Taktik kullanım oranı artar, taktiksiz kalan
oyuncu azalır.

---

## 5. Legend üstünlüğü ve Ranked modu — ⏳ ÖNERİ

**Mevcut davranış:** Legend, Legend olmayan her kartı mutlak yenir
(`compare_cards`). Ama gerçek katalogda Legend'lar zaten en güçlü
kartlar (94–99; Diamond 86–92). Bu yüzden kural turların sadece
**%0,1**'inde sonucu değiştiriyor. Legend'lı kadronun avantajı (%59)
**ham güçten** geliyor, kuraldan değil.

| Legend modu (simülasyon) | Legend'lı vs Legend'sız eşit kadro |
|---|---|
| Mevcut: mutlak | %59,0 |
| Alt.1: Legend +6 güç, mutlak değil | %59,0 |
| Alt.2: sadece Altın ve altını mutlak yener | %59,1 |
| Alt.3: seviye kuralı yok | %59,1 |

**Kod konumu:** `001_extensions_enums_helpers.sql` (`compare_cards`)

**Risk:** Bugün düşük. **Gelecekte yüksek:** gücü düşük bir Legend
eklenirse (ör. 88 güçlü bir "efsane"), kural birden belirleyici olur
ve taktiklere karşı da dokunulmaz olur.

**Önerilen Ranked modu:**
1. **Seviye kuralı yok** (Alt.3): sonuç güç + kimya + taktik. Nadirlik
   otomatik galibiyet vermez; bugünkü sonuçlar neredeyse aynı kalır.
2. **Kadro gücü bandında eşleştirme** (madde 2, R2). Rekabet adaletini
   asıl bu sağlıyor.
3. Normal mod bugünkü gibi kalır.

Bu değişikliği **motor sürümleme (madde 7)** taşıyabilir:
`game_rule_versions` tablosuna `legend_mode` bayrağı eklenir. Ranked
maçlar o sürümle kurulur, normal maçlar etkilenmez.

**Test yöntemi:** `tool/inceleme/genel.dart` (bölüm 5); uygulanırsa
`compare_cards` için sürüme bağlı SQL testleri.

**Beklenen sonuç:** Ranked'da nadirlik otomatik galibiyet sağlamaz;
güç ve beceri belirler.

---

## 6. Futbolcu özellikleri ↔ taktik etkileşimi — ⏳ TASARIM ÖNERİSİ

**Mevcut davranış:** Kartlarda 6 özellik var (şut, hız, fizik, defans,
dribling, hızlanma). Mevkiye göre profilden türetiliyorlar
(`016_card_attributes.sql`), ama **maçı hiç etkilemiyorlar**.

**Önerilen tasarım:** Özellik **gücü artırmaz**. Sadece taktik
bonusunu **ölçekler**, o da **sınırlı** olarak:

| Taktik | Belirleyen özellikler | Etki |
|---|---|---|
| Yüksek Pres (+9) | Fizik + Hızlanma | ×0,8 – ×1,2 → **+7 ile +11** |
| Kontra Atak (+2 / +13) | Hız + Dribling | ×0,8 – ×1,2 → kontra-pres **+10 ile +16** |
| Savunma Duvarı (+6 / +2) | Defans + Fizik | ×0,8 – ×1,2 → savunmada **+5 ile +7** |

Formül: `çarpan = 0,8 + 0,4 × (iki özelliğin ortalaması − 40) / 59`,
0,8 ile 1,2 arasına kırpılır.

**Neden böyle?**
- **Sınırsız güç yok.** En iyi özellik bile bonusu en fazla %20
  artırır; taktik yoksa özellik hiçbir şey yapmaz.
- **Farklı futbolcu türleri, farklı stratejiler.** Hızlı/dribling
  forvet kontrada parlar. Fizikli/defansif stoper duvarda parlar.
  Fizikli orta saha prese yatkındır.
- **Legend kuralı korunur.** Bonus yine Legend kontrolünden sonra
  eklenir.

**Risk:** Tasarım. Yanlış katsayı bir mevkiyi aşırı güçlendirebilir.

**Test yöntemi (uygulamadan ÖNCE):**
1. Prototipe `SimCard.attributes` eklenir. Denge raporu tekrar koşulur:
   bütün zorunlu hedefler tutmalı.
2. Yeni zorunlu hedef: hiçbir mevki/taktik çifti diğerlerinden %5'ten
   fazla tur kazandırmamalı.
3. Sunucuya **yeni bir kural sürümü** (3) olarak eklenir; süren maçlar
   etkilenmez.

**Beklenen sonuç:** Kart seçimi "en güçlüyü at"tan "bu taktiğe uygun
oyuncuyu seç"e döner. Güç farkı tablosu (madde 1) değişmemeli.

---

## 7. Kural güncellemesi süren maçları değiştiriyordu — ✅ DÜZELTİLDİ

**Mevcut davranış (önce):** Geçici bir veritabanında deneyle
gösterildi: 021'den önceki kurallarla başlayan bir maç, 021 uygulanınca
**yarısında** taktikli kurallara geçti. 5. turdaki oyuncunun enerjisi
başlangıç değerinde (2) kaldı. Maçın hangi kurallarla başladığı
**hiçbir yerde kayıtlı değildi.**

**Kod konumu:** `021_tactics.sql` (`_resolve_round` yerinde değişti),
`matches` tablosu

**Risk:** **Yüksek.** Her mekanik güncellemesi aktif maçları ortasında
değiştirecekti.

**Yapılan (`023_rules_versioning.sql`):**
- `game_rule_versions`: her sürüm bir satır ve özellik bayrakları
  (`tactics_enabled`; ileride `legend_mode` gibi bayraklar eklenebilir).
- `matches.rules_version`: maç **kurulurken** güncel sürüm yazılır.
- `_resolve_round` ve `play_card` maçın **kendi** sürümüne bakar.
  Taktiksiz sürümdeki maçta taktik reddedilir; uygulama taktik
  çubuğunu göstermez.
- Mevcut maçlar sürüm 2 olarak işaretlendi, çünkü 021'den beri fiilen
  o kurallarla oynanıyorlar. **Yeni maçlar için davranış değişmedi.**
- Fonksiyon gövdeleri 021'den **programla türetildi**; sadece işaretli
  satırlar farklı.

**Test yöntemi:**
- `database/tests/023_rules_versioning_test.sql`: sürüm 1 maçta taktik
  reddedilir, enerji değişmez, güçlü kart kazanır; yeni maç güncel
  sürümle kurulur.
- `scripts/db-testleri.sh`, madde 4: **eski sürümde başlayan maç, son
  migration uygulandıktan sonra hatasız biter ve kural sürümünü korur.**

**Sonuç (ölçüldü):** Yerelde bütün veritabanı testleri geçti. 021 ve
022 testleri 023'ten sonra da geçiyor; davranış değişmedi.

---

## 8. Migration'lar tek işlemde çalışmıyordu — ✅ DÜZELTİLDİ

**Mevcut davranış (önce):** `021_tactics.sql` önce `play_card`'ı
**siliyor**, sonra yeniden oluşturuyor. Migration'lar tek işlem içinde
çalıştırılmadığı için arada gelen bir kart oynama isteği "fonksiyon
yok" hatası alabiliyordu. Yarıda hata çıkarsa veritabanı yarım
kalıyordu.

**Kod konumu:** `scripts/veritabani-sifirla.ps1`

**Risk:** Orta (canlı sunucuya migration uygulanırken).

**Yapılan:** Bütün migration çalıştırıcıları `psql -1` kullanıyor
(sıfırlama betiği, `db-testleri.sh`, CI). Ayrıca migration'ların
**ikinci kez çalıştırılabilir** olduğu test ediliyor.

**Sonuç (ölçüldü):** 22 migration tek işlemde sıfırdan kuruldu ve
ikinci kez hatasız uygulandı.

---

## 9. Arena: gerçek 3B yol haritası — 📋 PLAN

**Mevcut durum:**
- `arena_backdrop.dart` (401 satır) ve `clash_scene.dart` (860 satır),
  saf `CustomPainter` ile yazılmış.
- **Hiç dış bağımlılık yok.** Perspektif tek bir sınıfta toplanmış:
  `ArenaProjection` (u,v → ekran).
- Çatışma sahnesi sunucunun tur kaydını oynatıyor; atlanabiliyor ve
  animasyon ayarına uyuyor.
- Sınırlar: oyuncular daire/şekil çizimi, karakter animasyonu yok,
  kamera sabit.

**Kod konumu:** `lib/features/match/presentation/arena/`

**Seçenekler (mevcut 2.5B'yi bozmadan, aşamalı):**

| Aşama | Ne | Bağımlılık | Risk | Kazanç |
|---|---|---|---|---|
| A1 | **Kamera hareketi:** `ArenaProjection` parametrelerini (ufuk, ölçek) animasyonla değiştir: çatışmada yakınlaşma, golde sarsıntı | Yok | Düşük | Yüksek his, sıfır maliyet |
| A2 | **Karakter animasyonu:** 2.5B "billboard" karakterler (Rive veya sprite sayfası); koşu, şut, kurtarış, mevki başına 4–6 klip | `rive` (onay gerekir) | Orta | Asıl kalite sıçraması |
| A3 | **Önceden işlenmiş klipler:** mevki başına kısa video, kart çerçevesinde oynatılır | `video_player` | Düşük | Sinematik, ama dinamik değil |
| A4 | **Gerçek 3B:** `flutter_scene` / Flutter GPU (Impeller), glTF modeller, iskelet animasyonu | Deneysel paket | **Yüksek** | Tam 3B; API'ler henüz kararlı değil |
| A5 | Unity/Godot gömme | Ağır yerel motor | Çok yüksek | Önerilmez: APK +40 MB, iki kod tabanı |

**Öneri:** A1 (hemen, bağımlılıksız) → A2 (bir mevkiyle prototip,
performans ölçümüyle) → A4'ü bir **özellik bayrağı** arkasında dene.
Mevcut CustomPainter arena her aşamada **yedek** olarak kalır; düşük
donanımlı cihazlarda ve "animasyonları kapat" ayarında o kullanılır.

**Test yöntemi:**
- Her aşamada mevcut `arena_test.dart` ve `match_layout_test.dart`
  geçmeli.
- **Gerçek cihazda** `flutter run --profile` + DevTools: kare süresi
  < 16 ms (60 FPS), düşük segment Android'de ölçülmeli.

**Beklenen sonuç:** Sunucu sonucu belirlemeye devam eder; arena sadece
görselleşir.

---

## 10. CI — ✅ EKLENDİ, ⚠️ HENÜZ ÇALIŞTIRILMADI

**Mevcut davranış (önce):** Otomatik kontrol yoktu.

**Kod konumu:** `.github/workflows/ci.yml`

**Yapılan, 5 iş:**

| İş | Ne yapıyor |
|---|---|
| `uygulama` | Model kodu üretimi, `flutter analyze`, `flutter test` |
| `paketler` | Ortak modeller, taktik prototipi (denge dahil), sunucu: analyze + test |
| `veritabani` | **İzole PostgreSQL 17**, `scripts/db-testleri.sh` (kurulum, kural testleri, tekrar çalıştırma, maç sürerken yükseltme) |
| `uctan_uca` | İzole PostgreSQL + **gerçek sunucu**: tam maç, gerçek zamanlı zincir, **günlükte jeton yok** kontrolü |
| `android` | `flutter build apk --release`, APK'da İNTERNET izni `aapt` ile doğrulanır |

**Dürüst durum:** YAML geçerli. İçindeki komutların hepsi bu oturumda
yerelde (Windows) tek tek çalıştı ve geçti. **İş akışının kendisi ise
GitHub'a gönderilmeden çalışamaz ve henüz çalıştırılmadı.** İlk
çalışmada Linux'a özgü küçük sorunlar çıkabilir.

**Test yöntemi:** GitHub'a gönder → Actions sekmesinde 5 iş yeşil olmalı.

---

## Onayını bekleyen kararlar

1. **Eşleştirmede kadro gücü bandı** (madde 2): rekabet adaleti için en
   etkili değişiklik.
2. **İlk açan:** S1 (+1 enerji) mi, S2 (kör cevap) mı, yoksa olduğu
   gibi mi? (madde 3)
3. **Ranked modu:** seviye kuralı olmadan + kadro gücü bandı. (madde 5)
4. **Özellik-taktik etkileşimi:** önce prototipte simülasyon, sonra
   kural sürümü 3. (madde 6)
5. **Arena:** A1 kamera hareketiyle başlayalım mı? A2 için `rive`
   bağımlılığına onay. (madde 9)
6. **CI'ın çalışması için GitHub'a gönderme.**
