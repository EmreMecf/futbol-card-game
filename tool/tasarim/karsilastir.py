"""Referans ve Flutter ekran goruntulerini yan yana koyar.

Kullanim: python -I tool/tasarim/karsilastir.py
Girdi:   design-reference/ekranlar/390x844/<ad>.png  (referans)
         test/goldens/ekranlar/<ad>_390x844.png       (Flutter golden)
Cikti:   design-reference/karsilastirma/<ad>.png
"""
import pathlib
from PIL import Image, ImageDraw

KOK = pathlib.Path(__file__).resolve().parents[2]
REF = KOK / 'design-reference' / 'ekranlar' / '390x844'
FL = KOK / 'test' / 'goldens' / 'ekranlar'
OUT = KOK / 'design-reference' / 'karsilastirma'
OUT.mkdir(parents=True, exist_ok=True)

for ref in sorted(REF.glob('*.png')):
    fl = FL / f'{ref.stem}_390x844.png'
    if not fl.exists():
        continue
    a, b = Image.open(ref).convert('RGB'), Image.open(fl).convert('RGB')
    w, h = a.width + b.width + 30, max(a.height, b.height) + 34
    out = Image.new('RGB', (w, h), (20, 20, 20))
    out.paste(a, (0, 34))
    out.paste(b, (a.width + 30, 34))
    d = ImageDraw.Draw(out)
    d.text((8, 10), f'REFERANS (HTML) - {ref.stem}', fill=(255, 220, 120))
    d.text((a.width + 38, 10), 'FLUTTER (golden)', fill=(120, 255, 200))
    out.save(OUT / f'{ref.stem}.png')
    print(ref.stem)
