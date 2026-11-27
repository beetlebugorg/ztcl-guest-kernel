#!/usr/bin/env python3
"""Makes docs/progress-light.svg and docs/progress-dark.svg from data.tsv.

Run: python3 tools/chart/chart.py
It uses only the standard library of Python.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

PANELS = [
    ("kvm", "KVM: guest boot to agent listen", "ms, best of 30 to 60 boots"),
    ("vz", "Virtualization.framework (M1): guest boot to agent listen", "ms, best of 10 boots"),
    ("whp", "WHP: start to agent answer", "ms, 256 MB guest"),
    ("size", "Loaded size of the x86-64 kernel", "MB"),
    ("mem", "Pooled 128 MB guest with -balloon 1, resident on KVM", "MB, after the boot"),
]

THEMES = {
    "light": {"bg": "#ffffff", "fg": "#1f2328", "muted": "#59636e", "grid": "#d1d9e0",
              "line": "#0969da", "noisy": "#bc4c00", "move": "#8250df"},
    "dark": {"bg": "#0d1117", "fg": "#f0f6fc", "muted": "#9198a1", "grid": "#3d444d",
             "line": "#4493f8", "noisy": "#f0883e", "move": "#ab7df8"},
}

W, PW, PH = 1000, 470, 300
MARGIN, GAP = 30, 20
PAD_L, PAD_R, PAD_T, PAD_B = 50, 16, 52, 92


def load():
    rows = {}
    with open(os.path.join(HERE, "data.tsv")) as f:
        for line in f:
            if not line.strip() or line.startswith("#"):
                continue
            panel, step, label, value, style, note = (line.rstrip("\n").split("\t") + [""] * 6)[:6]
            rows.setdefault(panel, []).append((int(step), label, float(value), style, note))
    for r in rows.values():
        r.sort()
    return rows


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def nice_max(v):
    for e in range(-1, 4):
        for m in (1, 2, 2.5, 5):
            top = m * 10 ** e
            if top >= v * 1.15:
                return top, top / 5
    return v * 1.2, v / 5


def fmt(v):
    return ("%.2f" % v).rstrip("0").rstrip(".") if v < 100 else "%d" % round(v)


def panel_svg(x0, y0, key, title, unit, pts, t):
    out = []
    left, top = x0 + PAD_L, y0 + PAD_T
    width, height = PW - PAD_L - PAD_R, PH - PAD_T - PAD_B
    out.append(f'<text x="{x0}" y="{y0 + 18}" font-size="15" font-weight="600" fill="{t["fg"]}">{esc(title)}</text>')
    out.append(f'<text x="{x0}" y="{y0 + 36}" font-size="12" fill="{t["muted"]}">{esc(unit)}</text>')
    vmax, tick = nice_max(max(p[2] for p in pts))
    n = len(pts)
    def px(i):
        return left + (width * (i + 0.5) / n)
    def py(v):
        return top + height - height * v / vmax
    v = 0.0
    while v <= vmax + 1e-9:
        y = py(v)
        out.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left + width}" y2="{y:.1f}" stroke="{t["grid"]}" stroke-width="1"/>')
        out.append(f'<text x="{left - 6}" y="{y + 4:.1f}" font-size="11" text-anchor="end" fill="{t["muted"]}">{fmt(v)}</text>')
        v += tick
    # The move from 6.12 to 7.3.
    for i in range(1, n):
        if pts[i][1].startswith("7.3") and not pts[i - 1][1].startswith("7.3"):
            xm = (px(i - 1) + px(i)) / 2
            out.append(f'<line x1="{xm:.1f}" y1="{top}" x2="{xm:.1f}" y2="{top + height}" stroke="{t["move"]}" stroke-width="1.5" stroke-dasharray="5 4"/>')
            out.append(f'<text x="{xm + 4:.1f}" y="{top + 12}" font-size="11" fill="{t["move"]}">6.12 to 7.3</text>')
    # The line through the points of the main series, and a dashed line
    # through the noisy points.
    for style, color, dash in (("solid", t["line"], ""), ("hollow", t["noisy"], ' stroke-dasharray="4 3"')):
        seq = [(px(i), py(p[2])) for i, p in enumerate(pts) if p[3] == style]
        if len(seq) > 1:
            d = " ".join(f"{a:.1f},{b:.1f}" for a, b in seq)
            out.append(f'<polyline points="{d}" fill="none" stroke="{color}" stroke-width="2.5"{dash}/>')
    for i, (step, label, value, style, note) in enumerate(pts):
        x, y = px(i), py(value)
        if style == "hollow":
            out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5" fill="{t["bg"]}" stroke="{t["noisy"]}" stroke-width="2"/>')
            color = t["noisy"]
        else:
            out.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5" fill="{t["line"]}"/>')
            color = t["fg"]
        out.append(f'<text x="{x:.1f}" y="{y - 10:.1f}" font-size="12" font-weight="600" text-anchor="middle" fill="{color}">{fmt(value)}</text>')
        words = label.split(" ")
        lines, cur = [], ""
        for w in words:
            if len(cur) + len(w) + 1 > 13 and cur:
                lines.append(cur)
                cur = w
            else:
                cur = (cur + " " + w).strip()
        lines.append(cur)
        nlab = len(lines)
        if note:
            lines.append(f"({note})")
        for k, l in enumerate(lines[:5]):
            c = t["noisy"] if (k >= nlab and style == "hollow") else t["muted"]
            out.append(f'<text x="{x:.1f}" y="{top + height + 18 + 13 * k:.1f}" font-size="11" text-anchor="middle" fill="{c}">{esc(l)}</text>')
    return out


def svg(theme, rows):
    t = THEMES[theme]
    nrows = (len(PANELS) + 2) // 2
    H = MARGIN * 2 + 40 + nrows * PH + (nrows - 1) * GAP
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="-apple-system, Segoe UI, Helvetica, Arial, sans-serif">',
           f'<rect width="{W}" height="{H}" fill="{t["bg"]}"/>',
           f'<text x="{MARGIN}" y="{MARGIN + 16}" font-size="18" font-weight="700" fill="{t["fg"]}">Boot time, size, and memory of the guest kernel of ztcl::vm</text>',
           f'<text x="{MARGIN}" y="{MARGIN + 34}" font-size="12" fill="{t["muted"]}">Lower is better. Hollow points are from a host with other work on it (load 10): the load changes such times by up to a factor of 2. Data: tools/chart/data.tsv, from TIMES.md.</text>']
    for i, (key, title, unit) in enumerate(PANELS):
        col, row = i % 2, i // 2
        x0 = MARGIN + col * (PW + GAP)
        y0 = MARGIN + 50 + row * (PH + GAP)
        out += panel_svg(x0, y0, key, title, unit, rows[key], t)
    # The key, in the free cell.
    x0, y0 = MARGIN + (PW + GAP), MARGIN + 50 + 2 * (PH + GAP) + 30
    out.append(f'<circle cx="{x0 + 8}" cy="{y0}" r="5" fill="{t["line"]}"/><text x="{x0 + 22}" y="{y0 + 4}" font-size="12" fill="{t["fg"]}">a measured step, in the order of the changes</text>')
    out.append(f'<circle cx="{x0 + 8}" cy="{y0 + 24}" r="5" fill="{t["bg"]}" stroke="{t["noisy"]}" stroke-width="2"/><text x="{x0 + 22}" y="{y0 + 28}" font-size="12" fill="{t["fg"]}">a pair measured together on a loaded host (noisy)</text>')
    out.append(f'<line x1="{x0}" y1="{y0 + 48}" x2="{x0 + 16}" y2="{y0 + 48}" stroke="{t["move"]}" stroke-width="1.5" stroke-dasharray="5 4"/><text x="{x0 + 22}" y="{y0 + 52}" font-size="12" fill="{t["fg"]}">the move from Linux 6.12 to 7.3</text>')
    out.append("</svg>")
    return "\n".join(out) + "\n"


def main():
    rows = load()
    os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)
    for theme in THEMES:
        path = os.path.join(ROOT, "docs", f"progress-{theme}.svg")
        with open(path, "w") as f:
            f.write(svg(theme, rows))
        print(path)


if __name__ == "__main__":
    sys.exit(main())
