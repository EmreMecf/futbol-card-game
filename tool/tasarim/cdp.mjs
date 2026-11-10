// Chrome'u DevTools protokolü (CDP) ile süren küçük yardımcı.
//
// Neden Puppeteer/Playwright değil? Projeye yeni bağımlılık eklememek
// için. Node 20'nin deneysel WebSocket'i yeterli:
//   node --experimental-websocket tool/tasarim/<betik>.mjs
//
// Gerçek uygulamanın ekran görüntüsü referansla AYNI çözünürlükte
// (390×844, piksel oranı 1) alınır; tarayıcı paneli görüntüyü
// pencereye sığdırmak için küçülttüğü için kullanılmadı.

import { spawn } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

export const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
export const bekle = (ms) => new Promise((r) => setTimeout(r, ms));

/** Görünür olmayan (headless) bir Chrome başlatır */
export async function chromeAc({ port = 9333, headless = true, kalici = false, pencere = '1400,1000' } = {}) {
  const profil = mkdtempSync(join(tmpdir(), 'fca-chrome-'));
  const args = [
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${profil}`,
    '--no-first-run',
    '--no-default-browser-check',
    '--disable-background-timer-throttling',
    '--disable-renderer-backgrounding',
    '--disable-backgrounding-occluded-windows',
    `--window-size=${pencere}`,
  ];
  if (headless) args.push('--headless=new');
  // kalici: betik bitince Chrome açık kalır (sonraki betikler bağlanır)
  const surec = spawn(CHROME, args, { stdio: 'ignore', detached: kalici });
  if (kalici) surec.unref();
  let surum;
  for (let i = 0; i < 50; i++) {
    try {
      surum = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
      break;
    } catch {
      await bekle(200);
    }
  }
  if (!surum) throw new Error('Chrome açılmadı');
  const tarayici = new Baglanti(surum.webSocketDebuggerUrl);
  await tarayici.ac();
  return { tarayici, kapat: () => surec.kill() };
}

class Baglanti {
  constructor(url) {
    this.url = url;
    this.sira = 1;
    this.bekleyen = new Map();
    this.dinleyiciler = [];
  }
  ac() {
    return new Promise((ok, hata) => {
      this.ws = new WebSocket(this.url);
      this.ws.onopen = ok;
      this.ws.onerror = hata;
      this.ws.onmessage = (e) => {
        const m = JSON.parse(e.data);
        if (m.id && this.bekleyen.has(m.id)) {
          const { ok: c, hata: h } = this.bekleyen.get(m.id);
          this.bekleyen.delete(m.id);
          m.error ? h(new Error(JSON.stringify(m.error))) : c(m.result);
        } else if (m.method) {
          for (const d of this.dinleyiciler) d(m);
        }
      };
    });
  }
  gonder(method, params = {}, sessionId) {
    const id = this.sira++;
    const mesaj = { id, method, params };
    if (sessionId) mesaj.sessionId = sessionId;
    return new Promise((ok, hata) => {
      this.bekleyen.set(id, { ok, hata });
      this.ws.send(JSON.stringify(mesaj));
    });
  }
}

/** Açık bir Chrome'a bağlanır; var olan sayfa sekmelerini döndürür */
export async function chromeBaglan(port) {
  const surum = await (await fetch(`http://127.0.0.1:${port}/json/version`)).json();
  const tarayici = new Baglanti(surum.webSocketDebuggerUrl);
  await tarayici.ac();
  return tarayici;
}

/** Var olan bir sayfa hedefine (targetId) sekme nesnesiyle bağlanır */
export async function sekmeyeBaglan(tarayici, targetId, { genislik = 390, yukseklik = 844 } = {}) {
  return sekmeAc(tarayici, { genislik, yukseklik, targetId, boyutAyarla: false });
}

/** Ayrı çerezli/depolu yeni bir sekme (iki oyuncu = iki bağlam) */
export async function sekmeAc(tarayici, { genislik = 390, yukseklik = 844, ayriBaglam = false, targetId: varOlan, boyutAyarla = true } = {}) {
  let browserContextId;
  if (ayriBaglam) {
    ({ browserContextId } = await tarayici.gonder('Target.createBrowserContext'));
  }
  const targetId = varOlan ?? (await tarayici.gonder('Target.createTarget', { url: 'about:blank', browserContextId })).targetId;
  const { sessionId } = await tarayici.gonder('Target.attachToTarget', { targetId, flatten: true });
  const s = (m, p) => tarayici.gonder(m, p, sessionId);
  await s('Page.enable');
  await s('Runtime.enable');
  // Pencere zaten doğru boyuttaysa (kalıcı PvP Chrome'u) ayarlama:
  // bağlantı her kapandığında ayar sıfırlanır, uygulama bunu boyut
  // değişikliği sanıp sayfayı başa kaydırır.
  if (boyutAyarla) await s('Emulation.setDeviceMetricsOverride', {
    width: genislik,
    height: yukseklik,
    deviceScaleFactor: 1,
    mobile: false,
  });
  const konsol = [];
  tarayici.dinleyiciler.push((m) => {
    if (m.sessionId !== sessionId) return;
    if (m.method === 'Runtime.consoleAPICalled') {
      konsol.push(m.params.args.map((a) => a.value ?? a.description).join(' '));
    }
    if (m.method === 'Runtime.exceptionThrown') {
      const d = m.params.exceptionDetails;
      konsol.push('HATA: ' + d.text + ' ' + (d.exception?.description ?? '').slice(0, 1500));
    }
  });

  return {
    s,
    targetId,
    konsol,
    async git(url, ms = 4000) {
      await s('Page.navigate', { url });
      await bekle(ms);
    },
    async js(ifade) {
      const r = await s('Runtime.evaluate', { expression: ifade, awaitPromise: true, returnByValue: true });
      return r.result?.value;
    },
    async rota(hash, ms = 2500) {
      await this.js(`location.hash = ${JSON.stringify(hash)}`);
      await bekle(ms);
    },
    async tikla(x, y, ms = 400) {
      for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
        await s('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
      }
      await bekle(ms);
    },
    async yaz(metin) {
      await s('Input.insertText', { text: metin });
      await bekle(150);
    },
    async tus(key, code = key, windowsVirtualKeyCode) {
      await s('Input.dispatchKeyEvent', { type: 'keyDown', key, code, windowsVirtualKeyCode });
      await s('Input.dispatchKeyEvent', { type: 'keyUp', key, code, windowsVirtualKeyCode });
      await bekle(200);
    },
    async kaydir(dy, x = genislik / 2, y = yukseklik / 2, ms = 900) {
      // Flutter fare tekerini adım adım işler
      const adim = Math.sign(dy) * 120;
      for (let i = 0; i < Math.abs(Math.round(dy / 120)); i++) {
        await s('Input.dispatchMouseEvent', { type: 'mouseWheel', x, y, deltaX: 0, deltaY: adim });
        await bekle(16);
      }
      await bekle(ms);
    },
    async foto(dosya) {
      const { data } = await s('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
      writeFileSync(dosya, Buffer.from(data, 'base64'));
    },
    /** requestAnimationFrame ile ms süresince kare sayar */
    async fps(ms = 3000) {
      return this.js(`new Promise(ok => {
        const kareler = []; const bas = performance.now();
        function f(t) { kareler.push(t); if (t - bas < ${ms}) requestAnimationFrame(f);
          else { const araliklar = kareler.slice(1).map((v,i)=>v-kareler[i]);
                 araliklar.sort((a,b)=>a-b);
                 const p95 = araliklar[Math.floor(araliklar.length*0.95)] || 0;
                 ok({ fps: +(kareler.length / ((t-bas)/1000)).toFixed(1),
                      kare: kareler.length, p95ms: +p95.toFixed(1),
                      uzun: araliklar.filter(a=>a>33).length }); } }
        requestAnimationFrame(f); })`);
    },
  };
}
