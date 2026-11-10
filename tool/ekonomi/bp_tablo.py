"""Battle Pass 50 kademe ödül tablosu (toplamlar simulasyon.py AYARLAR ile aynı).
Kullanım: python -I tool/ekonomi/bp_tablo.py  -> markdown tablo"""
F_SANDIK = {3: 'Gümüş sandık', 9: 'Gümüş sandık', 15: 'Gümüş sandık', 21: 'Gümüş sandık', 33: 'Gümüş sandık',
            45: 'Gümüş sandık', 12: 'Altın sandık', 24: 'Altın sandık', 36: 'Altın sandık', 42: 'Altın sandık',
            50: 'Efsane sandık'}
F_JOKER = {6: 2, 18: 2, 27: 2, 39: 2, 48: 2}            # Altın joker parça (toplam 10)
F_KOZ = {25: 'Sezon rozeti (bronz)', 30: 'Enerji içeceği x2'}
P_SANDIK = {5: 'Altın sandık', 13: 'Altın sandık', 22: 'Altın sandık', 28: 'Altın sandık', 44: 'Altın sandık',
            47: 'Altın sandık', 15: 'Efsane sandık', 35: 'Efsane sandık', 50: 'Efsane sandık'}
P_JOKER = {2: ('Altın', 3), 8: ('Altın', 3), 17: ('Altın', 3), 26: ('Altın', 3), 32: ('Altın', 4), 41: ('Altın', 4),
           19: ('Elmas', 2), 37: ('Elmas', 2), 49: ('Elmas', 2)}
P_KOZ = {1: 'Forma: Sezon 1', 10: 'Kart görünümü: Gece Işığı', 20: 'Profil çerçevesi: Sezon 1',
         25: 'Sezon rozeti (altın)', 30: 'Arena görünümü: Yağmurlu Gece', 38: 'Sandık hızlandırıcı (2 sa) x2',
         40: 'Zafer animasyonu: Havai Fişek', 45: 'Karakter kozmetiği: Kaptan Bandı',
         46: 'Ustalık kitabı (Altın) x1'}

def dagit(toplam, bos):
    pay = toplam // len(bos)
    d = {t: pay for t in bos}
    d[bos[-1]] += toplam - pay * len(bos)
    return d

f_bos = [t for t in range(1, 51) if t not in F_SANDIK and t not in F_JOKER and t not in F_KOZ]
p_bos = [t for t in range(1, 51) if t not in P_SANDIK and t not in P_JOKER and t not in P_KOZ]
f_altin, p_altin = dagit(3000, f_bos), dagit(4500, p_bos)
print('| Kademe | Ücretsiz yol | Premium yol |')
print('|---|---|---|')
for t in range(1, 51):
    f = F_SANDIK.get(t) or (f'Altın joker parça x{F_JOKER[t]}' if t in F_JOKER else None) or F_KOZ.get(t) or f'{f_altin[t]} altın'
    if t in P_JOKER:
        p = f'{P_JOKER[t][0]} joker parça x{P_JOKER[t][1]}'
    else:
        p = P_SANDIK.get(t) or P_KOZ.get(t) or f'{p_altin[t]} altın'
    print(f'| {t} | {f} | {p} |')
print()
print(f'Toplam: ücretsiz {sum(f_altin.values())} altın, {sum(1 for v in F_SANDIK.values() if "Gümüş" in v)} gümüş / '
      f'{sum(1 for v in F_SANDIK.values() if "Altın" in v)} altın / 1 efsane sandık, {sum(F_JOKER.values())} Altın joker; '
      f'premium {sum(p_altin.values())} altın, {sum(1 for v in P_SANDIK.values() if "Altın" in v)} altın / '
      f'{sum(1 for v in P_SANDIK.values() if "Efsane" in v)} efsane sandık, '
      f'{sum(n for k, n in P_JOKER.values() if k == "Altın")} Altın + {sum(n for k, n in P_JOKER.values() if k == "Elmas")} Elmas joker.')
