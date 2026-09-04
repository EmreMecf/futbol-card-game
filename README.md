# Futbol Kart

Gerçek zamanlı, çok oyunculu futbol kart/strateji oyunu.

```
Flutter  ──HTTP/JSON──▶  Dart Sunucu  ──SQL──▶  PostgreSQL
   ▲                          │                     │
   │                          │◀───NOTIFY───────────┘
   └────WebSocket─────────────┘
```

Supabase kullanılmıyor. Veritabanı, backend ve istemci tamamen bizim.

---

## Çalıştırma (3 adım)

**1. Veritabanı**

```bash
.\scripts\veritabani-baslat.ps1
```

**2. Backend** (ayrı bir terminalde)

```bash
.\scripts\sunucu-baslat.ps1
```

**3. Uygulama**

```bash
flutter run
```

> Android emülatöründe test ediyorsan `.env` içindeki `API_BASE_URL` değerini
> `http://10.0.2.2:8080` yap. Emülatör için `localhost` kendisini gösterir,
> bilgisayarını değil.

---

## Klasörler

| Klasör | Ne var |
|---|---|
| `lib/` | Flutter uygulaması (MVVM) |
| `server/` | Dart + Shelf backend — [README](server/README.md) |
| `packages/shared_models/` | **Sunucu ve uygulamanın ortak modelleri** — [README](packages/shared_models/README.md) |
| `lib/core/theme/` | Tasarım sistemi: renk, yazı tipi ölçeği, kırılma noktaları |
| `lib/features/profile/` | Profil: karne, kazanma oranı, maç geçmişi |
| `lib/features/settings/` | Ayarlar: ses, titreşim, animasyon (cihazda saklanır) |
| `lib/shared/widgets/app_shell.dart` | Gezinme kabuğu: telefonda alt çubuk, masaüstünde kenar çubuğu |
| `assets/fonts/` | Barlow Condensed (başlık/rakam) + Nunito (metin) |
| `lib/shared/widgets/premium_card/` | FIFA seviyesi kart widget'ları — [README](lib/shared/widgets/premium_card/README.md) |
| `lib/shared/widgets/walkout/` | Görkemli paket açılışı: spot ışığı, bayrak, arma, konfeti |
| `database/` | PostgreSQL şeması ve oyun kuralları — [README](database/README.md) |
| `scripts/` | Veritabanı ve sunucu başlatma betikleri |
| `supabase/` | **Ölü kod** — eski Supabase şeması, silinebilir |

---

## Oyun kuralları nerede yaşıyor?

**Hepsi PostgreSQL fonksiyonlarında** (`database/migrations/`). Uygulama ve
backend kuralları *bilmez*, sadece sorar.

| Kural | Nerede |
|---|---|
| Legend kart alt 4 seviyeyi yener | `compare_cards()` |
| 1 GK + 4 DEF + 4 MID + 2 FWD zorunlu | `validate_deck()` |
| Sıra kontrolü, pozisyon zorunluluğu | `play_card()` |
| Beraberlikte kartlar masada kalır | `_resolve_round()` |
| Kaybeden 3 korumasız kartını kaptırır | `_finish_match()` |
| **Kimya:** aynı kulüp / lig+uyruk = +2, uyruk veya lig = +1 | `chemistry_link_score()` |
| Kartın maçtaki gücü = güç + kimya | `_resolve_round()` |
| Maç sonucu ve kart transferleri | `get_match_result()` |
| Oyuncunun bitmiş maçları | `get_match_history()` |
| SBC şart doğrulama ve kart eritme | `evaluate_sbc_squad()`, `submit_sbc()` |
| Paket açma / kart çıkma ihtimalleri | `open_pack()`, `_roll_tier()` |
| **Kart özellikleri:** şut/hız/fizik/defans/dribling/hızlanma | `fill_card_attributes()`, `position_attribute_profile()` |
| Başlangıç paketi: 15 kart, Diamond/Legend yok | `grant_starter_pack()` |
| 45 sn + 15 sn AFK → hükmen mağlubiyet | `claim_turn_timeout()`, `sweep_timed_out_matches()` |

Bunun getirisi: bir kuralı değiştirmek için tek bir SQL fonksiyonunu
güncellemen yeterli. Uygulamayı yeniden yayınlamana gerek yok.

> **Kart özellikleri turu KAZANDIRMAZ.** Şut, hız, fizik, defans,
> dribling ve hızlanma şu an sadece kartın karakterini gösterir; turu
> hâlâ `güç + kimya` belirliyor. Bir özelliği maça bağlamak istersek
> değişecek tek yer `_resolve_round()`.
>
> Değerler elle yazılmadı: `position_attribute_profile()` pozisyona göre
> bir profil veriyor, üstüne kartın kendi kimliğinden türetilen sabit
> bir sapma ekleniyor. Bu yüzden aynı kart her sıfırlamada **aynı**
> değerleri alır ve yeni kart eklendiğinde sadece
> `select fill_card_attributes();` çağırmak yeterlidir.

---

## Tek kod, iki ekran: telefon ve tarayıcı

Aynı ViewModel'i paylaşan **iki yerleşim** var. Hangisinin çizileceğine
`AppBreakpoints` karar veriyor.

| Genişlik | Sınıf | Gezinme | Ana sayfa | Maç ekranı |
|---|---|---|---|---|
| < 600 px | `mobile` | Alt sekme çubuğu | Tek sütun | Masa dikey, el altta |
| 600–1024 px | `tablet` | Alt sekme çubuğu | Geniş tek sütun | Üç sütun |
| > 1024 px | `desktop` | Sol kenar çubuğu | İki sütunlu ızgara | Üç sütun + yan panel |

Alt çubuk **en fazla 5 madde** taşır; fazlası dokunma hedeflerini 44 px'in
altına düşürür. Telefona sığmayan Koleksiyon ve Görevler kenar çubuğunda
yer alır.

**Maç ekranı kaydırılamaz.** Oyuncu 45 saniyede karar verirken kaydırma
yapmak zorunda kalmamalı; bu yüzden kart ölçüleri sabit değil, mevcut
yüksekliğe göre hesaplanıyor.

### Yazı tipleri

| Aile | Nerede | Neden |
|---|---|---|
| Barlow Condensed | Kart gücü, skor, sayaç, başlık, buton | Rakamları dar; 3 haneli güç değeri karta sığıyor |
| Nunito | Açıklama, etiket, gövde metni | Yumuşak köşeli, uzun metinde yormuyor |

Nunito **değişken (variable)** bir font. Flutter'da yalnızca `fontWeight`
vermek her platformda çalışmıyor; `AppTypography` her stile `fontVariations`
ile `wght` eksenini de yazıyor.

### Kimya artık maç ekranında görünüyor

Turu `güç + kimya` belirliyor ama bu bonus hiçbir yerde gösterilmiyordu.
Şimdi her kartın köşesinde **+N** rozeti var, seçili kartta altında
**MAÇTA 86** yazıyor, masaüstü yan panelinde ise dökümü duruyor:
`83 + 3 kimya = 86`.

Ayrıca kart artık dokunulur dokunulmaz oynanmıyor: önce **seçiliyor**,
sonra ayrı bir butonla onaylanıyor. Hamle geri alınamaz; telefonda listeyi
kaydırırken yanlışlıkla kart oynanıyordu.

---

## Ekranlar

Hepsi tek kod tabanında, iki yerleşimle. Hangisinin çizileceğine
`AppBreakpoints` karar veriyor.

| Ekran | Telefon | Masaüstü |
|---|---|---|
| Ana sayfa | Tek sütun, alt sekme çubuğu | İki sütunlu ızgara, kenar çubuğu |
| Maç | Dikey masa, el altta | Üç sütun: tur geçmişi / masa / seçili kart |
| Koleksiyon | Yatay filtre çipleri | Sol filtre sütunu, 5'li ızgara |
| Kadro | Saha ortada, kimya üstte | Saha solda, kimya ve kaydet sağda |
| Mağaza | Yatay paket kartı | Üç sütunlu ızgara, dikey kart |
| Görevler | Kart listesi | Aynı, geniş |
| Görev kurma | Şartlar üstte | Saha solda, şartlar sağda |
| Profil | Karne + maç geçmişi | Aynı, ortalanmış |
| Ayarlar | Tek sütun | Aynı, ortalanmış |
| Eşleşme, maç sonucu, paket açılışı | Tam ekran | Ortalanmış, en fazla 720 px |

Tasarım tuvali 20 artboard olarak ayrı tutuluyor; koda dökülmeden önce
orada karara bağlanıyor.

### Bilerek yapılmayanlar

| İstenen | Neden yok |
|---|---|
| Günlük ödül, sezon geçidi | Sunucuda karşılığı yok. Uydurma sayı göstermek yerine o alana gerçek karne kondu. |
| Profilde rozet ve başarı | Sunucuda böyle bir sistem yok. |
| Kullanıcı adı / şifre değiştirme | Sunucuda uç yok. Ayarlarda bilgi olarak gösteriliyor. |
| Liderlik tablosu | Sıralama sorgusu ve API ucu gerekiyor. |
| Gerçek oyuncu görselleri | Kartlar siluet çiziyor. |

---

## Paket açılışı: üç kademe

Paketten çıkan **en yüksek seviyeli karta** göre farklı bir açılış oynar.
Karar `PackOpeningViewModel` içinde, çizim `lib/shared/widgets/walkout/`
altında.

| Çıkan en iyi kart | Açılış | Süre |
|---|---|---|
| Bronz / Gümüş | Hızlı kart dönme (flip) | 0,35 sn |
| Altın | Parlamalı dönme + hafif titreşim | 0,75 sn |
| **Diamond / Legend** | **WALKOUT sahnesi** | ~4,6 sn |

**Walkout akışı:** ekran kararır ve stadyum ışıkları yanar → **bayrak**
(1 sn) → **pozisyon** (1 sn) → **kulüp arması** (1 sn) → kart ekrana
*vurur*, telefon titrer (`HapticFeedback.heavyImpact`), konfeti patlar.
Ekrana dokunmak sahneyi doğrudan kartın vuruş anına atlar.

Walkout **paket başına bir kez** oynar; hak paketin en iyi kartınındır.
İki Legend çıkarsa ikincisi altın kademesinde açılır — aynı 4,6 saniyelik
sahneyi tekrar izletmek heyecan değil sabırsızlık üretir.

Bayraklar ve kulüp armaları **görsel dosyası kullanmaz**, `CustomPainter`
ile çizilir. Arma kulüp adından türetilir, yani `Anadolu SK` her zaman
aynı armayı alır.

---

## Anti-hile

İstemciye asla güvenilmiyor. Doğrulanmış davranışlar:

| Saldırı denemesi | Sonuç |
|---|---|
| Rakibin elini okumak | İki oyuncunun gördüğü kart kümeleri hiç kesişmiyor |
| Sırası değilken oynamak | `"Sıra sizde değil."` |
| Yanlış pozisyonda kart oynamak | `"Bu turda GK pozisyonunda kart oynamalısınız."` |
| Kartı olduğu halde pas geçmek | `"Elinizde bu pozisyonda kart var, pas geçemezsiniz."` |
| Başkası adına işlem yapmak | Kullanıcı kimliği JWT'den çözülür, istemciden alınmaz |
| Jetonsuz istek | `401` |
| Paket açılışını istemcide manipüle etmek | Çekiliş tamamen veritabanında; rastgeleliği bile sunucu üretir |

Şifreler bcrypt (maliyet 12), refresh token'lar veritabanında SHA-256 özeti
olarak saklanıyor.

---

## Test hesabı

Veritabanı sıfırlandığında hazır bir test hesabı yok — uygulamadan kaydol,
sonra Koleksiyon ekranındaki **"TEST: Tüm kartları ekle"** butonuna bas.
Katalogdaki 100 kartın tamamı hesabına eklenir.

Bu buton `/api/game/dev/grant-all-cards` ucunu çağırır ve
`ENVIRONMENT=production` iken **404 döner** — yayına çıkınca kendiliğinden
kapanır.

---

## Test

```bash
flutter test
```

```bash
cd packages/shared_models; dart test
```

```bash
cd server; dart run tool/realtime_test.dart
```

```bash
cd server; dart run tool/full_match_test.dart
```

`full_match_test.dart` iki oyuncu oluşturur, WebSocket ile bağlar, eşleştirir
ve maçı **sonuna kadar oynatır**. Şu zincirin tamamını doğrular:
`REST → PostgreSQL → pg_notify → LISTEN → WebSocket → istemci`

`test/api_integration_test.dart` uygulamanın gerçek ağ katmanını canlı
backend'e karşı çalıştırır (otomatik jeton yenileme dahil). Backend kapalıysa
testler atlanır, başarısız olmaz.

---

## Durum

| Parça | Durum |
|---|---|
| PostgreSQL şeması + oyun kuralları | ✅ Tamamlandı, test edildi |
| Backend (REST + WebSocket + JWT) | ✅ Tamamlandı, test edildi |
| Flutter: giriş / kayıt / oturum | ✅ Tamamlandı, test edildi |
| Freezed modelleri (`packages/shared_models`) | ✅ Tamamlandı, 17 test |
| Sunucu ve uygulama aynı modelleri kullanıyor | ✅ Tamamlandı |
| Paket sistemi (Gacha) + çıkma ihtimalleri | ✅ Tamamlandı, istatistiksel doğrulama |
| Premium kart widget'ı (FIFA seviyesi) | ✅ Tamamlandı, 15 test |
| 100 kartlık test kadrosu | ✅ Tamamlandı |
| Koleksiyon ekranı (filtre, arama, sıralama) | ✅ Tamamlandı, 12 test |
| Flutter: koleksiyon, kadro, profil ekranları | ✅ Tamamlandı |
| Kimya sistemi (uyruk / lig / kulüp) | ✅ Tamamlandı, test edildi |
| SBC (kadro kurma görevleri) + ekonomi | ✅ Tamamlandı, test edildi |
| Kart özellikleri (6 özellik) | ✅ Tamamlandı, 20 test |
| Kademeli paket açılışı + Walkout animasyonu | ✅ Tamamlandı, 24 test |
| Flutter: eşleşme ve maç ekranı | ✅ Tamamlandı, test edildi |
| Tasarım sistemi (renk, yazı tipi, kırılma noktaları) | ✅ Tamamlandı, 29 test |
| Duyarlı gezinme kabuğu (telefon + masaüstü) | ✅ Tamamlandı, 12 test |
| Ana sayfa ve maç ekranı yeni tasarımı | ✅ Tamamlandı, tarayıcıda doğrulandı |
| Koleksiyon, kadro, mağaza, görevler duyarlı | ✅ Tamamlandı |
| Profil ekranı + maç geçmişi API'si | ✅ Tamamlandı, 17 test |
| Ayarlar ekranı (cihazda saklanan tercihler) | ✅ Tamamlandı |
| Günlük ödül / sezon geçidi | ❌ Sunucuda karşılığı yok, arayüzde de yok |
| Liderlik tablosu | ❌ Kenar çubuğunda maddesi var, arkasında API yok |
| Gerçek oyuncu görselleri | ❌ Siluet yer tutucu |
