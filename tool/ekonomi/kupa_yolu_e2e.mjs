// KUPA YOLU (043) — uçtan uca (gerçek sunucu, YENİ geçici hesap)
//
//   node --experimental-websocket tool/ekonomi/kupa_yolu_e2e.mjs
//
// YALNIZ yerel geliştirme: test süresince sürüm 4, `bots_v1` ve
// `trophy_road` anahtarları açılır; bitince eski değerlerine döner.
// Geçici hesabın puanı yalnız kurulum için 1090'a ayarlanır (anahtar
// KAPALIYKEN, ödül tetiklenmez); gerisi gerçek dereceli maçla olur.
//
// 1. /leaderboard/trophy-road: açık, 12 basamak, Amatör 2 kilitli
// 2. Gerçek dereceli maç (rakip yoksa bot) KAZANILINCA puan 1115 ->
//    Amatör 2: Gümüş sandık + 50 altın, ekranda "granted"
// 3. Ödül tek: aynı basamak ikinci kez verilmez
// (Sezon sonu sıfırlaması gerçek sezonu kapatmayı gerektirdiği için
//  burada değil, database/tests/043_trophy_road_test.sql'de.)
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
           || '${JSON.stringify(ek)}'::jsonb, 'kupa_yolu_e2e'
  from economy_config_versions where kind = 'feature_flags' returning version`);
const onceki = JSON.parse(sql(`select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1`));

let J = null;
async function post(yol, govde = {}) {
  const r = await fetch(API + yol, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${J}` },
    body: JSON.stringify(govde),
  });
  return { durum: r.status, veri: await r.json().catch(() => null) };
}

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

let uid = null;
try {
  const ek = randomBytes(4).toString('hex');
  const kayit = await istek('/auth/register', {
    yontem: 'POST',
    govde: { email: `kupa_${ek}@test.local`, password: randomBytes(12).toString('base64url'), username: `kupa_${ek}` },
  });
  J = kayit.tokens.access_token;
  uid = kayit.user.id;
  sql(`update users set mmr = 1090 where id = '${uid}'`);           // anahtar KAPALI: ödül yok
  anahtarlar({ economy_v2_enabled: true, ranked_rewards_v2: true, duel_v4: true, bots_v1: true, trophy_road: true });

  let y = await istek('/leaderboard/trophy-road', { jeton: J });
  const t2 = () => y.tiers.find((t) => t.tier_id === 2);
  kontrol('kupa yolu açık, 12 basamak, Amatör 2 kilitli', y.enabled && y.tiers.length === 12 && t2().status === 'locked',
    `${y.tiers.length} basamak, Amatör 2: ${t2().status}`);
  kontrol('Amatör 2 ödülü: Gümüş + 50', t2().reward?.chest === 'silver' && t2().reward?.coins === 50);

  const deste = (await istek('/game/decks', { jeton: J })).decks.find((x) => x.is_active);
  let kazandi = false;
  for (let deneme = 1; deneme <= 4 && !kazandi; deneme++) {
    let mac = null;
    for (let i = 0; !mac?.match_id && i < 20; i++) {
      const r = await istek('/match/find', { yontem: 'POST', govde: { deck_id: deste.id }, jeton: J });
      if (r?.match_id) mac = r; else await bekle(4000);
    }
    if (!mac?.match_id) throw new Error('rakip/bot gelmedi');
    const s = await sonunaKadarOyna(mac.match_id);
    kazandi = s.status === 'finished' && s.winner_id === uid;
    console.log(`       deneme ${deneme}: ${kazandi ? 'kazandı' : 'kazanamadı'} (${s.my_score}-${s.opponent_score})`);
    if (!kazandi) sql(`update users set mmr = 1090 where id = '${uid}'`);   // Amatör 1 içinde kalır
  }
  kontrol('dereceli maç kazanıldı', kazandi);
  const p = (await istek('/me', { jeton: J })).user;
  kontrol('puan 1115 (Amatör 2)', p.mmr === 1115, `${p.mmr}`);
  await bekle(500);
  y = await istek('/leaderboard/trophy-road', { jeton: J });
  kontrol('ekranda Amatör 2 "alındı"', t2().status === 'granted', t2().status);
  const sandik = await istek(`/chests/source?type=trophy_road&id=2`, { jeton: J });
  kontrol('Gümüş sandık verildi', sandik.chest?.chest_type === 'silver', sandik.chest?.chest_type ?? 'yok');
  kontrol('kupa yolu altını defterde (+50) tek kayıt',
    sql(`select count(*) || ':' || sum(coins_delta) from economy_ledger where user_id = '${uid}' and entry_type = 'trophy_road'`) === '1:50');
  sql(`update users set mmr = 1000 where id = '${uid}'`);
  sql(`update users set mmr = 1150 where id = '${uid}'`);
  kontrol('düşüp yeniden çıkınca ikinci ödül yok',
    sql(`select count(*) from trophy_road_grants where user_id = '${uid}'`) === '1');
  kontrol('kupa yolu hatası yok', sql(`select count(*) from economy_errors where context = 'trophy_road'`) === '0');
} finally {
  anahtarlar({
    ranked_rewards_v2: onceki.ranked_rewards_v2 ?? false, duel_v4: onceki.duel_v4 ?? false,
    economy_v2_enabled: onceki.economy_v2_enabled ?? false, bots_v1: onceki.bots_v1 ?? false,
    trophy_road: onceki.trophy_road ?? false,
  });
  console.log('anahtarlar eski değerlerine döndü: kural sürümü', sql('select current_rules_version()'));
}
console.log(hata ? `\n${hata} KONTROL KALDI` : '\nTÜM KONTROLLER GEÇTİ');
process.exit(hata ? 1 : 0);
