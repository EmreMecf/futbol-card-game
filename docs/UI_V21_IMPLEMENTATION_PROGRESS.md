# Futbol Card Arena — V2.1 Flutter UI dönüşümü: ilerleme raporu

**Faz:** 1–3 (ilk görev + Koleksiyon), Faz 2 (temel tasarım sistemi, §10), Faz 3 (Kadrom, Mağaza, Sezon, §11), Faz 4 (iç ekranlar, §12), Faz 5 (paket, sandık, kart, maç sonu, §13), Faz 6 (sıralama, kadro kurma, olasılıklar, maç sonu panelleri, §14), Faz 7 (öğretici ipucu, kadro uyarısı, walkout, açılış, §15), Faz 8 (Maça Hazırlan, rakip arama, canlı arena, §16), hedef platform: yalnız telefon/tablet dikey (§17) · **Dal:** `feature/ui-v21-rebuild` · **Tarih:** 2026-11-17
**Durum:** Commit edilmedi. Değişiklikler yerelde duruyor; GitHub Desktop'tan commit edilecek.

Bu fazın kapsamı: referans HTML'nin envanteri, mevcut ekranlarla eşleşme tablosu, `lib/ui_v21/` altında bağımsız V2.1 tasarım sistemi (8 temel bileşen + 2 yardımcı bileşen) ve gerçek sunucu verisiyle çalışan **V2.1 Ana Sayfa** ile **V2.1 Koleksiyon (KARTLARIM)**. Eski Ref arayüzü silinmedi.

---

## 1. Referans HTML envanteri

**Kaynak:** `design/reference/FutbolCard_V21_Telefon_HTML_Prototip.html` (7,39 MB; `Downloads` klasöründen kopyalandı).
**Yapısı:** Tek dosyalık bir inceleme aracı. `VIEWS` dizisinde 38 görünüm, `HOTSPOTS` haritasında tıklama bölgeleri, `SIM` nesnesinde 5 HTML demo modalı var. Figma ekranları **tam ekran 390×844 PNG** olarak gömülü. Prototip bu görsellerin üstüne görünmez düğmeler koyuyor. Flutter tarafında bu yöntem **kullanılmadı**.

Makine tarafından okunabilir döküm: `design/reference/v21_screens_manifest.json` (her ekranın kimliği, grubu, kaynağı, boyutu ve tıklama bölgeleri). Yeniden üretmek için:

```bash
dart run tool/v21/extract_reference.dart
```

Tarayıcıda 390×844 incelemek için `.claude/launch.json` → `v21-referans` (`dart run tool/v21/serve_reference.dart 5591`) eklendi.

### 1.1 Ekranlar

| # | id | Ekran | Grup | Kaynak | Geçişler (hotspot) |
|---|---|---|---|---|---|
| 1 | login | Giriş | Hesap | Figma PNG (gömülü) | → home |
| 2 | home | Ana Sayfa | Ana Akış | Figma PNG | → matchPrep, profile, collection, chests, league, season; alt menü |
| 3 | collection | Koleksiyon (Kartlarım) | Kartlar | Figma PNG | → cardModal, progress; alt menü |
| 4 | deck | Kadrom | Kartlar | Figma PNG | → deckModal, matchPrep; alt menü |
| 5 | arena | Canlı Arena (kart seçimi) | PvP | Figma PNG | → hf8, hf9, hf10 |
| 6 | win | Zafer | PvP | Figma PNG | → home, matchPrep |
| 7 | store | Mağaza | Ekonomi | Figma PNG | → packSeal, chests, sbc; alt menü |
| 8 | chests | Sandıklar | Ekonomi | Figma PNG | → packSeal; alt menü |
| 9 | packSeal | Paket Mührü | Ekonomi | Figma PNG | → packLegend |
| 10 | packLegend | Efsane Açılış | Ekonomi | Figma PNG | → store |
| 11 | league | Lig Yolu | İlerleme | Figma PNG | → season; alt menü |
| 12 | profile | Profil | Oyuncu | Figma PNG | → settings, league; alt menü |
| 13 | settings | Ayarlar | Oyuncu | Figma PNG | → login (çıkış); alt menü |
| 14 | season | Sezon Yolu | İlerleme | Figma PNG | → chests, league; alt menü |
| 15 | progress | Kart Gelişimi | Kartlar | Figma PNG | → cardModal, collection; alt menü |
| 16 | inventory | Envanter | Ekonomi | Figma PNG | → itemModal; alt menü |
| 17 | sbc | Kart Takası | Ekonomi | Figma PNG | → sbcModal; alt menü |
| 18 | hf0 | Arkadaşınla Oyna — Giriş | P0 Arkadaşlar | **Uzak** (Higgsfield/CloudFront) | → hf1, hf2 |
| 19 | hf1 | Özel Maç — Oda Sahibi | P0 Arkadaşlar | Uzak | → hf2 |
| 20 | hf2 | Özel Maç — Misafir | P0 Arkadaşlar | Uzak | → hf7 |
| 21 | hf3 | Rakip Aranıyor — İlk 10 sn | P0 Eşleştirme | Uzak | → hf4 |
| 22 | hf4 | Arama Genişletildi — 20–30 sn | P0 Eşleştirme | Uzak | → hf5 |
| 23 | hf5 | Rakip Bulunamadı — 60 sn | P0 Eşleştirme | Uzak | → hf3 |
| 24 | hf6 | Bağlantı Kontrol Ediliyor | P0 Eşleştirme | Uzak | → hf3 |
| 25 | hf7 | PvP — Mevki Seçimi | P0 PvP | Uzak | → hf8 |
| 26 | hf8 | PvP — Gizli Kart Seçimi | P0 PvP | Uzak | → hf9 |
| 27 | hf9 | PvP — Taktik ve Enerji | P0 PvP | Uzak | → hf10 |
| 28 | hf10 | PvP — Rakip Bekleniyor | P0 PvP | Uzak | → win |
| 29 | hf11 | PvP — Maça Yeniden Bağlanma | P0 PvP | Uzak | → hf7 |
| 30 | hf12 | Öğretici — Mevki (1/3) | P1 Öğretici | Uzak | → hf13 |
| 31 | hf13 | Öğretici — Kart (2/3) | P1 Öğretici | Uzak | → hf14 |
| 32 | hf14 | Öğretici — Taktik (3/3) | P1 Öğretici | Uzak | → home |
| 33 | hf17 | Kadro — Geçersiz Kadro Uyarısı | P1 Kadro | Uzak | → deck |
| 34 | matchPrep | Maça Hazırlan | demo | HTML demo (görsel yok) | → hf3, hf0, hf12, deck |
| 35 | cardModal | Oyuncu Kartı modalı | demo | HTML demo | → progress, deck, collection |
| 36 | deckModal | Oyuncu Değiştir modalı | demo | HTML demo | → collection, deck |
| 37 | itemModal | Eşya ayrıntısı modalı | demo | HTML demo | → inventory |
| 38 | sbcModal | Kart takası onayı | demo | HTML demo | → sbc, collection |

> Not: `hf15` ve `hf16` numaraları prototipte yok (atlanmış). Kaynakta bunlara karşılık bir ekran bulunmuyor.

### 1.2 Ortak öğeler

| Öğe | Nerede | Not |
|---|---|---|
| **Üst başlık** | home, profile (benzeri), diğer ekranlarda yerine sayfa başlığı + kaynak hapı | Seviye dairesi + ad + XP çubuğu + altın hapı |
| **Sayfa başlığı** | collection, deck, store, chests, league, settings, season, progress, inventory, sbc | Sol mavi "‹" geri düğmesi + büyük beyaz başlık + sağda kaynak hapı |
| **Alt menü** | 15 Figma ekranının 12'sinde | KARTLAR · KADRO · ARENA · MAĞAZA · SEZON. Etkin madde mavi, 12 px yükseltilmiş karo. Ana sayfa = ARENA |
| **Kaynak hapları** | altın (home, store, progress), kart sayısı (collection), güç (deck), kupa (league), süre (season) | Koyu hap + simge + kalın sayı |

### 1.3 Düğme tipleri

| Tip | Örnek | Renk |
|---|---|---|
| Ana altın (3B dudaklı) | MAÇA BAŞLA, GİRİŞ YAP, DEVAM, YENİ MAÇ | sarı → turuncu, kahverengi metin gölgesi |
| Mavi | ANA MENÜ, AYARLAR, JOKERLE ATLA, ÇIKIŞ YAP | açık mavi → mavi |
| Yeşil | OTOMATİK DİZ, AÇ!, SEVİYE ATLA, BAŞLA, TÜMÜNÜ AL | açık yeşil → yeşil |
| Soluk mor (pasif) | KADROYU DÜZENLE (demo), kilitli | mor-gri |
| Hap / filtre | TÜMÜ, GK/DEF/MID/FWD, PAKETLER/TEKLİFLER/KOZMETİK | kenarlı hap; seçili sarı dolgu |
| Yuvarlak geri | ‹ (10 ekranda) | mavi daire + alt dudak |
| Anahtar (toggle) | Ayarlar | yeşil / gri |

### 1.4 Kart çerçeveleri (Koleksiyon, Kadro, Arena, Paket)

Kalın nadirlik kenarı (Efsane mor, Elmas camgöbeği, Altın sarı, Gümüş gri, Bronz turuncu), sol üstte taşan güç dairesi, sağ üstte mevki hapı, tam portre ve altta ad plakası ("★ NADİRLİK ★"). Kadro ve Arena'da aynı çerçevenin küçük hâli, rakip kartı mor arka yüz ve "?" ile çiziliyor.

### 1.5 Animasyonlar

PNG ekranlarında hareket yok. HTML'de yalnız düğme `:active` basılma (3 px aşağı), toast ve ekran geçişleri var. Tasarım dilinden çıkarılan ve V2.1'de yazılanlar:

* Düğme basılma
* Hazır sandık nabzı
* İlerleme çubuğu dolumu
* Hata titreşimi
* Giriş süzülmesi

Ekran tasarımından anlaşılan ama henüz yazılmayanlar (sonraki fazlar):

* Paket mührü kırma ve efsane ışın patlaması
* Zafer konfetisi
* VS çarpışması
* Arama radarı

### 1.6 Görseller

| Durum | Görseller |
|---|---|
| **Gömülü (çıkarıldı)** | 17 Figma ekranı, `assets/v21/screens/*.png` (390×844, 1×). **Uygulamaya paketlenmez**, yalnız karşılaştırma referansı |
| **Uzaktan yüklenen** | 16 Higgsfield V2.1 ekranı (hf0–hf14, hf17) CloudFront URL'leri. **İndirilmedi.** URL'ler manifestte. Bağlantı yoksa prototip HTML yedeği gösteriyor |
| **Tekrar kullanılan** | Maskot "Efsane Kaptan" (login, home, collection, packLegend, win), altın sandık (home, store, chests, season, league, sbc), kart arka yüzü (packSeal, arena, alt menü KARTLAR), kadro portresi (alt menü, deck, sbc), stadyum (home, arena, alt menü ARENA) |
| **Eksik (katmanlı kaynak yok)** | Tüm illüstrasyonlar yalnız ekran görüntüsünün içinde var: saydam maskot, stadyum zemini, sandık türleri (bronz/gümüş/efsane ayrı çizim yok, hepsi aynı altın sandık), oyuncu portreleri (Usta Kaleci, Altın Golcü, Sert Stoper…), envanter eşya simgeleri, lig kalkanları, sezon ödül simgeleri. **Tasarımcıdan 3× katmanlı PNG/SVG istenmeli** |

---

## 2. Eşleşme tablosu: V2.1 ↔ mevcut Flutter

| V2.1 ekranı | Mevcut Flutter (Ref UI) | V2.1 durumu | Not |
|---|---|---|---|
| home | `lib/features/home/presentation/view/home_view.dart` (`HomeView`) | ✅ **`lib/ui_v21/screens/home/v21_home_screen.dart`** | Rota bağlandı (`kV21Home`), eski ekran duruyor |
| login | `features/auth/presentation/view/login_view.dart` | ⏳ | Sosyal giriş PR #3 bu ekrana dokunacak |
| collection | `features/collection/presentation/view/collection_view.dart` | ✅ **`lib/ui_v21/screens/collection/v21_collection_screen.dart`** | Rota bağlandı (`kV21Collection`), eski ekran duruyor |
| cardModal | `features/collection/presentation/widgets/card_detail_sheet.dart` | ✅ V2.1 (Faz 5) | |
| deck, deckModal | `features/deck/presentation/view/deck_view.dart`, `widgets/formation_pitch.dart`, `card_picker_sheet.dart` | ✅ **`lib/ui_v21/screens/deck/v21_deck_screen.dart`** (Faz 3; deckModal = mevcut kart seçici) | `kV21Deck` |
| hf17 | `deck_view.dart` doğrulama uyarısı | ✅ V2.1 (Faz 7, Kadrom) | Eşleştirmedeki doğrulama PR #5 sonrası |
| matchPrep, hf3–hf6 | `features/matchmaking/presentation/view/matchmaking_view.dart` | ✅ V2.1 (Faz 8, `kV21Arena`) | PR #5 sonrası `searchWarning` bağlanmalı (§16.8) |
| hf0–hf2 | **Yok.** PR #6: `features/friends/friend_room_view.dart` | ⏳ | PR #6 birleşince V2.1'e taşınmalı |
| arena, hf7–hf11 | `features/match/presentation/view/match_view.dart`, `widgets/match_table.dart`, `tactic_widgets.dart`, `turn_timer.dart`, `arena/*` | ✅ V2.1 (Faz 8, `kV21Arena`) | Tek gizli hamle korundu; PR #6 arkadaş maçı uyarlaması gerekli (§16.8) |
| win | `features/match/presentation/widgets/match_result_view.dart` | ✅ V2.1 (Faz 5) | |
| hf12–hf14 | `features/match/presentation/widgets/tutorial_hint.dart` | ✅ V2.1 ipucu (Faz 7, `kV21Tutorial`) | Arena V2.1'e PR #6 sonrası; "ATLA" sunucuda yok |
| store | `features/store/presentation/view/store_view.dart` | ✅ **`lib/ui_v21/screens/store/v21_store_screen.dart`** (Faz 3) | `kV21Store` |
| packSeal, packLegend | `store/presentation/widgets/pack_seal_scene.dart`, `pack_reveal_view.dart`, `shared/widgets/walkout/*` | ✅ V2.1 (Faz 5) | |
| chests | `features/chests/presentation/view/chests_view.dart` | ✅ V2.1 (Faz 4, `kV21Inner`) | `V21ChestSlot` hazır |
| league | `features/leaderboard/presentation/view/league_tiers_view.dart` | ✅ V2.1 (Faz 4, `kV21Inner`) | Sıralama (`LeaderboardView`) ve sandık olasılıkları (`ChestOddsView`) Faz 6 |
| profile | `features/profile/presentation/view/profile_view.dart` | ✅ V2.1 (Faz 4, `kV21Inner`) | |
| settings | `features/settings/presentation/view/settings_view.dart` | ✅ V2.1 (Faz 4, `kV21Inner`) | |
| season | `features/season/presentation/view/season_view.dart` | ✅ **`lib/ui_v21/screens/season/v21_season_screen.dart`** (Faz 3) | `kV21Season` |
| progress | `features/progress/presentation/view/progress_view.dart` | ✅ V2.1 (Faz 4, `kV21Inner`) | |
| inventory, itemModal | `features/items/presentation/view/inventory_view.dart` | ✅ V2.1 (Faz 4, `kV21Inner`) | |
| sbc, sbcModal | `features/sbc/presentation/view/sbc_list_view.dart`, `sbc_builder_view.dart` | ✅ V2.1 (liste Faz 4, kadro kurma Faz 6; `kV21Inner`) | |
| (alt menü) | `shared/widgets/app_shell.dart` (`RefBottomNav`) | ✅ `V21BottomNavigation` | Şimdilik yalnız V2.1 ana sayfada. Diğer ekranlar eski kabukta |
| (üst başlık) | `app_shell.dart` (`RefPhoneHeader`) | ✅ `V21GameHeader` | |

**Bileşen eşleşmesi**

| V2.1 bileşeni | Eski karşılığı (`lib/shared/widgets/ref`, `game`) |
|---|---|
| `V21GameButton` | `RefCta`, `RefSecondaryButton`, `GameButton` |
| `V21PlayerCard` | `RefPlayerCard`, `PremiumPlayerCard` (portre çizicisi `AvatarPortrait` ortak) |
| `V21GameHeader` | `RefPhoneHeader` |
| `V21BottomNavigation` | `RefBottomNav` |
| `V21ResourcePill` | `RefPill` + `StatChip` |
| `V21GamePanel` | `RefCardPanel`, `GlassPanel` |
| `V21ProgressBar` | `RefBar`, `GameProgressBar` |
| `V21LeagueBadge` | `RefPill` (lig), `TierBadge` |
| `V21ChestSlot` (ek) | `ChestSlotTile` |

---

## 3. Oluşturulan ve değiştirilen dosyalar

### Yeni

```
lib/ui_v21/
  ui_v21.dart                         dışa aktarım (barrel)
  v21_flags.dart                      kV21Home (--dart-define=V21_HOME=false ile eski ana sayfa)
  foundation/v21_colors.dart          piksel örneklenmiş palet
  foundation/v21_typography.dart      Barlow Condensed (başlık/sayı) + Nunito (etiket)
  foundation/v21_metrics.dart         390×844 ölçüleri
  foundation/v21_assets.dart          görsel yolları
  theme/v21_theme.dart                V2.1 alt ağaç teması (AppTheme'i değiştirmez)
  utilities/v21_scale.dart            390 tuvalinden ekrana ölçek (genişlik + kısa ekran)
  utilities/v21_format.dart           2.450 · 1:23:45 · 6 sa · Türkçe büyük harf
  animations/v21_motion.dart          süreler, V21Pulse, V21EnterFade (animasyon azaltmaya uyar)
  components/v21_game_button.dart     normal/pressed/disabled/loading/success/error; altın/mavi/yeşil/mor/kırmızı; 4 boy
  components/v21_player_card.dart     nadirlik çerçevesi, güç dairesi, mevki hapı, ad plakası
  components/v21_game_header.dart     seviye dairesi + ad + çubuk + kaynak hapları
  components/v21_bottom_navigation.dart
  components/v21_resource_pill.dart
  components/v21_game_panel.dart      raised / slot / empty (kesikli)
  components/v21_progress_bar.dart    animasyonlu dolum
  components/v21_league_badge.dart    kalkan + altın panel
  components/v21_chest_slot.dart      (ek) boş/kapalı/açılıyor/hazır/yükleniyor
  components/v21_stadium_sky.dart     (ek) vektör gece göğü + projektörler
  components/v21_painters.dart        para, yıldız, kart simgesi, kesikli kenar, kalkan
  layouts/v21_screen_layout.dart      zemin + gövde + bindirmeli alt menü, tablet ortalama
  screens/home/v21_home_screen.dart   V2.1 ana sayfa
  screens/home/v21_home_nav.dart      alt menünün rotalara bağlanması
  screens/collection/v21_collection_screen.dart   V2.1 Koleksiyon (KARTLARIM)
  components/v21_filters.dart         V21PageTitle, V21FilterPill, V21RarityChip, V21OrbIcon
assets/v21/screens/*.png              17 referans ekran (PAKETLENMEZ)
assets/v21/illustrations/home_hero_stadium.png   home.png (0,146)-(390,558) kırpımı
assets/v21/icons/chest_gold.png                  sandık (zemini saydamlaştırıldı)
assets/v21/icons/nav_squad_portrait.png          alt menü KADRO
assets/v21/icons/nav_arena_stadium.png           alt menü ARENA
design/reference/FutbolCard_V21_Telefon_HTML_Prototip.html
design/reference/v21_screens_manifest.json
tool/v21/extract_reference.dart       HTML → PNG + manifest
tool/v21/serve_reference.dart         referansı 127.0.0.1'de sunar
test/ui_v21/v21_test_support.dart     yazı tipi yükleme, boyutlar
test/ui_v21/v21_home_test.dart        veri, sayaç, hata durumları, 7 boyut taşma + golden, referans farkı
test/ui_v21/v21_components_test.dart  bileşen davranışı + vitrin golden'ı
test/ui_v21/v21_collection_test.dart  veri, filtreler, arama, favoriler, sıralama, katalog hatası, boş durum, kilitli kart, ayrıntı, 7 boyut
test/ui_v21/v21_compare.dart          referans fark aracı (ekran + bölge parametreli)
test/ui_v21/goldens/*.png             15 golden
docs/ui_v21/compare/                  karşılaştırma çıktıları
docs/UI_V21_IMPLEMENTATION_PROGRESS.md
```

### Değişen

| Dosya | Değişiklik |
|---|---|
| `lib/core/router/app_router.dart` | Ana sayfa ve koleksiyon rotaları bayraklı (`kV21Home`, `kV21Collection`); 3 import. Dört açık PR'ın sürümüyle `git merge-file` denemesi: **çakışma yok** |
| `lib/features/collection/presentation/viewmodel/collection_view_model.dart` | Ekleme: `catalogSize`, `uniqueOwned`, `catalogProgress`, `loadCatalogSize()` (mevcut `fetchCatalog()`). Var olan davranış değişmedi; dört PR'la çakışma yok |
| V2.1 bileşenleri | `V21ResourcePill` hazır metin (`text`), `V21PlayerCard` kilitli durum (`locked`), `V21ScreenLayout` zemin seçimi (`background`, `V21Background.page`) |
| `pubspec.yaml` | `assets/v21/illustrations/`, `assets/v21/icons/` (bağımlılık eklenmedi) |
| `.claude/launch.json` | `v21-referans` yapılandırması |

`analysis_options.yaml` ve `pubspec.lock` bu görevden önce de değiştirilmiş durumdaydı (bu oturumun değişikliği değil).

**Dokunulmayanlar:** backend (`server/`), migration'lar, ekonomi kuralları, WebSocket protokolü, `HomeView`, `CollectionView` ve tüm Ref UI dosyaları.

---

## 4. Ana sayfa: bağlanan API'ler (hepsi mevcut ViewModel/repository)

| Ekran öğesi | Kaynak | Uç nokta |
|---|---|---|
| Kullanıcı adı, altın | `SessionManager.user` (+ `AuthViewModel.refreshProfile()` açılışta) | `/api/auth/me` |
| Lig kodu "M2", "MASTER 2", puan, ilerleme | `HomeViewModel.rank` → `LeaderboardRepository.fetchMyRank` | `/api/leaderboard/rank` |
| Seviye dairesi + XP çubuğu | `SeasonViewModel.overview.tier / tierProgress` (sezon kademesi) | `/api/season` |
| 4 sandık yuvası, sayaç, süreler | `ChestsViewModel` (sunucu saati farkıyla sayaç, WebSocket `chest_granted` ile tazeleme, `chestInventoryChanged`) | `/api/chests` |
| MAÇA BAŞLA / MAÇA DÖN | `AuthViewModel.activeMatchId` | `/api/auth/me` |

**Yedek davranışlar (sahte veri yok):**

* Sezon kapalı ya da yok: dairede kişi simgesi gösterilir, çubuk çizilmez.
* Lig yüklenemedi: "LİG" yazılır; sayı ve kod yer tutucu olur.
* Ekonomi kapalı: sandık şeridi hiç çizilmez.
* Sandıklar yükleniyor: 4 iskelet yuva gösterilir.
* Altın bilinmiyor: "—" gösterilir.

**Dokunma hedefleri:**

| Hedef | Gittiği ekran |
|---|---|
| Profil (daire + ad) | `/profil` |
| Altın | `/magaza` |
| Lig rozeti | `/ligler` |
| Sandık yuvası | `/sandiklar` |
| Alt menü | `/koleksiyon`, `/kadro`, `/ana-sayfa`, `/magaza`, `/sezon` |

**Eski ana sayfadan V2.1'de olmayanlar** (referansta yok): kadro/kart/paket karoları, günlük görevler, lig ilerleme kartı, devam eden maç kartı. Devam eden maç bilgisi "MAÇA DÖN" düğmesine taşındı, görevler SEZON sekmesinde.

---

## 5. Görsel karşılaştırma (390×844)

* Referans: `assets/v21/screens/home.png`. Tarayıcı ekran görüntüsü `docs/ui_v21/compare/reference_html_browser_390x844.jpg`. HTML bu PNG'yi 1:1 çiziyor (img 0,0–390,844, ölçek 1).
* Flutter: `docs/ui_v21/compare/home_390x844_flutter.png` (golden testteki sahte depolar referanstaki veriyi döndürür).
* Yan yana + fark ısı haritası: `docs/ui_v21/compare/home_390x844_side_by_side.png`
* Sayısal rapor: `docs/ui_v21/compare/home_390x844_report.md` (test her çalıştığında yeniden yazılır)

| Bölge | Ortalama kanal farkı (0–255) | 1. tur → son |
|---|---:|---|
| Üst başlık | 21,0 | 25,2 → 21,0 |
| Lig rozeti | 22,2 | 39,8 → 22,2 |
| Kahraman | 11,0 | 11,7 → 11,0 |
| Düğme | 22,4 | 24,2 → 22,4 |
| Sandıklar | 21,3 | 21,6 → 21,3 |
| Alt menü | 20,6 | 20,6 |
| **Tüm ekran** | **16,4** | 19,1 → 16,4 |

**Düzeltilen farklar:**

* Seviye dairesinin beyaz kenarı lacivert yapıldı ve çap 44 oldu.
* Kullanıcı adı ve altın sayısı dar başlık yazı tipine geçti.
* Altın hapı sağ kenara yaslandı; kenar rengi `#4B3C6F`.
* Lig kalkanının altı sivri yerine "U" yapıldı; kalkan rengi `#E3A9FA → #8A3FD0`.
* Lig başlığı 26 px oldu; puan ve çubuk referans konumlarına alındı.
* Gece göğü, mor bulutlar ve iki projektör vektörle çizildi.
* Düğmenin iki yanına stadyum zemini eklendi; düğmeye 2 px lacivert kontur verildi.
* Alt menüdeki kart ve sandık simgeleri büyütüldü.

**Kalan farklar ve nedenleri:**

1. **Yazı tipi.** Referanstaki başlık yazısı ("MAÇA BAŞLA", "MASTER 2", "2.450") yuvarlak hatlı bir oyun fontu. Projede bulunan en yakın font Barlow Condensed Black; harf genişlikleri farklı. Fontun adı ve lisansı tasarımcıdan alınırsa eklenebilir.
2. **Kahraman görseli 1×.** Kaynak 390 px genişlikte; 3× ekranlarda yumuşak görünür. Üst kenarda 30 px geçiş var.
3. **Maskot etiketi görselin içinde.** "Efsane Kaptan" etiketi kırpılan görselin parçası; ayrı widget değil.
4. **Sandık görseli tek.** Bronz ve gümüş için renk süzgeci kullanılıyor; tür başına çizim yok.
5. **Projektörler yaklaşık çizim.** Vektörle çizildikleri için konumları birkaç piksel farklı.

---

## 5b. Koleksiyon (KARTLARIM)

**Ekran:** `lib/ui_v21/screens/collection/v21_collection_screen.dart`. Rota `/koleksiyon`, bayrak `kV21Collection` (`--dart-define=V21_COLLECTION=false` eski ekrana döndürür).

**Yerleşim (referans `collection.png`):**

* Başlık "KARTLARIM" ve sağda sayaç hapı ("12 / 100").
* Mor katalog çubuğu. Dokununca Gelişim ekranı açılır (referans hotspot "Gelişim").
* TÜMÜ ve 5 nadirlik dairesi: Bronz, Gümüş, Altın, Elmas, Efsane.
* GK / DEF / MID / FWD mevki hapları.
* **Araç satırı (referansta yok, eski ekrandan korundu):** arama kutusu, favori hapı ("♥ 3"; dokununca yalnız favoriler), sıralama hapı (alttan açılan "SIRALA" sayfası).
* 2 sütun `V21PlayerCard` ızgarası. Ekran 600 px'ten genişse 3 sütun.
* Alt menüde KARTLAR etkin.

**Veri:**

| Öğe | Kaynak |
|---|---|
| Kartlar | `CollectionViewModel.load()` → `/api/cards/inventory` |
| "12" (farklı kart) | `uniqueOwned` (kopyalar bir sayılır) |
| "/ 100" ve çubuk | `loadCatalogSize()` → mevcut `fetchCatalog()` |
| Filtreler | ViewModel'in var olan `setTierFilter`, `setPositionFilter`, `clearCategoryFilters` metotları (bellekte; sunucu isteği yok) |
| Arama | `setSearch` (ad, kulüp, ülke; Türkçe küçük harf eşleşmesi) |
| Favoriler | `FavoritesStore` (bu cihazda, en çok 50), `setFavoritesOnly`, `favoriteCount`; kartta kalp işareti. Favori ekleme/çıkarma kart ayrıntısından |
| Sıralama | `setSort`: güç (yüksek/düşük), seviye, isim. Varsayılan dışı bir sıralamada hap altın görünür |
| Kart ayrıntısı | Mevcut `CardDetailSheet` (favori, gelişim). Henüz V2.1 görünümünde değil |

**Durumlar (sahte veri yok):**

* Katalog alınamazsa yalnız "12" gösterilir ve çubuk boş kalır.
* Yükleniyor: dönen gösterge.
* Hata: panel + TEKRAR DENE.
* Boş koleksiyon: MAĞAZAYA GİT.
* Filtrede kart yok: FİLTRELERİ TEMİZLE (arama kutusu da boşalır).
* Kilitli kart: koyu örtü + kilit simgesi; ekran okuyucuya "kilitli" denir.
* Favori kart: mevki hapının altında kalp; ekran okuyucuya "favori" denir.

**Yeni bileşenler** (`components/v21_filters.dart`):

* `V21PageTitle`
* `V21FilterPill` (altın / renkli kenar, seçili dolgu)
* `V21RarityChip`
* `V21OrbIcon`
* `V21SearchField` (koyu hap, büyüteç, temizle)
* `V21IconPill` (simge + sayı, seçiliyken altın)

`V21PlayerCard`'a `favorite` (kalp) eklendi.

**Referans karşılaştırması (390×844):** `docs/ui_v21/compare/collection_390x844_*`

| Bölge | Ortalama fark | 1. tur → son |
|---|---:|---|
| Başlık (0–95) | 23,2 | 25,6 → 23,2 |
| Filtreler (95–195) | 10,7 | 33,7 → 10,7 |
| Kart ızgarası (195–760) | 61,3 | 46,4 → 46,3 → **61,3** (araç satırı) |
| Alt menü (760–844) | 23,5 | 22,4 → 23,5 |
| **Tüm ekran** | **47,3** | 40,2 → 37,1 → **47,3** (araç satırı) |

Kart ızgarasındaki fark iki kaynaktan geliyor:

1. **Portreler.** Referansta her futbolcu çizilmiş bir illüstrasyon; uygulamada sunucuda onaylı görsel (`imageUrl`) yoksa projenin 2D avatar çizicisi kullanılıyor.
2. **Araç satırı.** Kullanıcı kararıyla eklenen arama/favori/sıralama satırı (referansta yok) ızgarayı 50 px aşağı itiyor. Araç satırından önce ızgara farkı 46,3 idi.

Başlık, filtreler ve kart çerçevesi (güç dairesi, mevki hapı, ad plakası) referansla örtüşüyor.

Kart üstünde seviye rozeti (eski ekranda vardı) henüz yok.

---

## 6. Test sonuçları (Faz 1 + Koleksiyon; Faz 2 sonrası güncel sonuçlar §10.5)

| Komut | Sonuç |
|---|---|
| `flutter pub get` | ✅ |
| `flutter analyze` | ✅ hata ve uyarı yok. 152 bilgi notu: 150'si `material.dart` deprecation (133'ü önceden vardı, 17'si yeni V2.1 dosyalarının importu), 2'si önceden var olan `app.dart` yerelleştirme notu |
| `flutter test test/ui_v21` | ✅ 51/51 geçti (Windows'ta golden'lar dahil) |
| `flutter test` (tümü) | ✅ **557 geçti, 244 atlandı, 0 başarısız.** Önceki durum 506 geçti / 244 atlandı; +51 yeni V2.1 testi (ana sayfa ve bileşenler 27, koleksiyon 24). Atlananlar: backend kapalıyken entegrasyon testleri ve yazı tipi yolu yüzünden eski golden'lar (bkz. §7-1) |
| `flutter build apk --debug` | ❌ **Ortam nedeniyle derlenemedi; kod hatası değil.** Gradle 9.1 JDK 17+ istiyor. Bu makinede PATH'te Java 8 (`jre-1.8`) var, JAVA_HOME boş; bulunan tek ek JDK IntelliJ 2022.1 JBR 11. Hata: `Unrecognized option: --enable-native-access=ALL-UNNAMED` / `Could not create the Java Virtual Machine`. Çözüm: JDK 17+ (ör. Android Studio JBR) kurup `flutter config --jdk-dir <yol>` vermek. Dart tarafı `flutter analyze` ve 557 testle doğrulandı |

**Duyarlı yerleşim** (her biri taşma denetimi + golden):

* 320×568
* 360×640
* 390×844
* 412×915
* 768×1024 (tablet dikey)
* 1024×768 (tablet yatay)
* 1366×768 (masaüstü)

Golden dosyaları `test/ui_v21/goldens/` altında.

---

## 7. Bilinen sorunlar ve riskler

1. **Mevcut golden testleri bu makinede atlanıyor.** `test/goldens/golden_araclari.dart` MaterialIcons yolunu `C:/dev/flutter/...` olarak sabit yazıyor; Flutter burada `%USERPROFILE%/dev/flutter` altında. 244 "atlandı"nın bir bölümü bu yüzden. V2.1 testleri yolu `FLUTTER_ROOT`'tan buluyor. Eski aracın düzeltilmesi ayrı bir iş (kapsam dışı).
2. **V2.1 golden'ları yalnız Windows'ta karşılaştırılır.** CI (Ubuntu) bunları atlar; taşma ve veri testleri her platformda çalışır.
3. **Kabuk tutarsızlığı.** V2.1 alt menüsü yalnız ana sayfa ve koleksiyonda; Kadro, Mağaza ve Sezon hâlâ eski `RefBottomNav` ile açılıyor (sekmeler arasında görünüm değişiyor). Ekranlar taşındıkça kapanacak.
4. **Masaüstü yerleşimi.** ≥1024 genişlikte eski kabuk sol kenar çubuğu kullanıyordu. V2.1 ana sayfa telefon sütununu ortalıyor (en çok 520 px). Masaüstü için ayrı tasarım yok.
5. **PR #6 (arkadaş daveti)** eski `HomeView`'e "ARKADAŞINLA OYNA" düğmesi ekliyor. V2.1 ana sayfada bu düğme yok. PR #6 birleşince düğme ya V2.1 ana sayfaya eklenmeli ya da hf0 akışına (Maça Hazırlan) bağlanmalı. Git çakışması beklenmiyor; ancak V2.1 açıkken PR'ın düğmesi görünmez.
6. **Lig kalkan rengi.** Referans ana sayfada Master için mor; Lig Yolu ekranında Master altın. Şimdilik ana sayfa referansı izleniyor (her ligde mor). Lig Yolu taşınırken lig renkleri birleştirilmeli.
7. **APK derlemesi bu makinede yapılamadı.** Gradle 9.1, JDK 17+ istiyor (bkz. §6). Android'de cihaz üstü doğrulama yapılmadı.
8. **Seviye dairesi = sezon kademesi.** Sunucuda ayrı "oyuncu seviyesi" yok. Referanstaki "12" ve XP çubuğu sezon kademesine bağlandı. Ürün kararı gerekiyorsa değiştirilebilir.
9. **Koleksiyon araç satırı referansta yok.** Arama, favori ve sıralama kullanıcı kararıyla korundu; görünümü V2.1 dilinden türetildi. Tasarımcıdan onay ya da çizim alınmalı. Kartta seviye rozeti henüz yok.
10. **Kart ayrıntısı eski görünümde.** `CardDetailSheet` henüz V2.1'e taşınmadı (referansta yalnız HTML demo modalı `cardModal` var).

---

## 8. Sonraki adım

1. Tasarımcıdan iste:
   * Katmanlı 3× görseller: maskot, stadyum, sandık türleri, portreler, eşya simgeleri.
   * Başlık fontunun adı ve lisansı.
   * Higgsfield ekranlarının yerel kopyaları.
2. **Faz 3 devamı:** Kadro (`deck`, sekme; KADRO alt menüsü), Mağaza (`store`) ve Sezon (`season`): böylece alt menünün bütün sekmeleri V2.1 olur. Ardından geri düğmeli iç ekranlar için `V21BackButton` + sayfa başlığı: Sandıklar (`V21ChestSlot` hazır), Gelişim, Envanter, Lig Yolu, Profil, Ayarlar.
3. **Ortak kabuk:** `V21ScreenLayout` + `V21HomeNav`'ı bütün ana sekmelere uygula; `AppShell` geçişini bayrakla yönet.
4. **Maça Hazırlan + eşleştirme (hf3–hf6):** PR #5 birleştikten sonra.
5. **PvP (hf7–hf11):** V3 tek gizli hamle sözleşmesini koruyarak.
6. **Arkadaş akışı (hf0–hf2):** PR #6 birleştikten sonra.

---

## 10. Faz 2 raporu — temel tasarım sistemi

**Kapsam.** Faz 1'deki bileşenler baştan yazılmadı. Faz 2'de eksik temel bileşenler, animasyon temelleri ve dekoratif görsel eklendi; HTML referansına sadakat öğe bazında ölçüldü.

### 10.1 Bileşen durumu

| İstenen | Durum | Dosya | Referans karşılığı |
|---|---|---|---|
| Renkler, tipografi | ✅ Faz 1 | `foundation/v21_colors.dart`, `v21_typography.dart` | piksel örneklenmiş |
| 3B butonlar (normal/pressed/disabled/loading/success/error) | ✅ Faz 1 | `components/v21_game_button.dart` | `.gbutton` |
| `V21PlayerCard` | ✅ Faz 1 (+ `locked`, `favorite`) | `components/v21_player_card.dart` | Koleksiyon kartı |
| **`V21CardBack`** | ✅ yeni | `components/v21_card_back.dart` | Arena rakip kartı, Paket Mührü |
| Paneller | ✅ Faz 1 | `components/v21_game_panel.dart` | `.gameCard`, yuva |
| `V21BottomNavigation`, `V21GameHeader` | ✅ Faz 1 | | Ana sayfa |
| `V21ResourcePill`, `V21ProgressBar`, `V21LeagueBadge` | ✅ Faz 1 | | Ana sayfa |
| **`V21PlayerAvatar`** | ✅ yeni | `components/v21_match_widgets.dart` | Arena "SEN" / "RAKİP" |
| **`V21EnergyBar`** | ✅ yeni | `components/v21_match_widgets.dart` | Arena "ENERJİ 3/5" |
| **`V21MatchTimer`** | ✅ yeni | `components/v21_match_widgets.dart` | Arena "11" |
| **`V21GameDialog`** (+ `V21DialogAction`, `show<T>()`) | ✅ yeni | `components/v21_feedback.dart` | HTML demo modalları (`cardModal`, `sbcModal`) |
| **`V21LoadingOverlay`** | ✅ yeni | `components/v21_feedback.dart` | Referansta yok; V2.1 paneli |
| **`V21NetworkStatus`** (`V21Connection`) | ✅ yeni | `components/v21_feedback.dart` | HTML `.connection` hapı |
| **`V21EmptyState`** | ✅ yeni | `components/v21_feedback.dart` | HTML demo `.heroIcon` + `.gameCard` |
| **`V21RewardCard`** (`coins`, `trophies`, `chest`) | ✅ yeni | `components/v21_reward_cards.dart` | Zafer "ÖDÜLLERİN" |
| **`V21ChestCard`** | ✅ yeni | `components/v21_reward_cards.dart` | Sandıklar yuvaları |
| `V21BackButton` (ek) | ✅ yeni | `components/v21_match_widgets.dart` | 10 ekrandaki mavi geri düğmesi |

**Uyum notları:**

* Kart arka yüzü oyuncu kartıyla aynı oranı (165×235) kullanır.
* Nadirlik renkleri `V21Rarity` üzerinden gelir (`CardTier`).
* Mevki kodları `CardPosition.code` ile yazılır.
* `V21MatchTimer` süreyi yalnız gösterir; sayaç sunucu saatine bağlı kalır.
* `V21GameDialog` geri dönüşü olmayan işlemlerde açık onay için tasarlandı (ör. "TAKAS ET" / "VAZGEÇ").

### 10.2 Animasyon temelleri (`animations/v21_card_motion.dart`)

| Hareket | Bileşen | Azaltılmış hareket | Düşük güç (`V21Motion.lowPower`) |
|---|---|---|---|
| Basılma | `V21GameButton` (Faz 1) | titreşim yok | aynı |
| Kart yükselme | `V21CardLift` (seçili ya da üstüne gelince 8 px, %3 büyüme) | anında | aynı |
| Kart çevirme | `V21CardFlip` (Y ekseni, 520 ms, perspektif) | anında değişim | aynı |
| Nadirlik parlaması | `V21RarityGlow` (kenarda dönen ışık, 3 sn döngü) | sabit hâle, kare çizilmez | sabit hâle, kare çizilmez |
| Ekran geçişi | `V21Transitions.page()` / `fadeUp` (GoRouter, 220 ms solma + kayma) | geçiş yok | aynı |
| Nabız | `V21Pulse` (Faz 1; hazır sandık, acil sayaç, bağlanıyor noktası) | sabit | aynı |

**Eski cihazlar için:**

* Bulanıklık (`BackdropFilter`, `MaskFilter.blur`) yok.
* Dönüşler `Transform` ile yapılıyor.
* Parlama tek `CustomPaint` ve `RepaintBoundary` içinde çiziliyor.
* Sürekli efektler yalnız ekrandayken çalışıyor (`TickerMode`).

`V21Transitions.page()` henüz rotalara bağlanmadı. Bütün sekmeler V2.1'e geçince tek seferde bağlanmalı; yoksa yarısı eski, yarısı yeni geçiş kullanır.

### 10.3 Dekoratif görseller

| Görsel | Kaynak | Not |
|---|---|---|
| `assets/v21/icons/chest_gold_large.png` (yeni, 138×112) | `chests.png` Gümüş yuvası | Mor zemin kenardan taşma doldurmayla saydamlaştırıldı. Sandık kartı ve ödül kartında kullanılıyor; küçük sprite büyütülünce bulanıklaşıyordu |
| `assets/v21/icons/chest_gold.png` (yeniden) | `home.png` 2. yuva | Aynı yöntemle temizlendi; köşelerdeki artık pikseller kalktı |
| Kart arka yüzü, para, yıldız, kart simgesi, geri oku | vektör | Her yoğunlukta keskin |

**Eksik (tasarımcıdan beklenenler):**

* Oyuncu portreleri (avatar ve kart illüstrasyonları)
* Tür başına sandık görselleri
* Kupa simgesi (referansta yıldız kullanılmış; aynısı yapıldı)
* Zafer ekranı ışın patlaması ve konfeti
* Paket mührü ışın efekti

### 10.4 HTML referansıyla öğe karşılaştırması

Her bileşen, referans PNG'deki aynı dikdörtgenin üstüne aynı yerde çizildi. Ölçü: kanal başına ortalama mutlak fark (0–255).

* Görsel: `docs/ui_v21/compare/phase2_elements.png` (satır başına referans | Flutter | fark)
* Tablo: `docs/ui_v21/compare/phase2_elements_report.md`

| Öğe | Kaynak | 1. tur | Son | Kalan farkın nedeni |
|---|---|---:|---:|---|
| Ödül kartı +150 ALTIN | win | 23,5 | 21,5 | yazı tipi |
| Ödül kartı +25 KUPA | win | 20,8 | 19,1 | yazı tipi |
| Ödül kartı ALTIN SANDIK | win | 31,3 | 29,1 | sandık görseli |
| Maç sayacı "11" | arena | 38,9 | 30,2 | yazı tipi; yay inceltildi |
| Enerji 3/5 | arena | 24,6 | 12,4 | kutu ölçüsü düzeltildi |
| Oyuncu avatarı | arena | 57,1 | 57,1 | **portre**: referansta illüstrasyon, bizde 2D avatar |
| Kart arka yüzü (4,7° eğik) | arena | 23,9 | 23,8 | şerit aralığı |
| Sandık kartı (açılıyor) | chests | 33,0 | 26,3 | büyük sandık görseli eklendi |
| Sandık kartı (kilitli) | chests | 30,4 | 22,1 | büyük sandık görseli eklendi |
| Boş yuva kartı | chests | 9,2 | 9,0 | — |
| Geri düğmesi | chests | 23,5 | 23,5 | ok kalınlığı |
| Oyuncu kartı (Altın Golcü) | collection | 57,9 | 57,8 | **portre** |

**Galeri:** `test/ui_v21/goldens/v21_phase2_gallery_<boyut>.png` (390×844 ve 4 boyut daha). Galerinin bütün olarak HTML'de karşılığı yok; karşılaştırma öğe bazında yapıldı.

### 10.5 Testler

| Komut | Sonuç |
|---|---|
| `flutter analyze` | ✅ hata ve uyarı yok. 158 bilgi notu, hepsi deprecation: 133 önceden vardı, 23'ü V2.1 dosyalarının `material.dart` importu, 2'si `app.dart` |
| `flutter test test/ui_v21` | ✅ 72/72 (Faz 2: 21 yeni test) |
| `flutter test` (tümü) | ✅ **578 geçti, 244 atlandı, 0 başarısız** (başlangıç 506 / 244) |
| Galeri: 320×568, 360×640, 390×844, 412×915, 768×1024 | ✅ taşma yok + golden |
| Öğe karşılaştırması | ✅ 12 öğe, hepsi eşik (80) altında |
| `flutter build apk --debug` | ❌ ortam: JDK 17+ yok (bkz. §6); bu fazda tekrar denenmedi |

**Faz 2 widget testleri** (`test/ui_v21/v21_phase2_test.dart`):

* Kart arka yüzü: oran ve ekran okuyucu metni.
* Avatar: seviye rozeti.
* Enerji: değer sınırlama.
* Sayaç: canlı bölge; azaltılmış harekette kare çizilmez.
* Ödül kartları: kayıpta "-25"; Türkçe büyük harf "GÜMÜŞ".
* Sandık kartı: durumlar ve dokunma.
* Diyalog: seçilen sonucu döndürür.
* Yükleme katmanı: alttaki dokunmaları kapatır.
* Ağ durumu: bağlıyken gizli; yeniden deneme çalışır.
* Boş durum: eylem düğmesi.
* Kart çevirme: azaltılmış harekette anında.
* Kart yükselme.
* Nadirlik parlaması: azaltılmış ve düşük güç modunda kare çizilmez.
* Geçiş: azaltılmış harekette sarmalamaz.

### 10.6 Faz 2'de oluşturulan ve değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/ui_v21/components/v21_card_back.dart` | yeni |
| `lib/ui_v21/components/v21_match_widgets.dart` | yeni: avatar, enerji, sayaç, geri düğmesi |
| `lib/ui_v21/components/v21_feedback.dart` | yeni: diyalog, yükleme, ağ durumu, boş durum |
| `lib/ui_v21/components/v21_reward_cards.dart` | yeni: ödül kartı, sandık kartı |
| `lib/ui_v21/animations/v21_card_motion.dart` | yeni: yükselme, çevirme, parlama, geçiş |
| `lib/ui_v21/animations/v21_motion.dart` | `V21Motion.lowPower` |
| `lib/ui_v21/foundation/v21_assets.dart` | `chestGoldLarge` |
| `lib/ui_v21/ui_v21.dart` | yeni dışa aktarımlar |
| `lib/ui_v21/screens/collection/v21_collection_screen.dart` | boş, hata ve filtre durumları `V21EmptyState` ile |
| `assets/v21/icons/chest_gold.png`, `chest_gold_large.png` | temizlendi / yeni |
| `test/ui_v21/v21_phase2_test.dart` | yeni (21 test) |
| `test/ui_v21/v21_compare.dart` | `compareElements()` (öğe bazında karşılaştırma) |
| `test/ui_v21/goldens/` | 5 galeri golden'ı; sandık sprite'ı değiştiği için ana sayfa ve galeri golden'ları güncellendi |

Backend, migration'lar, ekonomi kuralları ve WebSocket protokolüne dokunulmadı.

### 10.7 Bilinen sorunlar

1. **Portre farkı (57–58).** Avatar ve oyuncu kartı karşılaştırmasındaki fark yerleşimden değil, illüstrasyonun olmamasından kaynaklanıyor.
2. **Ekran geçişi henüz rotalara bağlı değil** (bkz. §10.2).
3. **Sayaç yayı referansta yok.** Kalan süreyi gösteren ince, yarı saydam bir yay ekledik. Tasarım kararı gerekirse kaldırılabilir.
4. **Diyalog görünümü HTML demo modalından türetildi.** Figma'da karşılığı yok; tasarımcı onayı gerekir.
5. **`V21Motion.lowPower` ayarlara bağlı değil;** varsayılanı kapalı.

### 10.8 Sonraki adım (Faz 3)

1. **Alt menünün kalan sekmeleri:** Kadro (`V21PlayerCard` küçük boy + saha), Mağaza ve Sezon. Ardından `V21Transitions.page()` bütün V2.1 rotalarına bağlanmalı.
2. **Geri düğmeli iç ekranlar:** Sandıklar (`V21ChestCard` + `V21BackButton` hazır), Gelişim, Envanter, Lig Yolu, Profil, Ayarlar.
3. **Maç ekranı (hf7–hf11):**
   * Kullanılacak bileşenler: `V21PlayerAvatar`, `V21MatchTimer`, `V21EnergyBar`, `V21CardBack` + `V21CardFlip`.
   * Zafer ekranında `V21RewardCard`.
   * V3 tek gizli hamle sözleşmesi korunmalı.

---

## 11. Faz 3 raporu — alt menünün kalan sekmeleri

**Kapsam.** Kadrom, Mağaza ve Sezon Yolu V2.1'e taşındı. Alt menünün beş sekmesinin hepsi artık V2.1:

* KARTLAR
* KADRO
* ARENA (ana sayfa)
* MAĞAZA
* SEZON

Ekran geçişi bütün rotalara bağlandı. Eski ekranlar silinmedi; her biri bayrakla geri açılabiliyor.

### 11.1 Ekranlar

| Ekran | Dosya | Bayrak | Bağlantı |
|---|---|---|---|
| Kadrom | `lib/ui_v21/screens/deck/v21_deck_screen.dart` | `kV21Deck` (`V21_DECK`) | `DeckView` içinde (aşağıya bakınız) |
| Mağaza | `lib/ui_v21/screens/store/v21_store_screen.dart` | `kV21Store` (`V21_STORE`) | `app_router.dart` |
| Sezon Yolu | `lib/ui_v21/screens/season/v21_season_screen.dart` | `kV21Season` (`V21_SEASON`) | `app_router.dart` |
| Ekran geçişi | `V21PageTransitionsBuilder` (`animations/v21_card_motion.dart`) | `kV21Transitions` (`V21_TRANSITIONS`) | `AppTheme.dark.pageTransitionsTheme` |

**Kadro neden `DeckView` içinde bağlandı?** Açık PR #6, `app_router.dart`'ta kadro rotasının hemen yanına yeni rotalar ekliyor. O satıra dokunmak birleştirmede çakışma çıkarırdı. Bu yüzden geçiş `DeckView.build` içinde yapılıyor (`if (kV21Deck && !forceLegacy) return const V21DeckScreen();`).

**Ekran geçişi neden temada?** Geçiş uygulama temasında `pageTransitionsTheme` olarak verildi. Böylece rota dosyasına dokunmadan bütün rotalarda (eski ekranlar dahil) aynı geçiş kullanılıyor. "Animasyonları azalt" açıksa geçiş yok.

### 11.2 Veri ve davranış (mevcut ViewModel'ler, değişmedi)

**Kadrom** (`DeckViewModel`):

* **Görünüm:** Saha 4-4-2 ve `V21PlayerCard` küçük boy. Kimya bağları kartların altında çiziliyor (mevcut `ChemistryLinksPainter`).
* **Dokunma:** Mevcut `CardPickerSheet` açılıyor.
* **Sürükleme:** Yalnız aynı mevkiye bırakılabiliyor.
* **Basılı tutma:** Kartın kimya bağları vurgulanıyor.
* **Daireler:** GÜÇ (`averagePower`), KİMYA (`chemistry.total`), KADRO (`totalSelected/11`).
* **İpucu satırı:** eksik mevki uyarısını (`missingMessage`) ya da kayıt sonucunu (`saveMessage`) gösteriyor. Yanında "KİMYA" hapı var (`autoFillByChemistry`).
* **Düğmeler:** Değişiklik yokken yalnız OTOMATİK DİZ (`autoFillBest`). Kaydedilmemiş değişiklik varsa OTOMATİK DİZ + KAYDET (`save`, sunucu doğrular).
* **Çıkış:** Kaydedilmemiş değişiklikle çıkarken `V21GameDialog` ile onay isteniyor.
* **Acil kadro:** Kadro eksikse mevcut acil kadro afişi gösteriliyor.

**Mağaza** (`StoreViewModel`):

* **Günün teklifi:** ad, kart sayısı, indirim, fiyat. Bugün alındıysa "BUGÜN ALINDI" (pasif).
* **Paket kartları:** Fiyat düğmesine basınca paket satın alınıyor.
  * Altın yetiyorsa düğme yeşil.
  * Yetmiyorsa düğme gri ve altında kırmızı "N altın eksik" yazısı.
* **Oranlar:** Seçili paketin oranları gösteriliyor (varsayılan: Efsane oranı en yüksek paket).
* **Açılış:** Açılış mevcut `PackRevealView` ile gösteriliyor.
* **Sekmeler (prototip hotspot'larıyla aynı hedefler):** TEKLİFLER → Kart Takası, KOZMETİK → Envanter. Eski mağazada ikisi de "yakında" diyordu.
* **Paket görseli:** Referansta paketlerin üstünde örnek futbolcu var. Bunun yerine kart arka yüzü ve paketin imza nadirliğinde bir kart çizildi. Paket içeriğini sunucu belirlediği için örnek futbolcu sahte veri olurdu.

**Sezon Yolu** (`SeasonViewModel`):

* **Üst kısım:** Kalan süre hapı ("22g 14s", `endsAt − serverTime`), kademe kartı (yıldız, XP çubuğu) ve TÜMÜNÜ AL (`claimAll`, idempotency anahtarlı).
* **Ödül yolu:** Yatay ilerliyor ve oyuncunun kademesine kaydırılmış açılıyor. Alınabilir düğümler nabız atıyor. Düğüme dokununca ücretsiz ve premium ödülü gösteren diyalog açılıyor; ödül buradan alınıyor (`claim`).
* **Görevler:** GÜNLÜK, HAFTALIK ve SEZON görevleri listeleniyor. "ALINDI" ve "+200 XP" düğme değil, durum rozeti; görev XP'si sunucuda otomatik veriliyor.
* **Sezon kapalıysa:** "SEZON YAKINDA" boş durumu gösteriliyor.
* **Sekme davranışı:** Alt menüdeki SEZON artık bir sekme gibi `go` ile açılıyor. Eski sezon ekranı `push` ile açılıyordu; bayrak kapalıyken bu davranış korunuyor.

### 11.3 Yeni ortak bileşenler

| Bileşen | Dosya | Not |
|---|---|---|
| `V21StatOrb` | `components/v21_stat_widgets.dart` | Kadrom GÜÇ/KİMYA/KADRO daireleri |
| `V21Tag` | `components/v21_stat_widgets.dart` | GÜNLÜK / HAFTALIK / GÜNÜN TEKLİFİ |
| `V21PageTitle(onBack:)` | `components/v21_filters.dart` | Başlığın solunda mavi geri düğmesi |
| `V21GameButton(leading:)` | `components/v21_game_button.dart` | Özel simge (altın sikkesi) |
| `V21GameButton` anlam düğümü | | `container: true`: düğme, kartın içindeyken de ayrı erişilebilirlik düğümü |
| `V21PageTransitionsBuilder` | `animations/v21_card_motion.dart` | Tema geçişi |

### 11.4 Referans karşılaştırması (390×844)

Raporlar `docs/ui_v21/compare/{season,store,deck}_390x844_*` altında.

| Ekran | Tüm ekran farkı | En büyük fark | Nedeni |
|---|---:|---|---|
| Sezon Yolu | **28,9** | kademe kartı 41,5 | Yazı tipi; örnek veri farklı (referans: "10 galibiyet", test: "25 maç oyna") |
| Kadrom | **31,6** | saha 34,5 | **Portreler** (referansta illüstrasyon); test kadrosu farklı kartlar |
| Mağaza | **38,6** | günün teklifi 53,3 | Paket görseli bilerek farklı (örnek futbolcu yok); referansta "en az 1 Altın" yazıyor ama sunucuda bu bilgi yok, "2.000 yerine" yazılıyor; afiş 8 px daha kısa |

Yerleşim (başlık, panel konumları, düğmeler, alt menü) üç ekranda da referansla örtüşüyor. Yan yana görseller `*_side_by_side.png`.

### 11.5 Testler

| Komut | Sonuç |
|---|---|
| `flutter analyze` | ✅ hata ve uyarı yok. 163 bilgi notu, hepsi deprecation: 133'ü önceden vardı, 28'i V2.1 dosyalarının `material.dart` importu, 2'si `app.dart` |
| `flutter test test/ui_v21` | ✅ 107/107 (Faz 3: 35 yeni test) |
| `flutter test` (tümü) | ✅ **613 geçti, 244 atlandı, 0 başarısız** (başlangıç 506 / 244) |
| Duyarlı yerleşim (3 ekran × 7 boyut: 320×568, 360×640, 390×844, 412×915, 768×1024, 1024×768, 1366×768) | ✅ taşma yok + 21 golden |
| PR çakışma denemesi (`git merge-file`, dört açık PR) | ✅ Değiştirilen dosyalarda çakışma yok (`analysis_options.yaml` uyarısı yanlış tabandan kaynaklanıyordu; gerçek birleştirme tabanıyla çakışma yok, bkz. §12.4) |
| `flutter build apk --debug` | ❌ Ortam sorunu: JDK 17+ yok (bkz. §6). Tekrar denenmedi |

**Faz 3 widget testleri** (`test/ui_v21/v21_tabs_test.dart`):

* **Sezon Yolu:**
  * Kademe, kalan süre ve görevler gösteriliyor.
  * TÜMÜNÜ AL sunucuya gidiyor.
  * Düğüm diyaloğundan ödül alınıyor (`free:6`).
  * Sezon kapalıyken boş durum çıkıyor.
* **Mağaza:**
  * Günün teklifi, "50 altın eksik" ve "1.550 altın eksik" yazıları görünüyor.
  * Pakete dokununca oranlar değişiyor.
  * Parası yetmeyen paket alınamıyor.
  * Satın alma sunucuya gidiyor ve açılış ekranı geliyor.
* **Kadrom:**
  * `DeckView` V2.1 ekranına geçiyor.
  * Otomatik Diz ve Kaydet ile sunucuya 11 kart gidiyor.
  * Geri basınca onay diyaloğu çıkıyor.
  * Defans kartı kaleci yuvasına bırakılamıyor.

**Eski testler:** Eski kadro testleri (`deck_drag_test`, `ref_ekranlar_golden_test`, `sandik_golden_test`, `faz8_performans_test`) yedek ekranı test etmeye devam ediyor. Bunun için `DeckView(forceLegacy: true)` kullanıyorlar.

### 11.6 Faz 3'te oluşturulan ve değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/ui_v21/screens/deck/v21_deck_screen.dart` | yeni |
| `lib/ui_v21/screens/store/v21_store_screen.dart` | yeni |
| `lib/ui_v21/screens/season/v21_season_screen.dart` | yeni |
| `lib/ui_v21/components/v21_stat_widgets.dart` | yeni |
| `lib/ui_v21/components/v21_filters.dart` | `V21PageTitle(onBack:)` |
| `lib/ui_v21/components/v21_game_button.dart` | `leading`, `container: true` |
| `lib/ui_v21/animations/v21_card_motion.dart` | `V21PageTransitionsBuilder` |
| `lib/ui_v21/screens/home/v21_home_nav.dart` | SEZON sekmesi `go` ile |
| `lib/ui_v21/v21_flags.dart` | `kV21Deck`, `kV21Store`, `kV21Season`, `kV21Transitions` |
| `lib/ui_v21/ui_v21.dart` | dışa aktarım |
| `lib/core/router/app_router.dart` | Mağaza ve Sezon rotaları bayraklı; 2 import |
| `lib/core/theme/app_theme.dart` | `pageTransitionsTheme` (4 satır) |
| `lib/features/deck/presentation/view/deck_view.dart` | V2.1'e geçiş + `forceLegacy` |
| `test/ui_v21/v21_tabs_test.dart` | yeni (35 test) |
| `test/deck_drag_test.dart`, `test/goldens/{ref_ekranlar,sandik,faz8_performans}*` | `DeckView(forceLegacy: true)` |
| `test/ui_v21/goldens/` | 21 yeni golden; buton anlam düğümü değiştiği için mevcut golden'lar yeniden üretildi (görsel fark yok) |

Backend, migration'lar, ekonomi kuralları ve WebSocket protokolüne dokunulmadı.

### 11.7 Bilinen sorunlar

1. **Paket açılışı eski görünümde.** Satın alma sonrası `PackRevealView` (Ref UI) açılıyor. V2.1 paket mührü ve efsane açılışı (packSeal, packLegend) ayrı bir iş.
2. **Kart seçici ve acil kadro afişi eski görünümde.** Kadrom'daki `CardPickerSheet` ve `EmergencySquadBanner` henüz V2.1'e taşınmadı.
3. **Kadro formasyon seçimi yok.** Eski ekrandaki 4-3-3 / 3-5-2 satırı oyunda zaten pasifti; referansta da yok, eklenmedi.
4. **Premium sezon yolu ayrı çizilmiyor.** Referansta yalnız ücretsiz yol var. Premium ödüller düğüm diyaloğunda görünüyor; premium satın alma zaten kapalı (K4).
5. **Ekran geçişi bütün uygulamada açık.** Eski ekranlar da yeni geçişi kullanıyor (`V21_TRANSITIONS=false` ile kapanır).
6. **Mağaza günün teklifi afişi.** Sunucu "en az 1 Altın" gibi bir garanti bilgisi göndermediği için referanstaki alt satır yerine "2.000 yerine" yazılıyor.

### 11.8 Sonraki adım (Faz 4)

1. **Geri düğmeli iç ekranlar:**
   * Sandıklar (`V21ChestCard` + `V21BackButton` hazır)
   * Gelişim
   * Envanter
   * Lig Yolu
   * Profil
   * Ayarlar
   * Kart Takası
2. **Paket akışı:** paket mührü + efsane açılışı (`V21CardFlip`, `V21RarityGlow`), kart seçici ve kart ayrıntısı V2.1 görünümüne.
3. **Maç akışı (hf3–hf11):** Maça Hazırlan, eşleştirme (PR #5 sonrası), PvP ve Zafer. V3 tek gizli hamle sözleşmesi korunmalı.

---

## 12. Faz 4 raporu — geri düğmeli iç ekranlar

**Kapsam.** Yedi iç ekran V2.1'e taşındı. Hepsi mevcut ViewModel'leri ve gerçek sunucu verisini kullanıyor. Eski ekranlar silinmedi; tek bayrakla (`kV21Inner`, `--dart-define=V21_INNER=false`) geri dönülebiliyor.

| Ekran | Dosya | Rota | Alt menüde vurgu |
|---|---|---|---|
| Sandıklar | `lib/ui_v21/screens/inner/v21_chests_screen.dart` | `/sandiklar` | ARENA |
| Lig Yolu | `…/v21_league_screen.dart` | `/ligler` | ARENA |
| Gelişim | `…/v21_progress_screen.dart` | `/gelisim` | KARTLAR |
| Envanter | `…/v21_inventory_screen.dart` | `/envanter` | — |
| Profil | `…/v21_profile_screen.dart` | `/profil` | — |
| Ayarlar | `…/v21_settings_screen.dart` | `/ayarlar` | alt menü yok (referans) |
| Kart Takası | `…/v21_sbc_screen.dart` | `/gorevler` | — |

### 12.1 Ortak iskelet: `V21InnerPage` (`lib/ui_v21/layouts/v21_inner_page.dart`)

* **Başlık satırı:** geri düğmesi, başlık ve sağda kaynak hapı. Geri düğmesi önce `pop` dener, yığında sayfa yoksa belirtilen üst sayfaya gider (`fallbackRoute`).
* **Durumlar (sayı uydurulmaz):** yükleniyor, hata (TEKRAR DENE), sistem kapalı ("… YAKINDA") ve hazır.
* **Liste:** kaydırılabilir, aşağı çekince yenileniyor.
* **Alt menü:** üst sekme vurgulanabiliyor (`V21HomeNav(highlightRoute:)`). Ayarlar'da alt menü kapalı.
* **Ek parçalar:** `V21SectionTitle` (bölüm başlığı), `V21Toggle` (açma-kapama anahtarı), `V21HexIcon` (joker altıgeni).

### 12.2 Ekranlar: veri ve davranış

**Sandıklar** (`ChestsViewModel`):

* **Sandık hakkı paneli:** "7/10", 10 hücre ve "Her 96 dk'da 1 hak yenilenir · sonraki 41 dk". Süre sunucu saatine göre.
* **Yuvalar:** 2×2 `V21ChestCard`. Sayaç çalışırken yeşil, kilitliyken süreyi, hazırken "AÇ!" gösteriyor.
* **Dokunma davranışı (eski ekranla aynı):**
  * Hazır sandık → mevcut `ChestOpenView` açılış sahnesi.
  * Anahtar ya da hızlandırıcı varsa → `V21GameDialog` seçenekleri (KİLİDİ AÇ / ANAHTARLA AÇ / HIZLANDIR).
  * Kapalı sandık ve başka sayaç yoksa → sayaç başlıyor.
* **Diğer bölümler:** hemen açılabilen sandıklar (geniş satır + "AÇ!"), posta kutusu (TAŞI) ve olasılık sayfasına bağlantı.

**Lig Yolu** (`LeagueTiersViewModel`):

* **Düzen:** Ligler yukarıdan aşağıya Master Class → Amatör. Sol kenarda kalkanlar ve dikey yol var; geçilen kısım yeşil, üsttekiler pembe.
* **Oyuncunun ligi:** altın kenar, "SEN · M2" etiketi ve basamak ilerleme çubuğu.
* **Diğer ligler:** geçilenlerde yeşil onay, üsttekilerde kilit.
* **Ödüller:** Her ligin giriş ödülü kupa yolundan (`TrophyRoad`) geliyor.
* **Basamaklar:** Her kartta 1·2·3 basamak çipleri ve eşik puanları var. Bu bilgi referansta yok; eski ekranın bilgisi korunsun diye eklendi.
* **Terim:** Referans lig puanına "kupa" diyor; V2.1 ekranları bunu izliyor.

**Gelişim** (`ProgressViewModel`):

* **Üst kısım:** joker parçalar (5 altıgen) ve TÜMÜ / ATLAYABİLİR filtreleri. Filtreler referansta yok ama eski ekranda vardı.
* **Satırlar:** Her satırda kart, "SEVİYE N", 10 seviye noktası ve kopya çubuğu var.
* **Ana eylem:** SEVİYE ATLA ya da JOKERLE ATLA. En yüksek seviyede altın kenar ve "EN YÜKSEK SEVİYE ★".
* **"…" seçenekleri:** jokerle atla, %25 indirimle atla, ustalık kitabı ve kopya çevirme.
* **Kopya çevirme:** **Geri alınamaz**; ayrı bir onay diyaloğu istiyor (test: vazgeçince sunucuya gitmiyor).

**Envanter** (`ItemsViewModel`):

* 2 sütun karo: renkli daire simgesi ve "×N" adet rozeti.
* Eylemler: KULLAN (enerji içeceği), GİY / ÇIKAR (kozmetik), giyili olanda "GİYİLİ" etiketi.
* Karoya dokununca açıklama diyaloğu açılıyor.
* Süreli eşyada bitiş süresi, enerji içeceğinde günlük kullanım gösteriliyor.

**Profil** (`ProfileViewModel`):

* **Kimlik kartı:** avatar (giyilen çerçeve kozmetiği `CosmeticFrame` ile), ad, lig hapı, "24G · 9M · 2B", kazanma oranı çubuğu.
* **Döşemeler:** MAÇ / KUPA / ALTIN.
* **Başarımlar:** 3 sütun; kilitli olanlar soluk ve ilerleme sayısıyla.
* **Düğmeler:** AYARLAR. Altında, referansta olmayan ama oyunda gerçek ENVANTER ve SIRALAMA düğmeleri.
* **SON MAÇLAR** listesi.

**Ayarlar** (`SettingsViewModel`, tek örnek, `.value` ile verilir):

* **Gerçek anahtarlar:** titreşim, kart parıltısı, süre uyarısı.
* **Pasif:** Ses efektleri ve müzik "YAKINDA" olarak pasif. Oyunda ses motoru yok; anahtar çalışıyormuş gibi gösterilmiyor.
* **Hesap:** avatar, kullanıcı adı ve e-posta.
* **ÇIKIŞ YAP:** onay diyaloğu istiyor.
* **Geliştirici bağlantıları:** yalnız hata ayıklama derlemesinde (`kDebugMode`).

**Kart Takası** (`SbcListViewModel`):

* Turuncu afiş ve görev kartları.
* Her kartta: şartın nadirliğinde kart yelpazesi → ödül kutusu (altın / PAKET / PAKET+500), şart özeti ve BAŞLA ya da "YAPILDI".
* BAŞLA, mevcut kadro kurma ekranını açıyor.
* Altta "Verilen kartlar kalıcı olarak silinir" uyarısı.
* Referanstaki kart yelpazesinde örnek futbolcular var; burada şartın nadirliği gösteriliyor (örnek veri uydurulmuyor).

### 12.3 Referans karşılaştırması (390×844, tüm ekran farkı)

| Ekran | Fark | Kalan farkın nedeni |
|---|---:|---|
| Sandıklar | **26,2** | yazı tipi; çok yakın |
| Ayarlar | **34,8** | Testte (debug) GELİŞTİRİCİ bölümü ÇIKIŞ düğmesini aşağı itiyor ve referansta olmayan alt satırlar var. Yayın derlemesinde daha yakın |
| Lig Yolu | **35,6** (ilk tur 41,9) | Satır aralığı düzeltildi; basamak çipleri referansta yok |
| Envanter | **37,2** | Test verisi farklı eşyalar; karo yüksekliği referanstan 30 px fazla (eylem düğmesi + ek bilgi satırı) |
| Kart Takası | **42,2** | Kart yelpazesinde portre yerine nadirlik kartları |
| Profil | **42,6** | Avatar portresi; SON MAÇLAR ve ek düğmeler referansta yok |
| Gelişim | **43,3** | Portreler; filtre satırı referansta yok |

Raporlar `docs/ui_v21/compare/<ekran>_390x844_*` altında.

### 12.4 Testler

| Komut | Sonuç |
|---|---|
| `flutter analyze` | ✅ hata ve uyarı yok. 172 bilgi notu, hepsi deprecation: 133'ü önceden vardı, 37'si V2.1 dosyalarının `material.dart` importu, 2'si `app.dart` |
| `flutter test test/ui_v21` | ✅ 174/174 (Faz 4: 67 yeni test) |
| `flutter test` (tümü) | ✅ **680 geçti, 244 atlandı, 0 başarısız** (başlangıç 506 / 244) |
| Duyarlı yerleşim (7 ekran × 7 boyut: 320×568 … 1366×768) | ✅ taşma yok + 49 golden. İlk turda Envanter karosu 9–14 px taşıyordu; karo yüksekliği düzeltildi |
| PR çakışma denemesi (`git merge-file`, gerçek birleştirme tabanıyla, dört açık PR) | ✅ değiştirilen hiçbir dosyada çakışma yok (Faz 3'teki `analysis_options.yaml` uyarısı yanlış tabandan kaynaklanıyormuş) |
| `flutter build apk --debug` | ❌ ortam: JDK 17+ yok (bkz. §6); tekrar denenmedi |

**Faz 4 widget testleri** (`test/ui_v21/v21_inner_test.dart`):

* **Sandıklar:** hak ve süre metni; yuvalar; hemen aç; anahtar varken seçenek diyaloğu (başka sayaç çalışırken KİLİDİ AÇ seçeneği yok).
* **Lig Yolu:** sıralama (en yüksek lig üstte); şu anki, geçilen ve kilitli durumlar; ödül "alındı".
* **Gelişim:** eylem düğmeleri ve en yüksek seviye; kopya çevirmede açık onay ve vazgeçince sunucuya gitmeme.
* **Envanter:** adet, KULLAN, GİYİLİ, ayrıntı diyaloğu; KULLAN sunucuya gidiyor.
* **Profil:** kimlik ve istatistikler.
* **Ayarlar:** anahtar ayarı değiştiriyor; ses ve müzik pasif; alt menü yok; çıkış onayı.
* **Kart Takası:** afiş, görevler, uyarı.

### 12.5 Faz 4'te oluşturulan ve değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/ui_v21/layouts/v21_inner_page.dart` | yeni: `V21InnerPage`, `V21PageState`, `V21SectionTitle` |
| `lib/ui_v21/screens/inner/*.dart` | 7 ekran + `v21_inner_screens.dart` dışa aktarımı |
| `lib/ui_v21/components/v21_stat_widgets.dart` | `V21Toggle`, `V21HexIcon` |
| `lib/ui_v21/screens/home/v21_home_nav.dart` | `highlightRoute` |
| `lib/ui_v21/v21_flags.dart` | `kV21Inner` |
| `lib/ui_v21/ui_v21.dart` | dışa aktarım |
| `lib/core/router/app_router.dart` | 7 rota bayraklı; 1 import |
| `test/ui_v21/v21_inner_test.dart` | yeni (67 test) |
| `test/ui_v21/goldens/` | 49 yeni golden |

Backend, migration'lar, ekonomi kuralları ve WebSocket protokolüne dokunulmadı.

### 12.6 Bilinen sorunlar

1. **Alt akışlar henüz V2.1 değil:**
   * Sandık açılış sahnesi (`ChestOpenView`)
   * Olasılıklar sayfası
   * Kart takası kadro kurma ekranı (`SbcBuilderView`)
   * Liderlik tablosu (`/liderlik`)
   * Kart ayrıntısı
2. **Profil seviye rozeti yok.** Referanstaki avatar "12" rozeti (sezon kademesi) Profil'de gösterilmiyor; ProfileViewModel sezon verisini yüklemiyor. Ana sayfa başlığında gösteriliyor.
3. **Favori kartlar bölümü Profil'den çıktı.** Favoriler koleksiyonda kalp işaretiyle ve "yalnız favoriler" filtresiyle görülüyor.
4. **Kart Takası'nda "KİLİTLİ" durumu yok.** Referansta var ama sunucuda karşılığı yok.
5. **Profil/Envanter geri dönüşü.** Yığında sayfa yoksa (derin bağlantı) geri düğmesi Envanter'den Profil'e, Profil'den Ana Sayfa'ya gidiyor.

### 12.7 Sonraki adım (Faz 5)

1. **Paket akışı:** paket mührü ve efsane açılışı (`V21CardFlip`, `V21RarityGlow`, `V21RewardCard`), sandık açılış sahnesi, kart ayrıntısı ve kart seçici.
2. **Maç akışı:** Maça Hazırlan, eşleştirme (hf3–hf6, PR #5 sonrası), PvP (hf7–hf11; V3 tek gizli hamle sözleşmesi korunarak) ve Zafer.
3. **Arkadaş akışı (hf0–hf2):** PR #6 birleştikten sonra.
4. **Kalan iç ekranlar:** liderlik tablosu ve kart takası kadro kurma.

---

## 13. Faz 5 raporu — paket, sandık, kart ve maç sonu akışları

**Kapsam kararı.** Faz 5 dört akışı taşıdı: paket açılışı (mühür + kart kart + özet), sandık açılışı, kart ayrıntısı / kart seçici ve maç sonucu (Zafer).

**Bilerek ertelenenler:** eşleştirme (hf3–hf6), PvP maç ekranı (hf7–hf11) ve arkadaş akışı (hf0–hf2). Nedenleri:

* **PR #5** eşleştirme ViewModel'ine yeni bir durum ekliyor (`searchWarning`, "bağlantı kontrol ediliyor"; referanstaki hf6'ya karşılık geliyor). Şimdi taşınsa PR birleşince yeniden yazılması gerekir.
* **PR #6** `match_view.dart` dosyasında maç başlığını, teslim olma metnini ve "yeni maç" yönlendirmesini değiştiriyor. 1.267 satırlık PvP ekranını şimdi taşımak bu PR'la çakışır.
* **V3 sözleşmesi:** PvP ekranı V3 sözleşmesini (kart ve taktik tek gizli hamle) koruyarak dikkatle taşınmalı. Ayrıca referans ekranları uzak (Higgsfield) görseller.

### 13.1 Ekranlar

| Akış | Dosya | Nerede kullanılıyor | Bayrak / geçiş |
|---|---|---|---|
| Paket açılışı | `lib/ui_v21/screens/rewards/v21_pack_opening.dart` | V2.1 Mağaza (paket ve günün teklifi) | Mağaza ile birlikte (`kV21Store`) |
| Sandık açılışı | `…/v21_chest_opening.dart` | V2.1 Sandıklar | `kV21Inner` |
| Kart ayrıntısı | `…/v21_card_sheets.dart` (`V21CardDetailSheet`) | V2.1 Koleksiyon | `kV21Collection` |
| Kart seçici | `…/v21_card_sheets.dart` (`V21CardPickerSheet`) | V2.1 Kadrom | `kV21Deck` |
| Maç sonucu | `…/v21_match_result.dart` | `MatchResultView` içinde (bütün maç modları) | `kV21MatchResult` (`V21_RESULT`) |

**Maç sonucu neden `MatchResultView` içinde bağlandı?** Açık PR #6, `match_view.dart`'ta sonuç ekranının kurulduğu satırı değiştiriyor. O yüzden geçiş `MatchResultView.build` içinde yapıldı. Eski testler (`match_result_test` ve dört golden testi) `MatchResultView(forceLegacy: true, …)` ile eski ekranı test etmeye devam ediyor.

### 13.2 Veri ve davranış

**Paket açılışı** (mevcut `PackOpeningViewModel`; sıra, walkout kararı ve "hepsini göster" değişmedi):

1. **Mühür (referans `packSeal`):**
   * paket adı ve HEPSİNİ GÖSTER;
   * eğik kart arka yüzü, parıltılar ve nabız atan dokunma göstergesi;
   * "DOKUN!" ve "N kart seni bekliyor";
   * alt sırada küçük kart arka yüzleri.

   Dokununca kısa bir patlama hareketi var; animasyon azaltılmışsa yok.
2. **Kart kart (referans `packLegend`):**
   * ışın arka planı, "YENİ KART!" ve altın degrade nadirlik başlığı ("EFSANE!");
   * kart arka yüzden döner (`V21CardFlip`); Elmas ve Efsane'de nadirlik parlaması (`V21RarityGlow`);
   * ilerleme noktaları, "Paketteki en iyi kart · 5/5" ve DEVAM.

   Walkout hakkı olan en iyi kart mevcut `WalkoutScreen` sinematiğiyle açılıyor.
3. **Özet:**
   * PAKET AÇILDI ve en iyi kart;
   * nadirlik dağılımı etiketleri ve diğer kartlar;
   * gelişim kopyaları;
   * kalan altın;
   * KOLEKSİYONA GİT / MAĞAZAYA DÖN.

**Sandık açılışı:** Eski sahnenin akışı korundu:

* sandık 3 kez sallanır ve açılır;
* kartlar sırayla belirir ve her birinde YENİ / +1 GELİŞİM / KADRO KORUMASI / JOKER etiketi var;
* ödül kartları gelir: +altın, +joker, +eşya;
* bakiye ve açıklama gösterilir, ardından TAMAM.

Dokunmak animasyonu atlıyor. Animasyon azaltılmışsa ya da "Kart parıltısı" kapalıysa sahne doğrudan son hâlinde açılıyor.

**Kart ayrıntısı (referans HTML demo `cardModal`):**

* "KOLEKSİYON / OYUNCU KARTI" başlığı;
* "pop" hareketiyle büyük kart; Elmas ve Efsane'de parlama;
* GÜÇ / NADİRLİK / MEVKİ kutuları ve gelişim seviyesi;
* altı özellik çubuğu (sunucuda yoksa gizli), kulüp ve uyruk;
* kilitli kart ve Efsane kuralı notları;
* GELİŞİME GİT, favorilere ekle / çıkar (en çok 50 sınırı korunuyor) ve KAPAT.

**Kart seçici (referans HTML demo `deckModal`):**

* "KADRO YÖNETİMİ / DEFANS SEÇ" başlığı ve kart sayısı;
* yalnız uygun kartlar listeleniyor (`availableForSlot`);
* sıralama eskisiyle aynı: kimya ×3 + güç;
* her kartta "+N KİMYA" etiketi;
* fareyle üstüne gelince kart yükseliyor (`V21CardLift`).

**Maç sonucu (referans `win`):**

* "ZAFER!" / "BERABERLİK" / "MÜCADELE BİTTİ" başlığı (altın ya da kırmızı).
* Maskot yalnız galibiyette görünüyor (`assets/v21/illustrations/victory_mascot.png`, kenarları yumuşatılmış).
* Skor paneli iki avatarla.
* **ÖDÜLLERİN** satırı (+altın / +kupa / +koruma) maç öncesi-sonrası farkından hesaplanıyor; fark yoksa ya da maç dereceli değilse çizilmiyor.
* Kazanılan / kaybedilen kartlar ve ANA MENÜ / YENİ MAÇ düğmeleri.
* **Yalnız dereceli maçta:** mevcut maç sandığı paneli, sezon XP satırı ve lig değişimi paneli. Böylece PR #6'nın getirdiği kural (arkadaş maçında sandık ve XP yok) şimdiden uygulanıyor.
* Terfi kutlaması, konfeti ve fişek kozmetiği korunuyor.
* Titreşim tek sefer: eski durum sınıfı V2.1 açıkken titreşmiyor.

### 13.3 Ortak eklemeler

| Bileşen | Dosya | Not |
|---|---|---|
| `V21RaysBackground` | `components/v21_celebration.dart` | Dönen ışınlar, tek CustomPaint; efektler kapalıysa durur |
| `V21Sparkles` | | Sabit 4 köşeli parıltılar |
| `V21HeroTitle` | | Altın-turuncu (ya da kırmızı) degrade dev başlık |
| `V21TapHint` | | Nabız atan dokunma göstergesi |
| `V21PageDots` | | İlerleme noktaları |
| `V21Motion.cardEffects()` | `animations/v21_motion.dart` | Süs efektleri üç koşulun hepsinde kapanır: animasyon azaltma, düşük güç ve Ayarlar'daki **"Kart parıltısı"**. Daha önce V2.1 bu ayarı dikkate almıyordu; `V21RarityGlow` da artık uyuyor |
| `victory_mascot.png` | `assets/v21/illustrations/` | Zafer maskotu (win.png kırpımı) |

### 13.4 Referans karşılaştırması (390×844, tüm ekran farkı)

| Ekran | 1. tur | Son | Kalan farkın nedeni |
|---|---:|---:|---|
| Paket Mührü | 28,0 | **28,0** | Arka plan hâlesinin yoğunluğu ve başlık yazı tipi |
| Zafer | 59,8 | **45,5** | Kart satırı referanstaki gibi yazı solda, kartlar sağda yapıldı; galibiyette alt yazı kaldırıldı. Kalan: avatar ve kart portreleri, ödül kartlarında sandık yerine KORUMA (gerçek veri) |
| Efsane Açılış | 54,9 | **54,8** | Referanstaki çizilmiş Efsane Kaptan portresi (bizde 2D avatar); testte 2 kartlı paket olduğu için noktalar "1/2"; ek "Hepsini göster" bağlantısı |

### 13.5 Testler

| Komut | Sonuç |
|---|---|
| `flutter analyze` | ✅ hata ve uyarı yok. 178 bilgi notu, hepsi deprecation: 133'ü önceden vardı, 43'ü V2.1 dosyalarının `material.dart` importu, 2'si `app.dart` |
| `flutter test test/ui_v21` | ✅ 215/215 (Faz 5: 41 yeni test) |
| `flutter test` (tümü) | ✅ **721 geçti, 244 atlandı, 0 başarısız** (başlangıç 506 / 244) |
| Duyarlı yerleşim (paket mührü, paket özeti, sandık açılışı, zafer × 7 boyut) | ✅ taşma yok + 28 golden |
| PR çakışma denemesi (gerçek birleştirme tabanı, dört açık PR) | ✅ `match_result_view.dart` dahil hiçbir dosyada çakışma yok |
| `flutter build apk --debug` | ❌ ortam: JDK 17+ yok (bkz. §6); tekrar denenmedi |

**Faz 5 widget testleri** (`test/ui_v21/v21_rewards_test.dart`):

* **Paket:**
  * mühür → kart kart açılış → en iyi kartta walkout;
  * HEPSİNİ GÖSTER doğrudan özete geçiyor; MAĞAZAYA DÖN kapatıyor;
  * animasyon azaltılmışsa mühür anında açılıyor.
* **Sandık:** tür başlığı, kart sonuç etiketleri, sunucunun verdiği altın, TAMAM.
* **Kart ayrıntısı:** güç / nadirlik / özellik, Efsane notu, favori değişiyor, KAPAT.
* **Kart seçici:** kimyası yüksek kart en üstte, "+6 KİMYA" etiketi, dokununca seçiliyor.
* **Maç sonucu:**
  * `MatchResultView` varsayılan olarak V2.1 çiziyor;
  * zaferde skor, ödüller, kazanılan kartlar ve düğmeler;
  * antrenmanda ödül kartı yok;
  * mağlubiyette kırmızı başlık, "-25", kaybedilen kartlar, maskot yok.

**Eski testlere dokunuş:** Beş test dosyasında `MatchResultView(` → `MatchResultView(forceLegacy: true,` (yalnız bu değişiklik; biçimlendirme korunarak).

### 13.6 Faz 5'te oluşturulan ve değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/ui_v21/screens/rewards/v21_pack_opening.dart` | yeni |
| `lib/ui_v21/screens/rewards/v21_chest_opening.dart` | yeni |
| `lib/ui_v21/screens/rewards/v21_card_sheets.dart` | yeni (kart ayrıntısı + kart seçici) |
| `lib/ui_v21/screens/rewards/v21_match_result.dart` | yeni |
| `lib/ui_v21/components/v21_celebration.dart` | yeni |
| `lib/ui_v21/animations/v21_motion.dart`, `v21_card_motion.dart` | `cardEffects()`; parlama "Kart parıltısı" ayarına uyar |
| `lib/ui_v21/foundation/v21_assets.dart` | `victoryMascot` |
| `lib/ui_v21/v21_flags.dart` | `kV21MatchResult` |
| `lib/ui_v21/screens/store/v21_store_screen.dart` | `PackRevealView` → `V21PackOpening` |
| `lib/ui_v21/screens/inner/v21_chests_screen.dart` | `ChestOpenView` → `V21ChestOpening` |
| `lib/ui_v21/screens/collection/v21_collection_screen.dart` | `CardDetailSheet` → `V21CardDetailSheet` |
| `lib/ui_v21/screens/deck/v21_deck_screen.dart` | `CardPickerSheet` → `V21CardPickerSheet` |
| `lib/features/match/presentation/widgets/match_result_view.dart` | V2.1'e geçiş + `forceLegacy` + çift titreşim koruması |
| `assets/v21/illustrations/victory_mascot.png` | yeni |
| `test/ui_v21/v21_rewards_test.dart` | yeni (41 test) |
| `test/match_result_test.dart`, `test/goldens/{faz7,faz8,kozmetik,sandik}_golden_test.dart` | `forceLegacy: true` |

Backend, migration'lar, ekonomi kuralları ve WebSocket protokolüne dokunulmadı.

### 13.7 Bilinen sorunlar

1. **Walkout sinematiği** (`WalkoutScreen`) eski görünümde. Uzun bir sahne olduğu için ayrı ele alınmalı.
2. **Kart ayrıntısında gelişim paneli yok.** Eski ayrıntıdaki gömülü gelişim paneli (seviye atlama) yerine "GELİŞİME GİT" bağlantısı var; seviye atlama Gelişim ekranında yapılıyor.
3. ~~Maç sonundaki paneller eski görünümde.~~ Faz 6'da V2.1'e taşındı (§14.2).
4. **Zafer ödül kartlarında sandık yok.** Referansta üçüncü ödül kartı "ALTIN SANDIK"; bizde KORUMA çünkü maçın sandığı ayrı bir istekle (`MatchChestPanel`) geliyor ve hemen altında gösteriliyor.
5. **Zafer maskotu 1× kırpım** ve içinde referansın ışınları var. Kenarları yumuşatıldı; katmanlı görsel gelince değişmeli.

### 13.8 Sonraki adım (Faz 6)

PR #5 ve PR #6 birleştikten sonra:

1. **Maça Hazırlan + eşleştirme (hf3–hf6):** PR #5'in `searchWarning` durumu hf6 "Bağlantı kontrol ediliyor" ekranına bağlanır.
2. **PvP (hf7–hf11):** mevki seçimi, gizli kart seçimi, taktik ve enerji, rakip bekleniyor, yeniden bağlanma. Bileşenler hazır: `V21PlayerAvatar`, `V21MatchTimer`, `V21EnergyBar`, `V21CardBack`, `V21CardFlip`. **V3 sözleşmesi korunmalı:** kart ve taktik tek gizli hamle olarak gönderilir.
3. **Arkadaş akışı (hf0–hf2):** PR #6'nın `FriendRoomView` ekranı.
4. **Kalanlar:** walkout, liderlik tablosu, kart takası kadro kurma, sandık olasılıkları, giriş/kayıt (PR #3 sonrası).

Uzak referans görselleri (hf*) çevrimdışı değil; bu faz başlarken tarayıcıda açılıp ekran görüntüsü alınmalı.

---

## 14. Faz 6 raporu — PR'lardan bağımsız kalanlar

Kullanıcı kararı: eşleştirme ve PvP, PR #5 ve PR #6 birleşene kadar bekliyor. Bu fazda o PR'lara dokunmayan ekranlar taşındı.

### 14.1 Yeni ekranlar

HTML referansında bu ekranların karşılığı **yok**. Lig Yolu, Kadrom, Kart Takası ve Sandıklar ekranlarının dilinden türetildi; referans fark raporu üretilmedi.

| Ekran | Dosya | Veri | Rota |
|---|---|---|---|
| Sıralama | `lib/ui_v21/screens/inner/v21_leaderboard_screen.dart` | `LeaderboardViewModel` (`/api/leaderboard`, `/api/leaderboard/rank`) | `AppRoutes.leaderboard` (`kV21Inner`) |
| Kart takası kadro kurma | `lib/ui_v21/screens/inner/v21_sbc_builder_screen.dart` | `SbcBuilderViewModel` (`/api/sbc/:id/submit`) | `AppRoutes.sbcBuilder` (`kV21Inner`) |
| Sandık olasılıkları | `lib/ui_v21/screens/inner/v21_chest_odds_screen.dart` | `ChestsViewModel.loadOdds` (`/api/chests/odds`) | `AppRoutes.chestOdds` (`kV21Inner`) |

**Sıralama:**
* Üstte kendi kartın: kalkan, lig adı, sıran, basamak ilerlemesi ve "N kupa sonra X (M galibiyet)" satırı.
* İlk üç oyuncu podyumda (2-1-3), geri kalanlar liste halinde. Senin satırın altın çerçeveli.
* Listede değilsen kendi satırın altta, araya "⋮" ile ayrı gösterilir.
* LİG YOLU ve MAÇ OYNA düğmeleri.

**Kadro kurma:**
* Üstte kart, kimya ve eriyecek güç sayaçları.
* Şartlar paneli; değerlendirme mevcut `SbcEvaluation` ile yapılır.
* "Kimyaya göre / En düşükler / Boşalt" düğmeleri.
* Yeşil saha: Kadrom'dan çıkarılan ortak `V21SquadPitch` bileşeni, burada sürükleme kapalı. Bir yuvaya dokununca kart seçici açılır.
* **Kartları eritmek geri alınamaz.** Gönder düğmesi önce "KARTLAR ERİTİLSİN Mİ? / GERİ ALINAMAZ" onayını açar. VAZGEÇ seçilirse istek gitmez.
* Gönderimden sonra "GÖREV TAMAMLANDI" sonuç ekranı gelir: ışınlar, eritilen kart sayısı ve ödüller.

**Olasılıklar:**
* Galibiyet, beraberlik ve yenilgi için sandık türü tablosu.
* Şanssızlık koruması metni.
* Her tür için ayrı panel: kilit süresi, altın aralığı, joker, yuva × nadirlik tablosu (son yuva garanti) ve telafi altını.
* Sürüm etiketi. Oranların hepsi sunucudan gelir.

### 14.2 Maç sonu panelleri (`lib/ui_v21/screens/rewards/v21_match_panels.dart`)

`V21MatchResultView` artık eski Ref panellerini kullanmıyor; dört V2.1 paneline geçti:

| Panel | Eski | Davranış |
|---|---|---|
| `V21MatchChestPanel` | `MatchChestPanel` | Aynı istek: `ChestRepository.fetchMatchChest`. Sandığın nereye gittiği yazar: hemen açılır, N. yuvaya kondu, posta kutusu ya da telafi altını. Ayrıca enerji yokken atlanan sandığın notunu ve galibiyetle gelen gelişim kopyasını gösterir. |
| `V21MatchSeasonXpLine` | `MatchSeasonXpLine` | `SeasonRepository.fetchMatchXp`. XP 0 ise satır hiç görünmez. Enerji yoksa "%25 verildi" notu çıkar. |
| `V21LeagueChangePanel` | `LeagueChangePanel` | Önceki ve sonraki kalkan, kupa farkı, "LİG/SEVİYE ATLADIN/DÜŞTÜN" şeridi. Basamak çubuğu dolarak ilerler; animasyon azaltılmışsa anında dolar. |
| `V21LeaguePromotionOverlay` | `LeaguePromotionOverlay` | Işınlar ve "TERFİ!" yazısı, büyük kalkan, DEVAM düğmesi. Sunucu terfi ödülü vermediği için ekranda ödül gösterilmez. |

Eski paneller duruyor; eski sonuç ekranı (`forceLegacy`) onları kullanmaya devam ediyor.

### 14.3 Ortak bileşen

`lib/ui_v21/components/v21_squad_pitch.dart` (`V21SquadPitch`): formasyon sahası, yuvalar ve kimya çizgileri.
* Kadrom ekranından çıkarıldı; Kadrom bu bileşeni sürüklemeli kullanıyor, kadro kurma sürüklemesiz.
* Kadrom goldenları **değişmedi**; çıkarma piksel düzeyinde aynı sonucu veriyor.

### 14.4 Testler

`test/ui_v21/v21_faz6_test.dart`: 43 test, hepsi geçiyor.
* Sıralama: kendi sıran, podyum, liste.
* Olasılıklar: tablolar ve koruma metni.
* Kadro kurma:
  * boş kadroda gönderim kilitli;
  * doldurunca onay penceresi açılıyor;
  * **VAZGEÇ istek göndermiyor, ERİT tam 11 kart gönderiyor**;
  * ardından sonuç ekranı geliyor.
* Paneller: yuva, kopya, XP ve lig atlama; enerji yokken atlanan sandık; XP 0 iken satır yok; aynı basamakta şerit yok; terfi ekranında DEVAM kapatıyor.
* 5 ekran × 7 boyut golden ve taşma kontrolü (`test/ui_v21/goldens/v21_{leaderboard,chest_odds,sbc_builder,match_panels,promotion}_*.png`).

Tam sonuçlar:
* `flutter analyze`: 184 bilgi notu, hepsi deprecation: `material.dart` yerine `material_ui` önerisi. Hata ve uyarı yok.
* `flutter test`: **764 geçti, 244 atlandı, 0 hata.** Faz 5 sonunda 721 geçiyordu; 43 test eklendi. Atlananların hepsi yalnız Windows'ta çalışan golden testleri.

### 14.5 Değişen dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/ui_v21/screens/inner/v21_leaderboard_screen.dart` | yeni |
| `lib/ui_v21/screens/inner/v21_sbc_builder_screen.dart` | yeni |
| `lib/ui_v21/screens/inner/v21_chest_odds_screen.dart` | yeni |
| `lib/ui_v21/screens/inner/v21_inner_screens.dart` | üç dışa aktarım |
| `lib/ui_v21/screens/rewards/v21_match_panels.dart` | yeni |
| `lib/ui_v21/screens/rewards/v21_match_result.dart` | eski paneller → V2.1 panelleri |
| `lib/ui_v21/components/v21_squad_pitch.dart` | yeni (Kadrom'dan çıkarıldı) |
| `lib/ui_v21/screens/deck/v21_deck_screen.dart` | `V21SquadPitch` kullanıyor |
| `lib/core/router/app_router.dart` | sıralama, olasılıklar ve kadro kurma `kV21Inner` ile V2.1'e geçti |
| `test/ui_v21/v21_faz6_test.dart` + 35 golden | yeni |

Backend, migration'lar, ekonomi kuralları ve WebSocket protokolüne dokunulmadı.

**PR çakışma kontrolü:** değişen her dosya için `git merge-file` çalıştırıldı, taban olarak gerçek merge-base kullanıldı.
* PR #3, #4 ve #6: çakışma yok. PR #6 da `app_router.dart` ile `match_result_view.dart` dosyalarına dokunuyor; ikisi de temiz birleşiyor.
* PR #5 bu dosyaların hiçbirine dokunmuyor.

### 14.6 Bilinen sorunlar

1. **Referans yok.** Bu dört ekranın görünümü V2.1 diline göre türetildi; tasarımcı onayı gerekebilir.
2. **Sıralamada sayfalama yok.** Eski ekranda da yoktu; ilk 50 oyuncu gösterilir.
3. **Fontta "→" ve "★" yok.** Metinlerde kullanılmadı; oklar ve yıldızlar ikonla çiziliyor.

### 14.7 Sonraki adım

PR #5 ve PR #6 birleştikten sonra:
* Maça Hazırlan ve eşleştirme (hf3–hf6).
* PvP (hf7–hf11). V3'te kart ve taktik tek gizli hamle olarak gönderilir.
* Arkadaş akışı (hf0–hf2).
* Walkout ve giriş/kayıt (giriş/kayıt PR #3 sonrası).

---

## 15. Faz 7 raporu — PR'lardan bağımsız son ekranlar

Kullanıcı kararı (PR'ların hiçbiri hâlâ main'de değil): PR'ların dokunmadığı kalan ekranlar taşındı. Eşleştirme, PvP, arkadaş akışı ve giriş/kayıt PR'ları bekliyor.

### 15.1 Referanslar

hf12, hf13, hf14 ve hf17 uzak (CloudFront) görseller. Tarayıcıda açılıp incelendi; repoya **indirilmedi**, dolayısıyla piksel karşılaştırması yapılmadı.

* **hf12–hf14:** Maç ekranının üstündeki öğretici katmanı. Üstte "ÖĞRETİCİ · N/3", altında MEVKİ / KART / TAKTİK adım çizelgesi, maskot ve konuşma balonu. Ayrıca "ÖDÜLSÜZ" etiketi ve "ATLA" düğmesi var.
* **hf17:** Kadrom üzerinde "KADRO EKSİK" penceresi. "Maça çıkmak için 11 geçerli kart gerekli." metni, "EKSİK MEVKİLER" kutusu, KADROYU DÜZENLE ve KAPAT düğmeleri.

### 15.2 Öğretici ipucu (hf12–hf14)

Yeni dosya: `lib/ui_v21/screens/match/v21_tutorial_hint.dart` (`V21TutorialHint`).

* İçeriği:
  * "ÖĞRETİCİ · N/3" başlığı ve "ÖDÜLSÜZ" etiketi;
  * üç adımlı çizelge: geçilen adım yeşil ✓, şu anki altın, sıradakiler mor;
  * maskot (Efsane Kaptan) ve altın çerçeveli konuşma balonu.
* Metinler eski ipucuyla **aynı kaynaktan** geliyor (`TutorialHint.textFor`), bu yüzden sunucu kural sayılarıyla uyumlu.
* "ÖDÜLSÜZ" etiketi doğru: migration 042'ye göre öğretici maçları ödülsüz ve puansız. Ödül olarak yalnız 3. adım bitince bir Gümüş sandık veriliyor.
* Geçiş `TutorialHint` içinde yapılıyor (`kV21Tutorial`, `--dart-define=V21_TUTORIAL=false` ile kapanır). Maç ekranı (`match_view.dart`) PR #6'da değiştiği için ona dokunulmadı.
* Eski test `forceLegacy: true` ile eski paneli test ediyor.
* **Referanstaki "ATLA" yok.** Sunucuda öğreticiyi atlama uç noktası bulunmadığı için eklenmedi.

### 15.3 Geçersiz kadro uyarısı (hf17)

Yeni dosya: `lib/ui_v21/components/v21_squad_warning.dart` (`V21SquadWarning.show`, `MissingPositions`).

* Kadrom'da 11 kart dolmadan **KAYDET artık pasif değil.** Basınca "KADRO EKSİK" penceresi açılıyor ve eksik mevkiler ×sayı ile gösteriliyor. Eksik kadro sunucuya gönderilmiyor.
* KADROYU DÜZENLE, ilk boş yuvanın kart seçicisini açıyor.
* Sunucu kadroyu reddederse (`DeckValidation.isValid == false`), aynı pencere "KADRO GEÇERSİZ" başlığıyla ve sunucunun mesajıyla açılıyor. Önceden bu mesaj yalnız alttaki durum satırında görünüyordu.
* `V21GameDialog`'a isteğe bağlı `content` alanı eklendi.
* Eşleştirme ekranındaki kadro doğrulaması (`MatchmakingViewModel.validation`) PR #5'in dosyasında. Uyarı oraya o PR birleştikten sonra bağlanacak.

### 15.4 Walkout

Yeni dosya: `lib/ui_v21/screens/rewards/v21_walkout.dart` (`V21WalkoutScreen`).

* Eski sahneyle aynı zaman çizelgesi (4,6 sn): ışınlar → ÜLKE (bayrak) → MEVKİ (dev "MID" ve "ORTA SAHA") → KULÜP (arma) → kart vuruşu.
* Kart vuruşunda: şok halkası, konfeti, ağır titreşim, "EFSANE!" yazısı, parlayan `V21PlayerCard`, oyuncu adı ve kulübü.
* Işınların rengi nadirliğe göre: Efsane mor, Elmas mavi.
* İlk dokunuş karta atlıyor, ikincisi devam ediyor. Sahne bitince DEVAM düğmesi çıkıyor (erişilebilirlik için).
* **Animasyon azaltılmışsa** sahne hiç oynamıyor; kart ve DEVAM doğrudan geliyor. Konfeti, parlama ve şok halkası "Kart parıltısı" ayarına uyuyor (`V21Motion.cardEffects`).
* Bayrak ve arma çizicileri ortak (`NationFlag`, `ClubCrest`).
* V2.1 paket açılışı artık bu sahneyi kullanıyor. Eski `WalkoutScreen` duruyor; eski paket ekranı onu kullanmaya devam ediyor.

### 15.5 Açılış ekranı

Yeni dosya: `lib/ui_v21/screens/auth/v21_splash_art.dart` (`V21SplashArt`, `V21Logo`).

* Giriş referansının üst yarısından türetildi: "FUTBOL / CARD ARENA" logosu kodla çiziliyor, üç kahraman ve altında yükleniyor göstergesi var.
* **Yalnız görüntü değişti.** 900 ms bekleme ve oturuma göre yönlendirme `SplashView`'de olduğu gibi duruyor (`kV21Splash`).
* Kahraman görseli `assets/v21/illustrations/login_heroes.png`, login.png'den kırpıldı (0,150–390,438; yazı içermiyor). Giriş ekranı PR #3'ten sonra taşınırken aynı görsel ve `V21Logo` kullanılabilir.

### 15.6 Testler

* `test/ui_v21/v21_faz7_test.dart`: 43 test.
  * öğretici: varsayılan V2.1, adım çizelgesi, adım 3'te iki ✓, ekran okuyucu etiketi, `forceLegacy`;
  * uyarı: eksik mevkiler, KADROYU DÜZENLE `true`, KAPAT `false`;
  * walkout: sahnenin sırası, atla/devam, animasyon azaltılmış;
  * açılış: logo ve gösterge, başta logo görünmez;
  * 5 görünüm × 7 boyut golden ve taşma kontrolü.
* `test/ui_v21/v21_tabs_test.dart`: Kadrom için 2 yeni test.
  * eksik kadroda KAYDET uyarıyı açıyor, sunucuya istek gitmiyor, KADROYU DÜZENLE seçiciyi açıyor;
  * sunucu reddedince KADRO GEÇERSİZ.
* `test/ui_v21/v21_rewards_test.dart`: paket akışı artık V2.1 walkout'u da sonuna kadar oynatıyor (atla → EFSANE! → DEVAM).
* `test/tutorial_hint_test.dart`: `forceLegacy: true`.

Tam sonuçlar:
* `flutter analyze`: 189 bilgi notu, hepsi deprecation (`material.dart` → `material_ui` önerisi). Hata ve uyarı yok.
* `flutter test`: **809 geçti, 244 atlandı, 0 hata.** Faz 6 sonunda 764 geçiyordu; 45 test eklendi. Atlananların hepsi yalnız Windows'ta çalışan golden testleri.

### 15.7 Değişen dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/ui_v21/screens/match/v21_tutorial_hint.dart` | yeni |
| `lib/ui_v21/components/v21_squad_warning.dart` | yeni (barrel'a eklendi) |
| `lib/ui_v21/screens/rewards/v21_walkout.dart` | yeni |
| `lib/ui_v21/screens/auth/v21_splash_art.dart` | yeni |
| `assets/v21/illustrations/login_heroes.png` | yeni (login.png kırpımı) |
| `lib/ui_v21/foundation/v21_assets.dart` | `loginHeroes` |
| `lib/ui_v21/v21_flags.dart` | `kV21Tutorial`, `kV21Splash` |
| `lib/ui_v21/components/v21_feedback.dart` | `V21GameDialog.content` |
| `lib/ui_v21/screens/deck/v21_deck_screen.dart` | KAYDET → KADRO EKSİK / GEÇERSİZ |
| `lib/ui_v21/screens/rewards/v21_pack_opening.dart` | `WalkoutScreen` → `V21WalkoutScreen` |
| `lib/features/match/presentation/widgets/tutorial_hint.dart` | V2.1'e geçiş + `forceLegacy` |
| `lib/features/auth/presentation/view/splash_view.dart` | V2.1 görüntü (yönlendirme aynı) |
| `test/ui_v21/v21_faz7_test.dart` + 35 golden | yeni |
| `test/ui_v21/v21_tabs_test.dart`, `v21_rewards_test.dart`, `test/tutorial_hint_test.dart` | yukarıdaki testler |

Backend, migration'lar, ekonomi kuralları ve WebSocket protokolüne dokunulmadı.

**PR çakışma kontrolü** (gerçek merge-base ile `git merge-file`):
* 4 PR'ın hiçbiriyle çakışma yok.
* PR'lar `splash_view.dart`, `tutorial_hint.dart` ve bu fazda değişen diğer dosyalara dokunmuyor.

### 15.8 Bilinen sorunlar

1. **Öğretici ipucu eski maç ekranında duruyor.** Maç ekranı (Ref) PR #6 birleşince V2.1'e taşınacak; o zamana kadar V2.1 ipucu Ref arenanın içinde görünüyor. İstenirse `V21_TUTORIAL=false` ile kapanır.
2. **Açılış kahraman görseli 1×** (390 px genişlik). Geniş ekranda ve tablette yumuşak görünür; yüksek çözünürlüklü görsel gelince değiştirilmeli.
3. **hf* görselleri repoda yok.** Uzak bağlantılar kaybolursa referans da kaybolur; indirilmesi için kullanıcı onayı gerekiyor.

### 15.9 Sonraki adım

V2.1'e taşınmamış ekranların hepsi açık PR'lara bağlı:
* **PR #5 sonrası:** Maça Hazırlan ve eşleştirme (hf3–hf6), eşleştirmedeki KADRO EKSİK uyarısı.
* **PR #6 sonrası:**
  * PvP arena (hf7–hf11). V3'te kart ve taktik tek gizli hamle olarak gönderilir.
  * Arkadaş akışı (hf0–hf2).
  * Öğretici ipucunun arena içindeki yeri.
* **PR #3 sonrası:** giriş ve kayıt; `V21Logo` ve `login_heroes.png` hazır.

---

## 16. Faz 8 raporu — Maça Hazırlan, rakip arama ve canlı arena

Kullanıcı kararı: PR #5 ve PR #6 birleşmeden, eşleştirme ve arena **şimdi** V2.1'e taşındı. Yeni ekranlar `lib/ui_v21` altında. `matchmaking_view.dart` ve `match_view.dart` dosyalarına dokunulmadı; geçiş yönlendiricide `kV21Arena` bayrağıyla yapılıyor (`--dart-define=V21_ARENA=false` ile kapanır).

### 16.1 Referanslar

* **arena.png:** repoda var; referans karşılaştırması bununla yapıldı.
* **hf3–hf11:** uzak (CloudFront) görseller. Tarayıcıda açılıp incelendi, repoya indirilmedi.
* **matchPrep:** HTML'de yalnızca bir demo. Başlık "MAÇA HAZIRLAN", alt başlık "Takımın hazır mı?". Seçenekler: RAKİP BUL, ARKADAŞINLA OYNA, BOTLA ANTRENMAN, KADROYU DÜZENLE.

**Referanstan bilerek ayrılan nokta:** hf8 ayrı bir "KARTI KİLİTLE" adımı gösteriyor. V3 sözleşmesinde kart ve taktik **tek gizli hamle** olduğu için bu adım yok. Kart ve taktik hf9'daki gibi aynı ekranda seçiliyor ve tek bir OYNA! ile gidiyor.

### 16.2 Maça Hazırlan + rakip arama

Yeni dosya: `lib/ui_v21/screens/arena/v21_matchmaking_screen.dart` (`V21MatchmakingScreen`, `searchPhaseFor`).

**Maça Hazırlan:**
* Kahraman panelinde "Takımın hazır mı?", kadro durumu (sunucu doğrulaması) ve "KORUMA n/m" ya da "KART KAYBI YOK" etiketi var.
* Yeni oyuncuya öğretici kartı gösteriliyor: adım çizelgesi ve ÖĞRETİCİYİ BAŞLAT.
* Düğmeler: RAKİP BUL, BOTLA ANTRENMAN (anahtar açıksa) ve KADROYU DÜZENLE.
* Kart kaybı açıksa KARTLARINI KORU ızgarası ve EN İYİLERİ KORU düğmesi çıkıyor.
* **Kadro geçersizken RAKİP BUL arama yapmıyor.** Bunun yerine sunucunun mesajıyla "KADRO GEÇERSİZ" uyarısı açılıyor; KADROYU DÜZENLE Kadrom'a gidiyor.

**Arama ekranının aşamaları:**

| Aşama | Ne zaman | Ekranda |
|---|---|---|
| hf3 | 20 sn'den kısa | RAKİP ARANIYOR, radar, sayaç, "Benzer güçte rakip aranıyor" |
| hf4 | 20–60 sn | ARAMA DEVAM EDİYOR, "Arama aralığı genişletiliyor", BOTLA ANTRENMAN |
| hf5 | 60 sn'den uzun | HENÜZ RAKİP BULUNAMADI. **Arama durmuyor**: sunucu kuyruğu tutmaya devam ediyor, ekran bunu söylüyor. |
| hf6 | WebSocket kopuk | BAĞLANTI KONTROL EDİLİYOR. REST yoklaması sürdüğü için arama devam ediyor. |

Diğer kurallar:
* Arama sırasında alt menü gizli ve geri tuşu aramayı iptal ediyor (eskisiyle aynı). Sayaç saniyede bir ilerliyor.
* "BOTLA ANTRENMAN" önce aramayı iptal ediyor. İptal sırasında eşleşme gelirse maça gidiliyor, antrenman başlamıyor.
* Radar animasyon azaltılmışsa ya da düşük güç kipinde duruyor.

### 16.3 Canlı arena (hf7–hf11)

Yeni dosya: `lib/ui_v21/screens/arena/v21_arena_screen.dart` (`V21ArenaScreen`, `arenaSteps`, `arenaStatus`).

Ekranın bölümleri:
* **Skor tabelası:** SEN (mavi) · 2:2 / TUR 5/11 · RAKİP (kırmızı). Altında mod etiketi: DERECELİ, ANTRENMAN · ÖDÜLSÜZ ya da ÖĞRETİCİ · ÖDÜLSÜZ.
* **Hamle sayacı:** `V21MatchTimer`. "Süre uyarısı" ayarı kapalıysa kırmızıya dönmüyor.
* **Adım çizelgesi:** MEVKİ / KART / TAKTİK. Taktiksiz maçta TAKTİK, sıralı kuralda MEVKİ adımı çizilmiyor.
* **Öğretici maçında:** V2.1 öğretici ipucu da gösteriliyor.
* **VS satırı:**
  * Benim tarafım: seçili kart, masadaki kartım ya da kilitli sırt ("SEÇİMİN KİLİTLENDİ").
  * Rakip tarafı: "?", "Rakip seçti · gizli" (kilit) ya da açılan kartı.
* **Durum satırı:** eski ekranla aynı anlamlar.
* **Mevki seçimi (hf7):** KALECİ / DEFANS / ORTA SAHA / FORVET kutuları ve eldeki kart sayısı. Seçilen mevki DEVAM ET ile onaylanıyor; eskiden dokunur dokunmaz gidiyordu, yanlış dokunmanın önüne geçiyor. Lider rakipse bekleme gösteriliyor.
* **El (hf8):** "FORVET KARTINI SEÇ", "N kart uygun", masadaki kart sayısı. Uygun olmayan kartlar soluk.
* **Taktik + enerji (hf9):** PRES / KONTRA / DUVAR küreleri, maliyet çipleri (maçın kural sürümünden) ve `V21EnergyBar`.
* **Alt şerit:**
  * duruma göre OYNA!, DEVAM ET, PAS GEÇ · TURU KAYBET, RAKİP BEKLENİYOR (hf10, kilit simgesiyle), RAKİP MEVKİ SEÇİYOR ya da SIRA RAKİPTE;
  * altında "Teslim ol".
* **Teslim olma:** V2.1 onay penceresi; dereceli maçta "GERİ ALINAMAZ" uyarısı ve kart kaybı metni. Geri tuşu da bu pencereyi açıyor.
* **Yeniden bağlanma (hf11):** WebSocket koparsa "MAÇA YENİDEN BAĞLANILIYOR" paneli, BEKLE ve TEKRAR DENE (`refresh`). Seçim yerelde tutuluyor; hamle yalnız OYNA! ile gidiyor. Kopukken ViewModel 5 sn'de bir REST'ten yokluyor (değişmedi).
* **Çatışma sahnesi:** mevcut `DuelStage`; sonucu sunucu belirliyor. Maç bitince `MatchResultView`, o da V2.1 Zafer ekranını açıyor.
* **Değişmeyenler:** süre aşımı talebi, hata bildirimi ve yükleme/hata ekranları eskisiyle aynı davranıyor.

**V3 tek gizli hamle:**
* Taktik seçmek istek göndermiyor (`selectTactic` yerel).
* OYNA! tek bir `playCard(userCardId, tactic)` çağrısı yapıyor.
* Test bunu doğruluyor: Kuzey Yıldızı ile Yüksek Pres seçilip OYNA!'ya basılınca depoya tam bir çağrı gidiyor, `('2', highPress)`.

### 16.4 Ortak bileşen

`lib/ui_v21/components/v21_step_tracker.dart` (`V21StepTracker`): öğretici ipucundaki adım çizelgesi ortak bileşene çıkarıldı. Öğretici, Maça Hazırlan ve arena bunu kullanıyor. Faz 7 goldenları **değişmedi**.

### 16.5 Referans karşılaştırması (arena.png, 390×844)

Karşılaştırma referansla aynı durumda yapıldı: eş zamanlı seçim, forvet, kart seçili.

| Bölge | Ortalama fark |
|---|---:|
| skor | ~53 |
| sayaç + adımlar | ~33 |
| VS kartları | ~54 |
| el | ~53 |
| taktik + enerji | ~56 |
| OYNA! | ~62 |
| **Tüm ekran** | **52,1** |

Farkın ana nedenleri:
* Referanstaki çizim portreler (bizde 2D avatar).
* Referansta olmayan durum satırı ve mod etiketi, içeriği ~25 px aşağı itiyor.

Yan yana görüntü: `docs/ui_v21/compare/arena_390x844_side_by_side.png`.

### 16.6 Testler

`test/ui_v21/v21_faz8_test.dart`: 56 test.
* arama aşaması birim testi;
* Maça Hazırlan:
  * seçenekler ve koruma;
  * RAKİP BUL → arama, menü gizli, iptal geri dönüyor;
  * geçersiz kadroda arama yapılmıyor;
  * bağlantı kopukken BAĞLANTI KONTROL EDİLİYOR;
* arena:
  * skor, el, açılan rakip kartı, kart seçilmeden OYNA! pasif;
  * **tek playCard**;
  * mevki seçimi ve DEVAM ET;
  * rakip lider beklemesi;
  * kilitli hamle;
  * yeniden bağlanma;
  * teslim olma onayı;
* 6 görünüm × 7 boyut golden ve taşma kontrolü, arena.png karşılaştırması.

Eski testler (`arena_golden_test` vb.) `MatchView`/`MatchmakingView` widget'larını doğrudan kullandığı için etkilenmedi.

Tam sonuçlar:
* `flutter analyze`: 193 bilgi notu, hepsi deprecation (`material.dart` → `material_ui` önerisi). Hata ve uyarı yok.
* `flutter test`: **865 geçti, 244 atlandı, 0 hata.** Faz 7 sonunda 809 geçiyordu; 56 test eklendi.

### 16.7 Değişen dosyalar

| Dosya | Değişiklik |
|---|---|
| `lib/ui_v21/screens/arena/v21_matchmaking_screen.dart` | yeni |
| `lib/ui_v21/screens/arena/v21_arena_screen.dart` | yeni |
| `lib/ui_v21/components/v21_step_tracker.dart` | yeni (barrel'a eklendi) |
| `lib/ui_v21/screens/match/v21_tutorial_hint.dart` | `V21StepTracker` kullanıyor |
| `lib/ui_v21/v21_flags.dart` | `kV21Arena` |
| `lib/core/router/app_router.dart` | eşleştirme ve maç rotaları `kV21Arena` ile V2.1'e geçti (+2 import) |
| `test/ui_v21/v21_faz8_test.dart` + 42 golden | yeni |

Backend, migration'lar, ekonomi kuralları ve WebSocket protokolüne dokunulmadı.

**PR çakışma kontrolü** (gerçek merge-base ile `git merge-file`):
* 4 PR'ın hiçbiriyle **metin çakışması yok**.
* PR #6 `app_router.dart` içinde eşleştirme rotasının hemen üstüne iki rota ekliyor; bizim değişiklikle temiz birleşiyor.

### 16.8 PR'lar birleşince yapılacak uyarlamalar (önemli)

Çakışma olmasa da V2.1 ekranları rota düzeyinde devreye girdiği için PR'ların **eski ekranlara eklediği davranışlar V2.1'de görünmeyecek**. Birleşmeden hemen sonra şunlar V2.1 ekranlarına taşınmalı:

1. **PR #5 (uyarlamalı eşleştirme):** `MatchmakingViewModel.searchWarning` (art arda yoklama hatası) hf6 aşamasına bağlanmalı. Şimdi hf6 yalnız WebSocket kopukluğunda açılıyor. Bu tek satırlık bir değişiklik: `searchPhaseFor(..., online: _online && vm.searchWarning == null)`.
2. **PR #6 (arkadaş daveti):**
   * mod etiketi "ARKADAŞ MAÇI · ÖDÜL YOK";
   * arkadaş maçında teslim olma metni "Bu modda puan, ödül ve kart kaybı yok";
   * maç sonunda YENİ MAÇ → `AppRoutes.friends`;
   * Maça Hazırlan'a "ARKADAŞINLA OYNA" düğmesi;
   * arkadaş akışı ekranları (hf0–hf2).
   * PR #6 bunları `match_view.dart`'a ekliyor; `kV21Arena` açıkken o dosya çalışmıyor.

Bu uyarlamalar yapılana kadar, PR #6 birleştikten sonra arkadaş maçları için `V21_ARENA=false` ile eski ekrana dönmek güvenli seçenek.

### 16.9 Bilinen sorunlar

1. **Portreler:** referanstaki çizim portreler yerine 2D avatar kullanılıyor (bütün V2.1 ekranlarında olduğu gibi).
2. **Çatışma sahnesi eski görünümde.** `DuelStage` koyu/Ref tarzında; V2.1 zemininde ayrı duruyor.
3. **Geniş ekran:** arena telefon düzeninde (en fazla 520 px) ortalanıyor. Eski ekrandaki masaüstü iki sütunlu düzen ve tur geçmişi paneli V2.1'de yok.
4. **hf* görselleri repoda değil** (Faz 7 ile aynı not).

### 16.10 Sonraki adım

* PR #5 ve #6 birleşince §16.8'deki uyarlamalar ve arkadaş akışı (hf0–hf2).
* PR #3 sonrası giriş ve kayıt.
* İstenirse çatışma sahnesinin V2.1 görünümü.

---

## 17. Hedef platform: yalnız telefon ve tablet, dikey

Kullanıcı kararı: oyun **yalnız telefon ve tablette** (Android, iOS/iPadOS) yayınlanacak; web ve masaüstü sürümü olmayacak. Tabletler de **dikey**.

### 17.1 Yapılanlar

| Yer | Değişiklik |
|---|---|
| `ios/Runner/Info.plist` | iPhone: yalnız `Portrait`. iPad: `Portrait` ve `PortraitUpsideDown`. `UIRequiresFullScreen = true`. Dikey kilitli bir iPad uygulaması için gerekli; Split View / Slide Over kapanır. Önceden iPhone ve iPad'de yatay da açıktı. |
| `android/app/src/main/AndroidManifest.xml` | Etkinlikte `screenOrientation="sensorPortrait"` (dik ve ters dik), `android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY` özelliği (açıklaması aşağıda). |
| `lib/main.dart` | Değişmedi; zaten `portraitUp`/`portraitDown`. |
| `web/` | **Silindi** (index.html, manifest, 5 ikon). Git geçmişinde duruyor. |
| `.claude/launch.json` | Web ile ilgili iki başlatma yapılandırması kaldırıldı: `flutter run -d web-server` ve `build/web` sunucusu. |
| `lib/shared/widgets/premium_card/card_tilt.dart` | Gereksiz `kIsWeb` dalı kaldırıldı. Android/iOS denetimi duruyor; bilgisayardaki testlerde jiroskop yine kapalı. |
| `walkout_screen.dart`, `ui_v21` yorumları | "web/masaüstü" anlatımları düzeltildi. Fare-üstü (hover) davranışı kaldı: iPad fare ve trackpad işaretçisiyle çalışıyor. |
| `README.md` | Başa "Hedef platformlar" notu eklendi. Web derlemesi ve `CORS_ORIGIN` satırları düzeltildi. |
| `test/ui_v21/v21_test_support.dart` | V2.1 test boyutlarından yatay tablet (1024×768) ve masaüstü (1366×768) çıktı. Yerlerine dikey tabletler geldi: 820×1180 (iPad Air / 10. nesil) ve 1024×1366 (iPad Pro 12,9"). 64 eski golden silindi, yenileri üretildi. Hepsi taşmasız. |

**Android 16 ve tabletler:**
* Hedef SDK 36 (Android 16) büyük ekranlarda (en kısa kenar ≥ 600 dp) uygulamanın yön kilidini **yok sayıyor**. Bu, hem manifestteki ayarı hem `main.dart`'taki kilidi etkiliyor.
* `PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY` bu sürüm için resmi, geçici muafiyet.
* **Hedef SDK 37'ye geçilince bu muafiyet çalışmaz.** O zaman Android tabletlerde yatay düzen desteklenmeli. V2.1 ekranları yatayda taşmadan, telefon düzenini ortalayarak çalışıyor (eski 1024×768 goldenlarıyla görülmüştü).

### 17.2 Bilerek dokunulmayanlar

* **Eski (Ref) arayüzün masaüstü düzenleri:** `AppShell` kenar çubuğu, `AppBreakpoints.desktop`, ≥900 px iki sütunlu ekranlar ve bunların testleri (`app_shell_test`, `design_system_test`, 1366/1440 px goldenları) olduğu gibi duruyor.
  * Bu kod yalnız V2.1 bayrakları kapatılırsa çalışan yedek.
  * Eski golden testleri bu makinede zaten atlanıyor (MaterialIcons yolu `C:/dev/flutter`); burada yeniden üretilemezlerdi.
  * Eski arayüz kaldırılırken birlikte silinmeli.
* **Sunucudaki CORS:** backend değişmez kuralı gereği dokunulmadı. Mobil uygulama CORS'a tabi değil.
* **PR #3'teki `kIsWeb` kontrolleri** (`social_sign_in_service.dart`): zararsız, PR'a dokunulmadı.

### 17.3 Doğrulama

* `flutter analyze`: 193 bilgi notu, hepsi deprecation. Hata ve uyarı yok.
* `flutter test`: **865 geçti, 244 atlandı, 0 hata.**
* `AndroidManifest.xml` ve `Info.plist` XML olarak geçerli.
* **Gerçek cihazda ya da derlemede denenmedi.** APK derlemesi bu makinede JDK 8 yüzünden yapılamıyor (§7); iOS için Mac gerekiyor.
* PR çakışması: PR #3, #4 ve #6 manifest ya da `Info.plist` dosyalarına dokunuyor; üçü de temiz birleşiyor. Hiçbir PR `web/` klasörüne dokunmuyor ve hiçbir CI web derlemiyor.

### 17.4 Sonraki adım (öneri)

Büyük tabletlerde (iPad Pro 12,9") V2.1 telefon düzeni en fazla 520 px genişlikte ortalanıyor; altta geniş boş alan kalıyor. Tablet ana hedef olduğuna göre tablete özel ölçekleme ya da yerleşim ayrı bir iş olarak ele alınmalı.

---

## 9. Önerilen commit mesajı

Faz 1–8 birlikte tek commit için:

```
V2.1 arayüz: tasarım sistemi, beş sekme, iç ekranlar ve ödül akışları

- Referans HTML design/reference altına alındı; 17 Figma ekranı
  assets/v21/screens altına çıkarıldı (paketlenmez), manifest ve
  çıkarma aracı (tool/v21) eklendi
- lib/ui_v21 temeli: renk/yazı/ölçü, ölçek ve biçim yardımcıları;
  V21GameButton (6 durum), V21PlayerCard, V21GameHeader,
  V21BottomNavigation, V21ResourcePill, V21GamePanel, V21ProgressBar,
  V21LeagueBadge, V21ChestSlot, filtre/istatistik/anahtar bileşenleri
- Faz 2: V21CardBack, V21PlayerAvatar, V21EnergyBar, V21MatchTimer,
  V21GameDialog, V21LoadingOverlay, V21NetworkStatus, V21EmptyState,
  V21RewardCard, V21ChestCard, V21BackButton; kart yükselme/çevirme,
  nadirlik parlaması, ekran geçişi
- Faz 3: Kadrom, Mağaza, Sezon Yolu; ekran geçişi tema üzerinden
- Faz 4: V21InnerPage; Sandıklar, Lig Yolu, Gelişim, Envanter, Profil,
  Ayarlar, Kart Takası
- Faz 5: paket açılışı (mühür, kart kart, özet), sandık açılışı, kart
  ayrıntısı, kart seçici, maç sonucu (Zafer); kutlama bileşenleri;
  süs efektleri "Kart parıltısı" ayarına uyar
- Faz 6: Sıralama, kart takası kadro kurma (geri alınamaz onayıyla),
  sandık olasılıkları; maç sonu sandık/sezon XP/lig değişimi panelleri
  ve terfi kutlaması; ortak V21SquadPitch
- Faz 7: öğretici ipucu (adım çizelgesi + koç balonu), Kadrom'da
  KADRO EKSİK / GEÇERSİZ uyarısı, V2.1 walkout sinematiği, açılış ekranı
  görseli (yönlendirme aynı); kV21Tutorial, kV21Splash
- Faz 8: Maça Hazırlan + rakip arama (hf3–hf6) ve canlı arena
  (hf7–hf11); kart ve taktik tek gizli hamle (tek playCard);
  V21StepTracker; kV21Arena (rota düzeyinde)
- Platform: yalnız telefon ve tablet, dikey (iOS Info.plist, Android
  sensorPortrait + Android 16 muafiyeti); web/ klasörü kaldırıldı;
  V2.1 test boyutları dikey tabletlere çevrildi
- Bütün ekranlar mevcut ViewModel'leri kullanır ve bayraklıdır
  (kV21Home, kV21Collection, kV21Deck, kV21Store, kV21Season,
  kV21Inner, kV21MatchResult, kV21Transitions); eski Ref ekranları
  duruyor, eski testler forceLegacy ile onları test eder
- CollectionViewModel'e katalog boyutu (mevcut fetchCatalog)
- Testler: 359 yeni V2.1 testi; 7 boyutta taşma + golden, ekran ve öğe
  bazında HTML referansı fark raporları
- docs/UI_V21_IMPLEMENTATION_PROGRESS.md
```
