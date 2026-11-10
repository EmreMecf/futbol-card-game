# Futbol Card Arena — Game Economy V2 Tasarım Belgesi

Sürüm: 2 (10 Kasım 2026). Durum: **K1–K6 onaylandı**. FAZ 0 ve FAZ 1
uygulandı (bkz. §14 "Uygulama durumu").

Bu belge sandık, futbolcu seviyesi, Battle Pass, item envanteri ve ödül
enerjisi sistemlerini tasarlar. **Kod değişikliği yok.** Sayılar,
`tool/ekonomi/simulasyon.py` ile gerçek 100 kartlık katalog üzerinde
doğrulandı (sonuçlar: `tool/ekonomi/sonuclar.md`).

**Değişmeyen çekirdek** (onayın olmadan dokunulmaz):

- 11 kartlık kadro, 1-4-4-2 formasyonu
- Aynı mevki zorunluluğu, güç + kimya karşılaştırması, Efsane kuralı,
  pas, pot / beraberlik
- Taktik enerjisi (021)
- Maç sonu kuralları: galibiyet +100 altın, +25 MMR, +1 koruma hakkı
  (en fazla 10); yenilgi −25 MMR ve korumasız 3 rastgele el kartının
  kalıcı kaybı
- Mevcut paket sistemi (`pack_types`, `open_pack`), SBC, kart satışı
  (020, yarım; dokunulmadı)

---

## Senin kararın gereken konular (özet)

| # | Karar | Önerim | Neden |
|---|---|---|---|
| **K1** | Futbolcu seviyesi dereceli maçta kart gücünü değiştirsin mi? | **Hayır.** Seviye dereceli düelloda güce etki etmez. | Simülasyon: aynı kadroda seviye başına +1 güç → %100 kazanma; en fazla +4'lük yumuşak eğri bile %99–100. Bu oyunda aynı mevkideki kartlar birbirine çok yakın, kimya bile +1/+2. En küçük bonus bile maçı belirliyor (bkz. §2.4). |
| **K2** | Aynı futbolcu tekrar çıkınca ne olsun? | **Gelişim kopyası + kadro kilidi koruması.** Var olan fazla kopyalar silinmez, istenirse oyuncu kendisi dönüştürür. | Kalıcı kart kaybıyla çakışma: kopyalar parçaya dönerse kaybedilen kartın yerine yenisi gelmiyor. Koruma yokken (gerçekçi paket modeliyle) oyuncular 180 günün 72–112 gününde kadro kuramıyor; koruma + Acil Kadro ile 0–0,1 gün (§1.3, §1.6, §10). |
| **K3** | Yenilgide de sandık verilsin mi? | **Evet** (Bronz ağırlıklı). | Kart kaybının acısını azaltır, maç başına ödül hedefi tutar. |
| **K4** | Premium ödemesi | **Bu fazda yok.** Premium yalnız tasarımda; ödeme (Google Play / App Store) ayrı faz ve ayrı onay. | Gerçek para, iade, vergi, yaş ve ganimet kutusu mevzuatı ayrı iş (§12). |
| **K5** | Sandık gerçek parayla satılsın mı? | **Hayır.** Sandıklar yalnız oynayarak kazanılır. | Belçika ve Hollanda gibi ülkelerde ücretli ganimet kutusu yasak; olasılık gösterimi her yerde zorunlu hâle geliyor. |
| **K6** | Çok kısa maçta (teslim, AFK) sandık | 4. turdan önce biten maçta sandık **yok**. | İki hesapla karşılıklı teslim olup sandık çiftçiliğini önler. |

---

## 1. Kesin sandık kuralları

### 1.1 Sandık türleri

| Tür | Kilit süresi | İçerik | Altın | Joker parça |
|---|---|---|---|---|
| Bronz | anında (yuvaya girmez, hemen açılır) | 3 futbolcu | 10–20 | 1 Bronz |
| Gümüş | 2 saat | 3 futbolcu | 30–50 | 2 Bronz + 1 Gümüş |
| Altın | 6 saat | 3 futbolcu | 80–120 | 2 Gümüş + 1 Altın |
| Efsane | 12 saat | 3 futbolcu | 200–300 | 2 Altın + 1 Elmas |

### 1.2 Hangi sandık? (sürüm 1, veritabanında)

| Maç sonucu | Bronz | Gümüş | Altın | Efsane |
|---|---|---|---|---|
| Galibiyet | %52 | %35 | %11 | %2 |
| Beraberlik | %70 | %26 | %4 | %0 |
| Yenilgi | %80 | %18 | %2 | %0 |

**Şanssızlık koruması:**

- 15 sandıktır Altın ya da üstü gelmediyse sıradaki en az Altın.
- 60 sandıktır Efsane gelmediyse sıradaki Efsane.
- Sayaçlar oyuncu başına sunucuda tutulur.

### 1.3 Sandık içi nadirlik (sürüm 1)

Her sandık **tam 3 futbolcu** içerir. Her yuva ayrı çekilir; Gümüş ve
üstü sandıklarda 3. yuva "garanti yuvası"dır.

| Sandık / yuva | Bronz | Gümüş | Altın | Elmas | Efsane |
|---|---|---|---|---|---|
| Bronz 1–3 | 72 | 24 | 4 | – | – |
| Gümüş 1–2 | 50 | 38 | 11 | 1 | – |
| Gümüş 3 | – | 70 | 26 | 3,6 | 0,4 |
| Altın 1–2 | 25 | 42 | 28 | 4,5 | 0,5 |
| Altın 3 | – | – | 82 | 16 | 2 |
| Efsane 1–2 | – | 30 | 52 | 16 | 2 |
| Efsane 3 | – | – | – | 85 | 15 |

- Nadirlik içinde futbolcu, katalogdaki `drop_weight` ile seçilir
  (paketlerle aynı ağırlık, ayrı tablo).
- Oranlar **sürümlüdür:** `chest_odds_versions` (yayın tarihi, not) +
  `chest_slot_odds`.
- Her sandık açıldığı andaki sürüm numarasını saklar.
- İstemcide "Olasılıklar" sayfası sunucudaki aktif sürümü gösterir.
- Oran değişikliği yeni sürümdür; eski kayıtlar asla güncellenmez.

**Kadro kilidi koruması (K2'nin parçası):**

- Oyuncunun koleksiyonunda bir mevkide "formasyon ihtiyacı + 1 yedek"ten
  az kart varsa, sandık yuvası o mevkiden çekilir.
- Bu kart, gelişim kopyası değil **fiziksel kart** olarak verilir.
- Oyuncu bunu seçemez; sunucu karar verir.

### 1.4 Yuvalar, kilit açma, posta kutusu

- **4 sandık yuvası.**
- **Aynı anda tek sandığın kilidi açılır** (sunucuda tek "açılan" kayıt).
  Sayaç sunucu saatiyle tutulur: `unlock_ready_at = now() + süre`.
  İstemci yalnız gösterir.
- **Bronz:** yuvaya girmez, kazanıldığı an "hazır" olarak açılır.
- **Yuvalar doluysa** sandık posta kutusuna düşer: en fazla 8 sandık,
  7 gün ömür. Bir yuva boşalınca oyuncu postadan yuvaya taşır.
- **Güvenli telafi:** posta kutusu da doluysa ya da ömür dolduysa sandık
  kaybolmaz. Yerine telafi altını yazılır ve deftere (`economy_ledger`)
  kayıt düşülür:

  | Bronz | Gümüş | Altın | Efsane |
  |---|---|---|---|
  | 25 | 70 | 180 | 450 |

### 1.5 Maç sonu: kim, ne zaman, kaç kez

- **Sandık alan maçlar:** dereceli ve `finished` olan maç, en az 4 tur
  oynanmış. Her iki oyuncuya birer sandık (K3).
- **Ödül enerjisi gerekir** (§6). Enerjisizse sandık yok; maç ve mevcut
  ödüller aynen.
- **Bağlantı noktası:** `matches.status → finished` geçişinde çalışan
  `AFTER UPDATE` tetikleyicisi. `_finish_match` (007) değiştirilmez;
  022'deki MMR fotoğrafı da aynı yöntemi kullanıyor.
- **İki kez alınamaz:** `user_chests` üzerinde `unique (source_type,
  source_id, user_id)`.
  - Tetikleyici iki kez çalışsa bile ikinci kayıt reddedilir.
  - Açma işlemi `status = 'ready' → 'opened'` geçişinde satır kilidiyle
    (`for update`) tek seferliktir.
  - İstemcinin tekrar gönderdiği istek aynı sonucu alır (§8 idempotency).
- **Sonuç:** açılırken `secure_random_int` ile çekilir ve sandık
  satırına (`result jsonb`) yazılır. Aynı sandık ikinci kez açılamaz,
  sonuç değişmez.

### 1.6 Acil Kadro (K2'nin ikinci parçası; FAZ 1'de eklendi)

Kabul testinde canlı görüldü: yenilgide 3 kart kaybeden test hesabı
orta saha mevkiinde formasyonu kuramadı. 1.000 altınıyla 2 standart paket
aldı; standart ve premium paketlerde **mevki garantisi yok**, eksik
kapanmadı ve oyuncu 0 altınla kalıcı olarak kilitlendi. Kilitli oyuncu
maç oynayamadığı için sandık da kazanamıyor; yani §1.3'teki koruma tek
başına yetmiyor.

**Kural (`032_emergency_squad.sql`):**

- **Hak:** koleksiyonu formasyonu (1 GK, 4 DEF, 4 MID, 2 FWD)
  karşılamayan oyuncu. Yalnızca kadroya seçmesi gereken oyuncu hak
  kazanmaz.
- **Ne alır:** Bronz kart; her mevki "ihtiyaç + 1 yedek"e tamamlanır.
- **Sıklık:** 24 saatte en fazla 1 kez.
- **Kayıt:** deftere yazılır ve idempotent'tir.
- **Neden +1 yedek:** yalnızca eksik sayısı verilince günde 20 maç
  oynayan oyuncu 180 günün 22,5'inde yine kilitleniyordu. Acil kadroyu
  kullandıktan sonra aynı gün bir yenilgiyle tekrar kilitleniyordu.
  +1 yedekle bu 0,1 güne iniyor.
- **Suistimal:** Bronz kart olduğu için kötüye kullanmaya değmez.
  Düello kurallarına dokunmaz.

---

## 2. Futbolcu seviye maliyetleri

### 2.1 Model

- **Seviye kişiye ve futbolcuya bağlıdır**, fiziksel kopyaya değil:
  `player_progress(user_id, card_id, level 1–10, copies)`.
- Kartın kopyası kaybedilse bile seviye ve biriken kopya kaybolmaz; kart
  geri kazanılınca aynı seviyeden devam eder.
- **Sandıktan sahip olunan futbolcu** gelince `copies + 1` (fiziksel kart
  artmaz). İstisna: kadro kilidi koruması (§1.3).
- **Sandıktan sahip olunmayan futbolcu** gelince yeni `user_cards` satırı
  (fiziksel kart).
- **Paketler ve maç cezası transferi değişmez:** her zaman fiziksel kart.
- **Gönüllü dönüşüm:** 2'den fazla fiziksel kopyası olan oyuncu fazlasını
  gelişim kopyasına çevirebilir. Geri alınamaz, onay penceresi ve defter
  kaydıyla yapılır.
- **Seviye 10'daki futbolcunun kopyası** joker parçaya döner:
  Bronz 1, Gümüş 2, Altın 4, Elmas 10, Efsane 25.

### 2.2 Maliyet tablosu (L → L+1; kopya / altın)

| Seviye | Bronz | Gümüş | Altın | Elmas | Efsane |
|---|---|---|---|---|---|
| 1→2 | 1 / 20 | 1 / 30 | 1 / 50 | 1 / 100 | 1 / 200 |
| 2→3 | 2 / 50 | 2 / 75 | 1 / 125 | 1 / 250 | 1 / 500 |
| 3→4 | 3 / 100 | 3 / 150 | 2 / 250 | 1 / 500 | 1 / 900 |
| 4→5 | 5 / 200 | 4 / 300 | 3 / 500 | 2 / 900 | 1 / 1.500 |
| 5→6 | 8 / 400 | 6 / 600 | 5 / 900 | 3 / 1.500 | 2 / 2.500 |
| 6→7 | 12 / 700 | 9 / 1.000 | 7 / 1.500 | 4 / 2.400 | 3 / 4.000 |
| 7→8 | 16 / 1.000 | 13 / 1.500 | 10 / 2.200 | 6 / 3.600 | 4 / 6.000 |
| 8→9 | 22 / 1.500 | 18 / 2.200 | 14 / 3.200 | 8 / 5.000 | 5 / 8.500 |
| 9→10 | 30 / 2.500 | 24 / 3.500 | 18 / 5.000 | 11 / 7.500 | 7 / 12.000 |
| **Toplam** | **99 / 6.470** | **80 / 9.355** | **61 / 13.725** | **37 / 21.750** | **25 / 36.100** |

**Eğriler:**

- Nadir kart daha az kopya ama daha çok altın ister (Efsane 25 kopya,
  Bronz 99 kopya).
- Bir Bronz kartın belirli bir kopyası Elmas'tan çok daha sık geldiği için
  eğriler zaman olarak birbirine yakın düşer.
- Joker parça (sandık + Battle Pass) aynı nadirlikteki herhangi bir
  futbolcuya 1 kopya yerine geçer.

**Ölçülen sonuç (kadro ortalama seviyesi):**

| Profil | 30 gün | 90 gün | 180 gün |
|---|---|---|---|
| Günde 2 maç, ücretsiz | 2,3 | 4,0 | 4,9 |
| Günde 5 maç, ücretsiz | 3,3 | 5,1 | 5,7 |
| Günde 10 maç, ücretsiz (kontrol) | 4,5 | 6,1 | 6,5 |
| Günde 10 maç, premium | 4,8 | 6,4 | 6,7 |
| Günde 20 maç, premium plus | 5,6 | 7,0 | 7,7 |

Kimse 180 günde kadrosunu 10'a çıkaramıyor; uzun vadeli hedef korunuyor.

### 2.3 Seviye ne işe yarar? (K1)

Önerim, seviyenin dereceli maçta **güç ya da kazanma şansı vermemesi**.
Bunun yerine:

- **Ustalık görünümü:** kartta seviye yıldızları, 5 / 8 / 10'da çerçeve.
- **Ustalık kitabı ve ödüller:** seviye 5 / 10'a ulaşan her futbolcu için
  tek seferlik ödül (altın, sezon XP, kart görünümü).
- **Seviyeli etkinlik modu** (ayrı, MMR'siz, kart kaybı yok, ileriki faz):
  seviye bonusu yalnızca orada açılır (en fazla +3, maç tavanıyla).
- **Kadro ustalık puanı** (profil ve liderlik dışı istatistik).

### 2.4 Normalizasyon simülasyonu (gerçek düello kuralları)

Yöntem:

- 11 tur oynanır; turu açan rastgele kart açar, cevap veren aynı mevkiden
  en iyisini oynar ya da pas geçer.
- Güç + kimya karşılaştırılır, Efsane kuralı uygulanır.
- Beraberlik yarım galibiyet sayılır.
- Kadro: 180 günlük kadro (ortalama seviye 4,9–7,7).
- Her satır 1.500 maç.

| Yöntem | Aynı kadro, yalnız seviye farkı | Benzer güçte (±3), seviye 1 rakip |
|---|---|---|
| Etki yok | %49–51 | %67–77 * |
| Seviye başına +1 güç | **%100** | **%100** |
| Eğri (0,0,0,1,1,2,2,3,3,4) | **%99–100** | **%99–100** |
| Maç tavanı: min(ortalama) + 1, sonra eğri | %50–52 | %65–76 * |

\* %50'nin üstündeki fark seviyeden değil, kadronun kimyasından geliyor:
rastgele benzer kartlardan kurulan rakibin kimyası düşük. "Etki yok"
satırıyla aynı olduğuna dikkat et.

**Sonuç:**

- Bu oyunda seviyeye bağlı **her** güç bonusu kazananı belirliyor.
- "Maç tavanı" yöntemi etkiyi siliyor; ama o zaman dereceli maçta seviye
  zaten işlevsiz.
- Bu yüzden öneri K1: dereceli maçta seviye etkisi yok.

---

## 3. Battle Pass ödül tablosu

- **Sezon ve kademe:** 30 gün, 50 kademe, kademe başına 1.000 XP
  (toplam 50.000).
- **Yollar:**
  - **Ücretsiz:** herkes.
  - **Premium:** tek sezonluk satın alma (K4).
  - **Premium Plus:** Premium + anında 5 kademe + %10 sezon XP.
- **Premium'un hızlandırmadığı şeyler:**
  - XP (Premium Plus'ın %10'u hariç)
  - Dereceli güç
  - Ödül enerjisi kapasitesi
- **Premium'un hızlandırdığı:** gelişim (daha çok joker parça ve sandık)
  ve özel kozmetikler.

| Kademe | Ücretsiz yol | Premium yol |
|---|---|---|
| 1 | 93 altın | Forma: Sezon 1 |
| 2 | 93 altın | Altın joker parça x3 |
| 3 | Gümüş sandık | 195 altın |
| 4 | 93 altın | 195 altın |
| 5 | 93 altın | Altın sandık |
| 6 | Altın joker parça x2 | 195 altın |
| 7 | 93 altın | 195 altın |
| 8 | 93 altın | Altın joker parça x3 |
| 9 | Gümüş sandık | 195 altın |
| 10 | 93 altın | Kart görünümü: Gece Işığı |
| 11 | 93 altın | 195 altın |
| 12 | Altın sandık | 195 altın |
| 13 | 93 altın | Altın sandık |
| 14 | 93 altın | 195 altın |
| 15 | Gümüş sandık | Efsane sandık |
| 16 | 93 altın | 195 altın |
| 17 | 93 altın | Altın joker parça x3 |
| 18 | Altın joker parça x2 | 195 altın |
| 19 | 93 altın | Elmas joker parça x2 |
| 20 | 93 altın | Profil çerçevesi: Sezon 1 |
| 21 | Gümüş sandık | 195 altın |
| 22 | 93 altın | Altın sandık |
| 23 | 93 altın | 195 altın |
| 24 | Altın sandık | 195 altın |
| 25 | Sezon rozeti (bronz) | Sezon rozeti (altın) |
| 26 | 93 altın | Altın joker parça x3 |
| 27 | Altın joker parça x2 | 195 altın |
| 28 | 93 altın | Altın sandık |
| 29 | 93 altın | 195 altın |
| 30 | Enerji içeceği x2 | Arena görünümü: Yağmurlu Gece |
| 31 | 93 altın | 195 altın |
| 32 | 93 altın | Altın joker parça x4 |
| 33 | Gümüş sandık | 195 altın |
| 34 | 93 altın | 195 altın |
| 35 | 93 altın | Efsane sandık |
| 36 | Altın sandık | 195 altın |
| 37 | 93 altın | Elmas joker parça x2 |
| 38 | 93 altın | Sandık hızlandırıcı (2 sa) x2 |
| 39 | Altın joker parça x2 | 195 altın |
| 40 | 93 altın | Zafer animasyonu: Havai Fişek |
| 41 | 93 altın | Altın joker parça x4 |
| 42 | Altın sandık | 195 altın |
| 43 | 93 altın | 195 altın |
| 44 | 93 altın | Altın sandık |
| 45 | Gümüş sandık | Karakter kozmetiği: Kaptan Bandı |
| 46 | 93 altın | Ustalık kitabı (Altın) x1 |
| 47 | 93 altın | Altın sandık |
| 48 | Altın joker parça x2 | 210 altın |
| 49 | 117 altın | Elmas joker parça x2 |
| 50 | Efsane sandık | Efsane sandık |

Toplam: ücretsiz 3000 altın, 6 gümüş / 4 altın / 1 efsane sandık, 10 Altın joker; premium 4500 altın, 6 altın / 3 efsane sandık, 20 Altın + 6 Elmas joker.

Tablo `tool/ekonomi/bp_tablo.py` ile üretildi (toplamlar simülatörle aynı).

**Sezon bitişi ve geçiş:**

- **Alınmamış ödüller:** sezon kapanınca ulaşılmış ama alınmamış
  kademelerin ödülleri **otomatik** posta kutusuna gönderilir. Kaybolmaz;
  posta kuralları ve telafi geçerli.
- **Premium sonradan alınırsa:** ulaşılmış premium kademeleri hemen
  alınabilir.
- **Yeni sezon:** XP sıfırlanır. Kozmetik ve rozetler kalıcıdır. Joker
  parça ve itemler korunur.
- **Sezon kaydı:** `seasons(id, starts_at, ends_at, status)`. Kapanış
  sunucu işiyle yapılır; tekrar çalışırsa sonuç değişmez.

---

## 4. Item kataloğu

`item_definitions` her itemin türünü (`kind`) taşır. Kurallar sunucuda
türe göre doğrulanır.

| Tür (`kind`) | Kurallar |
|---|---|
| `stackable` | Miktar ≥ 0, `max_stack` aşılamaz; fazlası posta kutusuna |
| `consumable` | Kullanım tek işlem: miktar −1 + etki + defter kaydı (aynı transaction, idempotency anahtarı) |
| `timed` | `expires_at` sunucu saatiyle; süresi dolmuş item kullanılamaz, gösterilmez ama silinmez (denetim için) |
| `cosmetic` | Kalıcı, miktar 1, tekrar gelirse altına döner (yinelenen kozmetik telafisi) |

| Item | Tür | Etki / kural | Kaynak |
|---|---|---|---|
| Sandık anahtarı | consumable (max 10) | Bir sandığın kilidini anında açar; Efsane'de 2 anahtar | BP, etkinlik |
| Sandık hızlandırıcı (2 sa) | consumable (max 20) | Açılan sandığın süresinden 2 saat düşer | BP |
| Joker futbolcu parçası (5 nadirlik) | stackable (max 9.999) | Seçilen futbolcuya 1 kopya | Sandık, BP |
| Gelişim indirimi (%25) | timed (7 gün) | Sonraki seviye atlama altınına %25 indirim, tek kullanım | Etkinlik |
| Ustalık kitabı (nadirliğe göre) | consumable | O nadirlikte bir futbolcuya bir seviyelik kopya; altın yine ödenir | BP Premium |
| Enerji içeceği | consumable (max 10) | +3 ödül enerjisi, günde en fazla 2 | BP, görev |
| Ödül enerjisi | sayaç (§6) | Item değil, `reward_energy` tablosu | Zamanla dolar |
| Etkinlik bileti | timed (sezon sonu) | Etkinlik moduna 1 giriş | BP, görev |
| Profil çerçevesi | cosmetic | Görsel | BP, seviye ustalığı |
| Forma | cosmetic | 2D karakterlerin forması (yüz kimliği değişmez) | BP |
| Kart görünümü | cosmetic | Kart arka planı ve çerçeve deseni (nadirlik rengi korunur) | BP, ustalık |
| Arena görünümü | cosmetic | Stadyum teması (yalnız kendi ekranında) | BP |
| Zafer animasyonu | cosmetic | Maç sonu konfeti / efekt | BP |
| Karakter kozmetikleri | cosmetic | Kaptan bandı, saç bandı vb. | BP |
| Sezon rozeti | cosmetic | Profil rozeti, sezon numarasıyla | BP 25 / 50 |

**Hiçbir item dereceli maçta güç vermez.**

---

## 5. Sezon XP dengesi

| Kaynak | XP |
|---|---|
| Maç (enerjili): galibiyet / beraberlik / yenilgi | 100 / 70 / 60 |
| Maç (enerjisiz) | yukarıdakinin %25'i |
| Günlük görevler (1 / 2 / 3 maç ve benzeri) | 150 + 200 + 250 |
| Haftalık görevler (yaklaşık 28 maçlık hedef) | 6.000 |
| Sezon görevleri (yaklaşık 120 maçlık hedef) | 10.000 |

**Ölçülen sonuç (30 günlük sezon):**

| Profil | Ortalama kademe | Tamamlama |
|---|---|---|
| Günde 2 maç, ücretsiz | 32 / 50 | Bitiremez (ana ödüller 1–30 arasında dengeli) |
| Günde 5 maç | 50 | Tamamlar (tahmini 23. gün; simülatör yalnız sezon sonunu ölçüyor) |
| Günde 10 / 20 maç | 50 | Tamamlar |

**Görev örnekleri** (yalnız oynayarak yapılabilir, ödeme gerektirmez):

- **Günlük:** 1 maç oyna; 2 maç oyna; 3 maç oyna; bir taktik kullan;
  kimyası +2 olan kartla tur kazan.
- **Haftalık:** 10 galibiyet; 5 farklı mevkide tur kazan; 3 sandık aç.
- **Sezon:** 120 maç; 1 futbolcuyu 5. seviyeye çıkar; 3 SBC tamamla.

---

## 6. Enerji ekonomisi

- **Ödül enerjisi**, taktik enerjisinden tamamen ayrıdır (farklı tablo,
  farklı isim, farklı ekran öğesi).
- **Kapasite ve dolum:** en fazla 10; 96 dakikada 1 dolar (günde 15).
- **Hesaplama:** sunucuda tembel hesap. `reward_energy(user_id, energy,
  updated_at)`; okunurken `now()` farkı eklenir, ayrı bir zamanlayıcı yok.
- **Dereceli maç 1 enerji harcar** ve tam ödül verir: sandık + tam XP.
- **Enerjisiz maç normal oynanır:**
  - Eşleşme, MMR, galibiyet altını, koruma hakkı ve kart kaybı **aynen**
    geçerli.
  - Yalnız sandık çıkmaz ve XP %25'e düşer.
- **Ücretli seçenek:** enerji kapasitesini artıran ücretli bir şey yok.
  Enerji içeceği yalnız oynayarak (BP, görev) kazanılır, günde en fazla 2.
- **Ölçülen:** günde 20 maç oynayan 90 günde yaklaşık 446 maçı enerjisiz
  oynuyor (günde ~5). 2–10 maç oynayanlar hiç etkilenmiyor.

---

## 7. Maç sonu ödül sistemi

| Ödül | Galibiyet | Beraberlik | Yenilgi | Kaynak |
|---|---|---|---|---|
| Altın | +100 | – | – | **mevcut, değişmez** |
| MMR | +25 | – | −25 | **mevcut, değişmez** |
| Koruma hakkı | +1 (en fazla 10) | – | – | **mevcut, değişmez** |
| Kart kaybı | rakipten 3 kart | – | korumasız 3 kart | **mevcut, değişmez** |
| Sandık (enerjiliyse, ≥4 tur) | §1.2 tablosu | §1.2 | §1.2 | **yeni** |
| Sezon XP | 100 | 70 | 60 | **yeni** |

**Maç sonu ekranına eklenecekler:**

- "Sandık kazandın" kartı (tür, yuva ya da posta kutusu)
- XP çubuğu
- Enerji yoksa "Ödül enerjin bitti; maç ödüllerin geçerli, sandık için
  enerji dolunca oyna" notu

---

## 8. Veritabanı mimarisi

Bütün yeni şeyler yeni tablolarda; var olan tablolarda kolon silinmez ya
da anlamı değişmez. Migration'lar **028**'den başlar; 020 senin yarım
dosyan, numarası boş bırakılır.

| Tablo | Amaç | Faz |
|---|---|---|
| `economy_ledger` | Her ödül, harcama ve telafinin değişmez kaydı (`user_id`, `entry_type`, `coins_delta`, `items jsonb`, `source_type`, `source_id`, `idempotency_key unique`, `created_at`). Silme ya da güncelleme yok. | 0 |
| `idempotency_keys` | `(user_id, key)` unique, endpoint, istek özeti (hash), cevap `jsonb`, 48 saat | 0 |
| `economy_config_versions` | Sürümlü ayarlar (`kind`, `version`, `payload`, `active_from`) | 0 |
| `reward_energy` | Ödül enerjisi (tembel dolum) | 1 |
| `chest_types` | Bronz / Gümüş / Altın / Efsane: süre, altın aralığı, joker | 1 |
| `chest_odds_versions`, `chest_type_odds`, `chest_slot_odds` | Sürümlü olasılıklar (§1.2–1.3) | 1 |
| `user_chests` | `id`, `user_id`, `chest_type`, `odds_version`, `source_type`, `source_id`, `status` (`sealed`, `unlocking`, `ready`, `opened`, `compensated`), `location` (`slot` / `mailbox`), `slot_no`, `unlock_started_at`, `unlock_ready_at`, `opened_at`, `result jsonb`; `unique(source_type, source_id, user_id)`; kısmi unique: kullanıcı başına tek `unlocking` | 1 |
| `user_chest_state` | Şanssızlık sayaçları | 1 |
| `player_progress` | `(user_id, card_id)` PK, `level`, `copies`; FAZ 1'de yalnız `copies` birikir (seviye atlama kapalı) | 1 |
| `item_definitions`, `user_items` | Item kataloğu ve envanter (`quantity`, `expires_at`, `acquired_via`) | 3 |
| `seasons`, `season_tiers`, `user_seasons`, `season_claims` | Battle Pass | 4 |
| `missions`, `user_missions` | Günlük / haftalık / sezon görevleri | 4 |

**İlkeler:**

- Her ödül fonksiyonu tek transaction içinde çalışır: satır kilidi
  (`for update`), unique kısıt ve defter kaydı.
- İstemci miktar, oran ya da sonuç göndermez; yalnız kimlik ve
  idempotency anahtarı gönderir.
- Zamanlar yalnız `now()` ile tutulur; istemci saati hiçbir hesapta
  kullanılmaz. Cevaplarda `server_time` döner, istemci sayaç kaymasını
  buna göre düzeltir.

---

## 9. API sözleşmeleri (FAZ 0–1)

Bütün değiştirici isteklerde `Idempotency-Key: <uuid>` başlığı
zorunludur. Aynı anahtarla gelen istek aynı cevabı alır; farklı gövdeyle
gelirse 409 döner.

| Uç | Cevap / kural |
|---|---|
| `GET /api/economy/config` | Aktif sürümler `{chest_odds_version, energy:{max, refill_minutes}}` |
| `GET /api/energy` | `{energy, max, next_at, server_time}` |
| `GET /api/chests` | `{slots:[{id, type, status, slot_no, unlock_ready_at}], mailbox:[...], server_time, odds_version}` |
| `GET /api/chests/odds?version=` | Tür ve yuva oranları (tablo hâlinde) |
| `POST /api/chests/{id}/unlock` | Kilit açmayı başlatır. Zaten açılan varsa 409 `chest_already_unlocking` |
| `POST /api/chests/{id}/open` | Yalnız `ready` sandık. `{cards:[{card, outcome:"new"\|"copy"\|"joker"\|"squad_guard"}], coins, jokers, ledger_id}`. Tekrar açma aynı sonucu döner |
| `POST /api/chests/mailbox/{id}/claim` | Boş yuvaya taşır. Boş yuva yoksa 409 `slots_full` |
| WebSocket `chest_granted` | Maç bitince `{chest_id, type, location}`. Kopan bağlantı `GET /api/chests` ile toparlar |

**Hata gövdesi:** mevcut `ApiException` biçimi (Türkçe mesaj + makine
kodu).

---

## 10. Ekonomi simülasyon planı

**Araç:** `tool/ekonomi/simulasyon.py`

- Gerçek katalogdan beslenir: `katalog.csv`, veritabanından alındı.
- Saat adımlı çalışır, tohumu sabittir (tekrarlanabilir).
- Ayar kaynağı tek yer: `AYARLAR`.
- Bu belgedeki tablolar oradan gelir; biri değişirse diğeri de
  güncellenir.

**Profiller:**

- Günde 2 maç, ücretsiz
- Günde 5 maç, ücretsiz
- Günde 10 maç, ücretsiz (kontrol)
- Günde 10 maç, premium
- Günde 20 maç, premium plus

**Süreler:** 30 / 90 / 180 gün, profil başına 8 tekrar.

**Ölçülen 180 günlük sonuçlar** (ayrıntı: `tool/ekonomi/sonuclar.md`):

| Ölçüt | 2/gün ücretsiz | 5/gün ücretsiz | 10/gün ücretsiz | 10/gün premium | 20/gün premium+ |
|---|---|---|---|---|---|
| Kadro ortalama seviye | 4,84 | 5,66 | 6,46 | 6,74 | 7,59 |
| Sandık (B/G/A/E) | 224/114/46/7 | 568/266/105/25 | 1139/490/185/43 | 1126/500/202/47 | 1707/602/232/51 |
| Yuvalar dolu (zamanın) | %0 | %1 | %12 | %22 | %96 |
| Telafiye dönen sandık | 0 | 2 | 7 | 43 | 224 |
| Fazla kopya (seviye 10 üstü) | 0 | 0 | 0 | 1 | 145 |
| Altın bakiyesi (sonda) | 760 | 1.058 | 1.272 | 1.141 | 1.212 |
| Kadro kilitli gün | 0 | 0 | 0 | 0 | 0,1 |

**Okuma:**

- **Ücretli ile ücretsiz farkı:** aynı oyun süresinde (10 maç/gün)
  premiumun etkisi kadroda yalnız **+0,2 seviye**. Fark süreden geliyor,
  paradan değil. Seviye dereceli güce etki etmediği için (K1) PvP'ye
  yansımıyor.
- **Altın darboğazı:** ücretsiz oyuncularda seviye atlama altınla
  sınırlı. Bakiye 300–1.400 arasında dengede, şişme yok.
  Yan etkisi: paket satın alma azalıyor (§12 R4).
- **Sandık kuyruğu:** günde 10 maça kadar sorun yok. Günde 20 maçta
  yuvalar sürekli dolu; telafi devreye giriyor, sandık kaybolmuyor.
- **Kadro kilidi** (180 gün):

  | Senaryo | 2/gün | 5/gün | 10/gün ücretsiz | 10/gün premium | 20/gün |
  |---|---|---|---|---|---|
  | Koruma yok | 98 | 106 | 112 | 73 | 72 |
  | Sandık önceliği + Acil Kadro (yalnız eksik) | 0,1 | 0 | 0 | 0 | 22,5 |
  | Sandık önceliği + Acil Kadro (+1 yedek, **uygulanan**) | 0 | 0 | 0 | 0 | 0,1 |

  - **Düzeltme:** taslak 1'de "koruma yokken 23 gün" yazıyordu. O model,
    kilitli oyuncunun aldığı paketin eksik mevkiden kart verdiğini
    varsayıyordu; gerçekte standart paketin mevki garantisi yok. Gerçekçi
    modelle risk çok daha büyük çıktı.
  - Komutlar: `simulasyon.py 8 parca yok` (koruma yok),
    `simulasyon.py 8 parca koruma 0` (yalnız eksik),
    `simulasyon.py 8` (uygulanan).
- **Yeni oyuncu:** dereceli eşleşmede seviye etkisi olmadığı için yeni
  oyuncunun kazanma şansını yalnız kart gücü ve kimya belirliyor; bu
  mevcut durumla aynı (§2.4).

**Simülasyonun sınırları:**

- Kazanma oranı sabit %48 alındı (eşleştirme dengeli kabul edildi).
- Maç içi taktik ve pot sadeleştirildi.
- Oyuncu davranışı (seviye önceliği, paket alma eşiği) varsayımdır.
- Gerçek veri gelince yeniden ayarlanmalı.

---

## 11. Kullanıcı deneyimi ekranları

Hepsi referans HTML dilinde (`Ref` bileşenleri).

1. **Ana sayfa sandık şeridi:** 4 yuva + posta kutusu rozeti. "GÜNLÜK
   GÖREVLER — yakında" kartının yerine geçer (FAZ 4'te görevler gelince
   ikisi yan yana).
2. **Sandık ekranı:** yuvalar, kilit sayacı (sunucu saatine göre),
   "Kilidi aç", "Aç", posta kutusu sekmesi, "Olasılıklar" bağlantısı.
3. **Sandık açılışı:** paket açılışından **ayrı** bir sahne (sandık
   kapağı, 3 kart). Her kartta "YENİ", "+1 KOPYA" ya da "KADRO KORUMASI"
   rozeti; altın ve joker özeti.
4. **Olasılıklar sayfası:** aktif sürüm numarası ve tarihi, tür ve yuva
   tabloları, şanssızlık koruması açıklaması.
5. **Maç sonu:** "Sandık kazandın" kartı, XP çubuğu, enerji notu.
6. **Ödül enerjisi göstergesi:** başlıkta küçük ⚡ (taktik enerjisinden
   farklı renk ve ikon) ve dolum zamanı.
7. FAZ 2+: futbolcu gelişim sayfası, Battle Pass yolu, görevler,
   envanter.

---

## 12. Riskler ve geçiş planı

### Riskler

| # | Risk | Önlem |
|---|---|---|
| R1 | Seviye güç verirse kazanmak satın alınır | K1: dereceli maçta etki yok (simülasyon §2.4) |
| R2 | Kopyalar parçaya dönerse kadro kilitlenir | Kadro kilidi koruması + fiziksel kopyalar korunur (§1.3, §2.1) |
| R3 | Sandık çiftçiliği (iki hesap, teslim) | ≥4 tur kuralı, ödül enerjisi, ceza transferi zaten caydırıcı; defterden şüpheli eşleşme raporu |
| R4 | Altın seviye atlamaya akınca paket satışı düşer | İzlenecek. Gerekirse seviye altınını %20 düşür ya da paketlere joker parça ekle (paket sistemine dokunmadan, ayrı onay) |
| R5 | Ganimet kutusu mevzuatı | K5: sandıklar parayla satılmaz; olasılıklar sürümlü ve görünür; yaş ve ülke kontrolü ödeme fazında |
| R6 | Saat hilesi | Bütün süreler sunucuda `now()` |
| R7 | Çift ödül (tekrar istek, kopan bağlantı) | Unique kısıt + idempotency anahtarı + satır kilidi + defter |
| R8 | Battle Pass ödülünün sezon sonunda kaybolması | Otomatik posta kutusu + telafi |
| R9 | Kart satış dosyası (020) ile çakışma | 020 senin yarım işin. Ekonomi V2 onun tablolarına dokunmuyor; birleştirme senin onayınla |
| R10 | Mevcut veride çok sayıda test hesabı (liderlik kirliliği) | Ekonomi verisi yeni tablolarda; temizlik ayrı karar |

### Geçiş planı (veri kaybı yok)

1. Yeni tablolar boş açılır. `user_cards`, `pack_*`, `sbc_*`,
   `card_transfers` değişmez.
2. **`player_progress` doldurma:** sahip olunan her `(owner_id, card_id)`
   için `level = 1`, `copies = 0`.
   - Var olan fazla kopyalar **fiziksel olarak kalır**; hiçbir kart
     silinmez ya da dönüştürülmez.
   - Dönüşüm yalnız oyuncunun isteğiyle yapılır (§2.1).
   - Bugün 397 fazla kopya var.
3. `reward_energy`: herkese dolu (10) başlangıç.
4. Sandık tetikleyicisi, oyun kuralı sürümü gibi bir **özellik
   anahtarıyla** (`economy_config_versions`) açılır. Kapatılınca yeni
   sandık üretilmez, var olanlar açılabilir kalır.
5. Geri dönüş: anahtar kapatılır. Hiçbir eski tabloya yazılmadığı için
   geri alınacak veri yok.

---

## 13. Dosya bazlı geliştirme planı

### FAZ 0 — Temel (oyun davranışı değişmez)

| Dosya | İş |
|---|---|
| `database/migrations/028_economy_foundation.sql` | `economy_ledger`, `idempotency_keys`, `economy_config_versions` (+ `economy_v2_enabled = false`), yardımcılar `_ledger_add(...)`, `economy_flag(text)` |
| `server/lib/utils/idempotency.dart` | `Idempotency-Key` ara katmanı: anahtar ve gövde özeti; tekrar isteğe kayıtlı cevap |
| `server/lib/routes/economy_routes.dart` | `GET /api/economy/config` (salt okunur) |
| `server/bin/server.dart` | Rotanın bağlanması |
| `packages/shared_models/lib/src/economy_models.dart` (+ `shared_models.dart` export) | `EconomyConfig`, `LedgerEntry` (freezed) |
| `server/test/idempotency_test.dart` | Aynı anahtar → aynı cevap; farklı gövde → 409 |
| `test/economy_models_test.dart` | JSON sözleşmesi |
| `tool/ekonomi/` | Simülatör (bu belge) |

**Kabul:** bütün mevcut testler aynen geçer; anahtar kapalıyken hiçbir
cevap değişmez.

### FAZ 1 — Sandık V2 + ödül enerjisi

| Dosya | İş |
|---|---|
| `database/migrations/029_reward_energy.sql` | `reward_energy` + `energy_get / energy_spend` (tembel dolum) |
| `database/migrations/030_chests.sql` | `chest_types`, sürümlü oran tabloları + **sürüm 1** tohum verisi, `user_chests`, `user_chest_state`, `player_progress` (+ doldurma) |
| `database/migrations/031_chest_functions.sql` | `grant_match_chest()` tetikleyicisi (≥4 tur, enerji, unique), `list_chests`, `start_chest_unlock`, `open_chest` (`secure_random_int`, kadro kilidi koruması, joker, altın, defter), `claim_mailbox_chest`, `expire_mailbox()` (telafi) |
| `server/lib/routes/chest_routes.dart`, `server/lib/routes/energy_routes.dart` | §9 uçları |
| `server/lib/utils/row_mappers.dart` | Sandık eşleyicileri |
| `server/lib/realtime/...` (008 bildirim yolu) | `chest_granted` olayı |
| `packages/shared_models/lib/src/chest_models.dart` | `Chest`, `ChestOpenResult`, `ChestOdds`, `RewardEnergy` |
| `lib/features/chests/data/...` | `ChestRepository` (+ uzak kaynak) |
| `lib/features/chests/presentation/viewmodel/chests_view_model.dart` | Sunucu saatine göre sayaç, tekrar bağlanma |
| `lib/features/chests/presentation/view/chests_view.dart`, `chest_open_view.dart`, `chest_odds_view.dart` | §11 ekranları (Ref dili) |
| `lib/features/home/presentation/widgets/chest_strip.dart` | Ana sayfa şeridi |
| `lib/features/match/presentation/widgets/match_result_view.dart` | "Sandık kazandın" bölümü (yalnız ekleme) |
| `lib/core/router/app_routes.dart`, `app_router.dart`, `lib/core/di/injection.dart` | Yeni rotalar ve DI |
| `test/api_integration_test.dart` (ekleme) | Maç → tek sandık; ikinci tetikleme reddedilir; açma iki kez aynı sonuç; süre dolmadan açılamaz; tek kilit; posta taşması → telafi + defter; enerjisiz maç → sandık yok, MMR aynen |
| `test/chests_test.dart`, `test/goldens/chest_golden_test.dart` | ViewModel ve 6 boyut golden |
| `tool/tasarim/gercek_cek.mjs` (ekleme) | Gerçek uygulamada sandık ekranları |

**Kabul:** iki test hesabıyla PvP sonrası iki tarafa birer sandık; yeniden
bağlanmada kayıp ya da çift yok; mevcut 622 + 21 test geçer.

### Sonraki fazlar (her biri ayrı onay)

| Faz | Kapsam |
|---|---|
| 2 | Seviye atlama + ustalık ödülleri + gönüllü kopya dönüşümü. **K1 ve K2'ye bağlı** |
| 3 | Item kataloğu ve envanter |
| 4 | Battle Pass + görevler (premium satın alma kapalı) |
| 5 | Ödeme altyapısı. **K4, ayrı yasal inceleme** |
| 6 | Kozmetiklerin oyunda gösterimi (forma, arena, zafer animasyonu) |

---

## 14. Uygulama durumu (10 Kasım 2026)

| Faz | Durum | Kanıt |
|---|---|---|
| FAZ 0 | ✅ Yapıldı (`75f67f5`) | `database/tests/028_economy_foundation_test.sql`, `server/test/idempotency_test.dart` (8), `test/economy_models_test.dart` |
| FAZ 1 | ✅ Yapıldı | 029–032 migration; veritabanı testleri `031_chests_test.sql` (49 kontrol + 20.000 çekilişlik dağılım) ve `032_emergency_squad_test.sql`; `test/chests_test.dart` (7); `test/goldens/sandik_golden_test.dart` (26, 6 boyut); uçtan uca gerçek sunucu testi `tool/ekonomi/sandik_e2e.mjs` |
| FAZ 2 | ✅ Yapıldı | 033 migration; `033_player_levels_test.sql` (34 kontrol, K1 dahil: maç/eşleştirme fonksiyonları seviyeyi okumuyor); `test/progress_test.dart` (5); `test/goldens/gelisim_golden_test.dart` (9); gerçek sunucuda `tool/ekonomi/gelisim_e2e.mjs` (11 kontrol) |
| FAZ 3 | ✅ Yapıldı | 034 migration; `034_items_test.sql` (31 kontrol); `test/goldens/envanter_golden_test.dart` (envanter 6 boyut + davranış + sandık seçenekleri); gerçek sunucuda `tool/ekonomi/envanter_e2e.mjs` (16 kontrol, tekrar koşulabilir) |
| FAZ 4 | ✅ Yapıldı | 035 migration; `035_season_pass_test.sql` (46 kontrol, K1 dahil); `test/goldens/sezon_golden_test.dart` (Sezon Yolu 6 boyut + ödül yolu + ana sayfa görevleri + maç sonu XP + davranış); gerçek sunucuda `tool/ekonomi/sezon_e2e.mjs` (15 kontrol, gerçek maç XP'si dahil, tekrar koşulabilir) |

**Tasarımdan sapmalar:**

- **Olasılıkların yeri:** ayrı tablolar yerine `economy_config_versions`
  (`kind = chest_rules`) içinde tutuluyor. Yayınlanmış sürüm
  değiştirilemiyor (tetikleyici) ve her sandık kendi sürümünü saklıyor.
- **Acil Kadro (§1.6):** tasarımda yoktu; kabul testinde ortaya çıkan
  kilitlenme yüzünden eklendi (K2'nin kapsamında).
- **Sayaç açıkken kilitli kalan sandık:** sayacı bitmiş ama açılmamış
  sandık "tek kilit" kuralında sayılmaya devam ediyor. Oyuncu önce onu
  açmalı; ekran bunu "AÇ!" ile gösteriyor.

**FAZ 2 notları:**

- **K1:** seviye yalnız gelişim ve ustalık göstergesi. Kart rozeti 2. seviyeden itibaren görünür; kart gücü,
  kimya ve eşleştirme gücü değişmez (veritabanı testinde doğrulanıyor).
- **Kopya dönüşümü fiziksel kartı SİLMEZ.** `user_cards` satırı silinseydi `match_hands` CASCADE ile geçmiş
  maç kayıtları da silinirdi; ayrıca oynanmış kartta `match_moves` silmeyi engellerdi. Dönüştürülen kopya,
  giriş yapılamayan ve banlı `sistem_arsiv` hesabına devredilir ve `card_transfers` tablosuna
  `converted_to_progress` nedeniyle yazılır. Kart cezasıyla aynı sahiplik devri yöntemi kullanılır.
  Oyuncuda en az 2 kopya kalır; destedeki ve maçtaki kartlara dokunulmaz.
- **Tek sefer garantisi:**
  - Seviye atlama: defter anahtarı hedef seviyeyi içerir (aynı seviye iki kez ödenmez).
  - Ustalık ödülü: kullanıcı + kart + seviye başına tek kayıt.
  - Kopya dönüşümü: istemcinin istek kimliğine bağlı.
- **Seviye 10 taşması:** seviye 10'daki futbolcunun sandıktan gelen kopyası joker parçaya döner
  (`open_chest` yeniden tanımlandı; tek fark bu).
- **Listede jokerle atlama:** yalnız en az 1 kopyası olan futbolcuda önerilir. 1 joker, kopyası olmayan
  onlarca futbolcuda ayrı ayrı "hazır" görünüyordu (gerçek veride bulundu).

**FAZ 3 notları:**

- **Tablolar:** `item_definitions` (23 item tohumu), `user_items` (süresiz itemler tek satırda yığılır,
  süreli olanlar ayrı satır), `user_equipped` (kozmetik yuvası başına bir item).
- **K1:** hiçbir item maç gücünü değiştirmez. Kozmetikler yalnız giyilir; oyunda gösterimi FAZ 6'dadır.
- **Joker parçaları taşındı, silinmedi:** `user_joker_shards` satırları `joker_<nadirlik>` itemi olarak
  `user_items`'a kopyalandı, eski tablo `user_joker_shards_legacy` adıyla duruyor. Migration tekrar
  koşulursa ikinci kez saymaz.
- **Kullanım (`use_item`):**
  - Sandık anahtarı: sandık anında hazır olur (Efsane 2 anahtar).
  - Hızlandırıcı: kalan süreden 2 saat düşer.
  - Enerji içeceği: +3 ödül enerjisi, günde en fazla 2.
  - Ustalık kitabı: aynı nadirlikteki futbolcuya bir seviyelik kopya verir; altın yine ödenir.
  - Gelişim indirimi: seviye atlarken `use_discount` ile %25 düşer, tek kullanım, 7 gün geçerli.
  - Hepsi Idempotency-Key ile tek sefer işlenir ve deftere yazılır.

**FAZ 3 sapmaları:**

- **Taşma posta kutusuna değil altına:** yığın sınırını aşan item ve ikinci kez gelen kozmetik,
  tanımdaki karşılığı kadar altına çevrilir. Item için ayrı posta kutusu açmak yerine bu seçildi.
- **"Tek kilit" kuralına anahtar istisnası:** anahtarla açılan sandık (`unlocked_by_item`) tek sayaç
  kuralında sayılmaz. Başka bir sandığın sayacı çalışırken de anahtar kullanılabilir.
- **`level_up_player` 4 argümanlı oldu** (jokerler + indirim). Eski 3 argümanlı sürüm kaldırıldı.
- **Geliştirme ucu:** `POST /api/items/dev/grant` yalnız üretim dışında açık; testler için.

**FAZ 4 notları:**

- **Tablolar:** `seasons`, `season_tiers` (ödül tablosu sezon açılırken dondurulur), `user_seasons`,
  `season_claims` (kullanıcı + sezon + kademe + yol birincil anahtarı = tek sefer), `missions`, `user_missions`.
  Kurallar `economy_config_versions` içinde `season_rules` sürüm 1 (§3 tablosu, `bp_tablo.py` ile aynı).
- **Sezon tembel açılır:** aktif sezon yoksa ilk istekte 30 günlük yeni sezon açılır (ayrı zamanlayıcı yok).
  Biten sezon saatlik sunucu işinde (`close_due_seasons`) kapanır: ulaşılmış ama alınmamış ödüller otomatik
  verilir (sandık yuva doluysa posta kutusuna). Tekrar çalışırsa sonuç değişmez.
- **XP:** enerjili maç 100/70/60; ödül enerjisi yüzünden sandık atlanan maçta %25. Mevcut maç sonu ödülleri
  (altın, MMR, koruma, kart kaybı) değişmedi.
- **K1:** sezon verisini maç ve eşleştirme fonksiyonlarından hiçbiri okumuyor (veritabanı testinde doğrulanıyor).
- **K4:** premium yol görünür ama kilitli ("PREMIUM (YAKINDA)"). Yalnız geliştirme ortamında test için açılabilir
  (`POST /api/season/dev/premium`, üretimde yok).

**FAZ 4 sapmaları:**

- **Görev listesi:** §5'teki örneklerden "taktik kullan", "kimyası +2 kartla tur kazan" ve "5 farklı mevkide tur
  kazan" bu fazda yok (tur bazlı sayaç gerekir). Yerine: haftalık 25 maç / 10 galibiyet / 3 sandık, sezon 120 maç /
  bir futbolcuyu 5. seviyeye çıkar / 3 kart görevi. XP toplamları §5 ile aynı (günlük 600, haftalık 6.000, sezon 10.000).
- **Görev XP'si otomatik:** görev tamamlanınca XP hemen eklenir, ayrıca "al" düğmesi yok.
- **K6 XP'ye de uygulandı:** 4. turdan önce biten maç XP vermez ve görev ilerletmez (teslim çiftçiliğine karşı).
- **Premium Plus:** yalnız %10 XP bayrağı var; "anında 5 kademe" satın almayla birlikte FAZ 5'te.
- **Sezon 2 kozmetikleri:** yeni `season_rules` sürümü yayınlanmazsa Sezon 2 aynı "Sezon 1" kozmetiklerini verir;
  sahip olunan kozmetik tekrar gelince altına döner. Yeni sezondan önce yeni sürüm eklenmeli.
- **Gün ve hafta sınırı:** veritabanı sunucusunun saat dilimine göre (034'teki enerji içeceği sınırıyla aynı).

**Varsayılan:** `economy_v2_enabled` migration'da **kapalı**. Yerel
geliştirme veritabanında kabul testi için sürüm 2 ile açıldı. Kapatmak
için daha yüksek bir sürümle `false` eklenir.
