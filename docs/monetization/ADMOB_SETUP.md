# AdMob Kurulumu

Durum: kod hazır, **varsayılan Google TEST kimlikleri**. Gerçek reklam için
aşağıdaki adımlar bir insan tarafından yapılmalı (hesap gerektirir).

## 1. AdMob Console (BLOCKED: hesap)

1. admob.google.com → uygulama ekle (Android `com.futbolcard.futbol_card`, iOS bundle `com.futbolcard.futbolCard`).
2. Her platform için **Ödüllü (Rewarded)** reklam birimi oluştur.
3. Reklam biriminde **Sunucu tarafı doğrulama (SSV)** aç, geri çağrı adresi:
   `https://<sunucu>/api/ads/ssv` → "Verify URL" ile dene (sunucu 403 değil 200/409 dönmeli; imza geçerli test isteği kabul edilir).
4. **Engellenen kategoriler**: Kumar ve bahis, Alkol, Flört, Siyaset (araştırma: TR'de bahis reklamı yasal risk).
5. **app-ads.txt** web sitesinde yayımlanmalı.
6. **Gizlilik ve mesajlaşma**: AEA/UK/İsviçre için GDPR mesajı oluştur (UMP). Uygulama `ConsentInformation` + `ConsentForm` ile gösterir; rıza yoksa reklam istenmez.

## 2. Kimlikleri derlemeye verme (koda yazılmaz)

| Değer | Android | iOS |
|---|---|---|
| Uygulama kimliği | `-PadmobAppId=ca-app-pub-xxx~yyy` ya da ortam `ADMOB_APP_ID_ANDROID` | `ADMOB_APP_ID_IOS` derleme ayarı (xcconfig/CI) |
| Ödüllü birim | `--dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-xxx/yyy` | `--dart-define=ADMOB_REWARDED_IOS=...` |

Verilmezse Google'ın resmi test kimlikleri kullanılır (gerçek gelir yok, hesap riski yok).

## 3. Sunucu

| Ortam değişkeni | Açıklama |
|---|---|
| `ADMOB_SSV_KEYS_URL` | Varsayılan `https://www.gstatic.com/admob/reward/verifier-keys.json` (değiştirmeyin) |
| `DEPLOY_STAGE` | `staging` / `production` |
| `MONETIZATION_TEST_PROVIDERS` | Yalnız staging/yerel: `true` ise `/api/monetization/dev/ssv-simulate/<id>` açılır. Üretimde etkisiz. |

## 4. Açma (sunucu ayarı, uygulama güncellemesi gerekmez)

```sql
select set_monetization_config('{"monetization_enabled": true, "rewarded_ads_enabled": true,
  "daily_reward_ads_enabled": true, "chest_speedup_ads_enabled": true,
  "whitelist": ["<test-oyuncu-uuid>"]}', '<ad soyad>', 'staging test');
```

Yüzde açılım: `{"rollout_percent": 10}`. Acil kapatma: `select monetization_kill_switch('<ad>', '<neden>');`

## 5. Bilinen sınırlar

* Web'de reklam yok (AdMob web desteklemiyor; `NoAdProvider`).
* iOS: ATT izin ekranı ve SKAdNetwork kimlikleri henüz eklenmedi (Faz 2d). Kişiselleştirilmemiş reklam yeterliyse ATT gerekmez; karar insan onayı ister.
* KVKK aydınlatma metni ve uygulamaya özel rıza ekranı: **hukuki metin insan tarafından yazılmalı** (Faz 2d).
