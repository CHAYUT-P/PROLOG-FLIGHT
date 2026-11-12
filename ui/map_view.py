"""The Asia map and the journey animation (Qt Graphics View).

Everything here is presentation: Prolog has already chosen the trip. The map
is drawn from our own country outlines (no internet needed). It replays the
order in which Prolog explored the flights, then flies a plane along the
chosen route while the camera follows, zooming into the country for the
train/bus part and back out for the flight home.

Scene coordinates are the map units from backend/geo.py.
"""

from __future__ import annotations

import math
from typing import Callable

from PySide6.QtCore import QElapsedTimer, QPointF, QRectF, Qt, QTimer, Signal
from PySide6.QtGui import QBrush, QFont, QFontMetricsF, QPainter, QPainterPath, QPen, QPolygonF, QTransform
from PySide6.QtWidgets import QGraphicsItem, QGraphicsPathItem, QGraphicsScene, QGraphicsView

import booking
from theme import C, MONO, SANS, color, font

Pt = tuple[float, float]


# ---------------------------------------------------------------- geometry

def arc(a: dict, b: dict, k: float = 0.16, samples: int = 36) -> list[Pt]:
    """Flights bow out as arcs. The bend is fixed by city order, so A→B and
    B→A sit on the same curve as the background network."""
    p, q = (a, b) if a["id"] < b["id"] else (b, a)
    cx = (p["x"] + q["x"]) / 2 - (q["y"] - p["y"]) * k
    cy = (p["y"] + q["y"]) / 2 + (q["x"] - p["x"]) * k
    return [((1 - t) ** 2 * a["x"] + 2 * (1 - t) * t * cx + t * t * b["x"],
             (1 - t) ** 2 * a["y"] + 2 * (1 - t) * t * cy + t * t * b["y"])
            for t in (i / samples for i in range(samples + 1))]


def straight(a: dict, b: dict) -> list[Pt]:
    return [(a["x"], a["y"]), (b["x"], b["y"])]


def partial(pts: list[Pt], f: float) -> list[Pt]:
    if f >= 1:
        return pts
    seg = [math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1)]
    goal = sum(seg) * max(0.0, f)
    out = [pts[0]]
    for i, s in enumerate(seg):
        if goal <= s:
            t = goal / s if s else 0
            out.append((pts[i][0] + (pts[i + 1][0] - pts[i][0]) * t, pts[i][1] + (pts[i + 1][1] - pts[i][1]) * t))
            return out
        goal -= s
        out.append(pts[i + 1])
    return out


def path_of(pts: list[Pt]) -> QPainterPath:
    path = QPainterPath(QPointF(*pts[0]))
    for p in pts[1:]:
        path.lineTo(QPointF(*p))
    return path


def pen(name: str, width: float, alpha: float = 1.0, style=Qt.PenStyle.SolidLine) -> QPen:
    p = QPen(color(name, alpha), width)
    p.setCosmetic(True)  # width in screen pixels, whatever the zoom
    p.setStyle(style)
    p.setCapStyle(Qt.PenCapStyle.RoundCap)
    p.setJoinStyle(Qt.PenJoinStyle.RoundJoin)
    return p


# Each transport type: (theme colour, line style). Overnight rides are dashed.
MODE_STYLE = {
    "high_speed": ("train", Qt.PenStyle.SolidLine), "train": ("train", Qt.PenStyle.SolidLine),
    "night_train": ("train", Qt.PenStyle.DashLine), "bus": ("bus", Qt.PenStyle.SolidLine),
    "night_bus": ("bus", Qt.PenStyle.DashLine), "ferry": ("ferry", Qt.PenStyle.SolidLine),
    "night_ferry": ("ferry", Qt.PenStyle.DashLine), "plane": ("air", Qt.PenStyle.DotLine),
}
MODE_NAME = {"high_speed": "Bullet train", "train": "Train", "bus": "Bus", "ferry": "Ferry", "plane": "Flight",
             "night_bus": "Night bus", "night_train": "Night train", "night_ferry": "Night ferry"}


def ease(t: float) -> float:
    return 2 * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 2 / 2


def box_around(points: list[Pt], pad: float, min_size: float) -> QRectF:
    """A camera box around the points, with extra room on the right for city names."""
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    r = QRectF(min(xs) - pad, min(ys) - pad, max(xs) - min(xs) + 2.6 * pad, max(ys) - min(ys) + 2 * pad)
    if r.width() < min_size or r.height() < min_size:
        c = r.center()
        w, h = max(r.width(), min_size), max(r.height(), min_size)
        r = QRectF(c.x() - w / 2, c.y() - h / 2, w, h)
    return r


def lerp_rect(a: QRectF, b: QRectF, t: float) -> QRectF:
    return QRectF(a.x() + (b.x() - a.x()) * t, a.y() + (b.y() - a.y()) * t,
                  a.width() + (b.width() - a.width()) * t, a.height() + (b.height() - a.height()) * t)


# ---------------------------------------------------------------- items

class TextItem(QGraphicsItem):
    """Text that stays the same size on screen, with a soft halo."""

    def __init__(self, text: str, qfont: QFont, ink: str, halo: str | None = None, center: bool = True):
        super().__init__()
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIgnoresTransformations)
        self.text, self.qfont, self.ink, self.halo = text, qfont, ink, halo
        fm = QFontMetricsF(qfont)
        w, h = fm.horizontalAdvance(text), fm.height()
        self.rect = QRectF(-w / 2 if center else 0, -h / 2, w, h).adjusted(-3, -3, 3, 3)
        self.base = QPointF(-w / 2 if center else 0, fm.ascent() - h / 2)

    def boundingRect(self):  # noqa: N802
        return self.rect

    def paint(self, p: QPainter, *_):
        path = QPainterPath()
        path.addText(self.base, self.qfont, self.text)
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        if self.halo:
            p.strokePath(path, QPen(color(self.halo), 3.5))
        p.fillPath(path, color(self.ink))


class CityItem(QGraphicsItem):
    """A city dot with an optional label; same pixel size at every zoom."""

    def __init__(self, city: dict, on_click: Callable[[dict], None]):
        super().__init__()
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIgnoresTransformations)
        self.setPos(city["x"], city["y"])
        self.setZValue(7)
        self.setToolTip(f'{city["name"]} · {city["code"]}')
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.city, self.on_click = city, on_click
        self.state = "normal"   # normal | on | home
        self.show_label = False
        self.code_font = font(11.5, QFont.Weight.DemiBold, MONO)
        self.name_font = font(12, QFont.Weight.Bold, SANS)

    def set(self, state: str | None = None, show_label: bool | None = None) -> None:
        if state is not None:
            self.state = state
        if show_label is not None:
            self.show_label = show_label
        self.prepareGeometryChange()
        self.update()

    def boundingRect(self):  # noqa: N802
        return QRectF(-7, -9, 150 if self.show_label else 14, 18)

    def paint(self, p: QPainter, *_):
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        lit = self.state in ("on", "home")
        r = 4.5 if lit else 3.5
        p.setPen(QPen(color("land" if lit else ("ink3" if self.city["zone"] is None else "ink2")), 1.5))
        p.setBrush(color("ink" if lit else "land"))
        p.drawEllipse(QPointF(0, 0), r, r)
        if self.show_label:
            path = QPainterPath()
            path.addText(QPointF(9, 4.5), self.code_font, self.city["code"])
            w = QFontMetricsF(self.code_font).horizontalAdvance(self.city["code"])
            path.addText(QPointF(9 + w + 5, 4.5), self.name_font, self.city["name"])
            p.strokePath(path, QPen(color("land"), 3.5))
            p.fillPath(path, color("ink"))

    def mousePressEvent(self, event):  # noqa: N802
        self.on_click(self.city)


class CountryItem(QGraphicsPathItem):
    def __init__(self, path: QPainterPath, kind: str, trip: str | None, on_click: Callable[[str], None]):
        super().__init__(path)
        self.kind, self.trip, self.on_click = kind, trip, on_click
        self.focused = False
        self.hover = False
        self.setZValue(1)
        if trip and trip != "thailand":
            self.setAcceptHoverEvents(True)
            self.setCursor(Qt.CursorShape.PointingHandCursor)
            self.setToolTip("Click to fly here")
        self.restyle()

    def restyle(self) -> None:
        fill = {"neighbour": "neighbour", "trip": "land", "home": "land_home"}[self.kind]
        if self.focused or self.hover:
            fill = "land_focus"
        self.setBrush(QBrush(color(fill)))
        self.setPen(pen("ink3" if self.focused else "land_edge", 1.0 if self.focused else 0.6))
        self.setZValue(2 if self.focused else 1)

    def hoverEnterEvent(self, e):  # noqa: N802
        self.hover = True
        self.restyle()

    def hoverLeaveEvent(self, e):  # noqa: N802
        self.hover = False
        self.restyle()

    def mousePressEvent(self, e):  # noqa: N802
        if self.trip and self.trip != "thailand":
            self.on_click(self.trip)


class RiderItem(QGraphicsItem):
    """The plane (or, on the ground, a dot) that travels the route."""

    def __init__(self):
        super().__init__()
        self.setFlag(QGraphicsItem.GraphicsItemFlag.ItemIgnoresTransformations)
        self.setZValue(9)
        self.flying, self.angle = True, 0.0

    def boundingRect(self):  # noqa: N802
        return QRectF(-14, -14, 28, 28)

    def paint(self, p: QPainter, *_):
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        p.setPen(QPen(color("ink"), 1.4))
        p.setBrush(color("marigold"))
        if self.flying:
            p.rotate(self.angle)
            p.drawPolygon(QPolygonF([QPointF(10, 0), QPointF(-6, 6), QPointF(-3, 0), QPointF(-6, -6)]))
        else:
            p.drawEllipse(QPointF(0, 0), 5, 5)


# ---------------------------------------------------------------- the view

class MapView(QGraphicsView):
    country_picked = Signal(str)

    def __init__(self, data: dict):
        super().__init__()
        self.data = data
        self.cities = {c["id"]: c for c in data["cities"]}
        outline = data["outline"]
        self.W, self.H = outline["width"], outline["height"]
        self.scene_ = QGraphicsScene(self)
        self.scene_.setSceneRect(-400, -400, self.W + 800, self.H + 800)
        self.setScene(self.scene_)
        self.setRenderHints(QPainter.RenderHint.Antialiasing | QPainter.RenderHint.TextAntialiasing)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.setDragMode(QGraphicsView.DragMode.ScrollHandDrag)
        self.setTransformationAnchor(QGraphicsView.ViewportAnchor.AnchorUnderMouse)
        self.setViewportUpdateMode(QGraphicsView.ViewportUpdateMode.FullViewportUpdate)
        self.setBackgroundBrush(color("sea"))
        self.setFrameShape(QGraphicsView.Shape.NoFrame)

        self.asia = QRectF(6, 4, self.W - 12, self.H - 8)
        self.cam = QRectF(self.asia)
        self.focus: str | None = None
        self.route_country: str | None = None
        self.trace_items: list = []
        self.journey_items: list = []
        self.detail: dict | None = None   # cards shown on the country close-up
        self.show_cards = False           # only when the map is expanded
        self.timer = QTimer(self)
        self.timer.setInterval(16)
        self.timer.timeout.connect(self._tick)
        self.clock = QElapsedTimer()
        self.anim: dict | None = None
        self._build()

    # ------------------------------------------------------------ drawing the map

    def _build(self) -> None:
        s = self.scene_
        outline = self.data["outline"]
        for g in outline["grid"]:
            line = (QPainterPath(QPointF(-400, g["pos"])) if g["axis"] == "lat" else QPainterPath(QPointF(g["pos"], -400)))
            line.lineTo(QPointF(self.W + 400, g["pos"]) if g["axis"] == "lat" else QPointF(g["pos"], self.H + 400))
            item = s.addPath(line, pen("sea_ink", 1, 0.35, Qt.PenStyle.DashLine))
            item.setZValue(0)

        self.countries: list[CountryItem] = []
        for c in outline["countries"]:
            path = QPainterPath()
            for ring in c["rings"]:
                path.addPolygon(QPolygonF([QPointF(x, y) for x, y in ring]))
                path.closeSubpath()
            kind = "neighbour" if c["trip"] is None else ("home" if c["trip"] == "thailand" else "trip")
            item = CountryItem(path, kind, c["trip"], self.country_picked.emit)
            s.addItem(item)
            self.countries.append(item)

        # the whole network, faint: every flight route once, plus travel inside countries
        self.network: list = []
        seen = set()
        for f in self.data["flights"]:
            key = tuple(sorted((f["from"], f["to"])))
            if key not in seen:
                seen.add(key)
                self._net(arc(self.cities[f["from"]], self.cities[f["to"]]), pen("air", 1, 0.18))
        for g in self.data["ground"]:
            a, b = self.cities[g["from"]], self.cities[g["to"]]
            col, style = MODE_STYLE[g["mode"]]
            self._net(arc(a, b, 0.12) if g["mode"] == "plane" else straight(a, b), pen(col, 1, 0.35, style))

        label_font = font(10.5, QFont.Weight.DemiBold, MONO)
        label_font.setLetterSpacing(QFont.SpacingType.AbsoluteSpacing, 2.5)
        sea_font = font(9.5, QFont.Weight.Normal, MONO)
        sea_font.setItalic(True)
        sea_font.setLetterSpacing(QFont.SpacingType.AbsoluteSpacing, 3)
        for sea in outline["seas"]:
            t = TextItem(sea["text"], sea_font, "sea_ink")
            t.setPos(sea["x"], sea["y"])
            t.setZValue(6)
            s.addItem(t)
        self.country_labels = {}
        for c in self.data["countries"]:
            if c["id"] == "thailand":
                continue
            cs = [x for x in self.data["cities"] if x["country"] == c["id"]]
            t = TextItem(c["name"].upper(), label_font, "ink3", halo=None)
            t.setPos(sum(p["x"] for p in cs) / len(cs), sum(p["y"] for p in cs) / len(cs) - 2.8)
            t.setZValue(6)
            s.addItem(t)
            self.country_labels[c["id"]] = t

        self.city_items = {c["id"]: CityItem(c, self._city_clicked) for c in self.data["cities"]}
        for item in self.city_items.values():
            s.addItem(item)

        self.rider = RiderItem()
        self.rider.setVisible(False)
        s.addItem(self.rider)

    def _net(self, pts: list[Pt], p: QPen) -> None:
        item = self.scene_.addPath(path_of(pts), p)
        item.setZValue(3)
        self.network.append(item)

    def _city_clicked(self, city: dict) -> None:
        if city["country"] != "thailand":
            self.country_picked.emit(city["country"])

    # ------------------------------------------------------------ camera

    def _apply(self, rect: QRectF) -> None:
        vw, vh = max(1, self.viewport().width()), max(1, self.viewport().height())
        s = min(vw / rect.width(), vh / rect.height())
        self.setTransform(QTransform.fromScale(s, s))
        self.centerOn(rect.center())
        # zoomed in far enough: name every city of the country we are looking at
        zoomed = s > 14
        for cid, item in self.city_items.items():
            want = item.state != "normal" or (zoomed and item.city["country"] in (self.focus, self.route_country))
            if want != item.show_label:
                item.set(show_label=want)
        for cid, t in self.country_labels.items():
            t.setVisible(not zoomed)

    def set_camera(self, rect: QRectF) -> None:
        self.cam = QRectF(rect)
        self._apply(self.cam)

    def resizeEvent(self, e):  # noqa: N802
        super().resizeEvent(e)
        self._apply(self.cam)

    def wheelEvent(self, e):  # noqa: N802
        if self.anim:
            return
        factor = 1.0015 ** e.angleDelta().y()
        self.scale(factor, factor)
        self.cam = self.mapToScene(self.viewport().rect()).boundingRect()
        self._apply(self.cam)

    def mouseReleaseEvent(self, e):  # noqa: N802
        super().mouseReleaseEvent(e)
        if not self.anim:
            self.cam = self.mapToScene(self.viewport().rect()).boundingRect()

    def show_asia(self) -> None:
        self.set_camera(self.asia)

    # ------------------------------------------------------------ destination highlight

    def set_focus(self, country: str) -> None:
        self.focus = country
        for item in self.countries:
            item.focused = item.trip == country
            item.restyle()
        self._apply(self.cam)

    # ------------------------------------------------------------ search replay

    def clear(self) -> None:
        self.timer.stop()
        self.anim = None
        for item in self.trace_items + self.journey_items:
            self.scene_.removeItem(item)
        self.trace_items, self.journey_items = [], []
        self.rider.setVisible(False)
        self.route_country = None
        self.detail = None
        for item in self.city_items.values():
            item.set(state="normal")
        for n in self.network:
            n.setOpacity(1)
        self._apply(self.cam)

    def replay(self, edges: list, on_progress: Callable[[int], None], on_done: Callable[[], None]) -> None:
        """Draw each flight Prolog looked at, in the order it looked."""
        self.anim = {"kind": "replay", "edges": edges, "shown": 0, "progress": on_progress, "done": on_done,
                     "every": min(35, max(6, 1100 / max(1, len(edges)))), "start_cam": QRectF(self.cam)}
        self.clock.start()
        self.timer.start()

    def _tick_replay(self, a: dict) -> None:
        # the camera eases back to the whole of Asia while the search runs
        t = min(1.0, self.clock.elapsed() / 700)
        self.set_camera(lerp_rect(a["start_cam"], self.asia, ease(t)))
        want = min(len(a["edges"]), int(self.clock.elapsed() / a["every"]) + 1)
        while a["shown"] < want:
            f, to = a["edges"][a["shown"]]
            item = self.scene_.addPath(path_of(arc(self.cities[f], self.cities[to])), pen("marigold", 3.5))
            item.setZValue(4)
            self.trace_items.append(item)
            if len(self.trace_items) > 3:
                self.trace_items[-4].setPen(pen("marigold", 1.6, 0.85))
            a["shown"] += 1
            a["progress"](a["shown"])
        if a["shown"] >= len(a["edges"]) and self.clock.elapsed() > len(a["edges"]) * a["every"] + 300:
            self.timer.stop()
            self.anim = None
            self._fade_trace(a["edges"])
            a["done"]()

    def _fade_trace(self, edges: list) -> None:
        for item in self.trace_items:
            self.scene_.removeItem(item)
        path = QPainterPath()
        for f, to in edges:
            path.addPath(path_of(arc(self.cities[f], self.cities[to])))
        item = self.scene_.addPath(path, pen("marigold", 1.4, 0.16))
        item.setZValue(4)
        self.trace_items = [item]

    # ------------------------------------------------------------ the journey

    def _segments(self, opt: dict) -> list[dict]:
        cs = self.cities
        segs: list[dict] = [{"kind": "cam", "to": "route", "ms": 700}]
        for l in opt["outbound"]:
            segs.append({"kind": "fly", "pts": arc(cs[l["from"]], cs[l["to"]]), "pen": pen("air", 3),
                         "ms": min(1300, 650 + l["minutes"] * 0.8), "to": l["to"],
                         "label": f'Flying {l["code"]} · {cs[l["from"]]["name"]} to {cs[l["to"]]["name"]}'})
        if opt["moves"]:
            segs.append({"kind": "cam", "to": "country", "ms": 750})
            for mv in opt["moves"]:
                a, b = cs[mv["from"]], cs[mv["to"]]
                plane = mv["mode"] == "plane"
                col, style = MODE_STYLE[mv["mode"]]
                segs.append({"kind": "move", "pts": arc(a, b, 0.12) if plane else straight(a, b),
                             "pen": pen(col, 4 if mv["mode"] == "high_speed" else 3, 1,
                                        Qt.PenStyle.DashLine if plane else style),
                             "ms": min(1000, 500 + mv["minutes"] * 1.4), "to": mv["to"],
                             "label": f'Exploring · {a["name"]} to {b["name"]} by {MODE_NAME[mv["mode"]].lower()}'})
            segs.append({"kind": "cam", "to": "route", "ms": 750})
        for l in opt["inbound"]:
            segs.append({"kind": "fly", "pts": arc(cs[l["from"]], cs[l["to"]]), "pen": pen("air", 3),
                         "ms": min(1300, 650 + l["minutes"] * 0.8), "to": l["to"],
                         "label": f'Flying home {l["code"]} · {cs[l["from"]]["name"]} to {cs[l["to"]]["name"]}'})
        return segs

    def _boxes(self, opt: dict) -> dict:
        legs = opt["outbound"] + opt["inbound"]
        route = [(self.cities[c]["x"], self.cities[c]["y"]) for l in legs for c in (l["from"], l["to"])]
        country = [(self.cities[c]["x"], self.cities[c]["y"]) for c in opt["cities"]]
        return {"route": box_around(route, 7, 24), "country": box_around(country, 3, 9)}

    def travel(self, opt: dict, home: str, on_stage: Callable[[str], None], on_done: Callable[[], None]) -> None:
        """Fly out, zoom into the country, ride between cities, zoom out, fly home."""
        self.timer.stop()
        for item in self.journey_items:
            self.scene_.removeItem(item)
        self.journey_items = []
        for item in self.city_items.values():
            item.set(state="normal")
        self.route_country = opt["country"]
        self.detail = None
        self.city_items[home].set(state="home")
        for n in self.network:
            n.setOpacity(0.35)
        segs, boxes = self._segments(opt), self._boxes(opt)
        cam = QRectF(self.cam)
        for s in segs:  # remember where the camera is when each segment starts
            s["cam_from"] = cam
            if s["kind"] == "cam":
                cam = boxes[s["to"]]
        self.anim = {"kind": "travel", "segs": segs, "boxes": boxes, "opt": opt, "home": home,
                     "stage": on_stage, "done": on_done, "current": -1, "completed": 0, "item": None}
        self.rider.setVisible(False)
        self.clock.start()
        self.timer.start()

    def _tick_travel(self, a: dict) -> None:
        dwell = 180
        t = self.clock.elapsed()
        i = 0
        segs = a["segs"]
        while i < len(segs) and t >= segs[i]["ms"] + dwell:
            t -= segs[i]["ms"] + dwell
            if i >= a["completed"]:
                self._complete(a, i)
            i += 1
        if i >= len(segs):
            return self.skip()
        seg = segs[i]
        f = ease(min(1.0, t / seg["ms"]))
        if i != a["current"]:
            a["current"] = i
            a["item"] = None
            if seg["kind"] != "cam":
                a["stage"](seg["label"])
                item = self.scene_.addPath(QPainterPath(), seg["pen"])
                item.setZValue(5)
                self.journey_items.append(item)
                a["item"] = item
        if seg["kind"] == "cam":
            self.set_camera(lerp_rect(seg["cam_from"], a["boxes"][seg["to"]], f))
            return
        pts = partial(seg["pts"], f)
        a["item"].setPath(path_of(pts))
        x0, y0 = pts[max(0, len(pts) - 2)]
        x1, y1 = pts[-1]
        self.rider.flying = seg["kind"] == "fly"
        if (x1, y1) != (x0, y0):
            self.rider.angle = math.degrees(math.atan2(y1 - y0, x1 - x0))
        self.rider.setPos(x1, y1)
        self.rider.setVisible(True)
        self.rider.update()

    def _complete(self, a: dict, i: int) -> None:
        """A segment has finished: draw it fully and light up the city we reached."""
        seg = a["segs"][i]
        if seg["kind"] == "cam":
            self.set_camera(a["boxes"][seg["to"]])
            a["completed"] = i + 1
            return
        if a["current"] == i and a["item"] is not None:
            item = a["item"]
        else:  # the segment finished between two frames before it was ever drawn
            item = self.scene_.addPath(QPainterPath(), seg["pen"])
            item.setZValue(5)
            self.journey_items.append(item)
            a["stage"](seg["label"])
        item.setPath(path_of(seg["pts"]))
        if self.city_items[seg["to"]].state == "normal":
            self.city_items[seg["to"]].set(state="on")
        a["completed"] = i + 1

    def skip(self) -> None:
        """Jump to the end of the journey: draw the whole route at once."""
        a = self.anim
        if not a or a["kind"] != "travel":
            return
        self.timer.stop()
        for item in self.journey_items:
            self.scene_.removeItem(item)
        self.journey_items = []
        for seg in a["segs"]:
            if seg["kind"] != "cam":
                item = self.scene_.addPath(path_of(seg["pts"]), seg["pen"])
                item.setZValue(5)
                self.journey_items.append(item)
        for c in a["opt"]["cities"]:
            self.city_items[c].set(state="on")
        self.rider.setVisible(False)
        # End on a close-up of the country, with a card for every stop.
        self.detail = self._detail(a["opt"])
        self.detail_opt = a["opt"]
        self.anim = {"kind": "glide", "from": QRectF(self.cam), "to": self._closeup(a["opt"]), "ms": 900}
        self.clock.start()
        self.timer.start()
        a["done"]()

    def _tick(self) -> None:
        a = self.anim
        if not a:
            self.timer.stop()
        elif a["kind"] == "glide":
            t = min(1.0, self.clock.elapsed() / a["ms"])
            self.set_camera(lerp_rect(a["from"], a["to"], ease(t)))
            if t >= 1:
                self.timer.stop()
                self.anim = None
        elif a["kind"] == "replay":
            self._tick_replay(a)
        else:
            self._tick_travel(a)

    # ------------------------------------------------------------ country close-up

    def refit(self) -> None:
        """Re-frame the country close-up (after the map is expanded or shrunk)."""
        if self.detail and not self.anim:
            self.set_camera(self._closeup(self.detail_opt))
        self.viewport().update()

    def _closeup(self, opt: dict) -> QRectF:
        """The tour's cities, with room on the right for the day cards."""
        pts = [(self.cities[c]["x"], self.cities[c]["y"]) for c in opt["cities"]]
        r = box_around(pts, 2.5, 7)
        if not self.show_cards:  # small map: a little margin all round for the ride labels
            return QRectF(r.x() - r.width() * 0.3, r.y() - r.height() * 0.15, r.width() * 1.6, r.height() * 1.3)
        return QRectF(r.x() - r.width() * 0.15, r.y() - r.height() * 0.1, r.width() * 2.1, r.height() * 1.2)

    def _detail(self, opt: dict) -> dict:
        """What the close-up shows: one card per stay, and a label on each ride."""
        stays = booking.stays(opt)
        for st in stays:
            st["price"] = opt.get("roomPrice", {}).get(st["city"])
        rides = []
        for mv in opt["moves"]:
            a, b = self.cities[mv["from"]], self.cities[mv["to"]]
            h, m = divmod(mv["minutes"], 60)
            rides.append({"mid": ((a["x"] + b["x"]) / 2, (a["y"] + b["y"]) / 2),
                          "a": (a["x"], a["y"]), "b": (b["x"], b["y"]),
                          "text": f'{MODE_NAME[mv["mode"]]} · {f"{h}h " if h else ""}{m:02d}m'.replace(" 00m", ""),
                          "mode": MODE_STYLE[mv["mode"]][0]})
        return {"stays": stays, "rides": rides}

    def drawForeground(self, p: QPainter, rect) -> None:  # noqa: N802
        """Day cards beside the cities, joined to them by thin lines (drawn in screen pixels)."""
        if not self.detail or self.anim:
            return
        if not self.show_cards:  # small map: lines only; labels and cards when expanded
            return
        self._ride_labels(p)
        p.save()
        p.resetTransform()
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        vw = self.viewport().width()
        self._cards(p, vw)
        p.restore()

    def _ride_labels(self, p: QPainter) -> None:
        p.save()
        p.resetTransform()
        p.setRenderHint(QPainter.RenderHint.Antialiasing)
        for ride in self.detail["rides"]:
            mid = self.mapFromScene(QPointF(*ride["mid"]))
            a = self.mapFromScene(QPointF(*ride["a"]))
            b = self.mapFromScene(QPointF(*ride["b"]))
            f = font(11, QFont.Weight.DemiBold, MONO)
            w = QFontMetricsF(f).horizontalAdvance(ride["text"]) + 14
            cx, cy = mid.x(), mid.y()
            if math.hypot(b.x() - a.x(), b.y() - a.y()) < 140:
                # cities close together: put the label beside the line, away from the names
                cx -= w / 2 + 18
                cy += 22
                p.setPen(QPen(color(ride["mode"]), 1, Qt.PenStyle.DotLine))
                p.drawLine(QPointF(cx + w / 2, cy - 10), mid)
            box = QRectF(cx - w / 2, cy - 10, w, 20)
            p.setPen(QPen(color(ride["mode"]), 1.2))
            p.setBrush(color("panel"))
            p.drawRoundedRect(box, 10, 10)
            p.setFont(f)
            p.setPen(color(ride["mode"]))
            p.drawText(box, Qt.AlignmentFlag.AlignCenter, ride["text"])
        p.restore()

    def _cards(self, p: QPainter, vw: int) -> None:
        card_w = 230
        items = []
        for st in self.detail["stays"]:
            c = self.cities[st["city"]]
            pt = self.mapFromScene(QPointF(c["x"], c["y"]))
            acts = st["acts"][:4] + ([f'+{len(st["acts"]) - 4} more'] if len(st["acts"]) > 4 else [])
            if not acts:
                acts = ["Free time"]
            h = 52 + 17 * len(acts) + 20
            items.append((pt.y(), pt, st, c, acts, h))
        items.sort(key=lambda x: x[0])
        x = vw - card_w - 16
        y_next = 14.0
        head_f = font(10.5, QFont.Weight.DemiBold, MONO)
        name_f = font(15, QFont.Weight.ExtraBold)
        act_f = font(12.5)
        foot_f = font(11, QFont.Weight.Normal, MONO)
        for _, pt, st, c, acts, h in items:
            y = max(y_next, pt.y() - h / 2)
            card = QRectF(x, y, card_w, h)
            y_next = y + h + 10
            # the leader line from the card to the city
            p.setPen(QPen(color("ink3"), 1, Qt.PenStyle.DashLine))
            p.drawLine(QPointF(x, y + 26), pt)
            p.setPen(QPen(color("rule"), 1))
            p.setBrush(color("panel"))
            p.drawRoundedRect(card, 8, 8)
            days = f'DAY {st["first"]}' if st["first"] == st["last"] else f'DAYS {st["first"]}–{st["last"]}'
            p.setFont(head_f)
            p.setPen(color("ink3"))
            p.drawText(QPointF(x + 12, y + 18), f'{days} · {c["code"]}')
            p.setFont(name_f)
            p.setPen(color("ink"))
            p.drawText(QPointF(x + 12, y + 38), c["name"])
            p.setFont(act_f)
            p.setPen(color("ink2"))
            fm = QFontMetricsF(act_f)
            for i, a in enumerate(acts):
                p.drawText(QPointF(x + 12, y + 58 + 17 * i), fm.elidedText(f"• {a}", Qt.TextElideMode.ElideRight, card_w - 24))
            nights = st["nights"]
            foot = f'{nights} night{"s" if nights != 1 else ""}'
            if st["on_board"]:
                foot += f' + {MODE_NAME[st["on_board"]].lower()}'
            elif st.get("price") and nights:
                foot += f' · about ฿{st["price"]:,}/night'
            p.setFont(foot_f)
            p.setPen(color("ink3"))
            p.drawText(QPointF(x + 12, y + h - 10),
                       QFontMetricsF(foot_f).elidedText(foot, Qt.TextElideMode.ElideRight, card_w - 24))

