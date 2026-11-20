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

    def map_data(self) -> dict:
        return self._map

    def fare_routes(self, origin: str, destination: str) -> tuple[list, list]:
        countries = ({c for c in self.countries if c != "thailand"} if destination == "anywhere" else {destination})
        targets = {c["id"] for c in self._map["cities"] if c["country"] in countries}
        ends = {origin, "bangkok", "don_mueang"}
        pairs = set()
        for f in self._map["flights"]:
            a, b = f["from"], f["to"]
            if (a in ends and b in targets) or (b in ends and a in targets) or (origin in (a, b) and {a, b} <= ends):
                pairs.add((a, b))
        outbound = sorted(p for p in pairs if p[0] == origin or (p[0] in ends and p[1] in targets))
        inbound = sorted(p for p in pairs if p not in outbound)
        return outbound, inbound

    def set_live_fares(self, fares: dict[tuple[str, str], int], offers: dict | None = None) -> None:
        list(self.prolog.query("clear_live"))
        for (a, b), price in fares.items():
            if a in self.cities and b in self.cities:
                self.prolog.assertz(f"live_fare({a}, {b}, {int(price)})")
        known = {(f["code"], f["from"], f["to"]) for f in self._map["flights"]}
        for (a, b), offer in (offers or {}).items():
            code = f'{offer.get("airline", "")}{offer.get("flight", "")}'
            time = offer.get("time", "")
            if offer.get("exact") and (code, a, b) in known and len(time) == 5:
                self.prolog.assertz(f"live_departure('{code}', {int(time[:2]) * 100 + int(time[3:])})")

    def plan(self, origin, destination, days, month, people, budget, interests, pace, preference,
             options: dict | None = None) -> dict:
        if origin not in HOMES:
            raise PlannerError("Start from Bangkok (BKK or DMK), Chiang Mai or Phuket.")
        if destination != "anywhere" and (destination not in self.countries or destination == "thailand"):
            raise PlannerError("Unknown destination.")
        if any(i not in INTERESTS for i in interests):
            raise PlannerError("Unknown interest.")
        if pace not in PACES or preference not in PREFERENCES:
            raise PlannerError("Unknown pace or preference.")
        days = max(3, min(21, int(days)))
        month = max(1, min(12, int(month)))
        people = max(1, min(6, int(people)))
        budget = max(0, int(budget))

        opts = self.option_terms(options or {}, destination)
        query = (
            f"plan_trip({origin}, {destination}, {days}, {month}, {people}, {budget}, "
            f"[{','.join(interests)}], {pace}, {preference}, [{','.join(opts)}], Result)"
        )
        res = self._one(query)
        if res is None:
            raise PlannerError("Prolog could not answer that query.")
        stats, rows = res["Result"]
        steps, edges, flight_options, plans, affordable = stats
        options = [self._option(r, preference) for r in rows]
        return {
            "query": query,
            "stats": {
                "steps": steps,
                "explored": [[a, b] for a, b in edges],
                "flightOptions": flight_options,
                "plans": plans,
                "affordable": affordable,
            },
            "options": options,
            "empty_reason": self._empty_reason(origin, destination, flight_options, plans, days, pace),
        }

    def option_terms(self, options: dict, destination: str) -> list[str]:
        terms = []
        if options.get("max_flights") in (1, 2):
            terms.append(f'max_flights({options["max_flights"]})')
        if options.get("airlines") in ("budget", "full"):
            terms.append(f'airlines({options["airlines"]})')
        if options.get("night_flights") == "avoid":
            terms.append("night_flights(avoid)")
        if options.get("hotel") in ("budget", "luxury"):
            terms.append(f'hotel({options["hotel"]})')
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

    def _legs(self, rows) -> list[dict]:
        legs = []
        first_day = None
        for code, frm, to, dep, arr, price, wait in rows:
            dep_clock, dep_day = self._clock(frm, dep)
            arr_clock, arr_day = self._clock(to, arr)
            if first_day is None:
                first_day = dep_day
            legs.append({
                "code": code, "from": frm, "to": to, "price": price, "wait": wait,
                "minutes": arr - dep,
                "depart": dep_clock, "arrive": arr_clock,
                "departDay": dep_day - first_day, "arriveDay": arr_day - first_day,
            })
        return legs

    def _option(self, row, preference) -> dict:
        country, out, cities, moves, ret, days, cost, fits, reasons, meta, rooms_per_night = row
        flights, ground, hotel, daily, fees, total = cost
        rooms, nights, landed, flight_minutes, enjoy, free = meta
        outbound, inbound = self._legs(out), self._legs(ret)
        return {
            "country": country,
            "cities": list(cities),
            "outbound": outbound,
            "inbound": inbound,
            "moves": [{"from": m[0], "to": m[1], "mode": m[2], "price": m[3], "minutes": m[4]} for m in moves],
            "days": [self._day(d) for d in days],
            "cost": {"flights": flights, "ground": ground, "hotel": hotel, "daily": daily, "fees": fees, "total": total},
            "fits": fits == "yes",
            "reasons": [self._reason(r, preference) for r in reasons],
            "notes": [{"kind": r[0], "text": self._reason(r, preference)} for r in reasons if r[0] in IMPORTANT],
            "roomPrice": {c: p for c, p in rooms_per_night},
            "meta": {"rooms": rooms, "nights": nights, "landedDay": landed,
                     "flightMinutes": flight_minutes, "enjoy": enjoy, "free": free},
        }

    def _day(self, d) -> dict:
        n, kind, city, travel, acts = d
        out = {
            "day": n, "kind": kind, "city": None if city == "none" else city, "travel": None,
            "activities": [{"name": a[0], "category": a[1], "fee": a[2], "hours": float(a[3])} for a in acts],
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
            return (f"{MONTHS[a[1] - 1]} in {country(a[0])}: sample flight prices {sign(a[2])}, "
                    f"hotels {sign(a[3])} compared with a normal month")
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
        if tag == "hotel":
            return ("Budget hotels: about 40% cheaper than mid-range" if a[0] == "budget"
                    else "Luxury hotels: about 2.2 times mid-range prices")
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

    def _empty_reason(self, origin, destination, flight_options, plans, days, pace) -> str | None:
        if flight_options == 0:
            where = "any country" if destination == "anywhere" else self.countries[destination]["name"]
            return (f"No flights from {self._name(origin)} reach {where} with these flight options. "
                    "Try allowing more changes, any airline, or night flights.")
        if plans == 0:
            return (f"No plan fits {days} days at a {pace} pace with these options. "
                    "Add days, choose a faster pace, allow more flight changes or any airline, "
                    "or pick different cities.")
        return None


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
