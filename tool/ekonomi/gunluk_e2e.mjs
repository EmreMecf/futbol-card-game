// GÜNLÜK DÖNGÜ + GÜNÜN TEKLİFİ (044) — uçtan uca (gerçek sunucu, YENİ geçici hesap)
//
//   node --experimental-websocket tool/ekonomi/gunluk_e2e.mjs
//
// YALNIZ yerel geliştirme: test süresince ekonomi V2, sürüm 4, bots_v1,
// daily_loop, daily_shop, pack_duplicates_v2 açılır; bitince eski değerler.
// Geçici hesabın altını yalnız teklif alabilmesi için 5000 yapılır.
//
// 1. /economy/daily: açık; günlük sandık Bronz, seri 1; ikinci istek aynı sandık
// 2. /economy/daily-shop: %25 indirimli teklif; alınır (paket açılır, altın düşer);
//    ikinci alım 409 offer_used
// 3. Gerçek dereceli maç (bot) KAZANILINCA günün ilk galibiyeti: ek sezon XP'si
//    = o maçın galibiyet XP'si
import { execFileSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { API, istek } from '../tasarim/api.mjs';

const bekle = (ms) => new Promise((r) => setTimeout(r, ms));
let hata = 0;
const kontrol = (ad, kosul, ek = '') => {
  console.log(`${kosul ? 'GECTI' : 'KALDI'}  ${ad}${ek ? '  ' + ek : ''}`);
  if (!kosul) hata++;
};
const PSQL = process.env.PSQL ?? 'C:/Users/muhas/futbol-card-db/pgsql/bin/psql.exe';
const sql = (s) =>
  execFileSync(PSQL, ['-h', '127.0.0.1', '-U', 'futbol', '-d', 'futbol_card', '-Atc', s], {
    env: { ...process.env, PGPASSWORD: process.env.PGPASSWORD ?? 'futbol_dev_sifre_2026' },
  }).toString().trim();
const anahtarlar = (ek) => sql(`insert into economy_config_versions (kind, version, payload, note)
  select 'feature_flags', max(version) + 1,
         (select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1)
           || '${JSON.stringify(ek)}'::jsonb, 'gunluk_e2e'
  from economy_config_versions where kind = 'feature_flags' returning version`);
const onceki = JSON.parse(sql(`select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1`));

let J = null;
async function post(yol, govde = {}, anahtar = null) {
  const h = { 'content-type': 'application/json', authorization: `Bearer ${J}` };
  if (anahtar) h['idempotency-key'] = anahtar;
  const r = await fetch(API + yol, { method: 'POST', headers: h, body: JSON.stringify(govde) });
  return { durum: r.status, veri: await r.json().catch(() => null) };
}
const yeniAnahtar = () => randomBytes(16).toString('hex');

async function sonunaKadarOyna(id) {
  const basla = Date.now();
  while (Date.now() - basla < 6 * 60 * 1000) {
    const s = await istek(`/match/${id}/state`, { jeton: J });
    if (s.status !== 'active') return s;
    const el = (await istek(`/match/${id}/hand`, { jeton: J })).cards.filter((k) => !k.is_played);
    if (s.phase === 'position' && s.am_i_lead) {
      for (const p of [...new Set(el.map((k) => k.position))]) {
        if ((await post(`/match/${id}/position`, { position: p })).durum === 200) break;
      }
    } else if (s.phase === 'pick' && !s.i_have_played) {
      const k = el.filter((x) => x.position === s.required_position).sort((a, b) => b.power - a.power)[0];
      const taktik = s.my_energy >= 3 ? 'high_press' : (s.my_energy >= 2 ? 'counter_attack' : 'none');
      if (k) await post(`/match/${id}/play`, { user_card_id: k.user_card_id, tactic: taktik });
    }
    await bekle(700);
  }
  return istek(`/match/${id}/state`, { jeton: J });
}

try {
  anahtarlar({ economy_v2_enabled: true, ranked_rewards_v2: true, duel_v4: true, bots_v1: true,
               daily_loop: true, daily_shop: true, pack_duplicates_v2: true });
  const ek = randomBytes(4).toString('hex');
  const kayit = await istek('/auth/register', {
    yontem: 'POST',
    govde: { email: `gunluk_${ek}@test.local`, password: randomBytes(12).toString('base64url'), username: `gun_${ek}` },
  });
  J = kayit.tokens.access_token;
  const uid = kayit.user.id;

  // ---- 1. Günlük sandık ----
  let d = await istek('/economy/daily', { jeton: J });
  kontrol('günlük döngü açık, bugün alınmadı, Bronz', d.enabled && !d.claimed_today && d.chest_type === 'bronze', JSON.stringify(d));
  const k1 = await post('/economy/daily/claim', {}, yeniAnahtar());
  kontrol('günlük sandık alındı: Bronz, seri 1', k1.durum === 200 && k1.veri?.chest_type === 'bronze' && k1.veri?.streak === 1,
    `${k1.durum} ${JSON.stringify(k1.veri)}`);
  const k2 = await post('/economy/daily/claim', {}, yeniAnahtar());
  kontrol('aynı gün ikinci istek: aynı sandık', k2.veri?.already_claimed === true && k2.veri?.chest_id === k1.veri?.chest_id);
  const anahtarsiz = await post('/economy/daily/claim');
  kontrol('Idempotency-Key olmadan reddedilir', anahtarsiz.durum === 400, `${anahtarsiz.durum}`);
  d = await istek('/economy/daily', { jeton: J });
  kontrol('durum: bugün alındı', d.claimed_today === true && d.streak === 1);
  kontrol('tek günlük sandık', sql(`select count(*) from user_chests where user_id = '${uid}' and source_type = 'daily'`) === '1');

  // ---- 2. Günün teklifi ----
  sql(`update users set coins = 5000 where id = '${uid}'`);
  const t = await istek('/economy/daily-shop', { jeton: J });
  kontrol('teklif: %25 indirim, alınmadı', t.enabled && t.discount_pct === 25 && t.discounted_price === Math.floor(t.price * 75 / 100) && !t.bought_today,
    `${t.name} ${t.price} -> ${t.discounted_price}`);
  const al = await post('/economy/daily-shop/buy', {}, yeniAnahtar());
  kontrol('teklif alındı, paket açıldı', al.durum === 200 && al.veri?.pack?.pack_slug === t.pack_slug,
    `${al.durum} ${al.veri?.pack?.cards?.length ?? 0} kart + ${al.veri?.pack?.progress?.length ?? 0} gelişim kopyası`);
  kontrol('kart + gelişim kopyası = paket kart sayısı',
    (al.veri?.pack?.cards?.length ?? 0) + (al.veri?.pack?.progress?.length ?? 0) === t.card_count);
  const altin = (await istek('/me', { jeton: J })).user.coins;
  kontrol('indirimli fiyat ödendi', altin === 5000 - t.discounted_price, `${altin}`);
  const al2 = await post('/economy/daily-shop/buy', {}, yeniAnahtar());
  kontrol('günde ikinci alım: 409 offer_used', al2.durum === 409 && al2.veri?.code === 'offer_used', `${al2.durum} ${JSON.stringify(al2.veri)}`);

  // ---- 3. Günün ilk galibiyeti ----
  const deste = (await istek('/game/decks', { jeton: J })).decks.find((x) => x.is_active);
  let macId = null;
  for (let deneme = 1; deneme <= 4 && !macId; deneme++) {
    let mac = null;
    for (let i = 0; !mac?.match_id && i < 20; i++) {
      const r = await istek('/match/find', { yontem: 'POST', govde: { deck_id: deste.id }, jeton: J });
      if (r?.match_id) mac = r; else await bekle(4000);
    }
    if (!mac?.match_id) throw new Error('rakip/bot gelmedi');
    const s = await sonunaKadarOyna(mac.match_id);
    console.log(`       deneme ${deneme}: ${s.winner_id === uid ? 'kazandı' : 'kazanamadı'} (${s.my_score}-${s.opponent_score})`);
    if (s.winner_id === uid) macId = mac.match_id;
  }
  kontrol('dereceli maç kazanıldı', !!macId);
  await bekle(500);
  d = await istek('/economy/daily', { jeton: J });
  kontrol('durum: günün ilk galibiyeti alındı', d.first_win_today === true);
  const normal = sql(`select items ->> 'xp' from economy_ledger where idempotency_key = 'sxp:match:${macId}:${uid}'`);
  const bonus = sql(`select items ->> 'xp' from economy_ledger where user_id = '${uid}' and source_type = 'first_win'`);
  kontrol('ek XP = maçın galibiyet XP\'si (çift)', normal !== '' && normal === bonus, `maç ${normal}, ek ${bonus}`);
  kontrol('günlük hata yok',
    sql(`select count(*) from economy_errors where context in ('first_win', 'bot_tick')`) === '0');
} finally {
  anahtarlar({
    ranked_rewards_v2: onceki.ranked_rewards_v2 ?? false, duel_v4: onceki.duel_v4 ?? false,
    economy_v2_enabled: onceki.economy_v2_enabled ?? false, bots_v1: onceki.bots_v1 ?? false,
    daily_loop: onceki.daily_loop ?? false, daily_shop: onceki.daily_shop ?? false,
    pack_duplicates_v2: onceki.pack_duplicates_v2 ?? false,
  });
  console.log('anahtarlar eski değerlerine döndü: kural sürümü', sql('select current_rules_version()'));
}
console.log(hata ? `\n${hata} KONTROL KALDI` : '\nTÜM KONTROLLER GEÇTİ');
process.exit(hata ? 1 : 0);
