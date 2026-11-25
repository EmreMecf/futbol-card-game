-- =====================================================================
-- 059 - YABANCI ANAHTAR DİZİNLERİ
-- =====================================================================
-- Veritabanı denetiminde (2026-11-25) 46 yabancı anahtar sütununun
-- dizini olmadığı görüldü. PostgreSQL yabancı anahtara kendiliğinden
-- dizin koymaz. Dizinsiz sütunda:
--   * bağlı satır silinince (hesap silme, kart silme) alt tablo baştan
--     sona taranır,
--   * "bu oyuncunun hamleleri / kazandığı maçlar" gibi sorgular yavaşlar.
-- Bugün veri az olduğu için fark edilmiyor; oyuncu arttıkça büyür.
--
-- Burada büyüyen oyun tablolarındaki sütunlar dizinlenir. Katalog
-- tabloları (karakter, kurgusal lig/kulüp, lig basamakları, kural
-- sürümleri) küçük ve neredeyse hiç değişmediği için dizinlenmez.
--
-- Çoğu sütun boş (null) olabildiği için dizinler kısmi: yalnız dolu
-- satırlar dizine girer, dizin küçük kalır.
--
-- KULLANICI VERİSİ: değişmez; yalnız dizin eklenir. Tekrar çalıştırılabilir.
-- Not: Tablolar küçükken normal CREATE INDEX yeterli. Büyük bir canlı
-- veritabanında yeni dizin eklerken CREATE INDEX CONCURRENTLY tercih
-- edilmeli (migration işlemi içinde kullanılamaz).
-- =====================================================================

-- Maçlar ve maç içi kayıtlar (en hızlı büyüyenler)
create index if not exists idx_matches_winner        on matches (winner_id)        where winner_id is not null;
create index if not exists idx_matches_loser         on matches (loser_id)         where loser_id is not null;
create index if not exists idx_matches_current_turn  on matches (current_turn_id)  where current_turn_id is not null;
create index if not exists idx_matches_lead_player   on matches (lead_player_id)   where lead_player_id is not null;
create index if not exists idx_match_players_deck    on match_players (deck_id)    where deck_id is not null;
create index if not exists idx_match_hands_user      on match_hands (user_id);
create index if not exists idx_match_hands_card      on match_hands (card_id);
create index if not exists idx_match_hands_user_card on match_hands (user_card_id);
create index if not exists idx_match_moves_user      on match_moves (user_id);
create index if not exists idx_match_moves_card      on match_moves (card_id)      where card_id is not null;
create index if not exists idx_match_moves_user_card on match_moves (user_card_id) where user_card_id is not null;
create index if not exists idx_match_rounds_winner   on match_rounds (winner_id)   where winner_id is not null;
create index if not exists idx_match_level_bonus_user on match_hand_level_bonus (user_id);
create index if not exists idx_match_level_bonus_card on match_hand_level_bonus (card_id);

-- Eşleştirme kuyruğu
create index if not exists idx_matchmaking_queue_deck  on matchmaking_queue (deck_id)  where deck_id is not null;
create index if not exists idx_matchmaking_queue_match on matchmaking_queue (match_id) where match_id is not null;

-- Kartlar ve gelişim
create index if not exists idx_user_cards_acquired_from on user_cards (acquired_from) where acquired_from is not null;
create index if not exists idx_card_transfers_card      on card_transfers (card_id);
create index if not exists idx_player_progress_card     on player_progress (card_id);

-- Sezon, görev, günlük
create index if not exists idx_user_seasons_season        on user_seasons (season_id);
create index if not exists idx_season_claims_season       on season_claims (season_id);
create index if not exists idx_user_missions_mission      on user_missions (mission_slug);
create index if not exists idx_season_league_results_user on season_league_results (user_id);
create index if not exists idx_daily_first_wins_match     on daily_first_wins (match_id) where match_id is not null;

-- Eşyalar
create index if not exists idx_user_items_item    on user_items (item_slug);
create index if not exists idx_user_equipped_item on user_equipped (item_slug);

-- Arkadaşlık, odalar, davetler
create index if not exists idx_friendships_requested_by   on friendships (requested_by);
create index if not exists idx_friend_rooms_host_deck     on friend_rooms (host_deck_id)  where host_deck_id is not null;
create index if not exists idx_friend_rooms_guest_deck    on friend_rooms (guest_deck_id) where guest_deck_id is not null;
create index if not exists idx_friend_rooms_match         on friend_rooms (match_id)      where match_id is not null;
create index if not exists idx_friend_challenges_room     on friend_challenges (room_id);
