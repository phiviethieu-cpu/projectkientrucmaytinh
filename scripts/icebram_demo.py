#!/usr/bin/env python3
"""Thử nghiệm: cập nhật firmware CPU mini thẳng vào bitstream, không place & route lại.

Quy trình chuẩn của icestorm:
  1. Tổng hợp + place & route MỘT lần với nội dung ROM ngẫu nhiên (khuôn,
     sinh bằng `icebram -g`). Dữ liệu ngẫu nhiên giúp icebram tìm đúng vị trí
     của từng bit trong bitstream; firmware thật có nhiều từ lặp nên không dùng
     trực tiếp làm khuôn được.
  2. `icebram khuôn.hex firmware.hex` thay nội dung BRAM trong file .asc.
  3. Kiểm chứng: giải mã khối BRAM trong .asc, so với file hex.

Cần chạy scripts/experiments.py trước để có firmware sửa ở sim/exp_ewg7/.
Chạy từ thư mục gốc:  python scripts/icebram_demo.py
"""
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "sim" / "icebram"


def tool(name):
    return shutil.which(name) or shutil.which("yowasp-" + name)


def run(args, stdin=None, stdout=None):
    with open(WORK / stdin, "rb") if stdin else open(subprocess.os.devnull, "rb") as fi, \
         open(WORK / stdout, "wb") if stdout else open(subprocess.os.devnull, "wb") as fo:
        r = subprocess.run(args, cwd=WORK, stdin=fi, stdout=fo, stderr=subprocess.PIPE)
    if r.returncode != 0:
        sys.exit(f"lỗi: {' '.join(args)}\n{r.stderr.decode(errors='replace')}")


def bram_words(asc):
    """16 dòng .ram_data đầu tiên -> 256 từ 16 bit (thứ tự bit thô của iCE40)."""
    lines = (WORK / asc).read_text().splitlines()
    i = next(k for k, line in enumerate(lines) if line.startswith(".ram_data"))
    words = []
    for row in lines[i + 1:i + 17]:
        v = int(row, 16)
        words += [(v >> (16 * j)) & 0xFFFF for j in range(16)]
    return words


def hex_words(name):
    return [int(x, 16) for x in (WORK / name).read_text().split()]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    new_fw = ROOT / "sim" / "exp_ewg7" / "sw" / "traffic.hex"
    if not new_fw.exists():
        sys.exit("chưa có sim/exp_ewg7/sw/traffic.hex, hãy chạy scripts/experiments.py trước")
    shutil.rmtree(WORK, ignore_errors=True)
    (WORK / "sw").mkdir(parents=True, exist_ok=True)  # OneDrive có thể chưa nhả thư mục cũ
    for f in ("rtl/mini_cpu.v", "rtl/tlc_cpu.v", "rtl/tlc_defs.vh"):
        shutil.copy2(ROOT / f, WORK)
    shutil.copy2(ROOT / "sw" / "traffic.hex", WORK / "old.hex")
    shutil.copy2(new_fw, WORK / "new.hex")

    # 1. khuôn ngẫu nhiên -> tổng hợp, place & route một lần
    run([tool("icebram"), "-g", "16", "256"], stdout="template.hex")
    shutil.copy2(WORK / "template.hex", WORK / "sw" / "traffic.hex")
    run([tool("yosys"), "-q", "-p",
         "read_verilog -I . mini_cpu.v tlc_cpu.v; synth_ice40 -top tlc_cpu -json cpu.json"])
    run([tool("nextpnr-ice40"), "--hx8k", "--package", "ct256", "--json", "cpu.json",
         "--asc", "cpu_template.asc", "-q"])

    # 2. vá firmware
    for name in ("old", "new"):
        run([tool("icebram"), "template.hex", f"{name}.hex"],
            stdin="cpu_template.asc", stdout=f"cpu_{name}.asc")
        run([tool("icepack"), f"cpu_{name}.asc", f"cpu_{name}.bin"])

    # 3. kiểm chứng: suy hoán vị bit từ khuôn ngẫu nhiên rồi so nội dung BRAM
    tg, tw = bram_words("cpu_template.asc"), hex_words("template.hex")
    bit = lambda w, b: (w >> b) & 1
    perm = {}
    for b in range(16):
        cand = [a for a in range(16) if all(bit(tg[i], b) == bit(tw[i], a) for i in range(256))]
        if len(cand) != 1:
            sys.exit(f"không suy được hoán vị cho bit {b}: {cand}")
        perm[b] = cand[0]
    apply = lambda w: sum(bit(w, perm[b]) << b for b in range(16))
    print("Hoán vị bit dữ liệu BRAM iCE40 (bit trong bitstream <- bit dữ liệu):", perm)
    ok = True
    for name in ("old", "new"):
        match = [apply(w) for w in hex_words(f"{name}.hex")] == bram_words(f"cpu_{name}.asc")
        ok &= match
        print(f"cpu_{name}.asc: BRAM {'khớp' if match else 'KHÔNG khớp'} {name}.hex")
    a, b = (WORK / "cpu_old.bin").read_bytes(), (WORK / "cpu_new.bin").read_bytes()
    nd = sum(x != y for x, y in zip(a, b)) + abs(len(a) - len(b))
    print(f"Bitstream: {len(a)} byte, khác nhau {nd} byte (chỉ phần BRAM, không place & route lại)")
    print(">>> PASS" if ok else ">>> FAIL")


if __name__ == "__main__":
    main()
