-- =====================================================================
-- 010 - KART KATALOGU (100 KARTLIK KADRO)
-- =====================================================================
-- DAGILIM:
--   Seviye     GK  DEF  MID  FWD   Toplam   Guc araligi
--   ----------------------------------------------------
--   bronze      4    9   10    7     30     45-62
--   silver      3    9    9    7     28     63-74
--   gold        3    7    8    6     24     75-85
--   diamond     1    4    4    3     12     86-92
--   legend      1    1    2    2      6     93-99
--   ----------------------------------------------------
--   TOPLAM     12   30   33   25    100
--
-- =====================================================================
-- KIMYA SISTEMI ICIN KRITIK TASARIM KARARI
-- =====================================================================
-- UYRUK ile LIG/KULUP birbirinden BAGIMSIZ dagitildi.
--
-- Neden onemli? Ilk surumde her ulkenin kendi kulupleri vardi; yani
-- "ayni lig" otomatik olarak "ayni uyruk" demekti. Bu durumda kimya
-- kuralindaki "+2 = Ayni Lig + Ayni Uyruk" sarti asla +1'den farkli
-- davranmaz, sistem anlamsiz hale gelirdi.
--
-- Gercek futbolda bir ligde farkli uyruklardan oyuncular oynar. Simdi
-- her ligde 8-10 farkli uyruk var; oyuncu ya uyruk ya lig ya da kulup
-- uzerinden baglanti kurmayi SECMEK zorunda.
--
-- DIGER NOTLAR:
--
-- 1) GUC ARALIKLARINDA BOSLUK YOK. Bronz 45-62, Gumus 63-74...
--    Bitisik oldugu icin kimya bonusu bir alt seviyenin karti bir ust
--    seviyeyi gecebilir hale getirebiliyor - sistemin can alici noktasi.
--
-- 2) LEGEND KARTLAR GERCEK EFSANELER (vefat etmis ya da birakmis).
--    Diger 94 kart KURGUSALDIR; lisans sorunu olmasin diye.
--    Hepsi "Efsaneler Ligi"nde: birbirleriyle kimya kurabilirler ama
--    normal kartlarla lig/kulup baglantisi kuramazlar.
--
-- 3) image_url'ler HENUZ GERCEK DOSYA DEGIL.
-- =====================================================================

insert into cards
  (slug, full_name, position, tier, power, nationality, league, club,
   image_url, drop_weight)
values
  ('bronz-kaleci-emre-yilmaz', 'Emre Yilmaz', 'GK', 'bronze', 45, 'TUR', 'Super Lig', 'Anadolu SK', 'cards/bronz-kaleci-emre-yilmaz.png', 120),
  ('bronz-kaleci-rafael-costa', 'Rafael Costa', 'GK', 'bronze', 51, 'BRA', 'Premier Lig', 'Dover United', 'cards/bronz-kaleci-rafael-costa.png', 120),
  ('bronz-kaleci-sergio-marin', 'Sergio Marin', 'GK', 'bronze', 56, 'ESP', 'La Liga', 'Madrid Real', 'cards/bronz-kaleci-sergio-marin.png', 120),
  ('bronz-kaleci-lukas-vogel', 'Lukas Vogel', 'GK', 'bronze', 62, 'GER', 'Bundesliga', 'Rhein FC', 'cards/bronz-kaleci-lukas-vogel.png', 120),
  ('bronz-defans-pierre-dubois', 'Pierre Dubois', 'DEF', 'bronze', 45, 'FRA', 'Serie A', 'Verona FC', 'cards/bronz-defans-pierre-dubois.png', 120),
  ('bronz-defans-marco-bellini', 'Marco Bellini', 'DEF', 'bronze', 47, 'ITA', 'Ligue 1', 'Paris Nord', 'cards/bronz-defans-marco-bellini.png', 120),
  ('bronz-defans-tom-baker', 'Tom Baker', 'DEF', 'bronze', 49, 'ENG', 'Eredivisie', 'Amsterdam AC', 'cards/bronz-defans-tom-baker.png', 120),
  ('bronz-defans-nico-jansen', 'Nico Jansen', 'DEF', 'bronze', 51, 'NED', 'Super Lig', 'Bosphorus FC', 'cards/bronz-defans-nico-jansen.png', 120),
  ('bronz-defans-nicolas-salas', 'Nicolas Salas', 'DEF', 'bronze', 54, 'ARG', 'Premier Lig', 'Thames FC', 'cards/bronz-defans-nicolas-salas.png', 120),
  ('bronz-defans-tiago-alves', 'Tiago Alves', 'DEF', 'bronze', 56, 'POR', 'La Liga', 'Costa CF', 'cards/bronz-defans-tiago-alves.png', 120),
  ('bronz-defans-yuki-tanaka', 'Yuki Tanaka', 'DEF', 'bronze', 58, 'JPN', 'Bundesliga', 'Munchen SV', 'cards/bronz-defans-yuki-tanaka.png', 120),
  ('bronz-defans-ousmane-diallo', 'Ousmane Diallo', 'DEF', 'bronze', 60, 'SEN', 'Serie A', 'Milano Nero', 'cards/bronz-defans-ousmane-diallo.png', 120),
  ('bronz-defans-burak-demir', 'Burak Demir', 'DEF', 'bronze', 62, 'TUR', 'Ligue 1', 'Lyon Sud', 'cards/bronz-defans-burak-demir.png', 120),
  ('bronz-orta-lucas-silva', 'Lucas Silva', 'MID', 'bronze', 45, 'BRA', 'Eredivisie', 'Rotterdam FC', 'cards/bronz-orta-lucas-silva.png', 120),
  ('bronz-orta-alvaro-navarro', 'Alvaro Navarro', 'MID', 'bronze', 47, 'ESP', 'Super Lig', 'Ege United', 'cards/bronz-orta-alvaro-navarro.png', 120),
  ('bronz-orta-karl-fischer', 'Karl Fischer', 'MID', 'bronze', 49, 'GER', 'Premier Lig', 'Leeds Rovers', 'cards/bronz-orta-karl-fischer.png', 120),
  ('bronz-orta-vincent-leclerc', 'Vincent Leclerc', 'MID', 'bronze', 51, 'FRA', 'La Liga', 'Sevilla Norte', 'cards/bronz-orta-vincent-leclerc.png', 120),
  ('bronz-orta-andrea-rossi', 'Andrea Rossi', 'MID', 'bronze', 53, 'ITA', 'Bundesliga', 'Berlin Nord', 'cards/bronz-orta-andrea-rossi.png', 120),
  ('bronz-orta-owen-clarke', 'Owen Clarke', 'MID', 'bronze', 54, 'ENG', 'Serie A', 'Roma Est', 'cards/bronz-orta-owen-clarke.png', 120),
  ('bronz-orta-sven-bakker', 'Sven Bakker', 'MID', 'bronze', 56, 'NED', 'Ligue 1', 'Marsilya OC', 'cards/bronz-orta-sven-bakker.png', 120),
  ('bronz-orta-facundo-ortega', 'Facundo Ortega', 'MID', 'bronze', 58, 'ARG', 'Eredivisie', 'Eindhoven SV', 'cards/bronz-orta-facundo-ortega.png', 120),
  ('bronz-orta-rui-sousa', 'Rui Sousa', 'MID', 'bronze', 60, 'POR', 'Super Lig', 'Kartal SK', 'cards/bronz-orta-rui-sousa.png', 120),
  ('bronz-orta-sora-suzuki', 'Sora Suzuki', 'MID', 'bronze', 62, 'JPN', 'Premier Lig', 'Bristol AC', 'cards/bronz-orta-sora-suzuki.png', 120),
  ('bronz-forvet-ibrahima-ndiaye', 'Ibrahima Ndiaye', 'FWD', 'bronze', 45, 'SEN', 'La Liga', 'Aragon FC', 'cards/bronz-forvet-ibrahima-ndiaye.png', 120),
  ('bronz-forvet-kerem-kaya', 'Kerem Kaya', 'FWD', 'bronze', 48, 'TUR', 'Bundesliga', 'Hamburg BSC', 'cards/bronz-forvet-kerem-kaya.png', 120),
  ('bronz-forvet-matheus-santos', 'Matheus Santos', 'FWD', 'bronze', 51, 'BRA', 'Serie A', 'Napoli SC', 'cards/bronz-forvet-matheus-santos.png', 120),
  ('bronz-forvet-pablo-iglesias', 'Pablo Iglesias', 'FWD', 'bronze', 54, 'ESP', 'Ligue 1', 'Nantes FC', 'cards/bronz-forvet-pablo-iglesias.png', 120),
  ('bronz-forvet-julian-weber', 'Julian Weber', 'FWD', 'bronze', 56, 'GER', 'Eredivisie', 'Utrecht FC', 'cards/bronz-forvet-julian-weber.png', 120),
  ('bronz-forvet-antoine-moreau', 'Antoine Moreau', 'FWD', 'bronze', 59, 'FRA', 'Super Lig', 'Anadolu SK', 'cards/bronz-forvet-antoine-moreau.png', 120),
  ('bronz-forvet-matteo-greco', 'Matteo Greco', 'FWD', 'bronze', 62, 'ITA', 'Premier Lig', 'Dover United', 'cards/bronz-forvet-matteo-greco.png', 120),
  ('gumus-kaleci-harry-wright', 'Harry Wright', 'GK', 'silver', 63, 'ENG', 'La Liga', 'Madrid Real', 'cards/gumus-kaleci-harry-wright.png', 110),
  ('gumus-kaleci-daan-visser', 'Daan Visser', 'GK', 'silver', 68, 'NED', 'Bundesliga', 'Rhein FC', 'cards/gumus-kaleci-daan-visser.png', 110),
  ('gumus-kaleci-santiago-herrera', 'Santiago Herrera', 'GK', 'silver', 74, 'ARG', 'Serie A', 'Verona FC', 'cards/gumus-kaleci-santiago-herrera.png', 110),
  ('gumus-defans-joao-fonseca', 'Joao Fonseca', 'DEF', 'silver', 63, 'POR', 'Ligue 1', 'Paris Nord', 'cards/gumus-defans-joao-fonseca.png', 110),
  ('gumus-defans-haruto-watanabe', 'Haruto Watanabe', 'DEF', 'silver', 64, 'JPN', 'Eredivisie', 'Amsterdam AC', 'cards/gumus-defans-haruto-watanabe.png', 110),
  ('gumus-defans-mamadou-sarr', 'Mamadou Sarr', 'DEF', 'silver', 66, 'SEN', 'Super Lig', 'Bosphorus FC', 'cards/gumus-defans-mamadou-sarr.png', 110),
  ('gumus-defans-hakan-sahin', 'Hakan Sahin', 'DEF', 'silver', 67, 'TUR', 'Premier Lig', 'Thames FC', 'cards/gumus-defans-hakan-sahin.png', 110),
  ('gumus-defans-gabriel-oliveira', 'Gabriel Oliveira', 'DEF', 'silver', 68, 'BRA', 'La Liga', 'Costa CF', 'cards/gumus-defans-gabriel-oliveira.png', 110),
  ('gumus-defans-javier-torres', 'Javier Torres', 'DEF', 'silver', 70, 'ESP', 'Bundesliga', 'Munchen SV', 'cards/gumus-defans-javier-torres.png', 110),
  ('gumus-defans-tobias-hoffmann', 'Tobias Hoffmann', 'DEF', 'silver', 71, 'GER', 'Serie A', 'Milano Nero', 'cards/gumus-defans-tobias-hoffmann.png', 110),
  ('gumus-defans-hugo-girard', 'Hugo Girard', 'DEF', 'silver', 73, 'FRA', 'Ligue 1', 'Lyon Sud', 'cards/gumus-defans-hugo-girard.png', 110),
  ('gumus-defans-luca-conti', 'Luca Conti', 'DEF', 'silver', 74, 'ITA', 'Eredivisie', 'Rotterdam FC', 'cards/gumus-defans-luca-conti.png', 110),
  ('gumus-orta-jack-hughes', 'Jack Hughes', 'MID', 'silver', 63, 'ENG', 'Super Lig', 'Ege United', 'cards/gumus-orta-jack-hughes.png', 110),
  ('gumus-orta-bram-smit', 'Bram Smit', 'MID', 'silver', 64, 'NED', 'Premier Lig', 'Leeds Rovers', 'cards/gumus-orta-bram-smit.png', 110),
  ('gumus-orta-emiliano-molina', 'Emiliano Molina', 'MID', 'silver', 66, 'ARG', 'La Liga', 'Sevilla Norte', 'cards/gumus-orta-emiliano-molina.png', 110),
  ('gumus-orta-andre-cardoso', 'Andre Cardoso', 'MID', 'silver', 67, 'POR', 'Bundesliga', 'Berlin Nord', 'cards/gumus-orta-andre-cardoso.png', 110),
  ('gumus-orta-riku-ito', 'Riku Ito', 'MID', 'silver', 68, 'JPN', 'Serie A', 'Roma Est', 'cards/gumus-orta-riku-ito.png', 110),
  ('gumus-orta-cheikh-fall', 'Cheikh Fall', 'MID', 'silver', 70, 'SEN', 'Ligue 1', 'Marsilya OC', 'cards/gumus-orta-cheikh-fall.png', 110),
  ('gumus-orta-serkan-aslan', 'Serkan Aslan', 'MID', 'silver', 71, 'TUR', 'Eredivisie', 'Eindhoven SV', 'cards/gumus-orta-serkan-aslan.png', 110),
  ('gumus-orta-thiago-pereira', 'Thiago Pereira', 'MID', 'silver', 73, 'BRA', 'Super Lig', 'Kartal SK', 'cards/gumus-orta-thiago-pereira.png', 110),
  ('gumus-orta-marco-ramos', 'Marco Ramos', 'MID', 'silver', 74, 'ESP', 'Premier Lig', 'Bristol AC', 'cards/gumus-orta-marco-ramos.png', 110),
  ('gumus-forvet-felix-braun', 'Felix Braun', 'FWD', 'silver', 63, 'GER', 'La Liga', 'Aragon FC', 'cards/gumus-forvet-felix-braun.png', 110),
  ('gumus-forvet-theo-fontaine', 'Theo Fontaine', 'FWD', 'silver', 65, 'FRA', 'Bundesliga', 'Hamburg BSC', 'cards/gumus-forvet-theo-fontaine.png', 110),
  ('gumus-forvet-davide-marino', 'Davide Marino', 'FWD', 'silver', 67, 'ITA', 'Serie A', 'Napoli SC', 'cards/gumus-forvet-davide-marino.png', 110),
  ('gumus-forvet-callum-turner', 'Callum Turner', 'FWD', 'silver', 68, 'ENG', 'Ligue 1', 'Nantes FC', 'cards/gumus-forvet-callum-turner.png', 110),
  ('gumus-forvet-ruud-meijer', 'Ruud Meijer', 'FWD', 'silver', 70, 'NED', 'Eredivisie', 'Utrecht FC', 'cards/gumus-forvet-ruud-meijer.png', 110),
  ('gumus-forvet-agustin-rojas', 'Agustin Rojas', 'FWD', 'silver', 72, 'ARG', 'Super Lig', 'Anadolu SK', 'cards/gumus-forvet-agustin-rojas.png', 110),
  ('gumus-forvet-nuno-mendes', 'Nuno Mendes', 'FWD', 'silver', 74, 'POR', 'Premier Lig', 'Dover United', 'cards/gumus-forvet-nuno-mendes.png', 110),
  ('altin-kaleci-kaito-nakamura', 'Kaito Nakamura', 'GK', 'gold', 75, 'JPN', 'La Liga', 'Madrid Real', 'cards/altin-kaleci-kaito-nakamura.png', 100),
  ('altin-kaleci-aliou-gueye', 'Aliou Gueye', 'GK', 'gold', 80, 'SEN', 'Bundesliga', 'Rhein FC', 'cards/altin-kaleci-aliou-gueye.png', 100),
  ('altin-kaleci-onur-ozturk', 'Onur Ozturk', 'GK', 'gold', 85, 'TUR', 'Serie A', 'Verona FC', 'cards/altin-kaleci-onur-ozturk.png', 100),
  ('altin-defans-bruno-almeida', 'Bruno Almeida', 'DEF', 'gold', 75, 'BRA', 'Ligue 1', 'Paris Nord', 'cards/altin-defans-bruno-almeida.png', 100),
  ('altin-defans-nacho-vega', 'Nacho Vega', 'DEF', 'gold', 77, 'ESP', 'Eredivisie', 'Amsterdam AC', 'cards/altin-defans-nacho-vega.png', 100),
  ('altin-defans-jonas-schulz', 'Jonas Schulz', 'DEF', 'gold', 78, 'GER', 'Super Lig', 'Bosphorus FC', 'cards/altin-defans-jonas-schulz.png', 100),
  ('altin-defans-mathis-barbier', 'Mathis Barbier', 'DEF', 'gold', 80, 'FRA', 'Premier Lig', 'Thames FC', 'cards/altin-defans-mathis-barbier.png', 100),
  ('altin-defans-simone-ferrari', 'Simone Ferrari', 'DEF', 'gold', 82, 'ITA', 'La Liga', 'Costa CF', 'cards/altin-defans-simone-ferrari.png', 100),
  ('altin-defans-ethan-barnes', 'Ethan Barnes', 'DEF', 'gold', 83, 'ENG', 'Bundesliga', 'Munchen SV', 'cards/altin-defans-ethan-barnes.png', 100),
  ('altin-defans-joost-bos', 'Joost Bos', 'DEF', 'gold', 85, 'NED', 'Serie A', 'Milano Nero', 'cards/altin-defans-joost-bos.png', 100),
  ('altin-orta-lautaro-acosta', 'Lautaro Acosta', 'MID', 'gold', 75, 'ARG', 'Ligue 1', 'Lyon Sud', 'cards/altin-orta-lautaro-acosta.png', 100),
  ('altin-orta-ricardo-teixeira', 'Ricardo Teixeira', 'MID', 'gold', 76, 'POR', 'Eredivisie', 'Rotterdam FC', 'cards/altin-orta-ricardo-teixeira.png', 100),
  ('altin-orta-ren-kobayashi', 'Ren Kobayashi', 'MID', 'gold', 78, 'JPN', 'Super Lig', 'Ege United', 'cards/altin-orta-ren-kobayashi.png', 100),
  ('altin-orta-moussa-sow', 'Moussa Sow', 'MID', 'gold', 79, 'SEN', 'Premier Lig', 'Leeds Rovers', 'cards/altin-orta-moussa-sow.png', 100),
  ('altin-orta-cenk-dogan', 'Cenk Dogan', 'MID', 'gold', 81, 'TUR', 'La Liga', 'Sevilla Norte', 'cards/altin-orta-cenk-dogan.png', 100),
  ('altin-orta-diego-ribeiro', 'Diego Ribeiro', 'MID', 'gold', 82, 'BRA', 'Bundesliga', 'Berlin Nord', 'cards/altin-orta-diego-ribeiro.png', 100),
  ('altin-orta-raul-delgado', 'Raul Delgado', 'MID', 'gold', 84, 'ESP', 'Serie A', 'Roma Est', 'cards/altin-orta-raul-delgado.png', 100),
  ('altin-orta-niklas-krause', 'Niklas Krause', 'MID', 'gold', 85, 'GER', 'Ligue 1', 'Marsilya OC', 'cards/altin-orta-niklas-krause.png', 100),
  ('altin-forvet-enzo-renaud', 'Enzo Renaud', 'FWD', 'gold', 75, 'FRA', 'Eredivisie', 'Eindhoven SV', 'cards/altin-forvet-enzo-renaud.png', 100),
  ('altin-forvet-alessio-galli', 'Alessio Galli', 'FWD', 'gold', 77, 'ITA', 'Super Lig', 'Kartal SK', 'cards/altin-forvet-alessio-galli.png', 100),
  ('altin-forvet-mason-cooper', 'Mason Cooper', 'FWD', 'gold', 79, 'ENG', 'Premier Lig', 'Bristol AC', 'cards/altin-forvet-mason-cooper.png', 100),
  ('altin-forvet-stijn-dekker', 'Stijn Dekker', 'FWD', 'gold', 81, 'NED', 'La Liga', 'Aragon FC', 'cards/altin-forvet-stijn-dekker.png', 100),
  ('altin-forvet-julian-benitez', 'Julian Benitez', 'FWD', 'gold', 83, 'ARG', 'Bundesliga', 'Hamburg BSC', 'cards/altin-forvet-julian-benitez.png', 100),
  ('altin-forvet-fabio-lopes', 'Fabio Lopes', 'FWD', 'gold', 85, 'POR', 'Serie A', 'Napoli SC', 'cards/altin-forvet-fabio-lopes.png', 100),
  ('diamond-kaleci-takumi-sato', 'Takumi Sato', 'GK', 'diamond', 89, 'JPN', 'Ligue 1', 'Nantes FC', 'cards/diamond-kaleci-takumi-sato.png', 80),
  ('diamond-defans-pape-diouf', 'Pape Diouf', 'DEF', 'diamond', 86, 'SEN', 'Eredivisie', 'Utrecht FC', 'cards/diamond-defans-pape-diouf.png', 80),
  ('diamond-defans-volkan-aydin', 'Volkan Aydin', 'DEF', 'diamond', 88, 'TUR', 'Super Lig', 'Anadolu SK', 'cards/diamond-defans-volkan-aydin.png', 80),
  ('diamond-defans-vinicius-nunes', 'Vinicius Nunes', 'DEF', 'diamond', 90, 'BRA', 'Premier Lig', 'Dover United', 'cards/diamond-defans-vinicius-nunes.png', 80),
  ('diamond-defans-iker-castillo', 'Iker Castillo', 'DEF', 'diamond', 92, 'ESP', 'La Liga', 'Madrid Real', 'cards/diamond-defans-iker-castillo.png', 80),
  ('diamond-orta-maximilian-winkler', 'Maximilian Winkler', 'MID', 'diamond', 86, 'GER', 'Bundesliga', 'Rhein FC', 'cards/diamond-orta-maximilian-winkler.png', 80),
  ('diamond-orta-nolan-chevalier', 'Nolan Chevalier', 'MID', 'diamond', 88, 'FRA', 'Serie A', 'Verona FC', 'cards/diamond-orta-nolan-chevalier.png', 80),
  ('diamond-orta-federico-bruno', 'Federico Bruno', 'MID', 'diamond', 90, 'ITA', 'Ligue 1', 'Paris Nord', 'cards/diamond-orta-federico-bruno.png', 80),
  ('diamond-orta-alfie-foster', 'Alfie Foster', 'MID', 'diamond', 92, 'ENG', 'Eredivisie', 'Amsterdam AC', 'cards/diamond-orta-alfie-foster.png', 80),
  ('diamond-forvet-lars-vos', 'Lars Vos', 'FWD', 'diamond', 86, 'NED', 'Super Lig', 'Bosphorus FC', 'cards/diamond-forvet-lars-vos.png', 80),
  ('diamond-forvet-mateo-cabrera', 'Mateo Cabrera', 'FWD', 'diamond', 89, 'ARG', 'Premier Lig', 'Thames FC', 'cards/diamond-forvet-mateo-cabrera.png', 80),
  ('diamond-forvet-diogo-barros', 'Diogo Barros', 'FWD', 'diamond', 92, 'POR', 'La Liga', 'Costa CF', 'cards/diamond-forvet-diogo-barros.png', 80),
  ('legend-kaleci-lev-yashin', 'Lev Yashin', 'GK', 'legend', 95, 'RUS', 'Efsaneler Ligi', 'Efsaneler', 'cards/legend-kaleci-lev-yashin.png', 60),
  ('legend-defans-franz-beckenbauer', 'Franz Beckenbauer', 'DEF', 'legend', 96, 'GER', 'Efsaneler Ligi', 'Efsaneler', 'cards/legend-defans-franz-beckenbauer.png', 60),
  ('legend-orta-diego-maradona', 'Diego Maradona', 'MID', 'legend', 99, 'ARG', 'Efsaneler Ligi', 'Efsaneler', 'cards/legend-orta-diego-maradona.png', 60),
  ('legend-orta-johan-cruyff', 'Johan Cruyff', 'MID', 'legend', 97, 'NED', 'Efsaneler Ligi', 'Efsaneler', 'cards/legend-orta-johan-cruyff.png', 60),
  ('legend-forvet-pele', 'Pele', 'FWD', 'legend', 98, 'BRA', 'Efsaneler Ligi', 'Efsaneler', 'cards/legend-forvet-pele.png', 60),
  ('legend-forvet-ferenc-puskas', 'Ferenc Puskas', 'FWD', 'legend', 94, 'HUN', 'Efsaneler Ligi', 'Efsaneler', 'cards/legend-forvet-ferenc-puskas.png', 60)
on conflict (slug) do update
set full_name   = excluded.full_name,
    position    = excluded.position,
    tier        = excluded.tier,
    power       = excluded.power,
    nationality = excluded.nationality,
    league      = excluded.league,
    club        = excluded.club,
    image_url   = excluded.image_url,
    drop_weight = excluded.drop_weight,
    is_active   = true;

-- Ilk denemelerdeki 35 kartlik kucuk katalogu pasife al
update cards
set is_active = false
where slug ~ '^(kaleci|defans|orta|forvet)-';
