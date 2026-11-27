:- dynamic(explored/2).
:- dynamic(steps/1).
:- dynamic(flight_memo/4).
:- dynamic(trip_month/1).
:- dynamic(live_fare/3).
:- dynamic(live_departure/2).
:- dynamic(live_offer/6).
:- dynamic(option/2).


:- ensure_loaded([facts_geo, facts_places, search_flights, search_trip, ranking]).

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
    city_tour(Arrive, 4, Cities, Moves),
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
