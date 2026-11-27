# Güvenlik İncelemesi (Faz 1–2)

| Tehdit | Önlem | Kanıt |
|---|---|---|
| Sahte istemci ödülü | İstemci olayları (`earned`) ödül vermez; ödül yalnız imzalı SSV ile | `060_monetization_core_test.sql` ("istemci olayi odul vermemeli"), `monetization_test.dart` |
| Geçersiz imza | ECDSA P-256/SHA-256, Google anahtarları; geçersiz → 403 + kayıt (`ad_ssv_events.signature_valid=false`) | `ad_ssv_verifier_test.dart` |
| Ödül miktarı / kullanıcı manipülasyonu | İmzalı içerik değişirse imza tutmaz; ödül miktarı SUNUCU ayarından (geri çağrıdaki `reward_amount` kullanılmaz) | test: "ödül miktarı / kullanıcı değiştirilirse" |
| Tekrar (replay) / çift geri çağrı | `ad_sessions.ssv_transaction_id UNIQUE`; aynı işlem aynı cevabı alır | SQL test "ayni islem ikinci odul vermemeli" |
| Başka hesaba ödül | SSV `user_id` oturum sahibiyle eşleşmeli; eşleşmezse oturum yanmaz | SQL test "farkli kullanici" |
| Süresi dolmuş oturum | `ssv_grace_seconds` (1 sa) sonrası ret | `ad_ssv_grant` |
| Eşzamanlı istek / limit aşımı | Oyuncu başına advisory lock, süreli rezervasyon sayılır | `_ad_used_today` + kilit |
| Cihaz saati | Gün sınırı sunucuda `game_day()` | — |
| Aktif PvP'de reklam | `get_active_match_id` doluysa `in_match` | SQL test |
| Ayar kurcalama | Ayar sürümleri değiştirilemez (028 tetikleyici); her değişiklik denetim kaydı (değiştirilemez); bilinmeyen anahtar/aralık dışı değer reddedilir | SQL test |
| Test sağlayıcı üretimde | `/dev/ssv-simulate` yalnız `DEPLOY_STAGE != production` **ve** `MONETIZATION_TEST_PROVIDERS=true` | `Env.monetizationTestProviders` |
| SQL enjeksiyonu | Tüm sorgular parametreli; kimlikler UUID biçim denetiminden geçer | rotalar |
| Hassas veri günlüğü | İmza, makbuz, jeton saklanmaz/günlüklenmez | `ad_ssv_events` imza sütunu yok |
| Geri çağrı ucu oturum gerektirmez | Bilerek: Google oyuncu jetonu taşımaz; koruma imza + hız sınırı (dakikada 120/IP) | `server.dart` |

## Faz 3 — Satın alma

| Tehdit | Önlem | Kanıt |
|---|---|---|
| Sahte makbuz / istemci "satın aldım" demesi | Ödül yalnız mağaza API'si doğrulayınca (`purchase_grant_verified`); istemci yalnız jeton/işlem kimliği gönderir | `purchase_verifier_test.dart`, `purchase_test.dart` |
| Aynı makbuzun tekrar kullanımı | (platform, mağaza işlemi) UNIQUE + jeton özeti UNIQUE; tekrar aynı cevabı alır | `061_purchases_test.sql` |
| Başka hesabın makbuzu | Google `obfuscatedExternalAccountId`, Apple `appAccountToken` = oyuncu; ayrıca veritabanında hesaplar arası engel | SQL + sunucu testi |
| Bekleyen ödeme | Ödül yok; tamamlanınca mağaza yeniden bildirir | SQL + istemci testi |
| İade / geri alma | RTDN / Apple bildirimi → ücretli elmas geri alınır, yetmezse borç | SQL test |
| Sahte bildirim | Google: Pub/Sub OIDC imzası + hizmet hesabı; Apple: yük güvenilmez, API yeniden sorgulanır | `purchase_routes.dart` |
| Fiyat manipülasyonu | Fiyat istemcide yalnız mağaza SDK'sından; sunucu fiyat almaz, ürün içeriği katalogdan | — |
| Güç satışı | Katalog CHECK: içerikte `coins/jokers/chests/cards/gems` yasak; ücretli elmas altın/sandık açamaz (R1) | SQL test |
| Anahtar eksik | Doğrulayıcı kurulmaz, 503 (fail-closed); test sağlayıcı üretimde kurulmaz | e2e kapı kontrolleri |
| Hassas veri | Jeton yalnız SHA-256 özetiyle saklanır; makbuz/özel anahtar günlüğe yazılmaz | şema |

## Faz 4 — Kozmetik mağaza

| Tehdit | Önlem | Kanıt |
|---|---|---|
| Fiyat manipülasyonu | İstemci yalnız teklif kimliği gönderir; fiyat sunucu tablosundan | `buy_cosmetic` |
| Çift harcama (çift dokunma, ağ tekrarı) | Oyuncu satır kilidi + `(user, request_key)` tekil; aynı anahtar aynı sonucu döndürür | SQL test, uçtan uca |
| Aynı kozmetiği iki kez almak | `(user, item_slug)` tekil + sahiplik kontrolü | SQL test |
| Güç veren item satmak | Tetikleyici: yalnız `kind='cosmetic'` teklif olabilir | SQL test |
| Eksi bakiye | Toplam yetmezse ret; ücretsiz ve ücretli defter satırları ayrı | SQL test |
| Girdi | Teklif kimliği ve anahtar biçim denetimi (`^[a-z0-9_]{3,60}$`), parametreli sorgu | uçtan uca (404) |

## Faz 6 — Yönetim

| Tehdit | Önlem | Kanıt |
|---|---|---|
| Oyuncunun yönetici işlemi yapması | Rol `admin_users`'ta; her yönetici fonksiyonu SQL'de rol denetler; rolsüz 403 | SQL test, uçtan uca |
| Yetki yükseltme | API ile rol verilemez; rol yalnız veritabanından | şema |
| Gerçek parayı yanlışlıkla açmak | Satın alma bayraklarını açmak ve ücretli ürünü yayına almak yalnız `owner` | SQL test, uçtan uca (operator 403) |
| İz bırakmadan değişiklik | Her değişiklik değiştirilemez denetim kaydına, gerekçe zorunlu; reddedilen işlem yazılmaz | SQL test |
| Kaba kuvvet / otomasyon | Yönetim uçlarında dakikada 60 istek | `server.dart` |
| Kişisel verinin süresiz tutulması | Olaylar 180, ham SSV 90, doğrulama olayı 400 gün; mali kayıt silinmez | `purge_monetization_events` |

## Açık kalanlar

* Yönetici işlemleri oyuncu oturumuyla yapılıyor; ayrı yönetici girişi ve iki adımlı doğrulama yok. Rol yalnız güvenilir hesaplara verilmeli.
* Gerçek mağaza doğrulaması kodda hazır, hesap ve anahtarlar **BLOCKED**; gerçek cihazda sandbox testi yapılmadı.
* Saklama süreleri (180/90/400 gün) varsayımdır; KVKK aydınlatma metniyle birlikte hukukçu onaylamalı.
