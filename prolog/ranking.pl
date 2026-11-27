% RANKING, INSERTION SORT, BUDGET FILTER & EXPLAINABLE AI REASONS
% --- Insertion sort
insort([], []).
insort([X | L], M) :- insort(L, N), insortx(X, N, M).
insortx(X, [A | L], [A | M]) :- before(A, X), !, insortx(X, L, M).
insortx(X, L, [X | L]).
before(K1 - _, K2 - _) :- K1 =< K2.

values([], []).
values([_ - V | T], [V | Vs]) :- values(T, Vs).


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

