# Arkadasinla Oyna - Private invite lobby (PR #6)

## Kullanici akisi

Ana sayfa **ARKADASINLA OYNA** -> **DAVET OLUSTUR** -> **LINKI PAYLAS**
-> davetli uygulama linkini acar (ya da oyun icinde davet kodunu girer)
-> iki oyuncu **HAZIRIM** -> ayni mac.

- Iki oyuncu. Link 15 dakika gecerli.
- 120 bit kriptografik rastgele 30 karakterlik kod; tahmin edilebilir sirali oda ID kullanilmaz.
- Davet yalniz odaya katilmis, giris yapmis oyuncular tarafindan okunur.
- Bos oda / dolu oda / suresi gecmis davet / gecersiz kadro mesajlari.
- 2s polling hem Android hem iOS tarafinda ayni `match_id` sonucunu getirir; JWT gereklidir.
- Yalniz **iki oyuncu** hazirken bir PostgreSQL advisory lock icinde `_create_match` cagrilir.
- Ranked queue bu akistan ayrilir ve iki katilimci normal kuyruktan temizlenir.
- `mode=friendly`: **MMR, win/loss, coin, kart kaybi, kart gelisim kopyasi, sandik odulu YOK**. 042 son-mac fonksiyonu bu mod icin ayarlandi.
- User account ve mevcut ligler degismez.

## URL gelistirmesi

Paylasilan link ornegi (staging dagitildiktan sonra):
`https://futbol-card-staging-api-lzq3.onrender.com/invite/<30-character-code>`

1. HTTPS link bir basit web sayfasi acar.
2. Web sayfasi `futbolcard:///davet/<code>` custom-scheme'ine otomatik yonlendirmeye calisir ve **Oyunda ac** dugmesi sunar.
3. `app_links` Flutter plugin'i uygulama kapaliyken de acikken de davet kodunu GoRouter'da `/davet/:code` ekranina iletir.
4. Kullanici giris yapmadiysa, oturum acmasindan sonra davete doner.
5. Uygulama kurulu degilse kod elle girilebilir.

**Sınır:** HTTPS Universal Links / Android Verified App Links icin alan adi sahipligi,
Android imza SHA-256 + `/.well-known/assetlinks.json`, iOS Associated Domains entitlement
ve `/.well-known/apple-app-site-association` gerekiyor. Bu PR'da mevcut
Render alt alan adinda **verified universal links aktif edildigi iddia edilmez**.
Tarayici otomatik custom scheme engelleyebilir; Oyunda ac dugmesi ve manuel kod var.
Apple/Google login PR #3 bagimsizdir.

## API

- `POST /api/friends/create` -> `{status,code,is_host,host_name,...}`
- `POST /api/friends/join` body `{"code":"..."}`
- `GET /api/friends/:code`
- `POST /api/friends/:code/ready` body `{"deck_id":"UUID"}`
- `POST /api/friends/:code/ready` body `{"deck_id":null}` -> hazir degil
- `POST /api/friends/:code/leave`

Hepsi login JWT gerektirir. `GET /invite/:code` ise hicbir oyuncu bilgisini aciklamayan public landing sayfasidir.

## Staging iki telefon kabul testleri

1. Staging DB'ye `047_friend_invite_rooms.sql` uygulanmis olmali; API ile APK ayni kod surumunde olmali.
2. A Android'de odayi olusturur, linki B'ye gonderir. B linki tiklar, kodu dogrulanmis davete katilir.
3. A hazir / B hazir: yalniz B hazir oldugunda **tek** `friendly` mac olusur.
4. A/B ayni anda hazir: tek match ID. Tekrar hazir istegi yeni mac yaratmaz.
5. Odaya ucuncu hesap katilamaz; host kendi davetine misafir olarak katilamaz.
6. Host iptal eder, misafir ayrilir, 15dk suresi dolan davet, kapali/bagli olmayan telefon senaryolari.
7. Aktif ranked match varken ozel mac baslatmak yasak.
8. Tam mac sonunda MMR/kart/coin/XP degisimi olmamali. Gececek oyuna baska hesaptan giris yapinca ayni hesap ilerlemesi korunmali.
9. iPhone Android arasi davet tiklama, foreground/background/cold launch test et.
10. Aynı davet linkinin birden cok cihazda paylasimi ve zaman asimi/reconnect kontrolu.

**Yayin:** PR CI yesil + iki cihaz kabul testi olmadan otomatik main merge ya da Render deployment YOK. Migration geri alma planina ihtiyac varsa halihazirda acik odalari iptal ederek ve yeni endpoint'i kaldirarak eski yapidan devam edilebilir; geriye donuk DB tablo silme islemi gerekmez.
