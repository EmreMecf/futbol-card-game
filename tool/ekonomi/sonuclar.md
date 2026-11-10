# Ekonomi V2 simülasyon sonuçları

`python -I tool/ekonomi/simulasyon.py` çıktısı. Değerler tekrarların ortalamasıdır.

## 30 gün

| Profil | Maç | Kadro ort. sv | Kadro max sv | Koleksiyon ort. sv | Farklı kart | Sandık (B/G/A/E) | Yuva dolu | Posta | Telafi | Enerjisiz maç | Fazla kopya | Altın sonu | Altın harcanan | BP ort. kademe | BP tamam | Kart kaybı | Kart kazancı | Kilitli gün |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Gunde 2 mac, ucretsiz | 52 | 2.00 | 3.8 | 1.83 | 73 | 33/16/6/1 | %0 | 0 | 0 | 0 | 0 | 544 | 6518 | 27.9 | %0 | 41 | 74 | 3.8 |
| Gunde 5 mac, ucretsiz | 150 | 3.35 | 4.9 | 2.06 | 91 | 96/42/18/4 | %1 | 1 | 0 | 0 | 0 | 194 | 16642 | 50.0 | %100 | 91 | 208 | 0.1 |
| Gunde 10 mac, ucretsiz (kontrol) | 300 | 4.49 | 5.8 | 2.27 | 88 | 191/79/30/6 | %12 | 9 | 2 | 0 | 0 | 540 | 29339 | 50.0 | %100 | 153 | 441 | 0.1 |
| Gunde 10 mac, premium | 300 | 4.74 | 6.0 | 2.41 | 87 | 190/82/33/7 | %17 | 18 | 8 | 0 | 0 | 283 | 35482 | 50.0 | %100 | 159 | 423 | 0.1 |
| Gunde 20 mac, premium plus | 525 | 4.92 | 5.9 | 2.28 | 77 | 256/91/35/6 | %73 | 119 | 18 | 128 | 0 | 470 | 46914 | 44.4 | %88 | 262 | 742 | 3.8 |

## 90 gün

| Profil | Maç | Kadro ort. sv | Kadro max sv | Koleksiyon ort. sv | Farklı kart | Sandık (B/G/A/E) | Yuva dolu | Posta | Telafi | Enerjisiz maç | Fazla kopya | Altın sonu | Altın harcanan | BP ort. kademe | BP tamam | Kart kaybı | Kart kazancı | Kilitli gün |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Gunde 2 mac, ucretsiz | 158 | 3.36 | 4.4 | 2.13 | 81 | 101/47/20/3 | %0 | 0 | 0 | 0 | 0 | 152 | 19589 | 28.0 | %0 | 86 | 231 | 11.2 |
| Gunde 5 mac, ucretsiz | 450 | 5.15 | 6.1 | 2.60 | 92 | 282/133/54/12 | %2 | 1 | 1 | 0 | 0 | 990 | 49089 | 50.0 | %100 | 227 | 654 | 0.0 |
| Gunde 10 mac, ucretsiz (kontrol) | 900 | 6.10 | 7.1 | 3.02 | 87 | 574/240/93/20 | %11 | 21 | 5 | 0 | 0 | 843 | 86189 | 50.0 | %100 | 448 | 1299 | 0.0 |
| Gunde 10 mac, premium | 900 | 6.39 | 7.4 | 3.25 | 85 | 563/250/100/24 | %20 | 60 | 22 | 0 | 0 | 996 | 105596 | 50.0 | %100 | 452 | 1274 | 0.0 |
| Gunde 20 mac, premium plus | 1800 | 7.01 | 8.4 | 4.15 | 84 | 859/309/116/23 | %95 | 464 | 98 | 446 | 2 | 1514 | 164157 | 50.0 | %100 | 884 | 2572 | 0.0 |

## 180 gün

| Profil | Maç | Kadro ort. sv | Kadro max sv | Koleksiyon ort. sv | Farklı kart | Sandık (B/G/A/E) | Yuva dolu | Posta | Telafi | Enerjisiz maç | Fazla kopya | Altın sonu | Altın harcanan | BP ort. kademe | BP tamam | Kart kaybı | Kart kazancı | Kilitli gün |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Gunde 2 mac, ucretsiz | 360 | 4.84 | 5.9 | 2.56 | 89 | 224/114/46/7 | %0 | 0 | 0 | 0 | 0 | 760 | 42962 | 32.5 | %0 | 190 | 504 | 0.0 |
| Gunde 5 mac, ucretsiz | 900 | 5.66 | 7.1 | 3.95 | 88 | 568/266/105/25 | %1 | 3 | 2 | 0 | 0 | 1058 | 96270 | 50.0 | %100 | 460 | 1258 | 0.0 |
| Gunde 10 mac, ucretsiz (kontrol) | 1800 | 6.46 | 7.2 | 4.80 | 89 | 1139/490/185/43 | %12 | 52 | 7 | 0 | 0 | 1272 | 172043 | 50.0 | %100 | 878 | 2606 | 0.0 |
| Gunde 10 mac, premium | 1800 | 6.74 | 8.4 | 5.26 | 88 | 1126/500/202/47 | %22 | 126 | 43 | 0 | 1 | 1141 | 211584 | 50.0 | %100 | 880 | 2592 | 0.0 |
| Gunde 20 mac, premium plus | 3600 | 7.59 | 9.0 | 6.47 | 86 | 1707/602/232/51 | %96 | 921 | 224 | 896 | 145 | 1212 | 333271 | 50.0 | %100 | 1746 | 5168 | 0.1 |

## Seviye normalizasyonu (180 gün sonrası kadro, gerçek düello kuralları)

`saf` = aynı 11 kart, biri profilin seviyelerinde diğeri seviye 1. `eşleşme` = profil kadrosu+seviyeleri vs eşleştirmenin bulacağı benzer güçte (±3) seviye 1 rakip. Beraberlik yarım galibiyet. Hedef: %50 civarı = seviye kazanmayı belirlemiyor.

| Profil | Yöntem | Saf seviye etkisi (kazanma) | Eşleşmede kazanma |
|---|---|---|---|
| Gunde 2 mac, ucretsiz | yok | %51 | %72 |
| Gunde 2 mac, ucretsiz | ham | %100 | %100 |
| Gunde 2 mac, ucretsiz | egri | %100 | %99 |
| Gunde 2 mac, ucretsiz | normalize | %50 | %72 |
| Gunde 5 mac, ucretsiz | yok | %50 | %75 |
| Gunde 5 mac, ucretsiz | ham | %100 | %100 |
| Gunde 5 mac, ucretsiz | egri | %100 | %100 |
| Gunde 5 mac, ucretsiz | normalize | %50 | %73 |
| Gunde 10 mac, ucretsiz (kontrol) | yok | %50 | %62 |
| Gunde 10 mac, ucretsiz (kontrol) | ham | %100 | %100 |
| Gunde 10 mac, ucretsiz (kontrol) | egri | %100 | %100 |
| Gunde 10 mac, ucretsiz (kontrol) | normalize | %50 | %65 |
| Gunde 10 mac, premium | yok | %49 | %59 |
| Gunde 10 mac, premium | ham | %100 | %100 |
| Gunde 10 mac, premium | egri | %100 | %100 |
| Gunde 10 mac, premium | normalize | %52 | %60 |
| Gunde 20 mac, premium plus | yok | %51 | %64 |
| Gunde 20 mac, premium plus | ham | %100 | %100 |
| Gunde 20 mac, premium plus | egri | %100 | %100 |
| Gunde 20 mac, premium plus | normalize | %50 | %62 |
