// Yerel test hesaplarını git dışındaki dosyalardan okur (şifre ekrana
// ya da depoya yazılmaz). Dosya biçimi:  e-posta: ... / sifre: ...
import { readFileSync, existsSync } from 'node:fs';

export function hesapOku(dosya) {
  if (!existsSync(dosya)) return null;
  const d = {};
  for (const satir of readFileSync(dosya, 'utf8').split(/\r?\n/)) {
    if (satir.startsWith('#') || !satir.includes(':')) continue;
    const i = satir.indexOf(':');
    d[satir.slice(0, i).trim()] = satir.slice(i + 1).trim();
  }
  return { eposta: d['e-posta'], sifre: d['sifre'], ad: d['kullanici adi'] };
}

/** Giriş ekranında (390×844) formu doldurup giriş yapar */
export async function girisYap(sekme, hesap, kok = 'http://localhost:5581') {
  await sekme.git(`${kok}/#/giris`, 6000);
  await sekme.tikla(195, 463);
  await sekme.yaz(hesap.eposta);
  await sekme.tikla(195, 527);
  await sekme.yaz(hesap.sifre);
  await sekme.tus('Enter', 'Enter', 13);
  await new Promise((r) => setTimeout(r, 4000));
}
