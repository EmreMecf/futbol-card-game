// Görünür Chrome'da (ekran kartıyla) kare hızı ölçümü.
//   node --experimental-websocket tool/tasarim/fps_olc.mjs [headless]
import { writeFileSync } from 'node:fs';
import { chromeAc, sekmeAc, bekle } from './cdp.mjs';
import { hesapOku, girisYap } from './hesap.mjs';

const headless = process.argv[2] === 'headless';
const { tarayici, kapat } = await chromeAc({ headless, port: 9334 });
const sonuc = { mod: headless ? 'headless' : 'gorunur (GPU)' };
try {
  const sekme = await sekmeAc(tarayici);
  await sekme.s('Page.bringToFront');
  sonuc.gpu = await sekme.js(`(() => { const c = document.createElement('canvas').getContext('webgl');
    const d = c && c.getExtension('WEBGL_debug_renderer_info');
    return d ? c.getParameter(d.UNMASKED_RENDERER_WEBGL) : 'bilinmiyor'; })()`);
  await girisYap(sekme, hesapOku('test-hesabi.local.txt'));
  await bekle(5000);
  for (const [ad, hash] of [['ana_sayfa', '#/ana-sayfa'], ['koleksiyon', '#/koleksiyon'], ['kadro', '#/kadro'],
    ['mac_hazirligi', '#/eslesme'], ['magaza', '#/magaza'], ['profil', '#/profil']]) {
    await sekme.rota(hash, 4500);
    sonuc[ad] = await sekme.fps(4000);
    if (ad === 'koleksiyon') {
      const olcum = sekme.fps(3000);
      for (let i = 0; i < 24; i++) {
        await sekme.s('Input.dispatchMouseEvent', { type: 'mouseWheel', x: 195, y: 500, deltaX: 0, deltaY: i % 2 ? -240 : 240 });
        await bekle(110);
      }
      sonuc.koleksiyon_kaydirma = await olcum;
    }
  }
  console.log(JSON.stringify(sonuc, null, 1));
  writeFileSync(`design-reference/gercek/fps_${headless ? 'headless' : 'gpu'}.json`, JSON.stringify(sonuc, null, 2));
} finally {
  kapat();
}
