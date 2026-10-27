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
`timescale 1ns/1ps

module de10_lite_top (
    input  wire       MAX10_CLK1_50,
    input  wire [1:0] KEY,
    input  wire [3:0] SW,
    output wire [9:0] LEDR
);
    board_demo #(.CLK_HZ(50_000_000), .RST_ACTIVE_LOW(1)) u (
        .clk(MAX10_CLK1_50), .btn_rst(KEY[0]), .sw_night(SW[0]), .sw_sensor(SW[1]), .sel(SW[3:2]),
        .led(LEDR[5:0]), .led_sel(LEDR[9:6])
    );
endmodule
