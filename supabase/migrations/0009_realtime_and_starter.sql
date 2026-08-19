-- =====================================================================
-- 0009 — REALTIME YAYINI, BAŞLANGIÇ PAKETİ VE ÖRNEK KART VERİSİ
-- =====================================================================

-- ---------------------------------------------------------------------
-- REALTIME
-- ---------------------------------------------------------------------
-- Flutter tarafı bu tabloları dinleyecek. RLS kuralları Realtime için de
-- geçerlidir; yani oyuncu sadece görme yetkisi olan satırların
-- değişikliklerini alır. (match_hands yayına EKLENMEZ!)
do $$
begin
  -- Eşleşme bekleyen oyuncu kendi kuyruk satırını dinler
  alter publication supabase_realtime add table public.matchmaking_queue;
exception when duplicate_object then null; end $$;

do $$
begin
  -- Sıra değişimi, skor, tur numarası
  alter publication supabase_realtime add table public.matches;
exception when duplicate_object then null; end $$;

do $$
begin
  -- Rakibin oynadığı kartın masaya düşme animasyonu
  alter publication supabase_realtime add table public.match_moves;
exception when duplicate_object then null; end $$;

do $$
begin
  -- Tur sonucu (kim kazandı, hangi kartlar toplandı)
  alter publication supabase_realtime add table public.match_rounds;
exception when duplicate_object then null; end $$;

-- UPDATE olaylarında eski değerlerin de gelmesi için (opsiyonel ama faydalı)
alter table public.matches replica identity full;

-- ---------------------------------------------------------------------
-- BAŞLANGIÇ PAKETİ
-- ---------------------------------------------------------------------
-- Yeni oyuncu ilk girişte çağırır. 17 kart verir ve geçerli bir
-- 4-4-2 kadro (1 GK, 4 DEF, 4 MID, 2 FWD) otomatik oluşturur.
create or replace function public.grant_starter_pack()
returns json
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_deck_id uuid;
  v_total   int;
begin
  if v_uid is null then
    raise exception 'Oturum bulunamadi.';
  end if;

  -- Sadece bir kez verilir
  if exists (select 1 from public.user_cards where owner_id = v_uid) then
    raise exception 'Baslangic paketi zaten alinmis.';
  end if;

  -- Pozisyon başına rastgele bronz/gümüş kart dağıt
  insert into public.user_cards (owner_id, card_id)
  select v_uid, x.id from (
    (select id from public.cards where position = 'GK'  and tier in ('bronze','silver') and is_active order by random() limit 2)
    union all
    (select id from public.cards where position = 'DEF' and tier in ('bronze','silver') and is_active order by random() limit 6)
    union all
    (select id from public.cards where position = 'MID' and tier in ('bronze','silver') and is_active order by random() limit 6)
    union all
    (select id from public.cards where position = 'FWD' and tier in ('bronze','silver') and is_active order by random() limit 3)
  ) x;

  select count(*) into v_total from public.user_cards where owner_id = v_uid;

  -- Varsayılan aktif deste
  insert into public.decks (owner_id, name, is_active)
  values (v_uid, 'Ilk Kadrom', true)
  returning id into v_deck_id;

  -- Geçerli formasyonu otomatik kur: 1 GK + 4 DEF + 4 MID + 2 FWD
  insert into public.deck_cards (deck_id, user_card_id)
  select v_deck_id, y.id from (
    (select uc.id from public.user_cards uc join public.cards c on c.id = uc.card_id
      where uc.owner_id = v_uid and c.position = 'GK'  order by c.power desc limit 1)
    union all
    (select uc.id from public.user_cards uc join public.cards c on c.id = uc.card_id
      where uc.owner_id = v_uid and c.position = 'DEF' order by c.power desc limit 4)
    union all
    (select uc.id from public.user_cards uc join public.cards c on c.id = uc.card_id
      where uc.owner_id = v_uid and c.position = 'MID' order by c.power desc limit 4)
    union all
    (select uc.id from public.user_cards uc join public.cards c on c.id = uc.card_id
      where uc.owner_id = v_uid and c.position = 'FWD' order by c.power desc limit 2)
  ) y;

  return json_build_object('status', 'ok', 'card_count', v_total, 'deck_id', v_deck_id);
end;
$$;

grant execute on function public.grant_starter_pack() to authenticated;

-- ---------------------------------------------------------------------
-- ÖRNEK KART VERİSİ (PLACEHOLDER)
-- ---------------------------------------------------------------------
-- NOT: Buradaki isimler sadece sistemi test edebilmen için örnektir.
-- Yayına çıkarken lisans/telif açısından kendi kurgusal isimlerini veya
-- lisansladığın isimleri kullanmalısın. image_url alanları Supabase
-- Storage'daki 3D Pixar tarzi gorsellere isaret edecek.

insert into public.cards (slug, full_name, position, tier, power, nationality, club, image_url) values
  -- Kaleciler
  ('kaleci-bronz-1',  'Emre Kaya',        'GK',  'bronze',  52, 'TUR', 'Anadolu SK',  'cards/gk_bronze_1.png'),
  ('kaleci-bronz-2',  'Marco Bellini',    'GK',  'bronze',  55, 'ITA', 'Verona FC',   'cards/gk_bronze_2.png'),
  ('kaleci-gumus-1',  'Lukas Vogel',      'GK',  'silver',  68, 'GER', 'Rhein FC',    'cards/gk_silver_1.png'),
  ('kaleci-altin-1',  'Diego Salas',      'GK',  'gold',    81, 'ARG', 'Rio Plate',   'cards/gk_gold_1.png'),
  ('kaleci-legend-1', 'Lev Yashin',       'GK',  'legend',  95, 'RUS', 'Efsaneler',   'cards/gk_legend_1.png'),

  -- Defanslar
  ('defans-bronz-1',  'Ali Demir',        'DEF', 'bronze',  50, 'TUR', 'Anadolu SK',  'cards/def_bronze_1.png'),
  ('defans-bronz-2',  'Tom Baker',        'DEF', 'bronze',  53, 'ENG', 'Dover United','cards/def_bronze_2.png'),
  ('defans-bronz-3',  'Pierre Dubois',    'DEF', 'bronze',  56, 'FRA', 'Lyon Nord',   'cards/def_bronze_3.png'),
  ('defans-bronz-4',  'Ivan Petrov',      'DEF', 'bronze',  54, 'BUL', 'Sofia FC',    'cards/def_bronze_4.png'),
  ('defans-gumus-1',  'Rafael Costa',     'DEF', 'silver',  66, 'BRA', 'Sao Verde',   'cards/def_silver_1.png'),
  ('defans-gumus-2',  'Jonas Berg',       'DEF', 'silver',  69, 'SWE', 'Nord IF',     'cards/def_silver_2.png'),
  ('defans-gumus-3',  'Hakan Yildiz',     'DEF', 'silver',  64, 'TUR', 'Bosphorus',   'cards/def_silver_3.png'),
  ('defans-altin-1',  'Sergio Marin',     'DEF', 'gold',    82, 'ESP', 'Madrid Real', 'cards/def_gold_1.png'),
  ('defans-diamond-1','Vincent Leclerc',  'DEF', 'diamond', 89, 'FRA', 'Paris Nord',  'cards/def_diamond_1.png'),
  ('defans-legend-1', 'Franco Baresi',    'DEF', 'legend',  93, 'ITA', 'Efsaneler',   'cards/def_legend_1.png'),

  -- Orta sahalar
  ('orta-bronz-1',    'Kemal Aslan',      'MID', 'bronze',  51, 'TUR', 'Anadolu SK',  'cards/mid_bronze_1.png'),
  ('orta-bronz-2',    'Sean Murphy',      'MID', 'bronze',  55, 'IRL', 'Dublin City', 'cards/mid_bronze_2.png'),
  ('orta-bronz-3',    'Karl Fischer',     'MID', 'bronze',  57, 'GER', 'Rhein FC',    'cards/mid_bronze_3.png'),
  ('orta-bronz-4',    'Luis Ortega',      'MID', 'bronze',  53, 'MEX', 'Azteca',      'cards/mid_bronze_4.png'),
  ('orta-gumus-1',    'Andrea Rossi',     'MID', 'silver',  67, 'ITA', 'Verona FC',   'cards/mid_silver_1.png'),
  ('orta-gumus-2',    'Yuki Tanaka',      'MID', 'silver',  70, 'JPN', 'Tokyo Blue',  'cards/mid_silver_2.png'),
  ('orta-gumus-3',    'Nico Jansen',      'MID', 'silver',  65, 'NED', 'Amsterdam A', 'cards/mid_silver_3.png'),
  ('orta-altin-1',    'Bruno Alves',      'MID', 'gold',    83, 'POR', 'Lisboa FC',   'cards/mid_gold_1.png'),
  ('orta-diamond-1',  'Kevin Sorensen',   'MID', 'diamond', 90, 'DEN', 'Copenhagen',  'cards/mid_diamond_1.png'),
  ('orta-legend-1',   'Diego Maradona',   'MID', 'legend',  97, 'ARG', 'Efsaneler',   'cards/mid_legend_1.png'),
  ('orta-legend-2',   'Johan Cruyff',     'MID', 'legend',  96, 'NED', 'Efsaneler',   'cards/mid_legend_2.png'),

  -- Forvetler
  ('forvet-bronz-1',  'Burak Sahin',      'FWD', 'bronze',  54, 'TUR', 'Anadolu SK',  'cards/fwd_bronze_1.png'),
  ('forvet-bronz-2',  'Owen Clarke',      'FWD', 'bronze',  56, 'ENG', 'Dover United','cards/fwd_bronze_2.png'),
  ('forvet-bronz-3',  'Matteo Greco',     'FWD', 'bronze',  58, 'ITA', 'Verona FC',   'cards/fwd_bronze_3.png'),
  ('forvet-gumus-1',  'Adama Traore',     'FWD', 'silver',  71, 'MLI', 'Bamako SC',   'cards/fwd_silver_1.png'),
  ('forvet-gumus-2',  'Rodrigo Pinto',    'FWD', 'silver',  68, 'BRA', 'Sao Verde',   'cards/fwd_silver_2.png'),
  ('forvet-altin-1',  'Erik Lindqvist',   'FWD', 'gold',    84, 'NOR', 'Oslo FK',     'cards/fwd_gold_1.png'),
  ('forvet-diamond-1','Julian Weber',     'FWD', 'diamond', 91, 'GER', 'Munchen SV',  'cards/fwd_diamond_1.png'),
  ('forvet-legend-1', 'Pele',             'FWD', 'legend',  98, 'BRA', 'Efsaneler',   'cards/fwd_legend_1.png'),
  ('forvet-legend-2', 'Ferenc Puskas',    'FWD', 'legend',  94, 'HUN', 'Efsaneler',   'cards/fwd_legend_2.png')
on conflict (slug) do nothing;
