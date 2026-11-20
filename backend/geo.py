import math

LON_MIN, LON_MAX = 89.0, 147.0
LAT_MIN, LAT_MAX = -11.0, 46.0
UNITS_PER_DEG = 2.0
LON_SCALE = math.cos(math.radians(17.0))

WIDTH = round((LON_MAX - LON_MIN) * LON_SCALE * UNITS_PER_DEG, 2)
HEIGHT = round((LAT_MAX - LAT_MIN) * UNITS_PER_DEG, 2)


def project(lat: float, lon: float) -> tuple[float, float]:
    x = (lon - LON_MIN) * LON_SCALE * UNITS_PER_DEG
    y = (LAT_MAX - lat) * UNITS_PER_DEG
    return round(x, 3), round(y, 3)
