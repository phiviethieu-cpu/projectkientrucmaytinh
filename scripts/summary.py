#!/usr/bin/env python3
"""Đọc kết quả yosys trong synth/ và in bảng so sánh tài nguyên (Markdown)."""
import re
import sys
from pathlib import Path

# thư mục chứa log của yosys và nextpnr
SYNTH = Path(__file__).resolve().parent.parent / "synth"
# tên module top và nhãn trong bảng
DESIGNS = [("tlc_fsm", "FSM cứng"), ("tlc_micro", "Vi chương trình ngang"),
           ("tlc_vmicro", "Vi chương trình dọc"), ("tlc_cpu", "CPU mini")]


def cells(path):
    """Trả về {tên cell: số lượng} trong file stat của yosys."""
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        # dòng có dạng "<số lượng> <tên cell>"
        m = re.match(r"\s+(\d+)\s+(\$_\w+_|SB_\w+)\s*$", line)
        if m:
            out[m.group(2)] = out.get(m.group(2), 0) + int(m.group(1))
    return out


# số cổng trên đường tổ hợp dài nhất, lấy từ lệnh ltp
def depth(path):
    m = re.search(r"length=(\d+)", path.read_text(encoding="utf-8"))
    return int(m.group(1)) if m else 0


def fmax(path):
    """Fmax trung bình, nhỏ nhất, lớn nhất qua các seed place & route."""
    if not path.exists():
        return "-"
    # mỗi dòng là Fmax của một seed
    vals = [float(x) for x in path.read_text().split()]
    if not vals:
        return "-"
    return f"{sum(vals) / len(vals):.1f} ({min(vals):.0f}–{max(vals):.0f})"


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    rows = []
    for top, label in DESIGNS:
        # g: tổng hợp cổng logic chung, f: tổng hợp cho iCE40
        g = cells(SYNTH / f"{top}_gates.stat")
        f = cells(SYNTH / f"{top}_ice40.stat")
        # flip-flop đếm riêng, phần còn lại là cổng
        ff_g = sum(v for k, v in g.items() if "DFF" in k)
        rows.append([
            label,
            sum(g.values()) - ff_g,
            ff_g,
            depth(SYNTH / f"{top}_ltp.txt"),
            f.get("SB_LUT4", 0),
            sum(v for k, v in f.items() if k.startswith("SB_DFF")),
            f.get("SB_CARRY", 0),
            f.get("SB_RAM40_4K", 0),
            fmax(SYNTH / f"{top}_fmax.txt"),
        ])
    # in bảng Markdown
    head = ["Phương pháp", "Cổng logic", "Flip-flop", "Độ sâu logic",
            "iCE40 LUT4", "iCE40 DFF", "iCE40 CARRY", "iCE40 BRAM", "Fmax MHz (min–max)"]
    print("| " + " | ".join(head) + " |")
    print("|" + "|".join("---" for _ in head) + "|")
    for r in rows:
        print("| " + " | ".join(str(x) for x in r) + " |")


if __name__ == "__main__":
    main()
