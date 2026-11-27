% FLIGHT SEARCH: TIMEZONES, PRICING, BEST-FIRST SEARCH, A* & MEMOIZATION
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

leg_country(OriginCountry, _, To, C) :- city(To, _, _, _, C, _, _), \+ C = OriginCountry, !.
leg_country(_, From, _, C) :- city(From, _, _, _, C, _, _).

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

% --- Candidate flight edges: real multi-airline API offers + non-overlapping static carriers
edge_target(Here, Next) :-
    findall(N, (flight(_, Here, N, _, _, _) ; live_offer(Here, N, _, _, _, _)), Ns),
    no_dups(Ns, Targets),
    member(Next, Targets).

route_edge(OriginCountry, Here, Next, Code, HHMM, Minutes, Price) :-
    edge_target(Here, Next),
    route_edge_for(OriginCountry, Here, Next, Code, HHMM, Minutes, Price).

route_edge_for(_, Here, Next, Code, HHMM, Minutes, Price) :-
    live_offer(Here, Next, _, Code, HHMM, Price),
    edge_minutes(Here, Next, Minutes).
route_edge_for(OriginCountry, Here, Next, Code, HHMM, Minutes, Price) :-
    flight(Code, Here, Next, Timetable, Minutes, Sample),
    airline(Code, A),
    \+ live_offer(Here, Next, A, _, _, _),
    departs(Code, Timetable, HHMM),
    flight_price(OriginCountry, Code, Here, Next, Sample, Price).

min_static_fare(From, To, Min) :-
    findall(S, flight(_, From, To, _, _, S), [S0 | Ss]),
    min_num(Ss, S0, Min).

min_num([], M, M).
min_num([X | Xs], M0, M) :- X < M0, !, min_num(Xs, X, M).
min_num([_ | Xs], M0, M) :- min_num(Xs, M0, M).

% --- API live_fare vs static price (fallback when no live_offer/6, scaled by carrier Sample)
flight_price(_, Code, From, To, Sample, Price) :-
    live_fare(From, To, Live),
    min_static_fare(From, To, MinS), MinS > 0, !,
    Scaled is Live * Sample // MinS,
    (airline_tier(Code, budget) -> Floor = Live ; Floor is Live * 155 // 100),
    (Scaled > Floor -> Price = Scaled ; Price = Floor).
flight_price(_, Code, From, To, _, Price) :-
    live_fare(From, To, Live), airline_tier(Code, budget), !,
    Price = Live.
flight_price(_, _, From, To, _, Price) :-
    live_fare(From, To, Live), !,
    Price is Live * 160 // 100.
flight_price(OriginCountry, _, From, To, Sample, Price) :-
    trip_month(Month),
    leg_country(OriginCountry, From, To, Country),
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
    bf(astar, [r(0, From, start, [From], [])], OriginCountry, To, Pref, K, Routes).

best_routes_ucs(From, To, Pref, K, Routes) :-
    city(From, _, _, _, OriginCountry, _, _),
    bf(ucs, [r(0, From, start, [From], [])], OriginCountry, To, Pref, K, Routes).

bf(_, _, _, _, _, 0, []) :- !.
bf(_, [], _, _, _, _, []) :- !.
bf(Mode, Queue, OriginCountry, To, Pref, K, Routes) :-
    shortest(Queue, Best, Rest),
    visit(Mode, Best, Rest, OriginCountry, To, Pref, K, Routes).

visit(Mode, r(_, To, _, _, Legs), Rest, OriginCountry, To, Pref, K, [Route | More]) :-
    \+ Legs = [], !,
    rev(Legs, Route),
    K1 is K - 1,
    bf(Mode, Rest, OriginCountry, To, Pref, K1, More).
visit(Mode, r(_, Here, Clock, Seen, Legs), Rest, OriginCountry, To, Pref, K, Routes) :-
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
              (Mode = astar ->
                  astar_cost(Pref, Next, To, [leg(Code, Here, Next, Dep, Arr, Price, Wait) | Legs], C)
              ;
                  path_cost(Pref, [leg(Code, Here, Next, Dep, Arr, Price, Wait) | Legs], C)
              ) ),
            Longer),
    append(Longer, Rest, Queue),
    bf(Mode, Queue, OriginCountry, To, Pref, K, Routes).
visit(Mode, _, Rest, OriginCountry, To, Pref, K, Routes) :-
    bf(Mode, Rest, OriginCountry, To, Pref, K, Routes).

% --- Memoization (Top 4 flight cache)
best_flights(From, To, Pref, Best) :- flight_memo(From, To, Pref, Best), !.
best_flights(From, To, Pref, Best) :-
    best_routes(From, To, Pref, 4, Best),
    assertz(flight_memo(From, To, Pref, Best)).

compare_search(From, To, Pref, DF, BF) :-
    compare_all_search(From, To, Pref, DF, _, BF).

compare_all_search(From, To, Pref, DF, UCS, AStar) :-
    reset_search,
    findall(K - L, (fly(From, To, L), \+ L = [], flight_key(Pref, L, K)), Pairs),
    insort(Pairs, _),
    steps(DF),
    reset_search,
    best_routes_ucs(From, To, Pref, 4, _),
    steps(UCS),
    reset_search,
    best_routes(From, To, Pref, 4, _),
    steps(AStar).

clear_live :- retract(live_fare(_, _, _)), fail.
clear_live :- retract(live_departure(_, _)), fail.
clear_live :- retract(live_offer(_, _, _, _, _, _)), fail.
clear_live.


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

