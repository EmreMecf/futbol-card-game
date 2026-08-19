# shared_models

Sunucu ve Flutter uygulamasının **ortak** kullandığı veri modelleri.

## Neden ayrı bir paket?

Normalde sunucu JSON üretir, uygulama o JSON'u okur ve ikisi birbirinden
habersiz yaşar. Bir alanın adı değişince kimse fark etmez — uygulama sessizce
`null` okur ve ekranda boş kart görünür.

Burada ikisi de **aynı sınıfı** kullanıyor:

```
Sunucu:    HandCard(...).toJson()   ──JSON──▶   Uygulama: HandCard.fromJson(...)
```

Bir alanın adını değiştirdiğinde **iki taraf da derleme hatası verir**.
Çalışma zamanında sessizce bozulmaz.

> ⚠️ Bu paket **saf Dart**'tır. Flutter'a bağımlı hiçbir şey (widget, material,
> `dart:ui`) eklenmemeli — aksi halde sunucu tarafında kullanılamaz.

---

## İçindekiler

| Dosya | Ne var |
|---|---|
| `enums.dart` | `CardPosition`, `CardTier`, `MatchStatus`, `MatchmakingStatus` + **Legend kuralı** |
| `game_rules.dart` | Oyun sabitleri (11 kart, 45 sn, 3 ceza kartı...) |
| `user_model.dart` | `UserModel` |
| `auth_models.dart` | `AuthTokens`, `AuthResponse`, `MeResponse` |
| `card_model.dart` | `CardModel` (katalog), `InventoryCard` (envanter) |
| `deck_models.dart` | `DeckSummary`, `DeckValidation`, `DeckBuilderState` |
| `match_models.dart` | `HandCard`, `MatchState`, `MatchMove`, `MatchRound`, `MatchHistory`, `MatchFindResult`, `PlayCardResult` |
| `realtime_event.dart` | `RealtimeEvent` — WebSocket olayları |

---

## Dikkat çeken üç tasarım kararı

### 1. Legend kuralı iki yerde yazılı — ve bu kasıtlı

`compareCards()` fonksiyonu, veritabanındaki `compare_cards()` ile **aynı
kuralı** uygular. Kopya gibi görünüyor ama değil:

- **SQL tarafı** maçın gerçek sonucunu belirler. Tek yetkili odur.
- **Dart tarafı** sadece arayüz içindir — oyuncu kartına dokunduğunda
  "bu kazanır mı?" önizlemesi gösterebilmek için.

İkisi birbirine güvenmez. İstemci tarafındaki hesabı değiştiren biri
maçın sonucunu değiştiremez.

### 2. Süre sayacı cihaz saatine güvenmiyor

`MatchState.remainingTurnTime` şöyle hesaplanıyor:

```dart
turnDeadline - serverTime
```

Sunucu hem son anı hem de **kendi o anki saatini** gönderiyor. Böylece
oyuncunun telefon saati yanlış (hatta kasıtlı değiştirilmiş) olsa bile
sayaç doğru çalışır.

### 3. Bilinmeyen olaylar uygulamayı çökertmiyor

`RealtimeEventType` içinde bir `unknown` değeri var. İleride sunucuya yeni
bir olay tipi eklediğimizde, mağazadaki eski uygulama sürümleri çökmek
yerine olayı görmezden gelir.

---

## Kod üretimi

Modelleri değiştirdikten sonra:

```bash
cd packages/shared_models; dart run build_runner build
```

Geliştirirken sürekli izlemek için:

```bash
cd packages/shared_models; dart run build_runner watch
```

## Test

```bash
cd packages/shared_models; dart test
```

17 test var: Legend kuralı, sunucudan gelen JSON'un doğru okunması,
kadro kurma mantığı ve süre hesabı.
