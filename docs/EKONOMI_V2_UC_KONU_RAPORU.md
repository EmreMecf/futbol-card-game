# Ekonomi V2 — Üç konu raporu (10 Kasım 2026)

**Durum: DEĞERLENDİRME. Hiçbir ekonomi kuralı değiştirilmedi; aşağıdaki öneriler onay bekliyor.**

Kaynaklar: `tool/ekonomi/karsilastirma.py` (5 senaryo × 5 profil × 30/90/180 gün, 10 tekrar,
gerçekçi oyuncu: günlük maç ~N(ort., %35), günlerin %15'i boş, maçların %3'ü 4. turdan önce
biter), ham tablolar `tool/ekonomi/karsilastirma.md`. Genel kalite kontrolü:
`docs/EKONOMI_V2_KALITE_KONTROLU.md`.

Senaryolar: **S0** mevcut · **S1** kayıpsız · **S3** S1 + her meşru maça sandık (enerjisizse
Bronz) · **S4** S3 + galibiyette +1 gelişim kopyası · (S2: S1 + enerjisiz maça da tam sandık).

---

## 1. Kalıcı kart kaybının kaldırılması

**Bugün:** dereceli maçta kaybeden, korumaya almadığı 3 kartı kalıcı olarak kazanana verir.

| 180 gün | Günde 2 maç | Günde 5 | Günde 10 | Günde 20 |
|---|---|---|---|---|
| El değiştiren kart (S0) | 164 | 384 | 741 | 1.466 |
| Farklı kart sayısı S0 → S1 | 90 → 94 | 88 → 98 | 89 → 100 | 86 → 99 |
| Acil Kadro kullanımı S0 → S1 | 0,1 → 0 | 0,2 → 0 | 0,1 → 0 | 0,6 → 0 |

- **Artı:** kayıp korkusu ve "kadrom kilitlendi" durumu biter; Acil Kadro ihtiyacı sıfırlanır;
  koleksiyon daha çeşitli kalır. Mağlubiyet cezası yalnız MMR olur (−25, değişmez).
- **Eksi (ölçüldü):** kazanılan kartlar fazla kopya olarak seviyeyi besliyordu. Kayıp kalkınca
  kadro ortalama seviyesi **%25–35 düşer** (180 günde günde 2 maç 4,59 → 3,00; günde 20 maç
  6,98 → 5,22). Galibiyette verilen +1 koruma hakkı dereceli maçta anlamsızlaşır.
- **Öneri (R2 + R3):** transfer kalkar; +1 koruma hakkının yerine **galibiyette kadrodaki rastgele
  bir futbolcuya +1 gelişim kopyası** (fiziksel kart değil). Bu, kaybolan ilerlemeyi geri getirir
  (S4: 4,96 / 5,85 / 6,57 / 7,25 — S0'ın biraz üstü). Koruma verisi silinmez; ileride ayrı bir
  "riskli mod" için saklanır.
- **Dokunulan yer:** maç bitişindeki kart transferi (ödül katmanı). Düello motoru, tur çözümü,
  MMR ve eşleştirme değişmez. Temel düello kuralına dokunduğu için **ayrı açık onay** gerekir.

## 2. Her tamamlanan meşru maçta sandık

**Bugün:** sandık yalnız ödül enerjisi (en fazla 10, 96 dakikada 1, günde 15) varsa verilir;
4. turdan önce biten maç (K6) sandık vermez.

| 180 gün | Günde 2 | Günde 5 | Günde 10 | Günde 20 |
|---|---|---|---|---|
| Enerjisiz kaçan sandık (S0) | 0 | 0 | 3 | **709** (%23) |
| Telafi (adet / altın) S0 | 0 / 0 | 1 / 367 | 10 / 2.220 | 59 / 8.528 |
| Telafi S2 (enerjisize tam sandık) | 0 / 18 | 1 / 349 | 11 / 2.170 | **275 / 34.623** |
| Telafi S3 (enerjisize Bronz) | 0 / 18 | 1 / 349 | 11 / 2.137 | 63 / 9.145 |
| Altın geliri/gün S0 → S3 | 197 → 205 | 470 → 461 | 823 → 801 | 1.373 → 1.476 |

- Enerji günde 15 maçın altında **hiç bitmiyor**: değişiklik yalnız günde 15+ maç oynayanı etkiler.
- Enerjisiz maça **tam** sandık (S2) tek kilit kuyruğunu taşırır: telafi 4,6 kat, ~34.600 altın
  (enflasyon ve "sandık boşa gitti" hissi).
- **Öneri (R1):** her meşru maç (≥ 4 tur) iki oyuncuya da **1 sandık**. Enerji varsa (1 harcanır)
  sandık türü sonuç tablosundan ve sezon XP'si tam; yoksa **Bronz** (anında açılır, yuvaya girmez)
  ve XP %25. Enerji "bonus" olur: sandık kalitesi + XP. Kuyruk taşması bugünkü düzeyde kalır;
  ağır oyuncunun altın geliri +%7.

## 3. Futbolcu seviyeleri: anlamlı ilerleme, Ranked dengesi korunur

**K1 korunur:** hiçbir senaryoda seviye maç gücüne, kimyaya ya da eşleştirmeye girmez
(035 testinde maç/eşleştirme fonksiyonlarının sezon ve seviye verisini okumadığı doğrulanıyor).

| Kadro ort. seviye (30 / 90 / 180 gün) | Günde 2 | Günde 5 | Günde 10 | Günde 20 |
|---|---|---|---|---|
| S0 mevcut | 2,14 / 3,65 / 4,59 | 3,14 / 4,91 / 5,64 | 4,31 / 5,82 / 6,48 | 5,14 / 6,73 / 6,98 |
| S3 (kayıp yok, telafisiz) | 2,30 / 2,65 / 3,00 | 2,45 / 2,95 / 3,68 | 2,65 / 3,39 / 4,67 | 2,71 / 3,93 / 5,15 |
| **S4 öneri** | 2,94 / 4,42 / 4,96 | 3,65 / 5,34 / 5,85 | 4,36 / 6,18 / 6,57 | 5,25 / 6,86 / 7,25 |

| İlk 5. seviye (medyan gün, 30 günde ulaşan oran) | Günde 2 | Günde 5 | Günde 10 | Günde 20 |
|---|---|---|---|---|
| S0 | 22,5 (%40) | 18 (%90) | 7 | 4,5 |
| S4 | 24 (%60) | **10,5 (%100)** | 4,5 | 3 |

- S4 ilerlemeyi her galibiyete bağlar: oyuncu her kazandığında kadrosundan birinin ilerlediğini görür.
- Ranked'de güç farkı oluşmaz (K1). Seviyenin değeri: ustalık ödülleri (033), kart rozeti, sandık
  kopyalarının boşa gitmemesi ve 10. seviyede joker parçaya dönüşüm.
- **İsteğe bağlı görsel ek (ekonomiyi değiştirmez):** 5. ve 10. seviyede kartta ustalık çerçevesi
  (yalnız görünüm, FAZ 6 kozmetik altyapısıyla).

---

## Onay bekleyen kararlar

| # | Kural | Onay |
|---|---|---|
| R1 | Her meşru maça sandık; enerjisizse Bronz + %25 XP | ☐ |
| R2 | Dereceli maçta kalıcı kart transferi kalkar (temel düello kapsamı) | ☐ |
| R3 | Galibiyette +1 gelişim kopyası (+1 koruma hakkının yerine) | ☐ |
