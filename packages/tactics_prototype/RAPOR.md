# Taktik Sistemi — Denge Raporu (PROTOTİP)

> **Bu sistem oyunda AKTİF DEĞİL.** Gerçek maç kuralları (`_resolve_round`, `compare_cards`) değişmedi. Bu rapor, taktik fikrinin dengeli olup olmadığını simülasyonla ölçmek için üretildi. Oyuna alınıp alınmayacağına karar sizin.

Rapor `dart run bin/simulate.dart` ile üretildi. Tohum: `2026` (aynı tohum = aynı sonuç). Her tarz çifti için **3000** maç, toplam **693000** tur.

## Sonuç: ✅ Bütün denge hedefleri tuttu

| Kontrol | Ölçülen | Hedef | Durum |
|---|---|---|---|
| "Hep Yüksek Pres" herkesi ezmiyor | en zayıf eşleşmesi %41.6 | en az bir eşleşmede ≤ %60.0 | ✅ |
| "Hep Kontra Atak" herkesi ezmiyor | en zayıf eşleşmesi %32.9 | en az bir eşleşmede ≤ %60.0 | ✅ |
| "Hep Savunma Duvarı" herkesi ezmiyor | en zayıf eşleşmesi %36.2 | en az bir eşleşmede ≤ %60.0 | ✅ |
| "Hep Kontra Atak", "Hep Yüksek Pres"ı yener | %57.0 | > %50 | ✅ |
| "Hep Savunma Duvarı", "Hep Kontra Atak"ı yener | %67.1 | > %50 | ✅ |
| "Hep Yüksek Pres", "Hep Savunma Duvarı"ı yener | %59.7 | > %50 | ✅ |
| Akıllı oyuncu taktiksizi yener | %67.5 | %55.0 – %72.0 | ✅ |
| Taktiklerin turu çevirme oranı | %7.6 | %5.0 – %20.0 | ✅ |
| Legend kuralı ihlali | 0 / 693000 tur | 0 | ✅ |

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

| | Taktiksiz | Rastgele | Hep Yüksek Pres | Hep Kontra Atak | Hep Savunma Duvarı | Uyarlanır | Akıllı |
|---|---|---|---|---|---|---|---|
| **Taktiksiz** | — | %38.8 | %31.4 | %44.8 | %32.6 | %49.5 | %32.5 |
| **Rastgele** | %61.2 | — | %48.4 | %53.7 | %43.9 | %49.7 | %41.2 |
| **Hep Yüksek Pres** | %68.6 | %51.6 | — | %43.0 | %59.7 | %42.9 | %41.6 |
| **Hep Kontra Atak** | %55.2 | %46.3 | %57.0 | — | %32.9 | %34.6 | %41.3 |
| **Hep Savunma Duvarı** | %67.4 | %56.1 | %40.3 | %67.1 | — | %43.0 | %36.2 |
| **Uyarlanır** | %50.5 | %50.3 | %57.1 | %65.4 | %57.0 | — | %41.7 |
| **Akıllı** | %67.5 | %58.8 | %58.4 | %58.7 | %63.8 | %58.3 | — |

**Tarzlar:** *Taktiksiz* = bugünkü oyun. *Rastgele* = acemi. *Hep X* = gücü yettikçe hep aynı taktik. *Uyarlanır* = rakibin en çok kullandığı taktiğin karşısını seçer. *Akıllı* = rakibin kartını görüp hesap yapar, enerji saklar. Kart seçimi bütün tarzlarda aynı; fark sadece taktik kararlarından geliyor.

## Taktik kullanımı

| Taktik | Kullanıldığı tur | O turu kazanma oranı |
|---|---|---|
| Taktik yok | 745887 | %45.5 |
| Yüksek Pres | 132067 | %58.7 |
| Kontra Atak | 183986 | %54.1 |
| Savunma Duvarı | 324060 | %50.8 |

