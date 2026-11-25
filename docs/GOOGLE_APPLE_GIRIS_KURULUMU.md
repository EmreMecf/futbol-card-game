# Google ve Apple ile giriş kurulumu

Kod hazır. Bir yöntemin kimlikleri girilmedikçe o yöntemin düğmesi görünmez ve sunucu isteği reddeder.

| Platform | Google | Apple |
|---|---|---|
| Android | Var | Yok |
| iOS | Var | Var |
| Web | Var | Var |

## 1. Veritabanı

`database/migrations/049_social_identities.sql` dosyasını yayından önce çalıştır. Sunucuyu bu migration'dan sonra aç.

## 2. Google

[Google Cloud Console](https://console.cloud.google.com/apis/credentials) içinde bir proje aç, OAuth izin ekranını doldur ve üç OAuth istemcisi oluştur:

| Tür | Gerekli bilgi |
|---|---|
| Web application | Authorized JavaScript origins: web sitenin adresi (geliştirmede `http://localhost:PORT`) |
| Android | Paket: `com.futbolcard.futbol_card`, yayın ve hata ayıklama anahtarlarının SHA-1 değerleri |
| iOS | Bundle ID: `com.futbolcard.futbolCard` |

iOS için `ios/Runner/Info.plist` içindeki `CFBundleURLSchemes` dizisine iOS istemcisinin **ters** kimliğini ekle (`com.googleusercontent.apps.XXXX`).

## 3. Apple

Ücretli Apple Developer hesabı gerekir.

1. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) içinde `com.futbolcard.futbolCard` için **Sign in with Apple** yeteneğini aç.
2. Yetki dosyası hazır: `ios/Runner/Runner.entitlements`. TestFlight iş akışı onu
   yalnız GitHub'da **ios-testflight** ortamındaki `APPLE_SIGN_IN_IOS` değişkeni `true`
   iken bağlar ve düğmeyi açar. Önce App ID'de Sign in with Apple'ı aç, provisioning
   profile'ı **ondan sonra** yeniden üret; yoksa imzalama hata verir.
   (Mac'te Xcode ile derlerken: Runner, **Signing & Capabilities**, **+ Capability**, **Sign in with Apple**.)
3. Web için bir **Services ID** oluştur, alan adını ve dönüş adresini (`https://...`) tanımla. Apple `localhost` kabul etmez.

## 4. Ayarlar

Uygulama (`.env` ya da `--dart-define`). Bu değerler gizli değildir:

```
GOOGLE_WEB_CLIENT_ID=<web istemci kimliği>
GOOGLE_IOS_CLIENT_ID=<iOS istemci kimliği>
APPLE_SIGN_IN_IOS=true
APPLE_SERVICE_ID=<Services ID>
APPLE_REDIRECT_URI=https://<alan-adı>/<dönüş-adresi>
```

Sunucu (ortam değişkeni, virgülle ayrılmış):

```
GOOGLE_CLIENT_IDS=<web istemci kimliği>,<iOS istemci kimliği>
APPLE_CLIENT_IDS=com.futbolcard.futbolCard,<Services ID>
```

## Bu projenin kimlikleri

| Ad | Değer |
|---|---|
| Google Web istemcisi | `438252320232-herv722ro3g44n91rsjs65j76fhhankb.apps.googleusercontent.com` |
| Google iOS istemcisi | `438252320232-f8a1sodjhq4lddij8kgnnslpu4a24hvb.apps.googleusercontent.com` |

CI'daki staging APK derlemesine ve `ios/Runner/Info.plist` URL şemasına eklendi.
Render'da sunucuya girilecek satır:

```
GOOGLE_CLIENT_IDS=438252320232-herv722ro3g44n91rsjs65j76fhhankb.apps.googleusercontent.com,438252320232-f8a1sodjhq4lddij8kgnnslpu4a24hvb.apps.googleusercontent.com
```

Eksik: Android istemcisi (sabit yayın anahtarının SHA-1'i gerekir) ve Apple.

## 5. Yayından önce dene

- [ ] Android, iOS ve web'de yeni hesap: ad seçimi ve başlangıç paketi
- [ ] Aynı hesapla çıkıp yeniden giriş
- [ ] E-postayla açılmış hesaba aynı e-postanın Google hesabıyla giriş
- [ ] Apple'da "E-postamı gizle" seçeneği
- [ ] Giriş ekranında vazgeçme: hata görünmemeli

## Hesap bağlama (güvenlik)

Google/Apple ile girişte aynı e-postalı mevcut hesaba **kendiliğinden bağlanılmaz**
(kayıtta e-posta sahipliği doğrulanmıyor; başkası o adresle önceden hesap açmış
olabilir). Sunucu `409 social_link_required` döner. Oyuncu önce e-posta ve şifresiyle
giriş yapar, sonra **Ayarlar → HESAP → BAĞLI HESAPLAR** bölümünden bağlar
(`POST /api/me/social/link`).
