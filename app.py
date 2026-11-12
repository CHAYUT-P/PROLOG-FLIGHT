"""Tang (ทาง) — Asia trip planner. A desktop app in Python (PySide6 / Qt)
on top of Prolog (pyswip).

Run:  .venv/bin/python app.py

The window only collects the traveller's choices and draws Prolog's answer.
Every decision — flights, cities, days, costs, reasons — comes from
prolog/trip.pl through backend/planner.py.
"""

from __future__ import annotations

import datetime as dt
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "backend"))
sys.path.insert(0, str(ROOT / "ui"))

from concurrent.futures import Future, ThreadPoolExecutor  # noqa: E402

from PySide6.QtCore import Qt, QTimer  # noqa: E402
from PySide6.QtWidgets import (  # noqa: E402
    QApplication, QFrame, QGridLayout, QHBoxLayout, QMainWindow, QPushButton, QScrollArea, QSlider, QWidget,
)

import theme  # noqa: E402
from map_view import MapView  # noqa: E402
import live_prices  # noqa: E402
from planner import PlannerError, get_planner  # noqa: E402
from results import ResultsPanel, baht, plural, span  # noqa: E402
from theme import C, MONO, THAI  # noqa: E402
from widgets import (  # noqa: E402
    Chip, DatePicker, FlowLayout, Segmented, StationCard, Stepper, chips_box, eyebrow, field, hbox, label, vbox,
)

HOMES = [("bangkok", "BKK\nBangkok"), ("chiang_mai", "CNX\nChiang Mai"), ("phuket", "HKT\nPhuket")]
INTERESTS = [("food", "Food"), ("culture", "Temples && history"), ("nature", "Nature"), ("beach", "Beaches"),
             ("shopping", "Shopping"), ("adventure", "Adventure"), ("nightlife", "Nightlife")]
PACES = [("relaxed", "Relaxed\n3+ days a city"), ("normal", "Normal\n2+ days a city"), ("packed", "Packed\n1+ day a city")]
PREFS = [("cheapest", "Cheapest"), ("fastest", "Least flying"), ("fewest", "Fewest flights"), ("balanced", "Balanced")]
STOPS = [("1", "Direct only"), ("2", "1 change"), ("3", "2 changes")]
AIRLINES = [("any", "Any"), ("budget", "Budget only"), ("full", "Full-service")]
HOTELS = [("budget", "Budget"), ("mid", "Mid-range"), ("luxury", "Luxury")]
AROUND = [("any", "Any"), ("fast", "Fast"), ("no_night", "No night rides")]
MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
FARES = {"live": "live fares", "cache": "saved fares", "none": "no live fares, sample prices",
         "error": "fare check failed, sample prices", "off": "sample prices"}


def legend_item(ride: str, text: str) -> QWidget:
    from results import Swatch
    w = QWidget()
    lay = hbox(6)
    sw = Swatch(ride, 22, 3)
    lay.addWidget(sw, 0, Qt.AlignmentFlag.AlignVCenter)
    lay.addWidget(label(span(text, "ink2", 12), rich=True))
    w.setLayout(lay)
    return w


class TangWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.planner = get_planner()
        self.data = self.planner.map_data()
        self.cities = {c["id"]: c for c in self.data["cities"]}
        self.countries = {c["id"]: c for c in self.data["countries"]}
        leave = dt.date.today() + dt.timedelta(days=30)
        self.form = {"from": "bangkok", "to": "japan", "date": leave, "month": leave.month, "days": 7,
                     "people": 2, "budget": 90000, "max_flights": 3, "airlines": "any", "night_flights": "allowed",
                     "hotel": "mid", "cities": [], "getting_around": "any",
                     "interests": ["food", "culture"], "pace": "normal", "pref": "cheapest"}
        self.phase = "idle"          # idle | searching | travelling | done
        self.pool = ThreadPoolExecutor(max_workers=1)
        self.fare_status = "off"
        self.offers: dict = {}
        self.result: dict | None = None
        self.selected = 0
        self.searched: dict | None = None

        self.setWindowTitle("Tang · Asia trip planner")
        self.resize(1440, 900)
        self.setMinimumSize(1120, 720)

        root = QWidget()
        root.setObjectName("root")
        outer = vbox(0)
        root.setLayout(outer)
        self.setCentralWidget(root)
        outer.addWidget(self._masthead())

        body = QHBoxLayout()
        body.setSpacing(0)
        body.setContentsMargins(0, 0, 0, 0)
        outer.addLayout(body, 1)

        # search form | the plan (wide) | the map (narrow, can be expanded)
        self.form_panel = self._scroll(self._form(), "formPanel", 340)
        body.addWidget(self.form_panel)
        self.results = ResultsPanel(self.cities, self.countries)
        body.addWidget(self._plan_column(), 1)
        self.map_column = self._map_column()
        body.addWidget(self.map_column)

        self.map.country_picked.connect(lambda c: self.update_form(to=c))
        self.map.set_focus(self.form["to"])
        self.refresh_query()
        self.results.show_message("Where to?", "Pick a country, or click one on the map, and set your days and budget. "
                                  "Prolog searches every flight connection, plans the cities and days, and explains "
                                  "why it picked each trip.")

    # ------------------------------------------------------------ layout

    def _scroll(self, inner: QWidget, name: str, width: int) -> QScrollArea:
        area = QScrollArea()
        area.setObjectName(name)
        area.setWidget(inner)
        area.setWidgetResizable(True)
        area.setFixedWidth(width)
        area.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        return area

    def _masthead(self) -> QWidget:
        bar = QFrame()
        bar.setObjectName("masthead")
        lay = hbox(10, (24, 12, 24, 12))
        lay.addWidget(label(span("ทาง", "ink", 28, 700, THAI) + "&nbsp;&nbsp;" + span("tang", "ink", 22, 800)
                            + "&nbsp;&nbsp;&nbsp;" + span("Asia trip planner from Thailand · reasoning in Prolog", "ink2", 13),
                            rich=True))
        lay.addStretch()
        for ride, text in (("air", "Flight"), ("train", "Train"), ("bus", "Bus"), ("ferry", "Ferry")):
            lay.addWidget(legend_item(ride, text))
            lay.addSpacing(10)
        trace = QWidget()
        tl = hbox(6)
        swatch = QFrame()
        swatch.setFixedSize(22, 3)
        swatch.setStyleSheet(f"background:{C['marigold']}; border-radius:1px;")
        tl.addWidget(swatch, 0, Qt.AlignmentFlag.AlignVCenter)
        tl.addWidget(label(span("Prolog search", "ink2", 12), rich=True))
        trace.setLayout(tl)
        lay.addWidget(trace)
        bar.setLayout(lay)
        return bar

    def _plan_column(self) -> QWidget:
        """Status bar on top, then the plan."""
        self.plan_column = QWidget()
        col = vbox(0, (0, 0, 0, 0))
        ticker = QFrame()
        ticker.setObjectName("ticker")
        tl = hbox(10, (14, 8, 10, 8))
        self.lamp = QFrame()
        self.lamp.setFixedSize(8, 8)
        self.ticker = label("", "tickerText", rich=True)
        self.skip_btn = QPushButton("Skip")
        self.skip_btn.setObjectName("skip")
        self.skip_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.skip_btn.clicked.connect(lambda: self.map.skip())
        self.skip_btn.hide()
        tl.addWidget(self.lamp, 0, Qt.AlignmentFlag.AlignVCenter)
        tl.addWidget(self.ticker, 1)
        tl.addWidget(self.skip_btn)
        ticker.setLayout(tl)
        wrap = vbox(0, (20, 14, 20, 0))
        wrap.addWidget(ticker)
        col.addLayout(wrap)
        self.results_panel = QScrollArea()
        self.results_panel.setObjectName("resultsPanel")
        self.results_panel.setWidget(self.results)
        self.results_panel.setWidgetResizable(True)
        self.results_panel.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        col.addWidget(self.results_panel, 1)
        self.plan_column.setLayout(col)
        self.set_ticker("Ready. Choose a trip and Prolog will plan it.", "idle")
        return self.plan_column

    def _map_column(self) -> QWidget:
        """The map, small beside the plan; Expand swaps it for the plan."""
        w = QFrame()
        w.setObjectName("mapColumn")
        col = vbox(10, (12, 14, 16, 16))
        frame = QFrame()
        frame.setObjectName("mapFrame")
        fl = vbox(0, (1, 1, 1, 1))
        self.map = MapView(self.data)
        fl.addWidget(self.map)
        frame.setLayout(fl)
        col.addWidget(frame, 1)
        self.expand_btn = QPushButton("Expand map  ⤢")
        self.expand_btn.setObjectName("expand")
        self.expand_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.expand_btn.clicked.connect(self.toggle_map)
        col.addWidget(self.expand_btn)
        w.setLayout(col)
        w.setFixedWidth(440)
        self.map_expanded = False
        return w

    def toggle_map(self) -> None:
        """Big map with the day cards, or back to the plan."""
        self.map_expanded = not self.map_expanded
        self.plan_column.setVisible(not self.map_expanded)
        if self.map_expanded:
            self.map_column.setMinimumWidth(0)
            self.map_column.setMaximumWidth(16777215)
            self.expand_btn.setText("Back to the plan  ⤡")
        else:
            self.map_column.setFixedWidth(440)
            self.expand_btn.setText("Expand map  ⤢")
        self.map.show_cards = self.map_expanded
        QTimer.singleShot(0, self.map.refit)  # after the layout has resized the map

    def _form(self) -> QWidget:
        w = QWidget()
        lay = vbox(20, (24, 22, 24, 24))
        w.setLayout(lay)

        homes = Segmented(HOMES, self.form["from"])
        homes.changed.connect(lambda v: self.update_form(**{"from": v}))
        lay.addWidget(field("Fly from", homes))

        options = [("anywhere", "Anywhere (Prolog picks)", "ให้ Prolog เลือก · let Prolog choose")] + [
            (c["id"], c["name"], c["thai"]) for c in self.data["countries"] if c["id"] != "thailand"]
        self.station = StationCard(options)
        self.station.picked.connect(lambda v: self.update_form(to=v))
        lay.addWidget(self.station)

        today = dt.date.today()
        leave = DatePicker(self.form["date"], today + dt.timedelta(days=1), today + dt.timedelta(days=360))
        leave.changed.connect(lambda d: self.update_form(date=d, month=d.month))
        lay.addWidget(field("Leave on", leave))
        row = hbox(12)
        days = Stepper(self.form["days"], 3, 21, "days")
        days.changed.connect(lambda v: self.update_form(days=v))
        row.addWidget(field("Days", days))
        people = Stepper(self.form["people"], 1, 6, "people")
        people.changed.connect(lambda v: self.update_form(people=v))
        row.addWidget(field("People", people))
        self.return_label = label(f"{self.back_date():%a %d %b %Y}", "hint", wrap=True)
        row.addWidget(field("Return", self.return_label), 1)
        lay.addLayout(row)

        self.budget_label = label(baht(self.form["budget"]), "budgetValue")
        budget = QSlider(Qt.Orientation.Horizontal)
        budget.setRange(5, 300)          # thousands of baht
        budget.setValue(self.form["budget"] // 1000)
        budget.valueChanged.connect(lambda v: self.update_form(budget=v * 1000))
        lay.addWidget(field("Budget for everyone", self.budget_label, budget, spacing=6))

        self.chips = []
        for key, text in INTERESTS:
            chip = Chip(text, key in self.form["interests"])
            chip.toggled.connect(lambda on, k=key: self.toggle_interest(k, on))
            self.chips.append(chip)
        self.interest_hint = label("Nothing picked, so every kind of place counts.", "hint")
        lay.addWidget(field("You like", chips_box(self.chips), self.interest_hint))

        pace = Segmented(PACES, self.form["pace"])
        pace.changed.connect(lambda v: self.update_form(pace=v))
        lay.addWidget(field("Pace", pace))

        pref = Segmented(PREFS, self.form["pref"], columns=2)
        pref.changed.connect(lambda v: self.update_form(pref=v))
        lay.addWidget(field("Prefer", pref))

        # ---- more detail: each choice becomes a Prolog option (see section 3a of trip.pl)
        stops = Segmented(STOPS, str(self.form["max_flights"]))
        stops.changed.connect(lambda v: self.update_form(max_flights=int(v)))
        night = Chip("Avoid night flights (22:00–06:00)", self.form["night_flights"] == "avoid")
        night.toggled.connect(lambda on: self.update_form(night_flights="avoid" if on else "allowed"))
        lay.addWidget(field("Flight changes", stops, chips_box([night])))

        airlines = Segmented(AIRLINES, self.form["airlines"])
        airlines.changed.connect(lambda v: self.update_form(airlines=v))
        lay.addWidget(field("Airlines", airlines))

        hotel = Segmented(HOTELS, self.form["hotel"])
        hotel.changed.connect(lambda v: self.update_form(hotel=v))
        lay.addWidget(field("Hotels", hotel))

        around = Segmented(AROUND, self.form["getting_around"])
        around.changed.connect(lambda v: self.update_form(getting_around=v))
        lay.addWidget(field("Getting around", around,
                            label("Fast = bullet trains, trains and flights. Night rides save a hotel night.",
                                  "hint", wrap=True)))

        self.city_box = QWidget()
        self.city_flow = QGridLayout()   # a fixed grid always takes the height it needs
        self.city_flow.setContentsMargins(0, 0, 0, 0)
        self.city_flow.setSpacing(6)
        self.city_box.setLayout(self.city_flow)
        self.city_hint = label("", "hint", wrap=True)
        lay.addWidget(field("Cities", self.city_box, self.city_hint))
        self._fill_cities()

        self.go = QPushButton("Find trips                                      →")
        self.go.setObjectName("go")
        self.go.setCursor(Qt.CursorShape.PointingHandCursor)
        self.go.clicked.connect(self.search)
        lay.addWidget(self.go)
        lay.addStretch()
        self._show_destination()
        self.interest_hint.setVisible(not self.form["interests"])
        return w

    # ------------------------------------------------------------ form state

    def update_form(self, **changes) -> None:
        if "to" in changes and self.phase in ("searching", "travelling"):
            return
        self.form.update(changes)
        if "to" in changes:
            self._show_destination()
            self.map.set_focus(self.form["to"])
            self.form["cities"] = []
            self._fill_cities()
        if "date" in changes or "days" in changes:
            self.return_label.setText(f"{self.back_date():%a %d %b %Y}")
        if "budget" in changes:
            self.budget_label.setText(baht(self.form["budget"]))
        self.refresh_query()

    def _fill_cities(self) -> None:
        """One chip per city in the chosen country. Picked cities = exactly where the trip goes."""
        while self.city_flow.count():
            item = self.city_flow.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        country = self.form["to"]
        if country not in self.countries:
            self.city_hint.setText("Pick a country to choose its cities.")
            return
        self.city_hint.setText("Pick the cities you want: the trip goes only there. "
                               "Pick none and Prolog chooses for you.")
        mine = [c for c in self.data["cities"] if c["country"] == country]
        for i, c in enumerate(mine):
            chip = Chip(c["name"], c["id"] in self.form["cities"])
            chip.toggled.connect(lambda on, k=c["id"]: self.update_form(
                cities=[m for m in self.form["cities"] if m != k] + ([k] if on else [])))
            self.city_flow.addWidget(chip, i // 2, i % 2)
        self.city_box.updateGeometry()

    def toggle_interest(self, key: str, on: bool) -> None:
        items = [k for k, _ in INTERESTS if (k in self.form["interests"] and k != key) or (k == key and on)]
        self.update_form(interests=items)
        self.interest_hint.setVisible(not items)

    def _show_destination(self) -> None:
        c = self.countries.get(self.form["to"])
        if c:
            self.station.show_value(c["name"], c["thai"])
        else:
            self.station.show_value("Anywhere", "ให้ Prolog เลือก · let Prolog choose")

    def back_date(self, f: dict | None = None) -> dt.date:
        f = f or self.form
        return f["date"] + dt.timedelta(days=f["days"] - 1)

    def options(self, f: dict) -> dict:
        return {k: f[k] for k in ("max_flights", "airlines", "night_flights", "hotel", "cities", "getting_around")}

    def refresh_query(self) -> None:
        f = self.form
        opts = ",".join(self.planner.option_terms(self.options(f), f["to"]))
        self.results.set_query(f'?- plan_trip({f["from"]}, {f["to"]}, {f["days"]}, {f["month"]}, {f["people"]}, '
                               f'{f["budget"]}, [{",".join(f["interests"])}], {f["pace"]}, {f["pref"]}, [{opts}], Plan).')

    def set_ticker(self, html: str, state: str) -> None:
        self.ticker.setText(html)
        lamp = {"searching": "marigold", "travelling": "marigold", "done": "ok", "off": "danger"}.get(state, "ink3")
        self.lamp.setStyleSheet(f"background:{C[lamp]}; border-radius:4px;")

    # ------------------------------------------------------------ search and journey

    def search(self) -> None:
        if self.phase == "searching":
            return
        self.map.clear()
        self.phase = "searching"
        self.searched = dict(self.form)
        self.offers = {}
        self.selected = 0
        self.go.setEnabled(False)
        self.go.setText("Searching…")
        self.skip_btn.hide()
        self.set_ticker(span("Querying", "marigold", weight=600) + " · consulting trip.pl", "searching")
        self.results.show_message("Searching", "Prolog is trying every flight and connection and backtracking out "
                                  "of dead ends. Watch the map.")
        # Real fares are fetched in the background (the window stays responsive),
        # then handed to Prolog as facts before it plans.
        f = self.form
        self.fare_status = "off"
        if live_prices.token() or live_prices.CACHE.exists():
            where = "asking Aviasales" if live_prices.token() else "reading saved fares"
            back = self.back_date(f)
            self.set_ticker(span("Fetching fares", "marigold", weight=600)
                            + f' · {where} for {f["date"]:%d %b} and {back:%d %b}', "searching")
            outbound, inbound = self.planner.fare_routes(f["from"], f["to"])
            job: Future = self.pool.submit(live_prices.fares_for, outbound, inbound, f["date"], back)

            def wait() -> None:
                if not job.done():
                    QTimer.singleShot(80, wait)
                    return
                try:
                    got = job.result()
                    self.fare_status = got["status"] if got["fares"] else "none"
                    self.offers = got.get("offers", {})
                    self.planner.set_live_fares(got["fares"], self.offers)
                except Exception:
                    self.fare_status = "error"
                    self.planner.set_live_fares({})
                self._run_prolog()

            QTimer.singleShot(80, wait)
        else:
            self.planner.set_live_fares({})
            self._run_prolog()

    def _run_prolog(self) -> None:
        self.set_ticker(span("Querying", "marigold", weight=600) + " · consulting trip.pl", "searching")
        QApplication.processEvents()
        f = self.searched
        try:
            self.result = self.planner.plan(f["from"], f["to"], f["days"], f["month"], f["people"], f["budget"],
                                            f["interests"], f["pace"], f["pref"], self.options(f))
        except PlannerError as e:
            self.phase = "idle"
            self._ready()
            self.set_ticker("Prolog could not answer that", "off")
            self.results.show_notice(str(e), error=True)
            return
        stats = self.result["stats"]
        total = max(1, len(stats["explored"]))

        def progress(i: int) -> None:
            steps = round(stats["steps"] * i / total)
            self.set_ticker(span("Backtracking", "marigold", weight=600)
                            + f" · {steps:,} steps · {plural(i, 'flight route')} tried", "searching")

        self.map.replay(stats["explored"], progress, self._after_search)

    def _after_search(self) -> None:
        if self.result["options"]:
            self.travel(0)
        else:
            self.phase = "done"
            self._ready()
            self._summary()
            self.results.show_notice(self.result["empty_reason"] or "No trip found. Try more days or a bigger budget.")

    def pick_plan(self, index: int) -> None:
        """A plan tab was clicked: ride that plan (not while a search is running)."""
        if self.phase != "searching":
            self.travel(index)

    def travel(self, index: int) -> None:
        self.selected = index
        self.phase = "travelling"
        self._ready()  # a new search may start at any time; it stops this ride
        self.skip_btn.show()
        opt = self.result["options"][index]
        self.results.show_plan(self.result, index, False, self.searched, self.pick_plan, self.offers)

        def stage(text: str) -> None:
            verb, _, rest = text.partition(" · ")
            self.set_ticker(span(verb, "marigold", weight=600) + (f" · {rest}" if rest else ""), "travelling")

        self.map.travel(opt, self.searched["from"], stage, self._arrived)

    def _arrived(self) -> None:
        self.phase = "done"
        self.skip_btn.hide()
        self._ready()
        self._summary()
        self.results.show_plan(self.result, self.selected, True, self.searched, self.pick_plan, self.offers)

    def _summary(self) -> None:
        s = self.result["stats"]
        self.set_ticker(span(plural(s["plans"], "plan"), "marigold", weight=600)
                        + f' built · {s["affordable"]} within budget · {plural(s["flightOptions"], "flight option")}'
                        f' · {s["steps"]:,} steps · {FARES.get(self.fare_status, "sample fares")}', "done")

    def _ready(self) -> None:
        self.go.setEnabled(True)
        self.go.setText("Find trips                                      →")


def main() -> None:
    app = QApplication(sys.argv)
    app.setApplicationName("Tang")
    theme.setup(app)
    window = TangWindow()
    window.show()
    window.map.show_asia()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
