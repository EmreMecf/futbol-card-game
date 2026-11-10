"""Battle Pass incelemesi: 50 kademenin değer dağılımı (035 season_rules v1)
ve 30 günlük tamamlama oranları (1000 / 900 XP kademe varyantı).

Değer modeli (yalnız karşılaştırma için, altın eşdeğeri): sandık = sunucudaki
güvenli telafi altını (Gümüş 70, Altın 180, Efsane 450); joker parça Altın 40,
Elmas 100; enerji içeceği 20, hızlandırıcı 30, Altın ustalık kitabı 80;
kozmetik 0 (ekonomik değil).

Kullanım: python -I tool/ekonomi/bp_inceleme.py [tekrar]
"""
from __future__ import annotations

import json
import pathlib
import re
import statistics
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import karsilastirma as K  # noqa: E402

KOK = pathlib.Path(__file__).resolve().parents[2]
DEGER_SANDIK = {'silver': 70, 'gold': 180, 'legend': 450}
DEGER_ITEM = {'joker_gold': 40, 'joker_diamond': 100, 'energy_drink': 20, 'chest_speedup_2h': 30,
              'mastery_book_gold': 80}


def kademeler():
    s = (KOK / 'database/migrations/035_season_pass.sql').read_text(encoding='utf-8')
    j = s[s.index('$json${') + 6:s.index('}$json$') + 1]
    return json.loads(j)['tiers']


def deger(r):
    if r['type'] == 'coins':
        return r['amount']
    if r['type'] == 'chest':
        return DEGER_SANDIK[r['chest_type']]
    return DEGER_ITEM.get(r['slug'], 0) * r.get('qty', 1)


def main():
    tekrar = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    t = kademeler()
    print('== Deger dagilimi (altin esdegeri), 10 kademelik bloklar')
    for yol in ('free', 'premium'):
        bloklar = [sum(deger(k[yol]) for k in t[b:b + 10]) for b in range(0, 50, 10)]
        toplam = sum(bloklar)
        print(f"{yol:<8} toplam {toplam:>6}  " + '  '.join(f"{b + 1:>2}-{b + 10:<2}: %{100 * x / toplam:>4.1f}"
                                                         for b, x in zip(range(0, 50, 10), bloklar)))
        for son in (20, 27, 30, 40):
            print(f"   kademe {son:>2}'e kadar: %{100 * sum(deger(k[yol]) for k in t[:son]) / toplam:.0f}")

    print('\n== 30 gunluk tamamlama (S4 kurallari, gercekci degiskenlik)')
    sonuc = {}
    for xp in (1000, 900):
        K.A['bp_kademe_xp'] = xp
        for gunluk in (2, 3, 5, 10):
            p = {'ad': f'{gunluk}/gun', 'mac': gunluk, 'premium': None}
            kosular = [K.kosu(p, K.SENARYOLAR['S4 Oneri + galibiyette gelisim'], 104729 * i + gunluk, gunler=(30, 90))
                       for i in range(tekrar)]
            b = K.bp_ozet(kosular)
            sonuc[f'{xp}xp {gunluk}/gun'] = b
            print(f"kademe {xp} XP  gunde {gunluk:>2} mac: tamamlama %{b['tamamlama'] * 100:>3.0f}  ort {b['ort_kademe']:>4}  "
                  f"medyan {b['medyan_kademe']:>4}  en kotu %10 {b['p10_kademe']:>3}  medyan tamamlama gunu {b['medyan_tamam_gunu']}")
    K.A['bp_kademe_xp'] = 1000
    (pathlib.Path(__file__).resolve().parent / 'bp_inceleme.json').write_text(
        json.dumps(sonuc, ensure_ascii=False, indent=1), encoding='utf-8')


if __name__ == '__main__':
    main()
