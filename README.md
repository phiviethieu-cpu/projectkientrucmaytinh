# Bộ điều khiển đèn giao thông: FSM cứng, vi chương trình và CPU mini

Project cuối kỳ môn Kiến trúc máy tính. Cùng một bộ điều khiển đèn giao thông được viết bằng Verilog theo 4 cách: FSM cứng, vi chương trình ngang, vi chương trình dọc, và một CPU 8 bit 16 lệnh chạy firmware. Testbench kiểm tra rằng bốn bản cho cùng một chuỗi đèn; sau đó chúng được tổng hợp cho FPGA iCE40 để so tài nguyên, tốc độ và số dòng mã phải sửa khi đổi yêu cầu.

Báo cáo nộp là file PDF biên dịch từ mẫu LaTeX trong `GraduationThesisTemplate-main - Copy/GraduationThesisTemplate-main/` (lệnh `latexmk main.tex` trong thư mục đó). [docs/BaoCao.md](docs/BaoCao.md) là bản Markdown sinh từ cùng nguồn bằng `scripts/tex2md.py`.

## Chạy lại

```bash
bash scripts/run_sim.sh            # testbench CPU + so sánh 4 bộ điều khiển (Windows: scripts\run_sim.bat)
bash scripts/synth.sh              # tổng hợp + đặt-đi dây cho iCE40
python scripts/experiments.py      # thí nghiệm đổi tham số và thêm pha đi bộ
python scripts/icebram_demo.py     # vá firmware CPU vào bitstream, không đặt-đi dây lại
python scripts/make_figures.py     # vẽ lại hình trong docs/figures/
python scripts/tex2md.py           # sinh lại docs/BaoCao.md từ báo cáo LaTeX
```

Cần Icarus Verilog, Python 3 có matplotlib, và `pip install yowasp-yosys yowasp-nextpnr-ice40`. Biên dịch báo cáo cần MiKTeX hoặc TeX Live có gói vntex.

## Kết quả đo

| Phương pháp | iCE40 LUT4 | DFF | Fmax (MHz) | Độ trễ tick→đèn | Dòng mã sửa để thêm pha đi bộ |
| --- | --- | --- | --- | --- | --- |
| FSM cứng | 21 | 7 | ~133 | 1 chu kỳ | 38, toàn bộ là RTL |
| Vi chương trình ngang | 38 | 22 | ~126 | 1 chu kỳ | 65, phải đổi định dạng vi lệnh |
| Vi chương trình dọc | 83 | 27 | ~118 | ≤ 5 chu kỳ | 50 |
| CPU mini | 208 (+1 BRAM) | 54 | ~86 | ≤ 30 chu kỳ | 21, lõi CPU không đổi |

Fmax là trung bình 5 lần đặt-đi dây và dao động khoảng ±10% giữa các lần chạy. Testbench `tb_tlc` chạy 360 tick: 0 lệch giữa bốn bản, 0 vi phạm an toàn. `tb_mini_cpu` chạy đủ 16 opcode với CPI = 2. Chín lỗi cố ý cài vào thiết kế đều bị các testbench bắt.

## Nạp lên kit

Thư mục `boards/` có file top và file gán chân cho Basys 3 (`basys3_top.v`, `basys3.xdc`) và DE10-Lite (`de10_lite_top.v`, `de10_lite.qsf`). Bốn bản chạy song song trên chip; công tắc `SW[3:2]` chọn bản nào được nối ra LED. Phần này chưa được thử trên kit thật, nên cần đối chiếu số chân với tài liệu của kit trước khi nạp.
