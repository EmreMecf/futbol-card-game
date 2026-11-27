# Flutter Oyunu İçin Reklam Ağları, Mediation ve IAP Kütüphaneleri (2025-2026)

Not: Araştırma tarihi 27 Kasım 2026. Proje: Futbol Card Arena (Flutter iOS/Android/Web, Dart Shelf + PostgreSQL, ödüller sunucu tarafında veriliyor). Ana gelir planı: ödüllü video + IAP.

## 1. Mediation seçenekleri ve pazar payı (AdMob, AppLovin MAX, Unity LevelPlay, diğerleri)

### Takeaway
2025'te mediation pazarı üç oyuncuda toplanmış durumda: AppLovin MAX (>%50 tahmini), Unity LevelPlay ve AdMob birlikte >%90. Tek geliştirici için AdMob (en basit, resmi Flutter eklentisi, aynı hesapta ödeme) veya MAX (en güçlü talep, ama Flutter eklentisi resmi ve güncel) mantıklı; LevelPlay geride kalıyor. Meta Audience Network yalnızca bidding ile çalışıyor.

### Cited Findings
- GameBiz Consulting analizi (Mayıs 2025): MAX'in mediation payı %50'nin üzerinde; MAX + LevelPlay + AdMob toplamı %90'ın üzerinde; FairBid, Appodeal, Chartboost vb. toplamı %10'un altında. Bu bir danışman tahmini, denetlenmiş veri değil. — [PocketGamer.biz: nine facts about the mediation space in 2025](https://www.pocketgamer.biz/nine-facts-about-the-mediation-space-in-2025); [Gamigion](https://www.gamigion.com/mediations-in-2025-9-facts-out-there/)
- AppLovin, MAX kullanmayan yayıncılar için ROAS kampanyası çalıştırmıyor; bu yüzden reklam ağırlıklı oyunlar varsayılan olarak MAX'e yöneliyor. — [PocketGamer.biz](https://www.pocketgamer.biz/nine-facts-about-the-mediation-space-in-2025)
- LevelPlay (Unity, ironSource ile Kasım 2022'de birleşti) "geride kalıyor" olarak tanımlanıyor; AdMob en çok indirilen uygulamalarda LevelPlay'in iki katından fazla paya sahip; AppLovin ağı LevelPlay'de bidder olarak hâlâ yok. — [PocketGamer.biz](https://www.pocketgamer.biz/nine-facts-about-the-mediation-space-in-2025); [Gamigion](https://www.gamigion.com/mediations-in-2025-9-facts-out-there/)
- AppLovin 2021'de MoPub'u satın alıp 2022'de kapattı ve yayıncıları MAX'e taşıdı. — [Gamigion](https://www.gamigion.com/mediations-in-2025-9-facts-out-there/)
- AppLovin şirket analizi ("Apex Predator", Mayıs 2025) — [Deconstructor of Fun](https://www.deconstructoroffun.com/blog/2025/5/5/applovin-the-apex-predator)
- Meta Audience Network iOS/Android uygulamalarda yalnızca bidding ile reklam dolduruyor (Meta dokümanı 30 Haziran 2026'da güncellenmiş); waterfall kurulumları bidding'e geçmeli. — [Meta Audience Network Bidding Overview](https://developers.facebook.com/documentation/audience-network/bidding/overview)
- Google'a göre Meta 2021'de bidding-only oldu; AdMob Flutter mediation'da Meta adaptörü Banner, Interstitial, Rewarded, Rewarded Interstitial, Native destekliyor. — [AdMob Flutter: Meta mediation](https://developers.google.com/admob/flutter/mediation/meta)
- Temmuz 2025 forum başlığı: Meta açık artırmayı kazanıp reklamı dolduramayınca AdMob otomatik olarak başka ağa düşmüyor; geliştirici manuel yedek ekledi. — [Google AdMob SDK grubu](https://groups.google.com/g/google-admob-ads-sdk/c/Xx6a8kwB0QE)
- Yandex Mobile Ads'in resmi Flutter eklentisi var (`yandex_mobileads`, pub.dev'de 7.0.1); banner, interstitial, ödüllü reklam destekliyor; Android + iOS. — [pub.dev yandex_mobileads](https://pub.dev/packages/yandex_mobileads/example); [Yandex Flutter quick start](https://yandex.com/dev/mobile-ads/doc/plugins/flutter/quick-start/init.html); [Yandex duyurusu](https://yandex.com/adv/news/you-can-now-use-yandex-advertising-network-to-monetize-flutter-applications)
- Unity LevelPlay artık PubMatic ile de talep sunuyor (PubMatic tanıtım yazısı ~%90 oyun mediation payından bahsediyor). — [PubMatic blog](https://pubmatic.com/blog/where-mobile-scale-meets-mediation-power-unity-levelplay-now-available-with-pubmatic/)

### Inferences
- Tek geliştirici ve küçük ölçek için en düşük operasyonel yük: AdMob + bidding adaptörleri (Meta, AppLovin, Unity, Mintegral, Pangle, Liftoff vb. AdMob mediation adaptörü olarak eklenebilir). MAX genelde daha yüksek talep sağlar ama ayrı panel, ayrı ödeme hesabı ve AdMob'u ayrıca ağ olarak bağlama gerektirir.
- Meta bidding'in "kazanıp doldurmama" sorunu, ödüllü reklamda yükleme hatası için istemcide yeniden deneme/yedek mantığı gerektirir.
- Yandex Türkiye için ek talep kaynağı olabilir ama Türk yayıncı uygunluğu doğrulanmadı (aşağıda Gaps).

### Gaps
- Mintegral, Pangle, Liftoff/Vungle, InMobi, DT Exchange için 2025-2026 ayrı güncel değerlendirme kaynakları aranmadı; Türkiye'deki dolum oranları bilinmiyor.
- Yandex Reklam Ağı'nın Türkiye'deki yayıncılara ödeme yapıp yapmadığı, Türkiye talebi ve Yandex'in AdMob/MAX'e adaptör olarak eklenip eklenemeyeceği bulunamadı.
- Denetlenmiş (bağımsız) 2025-2026 mediation pazar payı tablosu bulunamadı; rakamlar danışman tahmini.

## 2. Resmi Flutter eklentileri (sürümler, özellikler, bakım, web desteği)

### Takeaway
Üç büyük mediation'ın da resmi ve aktif bakımlı Flutter eklentisi var: `google_mobile_ads` 9.2.0 (Ekim/Kasım 2026), `applovin_max` 4.x, `unity_levelplay_mediation` 9.x (eski `ironsource_mediation` kullanımdan kaldırıldı). Hiçbiri Flutter web'i desteklemiyor; web için tek Google yolu AdSense H5 Games Ads (kapalı beta, onay gerekli) ve `google_adsense` paketinin `h5.dart` kütüphanesi.

### Cited Findings
- `google_mobile_ads` son sürüm 9.2.0 ("36 gün önce" yayımlanmış, yani yaklaşık Ekim 2026 sonu): Android GMA SDK 25.5.0 (Next-Gen 1.5.0), iOS GMA 13.11.0, UMP Android 4.0.0 / iOS 3.1.0. — [pub.dev changelog](https://pub.dev/packages/google_mobile_ads/changelog)
- 9.1.0: reklam önyükleme (preloading) API'leri, UMP için `setConsentSyncId()`, `RequestConfiguration.ageRestrictedTreatment`. 8.0.0: minimum Flutter 3.38.1 / Dart 3.10.0, Swift Package Manager desteği, UISceneDelegate geçişi. Ödüllü interstitial 1.1.0'dan beri var. Platformlar: yalnız Android ve iOS. — [pub.dev changelog](https://pub.dev/packages/google_mobile_ads/changelog)
- Google, Android GMA SDK 25.0.0'ı 19 Şubat 2026'da duyurdu (23.0.0-23.6.0 kullanımdan kaldırıldı); Next-Gen Android SDK'yı 29 Ocak 2026'da duyurdu; iOS 13.0.0 6 Şubat 2026. — [Android SDK 25.0.0 duyurusu](https://developers.google.com/ads/blog/posts/2026/02/announcing-android-google-mobile-ads); [Next-Gen SDK duyurusu](https://developers.google.com/ads/blog/posts/2026/01/announcing-google-mobile-ads-next-gen)
- `applovin_max` (AppLovin resmi): interstitial, rewarded, banner, MREC. 4.0.0 Android/iOS SDK 13.0.0'a bağlı; 4.3.1 changelog'u eklenti/native SDK uyumsuzluğunda çökme düzeltmesi içeriyor. Sürüm listesi sayfası 4.0.2'yi gösteriyor, changelog 4.3.1'i — çelişki var, pub.dev'den doğrulanmalı. — [applovin_max changelog](https://pub.dev/packages/applovin_max/changelog); [applovin_max versions](https://pub.dev/packages/applovin_max/versions)
- `unity_levelplay_mediation` (Unity doğrulanmış yayıncı): rewarded, interstitial, banner, native; eski `ironsource_mediation` 9.0.0 ile kullanımdan kaldırıldı; 9.2.0 `LevelPlayPrivacySettings` (GDPR/CCPA/COPPA); Unity dokümanları ^9.3.0/^9.4.0'a atıf yapıyor; yalnız Android + iOS; pub.dev skoru 130/160 (eksik dokümantasyon, SPM yok). — [pub.dev unity_levelplay_mediation changelog](https://pub.dev/packages/unity_levelplay_mediation/changelog); [Unity LevelPlay Flutter entegrasyonu](https://docs.unity.com/en-us/grow/levelplay/sdk/flutter/plugin-integration)
- Web: H5 Games Ads kapalı beta; politika incelemesi ve kayıt gerekli; `google_adsense` paketinde `h5.dart` ile Ad Placement API (`adBreak`, rewarded tip) kullanılabiliyor; onaysız kullanım AdSense hesabında politika sorunu yaratabilir; her ödüllü reklam kullanıcı tarafından tek tek seçilmeli. — [google_adsense H5 Games Ads topic](https://pub.dev/documentation/google_adsense/latest/topics/H5%20Games%20Ads-topic.html); [Ad Placement API](https://developers.google.com/ad-placement/apis); [H5 Games Ads](https://adsense.google.com/start/h5-games-ads/); [Reward policy](https://support.google.com/publisherpolicies/answer/11975916)

### Inferences
- Web build'de reklam ya kapatılmalı ya da ayrı AdSense H5 başvurusu yapılmalı; web ödüllerinde sunucu tarafı doğrulama (SSV) eşdeğeri bulunmadığından web'de ödüllü reklam ödülü güvenilir şekilde sunucuda verilemez (bu çıkarım, SSV bulunamamasına dayanıyor).
- `google_mobile_ads` 9.x minimum Flutter 3.38+ istiyor; projenin Flutter sürümü bununla uyumlu olmalı.

### Gaps
- `applovin_max` ve `unity_levelplay_mediation` tam son sürüm tarihleri net değil.
- Ad Placement API'nin sunucu tarafı ödül doğrulaması olup olmadığı bulunamadı.

## 3. Ödüllü reklamlarda sunucu tarafı doğrulama (SSV / S2S)

### Takeaway
AdMob SSV, ECDSA-SHA256 imzalı bir GET callback'i gönderir; Dart backend'de Google'ın public key'leriyle imza doğrulanıp `transaction_id` ile tekilleştirme yapılmalı. Flutter'da `ServerSideVerificationOptions(userId, customData)` reklam gösterilmeden önce set edilir. MAX'te ad unit bazında Server Side Callback URL tanımlanır ve makrolarla (`{CUSTOM_DATA}`, `{EVENT_ID}`) bilgi gelir.

### Cited Findings
- AdMob SSV callback parametreleri: `ad_network`, `ad_unit`, `reward_amount`, `reward_item`, `timestamp`, `transaction_id`, `custom_data`, `user_id`, `key_id`, `signature` (son ikisi her zaman sonda). — [AdMob Flutter SSV](https://developers.google.com/admob/flutter/ssv)
- Doğrulama: anahtarlar `https://gstatic.com/admob/reward/verifier-keys.json`'dan alınır, `key_id` ile eşleştirilir; `&signature=` öncesindeki sorgu metni değiştirilmeden ECDSA SHA-256 (DER) ile doğrulanır; anahtarlar en fazla 24 saat önbelleğe alınmalı (rotasyon var). — [AdMob Flutter SSV](https://developers.google.com/admob/flutter/ssv)
- Flutter API: `ServerSideVerificationOptions` (`customData`, `userId`) `onAdLoaded` içinde `ad.setServerSideOptions(...)` ile, gösterimden önce set edilir. — [AdMob Flutter SSV](https://developers.google.com/admob/flutter/ssv)
- Callback gecikebilir; oyun ekonomisi gibi kritik ödüllerde doğrulanmış sunucu callback'ini beklemek öneriliyor. Sunucu HTTP 200 dönmezse Google 1 sn aralıkla 5 kez yeniden dener. — [AdMob Flutter SSV](https://developers.google.com/admob/flutter/ssv)
- MAX S2S: callback URL "Edit Ad Unit" sayfasında rewarded ad unit için "Server Side Callback URL" olarak girilir; `{CUSTOM_DATA}` URL-encoded özel veri (8192 karakter altı önerilir); `{EVENT_ID}` 40 hex karakterlik benzersiz olay kimliği; 5 sn zaman aşımı, en fazla 2 tekrar; test reklamlarında S2S callback gönderilmez. — [AppLovin S2S Rewarded Callback API](https://developers.applovin.com/en/max/advanced-features/s2s-rewarded-callback-api); [AppLovin destek](https://support.applovin.com/en/max/advanced-features/s2s-rewarded-callback-api); [How S2S callback works](https://support.applovin.com/en/max/faq/how-server-to-server-callback-works)

### Inferences
- Dart Shelf tarafında: (1) public GET endpoint, (2) ham query string'i saklayıp imzayı doğrulama (Dart'ta `pointycastle` veya `cryptography` paketi gibi ECDSA P-256 destekli bir kütüphane), (3) `transaction_id`'yi PostgreSQL'de UNIQUE kolonla saklayıp idempotent ödül, (4) `custom_data` içine sunucuda üretilen tek kullanımlık "reward intent" kimliği koyup kullanıcı/ödül tipini eşleştirme, (5) günlük ödül limiti.
- MAX'te test reklamlarında callback gelmediği için geliştirme sırasında ayrı test yolu gerekir.

### Gaps
- MAX S2S callback'inin imza/hash doğrulama mekanizması (ör. `{EVENT_TOKEN}` + event key hash) rewarded sayfasında doğrulanamadı; tam makro tablosu okunmalı.
- Unity LevelPlay'in sunucu tarafı ödül callback'i (S2S) bu araştırmada incelenmedi.
- Mediation üzerinden başka ağın reklamı gösterildiğinde AdMob SSV'nin çalışıp çalışmadığı (ad_network parametresi bunu ima ediyor) açıkça doğrulanmadı.

## 4. Ödüllü video eCPM kıyasları (Türkiye vs. global, Android vs. iOS)

### Takeaway
Ödüllü video en yüksek eCPM'li format. ABD ~$13-30, Kuzey Amerika iOS ~$13.6-13.9 / Android ~$9; Avrupa iOS ~$8.9 / Android ~$5.1; Orta Doğu Android ~$2.3-2.4. Türkiye için güvenilir, yayımlanmış bir ödüllü video eCPM rakamı bulunamadı; Türkiye'nin gelişmekte olan pazar bandında (Android muhtemelen $1-3 aralığı) olduğu yalnızca bir çıkarım.

### Cited Findings
- Appodeal Q4 2024 (Ekim-Aralık 2024) bölgesel ödüllü video eCPM (grafikten okunmuş, yaklaşık): Kuzey Amerika iOS ~$13.6-13.9 / Android ~$9.0-9.2; Avrupa iOS ~$8.8-8.9 / Android ~$5.1; APAC iOS ~$7.5 / Android ~$8.2; Orta Doğu iOS ~$8.4 / Android ~$2.3-2.4; LATAM iOS ~$3.4-3.75 / Android ~$1.8-1.9. — [Playio 2026 benchmarks](https://blog.playio.co/mobile-game-ecpm-benchmarks-2026); [Mistplay (eski Maf.ad), Mart 2026](https://business.mistplay.com/resources/mobile-ads-ecpm/); [Appodeal Q4 2024 PDF](https://appodeal.com/wp-content/uploads/2025/03/Quarterly_Mobile_eCPM_Report_-_Q4_2024.pdf)
- Appodeal verisiyle ülke ortalaması (iOS+Android): ABD $15.15, BAE $14.55, Avustralya $13.80, İsviçre $12.20, İngiltere $10.65, Japonya $10.80. Türkiye listede yok. — [Mistplay](https://business.mistplay.com/resources/mobile-ads-ecpm/)
- Tenjin × CAS Q2 2024 (oyun uygulamaları): iOS ABD $24.39, G. Kore $20.94, Avustralya $19.91; Android ABD $30.25, Kanada $23.13, G. Kore $22.01. — [Playio](https://blog.playio.co/mobile-game-ecpm-benchmarks-2026)
- Playwire (17 Eylül 2025): ödüllü video Tier 1 $15-30, global $8-18; interstitial $2.50-5.00 (metodoloji açıklanmamış). — [Playwire AdMob eCPM benchmarks](https://www.playwire.com/blog/admob-ecpm-benchmarks-what-publishers-should-expect)
- Appodeal: ödüllü video her iki platformda en yüksek eCPM'li format; LATAM ve MEA düşük eCPM ama hacim potansiyeli. — [Appodeal eCPM report](https://appodeal.com/the-mobile-ecpm-report-updated-q4-2024-view)
- Applixir: Latin Amerika / gelişmekte olan pazarlar genelde $2-3, bazen $2 altı. — [Applixir](https://www.applixir.com/?p=21)
- Tenjin 2025 verisinde Türkiye, Japonya ve Brezilya ile birlikte %5 pay ile geçiyor (bu gelir/hacim payı, eCPM değil). — [Tenjin ad mon gaming 2026](https://tenjin.com/tr/blog/ad-mon-gaming-2026/)
- Anekdot: Unity forumunda Türkiye'de Unity Ads ile çok düşük eCPM (tek kullanıcı, eski). — [Unity Discussions](https://discussions.unity.com/t/very-low-ecpm-unexpectedly/705175)
- TopOn 2025 H1: Hong Kong/Makao/Tayvan, Japonya/Kore, Avrupa ve Kuzey Amerika en iyi performanslı pazarlar. — [TopOn 2025 H1 rapor](https://mores.toponad.com/reports/TopOn%20Global%20Mobile%20Games%20Monetization%20Report%20_%202025%20H1.pdf)

### Inferences
- Türk kullanıcı tabanı ağırlıklıysa ödüllü video geliri batı pazarlarının bir kesri olacak; gelir modeli IAP'ye ve oyun ekonomisinde reklam başına küçük ödüllere dayanmalı. Gerçek Türkiye rakamı ancak canlı AdMob/MAX paneli ülke raporuyla öğrenilir.
- Orta Doğu verisinde iOS/Android farkı çok büyük (~$8.4 vs ~$2.4); Türkiye'de de iOS kullanıcıların reklam değeri belirgin şekilde yüksek olabilir (doğrulanmadı).

### Gaps
- Türkiye için 2024-2026 ödüllü video eCPM rakamı hiçbir güvenilir kaynakta bulunamadı (Appodeal'in ülke filtreli interaktif raporu erişilemedi).
- 2025 Q3/Q4 güncel mutlak rakamlar (Appodeal 2025 raporları) alınamadı; elimizdeki en sağlam veri Q4 2024.

## 5. Ödeme ve gereksinimler (AdMob eşiği, Türkiye vergi/banka, app-ads.txt)

### Takeaway
Google'ın TRY tablosuna göre ödeme eşiği ₺200, ödeme yöntemi eşiği ₺20, doğrulama eşiği $10 karşılığı; ödeme aylık, ayın ~21'inde, havale (wire) ile ~10 günde ulaşır. Türkiye vergi detayları için ayrıca kaynak gerekli.

### Cited Findings
- TRY: vergi bilgisi eşiği yok (N/A), doğrulama eşiği $10 karşılığı, ödeme yöntemi eşiği ₺20, ödeme eşiği ₺200, iptal eşiği ₺20 (Ad Manager ve AdSense tablolarında; AdMob için Payments sayfasından doğrulanmalı). — [Ad Manager payment thresholds](https://support.google.com/admanager/answer/2731681?hl=en); [AdSense payment thresholds](https://support.google.com/adsense/answer/1709871?hl=en)
- AdMob ödeme döngüsü aylık; eşik aşılmışsa ve bekletme yoksa ayın ~21'inde ödeme; havaleler ~21'inde başlatılır, ulaşması 10 güne kadar sürer; eşik altı bakiye devreder. — [AdMob payment timeline](https://support.google.com/admob/answer/2772208?hl=en)
- Google konuma göre vergi bilgisi isteyebilir; Türkiye, vergi mukimliği belgesi kabul edilen ülke listesinde geçiyor; belge Payments > Manage settings'ten yüklenir. — [AdMob tax info](https://support.google.com/admob/answer/14135099?hl=en)

### Inferences
- Türk geliştirici için yurt dışından gelen reklam geliri büyük olasılıkla döviz havalesi olarak gelir; gelir vergisi / şahıs şirketi / "hizmet ihracatı" konuları bir mali müşavirle netleştirilmeli (kaynaklı bulgu değil).

### Gaps
- app-ads.txt gereksinimleri bu araştırmada ayrıca kaynaklanmadı (AdMob, mağaza listesindeki geliştirici web sitesinin köküne app-ads.txt konmasını istiyor — doğrulanması gerekir).
- Türkiye'de reklam gelirinin vergilendirilmesi, döviz hesabı ve AppLovin/Unity ödeme eşikleri için kaynak bulunamadı.

## 6. Flutter IAP: resmi in_app_purchase vs. RevenueCat / Adapty / Qonversion; sunucu doğrulama ve iadeler

### Takeaway
Zaten kendi backend'i olan bir proje için resmi `in_app_purchase` + kendi sunucu doğrulaması (Google Play Developer API + RTDN + Voided Purchases; App Store Server API + Server Notifications V2) maliyetsiz ve tam kontrollü. RevenueCat $2.5K MTR'ye kadar ücretsiz, üstü %1; Adapty $5K'ya kadar ücretsiz (Şubat 2026 değişikliği), üstü %1; Qonversion $10K'ya kadar ücretsiz. Ana ürün tüketilebilir (gem) ise abonelik platformlarının avantajı sınırlı.

### Cited Findings
- RevenueCat: Pro plan $2.5K aylık izlenen gelire (MTR) kadar ücretsiz; üstünde MTR'nin %1'i; eski Pro %1.2 idi; ödeme bilgisi yoksa $2.5K'ya ulaşınca bazı özellikler kısıtlanıyor. — [RevenueCat pricing](https://www.revenuecat.com/pricing/)
- RevenueCat Flutter SDK (`purchases_flutter`) StoreKit 2 için dashboard'da In-App Purchase Key gerektiriyor. — [purchases_flutter changelog](https://pub.dev/packages/purchases_flutter/changelog)
- Adapty: 16 Şubat 2026 itibarıyla Pro (ücretsiz <$5K MTR, sonra %1) ve Enterprise; eski $10K ücretsiz eşiği geçersiz. — [Adapty new pricing 2026](https://adapty.io/blog/adapty-new-pricing-2026/); [Adapty pricing](https://adapty.io/pricing/)
- Qonversion: resmi sayfada $10K MTR'ye kadar ücretsiz; ücretli kademeler hakkında üçüncü taraf kaynaklar çelişkili. — [Qonversion pricing](https://qonversion.io/pricing)
- Resmi `in_app_purchase_storekit`: 0.4.10 StoreKit 2'de bitmemiş işlem varken yinelenen satın almayı engelliyor; 0.4.9 StoreKit 2 offer code desteği ve minimum Flutter 3.38; 0.4.8+1 iptal/beklemede/doğrulanmamış sonuçları purchaseStream'e iletiyor. — [in_app_purchase_storekit changelog](https://pub.dev/packages/in_app_purchase_storekit/changelog)
- Kasım 2025 PR: `SK2Transaction.unfinishedTransactions()` önerisi (birleşme durumu belirsiz). — [flutter/packages #10439](https://github.com/flutter/packages/pull/10439)
- Topluluk alternatifi `flutter_inapp_purchase` (9.x) StoreKit 2'yi tam destekliyor (iOS 15+). — [flutter_inapp_purchase changelog](https://pub.dev/packages/flutter_inapp_purchase/changelog)
- Google Play Voided Purchases API: iade/chargeback/iptal edilen siparişleri listeler (tek seferlik ürünler ve abonelikler), yalnız son 30 gün; `voidedSource` (kullanıcı/geliştirici/Google); kota 6.000 sorgu/gün/paket. — [Voided Purchases API](https://developers.google.com/android-publisher/voided-purchases?hl=en); [REST voidedpurchases](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.voidedpurchases)
- RTDN: voided purchase bildirimleri `refundType` içerir (tam iade veya çok adetli satın almada miktar bazlı kısmi iade); polling yerine RTDN önerilir; `messageId` ile tekilleştirme; Play Console'da voided purchase bildirimi tek seferlik ürün bildiriminden ayrı seçenek. — [RTDN reference](https://developer.android.com/google/play/billing/rtdn-reference); [Play Billing codelab](https://codelabs.developers.google.com/maximise-your-play-billing-integration)
- Tüketilebilir ürünler hızla consume edilmeli ki tekrar satın alınabilsin. — [Play Billing codelab](https://codelabs.developers.google.com/maximise-your-play-billing-integration)

### Inferences
- Önerilen akış (gem paketleri): istemci satın alır → purchaseToken / StoreKit 2 JWS işlemi backend'e gider → backend Google Play Developer API (purchases.products.get) veya App Store Server API ile doğrular → gem'i PostgreSQL'de idempotent (order_id/transaction_id UNIQUE) verir → ancak sonra istemci `completePurchase`/consume yapar. İadede (RTDN voided / App Store REFUND bildirimi) gem bakiyesi geri alınır veya eksiye düşürülür.
- Abonelik (ör. VIP pass) eklenecekse RevenueCat'in yenileme/grace period yönetimi zaman kazandırır; $2.5K altında ücretsiz.

### Gaps
- App Store Server API / App Store Server Notifications V2 (REFUND, CONSUMPTION_REQUEST) ayrıntıları ve Dart'ta JWS doğrulama bu araştırmada kaynaklanmadı.
- Resmi `in_app_purchase` ana paketinin güncel sürüm numarası ve tarihi alınamadı.
- Türkiye'de mağaza fiyatlandırması / KDV kesintileri incelenmedi.
