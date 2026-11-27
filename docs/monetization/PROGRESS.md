# İlerleme

Bağlam yenilenirse buradan devam edilir.

## Tamamlanan (27 Kasım 2026)

### Faz 0 — Denetim
* AUDIT, ARCHITECTURE, IMPLEMENTATION_PLAN, ECONOMY_RISK_ANALYSIS yazıldı.
* Üç çatışma: elmas→altın, premium sezon yolu, elmasla sandık. Karar:
  ücretli/ücretsiz elmas ayrımı; premium satış kapalı kalır.

### Faz 1 — Çekirdek (migration 060)
* `monetization` ayar türü (sürümlü, değiştirilemez), kapılar: global,
  özellik, platform, en düşük sürüm, beyaz liste, deterministik yüzde.
* `set_monetization_config` (doğrulamalı) + `monetization_admin_audit`
  (değiştirilemez) + `monetization_kill_switch`.
* `monetization_events` (analitik huni), `users.paid_gems` (0).

### Faz 2 — Ödüllü reklam
* SQL: `ad_sessions` (süreli rezervasyon), `ad_eligibility`,
  `ad_session_create`, `ad_session_client_event` (ödül vermez),
  `ad_ssv_grant` (tekil işlem, tavan yeniden sayımı, kredi),
  `ad_session_apply_credit`, `ad_status`, `monetization_client_config`.
* Sunucu: `server/lib/monetization/ad_ssv_verifier.dart` (ECDSA P-256,
  Google anahtar önbelleği), `monetization_routes.dart`
  (`/api/monetization/*`, `/api/ads/ssv`), `Env.deployStage`,
  `Env.monetizationTestProviders`.
* İstemci: `google_mobile_ads 9.2.0`, `lib/features/monetization/*`
  (modeller, API, sağlayıcı arayüzü + AdMob + web/yok, durum makinesi),
  `lib/ui_v21/screens/monetization/v21_ad_widgets.dart` (günlük ödül hapı,
  onay, doğrulama kutusu), sandık penceresinde reklamla −10 dk ve kayıtlı
  kredi. Android/iOS test uygulama kimlikleri.
* Belgeler: ADMOB_SETUP, SECURITY_REVIEW, TEST_REPORT, LIVEOPS_GUIDE,
  DEPLOYMENT_GUIDE, RELEASE_CHECKLIST, GOOGLE_PLAY_BILLING_SETUP,
  APPLE_IAP_SETUP (plan).
* Simülasyon: `tool/ekonomi/monetizasyon_simulasyonu.dart`.

### Faz 3 — Satın alma (migration 061)
* SQL: `gem_ledger.currency`, `users.paid_gems_debt`, `_paid_gem_add`
  (önce borç kapanır), `product_catalog` (güç içeriği CHECK ile yasak;
  4 ürün `draft`), `purchase_transactions`, `purchase_verification_events`,
  `purchase_grant_verified` (tekil, hesaplar arası engel, bekleyen ödeme),
  `purchase_mark_acknowledged`, `purchase_refund`, `purchase_history`.
* Sunucu: `purchase_verifier.dart` (Google Play, App Store, test sağlayıcı
  yalnız staging), `purchase_routes.dart` (`/api/purchases/*`,
  `/api/webhooks/google-play`, `/api/webhooks/apple`). Anahtar yoksa 503.
* İstemci: `in_app_purchase`, `lib/features/monetization/purchase/*`
  (mağaza arayüzü + IAP + yok, akış denetleyicisi), mağazada
  `V21GemPacksSection` (cayma hakkı onayı, geri yükleme).
* CI: simülatör analiz uyarıları; Android release'te eklenti lint çökmesi
  (`lint { checkReleaseBuilds = false }`).

### Faz 4 — Kozmetik mağaza + başlangıç paketi (migration 062)
* SQL: 5 yeni kozmetik (Neon / Kızıl Alev / Zümrüt / Çaylak çerçeve,
  Yıldız Yağmuru zafer animasyonu; tekrar telafisi 0 altın),
  `cosmetic_offers` (yalnız kozmetik; tetikleyiciyle denetlenir),
  `cosmetic_purchases` (oyuncu+kozmetik tekil, istek anahtarı tekil, ücretsiz/ücretli
  dağılımı), `cosmetic_shop`, `buy_cosmetic` (önce ücretsiz elmas, kapı
  `cosmetic_shop_enabled`). Başlangıç paketi içeriği: 50 ücretli elmas +
  Çaylak çerçevesi (taslak kalır).
* Sunucu: `cosmetic_shop_routes.dart` (`GET /api/shop/cosmetics`,
  `POST /api/shop/cosmetics/buy`).
* İstemci: `lib/features/monetization/cosmetics/cosmetic_shop.dart`,
  `lib/ui_v21/screens/monetization/v21_cosmetic_shop.dart` (teklif kartları,
  önizleme, açık onay, giy). Kozmetik mağaza açıkken mağaza sekmeli
  (PAKETLER / KOZMETİK / ELMAS); kapalıyken ekran aynen eski hâli.
  Başlangıç paketi afişi elmas bölümünde. Çerçeve paleti ve zafer
  animasyonu çizimleri `v21_cosmetics.dart`.
* Yalnız oyunda gerçekten çizilen kozmetikler satılır (çerçeve: profil ve
  açık profil; zafer: maç sonu). Test sunucu tohumuyla istemci çizimini
  karşılaştırır.

### Faz 5 — Güçsüz premium sezon yolu (migration 063)
* Sezon kuralı sürüm 2: ücretsiz yol 035 ile birebir aynı; premium yol
  yalnız ücretli elmas (kademe başına 5, 10/20/30/40'ta 20, 25'te 25) ve
  pas çerçeveleri (1: Buz Kristali, 50: Altın Kupa; telafi 0). Tablo sezon
  başında dondurulduğu için SÜREN sezon değişmez; yeni sezonlar sürüm 2.
* Satış kapısı `_season_premium_power_free`: süren sezonun premium yolu
  tamamen güçsüz değilse ürün katalogda görünmez, doğrulansa da premium
  verilmez (iade için işaretlenir). Sezon başına tek alım.
* Ürün `season_pass_premium` (SEASON_PASS, taslak). Satın alma süren sezona
  bağlanır; ulaşılmış kademeler hemen alınabilir (geriye dönük), alınmayanlar
  sezon sonunda otomatik. İade: premium kalkar, premium yoldan alınan ücretli
  elmas (borçla) ve pas kozmetikleri geri alınır.
* `_season_grant` yeni ödül türü `paid_gems`; `season_premium_status`.
* İstemci: `SeasonReward.isPaidGems`, sezon ekranında `V21SeasonPremiumOffer`
  (yalnız sunucu satarken), ödül yolunda elmas ve çerçeve simgesi; elmas
  bölümünde premium yol paket gibi listelenmez.
* 035/036 testleri kendi tablolarını (sürüm 1) işlem içinde sabitler.

## Sıradaki

| Adım | Not |
|---|---|
| 2d | Ayarlar > "Gizlilik seçenekleri" düğmesi (UMP `privacyOptionsRequired`), KVKK rıza ekranı (metin insan onayı), iOS ATT kararı |
| 2e | Maç sonu teklifi arayüzü (`post_match`, sunucu hazır, arayüz yok; bayrak kapalı) |
| 3b | Gerçek cihazda Google lisans testi / Apple sandbox (hesaplar BLOCKED); hukuk metni onayı (cayma hakkı cümlesi) |
| 4b | Kart görünümü / arena / forma kozmetiklerinin çizimi oyunda bağlı değil (034'te tanımlı, ekranda yok); bağlanınca mağazaya eklenebilir. 043 lig çerçeveleri de çizilmiyor |
| 5b | Her yeni sezon için yeni pas kozmetikleri (sürüm 3+): aynı çerçeve ikinci sezonda tekrar gelirse telafisi 0 olduğu için boş ödül olur |
| 6 | Yönetici uçları (rol + denetim), deney tablosu, olay saklama süresi |

## BLOCKED (insan / hesap)

* AdMob hesabı, gerçek reklam birimleri, SSV adresinin konsolda tanımı
* Google Play Console ürünleri + hizmet hesabı; App Store Connect ürünleri + API anahtarı
* KVKK aydınlatma metni, gizlilik politikası, mağaza beyanları (hukuk)

## Onay bekleyen (yapılmadı)

* Staging'e 060 + 061 + 062 + 063 deploy (commit/push kullanıcı kararı)
* Premium sezon yolunu satışa açmak (`season_pass_premium` active, `premium_season_pass_enabled`; gerçek para)
* Kozmetik mağazayı açmak (`cosmetic_shop_enabled`) ve teklif fiyatlarını onaylamak
* Gerçek para tahsilatını açmak (`iap_enabled`, ürünleri `active` yapmak)
* Üretimde herhangi bir monetizasyon bayrağını açmak
