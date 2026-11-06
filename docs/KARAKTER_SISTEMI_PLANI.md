# Özgün Karakter Evreni — Geçiş ve Geliştirme Planı

**Durum:** PLAN. Onay verilmeden hiçbir kod, veri veya varlık
değiştirilmeyecek. **Tarih:** 6 Kasım 2026

---

## 0. Depo analizi: bugün ne var?

Ölçümler yerel veritabanından ve koddan alındı.

| Konu | Bulgu | Önem |
|---|---|---|
| Kart görselleri | 100 kartın hepsinde `image_url` var (`cards/bronz-kaleci-emre-yilmaz.png`), ama **dosyaların hiçbiri yok**. Kartlar siluet çiziyor. Kodda görsellerin zaten "yapay zekâ ile üretilmiş, Pixar tarzı, şeffaf arka planlı" olması planlanmış (`premium_player_card.dart:358`). | Fotoğraf yok; geçişin görsel tarafı sıfırdan |
| **Gerçek kişi adları** | 6 Legend kartın tamamı gerçek ünlü futbolcu: **Diego Maradona, Pele, Johan Cruyff, Franz Beckenbauer, Lev Yashin, Ferenc Puskas**. Oyuncuların elinde bu kartlardan **50 adet** var. | 🔴 Kişilik/isim hakkı riski, yayından önce kalkmalı |
| **Tescilli lig adları** | Bundesliga, La Liga, Serie A, Premier Lig, Ligue 1, Eredivisie, Süper Lig | 🟠 Marka riski |
| Kulüpler | 29 kurgu ad, bazıları gerçeğe çok yakın ("Madrid Real", "Munchen SV", "Milano Nero") | 🟠 Değiştirilmeli |
| Uyruklar | 14 gerçek ülke kodu (TUR, BRA, …) | Ülke adı lisans gerektirmez; kurgu bölgeye geçiş bir tasarım tercihi |
| Diğer adlar | Bronz–Diamond 94 kartın adları kurgusal görünüyor (Emre Yılmaz, Luca Bianchi…). Gerçek kişilere tesadüfen denk gelme kontrolü yapılmadı. | Benzerlik kontrolünden geçmeli |
| Sahiplik | 100 farklı kartın hepsi sahiplenilmiş; 182 kullanıcıda **3.346 kart** | Kart kimlikleri (`cards.id`) **korunmalı** |
| Kimya | `club`, `league`, `nationality` alanlarının eşitliğine bakıyor (`014_chemistry.sql`) | Kurgu bölge/lig/kulüp aynı gruplamayı korumalı |
| Özellikler | 6 özellik = güç + mevki profili ± 4, `slug`'dan **deterministik** (`016`) | Denge motorunun temeli olarak korunabilir |
| Katalog dağılımı (100) | GK 12 · DEF 30 · MID 33 · FWD 25. Bronz 30 · Gümüş 28 · Altın 24 · Diamond 12 · Legend 6 | 150'lik plana taban |
| Arena | `ArenaBackdrop` (401 satır) + `ClashScene` (860 satır), saf `CustomPainter`; perspektif `ArenaProjection` içinde toplanmış. Oyuncular şekil/daire çizimi, gerçek karakter yok. | Gerçek 3B değil, yedek olarak kalır |
| Varlıklar | `assets/images`, `assets/animations`, `assets/icons` boş | Varlık hattı yok |

**Sonuç:** Mevcut sistem "gerçek fotoğraf" kullanmıyor; ama **gerçek kişi
adları ve tescilli lig adları** kullanıyor. Asıl acil iş bu.

---

## 1. Geçiş planı (gerçek isimlerden özgün karakterlere)

**İlke:** Kart **kimliği** (`cards.id`) ve **oyun değerleri** (mevki,
seviye, güç) aynen kalır; sadece **karakter kimliği** değişir. Böylece
sahiplik, kadrolar, kimya ve süren maçlar etkilenmez. Hiçbir veri
silinmez; eski kimlik arşivlenir.

| Adım | Ne yapılır | Güvence |
|---|---|---|
| G1 | `cards_identity_archive` tablosuna eski ad, kulüp, lig, uyruk ve `image_url` kopyalanır | Geri dönüş mümkün; veri silinmez |
| G2 | Kurgu dünya kurulur: 8 kurgu bölge, 8 kurgu lig, 29+ kurgu kulüp. **Gruplama birebir korunur**: eski "aynı kulüp" çiftleri yeni kulüpte de aynı kulüp olur. | Test: her kadronun kimyası geçişten önce ve sonra **aynı** |
| G3 | Her mevcut kart bir özgün karaktere bağlanır (`cards.character_id`). Mevki, seviye ve güç değişmez. | Test: hiçbir kartın güç/mevki/seviyesi değişmedi |
| G4 | 6 Legend özgün "efsane" karakterlere dönüşür (ör. kurgu bir ligin kurucu kaptanı). **Yayından önce zorunlu.** | Test: katalogda gerçek kişi adı kalmadı (kara liste + benzerlik) |
| G5 | 50 yeni karakter eklenir (toplam 150); yeni kartlar paket havuzuna girer | Paket oranları değişmez; yeni kartlar ilgili seviye havuzuna eklenir |
| G6 | Uygulama `character_id` üzerinden portre, hikâye ve görsel sürümünü gösterir | Eski alanlar okunmaya devam eder (geriye uyum) |

Bütün adımlar **katalog sürümü** olarak yapılır (bölüm 2). Taslak sürüm
onaylanana kadar oyunda görünmez; yayın tek işlemle olur.

---

## 2. Yeni karakter veri modeli

```
catalog_versions        (version, status: draft|review|published|retired, notes, published_at)

fictional_regions       (code, name, flag_spec jsonb)          -- ülke yerine kurgu bölge (isteğe bağlı)
fictional_leagues       (code, name, region_code, crest_spec)
fictional_clubs         (code, name, league_code, colors, crest_spec)

characters
  id uuid, slug unique, catalog_version
  given_name, family_name, display_name
  region_code, club_code
  primary_position, secondary_position
  playstyle              -- ör. 'hizli_kanat', 'kurt_stoper', 'oyun_kurucu', 'cizgi_kalecisi'
  personality jsonb      -- 3–5 özellik
  bio_short, bio_long
  appearance jsonb       -- ten, saç, yüz, boy-yapı, aksesuar, forma numarası
  animation_profile      -- hareket seti kimliği (bölüm 8)
  status: draft|in_review|approved|published|retired
  created_by: 'ai'|'human', reviewed_by, reviewed_at

cards  (MEVCUT, korunur)  + character_id → characters
  -- mevki / seviye / güç / özellikler oyun değeri olarak burada kalır;
  -- ileride aynı karakterin farklı seviyede kartı olabilir.

character_assets
  id, character_id, kind: reference_sheet|portrait|card_art|model_glb|sprite_sheet|anim_clip
  version int, uri, sha256, width, height, bytes
  generator, generator_model, prompt, negative_prompt, seed, params jsonb
  style_ref_version, reference_asset_id (tutarlılık zinciri)
  status: generated|in_review|approved|rejected
  reviewed_by, reviewed_at, rejection_reason

content_review_log      (entity, entity_id, action, actor, reason, at)
```

**Kurallar:**
- Bir karakterin onaylanmış varlıkları **değiştirilemez** (yeni sürüm
  eklenir). Kart her zaman en son **onaylı** sürümü gösterir.
- `seed`, `prompt`, `params` ve `reference_asset_id` saklandığı için
  aynı karakter yeniden üretildiğinde aynı kimliğe bağlı kalır.

---

## 3. Yapay zekâ futbolcu üretim mimarisi

```
[Katalog planı] ──► [1. Kimlik üretici (Claude)] ──► [2. Doğrulayıcı (kod)] ──► [3. Denge Motoru (kod)]
                                                                                 │
     [7. Yayın] ◄── [6. İnsan onayı (panel)] ◄── [5. Görsel/3B hattı] ◄── [4. Benzerlik denetimi]
```

1. **Kimlik üretici (metin):** Claude API (`claude-opus-5-5`, yapılandırılmış
   JSON çıktı `output_config.format`). Toplu iş (Message Batches, %50
   indirim) ile çalışır. Girdi: mevki, seviye yuvası, kurgu bölge/kulüp,
   çeşitlilik hedefleri ve o ana kadar üretilmiş adlar. Çıktı: ad, oyun
   tarzı, kişilik, hikâye, görünüş tanımı, görsel üretim tanımı.
   **Güç değeri üretmez.**
2. **Doğrulayıcı (deterministik kod):** şema, uzunluk, yasaklı içerik,
   ad tekrarı, mevki–oyun tarzı uyumu.
3. **Denge Motoru:** güç ve özellikleri **yapay zekâ değil, kod** belirler
   (bölüm 4).
4. **Benzerlik denetimi:**
   - Gerçek ünlü futbolcu ve kişi adlarından oluşan yerel bir **kara
     liste** ile birebir ve bulanık eşleşme.
   - İkinci bir Claude çağrısıyla "bu ad tanınmış gerçek bir kişiyi
     çağrıştırıyor mu?" yargısı.
   - Görsel taraf: **gerçek kişiye benzerlik insan onayıyla** kontrol
     edilir.
5. **Görsel / 3B hattı:** bölüm 7–9.
6. **İnsan onayı:** yönetim ekranında taslak karakter, kart önizlemesi ve
   portre yan yana; onayla / reddet (gerekçe) / yeniden üret. Her eylem
   `content_review_log`'a yazılır.
7. **Yayın:** onaylı karakterler yeni `catalog_version` olarak tek
   işlemle yayınlanır.

**Güvenlik:**
- Üretim hattı oyun sunucusundan **ayrı bir araç**tır (`server/tool/` veya
  ayrı paket). Oyuncu isteği asla canlı üretim tetiklemez.
- API anahtarı sadece ortam değişkeninde tutulur.
- Yapay zekâ çıktısı **asla doğrudan** `cards` tablosuna yazılmaz; sadece
  `characters` taslağına.

**Metin maliyeti (tahmini):** 150 karakter × ~2.000 çıktı jetonu ≈ 300 bin
jeton. Opus 5.5 fiyatıyla ($20 / milyon çıktı) toplu işte ~%50 indirimle
**~3–4 dolar**; benzerlik yargısı ve yeniden üretimlerle **10 doların
altında**. Görsel ve 3B maliyeti seçilecek sağlayıcıya bağlı (bölüm 11).

---

## 4. Güç dengeleme yöntemi (Game Balance Engine)

Yapay zekâ sadece **oyun tarzı** önerir. Sayıları kod üretir:

1. **Katalog kotası:** seviye × mevki dağılımı önceden sabittir (bölüm 5).
   Karakter bir **yuvaya** atanır (ör. "Altın DEF #7"). Güç o seviyenin
   gerçek aralığından deterministik olarak seçilir (Bronz 45–62 … Legend
   93–99).
2. **Özellikler:** bugünkü formül korunur: `güç + mevki profili ± sapma`
   (`016`). Oyun tarzı, mevki profili üstüne **toplamı sıfır**, her
   özellikte en fazla ±6'lık bir şekil ekler. Örnek: "hızlı kanat":
   hız +5, hızlanma +4, fizik −4, defans −5. Ortalama değişmez, sadece
   karakter kazanır.
3. **Taktik uyumu:** özelliklerin güçten sapmasından türetilir (prototipte
   `TacticAffinity`). Bugünkü canlı kurallarda (sürüm 2) **maçı etkilemez**;
   sadece kartta bilgi olarak gösterilir. Maça bağlanması ayrı bir kural
   sürümü ve onay gerektirir (bkz. `REKABET_ANALIZI_RAPORU.md` madde 3).
4. **Sınırlar ve doğrulama:**
   - Bütün değerler 1–99.
   - Aynı mevki ve seviyede özellik toplamı ±3 bandında.
   - Mevcut 100 kartın **gücü değişmez**.
5. **Simülatör kontrolü:** yeni katalogdan paket oranlarıyla kadrolar
   çekilip `runBalance` ve eşleştirme/ekonomi simülasyonları koşulur.
   Zorunlu hedefler tutmazsa katalog yayınlanmaz (CI'da test).

---

## 5. 150 karakterlik başlangıç kataloğu

**Dağılım** (önerin: 20 GK · 50 DEF · 50 MID · 30 FWD):

| | Bronz | Gümüş | Altın | Diamond | Legend | Toplam | Mevcut | Yeni |
|---|---|---|---|---|---|---|---|---|
| GK | 6 | 5 | 5 | 2 | 2 | 20 | 12 | 8 |
| DEF | 15 | 14 | 12 | 6 | 3 | 50 | 30 | 20 |
| MID | 15 | 14 | 12 | 6 | 3 | 50 | 33 | 17 |
| FWD | 9 | 9 | 7 | 3 | 2 | 30 | 25 | 5 |
| **Toplam** | 45 | 42 | 36 | 17 | 10 | **150** | 100 | 50 |

**Üretim sırası:**
1. **Kurgu dünya:** bölgeler, ligler, kulüpler. Yapay zekâ önerir, sen
   onaylarsın.
2. **Mevcut 100 kartın yeni kimliği** (mevki/seviye/güç sabit). Önce 6
   Legend.
3. **50 yeni karakter.**
4. **Görsel:** önce stil kılavuzu ve 5 seviye çerçevesi; sonra karakter
   başına referans sayfası → portre → kart görseli.
5. **3B model:** önce 1 prototip karakter (bölüm 10). Ölçeklendirme
   prototip sonucuna göre (150 tam rigli model pahalı olabilir; bölüm 7).

**Çeşitlilik hedefleri** (doğrulayıcıda sayısal):
- Ten, saç ve boy-yapı dağılımı dengeli.
- Kurgu bölgelerden her biri en az %8.
- Aynı ilk harf ya da benzer ses yapısı tekrarı sınırlı.

---

## 6. Yeni premium kart tasarım sistemi

Mevcut `PremiumPlayerCard`, renk paleti ve seviye temaları
(`CardTierTheme`) **korunur**. Değişen kısımlar:

| Katman | Bugün | Yeni |
|---|---|---|
| Görsel | Siluet | Onaylı portre (şeffaf PNG/WebP, 3 boyut: 256/512/1024) |
| Bilgi | Güç, mevki, ad, seviye | + **oyun tarzı** rozeti, + öne çıkan 2 özellik |
| Seviye efekti | Çerçeve, holografik parlama | + seviyeye göre arka plan sahnesi: Bronz sade, Gümüş metalik, Altın ışık hüzmesi, Diamond kırılma, Legend hareketli aura |
| Kimlik | — | Kurgu kulüp arması + bölge işareti (vektör, `crest_spec`'ten çizilir) |
| Detay | Alt sayfa | **Karakter detay ekranı**: büyük portre, hikâye, kişilik, özellik grafiği, taktik uyumu, (varsa) döndürülebilir 3B önizleme |

Kart ile portre aynı `character_assets` kaydından gelir; tutarlılık
böyle sağlanır.

---

## 7. 3D arena için önerilen teknoloji

**Değerlendirme:**

| Seçenek | Gerçek 3B? | Kalite | Mobil performans | Risk | Değerlendirme |
|---|---|---|---|---|---|
| 1. 2.5B animasyonlu (bugünkü + iyileştirme) | Hayır | Orta | Çok iyi | Düşük | Yedek olarak kalır, hedef değil |
| 2. Sprite tabanlı (3B modelden **önceden işlenmiş** kareler) | Görünüm olarak evet | Yüksek | Çok iyi | Düşük | Düşük donanım yedeği |
| 3. Parçalı 3B (kemiksiz, uzuv parçaları) | Evet | Düşük–orta | İyi | Orta | Önerilmez: stilize insan anatomisinde kötü durur |
| **4. Gerçek rig + iskelet animasyonu (glTF, Flutter içinde)** | **Evet** | **Yüksek** | Ölçülmeli | Orta | **Hedef** |
| 5. Oyun motoru gömme (Unity / Godot) | Evet | Çok yüksek | İyi | **Yüksek** | Önerilmez: APK +30–60 MB, iki kod tabanı, Flutter ile durum köprüsü |

**Öneri: 4 + 2 (iki katman).**
- **Ana katman:** glTF 2.0 model + iskelet + animasyon klipleri, Flutter
  içinde gerçek zamanlı. Aday kütüphane: `flutter_scene` (Flutter GPU /
  Impeller üzerinde, glTF ve iskelet animasyonu). **Deneysel bir paket.**
  Flutter 3.44 ile uyumu ve Android/iOS desteği prototipte doğrulanmalı.
  Bağımlılık eklemek onay gerektirir.
- **Yedek katman:** aynı rigli modelden önceden işlenmiş sprite sayfaları
  (Blender ile, komut satırından). Düşük donanımda, "animasyonları kapat"
  ayarında ve 3B katman açılamazsa kullanılır.
- **Mevcut `ArenaProjection` korunur:** saha, kamera ve yerleşim onunla
  hesaplanmaya devam eder; 3B karakterler aynı koordinatlara yerleştirilir.
  `ClashScene` sonucu yine sunucudan alır.

**Prototip ölçütü:** orta segment bir Android telefonda, 2 karakterli
çatışma sahnesinde kare süresi **< 16,7 ms (60 FPS)**, bellek artışı
**< 150 MB**. Tutmazsa sprite katmanı ana katman olur.

---

## 8. Karakter animasyon sistemi

**İlke:** Animasyon sonucu **belirlemez**. Sunucunun tur kaydından
(`ClashEvent`) bir **koreografi** seçilir ve oynatılır. Atlanabilir.

**Klip kütüphanesi** (karakter başına değil, **iskelet başına**; bütün
karakterler aynı iskeleti paylaşır, böylece 150 karakter aynı klipleri
kullanır):

| Mevki | Klipler |
|---|---|
| Ortak | bekleme, yürüyüş, koşu, galibiyet, mağlubiyet |
| Forvet | top sürme, şut, gol sevinci |
| Defans | alan kapatma, müdahale (kayarak), top kapma, savunma sevinci |
| Orta saha | pas, top kontrolü, çalım, pas arası |
| Kaleci | hazır bekleme, kurtarış, dalış (sol/sağ), topu tutma |

**Koreografi = (mevki, sonuç, taktik)** →
`[açan klip dizisi, cevap klip dizisi, kamera yolu]`.

Örnek: Forvet, açan kazandı, Yüksek Pres → forvet top sürer → şut;
rakip forvet müdahale eder ama geç kalır; kamera yakınlaşır.

**Kişilik katmanı:** `animation_profile` aynı klibin hız ve sevinç
varyantını seçer (ör. "gösterişçi" farklı bir sevinç yapar).

**Teknik:** Bir koreografi tablosu (veri), `ClashEvent` → koreografi
eşleyici (saf, test edilebilir) ve animasyon karıştırma
(çapraz geçiş 150–250 ms).

---

## 9. Karakter tutarlılığı ve görsel üretim

**Zincir:** stil kılavuzu (sürümlü) → **karakter referans sayfası**
(ön/yan/arka + yüz yakın çekim) → portre → kart görseli → 3B model →
sprite / klipler. Her adım bir öncekini `reference_asset_id` ile
referans alır.

**Kayıt altına alınanlar:** üretici, model sürümü, istem, negatif istem,
tohum, parametreler, stil sürümü, referans varlık, dosya özeti
(`sha256`), onay durumu ve onaylayan.

**Yeniden üretimde kimlik kayması önlemleri:**
- Görünüş tanımı yapılandırılmış alanlardan istem şablonuna dökülür.
- Referans görsel girdisi her üretimde kullanılır.
- Onaylı referans sayfası değiştirilemez.
- Yeni üretim, referansa benzerlik açısından insan onayından geçer.

**Görsel ve 3B üretim kimde?** Ben bu ortamda Claude ile **metin**
üretebilirim; **görsel ve 3B model doğrudan üretemem.** Seçenekler:
- **(a) Yapay zekâ görsel / görselden-3B hizmeti.** Oturuma bağlı harici
  bir hizmette görsel ve 3B üretim araçları görünüyor. Bunları
  kullanmak **ücretli** ve **senin onayını gerektirir**; şartları
  (ticari kullanım, çıktı hakları) önce incelenmeli.
- **(b) Sanatçı.** En tutarlı sonuç, en yavaş ve en pahalı yol.
- **(c) Karma.** Yapay zekâ taslak + sanatçı rötuş ve rig.

**Rig ve animasyon:** otomatik rig aracı + hazır animasyon kütüphanesi
(lisansı oyunda kullanıma uygun olmalı) ya da Blender ile elle.
**Lisans kontrolü zorunlu.**

---

## 10. Değiştirilecek / oluşturulacak dosyalar

**Veritabanı (yeni migration'lar; mevcutlara dokunulmaz):**
- `025_character_catalog.sql`: `catalog_versions`, kurgu dünya tabloları,
  `characters`, `character_assets`, `content_review_log`,
  `cards.character_id`, `cards_identity_archive`
- `026_fictional_world_seed.sql`: kurgu bölge, lig ve kulüpler (onaydan
  sonra)
- `027_catalog_v2_identities.sql`: 100 kartın yeni kimliği, 6 Legend
  dahil (onaydan sonra)
- Testler: `database/tests/025_*.sql` (sahiplik, kimya ve güç geçişten
  önce ve sonra aynı; gerçek ad kalmadı)

**Ortak modeller:** `packages/shared_models/lib/src/character_models.dart`
(yeni): `Character`, `CharacterAsset`, `Playstyle`, `FictionalClub`;
`card_model.dart`'a `characterId`

**Sunucu:**
- `server/lib/routes/character_routes.dart` (yeni): karakter detayı,
  varlık adresleri
- `server/lib/routes/admin_content_routes.dart` (yeni, yetkili): taslak,
  onay, ret

**İçerik hattı (yeni paket, oyundan ayrı):** `packages/content_pipeline/`:
Claude toplu üretim, doğrulayıcı, Denge Motoru, benzerlik denetimi,
dışa aktarım

**Uygulama:**
- `lib/shared/widgets/premium_card/premium_player_card.dart` (portre,
  oyun tarzı rozeti, seviye sahnesi)
- `lib/features/collection/...` (karakter detay ekranı)
- `lib/features/match/presentation/arena/` (3B katman + koreografi;
  `ArenaBackdrop` ve `ClashScene` yedek olarak kalır)
- Bölüm 13'teki ekranlar

**Değişmeyecekler:** maç motoru (`_resolve_round`, `play_card`, `023`
sürümleme), taktik/enerji, eşleştirme (`024`), lig/MMR, paket açma
mantığı, kimya **kuralları**.

---

## 11. Maliyet ve performans

- **Canlı üretim yok:** paket açılışında görsel üretilmez; bütün varlıklar
  önceden üretilir, onaylanır, CDN/sunucuda saklanır.
- **Çözünürlükler:**
  - Portre: 256 (liste), 512 (kart), 1024 (detay). WebP, şeffaf.
  - 3B model: 5–15 bin üçgen, 1–2 doku atlası (1024²).
  - Sprite: mevki başına sayfa, 512².
- **Önbellek:** `CachedNetworkImage` zaten var; disk önbelleği +
  liste görünümünde küçük boyut (`cacheWidth`).
- **Ölçüm:** gerçek cihazda `flutter run --profile` + DevTools.
  Koleksiyonda 100+ kart kaydırma, arena 60 FPS, bellek tavanı. **Bağlı
  cihaz olmadan ölçülemez** (önceki raporlarda da belirtildi).
- **Maliyet kalemleri:**
  - Metin < 10 $.
  - Görsel / 3B üretim: hizmete göre değişir; prototipte **1 karakterin
    gerçek maliyeti ölçülüp** 150'ye projekte edilir, karar sende.

---

## 12. Aşamalı geliştirme planı

| Aşama | Kapsam | Çıktı | Onay |
|---|---|---|---|
| **A0** | Kararlar (bölüm 14) | — | **Senden** |
| **A1** | Veri modeli (025) + ortak modeller + testler. Veri değişmez, sadece yeni tablolar. | Şema, testler, CI yeşil | — |
| **A2** | Acil hukuki temizlik: 6 Legend ve 7 lig adı için kurgu karşılık, sadece kimlik (güç aynı) | 026/027 taslağı | **Senden** (adlar) |
| **A3 — PROTOTİP** | **1 özgün karakter uçtan uca** (bölüm 13) | Çalışan demo + ölçümler | Prototip sonrası **senden** |
| A4 | İçerik hattı: Claude toplu üretim + doğrulayıcı + Denge Motoru + onay paneli | 150 karakter taslağı (metin) | **Senden** (her karakter) |
| A5 | Görsel üretimi (stil kılavuzu → 150 portre) | Onaylı portreler | **Senden** |
| A6 | Kart arayüzü + karakter detay + 10 ekranın uyarlanması | Ekranlar, golden görüntüler | — |
| A7 | 3B ölçeklendirme (prototip ölçümüne göre: tam 3B ya da sprite) | Arena | **Senden** |
| A8 | Katalog v2 yayını (tek işlem) | Canlı | **Senden** |

---

## 13. Prototip: bir karakter uçtan uca

**Hedef:** bir özgün karakterin kimliği, premium kartı, detay ekranı ve
**arenada gerçek iskelet animasyonu**, çalışan bir demo olarak.

| # | İş | Kim / ne ile | Doğrulama |
|---|---|---|---|
| P1 | 025 şeması + tek karakter kaydı (taslak katalogda; oyunda görünmez) | Ben | SQL testleri; mevcut 100 kart ve sahiplik dokunulmadı |
| P2 | Claude ile kimlik (yapılandırılmış JSON), doğrulayıcı, benzerlik denetimi | Ben (API anahtarı gerekir) | Şema ve kara liste testleri |
| P3 | Denge Motoru: yuvaya göre güç ve özellik | Ben | Birim testleri; sınırlar ve toplam bandı |
| P4 | Referans sayfası + portre (şeffaf) | **Harici görsel hizmeti ya da sanatçı (onay ve maliyet)** | Senin onayın |
| P5 | 3B model + rig + 5 klip: yürüyüş, koşu, müdahale, şut, galibiyet | **Harici 3B hizmeti / otomatik rig / animasyon kütüphanesi (onay ve maliyet)** ya da sanatçı | glTF doğrulama |
| P6 | Kart ve detay ekranı (portreyle) | Ben | Golden görüntüler, 320–412 px |
| P7 | Arena 3B katmanı (`flutter_scene` denemesi) + koreografi eşleyici + sprite yedeği | Ben | Birim (koreografi) + widget testleri |
| P8 | Gerçek cihazda FPS / bellek ölçümü | **Senin telefonun** | 60 FPS, < 150 MB |

**Benim yapamadıklarım** (dürüstçe): görsel/3B varlıkların kendisi (P4–P5)
harici bir hizmet ya da sanatçı gerektiriyor; gerçek cihaz ölçümü (P8) bir
telefon gerektiriyor. Bunlar hazır olmadan prototipin **kod tarafını**
(P1–P3, P6–P7) yer tutucu bir glTF modelle (lisansı uygun, açık kaynaklı
bir test karakteri) geliştirip test edebilirim. Yer tutucu model "özgün
karakter" olarak **sunulmaz**.

---

## 14. Onayını bekleyen kararlar

1. **Kurgu bölge mi, gerçek ülke mi?** Uyruk alanı kurgu bölgelere mi
   geçsin, gerçek ülkeler kalsın mı? (Ülke adları lisans gerektirmez.)
2. **6 Legend ve 7 lig adı** için kurgu karşılıklar: önce bunları
   üretip sana sunayım mı? (Yayından önce zorunlu olduğunu düşünüyorum.)
3. **Görsel ve 3B üretimi:** harici yapay zekâ hizmeti mi, sanatçı mı,
   karma mı? Bütçe sınırı?
4. **3B kütüphanesi:** `flutter_scene` (deneysel) denensin mi? Bağımlılık
   eklemek senin onayınla.
5. **Prototip karakteri:** hangi mevki? (Önerim: **forvet**; şut ve
   sevinç en gösterişli animasyonlar.)
6. **Claude API anahtarı:** içerik hattı için senin hesabın; anahtar sadece
   ortam değişkeninde tutulur.
