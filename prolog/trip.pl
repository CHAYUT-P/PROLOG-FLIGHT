/*  trip.pl — Tang (ทาง): an Asia trip planner for travellers from Thailand.

    Written only with what "Programming in Prolog" (Clocksin & Mellish)
    teaches, so every line can be traced back to the book:

      ch.1   facts, rules, questions
      ch.2   arithmetic:  is  +  -  *  //  mod  <  =<
      ch.3   lists, recursion, accumulators  (member, append)
      ch.4   backtracking and the cut  !
      ch.6   \+  ;  asserta / assertz / retract
      ch.7   findall (7.8), insertion sort (7.7), graph search with a trail (7.9)

    Sections
      1. Facts        countries, cities, flights, ground transport, attractions
      2. Helpers      small list predicates written the book's way
      3. Time         clock times, time zones, connections
      4. Search       flights (with one change) and city tours
      5. Planning     days, activities, costs
      6. Ranking      cheapest / fastest / fewest flights / balanced
      7. Reasons      why each plan was chosen
      8. API          the predicates Python calls
*/

:- dynamic(explored/2).       % explored(From, To): flights the search looked at
:- dynamic(steps/1).          % steps(N): how many search steps so far
:- dynamic(flight_memo/4).    % flight_memo(From, To, Pref, Best): remembered answers
:- dynamic(trip_month/1).     % trip_month(M): the month of the trip being planned
:- dynamic(live_fare/3).      % live_fare(From, To, PriceTHB): real fares Python fetched
:- dynamic(live_departure/2). % live_departure(Code, HHMM): real departure time for that day
:- dynamic(option/2).         % option(Name, Value): the traveller's extra choices

% ===========================================================================
% 1. FACTS
% ===========================================================================

%% country(Id, Name, ThaiName, DailyCostTHB)
%  DailyCost = food + local transport for one person for one day.
country(thailand,    'Thailand',    'ไทย',          0).
country(japan,       'Japan',       'ญี่ปุ่น',        1500).
country(korea,       'South Korea', 'เกาหลีใต้',      1200).
country(china,       'China',       'จีน',          900).
country(singapore,   'Singapore',   'สิงคโปร์',       1400).

destination(C) :- country(C, _, _, _), \+ C = thailand.

%% visa_free(Country, Days): how long a Thai passport holder may stay without a visa.
%  Sample data — rules change, so always check before travelling.
visa_free(japan, 15).  visa_free(korea, 90).
visa_free(china, 30).
visa_free(singapore, 30).

%% city(Id, Name, ThaiName, Code, Country, Latitude, Longitude)
city(bangkok,      'Bangkok',          'กรุงเทพฯ',       'BKK', thailand,    13.69, 100.75).
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

home(bangkok).  home(chiang_mai).  home(phuket).

%% airport(City, TimeZone): cities with international flights, and their UTC offset.
airport(bangkok, 7).   airport(chiang_mai, 7).  airport(phuket, 7).
airport(tokyo, 9).     airport(osaka, 9).       airport(sapporo, 9).
airport(seoul, 9).     airport(busan, 9).
airport(shanghai, 8).  airport(beijing, 8).     airport(xian, 8).
airport(singapore, 8).

%% flight(Code, From, To, DepartLocalHHMM, Minutes, PriceTHB)
%  One-way economy, flies every day. Sample prices.
% --- from Bangkok
flight('TG682', bangkok, tokyo,       2245, 345, 13500).
flight('XJ600', bangkok, tokyo,        745, 355,  7900).
flight('TG622', bangkok, osaka,       2350, 330, 12500).
flight('XJ610', bangkok, osaka,        105, 330,  7200).
flight('XJ620', bangkok, sapporo,       50, 405,  9800).
flight('TG656', bangkok, seoul,       2330, 330, 11000).
flight('7C2204', bangkok, seoul,       225, 320,  6900).
flight('BX726', bangkok, busan,         50, 330,  7500).
flight('MU548', bangkok, shanghai,     115, 270,  7200).
flight('CA960', bangkok, beijing,       55, 300,  8400).
flight('FD558', bangkok, xian,        1955, 265,  6500).
flight('SQ711', bangkok, singapore,    950, 145,  6500).
flight('TR869', bangkok, singapore,    720, 145,  3400).
% --- back to Bangkok
flight('TG683', tokyo,        bangkok, 1030, 405, 13500).
flight('XJ601', tokyo,        bangkok, 1700, 415,  7900).
flight('TG623', osaka,        bangkok, 1100, 375, 12500).
flight('XJ611', osaka,        bangkok, 1645, 380,  7400).
flight('XJ621', sapporo,      bangkok,  950, 480,  9800).
flight('TG657', seoul,        bangkok, 1940, 360, 11000).
flight('7C2203', seoul,       bangkok, 2010, 365,  6900).
flight('BX725', busan,        bangkok, 1940, 365,  7500).
flight('MU547', shanghai,     bangkok, 1810, 300,  7200).
flight('CA959', beijing,      bangkok, 1720, 340,  8400).
flight('FD559', xian,         bangkok,   30, 285,  6500).
flight('SQ706', singapore,    bangkok,  745, 145,  6500).
flight('TR868', singapore,    bangkok, 1805, 145,  3400).
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
% --- connections between hubs
flight('KE705', seoul,        tokyo,      850, 140,  5200).
flight('KE706', tokyo,        seoul,     1300, 160,  5200).
flight('SQ636', singapore,    tokyo,      745, 400, 11900).
flight('SQ637', tokyo,        singapore, 1105, 435, 11900).
flight('MU523', shanghai,     tokyo,      855, 180,  5900).
flight('MU524', tokyo,        shanghai,  1335, 210,  5900).

%% ground(A, B, Mode, PriceTHB, Minutes): travel inside a country, both directions.
%  Typical one-way adult fares (mock data). Modes:
%    high_speed   Shinkansen, KTX, Taiwan HSR, China's bullet trains
%    train        ordinary / limited express trains
%    bus          day coach            ferry        day boat
%    night_bus, night_train, night_ferry   overnight: you sleep on board
%    plane        domestic flight
% --- Japan
ground(tokyo,     kyoto,       high_speed, 3300, 135).   % Shinkansen Nozomi
ground(tokyo,     kyoto,       night_bus,  1000, 480).   % Willer Express overnight
ground(tokyo,     osaka,       high_speed, 3400, 150).
ground(tokyo,     osaka,       night_bus,  1000, 510).
ground(tokyo,     osaka,       plane,      1800,  70).   % Peach / Jetstar
ground(kyoto,     osaka,       train,       150,  30).   % JR Special Rapid
ground(tokyo,     sapporo,     plane,      3500, 100).
ground(osaka,     sapporo,     plane,      3800, 125).
% --- South Korea
ground(seoul,     busan,       high_speed, 1400, 150).   % KTX
ground(seoul,     busan,       bus,         700, 260).
ground(seoul,     jeju,        plane,      1500,  70).
ground(busan,     jeju,        plane,      1300,  60).
ground(busan,     jeju,        night_ferry,1200, 720).
% --- China
ground(shanghai,  beijing,     high_speed, 2800, 270).
ground(shanghai,  beijing,     night_train,1800, 720).   % sleeper berth
ground(beijing,   xian,        high_speed, 2600, 270).
ground(beijing,   xian,        night_train,1500, 720).
ground(shanghai,  xian,        high_speed, 3000, 360).

%% overnight(Mode): you travel at night and sleep on board — no hotel that night.
overnight(night_bus).  overnight(night_train).  overnight(night_ferry).

%% stay(City, PricePerNightTHB): one mid-range room for two people.
stay(tokyo, 3200).     stay(kyoto, 2900).      stay(osaka, 2600).     stay(sapporo, 2400).
stay(seoul, 2200).     stay(busan, 1900).      stay(jeju, 2000).
stay(shanghai, 2200).  stay(beijing, 2100).    stay(xian, 1500).
stay(singapore, 3800).

%% attraction(City, Name, Category, FeeTHB, Hours)
attraction(tokyo, 'Senso-ji Temple',          culture,      0, 2).
attraction(tokyo, 'Tsukiji Outer Market',     food,       600, 2).
attraction(tokyo, 'Shibuya and Harajuku',     shopping,     0, 3).
attraction(tokyo, 'teamLab Planets',          adventure,  900, 2).
attraction(tokyo, 'Shinjuku izakaya alleys',  nightlife,  800, 2).
attraction(tokyo, 'Mount Takao hike',         nature,     300, 5).
attraction(tokyo, 'Meiji Shrine', culture, 0, 1.5).
attraction(tokyo, 'Akihabara electronics town', shopping, 0, 3).
attraction(tokyo, 'Tokyo Skytree', adventure, 1000, 2).
attraction(tokyo, 'Ueno Park and museums', culture, 300, 3).
attraction(tokyo, 'Odaiba waterfront', shopping, 0, 3).
attraction(tokyo, 'Ginza', shopping, 0, 2).
attraction(tokyo, 'Shinjuku Gyoen garden', nature, 150, 2).
attraction(tokyo, 'Tokyo DisneySea', adventure, 2400, 8).
attraction(tokyo, 'Mount Fuji and Lake Kawaguchi day trip', nature, 1500, 8).
attraction(tokyo, 'Kamakura day trip', culture, 600, 6).
attraction(tokyo, 'Nikko day trip', culture, 1200, 8).
attraction(tokyo, 'Sushi and ramen crawl', food, 800, 2).
attraction(tokyo, 'Golden Gai bars', nightlife, 600, 2).
attraction(tokyo, 'Tokyo Tower', culture, 300, 1.5).
attraction(kyoto, 'Fushimi Inari Shrine',     culture,      0, 3).
attraction(kyoto, 'Arashiyama Bamboo Grove',  nature,       0, 2).
attraction(kyoto, 'Kinkaku-ji',               culture,    120, 1.5).
attraction(kyoto, 'Nishiki Market',           food,       500, 2).
attraction(kyoto, 'Kiyomizu-dera', culture, 100, 2).
attraction(kyoto, 'Gion evening walk', culture, 0, 2).
attraction(kyoto, 'Nara day trip and deer park', nature, 200, 6).
attraction(kyoto, 'Philosopher''s Path', nature, 0, 1.5).
attraction(kyoto, 'Kaiseki dinner', food, 1500, 2).
attraction(osaka, 'Dotonbori street food',    food,       600, 2).
attraction(osaka, 'Universal Studios Japan',  adventure, 2300, 8).
attraction(osaka, 'Osaka Castle',             culture,    140, 2).
attraction(osaka, 'Shinsaibashi shopping',    shopping,     0, 3).
attraction(osaka, 'Kuromon Market', food, 400, 2).
attraction(osaka, 'Umeda Sky Building', culture, 400, 1.5).
attraction(osaka, 'Kaiyukan Aquarium', adventure, 700, 3).
attraction(osaka, 'Shinsekai kushikatsu', food, 400, 2).
attraction(osaka, 'Namba nightlife', nightlife, 500, 2).
attraction(sapporo, 'Odori Park',             nature,       0, 1.5).
attraction(sapporo, 'Ramen Alley',            food,       350, 1).
attraction(sapporo, 'Otaru canal day trip',   culture,    300, 5).
attraction(sapporo, 'Mount Moiwa ropeway',    nature,     500, 2).
attraction(sapporo, 'Sapporo Beer Museum', food, 200, 2).
attraction(sapporo, 'Jozankei hot spring day trip', nature, 800, 5).
attraction(sapporo, 'Susukino nightlife', nightlife, 500, 2).

attraction(seoul, 'Gyeongbokgung Palace',     culture,     80, 2).
attraction(seoul, 'Myeongdong shopping',      shopping,     0, 3).
attraction(seoul, 'Gwangjang Market',         food,       400, 2).
attraction(seoul, 'Bukhansan hike',           nature,       0, 5).
attraction(seoul, 'Hongdae nightlife',        nightlife,  600, 3).
attraction(seoul, 'Bukchon Hanok Village', culture, 0, 2).
attraction(seoul, 'N Seoul Tower', culture, 500, 2).
attraction(seoul, 'Lotte World', adventure, 1500, 6).
attraction(seoul, 'Korean barbecue dinner', food, 600, 2).
attraction(seoul, 'DMZ tour', culture, 2000, 8).
attraction(seoul, 'Insadong', shopping, 0, 2).
attraction(seoul, 'Changdeokgung Secret Garden', nature, 200, 2).
attraction(seoul, 'Cheonggyecheon stream walk', nature, 0, 1).
attraction(busan, 'Haeundae Beach',           beach,        0, 3).
attraction(busan, 'Gamcheon Culture Village', culture,      0, 2).
attraction(busan, 'Jagalchi Fish Market',     food,       600, 2).
attraction(busan, 'Haedong Yonggungsa Temple', culture, 0, 2).
attraction(busan, 'Gwangalli bridge at night', nightlife, 0, 2).
attraction(busan, 'Taejongdae cliffs', nature, 100, 3).
attraction(jeju, 'Hallasan hike',             nature,       0, 7).
attraction(jeju, 'Seongsan Sunrise Peak',     nature,     130, 2).
attraction(jeju, 'Hyeopjae Beach',            beach,        0, 3).
attraction(jeju, 'Manjanggul lava tube', nature, 150, 2).
attraction(jeju, 'Black pork barbecue', food, 600, 2).
attraction(jeju, 'Udo Island', beach, 300, 5).



attraction(shanghai, 'The Bund',              culture,      0, 2).
attraction(shanghai, 'Yu Garden',             culture,    200, 2).
attraction(shanghai, 'Nanjing Road',          shopping,     0, 3).
attraction(shanghai, 'Xiaolongbao crawl',     food,       400, 2).
attraction(shanghai, 'Zhujiajiao water town', nature,       0, 4).
attraction(shanghai, 'Shanghai Tower', adventure, 800, 2).
attraction(shanghai, 'French Concession walk', culture, 0, 3).
attraction(shanghai, 'Shanghai Disneyland', adventure, 2700, 8).
attraction(beijing, 'Great Wall at Mutianyu', adventure,  600, 6).
attraction(beijing, 'Forbidden City',         culture,    300, 4).
attraction(beijing, 'Peking duck dinner',     food,       900, 2).
attraction(beijing, 'Summer Palace',          nature,     150, 3).
attraction(beijing, 'Temple of Heaven', culture, 150, 2).
attraction(beijing, 'Hutong rickshaw tour', culture, 500, 2).
attraction(beijing, 'Wangfujing snack street', food, 300, 2).
attraction(xian, 'Terracotta Army',           culture,    600, 4).
attraction(xian, 'City Wall bike ride',       adventure,  250, 2).
attraction(xian, 'Muslim Quarter food street', food,      300, 2).


attraction(singapore, 'Gardens by the Bay',   nature,     700, 3).
attraction(singapore, 'Hawker centre feast',  food,       300, 2).
attraction(singapore, 'Universal Studios Singapore', adventure, 2100, 8).
attraction(singapore, 'Marina Bay Sands SkyPark', culture, 900, 1.5).
attraction(singapore, 'Orchard Road',         shopping,     0, 3).
attraction(singapore, 'Clarke Quay',          nightlife,  800, 2).
attraction(singapore, 'Sentosa beaches', beach, 0, 4).
attraction(singapore, 'Night Safari', nature, 1300, 4).
attraction(singapore, 'Chinatown and Little India', culture, 0, 3).
attraction(singapore, 'Jewel Changi', shopping, 0, 2).
attraction(singapore, 'S.E.A. Aquarium', adventure, 1100, 3).
attraction(singapore, 'Singapore Botanic Gardens', nature, 0, 2.5).
attraction(singapore, 'Singapore Flyer', culture, 900, 1.5).
attraction(singapore, 'Haji Lane and Kampong Glam', shopping, 0, 2).
attraction(singapore, 'Pulau Ubin bike day', nature, 200, 5).
attraction(singapore, 'Lau Pa Sat satay night', food, 300, 2).
attraction(singapore, 'ArtScience Museum', culture, 700, 2).
attraction(singapore, 'East Coast Park seafood', food, 900, 3).
attraction(singapore, 'Bird Paradise', nature, 1200, 4).




%% highlight(Country, What, Months) / warning(Country, What, Months)
highlight(japan, 'cherry blossom season', [3, 4]).
highlight(japan, 'autumn leaves', [11]).
highlight(japan, 'the Sapporo Snow Festival', [2]).
highlight(korea, 'cherry blossoms', [4]).
highlight(korea, 'autumn colours', [10, 11]).
highlight(china, 'mild spring weather', [4, 5]).
highlight(china, 'golden autumn', [9, 10]).
highlight(singapore, 'Chinese New Year lights', [1, 2]).

warning(japan, 'the rainy season', [6]).
warning(japan, 'typhoon season', [8, 9]).
warning(korea, 'heavy monsoon rain', [7]).
warning(korea, 'freezing winter', [12, 1, 2]).
warning(china, 'freezing winter in Beijing', [12, 1, 2]).
warning(china, 'Golden Week crowds', [10]).
warning(singapore, 'the rainy monsoon', [11, 12, 1]).

interest(nature).  interest(culture).   interest(food).  interest(shopping).
interest(beach).   interest(adventure). interest(nightlife).

%% stay_range(City, MinDays, MaxDays): how long a visit is worth.
%  Big cities need several days; small ones one or two.
stay_range(tokyo, 3, 6).      stay_range(kyoto, 2, 4).      stay_range(osaka, 2, 3).
stay_range(sapporo, 2, 3).
stay_range(seoul, 3, 5).      stay_range(busan, 2, 3).      stay_range(jeju, 2, 3).
stay_range(shanghai, 3, 4).   stay_range(beijing, 3, 4).    stay_range(xian, 2, 3).
stay_range(singapore, 3, 6).

%% busy(Country, Months, Percent): flights and hotels cost Percent more
%  (or less, if negative) in those months. Sample data based on seasons.
busy(japan,       [3, 4],        30).   % cherry blossoms
busy(japan,       [11],          15).   % autumn leaves
busy(japan,       [6],          -15).   % rainy season, fewer visitors
busy(korea,       [4, 10],       20).   % cherry blossoms, autumn colours
busy(korea,       [1, 2],       -15).   % freezing winter
busy(china,       [10],          25).   % Golden Week
busy(china,       [1, 2],        20).   % Spring Festival
busy(singapore,   [12],          15).   % school holidays

%% thai_holiday(Months, Percent, Name): when Thais travel abroad, flights
%  out of Thailand cost more.
thai_holiday([4],     20, 'Songkran').
thai_holiday([10],    10, 'the October school break').
thai_holiday([12, 1], 20, 'New Year').

% ===========================================================================
% 2. HELPERS — written the way the book writes them
% ===========================================================================

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

% Insertion sort on Key-Value pairs, smallest key first (section 7.7).
insort([], []).
insort([X | L], M) :- insort(L, N), insortx(X, N, M).
insortx(X, [A | L], [A | M]) :- before(A, X), !, insortx(X, L, M).
insortx(X, L, [X | L]).
before(K1 - _, K2 - _) :- K1 =< K2.

values([], []).
values([_ - V | T], [V | Vs]) :- values(T, Vs).

% ===========================================================================
% 3. TIME — clock times, time zones and connections
% ===========================================================================

% 1430 means 14:30. Turn it into minutes after midnight.
clock_minutes(HHMM, M) :- M is (HHMM // 100) * 60 + HHMM mod 100.

% A local departure time at City, as minutes on the UTC clock.
to_utc(City, HHMM, T) :-
    airport(City, Zone),
    clock_minutes(HHMM, M),
    T is M - Zone * 60.

% Which day (0 = departure day) and what clock time it is at City
% when the UTC clock shows T.
local_time(City, T, Day, Clock) :-
    airport(City, Zone),
    L is T + Zone * 60,
    Day is L // 1440,
    Clock is L mod 1440.

% The first flight leaves at its timetable time on day 0.
% A connecting flight is the next daily departure at least 90 minutes after
% landing; waiting more than 12 hours does not count as a connection.
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

% ===========================================================================
% 3a. OPTIONS — the traveller's extra choices
% ===========================================================================
% Python passes a list such as [max_flights(2), airlines(budget), hotel(luxury)].
% Each one is stored as a fact option(Name, Value) for the rules to look up.

default_option(max_flights, 3).          % up to 2 changes
default_option(airlines, any).           % any | budget | full
default_option(night_flights, allowed).  % allowed | avoid
default_option(hotel, mid).              % budget | mid | luxury
default_option(cities, []).              % the cities the traveller picked ([] = let Prolog choose)
default_option(getting_around, any).     % any | fast | no_night

% Look the stored value up first, THEN compare: if we matched Value directly,
% a different stored value would fail before the cut and fall through to the default.
opt(Name, Value) :- option(Name, V), !, Value = V.
opt(Name, Value) :- default_option(Name, Value).

set_options(_) :- retract(option(_, _)), fail.
set_options(Opts) :- store_options(Opts).

% hotel(luxury) =.. [hotel, luxury]  (=.. is "univ", section 6.5)
store_options([]).
store_options([O | Os]) :- O =.. [Name, Value], assertz(option(Name, Value)), store_options(Os).

% Flights inside Thailand always count (they connect Chiang Mai and Phuket).
airline_ok(_, From, To) :-
    city(From, _, _, _, thailand, _, _), city(To, _, _, _, thailand, _, _), !.
airline_ok(_, _, _) :- opt(airlines, any), !.
airline_ok(Code, _, _) :- opt(airlines, budget), !, airline(Code, A), low_cost(A).
airline_ok(Code, _, _) :- opt(airlines, full), airline(Code, A), \+ low_cost(A).

% No take-offs between 22:00 and 06:00 if the traveller wants to avoid night flights.
daytime_ok(_) :- opt(night_flights, allowed), !.
daytime_ok(HHMM) :- HHMM >= 600, HHMM =< 2200.

hotel_factor(budget, 60).
hotel_factor(mid, 100).
hotel_factor(luxury, 220).

% The traveller's own cities. If they picked some, the tour must visit exactly
% those (any order). The only other city allowed is a "gateway": an airport
% city at the start or end, next to a picked city that has no airport
% (Kyoto has none, so you may fly into Osaka). Nothing picked = Prolog chooses.
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

% The cities between the first and the last.
middle([_], []) :- !.
middle([_, _], []) :- !.
middle([_ | T], Mid) :- rev(T, [_ | MidRev]), rev(MidRev, Mid).

ends_ok([C], Mine) :- !, member(C, Mine).
ends_ok(Cities, Mine) :-
    Cities = [First, Second | _], end_ok(First, Second, Mine),
    rev(Cities, [Last, Before | _]), end_ok(Last, Before, Mine).

end_ok(C, _, Mine) :- member(C, Mine), !.
end_ok(C, Next, Mine) :- airport(C, _), member(Next, Mine), \+ airport(Next, _).

% How the traveller is happy to move between cities.
ground_ok(_) :- opt(getting_around, any), !.
ground_ok(Mode) :- opt(getting_around, no_night), !, \+ overnight(Mode).
ground_ok(Mode) :- opt(getting_around, fast), \+ overnight(Mode), \+ Mode = bus.

% A gateway city is only a stopover: one night.
gateway(City) :- opt(cities, Ms), \+ Ms = [], \+ member(City, Ms).

% ===========================================================================
% 3b. PRICES — the month changes what things cost
% ===========================================================================

% Add up every percentage that applies to this country and month.
season_extra(Country, Month, Extra) :-
    findall(P, (busy(Country, Months, P), member(Month, Months)), Ps),
    sum(Ps, Extra).

holiday_extra(Month, Extra) :-
    findall(P, (thai_holiday(Months, P, _), member(Month, Months)), Ps),
    sum(Ps, Extra).

% Flights feel both the destination's season and Thai holidays; hotels only the season.
flight_level(Country, Month, Pct) :-
    season_extra(Country, Month, A), holiday_extra(Month, B), Pct is 100 + A + B.
hotel_level(Country, Month, Pct) :-
    season_extra(Country, Month, A), Pct is 100 + A.

% A flight belongs to the country it flies to (or from, when it flies to Thailand).
leg_country(_, To, C) :- city(To, _, _, _, C, _, _), \+ C = thailand, !.
leg_country(From, _, C) :- city(From, _, _, _, C, _, _).

%% low_cost(Airline): budget airlines, by their two-letter code.
low_cost('XJ'). low_cost('FD'). low_cost('VZ'). low_cost('AK'). low_cost('TR').
low_cost('7C'). low_cost('BX'). low_cost('5J'). low_cost('VJ'). low_cost('D7').
low_cost('TW').

% The airline is the first two characters of the flight code ('XJ600' -> 'XJ').
airline(Code, Airline) :- atom_chars(Code, [A, B | _]), atom_chars(Airline, [A, B]).

%% departs(+Code, +SampleHHMM, -HHMM): the real departure time if the API
%  found this exact flight on the chosen day, otherwise the timetable time.
departs(Code, _, HHMM) :- live_departure(Code, HHMM), !.
departs(_, HHMM, HHMM).

%% flight_price(+Code, +From, +To, +SamplePrice, -Price)
%  If Python fetched a real fare for this route and month, use it: the API
%  gives the cheapest fare on the route (usually a budget airline), so a
%  full-service airline is taken to cost 60% more. Otherwise use the sample
%  price adjusted for the season. The cuts keep the first answer.
flight_price(Code, From, To, _, Price) :-
    live_fare(From, To, Live), airline(Code, A), low_cost(A), !,
    Price = Live.
flight_price(_, From, To, _, Price) :-
    live_fare(From, To, Live), !,
    Price is Live * 160 // 100.
flight_price(_, From, To, Sample, Price) :-
    trip_month(Month),
    leg_country(From, To, Country),
    flight_level(Country, Month, Pct),
    Price is Sample * Pct // 100.

%% room_price(+City, -Price): one night, adjusted for the season.
room_price(City, Price) :-
    stay(City, Sample),
    city(City, _, _, _, Country, _, _),
    trip_month(Month),
    hotel_level(Country, Month, Pct),
    opt(hotel, Level), hotel_factor(Level, F),
    Price is Sample * Pct // 100 * F // 100.

set_month(_) :- retract(trip_month(_)), fail.
set_month(Month) :- assertz(trip_month(Month)).

% ===========================================================================
% 4. SEARCH
% ===========================================================================

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

%% fly(+From, +To, -Legs)
%  Depth-first search with a trail, as in section 7.9. At most two flights
%  (one change). Each leg is leg(Code, From, To, DepUTC, ArrUTC, Price, Wait).
fly(From, To, Legs) :- fly(From, To, 2, [From], start, Legs).

fly(Here, Here, _, _, _, []).
fly(Here, To, N, Trail, Clock, [leg(Code, Here, Next, Dep, Arr, Price, Wait) | Rest]) :-
    \+ Here = To,
    N > 0,
    flight(Code, Here, Next, Timetable, Minutes, Sample),
    \+ member(Next, Trail),
    departs(Code, Timetable, HHMM),
    flight_price(Code, Here, Next, Sample, Price),
    note_explored(Here, Next),
    departure(Clock, Here, HHMM, Dep, Wait),
    Arr is Dep + Minutes,
    N1 is N - 1,
    fly(Next, To, N1, [Next | Trail], landed(Arr), Rest).

legs_price([], 0).
legs_price([leg(_, _, _, _, _, P, _) | Legs], Total) :-
    legs_price(Legs, T0), Total is T0 + P.

% Door-to-door minutes: from the first take-off to the last landing.
legs_minutes(Legs, M) :-
    Legs = [leg(_, _, _, Dep, _, _, _) | _],
    last_elem(Legs, leg(_, _, _, _, Arr, _, _)),
    M is Arr - Dep.

flight_key(cheapest, Legs, K) :- legs_price(Legs, K).
flight_key(fastest,  Legs, K) :- legs_minutes(Legs, K).
flight_key(fewest,   Legs, K) :- listlen(Legs, N), legs_price(Legs, P), K is N * 1000000 + P.
flight_key(balanced, Legs, K) :- legs_price(Legs, P), legs_minutes(Legs, M), K is P + M * 10.

% ---------------------------------------------------------------------------
% BEST-FIRST SEARCH — the "best route" algorithm of section 7.9 (go3)
% ---------------------------------------------------------------------------
% The book keeps a list of partial routes r(Miles, Places) and always extends
% the SHORTEST one first, so the first route that reaches the destination is
% the best. We do the same; a partial route is
%     r(Cost, Here, Clock, Visited, LegsNewestFirst)
% and "cost" depends on what the traveller prefers. Every cost only grows as
% a route gets longer, which is why the first complete route found is the best.

path_cost(cheapest, Legs, C) :- legs_price(Legs, C).
path_cost(fastest,  Legs, C) :- elapsed(Legs, C).
path_cost(fewest,   Legs, C) :- listlen(Legs, N), legs_price(Legs, P), C is N * 1000000 + P.
path_cost(balanced, Legs, C) :- legs_price(Legs, P), elapsed(Legs, M), C is P + M * 10.

% Minutes from the first take-off to the latest landing (legs newest first).
elapsed(Legs, M) :-
    Legs = [leg(_, _, _, _, Arr, _, _) | _],
    last_elem(Legs, leg(_, _, _, Dep, _, _, _)),
    M is Arr - Dep.

% rev/2 as in section 7.5: reverse a list with an accumulator.
rev(L, R) :- rev(L, [], R).
rev([], A, A).
rev([H | T], A, R) :- rev(T, [H | A], R).

% shortest/3 as in section 7.9: take the cheapest partial route off the list.
shortest([R | Rs], S, [R | Rest]) :- shortest(Rs, S, Rest), cheaper(S, R), !.
shortest([R | Rs], R, Rs).

cheaper(r(C1, _, _, _, _), r(C2, _, _, _, _)) :- C1 < C2.

% On the way out, once abroad, don't route back through Thailand.
% (On the way home, changing in Bangkok for Chiang Mai or Phuket is fine.)
back_to_thailand(Here, Next, To) :-
    city(To, _, _, _, C0, _, _), \+ C0 = thailand,
    city(Here, _, _, _, C1, _, _), \+ C1 = thailand,
    city(Next, _, _, _, thailand, _, _).

%% best_routes(+From, +To, +Pref, +K, -Routes)
%  The K best ways to fly From → To (at most 3 flights), best first.
best_routes(From, To, Pref, K, Routes) :-
    bf([r(0, From, start, [From], [])], To, Pref, K, Routes).

bf(_, _, _, 0, []) :- !.
bf([], _, _, _, []) :- !.
bf(Queue, To, Pref, K, Routes) :-
    shortest(Queue, Best, Rest),
    visit(Best, Rest, To, Pref, K, Routes).

% 1. The cheapest route on the list has arrived: it is the next best answer.
visit(r(_, To, _, _, Legs), Rest, To, Pref, K, [Route | More]) :-
    \+ Legs = [], !,
    rev(Legs, Route),
    K1 is K - 1,
    bf(Rest, To, Pref, K1, More).
% 2. Not there yet: add every legal next flight (like proceed/4 in the book).
visit(r(_, Here, Clock, Seen, Legs), Rest, To, Pref, K, Routes) :-
    opt(max_flights, Max),
    listlen(Legs, N), N < Max, !,
    findall(r(C, Next, landed(Arr), [Next | Seen], [leg(Code, Here, Next, Dep, Arr, Price, Wait) | Legs]),
            ( flight(Code, Here, Next, Timetable, Minutes, Sample),
              \+ member(Next, Seen),
              \+ back_to_thailand(Here, Next, To),
              airline_ok(Code, Here, Next),
              departs(Code, Timetable, HHMM),
              daytime_ok(HHMM),
              departure(Clock, Here, HHMM, Dep, Wait),
              Arr is Dep + Minutes,
              flight_price(Code, Here, Next, Sample, Price),
              note_explored(Here, Next),
              path_cost(Pref, [leg(Code, Here, Next, Dep, Arr, Price, Wait) | Legs], C) ),
            Longer),
    append(Longer, Rest, Queue),
    bf(Queue, To, Pref, K, Routes).
% 3. Already the most flights allowed and still not there: drop it.
visit(_, Rest, To, Pref, K, Routes) :-
    bf(Rest, To, Pref, K, Routes).

%% best_flights(+From, +To, +Pref, -Best)
%  The two best ways to fly From → To, found by best-first search. Answers
%  are remembered with assertz (section 7.8) so each pair is searched once.
best_flights(From, To, Pref, Best) :- flight_memo(From, To, Pref, Best), !.
best_flights(From, To, Pref, Best) :-
    best_routes(From, To, Pref, 2, Best),
    assertz(flight_memo(From, To, Pref, Best)).

%% compare_search(+From, +To, -DepthFirstSteps, -BestFirstSteps)
%  For the presentation: how much work each search needs for the same answer.
%  Depth-first (fly/3) must find EVERY route and sort them; best-first stops
%  as soon as the best two are known.
compare_search(From, To, Pref, DF, BF) :-
    reset_search,
    findall(K - L, (fly(From, To, L), \+ L = [], flight_key(Pref, L, K)), Pairs),
    insort(Pairs, _),
    steps(DF),
    reset_search,
    best_routes(From, To, Pref, 2, _),
    steps(BF).

% Remove every live fact (Python calls this before adding new ones).
clear_live :- retract(live_fare(_, _, _)), fail.
clear_live :- retract(live_departure(_, _)), fail.
clear_live.

%% tour(+Start, +Max, -Cities, -Moves)
%  Cities to visit inside one country, by train/bus/ferry/domestic flight,
%  never visiting a city twice. Same trail idea as the flight search.
linked(A, B, Mode, Price, Minutes) :- ground(A, B, Mode, Price, Minutes).
linked(A, B, Mode, Price, Minutes) :- ground(B, A, Mode, Price, Minutes).

tour(Start, Max, [Start | Cities], Moves) :- tour(Start, Max, [Start], Cities, Moves).

% A tour may also end back where it started (Seoul → Busan → Seoul), so you
% can fly home from the city you flew into. That is the only repeat allowed.
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

% ===========================================================================
% 5. PLANNING — days, activities and money
% ===========================================================================

likes(Cat, Interests) :- member(Cat, Interests).

% How many attractions in City the traveller would like.
matches(City, Interests, N) :-
    findall(x, (attraction(City, _, Cat, _, _), likes(Cat, Interests)), Xs),
    listlen(Xs, N).

matching_categories(City, Interests, Cats) :-
    findall(Cat, (attraction(City, _, Cat, _, _), likes(Cat, Interests)), Cs),
    no_dups(Cs, Cats).

%% pick(+City, +Interests, +Used, +Hours, -Acts, -Used1)
%  Liked places first, then anything else, while they fit in the hours.
pick(City, Interests, Used, Hours, Acts, Used1) :-
    findall(act(Name, Cat, Fee, H),
            (attraction(City, Name, Cat, Fee, H), likes(Cat, Interests), \+ member(Name, Used)),
            Liked),
    findall(act(Name, Cat, Fee, H),
            (attraction(City, Name, Cat, Fee, H), \+ likes(Cat, Interests), \+ member(Name, Used)),
            Others),
    append(Liked, Others, Candidates),
    fit(Candidates, Hours, 3, Acts),
    act_names(Acts, Names),
    append(Used, Names, Used1).

fit([], _, _, []).
fit(_, _, 0, []) :- !.
fit([act(N, C, F, H) | As], Hours, Max, [act(N, C, F, H) | Rest]) :-
    H =< Hours, !,
    Hours1 is Hours - H, Max1 is Max - 1,
    fit(As, Hours1, Max1, Rest).
fit([_ | As], Hours, Max, Rest) :- fit(As, Hours, Max, Rest).

act_names([], []).
act_names([act(N, _, _, _) | As], [N | Ns]) :- act_names(As, Ns).

% Free hours on the day you land: from an hour after landing until 21:00.
arrival_hours(Clock, H) :- H0 is (1260 - Clock - 60) // 60, clamp(H0, 0, 8, H).
% Free hours on the day you fly home: from 09:00 until 3 hours before take-off.
leaving_hours(Clock, H) :- H0 is (Clock - 180 - 540) // 60, clamp(H0, 0, 6, H).
% Free hours on a day you change city: 8 minus the time on the road.
moving_hours(Minutes, H) :- H0 is 8 - (Minutes + 59) // 60, clamp(H0, 0, 8, H).

% ---------------------------------------------------------------------------
% Sharing the days between cities
% ---------------------------------------------------------------------------
% Every city first gets its minimum stay. Then each spare day goes to the city
% with the most room left (MaxDays - days so far), so Tokyo gets more days
% than Osaka. A tour that cannot give every city its minimum is rejected.
% Each entry is s(City, DaysSoFar, MaxDays).

% A city visited a second time (the end of a loop) only needs a short stay.
range_for(City, _, 1, 1) :- gateway(City), !.
range_for(City, Seen, 1, 2) :- member(City, Seen), !.
range_for(City, _, Min, Max) :- stay_range(City, Min, Max).

% The pace moves the minimum: packed stays may be a day shorter, relaxed a day longer.
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

%% share_days(+Cities, +Pace, +CityDays, -Shares)   Shares = [City-Days, ...]
share_days(Cities, Pace, CityDays, Shares) :-
    starts(Cities, Pace, [], S0),
    days_used(S0, Used),
    Spare is CityDays - Used,
    Spare >= 0,
    add_days(Spare, S0, S1),
    as_pairs(S1, Shares).

% If every city is already at its MaxDays, one extra day is fine (it goes to
% the biggest city); more than that means this tour is too small for the trip,
% so it fails and Prolog tries a tour with more or bigger cities.
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

%% build_plan(+Home, +Country, +Days, +People, +Interests, +Pace, +Out, +Cities, +Moves, +Ret, -Plan)
build_plan(Home, Country, Days, People, Interests, Pace, Out, Cities, Moves, Ret,
           plan(Country, Out, Cities, Moves, Ret, DayList, costs(Fl, Gr, Ho, Da, Fe, Total),
                meta(Rooms, Nights, Landed, FlightMin, Enjoy, Free))) :-
    % when do we land, and how many days are left for the cities?
    last_elem(Out, leg(_, _, First, _, Arr, _, _)),
    local_time(First, Arr, LandDay, LandClock),
    Landed is LandDay + 1,
    CityDays is Days - Landed,
    CityDays >= 1,
    share_days(Cities, Pace, CityDays, Shares),
    % the days themselves
    arrival_hours(LandClock, ArrHours),
    Ret = [leg(_, Last, _, RetDep, _, _, _) | _],
    local_time(Last, RetDep, _, RetClock),
    leaving_hours(RetClock, LeaveHours),
    flight_days(Home, Out, Landed, FlightDays),
    city_days(Shares, Moves, Landed, ArrHours, Interests, [], CityDays0, Used),
    same_day_landing(Landed, Out, CityDays0, CityDayList),
    pick(Last, Interests, Used, LeaveHours, LastActs, _),
    append(FlightDays, CityDayList, D1),
    append(D1, [day(Days, home, Last, flights(Ret), LastActs)], DayList),
    % money
    legs_price(Out, P1), legs_price(Ret, P2),
    Fl is (P1 + P2) * People,
    moves_price(Moves, MP), Gr is MP * People,
    Rooms is (People + 1) // 2,
    hotel_cost(CityDayList, 0, H0),
    on_board(Moves, Saved, OnBoard),
    H is H0 - Saved, Ho is H * Rooms,
    Nights is Days - Landed - OnBoard,
    country(Country, _, _, Daily), Da is Daily * People * CityDays,
    fees(DayList, F), Fe is F * People,
    Total is Fl + Gr + Ho + Da + Fe,
    legs_minutes(Out, M1), legs_minutes(Ret, M2), FlightMin is M1 + M2,
    enjoyment(DayList, Interests, Enjoy),
    free_days(DayList, Free).

free_days(Days, N) :- findall(x, member(day(_, free, _, _, _), Days), Xs), listlen(Xs, N).

% If we land on day 1, the flight is part of the first city day.
% If we land later (overnight flight), day 1 is the flight and any days
% in between are spent in the air.
flight_days(_, _, 1, []) :- !.
flight_days(Home, Out, Landed, [day(1, fly, Home, flights(Out), []) | Air]) :-
    in_air(2, Landed, Air).

same_day_landing(1, Out, [day(1, arrive, City, none, Acts) | Ds], [day(1, arrive, City, flights(Out), Acts) | Ds]) :- !.
same_day_landing(_, _, Ds, Ds).

in_air(N, Landed, []) :- N >= Landed, !.
in_air(N, Landed, [day(N, air, none, none, []) | Rest]) :- N1 is N + 1, in_air(N1, Landed, Rest).

% Walk through the cities. The first day in the first city is the landing day;
% the first day in every other city starts with the train/bus/flight there.
city_days([], _, _, _, _, Used, [], Used).
city_days([City - D | Shares], Moves, N, Hours, Interests, Used0, Days, Used) :-
    stay_days(City, D, N, Hours, first, Interests, Used0, Here, N1, Used1),
    next_city(Moves, Shares, Moves1, Hours1),
    city_days(Shares, Moves1, N1, Hours1, Interests, Used1, Later, Used),
    append(Here, Later, Days).

next_city([move(_, _, Mode, _, _) | Ms], _, Ms, 7) :- overnight(Mode), !.   % arrive early morning
next_city([move(_, _, _, _, Min) | Ms], _, Ms, Hours) :- !, moving_hours(Min, Hours).
next_city(Ms, _, Ms, 8).

% stay_days(City, HowMany, DayNo, HoursFirstDay, ...)
stay_days(_, 0, N, _, _, _, Used, [], N, Used) :- !.
stay_days(City, D, N, Hours, Kind, Interests, Used0, [day(N, Kind1, City, Travel, Acts) | Days], NOut, Used) :-
    pick(City, Interests, Used0, Hours, Acts, Used1),
    day_kind(Kind, Acts, Kind1, Travel),
    D1 is D - 1, N1 is N + 1,
    stay_days(City, D1, N1, 8, later, Interests, Used1, Days, NOut, Used).

% A later day with nothing left to do is a free day.
day_kind(first, _, arrive, none).
day_kind(later, [], free, none) :- !.
day_kind(later, _, explore, none).

% The day you arrive in each new city records how you got there. The first
% city was reached by plane; every later city takes the next move in order.
attach_moves(Days, Moves, Out) :- attach(Days, first, Moves, Out).

attach([], _, _, []).
attach([day(N, arrive, City, T, A) | Ds], first, Ms, [day(N, arrive, City, T, A) | Rest]) :- !,
    attach(Ds, later, Ms, Rest).
attach([day(N, arrive, City, none, A) | Ds], later, [move(F, City, M, P, Min) | Ms],
       [day(N, move, City, ground(F, City, M, P, Min), A) | Rest]) :- !,
    attach(Ds, later, Ms, Rest).
attach([D | Ds], Flag, Ms, [D | Rest]) :- attach(Ds, Flag, Ms, Rest).

moves_price([], 0).
moves_price([move(_, _, _, P, _) | Ms], T) :- moves_price(Ms, T0), T is T0 + P.

% Each overnight ride replaces one hotel night in the city you leave.
on_board(Moves, Saved, N) :-
    findall(P, (member(move(From, _, Mode, _, _), Moves), overnight(Mode), room_price(From, P)), Ps),
    sum(Ps, Saved),
    listlen(Ps, N).

% One hotel night for every city day (you fly home on the last day).
hotel_cost([], T, T).
hotel_cost([day(_, _, City, _, _) | Ds], T0, T) :-
    room_price(City, P), T1 is T0 + P, hotel_cost(Ds, T1, T).

fees(Days, Total) :- findall(F, (member(day(_, _, _, _, Acts), Days), member(act(_, _, F, _), Acts)), Fs), sum(Fs, Total).

sum([], 0).
sum([X | Xs], T) :- sum(Xs, T0), T is T0 + X.

enjoyment(Days, Interests, E) :-
    findall(x, (member(day(_, _, _, _, Acts), Days), member(act(_, Cat, _, _), Acts), likes(Cat, Interests)), Xs),
    listlen(Xs, E).

% ===========================================================================
% 6. RANKING
% ===========================================================================

plan_total(plan(_, _, _, _, _, _, costs(_, _, _, _, _, T), _), T).

%% plan_key(+Pref, +Plan, -Key)   smaller key = better plan
plan_key(cheapest, P, K) :- plan_total(P, K).
plan_key(fastest, P, K) :-
    P = plan(_, _, _, _, _, _, _, meta(_, _, _, Min, _, _)), plan_total(P, T), K is Min * 1000 + T.
plan_key(fewest, P, K) :-
    P = plan(_, Out, _, _, Ret, _, _, _), listlen(Out, A), listlen(Ret, B),
    plan_total(P, T), K is (A + B) * 10000000 + T.
plan_key(balanced, P, K) :-
    P = plan(_, _, _, _, _, _, _, meta(_, _, _, Min, Enjoy, _)), plan_total(P, T),
    K is T + Min * 10 - Enjoy * 1500.

% A day with nothing planned wastes that day's share of the trip's cost,
% so it is added on top. Prolog then prefers plans that keep you busy.
score(Pref, P, K) :-
    plan_key(Pref, P, K0),
    P = plan(_, _, _, _, _, Days, costs(_, _, _, _, _, T), meta(_, _, _, _, _, Free)),
    listlen(Days, N),
    K is K0 + Free * T // N.

rank(Pref, Plans, Ranked) :-
    keyed(Pref, Plans, Pairs), insort(Pairs, Sorted), values(Sorted, Ranked).

keyed(_, [], []).
keyed(Pref, [P | Ps], [K - P | KPs]) :- score(Pref, P, K), keyed(Pref, Ps, KPs).

% The best plan by a single pass (no sorting needed).
best_plan(Pref, [P | Ps], Best) :- score(Pref, P, K), best_plan(Pref, Ps, K, P, Best).
best_plan(_, [], _, Best, Best).
best_plan(Pref, [P | Ps], K0, _, Best) :-
    score(Pref, P, K), K < K0, !, best_plan(Pref, Ps, K, P, Best).
best_plan(Pref, [_ | Ps], K0, B0, Best) :- best_plan(Pref, Ps, K0, B0, Best).

affordable(_, [], []).
affordable(Budget, [P | Ps], [P | As]) :- plan_total(P, T), T =< Budget, !, affordable(Budget, Ps, As).
affordable(Budget, [_ | Ps], As) :- affordable(Budget, Ps, As).

% Keep plans that visit different cities, so A, B and C are real alternatives.
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

% "Anywhere": the best plan for each country, then countries ranked by
% value — every activity you would enjoy is worth ฿3,000.
best_per_country(_, [], _, []).
best_per_country(Pref, [C | Cs], Plans, [K - Best | Rest]) :-
    country_plans(C, Plans, Mine), \+ Mine = [], !,
    best_plan(Pref, Mine, Best),
    plan_total(Best, T),
    Best = plan(_, _, _, _, _, _, _, meta(_, _, _, _, Enjoy, _)),
    K is T - Enjoy * 3000,
    best_per_country(Pref, Cs, Plans, Rest).
best_per_country(Pref, [_ | Cs], Plans, Rest) :- best_per_country(Pref, Cs, Plans, Rest).

% ===========================================================================
% 7. REASONS — returned as lists; Python turns them into sentences
% ===========================================================================

reasons(Dest, Pref, Index, Count, Budget, Days, Month, People, Interests, Plan, Reasons) :-
    Plan = plan(Country, Out, Cities, Moves, Ret, _, costs(_, _, _, _, _, Total), meta(Rooms, _, Landed, _, Enjoy, Free)),
    rank_reason(Dest, Pref, Index, Count, Country, Enjoy, R1),
    budget_reason(Budget, Total, R2),
    flight_reason(out, Out, R3),
    flight_reason(back, Ret, R4),
    free_reason(Free, R5),
    append(Out, Ret, Legs),
    fares_reason(Legs, R6),
    findall(R, estimate_reason(Legs, R), R7a),
    findall(R, option_reason(Cities, R), R7c),
    findall([on_board, Mode, From, To], (member(move(From, To, Mode, _, _), Moves), overnight(Mode)), R7d),
    append(R7c, R7d, R7b),
    append(R7a, R7b, R7),
    findall(R, extra_reason(Country, Days, Month, People, Rooms, Landed, Cities, Interests, R), Rs),
    append([R1, R2, R3, R4, R5, R6], R7, Head),
    append(Head, Rs, Reasons).

% Say which of the traveller's choices shaped the plan.
option_reason(_, [max_flights, N]) :- opt(max_flights, N), N < 3.
option_reason(_, [airlines, A]) :- opt(airlines, A), \+ A = any.
option_reason(_, [no_night_flights]) :- opt(night_flights, avoid).
option_reason(_, [hotel, L]) :- opt(hotel, L), \+ L = mid.
option_reason(_, [your_cities]) :- opt(cities, Ms), \+ Ms = [].
option_reason(_, [getting_around, G]) :- opt(getting_around, G), \+ G = any.
option_reason(Cities, [gateway, G]) :- no_dups(Cities, Unique), member(G, Unique), gateway(G).

% Say so when a full-service flight's price was estimated from the budget fare.
estimate_reason(Legs, [full_service_estimate, Code]) :-
    member(leg(Code, F, T, _, _, _, _), Legs),
    live_fare(F, T, _), airline(Code, A), \+ low_cost(A), !.

% Where the flight prices came from.
fares_reason(Legs, [live_fares, N, Total]) :-
    findall(x, (member(leg(_, F, T, _, _, _, _), Legs), live_fare(F, T, _)), Xs),
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

extra_reason(_, _, _, _, _, Landed, _, _, [overnight]) :- Landed > 1.
extra_reason(_, _, _, People, Rooms, _, _, _, [rooms, People, Rooms]) :- People > 1.
extra_reason(_, _, _, _, _, _, Cities, _, [open_jaw, First, Last]) :-
    Cities = [First | _], last_elem(Cities, Last), \+ First = Last.
extra_reason(_, _, _, _, _, _, Cities, Interests, [city, City, N, Cats]) :-
    no_dups(Cities, Unique),
    member(City, Unique), matches(City, Interests, N), N > 0,
    matching_categories(City, Interests, Cats).
extra_reason(Country, Days, _, _, _, _, _, _, [visa_ok, Country, Max]) :-
    visa_free(Country, Max), Days =< Max.
extra_reason(Country, Days, _, _, _, _, _, _, [visa_too_short, Country, Max]) :-
    visa_free(Country, Max), Days > Max.
extra_reason(Country, _, Month, _, _, _, _, _, [prices, Country, Month, Fly, Stay]) :-
    flight_level(Country, Month, Fly), hotel_level(Country, Month, Stay),
    \+ (Fly =:= 100, Stay =:= 100).
extra_reason(_, _, Month, _, _, _, _, _, [thai_holiday, Name]) :-
    thai_holiday(Months, _, Name), member(Month, Months).
extra_reason(Country, _, Month, _, _, _, _, _, [highlight, Country, What]) :-
    highlight(Country, What, Months), member(Month, Months).
extra_reason(Country, _, Month, _, _, _, _, _, [warning, Country, What]) :-
    warning(Country, What, Months), member(Month, Months).

% ===========================================================================
% 8. API — called from Python (pyswip)
% ===========================================================================

normalize_interests([], All) :- !, findall(I, interest(I), All).
normalize_interests(Is, Is).

countries_for(anywhere, Cs) :- !, findall(C, destination(C), Cs).
countries_for(C, [C]).

%% candidate(+Home, +Country, +Days, +People, +Interests, +Pace, +Pref, -Plan)
%  Generate and test (chapter 4): fly in, tour some cities, fly home.
candidate(Home, Country, Days, People, Interests, Pace, Pref, Plan) :-
    city(Arrive, _, _, _, Country, _, _),
    airport(Arrive, _),
    best_flights(Home, Arrive, Pref, Outs),
    member(Out, Outs),
    round_tour(Arrive, 4, Cities, Moves),
    chosen_ok(Country, Cities),
    last_elem(Cities, Last),
    airport(Last, _),
    best_flights(Last, Home, Pref, Rets),
    member(Ret, Rets),
    build_plan(Home, Country, Days, People, Interests, Pace, Out, Cities, Moves, Ret, Plan0),
    Plan0 = plan(C, O, Cs, Ms, R, Ds, Costs, Meta),
    attach_moves(Ds, Ms, Ds1),
    Plan = plan(C, O, Cs, Ms, R, Ds1, Costs, Meta).

%% plan_trip(+Home, +Dest, +Days, +Month, +People, +Budget, +Interests, +Pace, +Pref, -Result)
%  Dest is a country, or `anywhere` to let Prolog choose.
%  Result = [Stats, Rows]
plan_trip(Home, Dest, Days, Month, People, Budget, Interests, Pace, Pref, Result) :-
    plan_trip(Home, Dest, Days, Month, People, Budget, Interests, Pace, Pref, [], Result).

%% plan_trip/11: the same, plus a list of options (see section 3a).
plan_trip(Home, Dest, Days, Month, People, Budget, Interests0, Pace, Pref, Options, [Stats, Rows]) :-
    normalize_interests(Interests0, Interests),
    reset_search,
    set_month(Month),
    set_options(Options),
    countries_for(Dest, Countries),
    findall(P, (member(C, Countries), candidate(Home, C, Days, People, Interests, Pace, Pref, P)), Plans),
    listlen(Plans, NPlans),
    affordable(Budget, Plans, Cheap),
    listlen(Cheap, NCheap),
    pool(Cheap, Plans, Pool),
    choose(Dest, Pref, Countries, Pool, Chosen),
    rows(Chosen, 1, Dest, Pref, NPlans, Budget, Days, Month, People, Interests, Rows),
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
rows([P | Ps], I, Dest, Pref, Count, Budget, Days, Month, People, Interests, [Row | Rest]) :-
    reasons(Dest, Pref, I, Count, Budget, Days, Month, People, Interests, P, Reasons),
    plan_row(P, Budget, Reasons, Row),
    I1 is I + 1,
    rows(Ps, I1, Dest, Pref, Count, Budget, Days, Month, People, Interests, Rest).

plan_row(plan(Country, Out, Cities, Moves, Ret, Days, costs(Fl, Gr, Ho, Da, Fe, T), meta(Rooms, Nights, Landed, Min, Enjoy, Free)),
         Budget, Reasons,
         [Country, OutRows, Cities, MoveRows, RetRows, DayRows, [Fl, Gr, Ho, Da, Fe, T], Fits, Reasons,
          [Rooms, Nights, Landed, Min, Enjoy, Free], RoomRows]) :-
    no_dups(Cities, Unique),
    room_rows(Unique, RoomRows),
    leg_rows(Out, OutRows),
    leg_rows(Ret, RetRows),
    move_rows(Moves, MoveRows),
    day_rows(Days, DayRows),
    fits(T, Budget, Fits).

% One night in each city, after the season rule.
room_rows([], []).
room_rows([C | Cs], [[C, P] | Rows]) :- room_price(C, P), room_rows(Cs, Rows).

fits(T, Budget, yes) :- T =< Budget, !.
fits(_, _, no).

leg_rows([], []).
leg_rows([leg(C, F, T, D, A, P, W) | Ls], [[C, F, T, D, A, P, W] | Rs]) :- leg_rows(Ls, Rs).

move_rows([], []).
move_rows([move(F, T, M, P, Min) | Ms], [[F, T, M, P, Min] | Rs]) :- move_rows(Ms, Rs).

day_rows([], []).
day_rows([day(N, Kind, City, Travel, Acts) | Ds], [[N, Kind, City, TravelRow, ActRows] | Rs]) :-
    travel_row(Travel, TravelRow),
    act_rows(Acts, ActRows),
    day_rows(Ds, Rs).

travel_row(none, none).
travel_row(flights(Legs), [flights, Rows]) :- leg_rows(Legs, Rows).
travel_row(ground(F, T, M, P, Min), [ground, F, T, M, P, Min]).

act_rows([], []).
act_rows([act(N, C, F, H) | As], [[N, C, F, H] | Rs]) :- act_rows(As, Rs).

%% map_data(-Countries, -Cities, -Flights, -Ground)
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
