# Taktik Sistemi — Denge Raporu

> Taktik sistemi kullanıcı onayıyla oyuna alındı (`database/migrations/021_tactics.sql`, kural sürümü 2). Bu rapor oyundaki sayılarla birebir aynı kurallar üzerinde simülasyondur; sayılar değişirse yeniden üretilmelidir.

Rapor `dart run bin/simulate.dart` ile üretildi. Tohum: `2026` (aynı tohum = aynı sonuç). Her tarz çifti için **2000** maç, toplam **792000** tur.

## Sonuç

- ✅ Bütün **zorunlu** hedefler tuttu.
- ❌ **3 izlenen hedef tutmadı.** Bunlar temel kural ya da eşleştirme değişikliği gerektiriyor; kullanıcı onayı bekliyor (geçti sayılmaz).

| Kontrol | Ölçülen | Hedef | Tür | Durum |
|---|---|---|---|---|
| "Hep Yüksek Pres" herkesi ezmiyor | en zayıf eşleşmesi %41.0 | en az bir eşleşmede ≤ %60.0 | zorunlu | ✅ |
| "Hep Kontra Atak" herkesi ezmiyor | en zayıf eşleşmesi %32.3 | en az bir eşleşmede ≤ %60.0 | zorunlu | ✅ |
| "Hep Savunma Duvarı" herkesi ezmiyor | en zayıf eşleşmesi %37.0 | en az bir eşleşmede ≤ %60.0 | zorunlu | ✅ |
| "Hep Kontra Atak", "Hep Yüksek Pres"ı yener | %58.6 | > %50 | zorunlu | ✅ |
| "Hep Savunma Duvarı", "Hep Kontra Atak"ı yener | %67.7 | > %50 | zorunlu | ✅ |
| "Hep Yüksek Pres", "Hep Savunma Duvarı"ı yener | %59.6 | > %50 | zorunlu | ✅ |
| Akıllı oyuncu taktiksizi yener | %67.7 | %55.0 – %72.0 | zorunlu | ✅ |
| Taktiklerin turu çevirme oranı | %7.7 | %5.0 – %20.0 | zorunlu | ✅ |
| Legend kuralı ihlali | 0 / 792000 tur | 0 | zorunlu | ✅ |
| Hiçbir basit tarz herkesi yenmiyor | yok | yok | zorunlu | ✅ |
| "Hep Yüksek Pres" için iyi bir cevap var | en kötü eşleşmesi %41.0 | ≤ %45.0 | zorunlu | ✅ |
| "Hep Kontra Atak" için iyi bir cevap var | en kötü eşleşmesi %32.3 | ≤ %45.0 | zorunlu | ✅ |
| "Hep Savunma Duvarı" için iyi bir cevap var | en kötü eşleşmesi %37.0 | ≤ %45.0 | zorunlu | ✅ |
| "Biriktirici" için iyi bir cevap var | en kötü eşleşmesi %37.5 | ≤ %45.0 | zorunlu | ✅ |
| "Harcayıcı" için iyi bir cevap var | en kötü eşleşmesi %37.4 | ≤ %45.0 | zorunlu | ✅ |
| Güç farkı arttıkça güçlü taraf daha çok kazanır | +0: %48.3, +2: %60.7, +4: %69.5, +8: %86.0 | artan | zorunlu | ✅ |
| Taktikler kart gücü farkını büyütmüyor / silmiyor | en büyük kayma %2.4 | ≤ %5.0 | zorunlu | ✅ |
| Taktik kullanmayan yeni oyuncu ezilmiyor | en kötü eşleşmesi %32.3 | ≥ %30.0 | izlenen | ✅ |
| İlk açan avantajı yok (Taktiksiz) | ilk açanın puanı %44.8 | %45.0 – %55.0 | izlenen | ❌ |
| İlk açan avantajı yok (Akıllı) | ilk açanın puanı %44.5 | %45.0 – %55.0 | izlenen | ❌ |
| Başlangıç kadrosu kıdemliye karşı şanslı | başlangıç kadrosunun puanı %0.0 | ≥ %10.0 | izlenen | ❌ |

## Eşit olmayan oyuncular

**Güç farkı** (güçlü kadronun her kartı +g güç):

| g | İkisi taktiksiz | İkisi Akıllı |
|---|---|---|
| +0 | %48.3 | %48.3 |
| +2 | %63.0 | %60.7 |
| +4 | %71.1 | %69.5 |
| +8 | %87.7 | %86.0 |

**Nadirlik** (Başlangıç: Bronz/Gümüş/Altın; Kıdemli: Altın/Diamond/%12 Legend):

- ikisi Akıllı: başlangıç kadrosu %0.0
- başlangıç Akıllı, kıdemli taktiksiz: başlangıç kadrosu %0.0

**İlk turu açan:**

- Taktiksiz vs Taktiksiz: ilk açan %44.8
- Akıllı vs Akıllı: ilk açan %44.5

## Taktikler

| Taktik | Enerji | Etki | Güçlü olduğu durum | Zayıf olduğu durum | Kırdığı | Kırıldığı |
|---|---|---|---|---|---|---|
| 🔥 Yüksek Pres | 3 | +9 güç | Rakip duvar kurduğunda ya da taktik kullanmadığında | Rakip kontraya çıkarsa bonus SIFIR, üstelik rakip +13 alır; en pahalı taktik | Savunma Duvarı | Kontra Atak |
| ⚡ Kontra Atak | 2 | +2 (rakip pres yaparsa +13) | Rakip pres yaptığında | Tek başına neredeyse etkisiz; duvara çarparsa SIFIR | Yüksek Pres | Savunma Duvarı |
| 🛡️ Savunma Duvarı | 1 | Savunurken +6, turu açarken +2 | Turu rakip açtığında (savunma) | Turu sen açarken zayıf; pres onu SIFIRLAR | Kontra Atak | Yüksek Pres |

**Enerji:** Maça 2 enerjiyle başlanır, her tur +1, en fazla 5. Harcanmayan enerji birikir. İki tarafın enerjisi de herkese açık.

**Bilgi:** Turu açan, kartını ve taktiğini gizli seçer. Cevap veren rakibin kartını görür ama taktiğini görmez. Taktikler tur çözülürken aynı anda açılır.

**Korunan kurallar:** Aynı mevki zorunluluğu, Legend kuralı (taktik bunu aşamaz), beraberlik/pot kuralı ve maç bitirme kuralı değişmedi.

## Tarzlar arası kazanma oranı

Satırdaki tarzın sütundaki tarza karşı puanı (galibiyet = 1, beraberlik = ½).

| | Taktiksiz | Rastgele | Hep Yüksek Pres | Hep Kontra Atak | Hep Savunma Duvarı | Biriktirici | Harcayıcı | Uyarlanır | Akıllı |
|---|---|---|---|---|---|---|---|---|---|
| **Taktiksiz** | — | %39.6 | %33.9 | %44.4 | %32.9 | %46.4 | %32.6 | %50.1 | %32.3 |
| **Rastgele** | %60.4 | — | %50.0 | %51.6 | %44.2 | %48.4 | %42.8 | %49.5 | %40.3 |
| **Hep Yüksek Pres** | %66.1 | %50.0 | — | %41.4 | %59.6 | %42.1 | %60.0 | %43.2 | %41.0 |
| **Hep Kontra Atak** | %55.6 | %48.4 | %58.6 | — | %32.3 | %53.5 | %32.9 | %34.8 | %42.7 |
| **Hep Savunma Duvarı** | %67.2 | %55.8 | %40.4 | %67.7 | — | %48.0 | %49.7 | %42.8 | %37.0 |
| **Biriktirici** | %53.6 | %51.6 | %57.9 | %46.5 | %52.0 | — | %52.3 | %37.5 | %40.9 |
| **Harcayıcı** | %67.5 | %57.2 | %40.0 | %67.1 | %50.3 | %47.7 | — | %41.0 | %37.4 |
| **Uyarlanır** | %49.9 | %50.5 | %56.8 | %65.2 | %57.3 | %62.5 | %59.0 | — | %41.8 |
| **Akıllı** | %67.7 | %59.7 | %59.0 | %57.3 | %62.9 | %59.1 | %62.6 | %58.2 | — |

**Tarzlar:** *Taktiksiz* = bugünkü oyun. *Rastgele* = acemi. *Hep X* = gücü yettikçe hep aynı taktik. *Biriktirici* = enerji dolunca pres, cevapta kontra. *Harcayıcı* = her fırsatta harcar. *Uyarlanır* = rakibin en çok kullandığı taktiğin karşısını seçer. *Akıllı* = rakibin kartını görüp hesap yapar, enerji saklar. Kart seçimi bütün tarzlarda aynı; fark sadece taktik kararlarından geliyor.

## Taktik kullanımı

| Taktik | Kullanıldığı tur | O turu kazanma oranı |
|---|---|---|
| Taktik yok | 780331 | %45.2 |
| Yüksek Pres | 143079 | %58.7 |
| Kontra Atak | 190615 | %55.3 |
| Savunma Duvarı | 469975 | %50.4 |

