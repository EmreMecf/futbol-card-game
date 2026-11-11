"""DÜELLO V3 SİMÜLASYONU — eş zamanlı gizli seçim + sınırlı seviye gücü.

Karar (11 Kasım 2026): (1) iki oyuncu kartını AYNI ANDA gizli seçer, tur
süresi kısalır; (2) seviye sınırlı güç verir (B), derecelide lig tavanı.
Bu dosya YALNIZ ölçer; oyun kodu değişmez.

Karşılaştırılan iki kural
  V2 (mevcut) : açan kartını AÇIK oynar; cevap veren aynı mevkiden, açanın
                kartını GÖREREK oynar. Taktik gizli. Uyamayan pas geçer.
  V3 (öneri)  : inisiyatif sahibi yalnız MEVKİYİ açıklar; iki oyuncu o
                mevkiden kart + taktiği aynı anda gizli seçer. İki kadro
                aynı dizilişte (1-4-4-2) olduğundan pas yoktur. Bir oyuncu
                12 kart topladığında (22'nin çoğu) maç erken biter.
Ortak: Efsane kuralı, kimya, beraberlikte kartlar ortada kalır ve
inisiyatif karşıya geçer, taktikler (pres 3 enerji +9; kontra 2 enerji +2,
prese karşı +13; duvar 1 enerji, inisiyatifsizken +6, inisiyatifliyken +2;
pres duvarı, duvar kontrayı, kontra presi SIFIRLAR), enerji 2 başlar, tur
başına +1, en fazla 5.

Seviye gücü (B): bonus = seviye // 2 (L2 +1 ... L10 +5). Derecelide iki
tarafın seviyesi LİG TAVANI ile sınırlanır.

Kullanım: python -I tool/ekonomi/duello_v3.py [maç sayısı]
Çıktı:    tool/ekonomi/duello_v3.md
"""
from __future__ import annotations

import pathlib
import random
import statistics
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import simulasyon as S  # noqa: E402

KOK = pathlib.Path(__file__).resolve().parent
FORMASYON = {'GK': 1, 'DEF': 4, 'MID': 4, 'FWD': 2}
MALIYET = {'yok': 0, 'pres': 3, 'kontra': 2, 'duvar': 1}
KIRAR = {'pres': 'duvar', 'duvar': 'kontra', 'kontra': 'pres'}


def taktik_bonus(benim: str, onun: str, inisiyatif: bool) -> int:
    if benim == 'yok' or KIRAR.get(onun) == benim:
        return 0
    if benim == 'pres':
        return 9
    if benim == 'kontra':
        return 13 if onun == 'pres' else 2
    return 2 if inisiyatif else 6


EGRI = 'b1'   # b1: seviye // 2 (en fazla +5) | b2: L4 +1, L7 +2, L10 +3


def seviye_bonus(sv: int, tavan: int | None) -> int:
    sv = min(sv, tavan or 10)
    return sv // 2 if EGRI == 'b1' else (sv - 1) // 3


def guce_gore_rakip(kadro, bonus: int, r: random.Random) -> list:
    """Eşleştirme ETKİN güce bakarsa bulunacak rakip: her mevkide
    (güç + seviye bonusu) ±3 içinde, seviye 1 bir kart"""
    secim = []
    for k in kadro:
        havuz = [c for c in S.KATALOG if c.mevki == k.mevki and c.tier != 'legend'
                 and abs(c.guc - (k.guc + bonus)) <= 3 and c not in secim] or [k]
        secim.append(r.choice(havuz))
    return secim


class Taraf:
    def __init__(self, kadro, seviye: dict, ajan: str, tavan: int | None):
        kim = S.kimya(kadro)
        self.el = [(k, k.guc + kim[k.slug] + seviye_bonus(seviye.get(k.slug, 1), tavan)) for k in kadro]
        self.ajan = ajan
        self.enerji = 2
        self.toplanan = 0

    def mevkiler(self):
        return sorted({k.mevki for k, _ in self.el})

    def uygun(self, mevki):
        return [x for x in self.el if x[0].mevki == mevki]

    # ---- kararlar ----
    def mevki_sec(self, r):
        m = self.mevkiler()
        if self.ajan == 'akilli':
            # en güçlü kartının olduğu mevki (%60), yoksa rastgele
            if r.random() < 0.6:
                return max(self.el, key=lambda x: x[1])[0].mevki
        return r.choice(m)

    def kart_sec(self, mevki, r, rakip_karti=None):
        u = self.uygun(mevki)
        if not u:
            return None
        if rakip_karti is not None and self.ajan != 'rastgele':
            # V2 cevap veren: açanın kartını görür -> yenebilen en zayıf kart, yoksa en zayıf
            yenen = [x for x in u if x[1] > rakip_karti[1] or (x[0].tier == 'legend' and rakip_karti[0].tier != 'legend')]
            return min(yenen, key=lambda x: x[1]) if yenen else min(u, key=lambda x: x[1])
        if self.ajan == 'acgozlu':
            return max(u, key=lambda x: x[1])
        if self.ajan == 'akilli':
            sirali = sorted(u, key=lambda x: x[1], reverse=True)
            # karışık strateji: en güçlü %50, ikinci %30, en zayıf %20 (feda)
            x = r.random()
            return sirali[0] if x < 0.5 else sirali[min(1, len(sirali) - 1)] if x < 0.8 else sirali[-1]
        return r.choice(u)

    def taktik_sec(self, r):
        olur = [t for t, m in MALIYET.items() if m <= self.enerji]
        if self.ajan == 'taktiksiz':
            return 'yok'
        if self.ajan == 'acgozlu':
            return 'pres' if 'pres' in olur else 'yok'
        if self.ajan == 'akilli':
            agirlik = {'yok': 30, 'duvar': 25, 'kontra': 25, 'pres': 20}
            return r.choices(olur, weights=[agirlik[t] for t in olur])[0]
        return r.choice(olur)


def mac(a: Taraf, b: Taraf, kural: str, r: random.Random):
    """Dönen: (sonuç: +1 a / -1 b / 0, tur sayısı, ilk inisiyatif a mı)"""
    ini_a = r.random() < 0.5
    ilk = ini_a
    pot = 0
    tur = 0
    while a.el and b.el and tur < 40:
        tur += 1
        ini, diger = (a, b) if ini_a else (b, a)
        if kural == 'v3':
            ortak = [m for m in ini.mevkiler() if diger.uygun(m)] or ini.mevkiler()
            mevki = ini.mevki_sec(r)
            if mevki not in ortak:
                mevki = r.choice(ortak)
            ki, kd = ini.kart_sec(mevki, r), diger.kart_sec(mevki, r)
        else:
            ki = ini.kart_sec(ini.mevki_sec(r), r)
            kd = diger.kart_sec(ki[0].mevki, r, rakip_karti=ki)
        ti, td = ini.taktik_sec(r), diger.taktik_sec(r)
        ini.el.remove(ki)
        masa = 1
        if kd is None:
            kazanan = ini           # pas: turu kaybeder
            td = 'yok'
        else:
            diger.el.remove(kd)
            masa = 2
            if ki[0].tier == 'legend' and kd[0].tier != 'legend':
                kazanan = ini
            elif kd[0].tier == 'legend' and ki[0].tier != 'legend':
                kazanan = diger
            else:
                pi = ki[1] + taktik_bonus(ti, td, True)
                pd = kd[1] + taktik_bonus(td, ti, False)
                kazanan = ini if pi > pd else diger if pd > pi else None
        for t, tk in ((ini, ti), (diger, td)):
            t.enerji = min(5, t.enerji - MALIYET[tk] + 1)
        if kazanan is None:
            pot += masa
            ini_a = not ini_a
        else:
            kazanan.toplanan += masa + pot
            pot = 0
            ini_a = kazanan is a
        if kural == 'v3' and max(a.toplanan, b.toplanan) >= 12:
            break
    return (a.toplanan > b.toplanan) - (a.toplanan < b.toplanan), tur, ilk


def kadro_uret(r: random.Random, tierler=('bronze', 'silver', 'gold')) -> list:
    secim = []
    for mevki, adet in FORMASYON.items():
        havuz = [k for k in S.KATALOG if k.mevki == mevki and k.tier in tierler]
        secim += r.sample(havuz, adet)
    return secim


def olc(n, r, kural, ajan_a='akilli', ajan_b='akilli', sv_a=1, sv_b=1, tavan=None, ayni_kadro=False, guc_farki=0, etkin_eslesme=False):
    """a'nın puanı (galibiyet 1, beraberlik 0.5), ilk inisiyatifin puanı, ortalama tur"""
    puan = ilk_puan = 0.0
    turlar = []
    for _ in range(n):
        ka = kadro_uret(r)
        if etkin_eslesme:
            kb = guce_gore_rakip(ka, seviye_bonus(sv_a, tavan), r)
        else:
            kb = ka if ayni_kadro else S.benzer_rakip(ka, r)
        a = Taraf(ka, {k.slug: sv_a for k in ka}, ajan_a, tavan)
        b = Taraf(kb, {k.slug: sv_b for k in kb}, ajan_b, tavan)
        if guc_farki:
            a.el = [(k, g + guc_farki) for k, g in a.el]
        s, tur, ilk_a = mac(a, b, kural, r)
        p = 1 if s > 0 else 0.5 if s == 0 else 0
        puan += p
        ilk_puan += p if ilk_a else 1 - p
        turlar.append(tur)
    return puan / n, ilk_puan / n, statistics.mean(turlar), turlar


def yuzde(x):
    return f'%{x * 100:.1f}'


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
    r = random.Random(20261111)
    L = ['# Düello V3 simülasyonu', '',
         f'Üretildi: `python -I tool/ekonomi/duello_v3.py {n}` ({n} maç / hücre, tohum sabit). '
         'Kurallar ve ajanlar dosya başında. Puan: galibiyet 1, beraberlik 0,5.', '']

    # 1) İlk inisiyatif avantajı
    L += ['## 1. İlk açan / ilk inisiyatif avantajı (hedef %45–55)', '',
          '| Kural | Oyuncular | İlk inisiyatifin puanı | Ortalama tur |', '|---|---|---|---|']
    for kural in ('v2', 'v3'):
        for ajan in ('akilli', 'taktiksiz'):
            _, ilk, tur, _ = olc(n, r, kural, ajan, ajan)
            L.append(f'| {kural.upper()} | {ajan} | {yuzde(ilk)} | {tur:.1f} |')
            print(kural, ajan, 'ilk', yuzde(ilk), 'tur', round(tur, 1))

    # 2) Maç süresi
    _, _, _, t2 = olc(n, r, 'v2')
    _, _, _, t3 = olc(n, r, 'v3')
    t3s = sorted(t3)
    L += ['', '## 2. Maç süresi', '',
          '| Kural | Ortalama tur | En uzun %10 | Tur süresi sınırı | En uzun maç (sınır) | Tipik maç (sürenin %60\'ı kullanılırsa) |',
          '|---|---|---|---|---|---|',
          f'| V2 | {statistics.mean(t2):.1f} | {sorted(t2)[int(len(t2) * 0.9)]} | 2 × 45 sn | '
          f'{sorted(t2)[int(len(t2) * 0.9)] * 90 / 60:.1f} dk | {statistics.mean(t2) * 90 * 0.6 / 60:.1f} dk |',
          f'| V3 | {statistics.mean(t3):.1f} | {t3s[int(len(t3s) * 0.9)]} | 5 sn mevki + 15 sn seçim | '
          f'{t3s[int(len(t3s) * 0.9)] * 20 / 60:.1f} dk | {statistics.mean(t3) * 20 * 0.6 / 60:.1f} dk |',
          '', 'V3 tur dağılımı: ' + ', '.join(f'{k} tur %{100 * t3.count(k) / len(t3):.0f}' for k in sorted(set(t3)))]
    print('tur v2', round(statistics.mean(t2), 1), 'v3', round(statistics.mean(t3), 1))

    # 3) Strateji dengesi (V3)
    L += ['', '## 3. V3 strateji dengesi (benzer güçte kadrolar)', '',
          '| A | B | A\'nın puanı |', '|---|---|---|']
    for a, b in (('akilli', 'taktiksiz'), ('akilli', 'acgozlu'), ('akilli', 'rastgele'), ('acgozlu', 'taktiksiz'),
                 ('rastgele', 'taktiksiz')):
        p, _, _, _ = olc(n, r, 'v3', a, b)
        L.append(f'| {a} | {b} | {yuzde(p)} |')
        print('v3', a, 'vs', b, yuzde(p))

    # 4) Güç farkı duyarlılığı
    L += ['', '## 4. Güç farkı → kazanma (AYNI kadro, A\'nın bütün kartlarına +güç; ikisi de akıllı)', '',
          '| Fark | V2 | V3 |', '|---|---|---|']
    for f in (0, 1, 2, 3, 4, 5, 8):
        p2, _, _, _ = olc(n // 2, r, 'v2', ayni_kadro=True, guc_farki=f)
        p3, _, _, _ = olc(n // 2, r, 'v3', ayni_kadro=True, guc_farki=f)
        L.append(f'| +{f} | {yuzde(p2)} | {yuzde(p3)} |')
        print('fark', f, yuzde(p2), yuzde(p3))

    # 5) Seviye (B) ve lig tavanı
    L += ['', '## 5. Seviye gücü B (bonus = seviye // 2) ve lig tavanı (V3, AYNI kadro, rakip seviye 1)', '',
          '| A\'nın seviyesi | Bonus | Tavansız | Tavan 4 | Tavan 6 | Tavan 8 |', '|---|---|---|---|---|---|']
    for sv in (2, 4, 6, 8, 10):
        satir = [f'| {sv} | +{sv // 2}']
        for tavan in (None, 4, 6, 8):
            p, _, _, _ = olc(n // 2, r, 'v3', sv_a=sv, sv_b=1, tavan=tavan, ayni_kadro=True)
            satir.append(yuzde(p))
        L.append(' | '.join(satir) + ' |')
        print('seviye', sv, satir[1:])
    L += ['', 'Aynı ligde en kötü durum (ikisi de tavanda değil): tavan 4\'te seviye 4\'e karşı seviye 1 = yukarıdaki '
          '"Tavan 4" sütununun 4. satırı.']

    # 6) Eğri seçimi ve etkin güce göre eşleştirme
    global EGRI
    L += ['', '## 6. Seviye eğrisi × eşleştirme (V3; A seviyeli, rakip seviye 1)', '',
          '`Puana göre`: rakip aynı TEMEL güçte (bugünkü eşleştirme seviyeyi görmez). '
          '`Etkin güce göre`: rakibin kartları A oyuncusunun güç + seviye bonusuna denk.', '',
          '| Eğri | A seviyesi | Bonus | Puana göre | Etkin güce göre |', '|---|---|---|---|---|']
    for egri, ad in (('b1', 'B1: seviye // 2 (en fazla +5)'), ('b2', 'B2: L4 +1, L7 +2, L10 +3')):
        EGRI = egri
        for sv in (4, 7, 10):
            p1, _, _, _ = olc(n // 2, r, 'v3', sv_a=sv)
            p2, _, _, _ = olc(n // 2, r, 'v3', sv_a=sv, etkin_eslesme=True)
            L.append(f'| {ad} | {sv} | +{seviye_bonus(sv, None)} | {yuzde(p1)} | {yuzde(p2)} |')
            print(egri, sv, yuzde(p1), yuzde(p2))
    EGRI = 'b1'

    (KOK / 'duello_v3.md').write_text('\n'.join(L) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
