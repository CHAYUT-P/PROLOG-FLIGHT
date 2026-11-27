from __future__ import annotations

import json
from pathlib import Path

from pyswip import Prolog

from geo import project

ROOT = Path(__file__).resolve().parent.parent
KB_PATH = ROOT / "prolog" / "trip.pl"
MAP_PATH = ROOT / "shared" / "asia_map.json"

HOMES = ["bangkok", "don_mueang", "chiang_mai", "phuket"]
INTERESTS = ["nature", "culture", "food", "shopping", "beach", "adventure", "nightlife"]
PACES = ["relaxed", "normal", "packed"]
PREFERENCES = ["cheapest", "fastest", "fewest", "balanced"]
MONTHS = ["January", "February", "March", "April", "May", "June", "July",
          "August", "September", "October", "November", "December"]
PREF_TEXT = {"cheapest": "Cheapest", "fastest": "Least time flying", "fewest": "Fewest flights",
             "balanced": "Best balance of price, flying time and things you like"}


MODE_NAME = {"high_speed": "Bullet train", "train": "Train", "bus": "Bus", "ferry": "Ferry", "plane": "Domestic flight",
             "night_bus": "Night bus", "night_train": "Night train", "night_ferry": "Night ferry"}


IMPORTANT = ("visa_ok", "visa_too_short", "highlight", "warning", "over_budget", "gateway")


class PlannerError(ValueError):
    pass


def baht(n: int) -> str:
    return f"฿ {n:,}"


def duration(minutes: int) -> str:
    h, m = divmod(int(minutes), 60)
    return f"{h} h {m:02d} min" if m else f"{h} h"


class Planner:
    def __init__(self) -> None:
        self.prolog = Prolog()
        self.prolog.consult(KB_PATH.as_posix())
        self._map = self._load_map()
        self.cities = {c["id"]: c for c in self._map["cities"]}
        self.countries = {c["id"]: c for c in self._map["countries"]}
        self.airports = {c["id"] for c in self._map["cities"] if c["zone"] is not None}
        self._city_cats: dict[str, list[str]] = {}


    def _one(self, query: str) -> dict | None:
        results = list(self.prolog.query(query, maxresult=1))
        return results[0] if results else None

    def _load_map(self) -> dict:
        res = self._one("map_data(Countries, Cities, Flights, Ground)")
        countries = [
            {"id": c[0], "name": c[1], "thai": c[2], "daily": c[3], "visa": None if c[4] == "none" else c[4]}
            for c in res["Countries"]
        ]
        cities = []
        for c in res["Cities"]:
            x, y = project(c[5], c[6])
            cities.append({
                "id": c[0], "name": c[1], "thai": c[2], "code": c[3], "country": c[4],
                "lat": c[5], "lon": c[6], "x": x, "y": y, "zone": None if c[7] == "none" else c[7],
            })
        flights = [
            {"code": f[0], "from": f[1], "to": f[2], "depart": f[3], "minutes": f[4], "price": f[5]}
            for f in res["Flights"]
        ]
        ground = [
            {"from": g[0], "to": g[1], "mode": g[2], "price": g[3], "minutes": g[4]}
            for g in res["Ground"]
        ]
        return {
            "countries": countries, "cities": cities, "flights": flights, "ground": ground,
            "outline": json.loads(MAP_PATH.read_text()),
        }

    def city_categories(self, city: str) -> list[str]:
        if city not in self._city_cats:
            res = self._one(f"city_cats({city}, Cats)")
            self._city_cats[city] = [str(c) for c in res["Cats"]] if res else []
        return self._city_cats[city]

    def replan_days(self, opt: dict, interests: list[str], day_prefs: dict[int, str],
                    people: int, budget: int) -> dict:
        specs = []
        for d in opt["days"]:
            city = d["city"] if d["city"] else "none"
            specs.append(f"[{d['day']},{d['kind']},{city},{float(d.get('hours', 0))},{d.get('window', 'full')}]")
        specs_term = "[" + ",".join(specs) + "]"
        prefs_term = "[" + ",".join(f"[{int(day)},{cat}]" for day, cat in sorted(day_prefs.items())) + "]"
        ints_term = "[" + ",".join(interests) + "]"
        q = f"reschedule_days({specs_term}, {ints_term}, {prefs_term}, OutRows)"
        res = self._one(q)
        if not res:
            return opt
        pack = lambda a: {
            "name": a[0], "category": a[1], "fee": a[2], "hours": float(a[3]),
            "zone": a[4], "slot": a[5], "details": a[6],
        }
        by_day = {int(row[0]): row for row in res["OutRows"]}
        for d in opt["days"]:
            row = by_day.get(d["day"])
            if not row:
                continue
            _, kind, act_rows, alt_rows = row
            d["kind"] = str(kind)
            d["activities"] = [pack(a) for a in act_rows]
            d["alternatives"] = [pack(a) for a in alt_rows]

        fees_pp = sum(a["fee"] for d in opt["days"] for a in d["activities"])
        opt["cost"]["fees"] = int(fees_pp) * people
        opt["cost"]["total"] = (opt["cost"]["flights"] + opt["cost"]["ground"]
                                + opt["cost"]["daily"] + opt["cost"]["fees"])
        opt["fits"] = opt["cost"]["total"] <= budget
        base_ints = set(interests or INTERESTS)
        opt["meta"]["enjoy"] = sum(
            1 for d in opt["days"] for a in d["activities"] if a["category"] in base_ints
        )
        opt["meta"]["free"] = sum(1 for d in opt["days"] if d["kind"] == "free")
        return opt

    def map_data(self) -> dict:
        return self._map

    def fare_routes(self, origin: str, destination: str) -> tuple[list, list]:
        origin_country = self.cities[origin]["country"]
        countries = ({c for c in self.countries if c != origin_country} if destination == "anywhere" else {destination})
        targets = {c["id"] for c in self._map["cities"] if c["country"] in countries}
        ends = {c["id"] for c in self._map["cities"] if c["country"] == origin_country and c["zone"] is not None}
        pairs = set()
        for f in self._map["flights"]:
            a, b = f["from"], f["to"]
            if (a in ends and b in targets) or (b in ends and a in targets) or (origin in (a, b) and {a, b} <= ends):
                pairs.add((a, b))
        outbound = sorted(p for p in pairs if p[0] == origin or (p[0] in ends and p[1] in targets))
        inbound = sorted(p for p in pairs if p not in outbound)
        return outbound, inbound

    def set_live_fares(self, fares: dict[tuple[str, str], int], offers: dict | None = None,
                       airline_offers: dict | None = None) -> None:
        list(self.prolog.query("clear_live"))
        for (a, b), price in fares.items():
            if a in self.cities and b in self.cities:
                self.prolog.assertz(f"live_fare({a}, {b}, {int(price)})")
        known = {(f["code"], f["from"], f["to"]): f["depart"] for f in self._map["flights"]}
        for (a, b), offer in (offers or {}).items():
            code = f'{offer.get("airline", "")}{offer.get("flight", "")}'
            time = offer.get("time", "")
            if offer.get("exact") and (code, a, b) in known and len(time) == 5:
                self.prolog.assertz(f"live_departure('{code}', {int(time[:2]) * 100 + int(time[3:])})")
        for (a, b), items in (airline_offers or {}).items():
            if a not in self.cities or b not in self.cities:
                continue
            for item in items:
                al = item.get("airline", "").strip()
                fl = item.get("flight", "").strip()
                price = int(item.get("price", 0))
                if not al or price <= 0:
                    continue
                code = f"{al}{fl}" if fl else al
                time = item.get("time", "")
                if len(time) == 5 and time[2] == ":":
                    hhmm = int(time[:2]) * 100 + int(time[3:])
                else:
                    hhmm = known.get((code, a, b), 1000)
                self.prolog.assertz(f"live_offer({a}, {b}, '{al}', '{code}', {hhmm}, {price})")

    def plan(self, origin, destination, days, month, people, budget, interests, pace, preference,
             options: dict | None = None) -> dict:
        if origin not in self.airports:
            raise PlannerError("Choose a departure city with an airport.")
        origin_country = self.cities[origin]["country"]
        if destination != "anywhere" and (destination not in self.countries or destination == origin_country):
            raise PlannerError("Choose a destination country different from your departure country.")
        if any(i not in INTERESTS for i in interests):
            raise PlannerError("Unknown interest.")
        if pace not in PACES or preference not in PREFERENCES:
            raise PlannerError("Unknown pace or preference.")
        days = max(3, min(21, int(days)))
        month = max(1, min(12, int(month)))
        people = max(1, min(6, int(people)))
        budget = max(0, int(budget))

        options = options or {}
        query = self._query(origin, destination, days, month, people, budget, interests, pace,
                            preference, options)
        res = self._one(query)
        if res is None:
            raise PlannerError("Prolog could not answer that query.")
        stats, rows = res["Result"]
        steps, edges, flight_options, plans, affordable = stats
        choice_cache: dict[tuple[str, str], list[dict]] = {}
        found = [self._option(r, preference, origin, choice_cache) for r in rows]
        benchmark = None
        if found and found[0]["outbound"]:
            arrive = found[0]["outbound"][-1]["to"]
            b = self._one(f"compare_all_search({origin}, {arrive}, {preference}, DF, UCS, AStar)")
            if b:
                benchmark = {
                    "from": origin, "to": arrive, "pref": preference,
                    "dfs": int(b["DF"]), "ucs": int(b["UCS"]), "astar": int(b["AStar"]),
                }
        trip = dict(origin=origin, destination=destination, days=days, month=month, people=people,
                    budget=budget, interests=interests, pace=pace, preference=preference,
                    options=options)
        return {
            "query": query,
            "stats": {
                "steps": steps,
                "explored": [[a, b] for a, b in edges],
                "flightOptions": flight_options,
                "plans": plans,
                "affordable": affordable,
            },
            "benchmark": benchmark,
            "options": found,
            "empty_reason": self._empty_reason(trip, flight_options, plans),
        }

    def _query(self, origin, destination, days, month, people, budget, interests, pace, preference,
               options: dict) -> str:
        opts = self.option_terms(options, destination)
        return (
            f"plan_trip({origin}, {destination}, {days}, {month}, {people}, {budget}, "
            f"[{','.join(interests)}], {pace}, {preference}, [{','.join(opts)}], Result)"
        )

    def _count_plans(self, trip: dict) -> int:
        res = self._one(self._query(**trip))
        return res["Result"][0][3] if res else 0

    def option_terms(self, options: dict, destination: str) -> list[str]:
        terms = []
        if options.get("max_flights") in (1, 2):
            terms.append(f'max_flights({options["max_flights"]})')
        if options.get("airlines") in ("budget", "full"):
            terms.append(f'airlines({options["airlines"]})')
        if options.get("night_flights") == "avoid":
            terms.append("night_flights(avoid)")
        if options.get("getting_around") in ("fast", "no_night"):
            terms.append(f'getting_around({options["getting_around"]})')
        picked = [c for c in options.get("cities", []) if c in self.cities
                  and (destination == "anywhere" or self.cities[c]["country"] == destination)]
        if picked:
            terms.append(f'cities([{",".join(picked)}])')
        return terms


    def _name(self, city_id: str) -> str:
        return self.cities[city_id]["name"]

    def _clock(self, city_id: str, utc_minutes: int) -> tuple[str, int]:
        local = utc_minutes + self.cities[city_id]["zone"] * 60
        day, clock = divmod(local, 1440)
        return f"{clock // 60:02d}:{clock % 60:02d}", day

    def _route_choices(self, origin: str, frm: str, to: str, cache: dict) -> list[dict]:
        key = (frm, to)
        if key in cache:
            return cache[key]
        res = self._one(f"route_choices({origin}, {frm}, {to}, Choices)")
        out = []
        for code, airline_name, airline_tier, dep, arr, price in (res["Choices"] if res else []):
            dep_clock, dep_day = self._clock(frm, dep)
            arr_clock, arr_day = self._clock(to, arr)
            out.append({
                "code": code, "airlineName": airline_name, "airlineTier": airline_tier,
                "price": price, "minutes": arr - dep,
                "depart": dep_clock, "arrive": arr_clock,
                "departDay": 0, "arriveDay": arr_day - dep_day,
            })
        cache[key] = out
        return out

    def _legs(self, rows, origin: str | None = None, choice_cache: dict | None = None) -> list[dict]:
        legs = []
        first_day = None
        for code, airline_name, airline_tier, frm, to, dep, arr, price, wait in rows:
            dep_clock, dep_day = self._clock(frm, dep)
            arr_clock, arr_day = self._clock(to, arr)
            if first_day is None:
                first_day = dep_day
            choices = (self._route_choices(origin, frm, to, choice_cache)
                       if (origin is not None and choice_cache is not None) else [])
            legs.append({
                "code": code, "airlineName": airline_name, "airlineTier": airline_tier,
                "from": frm, "to": to, "price": price, "wait": wait,
                "minutes": arr - dep,
                "depart": dep_clock, "arrive": arr_clock,
                "departDay": dep_day - first_day, "arriveDay": arr_day - first_day,
                "choices": choices,
            })
        return legs

    def _option(self, row, preference, origin: str | None = None, choice_cache: dict | None = None) -> dict:
        country, out, cities, moves, ret, days, cost, fits, reasons, meta = row
        flights, ground, daily, fees, total = cost
        landed, flight_minutes, enjoy, free = meta
        outbound, inbound = self._legs(out, origin, choice_cache), self._legs(ret, origin, choice_cache)
        return {
            "country": country,
            "cities": list(cities),
            "outbound": outbound,
            "inbound": inbound,
            "moves": [{"from": m[0], "to": m[1], "mode": m[2], "price": m[3], "minutes": m[4]} for m in moves],
            "days": [self._day(d) for d in days],
            "cost": {"flights": flights, "ground": ground, "daily": daily, "fees": fees, "total": total},
            "fits": fits == "yes",
            "reasons": [self._reason(r, preference) for r in reasons],
            "notes": [{"kind": r[0], "text": self._reason(r, preference)} for r in reasons if r[0] in IMPORTANT],
            "meta": {"landedDay": landed, "flightMinutes": flight_minutes, "enjoy": enjoy, "free": free},
        }

    def _day(self, d) -> dict:
        n, kind, city, travel, acts, alts, hours, window = d
        pack = lambda a: {
            "name": a[0], "category": a[1], "fee": a[2], "hours": float(a[3]),
            "zone": a[4], "slot": a[5], "details": a[6],
        }
        out = {
            "day": n, "kind": kind, "city": None if city == "none" else city, "travel": None,
            "hours": float(hours), "window": str(window),
            "activities": [pack(a) for a in acts],
            "alternatives": [pack(a) for a in alts],
        }
        if travel != "none":
            if travel[0] == "flights":
                out["travel"] = {"type": "flights", "legs": self._legs(travel[1])}
            else:
                _, frm, to, mode, price, minutes = travel
                out["travel"] = {"type": "ground", "from": frm, "to": to, "mode": mode,
                                 "price": price, "minutes": minutes}
        return out

    def _reason(self, r, preference) -> str:
        tag, *a = r
        n = self._name
        country = lambda c: self.countries[c]["name"]
        if tag == "best":
            return f"{PREF_TEXT[a[0]]} of {a[1]:,} plans Prolog built"
        if tag == "alternative":
            return f"Alternative #{a[0]}: visits different cities"
        if tag == "anywhere":
            return f"You picked anywhere, so Prolog chose {country(a[0])}: {a[1]} things you'd enjoy"
        if tag == "under_budget":
            return f"Fits your budget with {baht(a[0])} to spare"
        if tag == "over_budget":
            return f"Over budget by {baht(a[0])}. Nothing cheaper fits these days"
        if tag == "direct":
            way = "There" if a[0] == "out" else "Home"
            return f"{way}: direct flight {a[1]} from {n(a[2])} to {n(a[3])}"
        if tag == "change":
            way = "There" if a[0] == "out" else "Home"
            return f"{way}: change planes in {n(a[1])}, {duration(a[2])} between flights"
        if tag == "other_airport":
            return f"Flies home to {n(a[1])}, Bangkok's other airport (you left from {n(a[0])})"
        if tag == "overnight":
            return "Overnight flight: you sleep on the plane and land the next morning"
        if tag == "rooms":
            return f"{a[0]} travellers share {a[1]} hotel room{'s' if a[1] != 1 else ''}"
        if tag == "open_jaw":
            return f"Flies into {n(a[0])} and home from {n(a[1])}, so you never go back the same way"
        if tag == "city":
            cats = ", ".join(a[2])
            return f"{n(a[0])}: {a[1]} place{'s' if a[1] != 1 else ''} for {cats}"
        if tag == "visa_ok":
            return f"Thai passport: no visa needed for {country(a[0])} (up to {a[1]} days)"
        if tag == "visa_too_short":
            return f"Visa needed: Thai passports get only {a[1]} visa-free days in {country(a[0])}"
        if tag == "highlight":
            return f"Good timing: {a[1]} in {country(a[0])}"
        if tag == "warning":
            return f"Heads up: {a[1]} in {country(a[0])}"
        if tag == "prices":
            sign = lambda pct: f"{pct - 100:+d}%"
            return f"{MONTHS[a[1] - 1]} in {country(a[0])}: sample flight prices {sign(a[2])} compared with a normal month"
        if tag == "thai_holiday":
            return f"Thai holiday ({a[0]}): many Thais fly abroad, so flights from Thailand cost more"
        if tag == "live_fares":
            if a[0] == a[1]:
                return "Real fares from Aviasales for " + ("both flights" if a[1] == 2 else f"all {a[1]} flights")
            return f"Real fares from Aviasales for {a[0]} of {a[1]} flights; the others use sample prices"
        if tag == "full_service_estimate":
            return (f"{a[0]} is a full-service airline: priced at 60% above the cheapest real fare "
                    "on that route (Aviasales only gives the cheapest)")
        if tag == "sample_fares":
            return "Sample fares, adjusted for the month (no live price for these flights)"
        if tag == "max_flights":
            return "Direct flights only, as you asked" if a[0] == 1 else "At most one change of plane, as you asked"
        if tag == "airlines":
            return ("Budget airlines only (flights inside Thailand excepted)" if a[0] == "budget"
                    else "Full-service airlines only (flights inside Thailand excepted)")
        if tag == "no_night_flights":
            return "No take-offs between 22:00 and 06:00, as you asked"
        if tag == "your_cities":
            return "Visits only the cities you picked, in the best order"
        if tag == "gateway":
            return f"{n(a[0])} is only a stopover for one night: the nearest airport for the cities you picked"
        if tag == "getting_around":
            return ("Bullet trains, trains and flights only, as you asked" if a[0] == "fast"
                    else "No overnight buses, trains or ferries, as you asked")
        if tag == "on_board":
            return (f"{MODE_NAME.get(a[0], a[0])} from {n(a[1])} to {n(a[2])}: you sleep on board, "
                    "so no hotel that night")
        if tag == "no_free_days":
            return "Every day has something planned"
        if tag == "free_days":
            return f"{a[0]} free day{'s' if a[0] != 1 else ''}. Not enough places on the list to fill them"
        return " ".join(str(x) for x in r)

    def _empty_reason(self, trip: dict, flight_options: int, plans: int) -> str | None:
        if plans > 0:
            return None
        days, pace, options = trip["days"], trip["pace"], trip["options"]
        picked = [c for c in options.get("cities", []) if c in self.cities]
        if flight_options == 0:
            where = "any country" if trip["destination"] == "anywhere" else self.countries[trip["destination"]]["name"]
            limited = any(options.get(k) in v for k, v in
                          (("max_flights", (1, 2)), ("airlines", ("budget", "full")), ("night_flights", ("avoid",))))
            problem = (f"No flights from {self._name(trip['origin'])} reach {where}"
                       + (" with these flight options." if limited else "."))
        else:
            where = self._list([self._name(c) for c in picked], "and") if picked else "this country"
            problem = f"{days} days at a {pace} pace is not enough time for {where} with these options."

        tries = []
        if pace != "packed":
            tries.append(("change to a packed pace", {"pace": "packed"}))
        if options.get("max_flights") in (1, 2):
            tries.append(("allow more flight changes", {"options": {**options, "max_flights": 3}}))
        if options.get("airlines") in ("budget", "full"):
            tries.append(("allow any airline", {"options": {**options, "airlines": "any"}}))
        if options.get("night_flights") == "avoid":
            tries.append(("allow night flights", {"options": {**options, "night_flights": "allowed"}}))
        if len(picked) > 1:
            tries.append(("let Prolog choose the cities", {"options": {**options, "cities": []}}))
        twin = {"bangkok": "don_mueang", "don_mueang": "bangkok"}.get(trip["origin"])
        if twin:
            tries.append((f"fly from {self._name(twin)}", {"origin": twin}))
        works = [name for name, change in tries if self._count_plans({**trip, **change})]
        for more in range(days + 1, 22):
            if self._count_plans({**trip, "days": more}):
                works.append(f"take {more} days")
                break

        if not works:
            if flight_options == 0:
                return (f"Tang has no flight route from {self._name(trip['origin'])} to {where}. "
                        "Try another departure airport or destination.")
            return problem + " Try a different destination or other options."
        return f"{problem} Prolog finds plans if you {self._list(works, 'or')}."

    @staticmethod
    def _list(items: list[str], word: str) -> str:
        return items[0] if len(items) == 1 else ", ".join(items[:-1]) + f" {word} " + items[-1]


_planner: Planner | None = None


def get_planner() -> Planner:
    global _planner
    if _planner is None:
        _planner = Planner()
    return _planner


if __name__ == "__main__":
    p = get_planner()
    out = p.plan("bangkok", "japan", 7, 4, 2, 80000, ["food", "culture"], "normal", "cheapest")
    o = out["options"][0]
    print(o["cities"], o["cost"], o["fits"])
    print(o["outbound"])
    for r in o["reasons"]:
        print("  ⊢", r)
    for d in o["days"]:
        print(" ", d["day"], d["kind"], d["city"], d["travel"] and d["travel"]["type"], [a["name"] for a in d["activities"]])
