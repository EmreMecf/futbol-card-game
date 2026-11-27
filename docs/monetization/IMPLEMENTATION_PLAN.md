# Uygulama Planı

Her faz bağımsız bayrağın arkasında, varsayılan **kapalı**. Üretimde açma,
gerçek para, gerçek reklam kimliği ve üretim migration'ı açık kullanıcı
onayı ister.

| Faz | İçerik | Migration | Durum |
|---|---|---|---|
| 0 | Denetim, mimari, risk, plan | — | Tamam |
| 1 | `monetization` ayarı (yüzde, beyaz liste, platform, sürüm), denetim kaydı, olay tablosu, ücretli elmas sütunu | 060 | Bu tur |
| 2a | Reklam oturumu, uygunluk, günlük limit (rezervasyonlu), SSV kaydı ve ödül, kredi | 060 | Bu tur |
| 2b | Sunucu: SSV doğrulayıcı (ECDSA), Google anahtar önbelleği, rotalar | — | Bu tur |
| 2c | İstemci: `google_mobile_ads` (test kimlikleri), durum makinesi, günlük ödül merkezi, sandık hızlandırma, "doğrulanıyor" durumu, web'de kapalı | — | Bu tur |
| 2d | UMP rıza formu, gizlilik seçenekleri ayarı, KVKK metni | — | Sonraki tur (metin insan onayı) |
| 3 | `in_app_purchase`, ürün kataloğu, satın alma yaşam döngüsü, Google/Apple doğrulayıcı arayüzü, iade, ücretli elmas | 061 | Sonraki tur; gerçek doğrulayıcılar BLOCKED (hesap/anahtar) |
| 4 | Mağaza sekmeleri, kozmetik satışı ve önizleme, başlangıç paketi | 062 | Sonraki |
| 5 | Premium sezon yolu (güçsüz ödüllerle yeni sezon tanımı), geriye dönük ödül | 063 | Sonraki |
| 6 | Yönetim uçları (rol + denetim), acil kapatma, A/B atama, metrikler | — | Sonraki |
| 7 | Tam regresyon, güvenlik incelemesi, yayın belgeleri | — | Sonraki |

## Kabul ölçütleri (Faz 1–2)

* Bayraklar kapalıyken oyun davranışı birebir aynı (tüm mevcut testler).
* Aktif maç varken reklam oturumu açılamaz.
* Günlük 3 tavan eşzamanlı isteklerde de aşılmaz.
* Aynı SSV iki kez gelirse tek ödül.
* Geçersiz imza, süresi dolmuş oturum, başka oyuncunun oturumu: ödül yok.
* Cihaz saati sınırları etkilemez (gün sunucu `game_day()` ile).
