# LiveOps Rehberi

Yönetim paneli henüz yok (Faz 6). Bugün bütün işlemler veritabanı
fonksiyonlarıyla yapılır; her biri **yeni ayar sürümü + değiştirilemez
denetim kaydı** üretir. Eski sürüm silinmez, geri dönüş = eski değerleri
yeniden yazmak.

## Ayar okuma

```sql
select monetization_config();                         -- etkin ayar
select economy_config_version('monetization');        -- sürüm
select * from monetization_admin_audit order by id desc limit 20;  -- kim, ne zaman, neden
```

## Açma / kapatma

```sql
-- Staging'de yalnız test oyuncularına
select set_monetization_config('{"monetization_enabled": true, "rewarded_ads_enabled": true,
  "daily_reward_ads_enabled": true, "whitelist": ["<uuid>"]}', '<ad>', '<gerekce>');
-- Yüzde açılım (oyuncu başına sabit dilim; her oturumda değişmez)
select set_monetization_config('{"rollout_percent": 10}', '<ad>', 'A grubu');
-- Günlük tavan / yerleşim ödülü
select set_monetization_config('{"daily_rewarded_ad_limit": 2}', '<ad>', '<gerekce>');
select set_monetization_config(jsonb_build_object('placements',
  monetization_config()->'placements' || '{"daily_reward": {"flag": "daily_reward_ads_enabled",
  "daily_limit": 2, "reward": {"type": "coins", "amount": 40}}}'::jsonb), '<ad>', '<gerekce>');
-- Eski sürüme reklam açma
select set_monetization_config('{"min_app_version": "1.2.0"}', '<ad>', '<gerekce>');
```

## Kozmetik mağaza (062)

```sql
-- Aç (önce beyaz liste)
select set_monetization_config('{"monetization_enabled": true, "cosmetic_shop_enabled": true,
  "whitelist": ["<uuid>"]}', '<ad>', '<gerekce>');
-- Teklif fiyatı / durumu (yalnız kozmetik item teklif olabilir)
update cosmetic_offers set price_gems = 100 where id = 'offer_frame_neon';
update cosmetic_offers set status = 'paused' where id = 'offer_frame_crimson';
-- Süreli teklif
update cosmetic_offers set ends_at = now() + interval '7 days', featured = true where id = 'offer_frame_emerald';
-- Satışlar: ne kadarı ücretsiz, ne kadarı ücretli elmasla
select offer_id, count(*), sum(free_spent) ucretsiz, sum(paid_spent) ucretli
from cosmetic_purchases group by 1;
```

Yeni kozmetik eklemeden önce istemcide çizimi olmalı (`cosmeticFramePalette`,
`cosmeticVictoryOverlay`); çizilmeyen ürün satılmaz. Fiyat değişikliği
satın alınmış ürünleri etkilemez.

Başlangıç paketi (`starter_pack_1`): içerik 50 ücretli elmas + Çaylak
çerçevesi, hesap yaşı ≤ 7 gün, tek seferlik. Açmak için ürünü `active`
yapmak ve `starter_pack_enabled` gerekir (gerçek para: açık onay).

## Premium sezon yolu (063)

```sql
-- Süren sezon satılabilir mi (premium yolu tamamen güçsüz mü)?
select season_premium_status('<uuid>');
-- Aç (gerçek para: açık onay)
update product_catalog set status = 'active' where id = 'season_pass_premium';
select set_monetization_config('{"monetization_enabled": true, "iap_enabled": true,
  "premium_season_pass_enabled": true, "whitelist": ["<uuid>"]}', '<ad>', '<gerekce>');
-- Satışlar ve iadeler
select status, count(*) from purchase_transactions where product_id = 'season_pass_premium' group by 1;
```

Sezon ödül tablosu sezon başında dondurulur. 035 tablolu (güçlü premium)
bir sezon sürerken ürün görünmez; sürüm 2 ile açılan ilk sezonda satılabilir.
Yeni sezon için yeni pas kozmetiği istenirse yeni bir `season_rules`
sürümü eklenir (premium yolda yalnız `paid_gems` ve telafisi 0 kozmetik);
istemcide çizimi (`cosmeticFramePalette`) önce eklenmelidir.

## Acil kapatma

```sql
select monetization_kill_switch('<ad>', '<neden>');
```

Yeni reklam oturumu ve satın alma açılmaz. **Önceden doğrulanmış ödüller
kaybolmaz**; gecikmiş SSV geri çağrıları rezervasyonu olan oturumları yine
işler (oyuncunun hak ettiği ödül).

## İzleme sorguları

```sql
-- Günlük huni
select date_trunc('day', created_at) gun, event, count(*) from monetization_events
where created_at > now() - interval '7 days' group by 1, 2 order by 1 desc, 2;
-- SSV sağlığı (geçersiz imza, ret nedenleri)
select outcome, signature_valid, count(*) from ad_ssv_events
where received_at > now() - interval '1 day' group by 1, 2;
-- Oyuncu başı günlük reklam (tavan aşımı olmamalı)
select user_id, game_day, count(*) from ad_sessions where status in ('granted','credit')
group by 1, 2 having count(*) > 3;
```

Reklam geliri AdMob panelinden okunur; bu tablolar gelir değil **olay**
sayar. Tahmini ve kesin gelir karıştırılmaz.

## A/B (deney)

Yüzde dilimi `monetization_bucket(user_id, özellik)` deterministiktir.
Kontrol: `rollout_percent=0`; A: %50 ve `daily_reward` limit 2; B için
ayrı bir özellik anahtarıyla ikinci dilim (Faz 6'da deney tablosu).
Başarı ölçütü yalnız gelir değildir: D1/D7 elde tutma ve maç sayısı
kontrolden kötüyse deney başarısızdır.
