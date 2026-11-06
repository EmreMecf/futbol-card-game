# Taktik Sistemi — Prototip (FAZ 5)

> **Taktik sistemi kullanıcı onayıyla oyuna alındı.** Kurallar artık
> `database/migrations/021_tactics.sql` içinde yaşıyor. Bu paket bir
> simülasyon ve denge aracı olarak kalıyor; uygulama ve sunucu onu kod
> olarak kullanmıyor. `test/tactics_test.dart`, SQL'deki sayıların buradaki
> `TacticRules.balanced` ile aynı olduğunu denetler (biri değişip diğeri
> unutulursa denge raporu geçersiz kalır).

MD bölüm 7: *"Yeni taktik motorunu mevcut maç kurallarının yerine doğrudan
koyma. Önce ayrı bir prototipte test et ve sonuçlarını bana sun."*

## Ne var?

| Dosya | İçerik |
|---|---|
| `lib/src/tactics.dart` | 3 taktik, enerji, dengeleme sayıları, tur çözümü |
| `lib/src/simulation.dart` | Sunucu kurallarının birebir kopyası maç simülatörü + yapay oyuncular |
| `lib/src/balance.dart` | Denge hedefleri, ölçüm, Türkçe rapor |
| `bin/simulate.dart` | Raporu üretir: **[RAPOR.md](RAPOR.md)** |
| `tool/ayar_dene.dart` | Birkaç denge ayarını yan yana dener |
| `tool/tohumlar.dart` | Sonucun şans eseri olmadığını farklı tohumlarla doğrular |

## Çalıştırma

```bash
cd packages/tactics_prototype
dart run bin/simulate.dart        # RAPOR.md'yi üretir (çift başına 2000 maç)
dart run bin/simulate.dart 5000   # daha kesin
dart test                         # kurallar + denge + izolasyon
```

## Taktikler (taş - kâğıt - makas)

| | Enerji | Etki | Kırdığı | Kırıldığı |
|---|---|---|---|---|
| 🔥 Yüksek Pres | 3 | +9 | Savunma Duvarı | Kontra Atak (bonus sıfır, rakip +13) |
| ⚡ Kontra Atak | 2 | +2, rakip pres yaparsa +13 | Yüksek Pres | Savunma Duvarı (bonus sıfır) |
| 🛡️ Savunma Duvarı | 1 | savunurken +6, açarken +2 | Kontra Atak | Yüksek Pres (bonus sıfır) |

Enerji: 2 ile başlanır, her tur +1, en fazla 5.

## Korunan kurallar

Aynı mevki zorunluluğu, **Legend kuralı** (hiçbir taktik bunu aşamaz —
abartılı bonuslarla bile testli), beraberlik/pot ve maç bitirme kuralları.

## Oyuna alınırken yapılanlar

Bu prototip sadece KURALI ve DENGEYİ kanıtlıyor. Oyuna almak ayrı bir iş:
1. Sunucu: `match_moves`'a taktik, `match_players`'a enerji kolonu;
   `_resolve_round()` bonusu `compare_cards()` ÇAĞRILDIKTAN SONRA değil,
   güç karşılaştırmasına eklemeli (Legend kuralı önce).
2. Taktik, cevap veren tarafa tur çözülene kadar GİZLİ kalmalı.
3. Arayüz: arena ekranında enerji çubuğu ve 3 taktik düğmesi.
4. Gerçek oyuncu verisiyle yeniden dengeleme (simülasyon yapay oyuncu kullanıyor).
