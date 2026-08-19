# Backend Sunucusu (Dart + Shelf + PostgreSQL)

Supabase'in yerini alan kendi sunucumuz. Flutter uygulaması artık veritabanını
hiç görmüyor; her şey bu sunucudan geçiyor.

## Çalıştırma

```bash
.\scripts\veritabani-baslat.ps1
```

```bash
.\scripts\sunucu-baslat.ps1
```

Sunucu ayakta mı kontrol et:

```bash
curl http://localhost:8080/api/health
```

---

## Mimari

```
Flutter  ──HTTP/JSON──▶  Dart Sunucu  ──SQL──▶  PostgreSQL
   ▲                          │                     │
   │                          │◀───NOTIFY───────────┘
   └────WebSocket─────────────┘
```

| Katman | Sorumluluğu |
|---|---|
| `config/env.dart` | Ortam değişkenleri (veritabanı, JWT anahtarı, portlar) |
| `db/database.dart` | Bağlantı havuzu + özel tip dönüşümü |
| `auth/` | bcrypt şifre, JWT üretimi, yetki kontrolü |
| `routes/` | REST uç noktaları |
| `realtime/` | `LISTEN`/`NOTIFY` dinleyicisi + WebSocket merkezi |
| `scheduler/` | Süresi dolmuş maçları otomatik kapatan zamanlayıcı |

### Neden iki ayrı veritabanı bağlantısı var?

`LISTEN` yapan bir bağlantı bildirimleri beklerken meşgul sayılır. Havuzdan
alınan bağlantı geri bırakıldığında `LISTEN` kaydı da kaybolur. Bu yüzden
bildirimler için ömür boyu açık kalan **ayrı bir bağlantı** tutuluyor
([database.dart](lib/db/database.dart)).

### Özel PostgreSQL tipleri

PostgreSQL sürücüsü tanımadığı tipleri (`card_tier`, `card_position`, `citext`)
ham bayt olarak döndürüyor. Bunu her sorguda `::text` yazarak çözmek yerine
`Database._normalize()` içinde **tek noktada** hallettik. Yeni bir enum
eklediğinde hiçbir sorguyu değiştirmen gerekmiyor.

---

## API uç noktaları

### Kimlik doğrulama (jeton gerektirmez)

| Metot | Yol | Ne yapar |
|---|---|---|
| POST | `/api/auth/register` | Kayıt + başlangıç paketi |
| POST | `/api/auth/login` | Giriş |
| POST | `/api/auth/refresh` | Access token yenile |
| POST | `/api/auth/logout` | Çıkış |
| GET | `/api/health` | Sunucu ve veritabanı durumu |

### Korumalı (jeton gerekli)

| Metot | Yol | Ne yapar |
|---|---|---|
| GET | `/api/me` | Profilim + devam eden maçım |
| GET | `/api/game/cards` | Kart kataloğu |
| GET | `/api/game/inventory` | Kendi kartlarım |
| POST | `/api/game/starter-pack` | Başlangıç paketini al |
| GET | `/api/game/decks` | Destelerim |
| POST | `/api/game/decks` | Yeni deste |
| PUT | `/api/game/decks/{id}` | Destenin kartlarını değiştir |
| GET | `/api/game/decks/{id}/validate` | Kadro 4-4-2'ye uyuyor mu |
| GET | `/api/game/decks/{id}/cards` | Destedeki kartlar |
| POST | `/api/match/find` | Maç ara / kuyruğa gir |
| POST | `/api/match/cancel` | Kuyruktan çık |
| GET | `/api/match/active` | Devam eden maçım var mı |
| GET | `/api/match/{id}/state` | Maçın genel durumu |
| GET | `/api/match/{id}/hand` | **Sadece kendi** kartlarım |
| GET | `/api/match/{id}/moves` | Oynanan kartların geçmişi |
| POST | `/api/match/{id}/play` | Kart oyna (`user_card_id` yoksa pas) |
| POST | `/api/match/{id}/timeout` | Rakip AFK, maçı talep et |
| POST | `/api/match/{id}/surrender` | Teslim ol |

### WebSocket

```
ws://localhost:8080/ws?token=<access_token>
```

Gelen mesajlar:

```json
{"type": "connected",      "user_id": "..."}
{"type": "queue_updated",  "status": "matched", "match_id": "..."}
{"type": "match_updated",  "match_id": "..."}
{"type": "move_played",    "match_id": "..."}
{"type": "round_resolved", "match_id": "..."}
{"type": "match_finished", "match_id": "..."}
```

Mesajlar kasıtlı olarak **küçük** — sadece "ne oldu" bilgisi taşıyor. Uygulama
detayı `/api/match/{id}/state` ile ayrıca çekiyor. Böylece bildirim
kanalından yanlışlıkla gizli veri (rakibin eli) sızması imkânsız.

---

## Güvenlik

**`p_user_id` her zaman JWT'den gelir, asla istemciden değil.**
Uygulama "ben şu kullanıcıyım" diyemez. Bir oyuncu başkasının elini
isteyemez, başkası adına kart oynayamaz.

Doğrulanmış davranışlar (`tool/realtime_test.dart` ve API testleriyle):

| Saldırı denemesi | Sonuç |
|---|---|
| Rakibin elini okumak | İki oyuncunun gördüğü kart kümeleri **hiç kesişmiyor** |
| Sırası değilken oynamak | `400 — "Sıra sizde değil."` |
| Yanlış pozisyonda kart oynamak | `400 — "Bu turda GK pozisyonunda kart oynamalısınız."` |
| Kartı olduğu halde pas geçmek | `400 — "Elinizde bu pozisyonda kart var, pas geçemezsiniz."` |
| Jetonsuz istek | `401 — "Bu işlem için giriş yapmalısınız."` |
| Kullanılmış refresh token | `401` (jeton rotasyonu) |

Şifreler **bcrypt** (maliyet 12) ile saklanıyor. Refresh token'lar
veritabanında **SHA-256 özeti** olarak duruyor — veritabanı sızsa bile
jetonlar kullanılamaz.

> ⚠️ **Yayına çıkmadan önce:** `JWT_SECRET` ortam değişkenini mutlaka
> değiştir. Varsayilan anahtarla yayına çıkarsan herkes kendine jeton üretir.
> Ayrıca WebSocket için `wss://` (TLS) kullan — jeton sorgu parametresinde
> gidiyor, şifresiz bağlantıda ağ üzerinde açıkta kalır.

---

## Test araçları

```bash
dart run tool/realtime_test.dart
```

İki test oyuncusu oluşturur, WebSocket bağlanır, eşleştirir, kart oynatır ve
bildirimlerin ulaşıp ulaşmadığını raporlar.

```bash
dart analyze
```
