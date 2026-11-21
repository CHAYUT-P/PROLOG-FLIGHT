# Tang (ทาง) — Asia trip planner in Prolog + Python

Plan a round trip from Thailand (Bangkok BKK & DMK, Chiang Mai or Phuket) to Japan,
South Korea, China or Singapore: flights with connections, 2–4 cities inside the country, a
day-by-day plan, the full cost, and the reasons for every choice.

All of the reasoning is in **Prolog** (`prolog/trip.pl`). Everything else is
**Python**: `backend/planner.py` asks Prolog questions through **pyswip**, and
the desktop app is built with **PySide6 (Qt)**.

```
prolog/trip.pl        knowledge base + rules   ← the brain
backend/planner.py    pyswip bridge: builds queries, turns answers into Python dicts
backend/geo.py        latitude/longitude → map position
backend/live_prices.py  optional real fares (Aviasales API) → Prolog facts
app.py                the main window: form, status bar, wiring to Prolog
ui/booking.py         dates and booking links (direct Aviasales flight links when available, Booking.com hotels)
ui/map_view.py        the Asia map: search replay, flying plane, camera zoom
ui/results.py         the ticket, reasons, day-by-day plan, costs
ui/widgets.py         small controls (segmented buttons, chips, steppers)
ui/theme.py           colours (light and dark) and the Qt stylesheet
ui/fonts/             Overpass and IBM Plex Sans Thai (SIL Open Font License)
shared/asia_map.json  country outlines (from Natural Earth)
tools/build_map.py    rebuilds the outline file
```

## Setup (once)

```bash
brew install swi-prolog
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## Run

```bash
.venv/bin/python app.py
```
A window opens. No browser and no internet needed.

Prolog only:
```bash
swipl prolog/trip.pl
```
```prolog
?- fly(bangkok, tokyo, Legs).
?- plan_trip(bangkok, japan, 7, 4, 1, 60000, [food, culture], normal, cheapest, R).
?- plan_trip(bangkok, japan, 7, 4, 1, 60000, [food], normal, cheapest, [max_flights(1), cities([tokyo, kyoto])], R).
```

## Extra choices (all checked by Prolog rules, section 3a of `trip.pl`)

| Choice | Prolog rule |
|---|---|
| Flight changes: direct / 1 / 2 | `opt(max_flights, Max)` limits best-first search |
| Airlines: any / budget / full-service | `airline_ok/3` with `low_cost/1` and `airline/2` |
| Avoid night flights | `daytime_ok/1`: no take-off 22:00–06:00 |
| Hotels: budget / mid-range / luxury | `hotel_factor/2` in `room_price/2` |
| Cities to visit | `chosen_ok/2`: the tour visits exactly the picked cities; an airport "gateway" city is allowed only next to a picked city with no airport (Kyoto → Osaka) |
| Getting around: any / fast / no night rides | `ground_ok/1` filters the trains, buses, ferries and flights between cities |

Options arrive as a list, e.g. `[max_flights(1), hotel(luxury), cities([tokyo, kyoto])]`,
and are stored as `option(Name, Value)` facts using `=..` (section 6.5).

## Travel between cities

`ground/5` lists typical fares (mock data) for bullet trains (Shinkansen, KTX,
Taiwan HSR, Chinese high-speed rail), ordinary trains, buses, ferries,
domestic flights, and **overnight** night buses, night trains and night ferries.
`overnight/1` marks the night rides: Prolog saves that night's hotel
(`on_board/3`) and gives you the whole next day (`next_city/4`).

## Prices: the month matters, and real fares are optional

- **Season rule (always on):** `busy/3` and `thai_holiday/3` in `trip.pl` raise or
  lower sample flight and hotel prices by month (cherry blossoms, Golden Week,
  typhoons, Songkran, New Year…). `flight_price/5` and `room_price/2` apply them.
- **Real fares (optional):** with a free token from travelpayouts.com, Python
  (`backend/live_prices.py`) fetches the cheapest recent direct fares from
  Aviasales for your exact departure and return days (or, if a day has no data,
  the cheapest that month) and gives them to Prolog with `assertz` as
  `live_fare(From, To, Price)` facts. When the cheapest flight that day is one
  of our flights, its real time is passed too (`live_departure(Code, HHMM)`), and
  `departs/3` uses it. When an exact-day fare is found, its Aviasales `link`
  deeplink is saved too so **Book it** links directly to that flight (`View <flight>`),
  falling back to a route/date search otherwise. Prolog's `flight_price/5` uses a real fare
  when there is one and falls back to the season price otherwise. Fares are
  saved in `cache/fares.json`, so a demo works offline.

  To turn it on, create a file named `.env` in the project folder containing:
  ```
  TRAVELPAYOUTS_TOKEN=your-token-here
  ```
  Never share the token or put it in the code. `.env` is in `.gitignore`.

## Uses only what "Programming in Prolog" (Clocksin & Mellish) teaches

| Part of `trip.pl` | Book chapter |
|---|---|
| Facts: 15 cities (including Bangkok BKK & DMK), 13 airports, 62 flights, 18 ground routes, 107 attractions, hotels, visas, seasons | ch.1 facts |
| `clock_minutes`, `to_utc`, `local_time`, `departure`: times, time zones, layovers | ch.2 arithmetic (`is`, `//`, `mod`) |
| `listlen`, `last_elem`, `take`, `sum`, `no_dups`, `share` | ch.3 lists, recursion, accumulators |
| `best_routes/5`, `bf/5`, `shortest/3`: **best-first search** for the best flight route (cheapest / fastest / fewest flights), up to 3 flights | ch.7.9 `go3` best-first search |
| `fly/3`: depth-first search with a trail (kept for comparison; `compare_search/5` shows best-first does less work) | ch.7.9 `go`/`legalnode` |
| `tour/4`, `round_tour/4`: cities to visit inside a country | ch.7.9 + ch.3 |
| `candidate/8`: fly in → tour → fly home | ch.4 generate and test |
| `share_days/4`: each city gets its minimum stay (`stay_range/3`, e.g. Tokyo 3–6 days), then spare days go one by one to the city with the most room left | ch.3 recursion, accumulators |
| `fit/4`, `enough_time/2`, `day_kind/4`, `flight_price/5`, `departs/3` … | ch.4 cut `!` |
| `airline/2`: reads the airline from the flight code | ch.6 `atom_chars` |
| `best_flights/4`: remembers answers with `assertz`; `live_fare/3`, `live_departure/2` facts from Python | ch.6 / 7.8 using the database |
| `insort/2`: ranking plans | ch.7.7 insertion sort |
| `reasons/11`: explanations returned as lists | ch.1 rules |

Not used: `format`, `aggregate_all`, `keysort`, `msort`, `length`, `maplist`,
`->` (if-then-else), or any other SWI-Prolog extras.

## Main rules worth presenting

- **Connections & Thai hubs:** a change of plane counts only if the next flight leaves at
  least 90 minutes after landing and within 12 hours, worked out in UTC so time
  zones are handled. `bad_thai_hop/3` prevents Bangkok (`BKK` / `DMK`) trips
  from detouring through Chiang Mai or Phuket before flying abroad.
- **Days:** an overnight flight means you land on day 2 (and need one hotel
  night less). Free hours on arrival day = from an hour after landing until 21:00.
- **Empty days:** a day with nothing planned costs its share of the trip, so
  Prolog prefers plans that keep you busy.
- **"Anywhere":** each country's best plan is scored as cost minus ฿3,000 for
  every activity you would enjoy.
- **Advice:** visa-free days for Thai passports, seasons (cherry blossoms,
  typhoons, monsoon) for the chosen month.

Prices, timetables and visa rules are sample data for a class project.
# PROLOG-FLIGHT
