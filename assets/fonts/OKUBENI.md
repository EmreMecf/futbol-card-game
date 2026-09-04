# Yazı tipleri

| Dosya | Aile | Kullanım |
|---|---|---|
| `BarlowCondensed-*.ttf` | Barlow Condensed | Kart gücü, skor, sayaç, başlık, buton |
| `Nunito-Variable.ttf` | Nunito | Açıklama, etiket, gövde metni |

İkisi de **SIL Open Font License 1.1** ile dağıtılıyor. Lisans metinleri
bu klasördeki `OFL-*.txt` dosyalarında. Bu lisans ticari kullanıma,
gömmeye ve değiştirmeye izin verir; tek şartı fontların lisans metniyle
birlikte dağıtılması ve tek başına satılmamasıdır.

Kaynak: https://github.com/google/fonts

## Nunito neden tek dosya?

Nunito **değişken (variable)** bir font: 200-1000 arası bütün
ağırlıkları tek dosyada taşıyor. Bu yüzden dört ayrı dosya yerine bir
tane var ve toplam boyut daha küçük.

Ama Flutter'da bu tür fontlarda sadece `fontWeight` vermek her
platformda çalışmıyor. `AppTypography.body()` bu yüzden her stile
`fontVariations` ile `wght` eksenini de yazıyor. Yeni bir metin stili
eklerken doğrudan `TextStyle` yazmak yerine o yardımcıyı kullan.
