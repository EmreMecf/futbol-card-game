# Gizlilik ve Uyum: Reklam (ödüllü video) + Uygulama İçi Satın Alma (IAP) — Futbol Card Arena

Kapsam: Flutter (iOS, Android, web), Türk şahıs geliştirici, kullanıcılar Türkiye + AB + dünya. AdMob veya AppLovin MAX ile ödüllü video, mağaza IAP, e-posta/kullanıcı adı + Google/Apple girişi. Araştırma tarihi: Kasım 2026. Bu notlar hukuki görüş değildir; "BELİRSİZ" etiketli maddeler mutlaka resmi metinden veya avukat/SMMM ile doğrulanmalı.

## 1) AB/AEA/BK/İsviçre: GDPR rızası, IAB TCF v2.2, Google sertifikalı CMP (UMP), rıza yoksa ne olur

### Takeaway
AEA, BK ve İsviçre'de kişiselleştirilmiş reklam için Google sertifikalı, IAB TCF ile entegre bir CMP zorunlu (AEA/BK: 16 Ocak 2024, İsviçre: 31 Temmuz 2024). En basit yol Google'ın UMP SDK'sı (Flutter: google_mobile_ads içindeki ConsentInformation/ConsentForm); sertifikasız CMP trafiği yalnızca kişiselleştirilmemiş/sınırlı reklam alabilir.

### Cited Findings
- AdSense, Ad Manager ve AdMob yayıncıları AEA, BK veya İsviçre'de kişiselleştirilmiş reklam sunmak için IAB TCF ile entegre, Google sertifikalı bir CMP kullanmak zorunda. Başlangıç: AEA ve BK için 16 Ocak 2024, İsviçre için 31 Temmuz 2024 — [AdMob Help: Google consent management requirements](https://support.google.com/admob/answer/13554116?hl=en); [Ad Manager eşdeğer sayfası](https://support.google.com/admanager/answer/13554116?hl=en)
- Kişiselleştirilmiş reklama yalnızca sertifikalı CMP'den gelen trafik uygun; diğer CMP'lerden gelen trafik kişiselleştirilmemiş veya sınırlı reklam alabilir — [AdMob Help 13554116](https://support.google.com/admob/answer/13554116?hl=en)
- Google, CMP'leri TCF odaklı kriterlere göre değerlendiriyor ama TCF'ye veya gizlilik hukukuna tam uyumu denetlemiyor (yani sertifika ≠ GDPR uyumu) — [AdMob Help 13554116](https://support.google.com/admob/answer/13554116?hl=en)
- UMP SDK isteğe bağlı; sertifikalı listedeki herhangi bir CMP kullanılabilir. Google, uygulama yayıncılarına UMP SDK'yı bir seçenek olarak sunuyor; Flutter için ayrı rehber var — [AdMob Flutter: Disclose to EEA users (GDPR)](https://developers.google.com/admob/flutter/privacy/gdpr); [AdMob iOS GDPR](https://developers.google.com/admob/ios/privacy/gdpr)
- Sertifikalı CMP listesi düzenli güncelleniyor; kayıtlı kopyaya güvenmek yerine güncel liste kontrol edilmeli — [AdMob Help 13554116](https://support.google.com/admob/answer/13554116?hl=en)

### Inferences
- AppLovin MAX seçilirse de AdMob'un mediasyon ağı olarak kullanılması ya da Google talebi alınması durumunda sertifikalı CMP gerekecektir; MAX'in kendi "Terms & Privacy Policy Flow" aracının Google sertifikalı olup olmadığı ayrıca kontrol edilmeli (bu araştırmada doğrulanmadı).
- Uygulama hesap sistemi olduğu için önerilen akış: uygulama açılışında UMP `requestConsentInfoUpdate` → gerekiyorsa form → `canRequestAds` true olmadan reklam yüklememe; ayarlar ekranında "Gizlilik seçenekleri" butonu (UMP privacy options entry point) bulundurma.
- Web sürümünde AdMob yoktur; web'de reklam gösterilecekse AdSense/Ad Manager + aynı sertifikalı CMP kuralı geçerli olur (çıkarım).
- "Consent Mode" web/Google Analytics kavramıdır; mobil uygulamada Firebase Analytics kullanılıyorsa consent mode v2 sinyallerinin (ad_storage, ad_user_data, ad_personalization) ayarlanması gerekebilir — bu araştırmada kaynakla doğrulanmadı.

### Gaps
- TCF v2.2'nin içerik detayları (meşru menfaat temelinin reklam kişiselleştirmede kaldırılması, vendor sayısı açıklaması) için IAB Europe birincil kaynağı çekilmedi.
- "Limited ads" ile "non-personalized ads" arasındaki eCPM farkı için sayısal veri bulunmadı.
- AppLovin MAX CMP'sinin Google sertifika durumu doğrulanmadı.

## 2) iOS: ATT, SKAdNetwork/AdAttributionKit, gizlilik etiketleri, privacy manifest

### Takeaway
IDFA kullanılacaksa ATT izni şart; izin için ödül verilemez ve reddeden kullanıcıdan özellik esirgenemez. 1 Mayıs 2024'ten beri required-reason API kullanımı privacy manifest'te açıklanmayan uygulamalar App Store Connect'e kabul edilmiyor; yaygın üçüncü taraf SDK'lar (Google Mobile Ads, AppLovin dahil) kendi imzalı manifestleriyle gelmeli. SKAdNetwork için Google'ın (ve mediasyon ağlarının) SKAdNetwork ID'leri Info.plist'e eklenmeli.

### Cited Findings
- App Review Guideline 5.1.2(i): uygulamalar takibe izin veren kullanıcıyı ödüllendiremez veya reddedenlerden özellik esirgeyemez (ikincil kaynak; Apple metni doğrudan çekilmedi) — [Adapty: ATT glossary](https://adapty.io/glossary/app-tracking-transparency/)
- Apple politikası ATT istemini yükleme başına bir kez göstermeye izin veriyor (Unity dokümanı) — [Unity Ads: ATT compliance](https://docs.unity.com/ja-jp/ads-ios/4.19.0/privacy/ios14/att-compliance)
- Google, ATT isteminden hemen önce verinin nasıl kullanıldığını anlatan bir açıklama mesajı (explainer) gösterilebileceğini ve metnin test edilmesini öneriyor; SKAdNetwork için Google'ın ağ anahtarı yapılandırılmalı — [AdMob Help: Privacy strategies for iOS](https://support.google.com/admob/answer/9997589?hl=en)
- SKAdNetwork ve AdAttributionKit ATT izni olmadan toplu (aggregate) ölçüm yapar; AdAttributionKit iOS 17.4 (Mart 2024) ile geldi (ikincil kaynak) — [Adapty](https://adapty.io/glossary/app-tracking-transparency/)
- 1 Mayıs 2024'ten itibaren required-reason API kullanımını privacy manifest'te açıklamayan uygulamalar App Store Connect'e kabul edilmiyor — [Apple Developer News: Privacy requirement starts May 1](https://developer.apple.com/news/?id=pvszzano); [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- Üçüncü taraf SDK kendi kodunun kullandığı API'leri kendi privacy manifest'inde beyan etmeli; uygulamanın manifestine dayanamaz. Mayıs 2024 kuralı "yaygın kullanılan SDK" listesindeki yeni eklenen SDK'lar için geçerliydi — [Apple: Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements); [Apple: Privacy updates for App Store submissions](https://developer.apple.com/news/?id=3d8a9yyh)
- 12 Şubat 2025'ten itibaren gönderilen uygulamalar listedeki yaygın SDK'lar için geçerli privacy manifest içermeli — [Apple: Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements)
- Forumdaki Apple yanıtına göre uygulama, SDK'nın manifestindeki beyanları kendi dosyasında tekrar etmemeli — [Apple Developer Forums](https://developer.apple.com/forums/thread/738203)
- Tek kaynak (doğrulanmadı): Apple 16 Eylül 2026'da iOS 27.2 beta için alternatif ATT istem metni yayımlamış — [PPC Land](https://ppc.land/app-tracking-transparency/) — BELİRSİZ

### Inferences
- Ödüllü video için ATT reddi reklam ödülünü engellememeli; "izin verirsen ekstra jeton" gibi bir akış 5.1.2(i) ihlalidir.
- Flutter tarafında `app_tracking_transparency` vb. paketle istem; Info.plist'te `NSUserTrackingUsageDescription` (Türkçe + İngilizce yerelleştirme) gerekli (Apple genel bilgisi, bu oturumda kaynakla doğrulanmadı).
- AB kullanıcısında hem UMP (GDPR) hem ATT gerekir; Google'ın önerdiği sıra UMP formu → ATT istemi (UMP, IDFA explainer mesajını da gösterebiliyor) — sıralama kaynakla doğrulanmadı.
- App Store gizlilik "beslenme etiketleri" (App Privacy) formunda: reklam SDK'sı nedeniyle "Identifiers – Device ID", "Usage Data", "Diagnostics", "Purchases", hesap nedeniyle "Contact Info – Email", "User ID" beyan edilmesi ve "Used to Track You" bölümünün ATT kullanımına göre işaretlenmesi gerekir (çıkarım; Apple sayfası çekilmedi).
- Kendi uygulama kodu da `UserDefaults`, dosya zaman damgası, disk alanı gibi required-reason API kullanıyorsa (Flutter `shared_preferences` vb.) bunların plugin manifestleri kontrol edilmeli.

### Gaps
- Apple App Privacy (nutrition label) kategori listesinin birincil kaynağı çekilmedi.
- Privacy manifest zorunluluğunun tüm binary'ye genişleyip genişlemediği doğrulanmadı.
- Sign in with Apple zorunluluğu (Guideline 4.8) bu kapsamda araştırılmadı.

## 3) Google Play: Data safety, Reklam beyanı, AD_ID izni, Hedef kitle, Aileler politikası, çocuk etiketleri

### Takeaway
Play Console'da Data safety formu, "Ads" beyanı (uygulama reklam içeriyor), Advertising ID beyanı ve "Target audience and content" doldurulmalı. Hedef kitleye 13 yaş altı herhangi bir grup eklenirse Aileler politikası devreye girer: yalnızca Families Self-Certified Ads SDK'ları, çocuk/bilinmeyen yaştaki kullanıcıya reklam kimliği gönderilmemesi, tarafsız yaş ekranı. Ayrıca AppLovin SDK 13+ çocuk kullanıcıda hiç başlatılamaz — bu, karışık kitle senaryosunda AdMob'u daha uygun kılar.

### Cited Findings
- Android 13 (API 33)+ hedefleyen ve reklam kimliği kullanan uygulamalar manifestte `com.google.android.gms.permission.AD_ID` normal iznini beyan etmeli; beyan edilmezse kimlik sıfırlardan oluşan dizeyle değiştirilir. GMA SDK 20.4.0+ izni otomatik birleştirir; analitik/dolandırıcılık önleme gibi reklam dışı kullanımlar için App Set ID kullanılmalı — [Android 13 behavior changes](https://developer.android.com/about/versions/13/behavior-changes-13?hl=en); [AdMob Help 11402075](https://support.google.com/admob/answer/11402075?hl=en); [Play Console Help: Advertising ID](https://support.google.com/googleplay/android-developer/answer/6048248?hl=en)
- Yeni uygulama veya güncelleme yayınlarken hedef yaş grubu beyan edilmeli; Google beyanın doğruluğunu kendisi inceleyebilir — [Play Console Help: Target audience and app content](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en)
- Hedef kitlesinde çocuk içeren her uygulama Aileler politikasına uymalı; çocuklara yalnızca Families Self-Certified Ads SDK'larıyla reklam gösterilmeli; karışık kitlede çocukların yalnızca kişiselleştirilmemiş reklam görmesi için tarafsız yaş ekranı gerekir — [Play Console Help 9867159](https://support.google.com/googleplay/android-developer/answer/9867159?hl=en); [Play Console Help 9893335 (Families)](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)
- Designed for Families programında olmayan karışık kitleli uygulamalar sertifikasız reklam SDK'larını yalnızca 13 yaş üstüne reklam için kullanabilir — [Families Self-Certified Ads SDK Policy](https://support.google.com/googleplay/android-developer/answer/12918983)
- Families uyumlu reklam için her istekte `tagForChildDirectedTreatment(true)` ve `max_ad_content_rating = G` çağrılmalı; TFCD veya TFUA (tagForUnderAgeOfConsent) etiketli isteklerde reklam kimliği iletilmez — [Participate in the Families Ads Program](https://support.google.com/googleplay/android-developer/answer/9283445); [AdMob Help 11402075](https://support.google.com/admob/answer/11402075?hl=en)
- Hedef kitlede çocuk varsa uygulama çocuklar veya bilinmeyen yaştaki kullanıcılar için reklam kimliği dahil bazı tanımlayıcıları iletmemeli; Data safety'de SDK'lar dahil çocuklardan toplanan veri beyan edilmeli — [Play Console Help 9893335](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)
- Families Self-Certified Ads SDK programı: bir Google sayfası "şu anda yeni başvuru kabul etmiyor" diyor; eski sürüm 31 Ekim 2024'e kadar başvuru alıp 2025'te yeniden açılacağını söylüyordu — ÇELİŞKİLİ/BELİRSİZ — [Families Self-Certified Ads SDK Policy](https://support.google.com/googleplay/android-developer/answer/12918983)
- AppLovin: SDK 13.0.0'dan itibaren `setIsAgeRestrictedUser` desteklenmiyor; kullanıcı yasal tanımla "çocuk" ise SDK hiçbir şekilde başlatılamaz/kullanılamaz; yalnızca çocuklara yönelik (ör. iOS Kids kategorisi) uygulamalar AppLovin SDK'sını kullanamaz — [AppLovin MAX iOS Privacy](https://support.applovin.com/en/max/ios/overview/privacy); [AppLovin MAX Unity Privacy](https://support.applovin.com/en/max/unity/overview/privacy)

### Inferences
- En düşük riskli yol: Target audience'ı 13+ (ör. 13-15, 16-17, 18+) seçmek ve uygulamayı çocuklara yönelik pazarlamamak; bu durumda Aileler politikası uygulanmaz. Ancak 13-15 seçimi Google'ın ek "teen" korumalarını tetikleyebilir (aşağıdaki boşluk).
- 13 altı dahil edilirse: kayıt sırasında tarafsız yaş ekranı (doğum yılı seçimi, "13 yaşından büyük müsün?" gibi yönlendirici olmayan), yaşa göre AdMob `RequestConfiguration` (TFCD/TFUA, maxAdContentRating G/PG) ve AppLovin'i çocuk kullanıcıda hiç başlatmamak gerekir.
- Teacher Approved programı sadece çocuk hedefli uygulamalar içindir; ticari kart/IAP odaklı bir oyun için hedeflenmemeli (çıkarım; kaynak çekilmedi).
- Data safety formunda beyan edilecek tipik kalemler: E-posta, Kullanıcı ID, Satın alma geçmişi, Uygulama etkileşimleri, Çökme günlükleri, Cihaz veya diğer ID'ler (reklam ID); "üçüncü tarafla paylaşım" reklam SDK'ları için işaretlenmeli; aktarımda şifreleme ve hesap silme yolu (Play hesap silme URL'si zorunluluğu) belirtilmeli (çıkarım; Play hesap silme kuralı bu oturumda kaynakla doğrulanmadı).

### Gaps
- Google Play'in 13-15 yaş grubu için reklam/IAP kısıtları net olarak bulunamadı.
- Teacher Approved ve Play "Ads declaration" alanının güncel form içeriği doğrulanmadı.
- Families Self-Certified SDK listesinin güncel üyeleri (AdMob, AppLovin sürümleri) doğrulanmadı.

## 4) Yaş: COPPA (2025 değişikliği), UK AADC, AB DSA reşit olmayanlar rehberi, yaş kapıları

### Takeaway
Değiştirilmiş COPPA Kuralı 23 Haziran 2025'te yürürlüğe girdi; uyum tarihi 22 Nisan 2026 (geçti). Futbol kart oyunu ABD açısından "karışık kitle" sayılabilir; 13 altı kullanıcıyı tespit eden yaş kapısı + çocuk modu (kişiselleştirme yok, AppLovin yok) en güvenli yol. AB'de Komisyon'un 14 Temmuz 2025 DSA m.28 rehberi bağlayıcı değil ama uyum ölçütü; loot box ve sanal para gibi çocukların ticari okuryazarlık eksikliğini istismar eden özellikleri hedef alıyor — kart paketi (rastgele ödül) mekaniği için kritik.

### Cited Findings
- FTC'nin son COPPA değişiklikleri 22 Nisan 2025'te Federal Register'da yayımlandı, 23 Haziran 2025'te yürürlüğe girdi; çoğu hüküm için uyum tarihi 22 Nisan 2026 (§312.11(d)(1), (d)(4), (g) hariç) — [Federal Register 2025-05904](https://www.federalregister.gov/documents/2025/04/22/2025-05904/childrens-online-privacy-protection-rule); [Hunton](https://www.hunton.com/privacy-and-cybersecurity-law-blog/coppa-rule-amendment-compliance-deadline-approaches)
- Değiştirilmiş kural, çocuk hedefli hizmetler ile 13 yaş altından veri topladığını fiilen bilen (actual knowledge) operatörler için tam yürürlükte — [Finnegan](https://www.finnegan.com/en/insights/articles/coppas-amended-rule-is-now-in-full-effect-what-operators-need-to-know.html); [Davis Polk](https://www.davispolk.com/insights/client-update/ftc-prioritizes-coppa-enforcement-new-compliance-obligations-take-effect)
- Google'ın çocuk korumaları COPPA ve UK Age Appropriate Design Code (AADC) uyumunu destekler; dijital rıza yaşının altındaki kullanıcılar için reklam kişiselleştirmesini kapatır ve hassas reklam kategorilerini kısıtlar — [Google Ads policy: Ad-serving protections for children](https://support.google.com/adspolicy/answer/14170968?hl=en); [Ad protections for children and teens](https://support.google.com/adspolicy/answer/15416897?hl=en)
- AB Komisyonu reşit olmayanların korunmasına ilişkin nihai rehberi 14 Temmuz 2025'te yayımladı; gönüllü ama DSA m.28(1) uyumunda ölçüt olarak kullanılacak — [EC Digital Strategy](https://digital-strategy.ec.europa.eu/en/library/commission-publishes-guidelines-protection-minors); [EUR-Lex C/2025/5519](https://eur-lex.europa.eu/eli/C/2025/5519/oj)
- Rehber, çocukların sınırlı ticari okuryazarlığının istismarını (manipülatif reklam, loot box, bazı sanal paralar) engellemeyi amaçlıyor — [Hunton](https://www.hunton.com/privacy-and-cybersecurity-law-blog/european-commission-issues-guidelines-on-the-protection-of-minors); [CMS](https://cms.law/en/fra/news-information/protecting-minors-in-the-digital-space)
- Mayıs 2025 taslağı loot box/kumar benzeri uygulamaların aşırı harcamaya yol açabileceği yerlerde kullanılmamasını öneriyordu; nihai metinde aynen korunup korunmadığı doğrulanmadı — [Deloitte Legal Briefs](https://legalbriefs.deloitte.com/post/102kbir/european-commission-consults-on-guidelines-to-protect-children-online)

### Inferences
- DSA m.28 "çevrimiçi platformlar" için geçerlidir; kullanıcılar arası içerik barındırma/yayma yoksa saf bir oyun uygulaması "platform" sayılmayabilir. Sohbet/arkadaş maçı gibi sosyal özellikler kapsamı tartışmalı hale getirir — BELİRSİZ, avukat görüşü gerekir. Kapsam dışı olsa bile rehber, AB tüketici hukuku (UCPD) ve ileride Digital Fairness Act açısından iyi uygulama referansıdır.
- Kart paketi (rastgele içerik) satışı: olasılıkların (drop rate) açıklanması hem Apple (Guideline 3.1.1 "loot box" oranları) hem Google Play politikası gereğidir (genel bilgi; bu oturumda kaynak çekilmedi). Gerçek para ile rastgele paket satışı 18 yaş altına yönelik riskli; paketlerin yalnızca oyun içi kazanılan para ile alınması riski azaltır.
- Önerilen yaş kapısı: kayıt ekranında tarafsız doğum yılı/ay seçimi; <13 ise "çocuk modu" (TFCD, G içerik, kişiselleştirme yok, AppLovin başlatılmaz, sohbet kapalı), 13-17 ise TFUA (AB/BK dijital rıza yaşı ülkeye göre 13-16) ve harcama limitleri/uyarılar.
- UK AADC: varsayılan yüksek gizlilik, profillemenin varsayılan kapalı olması, nudge tekniklerinden kaçınma ilkeleri (genel bilgi; ICO sayfası çekilmedi).

### Gaps
- 2025 COPPA değişikliğinin ayrıntıları (hedefli reklam için ayrı ebeveyn rızası, veri saklama politikası yazılı zorunluluğu, güvenlik programı) birincil kaynaktan çekilmedi; Federal Register metni okunmalı.
- UK AADC'nin 15 standardı ve ICO'nun oyun rehberi bu oturumda çekilmedi.
- DSA rehberinin nihai loot box/sanal para ifadesi doğrulanmadı.

## 5) Türkiye: KVKK, tüketici hukuku (6502 / Mesafeli Sözleşmeler), vergi ve ödemeler

### Takeaway
KVKK: aydınlatma metni her durumda; reklam kişiselleştirme/profilleme ve analitik SDK'ları için amaç bazında ayrı (parçalı) açık rıza; rıza hizmet şartı yapılamaz. Yurt dışı aktarım (Google/AppLovin/Render sunucuları) 7499 sonrası m.9'a göre yapılmalı; standart sözleşme kullanılırsa imzadan itibaren 5 iş günü içinde KVKK'ya bildirim. VERBİS: 50 çalışan ve 100 milyon TL bilanço altındaki, ana faaliyeti özel nitelikli veri olmayan veri sorumluları muaf (şahıs geliştirici büyük olasılıkla muaf). Dijital IAP için Mesafeli Sözleşmeler Yönetmeliği m.15(1)(ğ) cayma hakkı istisnası var, ama satış öncesi bilgilendirme zorunlu. Vergi: GVK mük. 20/B mobil uygulama geliştirici istisnası — %15 stopaj, 2026 sınırı 5.300.000 TL, istisna belgesi + özel banka hesabı.

### Cited Findings
**KVKK — aydınlatma, açık rıza, çerez/SDK**
- KVKK Çerez Uygulamaları Hakkında Rehber 20/6/2022'de yayımlandı; masaüstü ve mobil web siteleri ile web uygulamalarını kapsar; bir kaynağa göre 2025'te güncellendi — [KVKK: Çerez Uygulamaları Hakkında Rehber](https://kvkk.gov.tr/Icerik/7353/Cerez-Uygulamalari-Hakkinda-Rehber); [Erdem & Erdem](https://www.erdem-erdem.av.tr/bilgi-bankasi/kisisel-verileri-koruma-kurumu-cerez-uygulamalari-hakkinda-rehberi-guncelledi)
- Zorunlu çerezler açık rıza gerektirmez; analitik, reklam ve kişiselleştirme çerezleri açık rıza gerektirir; her amaç için ayrı rıza; tek düğmeyle toplu onay yetmez; rıza hizmetin ön koşulu yapılamaz (çerez duvarı sorunlu) — [Hukukçular Evi](https://hukukcularevi.com/cerez-politikasi-ve-cerez-onayi-kvkk/); [Hukuki Haber](https://www.hukukihaber.net/kvk-kurumunun-cerez-uygulamalari-hakkinda-yayinladigi-rehber) (ikincil yorum)
- KVKK 14 Ocak 2026 duyurusu: mobil uygulamalarda anlık bildirim onay süreçleri "parçalı açık rıza" ve "belirlilik" ilkelerine göre yeniden gözden geçirilmeli — [KVKK: Mobil uygulamalar üzerinden gönderilen anlık bildirimler](https://www.kvkk.gov.tr/Icerik/8578/mobil-uygulamalar-uzerinden-gonderilen-anlik-bildirimlere-iliskin-kamuoyu-duyurusu)
- Kurul kararı: e-ticaret şirketinin site/mobil uygulamada çerezlerle hukuka aykırı veri işlemesi (davranışsal reklam/profilleme) — [KVKK Karar 2022/229 özeti](https://www.kvkk.gov.tr/Icerik/7275/2022-229)
- Aydınlatma her durumda yapılır; açık rıza yalnızca m.5/m.6'daki diğer şartlar yoksa başvurulan hukuki sebeptir — [Hukukçular Evi](https://hukukcularevi.com/cerez-politikasi-ve-cerez-onayi-kvkk/)

**KVKK — yurt dışına aktarım (7499)**
- 7499 sayılı Kanun m.34 ile KVKK m.9 değişti; Kurul'un 04.06.2024 tarih 2024/959 sayılı kararıyla standart sözleşme metinleri yayımlandı — [KVKK: Standart Sözleşmeler ve BCR dokümanları](https://www.kvkk.gov.tr/Icerik/7938/Standart-Sozlesmeler-ve-Baglayici-Sirket-Kurallarina-Iliskin-Dokumanlar-Hakkinda-Kamuoyu-Duyurusu); [KVKK: Yurt Dışına Aktarım](https://www.kvkk.gov.tr/Icerik/2053/Yurtdisina-Aktarim)
- Standart sözleşme, imzaların tamamlanmasından itibaren 5 iş günü içinde fiziki olarak, KEP ile veya Standart Sözleşme Bildirim Modülü üzerinden Kuruma bildirilmeli; her iki tarafın imza tarihi metinde yer almalı; geçerli imza yoksa sözleşme geçersiz — [KVKK: Standart sözleşmelerde dikkat edilecek hususlar (Şubat 2025)](https://www.kvkk.gov.tr/Icerik/8170/Yurt-Disina-Kisisel-Veri-Aktariminda-Kullanilacak-Standart-Sozlesmelerde-Dikkat-Edilmesi-Gereken-Hususlara-Iliskin-Kamuoyu-Duyurusu); [KVKK: Bildirim Modülü duyurusu](https://www.kvkk.gov.tr/Icerik/8043/Standart-Sozlesme-Bildirim-Modulu-Hakkinda-Kamuoyu-Duyurusu)
- Standart sözleşmelerin İngilizce çevirisi Kurum tarafından yayımlandı — [KVKK: Standard Contracts (EN)](https://kvkk.gov.tr/Icerik/7991/Standard-Contracts)

**VERBİS**
- Genel kural: yıllık çalışan sayısı 50'yi veya yıllık mali bilanço toplamı 100 milyon TL'yi aşan veri sorumluları kayıtlı olmalı (2023/1154 ile 25→100 milyon TL); bilanço esasına göre defter tutmayanlar için yalnız çalışan sayısı ölçütü — [Muhasebenews](https://www.muhasebenews.com/verbise-kayit-zorunluluguna-iliskin-2024-yili-hadleri-nedir/); [Hukuki Haber](https://www.hukukihaber.net/kisisel-verileri-koruma-kurulunun-04092025-tarihli-ve-20251572-sayili-karari-isiginda-verbis-kayit-yukumlulugunun-istisna-kapsaminda-degisimi)
- 04.09.2025 tarih 2025/1572 sayılı Kurul Kararı (RG 1 Ekim 2025): ana faaliyeti özel nitelikli veri işleme olanlar için istisna eşiği 10 çalışan / 10 milyon TL'ye düşürüldü — [KVKK Kamuoyu Duyurusu](https://kvkk.gov.tr/Icerik/8388/KAMUOYU-DUYURUSU); [Alomaliye: 2025/1572 uygulama esasları](https://www.alomaliye.com/2026/01/13/kisisel-verileri-koruma-kurulunun-2025-1572-sayili-kararinin-uygulama-esaslari/)
- VERBİS istisnası diğer KVKK yükümlülüklerini kaldırmaz — [Quasa](https://quasa.io/tr/media/verbis-istisnasi-kvkk-yukumluluklerini-ortadan-kaldirmiyor)

**Tüketici hukuku — dijital içerik / IAP cayma hakkı**
- Mesafeli Sözleşmeler Yönetmeliği m.15(1)(ğ): "Elektronik ortamda anında ifa edilen hizmetler veya tüketiciye anında teslim edilen gayrimaddi mallara ilişkin sözleşmeler"de tüketici cayma hakkını kullanamaz (taraflarca aksi kararlaştırılmadıkça); (h) bendi: cayma süresi bitmeden tüketicinin onayıyla ifasına başlanan hizmetler — [Lexpera: Mesafeli Sözleşmeler Yönetmeliği](https://www.lexpera.com.tr/mevzuat/yonetmelikler/mesafeli-sozlesmeler-yonetmeligi)
- m.5(1)(h): satıcı, sözleşme öncesi tüketicinin cayma hakkından yararlanamayacağını veya hangi koşullarda kaybedeceğini bildirmek zorunda; m.10: gerektiği gibi bilgilendirilmeyen tüketici için 14 günlük süre işlemez, süre en fazla bir yıl uzar — [Lexpera](https://www.lexpera.com.tr/mevzuat/yonetmelikler/mesafeli-sozlesmeler-yonetmeligi)
- 2022 değişikliğiyle eklenen (ı), (i), (j), (k) bentleri 1/1/2026'da yürürlüğe girdi; Danıştay 10. Daire 6/5/2026 kararıyla (ı), (j), (k) bentleri iptal edildi; 2025'te bir bent mülga — [Lexpera](https://www.lexpera.com.tr/mevzuat/yonetmelikler/mesafeli-sozlesmeler-yonetmeligi)

**Vergi — GVK mükerrer 20/B**
- İstisna, mobil cihazlar için geliştirilen uygulamalardan elektronik uygulama paylaşım/satış platformları üzerinden elde edilen kazanca yönelik; yalnız gerçek kişiler (Ltd/AŞ yararlanamaz); vergi dairesinden istisna belgesi (interaktif vergi dairesi) gerekir — [Muhasebenews: Mobil uygulama gelirleri nasıl vergilendirilir?](https://www.muhasebenews.com/?p=171723); [Muhasebenews: kazanç istisnası](https://www.muhasebenews.com/?p=147748)
- Türk bankasında bu faaliyete özel hesap açılmalı/belirlenmeli ve gelir bu hesaba gelmeli; hesap bilgisi başlangıçtan itibaren 1 ay içinde vergi dairesine bildirilmeli; banka %15 stopaj keser; şartlar sağlanırsa stopaj nihai, yıllık beyanname yok; stopaj brüt tutar üzerinden, gider düşülmez — [Muhasebenews ?p=171723](https://www.muhasebenews.com/?p=171723)
- 2026 yıllık sınır 5.300.000 TL; aşılırsa o faaliyetin tüm geliri (sadece aşan kısım değil) yıllık beyannameye girer, kesilen stopaj mahsup edilir; banka sınır aşılsa da kesmeye devam eder — [Muhasebenews ?p=171723](https://www.muhasebenews.com/?p=171723)
- İstisna kapsamındaki teslim/hizmetler KDVK m.17/4-a ile KDV'den istisna; defter tutma/belge düzenleme yükümlülükleri kaldırıldı; ücretli uygulama, IAP, abonelik, reklam ve sponsorluk gelirleri platform üzerinden elde edilmişse kapsama girebilir — [Muhasebenews ?p=171723](https://www.muhasebenews.com/?p=171723)
- GİB özelgesi örneği: oyun mobil cihazlara yönelik değilse ve gelir uygulama platformu üzerinden elde edilmiyorsa istisna uygulanmaz — [Lexpera özelge](https://www.lexpera.com.tr/mevzuat/ozelgeler/e-31435689-120-48570-sayili-ozelge-1)
- Düzenlemeyi getiren tebliğ: Gelir Vergisi Genel Tebliği Seri No 318 (RG 12 Ocak 2022) — [Resmî Gazete 12.01.2022](https://resmigazete.gov.tr/eskiler/2022/01/20220112-4.htm); [Alomaliye](https://www.alomaliye.com/?p=122957)

**Reklam içeriği — kumar/bahis**
- AdMob: hassas kategoriler "Standard" ve "Restricted" olarak ikiye ayrılır; "Gambling & Betting (18+)" kısıtlı kategoridir ve kumarın serbest olmadığı ülkelerde sunulmaz; alkol reklamı ülkeye göre değişir ve izinli ülkelerde opt-in'dir; en fazla 50 kategori engellenebilir; Mature (MA) seçmek, kumarı kapattıysanız onu açmaz — [AdMob: Block sensitive categories](https://support.google.com/admob/answer/3150953?hl=en); [AdMob: Ad content rating](https://support.google.com/admob/answer/10478094); [AdMob: Blocking controls](https://support.google.com/admob/answer/3150235?hl=en)
- Çocuklara yönelik içerikte yetişkin içerik, alkol ve kumar kategorileri kısıtlanır — [Google Ads policy 14170968](https://support.google.com/adspolicy/answer/14170968?hl=en)
- Türkiye: yasa dışı bahis 7258 sayılı Kanun m.5'te düzenlenir; yasa dışı bahis sitesi reklamı yapanlar için 1-3 yıl hapis ve adli para cezası belirtiliyor (hukuk bürosu kaynağı, rakamlar kaynaklar arasında tutarsız) — [Tahancı Hukuk](https://www.tahanci.av.tr/yasadisi-bahis-cezasi/); [Hukuki Haber](https://www.hukukihaber.net/yasa-disi-bahis-oynatma-bahis-oynanmasina-aracilik-etme-ve-bahis-oynama-kabahati-7258) — BELİRSİZ rakamlar
- Ticaret Bakanlığı Reklam Kurulu 14 Ağustos 2025 toplantısında yasa dışı bahis/kumar reklamlarını ana gündem yaptı ve yüksek takipçili hesaplara erişim engeli getirdi; 11 Aralık 2025'te 15 hesap için adli süreç kararı — [Ticaret Bakanlığı](https://ticaret.gov.tr/haberler/ticaret-bakanligi-reklam-kurulundan-kararli-mucadele-yasa-disi-bahis-ve-kumar-reklami-yaptigi-tespit-edilen-30-yuksek-takipcili-sosyal-medya-hesabina-erisim-engellendi); [Dünya](https://www.dunya.com/gundem/ticaret-bakanligi-duyurdu-yasa-disi-bahis-reklami-yapan-15-sosyal-medya-hesabi-kapatilacak-haberi-807428)

### Inferences
- KVKK uygulaması: (1) Türkçe aydınlatma metni (veri sorumlusu kimliği, amaçlar, hukuki sebepler, aktarım alıcıları — Google, AppLovin, Apple, barındırma sağlayıcısı —, yurt dışı aktarım, m.11 hakları ve başvuru yolu) giriş/kayıt ekranında ve ayarlarda; (2) reklam kişiselleştirme, analitik ve pazarlama bildirimi için ayrı ayrı, varsayılan kapalı açık rıza anahtarları; (3) Türkiye'deki kullanıcıya da (GDPR bölgesi dışında) bir rıza ekranı gösterilmeli — UMP yalnız AEA/BK/CH'de form gösterir, bu yüzden Türkiye için ya UMP'nin "diğer bölgeler" mesajı ya da uygulamaya özel KVKK rıza ekranı gerekir; rıza yoksa AdMob'da `npa=1` / kişiselleştirilmemiş istek (çıkarım).
- Yurt dışı aktarım: Google/Apple/AppLovin ile bireysel standart sözleşme imzalamak pratikte mümkün olmayabilir; m.9'daki "arızi aktarım" istisnaları veya açık rıza (arızi hallerde) yollarının uygulanabilirliği tartışmalı — BELİRSİZ, avukat görüşü gerekli. Render (ABD) gibi barındırmaların Türkiye dışı olması da yurt dışı aktarımdır.
- VERBİS: şahıs geliştirici bilanço esasına göre defter tutmuyorsa (20/B ile defter yükümlülüğü yok) yalnız çalışan sayısına bakılır → 50 altı olduğu için büyük olasılıkla kayıt yükümlülüğü yok; sağlık/biyometrik gibi özel nitelikli veri işlenmediği sürece.
- IAP cayma hakkı: Satın alma mağaza (Apple/Google) üzerinden yapıldığı için satıcı/aracı rolü ve iade politikası büyük ölçüde mağazaya ait; yine de uygulama içi mağaza ekranında "Dijital içerik anında teslim edilir; 6502 s. Kanun ve Mesafeli Sözleşmeler Yönetmeliği m.15(1)(ğ) uyarınca cayma hakkı yoktur" bilgilendirmesi ve satın alma öncesi onay verilmesi, m.5(1)(h) yükümlülüğünü karşılamak için önerilir (çıkarım).
- Reklam içeriği: genç kitle nedeniyle AdMob'da hesap düzeyinde Gambling & Betting, alkol, flört, siyasi, din, cinsel içerik vb. kategoriler engellenmeli; max ad content rating "T" (veya çocuk modunda "G"); AppLovin MAX tarafında da eşdeğer engellemeler (MAX dashboard'da ağ bazında) yapılmalı. Türkiye'de futbol temalı oyunda bahis reklamı görünmesi 7258 ve Reklam Kurulu açısından itibar ve yasal risk taşır.
- 20/B: web sürümünden (Flutter web) doğrudan elde edilen ödemeler (ör. Stripe) istisna kapsamında olmayabilir; IAP'nin yalnız App Store/Google Play üzerinden alınması 20/B uyumunu korur. Apple/Google ödemesi doğrudan özel hesaba (TL veya döviz) yatırılmalı. Sınır aşılırsa veya web gelirleri doğarsa şahıs şirketi/serbest meslek ya da Genç Girişimci İstisnası (GVK m.20) değerlendirilmeli — SMMM ile.
- Dijital Hizmet Vergisi (7194) eşikleri büyük şirketler içindir; şahıs geliştiricinin kendisini değil, Google/Apple'ı ilgilendirir (genel bilgi; bu oturumda kaynak çekilmedi). Türkiye'deki tüketiciye satılan IAP'lerde KDV'yi mağazalar tahsil eder (genel bilgi; doğrulanmadı).

### Gaps
- KVKK çerez rehberinin 2025 güncellemesinin içeriği (mobil SDK'lara özel hüküm olup olmadığı) birincil kaynaktan okunmadı.
- 13/18 yaş altı Türk kullanıcılar için KVKK'da açık rıza yaşı/veli rızası kuralı araştırılmadı (Medeni Kanun ayırt etme gücü yaklaşımı; avukat görüşü gerekir).
- Elektronik Ticaret Kanunu (6563) ve İYS (İleti Yönetim Sistemi): e-posta ile pazarlama/promosyon iletisi gönderilecekse ticari elektronik ileti onayı ve İYS kaydı gerekip gerekmediği bu oturumda araştırılmadı.
- 20/B'nin 2025 sınır tutarı, Genç Girişimci İstisnası ile birlikte uygulanabilirliği ve döviz ödemelerinde stopaj matrahı bulunamadı.
- 7258 sayılı Kanun'un reklam hükmünün resmi metni ve 2025 değişiklikleri doğrulanmadı.
- Dijital hizmet vergisi ve mağazaların Türkiye'de KDV tahsilatı için GİB kaynağı çekilmedi.
- AppLovin MAX'in hassas kategori/içerik derecelendirme kontrolleri için birincil kaynak bulunamadı.
