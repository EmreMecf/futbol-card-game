# Rekabet Analizi — Karşılaştırmalı Simülasyonlar

> Bu dosya `dart run bin/karsilastir.dart` ile üretildi. Her alternatif AYNI tohum ve kadrolarla bugünkü motora karşı ölçüldü. **Hiçbiri oyunda aktif değil.**

## A) İlk turu açanın dezavantajı

| Varyant | İlk açan (Akıllı) | İlk açan (Taktiksiz) | Beceri: Akıllı vs Taktiksiz | +4 güçlü kadro | −3 zayıf kadro |
|---|---|---|---|---|---|
| Bugün (canlı kural) | %44.4 | %44.5 | %66.5 | %71.3 | %34.5 |
| S1: ilk açana +1 enerji | %44.6 | %44.3 | %66.8 | %70.7 | %34.0 |
| S1b: ilk açana +2 enerji | %45.7 | %44.3 | %66.4 | %71.2 | %34.4 |
| S2: kör cevap (her tur) | %50.0 | %50.0 | %59.6 | %71.7 | %35.7 |
| S2b: kör cevap (sadece ilk tur) | %48.7 | %51.6 | %66.2 | %72.8 | %34.8 |
| S3: açma sırası dönüşümlü | %44.0 | %47.5 | %66.9 | %71.1 | %35.0 |
| S4: turu kaybeden açar | %43.1 | %41.3 | %65.4 | %70.6 | %34.5 |

Hedef: ilk açan %45–55 (ideal %50); beceri ve güç ödülleri bugünküne yakın kalmalı.

## B) Kural sürümü 2 (canlı) vs 3 adayı (özellik → taktik çarpanı, ±%20)

| | Sürüm 2 | Sürüm 3 |
|---|---|---|
| Zorunlu denge hedefleri | ✅ | ✅ |
| Turu çevirme oranı | %7.7 | %7.5 |
| Akıllı vs Taktiksiz | %65.7 | %65.7 |
| Yüksek Pres: mevkiler arası tur kazanma farkı | %1.0 | %3.5 |
| Kontra Atak: mevkiler arası tur kazanma farkı | %4.6 | %4.2 |
| Savunma Duvarı: mevkiler arası tur kazanma farkı | %1.8 | %2.7 |
| "Tip Bilen" vs Akıllı (Sürüm 2) | %54.6 | — |
| "Tip Bilen" vs Akıllı (Sürüm 3) | — | %55.9 |

"Tip Bilen": turu açarken taktiğe en uygun oyuncu tipini sürer. Sürüm 2'de de önde olması oyuncu tipinden değil, güçlü kartları saklayıp zayıflarla açmasından (kart yönetimi). Sürüm 3'ün katkısı bu iki satırın farkı kadar.

## C) Eşleştirme: MMR + kadro gücü

**Nüfus: 240 oyuncu** (%30 başlangıç, %45 orta, %25 kıdemli kadro; tarzlar eşit)

| Mod | Umutsuz maç | Yeni gelen: puan (ilk 20) | Yeni gelen: umutsuz | Bekleme ort / p90 | Sıralamada beceri ÷ kadro | Başlangıç MMR / Kıdemli MMR |
|---|---|---|---|---|---|---|
| Bugün: sadece MMR | %19.9 | %28.1 | %48.8 | 1 / 0 sn | 0.25 | 561 / 1711 |
| MMR + kadro gücü bandı | %0.7 | %50.7 | %0.0 | 4 / 10 sn | 3.59 | 934 / 1194 |
| Birleşik puan (MMR + kadro gücü) | %0.7 | %51.9 | %0.0 | 6 / 20 sn | 4.64 | 943 / 1131 |

**Nüfus: 40 oyuncu** (%30 başlangıç, %45 orta, %25 kıdemli kadro; tarzlar eşit)

| Mod | Umutsuz maç | Yeni gelen: puan (ilk 20) | Yeni gelen: umutsuz | Bekleme ort / p90 | Sıralamada beceri ÷ kadro | Başlangıç MMR / Kıdemli MMR |
|---|---|---|---|---|---|---|
| Bugün: sadece MMR | %26.7 | %27.1 | %46.7 | 5 / 10 sn | 0.11 | 520 / 2196 |
| MMR + kadro gücü bandı | %9.1 | %41.3 | %9.2 | 15 / 40 sn | 1.02 | 833 / 1682 |
| Birleşik puan (MMR + kadro gücü) | %8.3 | %44.2 | %0.8 | 18 / 50 sn | 1.03 | 793 / 1618 |

Umutsuz maç: ortalama kadro gücü farkı ≥ 4 (~%70'e %30 sonuç). "Beceri ÷ kadro" > 1 ise sıralama ustalığı kadrodan çok yansıtıyor.

## D) Ekonomi: kalıcı kart kaybı

**Eşleştirme: sadece MMR (bugün)** — 160 oyuncu, kişi başı 120 maç, yeni gelenler ortada katılır

| Kural | Kilitlenen (oynayamayan) | Kadro gücü ort (p10–p90) | En çok / en az kazanan %20: güç artışı | Kart/oyuncu | Legend/oyuncu | Yeni gelen puanı | El değiştiren kart/oyuncu |
|---|---|---|---|---|---|---|---|
| Bugün: kaybeden 3 korumasız kartını kaybeder | %59.1 | 82.4 (78.7–85.5) | +14.8 / +11.8 | 49.6 | 0.02 | %26.1 | 38.7 |
| Kalıcı kayıp yok | %0.0 | 82.8 (79.0–85.9) | +16.3 / +13.2 | 79.0 | 0.08 | %27.7 | 0.0 |
| Kayıp yok + kazanana 1 ödül kartı | %0.0 | 86.3 (83.4–89.2) | +20.1 / +16.1 | 135.1 | 0.11 | %22.5 | 0.0 |
| Kaybeden 1 kart kaybeder | %9.7 | 81.5 (77.5–85.2) | +15.1 / +10.4 | 75.8 | 0.07 | %23.0 | 58.6 |

**Eşleştirme: MMR + kadro gücü (024 combined)** — 160 oyuncu, kişi başı 120 maç, yeni gelenler ortada katılır

| Kural | Kilitlenen (oynayamayan) | Kadro gücü ort (p10–p90) | En çok / en az kazanan %20: güç artışı | Kart/oyuncu | Legend/oyuncu | Yeni gelen puanı | El değiştiren kart/oyuncu |
|---|---|---|---|---|---|---|---|
| Bugün: kaybeden 3 korumasız kartını kaybeder | %54.5 | 82.3 (79.0–85.8) | +16.5 / +11.4 | 51.1 | 0.04 | %38.8 | 40.0 |
| Kalıcı kayıp yok | %0.0 | 82.9 (79.8–86.0) | +15.5 / +13.0 | 78.8 | 0.06 | %45.2 | 0.0 |
| Kayıp yok + kazanana 1 ödül kartı | %0.0 | 86.1 (83.5–88.9) | +19.6 / +17.4 | 134.8 | 0.11 | %42.2 | 0.0 |
| Kaybeden 1 kart kaybeder | %4.5 | 81.6 (77.4–85.5) | +14.7 / +11.8 | 77.0 | 0.06 | %39.4 | 60.0 |

Varsayımlar: başlangıç paketi gerçek dağılımla (2 KL, 5 DF, 5 OS, 3 FV); galibiyet +100 coin; oyuncu coin yettikçe Standart Paket (500 coin, gerçek oranlar) alır; kaybeden önce yedeği olmayan mevkileri, sonra en güçlü kartları korur (canlı kural için en iyimser davranış). Kilitlenen: kadrosu eksik kaldığı ve coin kazanamadığı için bir daha maça giremeyen oyuncu.

