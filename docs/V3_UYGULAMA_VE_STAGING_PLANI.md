# Futbol Card Arena — V3 uygulama durumu, staging ve üretim planı

Tarih: 12 Kasım 2026. Temel: `48297de` + CI düzeltmesi (`6edc817`). Dal: `v3-faz1-esz-zamanli-duello`.

Bu belge, aynı adlı önceki taslağın ("039 henüz uygulanmadı") yerine geçer: Faz 1 (eş zamanlı gizli
seçim, kural sürümü 4) **uygulandı ve test edildi**, anahtarı **kapalı**. Önerilen adlarla gerçek adlar:

| Taslakta | Uygulamada | Neden |
|---|---|---|
| `game_v3_simultaneous` anahtarı | `duel_v4` (+ `economy_v2_enabled`, `ranked_rewards_v2`) | Kural sürümü zinciri 2 → 3 → 4; sürüm 4, sürüm 3'ün ödül kurallarının üstüne kurulu |
| `match_round_selections` tablosu | Mevcut `match_moves` | Zaten `unique (match_id, round_number, user_id)`; gizlilik okuma tarafında sağlanıyor |
| `POST /select` | Mevcut `POST /play` (sürüm 4'te gizli oynar) | İstemci ve eski maçlar aynı uç noktayı kullanır; davranışı maçın sürümü belirler |
| `position_selection → secret_selection` | `matches.phase`: `position` → `pick` | — |

---

## 0. CI hatası (çalışma 43040651331)

- **Belirti:** "Veritabanı" ve "Uçtan uca" işleri `psql istemcisi` adımında `exit code 100` (apt) ile kaldı;
  diğer 3 iş (Flutter, Dart, Android) geçti.
- **Neden:** `ubuntu-latest` etiketi 19 Ekim 2026'dan itibaren Ubuntu 26'ya taşınıyor (GitHub uyarısı
  aynı çalışmada). Yeni imajda `apt-get update`/`install postgresql-client` başarısız oldu. Önceki
  başarılı çalışma (42834025393, 10 Kasım) aynı adımı geçmişti; kod değişikliği bu adımı etkilemiyor.
- **Düzeltme (`6edc817`, PR "CI: PostgreSQL test işlerinde Ubuntu 24.04 ve apt yeniden deneme"):**
  PostgreSQL kullanan iki iş `ubuntu-24.04`'e sabitlendi, apt 3 kez yeniden deneniyor, kurulum
  başarısızsa iş testsiz geçmiyor (çıkış 1), sağlık kontrolü `-d postgres`.
- **Kanıt:** PR çalışması 43186315347 — 5/5 iş başarılı (Veritabanı, Uçtan uca, Dart, Flutter, Android).
- Bu dalda CI'a eklenenler: `SINIR=039` geçmiş veri kontrolü, eş zamanlı yarış testi, seviye
  tasarım testleri.

## 1–2. 037/038 testleri ve "anahtarlar kapalıyken eski davranış"

Yerel kanıt (12 Kasım 2026, PostgreSQL 17.5):

| Test | Sonuç |
|---|---|
| `scripts/db-testleri.sh` — 38 migration sıfırdan, her biri tek işlemde | GEÇTİ |
| 15 kural test dosyası (021–039; **037**, **038**, **039** dahil) | 15/15 GEÇTİ |
| Migration'ları ikinci kez uygulama | GEÇTİ |
| Maç sürerken son migration (039) uygulanır, maç kendi sürümüyle biter | GEÇTİ |
| `SINIR=037 gecmis-veri-kontrolu.sh` (6 maç, 11 transfer, 10 sandık, 16 defter kaydı) | parmak izi aynı `ffb32919…` |
| `SINIR=039 gecmis-veri-kontrolu.sh` (6 maç, 11 transfer, 8 sandık, 14 defter kaydı) | parmak izi aynı `38019c67…` |

Parmak izi şu tabloları kapsar: kullanıcılar (altın, MMR, galibiyet), kart sahipliği, kart transferleri,
maçlar (durum, kural sürümü, kazanan), maç elleri, sandıklar, seviye ilerlemesi, ekonomi defteri, sezonlar,
eşyalar. Yeni migration'lar yalnız ayar tablolarına **yeni sürüm satırı** ekler.

Anahtarlar kapalıyken (`039_duel_v4_test.sql` bölüm 0–1 ve 4): yeni maç sürüm 2 (ekonomi kapalı) / 3;
eski maçta mevki seçimi reddedilir; açan oynayınca sıra rakibe geçer; duvar 1 enerji; eski süre aşımı
taraması sürüm 4 maçlara, yeni zamanlayıcı eski maçlara dokunmaz.

Uçtan uca (gerçek sunucu, anahtarlar kapalı): tam maç zinciri, gerçek zamanlı bildirim, sandık, sezon,
gelişim, envanter — hepsi GEÇTİ. Flutter 717 test (708 birim/ekran + 9 sunuculu entegrasyon) GEÇTİ;
Dart: ortak modeller 63, taktik prototipi 37, içerik hattı 30, sunucu 29 GEÇTİ; analiz temiz.

## 3. V3 maç sisteminin uygulanabilirliği

**Uygulanabilir ve uygulandı (Faz 1).** Mevcut mimari buna uygun çıktı:

- `matches.rules_version` maç kurulurken yazılıyor (023) → yeni kural, süren maçları değiştirmeden
  gelebiliyor. Kanıt: yükseltme testi + `039` bölüm 1.
- Tur çözümü (`_resolve_round`), Efsane kuralı, kimya, beraberlikte kartların ortada kalması, taktikler
  ve MMR **aynı fonksiyonlarla** çalışıyor; 039 yalnız tur akışını ve duvar maliyetini (sürüm 4'te 2)
  değiştiriyor. Fonksiyonlar mevcut gövdelerden `tool/ekonomi/migration_uret_039.py` ile üretildi.
- Ölçülen (simülasyon, `duello_v3.md`): ilk inisiyatifin puanı %47,6 (hedef %45–55), tipik maç
  ~1,9 dk, en uzun 3,7 dk. Gerçek sunucuda örnek maç 10 turda 12-8 bitti.

**Açık riskler:**

1. Taktik dengesi basit ajanlarla ölçüldü: "hep duvar" akıllı ajana karşı hâlâ ~%68. Staging'de gerçek
   oyuncu verisiyle (taktik seçim oranları) yeniden ölçülmeli.
2. Taktik kullanmayan oyuncu çok zayıf (~%13–17) → **öğretici (Faz 3) zorunlu**, açılıştan önce.
3. 12 kartta erken bitiş, kısa maçlarda sandık kuralı (K6) ile etkileşir; ödül tarafı 037 ile test edildi
   (iki oyuncuya da sandık), ama "4 turdan kısa maç" kuralı gerçek oyunda izlenmeli.

## 4. Eş zamanlı gizli seçim — sunucu, WebSocket, animasyon, süre aşımı (uygulanan tasarım)

### 4.1 Durum makinesi (veritabanında, tek doğruluk kaynağı)

```
maç kurulur (trg_match_init_simultaneous)
   └─ phase = position, turn_deadline = now() + 15 sn (ilk tur: ekran yüklenirken; sonraki turlar 5 sn)
position ── lead POST /position {GK|DEF|MID|FWD} ──► pick (deadline = now() + 15 sn)
   └─ süre doldu → advance: en çok kartı olan mevki (otomatik; sayaca SAYILMAZ)
pick ── iki oyuncu da POST /play {kart, taktik} ──► _resolve_round → _after_round_simultaneous
   └─ süre doldu → advance: oynamayanın o mevkideki EN ZAYIF kartı, taktiksiz (auto_streak + 1)
_after_round_simultaneous:
   ├─ bir taraf ≥ 12 kart → maç biter (normal _finish_match: MMR, sandık, sezon)
   ├─ lead'in eli bittiyse inisiyatif karşıya geçer
   └─ phase = position (5 sn)
auto_streak ≥ 2 (üst üste 2 otomatik kart) → hükmen; ikisi birden → kazanansız biter
```

- Bütün geçişler `select … for update` ile maç satırını kilitler; süre kontrolü kilitten **sonra** yapılır.
- Veritabanı kısıtları ikinci savunma hattı: `match_moves unique (match_id, round_number, user_id)`,
  `match_rounds primary key (match_id, round_number)`, sandık `unique (source_type, source_id, user_id)`.
- Saat yalnız sunucuda (`turn_deadline`, UTC). İstemci sayacı sunucu saatine göre ofsetli.

### 4.2 API

| Uç nokta | Sürüm 4 davranışı |
|---|---|
| `POST /api/match/<id>/position` | Yalnız inisiyatif sahibi, yalnız `position` aşamasında; aksi 400 |
| `POST /api/match/<id>/play` | Gizli oynama; aynı turda ikinci istek reddedilir ("zaten oynadınız") |
| `GET /api/match/<id>/state` | `simultaneous`, `phase`, `i_have_played`, `opponent_has_played`, `tactic_costs`, `early_finish_cards`, `turn_deadline` |
| `GET /api/match/<id>/moves` | Rakibin **bu turdaki** hamlesi tur çözülene kadar hiç gönderilmez (kart, taktik dahil) |
| `POST /api/match/<id>/timeout` | Sürüm 4'te `advance_simultaneous_match` (istemci sayacı bitince dürter) |

### 4.3 WebSocket

- PostgreSQL tetikleyicisi (`008`) yalnız `{event, match_id, player1, player2, at}` yayınlar; sunucu
  bunu iki oyuncuya iletir. **Kart, taktik, güç hiçbir zaman WebSocket'ten gitmez.**
- İstemci her olayda REST ile tazeler (debounce). `move_played` rakibe yalnız "seçti" bilgisini verir
  — bu, tasarımın istediği "Rakip seçti, gizli" göstergesidir.
- Çok sunuculu kurulumda: her sunucu örneği aynı `LISTEN` kanalını dinler ve kendi soketlerine iletir;
  ortak pub/sub gerekmez.

### 4.4 Animasyon (istemci)

- Mevki aşaması: lead'e mevki seçici (GK/DEF/MID/FWD + kalan kart sayısı), diğerine "RAKİP MEVKİ SEÇİYOR".
- Seçim aşaması: "KARTINI SEÇ!"; oynayınca "RAKİP SEÇİYOR…"; VS alanında "Kartın gizli / Seçti, gizli".
- Açılış: çarpışma kuyruğu yeni **çözülmüş turlardan** üretilir; iki kart tur çözülünce birlikte açılır.
  Yeniden bağlanan istemci gösterilmemiş turları sırayla oynatır, tekrar oynatmaz.
- Ekran görüntüleri: `test/goldens/ekranlar/39*_v4_*`, `40*_v4_*` (390×844, 320×568, 1366×768).

### 4.5 Süre aşımı ve zamanlayıcı

- Sunucu her saniye `advance_simultaneous_matches()` çağırır (en fazla 200 maç/tur, kısmi indeks
  `idx_matches_simultaneous_deadline`). Tek maçtaki hata ötekileri durdurmaz; `economy_errors`'a yazılır.
- Sunucu yeniden başlarsa gecikmiş turlar veritabanından devam eder (durum bellekte değil).

### 4.6 Test kanıtı

| Test | Kapsam | Sonuç |
|---|---|---|
| `database/tests/039_duel_v4_test.sql` | kapalı varsayılan, eski maç aynen, akış, duvar 2, süre aşımı/hükmen, tek boş tur hükmen değil, erken bitiş, eşit olmayan eller, durum alanları | GEÇTİ |
| `scripts/esz-zamanli-yaris-testi.sh` (**yeni**) | 8 paralel zamanlayıcı → tek mevki / tek tur sonucu; aynı oyuncu 3 paralel oynama → tek hamle; oyuncu + zamanlayıcı yarışı → tek sonuç; 4 paralel "sunucu" ile maç sonu → her turda 2 hamle, oyuncu başına tek sandık, transfer yok | 17/17 GEÇTİ |
| `tool/ekonomi/duello_v4_e2e.mjs` (gerçek sunucu, iki hesap) | sürüm 4, yanlış oyuncu mevki seçemez (400), **REST gizliliği**, **WebSocket gizliliği** (yeni: 2 mesaj, sızan 0), açılış, zamanlayıcı 21,8 sn'de otomatik çözdü, 12-8 / 10 tur, transfer yok, iki sandık | 18/18 GEÇTİ |
| `test/match_view_model_test.dart` "Eş zamanlı düello" | 5 test | GEÇTİ |
| `test/goldens/duello_v4_golden_test.dart` | 7 test (taşma yok, duvar 2 enerji) | GEÇTİ |

## 5. Seviye bonusu × kadro gücü eşleştirmesi (Faz 2 — uygulanmadı, onay bekliyor)

Faz 2 güç hesabını, dolayısıyla düelloyu değiştirir; **ayrı onay olmadan uygulanmaz**. Hazırlanan testler:

**Şimdi çalışan (CI'da):** `tool/ekonomi/test_seviye_eslestirme.py` — 6/6 GEÇTİ (3 sn)
- B2 tablosu: seviye 1–3 → 0, 4–6 → +1, 7–9 → +2, 10 → +3
- Lig tavanı: seviye 10 kart Amatör'de +1, Usta'da +2, Master'da +3
- Bonus yalnız o karta eklenir
- Etkin güce göre eşleşmede seviye 4/7/10 oyuncu %45–56 (ölçülen: %51–54)
- Temel güce göre eşleşmede seviye 10 > %75 (ölçülen %89) — etkin gücün neden şart olduğunu kilitler
- Aynı ligde tavanın üstü sayılmaz (seviye 10 ile seviye 4 aynı sonuç)

**040 migration'ı yazılınca eklenecek veritabanı kabul testleri:**

| # | Senaryo | Beklenen |
|---|---|---|
| 1 | Anahtar kapalı | `deck_power`, el gücü, tur sonucu bugünküyle bayt bayt aynı (geçmiş veri parmak izi) |
| 2 | Bonus tek kaynaktan | Aynı SQL fonksiyonu hem `deck_power`'a hem maç eli anlık görüntüsüne (`match_hands.power`) uygulanır; ikisi farklıysa test kalır |
| 3 | Maç ortasında seviye atlama | Maçtaki el gücü değişmez (anlık görüntü) |
| 4 | Lig tavanı maç kurulurken | Tavan maç başındaki lige göre; maç içinde lig değişse de el aynı |
| 5 | Efsane kuralı | +3 bonuslu Elmas kart Efsane'yi yenemez |
| 6 | `combined` eşleştirme | Etkin gücü denk, MMR'ı farklı iki oyuncu aralıkta eşleşir; etkin güç farkı büyükse eşleşmez |
| 7 | Eski maç | Sürüm 1–4 maçlar bonus görmez (yeni kural sürümü 5) |

## 6. Android cihazlarda canlı PvP — staging hazırlığı

**Hazır olanlar:**
- İstemci adresi derleme anında verilebiliyor: `--dart-define=API_BASE_URL=… WS_URL=…`; `wss://`
  REST adresinden otomatik türetiliyor. Yayın derlemesi http/localhost adresini algılıyor (`AppConfig`).
- Yayın imzası `android/key.properties`'ten (yoksa debug anahtarıyla uyarı). `INTERNET` izni var.
- Sunucu üretim modunda zayıf `JWT_SECRET`'i reddediyor (`Env.productionProblems`), veritabanına
  `SslMode.require` ile bağlanıyor.
- CI Android derlemesi geçiyor (son çalışma 5/5).

**Eksikler (staging'den önce):**
1. Sunucu için **Dockerfile yok** (yalnız geliştirme `docker-compose.yml`'i: PostgreSQL + pgAdmin).
2. `docker-compose.yml`'deki migration yolu yalnız ilk kurulumda çalışır; staging/üretimde migration'lar
   ayrı, sıralı ve tek işlemde bir "migrate" adımıyla uygulanmalı (CI'daki döngü gibi).
3. TLS sonlandırma (HTTPS/WSS) için ters vekil tanımı yok.
4. Staging için ayrı paket kimliği (ör. `.staging`) ve ayrı imza yok; iki telefona aynı anda staging ve
   üretim kurulamaz.
5. Uygulama içi hata raporlama (çökme) yok.

**İki telefonla test planı:** (1) staging veritabanı + sunucu, anahtarlar staging'de açık; (2) iki ayrı
hesap; (3) senaryolar: eşleşme, mevki/gizli seçim, 5+15 sn süre aşımı, biri uygulamayı kapatıp açınca
yeniden bağlanma, uçak modu 10 sn, ekran kilidi, maç sonu sandık; (4) sunucu günlüğü + `economy_errors`
sıfır; (5) ölçüm: hamle → rakip ekranı gecikmesi (hedef < 500 ms).

## 7. Üretim planı

| Konu | Plan |
|---|---|
| **Docker** | Çok aşamalı: `dart compile exe bin/server.dart` → `debian:bookworm-slim` (veya `scratch` + `/runtime`), root olmayan kullanıcı, `HEALTHCHECK`, salt-okunur dosya sistemi. Ayrı `migrate` imajı/işi. |
| **Yönetilen PostgreSQL 17** | Özel ağ, `sslmode=require`, uygulama kullanıcısı süper kullanıcı değil, bağlantı havuzu (ör. PgBouncer, oturum modu — `LISTEN` için), otomatik yedek + **PITR** (en az 7 gün), ayda bir geri yükleme denemesi. |
| **HTTPS/WSS** | Ters vekil (Caddy/Nginx/yük dengeleyici) TLS sonlandırır, `Upgrade` başlıklarını geçirir, WebSocket boşta zaman aşımı ≥ 60 sn; HSTS. |
| **Ölçekleme** | Birden fazla sunucu örneği güvenli: WebSocket olayları PostgreSQL `LISTEN` ile her örneğe gelir; zamanlayıcı yarışı satır kilidiyle güvenli (yarış testi). Eski süre aşımı taraması (`sweep_timed_out_matches`) kod incelemesine göre güvenli (`_finish_match` maçı kilitler, bitmişse çıkar); paralel testi henüz yok. |
| **Yedekleme** | Sağlayıcının günlük yedeği + PITR; migration öncesi elle anlık görüntü; geri dönüş = önceki imaj + anahtar kapatma (migration'lar geri alınmaz, yeni kurallar anahtarla kapanır). |
| **Hata izleme** | Sunucu: yapılandırılmış JSON günlük, istek kimliği, kişisel veri maskeleme; Sentry (veya eşdeğeri) sunucu + Flutter. Alarm: `economy_errors` artışı, 5xx oranı, WebSocket bağlantı düşüşü, aktif maç sayısında "takılı" maç (deadline + 60 sn geçmiş). |
| **Sırlar** | `JWT_SECRET`, DB şifresi, imza anahtarı yalnız sır yöneticisinde/CI gizli değişkeninde. |
| **Açılış sırası** | (1) staging'de anahtarlar açık, 2 telefon testi; (2) üretimde migration'lar anahtarlar KAPALI; (3) geçmiş veri parmak izi üretim kopyasında; (4) onayla `economy_v2_enabled` → `ranked_rewards_v2` → `duel_v4`. Hiçbiri tam CI + onay olmadan açılmaz. |

## 8. Veri güvencesi

Bu çalışmada mevcut oyuncu verisi ve maç geçmişi **değiştirilmedi**: migration'lar yalnız yeni sürüm
satırı ekler (parmak izi kanıtı §1–2). Yerel testler geçici veritabanlarında çalışır ve silinir; uçtan uca
testler yalnız `*.local.txt` test hesaplarını kullanır, anahtarları test sonunda eski değerine döndürür.
