// PvP kabul testi: B oyuncusu (ikinci test hesabı) GERÇEK sunucu
// API'siyle oynar. Kurallar sunucuda; bot yalnız yasal hamle seçer:
//   zorunlu mevkide kartı varsa en güçlüsünü, yoksa PAS.
//   Turu kendisi açıyorsa en güçlü kartını.
//
//   node --experimental-websocket tool/tasarim/rakip_bot.mjs [hesap-dosyasi] [kayit]
// Hesap yoksa (yerel geliştirme sunucusunda) oluşturur ve bilgilerini
// git dışındaki dosyaya yazar.
import { existsSync, writeFileSync, appendFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { istek, apiGiris } from './api.mjs';
import { hesapOku } from './hesap.mjs';

const DOSYA = process.argv[2] ?? 'test-hesabi-2.local.txt';
const KAYIT = process.argv[3] ?? 'design-reference/gercek/pvp/bot_kaydi.txt';
const bekle = (ms) => new Promise((r) => setTimeout(r, ms));
const yaz = (m) => {
  console.log(m);
  appendFileSync(KAYIT, m + '\n');
};
if (!process.argv[4]) writeFileSync(KAYIT, '');

let hesap = hesapOku(DOSYA);
if (!hesap) {
  const ek = randomBytes(3).toString('hex');
  hesap = { eposta: `rakip.test.${ek}@futbolcard.local`, sifre: randomBytes(12).toString('base64url'), ad: `rakip_${ek}` };
  await istek('/auth/register', { yontem: 'POST', govde: { email: hesap.eposta, password: hesap.sifre, username: hesap.ad } });
  writeFileSync(
    DOSYA,
    `# YEREL TEST HESABI 2 (PvP kabul testi, sadece yerel gelistirme veritabani)\n# Bu dosya git disinda (.gitignore: *.local.txt)\ne-posta: ${hesap.eposta}\nkullanici adi: ${hesap.ad}\nsifre: ${hesap.sifre}\n`,
  );
  yaz(`yeni test hesabı oluşturuldu: ${hesap.ad}`);
}
const jeton = await apiGiris(hesap);
const j = { jeton };

// Aktif kadro
const { decks } = await istek('/game/decks', j);
const deste = decks.find((d) => d.is_active) ?? decks[0];
yaz(`B (${hesap.ad}) kadro: ${deste.id} (${deste.card_count} kart)`);

// Zaten süren bir maç varsa ona katıl (A oyuncusu için otomatik pilot);
// yoksa kuyruğa gir, A bekliyorsa hemen eşleşir.
const suren = await istek('/match/active', j).catch(() => null);
let mac = suren?.match_id
  ? suren
  : await istek('/match/find', { yontem: 'POST', govde: { deck_id: deste.id }, ...j });
yaz('find: ' + JSON.stringify(mac));
for (let i = 0; !mac.match_id && i < 120; i++) {
  await bekle(1000);
  const aktif = await istek('/match/active', j).catch(() => null);
  if (aktif?.match_id) mac = aktif;
}
const id = mac.match_id;
if (!id) throw new Error('eşleşme olmadı');
yaz('MAÇ: ' + id);

const sira = (k) => k.power + (k.chemistry ?? 0);
for (let dongu = 0; dongu < 400; dongu++) {
  const d = await istek(`/match/${id}/state`, j);
  if (['finished', 'abandoned', 'cancelled'].includes(d.status) || d.winner_id || d.is_draw) {
    yaz(`BİTTİ: durum=${d.status} skor B ${d.my_score} - A ${d.opponent_score} kazanan=${d.winner_id ?? 'beraberlik'}`);
    break;
  }
  if (!d.is_my_turn) {
    await bekle(1200);
    continue;
  }
  // A'nın arayüzde düello animasyonunu izlemesi için kısa bekleme
  await bekle(2500);
  const el = await istek(`/match/${id}/hand`, j);
  const kartlar = (el.cards ?? el).filter((k) => !k.is_played);
  const uygun = d.required_position ? kartlar.filter((k) => k.position === d.required_position) : kartlar;
  uygun.sort((x, y) => sira(y) - sira(x));
  const secim = uygun[0];
  const sonuc = await istek(`/match/${id}/play`, {
    yontem: 'POST',
    govde: { user_card_id: secim?.user_card_id ?? null, tactic: 'none' },
    ...j,
  }).catch((e) => ({ hata: e.message }));
  yaz(`tur ${d.round_number}: zorunlu=${d.required_position ?? '-'} ` +
    (secim ? `oynadı ${secim.full_name} (${secim.position} ${secim.power})` : 'PAS') +
    ` -> ${JSON.stringify(sonuc).slice(0, 160)}`);
  await bekle(800);
}
process.exit(0);
