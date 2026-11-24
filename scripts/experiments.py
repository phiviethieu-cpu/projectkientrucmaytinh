#!/usr/bin/env python3
"""Đo chi phí sửa đổi của 4 phương pháp qua 2 thí nghiệm.

  A. Đổi thời gian xanh EW từ 5 lên 7 tick (đổi tham số).
     Bản sửa được sinh tự động vào sim/exp_ewg7/ bằng các phép thay thế ghi
     trong EDITS_A, đúng những gì một người sửa tay phải làm.
  B. Thêm pha người đi bộ (thêm tính năng). Bản sửa nằm sẵn ở variants/ped/.

Với mỗi phương pháp: đếm số dòng thêm/xoá theo loại file, chạy testbench,
tổng hợp iCE40 để so sánh tài nguyên. Kết quả ghi vào synth/experiments.md.

Chạy từ thư mục gốc:  python scripts/experiments.py
"""
# difflib so hai phiên bản của một file
import difflib
import re
import shutil
import statistics
import subprocess
import sys
from pathlib import Path

# thư mục gốc và đường dẫn công cụ tổng hợp
ROOT = Path(__file__).resolve().parent.parent
YOSYS = shutil.which("yosys") or shutil.which("yowasp-yosys")
PNR = shutil.which("nextpnr-ice40") or shutil.which("yowasp-nextpnr-ice40")
# số lần đặt-đi dây để lấy Fmax trung bình
SEEDS = (1, 2, 3)
IGNORE = shutil.ignore_patterns("sim", "__pycache__")

# phương pháp -> (module top, các file thuộc phương pháp đó)
DESIGNS = {
    "FSM cứng":              ("tlc_fsm",    ["rtl/tlc_defs.vh", "rtl/tlc_fsm.v"]),
    "Vi chương trình ngang": ("tlc_micro",  ["rtl/tlc_micro.v", "rtl/microcode.mem"]),
    "Vi chương trình dọc":   ("tlc_vmicro", ["rtl/tlc_vmicro.v", "sw/traffic.uasm", "sw/uasm.py"]),
    "CPU mini":              ("tlc_cpu",    ["rtl/mini_cpu.v", "rtl/tlc_cpu.v", "sw/traffic.asm"]),
}
RTL = ["rtl/tlc_fsm.v", "rtl/tlc_micro.v", "rtl/tlc_vmicro.v", "rtl/mini_cpu.v", "rtl/tlc_cpu.v"]

# Thí nghiệm A: (file, chuỗi cũ, chuỗi mới)
EDITS_A = [
    ("rtl/tlc_defs.vh",   "`define T_EWG  4'd5", "`define T_EWG  4'd7"),
    ("rtl/microcode.mem", "   100001_0101_",      "   100001_0111_"),
    ("sw/traffic.uasm",   ".equ T_EWG, 5",        ".equ T_EWG, 7"),
    ("sw/traffic.asm",    ".equ T_EWG,   5",      ".equ T_EWG,   7"),
]


# phân loại file để biết dòng sửa thuộc phần nào
def kind(path):
    if path.endswith((".v", ".vh")):
        return "hw"
    if path.endswith(".py"):
        return "tool"
    return "mem"   # .mem, .asm, .uasm: nội dung bộ nhớ / phần mềm


def code_lines(path):
    """Các dòng mã của file, đã bỏ chú thích và khoảng trắng thừa."""
    if not path.exists():
        return []
    # dấu bắt đầu chú thích của từng loại file
    marks = {".py": "#", ".asm": ";", ".uasm": ";"}.get(path.suffix, "//")
    out, in_doc = [], False
    for line in path.read_text(encoding="utf-8").splitlines():
        if path.suffix == ".py" and line.count('"""') % 2 == 1:
            in_doc = not in_doc      # mở/đóng docstring nhiều dòng
            continue
        if in_doc or (path.suffix == ".py" and line.strip().startswith('"""')):
            continue
        # bỏ chú thích, gộp khoảng trắng
        code = " ".join(line.split(marks, 1)[0].split())
        if code:
            out.append(code)
    return out


def diff_count(a, b):
    """Số dòng mã (thêm, xoá) giữa 2 file, không tính chú thích và dòng trống."""
    add = rem = 0
    for line in difflib.unified_diff(code_lines(a), code_lines(b), lineterm="", n=0):
        # bỏ dòng tiêu đề của diff
        if line.startswith(("+++", "---", "@@")):
            continue
        if line.startswith("+"):
            add += 1
        elif line.startswith("-"):
            rem += 1
    return add, rem


# chạy một lệnh, lỗi thì in log rồi thoát
def run(cmd, cwd):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        sys.exit(f"lỗi khi chạy {' '.join(map(str, cmd))} trong {cwd}:\n{r.stdout}\n{r.stderr}")
    return r.stdout


def build_sw(work):
    """Dịch firmware và vi chương trình dọc trong thư mục work."""
    # -B: không sinh __pycache__ (OneDrive hay khoá thư mục này)
    run([sys.executable, "-B", "sw/asm.py", "sw/traffic.asm", "sw/traffic.hex"], work)
    run([sys.executable, "-B", "sw/uasm.py", "sw/traffic.uasm", "rtl/vmicrocode.mem"], work)


# biên dịch và chạy testbench trong thư mục work
def simulate(work, tb, rtl):
    (work / "sim").mkdir(exist_ok=True)
    run(["iverilog", "-g2005", "-I", "rtl", "-o", "sim/t.vvp", tb, *rtl], work)
    out = run(["vvp", "-n", "sim/t.vvp"], work)
    return "PASS" if ">>> PASS" in out else "FAIL"


def synth(work, top, rtl):
    """Trả về (LUT4, DFF, BRAM, Fmax trung bình)."""
    # bản yowasp (WebAssembly) chỉ thấy thư mục hiện hành -> dùng đường dẫn tương đối
    (work / "sim").mkdir(exist_ok=True)
    out_json = f"sim/{top}.json"
    run([YOSYS, "-q", "-p",
         f"read_verilog -I rtl {' '.join(rtl)}; synth_ice40 -top {top} -json {out_json}; "
         f"tee -o sim/{top}.stat stat"], work)
    log = (work / "sim" / f"{top}.stat").read_text(encoding="utf-8")
    # đếm cell trong file thống kê
    cnt = lambda name: sum(int(m) for m in re.findall(rf"(\d+)\s+{name}\b", log))
    lut, bram = cnt("SB_LUT4"), cnt("SB_RAM40_4K")
    # gộp mọi loại flip-flop SB_DFF*
    dff = sum(int(m) for m in re.findall(r"(\d+)\s+SB_DFF\w*", log))
    # mỗi seed cho một giá trị Fmax
    freqs = []
    for seed in SEEDS:
        subprocess.run([PNR, "--hx8k", "--package", "ct256", "--json", out_json, "--freq", "12",
                        "--seed", str(seed), "--log", "sim/pnr.log", "-q"], cwd=work, capture_output=True)
        plog = work / "sim" / "pnr.log"
        m = re.findall(r"([\d.]+) MHz \(PASS", plog.read_text(encoding="utf-8", errors="replace"))
        if m:
            freqs.append(float(m[-1]))
    return lut, dff, bram, (statistics.mean(freqs) if freqs else 0.0)


# cộng số dòng sửa theo phần cứng, bộ nhớ, công cụ
def changes(base_dir, new_dir, files):
    tot = {"hw": [0, 0], "mem": [0, 0], "tool": [0, 0]}
    for f in files:
        add, rem = diff_count(base_dir / f, new_dir / f)
        tot[kind(f)][0] += add
        tot[kind(f)][1] += rem
    return {k: f"+{v[0]}/−{v[1]}" if v != [0, 0] else "0" for k, v in tot.items()}


# thí nghiệm A: chép dự án, thay chuỗi, dịch lại và mô phỏng
def experiment_a():
    work = ROOT / "sim" / "exp_ewg7"
    shutil.rmtree(work, ignore_errors=True)
    for d in ("rtl", "sw", "tb"):
        shutil.copytree(ROOT / d, work / d, dirs_exist_ok=True, ignore=IGNORE)
    for f, old, new in EDITS_A:
        p = work / f
        s = p.read_text(encoding="utf-8")
        # chuỗi cũ phải xuất hiện đúng một lần
        assert s.count(old) == 1, (f, old)
        p.write_text(s.replace(old, new), encoding="utf-8")
    build_sw(work)
    rtl = RTL
    result = simulate(work, "tb/tb_tlc.v", rtl)
    return work, rtl, result


# thí nghiệm B: dùng bản có pha đi bộ làm sẵn
def experiment_b():
    # chép bản sửa vào thư mục làm việc, file nào bản sửa không có thì lấy từ bản gốc
    src = ROOT / "variants" / "ped"
    work = ROOT / "sim" / "exp_ped"
    shutil.rmtree(work, ignore_errors=True)
    shutil.copytree(src, work, dirs_exist_ok=True, ignore=IGNORE)
    for f in RTL + ["sw/asm.py"]:
        if not (work / f).exists():
            shutil.copy2(ROOT / f, work / f)
    build_sw(work)
    result = simulate(work, "tb/tb_ped.v", RTL)
    return work, RTL, result


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    # dịch lại phần mềm của bản gốc trước khi tổng hợp
    build_sw(ROOT)
    lines = []
    base = {}
    print("Tổng hợp bản gốc ...")
    for name, (top, _) in DESIGNS.items():
        base[name] = synth(ROOT, top, RTL)

    for title, fn in (("A. Đổi thời gian xanh EW 5 → 7 tick", experiment_a),
                      ("B. Thêm pha người đi bộ (nút nhấn + pha đỏ toàn phần 4 tick)", experiment_b)):
        print(f"Thí nghiệm {title} ...")
        work, rtl, result = fn()
        lines += [f"### {title}", "", f"Testbench sau khi sửa: **{result}**", "",
                  "| Phương pháp | Dòng mã sửa: phần cứng (.v) | Dòng mã sửa: bộ nhớ / phần mềm | Dòng mã sửa: công cụ | "
                  "LUT4 trước → sau | DFF trước → sau | Fmax MHz trước → sau |",
                  "|---|---|---|---|---|---|---|"]
        for name, (top, files) in DESIGNS.items():
            # số dòng sửa và tài nguyên sau khi sửa
            ch = changes(ROOT, work, files)
            lut, dff, bram, fmax = synth(work, top, rtl)
            b = base[name]
            lines.append(f"| {name} | {ch['hw']} | {ch['mem']} | {ch['tool']} | "
                         f"{b[0]} → {lut} | {b[1]} → {dff} | {b[3]:.0f} → {fmax:.0f} |")
        lines.append("")

    # ghi kết quả ra file và in ra màn hình
    out = "\n".join(lines)
    (ROOT / "synth").mkdir(exist_ok=True)
    (ROOT / "synth" / "experiments.md").write_text(out + "\n", encoding="utf-8")
    print(out)


if __name__ == "__main__":
    main()
