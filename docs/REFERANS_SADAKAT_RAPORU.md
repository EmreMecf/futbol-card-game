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
| Mağaza + paket açma | ⏳ FAZ 6 | yalnızca referans görüntüsü var |
| Ligler, liderlik, profil, görevler, maç sonucu | ⏳ FAZ 7 | yalnızca referans görüntüsü var |

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

## 6. Sıradaki fazlar

| Faz | Kapsam | Referansta görülenler |
|---|---|---|
| FAZ 4 | Kadro | 353 px yükseklikte saha, 47×55 oyuncu kutuları (`.squad-slot`), formasyon karoları (yalnız 4-4-2 etkin olacak), TAKIM GÜCÜ / KİMYA / KADRO istatistikleri, kimya açıklaması, KADROYU KAYDET. Sahadan taşan kartlar düzeltilecek. |
| FAZ 5 | Arena | Perspektifli saha (`.pitch3d` rotateX 43°), mavi/kırmızı oyuncu noktaları, top, skor ve tur, SENİN KARTIN / RAKİP KARTI, enerji çubuğu, 3 taktik karosu, KARTI OYNA. Kart seçilince sahaya geçiş ve 2D karakter animasyonu (`DuelStage`). Sonucu sunucu belirler. |
| FAZ 6 | Mağaza | PAKETLER / TEKLİFLER / KOZMETİK sekmeleri, günün paketi, 3 paket karosu, paket açma modalı. Taşmalar giderilecek. Fiyat ve olasılıklar sunucudan gelecek. |
| FAZ 7 | Diğer ekranlar | Ligler (kupa yolu, 5 rozet, liderlik satırları), profil, maç sonucu (ZAFER!, skor, ödül kutuları), görevler |
| FAZ 8 | Bütün ekranlar | 6 boyutta golden, performans |
