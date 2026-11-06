-- =====================================================================
-- 022: MAC SONRASI LIG DEGISIMI (FAZ 6 - lig ilerlemesi)
-- =====================================================================
-- AMAC: Mac sonu ekraninda "puanin 1290'dan 1315'e cikti, Amator 3'ten
-- Usta 1'e YUKSELDIN" diyebilmek.
--
-- NEDEN SUNUCUDA KAYDEDILIYOR?
-- Mac oncesi puani istemcinin oturumundan cikarmak guvenilir degil:
-- oturum bayat olabilir (baska cihazda oynanmis mac, uygulama yeniden
-- acilmis). Yanlis bir "lig atladin" ekrani, hic ekran olmamasindan
-- kotudur. Bu yuzden puan iki noktada SUNUCUDA kaydediliyor:
--
--   * Mac kurulurken (match_players satiri eklenirken): mmr_before
--   * Mac bittiginde (matches.status 'finished' olurken): mmr_after
--
-- NEDEN TETIKLEYICI, NEDEN _finish_match DEGISMIYOR?
-- _finish_match maçın en kritik fonksiyonu (ceza, kart devri, oduller).
-- Onu kopyalayip yeniden yazmak, sadece iki sayi kaydetmek icin gereksiz
-- risk. Puan SADECE _finish_match icinde degisiyor ve oyuncu ayni anda
-- tek macta olabiliyor; bu yuzden mac basindaki puan, bitisten hemen
-- onceki puanla aynidir. _finish_match puanlari guncelledikten SONRA
-- maci 'finished' yapiyor; tetikleyici o anki puani okuyor.
--
-- Bu migration'dan ONCE baslamis maclarda mmr_before bos kalir; o
-- maclar icin lig degisimi gosterilmez (uydurulmaz).
-- =====================================================================

alter table match_players add column if not exists mmr_before int;
alter table match_players add column if not exists mmr_after  int;

-- ---------------------------------------------------------------------
-- 1) MAC BASI: puani kaydet
-- ---------------------------------------------------------------------
create or replace function _snapshot_mmr_before()
returns trigger
language plpgsql
as $$
begin
  if new.mmr_before is null then
    select mmr into new.mmr_before from users where id = new.user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_match_players_mmr_before on match_players;
create trigger trg_match_players_mmr_before
  before insert on match_players
  for each row execute function _snapshot_mmr_before();

-- ---------------------------------------------------------------------
-- 2) MAC SONU: yeni puani kaydet
-- ---------------------------------------------------------------------
create or replace function _snapshot_mmr_after()
returns trigger
language plpgsql
as $$
begin
  update match_players mp
  set mmr_after = u.mmr
  from users u
  where mp.match_id = new.id
    and u.id = mp.user_id;
  return null;
end;
$$;

drop trigger if exists trg_matches_mmr_after on matches;
create trigger trg_matches_mmr_after
  after update of status on matches
  for each row
  when (new.status = 'finished' and old.status is distinct from 'finished')
  execute function _snapshot_mmr_after();

-- ---------------------------------------------------------------------
-- 3) HERHANGI BIR PUANIN LIG BILGISI
-- ---------------------------------------------------------------------
-- get_player_rank'in govdesi buraya tasindi: ayni hesap hem "su anki
-- ligim" hem "mac oncesi ligim" icin kullaniliyor. Iki kopya olsaydi
-- biri degisip digeri unutulabilirdi.
create or replace function rank_json_for_mmr(p_mmr int)
returns jsonb
language plpgsql
stable
as $$
declare
  v_tier     league_tiers;
  v_next     league_tiers;
  v_taban    int;
  v_tavan    int;
  v_ilerleme numeric;
begin
  select * into v_tier from rank_for_mmr(p_mmr);

  select * into v_next
  from league_tiers
  where id > v_tier.id
  order by id asc
  limit 1;

  v_taban := v_tier.min_mmr;

  if v_next.id is null then
    v_ilerleme := 1.0;
    v_tavan := null;
  else
    v_tavan := v_next.min_mmr;
    v_ilerleme := least(
      1.0,
      greatest(0.0, (p_mmr - v_taban)::numeric / nullif(v_tavan - v_taban, 0))
    );
  end if;

  return jsonb_build_object(
    'mmr',              p_mmr,
    'tier_id',          v_tier.id,
    'league_code',      v_tier.league_code,
    'league_name',      v_tier.league_name,
    'division',         v_tier.division,
    'color',            v_tier.color,
    'tier_min_mmr',     v_taban,
    'next_tier_mmr',    v_tavan,
    'next_league_name', v_next.league_name,
    'next_division',    v_next.division,
    'progress',         round(v_ilerleme, 4),
    'is_top_tier',      (v_next.id is null)
  );
end;
$$;

-- Davranis AYNI, sadece hesap ortak fonksiyona tasindi
create or replace function get_player_rank(p_user_id uuid)
returns jsonb
language plpgsql
stable
as $$
declare
  v_mmr int;
begin
  select mmr into v_mmr from users where id = p_user_id;
  if v_mmr is null then
    raise exception 'Oyuncu bulunamadi.' using errcode = 'P0001';
  end if;
  return rank_json_for_mmr(v_mmr);
end;
$$;

-- ---------------------------------------------------------------------
-- 4) BIR MACIN LIG ETKISI
-- ---------------------------------------------------------------------
-- Doner: null (mac bitmemis ya da kayit yok) veya
--   { mmr_before, mmr_after, mmr_delta,
--     rank_before, rank_after,
--     direction: 'promoted' | 'demoted' | 'same' }
create or replace function get_match_league_change(p_user_id uuid, p_match_id uuid)
returns jsonb
language plpgsql
stable
as $$
declare
  mp       match_players%rowtype;
  v_status match_status;
  v_once   jsonb;
  v_sonra  jsonb;
begin
  select status into v_status from matches where id = p_match_id;
  if v_status is null then
    raise exception 'Mac bulunamadi.';
  end if;

  select * into mp
  from match_players
  where match_id = p_match_id and user_id = p_user_id;

  if not found then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  if v_status <> 'finished' or mp.mmr_before is null or mp.mmr_after is null then
    return null;
  end if;

  v_once  := rank_json_for_mmr(mp.mmr_before);
  v_sonra := rank_json_for_mmr(mp.mmr_after);

  return jsonb_build_object(
    'mmr_before',  mp.mmr_before,
    'mmr_after',   mp.mmr_after,
    'mmr_delta',   mp.mmr_after - mp.mmr_before,
    'rank_before', v_once,
    'rank_after',  v_sonra,
    'direction',   case
                     when (v_sonra->>'tier_id')::int > (v_once->>'tier_id')::int then 'promoted'
                     when (v_sonra->>'tier_id')::int < (v_once->>'tier_id')::int then 'demoted'
                     else 'same'
                   end
  );
end;
$$;
