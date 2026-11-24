-- =====================================================================
-- 055 - KIMYA SISTEMI KALDIRILDI
-- =====================================================================
-- Kimya artik oyunun hicbir yerine etki etmez:
--   * Kart masaya yalniz kendi gucuyle cikar (yeni maclarda kimya 0).
--   * Kadro gucu (eslestirme) kimyasiz hesaplanir.
--   * Kart Takasi (SBC) gorevlerinde "en az takim kimyasi" sarti yok.
--
-- NASIL: Butun kimya hesaplari tek bir fonksiyondan, iki kart arasindaki
-- bag puanindan (chemistry_link_score) turetiliyor: deste kimyasi, kadro
-- ozeti, SBC kimyasi, deck_power. Bu fonksiyon artik her zaman 0 doner;
-- boylece kimya hicbir yolla geri sizamaz. Kolonlar ve fonksiyon adlari
-- yerinde kalir (eski uygulama surumleri ve gecmis mac kayitlari bozulmaz).
--
-- DEVAM EDEN MACLAR: kimya mac BASINDA dondurulup match_hands'e yazilir.
-- Bu migration sirasinda suren maclar kendi dondurulmus degerleriyle
-- biter; kurallar mac ortasinda degismez. Yeni maclar kimyasiz baslar.
--
-- KULLANICI VERISI DEGISMEZ: kart, kadro, mac, altin, sandik kayitlarina
-- dokunulmaz. Yalniz oyun kurali (fonksiyon) ve SBC gorev tanimlari degisir.
-- Tekrar calistirilabilir.
-- =====================================================================

create or replace function chemistry_link_score(
  p_a_nation text, p_a_league text, p_a_club text,
  p_b_nation text, p_b_league text, p_b_club text
)
returns int
language sql
immutable
as $$
  -- 055: kimya kaldirildi; hicbir bag puan vermez
  select 0;
$$;

comment on function chemistry_link_score(text, text, text, text, text, text) is
  '055: kimya sistemi kaldirildi, her zaman 0 doner. Kart gucu yalniz power (+ kural surumune bagli bonuslar).';

-- ---------------------------------------------------------------------
-- SBC: "en az takim kimyasi" sartlarini kaldir
-- ---------------------------------------------------------------------
update sbc_challenges
set requirements = coalesce((
      select jsonb_agg(r order by o)
      from jsonb_array_elements(requirements) with ordinality as t(r, o)
      where r->>'type' <> 'min_chemistry'
    ), '[]'::jsonb)
where requirements @> '[{"type": "min_chemistry"}]'::jsonb;

-- Aciklamalardaki kimya anlatimlari
update sbc_challenges set description = 'Elinde biriken bronz kartlari degerlendirme zamani.'
where slug = 'bronz-temizligi';
update sbc_challenges set description = '11 gumus kart ver, karsiliginda paket kazan.'
where slug = 'gumus-yukseltme';
update sbc_challenges set description = 'Farkli uyruklardan en az 6 oyunculu bir kadro kur.'
where slug = 'uluslararasi-kadro';
update sbc_challenges set description = 'Ayni ligden en az 8 kart topla.'
where slug = 'lig-uzmani';
update sbc_challenges set description = 'Sadece altin ve ustu kartlar, yuksek guc. Ciddi bir yatirim.'
where slug = 'altin-standart';

-- "Mukemmel Uyum" tamamen kimya uzerine kurulu bir gorevdi; kimya sarti
-- gidince "en az gumus" kalir ve premium paket bedavaya doner. Kapatilir.
update sbc_challenges set is_active = false where slug = 'mukemmel-uyum';

-- Guvenlik: kimya sarti kalan aktif gorev olmamali
do $$
begin
  if exists (select 1 from sbc_challenges
             where requirements @> '[{"type": "min_chemistry"}]'::jsonb) then
    raise exception '055 ABORT: kimya sarti iceren SBC gorevi kaldi';
  end if;
end $$;
