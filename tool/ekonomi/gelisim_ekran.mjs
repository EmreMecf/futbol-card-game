// EKONOMİ V2 FAZ 2 — gerçek uygulamada gelişim ekranları (390×844)
//   node --experimental-websocket tool/ekonomi/gelisim_ekran.mjs
import { mkdirSync, writeFileSync } from 'node:fs';
import { chromeAc, sekmeAc, bekle } from '../tasarim/cdp.mjs';
import { hesapOku, girisYap } from '../tasarim/hesap.mjs';

const K = 'design-reference/gercek/gelisim';
mkdirSync(K, { recursive: true });
const { tarayici, kapat } = await chromeAc({ port: 9361 });
try {
  const a = await sekmeAc(tarayici);
  await girisYap(a, hesapOku('test-hesabi.local.txt'));
  await bekle(6000);
  await a.rota('#/koleksiyon', 4500);
  await a.foto(`${K}/01_koleksiyon.png`);
  await a.rota('#/gelisim', 4500);
  await a.foto(`${K}/02_gelisim.png`);
  await a.kaydir(900);
  await a.foto(`${K}/03_gelisim_alt.png`);
  const hatalar = a.konsol.filter((k) => /HATA|Exception|overflow/i.test(k));
  writeFileSync(`${K}/konsol.txt`, a.konsol.join('\n'));
  console.log('konsol hata:', hatalar.length);
} finally {
  kapat();
}
