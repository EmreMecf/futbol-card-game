# Premium Kart Widget'ları

FIFA / EA FC Ultimate Team seviyesinde futbolcu kartı.

## Kullanım

```dart
PremiumPlayerCard.fromInventory(kart, width: 200)
```

```dart
PremiumPlayerCard.fromHand(elKarti, width: 140, onTap: () => oyna(kart))
```

---

## Katman mimarisi

Bir kart 7 katmandan oluşur. Sıra önemli — her katman altındakini tamamlar:

| # | Katman | Dosya | Ne yapar |
|---|---|---|---|
| 1 | Dış ışık | `premium_player_card.dart` | Seviyeye göre renkli hale + zemin gölgesi |
| 2 | Çerçeve | `card_frame_painter.dart` | Pahlı silüet + metalik degrade (CustomPaint) |
| 3 | Oyuncu görseli | `premium_player_card.dart` | Şeffaf PNG, eğilmeyle **paralaks** kayar |
| 4 | Bilgi katmanı | `premium_player_card.dart` | Güç, pozisyon, isim, kulüp |
| 5 | Holografik parlama | `holographic_shine.dart` | Yüzeyden geçen ışık (Altın ve üstü) |
| 6 | Yüzey yansıması | `card_tilt.dart` | Eğilmeye göre **kayan** parlaklık |
| 7 | Rozetler | `premium_player_card.dart` | Koruma kalkanı, kilit |

Tüm yığın `CardTilt` içine sarılır → dokunma veya jiroskop ile 3B eğilir.

---

## Neden bu şekilde yazıldı?

### Container yerine CustomPainter

FIFA kartının silüeti düz dikdörtgen değil: üst köşeler pahlı, alt kenar hafif
içbükey, çerçeve kalınlığı kenarlara göre değişiyor. Bunu iç içe `Container`'la
yapmak hem okunmaz bir ağaç hem gereksiz katman yaratır.

Tek `Canvas` üzerinde çizince degradeler **şeklin kendisine** uyuyor (kutuya
değil) ve katman sayısı düşüyor.

### Tek renk yerine "malzeme"

Kartların ikna edici görünmesinin sebebi renk seçimi değil, **malzeme hissi**:

| Seviye | Malzeme | Efektler |
|---|---|---|
| Bronz | Mat, sıcak, düşük kontrast | — |
| Gümüş | Soğuk, pürüzsüz, yüksek yansıma | — |
| Altın | Derin, zengin | Holografik süpürme |
| Diamond | Buzlu, prizmatik | Holografik süpürme (daha hızlı) |
| Legend | Renk değiştiren holografik | Süpürme + **dönen çerçeve ışığı** |

Bu yüzden her seviye için tek renk değil; degrade dizisi, ışık vurma rengi ve
efekt anahtarları tanımlandı ([card_tier_theme.dart](card_tier_theme.dart)).

### Kayan ışık, sabit ışık değil

Gerçek metal yüzeyde ışık, yüzey eğildikçe **kayar**. Sabit parlama kartın
sticker gibi görünmesine sebep olur; kayan parlama "elimde tuttuğum fiziksel
nesne" hissi verir.

### Paralaks

Oyuncu görseli, eğilmenin **tersi** yönde hafifçe kayar. Bu, oyuncunun
çerçevenin arkasında derinlikte durduğu hissini verir — kart "düz bir resim"
değil, katmanlı bir nesne gibi görünür.

---

## Performans

Bu widget ucuz değil. Üç mekanizma ile kontrol altında:

**1. `interactive: false`** — Koleksiyon ekranında yüzlerce kart olabilir.
Orada eğilmeyi ve holografik animasyonu kapat; yoksa her kart kendi
`AnimationController`'ını çalıştırır ve arayüz takılır.

```dart
PremiumPlayerCard.fromInventory(kart, width: 110, interactive: false)
```

**2. `RepaintBoundary`** — Her kart kendi çizim katmanına sahip. Eğilme
animasyonu ekranın geri kalanını yeniden çizmeye zorlamaz.

**3. `AnimatedBuilder` + `child`** — Eğilme saniyede 60 kez değişir. Alt
widget'lar (görsel, metinler, çerçeve) **bir kez** kurulup her karede tekrar
kullanılır; sadece dönüşüm matrisi yeniden hesaplanır.

**4. Holografik efekt sadece Altın ve üstünde** — Bronz/Gümüş kartlarda
animasyon hiç başlatılmaz.

---

## Jiroskop

```dart
PremiumPlayerCard(..., useGyroscope: true)
```

Sadece **tekil, büyük gösterimlerde** aç (paket açılış ekranı, kart detayı).
Masaüstü ve web'de jiroskop yoktur — sessizce devre dışı kalır ve dokunmayla
eğilme çalışmaya devam eder.

---

## Görseller

Kart görselleri yapay zeka ile üretilmiş 3D Pixar tarzı, **arka planı şeffaf
(PNG)** karakterler olacak.

> Şeffaflık şart. Aksi halde görselin dikdörtgen kenarı çerçevenin üzerinde
> görünür ve kartın bütünlüğü bozulur.

Görsel yoksa veya yüklenemezse widget **stilize bir silüet** gösterir; boş kutu
veya kırık resim ikonu görünmez. Şu an katalogdaki `image_url` değerleri
(`cards/mid_legend_1.png`) henüz gerçek dosyalara işaret etmediği için tüm
kartlar silüetle çiziliyor — bu beklenen davranış.

---

## Test

```bash
flutter test test/premium_card_test.dart
```

15 test: her seviyenin hatasız çizilmesi, sürükleyerek eğilme, rozetler,
görselsiz durum, çok küçük boyutta taşma kontrolü ve tema tutarlılığı.

`CustomPainter` ve `ShaderMask` hataları derleme anında değil **çizim anında**
ortaya çıkar — bu testler kartı gerçekten çizerek onları yakalar.
