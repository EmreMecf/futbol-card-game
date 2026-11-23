-- =====================================================================
-- 051: TUR SONUCU GOSTERILIRKEN MEVKI SURESI AKMASIN
-- =====================================================================
-- Sorun (canli test): tur cozulur cozulmez mevki asamasi basliyor ve
-- surum 4/5'te yalniz 5 sn suruyordu. Istemci once tur sonucu sahnesini
-- gosteriyor (~2,3 sn, ag gecikmesiyle daha fazla). Sahne bitince
-- oyuncuya ~1-2 sn kaliyor, cogu zaman sunucu mevkiyi oyuncu adina
-- seciyordu. Inisiyatif kazanmanin anlami kalmiyordu.
--
-- Cozum: mevki son anina tur sonucu sahnesi kadar pay eklenir. Kural
-- surumlerindeki position_seconds degismez; oyuncu sahneden sonra yine
-- position_seconds kadar sure gorur. Otomatik mevki secimi hareketsizlik
-- sayilmadigi icin hukmen kurali etkilenmez.
-- =====================================================================

-- Istemcinin tur sonucu sahnesi icin pay (saniye)
create or replace function clash_scene_seconds() returns int
language sql immutable as $$ select 3 $$;

create or replace function _after_round_simultaneous(p_match_id uuid)
returns void
language plpgsql
as $$
declare
  m      matches%rowtype;
  g      game_rule_versions%rowtype;
begin
  select * into m from matches where id = p_match_id for update;
  if m.status <> 'active' then
    return;   -- eller bitti, _resolve_round maci kapatti
  end if;
  select * into g from game_rule_versions where version = m.rules_version;
  if g.early_finish_cards is not null
     and greatest(m.p1_captured_count, m.p2_captured_count) >= g.early_finish_cards then
    perform _finish_match(p_match_id);
    return;
  end if;
  -- Inisiyatif sahibinin eli bittiyse (esit dizilisle olmaz; savunma):
  -- rakibin karti varsa inisiyatif ona gecer, yoksa mac biter.
  if not exists (select 1 from match_hands where match_id = p_match_id
                 and user_id = m.lead_player_id and not is_played) then
    if exists (select 1 from match_hands where match_id = p_match_id
               and user_id = _opponent_of(m, m.lead_player_id) and not is_played) then
      update matches set lead_player_id  = _opponent_of(m, m.lead_player_id),
                         current_turn_id = _opponent_of(m, m.lead_player_id)
      where id = p_match_id;
    else
      perform _finish_match(p_match_id);
      return;
    end if;
  end if;
  update matches
  set phase = 'position',
      -- 051: tur sonucu sahnesi + mevki suresi
      turn_deadline = now() + make_interval(secs => coalesce(g.position_seconds, 5) + clash_scene_seconds())
  where id = p_match_id;
end;
$$;
