# Dil desteği (Türkçe / English)

Oyun Türkçe ve İngilizce çalışır. Oyuncu dili **Ayarlar → DİL** bölümünden seçer. Seçim hemen uygulanır ve cihazda saklanır. İlk açılışta cihaz dili Türkçeyse Türkçe, değilse İngilizce açılır.

## Nasıl çalışır?

Metinler kodda Türkçe yazılır ve `.tr` ile işaretlenir. Türkçe metin aynı zamanda çevirinin **anahtarıdır**:

```dart
Text('KARTI OYNA'.tr)
Text('{n} kart'.trArgs({'n': adet}))   // yer tutuculu
```

İngilizce seçiliyse anahtar `lib/core/l10n/strings_en.dart` sözlüğünde aranır. Çevirisi yoksa Türkçesi görünür; ekran boş kalmaz.

| Dosya | İçerik |
|---|---|
| `lib/core/l10n/app_language.dart` | Dil seçimi, `.tr` ve `.trArgs` |
| `lib/core/l10n/strings_en.dart` | Arayüz metinlerinin İngilizcesi |
| `lib/core/l10n/server_strings_en.dart` | Sunucu metinlerinin İngilizcesi (hata mesajı, görev, eşya, paket) |
| `lib/core/l10n/server_text.dart` | Sunucu yanıtlarını çeviren katman |
| `lib/core/l10n/language_rebuilder.dart` | Dil değişince bütün ekranı yeniden çizer |
| `packages/shared_models/lib/src/display_text.dart` | Modellerdeki etiketlerin (mevki, taktik, şart) çeviri kancası |

## Yeni metin eklerken

1. Metni Türkçe yaz ve `.tr` (yer tutucu varsa `.trArgs`) ekle.
2. `strings_en.dart` içine aynı Türkçe metni anahtar olarak, İngilizcesini değer olarak ekle. Yer tutucular (`{n}`) iki dilde aynı olmalı.
3. `flutter test test/l10n_test.dart` çalıştır. Çevirisi eksik ya da işaretlenmemiş Türkçe metin varsa test hangi dosyada olduğunu söyler.

`const` bir yerde `.tr` kullanılamaz (çeviri çalışma anında yapılır). Böyle yerlerde ya `const` kaldırılır ya da metin ham bırakılıp **gösterilirken** `.tr` yapılır (ör. `Text(widget.title.tr)`).

Günlük kayıtları (`AppLogger`), HTTP başlıkları, rota adları ve futbolcu adları çevrilmez.

## Sunucu metinleri

Görev adları, SBC açıklamaları, eşya adları ve hata mesajları veritabanında Türkçe yazılı. Uygulama API ve WebSocket yanıtlarındaki `message`, `name`, `title`, `description`, `label`, `notice` gibi alanları İngilizce seçiliyse çevirir. Kullanıcı adı, kart adı, kod ve slug alanlarına dokunmaz.

İçinde sayı geçen mesajlar şablonla çevrilir:

```
'Yeterli elmas yok. Gerekli: %, mevcut: %'  →  'Not enough gems. Needed: {1}, you have: {2}'
```

Sunucuya yeni bir mesaj ya da içerik eklendiğinde İngilizcesi `server_strings_en.dart` dosyasına eklenmeli. Eklenmezse oyuncu o metni Türkçe görür; oyun bozulmaz.

## Bilinen sınırlar

- Dil değişmeden önce ekrana gelmiş sunucu verisi (ör. açık bir görev listesi), ekran yenilenince İngilizceye döner.
- Sunucu tarafındaki metinler değiştirilmedi; çeviri tamamen uygulamada.
