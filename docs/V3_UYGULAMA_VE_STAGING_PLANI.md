# Futbol Card Arena — V3 uygulanabilirlik, guvenli gecis ve staging kontrol listesi

Tarih: 12 Kasim 2026. Kaynak HEAD: `48297de`. **Bu belge bir uygulama/test sonucu degildir; V3 duello kodu bu PR'da degistirilmez.**
Once CI'da PostgreSQL ve uctan uca testlerin gecerli sonucu alinmalidir.

## Mevcut mimari ile uyum

- `023_rules_versioning.sql`: `matches.rules_version` mac baslangicinda sabitlenir. Surum 1/2/3 oynanmakta olan maclar yeni kuralla ASLA guncellenmemeli.
- `037_ranked_rewards_v2.sql`: surum 3 ekonomi kurallari; `economy_v2_enabled` ve `ranked_rewards_v2` birlikte aktif degilse surum 2 secilir. V3 yeni mekanik surum 4 olmali; ekonomi surumu 3 kurallariyla birlikte calismasi ayri test edilmeli.
- `024_matchmaking_deck_power.sql`: `matchmaking_settings.mode` varsayilan `mmr`. V3 seviye bonusu hesaplamasi *hem* matchmaking power hem de oynanan snapshot icin ayni kanonik fonksiyondan alinmali.
- `server/lib/routes/match_routes.dart`: `/play` endpoint'i bugun sirayla hamle kabul ediyor. V3 icin ayri endpoint ve surec gereklidir.
- `server/lib/realtime/ws_hub.dart`: WebSocket olaylari yalnız yenileme sinyali olmali; rakibin gizli kart/taktik secimi yayinlanmamali.

## Faz 1 — Sunucu tarafinda eszamanli gizli secim (oyun surumu 4)

**Kabul olmadan varsayilan kapali** `game_v3_simultaneous` anahtari. Yeni surum `game_rule_versions.version=4`; `current_rules_version()` yeni mac kurulurken secmeli. Eski/aktif maclarin `rules_version` degeri degismemeli.

- Durum makinesi: `position_selection` (5 saniye) -> `secret_selection` (15 saniye) -> `reveal` -> `resolved` -> sonraki tur / mac sonu.
- `match_round_selections` tablosu onerisi: `match_id`, `round_number`, `user_id`, `card_id`, `tactic`, `submitted_at`; `PRIMARY KEY(match_id, round_number, user_id)`. RLS / API gorunurlugu: rakibin secimi reveal olana kadar okunamaz. Gerekirse public state ve private hand selection iki farkli sorgu.
- `POST /api/match/:id/position`: sadece o turun inisiyatif sahibi mevki secer; ayni tur yeniden istek idempotent; gecerli pozisyonlar eldeki kartlarda bulunmali.
- `POST /api/match/:id/select`: oturumdaki kullanici yalniz kendi kartindan pozisyona uygun secim yapar; enerji yeterliligi sunucuda dogrulanir. Birden fazla istek replay/degisiklik politikasina gore kararli; tavsiye: ilk gecerli secim kilitlenir.
- Iki secim tamamlaninca `_resolve_round_v4` tek bir veritabani transaction'i icinde calisir. `SELECT ... FOR UPDATE`, benzersiz `match_id,round` sonuc kaydi, defter idempotency anahtari; ayni turun ikinci kez sonuc vermemesi zorunludur.
- WebSocket: `round_phase_changed`, `selection_received` (sadece kendi seciminin teyidi / rakibin hazirlik bayragi), `round_revealed`, `round_resolved`. Sunucu `card_id`/taktik bilgilerini `round_revealed` oncesi rakip aboneligine vermemeli.
- Timer: `deadline_at` UTC sunucu saati. Iki oyuncu da secmezse o mevkideki kalan en zayif kart + taktik none; iki ardisik sure asiminda hukum. Sunucu yeniden baslayinca geciken turlar PostgreSQL durumundan tekrar ele alinmali.
- 12 kart toplandiginda erken bitis; pot, Legend, kimya ve taktik mantigi testlerle korunmali. Iki tarafin 11 karti bitmesi ve pot sonu kosullari ayri test edilmeli.
- Ornek durum GET cevabi: `rules_version`, `phase`, `position`, `phase_deadline_at`, `my_selection_locked`, `opponent_ready`, `reveal` (yalniz ilgili fazdan sonra). Tum sayaç ve animasyonlar ayni sunucu durumundan turetilmeli.

## Faz 2 — Seviye B2 + etkin guc ve lig siniri

Seviye bonusu: `level >= 10 => +3; >= 7 => +2; >= 4 => +1; else 0`.
Lig tavani: Amator 4, Usta 7, Master+ 10. Bonus formulu `effective_level = min(actual_level, league_cap)`. Kartin temel guc + kimya hesaplamasi korunur. Aynı bonus tek kaynaktan **elde snapshot'i**, **deck_power** ve **tur hesaplamasina** yansir.

- `matchmaking_settings.mode='combined'` staging'de test edilmeden production'da acilmaz.
- Lig sinifi esigi ve baslangic MMR uyumsuzlugu (1000 alti) ayrica cozulmeli.
- Seviye bonusu yuksek nadirlik mutlak ustunluk kuralini kendi kendine kaldirmamali.
- Seviye bonusu hem oyuncuya hem rakibe ayni algoritmayla yansimazsa exploit ortaya cikar.

## Dogrulama matrisi (otomatik test yazilmali)

| Senaryo | Kabul |
| --- | --- |
| Varsayilan `game_v3_simultaneous=false` | Eski s2/s3 `play_card`, `_resolve_round`, sonuc ve oduller degismez |
| Ozellik mac ortasinda acilir | S2/s3 mac eski mekanikle biter |
| Iki kisi farkli kart secip bekler | Secimler reveal'den once rakibe sizmaz |
| Ayni kullanici secimi iki kez yollar | Tek kayit, tek tur sonucu |
| Ayni tur iki worker tarafindan resolve edilir | Tek skor ve tek odul |
| 5 saniye mevki, 15 saniye secim | Yalniz sunucu zamani belirleyici |
| 2 ardisik zaman asimi | Hükmen bitis / kart sinirlarina uygun |
| Baglanti kopar, telefon yeniden baglanir | Sunucu state ve tur kopyalanmaz, senkron |
| V3 kisa mac <4 tur | Sandik K6 kuralina gore korunur; yeni karar gerektiriyorsa ayri onay |
| Seviye 3/4/6/7/9/10 | 0/1/1/2/2/3 bonus |
| Lig tavani 4/7/10 | Her ortamda ayni cap |
| Esit efektif guc + farkli MMR | combined band filtrelemesi |
| Gecmis sahiplik, transfer, odul defteri | Migration once/sonra sayi + hash ayni |

## Staging ve Android iki telefon

1. Production'dan ayrilmis PostgreSQL ve yalniz staging hesaplari.
2. Server icin Docker multi-stage, non-root, healthcheck, config/secrets; 8080 api.
3. HTTPS/WSS; TLS reverse proxy; `API_BASE_URL` ile staging APK release; `WS_URL` tespit.
4. Iki Android telefonda farkli hesaplarla login, sira, gizli secim, animasyon, reconnect ve sonuc testi.
5. Canli matchmaking / websocket / DB connection metrics, migration rollback plani.
6. Test bitene kadar production feature flags kapali.

## Production hazirlik

- Yonetilen PostgreSQL: ozel ag, sifre rotasyonu, otomatik yedek/PITR, periyodik restore testi.
- Dart sunucusu: tek instance + guvenli deploy; coklu instanceta in-memory WS hub ortak pub/sub olmadan calismaz. Timeout sweeper singleton/dagitik kilit gerektirir.
- Koruma: user-scoped JWT, refresh rotate, rate limit, request body limits, CORS, HTTPS, HSTS, log redaction, audit events.
- SLO: API p95, matchmaking latency, WebSocket reconnect, DB hata orani, stale match, double-reward = 0.
- APK yayin: release keystore CI'da secret olarak; staging/production ayri API adresleri ve imzalar.
- GitHub Actions: DB+E2E yesil olmadan production deploy onaylanmaz.

**Durum siniri:** Bu belgede anlatilan V3 sunucu endpoint'leri, migration 039, sinirlar ve testler HENUZ uygulanmadi; yalniz guvenli dosya-bazli uygulama kilavuzudur.
