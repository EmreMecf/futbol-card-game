# LiveOps Rehberi

Görsel yönetim paneli yok; işlemler **yönetici API'si** (064) ya da
veritabanı fonksiyonlarıyla yapılır. Her değişiklik **değiştirilemez
denetim kaydı** (kim, ne, neden) üretir; ayar değişikliği ayrıca yeni ayar
sürümü. Eski sürüm silinmez, geri dönüş = eski değerleri yeniden yazmak.

## Roller (064)

| Rol | Yetki |
|---|---|
| `viewer` | genel bakış, metrik, deney raporu |
| `operator` | + ayar (gerçek para hariç), kozmetik teklif, ürünü durdurma, acil kapatma, deney |
| `owner` | + gerçek para: `iap_enabled`, `gem_packs_enabled`, `starter_pack_enabled`, `premium_season_pass_enabled` açmak ve ücretli ürünü `active` yapmak |

Rol **yalnız veritabanından** verilir (API ile rol verilemez):

```sql
insert into admin_users (user_id, role, granted_by, note)
values ((select id from users where username = '<kullanici>'), 'operator', '<veren>', '<neden>');
update admin_users set revoked_at = now() where user_id = '<uuid>';   -- geri al
```

## Yönetici API'si (`/api/admin/monetization`, oyuncu oturumu + rol)

```bash
A=https://<sunucu>/api/admin/monetization; H="authorization: Bearer <jeton>"
curl -H "$H" $A/overview                        # ayar, ürünler, teklifler, deneyler, son 30 denetim
curl -H "$H" "$A/metrics?days=7"                # reklam, satın alma (tahmini gelir), iade, kozmetik, ücretli elmas
curl -H "$H" -X POST $A/config -d '{"patch": {"rewarded_ads_enabled": true}, "reason": "..."}'
curl -H "$H" -X POST $A/kill-switch -d '{"reason": "..."}'
curl -H "$H" -X POST $A/products/gems_starter_100 -d '{"status": "paused", "reason": "..."}'
curl -H "$H" -X POST $A/offers/offer_frame_neon -d '{"patch": {"price_gems": 100}, "reason": "..."}'
curl -H "$H" -X POST $A/experiments -d '{"key": "odul_metni", "variants": [{"name": "control", "weight": 50}, {"name": "b", "weight": 50}], "reason": "..."}'
curl -H "$H" -X POST $A/experiments/odul_metni -d '{"status": "running", "reason": "..."}'
curl -H "$H" $A/experiments/odul_metni          # grup başına oyuncu, reklam ödülü, ödeyen
```

Hata: rol yetmezse 403 `admin_forbidden`; gerekçe boşsa 409 `invalid_reason`.
Hız sınırı dakikada 60 istek.

## Saklama süresi (064)

`purge_monetization_events()` saatlik zamanlayıcıyla çalışır: analitik
olay 180 gün, ham SSV kaydı 90 gün, doğrulama olayı 400 gün. Satın alma
kaydı, defterler (`gem_ledger`, `economy_ledger`) ve denetim kaydı
**silinmez** (mali kayıt).

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

064 deney tablosu: `monetization_experiments` (gruplar ve ağırlıklar, toplam
100), `experiment_assignments` (ilk görülmede yazılır, **kalıcı**: ağırlık
sonradan değişse de oyuncunun grubu değişmez). Durum: taslak → çalışıyor →
durdu (durmuş deney yeniden başlamaz). İstemci grubunu
`/api/monetization/config` cevabındaki `experiments` alanından okur.
Bugün deney yalnız istemci tarafı değişiklikleri (metin, yerleşim) için
hazır; sunucu kurallarını gruba göre değiştirmek (ör. günlük reklam
limiti) henüz bağlı değil.
Başarı ölçütü yalnız gelir değildir: D1/D7 elde tutma ve maç sayısı
kontrolden kötüyse deney başarısızdır.
