# Apple In-App Purchase Kurulumu — Faz 3 (BLOCKED)

Durum: **henüz uygulanmadı.** Apple Developer hesabı ve App Store Connect
anahtarı gerekir; `iap_enabled=false` iken satın alma görünmez.

## Gerekenler (insan)

1. App Store Connect → Uygulama içi satın alımlar: tüketilebilir elmas
   paketleri (Google ile aynı kimlikler). Fiyat TL kademesinden elle.
2. Kullanıcılar ve Erişim → Entegrasyonlar → App Store Server API anahtarı
   (`.p8`, Key ID, Issuer ID) → Render gizli değişkenleri:
   `APPLE_IAP_KEY_ID`, `APPLE_IAP_ISSUER_ID`, `APPLE_IAP_PRIVATE_KEY`.
3. App Store Server Notifications V2 adresi:
   `https://<sunucu>/api/webhooks/apple` (Faz 3).
4. Sandbox test kullanıcıları.
5. Small Business Program kaydı (%15 komisyon).

## Plan (kod)

* StoreKit 2 işlem kimliği UNIQUE; doğrulama App Store Server API
  `GET /inApps/v1/transactions/{id}` (JWS imzası Apple kök sertifikasıyla).
* Bildirim V2 JWS doğrulaması; `REFUND` / `REVOKE` → ücretli elmas geri alınır.
* Aynı işlem başka hesapta kullanılamaz (`appAccountToken` = oyuncu UUID).
