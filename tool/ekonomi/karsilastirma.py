"""EKONOMİ V2 KALİTE KONTROLÜ — karşılaştırmalı simülasyon (30 / 90 / 180 gün).

simulasyon.py'deki modeli (saat saat sandık kuyruğu, 4 yuva, tek kilit,
posta kutusu 8 / 7 gün, telafi altını, ödül enerjisi 10 / 96 dk, kart
kaybı ve koruma, Acil Kadro, seviye atlama, Battle Pass + görevler)
AYNEN kullanır; yalnız senaryo kurallarını değiştirir. Maç motoru
modellenmez: sonuç olasılıkları sabit (galibiyet %48, beraberlik %4).

Senaryolar
  S0  MEVCUT        : sandık yalnız enerjili maçta; yenilgide korumasız
                      3 kart kalıcı kaybı (kazanana geçer)
  S1  KAYIPSIZ      : S0 + dereceli maçta kalıcı kart kaybı YOK
  S2  HER MAÇA TAM  : S1 + her meşru maça sonuç tablosundan sandık
                      (enerji yalnız XP'yi etkiler)
  S3  ÖNERİ         : S1 + her meşru maça sandık; enerjili maçta sonuç
                      tablosu, enerjisiz maçta BRONZ (anında açılır,
                      kuyruğa girmez). Enerji = bonus (sandık kalitesi + XP)
  S4  ÖNERİ + GELİŞİM: S3 + galibiyette kadrodaki rastgele bir futbolcuya
                      +1 gelişim kopyası (fiziksel kart değil; kaybın
                      besleyip kaldırılınca kesilen ilerlemenin yerine)

Başlangıç: 15 FARKLI kart (gerçek başlangıç paketi kadroyu her zaman
kurar; simulasyon.py'nin tekrar eden kart verebilmesi model hatasıydı).

Oyuncu davranışı (gerçekçi değişkenlik)
  * günlük maç ~ N(ortalama, %35) ve %15 hiç oynamadığı gün
  * %3 maç 4. turdan önce biter (teslim / AFK): K6 -> sandık / XP yok

Kullanım:  python -I tool/ekonomi/karsilastirma.py [tekrar]
Çıktı:     tool/ekonomi/karsilastirma.json ve karsilastirma.md
"""
from __future__ import annotations

import json
import pathlib
import random
import statistics
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import simulasyon as S  # noqa: E402

KOK = pathlib.Path(__file__).resolve().parent
A = S.AYARLAR

SENARYOLAR = {
    'S0 Mevcut': {'kayip': True, 'sandik': 'enerjili'},
    'S1 Kayipsiz': {'kayip': False, 'sandik': 'enerjili'},
    'S2 Her maca tam sandik': {'kayip': False, 'sandik': 'hep_tam'},
    'S3 Oneri (enerjisiz=Bronz)': {'kayip': False, 'sandik': 'enerjisiz_bronz'},
    'S4 Oneri + galibiyette gelisim': {'kayip': False, 'sandik': 'enerjisiz_bronz', 'galibiyet_kopya': 1},
}

PROFILLER = [
    {'ad': 'Gunde 2 mac', 'mac': 2, 'premium': None},
    {'ad': 'Gunde 5 mac', 'mac': 5, 'premium': None},
    {'ad': 'Gunde 10 mac', 'mac': 10, 'premium': None},
    {'ad': 'Gunde 20 mac', 'mac': 20, 'premium': None},
    {'ad': 'Gunde 10 mac, premium', 'mac': 10, 'premium': 'premium'},
]
KISA_MAC = 0.03
BOS_GUN = 0.15
SAPMA = 0.35


class Oyuncu(S.Oyuncu):
    """Senaryo kurallarıyla maç sonu"""
    kural: dict = {}

    def __post_init__(self):
        # Gerçek başlangıç paketi gibi: kadroyu kuran FARKLI kartlar
        for mevki, adet in {'GK': 2, 'DEF': 5, 'MID': 5, 'FWD': 3}.items():
            havuz = [k for k in S.KATALOG if k.mevki == mevki and k.tier in ('bronze', 'silver', 'gold')]
            agirlik = [65 if k.tier == 'bronze' else 30 if k.tier == 'silver' else 5 for k in havuz]
            secilen = set()
            while len(secilen) < adet:
                secilen.add(self.r.choices(havuz, weights=agirlik)[0])
            for k in secilen:
                self.kart_ekle(k, sayac=False)

    def mac(self, gun: int):
        self.kilit_coz(gun)
        kadro = self.kadro()
        if kadro is None:
            return 'kilitli', False
        self.m['mac'] += 1
        x = self.r.random()
        sonuc = 'galibiyet' if x < 0.48 else 'beraberlik' if x < 0.52 else 'yenilgi'
        kisa = self.r.random() < KISA_MAC
        if sonuc == 'galibiyet' and not kisa and self.kural.get('galibiyet_kopya'):
            hedef = [k for k in kadro if self.seviye.get(k.slug, 1) < 10]
            if hedef:
                k = self.r.choice(hedef)
                self.ilerleme[k.slug] = self.ilerleme.get(k.slug, 0) + self.kural['galibiyet_kopya']
                self.m['galibiyet_kopyasi'] = self.m.get('galibiyet_kopyasi', 0) + 1
        if sonuc == 'galibiyet':
            self.m['galibiyet'] += 1
            self.altin += A['galibiyet_altin']
            self.m['altin_kazanc'] += A['galibiyet_altin']
            self.koruma = min(A['koruma_max'], self.koruma + 1)
            if self.kural['kayip']:
                for _ in range(A['kayip_kart']):
                    k = self.r.choice(kadro)
                    benzer = [c for c in S.KATALOG if c.mevki == k.mevki and abs(c.guc - k.guc) <= 6] or [k]
                    self.kart_ekle(self.r.choice(benzer))
        elif sonuc == 'yenilgi' and self.kural['kayip']:
            korunan = set(sorted(kadro, key=lambda k: k.guc, reverse=True)[:self.koruma])
            aday = [k for k in kadro if k not in korunan]
            for k in self.r.sample(aday, min(A['kayip_kart'], len(aday))):
                self.kopyalar[k.slug] -= 1
                self.m['kart_kaybi'] += 1
        if kisa:
            self.m['kisa_mac'] = self.m.get('kisa_mac', 0) + 1
            return sonuc, None          # K6: sandık yok, XP yok
        enerjili = self.enerji >= 1
        if enerjili:
            self.enerji -= 1
        mod = self.kural['sandik']
        if enerjili:
            self.sandik_kazan(sonuc, gun)
        elif mod == 'hep_tam':
            self.sandik_kazan(sonuc, gun)
        elif mod == 'enerjisiz_bronz':
            self.m['sandik_bronz_bonusuz'] = self.m.get('sandik_bronz_bonusuz', 0) + 1
            self.sandik_ver('bronz', gun)
        else:
            self.m['sandik_enerjisiz_kacan'] += 1
        return sonuc, enerjili


def kosu(profil: dict, kural: dict, seed: int, gunler=(30, 90, 180)) -> dict:
    r = random.Random(seed)
    Oyuncu.kural = kural
    o = Oyuncu(r, profil['premium'])
    bas, bit = A['gun_basi_aktif_saat']
    sezon_xp = sezon_mac = hafta_mac = 0
    kademe = 0
    sezonlar = []           # (bitiş kademesi, tamamlandığı gün ya da None)
    tamam_gunu = None
    ilk_l5 = ilk_l10 = None
    anlik = {}
    for gun in range(max(gunler)):
        if gun % 30 == 0 and gun > 0:
            sezonlar.append((kademe, tamam_gunu))
            sezon_xp = sezon_mac = 0
            kademe = 0
            tamam_gunu = None
        if gun % 7 == 0:
            hafta_mac = 0
        if r.random() < BOS_GUN:
            n = 0
        else:
            n = max(1, round(r.gauss(profil['mac'], profil['mac'] * SAPMA)))
        saatler = list(range(bas, bit))
        sayac = {s: 0 for s in range(24)}
        for i in range(n):
            sayac[r.choice(saatler)] += 1
        gunluk = []
        kilitli = False
        for saat in range(24):
            for _ in range(sayac[saat]):
                sonuc, enerjili = o.mac(gun)
                if sonuc == 'kilitli':
                    kilitli = True
                    continue
                if enerjili is None:        # kısa maç: XP yok, görev yok
                    continue
                gunluk.append((sonuc, enerjili))
            o.saat_gecti(bas <= saat < bit, gun)
        if kilitli:
            o.m['kilitli_gun'] += 1
        sezon_mac += len(gunluk)
        hafta_mac += len(gunluk)
        xp = S.bp_xp_hesapla(gunluk, profil['premium'], gun, sezon_mac, hafta_mac)
        if gun % 7 == 6:
            xp += int(A['haftalik_gorev_xp'] * min(1, hafta_mac / A['haftalik_gorev_mac']))
        if gun % 30 == 29:
            xp += int(A['sezon_gorev_xp'] * min(1, sezon_mac / A['sezon_gorev_mac']))
        sezon_xp += xp
        o.m['bp_xp'] += xp
        yeni = min(A['bp_kademe'], int(sezon_xp // A['bp_kademe_xp']))
        S.bp_odul_uygula(o, kademe, yeni)
        if yeni >= A['bp_kademe'] and tamam_gunu is None:
            tamam_gunu = gun % 30 + 1
        kademe = max(kademe, yeni)
        o.seviye_atla()
        o.paket_davranisi()
        o.seviye_atla()
        en = max((v for s, v in o.seviye.items() if o.sahip(s)), default=1)
        if ilk_l5 is None and en >= 5:
            ilk_l5 = gun + 1
        if ilk_l10 is None and en >= 10:
            ilk_l10 = gun + 1
        if gun + 1 in gunler:
            kadro = o.kadro() or []
            sv = [o.seviye.get(k.slug, 1) for k in kadro]
            mm = dict(o.m)
            anlik[gun + 1] = {
                'mac': mm['mac'],
                'sandik_toplam': sum(o.m['sandik'].values()),
                'sandik': dict(o.m['sandik']),
                'enerjisiz_kacan': mm['sandik_enerjisiz_kacan'],
                'enerjisiz_bronz': mm.get('sandik_bronz_bonusuz', 0),
                'telafi_adet': mm['telafi'],
                'telafi_altin': mm['telafi_altin'],
                'posta_giren': mm['posta_giren'],
                'altin_gelir_gun': mm['altin_kazanc'] / (gun + 1),
                'altin_son': o.altin,
                'farkli_kart': sum(1 for v in o.kopyalar.values() if v > 0),
                'kart_kaybi': mm['kart_kaybi'],
                'kadro_ort_seviye': statistics.mean(sv) if sv else 0,
                'kadro_gucu': statistics.mean(k.guc for k in kadro) if kadro else 0,
                'seviye_atlama': mm['seviye_atlama'],
                'seviye_hafta': round(mm['seviye_atlama'] / ((gun + 1) / 7), 2),
                'kilitli_gun': mm['kilitli_gun'],
                'acil_kadro': mm['acil_kadro'],
                'kilit_paketi': mm['kilit_paket'],
                'yuva_doluluk': mm['yuva_dolu_saat'] / max(1, mm['saat']),
                'ilk_l5_gun': ilk_l5,
                'ilk_l10_gun': ilk_l10,
                'kisa_mac': mm.get('kisa_mac', 0),
            }
    sezonlar.append((kademe, tamam_gunu))
    return {'anlik': anlik, 'sezonlar': sezonlar}


def ozetle(kosular, gun):
    ks = [k['anlik'][gun] for k in kosular]
    o = {}
    for a in ks[0]:
        v0 = ks[0][a]
        if isinstance(v0, dict):
            o[a] = {x: round(statistics.mean(k[a][x] for k in ks), 1) for x in v0}
        elif a.startswith('ilk_'):
            dolu = [k[a] for k in ks if k[a] is not None]
            o[a] = round(statistics.median(dolu), 1) if dolu else None
            o[a + '_oran'] = round(len(dolu) / len(ks), 2)
        else:
            o[a] = round(statistics.mean(k[a] for k in ks), 2)
    return o


def bp_ozet(kosular):
    """Bütün sezonlar: tamamlama oranı, ortalama / medyan / p10 kademe, medyan tamamlama günü"""
    sez = [s for k in kosular for s in k['sezonlar']]
    kad = sorted(s[0] for s in sez)
    gun = [s[1] for s in sez if s[1] is not None]
    return {
        'sezon': len(sez),
        'tamamlama': round(sum(1 for s in sez if s[0] >= 50) / len(sez), 3),
        'ort_kademe': round(statistics.mean(kad), 1),
        'medyan_kademe': statistics.median(kad),
        'p10_kademe': kad[len(kad) // 10],
        'medyan_tamam_gunu': statistics.median(gun) if gun else None,
    }


def main():
    tekrar = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    sonuc = {}
    for sad, kural in SENARYOLAR.items():
        sonuc[sad] = {}
        for p in PROFILLER:
            kosular = [kosu(p, kural, 7919 * i + p['mac']) for i in range(tekrar)]
            sonuc[sad][p['ad']] = {g: ozetle(kosular, g) for g in (30, 90, 180)}
            sonuc[sad][p['ad']]['bp'] = bp_ozet(kosular)
            g = sonuc[sad][p['ad']]
            print(f"{sad:<28} {p['ad']:<22} 180g: sandik {g[180]['sandik_toplam']:>6.0f} telafi {g[180]['telafi_adet']:>5.0f} "
                  f"({g[180]['telafi_altin']:>6.0f} a) altin/gun {g[180]['altin_gelir_gun']:>5.0f} kart {g[180]['farkli_kart']:>5.0f} "
                  f"kayip {g[180]['kart_kaybi']:>5.0f} kilitli {g[180]['kilitli_gun']:>4.1f} acil {g[180]['acil_kadro']:>4.1f} "
                  f"sv {g[180]['kadro_ort_seviye']:.2f} BP %{g['bp']['tamamlama'] * 100:.0f}")
    (KOK / 'karsilastirma.json').write_text(json.dumps(sonuc, ensure_ascii=False, indent=1), encoding='utf-8')
    md(sonuc, tekrar)


def md(s, tekrar):
    L = [f'# Ekonomi V2 kalite kontrolü — karşılaştırmalı simülasyon ({tekrar} tekrar / hücre)', '',
         'Üretildi: `python -I tool/ekonomi/karsilastirma.py`. Senaryolar ve varsayımlar dosya başında.', '']
    for gun in (30, 90, 180):
        L += [f'## {gun} gün', '',
              '| Senaryo | Profil | Maç | Sandık | Enerjisiz kaçan | Telafi (adet / altın) | Altın/gün | Farklı kart | '
              'Kart kaybı | Kadro sv | Seviye/hafta | Kilitli gün | Acil Kadro | İlk L5 günü |',
              '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|']
        for sad, pp in s.items():
            for pad, g in pp.items():
                x = g[gun]
                L.append(f"| {sad} | {pad} | {x['mac']:.0f} | {x['sandik_toplam']:.0f} | {x['enerjisiz_kacan']:.0f} | "
                         f"{x['telafi_adet']:.0f} / {x['telafi_altin']:.0f} | {x['altin_gelir_gun']:.0f} | {x['farkli_kart']:.0f} | "
                         f"{x['kart_kaybi']:.0f} | {x['kadro_ort_seviye']:.2f} | {x['seviye_hafta']:.1f} | {x['kilitli_gun']:.1f} | {x['acil_kadro']:.1f} | "
                         f"{x['ilk_l5_gun'] if x['ilk_l5_gun'] else '—'} (%{x['ilk_l5_gun_oran'] * 100:.0f}) |")
        L.append('')
    L += ['## Battle Pass (bütün 30 günlük sezonlar)', '',
          '| Senaryo | Profil | Sezon | Tamamlama | Ort. kademe | Medyan | En kötü %10 | Medyan tamamlama günü |',
          '|---|---|---|---|---|---|---|---|']
    for sad, pp in s.items():
        for pad, g in pp.items():
            b = g['bp']
            L.append(f"| {sad} | {pad} | {b['sezon']} | %{b['tamamlama'] * 100:.0f} | {b['ort_kademe']} | {b['medyan_kademe']} | "
                     f"{b['p10_kademe']} | {b['medyan_tamam_gunu'] or '—'} |")
    (KOK / 'karsilastirma.md').write_text('\n'.join(L) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
