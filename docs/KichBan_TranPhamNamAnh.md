# Kịch bản thuyết trình: Tổng hợp FPGA, đo đạc và thí nghiệm

- **Người trình bày:** Trần Phạm Nam Anh
- **Slide:** trang in 31–38
- **Thời lượng:** khoảng 8 phút (ước lượng, cần bấm giờ lại)
- **Người nói trước:** Phan Tiến Hưng. **Phần sau:** Kết luận

Chữ trong *[ngoặc vuông]* là thao tác chỉ slide, không đọc.

| Trang | Nội dung | Thời gian |
| --- | --- | --- |
| 31 | Giới thiệu | 20 giây |
| 32 | Quy trình tổng hợp | 70 giây |
| 33 | Tài nguyên và tần số | 70 giây |
| 34 | Đọc bảng số liệu cho đúng | 70 giây |
| 35 | Hiệu năng thời gian | 55 giây |
| 36 | Thí nghiệm A | 60 giây |
| 37 | Thí nghiệm B | 75 giây |
| 38 | Vá firmware vào bitstream | 70 giây |

## Trang 31. Giới thiệu (20 giây)

> Em chào thầy và các bạn, em là Trần Phạm Nam Anh. Các bạn vừa trình bày bốn cách làm bộ điều khiển. Phần em trả lời câu hỏi: mỗi cách tốn bao nhiêu tài nguyên, chạy nhanh tới đâu, và sửa tốn bao nhiêu công.

## Trang 32. Quy trình tổng hợp (70 giây)

*[Chỉ lần lượt năm ô từ trái sang phải]*

> Mã Verilog đi qua bốn công cụ. Yosys tổng hợp mã thành LUT, flip-flop và block RAM. nextpnr đặt các phần tử đó vào vị trí trên chip, nối dây, rồi phân tích thời gian để cho ra Fmax. icepack đóng gói thành bitstream. icebram thay nội dung block RAM trong bitstream đã có.

*[Chỉ khối Cách đo]*

> Mỗi thiết kế được tổng hợp hai lần: một lần ra cổng logic chung để đếm cổng và đo đường tổ hợp dài nhất, một lần cho chip iCE40. Kết quả đặt-đi dây phụ thuộc vào seed, nên Fmax được lấy trung bình 5 seed.

*[Chỉ khối Điều kiện vào BRAM]*

> ROM chỉ được đặt vào block RAM khi đọc đồng bộ. ROM đọc bất đồng bộ bị chuyển thành LUT. Điều này quyết định kết quả ở trang cuối của em.

## Trang 33. Tài nguyên và tần số (70 giây)

*[Chỉ cột LUT4]*

> Về tài nguyên, FSM nhỏ nhất với 21 LUT, bản ngang 38, bản dọc 83, CPU 208. CPU dùng thêm một block RAM để chứa firmware.

*[Chỉ cột Fmax]*

> Về tốc độ, Fmax trung bình giảm theo cùng thứ tự, từ khoảng 133 xuống 86 MHz. Số trong ngoặc là giá trị nhỏ nhất và lớn nhất qua 5 seed.

*[Chỉ biểu đồ]*

> Biểu đồ vẽ lại LUT, flip-flop, Fmax và độ trễ của bốn bản.

## Trang 34. Đọc bảng số liệu cho đúng (70 giây)

> Bảng vừa rồi có ba chỗ dễ đọc sai. Thứ nhất, bản ngang có 22 flip-flop. Nguyên nhân là Yosys gộp thanh ghi uPC vào cổng đọc ROM, tạo ra một ROM có thanh ghi ở đầu ra. Đó chính là thanh ghi vi lệnh MIR trong giáo trình, dù trong mã không viết.

> Thứ hai, cột cổng của CPU là 597 vì ROM chương trình bị tính thành cổng logic. Cột LUT sát thực tế hơn vì ở đó firmware nằm trong block RAM.

> Thứ ba, Fmax có nhiễu khoảng 10 phần trăm. FSM giữ nguyên 21 LUT mà Fmax đo được vẫn đổi từ 134 lên 147 MHz. Khoảng của FSM và bản ngang chồng nhau, nên em chỉ kết luận chắc được là CPU chậm hơn ba bản còn lại.

## Trang 35. Hiệu năng thời gian (55 giây)

*[Chỉ bảng]*

> Độ trễ tính từ tick đến lúc đèn đổi. FSM và bản ngang mất 1 chu kỳ, bản dọc tối đa 5, CPU tối đa 30 vì phải chạy nhiều lệnh. Bản quyết định càng muộn thì càng cần thêm phần cứng để chụp đầu vào.

*[Chỉ dạng sóng]*

> Ở lần chuyển này CPU mất 26 chu kỳ. Với clock 50 MHz, 30 chu kỳ là 600 nano giây, rất nhỏ so với một giây của đèn.

## Trang 36. Thí nghiệm A (60 giây)

> Thí nghiệm A đổi thời gian xanh của đường phụ từ 5 lên 7 tick. Script chép dự án, thay đúng một dòng ở mỗi bản, chạy lại testbench và tổng hợp lại. Cả bốn bản đều PASS.

*[Chỉ cột Dòng sửa ở]*

> Khác nhau ở chỗ dòng đó nằm đâu. FSM phải sửa RTL, ba bản còn lại sửa nội dung bộ nhớ. LUT của bản dọc vẫn đổi từ 83 xuống 81, vì ROM của nó nằm trong LUT.

## Trang 37. Thí nghiệm B (75 giây)

> Thí nghiệm B thêm nút nhấn và pha cho người đi bộ. Em đếm số dòng thêm và xoá, không tính chú thích và dòng trống.

*[Chỉ bảng]*

> FSM sửa 38 dòng, bản ngang 65, bản dọc 50, CPU 21. Bản ngang sửa nhiều nhất vì định dạng vi lệnh hết chỗ, cả 16 từ ROM phải mã hoá lại. CPU ít nhất vì lõi không đổi, chỉ sửa ngoại vi và firmware.

*[Chỉ kết quả testbench]*

> Testbench riêng cho bản này cho kết quả PASS: bốn bản khớp nhau, có 6 lần phục vụ người đi bộ. Lần nhấn ở tick 95 trong chế độ đêm được giữ lại và phục vụ ở tick 117.

## Trang 38. Vá firmware vào bitstream (70 giây)

> Câu hỏi cuối là mạch đã ở trên FPGA thì cập nhật thế nào. Firmware của CPU nằm trong block RAM nên thay được thẳng trong bitstream, không phải đặt-đi dây lại.

*[Chỉ ba bước]*

> Em tổng hợp một lần với ROM ngẫu nhiên làm khuôn, vì firmware thật có nhiều từ lặp nên icebram không tìm được vị trí. Sau đó icebram thay khuôn bằng firmware gốc, rồi bằng firmware có thời gian xanh 7 tick. Cuối cùng em giải mã block RAM và so với file hex, cả hai đều khớp.

*[Chỉ khối Kết quả]*

> Hai bitstream dài 135100 byte chỉ khác nhau 3 byte. Hai bản vi chương trình không làm được như vậy vì ROM của chúng đọc bất đồng bộ, nằm trong LUT. Phần của em đến đây là hết, tiếp theo là phần kết luận.

## Các số phải thuộc

| Số | Ý nghĩa |
| --- | --- |
| 21 / 38 / 83 / 208 | LUT4 của FSM / ngang / dọc / CPU |
| 132,9 / 126,2 / 117,5 / 85,8 | Fmax trung bình (MHz), 5 seed |
| 1 / 1 / 5 / 30 | Độ trễ xấu nhất (chu kỳ) |
| 38 / 65 / 50 / 21 | Dòng sửa ở thí nghiệm B |
| 5 và 3 | Số seed của bảng chính và của hai thí nghiệm |
| 3 trên 135100 byte | Khác nhau giữa hai bitstream |
