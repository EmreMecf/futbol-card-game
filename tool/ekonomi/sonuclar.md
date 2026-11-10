# Ekonomi V2 simülasyon sonuçları

`python -I tool/ekonomi/simulasyon.py` çıktısı. Değerler tekrarların ortalamasıdır.

## 30 gün

| Profil | Maç | Kadro ort. sv | Kadro max sv | Koleksiyon ort. sv | Farklı kart | Sandık (B/G/A/E) | Yuva dolu | Posta | Telafi | Enerjisiz maç | Fazla kopya | Altın sonu | Altın harcanan | BP ort. kademe | BP tamam | Kart kaybı | Kart kazancı | Kilitli gün |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Gunde 2 mac, ucretsiz | 60 | 2.27 | 4.1 | 1.99 | 80 | 38/18/8/0 | %0 | 0 | 0 | 0 | 0 | 602 | 7284 | 31.9 | %0 | 47 | 85 | 0.0 |
| Gunde 5 mac, ucretsiz | 150 | 3.29 | 4.8 | 2.07 | 90 | 96/42/18/4 | %1 | 0 | 0 | 0 | 0 | 116 | 16681 | 50.0 | %100 | 90 | 210 | 0.0 |
| Gunde 10 mac, ucretsiz (kontrol) | 300 | 4.54 | 5.6 | 2.20 | 87 | 189/80/31/7 | %13 | 9 | 2 | 0 | 0 | 633 | 29381 | 50.0 | %100 | 154 | 441 | 0.0 |
| Gunde 10 mac, premium | 300 | 4.82 | 6.0 | 2.37 | 89 | 191/80/34/7 | %15 | 14 | 7 | 0 | 0 | 468 | 35368 | 50.0 | %100 | 158 | 427 | 0.0 |
| Gunde 20 mac, premium plus | 600 | 5.61 | 7.1 | 2.47 | 86 | 292/98/42/7 | %87 | 138 | 27 | 146 | 0 | 625 | 54282 | 50.0 | %100 | 298 | 856 | 0.0 |

## 90 gün

| Profil | Maç | Kadro ort. sv | Kadro max sv | Koleksiyon ort. sv | Farklı kart | Sandık (B/G/A/E) | Yuva dolu | Posta | Telafi | Enerjisiz maç | Fazla kopya | Altın sonu | Altın harcanan | BP ort. kademe | BP tamam | Kart kaybı | Kart kazancı | Kilitli gün |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Gunde 2 mac, ucretsiz | 180 | 3.97 | 5.2 | 2.19 | 92 | 113/55/24/3 | %0 | 0 | 0 | 0 | 0 | 319 | 22299 | 32.0 | %0 | 97 | 267 | 0.0 |
| Gunde 5 mac, ucretsiz | 450 | 5.11 | 6.0 | 2.58 | 92 | 281/134/54/12 | %1 | 1 | 1 | 0 | 0 | 1161 | 48067 | 50.0 | %100 | 236 | 632 | 0.0 |
| Gunde 10 mac, ucretsiz (kontrol) | 900 | 6.11 | 7.2 | 3.01 | 86 | 575/240/91/20 | %10 | 16 | 5 | 0 | 0 | 694 | 85774 | 50.0 | %100 | 453 | 1287 | 0.0 |
| Gunde 10 mac, premium | 900 | 6.41 | 7.2 | 3.34 | 85 | 564/250/100/24 | %21 | 63 | 22 | 0 | 0 | 1038 | 105682 | 50.0 | %100 | 450 | 1283 | 0.0 |
| Gunde 20 mac, premium plus | 1800 | 6.98 | 8.2 | 4.18 | 84 | 867/306/116/24 | %94 | 455 | 91 | 446 | 2 | 1503 | 162594 | 50.0 | %100 | 896 | 2544 | 0.0 |

## 180 gün

| Profil | Maç | Kadro ort. sv | Kadro max sv | Koleksiyon ort. sv | Farklı kart | Sandık (B/G/A/E) | Yuva dolu | Posta | Telafi | Enerjisiz maç | Fazla kopya | Altın sonu | Altın harcanan | BP ort. kademe | BP tamam | Kart kaybı | Kart kazancı | Kilitli gün |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Gunde 2 mac, ucretsiz | 360 | 4.85 | 5.9 | 2.54 | 90 | 226/112/46/7 | %0 | 0 | 0 | 0 | 0 | 750 | 42864 | 32.5 | %0 | 191 | 501 | 0.0 |
| Gunde 5 mac, ucretsiz | 900 | 5.67 | 7.0 | 3.95 | 88 | 570/263/106/25 | %1 | 3 | 2 | 0 | 0 | 1060 | 96170 | 50.0 | %100 | 462 | 1252 | 0.0 |
| Gunde 10 mac, ucretsiz (kontrol) | 1800 | 6.47 | 7.2 | 4.76 | 88 | 1142/488/184/43 | %13 | 53 | 8 | 0 | 0 | 1384 | 171918 | 50.0 | %100 | 879 | 2602 | 0.0 |
| Gunde 10 mac, premium | 1800 | 6.67 | 8.2 | 5.31 | 88 | 1128/499/201/47 | %22 | 126 | 43 | 0 | 0 | 1263 | 211846 | 50.0 | %100 | 882 | 2593 | 0.0 |
| Gunde 20 mac, premium plus | 3600 | 7.65 | 9.1 | 6.42 | 86 | 1698/610/225/51 | %97 | 933 | 230 | 896 | 132 | 1347 | 334490 | 50.0 | %100 | 1728 | 5191 | 0.0 |

## Seviye normalizasyonu (180 gün sonrası kadro, gerçek düello kuralları)

`saf` = aynı 11 kart, biri profilin seviyelerinde diğeri seviye 1. `eşleşme` = profil kadrosu+seviyeleri vs eşleştirmenin bulacağı benzer güçte (±3) seviye 1 rakip. Beraberlik yarım galibiyet. Hedef: %50 civarı = seviye kazanmayı belirlemiyor.

| Profil | Yöntem | Saf seviye etkisi (kazanma) | Eşleşmede kazanma |
|---|---|---|---|
| Gunde 2 mac, ucretsiz | yok | %51 | %72 |
| Gunde 2 mac, ucretsiz | ham | %100 | %100 |
| Gunde 2 mac, ucretsiz | egri | %100 | %100 |
| Gunde 2 mac, ucretsiz | normalize | %50 | %72 |
| Gunde 5 mac, ucretsiz | yok | %50 | %77 |
| Gunde 5 mac, ucretsiz | ham | %100 | %100 |
| Gunde 5 mac, ucretsiz | egri | %99 | %99 |
| Gunde 5 mac, ucretsiz | normalize | %50 | %76 |
| Gunde 10 mac, ucretsiz (kontrol) | yok | %50 | %69 |
| Gunde 10 mac, ucretsiz (kontrol) | ham | %100 | %100 |
| Gunde 10 mac, ucretsiz (kontrol) | egri | %100 | %100 |
| Gunde 10 mac, ucretsiz (kontrol) | normalize | %50 | %69 |
| Gunde 10 mac, premium | yok | %49 | %69 |
| Gunde 10 mac, premium | ham | %100 | %100 |
| Gunde 10 mac, premium | egri | %100 | %100 |
| Gunde 10 mac, premium | normalize | %52 | %68 |
| Gunde 20 mac, premium plus | yok | %51 | %67 |
| Gunde 20 mac, premium plus | ham | %100 | %100 |
| Gunde 20 mac, premium plus | egri | %100 | %100 |
| Gunde 20 mac, premium plus | normalize | %50 | %65 |
