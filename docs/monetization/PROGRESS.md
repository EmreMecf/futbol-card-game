# İlerleme

Bağlam yenilenirse buradan devam edilir.

## Tamamlanan (27 Kasım 2026)

### Faz 0 — Denetim
* AUDIT, ARCHITECTURE, IMPLEMENTATION_PLAN, ECONOMY_RISK_ANALYSIS yazıldı.
* Üç çatışma: elmas→altın, premium sezon yolu, elmasla sandık. Karar:
  ücretli/ücretsiz elmas ayrımı; premium satış kapalı kalır.

### Faz 1 — Çekirdek (migration 060)
* `monetization` ayar türü (sürümlü, değiştirilemez), kapılar: global,
  özellik, platform, en düşük sürüm, beyaz liste, deterministik yüzde.
* `set_monetization_config` (doğrulamalı) + `monetization_admin_audit`
  (değiştirilemez) + `monetization_kill_switch`.
* `monetization_events` (analitik huni), `users.paid_gems` (0).

### Faz 2 — Ödüllü reklam
* SQL: `ad_sessions` (süreli rezervasyon), `ad_eligibility`,
  `ad_session_create`, `ad_session_client_event` (ödül vermez),
  `ad_ssv_grant` (tekil işlem, tavan yeniden sayımı, kredi),
  `ad_session_apply_credit`, `ad_status`, `monetization_client_config`.
* Sunucu: `server/lib/monetization/ad_ssv_verifier.dart` (ECDSA P-256,
  Google anahtar önbelleği), `monetization_routes.dart`
  (`/api/monetization/*`, `/api/ads/ssv`), `Env.deployStage`,
  `Env.monetizationTestProviders`.
* İstemci: `google_mobile_ads 9.2.0`, `lib/features/monetization/*`
  (modeller, API, sağlayıcı arayüzü + AdMob + web/yok, durum makinesi),
  `lib/ui_v21/screens/monetization/v21_ad_widgets.dart` (günlük ödül hapı,
  onay, doğrulama kutusu), sandık penceresinde reklamla −10 dk ve kayıtlı
  kredi. Android/iOS test uygulama kimlikleri.
* Belgeler: ADMOB_SETUP, SECURITY_REVIEW, TEST_REPORT, LIVEOPS_GUIDE,
  DEPLOYMENT_GUIDE, RELEASE_CHECKLIST, GOOGLE_PLAY_BILLING_SETUP,
  APPLE_IAP_SETUP (plan).
* Simülasyon: `tool/ekonomi/monetizasyon_simulasyonu.dart`.

## Sıradaki

| Adım | Not |
|---|---|
| 2d | Ayarlar > "Gizlilik seçenekleri" düğmesi (UMP `privacyOptionsRequired`), KVKK rıza ekranı (metin insan onayı), iOS ATT kararı |
| 2e | Maç sonu teklifi arayüzü (`post_match`, sunucu hazır, arayüz yok; bayrak kapalı) |
| 3 | Satın alma: `purchase_transactions`, doğrulayıcı arayüzü, test sağlayıcı (yalnız staging), Google/Apple gerçek doğrulayıcılar BLOCKED |
| 4 | Mağaza sekmeleri, kozmetik satış + önizleme, başlangıç paketi |
| 5 | Güçsüz premium sezon yolu |
| 6 | Yönetici uçları (rol + denetim), deney tablosu, olay saklama süresi |

## BLOCKED (insan / hesap)

* AdMob hesabı, gerçek reklam birimleri, SSV adresinin konsolda tanımı
* Google Play Console ürünleri + hizmet hesabı; App Store Connect ürünleri + API anahtarı
* KVKK aydınlatma metni, gizlilik politikası, mağaza beyanları (hukuk)

## Onay bekleyen (yapılmadı)

* Staging'e 060 deploy (commit/push kullanıcı kararı)
* Üretimde herhangi bir monetizasyon bayrağını açmak
