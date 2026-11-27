# Monetizasyon Denetimi (Faz 0)

Tarih: 27 Kasım 2026 · Dal: `main` (c6a7a34 ve sonrası) · Son migration: **059**

Bu belge mevcut kodun gerçek durumunu anlatır. Tahmin yok; her satırın
kaynağı kod ya da migration'dır. Kaynak araştırma:
`docs/arastirma/Oyun içi satış ve reklam stratejisi.md` (piyasa, hukuk,
teknik araştırma; bu denetimle büyük ölçüde örtüşüyor).

Sınıflar: **EXISTS** · **PARTIALLY_IMPLEMENTED** · **MISSING** ·
**NEEDS_REFACTOR** · **SECURITY_RISK** · **CONFLICT_WITH_MONETIZATION**

## 1. Proje talimatları

| Dosya | Durum |
|---|---|
| CLAUDE.md / AGENTS.md | MISSING — yok |
| README.md | EXISTS |
| docs/ | EXISTS — ekonomi V2 tasarım/plan, staging, güvenlik kapısı, araştırma |
| CI | EXISTS — `.github/workflows/ci.yml` (Flutter analiz/test, DB testleri, geçmiş veri denetimi, Android/web derleme), `ios-testflight.yml`, `local-secret-guard.yml` |
| Render | EXISTS — `render.yaml` (staging, `Dockerfile.staging`, otomatik deploy kapalı, `main`) |

## 2. Sistem sınıflandırması

| Sistem | Sınıf | Gerçek uygulama |
|---|---|---|
| Flutter mimarisi | EXISTS | MVVM: `lib/features/*/presentation/viewmodel` + `BaseViewModel`, depolar `Result<T>`, DI `get_it` (`lib/core/di/injection.dart`), yönlendirme `go_router`, arayüz `lib/ui_v21` |
| Dart sunucu | EXISTS | Shelf; `server/bin/server.dart` uçları bağlar; kural mantığı PL/pgSQL'de, rotalar yalnız taşır |
| Kimlik doğrulama | EXISTS | JWT erişim + yenileme jetonu, bcrypt, Google/Apple girişi (049), `requireAuth` ara katmanı |
| Oyuncu hesapları | EXISTS | `users` (002) + sonraki sütunlar (`gems` 056, `is_bot` 041) |
| Migration sistemi | EXISTS | `database/migrations/NNN_*.sql`, staging açılışta SHA256 ile doğrulanır (`scripts/staging-db-bootstrap.sh`); geçmiş migration değiştirilemez |
| Altın ekonomisi | EXISTS | `users.coins` + `economy_ledger` (028, UPDATE yasak), `_ledger_add` kilitli ve tekrar anahtarlı |
| Elmas ekonomisi | EXISTS / CONFLICT_WITH_MONETIZATION | `users.gems` (056, başlangıç 50) + `gem_ledger` (anahtar tekil), 057 yarışa dayanıklı hâle getirdi. Kazanma: sandık açılışı. Harcama: sandığı hemen açma, **elmas→altın** |
| Elmas → altın → paket | CONFLICT_WITH_MONETIZATION | `buy_coins_with_gems`: 10→250, 50→1.400, 120→3.600 altın. Altın kart paketi alır (500 / 2.500 / 4.000). Elmas parayla satılırsa para → altın → kart → güç olur (bkz. ECONOMY_RISK_ANALYSIS) |
| Kart paketleri | EXISTS | `open_pack` (011 → 044 → 050), altın ile, olasılıklar `chest_odds_public` / paket oranları ekranda |
| Kart geliştirme | EXISTS / CONFLICT_WITH_MONETIZATION | `level_up_player` (033/034); `card_level_power` açıkken seviye maçta +1..+3 güç (040, lig tavanlı). Joker parça ve kopyalar seviye atlatır → ücretli joker = güç |
| Sandıklar | EXISTS | 030/031/052, 4 yuva, kilit süreleri bronz 0 / gümüş 2 sa / altın 6 sa / efsane 12 sa; anahtar ve 2 saatlik hızlandırıcı eşya (034) |
| Sandık açılma süresi | EXISTS | `start_chest_unlock`, aynı anda tek sayaç; elmasla anında açma (056) |
| Envanter | EXISTS | `item_definitions`, `user_items`, `user_equipped` (034) |
| Kozmetik altyapısı | PARTIALLY_IMPLEMENTED | Kategoriler: profile_frame, kit, card_skin, arena_skin, victory_anim, character_cosmetic, season_badge. Giy/çıkar var. Arayüzde gerçekten çizilen: profil çerçevesi (`CosmeticFrame`), kart görünümü "Gece Işığı" (`v21_cosmetics.dart`). Diğerleri envanterde durur ama oyunda görüntüsü kısmi. Satış ve önizleme yok |
| Sezon sistemi | EXISTS / CONFLICT_WITH_MONETIZATION | 035: ücretsiz + premium yol, **`premium_purchase_enabled: false`** (premium satın alma yok). Premium ödüller joker, altın, sandık içeriyor → satılırsa güç |
| Matchmaking | EXISTS | 024/046/048/053, uyarlanabilir mod staging'de açık |
| WebSocket | EXISTS | `WsHub`, `?token=` ile; maç olayları |
| PvP maç yaşam döngüsü | EXISTS | `matches` + `match_hands` + eşzamanlı tur kuralları (039); `get_active_match_id` aktif maçı verir |
| Feature flag | EXISTS | `economy_config_versions` (028): sürümlü, **değiştirilemez** (UPDATE/DELETE tetikleyiciyle yasak), `economy_flag(ad)` tanımsızsa **false**. Platform, sürüm, yüzde, beyaz liste YOK |
| Yönetim paneli | MISSING | Yok. Ayar değişikliği SQL ile yeni sürüm ekleyerek yapılıyor (`scripts/staging-enable-v3.sql`) |
| Analitik | MISSING | İstemci/sunucu olay takibi yok. Sunucu yalnız istek günlüğü yazıyor |
| Reklam | MISSING | `google_mobile_ads` yok; Android/iOS uygulama kimliği yok |
| Uygulama içi satın alma | MISSING | `in_app_purchase` yok; makbuz doğrulama yok |
| Ürün kataloğu | PARTIALLY_IMPLEMENTED | Altınla paketler (`packs`), günlük teklif (044, altınla), elmas teklifleri `_gem_rules()` içinde sabit |
| Render | EXISTS | Yalnız staging servisi. Üretim servisi yok |
| GitHub Actions | EXISTS | Yukarıda |
| `/dev/*` uçları | EXISTS (güvenli) | `dev/add-coins`, `dev/grant-all-cards`, `items/dev/grant`, `season/dev/*` — hepsi `Env.isProduction` iken 404 |

## 3. Güvenlik bulguları

| Bulgu | Sınıf | Not |
|---|---|---|
| Ödüller sunucuda | EXISTS | Altın, elmas, sandık sonucu istemciden gelmiyor; tekrar anahtarları var |
| Ödüllü reklam doğrulaması | MISSING | Reklam eklenince istemci geri çağrısına güvenilmemeli; SSV gerekli |
| Makbuz doğrulama | MISSING | Satın alma eklenince zorunlu |
| `ENVIRONMENT` varsayılanı | SECURITY_RISK (düşük) | Ayarlanmazsa `development`; `/dev/*` uçları açılır. Staging `Dockerfile.staging` içinde `ENVIRONMENT=production` (doğrulandı). Staging de "production" kipinde çalıştığı için test sağlayıcıları bu değere bağlanamaz: ayrı `DEPLOY_STAGE` (staging/production) ve `MONETIZATION_TEST_PROVIDERS` ayarı kullanılır; `DEPLOY_STAGE=production` iken test sağlayıcısı hiçbir koşulda çalışmaz |
| Yönetici yetkisi | MISSING | Rol sistemi yok. Ayar değişikliği şu an veritabanı erişimiyle |

## 4. Sonuç

* Altyapı sağlam: sürümlü değiştirilemez ayar, iki defter (altın, elmas),
  tekrar anahtarı, kilitler, sunucu otoritesi. Monetizasyon bunların
  **üstüne** kurulacak, yeni paralel defter açılmayacak.
* Üç çatışma çözülmeden gerçek para satışı açılamaz:
  1. **Elmas→altın** (parayla güç),
  2. **Premium sezon yolu** (joker/sandık/altın),
  3. **Elmasla sandık açma** (para ile kart akışı hızlanır).
  Çözüm: ücretli ve ücretsiz elmas ayrılır; ücretli elmas yalnız
  kozmetik ve (güçsüz) premium yol için harcanır. Ayrıntı:
  `ECONOMY_RISK_ANALYSIS.md`.
* Mevcut bakiyeler değişmez: bugünkü `users.gems` "ücretsiz elmas" olarak
  aynen kalır.
