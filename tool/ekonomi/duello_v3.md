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

## 3b. V3 saf taktik stratejileri (satır, sütuna karşı puan)

| | hep_pres | hep_kontra | hep_duvar | akilli | taktiksiz |
|---|---|---|---|---|---|
| **hep_pres** | %47.4 | %23.4 | %38.2 | %40.4 | %87.0 |
| **hep_kontra** | %74.9 | %48.1 | %1.1 | %31.1 | %77.3 |
| **hep_duvar** | %59.4 | %97.9 | %50.5 | %84.0 | %98.3 |
| **akilli** | %58.1 | %66.0 | %14.8 | %47.9 | %86.8 |
| **taktiksiz** | %10.3 | %19.7 | %0.7 | %11.2 | %49.3 |

Aynı ajanlarla V2 kuralında akıllı, taktiksize karşı: %82.2 (karşılaştırma aynı simülatörde yapılmalı; prototip raporundaki %67,7 farklı kadro dağılımıyla ölçülmüştü).

## 4. Güç farkı → kazanma (AYNI kadro, A'nın bütün kartlarına +güç; ikisi de akıllı)

| Fark | V2 | V3 |
|---|---|---|
| +0 | %50.1 | %49.8 |
| +1 | %65.9 | %68.3 |
| +2 | %79.8 | %81.8 |
| +3 | %95.1 | %93.9 |
| +4 | %96.6 | %95.7 |
| +5 | %97.9 | %97.8 |
| +8 | %99.8 | %99.9 |

## 5. Seviye gücü B (bonus = seviye // 2) ve lig tavanı (V3, AYNI kadro, rakip seviye 1)

| A'nın seviyesi | Bonus | Tavansız | Tavan 4 | Tavan 6 | Tavan 8 |
|---|---|---|---|---|---|
| 2 | +1 | %70.9 | %69.4 | %68.8 | %67.0 |
| 4 | +2 | %83.0 | %83.1 | %82.0 | %82.0 |
| 6 | +3 | %92.8 | %82.8 | %92.7 | %92.7 |
| 8 | +4 | %96.5 | %82.2 | %92.1 | %96.1 |
| 10 | +5 | %97.4 | %85.0 | %92.5 | %95.6 |

Aynı ligde en kötü durum (ikisi de tavanda değil): tavan 4'te seviye 4'e karşı seviye 1 = yukarıdaki "Tavan 4" sütununun 4. satırı.

## 6. Seviye eğrisi × eşleştirme (V3; A seviyeli, rakip seviye 1)

`Puana göre`: rakip aynı TEMEL güçte (bugünkü eşleştirme seviyeyi görmez). `Etkin güce göre`: rakibin kartları A oyuncusunun güç + seviye bonusuna denk.

| Eğri | A seviyesi | Bonus | Puana göre | Etkin güce göre |
|---|---|---|---|---|
| B1: seviye // 2 (en fazla +5) | 4 | +2 | %78.9 | %52.0 |
| B1: seviye // 2 (en fazla +5) | 7 | +3 | %90.0 | %55.6 |
| B1: seviye // 2 (en fazla +5) | 10 | +5 | %97.0 | %48.9 |
| B2: L4 +1, L7 +2, L10 +3 | 4 | +1 | %67.2 | %54.5 |
| B2: L4 +1, L7 +2, L10 +3 | 7 | +2 | %79.3 | %53.4 |
| B2: L4 +1, L7 +2, L10 +3 | 10 | +3 | %89.4 | %54.4 |
