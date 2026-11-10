// EKONOMİ V2 FAZ 3 — item / envanter uçtan uca kabul testi (gerçek sunucu)
//
//   node tool/ekonomi/envanter_e2e.mjs
//
// Yalnız yerel geliştirme ortamı: itemler /api/items/dev/grant ile verilir,
// test sandıkları yerel psql ile _grant_chest çağrılarak eklenir.
// 1. Envanter açık, katalog dolu
// 2. Sandık hızlandırıcı: sayacı çalışan sandıktan 2 saat düşer
// 3. Anahtar: başka sayaç çalışırken de sandık anında hazır; tekrar = replay
// 4. Enerji içeceği: günlük sınır aşılınca 409 daily_limit
// 5. Ustalık kitabı: kopya eklenir; %25 indirimle seviye atlama
// 6. Kozmetik giy / çıkar; doğrudan kullanılamayan item 409
import { randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { API, istek, apiGiris } from '../tasarim/api.mjs';
import { hesapOku } from '../tasarim/hesap.mjs';

let hata = 0;
const kontrol = (ad, kosul, ek = '') => {
  console.log(`${kosul ? 'GECTI' : 'KALDI'}  ${ad}${ek ? '  ' + ek : ''}`);
  if (!kosul) hata++;
};

async function post(yol, jeton, govde = {}, anahtar = randomUUID()) {
  const r = await fetch(API + yol, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${jeton}`, 'idempotency-key': anahtar },
    body: JSON.stringify(govde),
  });
  return { durum: r.status, tekrar: r.headers.get('idempotent-replay') === 'true', veri: await r.json().catch(() => null) };
}

// Yerel veritabanı (yalnız test sandığı eklemek için)
const PSQL = process.env.PSQL ?? 'C:/Users/muhas/futbol-card-db/pgsql/bin/psql.exe';
const sql = (s) =>
  execFileSync(PSQL, ['-h', '127.0.0.1', '-U', 'futbol', '-d', 'futbol_card', '-Atc', s], {
    env: { ...process.env, PGPASSWORD: process.env.PGPASSWORD ?? 'futbol_dev_sifre_2026' },
  }).toString().trim();

const A = await apiGiris(hesapOku('test-hesabi.local.txt'));
const kullanici = JSON.parse(Buffer.from(A.split('.')[1], 'base64url').toString()).sub;
const ver = (slug, qty = 1) => post('/items/dev/grant', A, { slug, qty });
const adet = (env, slug) => env.items.filter((i) => i.slug === slug).reduce((t, i) => t + i.quantity, 0);

// ---- 1. Envanter ----
let env = await istek('/items', { jeton: A });
kontrol('envanter açık', env.enabled === true, `${env.catalog.length} item tanımı`);

// ---- 2-3. Sandık: hızlandırıcı + anahtar ----
// Süresi dolmuş ama açılmamış sandık yeni sayacı engeller (FAZ 1 kuralı):
// oyuncunun yapacağı gibi önce açılır.
let sandiklar = await istek('/chests', { jeton: A });
for (const c of sandiklar.slots) {
  if (c.status === 'ready') await post(`/chests/${c.id}/open`, A);
}
sandiklar = await istek('/chests', { jeton: A });
// Önceki koşuların mühürlü test sandıkları yeniden kullanılır (yuvalar dolmasın)
const eski = sandiklar.slots.filter((c) => c.source_type === 'uctan_uca_test' && c.status === 'sealed').map((c) => c.id);
const gereken = Math.max(0, 2 - eski.length);
const bos = sandiklar.slot_count - sandiklar.slots.length;
if (bos < gereken || sandiklar.slots.some((c) => c.status === 'unlocking')) {
  console.log(`ATLANDI  sandık adımları (boş yuva ${bos}; ya da sayaç zaten çalışıyor)`);
} else {
  const etiket = randomUUID();
  while (eski.length < 2) {
    eski.push(sql(`select _grant_chest('${kullanici}', 'silver', 'uctan_uca_test', 'faz3-${eski.length}-${etiket}')`));
  }
  const [s1, s2] = eski;
  await ver('chest_key', 1);
  await ver('chest_speedup_2h', 1);
  env = await istek('/items', { jeton: A });
  const anahtarOnce = adet(env, 'chest_key');

  const ac = await post(`/chests/${s1}/unlock`, A);
  const hazirOnce = Date.parse(ac.veri.unlock_ready_at);
  const h = await post('/items/chest_speedup_2h/use', A, { target: { chest_id: s1 } });
  const hazirSonra = Date.parse(h.veri?.result?.unlock_ready_at ?? h.veri?.unlock_ready_at);
  kontrol('hızlandırıcı 2 saat düşer', h.durum === 200 && Math.round((hazirOnce - hazirSonra) / 60000) === 120,
    `${h.durum} fark ${Math.round((hazirOnce - hazirSonra) / 60000)} dk`);

  const ikinciSayac = await post(`/chests/${s2}/unlock`, A);
  kontrol('anahtarsız ikinci sayaç reddedilir', ikinciSayac.durum === 409, `${ikinciSayac.durum} ${ikinciSayac.veri?.code ?? ''}`);

  const k = randomUUID();
  const k1 = await post('/items/chest_key/use', A, { target: { chest_id: s2 } }, k);
  const k2 = await post('/items/chest_key/use', A, { target: { chest_id: s2 } }, k);
  kontrol('anahtar: başka sayaç çalışırken sandık hazır', k1.durum === 200 && JSON.stringify(k1.veri).includes('"chest_ready":true'),
    `${k1.durum}`);
  kontrol('aynı anahtarla tekrar = replay', k2.durum === 200 && k2.tekrar);
  env = await istek('/items', { jeton: A });
  kontrol('anahtar bir kez düştü', adet(env, 'chest_key') === anahtarOnce - 1, `${anahtarOnce} -> ${adet(env, 'chest_key')}`);
  const acildi = await post(`/chests/${s2}/open`, A);
  kontrol('anahtarla açılan sandık açılır', acildi.durum === 200, `${acildi.durum} ${acildi.veri?.code ?? ''}`);
  const ikinci = await post('/items/chest_key/use', A, { target: { chest_id: s2 } });
  kontrol('açılmış sandığa anahtar 409', ikinci.durum === 409 || ikinci.durum === 404, `${ikinci.durum} ${ikinci.veri?.code ?? ''}`);
}

// ---- 4. Enerji içeceği ----
await ver('energy_drink', 3);
env = await istek('/items', { jeton: A });
const limit = env.catalog.find((d) => d.slug === 'energy_drink').params.daily_limit;
let son;
for (let i = env.energy_drinks_today; i < limit; i++) son = await post('/items/energy_drink/use', A);
if (son) kontrol('enerji içeceği kullanılır', son.durum === 200, `enerji ${son.veri?.result?.energy ?? son.veri?.energy}`);
const fazla = await post('/items/energy_drink/use', A);
kontrol('günlük sınır 409 daily_limit', fazla.durum === 409 && fazla.veri?.code === 'daily_limit', `${fazla.durum} ${fazla.veri?.code}`);

// ---- 5. Ustalık kitabı + indirim ----
let o = await istek('/progress', { jeton: A });
const aday = o.items.find((i) => i.owned_copies > 0 && i.next && i.copies < i.next.copies && o.coins >= i.next.coins);
if (!aday) {
  console.log('ATLANDI  kitap/indirim (uygun futbolcu yok)');
} else {
  const kitap = `mastery_book_${aday.tier}`;
  await ver(kitap, 1);
  const kb = await post(`/items/${kitap}/use`, A, { target: { card_id: aday.card_id } });
  o = await istek('/progress', { jeton: A });
  const sonra = o.items.find((i) => i.card_id === aday.card_id);
  kontrol('kitap kopyayı tamamlar', kb.durum === 200 && sonra.copies >= sonra.next.copies,
    `${aday.copies} -> ${sonra.copies} / ${sonra.next.copies}`);

  await ver('level_discount_25', 1);
  const altinOnce = o.coins;
  const tam = sonra.next.coins;
  const lv = await post(`/progress/${aday.card_id}/level-up`, A, { use_jokers: false, use_discount: true });
  o = await istek('/progress', { jeton: A });
  const harcanan = altinOnce - o.coins;
  kontrol('%25 indirimle seviye atlar', lv.durum === 200 && harcanan === tam - Math.floor(tam / 4),
    `${lv.durum} tam ${tam}, harcanan ${harcanan}`);
  const tekrarIndirim = await post(`/progress/${aday.card_id}/level-up`, A, { use_jokers: false, use_discount: true });
  kontrol('indirim tek kullanımlık', tekrarIndirim.durum === 409, `${tekrarIndirim.durum} ${tekrarIndirim.veri?.code}`);
}

// ---- 6. Kozmetik ----
await ver('frame_season1', 1);
const g = await post('/items/frame_season1/equip', A);
env = await istek('/items', { jeton: A });
kontrol('çerçeve giyilir', g.durum === 200 && env.equipped.frame === 'frame_season1');
const c = await post('/items/unequip/frame', A);
env = await istek('/items', { jeton: A });
kontrol('çerçeve çıkarılır', c.durum === 200 && !env.equipped.frame);
const dogrudan = await post('/items/frame_season1/use', A);
kontrol('kozmetik doğrudan kullanılamaz 409', dogrudan.durum === 409 && dogrudan.veri?.code === 'item_not_usable',
  `${dogrudan.durum} ${dogrudan.veri?.code}`);
const anahtarsiz = await fetch(API + '/items/energy_drink/use', {
  method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${A}` }, body: '{}',
});
kontrol('Idempotency-Key olmadan 400', anahtarsiz.status === 400);

console.log(hata ? `\n${hata} KONTROL KALDI` : '\nTÜM KONTROLLER GEÇTİ');
process.exit(hata ? 1 : 0);
