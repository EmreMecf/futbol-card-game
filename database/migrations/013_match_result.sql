-- =====================================================================
-- 013 - MAC SONUCU OZETI
-- =====================================================================
-- Mac bittikten sonra oyuncuya gosterilecek ozet.
--
-- NEDEN AYRI BIR FONKSIYON?
-- get_match_state() mac SURERKEN gereken bilgiyi doner (sira kimde,
-- kac kart kaldi...). Mac bitince ise bambaska bir sey merak edilir:
-- "Hangi kartlarimi kaybettim?"
--
-- Yuksek Risk Modu bu oyunun kalbi. Oyuncu 3 kartini kalici olarak
-- kaptirdiginda HANGI kartlari kaybettigini gormeli; yoksa envanterine
-- girip tek tek aramak zorunda kalir.
-- =====================================================================

create or replace function get_match_result(p_user_id uuid, p_match_id uuid)
returns json
language plpgsql
stable
as $$
declare
  m       matches%rowtype;
  v_opp   uuid;
  v_kazandim boolean;
begin
  select * into m from matches where id = p_match_id;

  if not found or p_user_id not in (m.player1_id, m.player2_id) then
    raise exception 'Bu macin oyuncusu degilsiniz.';
  end if;

  if m.status <> 'finished' then
    raise exception 'Bu mac henuz bitmedi.';
  end if;

  v_opp := _opponent_of(m, p_user_id);
  v_kazandim := (m.winner_id = p_user_id);

  return json_build_object(
    'match_id',       m.id,
    'is_draw',        m.is_draw,
    'did_i_win',      v_kazandim,
    'my_score',       case when m.player1_id = p_user_id
                           then m.p1_captured_count else m.p2_captured_count end,
    'opponent_score', case when m.player1_id = p_user_id
                           then m.p2_captured_count else m.p1_captured_count end,
    'total_rounds',   m.round_number - 1,
    'finished_at',    m.finished_at,

    'opponent', (
      select json_build_object('id', u.id, 'username', u.username,
                               'avatar_url', u.avatar_url, 'mmr', u.mmr)
      from users u where u.id = v_opp
    ),

    -- ---- KAYBEDILEN KARTLAR (bu macta benden gidenler) ----
    'cards_lost', (
      select coalesce(json_agg(
        json_build_object(
          'user_card_id', ct.user_card_id,
          'card_id',      c.id,
          'full_name',    c.full_name,
          'position',     c.position,
          'tier',         c.tier,
          'power',        c.power,
          'image_url',    c.image_url,
          'nationality',  c.nationality,
          'league',       c.league,
          'club',         c.club,
          'attributes',   card_attributes_json(
            c.shooting, c.pace, c.physical,
            c.defending, c.dribbling, c.acceleration
          )
        ) order by tier_rank(c.tier) desc, c.power desc
      ), '[]'::json)
      from card_transfers ct
      join cards c on c.id = ct.card_id
      where ct.match_id = p_match_id and ct.from_user_id = p_user_id
    ),

    -- ---- KAZANILAN KARTLAR (bu macta bana gelenler) ----
    'cards_won', (
      select coalesce(json_agg(
        json_build_object(
          'user_card_id', ct.user_card_id,
          'card_id',      c.id,
          'full_name',    c.full_name,
          'position',     c.position,
          'tier',         c.tier,
          'power',        c.power,
          'image_url',    c.image_url,
          'nationality',  c.nationality,
          'league',       c.league,
          'club',         c.club,
          'attributes',   card_attributes_json(
            c.shooting, c.pace, c.physical,
            c.defending, c.dribbling, c.acceleration
          )
        ) order by tier_rank(c.tier) desc, c.power desc
      ), '[]'::json)
      from card_transfers ct
      join cards c on c.id = ct.card_id
      where ct.match_id = p_match_id and ct.to_user_id = p_user_id
    ),

    -- ---- GUNCEL PROFIL (coin/MMR/koruma hakki degisti) ----
    'my_profile', (
      select json_build_object(
        'id', u.id, 'username', u.username, 'email', u.email,
        'avatar_url', u.avatar_url, 'coins', u.coins,
        'protection_slots', u.protection_slots, 'mmr', u.mmr,
        'wins', u.wins, 'losses', u.losses, 'draws', u.draws
      )
      from users u where u.id = p_user_id
    )
  );
end;
$$;

comment on function get_match_result(uuid, uuid) is
  'Bitmis macin ozeti: skor, rakip, kaybedilen/kazanilan kartlar ve guncel profil.';
