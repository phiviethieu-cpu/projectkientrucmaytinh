#!/usr/bin/env python3
"""Sinh các hình cho báo cáo vào docs/figures/ (PNG, 200 dpi, nền sáng để in).

  fig_timeline.png   chuỗi pha đèn theo tick của 4 bộ điều khiển (từ sim/tb_tlc.vcd)
  fig_latency.png    phóng to mức chu kỳ clock quanh một tick: độ trễ của từng cách
  fig_compare.png    so sánh LUT4, flip-flop, Fmax, độ trễ (từ synth/summary.md)
  fig_exp_ped.png    chi phí thêm pha đi bộ (từ synth/experiments.md)
  fig_state.png      sơ đồ trạng thái
  fig_arch.png       sơ đồ khối 4 kiến trúc

Cần chạy trước: scripts/run_sim.sh, scripts/synth.sh, scripts/experiments.py
Chạy từ thư mục gốc:  python scripts/make_figures.py
"""
import re
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt                      # noqa: E402
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "figures"

# ---- bảng màu (palette tham chiếu của skill dataviz, đã kiểm tra CVD) ----
SURFACE, INK, INK2, MUTED, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#8a8984", "#e6e5e0"
SERIES = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100"]     # 4 phương pháp, thứ tự cố định
METHODS = ["FSM cứng", "Vi chương trình ngang", "Vi chương trình dọc", "CPU mini"]
SHORT = ["FSM", "Micro ngang", "Micro dọc", "CPU"]
# màu đèn: dùng đúng màu của miền bài toán, luôn kèm chữ tên pha
LAMP = {"R": "#e34948", "Y": "#eda100", "G": "#1baf7a", "-": "#d9d8d3"}

plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 9, "axes.edgecolor": MUTED,
    "axes.labelcolor": INK2, "xtick.color": INK2, "ytick.color": INK2,
    "axes.facecolor": SURFACE, "figure.facecolor": SURFACE, "savefig.facecolor": SURFACE,
    "axes.spines.top": False, "axes.spines.right": False,
})

PHASE = {0b001100: "NSG", 0b010100: "NSY", 0b100100: "AR", 0b100001: "EWG",
         0b100010: "EWY", 0b010010: "FON", 0b000000: "OFF"}


def lamp(code, ns):
    bits = (code >> 3) & 7 if ns else code & 7
    return {4: "R", 2: "Y", 1: "G"}.get(bits, "-")


# ------------------------------------------------------------------ VCD
def read_vcd(path, names):
    """Trả về {tên: [(thời_điểm, giá_trị), ...]} cho các tín hiệu ở scope trên cùng."""
    ids, depth, t = {}, 0, 0
    changes = {n: [] for n in names}
    with open(path, encoding="ascii", errors="replace") as f:
        header = True
        for line in f:
            line = line.strip()
            if header:
                if line.startswith("$scope"):
                    depth += 1
                elif line.startswith("$upscope"):
                    depth -= 1
                elif line.startswith("$var") and depth == 1:
                    p = line.split()
                    if p[4] in names and p[3] not in ids:
                        ids[p[3]] = p[4]
                elif line.startswith("$enddefinitions"):
                    header = False
                continue
            if not line or line.startswith("$"):
                continue
            if line[0] == "#":
                t = int(line[1:])
            elif line[0] == "b":
                val, code = line[1:].split()
                if code in ids:
                    changes[ids[code]].append((t, int(val, 2) if set(val) <= {"0", "1"} else -1))
            elif line[0] in "01xz" and line[1:] in ids:
                changes[ids[line[1:]]].append((t, int(line[0]) if line[0] in "01" else -1))
    return changes


def value_at(ch, t):
    """Giá trị ngay TRƯỚC thời điểm t."""
    v = -1
    for tt, vv in ch:
        if tt >= t:
            break
        v = vv
    return v


# ------------------------------------------------------------- hình 1, 2
def fig_timeline(vcd):
    tick_falls = [t for t, v in vcd["tick"] if v == 0 and t > 0]   # cạnh lấy mẫu
    lo, hi = 14, 120
    samples = tick_falls[lo:hi]
    sigs = ["l_fsm", "l_mic", "l_vmc", "l_cpu"]
    fig, ax = plt.subplots(figsize=(10, 4.2))
    lanes = []
    for i, s in enumerate(sigs):
        for ns in (True, False):
            lanes.append((f"{SHORT[i]} · {'NS' if ns else 'EW'}", s, ns))
    for row, (label, s, ns) in enumerate(lanes):
        y = len(lanes) - row + (0.35 if not ns else 0)
        for k, t in enumerate(samples):
            code = value_at(vcd[s], t)
            ax.barh(y, 1, left=lo + k, height=0.8, color=LAMP[lamp(code, ns)], edgecolor=SURFACE, linewidth=0.6)
    ax.set_yticks([len(lanes) - r + (0.35 if not ns else 0) for r, (_, _, ns) in enumerate(lanes)])
    ax.set_yticklabels([l for l, _, _ in lanes])
    # đầu vào
    for name, y0, txt in (("sensor", -0.6, "sensor"), ("night", -1.6, "night")):
        for k, t in enumerate(samples):
            if value_at(vcd[name], t) == 1:
                ax.barh(y0, 1, left=lo + k, height=0.5, color=INK2, edgecolor=SURFACE, linewidth=0.4)
        ax.text(lo - 0.5, y0, txt, ha="right", va="center", color=INK2)
    ax.set_xlim(lo, hi)
    ax.set_ylim(-3.1, len(lanes) + 1.2)
    ax.set_xlabel("tick (giây)")
    ax.spines["left"].set_visible(False)
    ax.tick_params(axis="y", length=0)
    for k, (name, col) in enumerate((("Đỏ", "R"), ("Vàng", "Y"), ("Xanh", "G"), ("Tắt", "-"))):
        ax.barh(len(lanes) + 0.9, 3, left=lo + 1 + k * 9, height=0.5, color=LAMP[col])
        ax.text(lo + 4.5 + k * 9, len(lanes) + 0.9, name, va="center", color=INK2)
    ax.set_title("Chuỗi pha đèn của 4 bộ điều khiển, lấy mẫu tại mỗi tick (tick 14–120)",
                 loc="left", color=INK, fontsize=11)
    for x, txt in ((20, "có xe phụ"), (60, "hết xe"), (90, "bật đêm"), (110, "tắt đêm")):
        ax.axvline(x, color=MUTED, lw=0.8, ls=":")
        ax.text(x + 0.3, -2.75, txt, color=INK2, fontsize=8, va="center")
    fig.tight_layout()
    fig.savefig(OUT / "fig_timeline.png", dpi=200)
    plt.close(fig)


def fig_latency(vcd):
    """Phóng to quanh tick làm đèn chuyển AR -> NSG lần đầu."""
    tick_rises = [t for t, v in vcd["tick"] if v == 1]
    period = 10_000  # 10 ns = 10000 ps
    target = None
    for tr in tick_rises:
        t_edge = tr + period // 2          # cạnh lên clock có tick = 1
        before = value_at(vcd["l_fsm"], t_edge)
        after = value_at(vcd["l_fsm"], t_edge + period)
        if before == 0b100100 and after == 0b001100:
            target = t_edge
            break
    n = 36
    t0 = target - 2 * period
    fig, ax = plt.subplots(figsize=(10, 3.4))
    rows = [("tick", None)] + list(zip(SHORT, ["l_fsm", "l_mic", "l_vmc", "l_cpu"]))
    for r, (label, s) in enumerate(rows):
        y = len(rows) - r
        if s is None:
            xs, ys = [], []
            for c in range(n):
                t = t0 + c * period + period // 2
                v = value_at(vcd["tick"], t)
                xs += [c, c + 1]
                ys += [y - 0.3 + 0.6 * v] * 2
            ax.plot(xs, ys, color=INK, lw=1.6)
        else:
            prev, start = None, 0
            vals = [value_at(vcd[s], t0 + c * period + period // 2 + 1) for c in range(n)]
            # độ trễ tính như testbench: số cạnh clock từ cạnh có tick (kể cả cạnh đó)
            first = next(c for c in range(2, n) if vals[c] != vals[1])
            lat = first - 2 + 1
            ax.text(n + 0.4, y, f"{lat} chu kỳ", va="center", color=INK, fontsize=9)
            vals.append(None)
            for c, v in enumerate(vals):
                if v != prev:
                    if prev is not None:
                        col = SERIES[r - 1] if PHASE.get(prev) == "NSG" else "#d9d8d3"
                        ax.add_patch(FancyBboxPatch((start + 0.05, y - 0.3), c - start - 0.1, 0.6,
                                                    boxstyle="round,pad=0,rounding_size=0.15",
                                                    fc=col, ec="none"))
                        ax.text((start + c) / 2, y, PHASE.get(prev, "?"), ha="center", va="center",
                                color=INK, fontsize=8)
                    prev, start = v, c
        ax.text(-0.6, y, label, ha="right", va="center", color=INK2)
    # đánh dấu độ trễ
    edge = 2
    ax.axvline(edge, color=MUTED, lw=0.8, ls="--")
    ax.text(edge + 0.2, len(rows) + 0.55, "cạnh clock có tick", color=INK2, fontsize=8)
    ax.set_xlim(-0.2, n + 4)
    ax.set_ylim(0.4, len(rows) + 0.9)
    ax.set_yticks([])
    ax.set_xlabel("chu kỳ clock (tính từ 2 chu kỳ trước tick)")
    ax.spines["left"].set_visible(False)
    ax.set_title("Độ trễ từ tick đến lúc đèn đổi (pha AR → NSG): đếm bằng chu kỳ clock",
                 loc="left", color=INK, fontsize=11)
    fig.tight_layout()
    fig.savefig(OUT / "fig_latency.png", dpi=200)
    plt.close(fig)


# ------------------------------------------------------------- hình 3, 4
def md_rows(path):
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("|") and not line.startswith("|---"):
            rows.append([c.strip() for c in line.strip("|").split("|")])
    return rows


def bars(ax, values, title, unit="", fmt="{:g}"):
    x = range(len(values))
    ax.bar(x, values, width=0.62, color=SERIES, edgecolor=SURFACE, linewidth=2)
    for i, v in enumerate(values):
        ax.text(i, v, " " + fmt.format(v) + unit, ha="center", va="bottom", color=INK, fontsize=9)
    ax.set_xticks(list(x))
    ax.set_xticklabels([s.replace(" ", "\n", 1) for s in SHORT], fontsize=8)
    ax.set_title(title, loc="left", color=INK, fontsize=10)
    ax.yaxis.grid(True, color=GRID, lw=0.6)
    ax.set_axisbelow(True)
    ax.set_ylim(0, max(values) * 1.18)
    ax.tick_params(axis="x", length=0)


def fig_compare():
    rows = md_rows(ROOT / "synth" / "summary.md")[1:]
    lut = [int(r[4]) for r in rows]
    dff = [int(r[5]) for r in rows]
    fmax = [float(r[8].split()[0]) for r in rows]
    latency = [1, 1, 5, 30]   # từ sim/tb_tlc.log (độ trễ xấu nhất)
    fig, axs = plt.subplots(1, 4, figsize=(11, 3.3))
    bars(axs[0], lut, "iCE40 LUT4 (ít hơn = tốt)")
    bars(axs[1], dff, "Flip-flop (ít hơn = tốt)")
    bars(axs[2], fmax, "Fmax, MHz (cao hơn = tốt)", fmt="{:.0f}")
    bars(axs[3], latency, "Độ trễ tick→đèn, chu kỳ\n(thấp hơn = tốt)")
    fig.suptitle("So sánh 4 phương pháp trên FPGA iCE40 HX8K", x=0.01, ha="left", color=INK, fontsize=11)
    fig.tight_layout()
    fig.savefig(OUT / "fig_compare.png", dpi=200)
    plt.close(fig)


def fig_exp_ped():
    text = (ROOT / "synth" / "experiments.md").read_text(encoding="utf-8")
    part = text.split("### B.")[1]
    rows = [r for r in md_rows_from_text(part)[1:]]
    def plus(s):
        m = re.match(r"\+(\d+)/−(\d+)", s)
        return int(m.group(1)) + int(m.group(2)) if m else 0
    hw = [plus(r[1]) for r in rows]
    mem = [plus(r[2]) for r in rows]
    tool = [plus(r[3]) for r in rows]
    lut = [tuple(int(x) for x in r[4].split("→")) for r in rows]

    fig, axs = plt.subplots(1, 2, figsize=(11, 3.6), gridspec_kw={"width_ratios": [1.25, 1]})
    ax = axs[0]
    y = list(range(len(rows)))[::-1]
    cats = (("phần cứng (.v)", hw, "#52514e"), ("bộ nhớ / phần mềm", mem, "#9c9b95"),
            ("công cụ (assembler)", tool, "#cfcec8"))
    left = [0] * len(rows)
    for name, vals, col in cats:
        ax.barh(y, vals, left=left, height=0.55, color=col, edgecolor=SURFACE, linewidth=2, label=name)
        left = [a + b for a, b in zip(left, vals)]
    for yi, tot, h in zip(y, left, hw):
        ax.text(tot + 0.6, yi, f"{tot} dòng (phần cứng {h})", va="center", color=INK, fontsize=8)
    ax.set_yticks(y)
    ax.set_yticklabels(SHORT)
    ax.set_xlim(0, max(left) * 1.45)
    ax.set_xlabel("số dòng mã thêm + xoá (không tính chú thích)")
    ax.legend(frameon=False, loc="lower right", fontsize=8)
    ax.set_title("Dòng mã phải sửa để thêm pha đi bộ", loc="left", color=INK, fontsize=10)
    ax.xaxis.grid(True, color=GRID, lw=0.6)
    ax.set_axisbelow(True)

    ax = axs[1]
    for i, (a, b) in enumerate(lut):
        yy = len(rows) - 1 - i
        ax.plot([a, b], [yy, yy], color=SERIES[i], lw=2)
        ax.plot([a], [yy], "o", ms=7, mfc=SURFACE, mec=SERIES[i], mew=2)
        ax.plot([b], [yy], "o", ms=8, color=SERIES[i], mec=SURFACE, mew=2)
        ax.text(b + 5, yy, f"{a} → {b} (+{(b - a) / a * 100:.0f}%)", va="center", color=INK, fontsize=8)
    ax.set_yticks(list(range(len(rows)))[::-1])
    ax.set_yticklabels(SHORT)
    ax.set_xlim(0, max(b for _, b in lut) * 1.45)
    ax.set_xlabel("iCE40 LUT4 (vòng rỗng = trước, chấm đặc = sau)")
    ax.set_title("Tài nguyên trước → sau khi thêm", loc="left", color=INK, fontsize=10)
    ax.xaxis.grid(True, color=GRID, lw=0.6)
    ax.set_axisbelow(True)
    fig.tight_layout()
    fig.savefig(OUT / "fig_exp_ped.png", dpi=200)
    plt.close(fig)


def md_rows_from_text(text):
    rows = []
    for line in text.splitlines():
        if line.startswith("|") and not line.startswith("|---"):
            rows.append([c.strip() for c in line.strip("|").split("|")])
    return rows


# ------------------------------------------------------------- hình 5, 6
def box(ax, x, y, w, h, text, fc="#f1f0ec", ec=MUTED, fs=8.5):
    """Vẽ hộp, trả về hình học (x, y, w, h) để nối mũi tên vào mép hộp."""
    ax.add_patch(FancyBboxPatch((x - w / 2, y - h / 2), w, h, boxstyle="round,pad=0.02,rounding_size=0.08",
                                fc=fc, ec=ec, lw=1, zorder=2))
    ax.text(x, y, text, ha="center", va="center", fontsize=fs, color=INK, zorder=3)
    return (x, y, w, h)


def _edge(b, toward, side=None):
    """Điểm trên mép hộp b theo hướng tới điểm `toward`, hoặc giữa cạnh chỉ định."""
    if len(b) == 2:
        return b
    x, y, w, h = b
    if side:
        return {"l": (x - w / 2, y), "r": (x + w / 2, y), "t": (x, y + h / 2), "b": (x, y - h / 2)}[side]
    dx, dy = toward[0] - x, toward[1] - y
    if dx == 0 and dy == 0:
        return (x, y)
    t = min((w / 2 + 0.06) / abs(dx) if dx else 1e9, (h / 2 + 0.06) / abs(dy) if dy else 1e9)
    return (x + dx * t, y + dy * t)


def arrow(ax, a, b, text="", rad=0.0, fs=7.5, off=(0, 0), sa=None, sb=None):
    """Mũi tên từ hộp/điểm a tới hộp/điểm b, đầu mút nằm trên mép hộp.
    sa, sb: ép cạnh xuất phát / kết thúc ('l', 'r', 't', 'b')."""
    p = _edge(a, b[:2], sa)
    q = _edge(b, p if sa else a[:2], sb)
    ax.add_patch(FancyArrowPatch(p, q, arrowstyle="-|>", mutation_scale=10, color=INK2, lw=1,
                                 connectionstyle=f"arc3,rad={rad}", shrinkA=0, shrinkB=0, zorder=1))
    if text:
        mx, my = (p[0] + q[0]) / 2 + off[0], (p[1] + q[1]) / 2 + off[1]
        ax.text(mx, my, text, ha="center", va="center", fontsize=fs, color=INK2, zorder=4,
                bbox=dict(fc=SURFACE, ec="none", pad=0.8))


def fig_state():
    fig, ax = plt.subplots(figsize=(10, 5.4))
    G, Y, R, O = "#d6f1e6", "#fbe9c2", "#f8d7d6", "#ebeae6"
    w, h = 1.75, 0.95
    B = {
        "NSG":  box(ax, 0.0, 2.2, w, h, "NSG\nNS xanh ≥ 8", G),
        "NSY":  box(ax, 3.2, 2.2, w, h, "NSY\nNS vàng 3", Y),
        "AR1":  box(ax, 6.4, 2.2, w, h, "AR1\nđỏ toàn phần 1", R),
        "EWG":  box(ax, 9.6, 2.2, w, h, "EWG\nEW xanh 5", G),
        "EWY":  box(ax, 9.6, -0.6, w, h, "EWY\nEW vàng 3", Y),
        "AR2":  box(ax, 4.8, -0.6, w, h, "AR2\nđỏ toàn phần 1", R),
        "FON":  box(ax, 6.4, -3.1, w, h, "FON\nvàng 1", Y),
        "FOFF": box(ax, 3.2, -3.1, w, h, "FOFF\ntắt 1", O),
    }
    arrow(ax, B["NSG"], B["NSY"], "sensor ∨ night", off=(0, 0.28))
    arrow(ax, B["NSY"], B["AR1"], "hết giờ", off=(0, 0.28))
    arrow(ax, B["AR1"], B["EWG"], "¬night", off=(0, 0.28))
    arrow(ax, B["EWG"], B["EWY"], "hết giờ", off=(0.5, 0))
    arrow(ax, B["EWY"], B["AR2"], "hết giờ", off=(0, 0.28))
    arrow(ax, B["AR2"], B["NSG"], "¬night", off=(-0.35, 0.15))
    arrow(ax, B["AR1"], B["FON"], "night", sa="b", sb="t", off=(0.42, 0.6))
    arrow(ax, B["AR2"], B["FON"], "night", off=(-0.45, -0.1))
    arrow(ax, (6.4, -3.58), (3.2, -3.58), "hết giờ", rad=-0.35, off=(0, -0.6))
    arrow(ax, (4.08, -3.1), (5.52, -3.1), "night", off=(0, 0.25))
    arrow(ax, B["FOFF"], B["AR2"], "¬night", off=(-0.45, 0.05))
    # NSG tự giữ khi chưa có xe
    ax.add_patch(FancyArrowPatch((-0.45, 2.68), (0.45, 2.68), arrowstyle="-|>", mutation_scale=10,
                                 color=INK2, lw=1, connectionstyle="arc3,rad=-1.2", shrinkA=0, shrinkB=0))
    ax.text(0, 3.45, "giữ xanh nếu ¬(sensor ∨ night)", ha="center", fontsize=7.5, color=INK2)
    ax.annotate("", xy=(-0.9, 2.2), xytext=(-1.7, 2.2), arrowprops=dict(arrowstyle="-|>", color=INK2))
    ax.text(-1.75, 2.2, "reset", ha="right", va="center", color=INK2, fontsize=8)
    ax.set_xlim(-2.5, 10.8)
    ax.set_ylim(-4.6, 3.8)
    ax.axis("off")
    ax.set_title("Sơ đồ trạng thái bộ điều khiển (thời lượng tính bằng tick)", loc="left", color=INK, fontsize=11)
    fig.tight_layout()
    fig.savefig(OUT / "fig_state.png", dpi=200)
    plt.close(fig)


def fig_arch():
    fig, axs = plt.subplots(2, 2, figsize=(11, 7.6))
    for ax in axs.flat:
        ax.set_xlim(0, 10)
        ax.set_ylim(0, 6)
        ax.axis("off")
    hl = lambda i: SERIES[i] + "22"
    REG = "#ebeae6"

    # (a) FSM cứng
    ax = axs[0, 0]
    ax.set_title("(a) FSM cứng", loc="left", color=INK, fontsize=10)
    inp = box(ax, 1.6, 4.6, 2.2, 0.8, "sensor, night", SURFACE)
    nl = box(ax, 5.0, 4.6, 3.0, 1.2, "Logic trạng thái kế\n+ bảng thời lượng", hl(0))
    st = box(ax, 5.0, 2.2, 2.6, 1.0, "state (3 bit)\ncnt (4 bit)", REG)
    ol = box(ax, 8.4, 2.2, 2.0, 1.0, "Giải mã ra\n(Moore)", hl(0))
    lt = box(ax, 8.4, 4.6, 1.6, 0.8, "lights", SURFACE)
    arrow(ax, inp, nl)
    arrow(ax, (4.4, 4.0), (4.4, 2.7), "next", off=(-0.4, 0))
    arrow(ax, (5.6, 2.7), (5.6, 4.0), "state, cnt", off=(0.65, 0))
    arrow(ax, st, ol)
    arrow(ax, ol, lt)
    ax.text(5, 0.7, "Hành vi nằm trong cổng logic; đổi hành vi = sửa RTL", ha="center", color=INK2, fontsize=8)

    # (b) Vi chương trình ngang
    ax = axs[0, 1]
    ax.set_title("(b) Vi chương trình ngang (1 vi lệnh = 1 pha)", loc="left", color=INK, fontsize=10)
    upc = box(ax, 1.3, 3.2, 1.8, 0.8, "uPC (4 bit)", REG)
    cs = box(ax, 4.4, 3.2, 2.8, 1.5, "Control store\nROM 16 × 20 bit\nLIGHTS | DUR | COND\n| NEXT_T | NEXT_F", hl(1))
    lt = box(ax, 8.4, 5.1, 1.6, 0.7, "lights", SURFACE)
    cm = box(ax, 8.4, 3.6, 2.2, 0.8, "MUX điều kiện\n← sensor, night", hl(1))
    am = box(ax, 8.4, 1.8, 2.2, 0.8, "MUX địa chỉ", hl(1))
    tm = box(ax, 4.4, 5.3, 2.6, 0.7, "cnt + so sánh DUR", REG)
    arrow(ax, upc, cs)
    arrow(ax, cs, lt, "LIGHTS", off=(-0.2, 0.25))
    arrow(ax, cs, cm, "COND", off=(0, 0.22))
    arrow(ax, cs, am, "NEXT_T/F", off=(0.1, -0.3))
    arrow(ax, cm, am, "cond", off=(0.4, 0))
    arrow(ax, cs, tm, "DUR", off=(0.35, 0))
    arrow(ax, am, upc, sa="b", sb="b", rad=-0.35)
    ax.text(6.0, 0.15, "Sequencer cố định; hành vi nằm trong ROM", ha="center", color=INK2, fontsize=8)

    # (c) Vi chương trình dọc
    ax = axs[1, 0]
    ax.set_title("(c) Vi chương trình dọc (1 vi lệnh = 1 việc, 1 chu kỳ)", loc="left", color=INK, fontsize=10)
    upc = box(ax, 1.3, 3.0, 1.8, 0.8, "uPC (5 bit)", REG)
    cs = box(ax, 4.3, 3.0, 2.4, 1.3, "Control store\nROM 32 × 10 bit\nop | arg", hl(2))
    l1 = box(ax, 8.3, 4.6, 2.6, 0.75, "LIGHT → thanh ghi đèn", hl(2))
    l2 = box(ax, 8.3, 3.2, 2.6, 0.75, "TIMER → bộ định thời", hl(2))
    l3 = box(ax, 8.3, 1.8, 2.6, 0.75, "BR cond, addr", hl(2))
    nx = box(ax, 4.3, 0.8, 2.6, 0.75, "uPC + 1 hoặc addr", REG)
    arrow(ax, upc, cs)
    for b in (l1, l2, l3):
        arrow(ax, cs, b)
    arrow(ax, l3, nx)
    arrow(ax, nx, upc)
    ax.text(5, 5.6, "Một pha = LIGHT, TIMER, BR TRUN (chờ), BR điều kiện", ha="center", fontsize=8, color=INK2)

    # (d) CPU mini
    ax = axs[1, 1]
    ax.set_title("(d) CPU mini + phần mềm", loc="left", color=INK, fontsize=10)
    im = box(ax, 1.5, 4.5, 2.4, 1.0, "IMEM (BRAM)\n256 × 16 bit\nfirmware", hl(3))
    pc = box(ax, 1.5, 2.0, 2.4, 1.0, "PC, IR\nFSM FETCH/EXEC", REG)
    rf = box(ax, 5.0, 3.2, 2.4, 1.6, "Tệp thanh ghi R0–R3\nALU 8 bit, cờ Z", hl(3))
    io = box(ax, 8.6, 4.5, 2.4, 1.0, "Ngoại vi I/O\ncổng 0: vào / đèn\ncổng 1: xoá tick", REG)
    tk = box(ax, 8.6, 2.0, 2.4, 1.0, "tick_flag + snapshot\nsensor, night", REG)
    arrow(ax, im, pc, "lệnh", off=(0.35, 0))
    arrow(ax, pc, rf)
    arrow(ax, rf, io, "OUT", off=(0, 0.25))
    arrow(ax, tk, rf, "IN", off=(0, -0.25))
    ax.text(5, 0.6, "Phần cứng đa dụng; hành vi nằm hoàn toàn trong firmware", ha="center", color=INK2, fontsize=8)

    fig.suptitle("Sơ đồ khối 4 phương pháp hiện thực", x=0.01, ha="left", color=INK, fontsize=11)
    fig.tight_layout()
    fig.savefig(OUT / "fig_arch.png", dpi=200)
    plt.close(fig)


def fig_control():
    """Hai kiểu khối điều khiển trong lý thuyết (Chương 2)."""
    fig, axs = plt.subplots(1, 2, figsize=(11, 3.7))
    for ax in axs:
        ax.set_xlim(0, 10)
        ax.set_ylim(0, 6)
        ax.axis("off")
    ax = axs[0]
    ax.set_title("(a) Điều khiển cứng", loc="left", color=INK, fontsize=10)
    inp = box(ax, 1.7, 4.4, 2.6, 0.9, "Đầu vào, cờ trạng thái", SURFACE)
    log = box(ax, 5.6, 4.4, 2.8, 1.2, "Logic tổ hợp\n(hàm trạng thái kế\nvà hàm đầu ra)", SERIES[0] + "22")
    reg = box(ax, 5.6, 1.7, 2.8, 0.9, "Thanh ghi trạng thái", "#ebeae6")
    out = box(ax, 9.0, 4.4, 1.5, 0.9, "Tín hiệu\nđiều khiển", SURFACE)
    arrow(ax, inp, log)
    arrow(ax, log, out)
    arrow(ax, (5.0, 3.8), (5.0, 2.15), "trạng thái kế", off=(-0.85, 0))
    arrow(ax, (6.2, 2.15), (6.2, 3.8), "trạng thái", off=(0.7, 0))

    ax = axs[1]
    ax.set_title("(b) Điều khiển vi chương trình", loc="left", color=INK, fontsize=10)
    upc = box(ax, 1.3, 2.0, 1.8, 0.8, "uPC", "#ebeae6")
    cs = box(ax, 4.4, 4.4, 2.8, 1.1, "Bộ nhớ điều khiển\n(vi chương trình)", SERIES[1] + "22")
    mir = box(ax, 8.2, 4.4, 2.2, 0.9, "Thanh ghi vi lệnh\nMIR", "#ebeae6")
    seq = box(ax, 4.9, 2.0, 2.8, 0.9, "Logic chọn địa chỉ\nkế tiếp", SERIES[1] + "22")
    out = box(ax, 8.6, 2.0, 1.6, 0.9, "Tín hiệu\nđiều khiển", SURFACE)
    arrow(ax, upc, cs, "địa chỉ", off=(-0.55, 0.05))
    arrow(ax, cs, mir)
    arrow(ax, mir, out)
    arrow(ax, mir, seq, "trường địa chỉ", off=(-0.75, 0.25))
    arrow(ax, seq, upc)
    ax.text(4.9, 0.95, "↑ đầu vào, cờ trạng thái", ha="center", color=INK2, fontsize=8)
    fig.tight_layout()
    fig.savefig(OUT / "fig_control.png", dpi=200)
    plt.close(fig)


def fig_cpu():
    """Datapath của mini_cpu (Chương 3)."""
    fig, ax = plt.subplots(figsize=(10.5, 4.7))
    ax.set_xlim(0, 13)
    ax.set_ylim(0, 7)
    ax.axis("off")
    hl, reg = SERIES[3] + "22", "#ebeae6"
    pc = box(ax, 1.2, 5.6, 1.5, 0.8, "PC", reg)
    im = box(ax, 3.9, 5.6, 2.2, 1.0, "IMEM\n256 × 16 bit", hl)
    ir = box(ax, 6.8, 5.6, 1.5, 0.8, "IR", reg)
    ctl = box(ax, 10.3, 5.6, 3.0, 1.1, "FSM FETCH/EXEC\n+ giải mã opcode", hl)
    rf = box(ax, 4.2, 2.9, 2.5, 1.3, "Tệp thanh ghi\nR0–R3", reg)
    alu = box(ax, 7.8, 2.9, 1.9, 1.3, "ALU 8 bit", hl)
    z = box(ax, 10.3, 3.7, 1.1, 0.7, "Z", reg)
    io = box(ax, 10.6, 1.6, 2.8, 1.0, "Bus vào/ra\n(IN, OUT)", SURFACE)
    arrow(ax, pc, im, "địa chỉ", off=(0, 0.25))
    arrow(ax, im, ir, "lệnh", off=(0, 0.25))
    arrow(ax, ir, ctl, "op", off=(0, 0.25))
    arrow(ax, (6.3, 5.2), (4.9, 3.6), "rd, rs", off=(0.5, -0.3))
    arrow(ax, (7.3, 5.2), (7.8, 3.6), "imm", off=(0.35, 0))
    arrow(ax, (5.45, 3.2), (6.85, 3.2), "a", off=(0, 0.2))
    arrow(ax, (5.45, 2.6), (6.85, 2.6), "b", off=(0, 0.2))
    arrow(ax, alu, z)
    arrow(ax, (10.3, 4.05), (10.3, 5.05), "cờ Z", off=(0.4, 0))
    arrow(ax, (7.3, 2.25), (3.6, 2.25), rad=-0.32)
    ax.text(3.9, 1.25, "kết quả ghi về rd", ha="center", color=INK2, fontsize=7.5)
    arrow(ax, (5.2, 2.25), (9.2, 1.3), "OUT (từ rs)", rad=0.42, off=(1.2, -1.0))
    arrow(ax, (9.2, 1.9), (8.4, 2.25), "IN", off=(-0.15, -0.3))
    ax.add_patch(FancyArrowPatch((8.85, 5.05), (1.2, 5.2), arrowstyle="-|>", mutation_scale=10, color=INK2, lw=1,
                                 connectionstyle="arc3,rad=-0.12", shrinkA=0, shrinkB=0, zorder=1, ls="--"))
    ax.text(3.0, 4.35, "PC mới khi nhảy (JMP, JZ, JNZ, CALL, RET)", ha="center", color=INK2, fontsize=7.5)
    fig.tight_layout()
    fig.savefig(OUT / "fig_cpu.png", dpi=200)
    plt.close(fig)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    OUT.mkdir(parents=True, exist_ok=True)
    vcd = read_vcd(ROOT / "sim" / "tb_tlc.vcd", {"l_fsm", "l_mic", "l_vmc", "l_cpu", "tick", "sensor", "night"})
    fig_timeline(vcd)
    fig_latency(vcd)
    fig_compare()
    fig_exp_ped()
    fig_state()
    fig_arch()
    fig_control()
    fig_cpu()
    for p in sorted(OUT.glob("fig_*.png")):
        print(p.relative_to(ROOT))


if __name__ == "__main__":
    main()
