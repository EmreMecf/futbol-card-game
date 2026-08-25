-- =====================================================================
-- 011 - KART PAKETLERI VE CIKMA IHTIMALLERI (GACHA SISTEMI)
-- =====================================================================
-- ANTI-HILE TEMEL KURALI:
-- Paket acma islemi TAMAMEN burada, veritabaninda yapilir. Flutter
-- sadece "su paketi acmak istiyorum" der. Hangi kartlarin ciktigina
-- istemci KARISAMAZ; rastgeleligi bile sunucu uretir.
--
-- Istemci tarafinda yapilsaydi: oyuncu uygulamanin belleğini
-- degistirip kendine Legend kart yazdirabilirdi.
-- =====================================================================

-- ---------------------------------------------------------------------
-- GUVENLI RASTGELE SAYI
-- ---------------------------------------------------------------------
-- NEDEN random() DEGIL?
-- PostgreSQL'in random() fonksiyonu oyun icin yeterli olsa da,
-- setseed() ile onceden tahmin edilebilir hale getirilebilir. Kart
-- cikma ihtimalleri paranin dondugu bir mekanizma oldugu icin
-- kriptografik olarak guvenli gen_random_bytes() kullaniyoruz.
--
-- MODULO SAPMASI (modulo bias) NEDIR?
-- 0-255 arasi bir sayiyi 10'a bolup kalanini alirsan, 0-5 arasi
-- degerler 26 kez, 6-9 arasi degerler 25 kez cikar. Yani kucuk
-- sayilar hafifce avantajli olur. Bu "sapma"yi engellemek icin
-- sinirin ustunde kalan degerleri REDDEDIP tekrar cekiyoruz.
create or replace function secure_random_int(p_max int)
returns int
language plpgsql
volatile
as $$
declare
  v_bytes bytea;
  v_val   bigint;
  v_limit bigint;
begin
  if p_max < 1 then
    raise exception 'secure_random_int: p_max en az 1 olmali.';
  end if;

  -- 4 bayt = 0 .. 4294967295 arasi bir sayi uretir.
  -- p_max'in tam kati olan en buyuk siniri buluyoruz.
  v_limit := (4294967296::bigint / p_max) * p_max;

  loop
    v_bytes := gen_random_bytes(4);
    v_val := (get_byte(v_bytes, 0)::bigint << 24)
           | (get_byte(v_bytes, 1)::bigint << 16)
           | (get_byte(v_bytes, 2)::bigint << 8)
           |  get_byte(v_bytes, 3)::bigint;

    -- Sinirin ustundeyse reddet, tekrar cek (sapma olmasin)
    exit when v_val < v_limit;
  end loop;

  return (v_val % p_max)::int + 1;
end;
$$;

comment on function secure_random_int(int) is
  'Kriptografik olarak guvenli, modulo sapmasi olmayan 1..p_max rastgele sayi.';

-- ---------------------------------------------------------------------
-- PAKET TANIMLARI
-- ---------------------------------------------------------------------
-- Ihtimaller ONBINDE (basis point) olarak tutulur.
--
-- NEDEN YUZDE DEGIL?
-- Legend ihtimali %0.1. Yuzdeyi tam sayi tutarsak 0.1 yazamayiz;
-- ondalik (float) tutarsak yuvarlama hatalari olusur ve toplam
-- tam 100 etmez. Onbinde tam sayi kullaninca %0.1 = 10 olur ve
-- toplam her zaman tam 10000'dir.
create table if not exists pack_types (
  id              uuid primary key default gen_random_uuid(),
  slug            text not null unique,
  name            text not null,
  description     text,

  -- Paketten cikacak kart sayisi
  card_count      int not null check (card_count between 1 and 50),

  -- Fiyat (0 = ucretsiz / sadece sistem tarafindan verilir)
  price_coins     int not null default 0 check (price_coins >= 0),

  -- Oyuncu magazadan satin alabilir mi?
  is_purchasable  boolean not null default true,

  -- Seviye ihtimalleri (onbinde). Toplami 10000 olmali.
  -- Ornek: {"bronze":5500,"silver":3000,"gold":1300,"diamond":190,"legend":10}
  tier_weights    jsonb not null,

  -- GUVENLIK KEMERI: Bu seviyenin ustunde kart ASLA cikmaz.
  -- Baslangic paketi icin 'gold' yazilir; agirliklar yanlislikla
  -- bozulsa bile Diamond/Legend cikmasi IMKANSIZ olur.
  max_tier        card_tier,

  -- Pozisyon garantisi. Ornek: {"GK":2,"DEF":5,"MID":5,"FWD":3}
  -- NULL ise pozisyonlar tamamen rastgele secilir.
  -- Doluysa toplami card_count'a esit olmali.
  position_quota  jsonb,

  is_active       boolean not null default true,
  sort_order      int not null default 0,
  created_at      timestamptz not null default now()
);

comment on table pack_types is
  'Paket tanimlari. Ihtimalleri degistirmek icin sadece bu tabloyu guncellemek yeterli; kod degismez.';

-- ---------------------------------------------------------------------
-- PAKET ACMA GECMISI (denetim kaydi)
-- ---------------------------------------------------------------------
-- Oyuncu "Legend cikmasi gerekiyordu, hile yaptiniz" derse buradan
-- ispatlanir. Ayrica gercek cikma oranlarini olcup dengeleme yapmak
-- icin de kullanilir.
create table if not exists pack_openings (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references users(id) on delete cascade,
  pack_slug     text not null,
  card_ids      uuid[] not null,
  tiers         text[] not null,
  coins_spent   int not null default 0,
  created_at    timestamptz not null default now()
);

create index if not exists idx_pack_openings_user
  on pack_openings (user_id, created_at desc);

-- ---------------------------------------------------------------------
-- SEVIYE CEKILISI
-- ---------------------------------------------------------------------
-- Agirliklari kumulatif olarak gezer ve rastgele sayinin dustugu
-- araligi doner.
--
-- Ornek (bronze:5500, silver:3000, gold:1300, diamond:190, legend:10):
--     1 -  5500  -> Bronz
--  5501 -  8500  -> Gumus
--  8501 -  9800  -> Altin
--  9801 -  9990  -> Diamond
--  9991 - 10000  -> Legend
create or replace function _roll_tier(
  p_weights  jsonb,
  p_max_tier card_tier default null
)
returns card_tier
language plpgsql
volatile
as $$
declare
  v_toplam   int := 0;
  v_zar      int;
  v_birikim  int := 0;
  v_seviye   card_tier;
  v_agirlik  int;
  v_sonuc    card_tier := 'bronze';
begin
  -- Toplam agirligi hesapla
  foreach v_seviye in array enum_range(null::card_tier) loop
    v_toplam := v_toplam + coalesce((p_weights ->> v_seviye::text)::int, 0);
  end loop;

  if v_toplam <= 0 then
    raise exception 'Paket agirliklari gecersiz (toplam 0).';
  end if;

  v_zar := secure_random_int(v_toplam);

  foreach v_seviye in array enum_range(null::card_tier) loop
    v_agirlik := coalesce((p_weights ->> v_seviye::text)::int, 0);
    if v_agirlik > 0 then
      v_birikim := v_birikim + v_agirlik;
      if v_zar <= v_birikim then
        v_sonuc := v_seviye;
        exit;
      end if;
    end if;
  end loop;

  -- GUVENLIK KEMERI: tavan seviyeyi asamaz
  if p_max_tier is not null and tier_rank(v_sonuc) > tier_rank(p_max_tier) then
    v_sonuc := p_max_tier;
  end if;

  return v_sonuc;
end;
$$;

-- ---------------------------------------------------------------------
-- KART SECIMI
-- ---------------------------------------------------------------------
-- Istenen seviye ve pozisyondan bir kart seçer.
--
-- AGIRLIKLI SECIM: cards.drop_weight yuksek olan kartlar daha sik
-- cikar. `-ln(random()) / agirlik` siralamasi, agirlikli rastgele
-- secimin standart ve dogru yontemidir (Efraimidis-Spirakis).
--
-- YEDEK PLAN: O seviye+pozisyonda hic kart yoksa bir alt seviyeye
-- iner. Katalogda Legend kaleci yoksa oyuncu bos kalmaz.
create or replace function _pick_card(
  p_tier     card_tier,
  p_position card_position
)
returns uuid
language plpgsql
volatile
as $$
declare
  v_card_id uuid;
  v_tier    card_tier := p_tier;
  v_rank    int;
begin
  v_rank := tier_rank(p_tier);

  while v_rank >= 1 loop
    select id into v_card_id
    from cards
    where is_active
      and tier = v_tier
      and position = p_position
    order by -ln(random()) / greatest(drop_weight, 1)
    limit 1;

    if v_card_id is not null then
      return v_card_id;
    end if;

    -- Bu seviyede kart yok, bir alt seviyeye in
    v_rank := v_rank - 1;
    exit when v_rank < 1;

    select t into v_tier
    from unnest(enum_range(null::card_tier)) t
    where tier_rank(t) = v_rank;
  end loop;

  raise exception 'Katalogda % pozisyonunda hic kart yok.', p_position;
end;
$$;

-- ---------------------------------------------------------------------
-- POZISYON LISTESI URET
-- ---------------------------------------------------------------------
-- Kota verilmisse ona uyar, verilmemisse rastgele pozisyon secer.
create or replace function _build_position_list(
  p_quota      jsonb,
  p_card_count int
)
returns card_position[]
language plpgsql
volatile
as $$
declare
  v_liste    card_position[] := '{}';
  v_pozisyon card_position;
  v_adet     int;
  v_i        int;
  v_tumu     card_position[] := enum_range(null::card_position);
begin
  if p_quota is null then
    -- Kota yok: her kart icin rastgele pozisyon
    for v_i in 1..p_card_count loop
      v_liste := v_liste || v_tumu[secure_random_int(array_length(v_tumu, 1))];
    end loop;
    return v_liste;
  end if;

  -- Kota var: garanti dagitim
  foreach v_pozisyon in array v_tumu loop
    v_adet := coalesce((p_quota ->> v_pozisyon::text)::int, 0);
    for v_i in 1..v_adet loop
      v_liste := v_liste || v_pozisyon;
    end loop;
  end loop;

  if array_length(v_liste, 1) <> p_card_count then
    raise exception 'Pozisyon kotasi (%) kart sayisiyla (%) uyusmuyor.',
      array_length(v_liste, 1), p_card_count;
  end if;

  return v_liste;
end;
$$;

-- =====================================================================
-- ANA FONKSIYON: PAKET AC
-- =====================================================================
-- Donus (json):
--   {
--     "pack": {"slug": "...", "name": "..."},
--     "coins_spent": 500,
--     "coins_left": 1500,
--     "cards": [ {kart bilgileri, "is_new": true}, ... ]
--   }
create or replace function open_pack(
  p_user_id   uuid,
  p_pack_slug text,
  p_free      boolean default false   -- sadece sistem cagrilarinda true
)
returns json
language plpgsql
as $$
declare
  v_pack       pack_types%rowtype;
  v_coins      int;
  v_pozisyonlar card_position[];
  v_pozisyon   card_position;
  v_tier       card_tier;
  v_card_id    uuid;
  v_user_card  uuid;
  v_kart_idler uuid[] := '{}';
  v_seviyeler  text[] := '{}';
  v_i          int;
  v_ucret      int;
begin
  -- ---- PAKETI BUL ----
  select * into v_pack from pack_types
  where slug = p_pack_slug and is_active;

  if not found then
    raise exception 'Boyle bir paket yok: %', p_pack_slug;
  end if;

  if not v_pack.is_purchasable and not p_free then
    raise exception 'Bu paket magazadan satin alinamaz.';
  end if;

  -- ---- KULLANICIYI KILITLE (coin dusumu icin) ----
  select coins into v_coins from users where id = p_user_id for update;

  if not found then
    raise exception 'Kullanici bulunamadi.';
  end if;

  v_ucret := case when p_free then 0 else v_pack.price_coins end;

  if v_coins < v_ucret then
    raise exception 'Yeterli coin yok. Gerekli: %, mevcut: %', v_ucret, v_coins;
  end if;

  -- ---- POZISYONLARI BELIRLE ----
  v_pozisyonlar := _build_position_list(v_pack.position_quota, v_pack.card_count);

  -- ---- KARTLARI CEK ----
  for v_i in 1..v_pack.card_count loop
    v_pozisyon := v_pozisyonlar[v_i];
    v_tier := _roll_tier(v_pack.tier_weights, v_pack.max_tier);
    v_card_id := _pick_card(v_tier, v_pozisyon);

    insert into user_cards (owner_id, card_id)
    values (p_user_id, v_card_id)
    returning id into v_user_card;

    v_kart_idler := v_kart_idler || v_user_card;
    -- Gercekte hangi seviye verildi? (_pick_card alt seviyeye inmis olabilir)
    v_seviyeler := v_seviyeler || (select tier::text from cards where id = v_card_id);
  end loop;

  -- ---- COIN DUS ----
  if v_ucret > 0 then
    update users set coins = coins - v_ucret where id = p_user_id
    returning coins into v_coins;
  end if;

  -- ---- DENETIM KAYDI ----
  insert into pack_openings (user_id, pack_slug, card_ids, tiers, coins_spent)
  values (p_user_id, p_pack_slug, v_kart_idler, v_seviyeler, v_ucret);

  -- ---- SONUCU DON ----
  return json_build_object(
    'pack', json_build_object(
      'slug', v_pack.slug,
      'name', v_pack.name,
      'card_count', v_pack.card_count
    ),
    'coins_spent', v_ucret,
    'coins_left', v_coins,
    'cards', (
      select coalesce(json_agg(
        json_build_object(
          'user_card_id', uc.id,
          'card_id', c.id,
          'slug', c.slug,
          'full_name', c.full_name,
          'position', c.position,
          'tier', c.tier,
          'power', c.power,
          'nationality', c.nationality,
          -- 'league' eksikti: paketten cikan kart koleksiyona duserken
          -- ligi bos geliyor, kimya onizlemesi yanlis hesapliyordu.
          'league', c.league,
          'club', c.club,
          'attributes', card_attributes_json(
            c.shooting, c.pace, c.physical,
            c.defending, c.dribbling, c.acceleration
          ),
          'image_url', c.image_url
        ) order by tier_rank(c.tier) desc, c.power desc
      ), '[]'::json)
      from user_cards uc
      join cards c on c.id = uc.card_id
      where uc.id = any (v_kart_idler)
    )
  );
end;
$$;

-- =====================================================================
-- BASLANGIC PAKETI (ONBOARDING)
-- =====================================================================
-- KURALLAR:
--   * Tam 15 kart
--   * Diamond ve Legend KESINLIKLE cikmaz (max_tier = 'gold')
--   * Pozisyon garantisi: 2 GK + 5 DEF + 5 MID + 3 FWD = 15
--     Bu dagilim, zorunlu 1-4-4-2 formasyonunu kurmaya HER ZAMAN yeter
--     ve ustune her pozisyonda en az 1 yedek birakir.
create or replace function grant_starter_pack(p_user_id uuid)
returns json
language plpgsql
as $$
declare
  v_deck_id uuid;
  v_sonuc   json;
  v_toplam  int;
begin
  if not exists (select 1 from users where id = p_user_id) then
    raise exception 'Kullanici bulunamadi.';
  end if;

  -- Sadece bir kez verilir
  if exists (select 1 from user_cards where owner_id = p_user_id) then
    raise exception 'Baslangic paketi zaten alinmis.';
  end if;

  -- Paketi ac (ucretsiz)
  v_sonuc := open_pack(p_user_id, 'starter', true);

  select count(*) into v_toplam from user_cards where owner_id = p_user_id;

  if v_toplam < squad_size() then
    raise exception 'Katalogda yeterli kart yok. Once seed verisini yukleyin.';
  end if;

  -- Varsayilan aktif deste
  insert into decks (owner_id, name, is_active)
  values (p_user_id, 'Ilk Kadrom', true)
  returning id into v_deck_id;

  -- Zorunlu formasyonu otomatik kur: 1 GK + 4 DEF + 4 MID + 2 FWD
  -- (her pozisyondan en guclu kartlar secilir)
  --
  -- =================================================================
  -- SLOT ATAMASI NEDEN SART?
  -- =================================================================
  -- 014 ile kimya sistemi geldiginde validate_deck() "her kart
  -- formasyonda bir slotta durmali" kuralini kazandi; kimya
  -- baglantilari slot numaralarindan hesaplaniyor.
  --
  -- Burasi guncellenmedigi icin yeni kayit olan oyuncunun kadrosu
  -- slotsuz kaliyordu: kadroda 11 kart goruyordu ama mac aramaya
  -- basinca "Kadro dizilisi eksik" hatasi aliyor ve kadro ekranina
  -- girip kaydetmeden OYUNA HIC BASLAYAMIYORDU.
  --
  -- Slot numaralarini elle yazmiyoruz (0=GK, 1-4=DEF, ...). O bilgi
  -- zaten formation_slot_position() icinde; burada tekrar edersek
  -- formasyon degistiginde iki yerden birini unuturuz. Bunun yerine
  -- her pozisyonun ILK slotunu o fonksiyona sorup, pozisyon icinde
  -- guce gore siralayarak uzerine ekliyoruz.
  with secilen as (
    (select uc.id, c.position as poz, c.power
       from user_cards uc join cards c on c.id = uc.card_id
      where uc.owner_id = p_user_id and c.position = 'GK'
      order by c.power desc limit 1)
    union all
    (select uc.id, c.position, c.power
       from user_cards uc join cards c on c.id = uc.card_id
      where uc.owner_id = p_user_id and c.position = 'DEF'
      order by c.power desc limit 4)
    union all
    (select uc.id, c.position, c.power
       from user_cards uc join cards c on c.id = uc.card_id
      where uc.owner_id = p_user_id and c.position = 'MID'
      order by c.power desc limit 4)
    union all
    (select uc.id, c.position, c.power
       from user_cards uc join cards c on c.id = uc.card_id
      where uc.owner_id = p_user_id and c.position = 'FWD'
      order by c.power desc limit 2)
  )
  insert into deck_cards (deck_id, user_card_id, slot_index)
  select v_deck_id,
         s.id,
         -- pozisyonun ilk slotu + pozisyon icindeki sira
         (select min(g) from generate_series(0, squad_size() - 1) g
           where formation_slot_position(g) = s.poz)
         + (row_number() over (partition by s.poz order by s.power desc) - 1)::int
  from secilen s;

  return json_build_object(
    'status', 'ok',
    'card_count', v_toplam,
    'deck_id', v_deck_id,
    'cards', v_sonuc -> 'cards'
  );
end;
$$;

-- =====================================================================
-- PAKET TANIMLARI (SEED)
-- =====================================================================
-- Ihtimalleri degistirmek istersen SADECE bu satirlari guncelle;
-- hicbir kod degistirmen gerekmez.

insert into pack_types
  (slug, name, description, card_count, price_coins, is_purchasable,
   tier_weights, max_tier, position_quota, sort_order)
values
  -- ---- BASLANGIC PAKETI ----
  -- Diamond ve Legend KESINLIKLE yok. Altin cok dusuk ihtimalle (%5).
  ('starter', 'Baslangic Paketi',
   'Ilk kadronu kurman icin 15 kart. Diamond ve Legend cikmaz.',
   15, 0, false,
   '{"bronze": 6500, "silver": 3000, "gold": 500}'::jsonb,
   'gold',                                        -- guvenlik kemeri
   '{"GK": 2, "DEF": 5, "MID": 5, "FWD": 3}'::jsonb,
   0),

  -- ---- STANDART PAKET ----
  -- Istenen dagilim: Bronz %55, Gumus %30, Altin %13, Diamond %1.9, Legend %0.1
  ('standard', 'Standart Paket',
   '5 kart. Legend cikma ihtimali binde bir.',
   5, 500, true,
   '{"bronze": 5500, "silver": 3000, "gold": 1300, "diamond": 190, "legend": 10}'::jsonb,
   null,
   null,
   1),

  -- ---- PREMIUM PAKET ----
  ('premium', 'Premium Paket',
   '5 kart, belirgin sekilde daha yuksek ihtimaller.',
   5, 2500, true,
   '{"bronze": 2000, "silver": 3500, "gold": 3500, "diamond": 900, "legend": 100}'::jsonb,
   null,
   null,
   2),

  -- ---- KADRO PAKETI ----
  -- Pozisyon kotali: tam bir 1-4-4-2 kadro cikarir
  ('squad', 'Kadro Paketi',
   'Tam bir 11 kisilik kadro (1 kaleci, 4 defans, 4 orta saha, 2 forvet).',
   11, 4000, true,
   '{"bronze": 4000, "silver": 3500, "gold": 2200, "diamond": 280, "legend": 20}'::jsonb,
   null,
   '{"GK": 1, "DEF": 4, "MID": 4, "FWD": 2}'::jsonb,
   3)
on conflict (slug) do update
set name           = excluded.name,
    description    = excluded.description,
    card_count     = excluded.card_count,
    price_coins    = excluded.price_coins,
    is_purchasable = excluded.is_purchasable,
    tier_weights   = excluded.tier_weights,
    max_tier       = excluded.max_tier,
    position_quota = excluded.position_quota,
    sort_order     = excluded.sort_order;

-- ---------------------------------------------------------------------
-- AGIRLIK TOPLAMI KONTROLU
-- ---------------------------------------------------------------------
-- Yanlislikla toplami 10000 olmayan bir agirlik girilirse uyarir.
-- (Hata degil uyari: sistem yine calisir, sadece oranlar sasar.)
do $$
declare
  r record;
  v_toplam int;
begin
  for r in select slug, tier_weights from pack_types loop
    select sum(value::int) into v_toplam
    from jsonb_each_text(r.tier_weights);

    if v_toplam <> 10000 then
      raise notice 'UYARI: "%" paketinin agirlik toplami % (10000 olmali).',
        r.slug, v_toplam;
    end if;
  end loop;
end $$;
