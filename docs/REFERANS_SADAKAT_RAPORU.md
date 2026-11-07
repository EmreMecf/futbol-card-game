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
| Kadro / formasyon | ⏳ FAZ 4 | yalnızca referans görüntüsü var |
| Maç hazırlığı + arena | ⏳ FAZ 5 | yalnızca referans görüntüsü var |
| Mağaza + paket açma | ⏳ FAZ 6 | yalnızca referans görüntüsü var |
| Ligler, liderlik, profil, görevler, maç sonucu | ⏳ FAZ 7 | yalnızca referans görüntüsü var |

**Önemli:** Kadro, mağaza ve maç ekranlarında da yeni kart artık
görünüyor, çünkü `PremiumPlayerCard` ortak karta bağlandı. Ama bu
ekranların düzeni henüz referansa geçirilmedi. Kullanıcının bildirdiği
taşmalar (mağazada 18 px, premium pakette 35 px, kadroda sahadan taşan
kartlar) **bu turda düzeltilmedi**; FAZ 4 ve FAZ 6'nın işi.

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

## 6. Sıradaki fazlar

| Faz | Kapsam | Referansta görülenler |
|---|---|---|
| FAZ 4 | Kadro | 353 px yükseklikte saha, 47×55 oyuncu kutuları (`.squad-slot`), formasyon karoları (yalnız 4-4-2 etkin olacak), TAKIM GÜCÜ / KİMYA / KADRO istatistikleri, kimya açıklaması, KADROYU KAYDET. Sahadan taşan kartlar düzeltilecek. |
| FAZ 5 | Arena | Perspektifli saha (`.pitch3d` rotateX 43°), mavi/kırmızı oyuncu noktaları, top, skor ve tur, SENİN KARTIN / RAKİP KARTI, enerji çubuğu, 3 taktik karosu, KARTI OYNA. Kart seçilince sahaya geçiş ve 2D karakter animasyonu (`DuelStage`). Sonucu sunucu belirler. |
| FAZ 6 | Mağaza | PAKETLER / TEKLİFLER / KOZMETİK sekmeleri, günün paketi, 3 paket karosu, paket açma modalı. Taşmalar giderilecek. Fiyat ve olasılıklar sunucudan gelecek. |
| FAZ 7 | Diğer ekranlar | Ligler (kupa yolu, 5 rozet, liderlik satırları), profil, maç sonucu (ZAFER!, skor, ödül kutuları), görevler |
| FAZ 8 | Bütün ekranlar | 6 boyutta golden, performans |
