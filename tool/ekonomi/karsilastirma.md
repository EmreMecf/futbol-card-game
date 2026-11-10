# Ekonomi V2 kalite kontrolü — karşılaştırmalı simülasyon (10 tekrar / hücre)

Üretildi: `python -I tool/ekonomi/karsilastirma.py`. Senaryolar ve varsayımlar dosya başında.

## 30 gün

| Senaryo | Profil | Maç | Sandık | Enerjisiz kaçan | Telafi (adet / altın) | Altın/gün | Farklı kart | Kart kaybı | Kadro sv | Seviye/hafta | Kilitli gün | Acil Kadro | İlk L5 günü |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S0 Mevcut | Gunde 2 mac | 51 | 52 | 0 | 0 / 0 | 194 | 77 | 36 | 2.14 | 18.6 | 0.0 | 0.1 | 22.5 (%40) |
| S0 Mevcut | Gunde 5 mac | 128 | 133 | 0 | 0 / 0 | 455 | 88 | 77 | 3.14 | 27.7 | 0.0 | 0.2 | 18 (%90) |
| S0 Mevcut | Gunde 10 mac | 265 | 264 | 1 | 1 / 295 | 839 | 89 | 141 | 4.31 | 31.1 | 0.0 | 0.1 | 7.0 (%100) |
| S0 Mevcut | Gunde 20 mac | 500 | 362 | 116 | 9 / 1381 | 1356 | 86 | 250 | 5.14 | 32.4 | 0.1 | 0.5 | 4.5 (%100) |
| S0 Mevcut | Gunde 10 mac, premium | 264 | 266 | 1 | 7 / 1960 | 1059 | 91 | 139 | 4.47 | 34.7 | 0.0 | 0.1 | 6.5 (%100) |
| S1 Kayipsiz | Gunde 2 mac | 54 | 56 | 0 | 0 / 0 | 208 | 70 | 0 | 2.30 | 21.2 | 0.0 | 0.0 | 15.5 (%40) |
| S1 Kayipsiz | Gunde 5 mac | 126 | 130 | 0 | 0 / 0 | 459 | 85 | 0 | 2.45 | 39.2 | 0.0 | 0.0 | 12.5 (%100) |
| S1 Kayipsiz | Gunde 10 mac | 242 | 241 | 0 | 2 / 393 | 752 | 91 | 0 | 2.60 | 49.2 | 0.0 | 0.0 | 5.5 (%100) |
| S1 Kayipsiz | Gunde 20 mac | 508 | 366 | 124 | 8 / 1288 | 1388 | 94 | 0 | 2.93 | 65.9 | 0.0 | 0.0 | 1.5 (%100) |
| S1 Kayipsiz | Gunde 10 mac, premium | 255 | 260 | 0 | 6 / 1698 | 1022 | 92 | 0 | 3.38 | 53.5 | 0.0 | 0.0 | 5.5 (%100) |
| S2 Her maca tam sandik | Gunde 2 mac | 54 | 56 | 0 | 0 / 0 | 208 | 70 | 0 | 2.30 | 21.2 | 0.0 | 0.0 | 15.5 (%40) |
| S2 Her maca tam sandik | Gunde 5 mac | 126 | 130 | 0 | 0 / 0 | 459 | 85 | 0 | 2.45 | 39.2 | 0.0 | 0.0 | 12.5 (%100) |
| S2 Her maca tam sandik | Gunde 10 mac | 243 | 242 | 0 | 2 / 368 | 761 | 91 | 0 | 2.68 | 49.7 | 0.0 | 0.0 | 5.5 (%100) |
| S2 Her maca tam sandik | Gunde 20 mac | 522 | 460 | 0 | 48 / 6055 | 1614 | 95 | 0 | 2.45 | 70.2 | 0.0 | 0.0 | 1.5 (%100) |
| S2 Her maca tam sandik | Gunde 10 mac, premium | 255 | 260 | 0 | 6 / 1698 | 1022 | 92 | 0 | 3.38 | 53.5 | 0.0 | 0.0 | 5.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 2 mac | 54 | 56 | 0 | 0 / 0 | 208 | 70 | 0 | 2.30 | 21.2 | 0.0 | 0.0 | 15.5 (%40) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 5 mac | 126 | 130 | 0 | 0 / 0 | 459 | 85 | 0 | 2.45 | 39.2 | 0.0 | 0.0 | 12.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 10 mac | 244 | 244 | 0 | 2 / 431 | 759 | 91 | 0 | 2.65 | 49.7 | 0.0 | 0.0 | 5.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 20 mac | 529 | 509 | 0 | 10 / 1450 | 1477 | 95 | 0 | 2.71 | 65.5 | 0.0 | 0.0 | 1.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 10 mac, premium | 255 | 260 | 0 | 6 / 1698 | 1022 | 92 | 0 | 3.38 | 53.5 | 0.0 | 0.0 | 5.5 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 2 mac | 50 | 53 | 0 | 0 / 0 | 192 | 68 | 0 | 2.94 | 18.1 | 0.0 | 0.0 | 24.0 (%60) |
| S4 Oneri + galibiyette gelisim | Gunde 5 mac | 122 | 126 | 0 | 0 / 0 | 430 | 86 | 0 | 3.65 | 21.7 | 0.0 | 0.0 | 10.5 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 10 mac | 240 | 242 | 0 | 1 / 151 | 752 | 92 | 0 | 4.36 | 28.4 | 0.0 | 0.0 | 4.5 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 20 mac | 499 | 481 | 0 | 10 / 1438 | 1396 | 94 | 0 | 5.25 | 31.3 | 0.0 | 0.0 | 3.0 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 10 mac, premium | 250 | 254 | 0 | 6 / 1804 | 1003 | 92 | 0 | 4.81 | 32.7 | 0.0 | 0.0 | 4.0 (%100) |

## 90 gün

| Senaryo | Profil | Maç | Sandık | Enerjisiz kaçan | Telafi (adet / altın) | Altın/gün | Farklı kart | Kart kaybı | Kadro sv | Seviye/hafta | Kilitli gün | Acil Kadro | İlk L5 günü |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S0 Mevcut | Gunde 2 mac | 153 | 160 | 0 | 0 / 0 | 200 | 90 | 85 | 3.65 | 9.9 | 0.0 | 0.1 | 31.0 (%100) |
| S0 Mevcut | Gunde 5 mac | 388 | 406 | 0 | 0 / 153 | 470 | 90 | 203 | 4.91 | 13.5 | 0.0 | 0.2 | 18.5 (%100) |
| S0 Mevcut | Gunde 10 mac | 765 | 767 | 2 | 5 / 1054 | 818 | 89 | 383 | 5.82 | 16.9 | 0.0 | 0.1 | 7.0 (%100) |
| S0 Mevcut | Gunde 20 mac | 1500 | 1105 | 346 | 32 / 4706 | 1380 | 85 | 728 | 6.73 | 22.4 | 0.1 | 0.6 | 4.5 (%100) |
| S0 Mevcut | Gunde 10 mac, premium | 779 | 792 | 1 | 21 / 5551 | 1054 | 90 | 384 | 6.30 | 19.6 | 0.0 | 0.1 | 6.5 (%100) |
| S1 Kayipsiz | Gunde 2 mac | 158 | 165 | 0 | 0 / 18 | 205 | 89 | 0 | 2.65 | 15.4 | 0.0 | 0.0 | 35.5 (%100) |
| S1 Kayipsiz | Gunde 5 mac | 382 | 398 | 0 | 1 / 279 | 465 | 96 | 0 | 2.95 | 21.8 | 0.0 | 0.0 | 12.5 (%100) |
| S1 Kayipsiz | Gunde 10 mac | 753 | 755 | 1 | 5 / 1033 | 802 | 98 | 0 | 3.35 | 27.5 | 0.0 | 0.0 | 5.5 (%100) |
| S1 Kayipsiz | Gunde 20 mac | 1489 | 1093 | 352 | 26 / 3938 | 1356 | 98 | 0 | 4.07 | 33.8 | 0.0 | 0.0 | 1.5 (%100) |
| S1 Kayipsiz | Gunde 10 mac, premium | 766 | 784 | 0 | 20 / 5450 | 1041 | 98 | 0 | 4.10 | 29.1 | 0.0 | 0.0 | 5.5 (%100) |
| S2 Her maca tam sandik | Gunde 2 mac | 158 | 165 | 0 | 0 / 18 | 205 | 89 | 0 | 2.65 | 15.4 | 0.0 | 0.0 | 35.5 (%100) |
| S2 Her maca tam sandik | Gunde 5 mac | 382 | 398 | 0 | 1 / 279 | 465 | 96 | 0 | 2.95 | 21.8 | 0.0 | 0.0 | 12.5 (%100) |
| S2 Her maca tam sandik | Gunde 10 mac | 741 | 748 | 0 | 4 / 866 | 787 | 98 | 0 | 3.56 | 27.2 | 0.0 | 0.0 | 5.5 (%100) |
| S2 Her maca tam sandik | Gunde 20 mac | 1530 | 1368 | 0 | 141 / 17524 | 1591 | 99 | 0 | 4.04 | 35.5 | 0.0 | 0.0 | 1.5 (%100) |
| S2 Her maca tam sandik | Gunde 10 mac, premium | 763 | 781 | 0 | 20 / 5502 | 1036 | 98 | 0 | 4.10 | 29.1 | 0.0 | 0.0 | 5.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 2 mac | 158 | 165 | 0 | 0 / 18 | 205 | 89 | 0 | 2.65 | 15.4 | 0.0 | 0.0 | 35.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 5 mac | 382 | 398 | 0 | 1 / 279 | 465 | 96 | 0 | 2.95 | 21.8 | 0.0 | 0.0 | 12.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 10 mac | 738 | 742 | 0 | 5 / 1027 | 783 | 98 | 0 | 3.39 | 27.2 | 0.0 | 0.0 | 5.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 20 mac | 1560 | 1512 | 0 | 31 / 4539 | 1473 | 99 | 0 | 3.93 | 34.0 | 0.0 | 0.0 | 1.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 10 mac, premium | 762 | 780 | 0 | 19 / 5288 | 1036 | 98 | 0 | 4.12 | 29.1 | 0.0 | 0.0 | 5.5 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 2 mac | 155 | 163 | 0 | 0 / 0 | 201 | 87 | 0 | 4.42 | 9.9 | 0.0 | 0.0 | 26.0 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 5 mac | 371 | 388 | 0 | 0 / 153 | 456 | 95 | 0 | 5.34 | 10.2 | 0.0 | 0.0 | 10.5 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 10 mac | 771 | 777 | 0 | 4 / 981 | 818 | 97 | 0 | 6.18 | 15.7 | 0.0 | 0.0 | 4.5 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 20 mac | 1503 | 1459 | 0 | 28 / 4006 | 1423 | 98 | 0 | 6.86 | 22.2 | 0.0 | 0.0 | 3.0 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 10 mac, premium | 766 | 779 | 0 | 23 / 5951 | 1037 | 98 | 0 | 6.56 | 18.6 | 0.0 | 0.0 | 4.0 (%100) |

## 180 gün

| Senaryo | Profil | Maç | Sandık | Enerjisiz kaçan | Telafi (adet / altın) | Altın/gün | Farklı kart | Kart kaybı | Kadro sv | Seviye/hafta | Kilitli gün | Acil Kadro | İlk L5 günü |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S0 Mevcut | Gunde 2 mac | 307 | 321 | 0 | 0 / 0 | 197 | 90 | 164 | 4.59 | 6.5 | 0.0 | 0.1 | 31.0 (%100) |
| S0 Mevcut | Gunde 5 mac | 766 | 804 | 0 | 1 / 367 | 470 | 88 | 384 | 5.64 | 11.3 | 0.0 | 0.2 | 18.5 (%100) |
| S0 Mevcut | Gunde 10 mac | 1521 | 1529 | 3 | 10 / 2220 | 823 | 89 | 741 | 6.48 | 14.3 | 0.0 | 0.1 | 7.0 (%100) |
| S0 Mevcut | Gunde 20 mac | 3018 | 2218 | 709 | 59 / 8528 | 1373 | 86 | 1466 | 6.98 | 18.8 | 0.1 | 0.6 | 4.5 (%100) |
| S0 Mevcut | Gunde 10 mac, premium | 1535 | 1565 | 2 | 41 / 11061 | 1040 | 88 | 752 | 6.76 | 16.3 | 0.0 | 0.1 | 6.5 (%100) |
| S1 Kayipsiz | Gunde 2 mac | 312 | 328 | 0 | 0 / 18 | 205 | 94 | 0 | 3.00 | 10.8 | 0.0 | 0.0 | 35.5 (%100) |
| S1 Kayipsiz | Gunde 5 mac | 748 | 785 | 0 | 1 / 349 | 461 | 98 | 0 | 3.68 | 15.1 | 0.0 | 0.0 | 12.5 (%100) |
| S1 Kayipsiz | Gunde 10 mac | 1505 | 1512 | 2 | 11 / 2048 | 809 | 100 | 0 | 4.54 | 18.2 | 0.0 | 0.0 | 5.5 (%100) |
| S1 Kayipsiz | Gunde 20 mac | 3011 | 2215 | 706 | 57 / 8575 | 1372 | 99 | 0 | 5.22 | 21.5 | 0.0 | 0.0 | 1.5 (%100) |
| S1 Kayipsiz | Gunde 10 mac, premium | 1508 | 1542 | 1 | 39 / 10623 | 1027 | 99 | 0 | 4.98 | 19.3 | 0.0 | 0.0 | 5.5 (%100) |
| S2 Her maca tam sandik | Gunde 2 mac | 312 | 328 | 0 | 0 / 18 | 205 | 94 | 0 | 3.00 | 10.8 | 0.0 | 0.0 | 35.5 (%100) |
| S2 Her maca tam sandik | Gunde 5 mac | 748 | 785 | 0 | 1 / 349 | 461 | 98 | 0 | 3.68 | 15.1 | 0.0 | 0.0 | 12.5 (%100) |
| S2 Her maca tam sandik | Gunde 10 mac | 1506 | 1516 | 0 | 11 / 2170 | 810 | 99 | 0 | 4.74 | 18.0 | 0.0 | 0.0 | 5.5 (%100) |
| S2 Her maca tam sandik | Gunde 20 mac | 3056 | 2742 | 0 | 275 / 34623 | 1588 | 100 | 0 | 5.55 | 22.5 | 0.0 | 0.0 | 1.5 (%100) |
| S2 Her maca tam sandik | Gunde 10 mac, premium | 1491 | 1529 | 0 | 38 / 10483 | 1015 | 100 | 0 | 4.85 | 19.2 | 0.0 | 0.0 | 5.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 2 mac | 312 | 328 | 0 | 0 / 18 | 205 | 94 | 0 | 3.00 | 10.8 | 0.0 | 0.0 | 35.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 5 mac | 748 | 785 | 0 | 1 / 349 | 461 | 98 | 0 | 3.68 | 15.1 | 0.0 | 0.0 | 12.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 10 mac | 1492 | 1498 | 0 | 11 / 2137 | 801 | 99 | 0 | 4.67 | 18.0 | 0.0 | 0.0 | 5.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 20 mac | 3104 | 3010 | 0 | 63 / 9145 | 1476 | 100 | 0 | 5.15 | 21.8 | 0.0 | 0.0 | 1.5 (%100) |
| S3 Oneri (enerjisiz=Bronz) | Gunde 10 mac, premium | 1488 | 1526 | 0 | 38 / 10321 | 1019 | 99 | 0 | 5.05 | 19.3 | 0.0 | 0.0 | 5.5 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 2 mac | 312 | 329 | 0 | 0 / 0 | 202 | 93 | 0 | 4.96 | 6.0 | 0.0 | 0.0 | 26.0 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 5 mac | 758 | 795 | 0 | 2 / 448 | 466 | 99 | 0 | 5.85 | 11.2 | 0.0 | 0.0 | 10.5 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 10 mac | 1524 | 1532 | 0 | 9 / 1899 | 812 | 99 | 0 | 6.57 | 16.0 | 0.0 | 0.0 | 4.5 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 20 mac | 3014 | 2925 | 0 | 59 / 8372 | 1433 | 100 | 0 | 7.25 | 19.8 | 0.0 | 0.0 | 3.0 (%100) |
| S4 Oneri + galibiyette gelisim | Gunde 10 mac, premium | 1536 | 1567 | 0 | 43 / 11105 | 1044 | 99 | 0 | 6.82 | 17.7 | 0.0 | 0.0 | 4.0 (%100) |

## Battle Pass (bütün 30 günlük sezonlar)

| Senaryo | Profil | Sezon | Tamamlama | Ort. kademe | Medyan | En kötü %10 | Medyan tamamlama günü |
|---|---|---|---|---|---|---|---|
| S0 Mevcut | Gunde 2 mac | 60 | %0 | 26.5 | 26.0 | 23 | — |
| S0 Mevcut | Gunde 5 mac | 60 | %95 | 49.9 | 50.0 | 50 | 30 |
| S0 Mevcut | Gunde 10 mac | 60 | %100 | 50 | 50.0 | 50 | 25.0 |
| S0 Mevcut | Gunde 20 mac | 60 | %100 | 50 | 50.0 | 50 | 21.0 |
| S0 Mevcut | Gunde 10 mac, premium | 60 | %100 | 50 | 50.0 | 50 | 25.0 |
| S1 Kayipsiz | Gunde 2 mac | 60 | %0 | 27.2 | 27.0 | 23 | — |
| S1 Kayipsiz | Gunde 5 mac | 60 | %92 | 49.8 | 50.0 | 50 | 30 |
| S1 Kayipsiz | Gunde 10 mac | 60 | %100 | 50 | 50.0 | 50 | 26.0 |
| S1 Kayipsiz | Gunde 20 mac | 60 | %100 | 50 | 50.0 | 50 | 21.0 |
| S1 Kayipsiz | Gunde 10 mac, premium | 60 | %100 | 50 | 50.0 | 50 | 26.0 |
| S2 Her maca tam sandik | Gunde 2 mac | 60 | %0 | 27.2 | 27.0 | 23 | — |
| S2 Her maca tam sandik | Gunde 5 mac | 60 | %92 | 49.8 | 50.0 | 50 | 30 |
| S2 Her maca tam sandik | Gunde 10 mac | 60 | %100 | 50 | 50.0 | 50 | 26.0 |
| S2 Her maca tam sandik | Gunde 20 mac | 60 | %100 | 50 | 50.0 | 50 | 21.0 |
| S2 Her maca tam sandik | Gunde 10 mac, premium | 60 | %100 | 50 | 50.0 | 50 | 26.0 |
| S3 Oneri (enerjisiz=Bronz) | Gunde 2 mac | 60 | %0 | 27.2 | 27.0 | 23 | — |
| S3 Oneri (enerjisiz=Bronz) | Gunde 5 mac | 60 | %92 | 49.8 | 50.0 | 50 | 30 |
| S3 Oneri (enerjisiz=Bronz) | Gunde 10 mac | 60 | %100 | 50 | 50.0 | 50 | 26.0 |
| S3 Oneri (enerjisiz=Bronz) | Gunde 20 mac | 60 | %100 | 50 | 50.0 | 50 | 20.5 |
| S3 Oneri (enerjisiz=Bronz) | Gunde 10 mac, premium | 60 | %100 | 50 | 50.0 | 50 | 26.0 |
| S4 Oneri + galibiyette gelisim | Gunde 2 mac | 60 | %0 | 27.2 | 27.0 | 24 | — |
| S4 Oneri + galibiyette gelisim | Gunde 5 mac | 60 | %90 | 49.6 | 50.0 | 50 | 30.0 |
| S4 Oneri + galibiyette gelisim | Gunde 10 mac | 60 | %100 | 50 | 50.0 | 50 | 25.0 |
| S4 Oneri + galibiyette gelisim | Gunde 20 mac | 60 | %100 | 50 | 50.0 | 50 | 21.0 |
| S4 Oneri + galibiyette gelisim | Gunde 10 mac, premium | 60 | %100 | 50 | 50.0 | 50 | 25.5 |
