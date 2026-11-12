"""Booking links and calendar dates for a plan.

Plain web links, no extra API: an Aviasales flight search for each flight
day, and a Booking.com hotel search for each stay, for the dates chosen in the form.
"""

from __future__ import annotations

import datetime as dt
import urllib.parse

from live_prices import CITY_CODE, marker


def start_date(searched: dict) -> dt.date:
    """Day 1 of the trip: the departure date chosen in the form."""
    return searched["date"]


def day_date(start: dt.date, day: int) -> dt.date:
    return start + dt.timedelta(days=day - 1)


def flight_link(frm: str, to: str, when: dt.date, people: int) -> str:
    """Aviasales search: origin + DDMM + destination + number of passengers."""
    url = f"https://www.aviasales.com/search/{CITY_CODE[frm]}{when:%d%m}{CITY_CODE[to]}{people}"
    m = marker()
    return f"{url}?marker={urllib.parse.quote(m)}" if m else url


def hotel_link(city: str, country: str, checkin: dt.date, checkout: dt.date, people: int, rooms: int) -> str:
    query = urllib.parse.urlencode({
        "ss": f"{city}, {country}", "checkin": checkin.isoformat(), "checkout": checkout.isoformat(),
        "group_adults": people, "no_rooms": rooms, "group_children": 0,
    })
    return f"https://www.booking.com/searchresults.html?{query}"


OVERNIGHT = {"night_bus", "night_train", "night_ferry"}


def stays(opt: dict) -> list[dict]:
    """Group the city days into hotel stays: city, first day, last day, nights, activities.
    If you leave a city on an overnight bus/train/ferry, its last night is spent on board."""
    out: list[dict] = []
    for d in opt["days"]:
        if d["kind"] in ("fly", "air", "home") or not d["city"]:
            continue
        if out and out[-1]["city"] == d["city"] and out[-1]["last"] == d["day"] - 1:
            out[-1]["last"] = d["day"]
        else:
            ride = d["travel"] if d["travel"] and d["travel"]["type"] == "ground" else None
            if out and ride and ride["mode"] in OVERNIGHT:
                out[-1]["on_board"] = ride["mode"]
            out.append({"city": d["city"], "first": d["day"], "last": d["day"], "acts": [], "on_board": None})
        out[-1]["acts"] += [a["name"] for a in d["activities"]]
    for s in out:
        s["nights"] = s["last"] - s["first"] + (0 if s["on_board"] else 1)
    return out
