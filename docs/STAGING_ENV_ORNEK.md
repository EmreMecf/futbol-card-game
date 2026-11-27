# Staging ortam degiskenleri — SECRETS BU DOSYAYA YAZILMAZ

Bu dosya sade bir kontrol listesidir. Gercek degerleri Render Dashboard'da yalniz Environment/Secrets alaninda tut.

| Degisken | Aciklama |
|---|---|
| ENVIRONMENT | production (staging'de dahi guvenlik kontrolu aktif) |
| HOST | 0.0.0.0 |
| PORT | Render'in ayarladigi port, genellikle 10000 |
| DB_HOST | Yalniz internal Render PostgreSQL adresi |
| DB_PORT | 5432 |
| DB_NAME | Izole staging veritabani adi |
| DB_USER | Staging DB kullanicisi |
| DB_PASSWORD | Benzersiz staging veritabani sifresi |
| JWT_SECRET | Rastgele, en az 32 byte, varsayilanla ayni DEGIL |
| AUTH_RATE_LIMIT | Varsayilan 20/dakika; staging'de dusunerek ayarla |
| TRUST_PROXY | Proxy IP guvenligi denetlenmeden true yapma |
| CORS_ORIGIN | Yalniz bilinen web origin; birden cok adres virgulle yazilir (ornek: https://oyun.ornek.com,https://test.ornek.com) |
| DEPLOY_STAGE | staging (uretimde production; tanimsizsa ENVIRONMENT=production iken production sayilir) |
| MONETIZATION_TEST_PROVIDERS | Yalniz staging: true ise SSV benzetim ucu acilir; DEPLOY_STAGE=production iken etkisiz |
| ADMOB_SSV_KEYS_URL | Bos birak (Google resmi adresi kullanilir) |

Saglik kontrolu: `https://<host>/api/health`; WebSocket: `wss://<host>/ws?token=<jwt>`. WebSocket JWT'yi URL/query icinde tasir: request URL'lerini loglama ya da paylasma.

Varsayilan release Flutter build: `flutter build apk --release --dart-define=API_BASE_URL=https://<staging-host>`

**Staging APK icine DB_PASSWORD/JWT_SECRET KOYMA.**
