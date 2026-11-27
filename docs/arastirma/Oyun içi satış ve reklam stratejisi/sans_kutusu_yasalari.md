# Şans kutuları (loot box / gacha / ücretli rastgele sandık) için yasal ve platform kuralları (2025-2026)

Bağlam: Futbol Card Arena (Flutter; iOS, Android, web). Rastgele futbolcu kartı veren sandıklar/paketler satılıyor. İki para birimi var: altın (oyunda kazanılan) ve elmas (gerçek parayla da alınabilen). Geliştirici Türk ve tek kişi; oyun Türkiye'de ve dünya genelinde çıkacak; dereceli PvP modu var.
Araştırma tarihi: 27.11.2026. "Yürürlükte" ile "taslak/teklif" ayrımı her maddede belirtildi.
Kaynak notu: Arama sonuçlarının bir kısmı hukuk bürosu blogları ve oyun haber siteleri gibi ikincil kaynaklar. Birincil metne (resmi kılavuz veya mevzuat) ulaşılan yerler ayrıca belirtildi.

---

## 1. Platform kuralları: Apple App Store ve Google Play

### Takeaway
İki mağaza da gerçek parayla (veya satın alınan sanal parayla) açılan rastgele ödüllerde, her ödül türünün olasılığının satın almadan ÖNCE gösterilmesini zorunlu tutuyor. Bu, ülkeden bağımsız olarak her yerde geçerli. Çocuk kategorisindeki uygulamalarda ise satın alma ebeveyn kapısının (parental gate) arkasında olmalı.

### Cited Findings
- **Apple 3.1.1 (yürürlükte, güncel metin okundu):** Kılavuzda şöyle yazıyor: "Apps offering 'loot boxes' or other mechanisms that provide randomized virtual items for purchase must disclose the odds of receiving each type of item to customers prior to purchase." — [Apple App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Apple 3.1.1, sanal para:** "Any credits or in-game currencies purchased via in-app purchase may not expire", yani uygulama içi satın almayla alınan krediler ve oyun parası süresi dolarak kaybolamaz. Geri yüklenebilen satın almalar için bir "restore" mekanizması da olmalı. — [Apple Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- **Apple 1.3, Kids kategorisi:** Bu kategorideki uygulamalarda "purchasing opportunities" yalnızca ebeveyn kapısının arkasındaki ayrı bir alanda sunulabilir. — [Apple Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- Apple bu kuralı Aralık 2017'de getirdi. Basın, kuralın Çin'in yasal olasılık açıklama zorunluluğunun ardından geldiğini yazdı. — [Fenwick](https://www.fenwick.com/insights/publications/apple-now-requires-disclosure-of-loot-box-odds), [TouchArcade](https://toucharcade.com/2017/12/21/apple-quietly-updated-the-app-store-review-guidelines-to-require-disclosure-of-loot-box-iap-odds/)
- Bir geliştirici forumunda, kuralın "gerçek parayla alınan oyun parasıyla açılan kutuları" da kapsayıp kapsamadığı soruldu. Apple'dan resmi bir cevap gelmedi. — [Apple Developer Forums](https://developer.apple.com/forums/thread/94213)
- **Google Play (yürürlükte, güncel metin okundu):** Ödemeler politikasında şu ifade var: "Apps and games offering mechanisms to receive randomized virtual items from a purchase must clearly disclose the odds of receiving those items in advance of, and in close and timely proximity to, that purchase." — [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- Google, gerçek parayla kumarı kolaylaştıran içerikte Play faturalandırma sisteminin kullanılmasını yasaklıyor ve ayrıntılar için ayrı bir "Real-Money Gambling, Games, and Contests" politikasına yönlendiriyor. — [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)
- Google bu kuralı Mayıs 2019'da, gençleri korumaya yönelik politika paketiyle birlikte getirdi. — [Engadget](https://www.engadget.com/2019/05/30/google-android-apps-odds-loot-boxes/), [Fenwick](https://fenwick.com/insights/publications/google-play-now-requires-disclosure-of-loot-box-odds)

### Inferences
- Elmasla açılan sandıklarda olasılığı göstermek fiilen zorunlu. Elmas gerçek parayla satıldığı için kural büyük ihtimalle bu durumu da kapsıyor. En güvenli yol, altınla açılan sandıklarda da olasılık göstermek.
- Google metnindeki "close and timely proximity" ifadesine göre olasılık tablosu satın alma düğmesinin yanında veya hemen erişilebilir olmalı. Yalnızca web sitesinde ayrı bir sayfada durması yetmez.
- Web sürümü mağaza kurallarına tabi değil, ancak AB ve Kore gibi ülkelerin yasaları web için de geçerli. Bu yüzden web'de de aynı olasılık ekranını kullanmak mantıklı.
- Elmaslar iOS'ta süresi dolarak kaybolamaz. Sezon sonunda elmas silmek gibi bir tasarım Apple 3.1.1 ile çelişir.

### Gaps
- Google Play Families politikasının bu konudaki güncel metnine ve Apple 5.3 (oyun/kumar) bölümünün tam metnine ulaşılamadı (sayfa kesildi). Apple kılavuzunun son güncelleme tarihi de görülemedi.

---

## 2. Avrupa: AB, Belçika, Hollanda, Birleşik Krallık, Almanya, Avusturya, İspanya

### Takeaway
AB çapında bağlayıcı bir loot box yasası henüz yok. Ancak 2026 Kasım'ında önerilen Digital Fairness Act, ücretli rastgele ödülleri reşit olmayanlara yasaklamayı, olasılık açıklamasını zorunlu kılmayı ve yetişkinlere bu sistemleri kapatma seçeneği verilmesini öneriyor. Bu henüz TASLAK. CPC ağının 2025 ilkeleri ise bağlayıcı olmasa da şimdiden uygulamaya konuyor ve sanal ürünlerin fiyatının gerçek para karşılığıyla gösterilmesini istiyor. Belçika en riskli ülke: ücretli loot box orada kumar sayılıyor.

### Cited Findings
**AB – Digital Fairness Act (DFA) (TASLAK, yürürlükte değil)**
- Komisyon DFA önerisini 11-12 Kasım 2026'da yayımladı (kaynaklar tarih konusunda bir gün farklı). Parlamento ve Konsey'in müzakere edip kabul etmesi gerekiyor. Kabul edilirse yürürlüğe girdikten 12 ay sonra uygulanacak. — [iGaming Business](https://igamingbusiness.com/legal-compliance/eu-digital-fairness-act-tighten-rules-loot-boxes-gambling-influencer-marketing/)
- Taslağın 15. maddesi (gerekçe: Recital 63) ücretli "variable reward systems" kavramını düzenliyor. Bunlar, parayla veya parayla alınan sanal parayla elde edilen rastgele ödüller. Taslağa göre:
  - Ürün reşit olmayanlara yönelikse ya da satıcı reşit olmayanların ürünü kullandığını makul kesinlikle biliyorsa, bu sistemler reşit olmayanlara sunulamaz.
  - Ödül türleri ve olasılıklar satın almadan önce açıkça gösterilmeli.
  - Bu sistemleri kapatma aracı TÜM tüketicilere sunulmalı.
  — [iGaming Business](https://igamingbusiness.com/legal-compliance/eu-digital-fairness-act-tighten-rules-loot-boxes-gambling-influencer-marketing/)
- Diğer haberlere göre taslak ayrıca şunları içeriyor: ücretli sanal paraların reşit olmayanlar için varsayılan olarak kapalı olması, sanal parayla alınan ürünlerde gerçek para karşılığının gösterilmesi, reşit olmayanlarda pay-to-win kısıtlaması ve dünya cirosunun %6'sına kadar ceza. — [Back2Gaming](https://www.back2gaming.com/news/eus-proposed-digital-fairness-act-would-ban-paid-loot-boxes-and-pay-to-win-for-minors/), [This Week in Videogames](https://thisweekinvideogames.com/news/european-commissions-digital-fairness-act-proposal-takes-aim-at-loot-boxes-in-game-currencies-personalised-pricing-and-more/). Not: iGaming Business ceza oranını ve sanal para fiyat kuralını yazmıyor. Kaynaklar yasağın kapsamında da çelişiyor: bazıları "tüm reşit olmayanlar" diyor, bazıları "yöneliklik veya bilgi şartı" diyor.
- Avrupa Parlamentosu'nun ilgili komitesi, DFA ile reşit olmayanlara loot box yasağı getirilmesini istemişti. — [Futura Law](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026), [Promise Legal](https://blog.promise.legal/lootbox-laws-jurisdiction-indie-game-studios/)

**AB – CPC ağı "Key principles on in-game virtual currencies" (bağlayıcı değil, Mart 2025)**
- Bu ilkeler, görevde verilen "Mart 2024" tarihinden farklı olarak 21 Mart 2025'te yayımlandı. Ana ilke: oyun içi dijital içeriğin fiyatı gerçek parayla da gösterilmeli. Ayrıca birden fazla para birimi kullanmak veya zorunlu para dönüşümü gibi maliyeti gizleyen uygulamalardan kaçınılmalı. İlkeler bağlayıcı değil, ancak tüketici otoritelerinin hukuku nasıl yorumlayacağını gösteriyor. Ardından koordineli denetimler başladı. — [Reed Smith](https://www.reedsmith.com/articles/qas-on-the-eu-consumer-protection-authorities-joint-guidance-paper/), [Linklaters](https://techinsights.linklaters.com/post/102k6t4/game-changer-eu-introduces-consumer-protection-guidance-for-in-game-virtual-curr), [İlke metni PDF](https://esportslegal.news/wp-content/uploads/2025/03/Key-principles-on-in-game-virtual-currencies.pdf)
- CPC ağı bu ilkelere dayanarak King, Supercell, Mojang ve başka şirketler hakkında işlem başlattı. — [PocketGamer.biz](https://pocketgamer.biz/europes-cpc-targets-king-supercell-mojang-and-others-over-virtual-currencies)
- Süreci tetikleyen olay muhtemelen BEUC'un Eylül 2024 şikâyeti. — [Bird & Bird](https://www.twobirds.com/en/insights/2025/european-move-towards-protecting-users-from-harmful-practices-in-video-games-eu-consumer-protection)

**Belçika (yürürlükte, yorum yoluyla)**
- Belçika Oyun Komisyonu 2018'de ücretli loot box'ları "şans oyunu" saydı. Bu sistemlerin kaldırılmasını veya değiştirilmesini istedi ve uymayanlara cezai yaptırım uyarısı yaptı. — [European Gaming](https://europeangaming.eu/portal/compliance-updates/2018/04/26/19201/belgiums-gambling-commission-rules-against-loot-boxes/), [GamesRadar](https://gamesradar.com/belgium-deems-loot-boxes-dangerous-to-children-and-society-threatens-publishers-with-prison-and-fines)
- Antwerp Ticaret Mahkemesi 16 Ocak 2025'te LS v Apple davasında önemli bir karar verdi ve davayı AB Adalet Divanı'na gönderdi (C-47/25). Mahkemeye göre Apple, Belçika'da ücretli loot box'ların muhtemelen hukuka aykırı sayıldığını görmezden gelemezdi. — [Taylor Wessing](https://www.taylorwessing.com/en/insights-and-events/insights/2025/03/an-iphone-a-gambling-problem-and-the-loot-box-debate)
- Denetim zayıf. Xiao'ya göre Belçika'da en çok kazanan iPhone oyunlarının büyük kısmı hâlâ ücretli loot box sunuyor (bir ikincil kaynak %82 diyor). — [Leon Xiao – Belgium](https://sites.google.com/view/leon-xiao/policy/belgium), [Promise Legal](https://blog.promise.legal/loot-box-laws-game-developers/)
- Belçika regülatörünün başkanı 2025 sonunda ücretli rastgele ürünleri yılın en önemli konularından biri olarak andı. — [Focus Gaming News](https://focusgn.com/magali-clavie-belgium-wants-a-more-coordinated-and-effective-european-framework-against-illegal-gambling)

**Hollanda**
- Kansspelautoriteit (Ksa), FIFA paketleri nedeniyle EA'ya ceza vermişti. Danıştay (Raad van State, en yüksek idari yargı yeri) Mart 2022'de bu cezayı bozdu. Bugünkü yorum, kutu içeriğinin oyun dışında satılıp satılamadığı (ikincil piyasa) üzerinde yoğunlaşıyor. — [Promise Legal](https://blog.promise.legal/loot-box-laws-by-jurisdiction-indie-game-studios/)
- Temmuz 2025 tarihli bir Hollanda haberi, konunun "gri alan" olduğunu ve kuralların görmezden gelindiğini yazıyor. — [Esports Insider NL](https://esportsinsider.com/nl/2025/07/16/gamen-of-gokken-regels-rond-loot-boxes-worden-genegeerd-in-nederland)

**Birleşik Krallık (yasa değil, sektörün öz düzenlemesi)**
- Ukie, DCMS'in kurduğu çalışma grubuyla 11 ilke belirledi ve bunları 18 Temmuz 2023'te yayımladı. Uyum gönüllü. Hükümet, sektör harekete geçmezse ilkeleri zorunlu hale getirebileceğini söyledi. — [CMS](https://cms.law/en/gbr/legal-updates/loot-boxes-11-new-principles-for-an-industry-led-approach), [GOV.UK](https://www.gov.uk/guidance/loot-boxes-in-video-games-update-on-improvements-to-industry-led-protections)
- Royal Society'de 2025'te yayımlanan bir çalışma, App Store'da bu ilkelere "yaygın" biçimde uyulmadığını ve denetimin "yok denecek kadar az" olduğunu buldu. — [Royal Society blog](https://royalsociety.org/blog/2025/06/video-game-industry-loot-boxes/), [5Rights](https://5rightsfoundation.com/research-reveals-non-existent-enforcement-of-industry-led-standards-on-loot-boxes/)
- DCMS 2022'de yasayı değiştirmedi ve sektörden öz düzenleme istedi. — [PC Gamer](https://pcgamer.com/uk-governments-loot-box-inquiry-says-no-changes-to-law-asks-industry-to-self-regulate)

**Almanya**
- 2021 Gençliği Koruma Yasası (JuSchG) reformundan sonra loot box'lar yaş derecelendirmesinde bir risk unsuru oldu. USK 2023'ten beri bunu uyguluyor. Bir ikincil kaynağa göre loot box içeren oyunlar en az USK 12 alıyor. 2025 sonunda Bundesrat, loot box'ların kumar sayılmasını ve 18+ derece verilmesini değerlendirmesi için hükümete bağlayıcı olmayan bir çağrıda bulundu. — [Promise Legal](https://blog.promise.legal/lootbox-laws-jurisdiction-indie-game-studios/), [Futura Law](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026)

**Avusturya**
- Bildirilene göre Yüksek Mahkeme (OGH) Aralık 2025'te 6 Ob 228/24h sayılı kararında FIFA Ultimate Team paketlerinin kumar olmadığına hükmetti ve alt mahkeme kararlarını bozdu. Karar metni doğrulanmadı, yalnızca ikincil kaynakta geçiyor. — [Futura Law](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026)

**İspanya (TASLAK)**
- Tüketim Bakanlığı Temmuz 2022'de bir ön tasarı yayımladı. Tasarı, ödülü paraya çevrilebilen loot box'ları reşit olmayanlara yasaklamayı öngörüyordu. Kesinleşmiş bir yasa bulunamadı ve kaynaklar bu konuda çelişiyor. — [Promise Legal](https://blog.promise.legal/loot-box-laws-game-developers/), [Siege.gg](https://siege.gg/news/several-eu-countries-have-introduced-stricter-regulations-on-loot-boxes-in-games-in-2025)

### Inferences
- **Belçika:** Bu ülkede ücretli (elmasla açılan) sandık satmak en yüksek risk. Pratik çözüm, Belçika'da elmasla sandık açmayı coğrafi olarak kapatmak (store ülkesi veya IP'ye göre) ya da Belçika'da yalnızca içeriği önceden görülen ürünler satmak.
- **CPC ilkeleri:** Tasarımdaki çift para birimi (altın ve elmas) ve sandığın elmas fiyatı, CPC'nin "maliyeti gizleme" endişesine tam olarak uyuyor. AB kullanıcılarına sandık fiyatının yanında yaklaşık gerçek para karşılığını (örneğin "≈ €1,99") göstermek, şimdiden önerilen bir uyum adımı.
- **DFA:** Kabul edilirse en erken 2027-2028'de uygulanır. Yine de AB'de 18 yaş altına ücretli sandığı kapatmak, yaş beyanı/doğrulaması eklemek ve "ücretli sandıkları kapat" ayarı koymak şimdiden tasarıma eklenirse sonradan büyük değişiklik gerekmez.
- **Hollanda ve Avusturya:** Kartlar oyun dışında satılamıyor veya takas edilemiyorsa kumar riski düşük. Oyuncular arası pazar veya kart ticareti eklenmemeli. Böyle bir özellik eklenirse kartlar "piyasa değeri olan ödül" haline gelir ve kumar sınıflandırma riski ciddi biçimde artar.

### Gaps
- PEGI'nin "In-game purchases (includes random items)" etiketine dair resmi kaynağa bu araştırmada ulaşılamadı. Etiketin 2020'den beri kullanıldığı genel olarak biliniyor, ancak bunu doğrulayan bir kaynak bulunamadı.
- Ksa'nın 2025-2026'ya ait resmi bir loot box açıklaması bulunamadı.
- Hollanda Danıştay kararının tam tarihi ve metni birincil kaynaktan doğrulanmadı.
- AB Adalet Divanı'nın C-47/25 davasının sonucu bilinmiyor.
- DFA'nın resmi metni (COM numarası) doğrudan okunamadı.

---

## 3. Asya-Pasifik ve Amerika: Çin, Güney Kore, Japonya, Avustralya, Brezilya, ABD

### Takeaway
Güney Kore'de olasılık açıklaması yasal zorunluluk ve aktif olarak denetleniyor (Mart 2024'ten beri). Brezilya'da 17 Mart 2026'dan beri reşit olmayanlara yönelik veya onların erişebileceği oyunlarda loot box yasak. Avustralya'da ücretli şans içeren satın almaları olan oyunlar en az M derecesi alıyor. ABD'de FTC'nin Genshin uzlaşması fiili standardı belirliyor: 16 yaş altına ebeveyn onayı, olasılık ve kur açıklaması. Japonya'da "kompu gacha" 2012'den beri yasak.

### Cited Findings
**Güney Kore (yürürlükte)**
- Oyun Endüstrisini Teşvik Yasası Mart 2024'ten beri olasılık açıklamasını zorunlu tutuyor. Denetimi GRAC yapıyor. Bir 2025 çalışmasına göre en çok kazanan 100 iPhone oyunundan ücretli loot box içeren 90 tanesinin %84,4'ü olasılık açıklıyor. Bu oran, öz düzenlemeye dayanan ülkelerden daha iyi. — [PubMed – Acta Psychologica 2025](https://pubmed.ncbi.nlm.nih.gov/40945152/)
- Yanlış veya yanıltıcı olasılık yayımlayan şirketler ceza aldı. Kore Rekabet Kurumu (KFTC) bir etkinlikte olasılığı yanlış gösteren bir şirkete ceza verdi. Bildirilene göre Webzen'e Kasım 2025'te gizli %0 olasılık yapısı nedeniyle yaklaşık 110-120 bin dolar ceza kesildi. — [Shin & Kim](https://www.shinkim.com/eng/media/newsletter/3206), [Korea Game Desk](https://koreagamedesk.com/publishers-in-a-limbo-as-korea-weaponizes-instant-700k-penalties/)
- Satışların %3'üne kadar (üst sınır 1 milyar won) ceza öngören bir teklif ve Aralık 2025'te cezaları anında uygulanır hale getiren bir değişiklik haberi var. Bunların yasalaşıp yasalaşmadığı DOĞRULANAMADI. — [Respawn/Outlook](https://respawn.outlookindia.com/gaming/gaming-news/south-korea-proposes-revenue-based-fines-for-loot-box-violations), [Korea Game Desk](https://koreagamedesk.com/publishers-in-a-limbo-as-korea-weaponizes-instant-700k-penalties/)
- Bir kaynak Kore'de "3 kat tazminat" kuralından söz ediyor. Doğrulanmadı. — [Shattered.io](https://shattered.io/loot-box-odds-disclosure-laws-2026/)
- GRAC'ın Temmuz 2026 brifinginde 81 yayıncılık bir uyum listesi yayımlandı. Oyunların %40'ında kısmi, %14'ünde tam olasılık açıklamama tespit edildi. — [Tech Times](https://www.techtimes.com/articles/321760/20260728/south-korea-publishes-first-game-compliance-roster-81-publishers-one-faces-penalty.htm)

**Çin (yürürlükte: açıklama zorunlu; 2023 harcama taslağı geri çekildi)**
- Çin 2017'den beri olasılık açıklamasını yasal olarak zorunlu tutuyor. Bir 2024 çalışmasına göre olasılığı satın alma sayfasında otomatik gösteren oyunların oranı yalnızca %5,5. — [Leon Xiao, Durham repository](https://durham-repository.worktribe.com/output/1238986/gaming-the-system-suboptimal-compliance-with-loot-box-probability-disclosure-regulations-in-china)
- NPPA'nın Aralık 2023 taslağı harcama limitleri getirmeyi, giriş ödüllerini yasaklamayı ve reşit olmayanlara şans çekilişlerini yasaklamayı öngörüyordu. Taslak sonradan siteden kaldırıldı ve geri adım atıldı. — [The Star](https://www.thestar.com.my/tech/tech-news/2023/12/22/china-issues-draft-rules-for-online-game-management), [GamesRadar](https://gamesradar.com/china-seemingly-drops-proposed-gaming-restrictions-that-could-have-had-worldwide-implications-for-loot-boxes-microtransactions-and-daily-log-in-bonuses)
- Not: Çin'de yayın için ISBN lisansı gerekiyor. Bu oyun için Çin pazarı pratikte gündemde değil.

**Japonya (yürürlükte)**
- Tüketici İşleri Ajansı Mayıs 2012'de "kompu gacha"yı yasa dışı ilan etti. Kompu gacha, belirli bir kart setini tamamlayınca nadir bir ödül verme mekaniği. Yasak, haksız ikramiyeler yasasındaki "kart kombinasyonu" hükmüne dayanıyor ve 1 Temmuz 2012'de yürürlüğe girdi. — [Siliconera](https://www.siliconera.com/social-games-compu-gacha-model-officially-declared-illegal/), [Game Developer](https://gamedeveloper.com/business/why-quot-kompu-gacha-quot-was-banned)

**Avustralya (yürürlükte, 22 Eylül 2024)**
- Şansa bağlı oyun içi satın almaları (loot box) olan oyunlar en az M (15 yaş altına önerilmez) derecesi alıyor. Bu derece tavsiye niteliğinde, satış kısıtı getirmiyor. Simüle kumar (örneğin sosyal casino) içeren oyunlar ise en az R18+ alıyor ve bu yasal bir kısıtlama. 22.09.2024 öncesi derecelendirilen oyunlar yeniden derecelendirilmiyor. Ancak G veya PG dereceli bir oyuna sonradan şans içeren satın alma eklenirse yeniden derecelendirme gerekebilir. — [Classification.gov.au](https://www.classification.gov.au/about-us/media-and-news/news/new-classifications-for-gambling-content-video-games), [Fact sheet PDF](https://classification.gov.au/sites/default/files/documents/factsheet-new-mandatory-classifications-for-gambling-like-content-in-video-games.pdf)

**Brezilya (yürürlükte, 17 Mart 2026)**
- 15.211/2025 sayılı Kanun ("ECA Digital") 17 Eylül 2025'te imzalandı ve 17 Mart 2026'da yürürlüğe girdi. 20. madde, çocuk ve ergenlere yönelik veya yaş sınıflandırmasına göre onların erişebileceği oyunlarda loot box'ı yasaklıyor. Kaynaklarda ayrıca şunlar geçiyor: boş kutu yasak, her kutu en az bir ürün vermeli ve olasılıklar satın almadan önce gösterilmeli. — [PC Gamer](https://www.pcgamer.com/gaming-industry/brazils-president-has-signed-a-ban-on-selling-loot-boxes-to-minors-as-part-of-a-larger-online-child-safety-law), [Baker McKenzie](https://www.bakermckenzie.com/en/insight/publications/alerts/2025/09/brazil-digital-eca-sets-new-protections), [PocketGamer.biz](https://www.pocketgamer.biz/brazil-bans-loot-boxes-for-under-18s-in-online-child-safety-measure)
- Adalet Bakanlığı, yaş doğrulaması yapmadan loot box sunan oyunların izlenmesi için veri koruma otoritesi ANPD'ye başvurdu. — [gov.br teknik not](https://www.gov.br/mj/pt-br/assuntos/noticias-1/mjsp-pede-a-anpd-que-monitore-jogos-eletronicos-com-caixas-de-recompensa-que-nao-implementaram-verificacao-de-idade/NotaTcnican55.pdf)

**ABD (federal yasa yok; FTC uygulaması)**
- FTC ile Genshin Impact'in yayıncısı Cognosphere/HoYoverse Ocak 2025'te uzlaştı. Uzlaşmaya göre şirket 20 milyon dolar ceza ödüyor. 16 yaş altı kullanıcılar ebeveynin açık onayı olmadan loot box alamıyor. Şirket loot box olasılıklarını ve sanal para kurlarını açıklamak ve loot box'ı doğrudan gerçek parayla satın alma seçeneği sunmak zorunda. FTC, olasılıklar ve gerçek maliyet konusunda yanıltma olduğunu ve COPPA'nın (13 yaş altı) ihlal edildiğini iddia etti. Uzlaşma mahkeme onayına bağlıydı. — [FTC iş rehberi blogu](https://ftc.gov/business-guidance/blog/2025/01/level-tips-businesses-ftcs-settlement-genshin-impact-developer-hoyoverse), [PC Gamer](https://www.pcgamer.com/games/rpg/ftc-says-genshin-impact-deceived-children-and-orders-its-publisher-to-pay-a-usd20-million-fine-and-stop-selling-loot-boxes-to-kids), [Ferguson görüşü](https://www.ftc.gov/system/files/ftc_gov/pdf/ferguson-cognosphere-concurrence.pdf)

### Inferences
- **Kore:** Kore'de yayın yapılacaksa olasılık tablosu doğru, eksiksiz ve güncel olmalı. Sunucudaki gerçek olasılık ile gösterilen olasılık aynı kaynaktan (tek bir config) beslenmeli. Gizli %0 olasılık veya etkinlik sırasında gizli değişiklik ceza sebebi.
- **Brezilya:** Bir futbol kartı oyunu büyük ihtimalle "reşit olmayanların erişebileceği" bir oyun sayılır. Bu yüzden Brezilya'da ya yaş doğrulaması yapılıp 18 yaş altına ücretli sandık kapatılmalı ya da Brezilya'da ücretli sandık hiç sunulmamalı (bölgesel kapatma).
- **Japonya:** "11 kartı topla → efsane kart kazan" gibi bir set tamamlama ödülü, yalnızca rastgele ücretli çekilişlerle tamamlanabiliyorsa kompu gacha'ya benzer. Setler doğrudan satın alınabilen, takasla veya maçla kazanılan kartlarla da tamamlanabilmeli.
- **ABD:** FTC kararı ABD'de fiili standardı belirliyor. Bu standarda göre yapılması gerekenler:
  - 16 yaş altına ebeveyn onayı istemek
  - olasılık ve elmas/TL kurunu açıkça göstermek
  - sandığı doğrudan parayla alma seçeneği sunmak
  - 13 yaş altından veri toplamamak (COPPA)
- **Avustralya:** Mağaza derecesinde M veya 15+ beklenmeli.

### Gaps
- Kore'deki ceza artırımı teklifinin yasalaşma durumu belirsiz.
- Genshin uzlaşmasının mahkemece kesinleştiği birincil kaynaktan doğrulanmadı.
- Brezilya kanununun resmi Portekizce metni okunmadı.

---

## 4. Türkiye

### Takeaway
Türkiye'de loot box'a özgü yürürlükte bir yasa YOK. Buna rağmen oyun içi satışlar şu düzenlemelere tabi:
- 6502 sayılı Tüketicinin Korunması Hakkında Kanun (haksız ticari uygulama, ön bilgilendirme)
- Mesafeli Sözleşmeler Yönetmeliği (cayma hakkı istisnası için açık onay)
- Ticari Reklam ve Haksız Ticari Uygulamalar Yönetmeliği. Reklam Kurulu 2025'te fiziksel "gizemli kutu" satışlarını bu kapsamda cezalandırdı.
- TMK (7-17 yaş sınırlı ehliyet)
- KVKK
Loot box'ın 7258 sayılı Kanun ve TCK 228 kapsamında kumar sayılıp sayılmayacağı tartışmalı. TBMM'ye loot box yasağı içeren en az bir kanun teklifi sunulmuş, ancak bunlar TEKLİF aşamasında ve kabul edildiklerine dair bir bilgi yok.

### Cited Findings
- **6502 sayılı Kanun:** Oyun içi satın alma bir tüketici işlemi (m.3/1-l). Sanal ürünler "gayri maddi mal" tanımına girebilir (m.3/1-h). Yanıltıcı drop oranları ve pay-to-win, haksız ticari uygulamalar (m.62) açısından değerlendirilebilir. Tüketici, EULA'da yabancı mahkeme şartı olsa bile kendi yerleşim yerinde dava açabilir (m.73/5). — [Işıkoğlu Partners](https://www.isikoglupartners.com/makaleler/oyun-ici-satin-alma-yasal-cerceve/) (Not: makalede tarih tutarsızlığı var: 2026-03-09 / 2026-11-15. Ayrıca bir yerde madde numarası tutarsız, mevzuat.gov.tr'den doğrulanmalı.)
- **Mesafeli Sözleşmeler Yönetmeliği:** Oyun içi satın alma mesafeli sözleşmedir (TKHK m.48). Anında teslim edilen gayri maddi mallarda cayma hakkı istisnası (Yönetmelik m.15/1-ğ) ancak tüketici önceden bilgilendirilir, açık onayı alınır ve onay teyit edilirse geçerli olur. Ön bilgilendirme Yönetmeliğin 5. maddesinde düzenleniyor. — [Işıkoğlu Partners](https://www.isikoglupartners.com/makaleler/oyun-ici-satin-alma-yasal-cerceve/)
- **Kumar (7258 / TCK 228):** Kumar için şans, bedel ve kazanç unsurları gerekir. Belirleyici olan, kazanılan ürünün gerçek ekonomik değeri olup olmadığı. Bu konuda kesin bir içtihat yok. — [Işıkoğlu Partners](https://www.isikoglupartners.com/makaleler/oyun-ici-satin-alma-yasal-cerceve/), [Norton Rose Fulbright – Türkiye loot box (2022)](https://www.nortonrosefulbright.com/en/inside-turkiye/blog/2022/10/the-turkish-technology-ecosystem-loot-box-mechanics)
- **Reklam Kurulu 2025/2674 sayılı karar:** Kurul, Instagram ve bağlantılı sitelerde içeriği belirsiz "gizemli kutu" satışını iki yönden haksız ticari uygulama saydı: kutunun içeriği açıklanmıyordu ve sahte geri sayım sayacı ile aciliyet yaratılıyordu. Satış sitelerine erişim engellendi ve dosyaların yargıya iletilebileceği belirtildi. Hukuk bürosuna göre aynı mantık oyun içi loot box'lara da uygulanabilir: olasılık şeffaflığı olmaması ve geri sayım/kıtlık baskısı "dark pattern" sayılabilir. — [Özdağıstanlı Ekici (IP Tech Legal), 13.10.2025](https://www.ozdagistanliekici.com/reklam-kurulu-gizemli-kutu-satislarini-hedef-aldi-sanal-ganimet-kutulari-lootbox-icin-ne-anlama-geliyor/)
- **Çocuklar (TMK):**
  - 0-6 yaş tam ehliyetsizdir (m.15).
  - 7-17 yaş sınırlı ehliyetsizdir (m.16). Bu yaştaki çocuğun işlemi veli iznine veya sonradan onayına bağlıdır, onay gelene kadar askıdadır. Veli onaylamazsa ödenen bedelin iadesi istenebilir.
  - Ask to Buy ve Family Link gibi araçların TMK'daki izin yerine geçip geçmediği tartışmalı.
  — [Işıkoğlu Partners](https://www.isikoglupartners.com/makaleler/oyun-ici-satin-alma-yasal-cerceve/)
- **KVKK:** Çocuk verileri için ek koruma gerekiyor. Makalede ebeveyn onayı, yaşa uygun sınıflandırma ve harcama limiti öneriliyor (madde numarası verilmemiş). — [Işıkoğlu Partners](https://www.isikoglupartners.com/makaleler/oyun-ici-satin-alma-yasal-cerceve/)
- **TBMM teklifi (TEKLİF, kabul edilmedi):** "Dijital Ortamda Çocuk ve Gençlerin Korunmasına Dair Kanun Teklifi" (haber tarihi 9 Ocak 2026). Haberdeki içerik:
  - Çocukları kumara özendiren loot box benzeri şansa dayalı ödül mekanizmaları ve zorunlu mikro ödemeler yasak.
  - 16 yaş altına çevrim içi oyunda günde en fazla 55 dakika süre ve 22.30-09.30 arası erişim yasağı.
  - Platformlar velilere haftalık kullanım raporu sunacak.
  Teklif sahibi, esas numarası ve komisyon durumu kaynakta yok. — [Türk Siber Birliği](https://turksiberbirligi.com/tbmm-dijital-ortamda-cocuk-ve-genclerin-korunmasina-dair-kanun-teklifi/)
- **İkinci teklif haberi (TEKLİF):** Technopat'ta yaklaşık Ekim 2026'da yayımlanan bir habere göre oyunlardaki loot box ve şansa dayalı ödül mekanizmalarının tamamen yasaklanmasını, 18 yaş altı için yaş doğrulamasını ve velilere haftalık rapor sunulmasını öngören bir teklif TBMM'ye sunuldu. Sayfa açılamadı (HTTP 403), bilgi arama özetinden alındı. Yukarıdaki teklifle aynı olup olmadığı belirsiz. — [Technopat](https://www.technopat.net/sosyal/konu/oyun-yasaklari-ile-ilgili-yeni-kanun-teklifi-tbmmye-sunuldu.4186660/)
- **Derecelendirme:** Türkiye'de ESRB veya PEGI benzeri yerli bir oyun derecelendirme kurulu yok. Yeşilay, böyle bir kurulun oluşturulmasını öneren bir politika notu yayımladı. — [Yeşilay politika notu](https://www.yesilay.org.tr/media/eezdnwdt/turkiye-oyun-derecelendirme-kurulu-olusturulmasina-iliskin-politika-notu.pdf)
- Gamfed'in (tarihi belirsiz) bir yazısına göre, yazının yazıldığı tarihte TBMM'de loot box'a özel bir teklif yoktu. Bu yazı yukarıdaki tekliflerden önce yazılmış olabilir. — [Oyunlaştırma.co / Gamfed](https://oyunlastirma.co/makale/gamfed-turkiye-dijital-oyun-tasarimi-dot-ekibi-kaptanlari-arda-celik-ve-kevser-bilgic-sunar-lootbox-hukuku-ve-duzenlemeleri-oyun-2-makale/)

### Inferences
- Türkiye'de bugün en somut risk tüketici ve reklam hukuku, kumar hukuku değil. Yapılması gerekenler:
  - olasılık tablosu göstermek
  - sahte geri sayım ve "son 3 paket!" gibi yapay kıtlık kullanmamak
  - satın alma ekranında TL fiyatı ve "anında teslim, cayma hakkı yoktur" onayını göstermek
- Kartlar paraya çevrilemiyor ve takas edilemiyorsa 7258 ve TCK 228 kapsamında kumar riski düşük kalır. Bu durum korunmalı: kart satışı veya oyuncular arası pazar eklenmemeli.
- TBMM teklifleri yasalaşırsa en sert senaryoda Türkiye'de 18 yaş altına (hatta herkese) ücretli şanslı sandık yasaklanabilir. Bu yüzden sandık sistemi ülke ve yaş bazında açılıp kapatılabilen bir sunucu anahtarı (feature flag) ile tasarlanmalı. Projenin mevcut "kapalı anahtar" yaklaşımıyla uyumlu bu.
- Mağaza ödemeleri Apple ve Google üzerinden yapıldığı için iade süreçleri büyük ölçüde mağazada. Yine de TMK kapsamında veli itirazına karşı bir destek ve iade akışı tanımlanmalı.

### Gaps
- TBMM tekliflerinin resmi esas numarası, teklif sahipleri ve komisyon durumu tbmm.gov.tr'den doğrulanamadı.
- Ticari Reklam ve Haksız Ticari Uygulamalar Yönetmeliği'nin ilgili madde numaraları birincil kaynaktan okunmadı.
- BTK'nın veya Ticaret Bakanlığı'nın oyun içi loot box'a özel bir kararı bulunamadı.

---

## 5. Ülke ve platform matrisi ile önerilen uyum adımları

### Takeaway
Küresel olarak en düşük ortak payda şu: olasılık açıklaması, gerçek para fiyatının şeffaf gösterilmesi, reşit olmayanlarda ebeveyn onayı veya ücretli sandığı kapatma ve sandığın oynayarak da kazanılabilmesi. Belçika ve Brezilya'da (reşit olmayanlar için) ücretli sandığı bölgesel olarak kapatmak en güvenli yol.

### Cited Findings (matris; her satırın kaynağı yukarıdaki bölümlerde)

| Ülke / Platform | Durum | Zorunlu / Yasak / Riskli | Kaynak |
|---|---|---|---|
| Apple App Store | Yürürlükte | Olasılıklar satın almadan önce gösterilmeli; satın alınan sanal para süresi dolarak kaybolamaz; Kids kategorisinde ebeveyn kapısı | [Apple](https://developer.apple.com/app-store/review/guidelines/) |
| Google Play | Yürürlükte | Olasılıklar satın almadan önce ve satın almaya yakın yerde gösterilmeli | [Google](https://support.google.com/googleplay/android-developer/answer/9858738) |
| AB (DFA) | TASLAK (Kas 2026) | Önerilenler: reşit olmayanlara ücretli rastgele ödül yasağı, olasılık zorunluluğu, herkese kapatma seçeneği | [iGB](https://igamingbusiness.com/legal-compliance/eu-digital-fairness-act-tighten-rules-loot-boxes-gambling-influencer-marketing/) |
| AB (CPC ilkeleri) | Bağlayıcı değil ama denetim var (Mar 2025) | Fiyatın gerçek parayla da gösterilmesi, çoklu para birimiyle maliyeti gizlememek | [Reed Smith](https://www.reedsmith.com/articles/qas-on-the-eu-consumer-protection-authorities-joint-guidance-paper/) |
| Belçika | Yürürlükte (kumar yorumu) | Ücretli loot box = yasa dışı kumar; yüksek risk | [European Gaming](https://europeangaming.eu/portal/compliance-updates/2018/04/26/19201/belgiums-gambling-commission-rules-against-loot-boxes/) |
| Hollanda | Danıştay 2022 kararıyla gevşedi | İkincil piyasada satılabiliyorsa risk var | [Promise Legal](https://blog.promise.legal/loot-box-laws-by-jurisdiction-indie-game-studios/) |
| Birleşik Krallık | Öz düzenleme (Ukie 2023) | Yasa yok; 11 gönüllü ilke | [CMS](https://cms.law/en/gbr/legal-updates/loot-boxes-11-new-principles-for-an-industry-led-approach) |
| Almanya | Yaş derecelendirmesi | Loot box yaş derecesini yükseltir (bildirilen: en az USK 12) | [Promise Legal](https://blog.promise.legal/lootbox-laws-jurisdiction-indie-game-studios/) |
| Avusturya | OGH Ara 2025 (bildirilen) | FUT paketleri kumar değil | [Futura Law](https://www.futura.law/media-center/articles/loot-boxes-regulation-2026) |
| İspanya | TASLAK (2022) | Kesinleşmiş yasa yok | [Promise Legal](https://blog.promise.legal/loot-box-laws-game-developers/) |
| Güney Kore | Yürürlükte (Mar 2024), aktif denetim | Olasılık açıklaması zorunlu; yanlış olasılığa ceza | [PubMed](https://pubmed.ncbi.nlm.nih.gov/40945152/) |
| Çin | Yürürlükte (2017) | Olasılık açıklaması zorunlu; 2023 harcama taslağı geri çekildi | [Xiao](https://durham-repository.worktribe.com/output/1238986/gaming-the-system-suboptimal-compliance-with-loot-box-probability-disclosure-regulations-in-china) |
| Japonya | Yürürlükte (2012) | Kompu gacha yasak | [Siliconera](https://www.siliconera.com/social-games-compu-gacha-model-officially-declared-illegal/) |
| Avustralya | Yürürlükte (22.09.2024) | Loot box varsa en az M; simüle kumar varsa R18+ | [Classification.gov.au](https://www.classification.gov.au/about-us/media-and-news/news/new-classifications-for-gambling-content-video-games) |
| Brezilya | Yürürlükte (17.03.2026) | Reşit olmayanlara yönelik veya onların erişebileceği oyunlarda loot box yasak; olasılık zorunlu; boş kutu yasak | [Baker McKenzie](https://www.bakermckenzie.com/en/insight/publications/alerts/2025/09/brazil-digital-eca-sets-new-protections) |
| ABD | FTC uzlaşması (Oca 2025) | 16 yaş altına ebeveyn onayı; olasılık ve kur açıklaması; doğrudan parayla alma seçeneği; COPPA | [FTC](https://ftc.gov/business-guidance/blog/2025/01/level-tips-businesses-ftcs-settlement-genshin-impact-developer-hoyoverse) |
| Türkiye | Özel yasa yok; TBMM'de TEKLİF var | 6502 ve Reklam Kurulu: olasılık şeffaflığı ve sahte aciliyet yasağı; cayma hakkı istisnası için açık onay; 7-17 yaş için veli izni | [Işıkoğlu](https://www.isikoglupartners.com/makaleler/oyun-ici-satin-alma-yasal-cerceve/), [IP Tech Legal](https://www.ozdagistanliekici.com/reklam-kurulu-gizemli-kutu-satislarini-hedef-aldi-sanal-ganimet-kutulari-lootbox-icin-ne-anlama-geliyor/) |

Kaynaklarda geçen iyi uygulamalar:
- **Olasılık ekranı:** Olasılıklar satın alma sayfasında otomatik ve belirgin biçimde gösterilmeli. Çin'de bunu yapan oyunlar yalnızca %5,5; araştırmacı Xiao en belirgin biçimi öneriyor. — [Xiao](https://durham-repository.worktribe.com/output/1238986/gaming-the-system-suboptimal-compliance-with-loot-box-probability-disclosure-regulations-in-china)
- **Gerçek para karşılığı ve doğrudan satın alma:** Sanal ürünün fiyatı gerçek parayla gösterilmeli ve doğrudan parayla satın alma seçeneği olmalı. — [CPC ilkeleri](https://esportslegal.news/wp-content/uploads/2025/03/Key-principles-on-in-game-virtual-currencies.pdf), [FTC](https://ftc.gov/business-guidance/blog/2025/01/level-tips-businesses-ftcs-settlement-genshin-impact-developer-hoyoverse)
- **Boş kutu olmamalı:** Her kutu en az bir ürün vermeli. — [PocketGamer.biz – Brezilya](https://www.pocketgamer.biz/brazil-bans-loot-boxes-for-under-18s-in-online-child-safety-measure)
- **Kapatma seçeneği:** Ücretli rastgele sistemler kullanıcı tarafından kapatılabilmeli (DFA taslağı). — [iGB](https://igamingbusiness.com/legal-compliance/eu-digital-fairness-act-tighten-rules-loot-boxes-gambling-influencer-marketing/)
- **Baskı unsurları:** Sahte geri sayım, kıtlık vurgusu ve baskı dili kullanılmamalı. — [IP Tech Legal](https://www.ozdagistanliekici.com/reklam-kurulu-gizemli-kutu-satislarini-hedef-aldi-sanal-ganimet-kutulari-lootbox-icin-ne-anlama-geliyor/)
- **Çocuklar:** Harcama limiti, ebeveyn onayı ve yaşa uygun derecelendirme olmalı. — [Işıkoğlu](https://www.isikoglupartners.com/makaleler/oyun-ici-satin-alma-yasal-cerceve/)

### Inferences (Futbol Card Arena için önerilen uyum listesi; hukuki görüş değildir)
1. **Olasılık tablosu:** Her sandık için nadirlik ve kart türü bazında yüzde olasılıklar, satın alma düğmesinin hemen yanında bir "Olasılıklar" bağlantısı veya paneliyle gösterilmeli. Tablo, sunucudaki gerçek olasılık config'inden otomatik üretilmeli; elle girilmiş metin kullanılmamalı. Etkinlik sırasında olasılık değişirse tablo da anında güncellenmeli.
2. **Gerçek para karşılığı:** Elmasla satılan her ürünün yanında yaklaşık TL, €, $ karşılığı gösterilmeli. Elmas paketleri "sandık başına tam katlar" alınacak şekilde boyutlandırılmalı ki oyuncunun elinde zorunlu artık elmas kalmasın. Bu, CPC'nin maliyet gizleme endişesine karşı bir önlem.
3. **Oynayarak kazanılabilirlik:** Her sandık türü oyun içi yollarla da elde edilebilmeli: altınla, maç ödülüyle, sezon ödülüyle. Ücretsiz bir yol bulunması, kumar sınıflandırma riskini ve pay-to-win algısını azaltır.
4. **Pity / garanti sistemi:** "Her X sandıkta en az bir epik kart" gibi bir garanti açıkça yazılmalı ve tabloya eklenmeli. Kopya (duplicate) kartlar boşa gitmemeli; toz/parça gibi bir karşılığa dönüştürülmeli. Bunlar pratikte iyi bilinen uygulamalar, ancak yasal zorunluluk olduğuna dair bir kaynak bulunmadı.
5. **Kompu gacha'dan kaçınma:** Set tamamlama ödülleri yalnızca rastgele ücretli çekilişe bağlı olmamalı. Hedef kartlar başka yollarla da elde edilebilmeli.
6. **Paraya çevrilememe:** Kartların takası, satışı ve oyun dışına aktarılması olmamalı. Bu, Hollanda, Avusturya ve Türkiye'de kumar riskini düşük tutar.
7. **Yaş ve ülke anahtarları:**
   - İlk açılışta yaş beyanı alınmalı.
   - 18 yaş altında elmasla sandık açma kapatılmalı ya da ebeveyn onayı istenmeli (ABD için 16 yaş altı).
   - Belçika'da elmasla sandık açma tamamen kapatılmalı.
   - Brezilya'da 18 yaş altına kapatılmalı; tercihen oyunun genel yaş derecesine bakılarak bölge genelinde kapatılmalı.
   - Bu kurallar sunucu tarafında, ülke ve yaş bazında yönetilen bir feature flag ile uygulanmalı; böylece Türkiye ve AB yasaları yürürlüğe girdiğinde hızlıca açılıp kapatılabilir.
   - Ayarlara "Ücretli sandıkları kapat" seçeneği eklenmeli (DFA'ya hazırlık).
8. **Harcama limiti:** 18 yaş altı için günlük veya aylık harcama limiti konmalı. İsteğe bağlı olarak herkes için kendi koyabileceği bir limit sunulmalı.
9. **Satın alma ekranı (Türkiye):** TL fiyatı, ürün açıklaması ve şu metnin açık onayı gösterilmeli: "Dijital içerik anında teslim edilir; cayma hakkı bulunmamaktadır". Onay, kullanıcının işaretlediği bir onay kutusu olmalı; önceden işaretli olmamalı. Onay kaydı da saklanmalı.
10. **Pazarlama:** Sahte sayaç, "son X adet" gibi yapay kıtlık ve çocuklara yönelik baskı dili kullanılmamalı. Sınırlı süreli teklifler gerçekten o sürede bitmeli.
11. **Yaş derecelendirmesi:** Mağaza anketlerinde "rastgele ürün içeren uygulama içi satın alma" seçeneği doğru işaretlenmeli. Avustralya'da M, Almanya'da en az 12, PEGI'de "includes random items" etiketi beklenmeli. Kids/Families programına başvurulmamalı.
12. **Veri ve gizlilik:** 13 yaş altından kişisel veri toplanmamalı (COPPA). KVKK aydınlatma metni hazırlanmalı. Çocuk verileri için ek önlem alınmalı.

### Gaps
- Pity/garanti sistemini veya kopya kart korumasını yasal olarak zorunlu tutan bir kaynak bulunamadı. Bunlar iyi uygulama olarak önerildi.
- Ülke bazlı coğrafi kapatmanın mağaza kurallarıyla uyumu ve teknik yöntemi (store ülkesi mi, IP mi) bu araştırmada incelenmedi.
- Bu notlar hukuki görüş değildir. Türkiye ve AB lansmanı öncesinde bir avukata danışılması önerilir.
