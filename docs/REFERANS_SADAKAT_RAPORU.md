# Referans HTML → Flutter: Sadakat Raporu

**Referans:** `design-reference/futbol-card-arena.html` (onaylı tasarım,
kullanıcının dosyasının birebir kopyası).
**Tarih:** 7 Kasım 2026.
**Bu turda tamamlanan:**

- FAZ 1: token'lar, tipografi, gezinme ve ana sayfa
- FAZ 2: 2D karakter üretimi ve ortak kart
- FAZ 3: koleksiyon ve kart detayı

FAZ 4–8 henüz yapılmadı (bkz. "Sıradaki fazlar").

## 1. Yöntem

1. **Referans gerçekten açıldı.** HTML yerel sunucuda Chrome ile
   çalıştırıldı. Her ekran telefon boyutunda (390×844) dosyaya çizildi:
   `design-reference/ekranlar/390x844/`, 20 görüntü, 9 ekranın tamamı ve
   kaydırılmış altları. Araç: `python -I tool/tasarim/referans_cek.py
   [genişlik] [yükseklik]`.
   - Tasarım stüdyosu çerçevesi (telefon kasası, çentik, 25 px sahte durum
     çubuğu) çizimde gizlendi.
   - Stüdyonun kendi küçük pencere kuralları (`max-width:420px`)
     uygulanmadı. Böylece onaylı stüdyo telefonu nasıl görünüyorsa öyle
     çizildi.
2. **Değerler CSS'ten birebir alındı.** Kaynak `lib/core/theme/ref_tokens.dart`.
   Her rengin ve ölçünün hangi CSS seçicisinden geldiği yorumda yazıyor.
   Tahmini değer kullanılmadı. Örnekler:
   - `--bg #080e19`
   - `--accent #21dfaa`
   - `.cta` degradesi `#ffe9a8 → #f9c76b 45% → #ac6e20`, gölgesi
     `0 3px 0 #70400e`
   - `.collectible` 2 px çerçeve, 14 px köşe, `radial-gradient(circle at 55% 36%)`
3. **Flutter ekranları aynı mantıksal boyutta çizildi.** Golden testlerinde
   gerçek Barlow Condensed, Nunito, Material ikonları ve emoji yazı tipi
   kullanıldı. Kullanıcının istediği 6 boyutun hepsi var: 320×568,
   360×640, 390×844, 412×915, 768×1024, 1366×768. Kaynak:
   `test/goldens/ekranlar/`.
4. **Yan yana görüntüler.** `design-reference/karsilastirma/`: solda
   referans, sağda Flutter. Görüntüler tek tek gözle incelendi. Bulunan
   farklar düzeltildi, sonra testler yeniden çalıştırıldı.
5. **Gerçek uygulama kontrolü.** Web derlemesi yerel sunucuya bağlı olarak
   (test hesabı) 390×844'te açıldı. Ana sayfa, koleksiyon (103 kart) ve
   kart detayı gerçek veriyle çalıştı.

## 2. Ekran durumu

| Ekran | Durum | Karşılaştırma |
|---|---|---|
| Ana sayfa | ✅ Referansa geçirildi | `karsilastirma/01_ana_sayfa.png`, `01b_...alt` |
| Futbolcu kartı | ✅ Tek ortak bileşen | koleksiyon ve detay görüntüleri |
| Koleksiyon | ✅ Referansa geçirildi | `03_koleksiyon`, `03b_alt`, `03d_filtre` |
| Kart detayı | ✅ Referans modalı | `03c_kart_detay` |
| Gezinme (üst başlık + alt çubuk + masaüstü kenar çubuğu) | ✅ | bütün görüntülerde |
| Kadro / formasyon | ✅ FAZ 4 | `04_kadro`, `04b_kadro_alt`; golden'da kart seçimi `04c` |
| Maç hazırlığı + arena | ✅ FAZ 5 | `02_arena`, `02b_arena_alt`, `02d_duello_kareler` |
| Mağaza + paket açma | ✅ FAZ 6 | `05_magaza`, `05b_magaza_alt`, `05c_paket_acma`; golden'da mühür ve özet |
| Ligler + liderlik, lig basamakları | ✅ FAZ 7 | `06_ligler`, `06b_ligler_alt`; golden'da `06l_lig_basamaklari` |
| Profil | ✅ FAZ 7 | `07_profil`, `07b_profil_alt` |
| Maç sonucu | ✅ FAZ 7 | `08_mac_sonucu`; golden'da `08m_mac_sonucu_maglubiyet` |
| Görevler (kart görevleri) | ✅ FAZ 7 | referansta ayrı ekran yok; golden'da `10_gorevler`, `10s_gorev_sonucu` |

**Önemli:** Mağaza ve maç ekranlarında da yeni kart artık görünüyor,
çünkü `PremiumPlayerCard` ortak karta bağlandı. Ama bu ekranların düzeni
henüz referansa geçirilmedi. Kadroda sahadan taşan kartlar FAZ 4'te
düzeltildi. Mağazadaki 18 px ve premium paketteki 35 px taşma FAZ 6'nın
işi.

## FAZ 4 — Kadro (yapıldı)

- **Referans düzeni:**
  - `TAKIMIM` + "11 / 11" hapı
  - FORMASYON SEÇİMİ · KİMYA BONUSU AKTİF
  - 3 formasyon karosu
  - 353 px saha (362 px genişlikte; diğer genişliklerde orantılı)
  - 47×55 oyuncu kutuları (`.squad-slot`, altın-lacivert degrade, #e1bd63
    çerçeve)
  - TAKIM GÜCÜ / KİMYA / KADRO
  - Kimya paneli, KADROYU KAYDET
- **Konumlar** referanstaki `formations['4-4-2']` dizisinden birebir (x%, y%).
- **4-3-3 ve 3-5-2** referanstaki gibi görünür ama PASİF (`button:disabled`
  opaklığı). Oyunun aynı mevki kuralı 4-4-2'ye bağlı. Basılınca "Oyunda
  şimdilik yalnızca 4-4-2 geçerli" yazar.
- **Sahadan taşma düzeltildi.** Eski ekran sahaya tam kart (FIFA oranında)
  sığdırmaya çalışıyordu. Yeni ekranda referanstaki küçük kutular var ve
  saha genişlikle orantılı ölçekleniyor. Golden testi 6 boyutta her
  kutunun sahanın içinde kaldığını ÖLÇEREK denetliyor.
- **Referansta olmayan ama oyunda gerçek işlevler**, aynı bileşen diliyle:
  - Kimya çizgileri (kutuların altında)
  - Kart başına kimya rozeti
  - Basılı tut → bağlar vurgulanır
  - Sürükle-bırak (yalnızca aynı mevki)
  - Otomatik dizme (3 nötr düğme)
  - Eksik mevki uyarısı
  - Kaydedilmemiş değişiklikle çıkış onayı
- **Kart seçme penceresi** referans modal diliyle. Kartlar ortak kart
  bileşeninden, her birinin yanında "bu yuvaya konursa kimya" rozeti.
- **Referanstan bilinçli farklar:**
  - Mevki ST yerine FWD.
  - Kimya açıklaması oyunun gerçek kuralını yazıyor.
  - Güçlü / Orta / Zayıf haplarında gerçek bağ sayıları var.
  - Kimya paneline otomatik dizme düğmeleri eklendi.
  - Değişiklik yokken kaydet düğmesi "KADRO GÜNCEL" yazar ve pasiftir.
- **Oyun mantığı (DeckViewModel) değişmedi.** Sürükle-bırak testleri yeni
  kutularla yine geçiyor: aynı mevki kuralı arayüzden de korunuyor.

## 3. Bilinçli farklar (referanstan sapılan yerler ve sebepleri)

| Referansta | Flutter'da | Sebep |
|---|---|---|
| 💎 120 elmas | Gösterilmiyor | Oyunda elmas para birimi yok. Sahte sayı gösterilmez. |
| Günlük görevler, "2/3 · 150 altın" | "YAKINDA" + kart görevlerine düğme | Sunucuda günlük görev yok. Kart görevleri (SBC) gerçek. |
| "Sezon ödülü · 11 gün kaldı" | "Lig ilerlemesi" (aynı kart düzeni) | Sezon sistemi yok. Gerçek lig ilerlemesi gösteriliyor. |
| "ÖDÜLLER · 1 paket" karosu | "PAKETLER · Mağaza" | Bedava paket envanteri yok. |
| ALTIN LİG III, 🏆 1.825, 4 galibiyet serisi | Oyuncunun gerçek ligi, puanı ve serisi | Referans sayıları örnek. Seri 0 ise hap gösterilmez. |
| Mevki ST / LW | FWD / MID / DEF / GK | Oyunun gerçek mevki kodları |
| Kart detayında KİMYA | NADİRLİK, ayrıca 6 özellik, kulüp, kilit ve Efsane kuralı | Kartın kendine ait kimya değeri yok (kimya maçta hesaplanır). Özellikler gerçek veri. |
| Filtre satırı | Referans satırı birebir, altında 2. satır: Bronz, Gümüş, Altın, Elmas, Favoriler | Kullanıcı nadirlik filtresi ve favori gösterimi istedi. |
| Kart yüzü emoji | Karaktere özel 2D yüz (kodla çizilir) | Kullanıcının onayladığı 2D stil değişikliği |
| 🪙 altın simgesi | Çizilmiş altın sikke | 🪙 emojisi Windows'ta bile kutu olarak çiziliyor (referans görüntüsünde de kutu). |
| ⌂ ▣ ♟ ⚔ ▤ ☻ ✦ ▶ → | Vektörle çizilmiş aynı şekiller | Oyunun yazı tiplerinde yok; Android ve web'de kutu görünürdü. |
| Telefon kasası | Çizilmiyor | Kullanıcının kuralı: kasa yalnızca önizleme aracı. |

**Platform farkı:** Renkli emojiler (🏆 🛡️ 🃏 🎁 🎯) her işletim sisteminin
kendi emoji çizimiyle görünür. Referans Windows'un Segoe emojisiyle çizildi;
Android ve web Noto emojisini kullanır (örneğin kalkan kırmızı-beyaz yerine
gri-mavi). Bu bir hata değil, platform özelliği. Birebir aynı görünmesi
istenirse emojiler yerine uygulamaya gömülü görseller kullanılmalı (karar
bekliyor).

## 4. Kart sistemi (FAZ 2)

- **`RefPlayerCard`** (`lib/shared/widgets/ref_card/`): referans `.collectible`.
  - İki ölçü: ızgara (176,5 × 188) ve açılış/detay (205 × 295).
  - Bütün ölçüler genişlikle orantılı.
  - Uzun ad kesilmez, sığmazsa küçülür.
- **`PremiumPlayerCard`** artık bunun sarmalayıcısı. Maç eli, kadro, paket
  ve koleksiyon aynı karttan çizilir.
- **Yüz:** `AvatarSpec.generate(cardId, kitSeed: kulüp)` deterministik.
  - Aynı kart her cihazda aynı yüzü alır.
  - Aynı kulübün oyuncuları aynı formayı giyer.
  - Onaylı bir görsel (http/https) varsa o gösterilir.
  - Jenerik siluet artık hiç çizilmiyor.
- **Nadirlik renkleri:** referanstaki `--rarity` ve `--halo` değerleri
  birebir. Kullanıcının tarif ettiği ek efektler:
  - Altın: hafif parıltı
  - Elmas: soluk kristal çizgiler ve parıltı
  - Efsane: mor-altın, yavaşça dönen çerçeve ışığı
  - Listelerde yalnız Efsane ışığı döner (performans).
- **Hareket:**
  - Karta gelince 3 px yükselme ve %13 parlama, 180 ms (`.collectible:hover`)
  - Detay kartında "pop", 550 ms, `cubic-bezier(.18,1.4,.3,1)`
  - "Kart animasyonları" ayarı kapalıysa pop beklemeden görünür, yüz
    gölgesindeki bulanıklık çizilmez (düşük performans).

## 5. Testler

- `flutter analyze`: sorun yok.
- `flutter test`: 470 testin tamamı geçti. Bunlara 17 yeni golden testi
  dahil:
  - Ana sayfa ve koleksiyon × 6 boyut
  - Kaydırılmış alt görünümler
  - Efsane filtresi
  - Kart detayı (390 ve 320)

  Golden testleri ayrıca **taşma olmadığını** da denetliyor.
- Eski kart testleri yeni tasarıma göre güncellendi:
  - Ad büyük harfe çevrilmiyor.
  - Mevki kodu gösteriliyor.
  - Özellik ızgarası kartta değil, detayda.
  - Siluet yerine 2D yüz çiziliyor.
- **Golden testleri sadece Windows'ta çalışır.** Emoji yazı tipi CI'da
  (Ubuntu) yok. Orada sebebi yazılarak *atlanır*; "geçti" sayılmaz.

## FAZ 5 — Maç hazırlığı ve animasyonlu arena (yapıldı)

**Maç ekranı:** referans `arena()` düzeni, sırasıyla:

1. "⚔ DERECELİ KARŞILAŞMA / CANLI ARENA" başlığı ve TUR hapı
2. `.arena-stage`: SEN · skor · RAKİP başlığı, altında perspektifli stadyum
3. SENİN KARTIN – VS – RAKİP KARTI
4. TAKTİK ENERJİSİ çubuğu ve 3 taktik karosu
5. Durum satırı
6. TAKTİĞİ SIFIRLA / ⚔ KARTI OYNA

**Stadyum (`RefStadium`):**

- CSS değerleri birebir: `rotateX(43°) rotateZ(-8°)`, perspective 430, 230 px
  yükseklik.
- İki projektör, mavi ve kırmızı oyuncu noktaları (7-9-3 / 4-8-6).
- Top ±13/±4 px, 1,7 sn salınır (`@keyframes bob`).
- Tur çözülünce şut animasyonu (`@keyframes shot`, 0,65 sn) ve sahada
  parlama.
- Flutter'da X ekseni dönüş işareti CSS'in tersi; ilk denemede saha ters
  eğilmişti, yan yana karşılaştırmada fark edilip düzeltildi.

**Kart seçilince:**

- Elindeki kart 240 ms'de %8 büyür ve yeşil seçim ışığı alır.
- SENİN KARTIN panelinde yüz ve gerçek güç (güç + kimya) görünür.
- Durum satırı güç dökümünü yazar.

**Tur sonucu (sunucudan gelir):**

- Kartlar sahaya uçar, yan döner, 2D karakterler nadirlik ışığıyla belirir.
- Mevkiye uygun kısa düello oynanır.
- Sunucunun sonucu bant olarak çıkar (başlık, güç - güç, taktik ya da
  Efsane açıklaması); kazanan taraf spot ışığı alır, skor "pop" ile
  değişir (600 ms).
- Sahne süresi maç hızında (1,8×) 3,2 saniyenin altında. Kartın sahaya
  girişi yaklaşık 530 ms.
- Dokununca sonuca atlar, ikinci dokunuş kapatır.
- "Kart animasyonları" ayarı kapalıysa düello hiç oynamaz; yalnızca kısa
  sonuç bandı çıkar.
- Sonucu animasyon hesaplamaz. `ClashEvent` sunucunun tur kaydından
  oluşur.

**Referanstan bilinçli farklar:**

- **Elindeki kartlar şeridi eklendi.** Referansta el yok, ama kullanıcının
  listesinde var ve oyunda gerekli.
- **Hamle süresi hapı eklendi.** Oyunda tur süresi gerçek.
- **Mevkiye uymayan kartlar soluk görünür.** Aynı mevki kuralı arayüzde de
  görünsün diye.
- **"Taktik Yok / Kontrollü Oyun" yerine oyunun gerçek taktikleri:**
  Yüksek Pres 3, Kontra Atak 2, Savunma Duvarı 1 enerji. Enerji en fazla 5
  (referansta 10).
- **Masadaki biriken kart hapı eklendi** (beraberlikten).
- **Taktik rozeti:** rakibin taktiği tur çözülene kadar "TAKTİK ?" görünür.
- **Teslim ol bağlantısı eklendi.**
- **Masaüstünde tur geçmişi paneli var.**
- **Maç sırasında alt gezinme çubuğu yok, üst başlık kilitli.** Maçtan kaçış
  yalnızca teslim olarak (önceki kural). Referans arena ekranında alt
  çubuk görünür.
- **Düello maçta ortalanmış yatay bir panelde oynar** (`DuelStageFrame`).
  Dikey telefonda tam ekran açıldığında figürler fazla büyüyüp üst üste
  biniyordu.
- **Rakip kartının yüzü:** sunucu rakip hamlesinde kartın kalıcı kimliğini
  (`cardId`) göndermiyor. Rakip kartının yüzü maç içinde tutarlı, ama
  rakibin kendi koleksiyonundaki yüzle aynı olmayabilir. Benim kartlarım
  koleksiyondakiyle birebir aynı.

**Maç hazırlığı ("Arena" sekmesi):**

- Referansta ayrı bir ekran yok. Arena ekranının dili kullanıldı: başlık,
  stadyum ("KADRO HAZIR!"), kadro durumu paneli, KARTLARINI KORU ve ortak
  kart ızgarası, altın "⚔ RAKİP BUL ▶".
- Ararken stadyumda "RAKİP ARANIYOR...", süre hapı ve ARAMAYI İPTAL ET.
- Arama sürerken gezinme gizlenir, böylece oyuncu kuyrukta unutulmaz.

**Mantık değişmedi.** MatchViewModel'e yalnızca kullanıcı adını okuyan bir
getter eklendi (skor başlığındaki "SEN" altı için).

**Testler:**

- Maç ve maç hazırlığı 6 boyutta golden testinden geçiyor.
- Ayrıca: kart ve taktik seçilmiş durum, düellodan 6 kare, dokununca
  atlama testi.
- Eski taşma testleri (7 boyut, yazı %130 dahil) geçiyor.
- %130 yazıda başlıkta 17 px taşma bulundu ve düzeltildi.

**Gerçek uygulama kontrolü:** Maç hazırlığı, yerel sunucuya bağlı web
derlemesinde test hesabının gerçek kadrosuyla (11 kart) açıldı.

Web'e özgü bir not: emojiler ilk açılışta birkaç saniye kutu olarak
göründü, ardından düzeldi. CanvasKit, Noto emoji yazı tipini ilk
kullanımda internetten indiriyor. Android'de sistem emojisi olduğu için bu
gecikme yok. Web'de de anında görünmesi istenirse emoji yazı tipi
uygulamaya gömülebilir (boyut artar; karar bekliyor).

**Sınır:** Canlı bir maç, iki gerçek oyuncu gerektirdiği için tarayıcıda
baştan sona oynanmadı. Maç ekranı, sunucu biçimindeki verilerle (golden ve
davranış testleri) doğrulandı. Sunucu tarafındaki maç akışı testleri
(uçtan uca maç) bu fazda değişmedi.

## FAZ 6 — Mağaza ve paket açma (yapıldı)

### Taşma hatası

Test ortamında yeniden üretildi:

- **Ne oluyordu:** eski mağaza 1366 ve 1440 px genişlikte alttan 60–85 px
  taşıyordu ("BOTTOM OVERFLOWED").
- **Sebep:** masaüstü ızgarasında her paket sabit 420 px yükseklikteki
  kutuya sığdırılıyordu. Açıklaması ve oranı uzun paketler sığmıyordu.
  Kullanıcının gördüğü 18 ve 35 px aynı hatanın farklı pencere
  boyutlarıydı.
- **Çözüm:** yeni yerleşimde hiçbir pakete sabit yükseklik verilmiyor.
  Karolar satırdaki en uzun içerik kadar uzuyor (`IntrinsicHeight`).
- **Doğrulama:** golden testi 6 boyutta ve ayrıca 1440×900'de taşma
  olmadığını denetliyor.

### Mağaza

Referans `shop()` düzeni:

1. "MAĞAZA" başlığı ve altın bakiyesi
2. Sekmeler: PAKETLER, TEKLİFLER, KOZMETİK
3. Öne çıkan paket paneli (`.shop-feature`: altın çerçeve, radyal ışık,
   94 px paket simgesi, altın CTA)
4. KART PAKETLERİ karoları (`.shopgrid`)
5. Görev ödülleri paneli ve not

**Gerçek veriler:**

- Paket adları, açıklamaları, kart sayıları, fiyatlar ve nadirlik oranları
  sunucudan gelir (`pack_types`).
- Testler yerel veritabanındaki gerçek değerlerle yapıldı:
  - Standart: 500 altın, Bronz %55 … Efsane %0,1
  - Premium: 2.500 altın, … Efsane %1
  - Kadro: 4.000 altın, tam 4-4-2 garantili
- Öne çıkan paket veriden türetilir: Efsane ihtimali en yüksek satılık
  paket.

**Referanstan bilinçli farklar:**

- **Karoya dokunmak paketi yalnızca SEÇER.** Satın alma öne çıkan paneldeki
  CTA ile yapılır. Referansta karoya dokunmak doğrudan satın alıyordu; bu
  yanlışlıkla altın harcatabilirdi.
- **Altın yetmiyorsa CTA pasif** ve "YETERSİZ ALTIN" yazar.
- **"PAKET KARŞILAŞTIRMA" tablosu eklendi.** Kullanıcı karşılaştırma ve
  doğru oran bilgisi istedi; tabloda her paketin kart sayısı, fiyatı ve 5
  nadirliğin yüzdesi var.
- **Referanstaki "💎 elmas" ve "1 BEDAVA PAKET" yok.** Oyunda karşılığı yok.
  Yerine altın bakiyesi gösteriliyor.
- **TEKLİFLER ve KOZMETİK sekmeleri görünür ama "yakında".** Basınca
  açıklama çıkar; sahte içerik yok.
- **"HEDİYE PAKETLERİN" yerine "GÖREV ÖDÜLLERİ" paneli.** Gerçek kart
  görevlerine götürür; oyunda hediye paketi envanteri yok.
- **Referanstaki "fiyatlar örnek" notunun yerine gerçek bilgi:** çekiliş
  sunucuda yapılır, oranlar uygulanan değerlerdir.
- **Paket simgeleri referanstaki emojiler:** 📦 Standart, 💠 Premium,
  🎴 Kadro. Geliştirme test paketleri 🧪.

### Paket açma

Akış korundu, görünüm referans diline geçti.

1. **Mühürlü paket:** dokun → aç. "Hepsini göster" ile atlanır.
2. **Her kart için referans "✦ YENİ KART KEŞFEDİLDİ ✦" penceresi:**
   - İlerleme hapı (1/5) ve kart
   - Kart dönme animasyonu korundu: Bronz/Gümüş hızlı, Altın parlamalı.
   - "TEBRİKLER!" yalnızca Altın ve üstü kartlarda; düşük kartta kartın
     adı yazar.
   - Altında "Kart koleksiyonuna eklendi." ve SIRADAKİ KART / Hepsini göster.
3. **Elmas ve Efsane:** mevcut tam ekran "walkout" sahnesi aynen kalıyor
   (paket başına bir kez).
4. **Özet:** "✦ PAKET AÇILDI ✦", paket adı, en iyi kart (açılış ölçüsü),
   nadirlik renginde sayaçlar ve diğer kartlar.
   - Kartlar ortak ızgara kartı; eski 0.66 oranlı hücreler yerine referans
     oranı kullanılıyor.
   - Altta "N kart koleksiyonuna eklendi · kalan X altın", "KOLEKSİYONA
     GİT" ve "MAĞAZAYA DÖN".

**Paket içeriği her zaman sunucuda belirlenir.** Uygulama yalnızca
`PackOpenResult`'ı gösterir.

### Bulunup düzeltilenler

- **Çok büyük gölge bulanıklığı** (90 px) sert kenarlı siyah dikdörtgen
  olarak çiziliyordu. 40 px'e indirildi; kart detayı penceresi de
  düzeltildi.
- **Oran hapları** ağırlığa göre (Gümüş, Altın, Bronz…) diziliyordu. Artık
  nadirlik sırasıyla.

### Testler

- Mağaza 6 boyutta ve 1440×900'de taşma denetimiyle golden testinden
  geçiyor.
- Ayrıca:
  - Karoya dokunmak satın almıyor
  - Yetersiz altın
  - Paket açılışı (mühür → kart → özet) 390 ve 320 px'te, her adımda
    taşma yok
- `pack_flow_test` yeni metinlere göre güncellendi: "altın", "MAĞAZAYA
  DÖN".

## FAZ 7 — Ligler, profil, görevler, maç sonucu (yapıldı)

### Ligler ve liderlik
- Üst kart referanstaki kupa yolu kartı: büyük başlık, 🏆, oyuncunun
  **gerçek** ligi ve puanı, ilerleme çubuğu ve "N puan sonra …" satırı.
- "LİG KADEMELERİ": referansta 5 rozet (Bronz…Efsane) var, oyunda ise
  4 lig var (Amatör, Usta, Master, Master Class). 4 rozet gösteriliyor;
  oyuncunun ligi halkayla vurgulanıyor.
- Liderlik satırları referanstaki gibi: 🥇🥈🥉 ya da sıra numarası, ad,
  🏆 puan. Oyuncu listede değilse altta ayrı "Sen" satırı var.
- "Tüm basamaklar" düğmesi lig basamakları ekranını açıyor: her lig bir
  panel, 3 seviye kutusu, oyuncunun seviyesi vurgulu ("BURADASIN").
  Değerler veritabanından.

### Profil
- Referanstaki emoji yüz yerine oyuncunun kodla çizilen 2D yüzü.
- 6 gerçek istatistik kutusu: kazanılan maç, kazanma oranı, puan, altın,
  koruma, maç.
- Başarımlar referanstaki 3 sütunlu karo düzeninde. Gerçek sayaçlardan
  hesaplanıyor, kilitli olanlarda ilerleme çubuğu var.
- Favori kartlar (referansta tek "Favori futbolcu" satırı), son maçlar,
  LİG SIRALAMASINI GÖR ve AYARLAR düğmeleri.

### Maç sonucu
- Referanstaki altın çerçeveli panel: MAÇ SONUCU, 92 px 🏆, ZAFER!,
  büyük skor, ödül kutuları, YENİ MAÇ, ANA MENÜYE DÖN.
- Yenilgide 🛡️ ve kırmızı "MÜCADELE BİTTİ", beraberlikte 🤝.
- Ödül kutuları yalnızca sunucudan gelen gerçek değişimi gösteriyor
  (altın, puan, koruma). Referanstaki "+500 XP" gösterilmiyor; oyunda XP
  yok.
- Kazanılan veya kaptırılan kartlar, lig değişikliği paneli ve konfeti
  korunuyor.

### Görevler
- Referansta ayrı görev ekranı yok. Ana sayfadaki "GÜNLÜK GÖREVLER"
  panelinin dili kullanıldı: 🎯 ya da ✅, başlık, şart etiketleri,
  🎁 ödül, GÖREVE BAŞLA.
- Görev kadrosu ekranı kadro ekranının sahasını kullanıyor.
- Kartları eritmeden önce onay isteniyor. Bu işlem geri alınamaz.

### Bulunup düzeltilenler (yalnızca test verisi)
- Test liderlik listesinin 1. sırası test kullanıcısıyla aynı kimliği
  taşıyordu; ekran onu "(sen)" diye işaretledi. Kimlikler ayrıldı.
- Test rütbesi ("Usta 3, 1.825") veritabanındaki basamaklarla
  uyuşmuyordu; doğrusu Master 2. Düzeltildi; ana sayfa, ligler ve profil
  artık aynı ligi gösteriyor.
- Test maç geçmişinde rakip adı ve skor yoktu. Eklendi; galibiyet serisi
  aynı kaldı.

### Testler
- 7 ekran × 6 boyut = 42 golden testi + 2 kaydırılmış görüntü. Hepsinde
  taşma denetimi var.
- Ekranlar: ligler, lig basamakları, profil, maç sonucu (zafer ve
  yenilgi), görevler, görev sonucu.
- Tüm test paketi: 549/549 geçti. Yerel sunucu açıktı, API testleri de
  koştu.

### Hâlâ eski renklerde (FAZ 8'e kaldı)
- Ayarlar ekranı
- Tasarım sistemi sayfası
- Lig atlama/düşme paneli ve tam ekran kutlaması
  (`league_change_widgets.dart`)
- Kart kazanma gösterisi (`walkout_screen`)

## 6. Sıradaki fazlar

| Faz | Kapsam | Referansta görülenler |
|---|---|---|
| FAZ 4 | Kadro | 353 px yükseklikte saha, 47×55 oyuncu kutuları (`.squad-slot`), formasyon karoları (yalnız 4-4-2 etkin olacak), TAKIM GÜCÜ / KİMYA / KADRO istatistikleri, kimya açıklaması, KADROYU KAYDET. Sahadan taşan kartlar düzeltilecek. |
| FAZ 5 | Arena | Perspektifli saha (`.pitch3d` rotateX 43°), mavi/kırmızı oyuncu noktaları, top, skor ve tur, SENİN KARTIN / RAKİP KARTI, enerji çubuğu, 3 taktik karosu, KARTI OYNA. Kart seçilince sahaya geçiş ve 2D karakter animasyonu (`DuelStage`). Sonucu sunucu belirler. |
| FAZ 6 | Mağaza | PAKETLER / TEKLİFLER / KOZMETİK sekmeleri, günün paketi, 3 paket karosu, paket açma modalı. Taşmalar giderilecek. Fiyat ve olasılıklar sunucudan gelecek. |
| FAZ 7 | ✅ Yapıldı | Ligler, lig basamakları, profil, maç sonucu, görevler |
| FAZ 8 | Bütün ekranlar | 6 boyutta golden, performans; eski renklerde kalan ekranlar (ayarlar, lig değişikliği paneli, walkout, tasarım sistemi) |

## FAZ 8 — Tek palet, kalan ekranlar, performans (yapıldı)

- `AppColors` değerleri referans paletine (`Ref`) bağlandı; eski adları kullanan bütün ekranlar aynı renklere geçti. Kontrast: metin/zemin 17,61; muted/panel 7,07; accent/panel 10,41; red/panel 5,87; yeşil üstünde koyu yazı 11,22.
- Tema: giriş alanı (.search), pencere (.modal), alt pencere, bildirim, anahtar (switch) referans renklerinde.
- `GameButton`, `GlassPanel`, `GameLogo` referans görünümünde. Giriş, kayıt ve ayarlar ekranları referans dilinde.
- Lig rozeti her yerde aynı (🛡️ Amatör, 🥈 Usta, 🥇 Master, 👑 Master Class); bilinmeyen lig için eski kalkan yedekte.
- "Diamond/Legend" → "Elmas/Efsane" (walkout dahil); büyük harfler Türkçe kurala göre (`toUpperTr`).
- Nötr buton 47 → 49 px (en az 48 px parmak hedefi).
- Yeni testler: `faz8_golden_test` (giriş, kayıt, ayarlar, lig atlama, lig paneli, walkout × 6 boyut) ve `faz8_performans_test` (13 ekran).
  - Animasyonlar kapalıyken 13 ekranın hepsi boşta 0 animasyon.
  - Açıkken yalnız koleksiyon (Efsane kart ışığı), maç hazırlığı ve arena (stadyum salınımı) çizer.
  - %130 yazı + 320×568: 13 ekranda taşma yok.
- Web yayın derlemesi başarılı; main.dart.js 3,96 MB (sıkıştırmasız).
- Açık soru: 🥈 emojisinin içinde "2" yazıyor; lig atlama ekranında yanında "Usta 1" rozeti var.
