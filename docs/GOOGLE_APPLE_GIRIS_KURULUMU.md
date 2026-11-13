# Futbol Card Arena — Google + Apple OAuth staging kurulumu

**Durum:** OAuth kodu PR #3 içinde. Credential'lar tanımlanmadan gerçek Google/Apple girişini kullanmayın. Bu PR, canlı Render servisinde henüz dağıtılmamıştır.

## Mevcut sistem korunur

- `users.id` bütün kartları, sandıkları, ligi, maç geçmişini ve ilerlemeyi taşır; `045_social_identity.sql` bunlara dokunmaz.
- `user_auth_providers(provider, provider_subject, user_id)`: sadece Google/Apple doğrulanmış `sub` değeri ile eşleştirme.
- Var olan e-posta hesabı otomatik birleştirilmez: aynı doğrulanmış e-postada 409 döner. E-postayla oturum açın → Ayarlar → sosyal hesabı bağlayın.
- Sosyal kayıt yeni kullanıcıya tek başlangıç paketi verir; mevcut şifreli giriş kapatılmaz.
- OAuth kimlik token'ları Flutter cihazından HTTPS aracılığıyla `/api/auth/social/` API'sine iletilir. Server RS256 imzasını sağlayıcının JWKS public key'leriyle, `iss/aud/exp/iat` claim'leriyle ve Apple için SHA256 nonce ile doğrular. İstemciden gelen e-postaya güvenilmez.
- Google ve Apple'ın `id_token` içeriğini veya refresh token'ı loglamayın.

## 1 — Google (Android)

1. [Google Cloud Console](https://console.cloud.google.com/apis/credentials) içinde ayrı bir proje seçin, OAuth consent screen yapılandırın.
2. Google OAuth **Web application** Client ID oluşturun. Bu `GOOGLE_WEB_CLIENT_ID`; secret'ı APK'ya KOYMAYIN.
3. Android OAuth Client ID oluşturun. Package name: `com.futbolcard.futbol_card`. SHA-1 parmak izi staging APK'sının **gerçek imzalama sertifikasından** alınmalıdır. Yerel debug, GitHub Actions debug ve Play signing farklı imzalar olduğundan her biri için gerektiğinde ayrı Android istemcisi gerekir.
4. Render > staging web service > Environment: `GOOGLE_WEB_CLIENT_ID=<Web OAuth Client ID>`.
5. Flutter APK:
   ```bash
   flutter build apk --release \
     --dart-define=API_BASE_URL=https://futbol-card-staging-api-lzq3.onrender.com \
     --dart-define=GOOGLE_WEB_CLIENT_ID=<Web OAuth Client ID>
   ```
6. Testte gerçek Google hesaplarıyla giriş, tekrar giriş, çıkış, mevcut hesaba bağlama, aynı e-postada 409 ve JWT refresh kontrol edilmelidir.

## 2 — Google (iOS)

- `GOOGLE_IOS_CLIENT_ID` iOS OAuth Client ID; iOS Bundle ID: `com.futbolcard.futbolCard`.
- `ios/Runner/Info.plist` içine Google'ın verdiği **REVERSED_CLIENT_ID** değerini URL scheme olarak ekleyin. Bu değer bilinmeden rastgele scheme uydurmayın.
- iOS derlemesine `--dart-define=GOOGLE_IOS_CLIENT_ID=<iOS client id>` ekleyin.
- Flutter SDK 3.44+ ve güncel google_sign_in API kullanılır.

## 3 — Apple (iOS)

- **Normal Apple ID yeterli değil:** Apple Developer Program üyeliği ve uygulamanın Apple geliştirici hesabında tanımlanması gerekir.
- [Apple Developer](https://developer.apple.com/account/resources/identifiers/list) → App IDs → `com.futbolcard.futbolCard` → Sign in with Apple yetkisini açın.
- Runner Xcode Signing & Capabilities > Sign In with Apple doğrulayın; `ios/Runner/Runner.entitlements` dosyası PR'da var.
- Render staging env: `APPLE_BUNDLE_ID=com.futbolcard.futbolCard`.
- Gerçek iPhone'da Apple kimlik doğrulaması ve gizli e-posta senaryosunu test edin.

## 4 — Apple (Android, ayrıca yapılandırılmalı)

- Apple Developer → **Services ID** oluşturun (Bundle ID değil), Apple Sign In etkinleştirin.
- Authorized domain: `futbol-card-staging-api-lzq3.onrender.com`.
- Return URL (Apple'ın web POST redirect'i):
  `https://futbol-card-staging-api-lzq3.onrender.com/api/auth/social/apple-callback`
- Server `APPLE_SERVICE_ID` değerine bu Services ID'yi koyun.
- Flutter derlemesine `--dart-define=APPLE_SERVICE_ID=<Services ID>` ve
  `--dart-define=APPLE_REDIRECT_URI=https://futbol-card-staging-api-lzq3.onrender.com/api/auth/social/apple-callback` ekleyin.
- Callback yalnızca sabit Android package name + `signinwithapple` scheme'e yönlendirir. Testte tarayıcı kapanması, hatalı state, kullanıcının iptal etmesi, bağlantı kopması gibi durumları kontrol edin.

## API sözleşmesi

```http
POST /api/auth/social/
Content-Type: application/json

{"provider":"google","id_token":"<provider-issued-jwt>"}
```

Apple için ayrıca `raw_nonce` gerekir. Sunucu `nonce` claim'inin SHA-256 karşılığını doğrular.

```http
POST /api/auth/social/link
Authorization: Bearer <existing-game-access-token>
Content-Type: application/json

{"provider":"apple","id_token":"<provider-issued-jwt>","raw_nonce":"<nonce>"}
```

Dönüş: mevcut `AuthResponse` biçimi; mevcut access/refresh ve WebSocket akışı korunur.

## Kabul testleri / sınırlar

1. `045_social_identity_test.sql`: aynı oyuncuya Google+Apple, aynı provider kimliğinin başka oyuncuya verilememesi, aynı oyuncuya aynı provider'dan iki kimlik verilememesi.
2. `social_token_verifier_test.dart`: tanımsız provider, imzasız token, boş OAuth ayarı reddedilir.
3. Gerçek cihaz: Google Android, Google iOS, Apple iOS, Apple Android (Services ID sonrası), hesap bağlama/409 ve tekrar giriş.
4. Sunucuda credential'lar girilmeden **Social login geçerli değil**. Staging'deki eski e-posta oturumuna dokunmayın.
5. Bu sürümde Apple authorization code ile Apple token endpoint exchange/revocation ve kapsamlı hesap silme akışı tamamlanmamıştır; public App Store release öncesi bunları uygulayın.
6. Production'daki kalıcı veritabanına migration/test kullanıcıları uygulamayın. Free staging PostgreSQL 30 günlüktür; test amaçlıdır.

## GitHub Actions'da durum

CI Android mevcut temel APK'yı derler, gerçek OAuth Client ID/SHA bilgileri olmadan Google/Apple giriş akışı uçtan uca test edilemez. Entegrasyonun kullanıldığı staging APK OAuth kimlikleri belirlendikten sonra ayrı job/artifact olarak üretilmelidir. CI sonuçları olmadan PR merge etmeyin.
