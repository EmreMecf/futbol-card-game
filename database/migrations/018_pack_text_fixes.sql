-- =====================================================================
-- 018 - PAKET METINLERI: DOGRU TURKCE
-- =====================================================================
-- Paket aciklamalari ASCII yazilmisti: "cikma", "yuksek", "sekilde".
-- Bunlar KOD YORUMU degil, magazada oyuncunun okudugu metinler.
--
-- Ayrica standart paketin aciklamasi "5 kart. ..." diye basliyordu ve
-- arayuz zaten kart sayisini ayri gosterdigi icin "5 kart · 5 kart..."
-- gibi tekrar ediyordu. Aciklamalar artik kart sayisini tekrarlamiyor.
-- =====================================================================

update pack_types set description = 'Legend çıkma ihtimali binde bir.'
where slug = 'standard';

update pack_types set description = 'Belirgin şekilde daha yüksek ihtimaller. En az bir Altın.'
where slug = 'premium';

update pack_types set description = 'Tam bir 11 kişilik kadro: 1 kaleci, 4 defans, 4 orta saha, 2 forvet.'
where slug = 'squad';

update pack_types set description = 'Başlangıç kadrosu. Diamond ve Legend çıkmaz.'
where slug = 'starter';

-- Gelistirme paketleri de duzgun yazilsin; test ekraninda da okunuyor.
update pack_types set description = 'Geliştirme için: Legend walkout sahnesini çok yüksek ihtimalle tetikler.'
where slug = 'test-legend';

update pack_types set description = 'Geliştirme için: Diamond walkout sahnesi.'
where slug = 'test-diamond';

update pack_types set description = 'Geliştirme için: altın kademe. Parlamalı flip, walkout YOK.'
where slug = 'test-altin';

-- SBC odul paketleri
update pack_types set description = 'Görev ödülü. Altın ağırlıklı.'
where slug = 'sbc_gold';

update pack_types set description = 'Görev ödülü. Diamond ve Legend ihtimali yüksek.'
where slug = 'sbc_premium';
