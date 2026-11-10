-- =====================================================================
-- EKONOMİ V2 KALİTE KONTROLÜ — VERİTABANI DENETİMİ (GERİ ALINIR)
-- =====================================================================
-- Konu 6: 23 item (kaynak, kullanım, süre dolumu, tekrar verilme, tek sefer)
-- Konu 7: sezon kapanışında alınmamış ödüller (hata durumu dahil)
-- Konu 8: sandık kuyruğu, posta kutusu, telafi (kaynak kaybı / çift ödül)
--
-- Test değil DENETİM: "BULGU" satırları düzeltme önerisidir, betik
-- durmaz. Çalıştırma (boş test veritabanında, migration'lardan sonra):
--   psql -d <db> -v ON_ERROR_STOP=1 -f database/audits/ekonomi_v2_denetim.sql
-- =====================================================================
begin;

create function pg_temp.ok(p_ad text, p_kosul boolean, p_bulgu text default null)
returns void language plpgsql as $$
begin
  if p_kosul then
    raise notice 'OK     %', p_ad;
  else
    raise notice 'BULGU  % — %', p_ad, coalesce(p_bulgu, '');
  end if;
end;
$$;

do $$
declare
  u uuid; v uuid; s1 uuid;
  d item_definitions%rowtype;
  kaynak text[];
  n int; n2 int; altin int; altin2 int;
  r jsonb;
  ch uuid; ch2 uuid;
  kart uuid;
  t text;
begin
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 980, '{"economy_v2_enabled": true}', 'denetim');
  insert into users (email, password_hash, username, coins) values ('denetim@test.local', 'x', 'denetim', 100000)
  returning id into u;
  insert into users (email, password_hash, username, coins) values ('denetim2@test.local', 'x', 'denetim_2', 0)
  returning id into v;

  -- ============ KONU 6: ITEMLER ============
  -- 6a) Oyunda kaynağı olan itemler: Battle Pass tablosu + sandıktaki jokerler
  select array_agg(distinct x) into kaynak from (
    select t2 -> y ->> 'slug' x
    from jsonb_array_elements(_season_rules() -> 'tiers') t2, unnest(array['free', 'premium']) y
    where t2 -> y ->> 'type' = 'item'
    union select 'joker_' || j from unnest(array['bronze', 'silver', 'gold', 'diamond', 'legend']) j
  ) q;
  for d in select * from item_definitions where is_active order by sort_order loop
    perform pg_temp.ok('6a kaynak: ' || d.slug, d.slug = any(kaynak),
      'oyunda hiçbir kaynaktan gelmiyor (yalnız geliştirme ucu)');
  end loop;

  -- 6b) Her item: aynı anahtarla iki kez verilince bir kez
  for d in select * from item_definitions where is_active loop
    perform grant_item(u, d.slug, 1, 'denetim', 'tek', 'denetim-tek-' || d.slug);
    perform grant_item(u, d.slug, 1, 'denetim', 'tek', 'denetim-tek-' || d.slug);
  end loop;
  select count(*) into n from item_definitions idf where idf.is_active and _item_qty(u, idf.slug) <> 1;
  perform pg_temp.ok('6b 23 item: aynı anahtarla tekrar verilmiyor (her biri 1)', n = 0, n || ' item 1 değil');

  -- 6c) Kullanım: kategoriye göre
  select id into kart from cards where tier = 'gold' and is_active order by power limit 1;
  insert into user_cards (owner_id, card_id) values (u, kart);
  for d in select * from item_definitions where is_active and kind in ('consumable', 'timed') order by sort_order loop
    begin
      r := use_item(u, d.slug, case d.category
                                 when 'mastery_book' then jsonb_build_object('card_id', kart)
                                 else '{}'::jsonb end, 'denetim-kullan-' || d.slug);
      perform pg_temp.ok('6c kullanılır: ' || d.slug, true);
    exception when others then
      t := split_part(sqlerrm, ':', 1);
      perform pg_temp.ok('6c kullanılır: ' || d.slug,
        -- beklenen ret: hedefi olmayan anahtar/hızlandırıcı, başka nadirlikte kitap, seviye ekranında kullanılan indirim
        t in ('item_not_applicable', 'chest_not_found', 'card_not_owned', 'item_not_usable')
          and d.slug <> 'event_ticket',
        case when d.slug = 'event_ticket' then 'hiçbir yerde kullanılamıyor (etkinlik modu yok): ' || t
             else 'beklenmeyen hata: ' || sqlerrm end);
    end;
  end loop;

  -- 6d) Aynı kullanım anahtarıyla tekrar: bir kez düşer
  perform grant_item(u, 'energy_drink', 3, 'denetim', 'icecek', 'denetim-icecek');
  n := _item_qty(u, 'energy_drink');
  perform use_item(u, 'energy_drink', '{}', 'denetim-ayni');
  perform use_item(u, 'energy_drink', '{}', 'denetim-ayni');
  perform pg_temp.ok('6d aynı anahtarla kullanım tek sefer', _item_qty(u, 'energy_drink') = n - 1);

  -- 6e) Süre dolumu: indirim süresi geçince görünmez, kullanılamaz; yeniden verilince çalışır
  update user_items set expires_at = now() - interval '1 second' where user_id = u and item_slug = 'level_discount_25';
  perform pg_temp.ok('6e süresi dolan indirim sayılmaz', _item_qty(u, 'level_discount_25') = 0);
  perform pg_temp.ok('6e süresi dolan envanterde görünmez', not exists (
    select 1 from jsonb_array_elements(item_inventory(u) -> 'items') x where x ->> 'slug' = 'level_discount_25'));
  perform pg_temp.ok('6e süresi dolan satır denetim için saklanır',
    exists (select 1 from user_items where user_id = u and item_slug = 'level_discount_25'));
  perform grant_item(u, 'level_discount_25', 1, 'denetim', 'yeniden', 'denetim-yeniden');
  perform pg_temp.ok('6e yeniden verilince 1 adet, 7 gün', _item_qty(u, 'level_discount_25') = 1 and exists (
    select 1 from user_items where user_id = u and item_slug = 'level_discount_25'
      and expires_at between now() + interval '6 days 23 hours' and now() + interval '7 days 1 hour'));

  -- 6f) Kozmetik ikinci kez (farklı anahtar) -> altın, tekrar etmez
  altin := (select coins from users where id = u);
  perform grant_item(u, 'kit_season1', 1, 'denetim', 'kozmetik2', 'denetim-kozmetik-2');
  perform pg_temp.ok('6f tekrar kozmetik altına döner (150)',
    _item_qty(u, 'kit_season1') = 1 and (select coins from users where id = u) = altin + 150);

  -- ============ KONU 8: SANDIK KUYRUĞU / POSTA / TELAFİ ============
  delete from user_chests where user_id = v;
  for n in 1..4 loop perform _grant_chest(v, 'silver', 'denetim', 'yuva-' || n); end loop;
  for n in 1..8 loop perform _grant_chest(v, 'gold', 'denetim', 'posta-' || n); end loop;
  perform pg_temp.ok('8a 4 yuva + 8 posta dolu',
    (select count(*) from user_chests where user_id = v and location = 'slot') = 4
    and (select count(*) from user_chests where user_id = v and location = 'mailbox' and status = 'sealed') = 8);
  altin := (select coins from users where id = v);
  ch := _grant_chest(v, 'gold', 'denetim', 'tasma');
  ch2 := _grant_chest(v, 'gold', 'denetim', 'tasma');
  perform pg_temp.ok('8b taşan sandık telafi edilir, aynı kaynakla ikinci kez verilmez',
    ch = ch2 and (select coins from users where id = v) = altin + 180
    and (select count(*) from economy_ledger where idempotency_key = 'chest_comp:' || ch) = 1);
  perform pg_temp.ok('8c telafi kaybolmaz (durum compensated, sonuçta altın)',
    (select status from user_chests where id = ch) = 'compensated');

  -- Posta ömrü dolunca telafi; ikinci çalıştırma bir şey vermez
  update user_chests set created_at = now() - interval '8 days' where user_id = v and location = 'mailbox' and status = 'sealed';
  altin := (select coins from users where id = v);
  n := expire_mailbox_chests();
  n2 := expire_mailbox_chests();
  perform pg_temp.ok('8d posta ömrü: 8 sandık telafi, tekrar 0',
    n = 8 and n2 = 0 and (select coins from users where id = v) = altin + 8 * 180);

  -- Açılış tek sefer
  select id into ch from user_chests where user_id = v and location = 'slot' order by slot_no limit 1;
  perform start_chest_unlock(v, ch);
  update user_chests set unlock_ready_at = now() - interval '1 second' where id = ch;
  altin := (select coins from users where id = v);
  r := open_chest(v, ch);
  altin2 := (select coins from users where id = v);
  r := open_chest(v, ch);
  perform pg_temp.ok('8e aynı sandığı ikinci açış ödül vermez', (select coins from users where id = v) = altin2
    and altin2 > altin and (select count(*) from economy_ledger where entry_type = 'chest_open' and source_id = ch::text) <= 1);

  -- Yuvalar doluyken postadan alma reddedilir, sandık postada kalır
  for n in 1..2 loop perform _grant_chest(v, 'gold', 'denetim', 'posta2-' || n); end loop;
  perform _grant_chest(v, 'silver', 'denetim', 'yuva-yeniden');   -- açılan yuvayı doldur
  select id into ch2 from user_chests where user_id = v and location = 'mailbox' and status = 'sealed' limit 1;
  begin
    perform claim_mailbox_chest(v, ch2);
    perform pg_temp.ok('8f dolu yuvaya postadan alma reddedilir', false, 'kabul edildi');
  exception when others then
    perform pg_temp.ok('8f dolu yuvaya postadan alma reddedilir, sandık postada kalır',
      (select location from user_chests where id = ch2) = 'mailbox');
  end;

  -- Sezon ödülü sandığı yuvalar + posta doluyken: telafi, ödül kaydı tek
  for n in 1..8 loop perform _grant_chest(v, 'gold', 'denetim', 'posta3-' || n); end loop;
  perform dev_season_add_xp(v, 3000);
  altin := (select coins from users where id = v);
  r := claim_season_reward(v, 3, 'free');     -- 3. kademe: Gümüş sandık
  perform pg_temp.ok('8g dolu kutuda sezon sandığı telafiye döner (70)',
    (select status from user_chests where id = (r ->> 'chest_id')::uuid) = 'compensated'
    and (select coins from users where id = v) = altin + 70);
  r := claim_season_reward(v, 3, 'free');
  perform pg_temp.ok('8g tekrar alma çift telafi vermez', (select coins from users where id = v) = altin + 70);

  -- ============ KONU 7: SEZON KAPANIŞI ============
  s1 := (_current_season()).id;
  perform dev_season_add_xp(u, 5000);                 -- u: 5 kademe
  perform claim_season_reward(u, 1, 'free');          -- 1'i aldı, 2-5 almadı
  perform dev_set_season_premium(u, true);
  -- Hata durumu: premium 1. kademe ödülü (forma) kapanış anında verilemiyor
  update item_definitions set is_active = false where slug = 'kit_season1';
  update seasons set ends_at = now() - interval '1 second', starts_at = now() - interval '30 days' where id = s1;
  n := close_due_seasons();
  perform pg_temp.ok('7a ücretsiz 2-5 otomatik verildi',
    (select count(*) from season_claims where user_id = u and season_id = s1 and track = 'free' and auto) = 4);
  perform pg_temp.ok('7b hata alan ödül kaydedildi (economy_errors)',
    exists (select 1 from economy_errors where context = 'season_close' and user_id = u));
  perform pg_temp.ok('7c hata alan ödül sonra yeniden denenebiliyor',
    exists (select 1 from pg_proc where proname = 'repair_season_rewards'),
    'sezon "kapandı" işaretlenir ve yeniden deneme yok: premium 1. kademe (forma) KALICI KAYIP');
  update item_definitions set is_active = true where slug = 'kit_season1';
  perform pg_temp.ok('7c2 onarım hata alan ödülü verir (036)',
    repair_season_rewards() = 1 and _item_qty(u, 'kit_season1') >= 1, 'onarılamadı');
  perform pg_temp.ok('7c3 ikinci onarım çift ödül vermez', repair_season_rewards() = 0);
  perform pg_temp.ok('7d kapanış tekrar çalışınca çift ödül yok', close_due_seasons() = 0);
  perform pg_temp.ok('7e kapanmış sezona elle alma yeni sezona gider (eskiye dokunmaz)',
    (_current_season()).id <> s1);

  raise notice 'DENETİM BİTTİ';
end;
$$;

rollback;
