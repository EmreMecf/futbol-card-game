// DÜELLO SÜRÜM 4 (039) — eş zamanlı gizli seçim, uçtan uca (gerçek sunucu, iki hesap)
//
//   node --experimental-websocket tool/ekonomi/duello_v4_e2e.mjs
//
// YALNIZ yerel geliştirme: test süresince `ranked_rewards_v2` ve `duel_v4`
// anahtarları yerel veritabanında açılır, test bitince (hata olsa da)
// eski değerlerine döndürülür (yeni sürüm satırıyla; geçmiş silinmez).
//
// 1. Yeni maç sürüm 4, mevki aşamasında; mevkiyi yalnız inisiyatif sahibi seçer
// 2. GİZLİLİK: bir oyuncu kartını oynadıktan sonra rakip /moves'ta o kartı
//    GÖRMEZ; rakibin WebSocket'ine de kart/taktik bilgisi gitmez
// 3. İkisi oynayınca tur çözülür, kart iki tarafa da açılır
// 4. Süre aşımı: kimse oynamazsa zamanlayıcı ~15 sn içinde otomatik oynatır
// 5. Maç sonu: kart transferi yok, iki oyuncuya sandık, ≤ 11 tur
//
// SURUM=5 ile (040, seviye gücü): `card_level_power` da açılır; aynı akış
// sürüm 5'te koşar ve REST'teki el gücü = katalog gücü + seviye bonusu
// (match_hand_level_bonus) kontrol edilir. Eşleştirme 'combined' olur.
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
           || '${JSON.stringify(ek)}'::jsonb, 'duello_v4_e2e'
  from economy_config_versions where kind = 'feature_flags' returning version`);

const SURUM = Number(process.env.SURUM ?? 4);
const onceki = JSON.parse(sql(`select payload from economy_config_versions where kind = 'feature_flags' order by version desc limit 1`));
const A = await apiGiris(hesapOku('test-hesabi.local.txt'));
const B = await apiGiris(hesapOku('test-hesabi-2.local.txt'));
const kim = (j) => JSON.parse(Buffer.from(j.split('.')[1], 'base64url').toString()).sub;
const idA = kim(A), idB = kim(B);

async function post(yol, jeton, govde = {}) {
  const r = await fetch(API + yol, {
    method: 'POST',
    headers: { 'content-type': 'application/json', authorization: `Bearer ${jeton}` },
    body: JSON.stringify(govde),
  });
  return { durum: r.status, veri: await r.json().catch(() => null) };
}

try {
  anahtarlar({ economy_v2_enabled: true, ranked_rewards_v2: true, duel_v4: true, card_level_power: SURUM === 5 });
  kontrol('yerelde anahtarlar açıldı', sql('select current_rules_version()') === String(SURUM));
  if (SURUM === 5) kontrol('eşleştirme etkin güce göre (combined)', sql('select matchmaking_mode()') === 'combined');

  // Kadrolar geçerli mi (önceki testler kart kaybettirmiş olabilir)
  for (const [j, ad] of [[A, 'A'], [B, 'B']]) {
    const { decks } = await istek('/game/decks', { jeton: j });
    const d = decks.find((x) => x.is_active);
    const v = await istek(`/game/decks/${d.id}/validate`, { jeton: j });
    if (!v.is_valid) throw new Error(`${ad} kadrosu geçersiz: önce sandik_e2e.mjs ile tamamlayın`);
  }
  const kartSayisi = async (j) => (await istek('/game/inventory', { jeton: j })).cards.length;
  const kartA = await kartSayisi(A), kartB = await kartSayisi(B);

  // ---- Eşleş ----
  const desteA = (await istek('/game/decks', { jeton: A })).decks.find((x) => x.is_active);
  const desteB = (await istek('/game/decks', { jeton: B })).decks.find((x) => x.is_active);
  // İstemci gibi: kuyruktayken düzenli yeniden sor (puan aralığı her 10 sn'de genişler)
  let mac = null;
  for (let i = 0; !mac?.match_id && i < 45; i++) {
    for (const [j, d] of [[A, desteA], [B, desteB]]) {
      const r = await istek('/match/find', { yontem: 'POST', govde: { deck_id: d.id }, jeton: j });
      if (r?.match_id) { mac = r; break; }
    }
    if (!mac?.match_id) await bekle(2000);
  }
  if (!mac?.match_id) {
    for (const j of [A, B]) await post('/match/cancel', j);
    throw new Error('90 sn içinde eşleşme olmadı');
  }
  const id = mac.match_id;
  console.log('maç:', id);
  let s = await istek(`/match/${id}/state`, { jeton: A });
  kontrol(`maç sürüm ${SURUM}, mevki aşamasında`, s.rules_version === SURUM && s.simultaneous && s.phase === 'position',
    `sürüm ${s.rules_version}, aşama ${s.phase}`);
  kontrol('durum: duvar 2 enerji, 12 kartta bitiş', s.tactic_costs?.defensive_wall === 2 && s.early_finish_cards === 12);

  const lead = s.am_i_lead ? A : B, diger = lead === A ? B : A;
  const el = async (j) => (await istek(`/match/${id}/hand`, { jeton: j })).cards.filter((k) => !k.is_played);

  if (SURUM === 5) {
    // El gücü = katalog gücü + seviye bonusu (bonus maç kurulurken donduruldu)
    for (const [j, ad] of [[A, 'A'], [B, 'B']]) {
      const kartlar = (await istek(`/match/${id}/hand`, { jeton: j })).cards;
      const bek = JSON.parse(sql(`select json_object_agg(x.user_card_id, c.power + x.bonus)
        from match_hand_level_bonus x join cards c on c.id = x.card_id where x.match_id = '${id}'`) || '{}');
      const uyan = kartlar.filter((k) => bek[k.user_card_id] === k.power).length;
      kontrol(`${ad}: eldeki güç = katalog + seviye bonusu`, kartlar.length > 0 && uyan === kartlar.length,
        `${uyan}/${kartlar.length}`);
    }
    console.log('       bonus dağılımı:', sql(`select string_agg(n || ' kart +' || bonus, ', ' order by bonus)
      from (select bonus, count(*) n from match_hand_level_bonus where match_id = '${id}' group by bonus) x`));
  }

  // ---- 1. Mevki ----
  const yanlis = await post(`/match/${id}/position`, diger, { position: 'MID' });
  kontrol('mevkiyi inisiyatifsiz oyuncu seçemez', yanlis.durum >= 400, `${yanlis.durum}`);
  const secim = await post(`/match/${id}/position`, lead, { position: 'MID' });
  kontrol('inisiyatif sahibi mevkiyi seçti', secim.durum === 200 && secim.veri?.phase === 'pick');

  // ---- 2. Gizlilik ----
  // Rakibin (inisiyatif sahibinin) WebSocket'ini dinle
  const wsMesajlari = [];
  const ws = new WebSocket(API.replace('http', 'ws').replace('/api', '') + `/ws?token=${lead}`);
  await new Promise((ok, red) => { ws.onopen = ok; ws.onerror = red; setTimeout(ok, 3000); });
  ws.onmessage = (e) => wsMesajlari.push(String(e.data));
  const dKart = (await el(diger)).find((k) => k.position === 'MID');
  await istek(`/match/${id}/play`, { yontem: 'POST', govde: { user_card_id: dKart.user_card_id, tactic: 'none' }, jeton: diger });
  const goren = await istek(`/match/${id}/moves`, { jeton: lead });
  const sizan = goren.moves.filter((m) => m.round_number === 1);
  kontrol('GİZLİLİK: rakip oynadıktan sonra kartı görünmez', sizan.length === 0, `görünen hamle: ${sizan.length}`);
  const sL = await istek(`/match/${id}/state`, { jeton: lead });
  kontrol('ama "rakip oynadı" bilgisi var', sL.opponent_has_played === true && sL.i_have_played === false);
  await bekle(800);
  const hamleOlayi = wsMesajlari.filter((m) => m.includes('move_played'));
  const sizanWs = wsMesajlari.filter((m) => m.includes(dKart.user_card_id) || m.includes(String(dKart.card_id))
    || /"(user_card_id|card_id|tactic|power)"/.test(m));
  kontrol('GİZLİLİK (WebSocket): rakibe yalnız "hamle yapıldı" sinyali gider, kart/taktik gitmez',
    hamleOlayi.length >= 1 && sizanWs.length === 0, `${wsMesajlari.length} mesaj, sızan ${sizanWs.length}`);
  ws.close();

  // ---- 3. Çözüm ----
  const lKart = (await el(lead)).find((k) => k.position === 'MID');
  await istek(`/match/${id}/play`, { yontem: 'POST', govde: { user_card_id: lKart.user_card_id, tactic: 'none' }, jeton: lead });
  const acik = (await istek(`/match/${id}/moves`, { jeton: lead })).moves.filter((m) => m.round_number === 1);
  kontrol('tur çözülünce iki kart da açık', acik.length === 2);
  s = await istek(`/match/${id}/state`, { jeton: A });
  kontrol('2. tur mevki aşaması', s.round_number === 2 && s.phase === 'position');

  // ---- 4. Süre aşımı (zamanlayıcı) ----
  const bas = Date.now();
  let ilerledi = false;
  for (let i = 0; i < 50; i++) {
    await bekle(500);
    s = await istek(`/match/${id}/state`, { jeton: A });
    if (s.round_number >= 3 || s.status !== 'active') { ilerledi = true; break; }
  }
  const sure = ((Date.now() - bas) / 1000).toFixed(1);
  kontrol('kimse oynamayınca zamanlayıcı turu otomatik çözdü', ilerledi, `${sure} sn (sınır: 5 sn mevki + 15 sn seçim)`);
  kontrol('otomatik hamle hükmen bitirmedi (tek seferlik)', s.status === 'active');

  // ---- 5. Sonuna kadar oyna ----
  for (let d = 0; d < 300; d++) {
    s = await istek(`/match/${id}/state`, { jeton: A });
    if (s.status !== 'active') break;
    if (s.phase === 'position') {
      const j = s.am_i_lead ? A : B;
      const k = (await el(j))[0];
      await post(`/match/${id}/position`, j, { position: k.position });
    } else {
      for (const j of [A, B]) {
        const sj = await istek(`/match/${id}/state`, { jeton: j });
        if (sj.status !== 'active' || sj.phase !== 'pick' || sj.i_have_played) continue;
        const k = (await el(j)).filter((x) => x.position === sj.required_position)
          .sort((x, y) => y.power + y.chemistry - (x.power + x.chemistry))[0];
        await post(`/match/${id}/play`, j, { user_card_id: k?.user_card_id ?? null, tactic: 'none' });
      }
    }
  }
  s = await istek(`/match/${id}/state`, { jeton: A });
  const tur = Number(sql(`select count(*) from match_rounds where match_id = '${id}'`));
  kontrol('maç bitti', s.status === 'finished', `skor ${s.my_score}-${s.opponent_score}, ${tur} tur`);
  kontrol('en fazla 11 tur', tur <= 11);
  kontrol('kart transferi yok', (await kartSayisi(A)) === kartA && (await kartSayisi(B)) === kartB,
    `A ${kartA}->${await kartSayisi(A)}, B ${kartB}->${await kartSayisi(B)}`);
  kontrol('bu maçta card_transfers satırı yok', sql(`select count(*) from card_transfers where match_id = '${id}'`) === '0');
  await bekle(800);
  const sa = await istek(`/chests/source?type=match&id=${id}`, { jeton: A });
  const sb = await istek(`/chests/source?type=match&id=${id}`, { jeton: B });
  kontrol('iki oyuncuya da sandık', !!sa.chest && !!sb.chest, `${sa.chest?.chest_type} / ${sb.chest?.chest_type}`);
  void idA; void idB;
} finally {
  anahtarlar({ ranked_rewards_v2: onceki.ranked_rewards_v2 ?? false, duel_v4: onceki.duel_v4 ?? false,
               card_level_power: onceki.card_level_power ?? false,
               economy_v2_enabled: onceki.economy_v2_enabled ?? false });
  console.log('anahtarlar eski değerlerine döndü: kural sürümü', sql('select current_rules_version()'));
}
console.log(hata ? `\n${hata} KONTROL KALDI` : '\nTÜM KONTROLLER GEÇTİ');
process.exit(hata ? 1 : 0);
