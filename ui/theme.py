from __future__ import annotations

from pathlib import Path

from PySide6.QtGui import QColor, QFont, QFontDatabase, QGuiApplication
from PySide6.QtCore import Qt

FONT_DIR = Path(__file__).resolve().parent / "fonts"

LIGHT = dict(
    paper="#e3e9e4", panel="#f1f5f2", ink="#13232a", ink2="#4b5d61", ink3="#7d8d8e", rule="#c2ccc6",
    marigold="#e89a00", air="#8a3a86", train="#2b55b8", bus="#1f8456", ferry="#0b8ba3",
    danger="#b3261e", ok="#1f8456",
    sea="#d3dfdd", sea_ink="#8aa3a2", land="#f3f6f2", land_focus="#ffffff", land_home="#e9efe9",
    land_edge="#8fa39c", neighbour="#e2e8e3",
)
DARK = dict(
    paper="#0e171a", panel="#152126", ink="#e2eae5", ink2="#a2b3b2", ink3="#6f8183", rule="#2a3a3f",
    marigold="#f5b031", air="#d17cc6", train="#7393f2", bus="#4fbf88", ferry="#3cc3da",
    danger="#f2827b", ok="#4fbf88",
    sea="#0a1316", sea_ink="#3d5559", land="#18262b", land_focus="#22343a", land_home="#1c2b30",
    land_edge="#4b6168", neighbour="#111d21",
)

C: dict[str, str] = dict(LIGHT)

SANS = "Overpass"
MONO = "Overpass Mono Light"
THAI = "IBM Plex Sans Thai"


def color(name: str, alpha: float = 1.0) -> QColor:
    c = QColor(C[name])
    c.setAlphaF(alpha)
    return c


def font(size: float, weight: QFont.Weight = QFont.Weight.Normal, family: str = SANS) -> QFont:
    f = QFont(family)
    f.setPixelSize(round(size))
    f.setWeight(weight)
    return f


def setup(app) -> None:
    for f in sorted(FONT_DIR.glob("*.ttf")):
        QFontDatabase.addApplicationFont(str(f.resolve()))
    dark = QGuiApplication.styleHints().colorScheme() == Qt.ColorScheme.Dark
    C.clear()
    C.update(DARK if dark else LIGHT)
    app.setFont(font(14))
    app.setStyleSheet(stylesheet())


def stylesheet() -> str:
    c = C
    return f"""
    QWidget {{ color: {c['ink']}; font-family: "{SANS}"; font-size: 14px; }}
    QMainWindow, #root {{ background: {c['paper']}; }}
    QToolTip {{ background: {c['ink']}; color: {c['paper']}; border: 0; padding: 4px 6px; border-radius: 4px; }}

    #masthead {{ border-bottom: 1px solid {c['rule']}; }}
    #formPanel {{ border-right: 1px solid {c['rule']}; background: {c['paper']}; }}
    #resultsPanel {{ border: 0; background: {c['paper']}; }}
    QScrollArea {{ border: 0; background: transparent; }}
    QScrollArea > QWidget > QWidget {{ background: transparent; }}
    QScrollBar:vertical {{ background: transparent; width: 8px; margin: 2px; }}
    QScrollBar::handle:vertical {{ background: {c['rule']}; border-radius: 3px; min-height: 30px; }}
    QScrollBar::add-line, QScrollBar::sub-line {{ height: 0; }}

    #eyebrow {{ font-family: "{MONO}"; font-size: 11px; letter-spacing: 1px; color: {c['ink3']}; }}
    #hint {{ font-size: 12px; color: {c['ink3']}; }}

    /* segmented buttons */
    #segmented {{ background: {c['rule']}; border: 1px solid {c['rule']}; border-radius: 6px; }}
    #segmented QPushButton {{ background: {c['panel']}; border: 0; padding: 8px 4px; font-size: 13px; color: {c['ink2']}; }}
    #segmented QPushButton:hover {{ color: {c['ink']}; }}
    #segmented QPushButton:checked {{ background: {c['ink']}; color: {c['paper']}; font-weight: 600; }}

    /* destination card */
    #station {{ background: {c['panel']}; border: 1px solid {c['rule']}; border-radius: 6px; }}
    #station:hover {{ border-color: {c['ink3']}; }}
    #stationName {{ font-size: 30px; font-weight: 800; }}
    #stationThai {{ font-family: "{THAI}"; font-size: 13px; color: {c['ink2']}; }}
    #caret {{ color: {c['ink3']}; font-size: 13px; }}

    #datePick {{ background: {c['panel']}; border: 1px solid {c['rule']}; border-radius: 6px; padding: 0 12px;
                 min-height: 40px; text-align: left; font-family: "{MONO}"; font-size: 14px; font-weight: 600; }}
    #datePick:hover {{ border-color: {c['ink3']}; }}
    #calendarPopup {{ background: {c['panel']}; border: 1px solid {c['rule']}; border-radius: 8px; }}
    QCalendarWidget QWidget {{ background: {c['panel']}; color: {c['ink']}; alternate-background-color: {c['panel']}; }}
    QCalendarWidget QAbstractItemView {{ selection-background-color: {c['ink']}; selection-color: {c['paper']};
                                         font-size: 13px; outline: 0; }}
    QCalendarWidget QAbstractItemView:disabled {{ color: {c['rule']}; }}
    QCalendarWidget QToolButton {{ background: transparent; color: {c['ink']}; font-weight: 700; padding: 4px 8px;
                                   font-size: 14px; }}
    QCalendarWidget QToolButton:hover {{ background: {c['paper']}; border-radius: 4px; }}
    QCalendarWidget QToolButton::menu-indicator {{ image: none; width: 0; }}
    QCalendarWidget QSpinBox {{ background: {c['panel']}; border: 0; font-weight: 700; }}
    #qt_calendar_navigationbar {{ background: {c['panel']}; border-bottom: 1px solid {c['rule']}; }}
    QComboBox {{ background: {c['panel']}; border: 1px solid {c['rule']}; border-radius: 6px; padding: 0 10px;
                 min-height: 38px; font-family: "{MONO}"; font-size: 15px; font-weight: 600; }}
    QComboBox::drop-down {{ border: 0; width: 22px; }}
    QComboBox QAbstractItemView {{ background: {c['panel']}; border: 1px solid {c['rule']}; selection-background-color: {c['ink']};
                                   selection-color: {c['paper']}; outline: 0; }}
    QMenu {{ background: {c['panel']}; border: 1px solid {c['rule']}; padding: 4px; }}
    QMenu::item {{ padding: 7px 18px; border-radius: 4px; }}
    QMenu::item:selected {{ background: {c['ink']}; color: {c['paper']}; }}
    QMenu::separator {{ height: 1px; background: {c['rule']}; margin: 4px 6px; }}

    /* steppers */
    #stepper {{ background: {c['panel']}; border: 1px solid {c['rule']}; border-radius: 6px; }}
    #stepper QPushButton {{ background: transparent; border: 0; font-size: 17px; color: {c['ink2']}; min-width: 26px; min-height: 36px; }}
    #stepper QPushButton:hover {{ color: {c['ink']}; }}
    #stepper QPushButton:disabled {{ color: {c['rule']}; }}
    #stepperValue {{ font-family: "{MONO}"; font-size: 16px; font-weight: 600; min-width: 24px; }}

    #budgetValue {{ font-family: "{MONO}"; font-size: 20px; font-weight: 600; }}
    QSlider::groove:horizontal {{ height: 2px; background: {c['rule']}; }}
    QSlider::sub-page:horizontal {{ background: {c['ink']}; }}
    QSlider::handle:horizontal {{ background: {c['panel']}; border: 2px solid {c['ink']}; width: 12px; height: 12px;
                                  margin: -7px 0; border-radius: 8px; }}

    /* interest chips */
    #chip {{ background: transparent; border: 1px solid {c['rule']}; border-radius: 13px; padding: 5px 12px; min-height: 16px;
             font-size: 13px; color: {c['ink2']}; }}
    #chip:hover {{ border-color: {c['ink3']}; color: {c['ink']}; }}
    #chip:checked {{ background: {c['ink']}; border-color: {c['ink']}; color: {c['paper']}; }}

    #go {{ background: {c['ink']}; color: {c['paper']}; border: 0; border-radius: 6px; padding: 14px 18px;
           font-size: 16px; font-weight: 700; text-align: left; }}
    #go:disabled {{ background: {c['ink3']}; }}

    /* ticker */
    #ticker {{ background: {c['ink']}; border-radius: 6px; }}
    #tickerText {{ color: {c['paper']}; font-family: "{MONO}"; font-size: 12.5px; }}
    #skip {{ background: transparent; color: {c['paper']}; border: 1px solid {c['ink2']}; border-radius: 10px;
             padding: 2px 10px; font-size: 11.5px; }}
    #skip:hover {{ border-color: {c['paper']}; }}

    #back {{ background: {c['panel']}; border: 1px solid {c['rule']}; border-radius: 6px; padding: 8px 14px;
             font-weight: 700; font-size: 13px; }}
    #back:hover {{ border-color: {c['ink3']}; }}
    #back:disabled {{ color: {c['ink3']}; }}

    #mapColumn {{ border-left: 1px solid {c['rule']}; }}
    #expand {{ background: {c['panel']}; border: 1px solid {c['rule']}; border-radius: 6px; padding: 8px 12px;
               font-weight: 700; font-size: 13px; }}
    #expand:hover {{ border-color: {c['ink3']}; }}
    #mapFrame {{ border: 1px solid {c['rule']}; border-radius: 10px; background: {c['sea']}; }}

    /* results */
    #emptyTitle {{ font-size: 26px; font-weight: 800; }}
    #muted {{ color: {c['ink2']}; }}
    #query {{ font-family: "{MONO}"; font-size: 12px; color: {c['ink2']}; }}
    #notice {{ background: {c['panel']}; border: 1px solid {c['rule']}; border-radius: 6px; padding: 12px 14px; }}
    #error {{ color: {c['danger']}; font-family: "{MONO}"; font-size: 12.5px; border: 1px solid {c['danger']};
              border-radius: 6px; padding: 10px 12px; }}
    #tab {{ background: transparent; border: 1px solid {c['rule']}; border-radius: 6px; }}
    #tab:hover {{ border-color: {c['ink3']}; }}
    #tab[on="true"] {{ background: {c['panel']}; border: 2px solid {c['ink']}; }}
    #ticket {{ background: {c['panel']}; border: 1px solid {c['rule']}; border-radius: 10px; }}
    #ticketCode {{ font-size: 38px; font-weight: 800; }}
    #ticketCountry {{ font-size: 17px; font-weight: 800; }}
    #stopCode {{ background: {c['ink']}; color: {c['paper']}; border-radius: 4px; padding: 1px 6px;
                 font-family: "{MONO}"; font-size: 12px; font-weight: 600; }}
    #factKey {{ font-family: "{MONO}"; font-size: 10.5px; color: {c['ink3']}; }}
    #factValue {{ font-family: "{MONO}"; font-size: 15px; font-weight: 600; }}
    #layover {{ background: {c['paper']}; border-radius: 4px; padding: 4px 8px; font-size: 12px; color: {c['ink2']}; }}
    #sectionTitle {{ font-size: 13px; font-weight: 700; }}
    #mono {{ font-family: "{MONO}"; font-size: 12.5px; color: {c['ink2']}; }}
    #fine {{ font-size: 11.5px; color: {c['ink3']}; }}
    """
