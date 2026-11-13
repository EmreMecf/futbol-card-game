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

## 4. Yeni oyuncu ve tek oyunculu döngü

- **Öğretici:** 3 kısa maç (mevki → gizli seçim → taktik), sonunda bir Gümüş sandık.
- **Bot rakip:** ilk 5 maç ve 20 sn'de rakip bulunamadığında; kadro gücü oyuncuya denk; puan ve
  ödül normal (Clash Royale'in düşük kupa botları gibi), bot olduğu belirtilmez.
- **Antrenman modu:** bota karşı ödülsüz, taktik denemek için.
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
| 3 | Öğretici + bot + antrenman | Hayır |
| 4 | Kupa yolu ödülleri, lig tabanı, sezon sıfırlaması | Hayır |
| 5 | Günlük döngü, etkinlik, mağaza teklifleri, sadeleştirmeler | Hayır |

Hepsi yeni kural sürümü ve varsayılan kapalı anahtarlarla; süren maçlar eski kuralla biter.
