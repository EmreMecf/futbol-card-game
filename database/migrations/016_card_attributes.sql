-- =====================================================================
-- 016 - KART OZELLIKLERI (SUT / HIZ / FIZIK / DEFANS / DRIBLING / HIZLANMA)
-- =====================================================================
-- AMAC: Bir kart artik tek bir sayidan (guc) ibaret degil. Ayni 78 gucte
-- iki kart olabilir ama biri "hizli ama camdan" digeri "yavas ama duvar"
-- olur. Bu, koleksiyona kimlik ve ileride taktik derinligi katar.
--
-- ---------------------------------------------------------------------
-- KRITIK: BU DEGERLER MACI BELIRLEMIYOR
-- ---------------------------------------------------------------------
-- Turlari kazanan hala `power + kimya`. Ozellikler su an TAMAMEN
-- GOSTERIM amaclidir. Sebebi bilincli:
--
--   * Kimya sistemi yeni dengelendi. Ayni anda ikinci bir carpani
--     devreye almak, bir sorun ciktiginda hangisinin bozdugunu
--     anlamayi imkansiz kilardi.
--   * Ozellikleri maca baglamak bir KURAL karari; oyunun nasil
--     oynandigini degistirir (ornegin "forvet forvete karsi oynarken
--     sut degeri sayilsin"). Bu ayri bir adim olarak konusulmali.
--
-- Baglamak istedigimizde degisecek tek yer: _resolve_round() icindeki
-- guc karsilastirmasi.
--
-- ---------------------------------------------------------------------
-- DEGERLER NEDEN ELLE YAZILMADI?
-- ---------------------------------------------------------------------
-- 100 kart x 6 ozellik = 600 sayi. Elle yazilsa:
--   * Yeni kart eklendiginde 6 sayi daha uydurmak gerekirdi,
--   * Bir kartin gucu degistiginde ozellikleri tutarsiz kalirdi,
--   * Kaciniz "kaleci 82 sut" gibi sacma bir satiri fark ederdi?
--
-- Bunun yerine POZISYON PROFILI + kartin kendi kimliginden turetilmis
-- sabit bir sapma kullaniyoruz. Sonuc hem tutarli hem de her kartta
-- farkli. Ayni kart her calistirmada AYNI degerleri alir (hashtext
-- deterministiktir), yani veritabanini sifirlamak kartlari degistirmez.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0) KOLONLARI GARANTIYE AL
-- ---------------------------------------------------------------------
-- Kolonlar 003'te tablo tanimina yazildi; SIFIR'dan kurulan bir
-- veritabaninda oradan gelirler.
--
-- Ama 003 `create table if not exists` kullaniyor: MEVCUT bir
-- veritabaninda tablo zaten var oldugu icin o dosya hicbir sey yapmaz
-- ve kolonlar eksik kalirdi. Asagidaki alter, calisan bir kurulumu
-- SIFIRLAMADAN guncellemeyi mumkun kiliyor.
--
-- Iki tarafi da idempotent: her iki durumda da tekrar tekrar
-- calistirilabilir.
alter table cards
  add column if not exists shooting     int check (shooting     between 1 and 99),
  add column if not exists pace         int check (pace         between 1 and 99),
  add column if not exists physical     int check (physical     between 1 and 99),
  add column if not exists defending    int check (defending    between 1 and 99),
  add column if not exists dribbling    int check (dribbling    between 1 and 99),
  add column if not exists acceleration int check (acceleration between 1 and 99);

-- ---------------------------------------------------------------------
-- 1) KARTA OZEL SABIT SAPMA
-- ---------------------------------------------------------------------
-- Butun kartlar profilin tam ortasinda olsaydi ayni gucteki iki forvet
-- birebir ayni olurdu. -4..+4 arasi bir sapma her karta kendi
-- karakterini veriyor.
--
-- random() KULLANILMIYOR: rastgele olsaydi veritabanini her
-- sifirladiginda oyuncunun kartlari degisirdi. hashtext deterministik
-- oldugu icin "slug + ozellik adi" ayni girdiden hep ayni sayiyi uretir.
--
-- NOT: `% 9` sonucu negatif olabilir (PostgreSQL'de mod isareti
-- bolunenden gelir), bu yuzden +9 ve tekrar %9 ile 0..8 araligina
-- sabitleyip 4 cikariyoruz. abs() kullanmiyoruz cunku hashtext
-- -2147483648 dondurdugunde abs() tasar.
create or replace function _attribute_jitter(p_slug text, p_attribute text)
returns int
language sql
immutable
as $$
  select ((hashtext(p_slug || ':' || p_attribute) % 9) + 9) % 9 - 4;
$$;

-- ---------------------------------------------------------------------
-- 2) TEK BIR OZELLIGIN DEGERI
-- ---------------------------------------------------------------------
-- deger = guc + pozisyon sapmasi + karta ozel sapma, 1..99 arasina kirpik
create or replace function _attribute_value(
  p_slug      text,
  p_attribute text,
  p_power     int,
  p_offset    int
)
returns int
language sql
immutable
as $$
  select greatest(1, least(99,
    p_power + p_offset + _attribute_jitter(p_slug, p_attribute)
  ));
$$;

-- ---------------------------------------------------------------------
-- 3) POZISYON PROFILLERI
-- ---------------------------------------------------------------------
-- Her sayi, kartin GUCUNE gore sapmadir. Ornek: 80 gucunde bir forvetin
-- sutu 80 + 6 = 86 civari, defansi 80 - 24 = 56 civari olur.
--
-- Profiller kabaca gercek futbolu taklit ediyor:
--   Kaleci  : ayakla oynamaz; sut/dribling/hizlanma cok dusuk
--   Defans  : fizik ve defans yuksek, sut dusuk
--   Ortasaha: her sey dengeli, dribling one cikar
--   Forvet  : sut/hiz/hizlanma yuksek, defans cok dusuk
--
-- YAN ETKI - KALECI GORUNUMU: 45 gucundeki bronz kalecinin sutu
-- 45-38 = 7 civarina duser. Bu KASITLI; kalecinin sut atmasi
-- beklenmiyor ve kartta bunun gorunmesi dogru.
create or replace function position_attribute_profile()
returns table (
  pos          card_position,
  shooting     int,
  pace         int,
  physical     int,
  defending    int,
  dribbling    int,
  acceleration int
)
language sql
immutable
as $$
  select * from (values
    --  pozisyon             SUT   HIZ  FIZIK  DEF  DRIB  HIZLANMA
    ('GK'::card_position,    -38,  -20,    1,    2,  -28,   -22),
    ('DEF'::card_position,   -22,   -5,    6,    8,  -12,    -6),
    ('MID'::card_position,    -3,   -2,   -5,   -7,    6,    -2),
    ('FWD'::card_position,     6,    5,   -6,  -24,    5,     6)
  ) as t(pos, shooting, pace, physical, defending, dribbling, acceleration);
$$;

-- ---------------------------------------------------------------------
-- 4) KATALOGU DOLDUR
-- ---------------------------------------------------------------------
-- p_force = false  -> sadece bos olanlari doldurur (yeni kart eklenince
--                     mevcut kartlar degismez)
-- p_force = true   -> hepsini yeniden uretir (profilleri degistirdiysen)
create or replace function fill_card_attributes(p_force boolean default false)
returns int
language plpgsql
as $$
declare
  v_sayi int;
begin
  update cards c set
    shooting     = _attribute_value(c.slug, 'shooting',     c.power, p.shooting),
    pace         = _attribute_value(c.slug, 'pace',         c.power, p.pace),
    physical     = _attribute_value(c.slug, 'physical',     c.power, p.physical),
    defending    = _attribute_value(c.slug, 'defending',    c.power, p.defending),
    dribbling    = _attribute_value(c.slug, 'dribbling',    c.power, p.dribbling),
    acceleration = _attribute_value(c.slug, 'acceleration', c.power, p.acceleration)
  from position_attribute_profile() p
  where p.pos = c.position
    and (p_force or c.shooting is null);

  get diagnostics v_sayi = row_count;
  return v_sayi;
end;
$$;

comment on function fill_card_attributes(boolean) is
  'Kart ozelliklerini pozisyon profilinden uretir. Yeni kart ekledikten sonra cagir.';

-- Katalogdaki 100 karti doldur
select fill_card_attributes();

-- ---------------------------------------------------------------------
-- 5) DENETIM GORUNUMU
-- ---------------------------------------------------------------------
-- Profilleri degistirdikten sonra "kaleciler gercekten defansif mi
-- gorunuyor?" diye tek sorguyla bakabilmek icin.
create or replace view card_attributes_summary as
  select position,
         tier,
         count(*)                    as kart_sayisi,
         round(avg(power))           as ort_guc,
         round(avg(shooting))        as ort_sut,
         round(avg(pace))            as ort_hiz,
         round(avg(physical))        as ort_fizik,
         round(avg(defending))       as ort_defans,
         round(avg(dribbling))       as ort_dribling,
         round(avg(acceleration))    as ort_hizlanma
  from cards
  where is_active
  group by position, tier
  order by position, tier_rank(tier);

comment on view card_attributes_summary is
  'Ozellik dengesini gozle kontrol etmek icin: select * from card_attributes_summary;';
