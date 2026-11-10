// EKONOMİ V2 FAZ 1 — gerçek uygulamada sandık ekranları (390×844).
//   node --experimental-websocket tool/ekonomi/sandik_ekran.mjs
// A: ana sayfa şeridi, sandıklar, olasılıklar, (hazırsa) açılış sahnesi
// B: kadro ekranı (kart kaybı sonrası acil kadro uyarısı)
import { mkdirSync, writeFileSync } from 'node:fs';
import { chromeAc, sekmeAc, bekle } from '../tasarim/cdp.mjs';
import { hesapOku, girisYap } from '../tasarim/hesap.mjs';

const K = 'design-reference/gercek/sandik';
mkdirSync(K, { recursive: true });
const { tarayici, kapat } = await chromeAc({ port: 9360 });
try {
  const a = await sekmeAc(tarayici, { ayriBaglam: true });
  await girisYap(a, hesapOku('test-hesabi.local.txt'));
  await bekle(6000);
  await a.rota('#/ana-sayfa', 4000);
  await a.kaydir(500);
  await a.foto(`${K}/01_ana_sayfa_serit.png`);
  await a.rota('#/sandiklar', 4500);
  await a.foto(`${K}/02_sandiklar.png`);
  await a.kaydir(700);
  await a.foto(`${K}/03_sandiklar_alt.png`);
  await a.rota('#/sandiklar/olasiliklar', 4000);
  await a.foto(`${K}/04_olasiliklar.png`);

  const b = await sekmeAc(tarayici, { ayriBaglam: true });
  await girisYap(b, hesapOku('test-hesabi-2.local.txt'));
  await bekle(6000);
  await b.rota('#/kadro', 5000);
  await b.foto(`${K}/05_kadro_acil_kadro.png`);

  const hatalar = [...a.konsol, ...b.konsol].filter((k) => /HATA|Exception|overflow/i.test(k));
  writeFileSync(`${K}/konsol.txt`, [...a.konsol, '----', ...b.konsol].join('\n'));
  console.log('konsol hata:', hatalar.length, hatalar.slice(0, 3).join(' | '));
} finally {
  kapat();
}
