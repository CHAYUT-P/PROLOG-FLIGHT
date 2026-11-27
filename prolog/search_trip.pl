% TRIP SEARCH: DFS CITY TOURS, CONSTRAINED ATTRACTION SCHEDULER, GREEDY DAYS & COST
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

% --- Default to 1 main city (or nearby <=60m rail/bus day trip) unless user picked specific cities
city_tour(Start, Max, Cities, Moves) :-
    opt(cities, Ms), \+ Ms = [], !,
    round_tour(Start, Max, Cities, Moves).
city_tour(Start, _, [Start], []).
city_tour(Start, _, [Start, Near, Start], [move(Start, Near, Mode, P, Min), move(Near, Start, Mode, P, Min)]) :-
    linked(Start, Near, Mode, P, Min),
    \+ Mode = plane,
    Min =< 60,
    ground_ok(Mode).

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
    schedule_day(normal, City, Interests, Used, Hours, Window, Acts, Alts, Used1).

schedule_day(Mode, City, Interests, Used, Hours, Window, Acts, Alts, Used1) :-
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
    (Mode = strict, Liked \= [] -> Pool0 = Liked ; append(Liked, Others, Pool0)),
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
    append(Liked, Others, AltPool),
    pick_alternatives(AltPool, Used1, 3, Alts).
schedule_day(_, City, Interests, Used, _, _, [], Alts, Used) :-
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

zone_transit(none, _, 0) :- !.
zone_transit(Z, Z, 0) :- !.
zone_transit(_, _, 0.5).

day_seq(_, _, 0, _, _, [], 0, 0) :- !.
day_seq([], _, _, _, _, [], 0, 0).
day_seq([A | As], RemH, Max, PrevZone, PrevSlot, [A | Rest], HUsed, Switches) :-
    A = act(_, _, _, H, Zone, Slot, _),
    zone_transit(PrevZone, Zone, Transit),
    Need is H + Transit,
    Need =< RemH,
    (PrevSlot = none -> true ; slot_order_ok(PrevSlot, Slot)),
    RemH1 is RemH - Need,
    Max1 is Max - 1,
    (PrevZone = none -> Sw0 = 0 ; (PrevZone = Zone -> Sw0 = 0 ; Sw0 = 1)),
    (Slot = all_day ->
        Rest = [], HUsed = Need, Switches = Sw0
    ;
        day_seq(As, RemH1, Max1, Zone, Slot, Rest, HRest, SwRest),
        HUsed is Need + HRest,
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
add_days(N, S0, S) :-
    N > 0,
    biggest(S0, 1, 0, 0, Pos),
    bump(S0, Pos, S1),
    N1 is N - 1,
    add_days(N1, S1, S).

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
    schedule_day(normal, Last, Interests, Used, LeaveHours, morning, LastActs, LastAlts, UsedAll),
    append(FlightDays, CityDayList, D1),
    append(D1, [day(Days, home, Last, flights(Ret), LastActs, LastAlts, LeaveHours, morning)], DayList0),
    clean_trip_alts(DayList0, UsedAll, DayList),
    legs_price(Out, P1), legs_price(Ret, P2),
    Fl is (P1 + P2) * People,
    moves_price(Moves, MP), Gr is MP * People,
    country(Country, _, _, Daily), Da is Daily * People * CityDays,
    fees(DayList, F), Fe is F * People,
    Total is Fl + Gr + Da + Fe,
    legs_minutes(Out, M1), legs_minutes(Ret, M2), FlightMin is M1 + M2,
    enjoyment(DayList, Interests, Enjoy),
    free_days(DayList, Free).

clean_trip_alts([], _, []).
clean_trip_alts([day(N, Kind, City, Travel, Acts, Alts0, H, W) | Ds], UsedAll,
                [day(N, Kind, City, Travel, Acts, Alts, H, W) | Rest]) :-
    findall(A, (member(A, Alts0), A = act(Name, _, _, _, _, _, _), \+ member(Name, UsedAll)), Alts),
    clean_trip_alts(Ds, UsedAll, Rest).

free_days(Days, N) :- findall(x, member(day(_, free, _, _, _, _, _, _), Days), Xs), listlen(Xs, N).

flight_days(_, _, 1, []) :- !.
flight_days(Home, Out, Landed, [day(1, fly, Home, flights(Out), [], [], 0, full) | Air]) :-
    in_air(2, Landed, Air).

same_day_landing(1, Out, [day(1, arrive, City, none, Acts, Alts, H, W) | Ds],
                 [day(1, arrive, City, flights(Out), Acts, Alts, H, W) | Ds]) :- !.
same_day_landing(_, _, Ds, Ds).

in_air(N, Landed, []) :- N >= Landed, !.
in_air(N, Landed, [day(N, air, none, none, [], [], 0, full) | Rest]) :- N1 is N + 1, in_air(N1, Landed, Rest).

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
stay_days(City, D, N, Hours, Win, Kind, Interests, Used0, [day(N, Kind1, City, Travel, Acts, Alts, Hours, Win) | Days], NOut, Used) :-
    schedule_day(normal, City, Interests, Used0, Hours, Win, Acts, Alts, Used1),
    day_kind(Kind, Acts, Kind1, Travel),
    D1 is D - 1, N1 is N + 1,
    stay_days(City, D1, N1, 8, full, later, Interests, Used1, Days, NOut, Used).

day_kind(first, _, arrive, none).
day_kind(later, [], free, none) :- !.
day_kind(later, _, explore, none).

attach_moves(Days, Moves, Out) :- attach(Days, first, Moves, Out).

attach([], _, _, []).
attach([day(N, arrive, City, T, A, Alts, H, W) | Ds], first, Ms, [day(N, arrive, City, T, A, Alts, H, W) | Rest]) :- !,
    attach(Ds, later, Ms, Rest).
attach([day(N, arrive, City, none, A, Alts, H, W) | Ds], later, [move(F, City, M, P, Min) | Ms],
       [day(N, move, City, ground(F, City, M, P, Min), A, Alts, H, W) | Rest]) :- !,
    attach(Ds, later, Ms, Rest).
attach([D | Ds], Flag, Ms, [D | Rest]) :- attach(Ds, Flag, Ms, Rest).

moves_price([], 0).
moves_price([move(_, _, _, P, _) | Ms], T) :- moves_price(Ms, T0), T is T0 + P.

fees(Days, Total) :-
    findall(F, (member(day(_, _, _, _, Acts, _, _, _), Days), member(act(_, _, F, _, _, _, _), Acts)), Fs),
    sum(Fs, Total).

sum([], 0).
sum([X | Xs], T) :- sum(Xs, T0), T is T0 + X.

enjoyment(Days, Interests, E) :-
    findall(x, (member(day(_, _, _, _, Acts, _, _, _), Days), member(act(_, Cat, _, _, _, _, _), Acts), likes(Cat, Interests)), Xs),
    listlen(Xs, E).

% --- Interactive re-search across base trip days when user pins per-day categories (zero duplicates)
city_cats(City, Cats) :-
    findall(Cat, attraction(City, _, Cat, _, _, _, _, _), Cs),
    no_dups(Cs, Cats).

reschedule_days(DaySpecs, BaseInterests, DayPrefs, OutRows) :-
    resched_loop(DaySpecs, BaseInterests, DayPrefs, [], RawDays, UsedAll),
    clean_resched_rows(RawDays, UsedAll, OutRows).

resched_loop([], _, _, Used, [], Used).
resched_loop([[N, Kind, none, H, W] | Ds], BaseInt, Prefs, Used0,
             [[N, Kind, [], [], H, W] | Rest], UsedAll) :- !,
    resched_loop(Ds, BaseInt, Prefs, Used0, Rest, UsedAll).
resched_loop([[N, Kind, _City, H, W] | Ds], BaseInt, Prefs, Used0,
             [[N, Kind1, Acts, Alts, H, W] | Rest], UsedAll) :-
    (Kind = fly ; Kind = air), !,
    Kind1 = Kind, Acts = [], Alts = [],
    resched_loop(Ds, BaseInt, Prefs, Used0, Rest, UsedAll).
resched_loop([[N, Kind, City, H, W] | Ds], BaseInt, Prefs, Used0,
             [[N, Kind1, Acts, Alts, H, W] | Rest], UsedAll) :-
    (member([N, Cat], Prefs) ->
        Mode = strict, DayInt = [Cat]
    ;
        Mode = normal, DayInt = BaseInt
    ),
    schedule_day(Mode, City, DayInt, Used0, H, W, Acts, Alts, Used1),
    resched_kind(Kind, Acts, Kind1),
    resched_loop(Ds, BaseInt, Prefs, Used1, Rest, UsedAll).

resched_kind(explore, [], free) :- !.
resched_kind(free, [], free) :- !.
resched_kind(free, _, explore) :- !.
resched_kind(K, _, K).

clean_resched_rows([], _, []).
clean_resched_rows([[N, Kind, Acts, Alts0, _, _] | Ds], UsedAll,
                   [[N, Kind, ActRows, AltRows] | Rest]) :-
    findall(A, (member(A, Alts0), A = act(Name, _, _, _, _, _, _), \+ member(Name, UsedAll)), Alts),
    act_rows(Acts, ActRows),
    act_rows(Alts, AltRows),
    clean_resched_rows(Ds, UsedAll, Rest).

