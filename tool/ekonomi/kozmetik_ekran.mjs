// EKONOMİ V2 FAZ 6 — gerçek uygulamada kozmetikler (390×844)
//   node --experimental-websocket tool/ekonomi/kozmetik_ekran.mjs
//
// Yalnız yerel geliştirme: A hesabında olmayan kozmetikler
// /api/items/dev/grant ile verilir, sonra 7 yuvanın hepsi giyilir.
// Gerçek uygulama (5581, flutter build web) açılıp profil, koleksiyon,
// envanter ve maç hazırlığı (arena) ekranları çekilir.
import { randomUUID } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { API, istek, apiGiris } from '../tasarim/api.mjs';
import { chromeAc, sekmeAc, bekle } from '../tasarim/cdp.mjs';
import { hesapOku, girisYap } from '../tasarim/hesap.mjs';

const KOZMETIK = ['frame_season1', 'kit_season1', 'captain_band', 'badge_s1_gold', 'card_skin_night',
  'arena_rainy_night', 'victory_fireworks'];

const post = async (yol, jeton, govde = {}) => {
  const r = await fetch(API + yol, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${jeton}`, 'idempotency-key': randomUUID() },
    body: JSON.stringify(govde),
  });
  return { durum: r.status, veri: await r.json().catch(() => null) };
};

const hesap = hesapOku('test-hesabi.local.txt');
const A = await apiGiris(hesap);
let env = await istek('/items', { jeton: A });
for (const slug of KOZMETIK) {
  if (!env.items.some((i) => i.slug === slug)) await post('/items/dev/grant', A, { slug, qty: 1 });
  const g = await post(`/items/${slug}/equip`, A);
  if (g.durum !== 200) console.log('giyilemedi', slug, g.durum, g.veri?.code);
}
env = await istek('/items', { jeton: A });
console.log('giyilen:', JSON.stringify(env.equipped));

const K = 'design-reference/gercek/kozmetik';
mkdirSync(K, { recursive: true });
const { tarayici, kapat } = await chromeAc({ port: 9362 });
try {
  const a = await sekmeAc(tarayici);
  await girisYap(a, hesap);
  await bekle(6000);
  await a.rota('#/profil', 4500);
  await a.foto(`${K}/01_profil.png`);
  await a.rota('#/koleksiyon', 4500);
  await a.foto(`${K}/02_koleksiyon_gece_isigi.png`);
  await a.rota('#/eslesme', 5000);
  await a.foto(`${K}/03_mac_hazirligi_yagmurlu_gece.png`);
  await a.rota('#/envanter', 4500);
  await a.kaydir(900);
  await a.foto(`${K}/04_envanter_kozmetik.png`);
  const hatalar = a.konsol.filter((k) => /HATA|Exception|overflow/i.test(k));
  writeFileSync(`${K}/konsol.txt`, a.konsol.join('\n'));
  console.log('konsol hata:', hatalar.length);
} finally {
  kapat();
}
