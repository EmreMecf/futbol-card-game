# Ekonomi V2 — Uygulama planı: kaynaksız 7 item ve R1–R3 (10 Kasım 2026)

**Durum: PLAN. Hiçbiri uygulanmadı.** R1–R3 ve item kaynakları oyuncu ekonomisini değiştirir;
açık onaydan önce devreye alınmaz. Sayılar `tool/ekonomi/karsilastirma.py` (S4, 10 tekrar,
180 gün) sonuçlarına dayanır. Ayrıntılı gerekçe: `docs/EKONOMI_V2_UC_KONU_RAPORU.md`.

## Değişmeyecekler (bütün planlar için bağlayıcı)

- **Maç motoru:** `play_card`, `_resolve_round`, taktik sistemi (021), kimya (014), kart
  karşılaştırması (aynı mevki, güç + kimya, Efsane kuralı) ve eşleştirme (024) **dokunulmaz**.
- **MMR ve galibiyet altını:** `_finish_match` içindeki `mmr ± 25`, `coins + 100` aynen kalır.
- **Geçmiş ve mevcut veri:** `card_transfers` satırları, `user_cards` sahiplikleri,
  `match_hands`, `matches` ve protection verisi **silinmez ve güncellenmez**. Yeni kurallar
  yalnız etkinleştirmeden SONRA kurulan maçlara uygulanır (023 maç kural sürümü).
- **Üretim:** `economy_v2_enabled` ve yeni `ranked_rewards_v2` anahtarları migration'da
  **kapalı** gelir. Üretimde açmanın ön koşulu: aynı commit'te CI'ın 5 işi yeşil + açık onay.

---

## A. Kaynağı olmayan 7 item

Denetim (`database/audits/ekonomi_v2_denetim.sql`, 6a): aşağıdakiler yalnız geliştirme
ucuyla veriliyor. Kullanım yolları zaten çalışıyor ve testli (034); eksik olan **kaynak**.

| Item | Önerilen kaynak | 180 günde beklenen (günde 2 / 5 / 10 / 20 maç) | Kullanım |
|---|---|---|---|
| Sandık anahtarı | Altın sandık %10, Efsane sandık %40 → 1 anahtar (yığın sınırı 10) | 6 / 17 / 29 / 40 | Var: sandığı anında açar (Efsane 2) |
| Ustalık kitabı Bronz / Gümüş / Elmas / Efsane | Efsane sandık %30 → 1 kitap; nadirlik: Bronz 35, Gümüş 35, Elmas 25, Efsane 5 (Altın kitap BP'de kalır) | 1,7 / 5,9 / 10,7 / 14 | Var: aynı nadirlikte futbolcuya bir seviyelik kopya, altın yine ödenir |
| Gelişim indirimi (%25) | Haftalık görev "10 galibiyet" tamamlanınca +1 (7 gün geçerli, tek kullanım) | haftada en fazla 1 | Var: seviye atlamada `use_discount` |
| Etkinlik bileti | **Pasif** (`is_active = false`) — etkinlik modu gelene kadar | 0 | Etkinlik moduna 1 giriş (mod ayrı onay) |

**Teknik yol (migration 038, ayrı onay):**

1. `chest_rules` **sürüm 2**: `extras` alanı (binde oran) — `{"gold": {"chest_key": 100},
   "legend": {"chest_key": 400, "mastery_book": 300}}`. Sandık kendi `rules_version`'ını
   sakladığı için **eski sandıklar sürüm 1 kurallarıyla açılır** (değişmez). `open_chest`
   ek ödülü `_item_add` ile verir; sonuç `result.extras`'a yazılır; tekrar açma aynı sonucu döner.
2. `missions.reward_items jsonb` sütunu: `weekly_win_10 → {"level_discount_25": 1}`.
   `_mission_event` tamamlanınca `grant_item(..., 'mission', slug:dönem, anahtar)` (tek sefer).
3. `update item_definitions set is_active = false where slug = 'event_ticket'` — sahip olan
   yok (yalnız geliştirme verisi); satır silinmez.
4. **Test:** eski sürüm sandık ekstrasız açılır; yeni sürümde 20.000 çekilişte oranlar
   toleransta; anahtar sınırı 10 aşınca altına döner; görev indirimi haftada bir; tekrar
   açma / tekrar görev çift vermez.

---

## B. R1–R3 migration planı (037, açık onaydan sonra)

### Etkinleştirme mekanizması

- Yeni oyun kural sürümü **3** (`game_rule_versions`): `tactics_enabled = true` (sürüm 2 ile
  aynı düello) + yeni bayraklar `card_transfer = false`, `win_progress_copy = 1`,
  `no_energy_chest = 'bronze'`. Sürüm 1–2 satırlarına `card_transfer = true` (bugünkü davranış).
- `current_rules_version()`: `case when economy_flag('ranked_rewards_v2') then 3 else 2 end`
  (`stable`). Maç kurulurken sürüm `matches.rules_version`'a yazılır → **süren maçlar eski
  kurallarla biter** (023'ün güvencesi).
- Anahtar kapalıyken her şey bugünkü gibi; açıp kapatmak geri alınabilir.

### R2 — Dereceli maçta kalıcı kart transferi kalkar

- `_finish_match`: yalnız "CEZA" bloğu `rules_card_transfer(m.rules_version)` koşuluna bağlanır.
  Sürüm 3 maçında `card_transfers` satırı yazılmaz, sahiplik değişmez, desteden kart düşmez.
- Galibiyette `protection_slots + 1` de sürüm 3'te uygulanmaz (değer silinmez; ileride ayrı
  "riskli mod" için saklanır). `wins / losses / draws`, `mmr ± 25`, `coins + 100` aynen.
- İstemci: sürüm 3'te maç hazırlığındaki "KARTLARINI KORU" bölümü ve maç sonu "kaybettiğin
  kartlar" gizlenir (sunucu `rules_version`'ı zaten maç durumunda veriyor).

### R1 — Her meşru maça sandık

- `_grant_match_chest`: enerji harcanamazsa **sürüm 3 maçında** `_grant_chest(p, 'bronze',
  'match', match_id)` (anında, yuvaya girmez). `chest_skip:` defter kaydı yine yazılır (035'in
  %25 XP hesabı bu kayda bakar → XP kuralı değişmez). K6 (≥ 4 tur) aynen.
- `get_source_chest` enerjisiz Bronz'u `{chest, no_energy: true}` döner; maç sonu paneli
  "Ödül enerjin yoktu: Bronz sandık" gösterir.

### R3 — Galibiyette +1 gelişim kopyası

- `_economy_on_match_finished` (sürüm 3, ≥ 4 tur, galip): kazananın aktif destesinden
  seviyesi < 10 olan rastgele bir futbolcuya `player_progress.copies + 1`; defter
  `win_progress_copy` (anahtar `wincopy:<maç>`) → tek sefer. Fiziksel kart eklenmez.
- Maç sonu paneli: "+1 gelişim kopyası: <futbolcu>".

### Test planı (037_ranked_rewards_v2_test.sql)

| Kontrol | Beklenen |
|---|---|
| Anahtar kapalı, sürüm 2 maçı | transfer + koruma +1 bugünkü gibi |
| Anahtar açık, sürüm 3 maçı | transfer yok, `card_transfers` sayısı değişmez, sahiplik aynı |
| Açılmadan önce başlamış maç, açıldıktan sonra biter | sürüm 2 kuralları (transfer var) |
| MMR / altın / galibiyet sayıları | sürüm 2 ve 3'te birebir aynı |
| Enerjisiz sürüm 3 maçı | 1 Bronz sandık, XP %25, `chest_skip` kaydı var |
| Galibiyet kopyası | tek sefer, yalnız destedeki ve seviyesi < 10 kart; kısa maçta (K6) yok |
| Geçmiş veri | migration öncesi/sonrası `card_transfers`, `user_cards` özetleri (sayı + sahiplik karması) eşit |
| Düello | 021 / 024 testleri değişmeden geçer; `_resolve_round` ve `play_card` gövdeleri migration'da yok |

### Beklenen etki (S0 → S4, 180 gün; günde 2 / 5 / 10 / 20 maç)

| Ölçü | S0 | S4 |
|---|---|---|
| Kalıcı kart kaybı | 164 / 384 / 741 / 1466 | 0 |
| Kadro ort. seviye | 4,59 / 5,64 / 6,48 / 6,98 | 4,96 / 5,85 / 6,57 / 7,25 |
| Sandık | 321 / 804 / 1529 / 2218 | 329 / 795 / 1532 / 2925 |
| Telafi (adet) | 0 / 1 / 10 / 59 | 0 / 2 / 9 / 59 |
| Altın geliri/gün | 197 / 470 / 823 / 1373 | 202 / 466 / 812 / 1433 |

## C. Etkinleştirme sırası (üretim)

1. 036 (sezon onarımı, hata düzeltmesi) — **bu turda uygulandı**, ekonomi kuralı değişmez.
2. Onay → 037 (R1–R3) ve 038 (item kaynakları) anahtarları **kapalı** olarak yayınlanır.
3. CI 5/5 yeşil (aynı commit) → hazırlık ortamında anahtar açılır, uçtan uca test.
4. Üretimde önce `economy_v2_enabled`, gözlemden sonra `ranked_rewards_v2`.
