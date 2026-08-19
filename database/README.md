# Veritabanı — Saf PostgreSQL

Supabase'den çıkıldı. Bu klasördeki SQL **hiçbir Supabase özelliği kullanmıyor**;
PostgreSQL 14+ olan her yerde (Docker, kendi sunucun, herhangi bir hosting)
olduğu gibi çalışır.

## Hızlı başlangıç

```bash
docker compose up -d
```

İlk çalıştırmada `database/migrations/` klasöründeki 10 dosya **alfabetik
sırayla otomatik** çalışır. Bittiğinde:

- PostgreSQL → `localhost:5432` (kullanıcı: `futbol`, şifre: `futbol_dev_sifre_2026`, veritabanı: `futbol_card`)
- pgAdmin → http://localhost:5050 (`admin@futbol.local` / `admin`)

> pgAdmin içinden sunucuya bağlanırken host olarak **`postgres`** yaz,
> `localhost` değil. Çünkü pgAdmin de bir konteynerin içinde çalışıyor.

Şemayı değiştirdikten sonra sıfırdan kurmak için:

```bash
docker compose down -v
```

`-v` bayrağı veri diskini de siler; `up -d` dediğinde migration'lar baştan çalışır.

---

## Supabase'den ne değişti?

| Supabase'de | Şimdi | Neden |
|---|---|---|
| `auth.users` tablosu | Kendi `users` tablomuz (`email` + `password_hash`) | Supabase Auth'a bağımlılık kalktı |
| `auth.uid()` | RPC'lere `p_user_id uuid` parametresi | Kullanıcıyı backend JWT'den çözüp geçirir |
| RLS politikaları | **Kaldırıldı** | Veritabanına artık sadece backend bağlanıyor |
| Supabase Realtime | `LISTEN` / `NOTIFY` + WebSocket | Postgres'in kendi mekanizması, ekstra servis yok |
| `pg_cron` | Backend'de zamanlayıcı | Eklenti kurulumu gerektirmiyor |

### "RLS'i kaldırdık, güvenlik zayıfladı mı?"

**Hayır.** RLS'in görevi, uygulamanın veritabanına *doğrudan* bağlandığı
durumda kullanıcıyı kendi satırlarıyla sınırlamaktı. Artık uygulama
veritabanını hiç görmüyor — arada backend var ve veritabanı şifresi sadece
sunucuda duruyor.

Asıl önemli olan **oyun kuralı doğrulamaları** ise hâlâ burada, veritabanında:

- `play_card()` sıranın sende olduğunu kontrol eder
- kartın gerçekten elinde olduğunu kontrol eder
- zorunlu pozisyona uyduğunu kontrol eder
- "kartım yok" iddiasını doğrular (kartın varsa pas geçemezsin)
- turu kimin kazandığına `compare_cards()` karar verir
- süreleri sunucu saatiyle ölçer

Yani **"istemciye asla güvenme"** prensibi aynen duruyor; sadece kontrol
noktası bir katman yukarı taşındı.

---

## Dosyalar

| Dosya | İçerik |
|---|---|
| `001_extensions_enums_helpers.sql` | Enum'lar, oyun sabitleri, **Legend kuralı** (`compare_cards`) |
| `002_users.sql` | Kullanıcılar + refresh token tablosu |
| `003_cards_inventory.sql` | Kart kataloğu, envanter, transfer geçmişi |
| `004_decks.sql` | Desteler + **4-4-2 formasyon doğrulaması** |
| `005_matches.sql` | Maç, gizli el, hamle, tur ve kuyruk tabloları |
| `006_rpc_matchmaking.sql` | `find_match`, `cancel_matchmaking` |
| `007_rpc_gameplay.sql` | `play_card`, tur çözümü, maç bitişi, ceza sistemi |
| `008_realtime_notify.sql` | `pg_notify` trigger'ları (gerçek zamanlı bildirim) |
| `009_starter_pack.sql` | Yeni oyuncuya 17 kart + hazır kadro |
| `010_seed_cards.sql` | 35 örnek kart |

---

## Backend'in çağıracağı fonksiyonlar

Hepsi ilk parametre olarak `p_user_id` alır. **Bu değeri backend JWT'den
çözer; istemci asla göndermez.**

| Fonksiyon | Ne yapar |
|---|---|
| `grant_starter_pack(p_user_id)` | 17 kart + hazır 4-4-2 kadro verir |
| `validate_deck(p_user_id, p_deck_id)` | `NULL` = geçerli, aksi halde Türkçe hata metni |
| `find_match(p_user_id, p_deck_id, p_protected[])` | Maç arar veya kuyruğa alır |
| `cancel_matchmaking(p_user_id)` | Kuyruktan çıkar |
| `get_match_state(p_user_id, p_match_id)` | Ekranı çizecek tüm genel bilgi (JSON) |
| `get_my_hand(p_user_id, p_match_id)` | **Sadece o oyuncunun** kartları |
| `play_card(p_user_id, p_match_id, p_user_card_id)` | Kart oynar (`NULL` = pas) |
| `claim_turn_timeout(p_user_id, p_match_id)` | Rakip AFK ise maçı hükmen kazanır |
| `surrender_match(p_user_id, p_match_id)` | Teslim olur (ceza uygulanır) |
| `sweep_timed_out_matches()` | Zamanlayıcı çağırır, süresi dolmuş maçları kapatır |
| `cleanup_expired_tokens()` | Eski refresh token'ları siler |

---

## Gerçek zamanlı bildirim nasıl çalışıyor?

```
1. Veritabanında bir şey değişir (sıra rakibe geçer)
2. Trigger  ->  pg_notify('match_events', {...})
3. Backend  ->  LISTEN match_events    (bildirimi anında alır)
4. Backend  ->  WebSocket ile iki oyuncuya haber verir
5. Flutter  ->  ekranı günceller
```

Bildirim mesajı kasıtlı olarak **küçük** tutuldu — sadece "hangi maçta ne oldu"
bilgisi gidiyor. Detayı backend `get_match_state()` ile ayrıca çekiyor.

İki sebebi var: `pg_notify`'ın 8000 baytlık sınırı var, ve daha da önemlisi
bildirim kanalından **yanlışlıkla gizli veri sızması imkânsız** hale geliyor.

---

## Elle test (psql ile)

```bash
docker exec -it futbol_card_db psql -U futbol -d futbol_card
```

```sql
-- Kaç kart yüklendi?
select tier, position, count(*) from cards group by 1,2 order by 1,2;

-- Legend kuralını dene: zayıf Legend, güçlü Diamond'ı yenmeli
select compare_cards('legend', 60, 'diamond', 99);  -- 1 dönmeli

-- İki Legend arasında güç belirleyici
select compare_cards('legend', 94, 'legend', 97);   -- -1 dönmeli

-- Test kullanıcısı oluştur (şifre hash'i sahte, sadece şema testi için)
insert into users (email, password_hash, username)
values ('test1@test.com', 'sahte', 'test1'), ('test2@test.com', 'sahte', 'test2');

-- Başlangıç paketlerini ver
select grant_starter_pack(id) from users where username in ('test1','test2');

-- Eşleştir
select find_match(
  (select id from users where username='test1'),
  (select id from decks where owner_id=(select id from users where username='test1'))
);
-- {"status": "queued", ...} dönmeli

select find_match(
  (select id from users where username='test2'),
  (select id from decks where owner_id=(select id from users where username='test2'))
);
-- {"status": "matched", "match_id": "..."} dönmeli
```
