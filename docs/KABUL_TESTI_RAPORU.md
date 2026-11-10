# Son Görsel Kalite ve Kabul Testi (gerçek uygulama)

Tarih: 10 Kasım 2026. Bu rapor **golden testlerini değil**, gerçek
sunucuya bağlı çalışan Flutter Web uygulamasını anlatır.

## Nasıl yapıldı

- **Sunucu:** yerel PostgreSQL + Dart sunucusu (8080), gerçek hesap
  (`testoyuncu`, 118+ kart).
- **Uygulama:** `flutter build web --profile`. Yayın (release) derlemesi
  bilerek https dışındaki adresleri reddediyor; bu güvenlik kuralına
  dokunulmadı. Profile modunun performansı yayına çok yakın.
- **Ekran görüntüleri:** Chrome, DevTools protokolüyle sürüldü
  (`tool/tasarim/cdp.mjs`). Pencere 390×844, piksel oranı 1, yani
  referans görüntüleriyle aynı çözünürlük. Masaüstü tarayıcı paneli
  kullanılmadı, çünkü görüntüyü küçültüyor.
- **Yan yana görüntüler:** `design-reference/karsilastirma_gercek/`
  (solda referans HTML, sağda gerçek uygulama). Hepsinin küçük hali:
  `design-reference/gercek/genel_bakis.png`.

Betikler:

| Betik | Ne yapar |
|---|---|
| `tool/tasarim/gercek_cek.mjs` | Bütün ekranlar + boşta/kaydırma FPS |
| `tool/tasarim/fps_olc.mjs` | Görünür Chrome'da, ekran kartıyla FPS |
| `tool/tasarim/pvp_sunucu.mjs` + `komut.mjs` | A oyuncusunun açık sekmesi ve adım adım komutlar |
| `tool/tasarim/rakip_bot.mjs` | B oyuncusu (gerçek API, yasal hamle) |

## Sonuçlar

### 1–5. Ekranlar ve referans karşılaştırması

Ana sayfa, koleksiyon (+alt, filtre, kart detayı), kadro (+alt, kart
seçme), maç hazırlığı, canlı arena, maç sonucu, mağaza (+alt, paket
açma, walkout, özet), görevler, profil, ligler/liderlik ve ayarlar
gerçek veriyle açıldı. Yan yana görüntüleri `karsilastirma_gercek/`
klasöründe.

**Bu denetimde bulunup düzeltilenler** (golden testlerinde
görünmüyordu):

| Önem | Sorun | Çözüm |
|---|---|---|
| Yüksek | Rakip kartın 2D yüzü maçta koleksiyondakinden farklıydı. Hamle verisinde kart kimliği yoktu, yüz ada göre üretiliyordu. Oynanıp elden çıkan kendi kartında da aynı sorun vardı. | Sunucu hamleyle `card_id`, `club`, `nationality` gönderiyor (yalnız görsel kimlik, kural hesabı aynı). İstemci yüzü `kartId + (kulüp ?? uyruk)` kuralıyla üretiyor. Test: `test/yuz_kimligi_test.dart` |
| Yüksek | Koleksiyon boştayken 39 FPS (Efsane kart ışığı her karede bütün kartı yeniden çizdiriyordu) | Hareketli çerçeve ayrı katmanda; ressam animasyona doğrudan bağlı |
| Yüksek | Maç hazırlığı 30–43 FPS (her karede bütün stadyum yeniden kuruluyordu, oysa hareket eden yalnız top) | Durağan stadyum ayrı katmanda; renk filtresi yalnız şut anında |
| Orta | Profilde avatar ve isim sola kaymıştı (referansta ortada) | `RefHero` içeriği tam genişliğe yayılıyor |
| Orta | "Sayfa bulunamadi" ekranı Türkçe karakter kullanmıyordu, eski görünümdeydi ve geri dönüş yolu yoktu | Referans dilinde boş durum + "ANA SAYFAYA DÖN" |

**Kalan farklar** (önem sırasıyla):

1. **Emoji çizimi:** web'de Google Noto, referansta Windows Segoe emojisi.
   Örneğin ana sayfadaki kalkan referansta kırmızı-beyaz, uygulamada
   gri. Bu tarayıcı ve platform farkı; Android'de de Noto kullanılır.
   Uygulamaya ayrı bir emoji yazı tipi gömmek gerekir (yaklaşık 10 MB),
   bu yüzden yapılmadı.
2. **Canlı maç ve maç sonucu ekranlarında alt gezinme çubuğu yok**
   (referansta var). Bilinçli: maçtan çıkmak hükmen yenilgi sayılıyor.
3. **Referanstaki örnek sayılar ve sistemler gösterilmiyor:** 💎 elmas,
   günlük görevler, sezon ödülü, +500 XP. Oyunda bunlar yok; sahte sayı
   gösterilmez (bkz. `REFERANS_SADAKAT_RAPORU.md`).
4. **Veri kirliliği:**
   - Liderlik tablosu entegrasyon testlerinin bıraktığı onlarca
     `test_xxxxx` hesabıyla dolu.
   - Mağazada veritabanındaki "[TEST] LEGEND/DIAMOND" paketleri
     İngilizce adla görünüyor.
   - Bunlar yerel geliştirme verisi. Kullanıcı verisi silinmedi; temizlik
     senin kararın.
5. **Kart detayı** referanstan büyük (6 özellik, kulüp, Efsane kuralı,
   favori). Gerçek verinin gösterilmesi için bilinçli.

### 6–7. Yüz kimliği

Aynı futbolcu her yerde aynı yüzle göründü:

- **Pele:** koleksiyon, kadro kart seçimi, maç hazırlığı, maçta
  "SENİN KARTIN", paket açılışında walkout ve özet ekranı.
- **Maradona:** koleksiyon, kart detayı, maç.

Rakip tarafında, oynanan gerçek maçın hamle verisinde artık kart
kimliği geliyor (API'den doğrulandı): Luca Conti, Rotterdam FC, ITA.

### 8. Gerçek veriyle akışlar

- **Koleksiyon:** 118+ kart, "Efsane" filtresi, kart detayı.
- **Kadro kart seçimi:** FORVET SEÇ, 30 kart, kimya rozetleri.
- **Paket açma:** gerçek "[TEST] Legend Paketi" açıldı. Sıra: mühür →
  5 kart (Bronz, Gümüş, Gümüş, Altın "TEBRİKLER!", Efsane Pele) →
  walkout (FWD·FORVET → konfeti + "EFSANE") → özet ("5 kart
  koleksiyona eklendi · kalan 1.100 altın").
- **Maç hazırlığı:** "En iyileri koru" ile 3 kart (99, 98, 97) korumaya
  alındı, "RAKİP BUL" çalıştı.

### 9. Tam PvP maçı (iki test hesabı)

- **A** (`testoyuncu`) arayüzden oynadı. 1. turda kart seçip "KARTI
  OYNA"ya bastı. Sonraki turlarda hamleler aynı kurallı mantıkla
  API'den yapıldı, A'nın arayüzü açık kalıp her turu canlı gösterdi.
- **B** (`rakip_7737a2`, yeni yerel test hesabı, bilgileri git dışındaki
  `test-hesabi-2.local.txt` dosyasında) gerçek API'yle yasal hamle
  yaptı.
- **Sonuç:** 11 tur, A 22–0 kazandı. Skor iki tarafta tutarlı.
- **Arayüzde doğrulananlar:** "Rakip düşünüyor…", 2D düello sahnesi,
  "ELİ KAZANDIN! 92–75", skor ve tur sayacı, ZAFER! ekranı, ödüller
  (+100 altın, +25 puan, +1 koruma), lig paneli (1000 → 1025), kazanılan
  3 kart.
- **Hesaba yansıyanlar:** sonrasında altın 1.000 → 1.100, profilde
  1 galibiyet, %100, koruma 4/10.
- **Kare dizileri:** `gercek/pvp/07_tur1_seri.png` ve
  `gercek/pvp/08_mac_seri.png`. Hamle kayıtları: `pvp/a_kaydi.txt` ve
  `pvp/bot_kaydi.txt`.
- **Not:** Kurallar gereği B'nin 3 kartı A'ya geçti. İkisi de yerel test
  hesabı.

### 10. Performans ve okunabilirlik (Windows Chrome)

**Ekran kartıyla** (görünür Chrome, Intel HD 530, ilk düzeltme sonrası):

| Ekran | Önce | Sonra |
|---|---|---|
| Koleksiyon boşta | 39 | 52 |
| Koleksiyon kaydırma | 43 | 50 |
| Maç hazırlığı | 43 | 52 |
| Ana sayfa / kadro / mağaza | 60 | 60 |

**Headless Chrome** (son derleme): bütün ekranlar boşta 60 FPS,
koleksiyonda kaydırma 52 FPS (önce 35–38).

- 60'a tam ulaşılamayan yerlerin sebebi: tarayıcı (CanvasKit), ekranda
  bir animasyon varken bütün gölge ve bulanıklık katmanlarını her
  karede yeniden birleştiriyor. Bu eski, entegre bir ekran kartı.
  Ayarlardan "Kart animasyonları" kapatılınca ekranlar tamamen duruyor
  (otomatik test `faz8_performans_test`).
- **Taşma ve okunabilirlik:** gerçek uygulamada konsolda taşma ya da
  hata yok. %130 yazı + 320 px testi 13 ekranda geçiyor.
- Not: ilk çekimde profil bir kez beyaz kaldı ("Uncaught" hatası,
  ayrıntısız). Sonraki 3 çekimde tekrar etmedi. Muhtemelen headless
  yazılım çiziminde WebGL bağlantısının kaybolması; gerçek ekran
  kartıyla görülmedi.

## Yapılamayanlar

- **Gerçek Android cihaz:** bilgisayara bağlı Android cihaz ya da
  emülatör yok (`flutter devices` yalnızca Windows/Chrome/Edge
  gösteriyor). Android'de FPS ve dokunma testi yapılmadı.
- **A'nın 11 turun hepsini arayüzden oynaması:** yalnız 1. tur
  arayüzden. Kalan turlar API'den oynandı, arayüz izlendi.
- **Eksik karakter uyarısı:** konsolda bir kez "eksik karakterler için
  Noto yazı tipi bulunamadı" uyarısı görüldü. Ekran görüntülerinde kutu
  (□) görünmedi; hangi karakter olduğu bulunamadı.
