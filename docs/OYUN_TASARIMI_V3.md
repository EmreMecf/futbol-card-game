# Oyun tasarımı V3 — "her gün geri gelinen strateji oyunu" (11 Kasım 2026)

**Durum: TASARIM. Kod değişmedi.** Kararlar (kullanıcı, 11 Kasım 2026):
1. Maç: iki oyuncu kartını **aynı anda gizli** seçer, tur süresi kısalır. ✅
2. Seviye: **sınırlı güç (B)**. ✅ — bu, K1'in ("seviye güce etki etmez") yerine geçer.
3. Sosyal katman (kulüp) şimdilik **yok**; önce tek oyunculu döngü. ✅

Ölçümler: `tool/ekonomi/duello_v3.py` → `tool/ekonomi/duello_v3.md` (4.000 maç / hücre).
Denetim bulguları: `docs/OYUN_SISTEMI_DENETIMI.md`.

## 1. Maç (kural sürümü 4)

| | Bugün (sürüm 2/3) | V3 (sürüm 4) |
|---|---|---|
| Tur akışı | Açan kartını açık oynar, rakip görerek cevaplar | İnisiyatif sahibi yalnız **mevkiyi** seçer (5 sn); iki oyuncu o mevkiden **kart + taktiği aynı anda gizli** seçer (15 sn); birlikte açılır |
| Uyamama | Mevkide kart yoksa pas, tur kaybedilir | Yok: iki kadro da 1-4-4-2 olduğundan her mevkide eşit kart var |
| İnisiyatif | Turu kazanan açar; beraberlikte karşıya geçer | Aynı (turu kazanan mevkiyi seçer) |
| Bitiş | 22 kart bitince | Bir oyuncu **12 kart** topladığında erken biter (çoğunluk) |
| Süre aşımı | 45 sn + 15 sn, sonra hükmen yenilgi | Mevki seçilmezse en çok kartın olduğu mevki; kart seçilmezse o mevkideki **en zayıf kart taktiksiz** oynanır. **Üst üste 2 turda** kartı otomatik oynanan hükmen kaybeder (otomatik mevki sayılmaz, elle mevki seçmek sayacı sıfırlar) |
| Değişmeyen | Efsane kuralı, kimya, beraberlikte kartların ortada kalması, taktikler ve enerji (2 başlar, +1/tur, en fazla 5) | — |

Savunma Duvarı'nın "savunurken +6 / açarken +2" kuralı aynen: inisiyatifi olmayan +6, olan +2.

**Ölçülen:**

| Ölçü | Bugün | V3 | Hedef |
|---|---|---|---|
| İlk inisiyatifin puanı (akıllı oyuncular) | %43,4 | **%47,6** | %45–55 |
| İlk inisiyatifin puanı (taktiksiz) | %46,0 | **%50,7** | %45–55 |
| Ortalama tur | 11 | 9,7 (6–11) | — |
| En uzun maç (süre sınırı) | 16,5 dk | **3,7 dk** | ≤ 4 dk |
| Tipik maç (sürenin %60'ı) | ~9,9 dk | **~1,9 dk** | 2–3 dk |

**Açık risk:** benzer güçte kadrolarda taktik kullanmayan oyuncu %13 puanda kalıyor
(bugünkü raporda %32). Taktikler eş zamanlı düzende daha belirleyici; bu bir strateji oyunu
için istenen şey ama **öğretici zorunlu** (Faz 3) ve taktik sayıları Faz 1'de prototipte
(`packages/tactics_prototype`) yeniden dengelenmeli.

**Taktik dengesi (Faz 1 ölçümü, `tool/ekonomi/denge_ara.py`):** eş zamanlı düzende 1 enerjili
Savunma Duvarı her stratejiyi yeniyordu ("hep duvar" %84 akıllı oyuncuya karşı). **Duvar 2 enerji**
yapıldı (yalnız sürüm 4): döngü korunuyor (pres > duvar %60, duvar > kontra %88, kontra > pres %75),
akıllı oyuncu taktiksize karşı %80.

### Faz 1 durumu: ✅ uygulandı (039, anahtar `duel_v4` KAPALI)

- Migration `039_duel_v4.sql` (`tool/ekonomi/migration_uret_039.py` ile mevcut gövdelerden üretildi):
  kural sürümü 4, `choose_position`, gizli `play_card`, `advance_simultaneous_matches` (sunucu saniyede
  bir çağırır), 12 kartta erken bitiş. Sürüm 1–3 maçlar aynen.
- Sunucu: `POST /api/match/<id>/position`; `/moves` sürüm 4'te rakibin bu turdaki hamlesini (kart dahil)
  tur çözülene kadar **hiç** göndermez.
- İstemci: mevki seçici, gizli seçim / rakip bekleniyor yazıları, taktik maliyeti maçın sürümünden.
- Testler: `039_duel_v4_test.sql`, ViewModel (5), ekran görüntüleri (`duello_v4_golden_test.dart`),
  gerçek sunucuda `tool/ekonomi/duello_v4_e2e.mjs` (REST + WebSocket gizliliği, zamanlayıcı, erken
  bitiş, ödüller), paralel oturum yarış testi `scripts/esz-zamanli-yaris-testi.sh`.
- Sunucu/WebSocket/animasyon/süre aşımı tasarımı, staging ve üretim planı:
  `docs/V3_UYGULAMA_VE_STAGING_PLANI.md`.
- Açma sırası: `economy_v2_enabled` + `ranked_rewards_v2` + `duel_v4` üçü birlikte açıkken yeni maçlar sürüm 4.

## 2. Seviye gücü (B) ve adalet

Simülasyon: bütün kartlara +1 güç = %70, +2 = %83, +3 = %93 kazanma (aynı kadro). Yani bonus
küçük tutulmalı ve **eşleştirme seviyeyi görmeli**.

| Eğri | Seviye 4 | Seviye 7 | Seviye 10 |
|---|---|---|---|
| B1: seviye // 2 (en fazla +5) — puana göre eşleşme | %81,5 | %88,9 | %96,8 |
| **B2: L4 +1, L7 +2, L10 +3** — puana göre eşleşme | %66,1 | %80,0 | %87,8 |
| B1 — **etkin güce göre** eşleşme | %53,6 | %53,7 | %47,5 |
| **B2 — etkin güce göre eşleşme** | **%51,4** | **%53,0** | **%53,5** |

**Kural:**
- Seviye bonusu **B2**: 4. seviyede +1, 7. seviyede +2, 10. seviyede +3 (yalnız o kart).
- Eşleştirme `combined` moda alınır (024) ve kadro gücü **seviye bonusu dahil** hesaplanır.
  Seviyeli kadro daha güçlü rakiple eşleşir: oyuncu "güçlendim ve yükseldim" hisseder, ezme olmaz.
- Lig tavanı: Amatör 4, Usta 7, Master ve üstü 10. Tavanın üstündeki seviye o ligde sayılmaz.
- Efsane kuralı değişmez (seviye, Efsane olmayan kartın Efsane'yi yenmesini sağlamaz).

### Faz 2 durumu: ✅ uygulandı (040, anahtar `card_level_power` KAPALI)

- Migration `040_level_power.sql`: kural sürümü 5 = sürüm 4 + seviye gücü. Dört anahtar
  (`economy_v2_enabled`, `ranked_rewards_v2`, `duel_v4`, `card_level_power`) açıkken yeni maçlar sürüm 5.
- Bonus **tek kaynaktan**: `card_level_bonus(oyuncu, futbolcu, puan)` = B2(min(seviye, lig tavanı)).
  Hem `deck_power` (eşleştirme) hem maç eli (`match_hands.power`, maç kurulurken dondurulur) bunu kullanır.
- Lig tavanı maç **kurulurkenki** puana göre; maç içinde seviye atlansa ya da lig değişse de el aynı.
- Sürüm 5'te eşleştirme kendiliğinden `combined` (MMR + etkin kadro gücü); anahtar kapalıyken
  `matchmaking_settings.mode` aynen geçerli.
- `_create_match`, `play_card`, `_resolve_round`, `find_match`, taktik, kimya, Efsane kuralı ve MMR
  DEĞİŞMEDİ. Bonus bir `match_hands` tetikleyicisiyle eklenir; hangi kartın hangi seviye/tavanla ne aldığı
  `match_hand_level_bonus` tablosunda (eski `match_hands` satırlarına sütun eklenmedi).
- Testler: `database/tests/040_level_power_test.sql` (7 kabul şartı + sürüm 5 maçı sonuna kadar),
  `tool/ekonomi/test_seviye_eslestirme.py`, gerçek sunucuda `SURUM=5 node … duello_v4_e2e.mjs`.
- İstemci değişmedi: el kartında görünen güç zaten bonus dahil (`get_my_hand` → `match_hands.power`).
  Kartın üstünde ayrıca "+N" rozeti göstermek ayrı bir arayüz işi.

## 3. Kupa yolu (lig = ilerleme yolu)

- 12 lig basamağının her biri **bir kez** ödül verir: sandık + altın; lig değişiminde kozmetik.
- En alt basamak 0 puandan başlar (bugün 1000'in altı tanımsız).
- Kart havuzu basamakla açılır: Amatör Bronz–Altın, Usta + Elmas, Master + Efsane sandık ihtimali.
  100 kartlık katalog böylece bir ayda tükenmez.
- Sezon sonu: Usta ve üstü bir basamak geri (yumuşak sıfırlama) + sezon ligi ödülü. Battle Pass
  sezonuyla aynı takvim.

### Faz 4 durumu: ✅ uygulandı (043, anahtarlar `trophy_road` ve `league_season_reset` KAPALI)

Kullanıcı kararları (13 Kasım 2026): önerilen ödül tablosu, **geriye dönük ödül yok**, sezon sonu yumuşak
sıfırlama + ödül, **kart havuzu kuralı şimdilik yok** (sandık şansları değişmedi).

| Basamak | İlk ulaşılınca (bir kez) |
|---|---|
| Amatör 1 | Başlangıç, ödülsüz |
| Amatör 2-3 | Gümüş sandık + 50 altın |
| Usta 1 | Altın sandık + 100 altın + **Usta çerçevesi** |
| Usta 2-3 | Altın sandık + 100 altın |
| Master 1 | Altın sandık + 200 altın + **Master çerçevesi** |
| Master 2-3 | Altın sandık + 200 altın |
| Master Class 1 | Efsane sandık + 300 altın + **Master Class çerçevesi** |
| Master Class 2-3 | Efsane sandık + 300 altın |

- Ödül tablosu `economy_config_versions` (tür `trophy_road`, sürüm 1); ileride yeni sürüm satırıyla değişir.
- Geriye dönük yok: oyuncunun şimdiye kadar ulaştığı en yüksek basamak (şu anki puan ve maç
  kayıtlarındaki önce/sonra puanları) ödülsüz sayılır. Düşüp yeniden çıkmak ödül vermez.
- **Sezon sonu** (Sezon Yolu kapanınca): o sezon en az bir dereceli maç bitiren oyuncu bitiş ligine göre
  ödül alır (Amatör Gümüş, Usta Altın, Master Altın + 200 altın, Master Class Efsane). Usta ve üstü
  herkesin puanı bir alt basamağın tabanına iner; Amatör'e dokunulmaz. Her sonuç `season_league_results`'ta.
- Botlar ödül ve sıfırlama görmez. Maç, MMR ±25, eşleştirme ve sandık şansları değişmedi.
- Ligler ekranında her basamağın altında ödül ve durum (✅ alındı · 🔒 kilitli · — açılıştan önce).
- "En alt basamak 0 puandan" maddesi uygulanmadı: `rank_for_mmr` zaten 1000'in altını Amatör 1 sayıyor;
  eşik tablosunu değiştirmek ilerleme çubuğunu herkes için değiştirirdi.
- Testler: `database/tests/043_trophy_road_test.sql`, `test/trophy_road_test.dart`, gerçek sunucuda
  `tool/ekonomi/kupa_yolu_e2e.mjs`.

## 4. Yeni oyuncu ve tek oyunculu döngü

- **Öğretici:** 3 kısa maç (mevki → gizli seçim → taktik), sonunda bir Gümüş sandık.
- **Bot rakip:** ilk 5 maç ve 20 sn'de rakip bulunamadığında; kadro gücü oyuncuya denk; puan ve
  ödül normal (Clash Royale'in düşük kupa botları gibi), bot olduğu belirtilmez.
- **Antrenman modu:** bota karşı ödülsüz, taktik denemek için.

### Faz 3a durumu: ✅ bot + antrenman uygulandı (041, anahtarlar `bots_v1` ve `training_mode` KAPALI)

Kullanıcı kararı (13 Kasım 2026) tasarımı şöyle netleştirdi:

| | Antrenman botu | Eşleştirme botu |
|---|---|---|
| Ne zaman | Oyuncu "Antrenman" düğmesine basınca, hemen | Derecelide **20 sn** rakip bulunamazsa |
| Rakip adı | **"Bot"** (sunucu gösterir) | **Rastgele** kullanıcı adı |
| Puan / ödül | **Yok** (MMR, altın, G/M/B, sandık, sezon XP'si yok; geçmişe girmez) | **Normal** (±25, altın, sandık, geçmiş) |

- "İlk 5 maç bot" kuralı UYGULANMADI (kullanıcı yalnız "rakip bulunamazsa" dedi).
- Eşleştirme botu yalnız kart transferi olmayan kural sürümünde (3+) gelir: bota kart kaybetmek ya da
  bottan üretilmiş kart kazanmak ekonomiyi bozardı.
- Bot kadrosu her maçta rakibin kadrosuna göre kurulur: aynı mevki ve sınıf, etkin güç ±3.
- Bot yalnız kendi elini görür, 2-5 sn "düşünür", sunucu zamanlayıcısı saniyede bir `bot_tick()` çağırır.
  Hem eş zamanlı (sürüm 4/5) hem sıralı (sürüm 2/3) kurallarla oynar.
- Botlar liderlik tablosunda görünmez; bot havuzu yeniden kullanılır (son 5 rakip tekrar gelmez).
- `find_match`, `_create_match`, `play_card`, `_resolve_round`, taktik, kimya ve MMR değişmedi. `_finish_match`
  037 gövdesinden aynen alındı; yalnız antrenman bloğu eklendi.
- Testler: `database/tests/041_bots_training_test.sql`, ViewModel (2), gerçek sunucuda `tool/ekonomi/bot_e2e.mjs`.

### Faz 3b durumu: ✅ öğretici uygulandı (042, anahtar `tutorial_v1` KAPALI)

| Adım | Ders | Kural sürümü | Not |
|---|---|---|---|
| 1 | Mevki seçimi | 6 (taktiksiz) | İlk mevkiyi oyuncu seçer |
| 2 | Gizli seçim | 6 (taktiksiz) | |
| 3 | Taktik | 7 (taktikli) | Bitince **tek sefer Gümüş sandık** |

- Sürüm 6/7 = sürüm 4 akışı, yalnız veri farkı: **6 kartta** biter, mevki 15 sn, seçim 30 sn.
  Düello kodu değişmedi.
- Rakip "Bot", kadrosu oyuncununkinden ~6 güç zayıf. Maçlar ödülsüz ve puansız, maç geçmişine girmez.
- Adım sayılır: maç biter, en az 3 tur oynanır, oyuncu süre aşımıyla düşmez (kaybetmek de sayılır).
- Yalnız eş zamanlı kurallar canlıyken (sürüm 4/5) açılır.
- Maç ekranında adıma ve aşamaya göre ipucu paneli; hazırlık ekranında "ÖĞRETİCİ · ADIM n/3" kartı.
- **041 düzeltmesi:** galibiyet gelişim kopyası (R3) antrenman maçında da veriliyordu; artık yalnız
  dereceli. Taktiksiz sürümde (6) eş zamanlı akış taktiği kaydetmeden reddediyor.
- Testler: `database/tests/042_tutorial_test.sql`, ViewModel (3), ipucu (6), gerçek sunucuda
  `tool/ekonomi/ogretici_e2e.mjs`.
- **Günlük döngü:** ücretsiz günlük sandık, günün ilk galibiyeti çift XP, dönen mağaza teklifi.
- **Hafta sonu etkinliği:** özel kurallı kısa turnuva (yalnız Bronz, çift enerji gibi), giriş
  etkinlik biletiyle (ölü item canlanır).

## 5. Sadeleştirme

- Paket de sandık kuralına bağlanır: sahip olunan kart → gelişim kopyası (iki ayrı "kopya" biter).
- Kalıcı kart kaybı kalkar (037 hazır); koruma hakkı ekrandan kalkar.
- "Ödül enerjisi" adı değişir (taktik enerjisiyle karışmasın).
- Menü: "Görevler" Sezon Yolu'na gider; kart görevi (SBC) "Kart Takası" olur.

## 6. Fazlar (her biri ayrı test + onay)

| Faz | Kapsam | Düelloya dokunur mu |
|---|---|---|
| 0 | Bekleyen 037/038'i tam testle bitirmek | Hayır (yalnız maç sonu) |
| 1 | Sürüm 4 düello: prototipte denge → migration → sunucu → maç ekranı (gizli seçim, 5+15 sn) | **Evet** |
| 2 | Seviye bonusu B2 + etkin güce göre eşleştirme + lig tavanı (✅ 040, kapalı) | **Evet** (güç hesabı) |
| 3 | Öğretici + bot + antrenman (✅ 041 + 042, anahtarlar kapalı) | Hayır |
| 4 | Kupa yolu ödülleri, lig tabanı, sezon sıfırlaması (✅ 043, kapalı; kart havuzu kuralı yok) | Hayır |
| 5 | Günlük döngü, etkinlik, mağaza teklifleri, sadeleştirmeler | Hayır |

Hepsi yeni kural sürümü ve varsayılan kapalı anahtarlarla; süren maçlar eski kuralla biter.
