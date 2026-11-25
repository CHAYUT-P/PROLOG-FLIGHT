:- dynamic(explored/2).
:- dynamic(steps/1).
:- dynamic(flight_memo/4).
:- dynamic(trip_month/1).
:- dynamic(live_fare/3).
:- dynamic(live_departure/2).
:- dynamic(live_offer/6).
:- dynamic(option/2).

%FACTS
country(thailand,    'Thailand',    'ไทย',          1000).
country(japan,       'Japan',       'ญี่ปุ่น',        1500).
country(korea,       'South Korea', 'เกาหลีใต้',      1200).
country(china,       'China',       'จีน',          900).
country(singapore,   'Singapore',   'สิงคโปร์',       1400).

destination(OriginCountry, C) :- country(C, _, _, _), \+ C = OriginCountry.

visa_free(japan, 15).  visa_free(korea, 90).
visa_free(china, 30).
visa_free(singapore, 30).

city(bangkok,      'Bangkok Suvarnabhumi', 'สุวรรณภูมิ',   'BKK', thailand,    13.69, 100.75).
city(don_mueang,   'Bangkok Don Mueang',   'ดอนเมือง',     'DMK', thailand,    13.91, 100.61).
city(chiang_mai,   'Chiang Mai',       'เชียงใหม่',       'CNX', thailand,    18.77,  98.96).
city(phuket,       'Phuket',           'ภูเก็ต',          'HKT', thailand,     8.11,  98.31).
city(tokyo,        'Tokyo',            'โตเกียว',        'HND', japan,       35.68, 139.77).
city(kyoto,        'Kyoto',            'เกียวโต',        'KYO', japan,       35.01, 135.77).
city(osaka,        'Osaka',            'โอซาก้า',        'KIX', japan,       34.69, 135.50).
city(sapporo,      'Sapporo',          'ซัปโปโร',        'CTS', japan,       43.06, 141.35).
city(seoul,        'Seoul',            'โซล',           'ICN', korea,       37.57, 126.98).
city(busan,        'Busan',            'ปูซาน',          'PUS', korea,       35.18, 129.08).
city(jeju,         'Jeju',             'เชจู',           'CJU', korea,       33.50, 126.53).
city(shanghai,     'Shanghai',         'เซี่ยงไฮ้',        'PVG', china,       31.23, 121.47).
city(beijing,      'Beijing',          'ปักกิ่ง',          'PEK', china,       39.90, 116.40).
city(xian,         'Xi''an',           'ซีอาน',          'XIY', china,       34.34, 108.94).
city(singapore,    'Singapore',        'สิงคโปร์',        'SIN', singapore,    1.35, 103.82).

home(C) :- airport(C, _).

twin(bangkok, don_mueang).  twin(don_mueang, bangkok).

airport(bangkok, 7).   airport(don_mueang, 7).  airport(chiang_mai, 7).  airport(phuket, 7).
airport(tokyo, 9).     airport(osaka, 9).       airport(sapporo, 9).
airport(seoul, 9).     airport(busan, 9).
airport(shanghai, 8).  airport(beijing, 8).     airport(xian, 8).
airport(singapore, 8).

% --- Airlines catalog (2-letter IATA code, display name, carrier tier)
airline_info('TG', 'Thai Airways',           full).
airline_info('XJ', 'Thai AirAsia X',         budget).
airline_info('FD', 'Thai AirAsia',           budget).
airline_info('VZ', 'Thai Vietjet Air',       budget).
airline_info('SL', 'Thai Lion Air',          budget).
airline_info('DD', 'Nok Air',                budget).
airline_info('PG', 'Bangkok Airways',        full).
airline_info('NH', 'ANA',                    full).
airline_info('JL', 'Japan Airlines',         full).
airline_info('MM', 'Peach Aviation',         budget).
airline_info('ZG', 'ZIPAIR Tokyo',           budget).
airline_info('NQ', 'Air Japan',              budget).
airline_info('KE', 'Korean Air',             full).
airline_info('OZ', 'Asiana Airlines',        full).
airline_info('7C', 'Jeju Air',               budget).
airline_info('TW', 'T''way Air',             budget).
airline_info('BX', 'Air Busan',              budget).
airline_info('LJ', 'Jin Air',                budget).
airline_info('ZE', 'Eastar Jet',             budget).
airline_info('MU', 'China Eastern',          full).
airline_info('CA', 'Air China',              full).
airline_info('HO', 'Juneyao Air',            full).
airline_info('FM', 'Shanghai Airlines',      full).
airline_info('CZ', 'China Southern',         full).
airline_info('9C', 'Spring Airlines',        budget).
airline_info('SQ', 'Singapore Airlines',     full).
airline_info('TR', 'Scoot',                  budget).
airline_info('AK', 'AirAsia',                budget).
airline_info('D7', 'AirAsia X',              budget).
airline_info('MH', 'Malaysia Airlines',      full).
airline_info('CX', 'Cathay Pacific',         full).
airline_info('VJ', 'VietJet Air',            budget).
airline_info('VN', 'Vietnam Airlines',       full).
airline_info('5J', 'Cebu Pacific',           budget).

% --- from Bangkok
flight('TG682', bangkok, tokyo,       2245, 345, 13500).
flight('XJ600', don_mueang, tokyo,        745, 355,  7900).
flight('TG622', bangkok, osaka,       2350, 330, 12500).
flight('XJ610', don_mueang, osaka,        105, 330,  7200).
flight('XJ620', don_mueang, sapporo,       50, 405,  9800).
flight('TG656', bangkok, seoul,       2330, 330, 11000).
flight('7C2204', bangkok, seoul,       225, 320,  6900).
flight('BX726', bangkok, busan,         50, 330,  7500).
flight('MU548', bangkok, shanghai,     115, 270,  7200).
flight('CA960', bangkok, beijing,       55, 300,  8400).
flight('FD558', don_mueang, xian,        1955, 265,  6500).
flight('SQ711', bangkok, singapore,    950, 145,  6500).
flight('TR869', don_mueang, singapore,    720, 145,  3400).
% --- back to Bangkok
flight('TG683', tokyo,        bangkok, 1030, 405, 13500).
flight('XJ601', tokyo,        don_mueang, 1700, 415,  7900).
flight('TG623', osaka,        bangkok, 1100, 375, 12500).
flight('XJ611', osaka,        don_mueang, 1645, 380,  7400).
flight('XJ621', sapporo,      don_mueang,  950, 480,  9800).
flight('TG657', seoul,        bangkok, 1940, 360, 11000).
flight('7C2203', seoul,       bangkok, 2010, 365,  6900).
flight('BX725', busan,        bangkok, 1940, 365,  7500).
flight('MU547', shanghai,     bangkok, 1810, 300,  7200).
flight('CA959', beijing,      bangkok, 1720, 340,  8400).
flight('FD559', xian,         don_mueang,   30, 285,  6500).
flight('SQ706', singapore,    bangkok,  745, 145,  6500).
flight('TR868', singapore,    don_mueang, 1805, 145,  3400).
% --- inside Thailand, to connect through Bangkok
flight('TG101', chiang_mai,   bangkok,    700,  70,  1500).
flight('TG103', chiang_mai,   bangkok,   1230,  70,  1500).
flight('TG105', chiang_mai,   bangkok,   1830,  70,  1500).
flight('TG100', bangkok,      chiang_mai, 830,  70,  1500).
flight('TG102', bangkok,      chiang_mai,1430,  70,  1500).
flight('TG104', bangkok,      chiang_mai,2030,  70,  1500).
flight('TG201', phuket,       bangkok,    700,  85,  1800).
flight('TG203', phuket,       bangkok,   1200,  85,  1800).
flight('TG205', phuket,       bangkok,   1800,  85,  1800).
flight('TG200', bangkok,      phuket,     900,  85,  1800).
flight('TG202', bangkok,      phuket,    1500,  85,  1800).
flight('TG204', bangkok,      phuket,    2100,  85,  1800).
flight('FD3432', chiang_mai,  don_mueang,  640,  75,  1100).
flight('FD3438', chiang_mai,  don_mueang, 1715,  75,  1100).
flight('FD3431', don_mueang,  chiang_mai,  800,  75,  1100).
flight('FD3437', don_mueang,  chiang_mai, 2050,  75,  1100).
flight('FD3022', phuket,      don_mueang,  650,  85,  1300).
flight('FD3028', phuket,      don_mueang, 1720,  85,  1300).
flight('FD3021', don_mueang,  phuket,      815,  85,  1300).
flight('FD3027', don_mueang,  phuket,     2100,  85,  1300).
% --- Chiang Mai
flight('TW104', chiang_mai,   seoul,       50, 330,  7200).
flight('TW103', seoul,        chiang_mai, 1940, 360, 7200).
flight('TR847', chiang_mai,   singapore, 1355, 195,  4300).
flight('TR846', singapore,    chiang_mai,1035, 200,  4300).
flight('HO1342', chiang_mai,  shanghai,   130, 250,  6400).
flight('HO1341', shanghai,    chiang_mai,2050, 270,  6400).
% --- Phuket
flight('KE638', phuket,       seoul,     2240, 375, 12000).
flight('KE637', seoul,        phuket,    1830, 395, 12000).
flight('SQ727', phuket,       singapore, 1210, 100,  4200).
flight('SQ726', singapore,    phuket,     955, 100,  4200).
% --- connections between international hubs (for anyplace-to-anyplace routing)
flight('KE705', seoul,        tokyo,      850, 140,  5200).
flight('KE706', tokyo,        seoul,     1300, 160,  5200).
flight('7C1102', seoul,       tokyo,     1120, 145,  3900).
flight('7C1101', tokyo,       seoul,     1455, 160,  3900).
flight('KE723', seoul,        osaka,      935, 105,  4800).
flight('KE724', osaka,        seoul,     1225, 115,  4800).
flight('TW283', seoul,        osaka,     1415, 110,  3400).
flight('TW284', osaka,        seoul,     1710, 115,  3400).
flight('SQ636', singapore,    tokyo,      745, 400, 11900).
flight('SQ637', tokyo,        singapore, 1105, 435, 11900).
flight('TR808', singapore,    tokyo,      100, 410,  6800).
flight('TR809', tokyo,        singapore, 1015, 445,  6800).
flight('SQ622', singapore,    osaka,     1405, 385, 11500).
flight('SQ623', osaka,        singapore, 2325, 415, 11500).
flight('SQ600', singapore,    seoul,      800, 380,  9900).
flight('SQ601', seoul,        singapore, 1620, 405,  9900).
flight('TR840', singapore,    seoul,      930, 385,  5900).
flight('TR841', seoul,        singapore, 1730, 410,  5900).
flight('SQ830', singapore,    shanghai,   925, 315,  8800).
flight('SQ831', shanghai,     singapore, 1605, 330,  8800).
flight('SQ802', singapore,    beijing,    830, 365,  9200).
flight('SQ803', beijing,      singapore, 1630, 385,  9200).
flight('MU523', shanghai,     tokyo,      855, 180,  5900).
flight('MU524', tokyo,        shanghai,  1335, 210,  5900).
flight('MU515', shanghai,     osaka,     1010, 145,  5200).
flight('MU516', osaka,        shanghai,  1355, 160,  5200).
flight('MU5041', shanghai,    seoul,      915, 120,  4600).
flight('MU5042', seoul,       shanghai,  1230, 130,  4600).
flight('CA925', beijing,      tokyo,      920, 210,  7100).
flight('CA926', tokyo,        beijing,   1515, 240,  7100).
flight('CA123', beijing,      seoul,      835, 125,  4900).
flight('CA124', seoul,        beijing,   1145, 140,  4900).

% --- Thailand ground links
ground(bangkok,   chiang_mai,  plane,      1500,  70).
ground(bangkok,   chiang_mai,  night_train, 900, 720).
ground(bangkok,   phuket,      plane,      1800,  85).
ground(bangkok,   phuket,      night_bus,   850, 720).
% --- Japan
ground(tokyo,     kyoto,       high_speed, 3300, 135).
ground(tokyo,     kyoto,       night_bus,  1000, 480).
ground(tokyo,     osaka,       high_speed, 3400, 150).
ground(tokyo,     osaka,       night_bus,  1000, 510).
ground(tokyo,     osaka,       plane,      1800,  70).
ground(kyoto,     osaka,       train,       150,  30).
ground(tokyo,     sapporo,     plane,      3500, 100).
ground(osaka,     sapporo,     plane,      3800, 125).
% --- South Korea
ground(seoul,     busan,       high_speed, 1400, 150).
ground(seoul,     busan,       bus,         700, 260).
ground(seoul,     jeju,        plane,      1500,  70).
ground(busan,     jeju,        plane,      1300,  60).
ground(busan,     jeju,        night_ferry,1200, 720).
% --- China
ground(shanghai,  beijing,     high_speed, 2800, 270).
ground(shanghai,  beijing,     night_train,1800, 720).
ground(beijing,   xian,        high_speed, 2600, 270).
ground(beijing,   xian,        night_train,1500, 720).
ground(shanghai,  xian,        high_speed, 3000, 360).

overnight(night_bus).  overnight(night_train).  overnight(night_ferry).

% --- Attractions: attraction(City, Name, Category, FeeTHB, Hours, Zone, Slot, Details)
% Thailand
attraction(bangkok, 'Grand Palace and Wat Pho',      culture,    500, 3,   old_town,   morning,   'Royal temple complex, Emerald Buddha & Reclining Buddha').
attraction(bangkok, 'Chinatown street food',         food,       400, 2.5, old_town,   evening,   'Yaowarat neon food stalls, seafood & traditional desserts').
attraction(bangkok, 'Siam and CentralWorld',         shopping,     0, 3,   siam,       afternoon, 'Flagship malls, Thai designer boutiques & indoor dining').
attraction(bangkok, 'Chatuchak Weekend Market',      shopping,     0, 3.5, north,      morning,   '15,000+ stalls for crafts, vintage fashion & street snacks').
attraction(bangkok, 'Chao Phraya dinner cruise',     nightlife,  900, 2.5, riverside,  evening,   'Evening boat ride past illuminated riverside temples').
attraction(bangkok, 'Lumphini Park morning walk',    nature,       0, 1.5, silom,      morning,   'Shaded city park lakes, monitor lizards & morning exercise').
attraction(bangkok, 'Jim Thompson House',            culture,    250, 1.5, siam,       afternoon, 'Traditional Thai teak houses, silk heritage & garden cafe').
attraction(bangkok, 'Jodd Fairs night market',       food,       350, 2,   ratchada,   evening,   'Open-air night market with volcano ribs & indie fashion').

attraction(chiang_mai, 'Doi Suthep temple',          culture,    100, 3,   mountain,   morning,   'Golden hilltop chedi overlooking the entire Chiang Mai valley').
attraction(chiang_mai, 'Old City temples walk',      culture,     50, 2.5, old_city,   morning,   'Wat Chedi Luang, Wat Phra Singh & ancient city moats').
attraction(chiang_mai, 'Nimman cafe and boutiques',  shopping,   300, 2.5, nimman,     afternoon, 'Artisan coffee roasters, craft studios & local concept shops').
attraction(chiang_mai, 'Khao Soi food crawl',        food,       300, 2,   old_city,   afternoon, 'Northern coconut curry noodles & local Lanna market snacks').
attraction(chiang_mai, 'Doi Inthanon nature day trip', nature,   700, 7,   day_trip,   all_day,   'Thailand''s highest peak, twin pagodas & misty waterfalls').
attraction(chiang_mai, 'Night Bazaar',               shopping,     0, 2.5, riverside,  evening,   'Handmade crafts, hill-tribe textiles & evening street food').

attraction(phuket, 'Kata and Karon Beaches',         beach,        0, 3.5, west_coast, afternoon, 'Clear Andaman surf, soft white sand & sunset viewpoints').
attraction(phuket, 'Phuket Old Town',                culture,      0, 2.5, old_town,   morning,   'Sino-Portuguese shophouses, street murals & local kopitiams').
attraction(phuket, 'Phi Phi Islands boat day trip',  beach,     1600, 7,   day_trip,   all_day,   'Snorkeling in turquoise lagoons & Maya Bay limestone cliffs').
attraction(phuket, 'Phuket seafood and night market',food,       600, 2.5, old_town,   evening,   'Grilled Andaman lobster, Southern Thai curries & live music').
attraction(phuket, 'Big Buddha and Promthep Cape',   nature,       0, 3,   south,      afternoon, 'Hilltop marble statue & panoramic Andaman sunset cliff').
attraction(phuket, 'Jungceylon and Patong night walk', shopping,   0, 2.5, patong,     evening,   'Beachside shopping mall, Bangla walking street & night stalls').

% Japan
attraction(tokyo, 'Senso-ji Temple',          culture,      0, 2,   asakusa,    morning,   'Tokyo''s oldest Buddhist temple & Nakamise souvenir street').
attraction(tokyo, 'Tsukiji Outer Market',     food,       600, 2,   ginza_tsukiji, morning, 'Fresh sashimi bowls, tamagoyaki & Japanese knife shops').
attraction(tokyo, 'Shibuya and Harajuku',     shopping,     0, 3,   shibuya,    afternoon, 'Shibuya Crossing, Takeshita Street & boutique fashion alleys').
attraction(tokyo, 'teamLab Planets',          adventure,  900, 2,   bay_area,   afternoon, 'Immersive barefoot digital art rooms in Toyosu').
attraction(tokyo, 'Shinjuku izakaya alleys',  nightlife,  800, 2,   shinjuku,   evening,   'Lantern-lit Omoide Yokocho yakitori & late-night bars').
attraction(tokyo, 'Mount Takao hike',         nature,     300, 5,   west_suburb, morning,  'Forested mountain trails with Fuji views & cable car').
attraction(tokyo, 'Meiji Shrine',             culture,      0, 1.5, shibuya,    morning,   'Peaceful forested Shinto shrine right beside Harajuku').
attraction(tokyo, 'Akihabara electronics town', shopping,   0, 3,   east_central, afternoon, 'Anime figures, retro games, arcades & tax-free gadgets').
attraction(tokyo, 'Tokyo Skytree',            adventure, 1000, 2,   asakusa,    afternoon, '634m observation decks & Solamachi shopping complex').
attraction(tokyo, 'Ueno Park and museums',    culture,    300, 3,   ueno,       morning,   'National Museum, cherry-tree avenues & Ameyoko market').
attraction(tokyo, 'Odaiba waterfront',        shopping,     0, 3,   bay_area,   afternoon, 'Rainbow Bridge views, DiverCity & waterfront promenades').
attraction(tokyo, 'Ginza',                    shopping,     0, 2,   ginza_tsukiji, afternoon, 'Luxury department stores, flagship stationery & art galleries').
attraction(tokyo, 'Shinjuku Gyoen garden',    nature,     150, 2,   shinjuku,   morning,   'Traditional Japanese, English & French landscaped gardens').
attraction(tokyo, 'Tokyo DisneySea',          adventure, 2400, 8,   day_trip,   all_day,   'Full-day nautical Disney theme park in Chiba').
attraction(tokyo, 'Mount Fuji and Lake Kawaguchi day trip', nature, 1500, 8, day_trip, all_day, 'Iconic Mt. Fuji views, Chureito Pagoda & lakeside ropeway').
attraction(tokyo, 'Kamakura day trip',        culture,    600, 6,   day_trip,   all_day,   'Great Bronze Buddha, coastal shrines & Komachi shopping street').
attraction(tokyo, 'Nikko day trip',           culture,   1200, 8,   day_trip,   all_day,   'UNESCO Toshogu Shrine, cedar forests & Kegon Falls').
attraction(tokyo, 'Sushi and ramen crawl',    food,       800, 2,   shinjuku,   evening,   'Counter sushi & late-night Tonkotsu ramen tasting').
attraction(tokyo, 'Golden Gai bars',          nightlife,  600, 2,   shinjuku,   evening,   'Six narrow alleys packed with tiny 6-seat themed bars').
attraction(tokyo, 'Tokyo Tower',              culture,    300, 1.5, central,    evening,   'Illuminated red steel landmark & Shiba Park night views').

attraction(kyoto, 'Fushimi Inari Shrine',     culture,      0, 3,   south,      morning,   'Thousands of vermilion torii gates winding up Mt. Inari').
attraction(kyoto, 'Arashiyama Bamboo Grove',  nature,       0, 2,   west,       morning,   'Towering bamboo forest, Togetsukyo Bridge & river boats').
attraction(kyoto, 'Kinkaku-ji',               culture,    120, 1.5, north,      morning,   'Gold-leaf pavilion reflected on Mirror Pond').
attraction(kyoto, 'Nishiki Market',           food,       500, 2,   central,    afternoon, 'Kyoto''s 400-year-old covered food & kitchenware market').
attraction(kyoto, 'Kiyomizu-dera',            culture,    100, 2,   east,       afternoon, 'Wooden hillside stage & Higashiyama pottery lanes').
attraction(kyoto, 'Gion evening walk',        culture,      0, 2,   east,       evening,   'Preserved wooden machiya teahouses & Hanamikoji street').
attraction(kyoto, 'Nara day trip and deer park', nature,  200, 6,   day_trip,   all_day,   'Bow-greeting wild deer, Todai-ji Great Buddha & Kasuga Shrine').
attraction(kyoto, 'Philosopher''s Path',      nature,       0, 1.5, east,       morning,   'Canal-side stone path lined with cherry & maple trees').
attraction(kyoto, 'Kaiseki dinner',           food,      1500, 2,   central,    evening,   'Seasonal multi-course Kyoto haute cuisine').

attraction(osaka, 'Dotonbori street food',    food,       600, 2,   namba,      evening,   'Neon Glico sign, takoyaki stalls & canal boardwalk').
attraction(osaka, 'Universal Studios Japan',  adventure, 2300, 8,   day_trip,   all_day,   'Full-day Super Nintendo World & Wizarding World park').
attraction(osaka, 'Osaka Castle',             culture,    140, 2,   central,    morning,   '16th-century castle keep, moat gardens & history museum').
attraction(osaka, 'Shinsaibashi shopping',    shopping,     0, 3,   namba,      afternoon, '600m covered arcade from boutiques to street-style brands').
attraction(osaka, 'Kuromon Market',           food,       400, 2,   namba,      morning,   'Osaka''s kitchen: grilled scallops, wagyu skewers & fruit').
attraction(osaka, 'Umeda Sky Building',       culture,    400, 1.5, umeda,      evening,   '360-degree open-air rooftop observatory above Osaka').
attraction(osaka, 'Kaiyukan Aquarium',        adventure,  700, 3,   bay_area,   afternoon, 'Giant Pacific Ocean tank with whale sharks & penguins').
attraction(osaka, 'Shinsekai kushikatsu',     food,       400, 2,   shinsekai,  evening,   'Retro Tsutenkaku district famous for crispy skewers').
attraction(osaka, 'Namba nightlife',          nightlife,  500, 2,   namba,      evening,   'Hozenji Yokocho alley pubs & live music clubs').

attraction(sapporo, 'Odori Park',             nature,       0, 1.5, central,    morning,   'Tree-lined central promenade & Sapporo TV Tower').
attraction(sapporo, 'Ramen Alley',            food,       350, 1,   susukino,   evening,   'Narrow lane of classic Hokkaido miso-butter ramen shops').
attraction(sapporo, 'Otaru canal day trip',   culture,    300, 5,   day_trip,   all_day,   'Historic stone canal warehouses, music boxes & seafood').
attraction(sapporo, 'Mount Moiwa ropeway',    nature,     500, 2,   south,      evening,   'Cable car summit with panoramic night city lights').
attraction(sapporo, 'Sapporo Beer Museum',    food,       200, 2,   east,       afternoon, 'Red-brick Meiji brewery & Genghis Khan lamb tasting').
attraction(sapporo, 'Jozankei hot spring day trip', nature, 800, 5, day_trip,   all_day,   'Mountain valley onsen baths & autumn gorge views').
attraction(sapporo, 'Susukino nightlife',     nightlife,  500, 2,   susukino,   evening,   'Northern Japan''s lively neon dining & bar district').

% South Korea
attraction(seoul, 'Gyeongbokgung Palace',     culture,     80, 2,   jongno,     morning,   'Main Joseon royal palace & changing of the guard').
attraction(seoul, 'Myeongdong shopping',      shopping,     0, 3,   central,    afternoon, 'K-beauty flagship stores, street snacks & duty-free malls').
attraction(seoul, 'Gwangjang Market',         food,       400, 2,   jongno,     afternoon, 'Bindaetteok mung-bean pancakes, tteokbokki & yukhoe').
attraction(seoul, 'Bukhansan hike',           nature,       0, 5,   north,      morning,   'Granite peaks & fortress walls inside Seoul National Park').
attraction(seoul, 'Hongdae nightlife',        nightlife,  600, 3,   hongdae,    evening,   'Indie busking streets, youth fashion & late-night clubs').
attraction(seoul, 'Bukchon Hanok Village',    culture,      0, 2,   jongno,     morning,   'Hilltop lanes of preserved traditional Korean wooden homes').
attraction(seoul, 'N Seoul Tower',            culture,    500, 2,   central,    evening,   'Namsan Mountain cable car & city skyline observatory').
attraction(seoul, 'Lotte World',              adventure, 1500, 6,   jamsil,     all_day,   'Indoor-outdoor theme park, ice rink & Seokchon Lake').
attraction(seoul, 'Korean barbecue dinner',   food,       600, 2,   hongdae,    evening,   'Charcoal-grilled samgyeopsal & banchan side dishes').
attraction(seoul, 'DMZ tour',                 culture,   2000, 8,   day_trip,   all_day,   'Guided border tour: Imjingak, 3rd Tunnel & Dora Observatory').
attraction(seoul, 'Insadong',                 shopping,     0, 2,   jongno,     afternoon, 'Traditional crafts, tea houses, ceramics & Ssamziegil mall').
attraction(seoul, 'Changdeokgung Secret Garden', nature,  200, 2,   jongno,     morning,   'UNESCO wooded palace garden with lotus pavilions').
attraction(seoul, 'Cheonggyecheon stream walk', nature,     0, 1,   central,    evening,   'Illuminated downtown urban stream promenade').

attraction(busan, 'Haeundae Beach',           beach,        0, 3,   haeundae,   afternoon, 'Wide sandy bay, coastal Sky Capsule & beach cafes').
attraction(busan, 'Gamcheon Culture Village', culture,      0, 2,   west,       morning,   'Pastel hillside houses, murals & Little Prince overlook').
attraction(busan, 'Jagalchi Fish Market',     food,       600, 2,   nampo,      afternoon, 'Korea''s largest seafood market with upstairs sashimi dining').
attraction(busan, 'Haedong Yonggungsa Temple', culture,     0, 2,   haeundae,   morning,   'Dramatic cliffside Buddhist temple overlooking ocean waves').
attraction(busan, 'Gwangalli bridge at night', nightlife,   0, 2,   gwangalli,  evening,   'Beachfront cafes facing LED-lit Diamond Bridge').
attraction(busan, 'Taejongdae cliffs',        nature,     100, 3,   south,      afternoon, 'Coastal pine trails, lighthouse & sea-cliff views').

attraction(jeju, 'Hallasan hike',             nature,       0, 7,   central,    all_day,   'South Korea''s highest volcanic peak & crater lake trail').
attraction(jeju, 'Seongsan Sunrise Peak',     nature,     130, 2,   east,       morning,   'UNESCO volcanic tuff cone rising from the eastern sea').
attraction(jeju, 'Hyeopjae Beach',            beach,        0, 3,   west,       afternoon, 'Emerald shallow waters & Biyangdo Island views').
attraction(jeju, 'Manjanggul lava tube',      nature,     150, 2,   east,       afternoon, 'Vast underground volcanic lava cavern').
attraction(jeju, 'Black pork barbecue',       food,       600, 2,   jeju_city,  evening,   'Jeju specialty thick-cut black pork grilled with anchovy sauce').
attraction(jeju, 'Udo Island',                beach,      300, 5,   day_trip,   all_day,   'Ferry ride to peanut-ice-cream island & coastal bike loop').

% China
attraction(shanghai, 'The Bund',              culture,      0, 2,   huangpu,    evening,   'Colonial riverfront promenade facing Pudong''s neon skyline').
attraction(shanghai, 'Yu Garden',             culture,    200, 2,   old_town,   morning,   'Ming-dynasty rockeries, koi ponds & bazaar teahouses').
attraction(shanghai, 'Nanjing Road',          shopping,     0, 3,   huangpu,    afternoon, 'China''s premier pedestrian shopping boulevard').
attraction(shanghai, 'Xiaolongbao crawl',     food,       400, 2,   old_town,   afternoon, 'Steamed soup dumplings & pan-fried shengjianbao tasting').
attraction(shanghai, 'Zhujiajiao water town', nature,       0, 4,   day_trip,   morning,   'Ancient stone bridges, canal gondolas & riverside tea shops').
attraction(shanghai, 'Shanghai Tower',        adventure,  800, 2,   pudong,     afternoon, 'World''s 3rd tallest skyscraper observation deck').
attraction(shanghai, 'French Concession walk', culture,     0, 3,   xuhui,      afternoon, 'Plane-tree avenues, art cafes & Tianzifang craft lanes').
attraction(shanghai, 'Shanghai Disneyland',   adventure, 2700, 8,   day_trip,   all_day,   'Full-day theme park with TRON Lightcycle & Zootopia').

attraction(beijing, 'Great Wall at Mutianyu', adventure,  600, 6,   day_trip,   all_day,   'Restored Ming Great Wall section with cable car & toboggan').
attraction(beijing, 'Forbidden City',         culture,    300, 4,   central,    morning,   'Imperial Ming-Qing palace complex of 980 historic buildings').
attraction(beijing, 'Peking duck dinner',     food,       900, 2,   central,    evening,   'Crispy wood-roasted duck carved tableside with pancakes').
attraction(beijing, 'Summer Palace',          nature,     150, 3,   northwest,  afternoon, 'Imperial lakeside gardens, Marble Boat & Long Corridor').
attraction(beijing, 'Temple of Heaven',       culture,    150, 2,   south,      morning,   'Circular blue-tiled Hall of Prayer & morning tai chi park').
attraction(beijing, 'Hutong rickshaw tour',   culture,    500, 2,   central,    afternoon, 'Traditional courtyard alleyways around Houhai lakes').
attraction(beijing, 'Wangfujing snack street', food,      300, 2,   central,    evening,   'Bustling pedestrian shopping street & classic night snacks').

attraction(xian, 'Terracotta Army',           culture,    600, 4,   day_trip,   morning,   'Thousands of life-sized Qin dynasty clay warriors in three pits').
attraction(xian, 'City Wall bike ride',       adventure,  250, 2,   central,    afternoon, 'Cycle atop China''s best-preserved 14km Ming city ramparts').
attraction(xian, 'Muslim Quarter food street', food,      300, 2,   central,    evening,   'Hand-pulled biangbiang noodles, roujiamo & pomegranate juice').

% Singapore
attraction(singapore, 'Gardens by the Bay',   nature,     700, 3,   marina_bay, afternoon, 'Supertree Grove, Cloud Forest waterfall & Flower Dome').
attraction(singapore, 'Hawker centre feast',  food,       300, 2,   chinatown,  evening,   'Maxwell or Lau Pa Sat chicken rice, laksa & chilli crab').
attraction(singapore, 'Universal Studios Singapore', adventure, 2100, 8, sentosa, all_day,   'Full-day movie theme park on Sentosa Island').
attraction(singapore, 'Marina Bay Sands SkyPark', culture, 900, 1.5, marina_bay, evening,  '57th-floor skyline deck & Spectra evening light show').
attraction(singapore, 'Orchard Road',         shopping,     0, 3,   orchard,    afternoon, '2km boulevard of flagship malls, Design Orchard & cafes').
attraction(singapore, 'Clarke Quay',          nightlife,  800, 2,   river,      evening,   'Colourful riverside warehouses with bars & boat cruises').
attraction(singapore, 'Sentosa beaches',      beach,        0, 4,   sentosa,    afternoon, 'Siloso & Palawan palm beaches with island cable car').
attraction(singapore, 'Night Safari',         nature,    1300, 4,   north,      evening,   'Open-air nocturnal zoo tram & leopard walking trails').
attraction(singapore, 'Chinatown and Little India', culture, 0, 3,  chinatown,  morning,   'Buddha Tooth Relic Temple, Sri Veeramakaliamman & murals').
attraction(singapore, 'Jewel Changi',         shopping,     0, 2,   east,       afternoon, 'Rain Vortex indoor waterfall, Canopy Park & flagship shops').
attraction(singapore, 'S.E.A. Aquarium',      adventure, 1100, 3,   sentosa,    morning,   'Giant marine habitat with manta rays & ocean tunnel').
attraction(singapore, 'Singapore Botanic Gardens', nature,  0, 2.5, orchard,    morning,   'UNESCO tropical gardens & National Orchid Garden').
attraction(singapore, 'Singapore Flyer',      culture,    900, 1.5, marina_bay, evening,   '165m giant observation wheel overlooking Marina Bay').
attraction(singapore, 'Haji Lane and Kampong Glam', shopping, 0, 2, bugis,      afternoon, 'Indie boutiques, street art & Sultan Mosque heritage quarter').
attraction(singapore, 'Pulau Ubin bike day',  nature,     200, 5,   east,       all_day,   'Rustic bumboat island, Chek Jawa boardwalk & forest cycling').
attraction(singapore, 'Lau Pa Sat satay night', food,     300, 2,   marina_bay, evening,   'Open-air Satay Street skewers beneath Victorian cast iron').
attraction(singapore, 'ArtScience Museum',    culture,    700, 2,   marina_bay, afternoon, 'Lotus-shaped museum with interactive Future World exhibits').
attraction(singapore, 'East Coast Park seafood', food,    900, 3,   east,       evening,   'Seaside cycling path & classic chilli/black-pepper crab').
attraction(singapore, 'Bird Paradise',        nature,    1200, 4,   north,      morning,   'Eight walk-in aviaries in Mandai Wildlife Reserve').

highlight(thailand,  'cool dry weather',          [11, 12, 1, 2]).
highlight(thailand,  'Songkran water festival',   [4]).
highlight(japan,     'cherry blossom season',     [3, 4]).
highlight(japan,     'autumn leaves',             [11]).
highlight(japan,     'the Sapporo Snow Festival', [2]).
highlight(korea,     'cherry blossoms',           [4]).
highlight(korea,     'autumn colours',            [10, 11]).
highlight(china,     'mild spring weather',       [4, 5]).
highlight(china,     'golden autumn',             [9, 10]).
highlight(singapore, 'Chinese New Year lights',   [1, 2]).

warning(thailand,  'heavy monsoon rain',          [9, 10]).
warning(thailand,  'peak tropical heat',          [4, 5]).
warning(japan,     'the rainy season',            [6]).
warning(japan,     'typhoon season',              [8, 9]).
warning(korea,     'heavy monsoon rain',          [7]).
warning(korea,     'freezing winter',             [12, 1, 2]).
warning(china,     'freezing winter in Beijing',  [12, 1, 2]).
warning(china,     'Golden Week crowds',          [10]).
warning(singapore, 'the rainy monsoon',           [11, 12, 1]).

interest(nature).  interest(culture).   interest(food).  interest(shopping).
interest(beach).   interest(adventure). interest(nightlife).

stay_range(bangkok, 2, 4).     stay_range(chiang_mai, 2, 4).   stay_range(phuket, 2, 4).
stay_range(tokyo, 3, 6).       stay_range(kyoto, 2, 4).        stay_range(osaka, 2, 3).
stay_range(sapporo, 2, 3).
stay_range(seoul, 3, 5).       stay_range(busan, 2, 3).        stay_range(jeju, 2, 3).
stay_range(shanghai, 3, 4).    stay_range(beijing, 3, 4).      stay_range(xian, 2, 3).
stay_range(singapore, 3, 6).

busy(thailand,    [12, 1],       25).
busy(thailand,    [4],           15).
busy(thailand,    [9],          -10).
busy(japan,       [3, 4],        30).
busy(japan,       [11],          15).
busy(japan,       [6],          -15).
busy(korea,       [4, 10],       20).
busy(korea,       [1, 2],       -15).
busy(china,       [10],          25).
busy(china,       [1, 2],        20).
busy(singapore,   [12],          15).

thai_holiday([4],     20, 'Songkran').
thai_holiday([10],    10, 'the October school break').
thai_holiday([12, 1], 20, 'New Year').

%HELPERS
listlen([], 0).
listlen([_ | T], N) :- listlen(T, N0), N is N0 + 1.

last_elem([X], X) :- !.
last_elem([_ | T], X) :- last_elem(T, X).

take(0, _, []) :- !.
take(_, [], []) :- !.
take(N, [X | Xs], [X | Ys]) :- N1 is N - 1, take(N1, Xs, Ys).

no_dups(List, Result) :- no_dups(List, [], Result).
no_dups([], _, []).
no_dups([X | T], Seen, R) :- member(X, Seen), !, no_dups(T, Seen, R).
no_dups([X | T], Seen, [X | R]) :- no_dups(T, [X | Seen], R).

clamp(X, Lo, _, Lo) :- X < Lo, !.
clamp(X, _, Hi, Hi) :- X > Hi, !.
clamp(X, _, _, X).

% --- Insertion sort
insort([], []).
insort([X | L], M) :- insort(L, N), insortx(X, N, M).
insortx(X, [A | L], [A | M]) :- before(A, X), !, insortx(X, L, M).
insortx(X, L, [X | L]).
before(K1 - _, K2 - _) :- K1 =< K2.

values([], []).
values([_ - V | T], [V | Vs]) :- values(T, Vs).

%TIME — clock times, time zones and connections

clock_minutes(HHMM, M) :- M is (HHMM // 100) * 60 + HHMM mod 100.

to_utc(City, HHMM, T) :-
    airport(City, Zone),
    clock_minutes(HHMM, M),
    T is M - Zone * 60.

local_time(City, T, Day, Clock) :-
    airport(City, Zone),
    L is T + Zone * 60,
    Day is L // 1440,
    Clock is L mod 1440.

departure(start, City, HHMM, Dep, 0) :-
    to_utc(City, HHMM, Dep).
departure(landed(Arr), City, HHMM, Dep, Wait) :-
    to_utc(City, HHMM, T),
    W is (T - Arr) mod 1440,
    enough_time(W, Wait),
    Wait =< 720,
    Dep is Arr + Wait.

enough_time(W, W) :- W >= 90, !.
enough_time(W, W1) :- W1 is W + 1440.

%OPTIONS — the traveller's extra choices
default_option(max_flights, 3).
default_option(airlines, any).
default_option(night_flights, allowed).
default_option(cities, []).
default_option(getting_around, any).

opt(Name, Value) :- option(Name, V), !, Value = V.
opt(Name, Value) :- default_option(Name, Value).

set_options(_) :- retract(option(_, _)), fail.
set_options(Opts) :- store_options(Opts).

store_options([]).
store_options([O | Os]) :- O =.. [Name, Value], assertz(option(Name, Value)), store_options(Os).

airline_ok(_, From, To) :-
    city(From, _, _, _, C, _, _), city(To, _, _, _, C, _, _), !.
airline_ok(_, _, _) :- opt(airlines, any), !.
airline_ok(Code, _, _) :- opt(airlines, budget), !, airline_tier(Code, budget).
airline_ok(Code, _, _) :- opt(airlines, full), airline_tier(Code, full).

daytime_ok(_) :- opt(night_flights, allowed), !.
daytime_ok(HHMM) :- HHMM >= 600, HHMM =< 2200.

chosen_ok(Country, Cities) :-
    opt(cities, All),
    findall(M, (member(M, All), city(M, _, _, _, Country, _, _)), Mine),
    chosen_ok2(Mine, Cities).

chosen_ok2([], _) :- !.
chosen_ok2(Mine, Cities) :-
    all_in(Mine, Cities),
    middle(Cities, Mid),
    all_in(Mid, Mine),
    ends_ok(Cities, Mine).

all_in([], _).
all_in([X | Xs], L) :- member(X, L), all_in(Xs, L).

middle([_], []) :- !.
middle([_, _], []) :- !.
middle([_ | T], Mid) :- rev(T, [_ | MidRev]), rev(MidRev, Mid).

ends_ok([C], Mine) :- !, member(C, Mine).
ends_ok(Cities, Mine) :-
    Cities = [First, Second | _], end_ok(First, Second, Mine),
    rev(Cities, [Last, Before | _]), end_ok(Last, Before, Mine).

end_ok(C, _, Mine) :- member(C, Mine), !.
end_ok(C, Next, Mine) :- airport(C, _), member(Next, Mine), \+ airport(Next, _).

ground_ok(_) :- opt(getting_around, any), !.
ground_ok(Mode) :- opt(getting_around, no_night), !, \+ overnight(Mode).
ground_ok(Mode) :- opt(getting_around, fast), \+ overnight(Mode), \+ Mode = bus.

gateway(City) :- opt(cities, Ms), \+ Ms = [], \+ member(City, Ms).

%PRICES — airlines, live API offers & seasonal fallback
season_extra(Country, Month, Extra) :-
    findall(P, (busy(Country, Months, P), member(Month, Months)), Ps),
    sum(Ps, Extra).

holiday_extra(OriginCountry, Month, Extra) :-
    OriginCountry = thailand, !,
    findall(P, (thai_holiday(Months, P, _), member(Month, Months)), Ps),
    sum(Ps, Extra).
holiday_extra(_, _, 0).

flight_level(OriginCountry, Country, Month, Pct) :-
    season_extra(Country, Month, A), holiday_extra(OriginCountry, Month, B), Pct is 100 + A + B.

leg_country(_, To, C) :- city(To, _, _, _, C, _, _), \+ C = thailand, !.
leg_country(From, _, C) :- city(From, _, _, _, C, _, _).

airline(Code, Airline) :-
    atom_chars(Code, [A, B | _]), !,
    atom_chars(Airline, [A, B]).
airline(Code, Code).

airline_name(Code, Name) :-
    airline(Code, A),
    airline_info(A, Name, _), !.
airline_name(Code, A) :-
    airline(Code, A).

airline_tier(Code, Tier) :-
    airline(Code, A),
    airline_info(A, _, Tier), !.
airline_tier(_, full).

departs(Code, _, HHMM) :- live_departure(Code, HHMM), !.
departs(_, HHMM, HHMM).

% --- Estimate flight duration when an API offer connects two cities with no static flight/6
edge_minutes(From, To, Minutes) :-
    flight(_, From, To, _, Minutes, _), !.
edge_minutes(From, To, Minutes) :-
    city(From, _, _, _, _, Lat1, Lon1),
    city(To,   _, _, _, _, Lat2, Lon2),
    DLat is (Lat2 - Lat1) * 111.0,
    DLon is (Lon2 - Lon1) * 95.0,
    Dist is sqrt(DLat * DLat + DLon * DLon),
    Minutes is round(45 + Dist / 13.0).

% --- Candidate flight edges: real multi-airline API offers when present, else static flight/6
route_edge(_, Here, Next, Code, HHMM, Minutes, Price) :-
    live_offer(Here, Next, _, _, _, _), !,
    live_offer(Here, Next, _, Code, HHMM, Price),
    edge_minutes(Here, Next, Minutes).
route_edge(OriginCountry, Here, Next, Code, HHMM, Minutes, Price) :-
    flight(Code, Here, Next, Timetable, Minutes, Sample),
    departs(Code, Timetable, HHMM),
    flight_price(OriginCountry, Code, Here, Next, Sample, Price).

% --- API live_fare vs static price (fallback when no live_offer/6)
flight_price(_, Code, From, To, _, Price) :-
    live_fare(From, To, Live), airline_tier(Code, budget), !,
    Price = Live.
flight_price(_, _, From, To, _, Price) :-
    live_fare(From, To, Live), !,
    Price is Live * 160 // 100.
flight_price(OriginCountry, _, From, To, Sample, Price) :-
    trip_month(Month),
    leg_country(From, To, Country),
    flight_level(OriginCountry, Country, Month, Pct),
    Price is Sample * Pct // 100.

set_month(_) :- retract(trip_month(_)), fail.
set_month(Month) :- assertz(trip_month(Month)).

%SEARCH
reset_search :-
    retract_all_explored,
    assertz(steps(0)).

retract_all_explored :- retract(explored(_, _)), fail.
retract_all_explored :- retract(steps(_)), fail.
retract_all_explored :- retract(flight_memo(_, _, _, _)), fail.
retract_all_explored.

note_explored(A, B) :-
    retract(steps(N)), N1 is N + 1, assertz(steps(N1)),
    remember_edge(A, B).

remember_edge(A, B) :- explored(A, B), !.
remember_edge(A, B) :- assertz(explored(A, B)).

fly(From, To, Legs) :-
    city(From, _, _, _, OriginCountry, _, _),
    fly(OriginCountry, From, To, 2, [From], start, Legs).

fly(_, Here, Here, _, _, _, []).
fly(OriginCountry, Here, To, N, Trail, Clock, [leg(Code, Here, Next, Dep, Arr, Price, Wait) | Rest]) :-
    \+ Here = To,
    N > 0,
    route_edge(OriginCountry, Here, Next, Code, HHMM, Minutes, Price),
    \+ member(Next, Trail),
    note_explored(Here, Next),
    departure(Clock, Here, HHMM, Dep, Wait),
    Arr is Dep + Minutes,
    N1 is N - 1,
    fly(OriginCountry, Next, To, N1, [Next | Trail], landed(Arr), Rest).

legs_price([], 0).
legs_price([leg(_, _, _, _, _, P, _) | Legs], Total) :-
    legs_price(Legs, T0), Total is T0 + P.

legs_minutes(Legs, M) :-
    Legs = [leg(_, _, _, Dep, _, _, _) | _],
    last_elem(Legs, leg(_, _, _, _, Arr, _, _)),
    M is Arr - Dep.

flight_key(cheapest, Legs, K) :- legs_price(Legs, K).
flight_key(fastest,  Legs, K) :- legs_minutes(Legs, K).
flight_key(fewest,   Legs, K) :- listlen(Legs, N), legs_price(Legs, P), K is N * 1000000 + P.
flight_key(balanced, Legs, K) :- legs_price(Legs, P), legs_minutes(Legs, M), K is P + M * 10.

%BEST-FIRST SEARCH & A* (f(n) = g(n) + h(n))
path_cost(cheapest, Legs, C) :- legs_price(Legs, C).
path_cost(fastest,  Legs, C) :- elapsed(Legs, C).
path_cost(fewest,   Legs, C) :- listlen(Legs, N), legs_price(Legs, P), C is N * 1000000 + P.
path_cost(balanced, Legs, C) :- legs_price(Legs, P), elapsed(Legs, M), C is P + M * 10.

% --- Admissible & consistent heuristic h(n) for A* (fastest & fewest; h=0 for cheapest/balanced)
heuristic(_, To, To, 0) :- !.
heuristic(fastest, Here, To, H) :- !,
    city(Here, _, _, _, _, Lat1, Lon1),
    city(To,   _, _, _, _, Lat2, Lon2),
    MidLat is (Lat1 + Lat2) * 0.5 * 0.0174532925,
    DLat is (Lat2 - Lat1) * 111.0,
    DLon is (Lon2 - Lon1) * 111.0 * cos(MidLat),
    DistKm is sqrt(DLat * DLat + DLon * DLon),
    H is floor(DistKm * 60.0 / 1000.0).
heuristic(fewest, _, _, 1000000) :- !.
heuristic(_, _, _, 0).

astar_cost(Pref, Next, To, Legs, F) :-
    path_cost(Pref, Legs, G),
    heuristic(Pref, Next, To, H),
    F is G + H.

elapsed(Legs, M) :-
    Legs = [leg(_, _, _, _, Arr, _, _) | _],
    last_elem(Legs, leg(_, _, _, Dep, _, _, _)),
    M is Arr - Dep.

rev(L, R) :- rev(L, [], R).
rev([], A, A).
rev([H | T], A, R) :- rev(T, [H | A], R).

shortest([R | Rs], S, [R | Rest]) :- shortest(Rs, S, Rest), cheaper(S, R), !.
shortest([R | Rs], R, Rs).

cheaper(r(C1, _, _, _, _), r(C2, _, _, _, _)) :- C1 < C2.

bangkok_airport(bangkok).
bangkok_airport(don_mueang).

back_to_origin_country(OriginCountry, Here, Next, To) :-
    city(To, _, _, _, C0, _, _), \+ C0 = OriginCountry,
    city(Here, _, _, _, C1, _, _), \+ C1 = OriginCountry,
    city(Next, _, _, _, OriginCountry, _, _).

bad_origin_hop(OriginCountry, Here, Next, To) :-
    city(To, _, _, _, C0, _, _), \+ C0 = OriginCountry,
    city(Here, _, _, _, OriginCountry, _, _),
    city(Next, _, _, _, OriginCountry, _, _),
    bangkok_airport(Here).
bad_origin_hop(OriginCountry, _, Next, To) :-
    OriginCountry = thailand,
    bangkok_airport(To),
    city(Next, _, _, _, thailand, _, _),
    \+ Next = To.
bad_origin_hop(OriginCountry, _, Next, To) :-
    OriginCountry = thailand,
    city(To, _, _, _, thailand, _, _), \+ bangkok_airport(To),
    city(Next, _, _, _, thailand, _, _),
    \+ Next = To, \+ bangkok_airport(Next).

best_routes(From, To, Pref, K, Routes) :-
    city(From, _, _, _, OriginCountry, _, _),
    bf([r(0, From, start, [From], [])], OriginCountry, To, Pref, K, Routes).

bf(_, _, _, _, 0, []) :- !.
bf([], _, _, _, _, []) :- !.
bf(Queue, OriginCountry, To, Pref, K, Routes) :-
    shortest(Queue, Best, Rest),
    visit(Best, Rest, OriginCountry, To, Pref, K, Routes).

visit(r(_, To, _, _, Legs), Rest, OriginCountry, To, Pref, K, [Route | More]) :-
    \+ Legs = [], !,
    rev(Legs, Route),
    K1 is K - 1,
    bf(Rest, OriginCountry, To, Pref, K1, More).
visit(r(_, Here, Clock, Seen, Legs), Rest, OriginCountry, To, Pref, K, Routes) :-
    opt(max_flights, Max),
    listlen(Legs, N), N < Max, !,
    findall(r(C, Next, landed(Arr), [Next | Seen], [leg(Code, Here, Next, Dep, Arr, Price, Wait) | Legs]),
            ( route_edge(OriginCountry, Here, Next, Code, HHMM, Minutes, Price),
              \+ member(Next, Seen),
              \+ back_to_origin_country(OriginCountry, Here, Next, To),
              \+ bad_origin_hop(OriginCountry, Here, Next, To),
              airline_ok(Code, Here, Next),
              daytime_ok(HHMM),
              departure(Clock, Here, HHMM, Dep, Wait),
              Arr is Dep + Minutes,
              note_explored(Here, Next),
              astar_cost(Pref, Next, To, [leg(Code, Here, Next, Dep, Arr, Price, Wait) | Legs], C) ),
            Longer),
    append(Longer, Rest, Queue),
    bf(Queue, OriginCountry, To, Pref, K, Routes).
visit(_, Rest, OriginCountry, To, Pref, K, Routes) :-
    bf(Rest, OriginCountry, To, Pref, K, Routes).

% --- Memoization (Top 2 flight cache)
best_flights(From, To, Pref, Best) :- flight_memo(From, To, Pref, Best), !.
best_flights(From, To, Pref, Best) :-
    best_routes(From, To, Pref, 2, Best),
    assertz(flight_memo(From, To, Pref, Best)).

compare_search(From, To, Pref, DF, BF) :-
    reset_search,
    findall(K - L, (fly(From, To, L), \+ L = [], flight_key(Pref, L, K)), Pairs),
    insort(Pairs, _),
    steps(DF),
    reset_search,
    best_routes(From, To, Pref, 2, _),
    steps(BF).

clear_live :- retract(live_fare(_, _, _)), fail.
clear_live :- retract(live_departure(_, _)), fail.
clear_live :- retract(live_offer(_, _, _, _, _, _)), fail.
clear_live.

%DFS — in-country city tour
linked(A, B, Mode, Price, Minutes) :- ground(A, B, Mode, Price, Minutes).
linked(A, B, Mode, Price, Minutes) :- ground(B, A, Mode, Price, Minutes).

tour(Start, Max, [Start | Cities], Moves) :- tour(Start, Max, [Start], Cities, Moves).

round_tour(Start, Max, Cities, Moves) :- tour(Start, Max, Cities, Moves).
round_tour(Start, Max, Cities1, Moves1) :-
    tour(Start, Max, Cities, Moves),
    listlen(Cities, K), K >= 2,
    last_elem(Cities, Last),
    linked(Last, Start, Mode, Price, Minutes),
    ground_ok(Mode),
    append(Cities, [Start], Cities1),
    append(Moves, [move(Last, Start, Mode, Price, Minutes)], Moves1).

tour(_, _, _, [], []).
tour(Here, Max, Trail, [Next | Cities], [move(Here, Next, Mode, Price, Minutes) | Moves]) :-
    listlen(Trail, N),
    N < Max,
    linked(Here, Next, Mode, Price, Minutes),
    ground_ok(Mode),
    \+ member(Next, Trail),
    tour(Next, Max, [Next | Trail], Cities, Moves).

%PLANNING — days, activities (slot & zone search + alternatives) and money
likes(Cat, Interests) :- member(Cat, Interests).

matches(City, Interests, N) :-
    findall(x, (attraction(City, _, Cat, _, _, _, _, _), likes(Cat, Interests)), Xs),
    listlen(Xs, N).

matching_categories(City, Interests, Cats) :-
    findall(Cat, (attraction(City, _, Cat, _, _, _, _, _), likes(Cat, Interests)), Cs),
    no_dups(Cs, Cats).

% --- Search-based daily attraction scheduler (respects time window, slot ordering & zone clustering)
slot_rank(morning,   1).
slot_rank(any,       2).
slot_rank(afternoon, 2).
slot_rank(evening,   3).
slot_rank(all_day,   1).

slot_allowed(all_day,   full,      _) :- !.
slot_allowed(all_day,   _,         _) :- !, fail.
slot_allowed(morning,   morning,   _) :- !.
slot_allowed(any,       morning,   _) :- !.
slot_allowed(_,         morning,   _) :- !, fail.
slot_allowed(morning,   afternoon, _) :- !, fail.
slot_allowed(_,         afternoon, _) :- !.
slot_allowed(_,         full,      _).

slot_order_ok(_, all_day) :- !, fail.
slot_order_ok(all_day, _) :- !, fail.
slot_order_ok(S1, S2) :- slot_rank(S1, R1), slot_rank(S2, R2), R1 =< R2.

schedule_day(City, Interests, Used, Hours, Window, Acts, Alts, Used1) :-
    Hours > 0,
    findall(act(Name, Cat, Fee, H, Zone, Slot, Details),
            ( attraction(City, Name, Cat, Fee, H, Zone, Slot, Details),
              likes(Cat, Interests),
              \+ member(Name, Used),
              H =< Hours,
              slot_allowed(Slot, Window, Hours) ),
            Liked),
    findall(act(Name, Cat, Fee, H, Zone, Slot, Details),
            ( attraction(City, Name, Cat, Fee, H, Zone, Slot, Details),
              \+ likes(Cat, Interests),
              \+ member(Name, Used),
              H =< Hours,
              slot_allowed(Slot, Window, Hours) ),
            Others),
    append(Liked, Others, Pool0),
    take(8, Pool0, Pool),
    findall(Score - Seq,
            ( day_seq(Pool, Hours, 3, none, none, Seq, HUsed, Switches),
              \+ Seq = [],
              seq_score(Seq, Interests, Hours, HUsed, Switches, Score) ),
            Candidates),
    Candidates \= [], !,
    best_scored_seq(Candidates, Acts),
    act_names(Acts, Names),
    append(Used, Names, Used1),
    pick_alternatives(Pool0, Used1, 3, Alts).
schedule_day(City, Interests, Used, _, _, [], Alts, Used) :-
    findall(act(Name, Cat, Fee, H, Zone, Slot, Details),
            ( attraction(City, Name, Cat, Fee, H, Zone, Slot, Details),
              likes(Cat, Interests),
              \+ member(Name, Used) ),
            Liked),
    findall(act(Name, Cat, Fee, H, Zone, Slot, Details),
            ( attraction(City, Name, Cat, Fee, H, Zone, Slot, Details),
              \+ likes(Cat, Interests),
              \+ member(Name, Used) ),
            Others),
    append(Liked, Others, Pool0),
    pick_alternatives(Pool0, Used, 3, Alts).

day_seq(_, _, 0, _, _, [], 0, 0) :- !.
day_seq([], _, _, _, _, [], 0, 0).
day_seq([A | As], RemH, Max, PrevZone, PrevSlot, [A | Rest], HUsed, Switches) :-
    A = act(_, _, _, H, Zone, Slot, _),
    H =< RemH,
    (PrevSlot = none -> true ; slot_order_ok(PrevSlot, Slot)),
    RemH1 is RemH - H,
    Max1 is Max - 1,
    (PrevZone = none -> Sw0 = 0 ; (PrevZone = Zone -> Sw0 = 0 ; Sw0 = 1)),
    (Slot = all_day ->
        Rest = [], HUsed = H, Switches = Sw0
    ;
        day_seq(As, RemH1, Max1, Zone, Slot, Rest, HRest, SwRest),
        HUsed is H + HRest,
        Switches is Sw0 + SwRest
    ).
day_seq([_ | As], RemH, Max, PrevZone, PrevSlot, Seq, HUsed, Switches) :-
    day_seq(As, RemH, Max, PrevZone, PrevSlot, Seq, HUsed, Switches).

seq_score(Seq, Interests, MaxH, HUsed, Switches, Score) :-
    findall(x, (member(act(_, Cat, _, _, _, _, _), Seq), likes(Cat, Interests)), Hits),
    listlen(Hits, NHits),
    listlen(Seq, Len),
    Idle is MaxH - HUsed,
    Score is NHits * 100 + Len * 20 - Switches * 25 - Idle * 2.

best_scored_seq([S - Seq | Rest], Best) :- best_scored_seq(Rest, S, Seq, Best).
best_scored_seq([], _, Best, Best).
best_scored_seq([S - Seq | Rest], S0, _, Best) :-
    S > S0, !, best_scored_seq(Rest, S, Seq, Best).
best_scored_seq([_ | Rest], S0, B0, Best) :-
    best_scored_seq(Rest, S0, B0, Best).

pick_alternatives(Pool, Used, N, Alts) :-
    findall(A, (member(A, Pool), A = act(Name, _, _, _, _, _, _), \+ member(Name, Used)), Unseen),
    take(N, Unseen, Alts).

act_names([], []).
act_names([act(N, _, _, _, _, _, _) | As], [N | Ns]) :- act_names(As, Ns).

arrival_hours(Clock, H) :- H0 is (1260 - Clock - 60) // 60, clamp(H0, 0, 8, H).
leaving_hours(Clock, H) :- H0 is (Clock - 180 - 540) // 60, clamp(H0, 0, 6, H).
moving_hours(Minutes, H) :- H0 is 8 - (Minutes + 59) // 60, clamp(H0, 0, 8, H).

arrival_window(Clock, afternoon) :- Clock >= 720, !.
arrival_window(_, full).

% Sharing the days between cities

range_for(City, _, 1, 1) :- gateway(City), !.
range_for(City, Seen, 1, 2) :- member(City, Seen), !.
range_for(City, _, Min, Max) :- stay_range(City, Min, Max).

pace_min(packed, Min, _, M) :- !, M0 is Min - 1, at_least(1, M0, M).
pace_min(relaxed, Min, Max, M) :- !, M0 is Min + 1, at_most(Max, M0, M).
pace_min(_, Min, _, Min).

at_least(Lo, X, Lo) :- X < Lo, !.
at_least(_, X, X).
at_most(Hi, X, Hi) :- X > Hi, !.
at_most(_, X, X).

starts([], _, _, []).
starts([C | Cs], Pace, Seen, [s(C, M, Max) | Ss]) :-
    range_for(C, Seen, Min, Max),
    pace_min(Pace, Min, Max, M),
    starts(Cs, Pace, [C | Seen], Ss).

days_used([], 0).
days_used([s(_, D, _) | Ss], T) :- days_used(Ss, T0), T is T0 + D.

% --- Greedy: day allocation
share_days(Cities, Pace, CityDays, Shares) :-
    starts(Cities, Pace, [], S0),
    days_used(S0, Used),
    Spare is CityDays - Used,
    Spare >= 0,
    add_days(Spare, S0, S1),
    as_pairs(S1, Shares).

add_days(0, S, S) :- !.
add_days(N, S0, S) :-
    roomiest(S0, 1, 0, 0, Pos), !,
    bump(S0, Pos, S1),
    N1 is N - 1,
    add_days(N1, S1, S).
add_days(1, S0, S) :-
    biggest(S0, 1, 0, 0, Pos),
    bump(S0, Pos, S).

roomiest([], _, Room, Pos, Pos) :- Room > 0.
roomiest([s(_, D, Max) | Ss], I, Best, _, Pos) :-
    Room is Max - D, Room > Best, !,
    I1 is I + 1, roomiest(Ss, I1, Room, I, Pos).
roomiest([_ | Ss], I, Best, BestPos, Pos) :-
    I1 is I + 1, roomiest(Ss, I1, Best, BestPos, Pos).

biggest([], _, _, Pos, Pos).
biggest([s(_, _, Max) | Ss], I, Best, _, Pos) :-
    Max > Best, !,
    I1 is I + 1, biggest(Ss, I1, Max, I, Pos).
biggest([_ | Ss], I, Best, BestPos, Pos) :-
    I1 is I + 1, biggest(Ss, I1, Best, BestPos, Pos).

bump([s(C, D, M) | Ss], 1, [s(C, D1, M) | Ss]) :- !, D1 is D + 1.
bump([X | Ss], Pos, [X | Rest]) :- Pos1 is Pos - 1, bump(Ss, Pos1, Rest).

as_pairs([], []).
as_pairs([s(C, D, _) | Ss], [C - D | Ps]) :- as_pairs(Ss, Ps).

% --- Itinerary assembly & total cost (no mock hotel pricing)
build_plan(Home, Country, Days, People, Interests, Pace, Out, Cities, Moves, Ret,
           plan(Country, Out, Cities, Moves, Ret, DayList, costs(Fl, Gr, Da, Fe, Total),
                meta(Landed, FlightMin, Enjoy, Free))) :-
    last_elem(Out, leg(_, _, First, _, Arr, _, _)),
    local_time(First, Arr, LandDay, LandClock),
    Landed is LandDay + 1,
    CityDays is Days - Landed,
    CityDays >= 1,
    share_days(Cities, Pace, CityDays, Shares),
    arrival_hours(LandClock, ArrHours),
    arrival_window(LandClock, ArrWin),
    Ret = [leg(_, Last, _, RetDep, _, _, _) | _],
    local_time(Last, RetDep, _, RetClock),
    leaving_hours(RetClock, LeaveHours),
    flight_days(Home, Out, Landed, FlightDays),
    city_days(Shares, Moves, Landed, ArrHours, ArrWin, Interests, [], CityDays0, Used),
    same_day_landing(Landed, Out, CityDays0, CityDayList),
    schedule_day(Last, Interests, Used, LeaveHours, morning, LastActs, LastAlts, _),
    append(FlightDays, CityDayList, D1),
    append(D1, [day(Days, home, Last, flights(Ret), LastActs, LastAlts)], DayList),
    legs_price(Out, P1), legs_price(Ret, P2),
    Fl is (P1 + P2) * People,
    moves_price(Moves, MP), Gr is MP * People,
    country(Country, _, _, Daily), Da is Daily * People * CityDays,
    fees(DayList, F), Fe is F * People,
    Total is Fl + Gr + Da + Fe,
    legs_minutes(Out, M1), legs_minutes(Ret, M2), FlightMin is M1 + M2,
    enjoyment(DayList, Interests, Enjoy),
    free_days(DayList, Free).

free_days(Days, N) :- findall(x, member(day(_, free, _, _, _, _), Days), Xs), listlen(Xs, N).

flight_days(_, _, 1, []) :- !.
flight_days(Home, Out, Landed, [day(1, fly, Home, flights(Out), [], []) | Air]) :-
    in_air(2, Landed, Air).

same_day_landing(1, Out, [day(1, arrive, City, none, Acts, Alts) | Ds],
                 [day(1, arrive, City, flights(Out), Acts, Alts) | Ds]) :- !.
same_day_landing(_, _, Ds, Ds).

in_air(N, Landed, []) :- N >= Landed, !.
in_air(N, Landed, [day(N, air, none, none, [], []) | Rest]) :- N1 is N + 1, in_air(N1, Landed, Rest).

city_days([], _, _, _, _, _, Used, [], Used).
city_days([City - D | Shares], Moves, N, Hours, Win, Interests, Used0, Days, Used) :-
    stay_days(City, D, N, Hours, Win, first, Interests, Used0, Here, N1, Used1),
    next_city(Moves, Shares, Moves1, Hours1, Win1),
    city_days(Shares, Moves1, N1, Hours1, Win1, Interests, Used1, Later, Used),
    append(Here, Later, Days).

next_city([move(_, _, Mode, _, _) | Ms], _, Ms, 7, full) :- overnight(Mode), !.
next_city([move(_, _, _, _, Min) | Ms], _, Ms, Hours, Win) :- !,
    moving_hours(Min, Hours),
    (Hours =< 5 -> Win = afternoon ; Win = full).
next_city(Ms, _, Ms, 8, full).

stay_days(_, 0, N, _, _, _, _, Used, [], N, Used) :- !.
stay_days(City, D, N, Hours, Win, Kind, Interests, Used0, [day(N, Kind1, City, Travel, Acts, Alts) | Days], NOut, Used) :-
    schedule_day(City, Interests, Used0, Hours, Win, Acts, Alts, Used1),
    day_kind(Kind, Acts, Kind1, Travel),
    D1 is D - 1, N1 is N + 1,
    stay_days(City, D1, N1, 8, full, later, Interests, Used1, Days, NOut, Used).

day_kind(first, _, arrive, none).
day_kind(later, [], free, none) :- !.
day_kind(later, _, explore, none).

attach_moves(Days, Moves, Out) :- attach(Days, first, Moves, Out).

attach([], _, _, []).
attach([day(N, arrive, City, T, A, Alts) | Ds], first, Ms, [day(N, arrive, City, T, A, Alts) | Rest]) :- !,
    attach(Ds, later, Ms, Rest).
attach([day(N, arrive, City, none, A, Alts) | Ds], later, [move(F, City, M, P, Min) | Ms],
       [day(N, move, City, ground(F, City, M, P, Min), A, Alts) | Rest]) :- !,
    attach(Ds, later, Ms, Rest).
attach([D | Ds], Flag, Ms, [D | Rest]) :- attach(Ds, Flag, Ms, Rest).

moves_price([], 0).
moves_price([move(_, _, _, P, _) | Ms], T) :- moves_price(Ms, T0), T is T0 + P.

fees(Days, Total) :-
    findall(F, (member(day(_, _, _, _, Acts, _), Days), member(act(_, _, F, _, _, _, _), Acts)), Fs),
    sum(Fs, Total).

sum([], 0).
sum([X | Xs], T) :- sum(Xs, T0), T is T0 + X.

enjoyment(Days, Interests, E) :-
    findall(x, (member(day(_, _, _, _, Acts, _), Days), member(act(_, Cat, _, _, _, _, _), Acts), likes(Cat, Interests)), Xs),
    listlen(Xs, E).

%RANKING
% --- Utility scoring & ranking

plan_total(plan(_, _, _, _, _, _, costs(_, _, _, _, T), _), T).

plan_key(cheapest, P, K) :- plan_total(P, K).
plan_key(fastest, P, K) :-
    P = plan(_, _, _, _, _, _, _, meta(_, Min, _, _)), plan_total(P, T), K is Min * 1000 + T.
plan_key(fewest, P, K) :-
    P = plan(_, Out, _, _, Ret, _, _, _), listlen(Out, A), listlen(Ret, B),
    plan_total(P, T), K is (A + B) * 10000000 + T.
plan_key(balanced, P, K) :-
    P = plan(_, _, _, _, _, _, _, meta(_, Min, Enjoy, _)), plan_total(P, T),
    K is T + Min * 10 - Enjoy * 1500.

score(Pref, P, K) :-
    plan_key(Pref, P, K0),
    P = plan(_, _, _, _, _, Days, costs(_, _, _, _, T), meta(_, _, _, Free)),
    listlen(Days, N),
    K is K0 + Free * T // N.

rank(Pref, Plans, Ranked) :-
    keyed(Pref, Plans, Pairs), insort(Pairs, Sorted), values(Sorted, Ranked).

keyed(_, [], []).
keyed(Pref, [P | Ps], [K - P | KPs]) :- score(Pref, P, K), keyed(Pref, Ps, KPs).

best_plan(Pref, [P | Ps], Best) :- score(Pref, P, K), best_plan(Pref, Ps, K, P, Best).
best_plan(_, [], _, Best, Best).
best_plan(Pref, [P | Ps], K0, _, Best) :-
    score(Pref, P, K), K < K0, !, best_plan(Pref, Ps, K, P, Best).
best_plan(Pref, [_ | Ps], K0, B0, Best) :- best_plan(Pref, Ps, K0, B0, Best).

% --- Budget filter, city diversity & best per country
affordable(_, [], []).
affordable(Budget, [P | Ps], [P | As]) :- plan_total(P, T), T =< Budget, !, affordable(Budget, Ps, As).
affordable(Budget, [_ | Ps], As) :- affordable(Budget, Ps, As).

different(_, [], []).
different(0, _, []) :- !.
different(N, [P | Ps], [P | Rest]) :-
    P = plan(_, _, Cities, _, _, _, _, _),
    drop_same(Ps, Cities, Ps1),
    N1 is N - 1,
    different(N1, Ps1, Rest).

drop_same([], _, []).
drop_same([plan(_, _, Cities, _, _, _, _, _) | Ps], Cities, Rest) :- !, drop_same(Ps, Cities, Rest).
drop_same([P | Ps], Cities, [P | Rest]) :- drop_same(Ps, Cities, Rest).

in_country(Country, plan(Country, _, _, _, _, _, _, _)).

country_plans(_, [], []).
country_plans(C, [P | Ps], [P | Rest]) :- in_country(C, P), !, country_plans(C, Ps, Rest).
country_plans(C, [_ | Ps], Rest) :- country_plans(C, Ps, Rest).

best_per_country(_, [], _, []).
best_per_country(Pref, [C | Cs], Plans, [K - Best | Rest]) :-
    country_plans(C, Plans, Mine), \+ Mine = [], !,
    best_plan(Pref, Mine, Best),
    plan_total(Best, T),
    Best = plan(_, _, _, _, _, _, _, meta(_, _, Enjoy, _)),
    K is T - Enjoy * 3000,
    best_per_country(Pref, Cs, Plans, Rest).
best_per_country(Pref, [_ | Cs], Plans, Rest) :- best_per_country(Pref, Cs, Plans, Rest).

%REASONS

reasons(OriginCountry, Dest, Pref, Index, Count, Budget, Days, Month, Interests, Plan, Reasons) :-
    Plan = plan(Country, Out, Cities, _, Ret, _, costs(_, _, _, _, Total), meta(Landed, _, Enjoy, Free)),
    rank_reason(Dest, Pref, Index, Count, Country, Enjoy, R1),
    budget_reason(Budget, Total, R2),
    flight_reason(out, Out, R3),
    flight_reason(back, Ret, R4),
    free_reason(Free, R5),
    append(Out, Ret, Legs),
    fares_reason(Legs, R6),
    findall(R, option_reason(Cities, R), R7c),
    findall(R, twin_reason(Out, Ret, R), R7e),
    append(R7c, R7e, R7),
    findall(R, extra_reason(OriginCountry, Country, Days, Month, Landed, Cities, Interests, R), Rs),
    append([R1, R2, R3, R4, R5, R6], R7, Head),
    append(Head, Rs, Reasons).

twin_reason([leg(_, Home, _, _, _, _, _) | _], Ret, [other_airport, Home, Land]) :-
    last_elem(Ret, leg(_, _, Land, _, _, _, _)),
    twin(Home, Land).

option_reason(_, [max_flights, N]) :- opt(max_flights, N), N < 3.
option_reason(_, [airlines, A]) :- opt(airlines, A), \+ A = any.
option_reason(_, [no_night_flights]) :- opt(night_flights, avoid).
option_reason(_, [your_cities]) :- opt(cities, Ms), \+ Ms = [].
option_reason(_, [getting_around, G]) :- opt(getting_around, G), \+ G = any.
option_reason(Cities, [gateway, G]) :- no_dups(Cities, Unique), member(G, Unique), gateway(G).

fares_reason(Legs, [live_fares, N, Total]) :-
    findall(x, (member(leg(_, F, T, _, _, _, _), Legs), (live_offer(F, T, _, _, _, _) ; live_fare(F, T, _))), Xs),
    listlen(Xs, N), N > 0, !,
    listlen(Legs, Total).
fares_reason(_, [sample_fares]).

free_reason(0, [no_free_days]) :- !.
free_reason(N, [free_days, N]).

rank_reason(anywhere, _, _, _, Country, Enjoy, [anywhere, Country, Enjoy]) :- !.
rank_reason(_, Pref, 1, Count, _, _, [best, Pref, Count]) :- !.
rank_reason(_, _, Index, _, _, _, [alternative, Index]).

budget_reason(Budget, Total, [under_budget, Spare]) :- Total =< Budget, !, Spare is Budget - Total.
budget_reason(Budget, Total, [over_budget, Over]) :- Over is Total - Budget.

flight_reason(Way, [leg(Code, From, To, _, _, _, _)], [direct, Way, Code, From, To]) :- !.
flight_reason(Way, [_, leg(_, Hub, _, _, _, _, Wait) | _], [change, Way, Hub, Wait]).

extra_reason(_, _, _, _, Landed, _, _, [overnight]) :- Landed > 1.
extra_reason(_, _, _, _, _, Cities, _, [open_jaw, First, Last]) :-
    Cities = [First | _], last_elem(Cities, Last), \+ First = Last.
extra_reason(_, _, _, _, _, Cities, Interests, [city, City, N, Cats]) :-
    no_dups(Cities, Unique),
    member(City, Unique), matches(City, Interests, N), N > 0,
    matching_categories(City, Interests, Cats).
extra_reason(thailand, Country, Days, _, _, _, _, [visa_ok, Country, Max]) :-
    visa_free(Country, Max), Days =< Max.
extra_reason(thailand, Country, Days, _, _, _, _, [visa_too_short, Country, Max]) :-
    visa_free(Country, Max), Days > Max.
extra_reason(OriginCountry, Country, _, Month, _, _, _, [prices, Country, Month, Fly]) :-
    flight_level(OriginCountry, Country, Month, Fly),
    \+ Fly =:= 100.
extra_reason(thailand, _, _, Month, _, _, _, [thai_holiday, Name]) :-
    thai_holiday(Months, _, Name), member(Month, Months).
extra_reason(_, Country, _, Month, _, _, _, [highlight, Country, What]) :-
    highlight(Country, What, Months), member(Month, Months).
extra_reason(_, Country, _, Month, _, _, _, [warning, Country, What]) :-
    warning(Country, What, Months), member(Month, Months).

%API
normalize_interests([], All) :- !, findall(I, interest(I), All).
normalize_interests(Is, Is).

countries_for(OriginCountry, anywhere, Cs) :- !, findall(C, destination(OriginCountry, C), Cs).
countries_for(_, C, [C]).

% --- Backtracking template: 1 candidate plan
candidate(Home, Country, Days, People, Interests, Pace, Pref, Plan) :-
    city(Arrive, _, _, _, Country, _, _),
    airport(Arrive, _),
    best_flights(Home, Arrive, Pref, Outs),
    member(Out, Outs),
    round_tour(Arrive, 4, Cities, Moves),
    chosen_ok(Country, Cities),
    last_elem(Cities, Last),
    airport(Last, _),
    home_airport(Home, Land),
    best_flights(Last, Land, Pref, Rets),
    member(Ret, Rets),
    build_plan(Home, Country, Days, People, Interests, Pace, Out, Cities, Moves, Ret, Plan0),
    Plan0 = plan(C, O, Cs, Ms, R, Ds, Costs, Meta),
    attach_moves(Ds, Ms, Ds1),
    Plan = plan(C, O, Cs, Ms, R, Ds1, Costs, Meta).

home_airport(Home, Home).
home_airport(Home, Other) :- twin(Home, Other).

% --- Main entry: plan_trip (findall -> filter -> score -> Top 3)
plan_trip(Home, Dest, Days, Month, People, Budget, Interests, Pace, Pref, Result) :-
    plan_trip(Home, Dest, Days, Month, People, Budget, Interests, Pace, Pref, [], Result).

plan_trip(Home, Dest, Days, Month, People, Budget, Interests0, Pace, Pref, Options, [Stats, Rows]) :-
    city(Home, _, _, _, OriginCountry, _, _),
    normalize_interests(Interests0, Interests),
    reset_search,
    set_month(Month),
    set_options(Options),
    countries_for(OriginCountry, Dest, Countries),
    findall(P, (member(C, Countries), candidate(Home, C, Days, People, Interests, Pace, Pref, P)), Plans),
    listlen(Plans, NPlans),
    affordable(Budget, Plans, Cheap),
    listlen(Cheap, NCheap),
    pool(Cheap, Plans, Pool),
    choose(Dest, Pref, Countries, Pool, Chosen),
    rows(Chosen, 1, OriginCountry, Dest, Pref, NPlans, Budget, Days, Month, Interests, Rows),
    steps(Steps),
    findall([A, B], explored(A, B), Edges),
    findall(x, (flight_memo(_, _, _, Best), member(_, Best)), Fs), listlen(Fs, NFlights),
    Stats = [Steps, Edges, NFlights, NPlans, NCheap].

pool([], Plans, Plans) :- !.
pool(Cheap, _, Cheap).

choose(anywhere, Pref, Countries, Pool, Chosen) :- !,
    best_per_country(Pref, Countries, Pool, Pairs),
    insort(Pairs, Sorted), values(Sorted, Ranked),
    take(3, Ranked, Chosen).
choose(_, Pref, _, Pool, Chosen) :-
    rank(Pref, Pool, Ranked),
    different(3, Ranked, Chosen).

rows([], _, _, _, _, _, _, _, _, _, []).
rows([P | Ps], I, OriginCountry, Dest, Pref, Count, Budget, Days, Month, Interests, [Row | Rest]) :-
    reasons(OriginCountry, Dest, Pref, I, Count, Budget, Days, Month, Interests, P, Reasons),
    plan_row(P, Budget, Reasons, Row),
    I1 is I + 1,
    rows(Ps, I1, OriginCountry, Dest, Pref, Count, Budget, Days, Month, Interests, Rest).

plan_row(plan(Country, Out, Cities, Moves, Ret, Days, costs(Fl, Gr, Da, Fe, T), meta(Landed, Min, Enjoy, Free)),
         Budget, Reasons,
         [Country, OutRows, Cities, MoveRows, RetRows, DayRows, [Fl, Gr, Da, Fe, T], Fits, Reasons,
          [Landed, Min, Enjoy, Free]]) :-
    leg_rows(Out, OutRows),
    leg_rows(Ret, RetRows),
    move_rows(Moves, MoveRows),
    day_rows(Days, DayRows),
    fits(T, Budget, Fits).

fits(T, Budget, yes) :- T =< Budget, !.
fits(_, _, no).

leg_rows([], []).
leg_rows([leg(C, F, T, D, A, P, W) | Ls], [[C, AName, ATier, F, T, D, A, P, W] | Rs]) :-
    airline_name(C, AName),
    airline_tier(C, ATier),
    leg_rows(Ls, Rs).

move_rows([], []).
move_rows([move(F, T, M, P, Min) | Ms], [[F, T, M, P, Min] | Rs]) :- move_rows(Ms, Rs).

day_rows([], []).
day_rows([day(N, Kind, City, Travel, Acts, Alts) | Ds], [[N, Kind, City, TravelRow, ActRows, AltRows] | Rs]) :-
    travel_row(Travel, TravelRow),
    act_rows(Acts, ActRows),
    act_rows(Alts, AltRows),
    day_rows(Ds, Rs).

travel_row(none, none).
travel_row(flights(Legs), [flights, Rows]) :- leg_rows(Legs, Rows).
travel_row(ground(F, T, M, P, Min), [ground, F, T, M, P, Min]).

act_rows([], []).
act_rows([act(N, C, F, H, Z, S, D) | As], [[N, C, F, H, Z, S, D] | Rs]) :- act_rows(As, Rs).

% --- Airline choices per leg (called after plan selection so user can pick an airline)
route_choices(Home, From, To, Choices) :-
    city(Home, _, _, _, OriginCountry, _, _),
    findall(Price - [Code, AName, ATier, DepUTC, ArrUTC, Price],
            ( route_edge(OriginCountry, From, To, Code, HHMM, Minutes, Price),
              airline_ok(Code, From, To),
              daytime_ok(HHMM),
              to_utc(From, HHMM, DepUTC),
              ArrUTC is DepUTC + Minutes,
              airline_name(Code, AName),
              airline_tier(Code, ATier) ),
            Pairs),
    insort(Pairs, Sorted),
    values(Sorted, Raw),
    dedup_airlines(Raw, [], Choices).

dedup_airlines([], _, []).
dedup_airlines([[_, AName | _] | Rs], Seen, Out) :-
    member(AName, Seen), !,
    dedup_airlines(Rs, Seen, Out).
dedup_airlines([[Code, AName, ATier, D, A, P] | Rs], Seen, [[Code, AName, ATier, D, A, P] | Out]) :-
    dedup_airlines(Rs, [AName | Seen], Out).

% --- Export static map data to Python
map_data(Countries, Cities, Flights, Ground) :-
    findall([Id, Name, Thai, Daily, Visa],
            (country(Id, Name, Thai, Daily), visa_days(Id, Visa)), Countries),
    findall([Id, Name, Thai, Code, Country, Lat, Lon, Zone],
            (city(Id, Name, Thai, Code, Country, Lat, Lon), zone(Id, Zone)), Cities),
    findall([Code, From, To, Dep, Min, Price], flight(Code, From, To, Dep, Min, Price), Flights),
    findall([A, B, M, P, Min], ground(A, B, M, P, Min), Ground).

visa_days(C, D) :- visa_free(C, D), !.
visa_days(_, none).

zone(City, Z) :- airport(City, Z), !.
zone(_, none).
