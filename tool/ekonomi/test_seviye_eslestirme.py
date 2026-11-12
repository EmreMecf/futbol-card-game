"""FAZ 2 (seviye bonusu B2 + etkin güce göre eşleştirme + lig tavanı) — TASARIM TESTLERİ

Faz 2 henüz oyun koduna UYGULANMADI (düelloya dokunduğu için ayrı onay
bekliyor). Bu testler onaylanan sayıların (docs/OYUN_TASARIMI_V3.md §2)
simülatörde istenen sonucu verdiğini doğrular ve 040 migration'ı
yazıldığında aynı sayılar için kabul ölçütü olur:

  * B2 eğrisi: seviye 1-3 → +0, 4-6 → +1, 7-9 → +2, 10 → +3
  * lig tavanı: Amatör 4, Usta 7, Master ve üstü 10 (tavanın üstü sayılmaz)
  * bonus yalnız o kartın gücüne eklenir
  * eşleştirme ETKİN güce (güç + seviye bonusu) bakarsa seviyeli oyuncu
    %45–56 puan alır (adil); temel güce bakarsa seviye 10 ezer (> %75)

Kullanım: python -I tool/ekonomi/test_seviye_eslestirme.py -v
"""
import pathlib
import random
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import duello_v3 as D  # noqa: E402

LIG_TAVANI = {'amator': 4, 'usta': 7, 'master': 10}
MAC = 1200  # her ölçüm; standart hata ≈ %1,4


class B2Egrisi(unittest.TestCase):
    def setUp(self):
        self.eski = D.EGRI
        D.EGRI = 'b2'

    def tearDown(self):
        D.EGRI = self.eski

    def test_seviye_tablosu(self):
        beklenen = {1: 0, 2: 0, 3: 0, 4: 1, 5: 1, 6: 1, 7: 2, 8: 2, 9: 2, 10: 3}
        for sv, bonus in beklenen.items():
            self.assertEqual(D.seviye_bonus(sv, None), bonus, f'seviye {sv}')

    def test_lig_tavani(self):
        # seviye 10 kart, ligin tavanına göre
        self.assertEqual(D.seviye_bonus(10, LIG_TAVANI['amator']), 1)
        self.assertEqual(D.seviye_bonus(10, LIG_TAVANI['usta']), 2)
        self.assertEqual(D.seviye_bonus(10, LIG_TAVANI['master']), 3)
        # tavanın altındaki seviye aynen sayılır
        self.assertEqual(D.seviye_bonus(3, LIG_TAVANI['amator']), 0)
        self.assertEqual(D.seviye_bonus(6, LIG_TAVANI['usta']), 1)

    def test_bonus_yalniz_o_karta(self):
        r = random.Random(1)
        kadro = D.kadro_uret(r)
        seviyeli = kadro[0].slug
        t = D.Taraf(kadro, {seviyeli: 10}, 'akilli', None)
        t0 = D.Taraf(kadro, {}, 'akilli', None)
        farklar = {k.slug: g - g0 for (k, g), (_, g0) in zip(t.el, t0.el)}
        self.assertEqual(farklar[seviyeli], 3)
        self.assertTrue(all(v == 0 for s, v in farklar.items() if s != seviyeli))


class EtkinGuceGoreEslestirme(unittest.TestCase):
    """Seviyeli A, seviye 1 rakibe karşı (V3 kuralı, iki taraf da akıllı)."""

    def setUp(self):
        self.eski = D.EGRI
        D.EGRI = 'b2'

    def tearDown(self):
        D.EGRI = self.eski

    def test_etkin_guc_adil(self):
        for sv in (4, 7, 10):
            p, _, _, _ = D.olc(MAC, random.Random(100 + sv), 'v3', sv_a=sv, etkin_eslesme=True)
            self.assertGreaterEqual(p, 0.45, f'seviye {sv}: %{p * 100:.1f}')
            self.assertLessEqual(p, 0.56, f'seviye {sv}: %{p * 100:.1f}')

    def test_temel_guce_gore_eslesme_ezer(self):
        # Eşleştirme seviyeyi GÖRMEZSE seviye 10 ezer: etkin güç neden şart
        p, _, _, _ = D.olc(MAC, random.Random(7), 'v3', sv_a=10)
        self.assertGreater(p, 0.75, f'%{p * 100:.1f}')

    def test_ayni_ligde_tavan_farki_siner(self):
        # Amatör ligde (tavan 4) seviye 10'un seviye 4'e üstünlüğü yoktur
        r1, r2 = random.Random(3), random.Random(3)
        p10, _, _, _ = D.olc(MAC, r1, 'v3', sv_a=10, sv_b=4, tavan=LIG_TAVANI['amator'], ayni_kadro=True)
        p4, _, _, _ = D.olc(MAC, r2, 'v3', sv_a=4, sv_b=4, tavan=LIG_TAVANI['amator'], ayni_kadro=True)
        self.assertAlmostEqual(p10, p4, delta=0.001)
        self.assertGreaterEqual(p10, 0.45)
        self.assertLessEqual(p10, 0.55)


if __name__ == '__main__':
    unittest.main()
