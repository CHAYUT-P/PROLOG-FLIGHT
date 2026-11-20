from __future__ import annotations

import datetime as dt
from html import escape
from typing import Callable

from PySide6.QtCore import QPointF, QRectF, Qt
from PySide6.QtGui import QPainter, QPen
from PySide6.QtWidgets import (
    QFrame, QGridLayout, QHBoxLayout, QLabel, QSizePolicy, QVBoxLayout, QWidget,
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
    def __init__(self, cities: dict, countries: dict):
        super().__init__()
        self.cities, self.countries = cities, countries
        self.lay = vbox(22, (24, 22, 24, 24))
        self.setLayout(self.lay)

        self.query = label("", "query", wrap=True)
        self.body = vbox(22)
        top = vbox(4)
        top.addWidget(eyebrow("Query"))
        top.addWidget(self.query)
        self.lay.addLayout(top)
        self.lay.addLayout(self.body)
        self.lay.addStretch()

    def set_query(self, text: str) -> None:
        self.query.setText(text)

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
        self.body.addLayout(self._compare(opts, selected, on_select))
        self.body.addWidget(self._ticket(opt, searched["people"]))
        if full:
            cols = hbox(28)
            left, right = vbox(24), vbox(0)
            if opt.get("notes"):
                left.addLayout(self._notes(opt["notes"]))
            left.addLayout(self._booking(opt, start, searched, offers))
            left.addLayout(self._costs(opt, searched["budget"], searched["people"]))
            left.addStretch()
            right.addLayout(self._days(opt, start))
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
        people, rooms = searched["people"], opt["meta"]["rooms"]
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
            elif offer:
                text += "<br>" + span(f'No fare on record for this day; cheapest that month was '
                                      f'{baht(offer["price"])} on {offer["date"][8:]}/{offer["date"][5:7]}', "ink3", 12)
            row.addWidget(label(text, rich=True, wrap=True), 1)
            row.addWidget(link("Search flights", booking.flight_link(frm, to, when, people)), 0,
                          Qt.AlignmentFlag.AlignVCenter)
            box.addLayout(row)
        country = self.countries[opt["country"]]["name"]
        for stay in booking.stays(opt):
            c = cs[stay["city"]]
            checkin = booking.day_date(start, stay["first"])
            checkout = booking.day_date(start, stay["first"] + stay["nights"])
            if stay["nights"] == 0:
                continue
            night = opt.get("roomPrice", {}).get(stay["city"])
            row = hbox(10)
            text = (span("HOTEL", "ink3", 10.5, family=MONO) + "<br>"
                    + span(escape(c["name"]), "ink", 15, 700) + "&nbsp;&nbsp;"
                    + span(f'{plural(stay["nights"], "night")} · {checkin:%d %b} – {checkout:%d %b}', "ink2", 13))
            if night:
                text += "<br>" + span(f"Plan uses about {baht(night)} a night per room", "ink3", 12)
            row.addWidget(label(text, rich=True, wrap=True), 1)
            row.addWidget(link("Find hotels", booking.hotel_link(c["name"], country, checkin, checkout, people, rooms)),
                          0, Qt.AlignmentFlag.AlignVCenter)
            box.addLayout(row)
        return box

    def _ticket(self, opt: dict, people: int) -> QFrame:
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
        lay.addLayout(self._flights("Going", opt["outbound"]))
        lay.addSpacing(8)
        lay.addLayout(self._flights("Coming home", opt["inbound"]))
        return ticket

    def _flights(self, title: str, legs: list[dict]) -> QVBoxLayout:
        cs = self.cities
        box = vbox(4, (18, 8, 18, 0))
        box.addWidget(eyebrow(title))
        for leg in legs:
            if leg["wait"]:
                box.addWidget(label(f'Change in {cs[leg["from"]]["name"]} · {dur(leg["wait"])} between flights', "layover"))
            row = hbox(10)
            code = label(span(escape(leg["code"]), "air", 11.5, 600, MONO), rich=True)
            code.setFixedWidth(56)
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

    def _days(self, opt: dict, start: dt.date) -> QVBoxLayout:
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
            head = (span(f'DAY {d["day"]} · {when:%a %d %b}'.upper(), "ink3", 11, family=MONO) + "&nbsp;&nbsp;"
                    + span(escape(where), "ink", 15.5, 700))
            if city and kind not in ("home", "fly"):
                head += "&nbsp;&nbsp;" + span(city["thai"], "ink2", 12, family=THAI)
            inner.addWidget(label(head, rich=True))
            t = d["travel"]
            if t:
                ride = hbox(8)
                if t["type"] == "flights":
                    ride.addWidget(Swatch("air"), 0, Qt.AlignmentFlag.AlignVCenter)
                    text = " · ".join(f'{l["code"]} {l["depart"]} {cs[l["from"]]["code"]} → {l["arrive"]} {cs[l["to"]]["code"]}'
                                      for l in t["legs"])
                else:
                    ride.addWidget(Swatch(t["mode"]), 0, Qt.AlignmentFlag.AlignVCenter)
                    text = f'{GROUND[t["mode"]]} from {cs[t["from"]]["name"]} · {dur(t["minutes"])} · {baht(t["price"])}'
                    if t["mode"] in OVERNIGHT:
                        text += " · overnight, arrives in the morning"
                ride.addWidget(label(text, "mono", wrap=True), 1)
                inner.addLayout(ride)
            if d["activities"]:
                inner.addWidget(self._day_activities(d["activities"]))
            else:
                text = {"free": "Free day: nothing left on the list here, so wander or rest.",
                        "air": "Overnight in the air.", "fly": "Travel day.", "home": "Travel day."}.get(kind, "Arrive and settle in.")
                inner.addWidget(label(span(text, "ink3", 13), rich=True))
            rail.setLayout(inner)
            box.addWidget(rail)
        return box

    @staticmethod
    def _day_activities(acts: list[dict]) -> QWidget:
        names = " · ".join(a["name"] for a in acts)
        total = sum(a["fee"] for a in acts)
        fees = baht(total) if total else "Free"

        box = QWidget()
        lay = vbox(4)
        row = Clickable("daySummary")
        row.setToolTip("Show each activity's price")
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
        grid.setVerticalSpacing(3)
        for r, a in enumerate(acts):
            grid.addWidget(label(a["name"], wrap=True), r, 0)
            fee = label(span(baht(a["fee"]) if a["fee"] else "Free", "ink2", 12.5, family=MONO), rich=True)
            fee.setMinimumWidth(56)
            fee.setAlignment(Qt.AlignmentFlag.AlignRight)
            grid.addWidget(fee, r, 1)
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
        c, m = opt["cost"], opt["meta"]
        box = vbox(0)
        box.addWidget(label(f'Cost for {plural(people, "person", "people")}', "sectionTitle"))
        box.addSpacing(8)
        rows = [("Flights", c["flights"])]
        if c["ground"]:
            rows.append(("Trains, buses & domestic flights", c["ground"]))
        rows += [(f'Hotels · {plural(m["nights"], "night")} · {plural(m["rooms"], "room")}', c["hotel"]),
                 ("Food & local transport", c["daily"]), ("Entry fees", c["fees"]), ("Total", c["total"])]
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
