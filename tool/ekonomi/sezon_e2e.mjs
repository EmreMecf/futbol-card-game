// EKONOMİ V2 FAZ 4 — Battle Pass + görevler uçtan uca kabul testi (gerçek sunucu)
//
//   node --experimental-websocket tool/ekonomi/sandik_e2e.mjs   (önce: gerçek maç oynatır)
//   node tool/ekonomi/sezon_e2e.mjs
//
// Yalnız yerel geliştirme ortamı: XP /api/season/dev/xp ile eklenir.
// Tekrar koşulabilir: her koşu yeni bir kademeye ulaşıp onu alır.
// 1. Sezon açık, 50 kademe; 9 görev
// 2. Son gerçek maçın XP'si (maç sonu ekranının kullandığı uç)
// 3. Ulaşılmamış kademe 409; ulaşılan kademe alınır, aynı anahtarla replay
// 4. Premium kilitli 409 (K4: satın alma yok); geliştirme anahtarıyla açılıp
//    alınır, test sonunda geri kapatılır
// 5. Hepsini al; Idempotency-Key olmadan 400
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

const PSQL = process.env.PSQL ?? 'C:/Users/muhas/futbol-card-db/pgsql/bin/psql.exe';
const sql = (s) =>
  execFileSync(PSQL, ['-h', '127.0.0.1', '-U', 'futbol', '-d', 'futbol_card', '-Atc', s], {
    env: { ...process.env, PGPASSWORD: process.env.PGPASSWORD ?? 'futbol_dev_sifre_2026' },
  }).toString().trim();

const A = await apiGiris(hesapOku('test-hesabi.local.txt'));
const kullanici = JSON.parse(Buffer.from(A.split('.')[1], 'base64url').toString()).sub;
const altin = async () => (await istek('/progress', { jeton: A })).coins;

// ---- 1. Sezon + görevler ----
let s = await istek('/season', { jeton: A });
kontrol('sezon açık', s.enabled === true && s.tiers.length === 50, `${s.season?.name}, kademe ${s.tier}, ${s.xp} XP`);
kontrol('premium satın alma kapalı (K4)', s.premium_purchase_enabled === false);
const g = await istek('/season/missions', { jeton: A });
kontrol('9 görev', g.missions.length === 9,
  g.missions.filter((m) => m.period === 'daily').map((m) => `${m.title} ${m.progress}/${m.target}`).join(', '));

// ---- 2. Son gerçek maçın XP'si ----
const mac = sql(`select m.id from matches m
  where m.status = 'finished' and ${`'${kullanici}'`} in (m.player1_id, m.player2_id)
    and exists (select 1 from economy_ledger l where l.idempotency_key = 'sxp:match:' || m.id || ':' || '${kullanici}')
  order by m.finished_at desc nulls last limit 1`);
if (!mac) {
  console.log('ATLANDI  maç XP (035 sonrası bitmiş maç yok; önce sandik_e2e.mjs çalıştırın)');
} else {
  const x = await istek(`/season/match/${mac}`, { jeton: A });
  const sonuc = sql(`select case when is_draw then 'draw' when winner_id = '${kullanici}' then 'win' else 'loss' end
    from matches where id = '${mac}'`);
  const beklenen = { win: 100, draw: 70, loss: 60 }[sonuc];
  const tam = x.no_energy ? Math.floor(beklenen / 4) : beklenen;
  kontrol('gerçek maç XP doğru', x.xp === tam, `${sonuc}, ${x.no_energy ? 'enerjisiz' : 'enerjili'}: +${x.xp} XP`);
  const bugun = g.missions.find((m) => m.slug === 'daily_play_1');
  kontrol('maç günlük görevi ilerletti', bugun.progress >= 1, `${bugun.progress}/${bugun.target}`);
}

// ---- 3. Kademe alma ----
const kilitli = await post('/season/claim', A, { tier: 50, track: 'free' });
kontrol('ulaşılmamış kademe 409', s.tier >= 50 || (kilitli.durum === 409 && kilitli.veri?.code === 'tier_locked'),
  `${kilitli.durum} ${kilitli.veri?.code}`);

if (s.tier >= 50) {
  console.log('ATLANDI  kademe alma (son kademedesin)');
} else {
  await post('/season/dev/xp', A, { xp: (s.tier + 1) * 1000 - s.xp });
  s = await istek('/season', { jeton: A });
  const t = s.tiers.find((k) => k.tier === s.tier);
  const once = await altin();
  const anahtar = randomUUID();
  const r1 = await post('/season/claim', A, { tier: t.tier, track: 'free' }, anahtar);
  const r2 = await post('/season/claim', A, { tier: t.tier, track: 'free' }, anahtar);
  const sonra = await altin();
  const beklenenAltin = t.free.type === 'coins' ? t.free.amount : 0;
  kontrol(`kademe ${t.tier} alındı (${t.free.type})`, r1.durum === 200 && (t.free.type !== 'coins' || sonra - once === beklenenAltin),
    `${r1.durum}, altın ${once} -> ${sonra}`);
  kontrol('aynı anahtarla tekrar = replay', r2.durum === 200 && r2.tekrar);
  const r3 = await post('/season/claim', A, { tier: t.tier, track: 'free' });
  kontrol('farklı anahtarla tekrar: veritabanı tek sefer', r3.durum === 200 && r3.veri?.replay === true && (await altin()) === sonra);

  // ---- 4. Premium ----
  const p1 = await post('/season/claim', A, { tier: 1, track: 'premium' });
  kontrol('premium kilitli 409', p1.durum === 409 && p1.veri?.code === 'premium_required', `${p1.durum} ${p1.veri?.code}`);
  await post('/season/dev/premium', A, { premium: true });
  const p2 = await post('/season/claim', A, { tier: t.tier, track: 'premium' });
  kontrol('geliştirme premiumuyla premium ödül alınır', p2.durum === 200, `${p2.durum} ${JSON.stringify(p2.veri?.reward ?? p2.veri).slice(0, 80)}`);
  await post('/season/dev/premium', A, { premium: false });
  s = await istek('/season', { jeton: A });
  kontrol('premium geri kapatıldı', s.premium === false);
}

// ---- 5. Hepsini al + anahtarsız istek ----
const hep = await post('/season/claim-all', A);
kontrol('hepsini al', hep.durum === 200, `${hep.veri?.count} ödül`);
s = await istek('/season', { jeton: A });
const kalan = s.tiers.filter((k) => k.tier <= s.tier && !k.free_claimed).length;
kontrol('alınmamış ücretsiz ödül kalmadı', kalan === 0, `${kalan}`);
const anahtarsiz = await fetch(API + '/season/claim-all', {
  method: 'POST', headers: { 'content-type': 'application/json', authorization: `Bearer ${A}` }, body: '{}',
});
kontrol('Idempotency-Key olmadan 400', anahtarsiz.status === 400);

console.log(hata ? `\n${hata} KONTROL KALDI` : '\nTÜM KONTROLLER GEÇTİ');
process.exit(hata ? 1 : 0);
