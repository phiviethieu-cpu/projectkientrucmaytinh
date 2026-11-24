#!/usr/bin/env bash
# Tổng hợp 3 thiết kế bằng yosys, thu số liệu tài nguyên vào synth/
#   (1) cổng logic chung (AND/OR/XOR/MUX/NOT + DFF) và độ sâu logic dài nhất
#   (2) FPGA Lattice iCE40: số LUT4, flip-flop, block RAM
#   (3) place & route iCE40 HX8K với 5 seed -> tần số tối đa (Fmax)
# Chạy từ thư mục gốc dự án:  bash scripts/synth.sh
# Cần yosys + nextpnr-ice40, hoặc bản pip: yowasp-yosys, yowasp-nextpnr-ice40.
set -e
cd "$(dirname "$0")/.."
# ưu tiên bản cài sẵn, không có thì dùng bản pip
YOSYS=$(command -v yosys || command -v yowasp-yosys)
PNR=$(command -v nextpnr-ice40 || command -v yowasp-nextpnr-ice40)
SRC="rtl/tlc_fsm.v rtl/tlc_micro.v rtl/tlc_vmicro.v rtl/mini_cpu.v rtl/tlc_cpu.v"
mkdir -p synth

# lần lượt từng bộ điều khiển
for top in tlc_fsm tlc_micro tlc_vmicro tlc_cpu; do
    echo ">> $top"
    # (1) tổng hợp ra cổng logic chung, ltp đo đường tổ hợp dài nhất
    "$YOSYS" -q -l "synth/${top}_gates.log" -p "
        read_verilog -I rtl $SRC
        synth -top $top -flatten
        abc -g AND,NAND,OR,NOR,XOR,XNOR,MUX
        opt_clean
        tee -o synth/${top}_gates.stat stat
        tee -o synth/${top}_ltp.txt ltp -noff
    "
    # (2) tổng hợp cho iCE40
    "$YOSYS" -q -l "synth/${top}_ice40.log" -p "
        read_verilog -I rtl $SRC
        synth_ice40 -top $top -json synth/${top}.json
        tee -o synth/${top}_ice40.stat stat
    "
    # (3) đặt-đi dây với từng seed, mỗi dòng của file là một giá trị Fmax
    : > "synth/${top}_fmax.txt"
    for seed in 1 2 3 4 5; do
        "$PNR" --hx8k --package ct256 --json "synth/${top}.json" --freq 12 \
               --seed $seed --log synth/pnr.log -q > /dev/null 2>&1
        grep -oE "[0-9.]+ MHz \(PASS" synth/pnr.log | tail -1 | cut -d' ' -f1 >> "synth/${top}_fmax.txt"
    done
    rm -f synth/pnr.log
done
# in bảng tổng hợp
python scripts/summary.py | tee synth/summary.md
