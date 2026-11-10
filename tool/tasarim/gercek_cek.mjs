// GERÇEK UYGULAMANIN ekran görüntüleri (gerçek sunucu + gerçek hesap).
//
// Ön koşul: veritabanı + sunucu (8080) açık; `flutter build web --profile`
// çıktısı 5581'de sunuluyor (önizleme: futbol-kart-yayin).
//
//   node --experimental-websocket tool/tasarim/gercek_cek.mjs
//
// Çıktı: design-reference/gercek/390x844/<ad>.png  (referansla aynı adlar)
// Ayrıca her ekranda 3 sn boyunca kare hızı ölçülür -> fps.json

import { mkdirSync, writeFileSync } from 'node:fs';
import { chromeAc, sekmeAc, bekle } from './cdp.mjs';
import { hesapOku, girisYap } from './hesap.mjs';

const W = 390, H = 844;
const CIKTI = `design-reference/gercek/${W}x${H}`;
mkdirSync(CIKTI, { recursive: true });

const { tarayici, kapat } = await chromeAc();
const fps = {};
try {
  const sekme = await sekmeAc(tarayici, { genislik: W, yukseklik: H });
  await girisYap(sekme, hesapOku('test-hesabi.local.txt'));
  await bekle(6000);

  async function ekran(ad, hash, { alt = null, olc = true } = {}) {
    await sekme.rota(hash, 4500);
    await sekme.foto(`${CIKTI}/${ad}.png`);
    if (olc) fps[ad] = await sekme.fps(3000);
    if (alt) {
      await sekme.kaydir(4000);
      await sekme.foto(`${CIKTI}/${alt}.png`);
      await sekme.kaydir(-6000, W / 2, H / 2, 300);
    }
    console.log('çekildi', ad);
  }

  await ekran('01_ana_sayfa', '#/ana-sayfa', { alt: '01b_ana_sayfa_alt' });
  await ekran('03_koleksiyon', '#/koleksiyon');
  await sekme.kaydir(700);
  await sekme.foto(`${CIKTI}/03b_koleksiyon_alt.png`);
  fps['03b_koleksiyon_kaydirma'] = await (async () => {
    // Kaydırırken kare hızı: ölçüm sürerken teker döner
    const olcum = sekme.fps(2500);
    for (let i = 0; i < 18; i++) {
      await sekme.s('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 195, y: 500, deltaX: 0, deltaY: i % 2 ? -240 : 240 });
      await bekle(110);
    }
    return olcum;
  })();
  await ekran('04_kadro', '#/kadro', { alt: '04b_kadro_alt' });
  await ekran('02m_mac_hazirligi', '#/eslesme', { alt: '02n_mac_hazirligi_alt' });
  await ekran('05_magaza', '#/magaza', { alt: '05b_magaza_alt' });
  await ekran('06_ligler', '#/liderlik', { alt: '06b_ligler_alt' });
  await ekran('07_profil', '#/profil', { alt: '07b_profil_alt' });
  await ekran('10_gorevler', '#/gorevler', { alt: '10b_gorevler_alt' });
  await ekran('12_ayarlar', '#/ayarlar');
  await ekran('15_bulunamadi', '#/olmayan-bir-sayfa', { olc: false });

  writeFileSync(`${CIKTI}/fps.json`, JSON.stringify(fps, null, 2));
  const hatalar = sekme.konsol.filter((k) => /HATA|Exception|overflow/i.test(k));
  writeFileSync(`${CIKTI}/konsol.txt`, sekme.konsol.join('\n'));
  console.log('konsol hata/uyarı sayısı:', hatalar.length);
  console.log(JSON.stringify(fps));
} finally {
  kapat();
}
