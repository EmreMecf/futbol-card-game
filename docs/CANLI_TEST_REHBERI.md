# Canlı test rehberi

## 1. Robot oyuncularla otomatik test

İki robot oyuncu sunucuya gerçek oyuncu gibi bağlanır, dereceli ve arkadaş maçlarını baştan sona oynar. Her adımda şunları denetler:

- başlangıç kadrosunun geçerli olması
- eşleşme süresi
- iki tarafın aynı turu ve aynı skoru görmesi
- maçın bitmesi ve iki tarafın aynı kazananı görmesi
- arkadaş maçının puanı değiştirmemesi
- WebSocket bağlantısının kopmaması
- 3 saniyeden uzun süren istekler
- sunucu hataları (500)

Proje klasöründen:

```bash
dart run tool/canli_test/robot_mac.dart --sunucu https://futbol-card-staging-api-lzq3.onrender.com --mac 3 --hesaplar staging_hesaplar.txt
```

- `--mac N`: N dereceli ve N arkadaş maçı oynar.
- `--hesaplar dosya`: Dosya yoksa iki test hesabı açılır ve bilgileri bu dosyaya yazılır. Sonraki çalıştırmalarda aynı hesaplarla giriş yapılır. **Bu dosyada şifreler vardır, depoya ekleme.**
- `--hesaplar` verilmezse her çalıştırmada yeni hesap açılır. Bu, yerel test içindir.
- `--ayrintili`: her isteği süresiyle birlikte yazar.

Sonuçta `Hata: 0` görmelisin. Çıkış kodu, hata yoksa 0, varsa 1'dir.

### Tek başına "Rakip bul" ile oynamak için robot rakip

Telefonda dereceli maçı denemek istiyorsan ama ikinci bir oyuncun yoksa, robotu rakip olarak çalıştır. Robot verilen hesapla sürekli rakip arar, maç bulunca insan gibi 2–4 saniye düşünüp oynar:

```bash
dart run tool/canli_test/robot_mac.dart --sunucu https://futbol-card-staging-api-lzq3.onrender.com --rakip rakip_hesap.txt --dakika 20
```

`rakip_hesap.txt` dosyasının tek satırında robotun kullanacağı test hesabı durur: `e-posta şifre`. Robotu durdurduktan sonra yeni bir arama başlatmadan önce 20 saniye bekle; robotun kuyruktaki son kaydı o sürede silinir.

## 2. Telefonda elle kontrol listesi

Robot bunları yapamaz; iki telefonla dene. Hata görürsen ekran kaydı al.

### Kurulum ve giriş
- [ ] Yeni APK kuruluyor, açılış ekranı görünüyor
- [ ] Kayıt ol: başlangıç kadrosu hazır, "Kadro hazır" yazıyor (kopya futbolcu uyarısı yok)
- [ ] Çıkış yap, yeniden giriş yap

### Bağlantı (videodaki hata)
- [ ] Maç sırasında uygulamayı 1 dakika arka plana al, geri dön: maç kaldığı yerden sürüyor, büyük "yeniden bağlanılıyor" penceresi çıkmıyor
- [ ] Maç sırasında Wi-Fi'yi kapat (mobil veriye geç): en fazla küçük bir üst şerit çıkıyor ve birkaç saniyede kayboluyor
- [ ] Uçak modunu 10 saniye aç-kapat: şerit çıkıyor, bağlantı gelince kayboluyor, oyun kilitlenmiyor
- [ ] Rakip ararken uygulamayı arka plana al ve geri dön: arama sürüyor ya da maç açılıyor

### Davet linki
- [ ] Davet oluştur, "Bağlantıyı paylaş" ile WhatsApp'tan gönder: mesajdaki link mavi ve tıklanabilir
- [ ] Diğer telefonda linke tıkla: sayfa açılıyor, **OYUNDA AÇ** düğmesi oyunu açıp odaya götürüyor
- [ ] Oyun kapalıyken linke tıkla: oyun açılıp odaya gidiyor
- [ ] Sayfadaki **KODU KOPYALA** çalışıyor, kod elle girilince odaya katılınıyor

### Maç
- [ ] Dereceli maçı sonuna kadar oyna: sonuç ekranı, altın ve kupa doğru
- [ ] Arkadaş maçı: "Ödül ve puan yok" yazıyor, kupa değişmiyor
- [ ] Teslim ol: onay penceresi, sonuç ekranı

### Kadro
- [ ] Aynı futbolcunun ikinci kopyası kadroya konamıyor, uyarı Türkçe ve anlaşılır
- [ ] "Otomatik diz" her futbolcuyu bir kez koyuyor

## 3. Bilinen durumlar (hata değil)

- **Render ücretsiz planı:** Sunucu 15 dakika boşta kalınca uyur. İlk istek 30–50 saniye sürer. VPS'e geçince bu bekleme ortadan kalkar.
- **Hükmen:** Üst üste iki turda kart seçilmezse maç hükmen kaybedilir, skor önde ya da eşit olsa bile. Sonuç ekranı ve geçmiş bunu "Hükmen" olarak gösterir. Zamanında seçilmeyen mevki hükmen sayılmaz.
- **Kısa maçlar:** 4 turdan kısa süren maçlar (erken teslim, iki oyuncunun da oynamaması) sezon XP'si ve görev ilerlemesi vermez. Bu, kötüye kullanımı önlemek için böyle tasarlandı.
