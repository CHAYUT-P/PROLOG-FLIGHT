from __future__ import annotations

import datetime as dt
import json
import os
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "cache" / "fares.json"
API = "https://api.travelpayouts.com/aviasales/v3/prices_for_dates"
FRESH_HOURS = 24

CITY_CODE = {
    "bangkok": "BKK", "don_mueang": "DMK", "chiang_mai": "CNX", "phuket": "HKT",
    "tokyo": "TYO", "osaka": "OSA", "sapporo": "SPK",
    "seoul": "SEL", "busan": "PUS",
    "shanghai": "SHA", "beijing": "BJS", "xian": "SIA",
    "singapore": "SIN",
}


def token() -> str | None:
    if os.environ.get("TRAVELPAYOUTS_TOKEN"):
        return os.environ["TRAVELPAYOUTS_TOKEN"].strip()
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text().splitlines():
            key, _, value = line.partition("=")
            if key.strip() == "TRAVELPAYOUTS_TOKEN" and value.strip():
                return value.strip().strip('"').strip("'")
    return None


def travel_month(month: int, today: dt.date | None = None) -> str:
    today = today or dt.date.today()
    year = today.year if month >= today.month else today.year + 1
    return f"{year}-{month:02d}"


def _load_cache() -> dict:
    try:
        return json.loads(CACHE.read_text())
    except (OSError, ValueError):
        return {}


def _save_cache(cache: dict) -> None:
    CACHE.parent.mkdir(exist_ok=True)
    CACHE.write_text(json.dumps(cache, indent=1, sort_keys=True))


def _fetch_one(key: str, origin: str, dest: str, month: str, tok: str) -> tuple[str, dict | None]:
    query = urllib.parse.urlencode({
        "origin": origin, "destination": dest, "departure_at": month, "one_way": "true",
        "direct": "true", "currency": "thb", "sorting": "price", "limit": 20,
    })
    req = urllib.request.Request(f"{API}?{query}", headers={"X-Access-Token": tok, "Accept-Encoding": "identity"})
    try:
        with urllib.request.urlopen(req, timeout=6) as r:
            body = json.loads(r.read().decode())
    except Exception:
        return key, None
    offers = [x for x in body.get("data", []) if x.get("price")]
    if not offers:
        return key, {"price": -1}
    offers.sort(key=lambda x: x["price"])
    by_airline: dict[str, dict] = {}
    for item in offers:
        al = item.get("airline", "")
        if al and al not in by_airline:
            w = item.get("departure_at", "")
            by_airline[al] = {
                "price": int(item["price"]), "date": w[:10], "time": w[11:16],
                "airline": al, "flight": str(item.get("flight_number", "")),
                "link": item.get("link", ""),
            }
        if len(by_airline) >= 6:
            break
    best = offers[0]
    when = best.get("departure_at", "")
    return key, {"price": int(best["price"]), "date": when[:10], "time": when[11:16],
                 "airline": best.get("airline", ""), "flight": str(best.get("flight_number", "")),
                 "link": best.get("link", ""), "airlines": list(by_airline.values())}


def _refresh(keys: list[str], cache: dict, tok: str | None) -> bool:
    now = dt.datetime.now()

    def fresh(key: str) -> bool:
        hit = cache.get(key)
        if not hit:
            return False
        if tok and hit.get("price", -1) > 0 and ("link" not in hit or "airlines" not in hit):
            return False
        return now - dt.datetime.fromisoformat(hit["at"]) < dt.timedelta(hours=FRESH_HOURS)

    todo = [k for k in dict.fromkeys(keys) if not fresh(k)]
    if not tok or not todo:
        return False
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda k: _fetch_one(k, k[:3], k[4:7], k[8:], tok), todo))
    got = False
    for key, offer in results:
        if offer is not None:
            cache[key] = {**offer, "at": now.isoformat(timespec="seconds")}
            got = True
    if got:
        _save_cache(cache)
    return got


def fares_for(outbound: list[tuple[str, str]], inbound: list[tuple[str, str]],
              go: dt.date, back: dt.date) -> dict:
    tok = token()
    cache = _load_cache()
    jobs = []
    for pairs, when in ((outbound, go), (inbound, back)):
        for a, b in pairs:
            if a in CITY_CODE and b in CITY_CODE:
                route = f"{CITY_CODE[a]}-{CITY_CODE[b]}"
                jobs.append(((a, b), f"{route}-{when.isoformat()}", f"{route}-{when:%Y-%m}"))

    got_days = _refresh([d for _, d, _ in jobs], cache, tok)
    missing = [m for _, d, m in jobs if not (cache.get(d) and cache[d]["price"] > 0)]
    got_months = _refresh(missing, cache, tok)

    fares, offers, airline_offers = {}, {}, {}
    for pair, day_key, month_key in jobs:
        for key, exact in ((day_key, True), (month_key, False)):
            hit = cache.get(key)
            if hit and hit["price"] > 0:
                fares[pair] = hit["price"]
                offers[pair] = {**hit, "exact": exact}
                al_list = hit.get("airlines") or [
                    {k: hit.get(k, "") for k in ("price", "date", "time", "airline", "flight", "link")}
                ]
                airline_offers[pair] = [{**a, "exact": exact} for a in al_list if a.get("price", 0) > 0]
                break
    if tok:
        status = "live" if (got_days or got_months or fares) else "cache"
    else:
        status = "cache" if fares else "off"
    return {"status": status, "fares": fares, "offers": offers, "airline_offers": airline_offers}


def marker() -> str | None:
    if os.environ.get("TRAVELPAYOUTS_MARKER"):
        return os.environ["TRAVELPAYOUTS_MARKER"].strip()
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text().splitlines():
            key, _, value = line.partition("=")
            if key.strip() == "TRAVELPAYOUTS_MARKER" and value.strip():
                return value.strip()
    return None
