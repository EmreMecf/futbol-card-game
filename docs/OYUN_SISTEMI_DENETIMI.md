# Oyun sistemi denetimi (11 Kasım 2026)

Kapsam: migration 001–038, sunucu rotaları, istemci özellikleri, tasarım belgeleri ve
simülasyon sonuçları. Bu belge **bulgu listesidir**; hiçbir kural değiştirilmedi.
Kaynak sayılar: yerel veritabanı kataloğu ve `tool/ekonomi/karsilastirma.md`.

## A. Kritik (yayın öncesi çözülmeli)

| # | Bulgu | Kanıt | Öneri |
|---|---|---|---|
| A1 | **Gerçek kişi ve tescilli adlar.** 6 Efsane kart gerçek futbolcu adı; 7 lig adı tescilli | `cards`: Maradona, Pele, Cruyff, Beckenbauer, Yashin, Puskas; Bundesliga, La Liga, Serie A, Ligue 1, Eredivisie… | Kurgu adlara geçiş migration'ı (kart kimliği aynı kalır, yalnız ad/lig metni) |
| A2 | **Eşleştirme yalnız MMR.** Kadro gücü bandı (024) yazılı ama kapalı | `matchmaking_settings.mode = 'mmr'`; rapor: yeni oyuncunun ilk maçlarının ~%49'u umutsuz | `combined` moda almak (tek satır, geri alınabilir) |
| A3 | **İçerik çok az: 100 kart.** Koleksiyon hedefi bir ayda bitiyor | Simülasyon: günde 5 maçta 30. günde 86, 90. günde 95 farklı kart; Efsane 6, Elmas 12 | Katalogu büyütmek (en az 250–300) ya da kart varyantları; yoksa sandık/paket anlamsızlaşır |
| A4 | **Kalıcı kart kaybı hâlâ açık.** R1–R3 (037) yazıldı ve testli ama anahtar kapalı, commit edilmedi | `git status`; `ranked_rewards_v2 = false` | Tam test turundan sonra commit; açma kararı ayrı |
| A5 | **Yeni oyuncu akışı yok.** Öğretici, alıştırma maçı ve bot yok | `lib/` içinde öğretici yok; eşleştirmede bot yok | 3 adımlı öğretici + oyuncu azken bot rakip (derecesiz) |

## B. Sistemler arası tutarsızlık

| # | Bulgu | Neden sorun | Öneri |
|---|---|---|---|
| B1 | **İki ayrı kart kaynağı, iki ayrı "kopya".** Paket fiziksel kopya verir, sandık gelişim kopyası | Oyuncu aynı kartın neden bazen kart bazen kopya geldiğini anlayamaz | Paketi de sandık kuralına bağlamak (sahip olunan kart → gelişim kopyası) ya da paketi kaldırıp altınla sandık |
| B2 | **Kopya dönüşümünde "2 kopya kalsın" kuralı** kayıpsız düzende gereksiz | `convert_keep: 2` kart kaybına karşı yedekti | R2 açılınca 1'e indirmek |
| B3 | **Koruma hakkı ölü sisteme dönüşüyor.** R2 ile işlevi kalmıyor ama profilde "KORUMA 8/10" duruyor | `profile_view.dart` koşulsuz gösteriyor | Yeni kuralda gizlemek; ileride "riskli mod"a saklamak |
| B4 | **Seviyenin karşılığı zayıf.** Altın kartı 10. seviyeye çıkarmak 13.725 altın + 61 kopya; ödülü toplam 1.200 altın ve bir rozet | `level_rules`: ustalık 5→200, 10→1.000; K1 gereği güç yok | Seviye başına görünür ödül: kart çerçevesi (5/10), ustalık kozmetiği, seviyeye özel görev; güç yine yok |
| B5 | **Altının harcanacağı yer bitiyor.** Koleksiyon dolunca tek gider seviye | Gelir günde 200–1.400; mağazada paket dışı sekmeler "yakında" | Altınla kozmetik mağazası, haftalık dönen teklif, sandık anahtarı satışı |
| B6 | **Yenilgi 0 altın, MMR sabit ±25.** Rakibin puanı hesaba girmiyor | `_finish_match`: `mmr ± 25`, `coins + 100` | Yenilgiye küçük teselli altını; MMR'yi puan farkına duyarlı yapmak (ayrı onay: düello kapsamı) |
| B7 | **Ligin ödülü ve sezonu yok.** 12 basamak var, sıfırlama ve lig ödülü yok; Battle Pass sezonuyla bağlı değil | 019: yalnız eşik tablosu | Sezon sonu lig ödülü + yumuşak sıfırlama; iki "sezon"u tek takvime bağlamak |
| B8 | **1000 puanın altı tanımsız.** En alt lig 1000'de başlıyor, oyuncu aşağı düşebiliyor | `league_tiers.min_mmr` en düşük 1000; kullanıcılarda en düşük 875 | En alt ligi 0'dan başlatmak |
| B9 | **Başarımlar yalnız istemcide, ödülsüz, 6 adet** | `profile/domain/achievements.dart` | Sunucuya taşıyıp ödül bağlamak (sezon XP / kozmetik) |
| B10 | **İki farklı "enerji".** Maç içi taktik enerjisi ve ödül enerjisi | Aynı kelime, farklı sistem | Ödül enerjisine ayrı ad ("Sandık hakkı" gibi) |
| B11 | **"Görevler" iki yerde.** Menüdeki Görevler kart görevine (SBC) gidiyor; gerçek görevler Sezon Yolu'nda | `app_shell.dart` → `AppRoutes.sbc` | SBC'yi "Kart Takası" yapmak, Görevler'i sezona bağlamak |
| B12 | **Mobilde dağınık giriş.** Sezon yalnız ana sayfa kartından, Envanter profilden, Gelişim koleksiyondan, Sandık ana sayfa şeridinden | Alt menü 5 sekme | Ana sayfada tek "ilerleme" şeridi ya da Profil altında toplu menü |
| B13 | **Battle Pass tek sezonluk içerik.** 8 kozmetik var, Sezon 2 tablosu yok; günde 2 maç oynayan 26/50'de kalıyor | `season_rules` v1; `bp_inceleme` | Sezon 2 ödül sürümü; hafif oyuncu için "hafta sonu çift XP" gibi yakalama mekaniği |
| B14 | **Etkinlik bileti ölü item** | Mod yok; 038'de pasif | Etkinlik modu tasarlanana kadar katalogdan çıkarılmış sayılır |

## C. Düello tarafında açık kararlar (hepsi ayrı onay ister)

| # | Bulgu | Kanıt |
|---|---|---|
| C1 | Turu ilk açan dezavantajlı (%44,5 kazanma) | `REKABET_ANALIZI_RAPORU.md` §2; öneri: ilk tur kör cevap |
| C2 | Efsane kart mutlak üstün: Efsane olmayan hiçbir kart yenemiyor | `compare_cards`; 6 Efsane kart |
| C3 | Taktik kullanmayan oyuncu belirgin dezavantajlı | `BAGIMSIZ_INCELEME_RAPORU.md` §4 |

## D. Eksik parçalar

- Ses ve müzik yok (Ayarlar'da "yakında").
- Gerçek telefonda FPS/bellek ölçümü yapılmadı.
- Kart satışı (020) yarım; R2 sonrası gerekip gerekmediği karara bağlı.
- Rakibin kozmetikleri maçta görünmüyor.
- Premium Battle Pass ve ödeme (FAZ 5) yok; K4 gereği bilinçli.

## Önerilen sıra

1. A4: bekleyen 037/038 işini tam testle bitirip commit.
2. A2 + B8: eşleştirme modu ve lig tabanı (küçük, geri alınabilir).
3. A1: kurgu ad geçişi.
4. B1–B3: kart kaynaklarını tek kurala bağlamak (R2 ile birlikte).
5. A5: öğretici + bot.
6. A3 + B13: içerik (kart kataloğu, Sezon 2).
7. B4–B7, B9: ilerleme ve ödül döngüsü.
