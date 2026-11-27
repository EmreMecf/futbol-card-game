# Yayın Kontrol Listesi (Monetizasyon)

Hukuki ve mali maddeler bilgi amaçlıdır; avukat ve SMMM ile doğrulanmalı.

## Ödüllü reklam (Faz 2)

- [x] Sunucu SSV doğrulaması, tekil işlem, günlük tavan, aktif maç engeli (060 + testler)
- [x] İstemci ödül vermiyor; "Ödülün doğrulanıyor…" durumu
- [x] Reklam açıkça "REKLAM" etiketli, isteğe bağlı, onay penceresi
- [x] Bayraklar kapalıyken oyun aynı (1201 test, golden değişmedi)
- [ ] AdMob hesabı, gerçek birimler, SSV adresi, engellenen kategoriler (**BLOCKED: hesap**)
- [ ] UMP GDPR mesajı (AdMob konsolu) + ayarlarda "Gizlilik seçenekleri" düğmesi (Faz 2d)
- [ ] KVKK aydınlatma + parçalı rıza ekranı (**metin insan onayı**)
- [ ] iOS ATT kararı ve SKAdNetwork kimlikleri (Faz 2d)
- [ ] app-ads.txt
- [ ] Google Play Data safety + reklam beyanı + hedef kitle 13+; Families programı yok
- [ ] Staging'de beyaz liste ile uçtan uca gerçek test reklamı + SSV

## Satın alma (Faz 3–5)

- [ ] Google/Apple ürünleri, hizmet hesabı / App Store Server API anahtarı (**BLOCKED**)
- [ ] Sunucu makbuz doğrulama, iade (RTDN / Notifications V2)
- [ ] Ücretli elmas yalnız kozmetik (060 ayrımı) — simülasyon: güç farkı %0
- [ ] Premium sezon yolu güç vermeyen ödüllerle yeniden tanımlandı
- [ ] Satın alma ekranında TL fiyat, "Dijital içerik anında teslim edilir; cayma hakkı yoktur" onay kutusu
- [ ] Rastgele ücretli ürün yok (varsa oranlar satın almadan önce)
- [ ] 20/B istisna belgesi, Apple Small Business Program

## Her yayında

- [ ] `flutter analyze`, `flutter test`, `dart test` (server), DB testleri, geçmiş veri denetimi yeşil
- [ ] `monetization_config()` beklenen sürümde; üretimde varsayılan kapalı
- [ ] Acil kapatma denendi (staging)
