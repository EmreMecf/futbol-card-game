"""V3 (eş zamanlı) taktik dengesi taraması. Ölçüt (prototip RAPOR.md ile aynı mantık):
  * döngü: kontra > pres, duvar > kontra, pres > duvar  (her biri > %52)
  * hiçbir saf strateji herkesi ezmesin: her birinin en kötü eşleşmesi <= %45
  * akıllı (karışık) oyuncu taktiksizi yener ama ezmez
Kullanım: python -I tool/ekonomi/denge_ara.py [maç]"""
import itertools, random, sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import duello_v3 as D

n = int(sys.argv[1]) if len(sys.argv) > 1 else 1200
SAF = ['hep_pres', 'hep_kontra', 'hep_duvar']
sonuc = []
for dm, dv, di, pm, kp, pb in itertools.product((1, 2), (4, 5, 6), (1, 2), (2, 3), (11, 13), (7, 9)):
    D.MALIYET.update(duvar=dm, pres=pm)
    D.P.update(duvar=dv, duvar_ini=di, kontra_pres=kp, pres=pb)
    r = random.Random(7)
    m = {(a, b): D.olc(n, r, 'v3', a, b)[0] for a in SAF + ['akilli'] for b in SAF + ['akilli', 'taktiksiz'] if a != b}
    dongu = min(m['hep_kontra', 'hep_pres'], m['hep_duvar', 'hep_kontra'], m['hep_pres', 'hep_duvar'])
    en_kotu = {a: min(m[a, b] for b in SAF + ['akilli'] if b != a) for a in SAF}
    ezen = max(en_kotu.values())
    sonuc.append((dongu, -ezen, dict(duvar_maliyet=dm, duvar=dv, duvar_ini=di, pres_maliyet=pm, kontra_pres=kp, pres=pb),
                  {k: round(v * 100) for k, v in en_kotu.items()}, round(m['akilli', 'taktiksiz'] * 100),
                  round(m['hep_pres', 'hep_duvar'] * 100), round(m['hep_duvar', 'hep_kontra'] * 100), round(m['hep_kontra', 'hep_pres'] * 100)))
gecen = [x for x in sonuc if x[0] > 0.52 and -x[1] <= 0.45]
print(len(gecen), 'aday /', len(sonuc))
for x in sorted(gecen or sonuc, key=lambda x: (x[0] > 0.52, x[1]), reverse=True)[:10]:
    print(f"dongu en zayif %{x[0]*100:.0f} | saf en kotu {x[3]} | akilli-taktiksiz %{x[4]} | pres>duvar %{x[5]} duvar>kontra %{x[6]} kontra>pres %{x[7]} | {x[2]}")
