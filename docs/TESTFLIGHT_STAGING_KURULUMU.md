# Futbol Card Arena — iPhone TestFlight staging (GitHub Actions / macOS 26)

**Durum:** CI iskeleti hazir. Apple Developer sertifikasi, App Store Connect anahtari ve Google OAuth kimlikleri baglanmadan imzali IPA olusmaz / TestFlight'a yuklenmez. Bu akista **otomatik upload yoktur**. `workflow_dispatch` sirasinda `publish_testflight=true` secilmesi ve `ios-testflight` environment izinlerinin uygun olmasi gerekir.

## Proje parametreleri (kaynak koddan dogrulandi)

| Alan | Deger |
|---|---|
| iOS Bundle ID | `com.futbolcard.futbolCard` |
| Android Package ID | `com.futbolcard.futbol_card` (farkli!) |
| Flutter | `3.44.6` |
| Runner | `macos-26` / Xcode 26 |
| API | `https://futbol-card-staging-api-lzq3.onrender.com` |
| iOS entitlement | `ios/Runner/Runner.entitlements`: Sign in with Apple |
| Workflow | `.github/workflows/ios-testflight.yml` |
| PR kaynagi | `feature/google-apple-social-login` (PR #3) |

### Akis

- Pull Request: `ios_compile` macOS 26'da `flutter build ios --release --no-codesign` calistirir, Apple key gerekmez. CI basarili diye TestFlight yuklendi iddiasi YAPILMAZ.
- Elle baslatilan, `publish_testflight=true` secilen workflow: GitHub `ios-testflight` environment var/secrets dogrulama -> p12/profil gecici macOS keychain -> Google iOS URL scheme -> signing ayarlari (sadece CI runner'da) -> `flutter build ipa` -> imza kontrolu -> `apple-actions/upload-testflight-build@v5` -> cleanup.
- Workflow sadece repo vars/secret referanslarini kullanir; API private key, p12 ve sifreler repoya, issue'ya veya sohbete YAZILMAZ.
- OAuth sosyal giris kodu halen PR #3 kapsaminda olabilir. TestFlight CI uygulamanin varsayilan dalina merge edilmeden GitHub Actions UI'dan workflow_dispatch ile gosterilmeyebilir; bu sebeple oncelikle PR + merge, ardindan manuel calistirma gerekli.

## 1 — Apple Developer portal

[Apple Developer — Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list)

1. App ID: explicit `com.futbolcard.futbolCard`.
2. Capability: **Sign in with Apple**, gerekiyorsa yeniden profile olustur.
3. Apple Distribution sertifikasi olustur veya var olan sertifikayi kullan. Private key'i iceren `.p12` dosyasi ve ayri parola gerekir. Sertifikanin kendisi tek basina p12 degildir.
4. App Store Connect distribution provisioning profile olustur. App ID ve ayni Distribution sertifikasini sec; indirilen `.mobileprovision` dosyasini sakla.
5. App Store Connect > Apps > New App: iOS platformu, bu Bundle ID, uygulama adi, SKU. Yeni app icin app adi uygunlugu Apple tarafindan belirlenir.

Dogrulama: Profile `Entitlements:application-identifier` alaninin `TEAMID.com.futbolcard.futbolCard` oldugunu ve profile adini GitHub variable ile birebir eslestirdigini kontrol et.

## 2 — App Store Connect API Key

[App Store Connect](https://appstoreconnect.apple.com/) > Users and Access > Integrations > App Store Connect API.
- App Manager yetkisi olan API anahtari uret, `Key ID` ve `Issuer ID` al. `.p8` anahtarini olustururken **bir kez indir**, GitHub environment secret olarak kaydet. Anahtari sohbete, repoya ya da ekran goruntusune koyma.
- Apple Developer portalindakilerden farkli olabilen App Store Connect API key/tanimlayicilari icin bu bolumdeki bilgileri kullan.

## 3 — Google OAuth (iPhone)

[Google Cloud Console](https://console.cloud.google.com/apis/credentials)
- Web OAuth Client ID -> `GOOGLE_WEB_CLIENT_ID` (backend Render env'de de aynisi gerekir).
- iOS OAuth Client ID -> `GOOGLE_IOS_CLIENT_ID`, iOS bundle `com.futbolcard.futbolCard`.
- Google'in sagladigi **reversed iOS client ID URL scheme** -> `GOOGLE_IOS_REVERSED_CLIENT_ID`.
- Runner `Info.plist` dosyasina scheme'i gecici olarak enjekte eder. Kaynak dosyaya gercek client kimligini hardcode etmez.
- Bu degerler verilmezse signed job **bilerek hata verir**; bir onceki Android test APK'sinin basarili olmasi sosyal girisin calistigi anlamina gelmez.

## 4 — GitHub environment variable / secret kurulumu

GitHub repo Settings > Environments > **New environment** `ios-testflight`.

Environment protection (onerilir): Required reviewers, yanlislikla TestFlight yayinini engeller. Github planina gore ozellik kullanilabilirligi degisir. Deploy olusturma sadece manuel input true ile mumkun.

`ios-testflight` ortaminda su **Variables** tanimlanir:

| Variable | Kaynak |
|---|---|
| `IOS_TEAM_ID` | Apple Developer 10 karakterli Team ID |
| `IOS_PROFILE_NAME` | App Store provisioning profile adinin birebir aynisi |
| `GOOGLE_WEB_CLIENT_ID` | Google Web OAuth client ID |
| `GOOGLE_IOS_CLIENT_ID` | Google iOS OAuth client ID |
| `GOOGLE_IOS_REVERSED_CLIENT_ID` | Google iOS reversed scheme |
| `APPSTORE_ISSUER_ID` | App Store Connect API Issuer ID |
| `APPSTORE_API_KEY_ID` | App Store Connect API Key ID |

Ayni environment icinde su **Secrets** tanimlanir:

| Secret | Kaynak |
|---|---|
| `IOS_DISTRIBUTION_CERT_P12_BASE64` | Apple Distribution .p12 dosyasinin base64 icerigi |
| `IOS_DISTRIBUTION_CERT_PASSWORD` | .p12 export parolasi |
| `IOS_PROVISIONING_PROFILE_BASE64` | .mobileprovision dosyasinin base64 icerigi |
| `APPSTORE_API_PRIVATE_KEY` | `AuthKey_*.p8` dosyasinin tam icerigi, BEGIN/END satirlariyla |

**Windows PowerShell base64 hazirlamak (yalniz GitHub Secret kutusuna yapistir):**

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\\private\\apple-distribution.p12"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\\private\\appstore.mobileprovision"))
```

P12 parolasi veya .p8 private key'i hicbir yerde duz metin loglama. Ucretli plan veya gizli dosya yuklemesi gerektiren adimlar ayri yetkilendirme olmadan yapilmadi.

## 5 — Workflow nasil calistirilir?

1. PR #3 (OAuth kodu) ile bu iOS CI PR'i test edilsin; kod incelemesi + tum CI yesil olmadan production'a merge etme.
2. Yalniz test uygulamasi icin yeni iOS surum cikarmak istiyorsan staging ortamlarinin baglanmasini dogrula: Render'da `045_social_identity.sql` *yalniz staging* veritabaninda uygulanmali ve backend'in OAuth kodunu iceren surumu ayrica dagitilmali. Bu workflow Render'i DEGISTIRMEZ.
3. Vars ve secrets tamamlandiktan sonra, workflow varsayilan dala ulastiginda GitHub > Actions > iOS Staging - TestFlight > Run workflow > `publish_testflight: true` -> Run.
4. GitHub workflow **basarili upload** verdikten sonra, App Store Connect > Apps > Futbol Card > TestFlight bolumunde Apple'in build isleme durumunu kontrol et. GitHub CI basarili diye Apple tarafinda build hemen kullanilabilir sayilmaz.
5. Dahili test kullanicilarini ekle (App Store Connect Users and Access / TestFlight internal testing). iPhone'a App Store'dan **TestFlight** indir, daveti kabul et. Harici test gruplari Apple Beta App Review isteyebilir.
6. Android ve iPhone ayni staging HTTPS / WSS adresine baglanarak farkli iki test hesabi ile PvP oynasin. Apple, Google, mevcut e-posta girisi, tekrar giris, hesap baglama, eski kayit korunmasi ve WebSocket kopma/yeniden baglanma testleri raporlanmali.

## Sinirlar ve guvenlik

- Bu is akisi **yalniz iOS derleme/yukleme**; OAuth uygulamasini otomatik olarak staging backend'e dagitmaz.
- Yalniz PR'da `flutter build ios --no-codesign` testinin gecmesi, gerçek imzali IPA / TestFlight ve gercek Apple kimlik dogrulamasi testinin gectigi anlamina gelmez.
- CI macOS dakika kotalari/billing GitHub repository tipi ve planiyla iliskilidir; bu is akisi surekli veya her main push'unda calismaz.
- Provisioning profile Store distribution icin olusturulmali. Xcode 26 / SDK kabul kosullarini Apple'in guncel sayfasindan kontrol et.
- Staging DB'nin expiration tarihi 13 Aralik 2026; test oyuncu verisini kalici kabul etme.
- Hangi Social Auth endpoint'inin canli oldugu, Render deploy loglariyla ayrica dogrulanmalidir.
- Apple Developer private key, certificate ve App Store Connect API key'i **kullaniciya ait** kalir. Bunlari sohbet icerigine gondermeyin.

Kaynaklar: https://docs.flutter.dev/deployment/ios ;
https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds ;
https://developer.apple.com/help/account/provisioning-profiles/create-an-app-store-provisioning-profile ;
https://github.com/Apple-Actions/upload-testflight-build .
