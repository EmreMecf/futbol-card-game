-- =====================================================================
-- 0006 — ROW LEVEL SECURITY (RLS) KURALLARI
-- =====================================================================
-- TEMEL FELSEFE (Anti-Hile):
--   * Oyun mantığını değiştiren HİÇBİR yazma işlemine istemci izni yok.
--     Tüm INSERT/UPDATE'ler SECURITY DEFINER fonksiyonlar üzerinden yapılır.
--   * İstemciye sadece "görmesi gereken" veriler için SELECT izni verilir.
--   * match_hands tablosunda hiç policy YOK => hiç kimse okuyamaz.
-- =====================================================================

-- Tüm tablolarda RLS aç
alter table public.profiles           enable row level security;
alter table public.cards              enable row level security;
alter table public.user_cards         enable row level security;
alter table public.card_transfers     enable row level security;
alter table public.decks              enable row level security;
alter table public.deck_cards         enable row level security;
alter table public.matches            enable row level security;
alter table public.match_players      enable row level security;
alter table public.match_hands        enable row level security;
alter table public.match_moves        enable row level security;
alter table public.match_rounds       enable row level security;
alter table public.matchmaking_queue  enable row level security;

-- Güvenli varsayılan: hiçbir tabloya doğrudan yazma yetkisi verme
revoke insert, update, delete on all tables in schema public from anon, authenticated;

-- =====================================================================
-- PROFILES
-- =====================================================================

-- Herkes profilleri görebilir (rakip adı, avatarı, MMR'ı görünmeli)
drop policy if exists "profiller_herkese_acik" on public.profiles;
create policy "profiller_herkese_acik"
  on public.profiles for select
  to authenticated
  using (true);

-- Kullanıcı SADECE kendi profilinin görsel alanlarını değiştirebilir.
-- coins / mmr / protection_slots / wins gibi alanlar burada değiştirilemez;
-- onları sadece SECURITY DEFINER fonksiyonlar günceller.
drop policy if exists "kendi_profilini_guncelle" on public.profiles;
create policy "kendi_profilini_guncelle"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

grant update (username, avatar_url) on public.profiles to authenticated;

-- =====================================================================
-- CARDS (Katalog) — herkes okur, kimse yazamaz
-- =====================================================================
drop policy if exists "kart_katalogu_okunabilir" on public.cards;
create policy "kart_katalogu_okunabilir"
  on public.cards for select
  to authenticated
  using (is_active);

-- =====================================================================
-- USER_CARDS (Envanter)
-- =====================================================================

-- Oyuncu sadece KENDİ envanterini görebilir.
-- (Rakibin envanterini görmek stratejik avantaj olurdu.)
drop policy if exists "kendi_envanterini_gor" on public.user_cards;
create policy "kendi_envanterini_gor"
  on public.user_cards for select
  to authenticated
  using (owner_id = auth.uid());

-- Sahiplik değişimi sadece fonksiyonlarla yapılır => INSERT/UPDATE/DELETE yok.

-- =====================================================================
-- CARD_TRANSFERS (Denetim kaydı)
-- =====================================================================
drop policy if exists "kendi_transferlerini_gor" on public.card_transfers;
create policy "kendi_transferlerini_gor"
  on public.card_transfers for select
  to authenticated
  using (from_user_id = auth.uid() or to_user_id = auth.uid());

-- =====================================================================
-- DECKS / DECK_CARDS
-- =====================================================================
-- Deste düzenleme istemciye açıktır (hile riski yok), ancak maça girerken
-- validate_deck() sunucu tarafında tekrar kontrol edilir.

drop policy if exists "kendi_destelerini_gor" on public.decks;
create policy "kendi_destelerini_gor"
  on public.decks for select
  to authenticated using (owner_id = auth.uid());

drop policy if exists "kendi_desteni_olustur" on public.decks;
create policy "kendi_desteni_olustur"
  on public.decks for insert
  to authenticated with check (owner_id = auth.uid());

drop policy if exists "kendi_desteni_guncelle" on public.decks;
create policy "kendi_desteni_guncelle"
  on public.decks for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "kendi_desteni_sil" on public.decks;
create policy "kendi_desteni_sil"
  on public.decks for delete
  to authenticated using (owner_id = auth.uid());

grant insert, update, delete on public.decks to authenticated;

-- deck_cards: sadece kendi destene, sadece kendi kartını ve
-- kilitli olmayan (macta kullanilmayan) kartı ekleyebilirsin.
drop policy if exists "deste_kartlarini_gor" on public.deck_cards;
create policy "deste_kartlarini_gor"
  on public.deck_cards for select
  to authenticated
  using (exists (
    select 1 from public.decks d
    where d.id = deck_cards.deck_id and d.owner_id = auth.uid()
  ));

drop policy if exists "deste_kartlarini_ekle" on public.deck_cards;
create policy "deste_kartlarini_ekle"
  on public.deck_cards for insert
  to authenticated
  with check (
    exists (select 1 from public.decks d
             where d.id = deck_cards.deck_id and d.owner_id = auth.uid())
    and exists (select 1 from public.user_cards uc
             where uc.id = deck_cards.user_card_id
               and uc.owner_id = auth.uid()
               and uc.locked_match_id is null)
  );

drop policy if exists "deste_kartlarini_sil" on public.deck_cards;
create policy "deste_kartlarini_sil"
  on public.deck_cards for delete
  to authenticated
  using (
    exists (select 1 from public.decks d
             where d.id = deck_cards.deck_id and d.owner_id = auth.uid())
    and exists (select 1 from public.user_cards uc
             where uc.id = deck_cards.user_card_id
               and uc.locked_match_id is null)
  );

grant insert, delete on public.deck_cards to authenticated;

-- =====================================================================
-- MATCHES — sadece maçın iki tarafı görebilir
-- =====================================================================
drop policy if exists "kendi_maclarini_gor" on public.matches;
create policy "kendi_maclarini_gor"
  on public.matches for select
  to authenticated
  using (player1_id = auth.uid() or player2_id = auth.uid());

-- YAZMA YOK. Kart oynama, tur bitirme vs. hep RPC ile.

-- =====================================================================
-- MATCH_PLAYERS
-- =====================================================================
-- Rakibin hangi kartları koruduğunu görmemeli, ama toplanan kart
-- sayısını görmeli. protected_card_ids kolonunu istemciye vermemek için
-- SELECT'i sadece kendi satırına açıp, rakip bilgisini
-- get_match_state() RPC'si ile veriyoruz.
drop policy if exists "kendi_mac_satirini_gor" on public.match_players;
create policy "kendi_mac_satirini_gor"
  on public.match_players for select
  to authenticated
  using (user_id = auth.uid());

-- =====================================================================
-- MATCH_HANDS — KASITLI OLARAK HİÇ POLICY YOK
-- =====================================================================
-- RLS açık + policy yok = authenticated rolü için tam erişim yasağı.
-- Erişim yalnızca SECURITY DEFINER olan get_my_hand() üzerinden.
revoke all on public.match_hands from anon, authenticated;

-- =====================================================================
-- MATCH_MOVES / MATCH_ROUNDS — açık oynanan kartlar, iki taraf da görür
-- =====================================================================
drop policy if exists "mac_hamlelerini_gor" on public.match_moves;
create policy "mac_hamlelerini_gor"
  on public.match_moves for select
  to authenticated
  using (exists (
    select 1 from public.matches m
    where m.id = match_moves.match_id
      and (m.player1_id = auth.uid() or m.player2_id = auth.uid())
  ));

drop policy if exists "tur_sonuclarini_gor" on public.match_rounds;
create policy "tur_sonuclarini_gor"
  on public.match_rounds for select
  to authenticated
  using (exists (
    select 1 from public.matches m
    where m.id = match_rounds.match_id
      and (m.player1_id = auth.uid() or m.player2_id = auth.uid())
  ));

-- =====================================================================
-- MATCHMAKING_QUEUE — sadece kendi kuyruk satırını görür
-- =====================================================================
drop policy if exists "kendi_kuyruk_satirini_gor" on public.matchmaking_queue;
create policy "kendi_kuyruk_satirini_gor"
  on public.matchmaking_queue for select
  to authenticated
  using (user_id = auth.uid());

-- Kuyruğa girme/çıkma da RPC ile yapılır (MMR'ı istemci belirleyemesin).
