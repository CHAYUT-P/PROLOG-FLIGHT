from __future__ import annotations
from typing import Callable
import datetime as dt
from PySide6.QtCore import QDate, QPoint, QRect, QSize, Qt, Signal
from PySide6.QtGui import QTextCharFormat
from PySide6.QtWidgets import (
    QButtonGroup, QCalendarWidget, QFrame, QGridLayout, QHBoxLayout, QLabel, QLayout, QMenu, QPushButton,
    QSizePolicy, QVBoxLayout, QWidget,
)


def label(text: str = "", name: str | None = None, wrap: bool = False, rich: bool = False) -> QLabel:
    lab = QLabel(text)
    if name:
        lab.setObjectName(name)
    lab.setWordWrap(wrap)
    lab.setTextFormat(Qt.TextFormat.RichText if rich else Qt.TextFormat.PlainText)
    return lab


def eyebrow(text: str) -> QLabel:
    return label(text.upper(), "eyebrow")


def vbox(spacing: int = 0, margins: tuple[int, int, int, int] = (0, 0, 0, 0)) -> QVBoxLayout:
    lay = QVBoxLayout()
    lay.setSpacing(spacing)
    lay.setContentsMargins(*margins)
    return lay


def hbox(spacing: int = 0, margins: tuple[int, int, int, int] = (0, 0, 0, 0)) -> QHBoxLayout:
    lay = QHBoxLayout()
    lay.setSpacing(spacing)
    lay.setContentsMargins(*margins)
    return lay


def clear_layout(layout: QLayout) -> None:
    while layout.count():
        item = layout.takeAt(0)
        if item.widget():
            item.widget().deleteLater()
        elif item.layout():
            clear_layout(item.layout())


class FlowLayout(QLayout):
    def __init__(self, spacing: int = 6):
        super().__init__()
        self._items = []
        self._spacing = spacing
        self.setContentsMargins(0, 0, 0, 0)

    def addItem(self, item):
        self._items.append(item)

    def count(self):
        return len(self._items)

    def itemAt(self, i):
        return self._items[i] if 0 <= i < len(self._items) else None

    def takeAt(self, i):
        return self._items.pop(i) if 0 <= i < len(self._items) else None

    def hasHeightForWidth(self):
        return True

    def heightForWidth(self, width):
        return self._place(QRect(0, 0, width, 0), move=False)

    def setGeometry(self, rect):
        super().setGeometry(rect)
        self._place(rect, move=True)

    def sizeHint(self):
        return self.minimumSize()

    def minimumSize(self):
        size = QSize()
        for item in self._items:
            size = size.expandedTo(item.minimumSize())
        return size

    def _place(self, rect: QRect, move: bool) -> int:
        x, y, line = rect.x(), rect.y(), 0
        for item in self._items:
            w, h = item.sizeHint().width(), item.sizeHint().height()
            if x + w > rect.right() + 1 and line > 0:
                x, y, line = rect.x(), y + line + self._spacing, 0
            if move:
                item.setGeometry(QRect(QPoint(x, y), item.sizeHint()))
            x += w + self._spacing
            line = max(line, h)
        return y + line - rect.y()


class Segmented(QFrame):
    changed = Signal(str)
    def __init__(self, options: list[tuple[str, str]], value: str, columns: int | None = None):
        super().__init__()
        self.setObjectName("segmented")
        grid = QGridLayout(self)
        grid.setSpacing(1)
        grid.setContentsMargins(0, 0, 0, 0)
        self.group = QButtonGroup(self)
        self.buttons: dict[str, QPushButton] = {}
        cols = columns or len(options)
        for i, (key, text) in enumerate(options):
            b = QPushButton(text)
            b.setCheckable(True)
            b.setChecked(key == value)
            b.setCursor(Qt.CursorShape.PointingHandCursor)
            b.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
            b.clicked.connect(lambda _=False, k=key: self.changed.emit(k))
            self.group.addButton(b)
            self.buttons[key] = b
            grid.addWidget(b, i // cols, i % cols)


class Chip(QPushButton):
    def __init__(self, text: str, on: bool):
        super().__init__(text)
        self.setObjectName("chip")
        self.setCheckable(True)
        self.setChecked(on)
        self.setCursor(Qt.CursorShape.PointingHandCursor)


class Stepper(QFrame):
    changed = Signal(int)
    def __init__(self, value: int, lo: int, hi: int, what: str):
        super().__init__()
        self.setObjectName("stepper")
        self.value, self.lo, self.hi = value, lo, hi
        lay = hbox(0, (2, 0, 2, 0))
        self.minus = QPushButton("−")
        self.plus = QPushButton("+")
        self.minus.setToolTip(f"Fewer {what}")
        self.plus.setToolTip(f"More {what}")
        self.shown = label(str(value), "stepperValue")
        self.shown.setAlignment(Qt.AlignmentFlag.AlignCenter)
        for w in (self.minus, self.shown, self.plus):
            lay.addWidget(w)
        self.setLayout(lay)
        self.minus.clicked.connect(lambda: self.set(self.value - 1))
        self.plus.clicked.connect(lambda: self.set(self.value + 1))
        self._refresh()

    def set(self, v: int) -> None:
        self.value = max(self.lo, min(self.hi, v))
        self._refresh()
        self.changed.emit(self.value)

    def _refresh(self) -> None:
        self.shown.setText(str(self.value))
        self.minus.setEnabled(self.value > self.lo)
        self.plus.setEnabled(self.value < self.hi)


class StationCard(QFrame):
    picked = Signal(str)
    def __init__(self, options: list[tuple[str, str, str]], title: str = "Fly to"):
        super().__init__()
        self.setObjectName("station")
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Maximum)
        self.options = options
        lay = vbox(2, (14, 12, 14, 12))
        top = hbox()
        top.addWidget(eyebrow(title))
        top.addStretch()
        top.addWidget(label("▾", "caret"))
        lay.addLayout(top)
        self.name = label("", "stationName", wrap=True)
        self.thai = label("", "stationThai", wrap=True)
        lay.addWidget(self.name)
        lay.addWidget(self.thai)
        self.setLayout(lay)

    def show_value(self, name: str, thai: str) -> None:
        self.name.setText(name)
        self.thai.setText(thai)

    def mousePressEvent(self, event):
        menu = QMenu(self)
        for i, (key, name, _) in enumerate(self.options):
            act = menu.addAction(name)
            act.triggered.connect(lambda _=False, k=key: self.picked.emit(k))
            if i == 0:
                menu.addSeparator()
        menu.exec(self.mapToGlobal(QPoint(0, self.height() + 4)))


def qdate(d: dt.date) -> QDate:
    return QDate(d.year, d.month, d.day)


class DatePicker(QPushButton):
    changed = Signal(object)
    def __init__(self, value: dt.date, first: dt.date, last: dt.date):
        super().__init__()
        self.setObjectName("datePick")
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.value, self.first, self.last = value, first, last
        self.clicked.connect(self.open_calendar)
        self._show()

    def _show(self) -> None:
        self.setText(f"{self.value:%a %d %b %Y}    ▾")

    def open_calendar(self) -> None:
        popup = QFrame(self, Qt.WindowType.Popup)
        popup.setObjectName("calendarPopup")
        lay = QVBoxLayout(popup)
        lay.setContentsMargins(8, 8, 8, 8)
        cal = QCalendarWidget()
        cal.setGridVisible(False)
        cal.setFirstDayOfWeek(Qt.DayOfWeek.Monday)
        cal.setVerticalHeaderFormat(QCalendarWidget.VerticalHeaderFormat.NoVerticalHeader)
        cal.setHorizontalHeaderFormat(QCalendarWidget.HorizontalHeaderFormat.ShortDayNames)
        cal.setMinimumDate(qdate(self.first))
        cal.setMaximumDate(qdate(self.last))
        cal.setSelectedDate(qdate(self.value))
        weekend = QTextCharFormat()
        weekend.setForeground(self.palette().text())
        for day in (Qt.DayOfWeek.Saturday, Qt.DayOfWeek.Sunday):
            cal.setWeekdayTextFormat(day, weekend)
        cal.setMinimumSize(300, 240)

        def pick(q: QDate) -> None:
            self.value = dt.date(q.year(), q.month(), q.day())
            self._show()
            popup.close()
            self.changed.emit(self.value)

        cal.clicked.connect(pick)
        lay.addWidget(cal)
        popup.move(self.mapToGlobal(QPoint(0, self.height() + 4)))
        popup.show()


class Clickable(QFrame):
    clicked = Signal()
    def __init__(self, name: str):
        super().__init__()
        self.setObjectName(name)
        self.setCursor(Qt.CursorShape.PointingHandCursor)

    def mousePressEvent(self, event):
        self.clicked.emit()


def field(title: str, *widgets: QWidget, spacing: int = 8) -> QWidget:
    w = QWidget()
    lay = vbox(spacing)
    lay.addWidget(eyebrow(title))
    for x in widgets:
        lay.addWidget(x)
    w.setLayout(lay)
    return w


def chips_box(chips: list[QPushButton]) -> QWidget:
    w = QWidget()
    flow = FlowLayout(6)
    for c in chips:
        flow.addWidget(c)
    w.setLayout(flow)
    return w


Callback = Callable[..., None]
