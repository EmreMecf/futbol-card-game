-- =====================================================================
-- 008 - GERCEK ZAMANLI BILDIRIM (LISTEN / NOTIFY)
-- =====================================================================
-- Supabase Realtime'in yerini bu mekanizma aliyor.
--
-- NASIL CALISIR?
--   1. Veritabaninda bir sey degisir (ornek: sira rakibe gecer).
--   2. Trigger, pg_notify() ile kucuk bir bildirim yayinlar.
--   3. Backend surekli LISTEN yapar, bildirimi aninda alir.
--   4. Backend ilgili oyunculara WebSocket ile haber verir.
--   5. Flutter uygulamasi ekrani gunceller.
--
-- NEDEN PAYLOAD KUCUK?
--   pg_notify'in mesaj siniri 8000 bayttir. Bu yuzden bildirimde
--   sadece "hangi macta ne oldu" bilgisi gonderiyoruz. Backend detayi
--   get_match_state() ile ayrica cekiyor. Bu ayni zamanda daha guvenli:
--   bildirim kanalindan yanlislikla gizli veri sizamaz.
-- =====================================================================

-- ---------------------------------------------------------------------
-- MAC OLAYLARI
-- ---------------------------------------------------------------------
create or replace function notify_match_event()
returns trigger
language plpgsql
as $$
declare
  v_payload json;
  v_match_id uuid;
  v_p1 uuid;
  v_p2 uuid;
  v_event text;
begin
  -- Hangi tablodan geldigine gore mac kimligini bul
  if TG_TABLE_NAME = 'matches' then
    v_match_id := new.id;
    v_p1 := new.player1_id;
    v_p2 := new.player2_id;
    v_event := case when new.status = 'finished' then 'match_finished'
                    else 'match_updated' end;
  else
    v_match_id := new.match_id;
    select player1_id, player2_id into v_p1, v_p2
    from matches where id = v_match_id;
    v_event := case TG_TABLE_NAME
                 when 'match_moves'  then 'move_played'
                 when 'match_rounds' then 'round_resolved'
                 else 'match_updated'
               end;
  end if;

  v_payload := json_build_object(
    'event',     v_event,
    'match_id',  v_match_id,
    'player1',   v_p1,
    'player2',   v_p2,
    'at',        now()
  );

  perform pg_notify('match_events', v_payload::text);
  return null;  -- AFTER trigger, donus degeri onemsiz
end;
$$;

drop trigger if exists trg_notify_match on matches;
create trigger trg_notify_match
  after insert or update on matches
  for each row execute function notify_match_event();

drop trigger if exists trg_notify_move on match_moves;
create trigger trg_notify_move
  after insert on match_moves
  for each row execute function notify_match_event();

drop trigger if exists trg_notify_round on match_rounds;
create trigger trg_notify_round
  after insert on match_rounds
  for each row execute function notify_match_event();

-- ---------------------------------------------------------------------
-- ESLESTIRME OLAYLARI
-- ---------------------------------------------------------------------
-- Kuyrukta bekleyen oyuncuya "rakip bulundu" haberini ulastirir.
create or replace function notify_queue_event()
returns trigger
language plpgsql
as $$
begin
  perform pg_notify(
    'queue_events',
    json_build_object(
      'event',    'queue_updated',
      'user_id',  new.user_id,
      'status',   new.status,
      'match_id', new.match_id,
      'at',       now()
    )::text
  );
  return null;
end;
$$;

drop trigger if exists trg_notify_queue on matchmaking_queue;
create trigger trg_notify_queue
  after insert or update on matchmaking_queue
  for each row execute function notify_queue_event();
