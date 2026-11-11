# Düello V3 simülasyonu

Üretildi: `python -I tool/ekonomi/duello_v3.py 4000` (4000 maç / hücre, tohum sabit). Kurallar ve ajanlar dosya başında. Puan: galibiyet 1, beraberlik 0,5.

## 1. İlk açan / ilk inisiyatif avantajı (hedef %45–55)

| Kural | Oyuncular | İlk inisiyatifin puanı | Ortalama tur |
|---|---|---|---|
| V2 | akilli | %43.4 | 11.0 |
| V2 | taktiksiz | %46.0 | 11.0 |
| V3 | akilli | %47.6 | 9.7 |
| V3 | taktiksiz | %50.7 | 9.5 |

## 2. Maç süresi

| Kural | Ortalama tur | En uzun %10 | Tur süresi sınırı | En uzun maç (sınır) | Tipik maç (sürenin %60'ı kullanılırsa) |
|---|---|---|---|---|---|
| V2 | 11.0 | 11 | 2 × 45 sn | 16.5 dk | 9.9 dk |
| V3 | 9.7 | 11 | 5 sn mevki + 15 sn seçim | 3.7 dk | 1.9 dk |

V3 tur dağılımı: 6 tur %1, 7 tur %4, 8 tur %12, 9 tur %20, 10 tur %28, 11 tur %35

## 3. V3 strateji dengesi (benzer güçte kadrolar)

| A | B | A'nın puanı |
|---|---|---|
| akilli | taktiksiz | %86.9 |
| akilli | acgozlu | %56.0 |
| akilli | rastgele | %46.6 |
| acgozlu | taktiksiz | %87.3 |
| rastgele | taktiksiz | %88.6 |

## 4. Güç farkı → kazanma (AYNI kadro, A'nın bütün kartlarına +güç; ikisi de akıllı)

| Fark | V2 | V3 |
|---|---|---|
| +0 | %49.6 | %50.0 |
| +1 | %63.9 | %70.0 |
| +2 | %79.8 | %83.1 |
| +3 | %95.2 | %93.1 |
| +4 | %97.0 | %95.2 |
| +5 | %97.4 | %97.8 |
| +8 | %99.8 | %99.9 |

## 5. Seviye gücü B (bonus = seviye // 2) ve lig tavanı (V3, AYNI kadro, rakip seviye 1)

| A'nın seviyesi | Bonus | Tavansız | Tavan 4 | Tavan 6 | Tavan 8 |
|---|---|---|---|---|---|
| 2 | +1 | %69.6 | %68.8 | %69.0 | %68.7 |
| 4 | +2 | %83.2 | %84.4 | %82.5 | %84.0 |
| 6 | +3 | %93.6 | %83.8 | %93.5 | %92.8 |
| 8 | +4 | %95.7 | %82.2 | %93.1 | %95.2 |
| 10 | +5 | %97.4 | %82.6 | %93.1 | %96.6 |

Aynı ligde en kötü durum (ikisi de tavanda değil): tavan 4'te seviye 4'e karşı seviye 1 = yukarıdaki "Tavan 4" sütununun 4. satırı.

## 6. Seviye eğrisi × eşleştirme (V3; A seviyeli, rakip seviye 1)

`Puana göre`: rakip aynı TEMEL güçte (bugünkü eşleştirme seviyeyi görmez). `Etkin güce göre`: rakibin kartları A oyuncusunun güç + seviye bonusuna denk.

| Eğri | A seviyesi | Bonus | Puana göre | Etkin güce göre |
|---|---|---|---|---|
| B1: seviye // 2 (en fazla +5) | 4 | +2 | %81.5 | %53.6 |
| B1: seviye // 2 (en fazla +5) | 7 | +3 | %88.9 | %53.7 |
| B1: seviye // 2 (en fazla +5) | 10 | +5 | %96.8 | %47.5 |
| B2: L4 +1, L7 +2, L10 +3 | 4 | +1 | %66.1 | %51.4 |
| B2: L4 +1, L7 +2, L10 +3 | 7 | +2 | %80.0 | %53.0 |
| B2: L4 +1, L7 +2, L10 +3 | 10 | +3 | %87.8 | %53.5 |
