# Oyunun Parçası Gibi Hissettiren Reklam: Ödüllü Reklam ve Hibrit (IAP+IAA) Gelir Modeli (2024-2026)

Not: Araştırma 2026-11-27 tarihinde yapıldı. Kaynakların büyük bölümü reklam ağlarının (Unity/ironSource, AdMob, Anzu, Playio, Tapjoy) kendi yayınlarıdır. Bu yüzden sonuçları reklamı olumlu gösterme eğilimindedir. Bağımsız ve hakemli bir çalışma bulunamadı.

## 1. Doğal hissettiren ödüllü video yerleşimleri: hangileri, ne kadar iyi?

### Takeaway
En iyi bilinen doğal yerleşimler şunlar: ana ekranda veya mağazada "ücretsiz sandık/teklif", bekleme süresi kısaltma (sandık açma), maç ya da seviye sonu ödülü 2 katına çıkarma, günlük ödül çarpanı, kaybedince devam/seri koruma ve kaynak yenileme. Unity, ilk etapta 3-6 yerleşimle başlayıp tek tek A/B testi yapmayı öneriyor. Yerleşim başına etkileşim oranı veya DAU başına gösterim için kamuya açık, tarafsız bir benchmark yok.

### Cited Findings
- Unity'nin 5 temel yerleşimi (strateji oyunları için, Ocak 2023): (1) ana ekran: en çok görülen yer; temel kaynak, soft para veya gacha verilir, süre sınırı aciliyet yaratır; (2) oyun içi mağaza: sandık/gacha verilir, başlangıç sıklığı her 4-6 saatte 1 video; (3) seviye öncesi ve sonrası güçlendirici: kaybettikten sonra ekstra hak; fazlası sıkılmaya ve oyuncu kaybına yol açtığı için sınırlandırılmalı; (4) zaman kısaltma: kısaltma bekleme süresiyle orantılı olmalı (20 dk beklemede 10 dk, 3 saatte yaklaşık 1 saat); (5) günlük ödül çarpanı: günde 1 kez, örneğin 80 jeton ücretsiz + 20 jeton videoyla — [Unity Blog](https://unity.com/de/blog/3-monetization-mistakes-your-strategy-game-is-making-and-5-must-have-rewarded-video-placements)
- Aynı yazıdaki hatalar: videoyu rastgele yerlere (mini oyunlara) koymak; yeni oyunculara nadir para birimi vermek; yalnızca videoyla kazanılan üçüncü bir para birimi eklemek. Bir ortak, "film bileti" yerine doğrudan altın verdiğinde tüm KPI'larda "büyük sıçrama" gördü ve IAP zarar görmedi (rakam verilmemiş) — [Unity Blog](https://unity.com/de/blog/3-monetization-mistakes-your-strategy-game-is-making-and-5-must-have-rewarded-video-placements)
- Unity "temeller" yazısı (Aralık 2021) şu kalıpları sayıyor: premium tadımlık (War Robots 2 video karşılığı 1 günlük premium verir, 1 saatlik zamanlayıcıyla); oturum uzatma (enerji/can); kaynak yenileme (Zero City ödülü oyuncu seviyesine göre ölçekler); sürpriz sandık (Hustle Castle değeri göstermek için 1 ücretsiz sandık verir); 2-3 kat seviye sonu ödülü; kaçırılan teklifi yeniden göstermek. Ödülü eCPM'e göre değil, oyun ekonomisine göre ayarlamak gerekiyor; ödüllü video gelirini ekonomi dengesine baştan katmak gerekiyor — [Unity Blog](https://unity.com/blog/the-fundamentals-of-rewarded-video-ad-placements)
- Buton (trafik sürücüsü) tasarımı: renk, şekil ve konumla ayrışmalı (Subway Surfers mor + TV ikonu kullanır); ödül net yazmalı ("gelirini ikiye katla"); reklam tek dokunuşla başlamalı — [Unity Blog](https://unity.com/blog/the-fundamentals-of-rewarded-video-ad-placements)
- GameBiz deneyi (Ekim 2025, IAP ağırlıklı casual oyun, reklam gelirin %9'u): mağaza üstüne "FREE GOLD!" balonu eklendi; ücretsiz can teklifi can sıfırken değil, can maksimumun altındayken gösterildi; maç sonu butonu yeşilden sarıya çevrildi, "free" kelimesi ve 5 saniyelik geri sayım eklendi. Sonuçlar "anlamlı" deniyor, ancak rakamlar yalnızca görselde — [PocketGamer.biz](https://www.pocketgamer.biz/what-five-in-game-ad-experiments-taught-us-about-player-behaviour-and-revenue/)
- GameBiz deneyi (hibrit casual, gelir IAP ve RV arasında yarı yarıya): kaybedince devam yerleşiminin ilk sürümü bazı segmentlerde IAP'yi yedi. İkinci sürümde teklif daha ileri seviyelere ertelendi ve ülkeye özel sınırlar kondu. Sonuçta yerleşim reklam gelirinin %4'üne, sonra %7'sine ulaştı — [PocketGamer.biz](https://www.pocketgamer.biz/what-five-in-game-ad-experiments-taught-us-about-player-behaviour-and-revenue/)
- Squad Busters için önerilen yerleşimler (Mayıs 2024): sandık açarken ekstra ödül, mağaza veya ana ekranda izle-kazan, galibiyet serisini reklamla kurtarma (oyunda o sırada 500 jetondu) — [PocketGamer.biz / Božo Janković](http://www.pocketgamer.biz/supercells-big-squad-busters-mistake-and-how-theyre-missing-out-on-millions/)
- Sensor Tower, en yaygın 15 RV yerleşiminden 6'sıyla başlamayı öneriyor. RV'yi oyuncunun para yerine "zaman + dikkat" ile ödemesi olarak tanımlıyor; günlük limit ve sınırlı süreli kararları etkileşimi artıran unsurlar olarak sayıyor — [Sensor Tower](https://develop.sensortower.com/blog/ad-monetization-without-killing-retention-best-hybrid-monetization-practices)
- Appodeal Mobile Casual Benchmarks 2025 (yalnızca ABD Android, Haz 2024 - Oca 2025): kullanıcı başına ödüllü video Merge-3'te yaklaşık 101,5, Idle'da 73,2, Strateji'de yaklaşık 24,6. Rapor içindeki rakamlar kendi içinde tutarsız alıntılanıyor — [AppDeveloperMagazine](https://appdevelopermagazine.com/mobile-casual-benchmarks-report-2025/)
- Örnek model: 1M DAU, %50 etkileşim, izleyen başına 4 reklam, yani DAU başına yaklaşık 2 gösterim ve $20 eCPM ile aylık yaklaşık $1,2M (bu bir varsayım, ölçüm değil) — [PocketGamer.biz](http://www.pocketgamer.biz/supercells-big-squad-busters-mistake-and-how-theyre-missing-out-on-millions/)
- Rekabet ve canlı etkinlik: RV etkileşimi canlı etkinliklerde normalin %20-30 üzerine çıkıyor (AppLixir'e atfen, satıcı kaynak) — [Playio](https://blog.playio.co/mid-core-games-rewarded-ads-monetization)

### Inferences
- Futbol Card Arena'da en doğal yerleşimler: (a) sandık kilit süresini kısaltma (süreyle orantılı, örneğin kalan sürenin %30-50'si); (b) maç sonu ödülü x2 (yalnızca galibiyette veya her maçta, günlük limitli); (c) mağazada "ücretsiz günlük teklif/sandık" slotu (4-6 saatlik yenilenme); (d) günlük giriş ödülü çarpanı; (e) günlük görev yenileme (reroll); (f) kaybedince "kupa/seri koruma". Sonuncusu rekabetçi dereceli maçta adalet sorunu yaratır; dereceli dışındaki modlarda veya yalnızca seri sayacında kullanılması daha güvenlidir.
- Ödül olarak yalnızca altın (soft para) ve küçük miktarda öğe verilmeli. Gem (premium para) çok az veya hiç verilmemeli. Ayrı bir "reklam bileti" para birimi açılmamalı.
- Yerleşim başına etkileşim oranı tahmini kamuya açık veriyle desteklenemiyor. Kendi analitik olaylarınızla ölçmek gerekiyor.

### Gaps
- Yerleşim türüne göre (2x ödül, sandık hızlandırma, ücretsiz sandık) karşılaştırmalı etkileşim oranı veya DAU başına gösterim benchmark'ı bulunamadı. Sensor Tower ve GameAnalytics'in tam raporları ücretli veya kayıt gerektiriyor.
- "Günlük görev yenileme" ve "kayıp koruması" yerleşimleri için özel veri bulunamadı.

## 2. Gerçek oyun örnekleri

### Takeaway
Supercell oyun içi reklamı çok sınırlı kullanıyor: Hay Day ve Boom Beach'te ödüllü video var. 2024 itibarıyla Clash Royale, Brawl Stars ve Squad Busters'ta yok. Dream Games (Royal Match) saf IAP modelinde. Habby (Archero) ve Nordeus (Top Eleven) ise ödüllü reklamı tasarımın merkezine koyan hibrit örnekler.

### Cited Findings
- Supercell: Mayıs 2024 itibarıyla yalnızca Hay Day ve Boom Beach'te reklam var. Hay Day'de günlük ödül, rastgele ödül ve zamanlayıcı hızlandırma; Boom Beach'te (Kasım 2023'te eklendi, Şubat 2024'te genişletildi) küçük bonuslar ve mağazadaki Günlük Sandık'ı açarken ekstra ödül. Squad Busters reklamsız. Yazar, iyi kurulmuş bir sistemle reklamın Supercell gelirinin %10'u olabileceğini savunuyor — [PocketGamer.biz](http://www.pocketgamer.biz/supercells-big-squad-busters-mistake-and-how-theyre-missing-out-on-millions/)
- Brawl Stars: Ekim 2018'de soft launch sırasında "Reward Doubler" reklamları kaldırıldı — [Pocket Gamer](https://www.pocketgamer.com/brawl-stars/brawl-stars-is-set-to-remove-ads-indefinitely). Gamigion daha sonra bazı oyunculara reklam test edildiğini bildirdi (tarih belirsiz) — [Gamigion](https://www.gamigion.com/?p=4558)
- Clash Royale: 2025'te oyun içi reklam testi bulunamadı. Ağustos 2025 testi reklam değil, "Battle Rewards" (savaş ödülleri) testiydi — [Sportskeeda](https://www.sportskeeda.com/mobile-games/news-supercell-announced-testing-new-battle-rewards-clash-royale). AppGrowing'in "1661 reklamın %40'ı ödüllü video" verisi, Clash Royale'in kullanıcı kazanmak için başka uygulamalarda yayınladığı reklamlarla ilgili; oyun içi reklamla değil — [AppGrowing](https://appgrowing.net/blog/en/clash-royale/)
- Royal Match: freemium, reklamsız, IAP ile (jeton ve "daha fazla hamle" satışı) — [Wikipedia](https://en.wikipedia.org/wiki/Royal_Match). 2022'de $428M gelir — [Business of Apps](https://www.businessofapps.com/data/royal-match-statistics). Kardeş oyun Royal Kingdom'ın ödüllü ve interstitial reklam test ettiği yalnızca Gamigion'da geçiyor; doğrulanmadı — [Gamigion](https://www.gamigion.com/?p=33075)
- Archero (Habby): 6 farklı ödüllü video yerleşimi var (ekstra can/diriltme, bonuslar) — [Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/archero-monetization). Archero 2 ve Capybara Go'da yenilenmiş bir "Remove Ads" paketi var: ödüllü reklamları atlatıyor ve günlük gem ödülünü artırıyor — [Felix Braberg Substack](https://felixbraberg.substack.com/p/archero-2-review-the-evolution-of-fc7). Habby AdMob'a geçince reklam geliri %10 arttı — [AdMob](https://admob.google.ca/home/resources/habby-switches-to-admob-reports-ten-percent-increase-ad-revenue)
- Google araştırması (hibrit tür oyuncuları): ödeme yapan oyuncular, ilerlemeyi hızlandırdığında ödüllü reklamı ödeme yapmayanlardan daha çok kabul ediyor. Oyuncular reklamı oyunun başında veya sonunda tercih ediyor, ortasında değil — [Think with Google](https://thinkwithgoogle.com/intl/en-apac/marketing-strategies/app-and-mobile/mix-and-match-5-takeaways-hybrid-genre-game-marketing)
- Top Eleven (Nordeus, futbol menajerliği): ödüllü video ve offerwall hem gelir hem kullanıcı kazanımı için önemli — [ironSource (is.com)](https://www.is.com/?p=33074). GDC konuşmasında ödüllü video gelirinde %200 artış anlatılıyor — [GDC Vault](https://gdcvault.com/play/1025019/10-Lessons-Learned-Working-on). Mayıs 2026'da TyrAds ile özel ortaklık kuruldu (ödüllü etkileşim SDK'sı, "rahatsız etmeyen" ödül yolları) — [PocketGamer.biz](https://www.pocketgamer.biz/tyrads-announces-exclusive-strategic-partnership-with-nordeus)
- EA SPORTS FC Mobile: oyunda "Watch Ad" butonları ve günlük görevlere bağlı reklam ödülleri var. Oyuncular reklam ödülü için "maksimum reklam sayısına ulaştınız" uyarısı ve reklam yüklenmeme sorunları bildiriyor (2023-2024 forumları); yani günlük limit var — [EA Forum](https://forums.ea.com/discussions/fc-mobile-bug-reports-en/rewards-for-adverts-not-working/13005855), [EA Forum](https://forums.ea.com/discussions/fc-mobile-bug-reports-en/ads-are-not-working/13790927)
- Stumble Guys (Scopely): kozmetik IAP'nin üzerine reklam eklenmesi temel bir hamle olarak görülüyor. Gelir dağılımına dair üçüncü taraf tahminleri çelişkili (IAP %35 / reklam %65'e karşı IAP %67 / reklam %33) — [AppGoblin](https://appgoblin.info/apps/1541153375), [Games Alchemy](https://gamesalchemy.substack.com/p/17-how-stumble-guys-could-be-set)
- War Robots (Pixonic): oyun ve gelir dengesini koruyan bir ödüllü video örneği — [Unity case](https://unity.com/en/resources/pixonic-war-robots)
- Rush Royale: Google Play'de "reklam içerir" etiketi var, ancak yerleşim ayrıntısı bulunamadı — [Wikipedia](https://www.Wikipedia.org/wiki/Rush_Royale)

### Inferences
- Rekabetçi PvP kart ve strateji oyunlarında (Clash Royale, Brawl Stars) sektör liderleri reklamdan kaçınıyor. Bu, marka ve "pay-to-win algısı" kaygısıyla tutarlı. Futbol menajerliği ve kart oyunlarında (Top Eleven, FC Mobile) ise ödüllü reklam yaygın ve kabul görmüş. Futbol Card Arena bu ikinci gruba daha yakın.
- Supercell'in seçtiği yerleşimler (günlük sandık ekstra ödülü, zamanlayıcı hızlandırma) "en az müdahaleci" set olarak model alınabilir.

### Gaps
- Brawl Stars ve Clash Royale'in 2025-2026'daki güncel reklam durumu birincil kaynakla doğrulanamadı.
- Soccer Stars (Miniclip), Football Manager Mobile, Clash Mini ve Rush Royale için yerleşim ayrıntısı bulunamadı.

## 3. Sıklık sınırları, PvP'de interstitial, ödeme yapanlara reklamsızlık, elde tutmaya etkisi

### Takeaway
Ödüllü reklam elde tutmayı ve IAP'yi genelde bozmuyor. Satıcı verileri reklam izleyenlerin daha çok satın aldığını gösteriyor, ancak bu nedensellik kanıtı değil. Interstitial reklamlar ise belirgin şekilde daha fazla oyuncu kaybettiriyor. Ödeme yapanlardan ödüllü reklamı kaldırmak gerekmiyor; kaldırılması gereken, zorla gösterilen reklamlar. Sayısal günlük limitler için resmi bir standart yok.

### Cited Findings
- Unity/ironSource (Ağustos 2022, 8 büyük uygulama): en az 1 ödüllü reklamla etkileşime giren kullanıcıların IAP yapma olasılığı ortalama 4,5 kat daha yüksek (8 uygulamanın 7'sinde). İlk etkileşimden sonra kullanıcı başı harcama ağırlıklı ortalama %326 arttı. İlk haftada ödüllü reklam izleyenlerin 30 günlük elde tutma oranı en az %50 iken benchmark %13. Günlük oturum sayısı %34 arttı. Örneklem boyutu verilmiyor — [Unity Blog](https://unity.com/en/blog/understanding-the-impact-of-rewarded-ads-on-iap-retention-and-engagement)
- Tapjoy'un benzer bulgusu ilişkisel, nedensel değil — [GamesBeat](https://gamesbeat.com/tapjoy-claims-that-mobile-developers-can-have-rewarded-advertising-without-losing-any-in-app-purchase-revenue/)
- Avid.ly (AdMob vaka çalışması): IAP ağırlıklı oyuna ödüllü video eklenince ARPU %40, IAP geliri %18 arttı, oturumlar %20 uzadı — [AdMob vaka çalışması (arama sonucu özeti)](https://admob.google.co.in/home/resources/monetize-mobile-game-with-ads/)
- Reklam eklenen IAP oyunlarında geliştiricilerin %86'sı IAP'nin sabit kaldığını veya arttığını bildirdi (Facebook Audience Network / Udonis'e atfen; orijinal kaynak doğrulanamadı) — [Playio](https://blog.playio.co/mid-core-games-rewarded-ads-monetization)
- Ödeme yapan kullanıcılarda ödüllü video etkileşimi satın almadan sonra da sabit kalıyor. Oyuncuların para ödeyip kaldırmak istediği reklamlar, oyunun zorla gösterdiği reklamlar — [Business of Apps](https://businessofapps.com/?p=56912) (arama özeti)
- Unity: segmentlere ayırmayı öneriyor (ödeyen/ödemeyen, oturum uzunluğu); uzun oturum yapanlara daha yüksek sınır, abonelere reklamsız ödül. Casual ve midcore'da sınırlar hyper-casual'dan düşük tutulmalı; aşırı birikim IAP'yi gereksiz kılar — [Unity Blog](https://unity.com/blog/the-fundamentals-of-rewarded-video-ad-placements)
- Interstitial ve ödüllü reklamın oyuncu kaybettirmesi (Unity AdQuality, Kasım 2025 verisi, Mart 2026 yazısı): ödüllü videoda D1 kaybı Android'de çoğu ağda %2'nin, iOS'ta %1'in altında. Interstitial'da Android'de %5-10, iOS'ta AppLovin'de %15'in üstünde. Bazı ağlarda ödüllü reklam süresi ortalama 60 saniyeyi geçiyor. Öneri: ağı tamamen kapatmak yerine kötü kreatifleri engellemek, değerli kullanıcıları korumak — [PocketGamer.biz](https://www.pocketgamer.biz/what-our-data-reveals-about-ad-quality-and-player-churn-in-mobile-games/)
- Maç tabanlı bir oyunda interstitial'ı sonuç ekranından önceye almak reklam ARPDAU'yu %23-24 artırdı. Ancak aynı yayıncının daha önce yalnızca interstitial ekleme denemesi elde tutmayı düşürmüştü — [PocketGamer.biz](https://www.pocketgamer.biz/what-five-in-game-ad-experiments-taught-us-about-player-behaviour-and-revenue/)
- Kötü tasarımda IAP gerçekten yenebiliyor. Bir oyunda yeni RV yerleşimi bazı segmentlerde IAP kaybını karşılayamadı — [PocketGamer.biz](https://www.pocketgamer.biz/what-five-in-game-ad-experiments-taught-us-about-player-behaviour-and-revenue/)
- Payers'tan ücretsiz ödülleri kaldırmanın onları daha çok satın almaya iteceği varsayımı "hatalı mantık" olarak eleştiriliyor (sponsorlu yazı) — [Game Developer](https://gamedeveloper.com/business/are-you-punishing-players-who-pay-rethinking-monetization-strategies-)
- Önerilen test yöntemi: oyuncu tabanının %5-10'uyla kohort testi; kullanıcı başına toplam gelir (reklam + IAP) ölçülmeli — [Unity Blog](https://unity.com/en/blog/iap-to-hybrid-monetization), [Adapty](https://adapty.io/apple-ads/glossary/in-app-advertising/)
- King A/B testlerinde optimum sıklık 24 saatte kullanıcı başına 3 ödüllü gösterim (ikincil blog, tarihsiz; dikkatli kullanılmalı) — [AppSamurai](https://appsamurai.com/blog/rewarded-ads-in-mobile-games-strategy-data-and-best-practices/)
- Oturum başına 2-3 isteğe bağlı RV yerleşimi öneriliyor (kaynaksız benchmark) — [Playio](https://blog.playio.co/mid-core-games-rewarded-ads-monetization)
- FC Mobile'da reklam ödülleri için "maksimum reklam" limiti var — [EA Forum](https://forums.ea.com/discussions/fc-mobile-bug-reports-en/rewards-for-adverts-not-working/13005855)

### Inferences
- Futbol Card Arena için öneri: dereceli PvP akışında interstitial ve banner hiç kullanılmamalı; yalnızca ödüllü reklam olmalı. Günlük toplam sınır yaklaşık 6-10, ayrıca yerleşim başına sınır (örneğin x2 maç ödülü günde 3-5, sandık hızlandırma sandık başına 1, mağaza ücretsiz slotu 4-6 saatte 1). Bunlar sektör örneklerinden çıkarılmış başlangıç değerleri; doğrulanmış bir standart değil.
- "Reklamsız" satın almayı ödüllü reklamı kaldırmak olarak değil, Archero 2'deki gibi "reklam izlemeden ödülü al" ya da sezon bileti avantajı olarak tasarlamak daha mantıklı. Böylece ödeyen oyuncu ödülü kaybetmez.

### Gaps
- Bağımsız (satıcı olmayan) bir nedensellik çalışması bulunamadı.
- "Remove ads" satın alımını izole eden yayımlanmış bir test bulunamadı.
- AppLovin, Liftoff veya Tenjin'in 2025-2026 PvP'ye özel rehberi bulunamadı.

## 4. Diğer formatlar: offerwall, playable, in-world (stadyum panoları), banner, rewarded interstitial

### Takeaway
Futbol oyunu için en "oyunun parçası" format, stadyum panolarına yerleştirilen intrinsic (oyun dünyasına gömülü) reklamlar. Anzu bu alanda sporda (UFL, Axis Football, Slappyball) aktif, ancak sonuç rakamları satıcı kaynaklı. Offerwall IAP ağırlıklı oyunlarda IAP'yi yiyebilir. Banner en düşük gelirli ve en rahatsız edici format.

### Cited Findings
- Anzu, Mayıs 2026'da AAA futbol oyunu UFL'e intrinsic reklam getirdi; "oyunu bölmeden stadyum gerçekçiliğini artırma" iddiası var — [Anzu](https://www.anzu.io/news/anzu-brings-intrinsic-in-game-ads-to-aaa-football-hit-ufl), [Game Developer](https://www.gamedeveloper.com/press-release/anzu-brings-intrinsic-in-game-ads-to-aaa-football-hit-ufl)
- Axis Football: stadyum panoları gerçek ürünleri gösteriyor; sezona ve bazen maça göre değişiyor, gerçekçiliği artırıyor — [Anzu blog](https://anzu.io/blog/developer-interviews-axis-games)
- Slappyball (Amelore): stadyum tabanlı oyun; in-game reklamların toplam gelirin %50'si olduğu iddia ediliyor (sayfa metni bozuk, doğrulanmalı) — [Anzu case](https://www.anzu.io/case-studies/amelore-case-study)
- Gameloft (Asphalt 8 vb.): Anzu eklenen oyunlarda ARPDAU %10 arttı. Drift Max Pro'da toplam gelir %15 arttı — [Anzu Gameloft](https://www.anzu.io/case-studies/gameloft-case-study), [Anzu Drift Max Pro](https://www.anzu.io/case-studies/drift-max-pro-case-study)
- Lumen ve Anzu çalışmasına göre in-game reklamların görünürlüğü %98, diğer dijital medyada %78 (satıcı destekli) — [PocketGamer.biz](https://www.pocketgamer.biz/news/81799/anzu-and-lumens-two-year-study-finds-that-in-game-ads-come-out-on-top/)
- Super Soccer Blast (Unfinished Pixel) 2020'de Anzu ile saha içi pano anlaşması yaptı (PC/konsol), performans verisi yok — [European Gaming](https://europeangaming.eu/portal/latest-news/2020/07/28/74873/world-leading-in-game-advertising-platform-anzu-io-and-indie-sports-video-game-developer-unfinished-pixel-seal-new-exclusive-partnership/)
- Offerwall: diğer oyunlarda reklam gelirinin %8,4-36'sını oluşturdu ve elde tutmaya, IAP'ye zarar vermedi. Ancak IAP ağırlıklı bir oyunda test grubunda IAP %1,5 düştü (dönüşüm sabit, ortalama işlem değeri düştü) ve proje durduruldu — [PocketGamer.biz](https://www.pocketgamer.biz/what-five-in-game-ad-experiments-taught-us-about-player-behaviour-and-revenue/)
- Banner: eCPM yaklaşık $0,10-1, ek reklam geliri yaklaşık %10-15. Sensor Tower bannerı "çoğu zaman en rahatsız edici format" olarak tanımlıyor; yanlış tıklama alanı riskine dikkat çekiyor — [Sensor Tower](https://develop.sensortower.com/blog/ad-monetization-without-killing-retention-best-hybrid-monetization-practices), [AppFollow](https://appfollow.io/blog/mobile-game-ads-formats-monetization)
- Rewarded interstitial (Google politikası): "hayır" seçeneği olan, gizlenmemiş bir giriş ekranı zorunlu ve kullanıcıya vazgeçmesi için yeterli süre tanınmalı. Diğer ödüllü reklamlar ancak açık ve kesin onay sonrası gösterilebilir — [Google Ad Manager Policy](https://support.google.com/admanager/answer/7496282)
- Birden çok ödüllü formatı (video + offerwall) birleştirmek eCPM'i artırıyor — [Unity Blog](https://unity.com/en/blog/understanding-the-impact-of-rewarded-ads-on-iap-retention-and-engagement)

### Inferences
- Maç ekranındaki stadyum panoları, kart arka planları veya sponsorlu turnuvalar oyunu bölmeden gelir sağlayabilir. Ancak Anzu ve benzeri SDK'lar genelde Unity/Unreal odaklı. Flutter desteği belirsiz olduğu için entegrasyon riski yüksek.
- Offerwall, Futbol Card Arena'da yalnızca ödeme yapmayan segmente ve gem değil altın ödülüyle denenebilir.

### Gaps
- Anzu ve Admix'in Flutter SDK desteği araştırılamadı.
- Admix için 2024-2026 vaka verisi bulunamadı.
- Mobil spor oyunlarında pano reklamı için bağımsız gelir verisi bulunamadı.
- Playable reklamlar (yayıncı tarafında) için veri bulunamadı.

## 5. Benchmark: reklam ARPDAU'su, etkileşim oranı, DAU başına gösterim, hibrit oyunlarda IAA/IAP payı

### Takeaway
Midcore oyunlarda gelirin yaklaşık %90'ı IAP'den geliyor ve hibrit model midcore oyunların yalnızca yaklaşık %15'inde var. Hibrit midcore için tahmini dağılım %60-80 IAP, %20-40 reklam. ABD Android ödüllü video eCPM'i yaklaşık $30. Midcore reklam ARPDAU'su için güvenilir birincil benchmark yok.

### Cited Findings
- AppsFlyer verisine göre midcore'da gelirin yaklaşık %90'ı IAP'den geliyor ve hibrit model midcore oyunların yaklaşık %15'inde var. Bir rehber hibrit midcore için %60-80 IAP / %20-40 reklam tahmini veriyor — [Game Growth Advisor](https://gamegrowthadvisor.com/blog/2026-06-02-hybrid-monetization-mobile-games-iap-ads-guide-2026/)
- Ödüllü video eCPM'i Android'de ABD için $30,25, Güney Kore için $22,01 (Tenjin/CAS, 2024 Q2) — [Playio](https://blog.playio.co/arpdau-benchmarks-mobile-games)
- Strateji ARPDAU'su (toplam) için $0,10-0,35 aralığı veriliyor (kaynağı belirsiz) — [Juego Studio](https://www.juegostudio.com/blog/arpdau-benchmarks-by-game-genre)
- TopOn (2025 H1, casual): ödüllü video gelirin %39,35'ini ve gösterimlerin %21,25'ini oluşturuyor; interstitial'da bu oranlar %44,25 ve %29,31 — [arama özeti / Moloco-AppSamurai çevresi](https://appsamurai.com/blog/rewarded-ads-in-mobile-games-strategy-data-and-best-practices/)
- Midcore'da IAP dönüşümü kullanıcıların %3-5'i, yani %95-97 hiç ödeme yapmıyor — [Playio](https://blog.playio.co/mid-core-games-rewarded-ads-monetization)
- DAU başına gösterim ve ödüllü reklam etkileşim oranı için tarafsız benchmark yok — [Playio](https://blog.playio.co/mobile-game-ad-revenue-calculator)
- Örnek model: %50 etkileşim, izleyen başına 4 reklam, DAU başına yaklaşık 2 gösterim, $20 eCPM ile reklam ARPDAU'su yaklaşık $0,04 — [PocketGamer.biz](http://www.pocketgamer.biz/supercells-big-squad-busters-mistake-and-how-theyre-missing-out-on-millions/)
- Rewarded video eCPM'leri üst düzey pazarlarda $10-30 — [AppFollow](https://appfollow.io/blog/mobile-game-ads-formats-monetization)
- Rapor eCPM'lerini ($20-40) kendi hedefin olarak alma uyarısı — [Applixir](https://www.applixir.com/?p=4354)

### Inferences
- Futbol Card Arena için kaba başlangıç tahmini: DAU başına 1,5-3 ödüllü gösterim × bölgesel eCPM. Türkiye gibi pazarlarda eCPM ABD'den çok daha düşük olabilir; Türkiye için eCPM verisi bulunamadı. Reklam ARPDAU'su $0,005-0,04 aralığında olabilir. Bu bir çıkarım, doğrulanmış bir veri değil.

### Gaps
- GameAnalytics 2025/2026 PDF'i okunamadı. Midcore ve kart oyunları için segment ARPDAU'su bulunamadı.
- Türkiye ve MENA için ödüllü eCPM verisi bulunamadı.

## 6. UX kuralları: açık onay, ödülü önceden gösterme, zorlamama, yükleme hatası, çocuk kullanıcılar

### Takeaway
Google politikası şunları şart koşuyor: açık onay, ödülün ve gerekli eylemin reklamdan önce net gösterilmesi, reklamı atlayabilme ve atlayınca cezasız kalma, ödülün kesin teslimi. Para veya kripto ödül yasak. Rastgele ödülde olasılık açıklanmalı. Çocuklara yönelik yayında yalnızca Families sertifikalı SDK kullanılabilir ve kişiselleştirilmiş reklam yasak.

### Cited Findings
- Ödüllü reklam yalnızca kullanıcı "açık ve kesin olarak" onay verdikten sonra gösterilebilir. Rewarded interstitial'da "hayır" seçeneği olan bir giriş ekranı zorunlu. Reklam atlanabilmeli ve atlamak normal kullanımı engellememeli. Gerekli eylem ve ödül önceden net ve doğru açıklanmalı; birden çok reklam gerekiyorsa belirtilmeli. Ödül, eylem tamamlanınca mutlaka verilmeli. Nakit, kripto ve hediye kartı ödül olarak yasak; ödül devredilemez olmalı. Rastgele ödülde kazanma olasılığı izlemeden önce açıklanmalı ve sıfırdan büyük olmalı. Metin, "reklam izleyerek bizi destekle" gibi yönlendirmeler içermemeli — [Google Ad Manager Policy](https://support.google.com/admanager/answer/7496282)
- Google Play Families: hedef kitle yalnızca çocuklarsa yalnızca Families self-certified SDK kullanılabilir. Karışık kitlede çocuklara yalnızca sertifikalı SDK'larla reklam gösterilebilir (tarafsız yaş doğrulamasıyla). Çocuklara kişiselleştirilmiş reklam yasak. Ödüllü reklamlar dahil oyunu bölen reklamlar 5 saniye sonra kapatılabilir olmalı. AppLovin programdan ayrıldı — [Google Play Families SDK Policy](https://support.google.com/googleplay/android-developer/answer/12918983), [Families Policy](https://support.google.com/googleplay/android-developer/answer/9893335)
- Kullanıcı deneyimi: ödül butonu tek dokunuşla başlamalı ve ödül net yazmalı — [Unity Blog](https://unity.com/blog/the-fundamentals-of-rewarded-video-ad-placements)
- Reklamın yüklenmemesi gerçek bir sorun: FC Mobile oyuncuları gri kalan "Watch Ad" butonları, izlenen reklamın sayılmaması ve ödül alırken ağ hatası bildiriyor — [EA Forum](https://forums.ea.com/discussions/fc-mobile-bug-reports-en/ads-not-playingrecognised/8023361)
- Kötü kreatifler oyuncu kaybettiriyor; kaçış oranı (ad escape rate) ve otomatik tıklamalar izlenmeli — [PocketGamer.biz](https://www.pocketgamer.biz/what-our-data-reveals-about-ad-quality-and-player-churn-in-mobile-games/)

### Inferences
- Futbol Card Arena'da yapılması gerekenler: buton yalnızca reklam önceden yüklüyse aktif olmalı; yüklü değilse "şu an reklam yok, sonra tekrar dene" mesajı gösterilmeli ve sayaç düşülmemeli. Ödül sunucu tarafında (SSV, server-side verification) doğrulanmalı ve izleme kesintiye uğrarsa ödül kuyrukta saklanmalı. Kalan günlük hak görünür olmalı. 13 yaş altı için yaş kapısı ve kişiselleştirilmemiş reklam kullanılmalı.
- Web sürümü için AdMob mobil SDK'sı geçerli değil. Web'de ayrı bir çözüm (örneğin Google H5/Ad Placement API) gerekir; bu konuda ayrıca araştırma yapılmalı.

### Gaps
- iOS App Store ve ATT kuralları ile ödüllü reklam etkileşimi ayrıca araştırılamadı.
- Flutter `google_mobile_ads` için yükleme hatası ve SSV en iyi uygulamaları belgelerle doğrulanmadı.
- Apple'ın çocuk kategorisi reklam kuralları araştırılmadı.
