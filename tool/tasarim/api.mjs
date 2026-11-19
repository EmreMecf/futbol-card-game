// Yerel sunucuya (http://localhost:8080/api) küçük istemci
export const API = 'http://localhost:8080/api';

export async function istek(yol, { yontem = 'GET', govde, jeton } = {}) {
  const r = await fetch(API + yol, {
    method: yontem,
    headers: { 'content-type': 'application/json', ...(jeton ? { authorization: `Bearer ${jeton}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const metin = await r.text();
  let veri;
  try {
    veri = JSON.parse(metin);
  } catch {
    veri = metin;
  }
  if (!r.ok) throw new Error(`${yontem} ${yol} -> ${r.status} ${metin.slice(0, 300)}`);
  return veri;
}

export async function apiGiris(hesap) {
  const v = await istek('/auth/login', { yontem: 'POST', govde: { email: hesap.eposta, password: hesap.sifre } });
  return v.tokens?.access_token ?? v.access_token;
}
