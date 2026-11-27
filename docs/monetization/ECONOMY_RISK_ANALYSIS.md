# Ekonomi Risk Analizi

Öncelik: **Güvenlik > Oyun dengesi > Oyuncu deneyimi > Uzun vadeli gelir > Kısa vadeli gelir**

## 1. Güç zinciri (bugün)

```
altın ──► kart paketi ──► yeni kart (güç = kartın gücü)
joker / kopya + altın ──► seviye ──► card_level_power açıksa +1..+3 güç (lig tavanlı)
sandık ──► kart + joker + altın (+ elmas, 056)
elmas (ücretsiz) ──► altın (056) / sandığı hemen aç (056)
```

Kural: gerçek para bu zincirin **hiçbir halkasına** doğrudan girmemeli.

## 2. Çatışmalar ve kararlar

| # | Çatışma | Risk | Karar |
|---|---|---|---|
| R1 | Elmas parayla satılırsa elmas→altın→paket | Doğrudan parayla güç | **Ücretli elmas ayrı bakiye** (`users.paid_gems`). Altın değişimi ve sandık açma yalnız **ücretsiz** elmas (`users.gems`) harcar. Ücretli elmas yalnız kozmetik ve güçsüz premium yol. |
| R2 | Premium sezon yolu joker/sandık/altın veriyor | Parayla güç | Premium satın alma **kapalı kalır** (`premium_purchase_enabled=false`). Açılmadan önce premium yolun güç veren ödülleri kozmetiğe çevrilmiş yeni bir sezon tanımı gerekir (Faz 5). |
| R3 | Elmasla sandığı hemen açma | Zaman = kart akışı. Dolaylı avantaj | Yalnız ücretsiz elmasla (R1). Ücretli elmasla sandık açma ayarı (`paid_gems_chest_open_enabled`) varsayılan **kapalı**; açmak simülasyon sonrası ürün kararıdır. |
| R4 | Reklamla elmas/altın | Reklam çiftçiliği, enflasyon | Reklam ödülü: küçük altın (günlük ödül merkezi) ve sandık süresi kısaltma. **Elmas verilmez.** Günde en fazla 3 doğrulanmış reklam, sunucuda. |
| R5 | Mevcut bakiyeler | Haksız değişiklik | Hiçbir bakiye değişmez. Bugünkü elmaslar ücretsiz elmas olarak kalır. |
| R6 | Rastgele içerikli ücretli ürün | Hukuk (Belçika, Brezilya, Kore), mağaza kuralı | İlk sürümde **ücretli rastgele ürün yok**. Elmas paketleri ve kozmetik sabit içerikli. Rastgele ürün satılırsa oranlar sunucudaki aynı ayardan, satın almadan önce gösterilir. |
| R7 | Başlangıç paketi | Güç satışı | İçerik yalnız kozmetik + az miktar **ücretli** elmas (R1 gereği güç veremez). 062: 50 elmas + mağazada satılmayan Çaylak çerçevesi. |
| R8 | Elmasla alınan kozmetik tekrar gelirse altına döner (034 telafi) | Ücretli elmas → kozmetik → altın | 062 mağaza kozmetiklerinin telafisi **0 altın**; aynı kozmetik ikinci kez satılmaz (veritabanı tekilliği). |
| R9 | Görünmeyen ürün satmak | Oyuncuyu yanıltma | Yalnız oyunda çizilen kozmetik satılır; test sunucu tohumuyla istemci çizimini karşılaştırır. |

## 3. Reklam ödülü bütçesi (varsayılan ayar)

| Yerleşim | Günlük | Ödül | Günlük en fazla |
|---|---|---|---|
| Günlük ödül merkezi | 2 | 40 altın | 80 altın |
| Sandık hızlandırma | 1 | 10 dakika | 10 dakika |
| Maç sonu (kapalı) | 1 | 20 altın | 20 altın |
| **Toplam** | **3** (ortak tavan) | | ≈ 100 altın + 10 dk |

Kıyas: bir maç ödül sandığı 10–300 altın, en ucuz paket 500 altın.
Reklamın günlük katkısı en ucuz paketin beşte biri; ilerlemeyi belirgin
hızlandırmaz, enflasyon yaratmaz. Değerler sunucu ayarıdır.

Araştırma notu: brifteki "ödül bileti / kozmetik puan" önerisi yerine altın
seçildi. Gerekçe: ayrı bir reklam parası açmak hem araştırmada hem Unity
örneğinde KPI'ları düşüren bir hata olarak geçiyor; küçük altın ödülü
mevcut defterle izlenir. Ayar ile `reward.type` değiştirilebilir.

## 4. Simülasyon

`tool/ekonomi/monetizasyon_simulasyonu.dart` profilleri 7/30/90 gün için
karşılaştırır (reklamsız, günde 1, günde 3 reklam; düşük/orta/yüksek harcama;
yalnız kozmetik). Ücretli elmas yalnız kozmetiğe gittiği için ücretli
profillerin altın, sandık ve güç eğrisi ücretsiz profille **aynı** çıkmalı;
fark yalnız reklam altınıdır (%3–6). Rapor: `TEST_REPORT.md`.
