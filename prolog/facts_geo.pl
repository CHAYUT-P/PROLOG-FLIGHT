% GEOGRAPHY, AIRLINES & TRANSPORT FACTS
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
flight('NH848', bangkok, tokyo,        935, 355, 14800).
flight('JL034', bangkok, tokyo,       2205, 345, 15200).
flight('ZG052', bangkok, tokyo,       2345, 360,  8900).
flight('XJ600', don_mueang, tokyo,        745, 355,  7900).
flight('FD234', don_mueang, tokyo,       1420, 370,  8200).
flight('TG622', bangkok, osaka,       2350, 330, 12500).
flight('JL892', bangkok, osaka,        815, 335, 13900).
flight('MM092', bangkok, osaka,        110, 335,  7600).
flight('XJ610', don_mueang, osaka,        105, 330,  7200).
flight('XJ620', don_mueang, sapporo,       50, 405,  9800).
flight('TG656', bangkok, seoul,       2330, 330, 11000).
flight('KE652', bangkok, seoul,       2240, 325, 12400).
flight('OZ742', bangkok, seoul,        115, 330, 11800).
flight('7C2204', bangkok, seoul,       225, 320,  6900).
flight('BX726', bangkok, busan,         50, 330,  7500).
flight('MU548', bangkok, shanghai,     115, 270,  7200).
flight('CA960', bangkok, beijing,       55, 300,  8400).
flight('FD558', don_mueang, xian,        1955, 265,  6500).
flight('SQ711', bangkok, singapore,    950, 145,  6500).
flight('TG403', bangkok, singapore,    800, 145,  6200).
flight('TR869', don_mueang, singapore,    720, 145,  3400).
% --- back to Bangkok
flight('TG683', tokyo,        bangkok, 1030, 405, 13500).
flight('NH847', tokyo,        bangkok, 1050, 400, 14800).
flight('JL031', tokyo,        bangkok, 1120, 405, 15200).
flight('ZG051', tokyo,        bangkok, 1700, 410,  8900).
flight('XJ601', tokyo,        don_mueang, 1700, 415,  7900).
flight('TG623', osaka,        bangkok, 1100, 375, 12500).
flight('JL891', osaka,        bangkok, 1745, 385, 13900).
flight('MM091', osaka,        bangkok, 1930, 380,  7600).
flight('XJ611', osaka,        don_mueang, 1645, 380,  7400).
flight('XJ621', sapporo,      don_mueang,  950, 480,  9800).
flight('TG657', seoul,        bangkok, 1940, 360, 11000).
flight('KE651', seoul,        bangkok, 1715, 365, 12400).
flight('OZ741', seoul,        bangkok, 1920, 360, 11800).
flight('7C2203', seoul,       bangkok, 2010, 365,  6900).
flight('BX725', busan,        bangkok, 1940, 365,  7500).
flight('MU547', shanghai,     bangkok, 1810, 300,  7200).
flight('CA959', beijing,      bangkok, 1720, 340,  8400).
flight('FD559', xian,         don_mueang,   30, 285,  6500).
flight('SQ706', singapore,    bangkok,  745, 145,  6500).
flight('TG404', singapore,    bangkok, 1225, 145,  6200).
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

