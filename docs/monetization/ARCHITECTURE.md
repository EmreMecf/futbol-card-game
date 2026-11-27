# Monetizasyon Mimarisi

Projenin mevcut deseni korunur: **kurallar PostgreSQL'de (tek işlem, kilit,
tekrar anahtarı), Dart sunucu taşır ve dış sağlayıcıyı doğrular, Flutter
gösterir.** Yeni paralel defter açılmaz: altın `economy_ledger`, elmas
`gem_ledger`.

## Katmanlar

| Katman | Yer | İçerik |
|---|---|---|
| Presentation | `lib/ui_v21/screens/monetization/` | Günlük ödül merkezi, sandık hızlandırma, doğrulama durumu |
| Application | `lib/features/monetization/application/` | `RewardedAdController` (durum makinesi), ViewModel'ler |
| Domain | `lib/features/monetization/domain/` | `AdPlacement`, `AdSession`, `AdEligibility`, `MonetizationConfig`, `AdLifecycleState` |
| Infrastructure | `lib/features/monetization/data/` | `MonetizationApi` (sunucu), `AdProvider` arayüzü |
| External Providers | `lib/features/monetization/providers/` | `AdMobRewardedProvider` (`google_mobile_ads`), `NoAdProvider` (web, kapalı) |
| Persistence (sunucu) | `database/migrations/060_monetization_core.sql` | ayar, yerleşim, reklam oturumu, SSV kayıtları, ücretli elmas, yönetici denetimi |
| Sunucu servisleri | `server/lib/monetization/` | `MonetizationConfigService`, `AdSsvVerifier` (ECDSA P-256), `AdMobKeyStore`, rotalar |

Önerilen servis adları proje adlandırmasına uyarlandı:

| Brif | Projede |
|---|---|
| MonetizationConfigService | SQL `monetization_config()` + `monetization_enabled_for()`; Dart `MonetizationConfigService` |
| AdEligibilityService / AdFrequencyManager | SQL `ad_eligibility()` (bayrak, yerleşim, aktif maç, günlük limit, hesap yaşı, sürüm, platform, yüzde) |
| AdPlacementManager | `ad_placements` ayarı (`monetization` ayar içinde) + istemci `AdPlacement` |
| AdVerificationService | `AdSsvVerifier` + SQL `ad_ssv_grant()` |
| RewardGrantService | SQL `_ad_grant_reward()` → `_ledger_add` / sandık süresi |
| RewardedAdService | İstemci `RewardedAdController` |
| PurchaseService / PurchaseVerifier | Faz 3: `PurchaseVerifier` arayüzü, Google/Apple uygulamaları |
| MonetizationAnalyticsService | `monetization_events` tablosu + SQL `monetization_event()` |

## Ödüllü reklam akışı (SSV)

```
Flutter                    Sunucu (Dart)                 PostgreSQL                 AdMob
  │ GET /ads/eligibility ─►  ad_eligibility() ─────────► bayrak/limit/maç
  │ POST /ads/sessions ───►  ad_session_create() ──────► süreli rezervasyon (kilit)
  │ ◄── session_id, ssv_user_id, custom_data
  │ RewardedAd.load + ServerSideVerificationOptions(userId, customData=session_id)
  │ show ─────────────────────────────────────────────────────────────────────►
  │                          GET /ads/ssv?... ◄──────────────────────────────── imzalı callback
  │                          AdSsvVerifier: key_id → gstatic anahtarı, ECDSA-SHA256
  │                          ad_ssv_grant(tx_id, session, user) ─► tek işlem: oturum
  │                                                                 eşleşmesi, tx_id UNIQUE,
  │                                                                 limit, ödül defteri
  │ GET /ads/sessions/:id (yoklama) ◄── status: verifying | granted | credit | rejected
  ▼ "Ödülün doğrulanıyor…" → yalnız sunucu "granted" deyince ödül animasyonu
```

* İstemcinin `onUserEarnedReward` geri çağrısı yalnız "doğrulanıyor"
  durumuna geçirir; **ödül vermez**.
* Callback istemciden önce de sonra da gelebilir; oturum kaydı ikisini
  bağlar.
* Aynı `transaction_id` ikinci kez gelirse aynı sonuç döner (200), ödül
  ikinci kez verilmez. Google 200 almazsa yeniden dener; geçici hata 5xx döner.
* Sandık hedefi callback anında geçersizse (sandık bitmiş/açılmış) ödül
  kaybolmaz: oturum **kredi** olur, oyuncu başka bir sayaçlı sandığa uygular.

## Ayar (feature flag)

Mevcut `economy_config_versions` (değiştirilemez sürüm geçmişi) yeni
`kind = 'monetization'` ile kullanılır. Değişiklik yeni sürüm ekler, ayrıca
`monetization_admin_audit` satırı (kim, neden, önceki/yeni sürüm).

Değerlendirme sırası (hepsi sunucuda): global anahtar → özellik anahtarı →
platform listesi → en düşük uygulama sürümü → beyaz liste (her zaman açık) →
deterministik yüzde dilimi (`hashtext(user_id || anahtar) % 100`). Ayar
okunamazsa **kapalı**.

## Ücretli / ücretsiz elmas

* `users.gems` = ücretsiz elmas (bugünkü bakiye, değişmez).
* `users.paid_gems` = ücretli elmas (Faz 3, satın almayla).
* Altın değişimi ve sandık açma yalnız ücretsiz elması harcar (056/057
  fonksiyonları zaten yalnız `gems` sütununu kullanıyor).
* Ücretli elmas harcayan fonksiyonlar (kozmetik, premium yol) Faz 4–5'te
  eklenir; önce ücretsizden değil **ücretliden** düşmez, oyuncu seçimi
  gerekmez: kozmetik iki bakiyeden de alınabilir (önce ücretsiz).

## Ortamlar

| Ortam | `ENVIRONMENT` | `DEPLOY_STAGE` | Reklam birimi | SSV | Satın alma |
|---|---|---|---|---|---|
| Yerel | development | local | Google test kimlikleri | test anahtarı / benzetim ucu | test sağlayıcı |
| Staging | production | staging | Google test kimlikleri | gerçek Google anahtarları | sandbox (Faz 3) |
| Üretim | production | production | gerçek (ortam değişkeni) | gerçek | gerçek, onaydan sonra |

Test sağlayıcısı ve benzetim ucu yalnız `DEPLOY_STAGE != production` **ve**
`MONETIZATION_TEST_PROVIDERS=true` iken bağlanır.
