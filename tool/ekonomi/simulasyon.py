"""GAME ECONOMY V2 — ekonomi denge simülatörü.

Tasarım belgesi: docs/EKONOMI_V2_TASARIM.md (sayılar oradaki tablolarla AYNI;
biri değişirse diğeri de değişmeli — `AYARLAR` sözlüğü tek kaynak).

Ne simüle edilir?
  * 4 oyuncu profili x 30 / 90 / 180 gün, her profil için N tekrar (seed sabit)
  * Saat saat zaman: sandık yuvaları (4), tek kilit açma kuyruğu, posta
    kutusu (8), taşma -> güvenli telafi (altın)
  * Ödül enerjisi (maç içi taktik enerjisinden AYRI): enerjisiz maç da
    oynanır, yalnız sandık çıkmaz ve sezon XP'si azalır
  * Mevcut maç sonu kuralları DEĞİŞMEDEN: galibiyet +100 altın, +1 koruma
    hakkı (en fazla 10); yenilgide korumasız 3 rastgele el kartı kaybı
  * Sandık içeriği: 3 futbolcu; sahip olunmayan -> yeni kart, sahip
    olunan -> 1 kopya (seviye ilerlemesi). Seviye 10'daki kartın kopyası
    -> "fazla kopya" -> joker parça
  * Seviye atlama: aktif kadro önce, altın yettikçe
  * Battle Pass: 50 kademe x 1000 XP, günlük / haftalık / sezon görevleri

Ayrıca: SEVİYE NORMALİZASYONU. Gerçek düello kurallarıyla (aynı mevki,
güç + kimya, Efsane kuralı, pas = turu kaybetmek) Monte Carlo maç
oynatılır; 180 günlük oyuncunun kadrosu yeni oyuncuya karşı 4 yöntemle
karşılaştırılır.

Kullanım:  python -I tool/ekonomi/simulasyon.py [tekrar]
Çıktı:     tool/ekonomi/sonuclar.json ve sonuclar.md
"""
from __future__ import annotations

import csv
import json
import math
import pathlib
import random
import statistics
import sys
from dataclasses import dataclass, field

KOK = pathlib.Path(__file__).resolve().parent
TIERS = ['bronze', 'silver', 'gold', 'diamond', 'legend']

# =====================================================================
# AYARLAR (tasarım belgesindeki tablolar)
# =====================================================================
AYARLAR = {
    # ---- Sandık türü olasılığı (maç sonucu) ----
    'sandik_turu': {
        'galibiyet': {'bronz': 52, 'gumus': 35, 'altin': 11, 'efsane': 2},
        'beraberlik': {'bronz': 70, 'gumus': 26, 'altin': 4, 'efsane': 0},
        'yenilgi': {'bronz': 80, 'gumus': 18, 'altin': 2, 'efsane': 0},
    },
    # Şanssızlık koruması: X sandıktır bu türden (veya üstünden) çıkmadıysa garanti
    'sandik_garanti': {'altin': 15, 'efsane': 60},
    'kilit_suresi_saat': {'bronz': 0, 'gumus': 2, 'altin': 6, 'efsane': 12},
    # ---- Sandık içi nadirlik (3 yuva; son yuva "garanti yuvası") ----
    'sandik_icerik': {
        'bronz': [{'bronze': 72, 'silver': 24, 'gold': 4}] * 3,
        'gumus': [{'bronze': 50, 'silver': 38, 'gold': 11, 'diamond': 1}] * 2
        + [{'silver': 70, 'gold': 26, 'diamond': 3.6, 'legend': 0.4}],
        'altin': [{'bronze': 25, 'silver': 42, 'gold': 28, 'diamond': 4.5, 'legend': 0.5}] * 2
        + [{'gold': 82, 'diamond': 16, 'legend': 2}],
        'efsane': [{'silver': 30, 'gold': 52, 'diamond': 16, 'legend': 2}] * 2
        + [{'diamond': 85, 'legend': 15}],
    },
    # Sandıktaki joker parçalar (nadirliğe özel; o nadirlikteki HERHANGİ bir
    # futbolcuya 1 kopya yerine geçer)
    'sandik_joker': {'bronz': {'bronze': 1}, 'gumus': {'bronze': 2, 'silver': 1},
                     'altin': {'silver': 2, 'gold': 1}, 'efsane': {'gold': 2, 'diamond': 1}},
    'sandik_altin': {'bronz': (10, 20), 'gumus': (30, 50), 'altin': (80, 120), 'efsane': (200, 300)},
    'yuva_sayisi': 4,
    'posta_kapasite': 8,
    'posta_omur_gun': 7,
    'telafi_altin': {'bronz': 25, 'gumus': 70, 'altin': 180, 'efsane': 450},
    # ---- Ödül enerjisi ----
    'enerji_max': 10,
    'enerji_dolum_dk': 96,  # 15 / gün (günde 15 maça kadar tam ödül)
    # ---- Seviye (L -> L+1 için kopya, altın); index 0 = 1->2 ----
    'seviye_kopya': {
        'bronze': [1, 2, 3, 5, 8, 12, 16, 22, 30],
        'silver': [1, 2, 3, 4, 6, 9, 13, 18, 24],
        'gold': [1, 1, 2, 3, 5, 7, 10, 14, 18],
        'diamond': [1, 1, 1, 2, 3, 4, 6, 8, 11],
        'legend': [1, 1, 1, 1, 2, 3, 4, 5, 7],
    },
    'seviye_altin': {
        'bronze': [20, 50, 100, 200, 400, 700, 1000, 1500, 2500],
        'silver': [30, 75, 150, 300, 600, 1000, 1500, 2200, 3500],
        'gold': [50, 125, 250, 500, 900, 1500, 2200, 3200, 5000],
        'diamond': [100, 250, 500, 900, 1500, 2400, 3600, 5000, 7500],
        'legend': [200, 500, 900, 1500, 2500, 4000, 6000, 8500, 12000],
    },
    # Seviye 10'u geçen fazla kopya -> joker parça (nadirliğe göre)
    'fazla_kopya_joker': {'bronze': 1, 'silver': 2, 'gold': 4, 'diamond': 10, 'legend': 25},
    # ---- Mevcut kurallar (DEĞİŞMEZ) ----
    'galibiyet_altin': 100,
    'koruma_baslangic': 3,
    'koruma_max': 10,
    'kayip_kart': 3,
    # ---- Battle Pass ----
    'bp_kademe': 50,
    'bp_kademe_xp': 1000,
    'xp_mac': {'galibiyet': 100, 'beraberlik': 70, 'yenilgi': 60},
    'xp_enerjisiz_carpan': 0.25,
    'gunluk_gorev': [(1, 150), (2, 200), (3, 250)],  # (gereken maç, XP)
    'haftalik_gorev_xp': 6000, 'haftalik_gorev_mac': 28,
    'sezon_gorev_xp': 10000, 'sezon_gorev_mac': 120,
    'premium_plus_kademe': 5,
    'premium_xp_carpan': 1.0,      # premium XP HIZLANDIRMAZ (adil kalsın)
    'premium_plus_xp_carpan': 1.10,
    # BP ödül toplamları (50 kademe)
    'bp_ucretsiz': {'altin': 3000, 'sandik_gumus': 6, 'sandik_altin': 4, 'sandik_efsane': 1, 'joker': {'gold': 10}},
    'bp_premium': {'altin': 4500, 'sandik_altin': 6, 'sandik_efsane': 3, 'joker': {'gold': 20, 'diamond': 6}},
    'gun_basi_aktif_saat': (8, 24),
    # ---- Kadro kilidi koruması (V2 önerisi) ----
    # Sandık yuvası, koleksiyonda formasyon ihtiyacı + 1 yedeğin altında
    # kalan mevkiden çekilir (sunucu tarafında, oyuncu seçemez)
    'eksik_mevki_onceligi': True,
    # Kadro kurulamıyor ve altın < standart paket: ücretsiz "acil kadro"
    # (eksik mevkiler için Bronz kart), en fazla 24 saatte bir
    'acil_kadro': True,
    'standart_paket_fiyat': 500,
    # Oyuncu davranışı: bu kadar altını aşınca standart paket alır
    # (mevcut paket sistemi; paket kartı FİZİKSEL kopyadır) ve 2'den
    # fazla fiziksel kopyayı gönüllü olarak seviye kopyasına çevirir
    'paket_al_esik': 3000,
    'tut_kopya': 2,
    # 'parca'   : sahip olunan karttan gelen kopya yalnız seviye ilerlemesi
    #             (fiziksel kopya artmaz)  <- istenen V2 yaklaşımı
    # 'fiziksel': kopya fiziksel kart olarak eklenir; seviye atlarken
    #             fazla fiziksel kopyalar yakılır (en az 1 kalır)
    'kopya_modeli': 'parca',
}

PROFILLER = [
    {'ad': 'Gunde 2 mac, ucretsiz', 'mac': 2, 'premium': None},
    {'ad': 'Gunde 5 mac, ucretsiz', 'mac': 5, 'premium': None},
    # Kontrol: aynı oyun süresi, ücretsiz -> "paranın etkisi" = premium - bu
    {'ad': 'Gunde 10 mac, ucretsiz (kontrol)', 'mac': 10, 'premium': None},
    {'ad': 'Gunde 10 mac, premium', 'mac': 10, 'premium': 'premium'},
    {'ad': 'Gunde 20 mac, premium plus', 'mac': 20, 'premium': 'plus'},
]

FORMASYON = {'GK': 1, 'DEF': 4, 'MID': 4, 'FWD': 2}


# =====================================================================
# KATALOG
# =====================================================================
@dataclass(frozen=True)
class Kart:
    slug: str
    mevki: str
    tier: str
    guc: int
    kulup: str
    uyruk: str
    lig: str


def katalog_oku() -> list[Kart]:
    with open(KOK / 'katalog.csv', encoding='utf-8') as f:
        return [Kart(r['slug'], r['position'], r['tier'], int(r['power']), r['club'], r['nationality'], r['league'])
                for r in csv.DictReader(f)]


KATALOG = katalog_oku()
TIER_KARTLARI = {t: [k for k in KATALOG if k.tier == t] for t in TIERS}


def agirlikli(r: random.Random, tablo: dict) -> str:
    toplam = sum(tablo.values())
    x = r.random() * toplam
    for k, v in tablo.items():
        x -= v
        if x <= 0:
            return k
    return list(tablo)[-1]


# =====================================================================
# OYUNCU
# =====================================================================
@dataclass
class Oyuncu:
    r: random.Random
    premium: str | None
    kopyalar: dict = field(default_factory=dict)     # slug -> sahip olunan fiziksel kopya sayısı
    seviye: dict = field(default_factory=dict)       # slug -> seviye (kişiye bağlı, kayıpta kalır)
    ilerleme: dict = field(default_factory=dict)     # slug -> biriken kopya (seviye için)
    altin: int = 1000
    koruma: int = AYARLAR['koruma_baslangic']
    enerji: float = AYARLAR['enerji_max']
    yuvalar: list = field(default_factory=list)      # [tur, kalan_saat or None]
    posta: list = field(default_factory=list)        # [tur, gun]
    kilit_acan: int | None = None
    sandik_sayac: dict = field(default_factory=lambda: {'altin': 0, 'efsane': 0})
    # ölçümler
    m: dict = field(default_factory=lambda: {
        'mac': 0, 'galibiyet': 0, 'sandik': {'bronz': 0, 'gumus': 0, 'altin': 0, 'efsane': 0},
        'sandik_enerjisiz_kacan': 0, 'posta_giren': 0, 'telafi': 0, 'telafi_altin': 0,
        'yuva_dolu_saat': 0, 'saat': 0, 'yeni_kart': 0, 'kopya': 0, 'fazla_kopya': 0, 'joker': 0,
        'altin_kazanc': 0, 'altin_harcama': 0, 'seviye_atlama': 0, 'kart_kaybi': 0, 'kart_kazanc': 0,
        'kilitli_gun': 0, 'bp_xp': 0, 'kilit_paket': 0, 'acil_kadro': 0, 'kilit_onleme_karti': 0,
        'joker_bosa': 0, 'paket': 0, 'donusturulen_kopya': 0,
    })
    son_acil: int = -1

    def __post_init__(self):
        # Başlangıç paketi (mevcut kural): 15 kart, Elmas/Efsane yok, formasyonu kuracak dağılım
        for mevki, adet in {'GK': 2, 'DEF': 5, 'MID': 5, 'FWD': 3}.items():
            havuz = [k for k in KATALOG if k.mevki == mevki and k.tier in ('bronze', 'silver', 'gold')]
            for _ in range(adet):
                k = self.r.choices(havuz, weights=[65 if k.tier == 'bronze' else 30 if k.tier == 'silver' else 5 for k in havuz])[0]
                self.kart_ekle(k, sayac=False)

    # ---------------- kartlar ----------------
    def sahip(self, slug) -> bool:
        return self.kopyalar.get(slug, 0) > 0

    def kart_ekle(self, k: Kart, sayac=True):
        self.kopyalar[k.slug] = self.kopyalar.get(k.slug, 0) + 1
        self.seviye.setdefault(k.slug, 1)
        if sayac:
            self.m['kart_kazanc'] += 1

    def sandik_karti(self, k: Kart):
        """Sandıktan gelen kart: yoksa yeni kopya, varsa seviye kopyası"""
        if not self.sahip(k.slug):
            self.kart_ekle(k, sayac=False)
            self.m['yeni_kart'] += 1
            return
        if AYARLAR['kopya_modeli'] == 'fiziksel':
            self.kopyalar[k.slug] += 1
        if self.seviye.get(k.slug, 1) >= 10:
            self.m['fazla_kopya'] += 1
            self.m['joker'] += AYARLAR['fazla_kopya_joker'][k.tier]
            return
        self.ilerleme[k.slug] = self.ilerleme.get(k.slug, 0) + 1
        self.m['kopya'] += 1

    def eksik_mevkiler(self) -> set:
        """Formasyon ihtiyacı + 1 yedeğin altında kalan mevkiler"""
        say = {m: 0 for m in FORMASYON}
        for k in KATALOG:
            if self.kopyalar.get(k.slug, 0) > 0:
                say[k.mevki] += 1
        return {m for m, n in FORMASYON.items() if say[m] < n + 1}

    def kilit_coz(self, gun: int):
        """Kadro kurulamıyorsa: altın yetiyorsa standart paket, yoksa acil kadro"""
        if self.kadro() is not None:
            return
        if self.altin >= AYARLAR['standart_paket_fiyat']:
            self.altin -= AYARLAR['standart_paket_fiyat']
            self.m['altin_harcama'] += AYARLAR['standart_paket_fiyat']
            self.m['kilit_paket'] += 1
            for _ in range(5):
                eksik = self.eksik_mevkiler()
                havuz = [k for k in KATALOG if (not eksik or k.mevki in eksik) and k.tier in ('bronze', 'silver', 'gold')]
                self.kart_ekle(self.r.choice(havuz), sayac=False)
        elif AYARLAR['acil_kadro'] and self.son_acil != gun:
            self.son_acil = gun
            self.m['acil_kadro'] += 1
            for mevki in self.eksik_mevkiler():
                havuz = [k for k in KATALOG if k.mevki == mevki and k.tier == 'bronze']
                self.kart_ekle(self.r.choice(havuz), sayac=False)

    def kadro(self) -> list[Kart] | None:
        """1-4-4-2: her mevkide (güç + seviye) en iyiler; kurulamıyorsa None"""
        secim = []
        for mevki, adet in FORMASYON.items():
            havuz = sorted((k for k in KATALOG if k.mevki == mevki and self.sahip(k.slug)),
                           key=lambda k: (k.guc, self.seviye.get(k.slug, 1)), reverse=True)
            if len(havuz) < adet:
                return None
            secim += havuz[:adet]
        return secim

    def seviye_atla(self):
        kadro = self.kadro() or []
        oncelik = [k.slug for k in kadro]
        digerleri = sorted((s for s in self.ilerleme if s not in oncelik),
                           key=lambda s: self.ilerleme[s], reverse=True)
        tier_of = {k.slug: k.tier for k in KATALOG}
        for slug in oncelik + digerleri:
            while True:
                sv = self.seviye.get(slug, 1)
                if sv >= 10:
                    break
                t = tier_of[slug]
                gk, ga = AYARLAR['seviye_kopya'][t][sv - 1], AYARLAR['seviye_altin'][t][sv - 1]
                # kadro dışı kartlar için altının yarısını sakla (oyuncu davranışı)
                rezerv = 0 if slug in oncelik else 1500
                if self.ilerleme.get(slug, 0) >= gk and self.altin - ga >= rezerv and (
                        AYARLAR['kopya_modeli'] == 'parca' or self.kopyalar.get(slug, 0) - gk >= 1):
                    self.ilerleme[slug] -= gk
                    if AYARLAR['kopya_modeli'] == 'fiziksel':
                        self.kopyalar[slug] -= gk  # yakılan fazla kopyalar
                    self.altin -= ga
                    self.m['altin_harcama'] += ga
                    self.seviye[slug] = sv + 1
                    self.m['seviye_atlama'] += 1
                else:
                    break

    # ---------------- sandık ----------------
    def sandik_kazan(self, sonuc: str, gun: int):
        tur = agirlikli(self.r, AYARLAR['sandik_turu'][sonuc])
        # şanssızlık koruması
        for g in ('efsane', 'altin'):
            self.sandik_sayac[g] += 1
        if self.sandik_sayac['efsane'] >= AYARLAR['sandik_garanti']['efsane']:
            tur = 'efsane'
        elif self.sandik_sayac['altin'] >= AYARLAR['sandik_garanti']['altin'] and tur in ('bronz', 'gumus'):
            tur = 'altin'
        if tur == 'efsane':
            self.sandik_sayac = {'altin': 0, 'efsane': 0}
        elif tur == 'altin':
            self.sandik_sayac['altin'] = 0
        self.sandik_ver(tur, gun)

    def sandik_ver(self, tur: str, gun: int):
        if tur == 'bronz':
            self.sandik_ac(tur)  # anında
            return
        if len(self.yuvalar) < AYARLAR['yuva_sayisi']:
            self.yuvalar.append([tur, None])
        elif len(self.posta) < AYARLAR['posta_kapasite']:
            self.posta.append([tur, gun])
            self.m['posta_giren'] += 1
        else:
            self.telafi(tur)

    def telafi(self, tur):
        a = AYARLAR['telafi_altin'][tur]
        self.altin += a
        self.m['telafi'] += 1
        self.m['telafi_altin'] += a
        self.m['altin_kazanc'] += a

    def joker_harca(self, tier: str, adet: int):
        """Joker parçayı aktif kadrodaki o nadirlikten en düşük seviyeli karta"""
        self.m['joker'] += adet
        for _ in range(adet):
            kadro = self.kadro() or []
            hedef = [c for c in kadro if c.tier == tier and self.seviye.get(c.slug, 1) < 10]
            if not hedef:
                self.m['joker_bosa'] += 1
                continue
            c = min(hedef, key=lambda c: self.seviye.get(c.slug, 1))
            self.ilerleme[c.slug] = self.ilerleme.get(c.slug, 0) + 1

    def paket_davranisi(self):
        """Altın birikince standart paket (mevcut sistem) + fazla kopya dönüşümü"""
        while self.altin >= AYARLAR['paket_al_esik']:
            self.altin -= AYARLAR['standart_paket_fiyat']
            self.m['altin_harcama'] += AYARLAR['standart_paket_fiyat']
            self.m['paket'] += 1
            for _ in range(5):
                t = agirlikli(self.r, {'bronze': 5500, 'silver': 3000, 'gold': 1300, 'diamond': 190, 'legend': 10})
                self.kart_ekle(self.r.choice(TIER_KARTLARI[t]), sayac=False)
        for slug, n in list(self.kopyalar.items()):
            fazla = n - AYARLAR['tut_kopya']
            if fazla > 0 and self.seviye.get(slug, 1) < 10:
                self.kopyalar[slug] -= fazla
                self.ilerleme[slug] = self.ilerleme.get(slug, 0) + fazla
                self.m['donusturulen_kopya'] += fazla

    def sandik_ac(self, tur: str):
        self.m['sandik'][tur] += 1
        for t, adet in AYARLAR['sandik_joker'][tur].items():
            self.joker_harca(t, adet)
        for yuva in AYARLAR['sandik_icerik'][tur]:
            t = agirlikli(self.r, yuva)
            havuz = TIER_KARTLARI[t]
            eksik = self.eksik_mevkiler()
            if AYARLAR['eksik_mevki_onceligi'] and eksik:
                havuz = [k for k in havuz if k.mevki in eksik] or havuz
            k = self.r.choice(havuz)
            if eksik and k.mevki in eksik and self.sahip(k.slug) and AYARLAR['kopya_modeli'] == 'parca':
                # eksik mevkide: kopya fiziksel kart olarak verilir (kilit önleme)
                self.kopyalar[k.slug] += 1
                self.m['kilit_onleme_karti'] += 1
                continue
            self.sandik_karti(k)
        lo, hi = AYARLAR['sandik_altin'][tur]
        a = self.r.randint(lo, hi)
        self.altin += a
        self.m['altin_kazanc'] += a

    def saat_gecti(self, cevrimici: bool, gun: int):
        self.m['saat'] += 1
        if len(self.yuvalar) >= AYARLAR['yuva_sayisi']:
            self.m['yuva_dolu_saat'] += 1
        self.enerji = min(AYARLAR['enerji_max'], self.enerji + 60 / AYARLAR['enerji_dolum_dk'])
        # kilit açma (tek sıra)
        for y in self.yuvalar:
            if y[1] is not None and y[1] > 0:
                y[1] -= 1
        if cevrimici:
            # hazır olanları aç
            for y in [y for y in self.yuvalar if y[1] is not None and y[1] <= 0]:
                self.yuvalar.remove(y)
                self.sandik_ac(y[0])
            # posta kutusundan boşalan yuvaya taşı
            while self.posta and len(self.yuvalar) < AYARLAR['yuva_sayisi']:
                self.yuvalar.append([self.posta.pop(0)[0], None])
            # açılmayan yoksa en kısa süreliyi başlat
            if not any(y[1] is not None for y in self.yuvalar) and self.yuvalar:
                y = min(self.yuvalar, key=lambda y: AYARLAR['kilit_suresi_saat'][y[0]])
                y[1] = AYARLAR['kilit_suresi_saat'][y[0]]
        # posta ömrü dolanlar -> telafi
        for p in [p for p in self.posta if gun - p[1] >= AYARLAR['posta_omur_gun']]:
            self.posta.remove(p)
            self.telafi(p[0])

    # ---------------- maç ----------------
    def mac(self, gun: int) -> tuple[str, bool]:
        self.kilit_coz(gun)
        kadro = self.kadro()
        if kadro is None:
            return 'kilitli', False
        self.m['mac'] += 1
        x = self.r.random()
        sonuc = 'galibiyet' if x < 0.48 else 'beraberlik' if x < 0.52 else 'yenilgi'
        if sonuc == 'galibiyet':
            self.m['galibiyet'] += 1
            self.altin += AYARLAR['galibiyet_altin']
            self.m['altin_kazanc'] += AYARLAR['galibiyet_altin']
            self.koruma = min(AYARLAR['koruma_max'], self.koruma + 1)
            # kaybedenin 3 kartı kazanana geçer: rakibin kadrosuna benzer güçte rastgele kartlar
            for _ in range(AYARLAR['kayip_kart']):
                k = self.r.choice(kadro)
                benzer = [c for c in KATALOG if c.mevki == k.mevki and abs(c.guc - k.guc) <= 6] or [k]
                self.kart_ekle(self.r.choice(benzer))
        elif sonuc == 'yenilgi':
            korunan = set(sorted(kadro, key=lambda k: k.guc, reverse=True)[:self.koruma])
            aday = [k for k in kadro if k not in korunan]
            for k in self.r.sample(aday, min(AYARLAR['kayip_kart'], len(aday))):
                self.kopyalar[k.slug] -= 1   # seviye kişide kalır
                self.m['kart_kaybi'] += 1
        enerjili = self.enerji >= 1
        if enerjili:
            self.enerji -= 1
            self.sandik_kazan(sonuc, gun)
        else:
            self.m['sandik_enerjisiz_kacan'] += 1
        return sonuc, enerjili


# =====================================================================
# BATTLE PASS
# =====================================================================
def bp_xp_hesapla(gunluk_maclar: list[tuple[str, bool]], premium: str | None, gun_no: int, sezon_mac: int,
                  hafta_mac: int) -> int:
    xp = 0
    for sonuc, enerjili in gunluk_maclar:
        x = AYARLAR['xp_mac'][sonuc]
        xp += x if enerjili else x * AYARLAR['xp_enerjisiz_carpan']
    n = len(gunluk_maclar)
    xp += sum(x for gerek, x in AYARLAR['gunluk_gorev'] if n >= gerek)
    carpan = AYARLAR['premium_plus_xp_carpan'] if premium == 'plus' else 1.0
    return int(xp * carpan)


def bp_odul_uygula(o: Oyuncu, kademe_once: int, kademe_sonra: int):
    """Kademe ödüllerini doğrusal dağıt (50 kademe toplamı tasarım tablosunda)"""
    def pay(toplam, d):
        return toplam * d / AYARLAR['bp_kademe']
    d = kademe_sonra - kademe_once
    if d <= 0:
        return
    yollar = [AYARLAR['bp_ucretsiz']] + ([AYARLAR['bp_premium']] if o.premium else [])
    for y in yollar:
        a = int(pay(y['altin'], d))
        o.altin += a
        o.m['altin_kazanc'] += a
        for tur in ('gumus', 'altin', 'efsane'):
            adet = y.get(f'sandik_{tur}', 0)
            # kademe aralığına düşen sandık sayısı
            for _ in range(int(adet * kademe_sonra / 50) - int(adet * kademe_once / 50)):
                o.sandik_ver(tur, 0)
        for t, adet in y.get('joker', {}).items():
            o.joker_harca(t, int(adet * kademe_sonra / 50) - int(adet * kademe_once / 50))


# =====================================================================
# SİMÜLASYON
# =====================================================================
def simule(profil: dict, gun_sayisi: int, seed: int) -> dict:
    r = random.Random(seed)
    o = Oyuncu(r, profil['premium'])
    bas, bit = AYARLAR['gun_basi_aktif_saat']
    sezon_xp = 0
    sezon_kademe_toplam = []
    sezon_mac = hafta_mac = 0
    kademe = AYARLAR['premium_plus_kademe'] if profil['premium'] == 'plus' else 0
    for gun in range(gun_sayisi):
        if gun % 30 == 0 and gun > 0:
            sezon_kademe_toplam.append(kademe)
            sezon_xp, sezon_mac = 0, 0
            kademe = AYARLAR['premium_plus_kademe'] if profil['premium'] == 'plus' else 0
        if gun % 7 == 0:
            hafta_mac = 0
        mac_saatleri = sorted(r.sample(range(bas, bit), min(profil['mac'], bit - bas))) if profil['mac'] <= bit - bas else list(range(bas, bit))
        # günde 20 maç > 16 aktif saat: bazı saatlerde 2 maç
        sayac = {s: 0 for s in range(24)}
        for i in range(profil['mac']):
            sayac[mac_saatleri[i % len(mac_saatleri)]] += 1
        gunluk = []
        kilitli = False
        for saat in range(24):
            for _ in range(sayac[saat]):
                sonuc, enerjili = o.mac(gun)
                if sonuc == 'kilitli':
                    kilitli = True
                    # kilitliyse: (simülasyonda) her saat bir Bronz-eşdeğeri "kurtarma" yok -> raporla
                    continue
                gunluk.append((sonuc, enerjili))
            o.saat_gecti(bas <= saat < bit, gun)
        if kilitli:
            o.m['kilitli_gun'] += 1
        sezon_mac += len(gunluk)
        hafta_mac += len(gunluk)
        xp = bp_xp_hesapla(gunluk, profil['premium'], gun, sezon_mac, hafta_mac)
        if gun % 7 == 6:
            xp += int(AYARLAR['haftalik_gorev_xp'] * min(1, hafta_mac / AYARLAR['haftalik_gorev_mac']))
        if gun % 30 == 29:
            xp += int(AYARLAR['sezon_gorev_xp'] * min(1, sezon_mac / AYARLAR['sezon_gorev_mac']))
        sezon_xp += xp
        o.m['bp_xp'] += xp
        yeni = min(AYARLAR['bp_kademe'], kademe + int(sezon_xp // AYARLAR['bp_kademe_xp']) - (kademe if gun % 30 else 0))
        yeni = min(AYARLAR['bp_kademe'], (AYARLAR['premium_plus_kademe'] if profil['premium'] == 'plus' else 0)
                   + int(sezon_xp // AYARLAR['bp_kademe_xp']))
        bp_odul_uygula(o, kademe, yeni)
        kademe = max(kademe, yeni)
        o.seviye_atla()
        o.paket_davranisi()
        o.seviye_atla()
    sezon_kademe_toplam.append(kademe)

    kadro = o.kadro() or []
    kadro_sv = [o.seviye.get(k.slug, 1) for k in kadro]
    tum_sv = [v for s, v in o.seviye.items() if o.sahip(s)]
    return {
        'kadro_ort_seviye': statistics.mean(kadro_sv) if kadro_sv else 0,
        'kadro_max_seviye': max(kadro_sv) if kadro_sv else 0,
        'koleksiyon_ort_seviye': statistics.mean(tum_sv) if tum_sv else 0,
        'farkli_kart': sum(1 for v in o.kopyalar.values() if v > 0),
        'kadro_gucu': statistics.mean(k.guc for k in kadro) if kadro else 0,
        'altin_son': o.altin,
        'bp_kademe_son_sezon': sezon_kademe_toplam[-1] if gun_sayisi >= 30 else None,
        'bp_tamam_orani': sum(1 for k in sezon_kademe_toplam if k >= 50) / len(sezon_kademe_toplam),
        'bp_ort_kademe': statistics.mean(sezon_kademe_toplam),
        'kadro_seviyeleri': {k.slug: o.seviye.get(k.slug, 1) for k in kadro},
        **{k: v for k, v in o.m.items() if k != 'sandik'},
        'sandik': dict(o.m['sandik']),
        'yuva_doluluk_orani': o.m['yuva_dolu_saat'] / max(1, o.m['saat']),
        '_oyuncu': o,
    }


# =====================================================================
# DÜELLO (gerçek kurallar, sadeleştirilmiş taktik yok)
# =====================================================================
def kimya(kadro: list[Kart]) -> dict:
    """Her karta en iyi bağı (+2 yeşil / +1 sarı), mevcut kuralın sade hali"""
    sonuc = {}
    for k in kadro:
        en = 0
        for d in kadro:
            if d is k:
                continue
            if d.kulup and d.kulup == k.kulup or (d.lig == k.lig and d.uyruk == k.uyruk):
                en = max(en, 2)
            elif d.uyruk == k.uyruk or d.lig == k.lig:
                en = max(en, 1)
        sonuc[k.slug] = en
    return sonuc


def seviye_bonusu(sv: int, yontem: str, tavan: int) -> int:
    if yontem == 'yok':
        return 0
    if yontem == 'ham':           # seviye başına +1 güç
        return sv - 1
    egri = [0, 0, 0, 1, 1, 2, 2, 3, 3, 4]   # azalan getirili, en fazla +4
    if yontem == 'egri':
        return egri[sv - 1]
    if yontem == 'normalize':     # dereceli: maç tavanı (iki kadronun düşük ortalaması + 1)
        return egri[min(sv, tavan) - 1]
    raise ValueError(yontem)


def duello(a: list[Kart], a_sv: dict, b: list[Kart], b_sv: dict, yontem: str, r: random.Random) -> int:
    """11 tur; açan mevkiyi seçer, cevap veren aynı mevkiden oynamak zorunda
    (yoksa pas = turu kaybeder). Efsane, Efsane olmayanı her zaman yener.
    Dönen: +1 a kazandı, -1 b kazandı, 0 berabere."""
    tavan = min(round(statistics.mean(a_sv.values())), round(statistics.mean(b_sv.values()))) + 1
    ka, kb = kimya(a), kimya(b)
    el_a, el_b = list(a), list(b)

    def etkin(k, kim, sv):
        return k.guc + kim[k.slug] + seviye_bonusu(sv.get(k.slug, 1), yontem, tavan)

    skor_a = skor_b = 0
    acan_a = r.random() < 0.5
    for _ in range(11):
        acan, cevap = (el_a, el_b) if acan_a else (el_b, el_a)
        if not acan:
            break
        # açan rastgele bir kart açar (gerçek oyuncu davranışı: taktik,
        # blöf, mevki yönetimi; her zaman en güçlüsünü açmaz)
        ak = r.choice(acan)
        uygun = [k for k in cevap if k.mevki == ak.mevki]
        acan.remove(ak)
        a_kim, a_sv2 = (ka, a_sv) if acan_a else (kb, b_sv)
        c_kim, c_sv2 = (kb, b_sv) if acan_a else (ka, a_sv)
        if not uygun:
            kazanan_acan = True
        else:
            ck = max(uygun, key=lambda k: etkin(k, c_kim, c_sv2))
            cevap.remove(ck)
            if ak.tier == 'legend' and ck.tier != 'legend':
                kazanan_acan = True
            elif ck.tier == 'legend' and ak.tier != 'legend':
                kazanan_acan = False
            else:
                pa, pc = etkin(ak, a_kim, a_sv2), etkin(ck, c_kim, c_sv2)
                if pa == pc:
                    continue  # pot: (sadeleştirme) tur sayılmaz
                kazanan_acan = pa > pc
        a_kazandi = kazanan_acan == acan_a
        if a_kazandi:
            skor_a += 1
        else:
            skor_b += 1
        acan_a = a_kazandi  # kazanan sonraki turu açar
    return (skor_a > skor_b) - (skor_a < skor_b)


def benzer_rakip(kadro: list[Kart], r: random.Random) -> list[Kart]:
    """Mevcut eşleştirmenin (024: kadro gücü) seçeceği türden rakip:
    her kart, aynı mevkide ±3 güç içindeki başka bir kartla değişir"""
    secim = []
    for k in kadro:
        havuz = [c for c in KATALOG if c.mevki == k.mevki and abs(c.guc - k.guc) <= 3 and c not in secim] or [k]
        secim.append(r.choice(havuz))
    return secim


def oran(sonuclar) -> float:
    return round(sum(1 if x > 0 else 0.5 if x == 0 else 0 for x in sonuclar) / len(sonuclar), 3)


def normalizasyon_testi(veteran: Oyuncu, yeni: Oyuncu, r: random.Random, n=4000) -> dict:
    """Seviyenin dereceli maça etkisi, 4 yöntemle:
      saf     : AYNI 11 kart; biri profilin seviyelerinde, diğeri seviye 1
      eslesme : profil kadrosu+seviyeleri vs eşleştirmenin bulacağı benzer
                güçte, seviye 1 rakip (yeni oyuncu senaryosu)"""
    sonuc = {}
    vk = veteran.kadro()
    vsv = {k.slug: veteran.seviye.get(k.slug, 1) for k in vk}
    bir = {k.slug: 1 for k in vk}
    rakipler = [benzer_rakip(vk, r) for _ in range(40)]
    for yontem in ('yok', 'ham', 'egri', 'normalize'):
        saf = [duello(vk, vsv, vk, bir, yontem, r) for _ in range(n)]
        es = []
        for i in range(n):
            rk = rakipler[i % len(rakipler)]
            es.append(duello(vk, vsv, rk, {c.slug: 1 for c in rk}, yontem, r))
        sonuc[yontem] = {'saf_seviye_kazanma': oran(saf), 'veteran_vs_yeni_kazanma': oran(es)}
    sonuc['_kadro_ort_seviye'] = round(statistics.mean(vsv.values()), 2)
    return sonuc


# =====================================================================
def main():
    tekrar = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    if len(sys.argv) > 2:
        AYARLAR['kopya_modeli'] = sys.argv[2]
    if len(sys.argv) > 3:
        AYARLAR['eksik_mevki_onceligi'] = AYARLAR['acil_kadro'] = sys.argv[3] == 'koruma'
    print('kopya modeli:', AYARLAR['kopya_modeli'], '| kilit koruması:', AYARLAR['eksik_mevki_onceligi'])
    sonuclar = {}
    sonlar = {}
    for p in PROFILLER:
        sonuclar[p['ad']] = {}
        for gun in (30, 90, 180):
            kosular = [simule(p, gun, 1000 * gun + i) for i in range(tekrar)]
            ort = {}
            for anahtar in kosular[0]:
                if anahtar.startswith('_') or anahtar in ('kadro_seviyeleri',):
                    continue
                v0 = kosular[0][anahtar]
                if isinstance(v0, dict):
                    ort[anahtar] = {k: round(statistics.mean(x[anahtar][k] for x in kosular), 1) for k in v0}
                elif v0 is None:
                    ort[anahtar] = None
                else:
                    ort[anahtar] = round(statistics.mean(x[anahtar] for x in kosular), 3)
            sonuclar[p['ad']][gun] = ort
            if gun == 180:
                sonlar[p['ad']] = kosular[0]['_oyuncu']
            print(f"{p['ad']:<28} {gun:>3} gün  kadro sv {ort['kadro_ort_seviye']:.2f}  "
                  f"BP kademe {ort['bp_ort_kademe']:.1f}  altın {ort['altin_son']:.0f}  "
                  f"taşma {ort['telafi']:.1f}  enerjisiz {ort['sandik_enerjisiz_kacan']:.0f}  "
                  f"kilitli gün {ort['kilitli_gun']:.1f}  kilit paketi {ort['kilit_paket']:.1f}  acil {ort['acil_kadro']:.1f}  "
                  f"paket {ort['paket']:.0f}")

    # Yeni oyuncu: ücretsiz 2 maç x 7 gün
    yeni = simule(PROFILLER[0], 7, 7)['_oyuncu']
    r = random.Random(42)
    norm = {}
    for ad, v in sonlar.items():
        v.kilit_coz(-9); yeni.kilit_coz(-9)
        if v.kadro() is None or yeni.kadro() is None:
            print('normalizasyon atlandı (kadro yok):', ad)
            continue
        norm[ad] = normalizasyon_testi(v, yeni, r, n=1500)
        print('normalizasyon', ad, norm[ad])
    cikti = {'ayarlar': {k: v for k, v in AYARLAR.items()}, 'sonuclar': sonuclar, 'normalizasyon': norm}
    (KOK / 'sonuclar.json').write_text(json.dumps(cikti, ensure_ascii=False, indent=1, default=str), encoding='utf-8')
    md_yaz(sonuclar, norm)


def md_yaz(s, norm):
    L = ['# Ekonomi V2 simülasyon sonuçları', '', '`python -I tool/ekonomi/simulasyon.py` çıktısı. '
         'Değerler tekrarların ortalamasıdır.', '']
    for gun in (30, 90, 180):
        L += [f'## {gun} gün', '',
              '| Profil | Maç | Kadro ort. sv | Kadro max sv | Koleksiyon ort. sv | Farklı kart | Sandık (B/G/A/E) | '
              'Yuva dolu | Posta | Telafi | Enerjisiz maç | Fazla kopya | Altın sonu | Altın harcanan | '
              'BP ort. kademe | BP tamam | Kart kaybı | Kart kazancı | Kilitli gün |',
              '|' + '---|' * 19]
        for ad, g in s.items():
            v = g[gun]
            sd = v['sandik']
            L.append(f"| {ad} | {v['mac']:.0f} | {v['kadro_ort_seviye']:.2f} | {v['kadro_max_seviye']:.1f} | "
                     f"{v['koleksiyon_ort_seviye']:.2f} | {v['farkli_kart']:.0f} | "
                     f"{sd['bronz']:.0f}/{sd['gumus']:.0f}/{sd['altin']:.0f}/{sd['efsane']:.0f} | "
                     f"%{v['yuva_doluluk_orani'] * 100:.0f} | {v['posta_giren']:.0f} | {v['telafi']:.0f} | "
                     f"{v['sandik_enerjisiz_kacan']:.0f} | {v['fazla_kopya']:.0f} | {v['altin_son']:.0f} | "
                     f"{v['altin_harcama']:.0f} | {v['bp_ort_kademe']:.1f} | %{v['bp_tamam_orani'] * 100:.0f} | "
                     f"{v['kart_kaybi']:.0f} | {v['kart_kazanc']:.0f} | {v['kilitli_gun']:.1f} |")
        L.append('')
    L += ['## Seviye normalizasyonu (180 gün sonrası kadro, gerçek düello kuralları)', '',
          '`saf` = aynı 11 kart, biri profilin seviyelerinde diğeri seviye 1. '
          '`eşleşme` = profil kadrosu+seviyeleri vs eşleştirmenin bulacağı benzer güçte (±3) seviye 1 rakip. '
          'Beraberlik yarım galibiyet. Hedef: %50 civarı = seviye kazanmayı belirlemiyor.', '',
          '| Profil | Yöntem | Saf seviye etkisi (kazanma) | Eşleşmede kazanma |', '|---|---|---|---|']
    for ad, n in norm.items():
        for y, v in n.items():
            if y.startswith('_'):
                continue
            L.append(f"| {ad} | {y} | %{v['saf_seviye_kazanma'] * 100:.0f} | %{v['veteran_vs_yeni_kazanma'] * 100:.0f} |")
    (KOK / 'sonuclar.md').write_text('\n'.join(L) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
