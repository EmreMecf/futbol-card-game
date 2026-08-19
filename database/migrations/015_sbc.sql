-- =====================================================================
-- 015 - SBC (SQUAD BUILDING CHALLENGES) — KADRO KURMA GOREVLERI
-- =====================================================================
-- AMAC: Oyuncu paket actikca elinde yuzlerce kullanilmayan Bronz/Gumus
-- kart birikiyor. Bunlari cope atmak yerine "eritip" (burn) daha degerli
-- odullere donusturebilmeli.
--
-- ISLEYIS:
--   1. Gorev sartlar sunar ("11 gumus kart, en az 30 kimya, 3 farkli uyruk")
--   2. Oyuncu envanterinden 11 kart secip formasyona dizer
--   3. Sunucu sartlari DOGRULAR
--   4. Kartlar KALICI OLARAK SILINIR
--   5. Odul verilir
--
-- ISLEM BUTUNLUGU: Bu fonksiyonlar tek bir transaction icinde calisir.
-- Odul verilirken hata olursa kartlarin silinmesi de geri alinir; oyuncu
-- ne kartini ne odulunu kaybeder.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) KIMYA HESABINI GENELLESTIR
-- ---------------------------------------------------------------------
-- Kimya simdiye kadar sadece "deste" uzerinden hesaplanabiliyordu.
-- SBC kadrosu bir deste degil; sadece siralanmis 11 kart. Bu yuzden
-- cekirdek hesabi DIZI uzerinden calisacak sekilde ayiriyoruz.
--
-- Dizinin SIRASI slot numarasini belirler (0=kaleci, 1-4=defans, ...)
-- Deste versiyonu da artik bunu cagiriyor; kural tek yerde.
create or replace function calculate_squad_chemistry(p_card_ids uuid[])
returns table (
  slot_index   int,
  user_card_id uuid,
  chemistry    int
)
language sql
stable
as $$
  with kadro as (
    select (x.ord - 1)::int as slot_index,
           x.card_id as user_card_id,
           c.nationality, c.league, c.club
    from unnest(p_card_ids) with ordinality as x(card_id, ord)
    join user_cards uc on uc.id = x.card_id
    join cards c       on c.id  = uc.card_id
  ),
  baglar as (
    select l.slot_a, l.slot_b,
           chemistry_link_score(
             a.nationality, a.league, a.club,
             b.nationality, b.league, b.club
           ) as puan
    from formation_links() l
    join kadro a on a.slot_index = l.slot_a
    join kadro b on b.slot_index = l.slot_b
  )
  select k.slot_index,
         k.user_card_id,
         coalesce((
           select sum(b.puan)::int
           from baglar b
           where b.slot_a = k.slot_index or b.slot_b = k.slot_index
         ), 0)
  from kadro k
  order by k.slot_index;
$$;

-- Toplam takim kimyasi (baglarin puan toplami)
create or replace function squad_chemistry_total(p_card_ids uuid[])
returns int
language sql
stable
as $$
  with kadro as (
    select (x.ord - 1)::int as slot_index,
           c.nationality, c.league, c.club
    from unnest(p_card_ids) with ordinality as x(card_id, ord)
    join user_cards uc on uc.id = x.card_id
    join cards c       on c.id  = uc.card_id
  )
  select coalesce(sum(
    chemistry_link_score(
      a.nationality, a.league, a.club,
      b.nationality, b.league, b.club
    )
  ), 0)::int
  from formation_links() l
  join kadro a on a.slot_index = l.slot_a
  join kadro b on b.slot_index = l.slot_b;
$$;

-- Destedeki kartlari SLOT SIRASINA gore diziye cevirir.
--
-- DIKKAT - BOSLUKLU KADROLAR:
-- Kadro eksik olabilir (oyuncu mac kaybedip kart kaptirmis olabilir).
-- Sadece dolu slotlari toplayip dizi yapmak YANLIS olur: 0,1,2,4,5
-- slotlari doluysa dizi 5 elemanli olur ve 4. slottaki kart 3. slota
-- kaymis gibi hesaplanir.
--
-- Bu yuzden 11 elemanli TAM dizi uretiyoruz; bos slotlar NULL kaliyor.
-- NULL kartlar user_cards ile eslesmedigi icin hesaba girmiyor.
create or replace function deck_slot_array(p_deck_id uuid)
returns uuid[]
language sql
stable
as $$
  select array_agg(dc.user_card_id order by s.slot)
  from generate_series(0, squad_size() - 1) s(slot)
  left join deck_cards dc
    on dc.deck_id = p_deck_id and dc.slot_index = s.slot;
$$;

-- Deste versiyonu artik ortak cekirdegi kullaniyor
create or replace function calculate_deck_chemistry(p_deck_id uuid)
returns table (
  slot_index   int,
  user_card_id uuid,
  chemistry    int
)
language sql
stable
as $$
  select * from calculate_squad_chemistry(deck_slot_array(p_deck_id));
$$;

-- =====================================================================
-- 2) GOREV TANIMLARI
-- =====================================================================
-- Sartlar ve oduller JSONB olarak tutuluyor.
--
-- NEDEN JSONB, NEDEN AYRI KOLONLAR DEGIL?
-- Her yeni gorev tipi icin tabloya kolon eklemek ("min_kimya",
-- "min_uyruk_sayisi", "min_ortalama_guc"...) tabloyu sisirir ve her
-- eklemede kod degistirmeyi gerektirir. JSONB kural listesiyle yeni
-- bir gorev SADECE veri eklenerek olusturulabiliyor.
--
-- SART TIPLERI:
--   {"type":"exact_tier",          "tier":"silver"}          tum kartlar bu seviyede
--   {"type":"min_tier",            "tier":"gold"}            en az bu seviyede
--   {"type":"max_tier",            "tier":"gold"}            en fazla bu seviyede
--   {"type":"min_chemistry",       "value":30}               takim kimyasi
--   {"type":"min_avg_power",       "value":75}               ortalama guc
--   {"type":"min_distinct_nations","value":3}                farkli uyruk
--   {"type":"min_distinct_leagues","value":2}                farkli lig
--   {"type":"min_distinct_clubs",  "value":5}                farkli kulup
--   {"type":"min_cards_of_tier",   "tier":"gold","value":4}  belirli seviyeden N kart
--   {"type":"min_cards_of_league", "league":"Super Lig","value":4}
--   {"type":"min_cards_of_nation", "nation":"TUR","value":3}
--
-- ODUL TIPLERI:
--   {"type":"coins","amount":1000}
--   {"type":"pack","pack_slug":"premium"}
--   {"type":"card","card_slug":"legend-orta-diego-maradona"}
create table if not exists sbc_challenges (
  id            uuid primary key default gen_random_uuid(),
  slug          text not null unique,
  name          text not null,
  description   text,

  -- Zorluk/gruplama: 'baslangic', 'gunluk', 'ozel'
  category      text not null default 'genel',

  -- Sart listesi (JSONB dizisi)
  requirements  jsonb not null default '[]'::jsonb,

  -- Odul listesi (JSONB dizisi)
  rewards       jsonb not null default '[]'::jsonb,

  -- Kac kez tamamlanabilir? NULL = sinirsiz
  max_completions int default 1 check (max_completions is null or max_completions > 0),

  -- Gorev ne zaman kapaniyor? NULL = suresiz
  expires_at    timestamptz,

  is_active     boolean not null default true,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now()
);

comment on table sbc_challenges is
  'Kadro kurma gorevleri. Yeni gorev eklemek icin SADECE bu tabloya satir eklemek yeterli; kod degismez.';

create index if not exists idx_sbc_active
  on sbc_challenges (is_active, sort_order) where is_active;

-- ---------------------------------------------------------------------
-- 3) TAMAMLAMA GECMISI
-- ---------------------------------------------------------------------
-- Hangi kullanici hangi gorevi ne zaman, hangi kartlari eriterek
-- tamamladi? Oyuncu "kartlarim kayboldu" derse buradan ispatlanir.
create table if not exists sbc_completions (
  id              bigint generated always as identity primary key,
  user_id         uuid not null references users(id) on delete cascade,
  challenge_id    uuid not null references sbc_challenges(id) on delete cascade,

  -- Eritilen kartlarin kimlikleri (kartlar silindigi icin FK YOK)
  burned_card_ids uuid[] not null,

  -- Eritilen kartlarin okunabilir dokumu (kart silinse de kalsin)
  burned_summary  jsonb not null default '[]'::jsonb,

  -- Verilen odulun dokumu
  granted_rewards jsonb not null default '[]'::jsonb,

  completed_at    timestamptz not null default now()
);

create index if not exists idx_sbc_completions_user
  on sbc_completions (user_id, completed_at desc);

create index if not exists idx_sbc_completions_challenge
  on sbc_completions (challenge_id);

-- =====================================================================
-- 4) SART DEGERLENDIRME
-- =====================================================================
-- Bir kadronun gorev sartlarini karsilayip karsilamadigini olcer.
--
-- Donus: her sart icin hedef, mevcut deger ve karsilanip karsilanmadigi.
-- Arayuz bu listeyi dogrudan yesil tik / kirmizi carpi olarak gosteriyor.
--
-- ONEMLI: Bu fonksiyon HEM "kontrol et" ucu HEM DE gonderim icinde
-- kullaniliyor. Tek kaynak oldugu icin "ekranda yesil gorunuyordu ama
-- sunucu reddetti" durumu olusamaz.
create or replace function evaluate_sbc_squad(
  p_user_id     uuid,
  p_challenge_id uuid,
  p_card_ids    uuid[]
)
returns json
language plpgsql
stable
as $$
declare
  v_gorev      sbc_challenges%rowtype;
  v_sart       jsonb;
  v_sonuclar   jsonb := '[]'::jsonb;
  v_tumu_gecti boolean := true;

  v_kimya      int;
  v_ort_guc    numeric;
  v_kart_sayisi int;
  v_sahip_degil int;
  v_kilitli    int;
  v_destede    int;

  v_hedef      numeric;
  v_mevcut     numeric;
  v_gecti      boolean;
  v_etiket     text;
  v_tip        text;
begin
  select * into v_gorev from sbc_challenges where id = p_challenge_id;

  if not found then
    raise exception 'Gorev bulunamadi.';
  end if;

  -- ---- TEMEL KONTROLLER ----
  v_kart_sayisi := coalesce(array_length(p_card_ids, 1), 0);

  -- Ayni kart iki kez gonderilmis olabilir
  if v_kart_sayisi <> (select count(distinct x) from unnest(p_card_ids) x) then
    return json_build_object(
      'is_valid', false,
      'blocking_error', 'Ayni kart birden fazla kez kullanilamaz.',
      'requirements', '[]'::json
    );
  end if;

  if v_kart_sayisi <> squad_size() then
    return json_build_object(
      'is_valid', false,
      'blocking_error', format('Kadroda %s kart olmali, su an %s kart var.',
                               squad_size(), v_kart_sayisi),
      'requirements', '[]'::json
    );
  end if;

  -- Kartlar gercekten bu oyuncunun mu, kilitli mi, destede mi?
  select
    count(*) filter (where uc.owner_id is distinct from p_user_id),
    count(*) filter (where uc.locked_match_id is not null),
    count(*) filter (where dc.user_card_id is not null)
  into v_sahip_degil, v_kilitli, v_destede
  from unnest(p_card_ids) x(card_id)
  left join user_cards uc on uc.id = x.card_id
  left join deck_cards dc on dc.user_card_id = x.card_id;

  if v_sahip_degil > 0 then
    return json_build_object(
      'is_valid', false,
      'blocking_error', 'Secilen kartlardan bazilari size ait degil.',
      'requirements', '[]'::json
    );
  end if;

  if v_kilitli > 0 then
    return json_build_object(
      'is_valid', false,
      'blocking_error', 'Devam eden bir macta kullanilan kartlar eritilemez.',
      'requirements', '[]'::json
    );
  end if;

  -- KASITLI KORUMA: Kadrondaki kartlari yanlislikla eritmeyesin.
  -- Aksi halde gorevi tamamlayip maca giremez hale gelebilirdin.
  if v_destede > 0 then
    return json_build_object(
      'is_valid', false,
      'blocking_error', 'Kadrondaki kartlar eritilemez. Once onlari kadrodan cikar.',
      'requirements', '[]'::json
    );
  end if;

  -- Formasyona uygunluk (kimya hesabi buna bagli)
  if exists (
    select 1
    from unnest(p_card_ids) with ordinality as x(card_id, ord)
    join user_cards uc on uc.id = x.card_id
    join cards c       on c.id  = uc.card_id
    where c.position <> formation_slot_position((x.ord - 1)::int)
  ) then
    return json_build_object(
      'is_valid', false,
      'blocking_error', 'Kartlar formasyondaki dogru pozisyonlara yerlestirilmeli.',
      'requirements', '[]'::json
    );
  end if;

  -- ---- OLCUMLER ----
  v_kimya := squad_chemistry_total(p_card_ids);

  select avg(c.power) into v_ort_guc
  from unnest(p_card_ids) x(card_id)
  join user_cards uc on uc.id = x.card_id
  join cards c       on c.id  = uc.card_id;

  -- ---- SARTLARI TEK TEK DEGERLENDIR ----
  for v_sart in select * from jsonb_array_elements(v_gorev.requirements)
  loop
    v_tip := v_sart ->> 'type';
    v_hedef := coalesce((v_sart ->> 'value')::numeric, 0);

    case v_tip

      when 'min_chemistry' then
        v_mevcut := v_kimya;
        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('En az %s takim kimyasi', v_hedef::int);

      when 'min_avg_power' then
        v_mevcut := round(v_ort_guc, 1);
        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('En az %s ortalama guc', v_hedef::int);

      when 'exact_tier' then
        select count(*) into v_mevcut
        from unnest(p_card_ids) x(card_id)
        join user_cards uc on uc.id = x.card_id
        join cards c       on c.id  = uc.card_id
        where c.tier = (v_sart ->> 'tier')::card_tier;

        v_hedef := squad_size();
        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('Tum kartlar %s seviyesinde olmali',
                           (v_sart ->> 'tier'));

      when 'min_tier' then
        select count(*) into v_mevcut
        from unnest(p_card_ids) x(card_id)
        join user_cards uc on uc.id = x.card_id
        join cards c       on c.id  = uc.card_id
        where tier_rank(c.tier) >= tier_rank((v_sart ->> 'tier')::card_tier);

        v_hedef := squad_size();
        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('Tum kartlar en az %s seviyesinde olmali',
                           (v_sart ->> 'tier'));

      when 'max_tier' then
        select count(*) into v_mevcut
        from unnest(p_card_ids) x(card_id)
        join user_cards uc on uc.id = x.card_id
        join cards c       on c.id  = uc.card_id
        where tier_rank(c.tier) <= tier_rank((v_sart ->> 'tier')::card_tier);

        v_hedef := squad_size();
        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('Hicbir kart %s seviyesini gecmemeli',
                           (v_sart ->> 'tier'));

      when 'min_cards_of_tier' then
        select count(*) into v_mevcut
        from unnest(p_card_ids) x(card_id)
        join user_cards uc on uc.id = x.card_id
        join cards c       on c.id  = uc.card_id
        where c.tier = (v_sart ->> 'tier')::card_tier;

        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('En az %s adet %s kart',
                           v_hedef::int, (v_sart ->> 'tier'));

      when 'min_distinct_nations' then
        select count(distinct c.nationality) into v_mevcut
        from unnest(p_card_ids) x(card_id)
        join user_cards uc on uc.id = x.card_id
        join cards c       on c.id  = uc.card_id
        where c.nationality is not null;

        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('En az %s farkli uyruk', v_hedef::int);

      when 'min_distinct_leagues' then
        select count(distinct c.league) into v_mevcut
        from unnest(p_card_ids) x(card_id)
        join user_cards uc on uc.id = x.card_id
        join cards c       on c.id  = uc.card_id
        where c.league is not null;

        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('En az %s farkli lig', v_hedef::int);

      when 'min_distinct_clubs' then
        select count(distinct c.club) into v_mevcut
        from unnest(p_card_ids) x(card_id)
        join user_cards uc on uc.id = x.card_id
        join cards c       on c.id  = uc.card_id
        where c.club is not null;

        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('En az %s farkli kulup', v_hedef::int);

      when 'min_cards_of_league' then
        select count(*) into v_mevcut
        from unnest(p_card_ids) x(card_id)
        join user_cards uc on uc.id = x.card_id
        join cards c       on c.id  = uc.card_id
        where c.league = (v_sart ->> 'league');

        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('%s liginden en az %s kart',
                           (v_sart ->> 'league'), v_hedef::int);

      when 'min_cards_of_nation' then
        select count(*) into v_mevcut
        from unnest(p_card_ids) x(card_id)
        join user_cards uc on uc.id = x.card_id
        join cards c       on c.id  = uc.card_id
        where c.nationality = (v_sart ->> 'nation');

        v_gecti := v_mevcut >= v_hedef;
        v_etiket := format('%s uyruklu en az %s kart',
                           (v_sart ->> 'nation'), v_hedef::int);

      else
        -- Bilinmeyen sart tipi: gorevi kilitle, sessizce gecirme.
        v_mevcut := 0;
        v_gecti := false;
        v_etiket := format('Bilinmeyen sart: %s', v_tip);
    end case;

    if not v_gecti then
      v_tumu_gecti := false;
    end if;

    v_sonuclar := v_sonuclar || jsonb_build_object(
      'type',    v_tip,
      'label',   v_etiket,
      'target',  v_hedef,
      'current', v_mevcut,
      'is_met',  v_gecti
    );
  end loop;

  return json_build_object(
    'is_valid',       v_tumu_gecti,
    'blocking_error', null,
    'chemistry',      v_kimya,
    'avg_power',      round(coalesce(v_ort_guc, 0), 1),
    'requirements',   v_sonuclar
  );
end;
$$;

-- =====================================================================
-- 5) ODUL VERME
-- =====================================================================
create or replace function _grant_sbc_reward(p_user_id uuid, p_rewards jsonb)
returns json
language plpgsql
as $$
declare
  v_odul     jsonb;
  v_verilen  jsonb := '[]'::jsonb;
  v_tip      text;
  v_miktar   int;
  v_card_id  uuid;
  v_uc_id    uuid;
  v_paket    json;
begin
  for v_odul in select * from jsonb_array_elements(p_rewards)
  loop
    v_tip := v_odul ->> 'type';

    case v_tip

      when 'coins' then
        v_miktar := coalesce((v_odul ->> 'amount')::int, 0);
        update users set coins = coins + v_miktar where id = p_user_id;

        v_verilen := v_verilen || jsonb_build_object(
          'type', 'coins', 'amount', v_miktar
        );

      when 'pack' then
        -- Ucretsiz acilis: SBC odulu oldugu icin coin dusulmez
        v_paket := open_pack(p_user_id, v_odul ->> 'pack_slug', true);

        v_verilen := v_verilen || jsonb_build_object(
          'type', 'pack',
          'pack_slug', v_odul ->> 'pack_slug',
          'cards', v_paket -> 'cards'
        );

      when 'card' then
        select id into v_card_id from cards
        where slug = (v_odul ->> 'card_slug');

        if v_card_id is null then
          raise exception 'Odul karti bulunamadi: %', (v_odul ->> 'card_slug');
        end if;

        insert into user_cards (owner_id, card_id)
        values (p_user_id, v_card_id)
        returning id into v_uc_id;

        v_verilen := v_verilen || jsonb_build_object(
          'type', 'card',
          'user_card_id', v_uc_id,
          'card', (
            select jsonb_build_object(
              'user_card_id', v_uc_id,
              'card_id', c.id,
              'full_name', c.full_name,
              'position', c.position,
              'tier', c.tier,
              'power', c.power,
              'nationality', c.nationality,
              'league', c.league,
              'club', c.club,
              'image_url', c.image_url
            )
            from cards c where c.id = v_card_id
          )
        );

      else
        raise exception 'Bilinmeyen odul tipi: %', v_tip;
    end case;
  end loop;

  return v_verilen::json;
end;
$$;

-- =====================================================================
-- 6) ANA FONKSIYON: GOREVI GONDER (BURN + ODUL)
-- =====================================================================
-- ISLEM BUTUNLUGU:
-- PostgreSQL fonksiyonlari tek bir transaction icinde calisir. Odul
-- verilirken hata olusursa (ornek: katalogda odul karti yok) kartlarin
-- silinmesi de dahil TUM islem geri alinir. Oyuncu ne kartini kaybeder
-- ne de odulsuz kalir.
create or replace function submit_sbc(
  p_user_id      uuid,
  p_challenge_id uuid,
  p_card_ids     uuid[]
)
returns json
language plpgsql
as $$
declare
  v_gorev       sbc_challenges%rowtype;
  v_dogrulama   json;
  v_tamamlanan  int;
  v_ozet        jsonb;
  v_oduller     json;
begin
  -- ---- GOREVI KILITLE ----
  -- Ayni oyuncu iki sekmeden ayni anda gonderirse ikisi de gecmesin.
  select * into v_gorev from sbc_challenges
  where id = p_challenge_id for update;

  if not found then
    raise exception 'Gorev bulunamadi.';
  end if;

  if not v_gorev.is_active then
    raise exception 'Bu gorev artik aktif degil.';
  end if;

  if v_gorev.expires_at is not null and v_gorev.expires_at < now() then
    raise exception 'Bu gorevin suresi dolmus.';
  end if;

  -- ---- TEKRAR SINIRI ----
  if v_gorev.max_completions is not null then
    select count(*) into v_tamamlanan
    from sbc_completions
    where user_id = p_user_id and challenge_id = p_challenge_id;

    if v_tamamlanan >= v_gorev.max_completions then
      raise exception 'Bu gorevi zaten tamamladiniz.';
    end if;
  end if;

  -- ---- SARTLARI DOGRULA ----
  -- Istemci de ayni kurallari uyguluyor ama BURASI yetkili.
  v_dogrulama := evaluate_sbc_squad(p_user_id, p_challenge_id, p_card_ids);

  if (v_dogrulama ->> 'blocking_error') is not null then
    raise exception '%', (v_dogrulama ->> 'blocking_error');
  end if;

  if not (v_dogrulama ->> 'is_valid')::boolean then
    raise exception 'Kadro gorev sartlarini karsilamiyor.';
  end if;

  -- ---- ERITILECEK KARTLARIN DOKUMUNU AL ----
  -- Kartlar birazdan silinecek; gecmiste okunabilir kalsin diye
  -- ozetini simdi cikariyoruz.
  select coalesce(jsonb_agg(jsonb_build_object(
           'card_id',   c.id,
           'full_name', c.full_name,
           'position',  c.position,
           'tier',      c.tier,
           'power',     c.power
         )), '[]'::jsonb)
  into v_ozet
  from unnest(p_card_ids) x(card_id)
  join user_cards uc on uc.id = x.card_id
  join cards c       on c.id  = uc.card_id;

  -- ---- KARTLARI ERIT (KALICI SILME) ----
  delete from user_cards where id = any (p_card_ids);

  -- ---- ODULU VER ----
  v_oduller := _grant_sbc_reward(p_user_id, v_gorev.rewards);

  -- ---- GECMISE YAZ ----
  insert into sbc_completions
    (user_id, challenge_id, burned_card_ids, burned_summary, granted_rewards)
  values
    (p_user_id, p_challenge_id, p_card_ids, v_ozet, v_oduller::jsonb);

  return json_build_object(
    'status',        'ok',
    'challenge_slug', v_gorev.slug,
    'challenge_name', v_gorev.name,
    'burned_count',  array_length(p_card_ids, 1),
    'burned_cards',  v_ozet,
    'rewards',       v_oduller,
    'coins',         (select coins from users where id = p_user_id)
  );
end;
$$;

-- =====================================================================
-- 7) GOREV LISTESI (tamamlanma durumuyla)
-- =====================================================================
create or replace function list_sbc_challenges(p_user_id uuid)
returns json
language sql
stable
as $$
  select coalesce(json_agg(json_build_object(
    'id',              g.id,
    'slug',            g.slug,
    'name',            g.name,
    'description',     g.description,
    'category',        g.category,
    'requirements',    g.requirements,
    'rewards',         g.rewards,
    'max_completions', g.max_completions,
    'expires_at',      g.expires_at,
    'completed_count', (
      select count(*) from sbc_completions sc
      where sc.user_id = p_user_id and sc.challenge_id = g.id
    ),
    'is_completed', (
      g.max_completions is not null and
      (select count(*) from sbc_completions sc
       where sc.user_id = p_user_id and sc.challenge_id = g.id) >= g.max_completions
    )
  ) order by g.sort_order, g.name), '[]'::json)
  from sbc_challenges g
  where g.is_active
    and (g.expires_at is null or g.expires_at > now());
$$;

-- =====================================================================
-- 8) ODUL PAKETI: GARANTILI ALTIN
-- =====================================================================
-- SBC odulu olarak verilecek ozel paket. Magazadan SATIN ALINAMAZ.
insert into pack_types
  (slug, name, description, card_count, price_coins, is_purchasable,
   tier_weights, max_tier, position_quota, sort_order)
values
  ('sbc_gold', 'Garantili Altin Paket',
   'SBC odulu. 3 kart, hepsi en az Altin seviyesinde.',
   3, 0, false,
   '{"gold": 8200, "diamond": 1600, "legend": 200}'::jsonb,
   null, null, 90),

  ('sbc_premium', 'SBC Elit Paket',
   'Zor gorevlerin odulu. 5 kart, yuksek Diamond ve Legend ihtimali.',
   5, 0, false,
   '{"gold": 6000, "diamond": 3200, "legend": 800}'::jsonb,
   null, null, 91)
on conflict (slug) do update
set name           = excluded.name,
    description    = excluded.description,
    card_count     = excluded.card_count,
    tier_weights   = excluded.tier_weights,
    is_purchasable = excluded.is_purchasable;

-- =====================================================================
-- 9) BASLANGIC GOREVLERI
-- =====================================================================
-- Yeni gorev eklemek icin SADECE buraya satir eklemek yeterli.

insert into sbc_challenges
  (slug, name, description, category, requirements, rewards,
   max_completions, sort_order)
values

  -- ---- 1) BRONZ TEMIZLIGI ----
  -- En kolay gorev: elde biriken bronz kartlari coine cevirir.
  ('bronz-temizligi', 'Bronz Temizligi',
   'Elinde biriken bronz kartlari degerlendirme zamani. Kimya sarti yok.',
   'baslangic',
   '[{"type": "max_tier", "tier": "bronze"}]'::jsonb,
   '[{"type": "coins", "amount": 750}]'::jsonb,
   null,   -- sinirsiz tekrar
   1),

  -- ---- 2) GUMUS YUKSELTME ----
  ('gumus-yukseltme', 'Gumus Yukseltme',
   '11 gumus kart ver, karsiliginda paket kazan. Biraz kimya gerekiyor.',
   'baslangic',
   '[{"type": "exact_tier", "tier": "silver"},
     {"type": "min_chemistry", "value": 12}]'::jsonb,
   '[{"type": "pack", "pack_slug": "standard"}]'::jsonb,
   null,
   2),

  -- ---- 3) ULUSLARARASI KADRO ----
  -- Kimyayi uyruk uzerinden kurmayi ogretir.
  ('uluslararasi-kadro', 'Uluslararasi Kadro',
   'Farkli uyruklardan bir kadro kur. Kimyayi lig uzerinden toplaman gerekecek.',
   'genel',
   '[{"type": "min_tier", "tier": "silver"},
     {"type": "min_distinct_nations", "value": 6},
     {"type": "min_chemistry", "value": 18}]'::jsonb,
   '[{"type": "pack", "pack_slug": "sbc_gold"},
     {"type": "coins", "amount": 500}]'::jsonb,
   null,
   3),

  -- ---- 4) LIG UZMANI ----
  -- Kimyayi lig uzerinden kurmayi ogretir.
  ('lig-uzmani', 'Lig Uzmani',
   'Ayni ligden en az 8 kart topla. Ayni ligdekiler birbirine bag kurar.',
   'genel',
   '[{"type": "min_tier", "tier": "silver"},
     {"type": "min_cards_of_league", "league": "Super Lig", "value": 8},
     {"type": "min_chemistry", "value": 22}]'::jsonb,
   '[{"type": "pack", "pack_slug": "sbc_gold"}]'::jsonb,
   null,
   4),

  -- ---- 5) ALTIN STANDART ----
  -- Zor gorev: yuksek kimya + yuksek guc.
  ('altin-standart', 'Altin Standart',
   'Sadece altin ve ustu kartlar, yuksek kimya ve guc. Ciddi bir yatirim.',
   'ozel',
   '[{"type": "min_tier", "tier": "gold"},
     {"type": "min_avg_power", "value": 78},
     {"type": "min_chemistry", "value": 26}]'::jsonb,
   '[{"type": "pack", "pack_slug": "sbc_premium"},
     {"type": "coins", "amount": 2000}]'::jsonb,
   null,
   5),

  -- ---- 6) MUKEMMEL UYUM ----
  -- Kimya sisteminin ustasi icin.
  ('mukemmel-uyum', 'Mukemmel Uyum',
   'Takim kimyasi en az 30 olsun. Ayni kulup ve ligden kartlari yan yana diz.',
   'ozel',
   '[{"type": "min_chemistry", "value": 30},
     {"type": "min_tier", "tier": "silver"}]'::jsonb,
   '[{"type": "pack", "pack_slug": "sbc_premium"},
     {"type": "coins", "amount": 1500}]'::jsonb,
   null,
   6)

on conflict (slug) do update
set name            = excluded.name,
    description     = excluded.description,
    category        = excluded.category,
    requirements    = excluded.requirements,
    rewards         = excluded.rewards,
    max_completions = excluded.max_completions,
    sort_order      = excluded.sort_order,
    is_active       = true;
