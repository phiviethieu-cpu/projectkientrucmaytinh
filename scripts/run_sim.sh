#!/usr/bin/env bash
# Dịch firmware/vi chương trình, chạy testbench CPU và testbench so sánh.
#   bash scripts/run_sim.sh            # chu kỳ tick mặc định 64 clock
#   bash scripts/run_sim.sh 40         # đổi chu kỳ tick
# Kết quả: sim/*.log, sóng sim/*.vcd (mở bằng gtkwave)
set -e
cd "$(dirname "$0")/.."
mkdir -p sim
python sw/asm.py  sw/traffic.asm  sw/traffic.hex
python sw/asm.py  sw/cpu_test.asm sw/cpu_test.hex
python sw/uasm.py sw/traffic.uasm rtl/vmicrocode.mem

echo "=== tb_mini_cpu: kiểm tra tập lệnh ==="
iverilog -g2005 -Wall -o sim/tb_mini_cpu.vvp tb/tb_mini_cpu.v rtl/mini_cpu.v
vvp -n sim/tb_mini_cpu.vvp > sim/tb_mini_cpu.log
sed -n '/Số lệnh/,/>>>/p' sim/tb_mini_cpu.log

echo "=== tb_tlc: so sánh 4 bộ điều khiển ==="
PARAM=""
[ -n "$1" ] && PARAM="-Ptb_tlc.TICK_DIV=$1"
iverilog -g2005 -Wall -I rtl $PARAM -o sim/tb_tlc.vvp \
    tb/tb_tlc.v rtl/tlc_fsm.v rtl/tlc_micro.v rtl/tlc_vmicro.v rtl/mini_cpu.v rtl/tlc_cpu.v
vvp -n sim/tb_tlc.vvp > sim/tb_tlc.log
sed -n '/KẾT QUẢ/,/>>>/p' sim/tb_tlc.log
