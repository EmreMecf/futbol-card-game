"""Referans HTML'in (design-reference/futbol-card-arena.html) her ekranini
telefon boyutunda PNG'ye cizer. Tasarim studyosu cercevesi gizlenir; telefon
ekrani pencerenin tamamini kaplar (cerceve, centik ve 25px sahte durum
cubugu yok).

Kullanim:  python -I tool/tasarim/referans_cek.py [genislik] [yukseklik]
Cikti:     design-reference/ekranlar/<genislik>x<yukseklik>/*.png
"""
import pathlib, subprocess, sys

KOK = pathlib.Path(__file__).resolve().parents[2]
HTML = KOK / 'design-reference' / 'futbol-card-arena.html'
CHROME = r'C:\Program Files\Google\Chrome\Application\chrome.exe'

W = int(sys.argv[1]) if len(sys.argv) > 1 else 390
H = int(sys.argv[2]) if len(sys.argv) > 2 else 844
CIKTI = KOK / 'design-reference' / 'ekranlar' / f'{W}x{H}'
GECICI = KOK / 'design-reference' / '.gecici'
CIKTI.mkdir(parents=True, exist_ok=True)
GECICI.mkdir(exist_ok=True)

CSS = f"""<style>.sidebar,.worktop,.inspect,.preview-notes,.footerhint,.toast{{display:none!important}}
.phone-wrap{{position:fixed!important;left:0!important;top:0!important;max-width:none!important;width:{W}px!important;margin:0!important;z-index:30}}
.device{{padding:0!important;border:0!important;border-radius:0!important;box-shadow:none!important}}
.device:before{{display:none!important}}.phone{{height:{H}px!important;border-radius:0!important;width:{W}px!important}}
.safe{{height:0!important}}.page{{padding:14px 14px 18px!important}}.hero h2{{font-size:36px!important}}
*{{animation:none!important;transition:none!important}}body{{overflow:hidden}}</style>"""

# (dosya adi, calistirilacak JS)
EKRANLAR = [
    ('01_ana_sayfa', "setView('home')"),
    ('01b_ana_sayfa_alt', "setView('home');$('screen').scrollTop=9999"),
    ('02_arena', "setView('arena')"),
    ('02b_arena_alt', "setView('arena');$('screen').scrollTop=9999"),
    ('03_koleksiyon', "setView('collection')"),
    ('03b_koleksiyon_alt', "setView('collection');$('screen').scrollTop=700"),
    ('03c_kart_detay', "setView('collection');showCard(3)"),
    ('03d_koleksiyon_filtre', "setView('collection');setFilter('legend')"),
    ('04_kadro', "setView('squad')"),
    ('04b_kadro_alt', "setView('squad');$('screen').scrollTop=9999"),
    ('05_magaza', "setView('shop')"),
    ('05b_magaza_alt', "setView('shop');$('screen').scrollTop=9999"),
    ('05c_paket_acma', "setView('shop');Math.random=()=>0.3;openPack()"),
    ('06_ligler', "setView('leagues')"),
    ('06b_ligler_alt', "setView('leagues');$('screen').scrollTop=9999"),
    ('07_profil', "setView('profile')"),
    ('07b_profil_alt', "setView('profile');$('screen').scrollTop=9999"),
    ('08_mac_sonucu', "state.ourScore=7;state.enemyScore=4;state.lastReward=150;setView('result')"),
    ('09_tasarim_sistemi', "setView('system')"),
    ('09b_tasarim_sistemi_alt', "setView('system');$('screen').scrollTop=9999"),
]

kaynak = HTML.read_text(encoding='utf-8')
for ad, js in EKRANLAR:
    sayfa = kaynak.replace('</head>', CSS + '</head>').replace(
        'restoreTheme();render();',
        f"restoreTheme();render();document.fonts.ready.then(()=>{{{js};}});")
    f = GECICI / f'{ad}.html'
    f.write_text(sayfa, encoding='utf-8')
    out = CIKTI / f'{ad}.png'
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars',
                    f'--window-size={W},{H}', '--force-device-scale-factor=1',
                    '--virtual-time-budget=4000', f'--screenshot={out}', f.as_uri()],
                   check=True, capture_output=True, timeout=60)
    print(out.name)
