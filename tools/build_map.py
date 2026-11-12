"""Build shared/asia_map.json from Natural Earth borders.

Usage:
  curl -o countries-10m.json https://cdn.jsdelivr.net/npm/world-atlas@2/countries-10m.json
  .venv/bin/python tools/build_map.py countries-10m.json

Decodes the TopoJSON, keeps the countries inside the map window, projects
them with backend/geo.py and simplifies the outlines so the site loads fast.
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "backend"))
from geo import HEIGHT, LAT_MAX, LAT_MIN, LON_MAX, LON_MIN, WIDTH, project  # noqa: E402

# Natural Earth name -> country id used in prolog/trip.pl
TRIP_COUNTRIES = {
    "Thailand": "thailand", "Japan": "japan", "South Korea": "korea", "China": "china", "Singapore": "singapore",
}

# Seas, placed by hand in lat/lon.
SEAS = [
    ("SOUTH CHINA SEA", 13.5, 114.0),
    ("PHILIPPINE SEA", 20.0, 131.0),
    ("SEA OF JAPAN", 40.0, 134.5),
    ("EAST CHINA SEA", 29.0, 125.5),
    ("ANDAMAN SEA", 11.0, 95.5),
    ("JAVA SEA", -5.2, 110.5),
    ("INDIAN OCEAN", -8.0, 95.0),
    ("PACIFIC OCEAN", 30.0, 142.0),
]


def decode(topo):
    sx, sy = topo["transform"]["scale"]
    tx, ty = topo["transform"]["translate"]
    arcs = []
    for arc in topo["arcs"]:
        x = y = 0
        pts = []
        for dx, dy in arc:
            x += dx
            y += dy
            pts.append((x * sx + tx, y * sy + ty))  # (lon, lat)
        arcs.append(pts)

    def ring(indexes):
        pts = []
        for i in indexes:
            a = arcs[i] if i >= 0 else arcs[~i][::-1]
            pts.extend(a if not pts else a[1:])
        return pts

    countries = {}
    for g in topo["objects"]["countries"]["geometries"]:
        polys = g["arcs"] if g["type"] == "MultiPolygon" else [g["arcs"]] if g["type"] == "Polygon" else []
        countries[g["properties"]["name"]] = [ring(p[0]) for p in polys]  # outer rings only
    return countries


def simplify(pts, tol):
    """Douglas–Peucker, iterative so long coastlines don't hit the recursion limit."""
    if len(pts) < 3:
        return pts
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        a, b = stack.pop()
        (x1, y1), (x2, y2) = pts[a], pts[b]
        dx, dy = x2 - x1, y2 - y1
        norm = (dx * dx + dy * dy) ** 0.5
        best, idx = 0.0, -1
        for i in range(a + 1, b):
            px, py = pts[i]
            d = abs(dy * px - dx * py + x2 * y1 - y2 * x1) / norm if norm else ((px - x1) ** 2 + (py - y1) ** 2) ** 0.5
            if d > best:
                best, idx = d, i
        if idx >= 0 and best > tol:
            keep[idx] = True
            stack += [(a, idx), (idx, b)]
    return [p for p, k in zip(pts, keep) if k]


def in_view(ring, pad=3.0):
    lons = [p[0] for p in ring]
    lats = [p[1] for p in ring]
    return (max(lons) > LON_MIN - pad and min(lons) < LON_MAX + pad
            and max(lats) > LAT_MIN - pad and min(lats) < LAT_MAX + pad)


def size(ring):
    lons = [p[0] for p in ring]
    lats = [p[1] for p in ring]
    return max(max(lons) - min(lons), max(lats) - min(lats))


def shapes(rings, tol, min_size):
    out = []
    for r in rings:
        if not in_view(r) or size(r) < min_size:
            continue
        s = simplify(r, tol)
        if len(s) >= 4:
            out.append([list(project(lat, lon)) for lon, lat in s])
    return out


def main(src):
    countries = decode(json.loads(Path(src).read_text()))
    shapes_out = []
    for name, rings in countries.items():
        trip = TRIP_COUNTRIES.get(name)
        # trip countries keep more detail and small islands (Bali, Jeju, Macau)
        rs = shapes(rings, tol=0.012, min_size=0.03) if trip else shapes(rings, tol=0.08, min_size=0.5)
        if rs:
            shapes_out.append({"name": name, "trip": trip, "rings": rs})
    data = {
        "width": WIDTH,
        "height": HEIGHT,
        "countries": shapes_out,
        "grid": [{"axis": "lat", "deg": d, "pos": project(d, LON_MIN)[1]} for d in range(-10, 46, 10)]
        + [{"axis": "lon", "deg": d, "pos": project(LAT_MIN, d)[0]} for d in range(90, 147, 10)],
        "seas": [{"text": t, "x": project(lat, lon)[0], "y": project(lat, lon)[1]} for t, lat, lon in SEAS],
    }
    out = ROOT / "shared" / "asia_map.json"
    out.write_text(json.dumps(data, separators=(",", ":")))
    pts = sum(len(r) for c in shapes_out for r in c["rings"])
    print(f"wrote {out} · {len(shapes_out)} countries · {pts} points · {out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main(sys.argv[1])
