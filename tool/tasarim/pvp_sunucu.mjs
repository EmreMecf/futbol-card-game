// PvP kabul testi: A oyuncusunun sekmesini AÇIK TUTAN küçük test aracı.
//
// Neden? Sekmenin 390×844 boyut ayarı, CDP bağlantısı kapanınca
// sıfırlanıyor; uygulama bunu boyut değişikliği sanıp sayfayı başa
// kaydırıyor. Bu araç bağlantıyı hiç kapatmaz; komutları yalnız
// 127.0.0.1:9341 üzerinden alır (komut.mjs gönderir).
//
//   node --experimental-websocket tool/tasarim/pvp_sunucu.mjs
import { createServer } from 'node:http';
import { mkdirSync } from 'node:fs';
import { chromeAc, sekmeAc, bekle } from './cdp.mjs';
import { hesapOku, girisYap } from './hesap.mjs';

const KLASOR = 'design-reference/gercek/pvp';
mkdirSync(KLASOR, { recursive: true });
const { tarayici, kapat } = await chromeAc({ port: 9340 });
const sekme = await sekmeAc(tarayici);
await girisYap(sekme, hesapOku('test-hesabi.local.txt'));
await bekle(4000);
await sekme.rota('#/eslesme', 5000);
console.log('A hazır:', await sekme.js('location.hash'), await sekme.js('innerWidth+"x"+innerHeight'));

async function calistir(a) {
  const cikti = [];
  for (let i = 0; i < a.length; ) {
    const k = a[i++];
    if (k === 'tikla') await sekme.tikla(+a[i++], +a[i++], 300);
    else if (k === 'kaydir') await sekme.kaydir(+a[i++]);
    else if (k === 'bekle') await bekle(+a[i++]);
    else if (k === 'rota') await sekme.rota(a[i++], 3000);
    else if (k === 'foto') await sekme.foto(`${KLASOR}/${a[i++]}.png`);
    else if (k === 'seri') {
      const ad = a[i++], adet = +a[i++], aralik = +a[i++];
      for (let n = 0; n < adet; n++) {
        await sekme.foto(`${KLASOR}/${ad}_${String(n).padStart(2, '0')}.png`);
        await bekle(aralik);
      }
    } else if (k === 'fps') cikti.push(JSON.stringify(await sekme.fps(+a[i++])));
    else if (k === 'durum') cikti.push(await sekme.js('location.hash'));
    else if (k === 'konsol') cikti.push(sekme.konsol.slice(-+a[i++]).join('\n'));
    else if (k === 'kapat') {
      kapat();
      setTimeout(() => process.exit(0), 200);
    } else throw new Error('bilinmeyen komut ' + k);
  }
  return cikti.join('\n');
}

createServer(async (req, res) => {
  const a = JSON.parse(decodeURIComponent(new URL(req.url, 'http://x').searchParams.get('a') ?? '[]'));
  try {
    res.end(await calistir(a));
  } catch (e) {
    res.statusCode = 500;
    res.end(String(e));
  }
}).listen(9341, '127.0.0.1', () => console.log('komut bekleniyor: 127.0.0.1:9341'));
