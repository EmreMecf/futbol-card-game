# Google Play Billing Kurulumu — Faz 3

Durum: **kod hazır, hesap BLOCKED.** Anahtar yoksa doğrulayıcı kurulmaz ve
`/api/purchases/verify` 503 döner (fail-closed). Satış bayrağı
(`iap_enabled`) kapalıyken mağazada ürün görünmez.

## Gerekenler (insan)

1. Play Console → Para kazanma → Uygulama içi ürünler (tüketilebilir):
   `gems_starter_100`, `gems_popular_300`, `gems_large_700`;
   başlangıç paketi `starter_pack_1` (tek seferlik). Fiyat Play Console TL
   kademesinden **elle**; kodda fiyat yok, istemci fiyatı mağazadan alır.
2. Google Cloud → hizmet hesabı → Play Console'da "Finansal veriler" +
   "Siparişleri yönet" yetkisi. JSON anahtarı **Render gizli değişkeni**:
   `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (depoya ve günlüğe girmez).
3. `GOOGLE_PLAY_PACKAGE_NAME=com.futbolcard.futbol_card`.
4. Real-time Developer Notifications: Pub/Sub konusu → itme aboneliği
   `https://<sunucu>/api/webhooks/google-play`, "kimlik doğrulama etkin"
   (OIDC). `GOOGLE_RTDN_AUDIENCE` (abonelikte verilen hedef kitle) ve
   `GOOGLE_RTDN_SERVICE_ACCOUNT` (itme hizmet hesabı e-postası) tanımlanır.
5. Lisans test kullanıcıları (gerçek tahsilat olmadan).
6. Katalogda ürünü yayına al: `product_catalog.status='active'`
   (LIVEOPS_GUIDE), sonra `iap_enabled` + beyaz liste ile kademeli aç.

## Uygulanan (kod)

* `database/migrations/061_purchases.sql`: `product_catalog`,
  `purchase_transactions` (platform+mağaza işlemi UNIQUE, jeton özeti
  UNIQUE), `purchase_verification_events`, `purchase_grant_verified`,
  `purchase_refund` (ücretli elmas geri alınır; yetmezse borç
  `paid_gems_debt`, sonraki alımdan önce kapanır).
* `server/lib/monetization/purchase_verifier.dart` —
  `GooglePlayPurchaseVerifier`: Android Publisher
  `purchases.products.get`; paket adı, ürün, `purchaseState=0`,
  `obfuscatedExternalAccountId` = oyuncu kimliği; bekleyen ödeme ödül vermez.
  Ödül verildikten sonra sunucu `acknowledge` eder.
* İade: RTDN `voidedPurchaseNotification` → `purchase_refund`.
* İstemci (`in_app_purchase`): `completePurchase` yalnız sunucu cevabından
  sonra; geçici hatada işlem açık kalır ve sonraki açılışta yeniden doğrulanır.

## Staging testi

`MONETIZATION_TEST_PROVIDERS=true` ve `DEPLOY_STAGE=staging` iken
`test:<ürün>:<kimlik>` jetonları sahte doğrulayıcıyla geçer. Üretimde bu
sağlayıcı kurulmaz.
