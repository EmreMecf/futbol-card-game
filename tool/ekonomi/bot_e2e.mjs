// BOT RAKİP + ANTRENMAN (041) — uçtan uca (gerçek sunucu, test hesabı A)
//
//   node --experimental-websocket tool/ekonomi/bot_e2e.mjs
//
// YALNIZ yerel geliştirme: test süresince `bots_v1`, `training_mode` ve
// sürüm 4 anahtarları yerel veritabanında açılır; test bitince (hata olsa
// da) eski değerlerine döndürülür (yeni sürüm satırıyla; geçmiş silinmez).
//
// 1. ANTRENMAN: POST /match/training -> maç hemen kurulur; rakip adı "Bot",
//    mode=training. Bot sunucu zamanlayıcısıyla oynar, maç biter.
//    Puan, altın, G/M/B değişmez; sandık yok; maç geçmişinde yok.
// 2. DERECELİ BOT: rakip yokken /match/find 20 sn sonra bot verir; rakip
//    adı "Bot" DEĞİL (rastgele). Maç biter; puan ±25 (beraberlik 0),
//    oyuncuya maç sandığı verilir, maç geçmişinde görünür.
import { execFileSync } from 'node:child_process';
import { API, istek, apiGiris } from '../tasarim/api.mjs';
import { hesapOku } from '../tasarim/hesap.mjs';

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
           || '${JSON.stringify(ek)}'::jsonb, 'bot_e2e'
  from economy_config_versions where kind = 'feature_flags' returning version`);
const onceki = JSON.parse(sql(`select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1`));

const A = await apiGiris(hesapOku('test-hesabi.local.txt'));

async function post(yol, govde = {}) {
  const r = await fetch(API + yol, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${A}` },
    body: JSON.stringify(govde),
  });
  return { durum: r.status, veri: await r.json().catch(() => null) };
}

// İnsan tarafı: mevki (inisiyatif bendeyse) + o mevkideki en güçlü kart
async function sonunaKadarOyna(id) {
  const basla = Date.now();
  while (Date.now() - basla < 6 * 60 * 1000) {
    const s = await istek(`/match/${id}/state`, { jeton: A });
    if (s.status !== 'active') return s;
    const el = (await istek(`/match/${id}/hand`, { jeton: A })).cards.filter((k) => !k.is_played);
    if (s.simultaneous && s.phase === 'position' && s.am_i_lead) {
      const mevkiler = [...new Set(el.map((k) => k.position))];
      for (const p of mevkiler) {
        if ((await post(`/match/${id}/position`, { position: p })).durum === 200) break;
      }
    } else if (s.phase === 'pick' && !s.i_have_played) {
      const k = el.filter((x) => x.position === s.required_position).sort((a, b) => b.power - a.power)[0];
      if (k) await post(`/match/${id}/play`, { user_card_id: k.user_card_id });
    }
    await bekle(700);
  }
  return istek(`/match/${id}/state`, { jeton: A });
}

const profil = async () => istek('/me', { jeton: A }).then((r) => r.user ?? r);

try {
  anahtarlar({ economy_v2_enabled: true, ranked_rewards_v2: true, duel_v4: true, bots_v1: true, training_mode: true });
  kontrol('yerelde anahtarlar açıldı (sürüm 4)', sql('select current_rules_version()') === '4');
  const deste = (await istek('/game/decks', { jeton: A })).decks.find((x) => x.is_active);

  // ---------------- 1. ANTRENMAN ----------------
  const p0 = await profil();
  const t = await post('/match/training', { deck_id: deste.id });
  kontrol('antrenman maçı hemen kuruldu', t.durum === 200 && t.veri?.status === 'matched', `${t.durum}`);
  const tid = t.veri.match_id;
  let s = await istek(`/match/${tid}/state`, { jeton: A });
  kontrol('durum: mode=training, rakip adı "Bot"', s.mode === 'training' && s.opponent?.username === 'Bot',
    `${s.mode} / ${s.opponent?.username}`);
  const t0 = Date.now();
  s = await sonunaKadarOyna(tid);
  kontrol('antrenman bitti (bot sunucu zamanlayıcısıyla oynadı)', s.status === 'finished',
    `skor ${s.my_score}-${s.opponent_score}, ${Math.round((Date.now() - t0) / 1000)} sn`);
  kontrol('bot hiç süre aşımına düşmedi',
    sql(`select auto_streak from match_players mp join users u on u.id = mp.user_id where mp.match_id = '${tid}' and u.is_bot`) === '0');
  const p1 = await profil();
  kontrol('antrenman: puan / altın / G-M-B değişmedi',
    p1.mmr === p0.mmr && p1.coins === p0.coins && p1.wins === p0.wins && p1.losses === p0.losses && p1.draws === p0.draws,
    `puan ${p0.mmr}->${p1.mmr}, altın ${p0.coins}->${p1.coins}`);
  await bekle(800);
  const ts = await istek(`/chests/source?type=match&id=${tid}`, { jeton: A });
  kontrol('antrenman: sandık yok', !ts.chest);
  const r1 = await istek(`/match/${tid}/result`, { jeton: A });
  kontrol('sonuç: mode=training, rakip "Bot"', r1.mode === 'training' && r1.opponent?.username === 'Bot');
  const g1 = (await istek('/match/history?limit=50', { jeton: A })).matches;
  kontrol('antrenman maç geçmişinde yok', !g1.some((m) => m.match_id === tid));

  // ---------------- 2. DERECELİ BOT ----------------
  const p2 = await profil();
  let mac = null;
  const aramaBasi = Date.now();
  for (let i = 0; !mac?.match_id && i < 20; i++) {
    const r = await istek('/match/find', { yontem: 'POST', govde: { deck_id: deste.id }, jeton: A });
    if (r?.match_id) mac = r;
    else await bekle(4000);   // istemcinin yoklama aralığı
  }
  const sure = Math.round((Date.now() - aramaBasi) / 1000);
  if (!mac?.match_id) {
    await post('/match/cancel');
    throw new Error('80 sn içinde bot gelmedi');
  }
  kontrol('rakip yokken ~20 sn sonra bot geldi', sure >= 19 && sure <= 32, `${sure} sn`);
  const rid = mac.match_id;
  s = await istek(`/match/${rid}/state`, { jeton: A });
  kontrol('dereceli bot: mode=ranked, rastgele ad (Bot değil)',
    s.mode === 'ranked' && s.opponent?.username && s.opponent.username !== 'Bot', `${s.opponent?.username}`);
  kontrol('rakip gerçekten bot hesabı', sql(`select is_bot from users where id = '${s.opponent.id}'`) === 't');
  s = await sonunaKadarOyna(rid);
  kontrol('dereceli bot maçı bitti', s.status === 'finished', `skor ${s.my_score}-${s.opponent_score}`);
  const p3 = await profil();
  const beklenen = s.is_draw ? 0 : (s.winner_id === p2.id ? 25 : -25);
  kontrol('dereceli bot: puan normal (±25 / beraberlik 0)', p3.mmr - p2.mmr === beklenen,
    `${p2.mmr}->${p3.mmr}, beklenen ${beklenen >= 0 ? '+' : ''}${beklenen}`);
  await bekle(800);
  const rs = await istek(`/chests/source?type=match&id=${rid}`, { jeton: A });
  kontrol('dereceli bot: maç sandığı verildi', !!rs.chest, rs.chest?.chest_type ?? '');
  const g2 = (await istek('/match/history?limit=50', { jeton: A })).matches;
  kontrol('dereceli bot maç geçmişinde', g2.some((m) => m.match_id === rid));
  kontrol('bot sıralama tablosunda yok',
    !(await istek('/leaderboard?limit=200', { jeton: A })).entries?.some?.((e) => e.username === s.opponent.username));
  kontrol('bot hatası kaydedilmedi', sql(`select count(*) from economy_errors where context = 'bot_tick'`) === '0');
} finally {
  anahtarlar({
    ranked_rewards_v2: onceki.ranked_rewards_v2 ?? false, duel_v4: onceki.duel_v4 ?? false,
    economy_v2_enabled: onceki.economy_v2_enabled ?? false, bots_v1: onceki.bots_v1 ?? false,
    training_mode: onceki.training_mode ?? false,
  });
  console.log('anahtarlar eski değerlerine döndü: kural sürümü', sql('select current_rules_version()'));
}
console.log(hata ? `\n${hata} KONTROL KALDI` : '\nTÜM KONTROLLER GEÇTİ');
process.exit(hata ? 1 : 0);
