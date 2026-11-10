// pvp_sunucu.mjs'e komut gönderir. Örnek:
//   node tool/tasarim/komut.mjs tikla 195 600 bekle 800 foto 20_adim
// Komutlar: tikla x y | kaydir dy | bekle ms | rota #/yol | foto ad |
//           seri ad adet aralikMs | fps ms | durum | konsol n | kapat
const r = await fetch('http://127.0.0.1:9341/?a=' + encodeURIComponent(JSON.stringify(process.argv.slice(2))));
const metin = await r.text();
if (metin) console.log(metin);
process.exit(r.ok ? 0 : 1);
