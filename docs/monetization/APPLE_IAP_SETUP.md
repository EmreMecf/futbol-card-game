# Apple In-App Purchase Kurulumu — Faz 3

Durum: **kod hazır, hesap BLOCKED.** Anahtar yoksa iOS doğrulaması 503
döner (fail-closed); `iap_enabled=false` iken satış görünmez.

## Gerekenler (insan)

1. App Store Connect → Uygulama içi satın alımlar: Google ile aynı
   kimlikler (tüketilebilir elmas paketleri + `starter_pack_1`). Fiyat TL
   kademesinden elle.
2. Kullanıcılar ve Erişim → Entegrasyonlar → App Store Server API anahtarı
   (`.p8`) → Render gizli değişkenleri: `APPLE_IAP_KEY_ID`,
   `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_PRIVATE_KEY`, `APPLE_BUNDLE_ID`.
3. App Store Server Notifications V2: `https://<sunucu>/api/webhooks/apple`.
4. Sandbox test kullanıcıları; Small Business Program (%15 komisyon).

## Uygulanan (kod)

* `AppStorePurchaseVerifier`: ES256 JWT ile App Store Server API
  `GET /inApps/v1/transactions/{id}` (önce üretim, bulunamazsa sandbox).
  Paket kimliği, ürün ve `appAccountToken` = oyuncu UUID denetlenir;
  iptal/iade edilmiş işlem reddedilir.
* Bildirim ucu imzalı yüke güvenmez: bildirimdeki işlem kimliğiyle Apple
  API'si yeniden sorgulanır; `REFUND` / `REVOKE` → `purchase_refund`.
* Aynı işlem başka hesapta kullanılamaz (veritabanı kuralı).
