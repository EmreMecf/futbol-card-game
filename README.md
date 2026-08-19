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
| `lib/shared/widgets/premium_card/` | FIFA seviyesi kart widget'ları — [README](lib/shared/widgets/premium_card/README.md) |
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
| SBC şart doğrulama ve kart eritme | `evaluate_sbc_squad()`, `submit_sbc()` |
| Paket açma / kart çıkma ihtimalleri | `open_pack()`, `_roll_tier()` |
| Başlangıç paketi: 15 kart, Diamond/Legend yok | `grant_starter_pack()` |
| 45 sn + 15 sn AFK → hükmen mağlubiyet | `claim_turn_timeout()`, `sweep_timed_out_matches()` |

Bunun getirisi: bir kuralı değiştirmek için tek bir SQL fonksiyonunu
güncellemen yeterli. Uygulamayı yeniden yayınlamana gerek yok.

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
| Flutter: koleksiyon, kadro, profil ekranları | 🔨 Sırada |
| Flutter: eşleşme ve maç ekranı | 🔨 ADIM 4 |
