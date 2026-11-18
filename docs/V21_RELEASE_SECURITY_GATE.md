# V2.1 yayın ve güvenlik kapısı

## Güvenlik olayı: yerel şifre dosyaları
`database/.yerel_postgres_sifresi` ve `database/.yerel_test_hesabi` V2.1 dallarının geçmişine girdi. `main`'e entegrasyon tek commit olarak alındı; bu dosyalar `main`'in geçmişinde **yoktur**. Eski dallarda ise geçmişte durmaya devam eder.

Yayından önce:
1. O dosyalardaki PostgreSQL şifresini ve test hesabı şifresini değiştir. Şifreleri issue, PR, CI günlüğü ya da sohbete yazma.
2. Eski dalları (`feature/ui-v21-rebuild`, `fix/v21-security-and-release-readiness`, `infra/staging-docker-render`, `integration/v21-matchmaking-friends-staging`) GitHub'dan sil.
3. GitHub'da gizli bilgi taramasını ve push korumasını aç.

## Yayın kontrol listesi
- [ ] İki gerçek Android cihazda canlı maç, yeniden bağlanma, AFK, sonuç ve ödül doğruluğu
- [ ] Arkadaş daveti: bağlantı tıklama, kod ile katılma, iki oyuncu hazır, tek maç
- [ ] HTTPS/WSS staging sunucusu, ayrı test veritabanı, JWT_SECRET, yedek ve geri yükleme
- [ ] Android yayın imzası ve iOS TestFlight denemesi
- [ ] Google/Apple girişi ve iOS dalları ayrıca entegre edilip test edildi
- [ ] Özellik anahtarları yayından önce tek tek gözden geçirildi

Bu dosya bir kontrol listesidir; hiçbir testin çalıştığının kanıtı değildir.
