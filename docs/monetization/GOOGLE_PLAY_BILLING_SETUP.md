# Google Play Billing Kurulumu — Faz 3 (BLOCKED)

Durum: **henüz uygulanmadı.** Gerçek doğrulama Google hesabı ve anahtar
gerektirir; bu olmadan satın alma açılmaz (`iap_enabled=false`, fail-closed).

## Gerekenler (insan)

1. Play Console → Uygulama → Para kazanma → Ürünler → Uygulama içi ürünler:
   `gems_starter_100`, `gems_popular_300`, `gems_large_700` (tüketilebilir).
   Fiyatlar Play Console TL kademelerinden **elle** seçilir; kodda fiyat yok.
2. Google Cloud → hizmet hesabı → Play Console'da "Finansal veriler" + "Siparişler" yetkisi.
   JSON anahtarı **Render gizli ortam değişkeni** olur: `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (depoya girmez).
3. Real-time Developer Notifications: Pub/Sub konusu → itme aboneliği
   `https://<sunucu>/api/webhooks/google-play` (Faz 3'te eklenecek).
4. Lisans test kullanıcıları (gerçek tahsilat olmadan test).

## Plan (kod)

* `purchase_transactions` (purchase_token UNIQUE, durum: created → pending →
  verification_required → verified → granted → acknowledged; cancelled,
  failed, refunded, revoked), ödül `gem_ledger`'a (`users.paid_gems`).
* Doğrulama: Android Publisher API `purchases.products.get`; ürün kimliği,
  paket adı, `purchaseState=0`, `obfuscatedExternalAccountId` = oyuncu.
* İade: RTDN `voidedPurchaseNotification` + Voided Purchases API (30 gün).
  İade edilen ücretli elmas geri alınır.
* İstemci `in_app_purchase`: fiyat SDK'dan, `completePurchase` yalnız sunucu
  onayından sonra.
