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

## Açık kalanlar

* Yönetici rolü yok: ayar değişikliği bugün veritabanı erişimiyle (`set_monetization_config`). Yönetici uçları Faz 6.
* Satın alma doğrulaması Faz 3 (Google/Apple anahtarları **BLOCKED**).
* `ad_ssv_events` ve `monetization_events` için saklama süresi (KVKK veri minimizasyonu) — Faz 6'da temizleme işi.
