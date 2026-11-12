// EKONOMİ V2 FAZ 1 — uçtan uca kabul testi (gerçek sunucu + iki test hesabı)
//
//   node --experimental-websocket tool/ekonomi/sandik_e2e.mjs
//
// 1. A ve B kuyruğa girer, maç kurallı botla sonuna kadar oynanır
// 2. A'nın WebSocket'ine 'chest_granted' gelir
// 3. İki oyuncunun da maç sandığı vardır; /chests/source maçla eşleşir
// 4. Kilit aç -> süre dolmadan açma 409 -> (Bronz ise anında) aç
// 5. Aynı Idempotency-Key ile tekrar: saklanan cevap (replay)
//    Farklı anahtarla tekrar: veritabanı aynı sonucu döner (tek sefer)
// 6. Anahtarsız değiştirici istek 400
import { randomUUID } from 'node:crypto';
import { API, istek, apiGiris } from '../tasarim/api.mjs';
import { hesapOku } from '../tasarim/hesap.mjs';

const bekle = (ms) => new Promise((r) => setTimeout(r, ms));
let hata = 0;
const kontrol = (ad, kosul, ek = '') => {
  console.log(`${kosul ? 'GECTI' : 'KALDI'}  ${ad}${ek ? '  ' + ek : ''}`);
  if (!kosul) hata++;
};

async function post(yol, jeton, { anahtar = randomUUID(), govde = {} } = {}) {
  const r = await fetch(API + yol, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${jeton}`, ...(anahtar ? { 'idempotency-key': anahtar } : {}) },
    body: JSON.stringify(govde),
  });
  return { durum: r.status, tekrar: r.headers.get('idempotent-replay') === 'true', veri: await r.json().catch(() => null) };
}

const A = await apiGiris(hesapOku('test-hesabi.local.txt'));
const B = await apiGiris(hesapOku('test-hesabi-2.local.txt'));

// ---- WebSocket (A) ----
const olaylar = [];
const ws = new WebSocket(API.replace('http', 'ws').replace('/api', '') + `/ws?token=${A}`);
ws.onmessage = (m) => olaylar.push(JSON.parse(m.data));
await bekle(800);

// Oyuncunun yapacağı gibi: kadro geçersizse (kart kaybı sonrası)
// koleksiyondaki en güçlülerle tamamla; kart yetmezse standart paket al.
const FORMASYON = [['GK', 1], ['DEF', 4], ['MID', 4], ['FWD', 2]];
async function kadroyuTamamla(jeton, ad) {
  const { decks } = await istek('/game/decks', { jeton });
  const deste = decks.find((d) => d.is_active);
  for (let deneme = 0; deneme < 10; deneme++) {
    const v = await istek(`/game/decks/${deste.id}/validate`, { jeton });
    if (v.is_valid) return deste;
    const { cards } = await istek('/game/inventory', { jeton });
    const serbest = cards.filter((k) => !k.is_locked);
    const secim = [];
    let eksik = false;
    for (const [mevki, adet] of FORMASYON) {
      const aday = serbest.filter((k) => k.position === mevki).sort((x, y) => y.power - x.power).slice(0, adet);
      if (aday.length < adet) eksik = true;
      secim.push(...aday.map((k) => k.user_card_id));
    }
    if (eksik) {
      // Ekonomi V2 (031): önce hazır sandıkları aç — sandık, eksik mevkiden
      // FİZİKSEL kart verir (kadro kilidi koruması)
      const env = await istek('/chests', { jeton });
      const hazir = [...env.instant, ...env.slots.filter((c) => c.status === 'ready')];
      if (hazir.length) {
        for (const c of hazir) {
          const ac = await post(`/chests/${c.id}/open`, jeton);
          const koruma = ac.veri?.cards?.filter((k) => k.outcome === 'squad_guard') ?? [];
          kontrol(`${ad}: hazır sandık açıldı (${c.chest_type})`, ac.durum === 200,
            `kadro koruması: ${koruma.map((k) => `${k.full_name} (${k.position})`).join(', ') || 'yok'}`);
        }
        continue;
      }
      // Ekonomi V2 (032): Acil Kadro — eksik sayıda Bronz kart, 24 saatte bir
      const durum = await istek('/economy/emergency-squad', { jeton });
      if (durum.eligible) {
        const al = await post('/economy/emergency-squad/claim', jeton);
        kontrol(`${ad}: acil kadro alındı`, al.durum === 200,
          `eksik ${JSON.stringify(durum.missing)} -> ${al.veri?.cards?.map((k) => `${k.full_name} (${k.position})`).join(', ')}`);
        continue;
      }
      console.log(`${ad}: kadro kurulamıyor, acil kadro yok (${JSON.stringify(durum)}) -> standart paket`);
      // Gerçek kilitlenme (eski kural: kart kaybı + acil kadro 24 sa + altın yok).
      // Test hesabı tıkanmasın: YALNIZ geliştirme ucuyla paket parası eklenir.
      try {
        await istek('/game/packs/standard/open', { yontem: 'POST', govde: {}, jeton });
      } catch (e) {
        if (!String(e.message).includes('Yeterli coin yok')) throw e;
        console.log(`${ad}: KİLİTLENME (altın yok, acil kadro beklemede) -> geliştirme ucuyla 500 altın`);
        await istek('/game/dev/add-coins', { yontem: 'POST', govde: { amount: 500 }, jeton });
      }
      continue;
    }
    await istek(`/game/decks/${deste.id}`, { yontem: 'PUT', govde: { user_card_ids: secim }, jeton });
    console.log(`${ad}: kadro koleksiyondan tamamlandı`);
  }
  return deste;
}

// ---- Maç: iki taraf da kurallı bot ----
async function oyna(jeton, ilk) {
  const deste = await kadroyuTamamla(jeton, ilk ? 'A' : 'B');
  let mac = ilk ? await istek('/match/find', { yontem: 'POST', govde: { deck_id: deste.id }, jeton }) : null;
  // İstemci gibi 4 sn'de bir yeniden sor: iki test hesabının puan farkı
  // büyükse eşleştirme aralığı ancak zamanla genişler (10 sn'de +50).
  for (let i = 0; !mac?.match_id && i < 180; i++) {
    if (i % 8 === (ilk ? 4 : 0)) mac = await istek('/match/find', { yontem: 'POST', govde: { deck_id: deste.id }, jeton });
    if (mac?.match_id) break;
    await bekle(500);
    mac = await istek('/match/active', { jeton });
  }
  if (!mac?.match_id) throw new Error(`${ilk ? 'A' : 'B'}: 90 sn içinde eşleşme olmadı`);
  const id = mac.match_id;
  for (let d = 0; d < 400; d++) {
    const s = await istek(`/match/${id}/state`, { jeton });
    if (s.status !== 'active') return { id, s };
    if (!s.is_my_turn) { await bekle(150); continue; }
    const el = (await istek(`/match/${id}/hand`, { jeton })).cards.filter((k) => !k.is_played);
    const uygun = (s.required_position ? el.filter((k) => k.position === s.required_position) : el)
      .sort((x, y) => y.power + y.chemistry - (x.power + x.chemistry));
    await istek(`/match/${id}/play`, { yontem: 'POST', govde: { user_card_id: uygun[0]?.user_card_id ?? null, tactic: 'none' }, jeton })
      .catch(() => {});
  }
}
const [ra] = await Promise.all([oyna(A, true), (async () => { await bekle(600); return oyna(B, false); })()]);
const macId = ra.id;
console.log('maç:', macId, 'durum', ra.s.status, 'skor', ra.s.my_score, '-', ra.s.opponent_score);
await bekle(1500);

// ---- 2. WebSocket ----
const ev = olaylar.find((o) => o.type === 'chest_granted' && o.source_id === macId);
kontrol("A'ya chest_granted olayı geldi", !!ev, ev ? `(${ev.chest_type})` : JSON.stringify(olaylar.map((o) => o.type)));

// ---- 3. İki oyuncuya da maç sandığı ----
const sa = await istek(`/chests/source?type=match&id=${macId}`, { jeton: A });
const sb = await istek(`/chests/source?type=match&id=${macId}`, { jeton: B });
kontrol("A'nın maç sandığı var", !!sa.chest, sa.chest ? `${sa.chest.chest_type} / ${sa.chest.location}` : JSON.stringify(sa));
kontrol("B'nin maç sandığı var", !!sb.chest, sb.chest ? `${sb.chest.chest_type} / ${sb.chest.location}` : JSON.stringify(sb));

// ---- 4-5. Açma ----
const envanter = await istek('/chests', { jeton: A });
kontrol('envanter: anahtar açık', envanter.enabled === true, `enerji ${envanter.energy.energy}/${envanter.energy.max}`);
let hedef = sa.chest;
if (hedef && hedef.location === 'slot' && hedef.status === 'sealed') {
  const ac = await post(`/chests/${hedef.id}/unlock`, A);
  kontrol('kilit açma başladı', ac.durum === 200 && ac.veri.status === 'unlocking',
    `hazır: ${ac.veri?.unlock_ready_at}`);
  const erken = await post(`/chests/${hedef.id}/open`, A);
  kontrol('süre dolmadan açma reddedilir (409)', erken.durum === 409 && erken.veri.code === 'chest_not_ready', erken.veri?.code);
  // Bronz (anında) sandıkla tekrar testine geç
  hedef = envanter.instant[0] ?? null;
}
// Anında açılabilen (Bronz) sandık: önce A'da, yoksa B'de
let sahip = A;
if (!hedef || hedef.location !== 'instant') {
  hedef = (await istek('/chests', { jeton: A })).instant[0] ?? null;
  if (!hedef) {
    hedef = (await istek('/chests', { jeton: B })).instant[0] ?? null;
    sahip = B;
  }
}
if (hedef) {
  const anahtar = randomUUID();
  const r1 = await post(`/chests/${hedef.id}/open`, sahip, { anahtar });
  const r2 = await post(`/chests/${hedef.id}/open`, sahip, { anahtar });
  const r3 = await post(`/chests/${hedef.id}/open`, sahip);
  const baskasi = await post(`/chests/${hedef.id}/open`, sahip === A ? B : A);
  kontrol('başkasının sandığı açılamaz (404)', baskasi.durum === 404, baskasi.veri?.code);
  kontrol('sandık açıldı: tam 3 futbolcu', r1.durum === 200 && r1.veri.cards.length === 3,
    r1.veri?.cards?.map((k) => `${k.full_name} (${k.outcome})`).join(', '));
  kontrol('aynı anahtar: saklanan cevap', r2.tekrar && JSON.stringify(r2.veri) === JSON.stringify(r1.veri));
  kontrol('farklı anahtar: veritabanı aynı sonuç (tek sefer)', JSON.stringify(r3.veri) === JSON.stringify(r1.veri));
  const defter = await istek('/economy/ledger?limit=20', { jeton: sahip });
  const kayit = defter.entries.filter((e) => e.source_id === hedef.id && e.entry_type === 'chest_open');
  kontrol('defterde tek açılış kaydı', kayit.length === 1, `+${kayit[0]?.coins_delta} altın`);
} else {
  console.log('NOT: açılabilir Bronz sandık yok (bu maçta Bronz çıkmadı); tekrar testi atlandı');
}

// ---- 6. Anahtarsız ----
const anahtarsiz = await post(`/chests/${sa.chest?.id ?? 'x'}/unlock`, A, { anahtar: null });
kontrol('anahtarsız istek 400', anahtarsiz.durum === 400 && anahtarsiz.veri.code === 'idempotency_key_required');

// ---- Olasılıklar ----
const odds = await istek('/chests/odds', { jeton: A });
kontrol('olasılık tablosu sürümlü', odds.version >= 1, `sürüm ${odds.version}, galibiyet Efsane ${odds.type_odds.win.legend}/1000`);

ws.close();
console.log(hata ? `\n${hata} KONTROL KALDI` : '\nBUTUN KONTROLLER GECTI');
process.exit(hata ? 1 : 0);
