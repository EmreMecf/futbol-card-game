# Dağıtım Rehberi (Monetizasyon)

**Üretime deploy, gerçek reklam kimliği ve gerçek para açık kullanıcı
onayı ister.** Bu belge staging içindir.

## Staging (Render, elle deploy)

1. `main`'e birleşmiş ve CI yeşil olmalı (DB testleri 060 dahil).
2. Render → servis → Manual Deploy → Deploy latest commit. Açılışta
   `staging-db-bootstrap.sh` yeni migration'ı (060) uygular; geçmiş
   migration'ların SHA256'sı değişmemeli.
3. Ortam değişkenleri (Render → Environment):

| Anahtar | Staging | Üretim |
|---|---|---|
| `DEPLOY_STAGE` | `staging` | `production` |
| `MONETIZATION_TEST_PROVIDERS` | `true` (isteğe bağlı) | tanımsız / `false` |
| `ADMOB_SSV_KEYS_URL` | tanımsız (varsayılan) | tanımsız |
| `GOOGLE_PLAY_PACKAGE_NAME` | `com.futbolcard.futbol_card` | aynı |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | gizli (isteğe bağlı) | gizli |
| `GOOGLE_RTDN_AUDIENCE` / `GOOGLE_RTDN_SERVICE_ACCOUNT` | Pub/Sub itme ayarı | aynı |
| `APPLE_BUNDLE_ID` / `APPLE_IAP_KEY_ID` / `APPLE_IAP_ISSUER_ID` / `APPLE_IAP_PRIVATE_KEY` | gizli (isteğe bağlı) | gizli |

Mağaza anahtarı yoksa o platformun doğrulaması 503 döner; satın alma
ödülü hiçbir koşulda istemci beyanıyla verilmez. 061 da yalnız ekleme
yapar (yeni tablo/sütun; ürünler `draft`).

4. Doğrulama: `GET /api/health`; ayar kapalı olmalı:
   `select monetization_config()->>'monetization_enabled'` → `false`.
5. Test: beyaz listeye test oyuncusu ekle (LIVEOPS_GUIDE), Android
   cihazda test reklamı izle, `ad_ssv_events` içinde `granted` gör.
   Google test reklamlarında SSV geri çağrısı gelmezse
   `MONETIZATION_TEST_PROVIDERS=true` ile `/api/monetization/dev/ssv-simulate/<oturum>`.

## Geri alma

* Davranış: `monetization_kill_switch` (anında, kod gerekmez).
* Kod: Render'da önceki deploy → Rollback. 060 yalnız ekleme yapar
  (yeni tablo/sütun/fonksiyon); eski kod yeni şemayla çalışır.
* Veri: 060 mevcut veriyi değiştirmez; geri almada veri işlemi gerekmez.

## Mobil derleme

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://<staging>/api
```

Gerçek AdMob kimlikleri yalnız üretim derlemesinde (ADMOB_SETUP.md).
