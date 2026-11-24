# Ses ve müzik listesi

Oyuna eklenecek bütün müzik ve ses efektleri. **Dosya adları koddaki adlarla aynıdır.**
Ürettiğin sesi tam bu adla kaydet ve doğru klasöre koy, oyun kendisi bulur.

- Müzik → `assets/audio/music/`
- Ses efekti → `assets/audio/sfx/`

**⭐ = ilk sürümde olmalı** (35 adet: 4 müzik + 31 efekt). Diğerleri sonradan eklenebilir; dosya yoksa oyun sessiz geçer, hata vermez.

---

## Üretirken kurallar

1. **Tarifler İngilizce.** Tabloda "Tarif" sütununu kopyala, aracın kutusuna yapıştır.
2. **Ses efektlerinde tarifin sonuna şunu ekle** (bütün seslerin aynı tarzda çıkması için):
   `Style: polished bright cartoon mobile game sound, punchy and clean, no music, no voice.`
3. **Her ses için 3–4 deneme üret**, en iyisini seç.
4. **Başındaki sessizliği kes.** Ses dokunduğun anda başlamalı (Audacity → başı seç → Sil).
5. **Seviyeyi eşitle:** Audacity → Efekt → Normalize.
   - Ses efektleri: tepe −1 dB
   - Müzik: tepe −3 dB (müzik efektlerin altında kalmalı)
6. **Format:** MP3, 44.1 kHz.
   - Efektler: mono, 128 kbps
   - Müzik: stereo, 160 kbps
7. **Süreye uy.** Tablodaki süreden çok uzun olan efekt oyunu ağırlaştırır.
8. **Var olan bir şeye benzetme.** Tariflere oyun, şarkı ya da sanatçı adı yazma.
9. **Ticari kullanım:** Sesi, ticari kullanıma izin veren **ücretli bir planda** üret. En alttaki lisans tablosunu doldur.

---

## 🎵 Müzik (7)

Müzik tariflerinin sonuna şunu ekle: `instrumental, no vocals, high quality mix.`

| ✓ | # | Dosya | Nerede çalar | Süre | Öncelik | Tarif |
|---|---|---|---|---|---|---|
| ✓ | M1 | `muzik_menu.mp3` | Ana sayfa, kartlar, kadro, mağaza, sezon | 60–90 sn döngü | ⭐ | `upbeat energetic sports anthem for a mobile football card game main menu, modern drums, bright synth and orchestral hits, heroic and fun, 110 BPM, seamless loop` |
| ✓ | M2 | `muzik_arama.mp3` | Maça hazırlan, rakip aranıyor | 20–30 sn döngü | | `tense building anticipation music while searching for an opponent, pulsing bass, ticking percussion, rising energy, 120 BPM, seamless loop` |
| ✓ | M3 | `muzik_mac.mp3` | Maç ekranı | 60–90 sn döngü | ⭐ | `focused competitive match music for a strategy card game, driving rhythmic percussion, light stadium drums, confident and tense but not distracting, 120 BPM, seamless loop` |
| ☐ | M4 | `ambiyans_stadyum.mp3` | Maçın arkasında, müzikle birlikte | 30–60 sn döngü | | `football stadium crowd ambience, distant chanting and murmur, no commentary, steady, seamless loop` |
| ✓ | M5 | `jingle_zafer.mp3` | ZAFER! ekranı | 3–5 sn | ⭐ | `short victory fanfare for a mobile sports game, triumphant brass and drums, crowd cheer at the end, 4 seconds` |
| ✓ | M6 | `jingle_yenilgi.mp3` | MÜCADELE BİTTİ ekranı | 3–5 sn | ⭐ | `short defeat jingle for a mobile game, gentle descending melody, slightly sad but encouraging, 4 seconds` |
| ✓ | M7 | `jingle_beraberlik.mp3` | BERABERLİK ekranı | 3 sn | | `short neutral draw jingle for a sports game, balanced and unresolved, light percussion, 3 seconds` |

---

## 🔊 Ses efektleri (62)

### 1. Genel arayüz (7)

| ✓ | # | Dosya | Ne zaman | Süre | Öncelik | Tarif |
|---|---|---|---|---|---|---|
| ☐ | 1 | `ui_tik.mp3` | Herhangi bir butona basınca | 0,1 sn | ⭐ | `soft crisp UI button click, glossy, very short` |
| ☐ | 2 | `ui_geri.mp3` | Geri / kapat | 0,15 sn | ⭐ | `soft UI back button click with a tiny downward whoosh` |
| ☐ | 3 | `ui_sekme.mp3` | Alt menüde sekme değişince | 0,2 sn | ⭐ | `light airy tab switch swoosh with a tiny pop` |
| ☐ | 4 | `ui_hata.mp3` | Hata, izin yok, yetersiz altın | 0,3 sn | ⭐ | `gentle negative error buzz, two short low notes, cartoon, not harsh` |
| ☐ | 5 | `ui_pencere.mp3` | Açılır pencere / alt panel açılınca | 0,3 sn | | `bouncy popup panel appearing, soft pop with a small sparkle` |
| ☐ | 6 | `ui_dugme.mp3` | Ayarlarda aç/kapa düğmesi | 0,1 sn | | `small toggle switch click` |
| ☐ | 7 | `ui_bildirim.mp3` | Bildirim, davet geldi | 0,5 sn | | `friendly notification chime, two bright rising notes` |

### 2. Sandık açılışı (6)

| ✓ | # | Dosya | Ne zaman | Süre | Öncelik | Tarif |
|---|---|---|---|---|---|---|
| ☐ | 8 | `sandik_sallanma.mp3` | Sandık sallanırken (3 kez tekrar çalar) | 0,4 sn | ⭐ | `wooden treasure chest rattling and shaking, metal latch clinks` |
| ☐ | 9 | `sandik_acilis.mp3` | **Sandık patlayıp açılınca** | 1,5 sn | ⭐ | `cartoon treasure chest bursting open with a magical golden shimmer and coin jingle, bright reward moment` |
| ☐ | 10 | `sandik_odul.mp3` | Her ödül kartı belirdiğinde | 0,4 sn | ⭐ | `reward card popping in, bright sparkle whoosh` |
| ☐ | 11 | `sandik_nadir.mp3` | Joker / nadir ödül çıkınca | 1 sn | | `rare reward reveal, magical rising shimmer with a bell chime` |
| ☐ | 12 | `sandik_hazir.mp3` | Sandık süresi dolup açılmaya hazır olunca | 0,8 sn | | `chest unlocked and ready, cheerful ascending chime with a small coin jingle` |
| ☐ | 13 | `sandik_gunluk.mp3` | Günlük ücretsiz sandık hazır | 1 sn | | `daily free gift available, playful magical jingle` |

### 3. Paket açılışı ve mağaza (8)

| ✓ | # | Dosya | Ne zaman | Süre | Öncelik | Tarif |
|---|---|---|---|---|---|---|
| ☐ | 14 | `paket_titreme.mp3` | Mühürlü pakete dokununca, titrerken | 0,6 sn | ⭐ | `sealed card pack trembling, crackling magical energy building up` |
| ☐ | 15 | `paket_patlama.mp3` | **Paket patlayınca** | 1 sn | ⭐ | `card pack bursting open, foil paper tear followed by a magical explosion of light` |
| ☐ | 16 | `kart_cevirme.mp3` | Bronz / Gümüş kart dönünce | 0,3 sn | ⭐ | `playing card flip, crisp paper swish` |
| ☐ | 17 | `kart_cevirme_altin.mp3` | Altın kart dönünce | 0,6 sn | ⭐ | `golden card flip with a shiny shimmer sparkle` |
| ☐ | 18 | `kart_nadir_parilti.mp3` | Elmas / Efsane parlaması | 1,5 sn | | `epic rare card reveal, powerful magical choir swell and shimmer, purple energy` |
| ☐ | 19 | `paket_hizli.mp3` | "Hepsini göster" | 0,4 sn | | `rapid card shuffle swipe` |
| ☐ | 20 | `paket_ozet.mp3` | PAKET AÇILDI özeti | 1 sn | | `short satisfying summary fanfare with a sparkle` |
| ☐ | 21 | `magaza_satin_alma.mp3` | Mağazada satın alma başarılı | 0,8 sn | | `purchase success, coins dropping into a pouch, cheerful chime` |

### 4. Walkout, Elmas / Efsane sinematiği (4)

| ✓ | # | Dosya | Ne zaman | Süre | Öncelik | Tarif |
|---|---|---|---|---|---|---|
| ☐ | 22 | `walkout_isiklar.mp3` | Ekran kararıp stadyum ışıkları yanınca | 1 sn | ⭐ | `stadium floodlights switching on one by one, heavy electrical clunks, deep boom, crowd murmur rising` |
| ☐ | 23 | `walkout_vurus.mp3` | Bayrak, mevki ve arma belirdikçe (3 kez çalar) | 0,8 sn | | `dramatic cinematic hit, deep impact with a short whoosh, sports intro` |
| ☐ | 24 | `walkout_kart.mp3` | **Kart ekrana vurunca** | 2 sn | ⭐ | `card slamming onto the screen, huge impact boom, stadium crowd erupting in cheers` |
| ☐ | 25 | `walkout_konfeti.mp3` | Konfeti patlayınca | 1 sn | | `confetti cannon pop and paper flutter` |

### 5. Eşleşme (4)

| ✓ | # | Dosya | Ne zaman | Süre | Öncelik | Tarif |
|---|---|---|---|---|---|---|
| ☐ | 26 | `eslesme_radar.mp3` | Rakip aranırken (2 sn'de bir) | 0,5 sn | ⭐ | `soft sonar radar ping, futuristic` |
| ☐ | 27 | `eslesme_bulundu.mp3` | **Rakip bulundu** | 1,2 sn | ⭐ | `opponent found, energetic sports stinger with a drum hit and whoosh` |
| ☐ | 28 | `mac_duduk.mp3` | Maç başlangıcı | 1 sn | ⭐ | `referee whistle blow, short, with a crowd cheer` |
| ☐ | 29 | `eslesme_iptal.mp3` | Arama iptal edilince | 0,4 sn | | `search cancelled, soft descending whoosh` |

### 6. Maç (17)

| ✓ | # | Dosya | Ne zaman | Süre | Öncelik | Tarif |
|---|---|---|---|---|---|---|
| ☐ | 30 | `mac_mevki.mp3` | Mevki seçilince (GK/DEF/MID/FWD) | 0,3 sn | ⭐ | `tactical selection click with a soft chalkboard tap` |
| ☐ | 31 | `mac_kart_sec.mp3` | Elden kart seçilince | 0,2 sn | ⭐ | `card lifted from a hand, light swish` |
| ☐ | 32 | `mac_kart_oyna.mp3` | **Kart oynanınca** | 0,3 sn | ⭐ | `quick card slap on a table, punchy` |
| ☐ | 33 | `mac_rakip_secti.mp3` | "Rakip seçti, gizli" | 0,4 sn | ⭐ | `mysterious card placed face down, soft thud with a subtle shimmer` |
| ☐ | 34 | `taktik_pres.mp3` | Yüksek Pres seçilince | 0,5 sn | ⭐ | `aggressive forward rush whoosh with a stomp` |
| ☐ | 35 | `taktik_kontra.mp3` | Kontra Atak seçilince | 0,5 sn | | `quick sharp counterattack slash whoosh` |
| ☐ | 36 | `taktik_duvar.mp3` | Savunma Duvarı seçilince | 0,5 sn | | `solid stone shield block thud` |
| ☐ | 37 | `mac_enerji_yok.mp3` | Taktik için enerji yetmiyor | 0,4 sn | | `energy depleted fizzle, short power-down` |
| ☐ | 38 | `mac_acilis.mp3` | İki kart birlikte açılınca | 0,6 sn | ⭐ | `two cards flipping over at the same time, dramatic reveal whoosh` |
| ☐ | 39 | `mac_carpisma.mp3` | **Kartlar çarpışınca** | 0,6 sn | ⭐ | `powerful clash impact, two forces colliding, punchy` |
| ☐ | 40 | `mac_tur_kazan.mp3` | Tur kazanıldı | 0,8 sn | ⭐ | `round won, bright triumphant short sting with a crowd cheer` |
| ☐ | 41 | `mac_tur_kaybet.mp3` | Tur kaybedildi | 0,8 sn | ⭐ | `round lost, short descending sting with a crowd groan` |
| ☐ | 42 | `mac_beraberlik.mp3` | Tur berabere, kartlar ortada kaldı | 0,8 sn | | `tied round, neutral suspense sting` |
| ☐ | 43 | `mac_efsane.mp3` | Efsane kuralı devreye girdi | 1,2 sn | | `legendary power unleashed, epic golden choir hit with thunder` |
| ☐ | 44 | `mac_tiktak.mp3` | Son 5 saniye, her saniye bir kez | 0,2 sn | ⭐ | `single tense clock tick` |
| ☐ | 45 | `mac_sure_doldu.mp3` | Süre doldu, otomatik oynandı | 0,6 sn | | `time's up buzzer, short` |
| ☐ | 46 | `mac_erken_bitis.mp3` | 12 karta ulaşıldı, maç erken bitti | 1 sn | | `decisive final referee whistle, three short blasts` |

### 7. Maç sonucu ve ödüller (8)

| ✓ | # | Dosya | Ne zaman | Süre | Öncelik | Tarif |
|---|---|---|---|---|---|---|
| ☐ | 47 | `odul_altin.mp3` | Altın kazanınca | 0,8 sn | ⭐ | `coins pouring and jingling, rewarding` |
| ☐ | 48 | `odul_xp.mp3` | XP kazanınca | 0,6 sn | ⭐ | `experience points gained, rising sparkle arpeggio` |
| ☐ | 49 | `odul_kupa.mp3` | Kupa puanı artınca | 0,6 sn | | `trophy points increasing, metallic shine ding` |
| ☐ | 50 | `odul_kart_kazan.mp3` | Kart kazanınca | 0,8 sn | | `new cards added, cards fanning out with a sparkle` |
| ☐ | 51 | `odul_kart_kaybet.mp3` | Kart kaybedince | 0,8 sn | | `cards sliding away with a sad whoosh` |
| ☐ | 52 | `lig_atlama.mp3` | **Lig / basamak atlayınca** | 2 sn | ⭐ | `league promotion, triumphant brass fanfare with a crowd cheer` |
| ☐ | 53 | `seviye_atlama.mp3` | Oyuncu seviyesi atlayınca | 1,5 sn | | `level up, magical ascending fanfare` |
| ☐ | 54 | `sezon_odul.mp3` | Sezon Yolu "TÜMÜNÜ AL" | 1,2 sn | | `claim all rewards, cascade of coins and sparkles` |

### 8. Kadro, koleksiyon, kart takası (6)

| ✓ | # | Dosya | Ne zaman | Süre | Öncelik | Tarif |
|---|---|---|---|---|---|---|
| ☐ | 55 | `kadro_kaldir.mp3` | Kartı tutup kaldırınca | 0,2 sn | ⭐ | `card picked up, light paper lift` |
| ☐ | 56 | `kadro_birak.mp3` | Kartı yuvaya bırakınca | 0,3 sn | ⭐ | `card placed into a slot, satisfying snap` |
| ☐ | 57 | `kadro_gecersiz.mp3` | Yanlış mevkiye bırakınca | 0,3 sn | | `invalid placement, soft bounce-back thud` |
| ☐ | 58 | `kadro_kimya.mp3` | Kimya bağlantısı oluşunca | 0,5 sn | | `chemistry link connected, small electric spark chime` |
| ☐ | 59 | `kadro_kaydet.mp3` | Kadro kaydedilince | 0,5 sn | | `squad saved, confident confirmation chime` |
| ☐ | 60 | `takas_basarili.mp3` | Kart takası başarılı | 1 sn | | `card exchange success, magical transformation swirl` |

### 9. Diğer (2)

| ✓ | # | Dosya | Ne zaman | Süre | Öncelik | Tarif |
|---|---|---|---|---|---|---|
| ☐ | 61 | `ogretici_ipucu.mp3` | Öğretici ipucu balonu | 0,4 sn | | `friendly tip bubble pop` |
| ☐ | 62 | `gorev_tamam.mp3` | Görev tamamlandı | 0,8 sn | | `quest completed, cheerful check chime` |

---

## Özet

| | Toplam | ⭐ İlk sürüm |
|---|---|---|
| Müzik | 7 | 4 |
| Ses efekti | 62 | 31 |
| **Toplam** | **69** | **35** |

---

## Yeni ses ekleme (kısa yol)

1. Dosyayı tablodaki adla `~/Desktop/sesler/` klasörüne koy.
2. `bash tool/ses/isle.sh` çalıştır (ffmpeg gerekir: `brew install ffmpeg`).
   Betik kesme, döngü, seviye ve formatı yapar; sonucu `assets/audio/` altına yazar.
3. Uygulamayı yeniden başlat. Kod değişikliği gerekmez.

---

## Teknik kurulum (geliştirici için)

| Ne | Nerede |
|---|---|
| Ses kapısı (tek giriş) | `lib/core/audio/game_audio.dart` → `GameAudio.sfx(Sfx.x)`, `GameAudio.jingle(Jingle.x)`, `GameAudio.music(Music.x)` |
| Ses adları | Aynı dosyadaki `Music`, `Jingle`, `Sfx` enum'ları (bu tabloyla birebir; `test/game_audio_test.dart` denetler) |
| Ekrana göre müzik | `lib/core/audio/audio_route_listener.dart` → `musicForPath()`: `/eslesme` arama, `/mac/<id>` maç, diğerleri menü |
| Animasyona bağlı ses | `lib/core/audio/sound_cues.dart` → `SoundCues` (zaman çizelgesi), `SfxOnMount` (ekran açılınca bir kez) |
| Paket | `audioplayers` |
| Ayarlar | `SettingsViewModel.soundEffects` (efekt + jingle), `.music` (müzik; varsayılan açık) |
| Başlatma | `main.dart` → `getIt<GameAudio>().init()`, `app.dart` → `AudioRouteListener.attach()` |

**Kurallar**
- Ses çalmak için hiçbir yerde `AudioPlayer` doğrudan kullanılmaz; her şey `GameAudio`'dan geçer (ayar ve eksik dosya kontrolü orada).
- Dosyası eklenmemiş ses sessizce atlanır. Yeni bir an için önce tabloya satır, sonra `Sfx` enum'una değer eklenir.
- Ekranlar müziği açıp kapatmaz; müzik rotaya göre seçilir. Maç sonu jingle'ı müziği durdurur, ekrandan çıkınca menü müziği döner.
- Uygulama arka plana geçince müzik duraklar. Web'de tarayıcı ilk dokunuştan önce ses çalmaya izin vermez; müzik ilk dokunuşta başlar.
- Oyuncu sahneyi dokunarak atlarsa (`SoundCues`) aradaki sesler çalınmaz.
- Widget testlerinde `GameAudio` kayıtlı değilse bütün çağrılar sessizce hiçbir şey yapmaz.

---

## Lisans kaydı

Her ses için doldur. Mağaza ya da biri sorarsa kanıt olur.

| Dosya | Araç | Plan (ücretli mi?) | Üretim tarihi | Not |
|---|---|---|---|---|
| | | | | |
