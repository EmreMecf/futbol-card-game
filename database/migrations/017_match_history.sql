-- =====================================================================
-- 017 - MAC GECMISI
-- =====================================================================
-- AMAC: Profil ekraninda "son maclarim" listesi.
--
-- Bu veri zaten `matches` tablosunda duruyordu ama disari acilmamisti;
-- oyuncu kendi gecmisini goremiyordu. Bir maci kaybedip kart
-- kaptirdiginda "ne oldu?" sorusunun cevabi hicbir yerde yoktu.
--
-- GUVENLIK: Fonksiyon p_user_id'yi JWT'den alir. Baskasinin gecmisi
-- istenirse where kosulu zaten eslesmez, bos doner.
-- =====================================================================

create or replace function get_match_history(
  p_user_id uuid,
  p_limit   int default 20,
  p_offset  int default 0
)
returns table (
  match_id          uuid,
  opponent_id       uuid,
  opponent_username text,
  my_score          int,
  opponent_score    int,

  -- 'win' | 'loss' | 'draw'
  outcome           text,

  -- Bu macta el degistiren kart sayisi (kazandigim / kaptirdigim)
  cards_won         int,
  cards_lost        int,

  finished_at       timestamptz
)
language sql
stable
as $$
  select
    m.id,
    case when m.player1_id = p_user_id then m.player2_id else m.player1_id end,
    u.username,

    -- Skor: kim hangi tarafsa onun toplanan kart sayisi
    case when m.player1_id = p_user_id then m.p1_captured_count
         else m.p2_captured_count end,
    case when m.player1_id = p_user_id then m.p2_captured_count
         else m.p1_captured_count end,

    case when m.is_draw            then 'draw'
         when m.winner_id = p_user_id then 'win'
         else 'loss' end,

    -- Kart transferleri card_transfers tablosunda tutuluyor
    coalesce((
      select count(*)::int from card_transfers t
      where t.match_id = m.id and t.to_user_id = p_user_id
    ), 0),
    coalesce((
      select count(*)::int from card_transfers t
      where t.match_id = m.id and t.from_user_id = p_user_id
    ), 0),

    m.finished_at
  from matches m
  join users u
    on u.id = case when m.player1_id = p_user_id
                   then m.player2_id else m.player1_id end
  where (m.player1_id = p_user_id or m.player2_id = p_user_id)
    and m.status = 'finished'
  order by m.finished_at desc nulls last
  limit greatest(1, least(p_limit, 100))
  offset greatest(0, p_offset);
$$;

comment on function get_match_history is
  'Oyuncunun bitmis maclari, en yeniden eskiye. Profil ekrani kullanir.';

-- Gecmis sorgusu bitmis maclari tarar; aktif mac indeksleri ise
-- kismi (where status = active) oldugu icin bu sorguya yaramiyor.
create index if not exists idx_matches_history_p1
  on matches (player1_id, finished_at desc) where status = 'finished';
create index if not exists idx_matches_history_p2
  on matches (player2_id, finished_at desc) where status = 'finished';
