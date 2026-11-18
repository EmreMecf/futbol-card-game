# PvP eslestirme V2 — problem, kurallar ve staging kabul kontrolu

## Gercek cihaz raporu (14 Kasim 2026)

Iki yeni hesap birlikte "Rakip bul" demesine ragmen defalarca tekrar gerektirdi. Tekrarlanan buton/oturum denemeleri olmadan eslestirme beklenir. Mevcut `find_match_or_bot` sadece `bots_v1` aciksa ve kart transferi olmayan kural surumundeyse 20sn bot verir. `find_match` normalde `mmr` modu ile ±200 MMR'den baslar; `combined` destekli ama varsayilan kapali. Dolayisiyla ilk iki oyuncu ayni 1000 MMR'deyse normal kosullarda zaten **hemen** eslesmesi gerekir. Yasanan sorunun yalniz MMR'den kaynaklandigi KANITLANMADI.

### Kapsam

- 046 migration ile `adaptive` modu opt-in: mevcut `mmr`/ `combined` durumlari korunur
- Baslangic MMR benzer iki yeni oyuncu: ilk giriste eslestir
- Kuyrukta az kisi: puan araligini hizla buyut
- Kuyrukta daha cok kisi: kalite oncelikli eslestir, sonra gevset
- Ayni kullanicidan paralel `find_match`: advisory lock icinde yeniden aktif mac kontrolu
- Flutter: poll istekleri ust uste binmez; art arda hata sessizce yutulmaz; kacirilmis WebSocket bildirimi varsa `/match/active` ile kurtarir
- Insan rakip bulunamayan durumda algoritma fiziksel olarak yeni insan yaratamaz: `bots_v1` ve antrenman secenegi ayri, urun karari ile ele alinmali

## Opt-in kurallar

| Aktif kuyruk | 0s | 10s | 20s | 30s | 40s | 60s |
|---|---|---|---|---|---|---|
| <5 arayan | ±300 | ±600 | ±1200 | herhangi MMR | ayni | ayni |
| 5+ arayan | ±200 | ±200 | ±500 | ±500 | ±1000 | herhangi MMR |

*MMR, oyuncu seviyesi degildir; ileride efektif kadro gucu ve mac sayisi ile eslesme kalitesinin ayrica puanlanmasi onerilir. Etkili kadro gucu icin 024 `combined` modu vardir.*

**048 notu:** Kural surumu 5'te (seviye gucu) varsayilan mod `combined` kalir; `adaptive` acikca secilirse surum 5'te de `adaptive` kullanilir.

### Kontrolsuz rakip acilmamali

- Insan rakip yoksa kullaniciya gercek rakip varmis gibi gosterme. Tercih edilen UX: 20–30s sonra **Botla oyna (dereceli bot / antrenman)** secenegi.
- `bots_v1` kapaliysa otomatik bot olmayacak. Açmadan once mevcut 041 ekonomi, odul, AI ve 037 kart transferi kurallarini dogrula.
- Kart transferi acik olan surumde botun kart kaybi/kazanimi yaratmasina izin verme.

## Staging'de dogrulama

Bu PR uygulamada `adaptive` modunu otomatik acmaz. CI yesil, 046 testler ve iki telefon testi sonrasi staging'de:
```sql
select matchmaking_mode(), economy_flag('bots_v1'), current_rules_version();
select status, count(*) from matchmaking_queue group by status;
select count(*) from matchmaking_queue where status = 'searching'
  and updated_at >= now() - interval '30 seconds';
update matchmaking_settings set mode='adaptive', updated_at=now() where id=1;
```
Rollback:
```sql
update matchmaking_settings set mode='mmr', updated_at=now() where id=1;
```
Render Free Postgres dis baglantilara kapali oldugundan disaridan sorgu denemesi reddedildi; staging web container icinden yetkili SQL araci olmadan bu degerler gorulemedi.

## Iki telefonu test proseduru

1. Her telefonda farkli hesap ve aktif, sunucuca gecerli 11 kartli deste.
2. Iki kullanici uygulamanin **ayni staging versiyonunda** oldugunu kontrol et.
3. A basar, ekranda "Rakip araniyor"; B 1-3s sonra basar: her ikisi de ayni match ID ile 5s hedefi icinde maca gecmeli.
4. A/B tamamen ayni saniyede basar: tek match ID, cift match yok.
5. A/B ayni 1000 MMR yeni hesaplar; farkli MMR'li iki hesap; WebSocket kapali/yavas; polling 4s fallback; son anda iptal; 10 kez hizli tekrar tiklama; yeniden baslatma; internet kesilip gelme.
6. Gercek zamanli `/api/match/find` istek loglari HTTP 2xx/4xx/5xx ve sure bazinda degerlendirilmeli. Kullanici UID, sifre ve JWT loglanmamali.
7. Olcumler: basarili eslestirme orani, p50/p95 sure, zaman asimi, iptal ile cift match, oyuncu MMR/kadro gucu farki.
8. Tek insan varsa 60sn garantisi **verilemez**; bot fallback aktifligi ile ayrica test et.
