from __future__ import annotations

import datetime as dt
from html import escape
from typing import Callable

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QPainter, QPen
from PySide6.QtWidgets import (
    QFrame, QGridLayout, QHBoxLayout, QLabel, QMenu, QPushButton, QSizePolicy, QVBoxLayout, QWidget,
)

import booking

from theme import C, MONO, THAI, color
from widgets import Clickable, clear_layout, eyebrow, hbox, label, vbox

GROUND = {"high_speed": "Bullet train", "train": "Train", "bus": "Bus", "ferry": "Ferry", "plane": "Domestic flight",
          "night_bus": "Night bus", "night_train": "Night train", "night_ferry": "Night ferry"}
RIDE = {"train": "train", "high_speed": "train", "night_train": "train", "bus": "bus", "night_bus": "bus",
        "ferry": "ferry", "night_ferry": "ferry", "plane": "air", "air": "air"}
OVERNIGHT = {"night_bus", "night_train", "night_ferry"}


def baht(n: float) -> str:
    return f"฿ {round(n):,}"


def dur(minutes: int) -> str:
    h, m = divmod(int(minutes), 60)
    if not h:
        return f"{m}m"
    return f"{h}h {m:02d}m" if m else f"{h}h"


def plural(n: int, word: str, many: str | None = None) -> str:
    return f"{n} {word if n == 1 else (many or word + 's')}"


def span(text: str, col: str = "ink", size: float | None = None, weight: int | None = None,
         family: str | None = None) -> str:
    style = f"color:{C[col]};"
    if size:
        style += f"font-size:{size}px;"
    if weight:
        style += f"font-weight:{weight};"
    if family:
        style += f'font-family:"{family}";'
    return f'<span style="{style}">{text}</span>'


class Swatch(QWidget):

    def __init__(self, ride: str, w: int = 16, h: int = 3):
        super().__init__()
        self.ride = ride
        self.setFixedSize(w, h)

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(color(RIDE.get(self.ride, "rule")))
        p.drawRoundedRect(self.rect(), 1.5, 1.5)


class Perforation(QWidget):

    def __init__(self):
        super().__init__()
        self.setFixedHeight(18)

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        pen = QPen(color("rule"), 1.5, Qt.PenStyle.DashLine)
        p.setPen(pen)
        y = self.height() / 2
        p.drawLine(QPointF(14, y), QPointF(self.width() - 14, y))
        p.setPen(QPen(color("rule"), 1))
        p.setBrush(color("paper"))
        p.drawEllipse(QPointF(-1, y), 9, 9)
        p.drawEllipse(QPointF(self.width() + 1, y), 9, 9)


class DurationLine(QWidget):
    def __init__(self, text: str):
        super().__init__()
        self.text = text
        self.setMinimumWidth(60)
        self.setFixedHeight(20)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        y = self.height() / 2
        p.setPen(QPen(color("rule"), 1))
        p.drawLine(QPointF(0, y), QPointF(self.width(), y))
        f = self.font()
        f.setFamily(MONO)
        f.setPixelSize(10)
        p.setFont(f)
        w = p.fontMetrics().horizontalAdvance(self.text) + 12
        r = QRectF((self.width() - w) / 2, 0, w, self.height())
        p.fillRect(r, color("panel"))
        p.setPen(color("ink3"))
        p.drawText(r, Qt.AlignmentFlag.AlignCenter, self.text)


class Meter(QWidget):
    def __init__(self, fraction: float, over: bool):
        super().__init__()
        self.fraction, self.over = fraction, over
        self.setFixedHeight(6)

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.setPen(Qt.PenStyle.NoPen)
        p.setBrush(color("rule"))
        p.drawRoundedRect(self.rect(), 3, 3)
        p.setBrush(color("danger" if self.over else "ink"))
        p.drawRoundedRect(QRectF(0, 0, self.width() * min(1.0, self.fraction), self.height()), 3, 3)


class DayRail(QWidget):

    def __init__(self, kind: str, last: bool):
        super().__init__()
        self.kind, self.last = kind, last

    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if not self.last:
            p.setPen(QPen(color("rule"), 1))
            p.drawLine(QPointF(5.5, 10), QPointF(5.5, self.height()))
        air = self.kind in ("fly", "air", "home")
        p.setPen(QPen(color("air" if air else "ink"), 1.5))
        p.setBrush(color("air" if air else ("ink" if self.kind == "move" else "paper")))
        p.drawEllipse(QPointF(5.5, 9.5), 5, 5)


def link(text: str, url: str) -> QLabel:
    lab = label(f'<a href="{escape(url)}" style="color:{C["ink"]}; font-weight:700;">{escape(text)} ↗</a>', rich=True)
    lab.setOpenExternalLinks(True)
    lab.setTextInteractionFlags(Qt.TextInteractionFlag.TextBrowserInteraction)
    lab.setToolTip(url)
    return lab


class ResultsPanel(QWidget):
    def __init__(self, cities: dict, countries: dict,
                 on_replan_day: Callable[[dict, int, str | None], None] | None = None,
                 city_cats_fn: Callable[[str], list[str]] | None = None):
        super().__init__()
        self.cities, self.countries = cities, countries
        self.on_replan_day = on_replan_day
        self.city_cats_fn = city_cats_fn
        self.lay = vbox(22, (24, 22, 24, 24))
        self.setLayout(self.lay)

        self.body = vbox(22)
        self.lay.addLayout(self.body)
        self.lay.addStretch()

    # ------------------------------------------------------------ simple states

    def _reset(self) -> None:
        clear_layout(self.body)

    def show_message(self, title: str, text: str) -> None:
        self._reset()
        box = vbox(6)
        rule = QFrame()
        rule.setFixedHeight(1)
        rule.setStyleSheet(f"background:{C['rule']};")
        box.addWidget(rule)
        box.addSpacing(10)
        box.addWidget(label(title, "emptyTitle"))
        box.addWidget(label(text, "muted", wrap=True))
        self.body.addLayout(box)

    def show_notice(self, text: str, error: bool = False) -> None:
        self._reset()
        self.body.addWidget(label(text, "error" if error else "notice", wrap=True))

    # ------------------------------------------------------------ a plan

    def show_plan(self, result: dict, selected: int, full: bool, searched: dict,
                  on_select: Callable[[int], None], offers: dict | None = None) -> None:
        self._reset()
        offers = offers or {}
        opts = result["options"]
        opt = opts[selected]
        start = booking.start_date(searched)
        self._refresh_args = (result, selected, full, searched, on_select, offers)
        self.body.addLayout(self._compare(opts, selected, on_select))
        self.body.addWidget(self._ticket(opt, searched["people"], searched["budget"]))
        if full:
            cols = hbox(28)
            left, right = vbox(24), vbox(0)
            if opt.get("notes"):
                left.addLayout(self._notes(opt["notes"]))
            left.addLayout(self._booking(opt, start, searched, offers))
            left.addLayout(self._costs(opt, searched["budget"], searched["people"]))
            if result.get("benchmark"):
                left.addLayout(self._benchmark(result["benchmark"]))
            left.addStretch()
            right.addLayout(self._days(opt, start, searched["people"], searched["budget"]))
            right.addStretch()
            cols.addLayout(left, 1)
            cols.addLayout(right, 1)
            self.body.addLayout(cols)

    def _compare(self, opts: list[dict], selected: int, on_select: Callable[[int], None]) -> QVBoxLayout:
        box = vbox(4)
        box.addWidget(label("Plans Prolog picked", "sectionTitle"))
        box.addSpacing(4)
        widths = (22, 0, 70, 52, 84)
        head = hbox(10, (12, 0, 12, 0))
        for text, w in zip(("", "WHERE", "FLYING", "FREE", "TOTAL"), widths):
            lab = label(text, "factKey")
            if w:
                lab.setFixedWidth(w)
            if text in ("TOTAL", "FREE", "FLYING"):
                lab.setAlignment(Qt.AlignmentFlag.AlignRight)
            head.addWidget(lab, 0 if w else 1)
        box.addLayout(head)
        for i, o in enumerate(opts):
            row = Clickable("tab")
            row.setProperty("on", "true" if i == selected else "false")
            row.setToolTip("Show this plan")
            rl = hbox(10, (12, 8, 12, 8))
            cities = " → ".join(self.cities[c]["name"] for c in o["cities"])
            cells = [
                span("ABC"[i], "ink3", 12, 700, MONO),
                span(escape(self.countries[o["country"]]["name"]), "ink", 14, 800) + "<br>"
                + span(escape(cities), "ink2", 12),
                span(dur(o["meta"]["flightMinutes"]), "ink2", 12, family=MONO),
                span(str(o["meta"]["free"]), "ink2", 12, family=MONO),
                span(baht(o["cost"]["total"]), "ink" if o["fits"] else "danger", 13, 700, MONO),
            ]
            for html, w in zip(cells, widths):
                lab = label(html, rich=True, wrap=not w)
                if w:
                    lab.setFixedWidth(w)
                    if html is not cells[0]:
                        lab.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
                rl.addWidget(lab, 0 if w else 1)
            row.setLayout(rl)
            row.clicked.connect(lambda k=i: on_select(k))
            box.addWidget(row)
        return box

    def _booking(self, opt: dict, start: dt.date, searched: dict, offers: dict) -> QVBoxLayout:
        cs = self.cities
        people = searched["people"]
        box = vbox(8)
        box.addWidget(label("Book it", "sectionTitle"))
        box.addWidget(label("Opens in your web browser. Prices there are live and may differ from the plan.", "fine",
                            wrap=True))
        home = opt["outbound"][0]["from"]
        arrive = opt["outbound"][-1]["to"]
        leave = opt["inbound"][0]["from"]
        back = booking.day_date(start, len(opt["days"]))
        land = opt["inbound"][-1]["to"]
        for title, frm, to, when in (("Going", home, arrive, start), ("Coming home", leave, land, back)):
            row = hbox(10)
            text = (span(title.upper(), "ink3", 10.5, family=MONO) + "<br>"
                    + span(f'{cs[frm]["code"]} → {cs[to]["code"]}', "ink", 15, 700, MONO) + "&nbsp;&nbsp;"
                    + span(f"{when:%a %d %b %Y}", "ink2", 13))
            offer = offers.get((frm, to))
            if offer and offer.get("exact"):
                text += "<br>" + span(f'Real fare that day: {offer["airline"]} {offer["flight"]} at {offer["time"]}, '
                                      f'{baht(offer["price"])}', "ok", 12)
                code = f'{offer.get("airline", "")} {offer.get("flight", "")}'.strip()
                btn_text = f"View {code}" if (offer.get("link") and code) else ("View flight" if offer.get("link") else "Search flights")
            elif offer:
                text += "<br>" + span(f'No fare on record for this day; cheapest that month was '
                                      f'{baht(offer["price"])} on {offer["date"][8:]}/{offer["date"][5:7]}', "ink3", 12)
                btn_text = "Search flights"
            else:
                btn_text = "Search flights"
            row.addWidget(label(text, rich=True, wrap=True), 1)
            row.addWidget(link(btn_text, booking.flight_link(frm, to, when, people, offer)), 0,
                          Qt.AlignmentFlag.AlignVCenter)
            box.addLayout(row)
        return box

    def _pick_airline(self, opt: dict, leg: dict, choice: dict, people: int, budget: int) -> None:
        for k in ("code", "airlineName", "airlineTier", "depart", "arrive", "price", "minutes"):
            leg[k] = choice[k]
        if leg["departDay"] == 0:
            leg["arriveDay"] = choice["arriveDay"]
        flights_pp = sum(l["price"] for l in opt["outbound"] + opt["inbound"])
        opt["cost"]["flights"] = flights_pp * people
        opt["cost"]["total"] = (opt["cost"]["flights"] + opt["cost"]["ground"]
                                + opt["cost"]["daily"] + opt["cost"]["fees"])
        opt["fits"] = opt["cost"]["total"] <= budget
        opt["meta"]["flightMinutes"] = sum(l["minutes"] for l in opt["outbound"] + opt["inbound"])
        for d in opt["days"]:
            if d["travel"] and d["travel"]["type"] == "flights":
                for dl in d["travel"]["legs"]:
                    if dl["from"] == leg["from"] and dl["to"] == leg["to"]:
                        for k in ("code", "airlineName", "airlineTier", "depart", "arrive", "price", "minutes"):
                            dl[k] = choice[k]
        self.show_plan(*self._refresh_args)

    def _ticket(self, opt: dict, people: int, budget: int = 0) -> QFrame:
        cs = self.cities
        home = cs[opt["outbound"][0]["from"]]
        country = self.countries[opt["country"]]
        ticket = QFrame()
        ticket.setObjectName("ticket")
        lay = vbox(0, (0, 16, 0, 14))
        ticket.setLayout(lay)

        head = hbox(12, (18, 0, 18, 8))
        for side, title in (("left", "From"), ("mid", ""), ("right", "Back to")):
            col = vbox(0)
            if side == "mid":
                col.addStretch()
                name = label(country["name"], "ticketCountry")
                name.setAlignment(Qt.AlignmentFlag.AlignCenter)
                thai = label(span(country["thai"], "ink2", 12, family=THAI), rich=True)
                thai.setAlignment(Qt.AlignmentFlag.AlignCenter)
                bar = QFrame()
                bar.setFixedHeight(2)
                bar.setStyleSheet(f"background:{C['air']};")
                col.addWidget(name)
                col.addWidget(thai)
                col.addSpacing(4)
                col.addWidget(bar)
                col.addSpacing(16)
                head.addLayout(col, 1)
                continue
            align = Qt.AlignmentFlag.AlignLeft if side == "left" else Qt.AlignmentFlag.AlignRight
            end = home if side == "left" else cs[opt["inbound"][-1]["to"]]
            for w in (eyebrow(title), label(end["code"], "ticketCode"), label(end["name"], "muted")):
                w.setAlignment(align)
                col.addWidget(w)
            head.addLayout(col)
        lay.addLayout(head)

        stops = hbox(6, (18, 4, 18, 12))
        for i, c in enumerate(opt["cities"]):
            if i > 0:
                mode = opt["moves"][i - 1]["mode"] if i - 1 < len(opt["moves"]) else "rule"
                stops.addWidget(Swatch(mode, 18, 3), 0, Qt.AlignmentFlag.AlignVCenter)
            stops.addWidget(label(cs[c]["code"], "stopCode"))
            stops.addWidget(label(cs[c]["name"]))
        stops.addStretch()
        lay.addLayout(stops)

        facts = QGridLayout()
        facts.setContentsMargins(18, 0, 18, 8)
        for i, (k, v) in enumerate((("DAYS", str(len(opt["days"]))), ("PEOPLE", str(people)),
                                    ("FLYING", dur(opt["meta"]["flightMinutes"])), ("TOTAL", baht(opt["cost"]["total"])))):
            facts.addWidget(label(k, "factKey"), 0, i)
            facts.addWidget(label(v, "factValue"), 1, i)
        lay.addLayout(facts)
        lay.addWidget(Perforation())
        lay.addLayout(self._flights("Going", opt, opt["outbound"], people, budget))
        lay.addSpacing(8)
        lay.addLayout(self._flights("Coming home", opt, opt["inbound"], people, budget))
        return ticket

    def _flights(self, title: str, opt: dict, legs: list[dict], people: int, budget: int) -> QVBoxLayout:
        cs = self.cities
        box = vbox(4, (18, 8, 18, 0))
        box.addWidget(eyebrow(title))
        for leg in legs:
            if leg["wait"]:
                box.addSpacing(6)
                box.addWidget(label(f'Change in {cs[leg["from"]]["name"]} {dur(leg["wait"])} between flights', "layover"))
                box.addSpacing(2)
            row = hbox(10)
            tier = "Budget" if leg.get("airlineTier") == "budget" else "Full-service"
            airline_label = leg.get("airlineName") or leg["code"]
            code = label(span(escape(airline_label), "ink", 11.5, 700) + "<br>"
                         + span(f'{escape(leg["code"])} · {tier}', "air", 10.5, 600, MONO), rich=True)
            code.setFixedWidth(132)
            plus = leg["arriveDay"] - leg["departDay"]
            dep = label(span(leg["depart"], "ink", 16, 700, MONO) + "<br>" + span(cs[leg["from"]]["code"], "ink2", 11.5, family=MONO), rich=True)
            arr = label(span(leg["arrive"], "ink", 16, 700, MONO)
                        + (span(f"+{plus}", "air", 10, family=MONO) if plus > 0 else "")
                        + "<br>" + span(cs[leg["to"]]["code"], "ink2", 11.5, family=MONO), rich=True)
            arr.setAlignment(Qt.AlignmentFlag.AlignRight)
            price = label(span(baht(leg["price"]), "ink2", 12, family=MONO), rich=True)
            price.setFixedWidth(64)
            price.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
            row.addWidget(code)
            row.addWidget(dep)
            row.addWidget(DurationLine(dur(leg["minutes"])), 1)
            row.addWidget(arr)
            row.addWidget(price)
            box.addLayout(row)
            choices = leg.get("choices") or []
            if len(choices) > 1:
                pick = QPushButton(f'Change airline ({len(choices)} choices)  ▾')
                pick.setObjectName("airlinePick")
                pick.setSizePolicy(QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed)
                pick.setCursor(Qt.CursorShape.PointingHandCursor)
                menu = QMenu(pick)
                for c in choices:
                    t = "Budget" if c["airlineTier"] == "budget" else "Full-service"
                    mark = "✓  " if c["code"] == leg["code"] else "    "
                    act = menu.addAction(
                        f'{mark}{c["airlineName"]} ({c["code"]} · {t}) · {c["depart"]}–{c["arrive"]} · {baht(c["price"])}'
                    )
                    act.triggered.connect(
                        lambda _=False, o=opt, l=leg, ch=c, p=people, b=budget: self._pick_airline(o, l, ch, p, b)
                    )
                pick.clicked.connect(lambda _=False, b=pick, m=menu: m.exec(b.mapToGlobal(b.rect().bottomLeft())))
                box.addWidget(pick)
        return box

    def _notes(self, notes: list[dict]) -> QVBoxLayout:
        mark = {"visa_ok": ("✓", "ok"), "visa_too_short": ("!", "danger"), "highlight": ("★", "marigold"),
                "warning": ("!", "danger"), "over_budget": ("!", "danger"), "gateway": ("i", "ink3")}
        box = vbox(6)
        box.addWidget(label("Good to know", "sectionTitle"))
        for n in notes:
            sym, col = mark.get(n["kind"], ("•", "ink3"))
            row = hbox(8)
            m = label(span(sym, col, 13, 800, MONO), rich=True)
            m.setFixedWidth(14)
            m.setAlignment(Qt.AlignmentFlag.AlignTop)
            row.addWidget(m)
            row.addWidget(label(n["text"], wrap=True), 1)
            box.addLayout(row)
        return box

    def _benchmark(self, bench: dict) -> QVBoxLayout:
        cs = self.cities
        box = vbox(6)
        box.addWidget(label("Search benchmark (Prolog)", "sectionTitle"))
        card = QFrame()
        card.setObjectName("benchCard")
        lay = vbox(8, (14, 10, 14, 10))
        route = f'{cs[bench["from"]]["code"]} → {cs[bench["to"]]["code"]}'
        lay.addWidget(label(span(f'Route {route} · mode: {bench["pref"]}', "ink2", 12, family=MONO), rich=True))
        grid = QGridLayout()
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setHorizontalSpacing(12)
        cols = (("DFS", f'{bench["dfs"]:,} steps'),
                ("UNIFORM-COST", f'{bench["ucs"]:,} steps'),
                ("A* (f=g+h)", f'{bench["astar"]:,} steps'))
        for i, (k, v) in enumerate(cols):
            grid.addWidget(label(k, "factKey"), 0, i)
            grid.addWidget(label(v, "factValue"), 1, i)
        lay.addLayout(grid)
        card.setLayout(lay)
        box.addWidget(card)
        return box

    def _days(self, opt: dict, start: dt.date, people: int, budget: int) -> QVBoxLayout:
        cs = self.cities
        box = vbox(0)
        box.addWidget(label("Day by day", "sectionTitle"))
        box.addSpacing(10)
        for n, d in enumerate(opt["days"]):
            city = cs.get(d["city"]) if d["city"] else None
            kind = d["kind"]
            where = {"fly": "Fly out", "air": "In the air"}.get(kind) or (
                f'Fly home from {city["name"]}' if kind == "home" else city["name"])
            rail = DayRail(kind, n == len(opt["days"]) - 1)
            inner = vbox(4, (22, 0, 0, 16))
            when = booking.day_date(start, d["day"])
            head = (span(f'DAY {d["day"]} {when:%a %d %b}'.upper(), "ink3", 11, family=MONO) + "&nbsp;&nbsp;"
                    + span(escape(where), "ink", 15.5, 700))
            if city and kind not in ("home", "fly"):
                head += "&nbsp;&nbsp;" + span(city["thai"], "ink2", 12, family=THAI)
            head_row = hbox(8)
            head_row.addWidget(label(head, rich=True), 1)
            if (self.on_replan_day and d["city"] and kind not in ("home", "fly", "air")
                    and float(d.get("hours", 0)) >= 2.0):
                day_prefs = opt.get("dayPrefs", {})
                pinned = day_prefs.get(d["day"])
                btn = QPushButton(f"{pinned.title()} ▾" if pinned else "Auto ▾")
                btn.setObjectName("dayCatPick")
                btn.setProperty("pinned", "true" if pinned else "false")
                btn.setCursor(Qt.CursorShape.PointingHandCursor)
                btn.setToolTip("Choose activity category for this day and re-plan")
                menu = QMenu(btn)
                auto_act = menu.addAction("Auto (Base interests)" if not pinned else "Reset to Auto")
                auto_act.triggered.connect(
                    lambda _=False, o=opt, dn=d["day"]: self.on_replan_day(o, dn, None)
                )
                cats = self.city_cats_fn(d["city"]) if self.city_cats_fn else []
                if cats:
                    menu.addSeparator()
                    for cat in cats:
                        prefix = "✓ " if cat == pinned else ""
                        act_item = menu.addAction(f"{prefix}{cat.title()}")
                        act_item.triggered.connect(
                            lambda _=False, o=opt, dn=d["day"], c=cat: self.on_replan_day(o, dn, c)
                        )
                btn.clicked.connect(lambda _=False, b=btn, m=menu: m.exec(b.mapToGlobal(b.rect().bottomLeft())))
                head_row.addWidget(btn, 0, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
            inner.addLayout(head_row)
            t = d["travel"]
            if t:
                ride = hbox(8)
                if t["type"] == "flights":
                    ride.addWidget(Swatch("air"), 0, Qt.AlignmentFlag.AlignVCenter)
                    text = ", ".join(f'{l["code"]} {l["depart"]} {cs[l["from"]]["code"]} → {l["arrive"]} {cs[l["to"]]["code"]}'
                                      for l in t["legs"])
                else:
                    ride.addWidget(Swatch(t["mode"]), 0, Qt.AlignmentFlag.AlignVCenter)
                    text = f'{GROUND[t["mode"]]} from {cs[t["from"]]["name"]} {dur(t["minutes"])} {baht(t["price"])}'
                    if t["mode"] in OVERNIGHT:
                        text += " overnight, arrives in the morning"
                ride.addWidget(label(text, "mono", wrap=True), 1)
                inner.addLayout(ride)
            if d["activities"]:
                inner.addWidget(self._day_activities(opt, d, people, budget))
            else:
                text = {"free": "Free day: nothing left on the list here, so wander or rest.",
                        "air": "Overnight in the air.", "fly": "Travel day.", "home": "Travel day."}.get(kind, "Arrive and settle in.")
                inner.addWidget(label(span(text, "ink3", 13), rich=True))
                if d.get("alternatives"):
                    alt_text = " · ".join(f'{a["name"]} ({a["category"]})' for a in d["alternatives"])
                    inner.addWidget(label(span(f"Nearby options: {escape(alt_text)}", "ink3", 12), rich=True, wrap=True))
            rail.setLayout(inner)
            box.addWidget(rail)
        return box

    def _day_activities(self, opt: dict, day: dict, people: int, budget: int) -> QWidget:
        acts = day["activities"]
        alts = day.get("alternatives", [])
        names = ", ".join(a["name"] for a in acts)
        total = sum(a["fee"] for a in acts)
        fees = baht(total) if total else "Free"

        box = QWidget()
        lay = vbox(4)
        row = Clickable("daySummary")
        row.setToolTip("Show activity details")
        line = hbox(10)
        text = label(span(escape(names), "ink2", 13.5), wrap=True, rich=True)
        line.addWidget(text, 1)
        right = label(span(f"{fees}  ▸", "ink2", 12.5, family=MONO), rich=True)
        right.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignTop)
        line.addWidget(right, 0, Qt.AlignmentFlag.AlignTop)
        row.setLayout(line)
        lay.addWidget(row)

        detail = QWidget()
        grid = QGridLayout()
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setHorizontalSpacing(10)
        grid.setVerticalSpacing(6)
        slot_label = {"morning": "Morning", "afternoon": "Afternoon", "evening": "Evening",
                      "all_day": "All day", "any": "Flexible"}
        for r, a in enumerate(acts):
            zone = str(a.get("zone", "")).replace("_", " ").title()
            slot = slot_label.get(a.get("slot", ""), "")
            meta = " · ".join(x for x in (slot, a.get("category", "").title(), zone, f'{a["hours"]:g}h') if x)
            desc = a.get("details", "")
            info_html = (span(escape(a["name"]), "ink", 13, 600) + "<br>"
                         + span(escape(meta), "ink3", 11, family=MONO)
                         + (("<br>" + span(escape(desc), "ink2", 12)) if desc else ""))
            grid.addWidget(label(info_html, rich=True, wrap=True), r, 0)
            fee = label(span(baht(a["fee"]) if a["fee"] else "Free", "ink2", 12.5, family=MONO), rich=True)
            fee.setMinimumWidth(56)
            fee.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignTop)
            grid.addWidget(fee, r, 1, Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignTop)
        if alts:
            alt_lines = [f'{escape(x["name"])} ({escape(x["category"])}, {x["hours"]:g}h)' for x in alts]
            alt_html = span("Alternatives: ", "ink3", 11.5, 700, MONO) + span(" · ".join(alt_lines), "ink3", 12)
            grid.addWidget(label(alt_html, rich=True, wrap=True), len(acts), 0, 1, 2)
        grid.setColumnStretch(0, 1)
        detail.setLayout(grid)
        detail.hide()
        lay.addWidget(detail)
        box.setLayout(lay)

        def toggle() -> None:
            opening = detail.isHidden()
            detail.setVisible(opening)
            text.setText(span(f"{len(acts)} activities" if opening else escape(names), "ink2", 13.5))
            right.setText(span(f"{fees}  {'▾' if opening else '▸'}", "ink2", 12.5, family=MONO))

        row.clicked.connect(toggle)
        return box

    def _costs(self, opt: dict, budget: int, people: int) -> QVBoxLayout:
        c = opt["cost"]
        box = vbox(0)
        box.addWidget(label(f'Cost for {plural(people, "person", "people")}', "sectionTitle"))
        box.addSpacing(8)
        rows = [("Flights", c["flights"])]
        if c["ground"]:
            rows.append(("Trains, buses & domestic flights", c["ground"]))
        rows += [("Food & local transport", c["daily"]), ("Entry fees", c["fees"]), ("Total", c["total"])]
        for k, v in rows:
            total = k == "Total"
            row = QHBoxLayout()
            row.setContentsMargins(0, 5, 0, 5)
            row.addWidget(label(span(k, "ink" if total else "ink2", 14, 700 if total else None), rich=True))
            row.addStretch()
            row.addWidget(label(span(baht(v), "ink", 14, 700 if total else None, MONO), rich=True))
            box.addLayout(row)
            if not total:
                line = QFrame()
                line.setFixedHeight(1)
                line.setStyleSheet(f"background:{C['rule']};")
                box.addWidget(line)
        box.addSpacing(8)
        box.addWidget(Meter(c["total"] / max(1, budget), not opt["fits"]))
        box.addSpacing(6)
        caption = (f'{baht(budget - c["total"])} left of your {baht(budget)} budget' if opt["fits"]
                   else f'{baht(c["total"] - budget)} over your {baht(budget)} budget')
        box.addWidget(label(caption, "muted"))
        box.addSpacing(10)
        box.addWidget(label("Sample prices and visa rules for a class project. "
                            "Check real fares and entry rules before you travel.", "fine", wrap=True))
        return box
