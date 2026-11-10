// EKONOMİ V2 FAZ 2 — futbolcu seviyesi, gerçek sunucuda uçtan uca
//   node --experimental-websocket tool/ekonomi/gelisim_e2e.mjs
// A hesabının gerçek gelişim kopyalarıyla:
//   1. GET /progress açık; koleksiyon (inventory) seviye alanını taşır
//   2. Kopyası yeten bir futbolcu seviye atlar; AYNI anahtarla tekrar ->
//      saklanan cevap; altın TAM maliyet kadar düşer (iki kez değil)
//   3. Fazla fiziksel kopya varsa 1'i gelişime çevrilir; tekrar istek
//      ikinci kez çevirmez; koleksiyondaki kopya 1 azalır
//   4. K1: kadronun gücü (deck validate / chemistry) seviyeden etkilenmez
import { randomUUID } from 'node:crypto';
import { API, istek, apiGiris } from '../tasarim/api.mjs';
import { hesapOku } from '../tasarim/hesap.mjs';

let hata = 0;
const kontrol = (ad, kosul, ek = '') => {
  console.log(`${kosul ? 'GECTI' : 'KALDI'}  ${ad}${ek ? '  ' + ek : ''}`);
  if (!kosul) hata++;
};
async function post(yol, jeton, govde, anahtar = randomUUID()) {
  const r = await fetch(API + yol, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${jeton}`, 'idempotency-key': anahtar },
    body: JSON.stringify(govde ?? {}),
  });
  return { durum: r.status, tekrar: r.headers.get('idempotent-replay') === 'true', veri: await r.json().catch(() => null) };
}

const A = await apiGiris(hesapOku('test-hesabi.local.txt'));
let o = await istek('/progress', { jeton: A });
kontrol('gelişim açık', o.enabled === true, `${o.items.length} futbolcu, kural sürümü ${o.rules_version}`);
const env = await istek('/game/inventory', { jeton: A });
kontrol('koleksiyon seviye alanını taşıyor', env.cards.every((k) => typeof k.level === 'number'));

// ---- 2. Seviye atlama ----
const hazir = o.items.find((i) => i.owned_copies > 0 && i.next && i.copies >= i.next.copies && o.coins >= i.next.coins);
if (hazir) {
  const altinOnce = o.coins;
  const anahtar = randomUUID();
  const r1 = await post(`/progress/${hazir.card_id}/level-up`, A, { use_jokers: false }, anahtar);
  const r2 = await post(`/progress/${hazir.card_id}/level-up`, A, { use_jokers: false }, anahtar);
  kontrol(`${hazir.full_name}: seviye ${hazir.level} -> ${r1.veri?.level}`, r1.durum === 200 && r1.veri.level === hazir.level + 1,
    `${hazir.next.copies} kopya, ${hazir.next.coins} altın`);
  kontrol('aynı anahtar: saklanan cevap', r2.tekrar && JSON.stringify(r2.veri) === JSON.stringify(r1.veri));
  o = await istek('/progress', { jeton: A });
  const usta = r1.veri?.mastery_coins ?? 0;
  kontrol('altın tam maliyet kadar düştü (bir kez)', o.coins === altinOnce - hazir.next.coins + usta,
    `${altinOnce} -> ${o.coins}${usta ? ` (+${usta} ustalık)` : ''}`);
  const inv = await istek('/game/inventory', { jeton: A });
  kontrol('koleksiyonda yeni seviye görünüyor', inv.cards.some((k) => k.card_id === hazir.card_id && k.level === hazir.level + 1));
} else {
  const yakin = o.items.filter((i) => i.copies > 0).map((i) => `${i.full_name} ${i.copies}/${i.next?.copies}`).slice(0, 5);
  console.log('NOT: kopyası yeten futbolcu yok; seviye atlama atlandı. Kopyalı:', yakin.join(', ') || 'yok');
}

// Kopya yetmezse reddedilir
const eksik = o.items.find((i) => i.owned_copies > 0 && i.next && i.copies < i.next.copies);
if (eksik) {
  const r = await post(`/progress/${eksik.card_id}/level-up`, A, { use_jokers: false });
  kontrol('kopya eksikken reddedilir (409)', r.durum === 409 && r.veri.code === 'not_enough_copies', r.veri?.code);
}

// ---- 3. Gönüllü dönüşüm ----
const fazla = o.items.find((i) => i.convertible_copies > 0);
if (fazla) {
  const anahtar = randomUUID();
  const c1 = await post(`/progress/${fazla.card_id}/convert`, A, { count: 1 }, anahtar);
  const c2 = await post(`/progress/${fazla.card_id}/convert`, A, { count: 1 }, anahtar);
  kontrol(`${fazla.full_name}: 1 kopya gelişime çevrildi`, c1.durum === 200 && c1.veri.owned_copies === fazla.owned_copies - 1,
    `fiziksel ${fazla.owned_copies} -> ${c1.veri?.owned_copies}, gelişim ${fazla.copies} -> ${c1.veri?.copies}`);
  kontrol('tekrar istek ikinci kez çevirmedi', c2.tekrar && c2.veri.owned_copies === c1.veri.owned_copies);
  const fazlasi = await post(`/progress/${fazla.card_id}/convert`, A, { count: 99 });
  kontrol('fazlası reddedilir (en az 2 kopya kalır)', fazlasi.durum === 409 && fazlasi.veri.code === 'not_convertible');
} else {
  console.log('NOT: dönüştürülebilir fazla kopya yok; dönüşüm atlandı.');
}

// ---- 4. K1: kadro gücü seviyeden bağımsız ----
const { decks } = await istek('/game/decks', { jeton: A });
const deste = decks.find((d) => d.is_active);
const kartlar = await istek(`/game/decks/${deste.id}/cards`, { jeton: A });
const liste = kartlar.cards ?? kartlar;
const katalog = await istek('/game/cards', { jeton: A });
const guc = Object.fromEntries((katalog.cards ?? katalog).map((c) => [c.card_id ?? c.id, c.power]));
kontrol('K1: kadrodaki kart gücü = katalog gücü (seviye eklenmiyor)',
  liste.every((k) => guc[k.card_id] === undefined || k.power === guc[k.card_id]));

console.log(hata ? `\n${hata} KONTROL KALDI` : '\nBUTUN KONTROLLER GECTI');
process.exit(hata ? 1 : 0);
