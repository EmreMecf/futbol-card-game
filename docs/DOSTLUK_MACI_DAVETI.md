# Arkadaşını dostluk maçına çağırma

Oyuncu bir arkadaşını maça çağırır; arkadaşın ekranının üstünden bir davet kutucuğu kayarak gelir. Sistem bildirimi değildir, oyun açıkken görünür.

## Akış

1. **Çağıran:** Arkadaşlar listesindeki yeşil top düğmesine ya da arkadaşın profilindeki **MAÇA ÇAĞIR**'a basar. Özel odası açılır (ödülsüz, kart kaybı yok) ve odada bekler.
2. **Çağrılan:** Hangi ekrandaysa üstte kutucuk çıkar: ad, "seni dostluk maçına çağırıyor!", 60 saniyelik geri sayım, **REDDET** ve **KABUL ET**.
   - **KABUL ET:** aynı odaya katılır ve odaya geçer. İkisi kadro seçip HAZIRIM deyince maç başlar.
   - **REDDET:** davet kapanır.
   - **Yukarı kaydırma:** kutucuk gizlenir, davet süresi dolana kadar açık kalır.
3. **Çağırana bilgi:** "X davetini kabul etti / reddetti / yanıt vermedi" mesajı üstte görünür.

Kutucuk maç sırasında, rakip ararken, özel odadayken ve giriş ekranlarında gösterilmez. Bilgi mesajları yalnız maçta ve rakip ararken gizlenir.

## Kurallar (058)

- Yalnız arkadaşlar çağrılabilir; davet 60 saniye geçerlidir.
- Aynı arkadaşa bekleyen davet varken yenisi açılmaz.
- Dakikada en fazla 6 davet gönderilebilir.
- Oda tek kişiliktir: başka bir arkadaşı çağırınca öncekine giden davet kapanır.
- Çağıran odadan çıkınca bekleyen daveti geri çekilir.

## Teknik

| Parça | Yer |
|---|---|
| Tablo ve kurallar | `database/migrations/058_friend_challenges.sql` |
| Uçlar | `POST/GET /api/social/challenges...` (`server/lib/routes/social_routes.dart`) |
| Anlık bildirim | `social_events` kanalı → WebSocket `friend_challenge`, `friend_challenge_update` |
| Uygulama | `lib/features/social/friend_challenge.dart`, `lib/ui_v21/components/v21_friend_challenge_banner.dart` |

Bağlantı koparsa davet kaybolmaz: bağlantı geri gelince ve oturum açılınca bekleyen davetler yeniden sorulur.
