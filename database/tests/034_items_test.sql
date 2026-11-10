-- =====================================================================
-- 034 ITEM KATALOGU VE ENVANTER — VERITABANI TESTLERI (GERI ALINIR)
-- =====================================================================
begin;

create function pg_temp.beklenen(p_ad text, p_gercek anyelement, p_beklenen anyelement)
returns void language plpgsql as $$
begin
  if p_gercek is distinct from p_beklenen then
    raise exception 'TEST BASARISIZ: % -> beklenen %, gelen %', p_ad, p_beklenen, p_gercek;
  end if;
  raise notice 'OK  %', p_ad;
end;
$$;

create function pg_temp.hata_bekle(p_ad text, p_sql text, p_mesaj text)
returns void language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if position(p_mesaj in sqlerrm) = 0 then
      raise exception 'TEST BASARISIZ: % -> beklenmeyen hata: %', p_ad, sqlerrm;
    end if;
    raise notice 'OK  % (reddedildi)', p_ad;
    return;
  end;
  raise exception 'TEST BASARISIZ: % -> hata bekleniyordu, ama kabul edildi', p_ad;
end;
$$;

do $$
declare
  u uuid;
  bronz uuid;
  ch uuid;
  ch2 uuid;
  v jsonb;
  altin int;
  n int;
begin
  insert into economy_config_versions (kind, version, payload, note)
  values ('feature_flags', 995, '{"economy_v2_enabled": true}', 'test');
  insert into users (email, password_hash, username, coins) values ('item-test@test.local', 'x', 'item_test', 50000)
  returning id into u;
  select id into bronz from cards where tier = 'bronze' and is_active order by power limit 1;
  insert into user_cards (owner_id, card_id) values (u, bronz);

  -- 1) Katalog
  perform pg_temp.beklenen('katalogda 23 item', (select count(*)::int from item_definitions where is_active), 23);
  perform pg_temp.beklenen('kozmetiklerin yuvasi var',
    (select count(*)::int from item_definitions where kind = 'cosmetic' and cosmetic_slot is null), 0);

  -- 2) Ver: idempotent; kapasite asimi altina doner
  v := grant_item(u, 'chest_key', 3, 'test', 't1', 'k-1');
  perform pg_temp.beklenen('3 anahtar', _item_qty(u, 'chest_key'), 3);
  v := grant_item(u, 'chest_key', 3, 'test', 't1', 'k-1');
  perform pg_temp.beklenen('ayni anahtarla tekrar vermez', _item_qty(u, 'chest_key'), 3);
  altin := (select coins from users where id = u);
  v := grant_item(u, 'chest_key', 9, 'test', 't2', 'k-2');
  perform pg_temp.beklenen('kapasite 10', _item_qty(u, 'chest_key'), 10);
  perform pg_temp.beklenen('tasan 2 anahtar altina (60 x 2)', (select coins from users where id = u), altin + 120);

  -- 3) Kozmetik: tek; tekrar gelirse altin; giyilir
  perform grant_item(u, 'kit_season1', 1, 'test', 't3', 'k-3');
  altin := (select coins from users where id = u);
  perform grant_item(u, 'kit_season1', 1, 'test', 't4', 'k-4');
  perform pg_temp.beklenen('kozmetik tek adet', _item_qty(u, 'kit_season1'), 1);
  perform pg_temp.beklenen('tekrar kozmetik 150 altin', (select coins from users where id = u), altin + 150);
  v := equip_cosmetic(u, 'kit_season1');
  perform pg_temp.beklenen('forma giyildi', (select item_slug from user_equipped where user_id = u and slot = 'kit'), 'kit_season1');
  perform pg_temp.hata_bekle('sahip olunmayan giyilemez',
    format('select equip_cosmetic(%L, %L)', u, 'frame_season1'), 'not_enough_items');

  -- 4) Sureli: suresi dolan sayilmaz ama SILINMEZ
  perform grant_item(u, 'level_discount_25', 1, 'test', 't5', 'k-5');
  perform pg_temp.beklenen('indirim var', _item_qty(u, 'level_discount_25'), 1);
  update user_items set expires_at = now() - interval '1 second' where user_id = u and item_slug = 'level_discount_25';
  perform pg_temp.beklenen('suresi dolan sayilmaz', _item_qty(u, 'level_discount_25'), 0);
  perform pg_temp.beklenen('ama silinmedi',
    (select count(*)::int from user_items where user_id = u and item_slug = 'level_discount_25'), 1);

  -- 5) Anahtar: baska sandigin sayaci calisirken de kullanilir
  ch := _grant_chest(u, 'gold', 'test', 'item-ch-1');
  ch2 := _grant_chest(u, 'silver', 'test', 'item-ch-2');
  perform start_chest_unlock(u, ch2);
  v := use_item(u, 'chest_key', jsonb_build_object('chest_id', ch), 'use-1');
  perform pg_temp.beklenen('anahtarli sandik acilir', jsonb_array_length(open_chest(u, ch) -> 'cards'), 3);
  perform pg_temp.beklenen('1 anahtar harcandi', _item_qty(u, 'chest_key'), 9);
  v := use_item(u, 'chest_key', jsonb_build_object('chest_id', ch), 'use-1');
  perform pg_temp.beklenen('tekrar istek anahtar harcamaz', _item_qty(u, 'chest_key'), 9);
  ch := _grant_chest(u, 'legend', 'test', 'item-ch-3');
  perform use_item(u, 'chest_key', jsonb_build_object('chest_id', ch), 'use-2');
  perform pg_temp.beklenen('efsane 2 anahtar', _item_qty(u, 'chest_key'), 7);

  -- 6) Hizlandirici: calisan sayactan 2 saat duser
  perform grant_item(u, 'chest_speedup_2h', 1, 'test', 't6', 'k-6');
  v := use_item(u, 'chest_speedup_2h', '{}', 'use-3');
  perform pg_temp.beklenen('gumus sandik (2 sa) hazir', (v ->> 'chest_ready')::boolean, true);
  perform pg_temp.hata_bekle('sayac yokken hizlandirici kullanilmaz',
    format('select use_item(%L, %L, %L, %L)', u, 'chest_speedup_2h', '{}', 'use-4'), 'item_not_applicable');

  -- 7) Enerji icecegi: +3, gunde en fazla 2
  insert into reward_energy (user_id, energy) values (u, 2)
  on conflict (user_id) do update set energy = 2, refill_anchor = now();
  perform grant_item(u, 'energy_drink', 3, 'test', 't7', 'k-7');
  v := use_item(u, 'energy_drink', '{}', 'use-5');
  perform pg_temp.beklenen('enerji 2 -> 5', (v ->> 'energy')::int, 5);
  perform use_item(u, 'energy_drink', '{}', 'use-6');
  perform pg_temp.hata_bekle('gunluk sinir 2',
    format('select use_item(%L, %L, %L, %L)', u, 'energy_drink', '{}', 'use-7'), 'daily_limit');

  -- 8) Ustalik kitabi ve indirim
  perform grant_item(u, 'mastery_book_bronze', 1, 'test', 't8', 'k-8');
  perform grant_item(u, 'mastery_book_gold', 1, 'test', 't9', 'k-9');
  perform pg_temp.hata_bekle('yanlis nadirlik',
    format('select use_item(%L, %L, %L, %L)', u, 'mastery_book_gold', jsonb_build_object('card_id', bronz), 'use-8'),
    'item_not_applicable');
  v := use_item(u, 'mastery_book_bronze', jsonb_build_object('card_id', bronz), 'use-9');
  perform pg_temp.beklenen('kitap 1 kopya verdi (bronz 1->2)', (v ->> 'copies_added')::int, 1);
  perform grant_item(u, 'level_discount_25', 1, 'test', 't10', 'k-10');
  altin := (select coins from users where id = u);
  v := level_up_player(u, bronz, false, true);
  perform pg_temp.beklenen('indirim 5 altin (20 x %25)', (v ->> 'discount')::int, 5);
  perform pg_temp.beklenen('15 altin dustu', (select coins from users where id = u), altin - 15);
  perform pg_temp.beklenen('indirim harcandi', _item_qty(u, 'level_discount_25'), 0);

  -- 9) Joker sandiktan envantere; dogrudan kullanilmaz
  ch := _grant_chest(u, 'bronze', 'test', 'item-ch-4');
  perform open_chest(u, ch);
  perform pg_temp.beklenen('bronz sandik joker verdi', _item_qty(u, 'joker_bronze') >= 1, true);
  perform pg_temp.hata_bekle('joker dogrudan kullanilmaz',
    format('select use_item(%L, %L, %L, %L)', u, 'joker_bronze', '{}', 'use-10'), 'item_not_usable');

  -- 10) Defter: her kullanim tek kayit (anahtar 2 + hiz 1 + icecek 2 + kitap 1)
  select count(*) into n from economy_ledger where user_id = u and entry_type = 'item_use';
  perform pg_temp.beklenen('kullanim kayitlari 6', n, 6);

  -- 11) Joker tasimasi kayipsizdi: eski tablo saklaniyor
  perform pg_temp.beklenen('eski joker tablosu saklaniyor', to_regclass('user_joker_shards_legacy') is not null, true);
  perform pg_temp.beklenen('eski tablo adi artik yok', to_regclass('user_joker_shards') is null, true);

  raise notice '034 item testleri: HEPSI GECTI';
end;
$$;

rollback;
