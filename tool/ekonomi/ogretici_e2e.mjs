// ÖĞRETİCİ (042) — uçtan uca (gerçek sunucu, YENİ geçici hesap)
//
//   node --experimental-websocket tool/ekonomi/ogretici_e2e.mjs
//
// YALNIZ yerel geliştirme: test süresince sürüm 4 anahtarları ve
// `tutorial_v1` yerel veritabanında açılır; test bitince (hata olsa da)
// eski değerlerine döndürülür. Öğretici kişi başı TEK SEFER olduğu için
// test her çalışmada kendi geçici hesabını açar (test hesaplarına dokunmaz;
// şifre rastgele, hiçbir yere yazılmaz).
//
// 1. Yeni hesap: öğretici açık, sıradaki adım 1
// 2. Adım 1/2/3 sırayla: maç hemen kurulur, rakip "Bot", kural sürümü
//    6/6/7, adım 1'de ilk mevki oyuncuda; maç kısa (6 kart) ve biter
// 3. Her maçtan sonra adım ilerler; 3. adımda TEK Gümüş sandık
// 4. Puan, altın, G/M/B değişmez; maç geçmişi boş; tekrar başlatılamaz
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
           || '${JSON.stringify(ek)}'::jsonb, 'ogretici_e2e'
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
  while (Date.now() - basla < 5 * 60 * 1000) {
    const s = await istek(`/match/${id}/state`, { jeton: J });
    if (s.status !== 'active') return s;
    const el = (await istek(`/match/${id}/hand`, { jeton: J })).cards.filter((k) => !k.is_played);
    if (s.phase === 'position' && s.am_i_lead) {
      for (const p of [...new Set(el.map((k) => k.position))]) {
        if ((await post(`/match/${id}/position`, { position: p })).durum === 200) break;
      }
    } else if (s.phase === 'pick' && !s.i_have_played) {
      const k = el.filter((x) => x.position === s.required_position).sort((a, b) => b.power - a.power)[0];
      // 3. adımda enerji yetiyorsa pres dene (taktikli sürüm)
      const taktik = s.tactics_enabled && s.my_energy >= 3 ? 'high_press' : 'none';
      if (k) await post(`/match/${id}/play`, { user_card_id: k.user_card_id, tactic: taktik });
    }
    await bekle(700);
  }
  return istek(`/match/${id}/state`, { jeton: J });
}

try {
  anahtarlar({ economy_v2_enabled: true, ranked_rewards_v2: true, duel_v4: true, tutorial_v1: true });
  kontrol('yerelde anahtarlar açıldı (sürüm 4)', sql('select current_rules_version()') === '4');

  const ek = randomBytes(4).toString('hex');
  const kayit = await istek('/auth/register', {
    yontem: 'POST',
    govde: { email: `ogretici_${ek}@test.local`, password: randomBytes(12).toString('base64url'), username: `ogr_${ek}` },
  });
  J = kayit.tokens.access_token;
  const p0 = (await istek('/me', { jeton: J })).user;
  const deste = (await istek('/game/decks', { jeton: J })).decks.find((x) => x.is_active);

  let t = await istek('/match/tutorial', { jeton: J });
  kontrol('yeni hesap: öğretici açık, sıradaki adım 1', t.enabled && t.next_step === 1 && !t.completed, JSON.stringify(t));

  for (const adim of [1, 2, 3]) {
    const r = await post('/match/tutorial/start', { deck_id: deste.id });
    kontrol(`adım ${adim}: maç hemen kuruldu`, r.durum === 200 && r.veri?.status === 'matched', `${r.durum}`);
    const id = r.veri.match_id;
    let s = await istek(`/match/${id}/state`, { jeton: J });
    const surum = adim < 3 ? 6 : 7;
    kontrol(`adım ${adim}: öğretici, sürüm ${surum}, rakip "Bot", 6 kartta bitiş`,
      s.mode === 'tutorial' && s.tutorial_step === adim && s.rules_version === surum &&
        s.opponent?.username === 'Bot' && s.early_finish_cards === 6 && s.tactics_enabled === (adim === 3),
      `${s.mode}/${s.tutorial_step}/${s.rules_version}/${s.opponent?.username}/${s.early_finish_cards}/taktik ${s.tactics_enabled}`);
    if (adim === 1) kontrol('adım 1: ilk mevkiyi oyuncu seçer', s.am_i_lead && s.phase === 'position');
    const t0 = Date.now();
    s = await sonunaKadarOyna(id);
    kontrol(`adım ${adim}: maç bitti`, s.status === 'finished',
      `skor ${s.my_score}-${s.opponent_score}, ${Math.round((Date.now() - t0) / 1000)} sn`);
    const sonuc = await istek(`/match/${id}/result`, { jeton: J });
    kontrol(`adım ${adim}: sonuç ekranı öğretici`, sonuc.mode === 'tutorial' && sonuc.tutorial_step === adim);
    t = await istek('/match/tutorial', { jeton: J });
    kontrol(`adım ${adim} tamamlandı`, t.step === adim, JSON.stringify(t));
  }

  kontrol('öğretici tamamlandı', t.completed === true && t.next_step == null);
  await bekle(500);
  const uid = (await istek('/me', { jeton: J })).user.id;
  const sandik = await istek(`/chests/source?type=tutorial&id=${uid}`, { jeton: J });
  kontrol('3. adımda Gümüş sandık', sandik.chest?.chest_type === 'silver', sandik.chest?.chest_type ?? 'yok');
  kontrol('öğreticiden tek sandık',
    sql(`select count(*) from user_chests where user_id = '${uid}' and source_type = 'tutorial'`) === '1');
  kontrol('öğretici maçlarından maç sandığı yok',
    sql(`select count(*) from user_chests where user_id = '${uid}' and source_type = 'match'`) === '0');
  const p1 = (await istek('/me', { jeton: J })).user;
  kontrol('puan / altın / G-M-B değişmedi',
    p1.mmr === p0.mmr && p1.coins === p0.coins && p1.wins === p0.wins && p1.losses === p0.losses && p1.draws === p0.draws,
    `puan ${p0.mmr}->${p1.mmr}, altın ${p0.coins}->${p1.coins}`);
  const gecmis = (await istek('/match/history?limit=50', { jeton: J })).matches;
  kontrol('maç geçmişi boş (öğretici sayılmaz)', gecmis.length === 0, `${gecmis.length}`);
  const tekrar = await post('/match/tutorial/start', { deck_id: deste.id });
  kontrol('tamamlanınca tekrar başlamaz', tekrar.durum >= 400, `${tekrar.durum}`);
  kontrol('öğretici/bot hatası yok',
    sql(`select count(*) from economy_errors where context in ('bot_tick', 'tutorial_chest')`) === '0');
} finally {
  anahtarlar({
    ranked_rewards_v2: onceki.ranked_rewards_v2 ?? false, duel_v4: onceki.duel_v4 ?? false,
    economy_v2_enabled: onceki.economy_v2_enabled ?? false, tutorial_v1: onceki.tutorial_v1 ?? false,
  });
  console.log('anahtarlar eski değerlerine döndü: kural sürümü', sql('select current_rules_version()'));
}
console.log(hata ? `\n${hata} KONTROL KALDI` : '\nTÜM KONTROLLER GEÇTİ');
process.exit(hata ? 1 : 0);
