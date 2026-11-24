@echo off
rem Chạy mô phỏng trên Windows (cmd/PowerShell). Chạy từ thư mục gốc dự án.
rem   scripts\run_sim.bat        hoặc   scripts\run_sim.bat 40
chcp 65001 >nul
rem chuyển về thư mục gốc dự án
cd /d "%~dp0.."
if not exist sim mkdir sim
rem dịch firmware, chương trình thử CPU và vi chương trình dọc
python sw\asm.py  sw\traffic.asm  sw\traffic.hex     || exit /b 1
python sw\asm.py  sw\cpu_test.asm sw\cpu_test.hex    || exit /b 1
python sw\uasm.py sw\traffic.uasm rtl\vmicrocode.mem || exit /b 1

echo === tb_mini_cpu: kiem tra tap lenh ===
rem biên dịch và chạy testbench của CPU
iverilog -g2005 -Wall -o sim\tb_mini_cpu.vvp tb\tb_mini_cpu.v rtl\mini_cpu.v || exit /b 1
vvp -n sim\tb_mini_cpu.vvp > sim\tb_mini_cpu.log
findstr /C:">>>" sim\tb_mini_cpu.log

echo === tb_tlc: so sanh 4 bo dieu khien ===
rem tham số dòng lệnh (nếu có) đổi khoảng cách giữa hai tick
set PARAM=
if not "%1"=="" set PARAM=-Ptb_tlc.TICK_DIV=%1
iverilog -g2005 -Wall -I rtl %PARAM% -o sim\tb_tlc.vvp tb\tb_tlc.v rtl\tlc_fsm.v rtl\tlc_micro.v rtl\tlc_vmicro.v rtl\mini_cpu.v rtl\tlc_cpu.v || exit /b 1
rem chạy mô phỏng, log ghi ra file rồi in lại
vvp -n sim\tb_tlc.vvp > sim\tb_tlc.log
type sim\tb_tlc.log
