// ============================================================================
// de10_lite_top.v - Top cho kit Terasic DE10-Lite (MAX 10, clock 50 MHz)
// Dùng cùng boards/de10_lite.qsf. Trong Quartus: thêm các file rtl/*.v và file
// này; đặt rtl/microcode.mem, rtl/vmicrocode.mem, sw/traffic.hex đúng đường
// dẫn tương đối so với thư mục project (hoặc sửa tham số UCODE_FILE/PROG_FILE).
//
//   KEY[0] : reset (tích cực mức thấp)
//   SW[0]  : chế độ đêm   SW[1] : cảm biến xe phụ   SW[3:2] : chọn phương pháp
//   LEDR[5:0]: {ns_r, ns_y, ns_g, ew_r, ew_y, ew_g}  LEDR[9:6]: phương pháp đang chọn
// ============================================================================
`timescale 1ns/1ps                                          // đơn vị thời gian và độ chính xác khi mô phỏng

module de10_lite_top (                                      // tên cổng trùng với de10_lite.qsf
    input  wire       MAX10_CLK1_50,                        // clock 50 MHz
    input  wire [1:0] KEY,                                  // nút nhấn mức thấp, chỉ dùng KEY[0]
    input  wire [3:0] SW,                                   // công tắc
    output wire [9:0] LEDR                                  // LED đỏ
);
    board_demo #(.CLK_HZ(50_000_000), .RST_ACTIVE_LOW(1)) u (  // clock 50 MHz, reset mức thấp
        .clk(MAX10_CLK1_50), .btn_rst(KEY[0]), .sw_night(SW[0]), .sw_sensor(SW[1]), .sel(SW[3:2]),  // đầu vào
        .led(LEDR[5:0]), .led_sel(LEDR[9:6])                // đèn và phương pháp đang chọn
    );
endmodule
