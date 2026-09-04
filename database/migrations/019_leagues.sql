-- =====================================================================
-- 019 - LIG SISTEMI VE LIDERLIK TABLOSU
-- =====================================================================
-- AMAC: Oyuncunun puani (mmr) simdiye kadar sadece bir sayiydi. 1240
-- puanin iyi mi kotu mu oldugunu anlamanin yolu yoktu ve bir maci
-- kazanmak "sayi biraz artti"dan ibaretti.
--
-- LIG, o sayiya ANLAM veriyor: oyuncu "Usta 2"deyim der, bir sonraki
-- hedefi bilir ve dusme riskini hisseder.
--
-- YAPI: 4 lig x 3 seviye = 12 basamak.
--   Amatör 1 -> Amatör 2 -> Amatör 3 -> Usta 1 -> ... -> Master Class 3
--
-- =====================================================================
-- NEDEN TABLO, NEDEN KODA GOMULU DEGIL?
-- =====================================================================
-- Lig adlari ve esikleri DENGE AYARIDIR. Oyun yayina cikip oyuncular
-- birikince "Master Class'a cok kolay cikiliyor" denebilir. Bu bir
-- tablo satiri guncellemesiyle cozulmeli, uygulama yeniden
-- yayinlanarak degil.
--
-- Ayni sebeple ad degistirmek de tek satir: Master Class ismi
-- begenilmezse update yeter, kod hic degismez.
-- =====================================================================

create table if not exists league_tiers (
  -- 1'den 12'ye siralama. Buyuk olan daha yuksek basamak.
  id            smallint primary key check (id between 1 and 99),

  -- Lig kimligi: ayni ligin uc seviyesi ayni kodu paylasir
  league_code   text     not null,
  league_name   text     not null,

  -- Lig icindeki seviye: 1 en alt, 3 en ust
  division      smallint not null check (division between 1 and 9),

  -- Bu basamaga girmek icin gereken en dusuk puan.
  -- Ust sinir bir sonraki basamagin min_mmr'idir; ayrica tutulmuyor
  -- ki iki yerde tutulup birbirine uymayan deger olusmasin.
  min_mmr       int      not null,

  -- Arayuz rengi (kart seviyeleriyle KARISMAYACAK tonlar secildi)
  color         text     not null,

  created_at    timestamptz not null default now(),

  unique (league_code, division)
);

comment on table league_tiers is
  'Lig basamaklari. Ad ve esik degisikligi icin SADECE bu tabloyu guncelle.';

comment on column league_tiers.min_mmr is
  'Bu basamagin alt siniri. Ust sinir bir sonraki satirin min_mmr degeridir.';

-- ---------------------------------------------------------------------
-- BASAMAKLAR
-- ---------------------------------------------------------------------
-- ESIKLER NASIL SECILDI?
-- Bir mac +25 / -25 puan. Yani 100 puan = 4 net galibiyet.
-- Baslangic puani 1000, yani herkes Amatör 1'den basliyor.
--
-- Bantlar yukari cikildikca GENISLIYOR: Amatör'de 4 net galibiyet
-- yeterken Master Class 2'ye gecmek 10 net galibiyet istiyor. Boylece
-- ust ligler gercekten seyrek kaliyor.
--
-- AMATÖR 1'IN TABANI NEDEN 0 DEGIL 1000?
-- Baslangic puani 1000. Taban 0 olsaydi yeni bir oyuncu daha ilk
-- macini oynamadan ilerleme cubugunu %91 DOLU gorurdu; sanki neredeyse
-- yukselecekmis gibi. Taban baslangic puanina esitlenince yeni oyuncu
-- cubugu bos goruyor.
--
-- Puani 1000'in ALTINA dusen oyuncu yine Amatör 1'de kaliyor
-- (rank_for_mmr en alt basamaga geri donuyor) ve ilerlemesi %0
-- gorunuyor. Ligden dusme diye bir sey yok; en alt basamak zemin.
--
-- RENKLER: Kart seviyeleri bronz/gumus/altin/mavi/mor kullaniyor.
-- Ligler o paletten UZAK duruyor; yoksa "Altin lig" ile "Altin kart"
-- birbirine karisirdi.
insert into league_tiers (id, league_code, league_name, division, min_mmr, color)
values
  ( 1, 'amateur',      'Amatör',       1, 1000, '#7C8DA6'),
  ( 2, 'amateur',      'Amatör',       2, 1100, '#7C8DA6'),
  ( 3, 'amateur',      'Amatör',       3, 1200, '#7C8DA6'),

  ( 4, 'usta',         'Usta',         1, 1300, '#2DD4BF'),
  ( 5, 'usta',         'Usta',         2, 1400, '#2DD4BF'),
  ( 6, 'usta',         'Usta',         3, 1500, '#2DD4BF'),

  ( 7, 'master',       'Master',       1, 1625, '#F97316'),
  ( 8, 'master',       'Master',       2, 1750, '#F97316'),
  ( 9, 'master',       'Master',       3, 1875, '#F97316'),

  (10, 'master_class', 'Master Class', 1, 2025, '#F43F5E'),
  (11, 'master_class', 'Master Class', 2, 2225, '#F43F5E'),
  (12, 'master_class', 'Master Class', 3, 2475, '#F43F5E')
on conflict (id) do update set
  league_code = excluded.league_code,
  league_name = excluded.league_name,
  division    = excluded.division,
  min_mmr     = excluded.min_mmr,
  color       = excluded.color;

-- =====================================================================
-- BIR PUANIN HANGI BASAMAGA DUSTUGU
-- =====================================================================
-- En yuksek min_mmr'i puani gecmeyen satir.
--
-- En alt basamagin tabani 1000 (baslangic puani). Puani bunun altina
-- dusen oyuncu icin hicbir satir eslesmez; o durumda EN ALT basamak
-- donuyor. Yani ligden dusup listeden cikmak diye bir sey yok.
create or replace function rank_for_mmr(p_mmr int)
returns league_tiers
language sql
stable
as $$
  -- Puani gecmeyen en yuksek basamak; hicbiri eslesmezse (oyuncu
  -- baslangic puaninin altina dustuyse) EN ALT basamak.
  select coalesce(
    (
      select t
      from league_tiers t
      where t.min_mmr <= greatest(p_mmr, 0)
      order by t.min_mmr desc
      limit 1
    ),
    (select t from league_tiers t order by t.id asc limit 1)
  );
$$;

comment on function rank_for_mmr is
  'Verilen puanin hangi lig basamagina denk geldigini doner.';

-- =====================================================================
-- OYUNCUNUN LIG DURUMU
-- =====================================================================
-- Arayuz icin tek cagrida her sey: hangi basamak, bir sonraki basamak
-- ne, aradaki ilerleme yuzde kac.
--
-- ILERLEME NEDEN SUNUCUDA HESAPLANIYOR?
-- Esikler burada duruyor. Istemcinin ayni hesabi yapabilmesi icin
-- esik tablosunu da tasimasi gerekirdi; o zaman esik degistiginde
-- eski surumdeki oyuncular yanlis ilerleme gorurdu.
create or replace function get_player_rank(p_user_id uuid)
returns jsonb
language plpgsql
stable
as $$
declare
  v_mmr      int;
  v_tier     league_tiers;
  v_next     league_tiers;
  v_taban    int;
  v_tavan    int;
  v_ilerleme numeric;
begin
  select mmr into v_mmr from users where id = p_user_id;
  if v_mmr is null then
    raise exception 'Oyuncu bulunamadi.' using errcode = 'P0001';
  end if;

  select * into v_tier from rank_for_mmr(v_mmr);

  -- Bir ustteki basamak (varsa)
  select * into v_next
  from league_tiers
  where id > v_tier.id
  order by id asc
  limit 1;

  v_taban := v_tier.min_mmr;

  if v_next.id is null then
    -- En ust basamakta ilerme cubugu dolu gosteriliyor; ustunde
    -- gidilecek yer yok.
    v_ilerleme := 1.0;
    v_tavan := null;
  else
    v_tavan := v_next.min_mmr;
    v_ilerleme := least(
      1.0,
      greatest(0.0, (v_mmr - v_taban)::numeric / nullif(v_tavan - v_taban, 0))
    );
  end if;

  return jsonb_build_object(
    'mmr',            v_mmr,
    'tier_id',        v_tier.id,
    'league_code',    v_tier.league_code,
    'league_name',    v_tier.league_name,
    'division',       v_tier.division,
    'color',          v_tier.color,
    'tier_min_mmr',   v_taban,
    'next_tier_mmr',  v_tavan,
    'next_league_name', v_next.league_name,
    'next_division',  v_next.division,
    'progress',       round(v_ilerleme, 4),
    'is_top_tier',    (v_next.id is null)
  );
end;
$$;

comment on function get_player_rank is
  'Oyuncunun lig basamagi ve bir sonraki basamaga ilerlemesi.';

-- =====================================================================
-- LIDERLIK TABLOSU
-- =====================================================================
-- Puana gore siralanmis oyuncular. Siralama SUNUCUDA veriliyor;
-- istemci kendi sirasini hesaplamaya calismiyor.
--
-- Banlanmis hesaplar listede gorunmuyor.
create or replace function get_leaderboard(
  p_limit  int default 50,
  p_offset int default 0
)
returns table (
  -- DIKKAT: 'position' PostgreSQL'de AYRILMIS KELIME (position(x in y)
  -- fonksiyonu). Kolon adi olarak kullanilirsa sozdizimi hatasi verir.
  rank_position bigint,
  user_id      uuid,
  username     text,
  mmr          int,
  wins         int,
  losses       int,
  draws        int,
  league_name  text,
  division     smallint,
  color        text
)
language sql
stable
as $$
  with siralanmis as (
    select
      row_number() over (order by u.mmr desc, u.wins desc, u.created_at asc)
        as sira,
      u.id, u.username, u.mmr, u.wins, u.losses, u.draws
    from users u
    where not u.is_banned
  )
  select
    s.sira,
    s.id,
    s.username,
    s.mmr,
    s.wins,
    s.losses,
    s.draws,
    t.league_name,
    t.division,
    t.color
  from siralanmis s
  cross join lateral rank_for_mmr(s.mmr) t
  order by s.sira
  limit greatest(1, least(p_limit, 200))
  offset greatest(0, p_offset);
$$;

comment on function get_leaderboard is
  'Puana gore siralanmis oyuncular. Sira numarasi sunucuda veriliyor.';

-- ---------------------------------------------------------------------
-- OYUNCUNUN LIDERLIK SIRASI
-- ---------------------------------------------------------------------
-- Oyuncu ilk 50'de degilse bile kendi sirasini gorebilmeli. Tum
-- tabloyu cekip icinde aramak yerine tek sayi donuyor.
create or replace function get_my_leaderboard_position(p_user_id uuid)
returns bigint
language sql
stable
as $$
  select count(*) + 1
  from users u
  join users me on me.id = p_user_id
  where not u.is_banned
    and (
      u.mmr > me.mmr
      or (u.mmr = me.mmr and u.wins > me.wins)
      or (u.mmr = me.mmr and u.wins = me.wins and u.created_at < me.created_at)
    );
$$;

comment on function get_my_leaderboard_position is
  'Oyuncunun liderlik tablosundaki sirasi. Ilk sayfada olmasa da calisir.';

-- Liderlik sorgusu tum tabloyu puana gore tariyor.
-- users(mmr desc) indeksi 002'de zaten var; banlanmislari eleyen
-- kismi indeks siralamayi daha da ucuzlatiyor.
create index if not exists idx_users_leaderboard
  on users (mmr desc, wins desc, created_at asc)
  where not is_banned;
