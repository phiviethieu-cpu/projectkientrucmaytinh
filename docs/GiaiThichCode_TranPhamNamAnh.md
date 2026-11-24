# Giải thích code phần tổng hợp, đo đạc và thí nghiệm

Dành cho Trần Phạm Nam Anh. Mở file này bên trái, file code bên phải. Số dòng là số dòng thật của file.

| File | Là gì | Ngôn ngữ |
| --- | --- | --- |
| `rtl/top_board.v` | Module ngoài cùng để nạp lên kit: tạo tick 1 Hz, đồng bộ nút nhấn, chọn bộ điều khiển | Verilog |
| `scripts/synth.sh` | Tổng hợp và đặt-đi dây bốn bản | Bash |
| `scripts/summary.py` | Đọc kết quả của `synth.sh`, in bảng | Python |
| `scripts/experiments.py` | Thí nghiệm A và B | Python |
| `scripts/icebram_demo.py` | Vá firmware vào bitstream | Python |

`summary.py` không có tên trong bảng phân công, nhưng `synth.sh` gọi nó ở dòng cuối nên cũng cần đọc.

Luồng: `synth.sh` → Yosys, nextpnr → `synth/` → `summary.py` in bảng. `experiments.py` → `sim/exp_ewg7`, `sim/exp_ped` → `synth/experiments.md`. `icebram_demo.py` dùng firmware do `experiments.py` tạo ra.

# 1. Cách chạy

Mở PowerShell tại thư mục gốc dự án (VS Code: Terminal → New Terminal). Các lệnh sau đã được chạy thử trên máy của Hiếu và cho lại đúng số trong báo cáo.

| Thứ tự | Lệnh | Thời gian | Kết quả |
| --- | --- | --- | --- |
| 1 | `& "C:\Program Files\Git\bin\bash.exe" scripts/synth.sh` | khoảng 34 giây | Bảng tài nguyên, file trong `synth/` |
| 2 | `python scripts\experiments.py` | khoảng 60 giây | Bảng thí nghiệm A và B |
| 3 | `python scripts\icebram_demo.py` | khoảng 10 giây | `BRAM khớp`, `khác nhau 3 byte`, `PASS` |
| 4 | `iverilog -g2005 -Wall -I rtl -o sim\tb_top_board.vvp tb\tb_top_board.v rtl\top_board.v rtl\tlc_fsm.v rtl\tlc_micro.v rtl\tlc_vmicro.v rtl\mini_cpu.v rtl\tlc_cpu.v` | 1 giây | Biên dịch testbench của module top |
| 5 | `vvp -n sim\tb_top_board.vvp` | 1 giây | `Số tick: 105`, `PASS` |

- Lệnh 3 cần chạy lệnh 2 trước, vì dùng `sim\exp_ewg7\sw\traffic.hex`.
- Muốn in lại bảng mà không tổng hợp lại: `python scripts\summary.py`.
- **Đừng gõ `bash scripts/synth.sh` trong PowerShell.** Trên máy đã thử, `bash` ở đó là của WSL, không phải Git Bash. Phải gọi đúng đường dẫn như lệnh 1.
- Máy chưa có công cụ thì cài: `pip install yowasp-yosys yowasp-nextpnr-ice40 matplotlib`. Icarus Verilog cài riêng.

# 2. Kiến thức FPGA tối thiểu

| Từ | Nghĩa |
| --- | --- |
| FPGA | Chip chứa sẵn nhiều ô logic, cấu hình lại được thành mạch tuỳ ý |
| Tổng hợp | Đổi Verilog thành danh sách phần tử của chip |
| Đặt-đi dây | Chọn vị trí cho từng phần tử trên chip rồi nối chúng |
| Bitstream | File cấu hình nạp vào FPGA |
| LUT4 | Bảng tra 4 đầu vào, 16 ô; tạo được mọi hàm logic của 4 biến |
| FF (flip-flop) | Phần tử nhớ 1 bit |
| CARRY | Mạch truyền số nhớ của bộ cộng |
| BRAM | Khối nhớ 4096 bit. Firmware CPU 256×16 = 4096 bit, vừa đúng 1 BRAM |
| Đường găng | Đường tổ hợp chậm nhất giữa hai flip-flop |
| Fmax | Tần số clock cao nhất, bằng 1 / độ trễ đường găng |
| Seed | Số khởi tạo cho phần ngẫu nhiên của đặt-đi dây. Seed khác cho kết quả khác |
| iCE40 HX8K | Chip Lattice dùng để đo |

Vì sao cần nhiều seed: đặt-đi dây có yếu tố ngẫu nhiên. Năm giá trị Fmax thật của FSM là 137,29; 137,29; 127,94; 131,48; 130,63, trung bình 132,9 MHz.

# 3. Ký hiệu cần biết

## 3.1. Số và Verilog

### 3.1.1. Số hệ 2 và hệ 16

- **Bit** là một chữ số 0 hoặc 1. **Byte** là 8 bit.
- **Hệ 2** (binary): mỗi vị trí gấp đôi vị trí bên phải. `1010` = 8 + 0 + 2 + 0 = 10.
- **Hệ 16** (hex): dùng 0–9 rồi A–F. Một chữ số hex đúng bằng 4 bit, nên viết gọn hơn hệ 2.

| Hex | Hệ 2 | Hệ 10 | | Hex | Hệ 2 | Hệ 10 |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 0000 | 0 | | 8 | 1000 | 8 |
| 1 | 0001 | 1 | | 9 | 1001 | 9 |
| 2 | 0010 | 2 | | A | 1010 | 10 |
| 3 | 0011 | 3 | | B | 1011 | 11 |
| 4 | 0100 | 4 | | C | 1100 | 12 |
| 5 | 0101 | 5 | | D | 1101 | 13 |
| 6 | 0110 | 6 | | E | 1110 | 14 |
| 7 | 0111 | 7 | | F | 1111 | 15 |

Đổi hex sang hệ 10: `5A` = 5 × 16 + 10 = 90. Đổi hex sang hệ 2: thay từng chữ số, `5A` = `0101 1010`.

**Tràn:** 8 bit chỉ chứa 0 đến 255 (FF). `F0 + 20` = 240 + 32 = 272 = `110` hex, cần 9 bit; chỉ giữ 8 bit thấp nên còn `10`.

**Số âm (bù 2):** số −n trong 8 bit được ghi là 256 − n. Vậy −1 = 255 = `FF`, −2 = 254 = `FE`.

### 3.1.2. Phần cứng tối thiểu

| Từ | Nghĩa |
| --- | --- |
| Clock (`clk`) | Tín hiệu đổi 0, 1, 0, 1 đều đặn, giữ nhịp cho cả mạch |
| Cạnh lên | Lúc clock chuyển từ 0 sang 1 |
| Chu kỳ clock | Thời gian giữa hai cạnh lên liên tiếp |
| Thanh ghi | Phần tử nhớ, chỉ đổi giá trị ở cạnh lên của clock |
| Mạch tổ hợp | Không nhớ, đầu ra chỉ phụ thuộc đầu vào hiện tại |
| Mạch tuần tự | Có nhớ, cập nhật theo clock |
| MUX | Mạch chọn một trong nhiều đầu vào |
| Reset (`rst`) | Đưa mạch về trạng thái ban đầu |

### 3.1.3. Cách viết số trong Verilog

Mẫu: `số bit` `'` `hệ` `giá trị`.

| Viết | Đọc là |
| --- | --- |
| `8'h5A` | 8 bit, `h` là hệ 16, giá trị 5A |
| `4'h2` | 4 bit, hệ 16, giá trị 2 |
| `2'd1` | 2 bit, `d` là hệ 10, giá trị 1 |
| `1'b0` | 1 bit, `b` là hệ 2, giá trị 0 |
| `16'hFFFF` | 16 bit đều bằng 1 |
| `5000` | Không ghi gì: số nguyên hệ 10 |

### 3.1.4. Khung của file

| Ký hiệu | Nghĩa |
| --- | --- |
| `//` | Từ đây tới cuối dòng là chú thích, máy bỏ qua |
| `;` | Kết thúc một câu lệnh |
| `,` | Ngăn cách các phần tử trong danh sách |
| `(` `)` | Bao danh sách hoặc biểu thức |
| `begin` `end` | Gom nhiều câu lệnh thành một khối, giống `{ }` trong ngôn ngữ C |
| `` `timescale 1ns/1ps `` | Đơn vị thời gian khi mô phỏng là 1 ns, làm tròn tới 1 ps |
| `module` ... `endmodule` | Bắt đầu và kết thúc một khối mạch |
| `#( ... )` sau tên module | Danh sách tham số |
| `parameter` | Hằng số có thể đổi khi dùng module |
| `localparam` | Hằng số không đổi được từ bên ngoài |
| `input` / `output` | Chân vào / chân ra |

### 3.1.5. Dây, biến, chỉ số

| Ký hiệu | Nghĩa |
| --- | --- |
| `wire` | Dây nối, không nhớ giá trị |
| `reg` | Biến được gán trong `always` hoặc `initial`. Là thanh ghi thật chỉ khi nằm trong khối có `posedge clk` |
| `integer` | Số nguyên, dùng trong testbench |
| `[7:0]` trước tên | Tín hiệu 8 bit, bit 7 là bit cao nhất |
| `ir[15:12]` | Lấy 4 bit, từ bit 15 xuống bit 12 |
| `reg [15:0] imem [0:255]` | `[15:0]` trước tên: mỗi ô 16 bit. `[0:255]` sau tên: có 256 ô |
| `imem[pc]` | Ô thứ `pc` của bộ nhớ |

### 3.1.6. Phép tính và so sánh

| Ký hiệu | Nghĩa | Ví dụ |
| --- | --- | --- |
| `+` `-` | Cộng, trừ | `8'hF0 + 8'h20` giữ 8 bit được `10` |
| `*` `/` `%` | Nhân, chia lấy nguyên, chia lấy dư | `148 / 74` = 2 |
| `&` | AND từng bit: cả hai là 1 mới ra 1 | `CC & AA` = `88` |
| `\|` | OR từng bit: một trong hai là 1 thì ra 1 | `0F \| 30` = `3F` |
| `~` | Đảo từng bit | `~clk` đổi 0 thành 1 và ngược lại |
| `&&` | VÀ logic, dùng cho điều kiện | `a && b` đúng khi cả hai đúng |
| `\|\|` | HOẶC logic, dùng cho điều kiện | `a \|\| b` đúng khi ít nhất một vế đúng |
| `!` | PHỦ ĐỊNH logic | `!z` đúng khi z = 0 |
| `==` | So sánh bằng | `op == OP_OUT` |
| `!=` | So sánh khác | |
| `!==` | Khác, so cả hai giá trị đặc biệt X (chưa xác định) và Z (hở mạch) | dùng trong testbench |
| `<` `>=` | Nhỏ hơn, lớn hơn hoặc bằng | |
| `a ? b : c` | Nếu a đúng thì lấy b, sai thì lấy c | `(z) ? 1 : 0` |

Chú ý hai cặp dễ nhầm:
- `=` là **gán**, `==` là **so sánh**.
- `<=` trong câu lệnh là **gán**, không phải "nhỏ hơn hoặc bằng".

### 3.1.7. Hai phép gán

| Ký hiệu | Tên | Cách chạy | Dùng ở |
| --- | --- | --- | --- |
| `=` | Gán chặn | Dòng trên xong mới tới dòng dưới | Mạch tổ hợp |
| `<=` | Gán không chặn | Đọc hết vế phải trước, rồi mọi vế trái đổi cùng lúc ở cạnh clock | Thanh ghi |

Ví dụ PC đang là 02:

```
ir <= imem[pc];     // đọc ô 02
pc <= pc + 8'd1;    // tính 02 + 1
```

Cả hai dòng đều đọc PC = 02. Sau cạnh clock: IR giữ lệnh ở ô 02, PC bằng 03.

### 3.1.8. Các khối

| Ký hiệu | Nghĩa |
| --- | --- |
| `assign x = ...;` | Nối dây: x luôn bằng biểu thức bên phải |
| `initial` | Chạy một lần khi bắt đầu |
| `always @*` | Mạch tổ hợp. `@` là "mỗi khi có", `*` là "bất kỳ đầu vào nào đổi" |
| `always @(posedge clk)` | Mạch tuần tự. `posedge` là cạnh lên |
| `if (đk) ... else ...` | Nếu đúng thì làm vế đầu, sai thì làm vế sau |
| `case (x) ... endcase` | Xét x, chạy nhánh có giá trị khớp |
| `2'd0: r0 <= alu;` | Một nhánh: nếu x bằng 0 thì làm câu lệnh sau dấu `:` |
| `default` | Nhánh dùng khi không nhánh nào khớp |

Thêm cho `top_board.v`:

| Ký hiệu | Nghĩa |
| --- | --- |
| `50_000_000` | Số 50000000, dấu `_` chỉ để dễ đọc |
| `{a, b}` | Ghép các bit: a ở bên trái, b ở bên phải |
| `$clog2(n)` | Số bit cần để đánh số n giá trị. `$clog2(50000000)` = 26 |
| `[W-1:0]` | Độ rộng tính theo hằng số W |
| `generate` ... `endgenerate` | Tạo mạch theo điều kiện, quyết định lúc biên dịch |
| `begin : g_fsm` | Đặt tên cho khối |
| `.overrun()` | Chân để hở, không nối |

## 3.2. Bash (file `.sh`)

| Ký hiệu | Nghĩa |
| --- | --- |
| `#` | Chú thích |
| `#!/usr/bin/env bash` | Dòng đầu: chạy file này bằng bash |
| `A="..."` | Gán biến, không có dấu cách quanh `=` |
| `$A`, `${A}` | Lấy giá trị biến |
| `$(lệnh)` | Lấy kết quả in ra của lệnh |
| `a \|\| b` | Chạy a, nếu a lỗi thì chạy b |
| `for x in ...; do ... done` | Lặp x qua từng giá trị |
| `\` ở cuối dòng | Lệnh còn tiếp ở dòng sau |
| `>` | Ghi kết quả ra file, xoá nội dung cũ |
| `>>` | Ghi nối vào cuối file |
| `2>&1` | Gộp thông báo lỗi vào kết quả thường |
| `/dev/null` | Nơi bỏ đi |
| `\|` | Đưa kết quả lệnh trái vào lệnh phải |
| `: > file` | Tạo file rỗng |

## 3.3. Python

| Ký hiệu | Nghĩa |
| --- | --- |
| `#` | Chú thích |
| `"""..."""` | Đoạn mô tả nhiều dòng |
| `import x` | Dùng thư viện x |
| `def f(a):` | Định nghĩa hàm f có tham số a. Phần thụt vào là thân hàm |
| `return x` | Trả kết quả |
| `=` / `==` | Gán / so sánh bằng |
| `[1, 2]` | Danh sách |
| `(1, 2)` | Bộ giá trị, không sửa được |
| `{"a": 1}` | Từ điển: tra theo khoá |
| `for x in ds:` | Lặp qua từng phần tử |
| `[f(x) for x in ds]` | Tạo danh sách mới bằng cách áp f cho từng phần tử |
| `lambda w: ...` | Hàm viết gọn trên một dòng |
| `f"...{x}..."` | Chuỗi có chèn giá trị x |
| `{x:.0f}` / `{x:.1f}` | In số với 0 / 1 chữ số thập phân |
| `r"..."` | Chuỗi giữ nguyên dấu `\`, hay dùng cho mẫu tìm kiếm |
| `\d+` / `\s+` trong mẫu | Một hay nhiều chữ số / khoảng trắng |
| `ROOT / "synth"` | Nối đường dẫn |
| `a += 1` | Cộng 1 vào a |
| `x >> n` / `x << n` | Dịch x sang phải / trái n bit |
| `x & 1` | Lấy bit thấp nhất của x |
| `assert đk` | Dừng nếu điều kiện sai |
| `if __name__ == "__main__":` | Chỉ chạy khi file được gọi trực tiếp |

# 4. File `rtl/top_board.v`

Nhiệm vụ: bọc quanh bộ điều khiển để nó chạy được trên kit thật.

| Dòng | Giải thích |
| --- | --- |
| 9 | Đơn vị thời gian mô phỏng |
| 11 | Module có tham số |
| 12 | `CLK_HZ`: clock của kit có bao nhiêu chu kỳ mỗi giây |
| 13 | `IMPL`: chọn bộ điều khiển 0 FSM, 1 ngang, 2 dọc, 3 CPU |
| 14 | `RST_ACTIVE_LOW`: bằng 1 nếu nút reset của kit cho mức thấp khi nhấn |
| 16–20 | Chân: clock, nút reset, hai công tắc, 6 LED |
| 24 | Mỗi đầu vào có hai flip-flop. `s_rst = 2'b11` nghĩa là vừa nạp xong mạch tự ở trạng thái reset |
| 25 | Nếu nút mức thấp thì đảo lại, để bên trong luôn dùng reset mức cao |
| 26 | Mỗi cạnh lên của clock |
| 27 | `{s_rst[0], rst_in}`: bit cũ thứ 0 chuyển lên bit 1, giá trị mới vào bit 0. Tín hiệu đi qua hai flip-flop |
| 28–29 | Làm như vậy cho hai công tắc |
| 31 | Dùng bit 1, tức là tín hiệu đã qua hai tầng |
| 34 | Số bit của bộ đếm. Với 50 MHz là 26 bit |
| 35 | Bộ đếm chu kỳ clock |
| 36 | Xung tick |
| 37–40 | Đang reset: xoá bộ đếm và tick |
| 41 | Đếm đủ một giây (từ 0 tới `CLK_HZ - 1`) |
| 42–43 | Đếm lại từ 0, tick = 1 |
| 44–46 | Chưa đủ: đếm thêm 1, tick = 0. Vì vậy tick chỉ rộng một chu kỳ |
| 51 | Chọn mạch lúc tổng hợp, chỉ một nhánh tồn tại trên chip |
| 52–53 | IMPL = 0: đặt một FSM tên `u`, nối chân |
| 54–57 | IMPL = 1, 2: hai bản vi chương trình |
| 58–60 | IMPL = 3: bản CPU, chân `overrun` để hở |

**Vì sao cần hai flip-flop?** Nút nhấn đổi lúc bất kỳ, có thể trùng cạnh clock. Khi đó flip-flop có thể rơi vào trạng thái bất ổn (metastability) trong chốc lát. Flip-flop thứ hai cho nó thêm một chu kỳ để ổn định trước khi dùng.

# 5. File `scripts/synth.sh`

| Dòng | Giải thích |
| --- | --- |
| 1 | Chạy bằng bash |
| 2 | Chú thích ghi "3 thiết kế" là chữ cũ; thật ra có 4, xem dòng 17 |
| 8 | Có lệnh lỗi thì dừng ngay |
| 9 | Chuyển về thư mục gốc. `$0` là đường dẫn file này, `dirname` lấy thư mục chứa nó |
| 11–12 | Tìm yosys và nextpnr; không có thì dùng bản cài bằng pip |
| 13 | Danh sách file Verilog |
| 14 | Tạo thư mục kết quả |
| 17 | Lặp qua bốn module top |
| 18 | In tên đang làm |
| 20 | Gọi Yosys: `-q` im lặng, `-l` ghi log, `-p` chạy các lệnh trong ngoặc kép |
| 21 | Đọc Verilog, `-I rtl` là chỗ tìm file `.vh` |
| 22 | Tổng hợp chung, `-flatten` gộp mọi module con thành một |
| 23 | Chỉ dùng các loại cổng liệt kê |
| 24 | Bỏ dây và cổng thừa |
| 25 | `stat` đếm phần tử, `tee -o` ghi ra file |
| 26 | `ltp` tìm đường dài nhất, `-noff` không tính flip-flop, tức là chỉ tính phần tổ hợp |
| 29–33 | Tổng hợp cho iCE40, ghi mạng phần tử ra file json cho nextpnr |
| 35 | Tạo file rỗng để ghi Fmax |
| 36 | Năm seed |
| 37 | `--hx8k` chip, `--package ct256` kiểu vỏ, `--freq 12` tần số mục tiêu 12 MHz |
| 38 | `--seed` hạt giống, `--log` file log |
| 39 | Tìm dòng có `MHz (PASS`, `tail -1` lấy dòng cuối (sau khi đi dây xong), `cut` lấy con số, ghi nối vào file |
| 41 | Xoá log tạm |
| 44 | In bảng và lưu vào `synth/summary.md` |

# 6. File `scripts/summary.py`

| Dòng | Giải thích |
| --- | --- |
| 8 | Thư mục `synth` |
| 10–11 | Tên module và nhãn hiển thị |
| 14–22 | Hàm `cells`: đọc file thống kê, trả về từ điển tên phần tử → số lượng |
| 19 | Mẫu: khoảng trắng, số, khoảng trắng, tên bắt đầu `$_` hoặc `SB_` |
| 21 | Cộng dồn; `get(..., 0)` nghĩa là chưa có thì coi là 0 |
| 26–28 | Hàm `depth`: lấy số sau `length=` |
| 31–39 | Hàm `fmax`: trung bình, nhỏ nhất, lớn nhất |
| 45 | Lặp qua bốn thiết kế |
| 47–48 | Đọc thống kê của hai lần tổng hợp |
| 50 | Cộng các phần tử có chữ DFF, đó là flip-flop |
| 53 | Cổng = tổng trừ flip-flop |
| 57 | iCE40 có nhiều loại flip-flop, cộng tất cả loại bắt đầu `SB_DFF` |
| 63–68 | In bảng dạng Markdown |

# 7. File `scripts/experiments.py`

## 7.1. Phần khai báo

| Dòng | Giải thích |
| --- | --- |
| 15–21 | Thư viện: `difflib` so file, `re` tìm mẫu, `shutil` chép file, `subprocess` chạy lệnh |
| 24 | Thư mục gốc, là thư mục cha của `scripts` |
| 25–26 | Đường dẫn công cụ |
| 28 | Ba seed. Ít hơn bảng chính (5) nên Fmax hơi khác: FSM 134 so với 132,9 |
| 32–37 | Mỗi phương pháp: module top và các file thuộc về nó, dùng để đếm dòng sửa |
| 38 | File RTL để biên dịch |
| 41–46 | Thí nghiệm A: file nào, chuỗi cũ, chuỗi mới. Ở `microcode.mem`, `0101` là 5 và `0111` là 7 |

## 7.2. Đếm dòng sửa

| Dòng | Giải thích |
| --- | --- |
| 50–55 | Phân loại: `.v`, `.vh` là phần cứng; `.py` là công cụ; còn lại là bộ nhớ hoặc phần mềm |
| 58–75 | Lấy các dòng mã, đã bỏ chú thích |
| 63 | Dấu chú thích theo loại file: `#` cho Python, `;` cho hợp ngữ, `//` cho Verilog |
| 66–70 | Bỏ đoạn mô tả `"""` của Python |
| 72 | Cắt phần sau dấu chú thích, gộp khoảng trắng |
| 78–89 | So hai file. Dòng bắt đầu `+` là thêm, `-` là xoá |
| 83 | Bỏ ba loại dòng tiêu đề |
| 142–148 | Cộng theo từng loại, in dạng `+25/−13` |

## 7.3. Chạy công cụ

| Dòng | Giải thích |
| --- | --- |
| 93–97 | Chạy lệnh; mã trả về khác 0 thì in lỗi và thoát |
| 100–104 | Dịch firmware và vi chương trình dọc |
| 108–112 | Biên dịch và chạy testbench, tìm chữ `>>> PASS` |
| 115–138 | Tổng hợp iCE40, trả về LUT, FF, BRAM, Fmax |
| 121–122 | Chuỗi lệnh đưa cho Yosys |
| 125 | Đếm phần tử theo tên |
| 128 | Đếm mọi loại `SB_DFF...` |
| 131–137 | Ba lần đặt-đi dây, lấy Fmax cuối trong log |
| 138 | Trung bình |

## 7.4. Hai thí nghiệm

| Dòng | Giải thích |
| --- | --- |
| 153–156 | Xoá thư mục cũ, chép `rtl`, `sw`, `tb` sang `sim/exp_ewg7` |
| 157–162 | Thay chuỗi trong từng file |
| 161 | Chuỗi cũ phải có **đúng một lần**, để không thay nhầm chỗ |
| 163–166 | Dịch lại, mô phỏng |
| 172–175 | Thí nghiệm B: chép `variants/ped` sang `sim/exp_ped` |
| 176–178 | File nào bản đi bộ không có thì lấy từ bản gốc. `variants/ped` không có `mini_cpu.v`, nên lõi CPU dùng nguyên bản |
| 180 | Chạy `tb_ped.v` |
| 190–192 | Tổng hợp bản gốc để có số "trước" |
| 194–209 | Với mỗi thí nghiệm: sửa, đếm dòng, tổng hợp, ghép thành hàng của bảng |
| 214 | Ghi `synth/experiments.md` |

# 8. File `scripts/icebram_demo.py`

## 8.1. Ý tưởng

Bitstream chứa cả mạch lẫn nội dung BRAM. Muốn đổi firmware, chỉ cần tìm đúng chỗ của BRAM trong bitstream rồi thay.

- **Khuôn ngẫu nhiên:** nạp ROM bằng số ngẫu nhiên, mỗi bit có một "dấu vết" riêng nên tìm được vị trí. Firmware thật có nhiều từ lặp (ô trống đều là `F000`), không phân biệt được.
- **Hoán vị bit:** bit trong BRAM của iCE40 bị xếp lại thứ tự. Script tìm thứ tự này từ khuôn rồi mới so.

## 8.2. Từng dòng

| Dòng | Giải thích |
| --- | --- |
| 22 | Thư mục làm việc |
| 26–27 | Tìm công cụ, không có thì thêm tiền tố `yowasp-` |
| 31–36 | Chạy lệnh; `stdin`, `stdout` cho phép đọc vào và ghi ra file |
| 39–49 | Đọc khối `.ram_data` đầu tiên, 16 dòng, mỗi dòng 256 bit = 16 từ 16 bit |
| 48 | Tách từng từ: dịch phải rồi giữ 16 bit thấp |
| 53–54 | Đọc file hex thành danh sách số |
| 60–62 | Firmware mới lấy từ thí nghiệm A; chưa có thì báo lỗi |
| 63–68 | Xoá, tạo lại thư mục, chép file. `old.hex` là firmware gốc, `new.hex` là firmware EWG = 7 |
| 71 | `icebram -g 16 256`: sinh 256 từ 16 bit ngẫu nhiên |
| 72 | Dùng nó làm nội dung ROM |
| 73–76 | Tổng hợp và đặt-đi dây **một lần duy nhất** |
| 79–82 | Với mỗi firmware: icebram thay khuôn bằng firmware, icepack đóng gói ra `.bin` |
| 85 | Nội dung BRAM trong bitstream và trong file khuôn |
| 87 | Lấy bit thứ b |
| 89–94 | Với mỗi bit b của bitstream, tìm bit dữ liệu a trùng ở cả 256 từ. Phải có đúng một |
| 96 | Xếp lại bit của một từ |
| 99–103 | So BRAM sau khi vá với file hex |
| 104–106 | Đếm byte khác nhau giữa hai bitstream |
| 108 | In PASS nếu cả hai khớp |

## 8.3. Vì sao khác đúng 3 byte

Đã kiểm tra trực tiếp hai file `.bin`:

| Vị trí byte | Cũ | Mới | Là gì |
| --- | --- | --- | --- |
| 119017 | `00` | `01` | Nội dung BRAM |
| 135095 | `cd` | `61` | Hai byte gần cuối file, nhiều khả năng là mã kiểm tra (CRC) |
| 135096 | `99` | `9b` | như trên |

Firmware chỉ khác một từ: địa chỉ `16`, từ `1405` (`LDI R1, 5`) thành `1407` (`LDI R1, 7`). Số 5 là `0101`, số 7 là `0111`: khác đúng một bit, nên dữ liệu đổi một byte.

# 9. Câu hỏi có thể gặp

| Câu hỏi | Trả lời |
| --- | --- |
| Vì sao chọn iCE40? | Có bộ công cụ mã nguồn mở đầy đủ, chạy bằng script được |
| Đã nạp chip thật chưa? | Chưa. Số liệu lấy từ tổng hợp và phân tích thời gian của nextpnr |
| Vì sao bảng chính 5 seed, thí nghiệm 3 seed? | Thí nghiệm phải tổng hợp 12 lần nên giảm seed cho nhanh. Vì vậy FSM là 132,9 ở bảng chính và 134 ở thí nghiệm |
| `--freq 12` có giới hạn Fmax không? | Không. Đó là tần số mục tiêu để báo PASS; nextpnr vẫn báo tần số cao nhất tính được |
| Vì sao flip-flop của CPU là 67 ở lần tổng hợp chung nhưng 54 trên iCE40? | Nguyên nhân chính: trên iCE40, 16 bit của thanh ghi IR được gộp vào đầu ra của BRAM (log Yosys ghi `merging output FF to cell`) nên không tính là flip-flop riêng. Phần chênh còn lại do hai lần tổng hợp tối ưu khác nhau, nhóm chưa phân tích chi tiết |
| Vì sao hai bản vi chương trình không vá được? | ROM của chúng đọc bất đồng bộ nên nằm trong LUT, không nằm trong BRAM |
| Sao không đo công suất? | Bộ công cụ mã nguồn mở cho iCE40 không có mô hình công suất |
| Đếm dòng có công bằng không? | Cùng một cách đếm cho cả bốn bản, bỏ chú thích và dòng trống. Nhưng số dòng chỉ là thước đo gần đúng của công sức |
| Thí nghiệm B có chứng minh lõi CPU không đổi? | Có. `variants/ped` không có `mini_cpu.v`, script dùng nguyên bản gốc |

**Điểm yếu nên biết trước:**
- Dòng 132–137 của `experiments.py` không kiểm tra nextpnr có chạy lỗi không. Nếu lỗi, script có thể đọc log của lần trước.
- `icebram_demo.py` chỉ kiểm tra nội dung BRAM trong file, chưa nạp lên chip thật.
- Chú thích đầu `synth.sh` ghi 3 thiết kế, thật ra là 4.

# 10. Tự kiểm tra

Che cột đáp án, trả lời thành tiếng.

| Câu hỏi | Đáp án |
| --- | --- |
| Tick rộng mấy chu kỳ? Dòng nào quyết định? | Một chu kỳ; dòng 43 và 46 của `top_board.v` |
| Vì sao cần hai flip-flop ở đầu vào? | Tránh bất ổn khi nút nhấn đổi trùng cạnh clock |
| Yosys và nextpnr khác nhau thế nào? | Yosys đổi Verilog thành phần tử; nextpnr đặt, nối dây và tính Fmax |
| Dòng nào của `synth.sh` chọn số seed? | Dòng 36 |
| `assert s.count(old) == 1` để làm gì? | Bảo đảm chuỗi cần thay có đúng một lần |
| Vì sao cần ROM ngẫu nhiên? | Để icebram tìm được vị trí từng bit |
| Hai bitstream khác mấy byte, vì sao? | 3 byte: 1 byte dữ liệu BRAM, 2 byte gần cuối file |
