// ============================================================================
// basys3_top.v - Top cho kit Digilent Basys 3 (Artix-7, clock 100 MHz)
// Dùng cùng boards/basys3.xdc. Trong Vivado: thêm các file rtl/*.v, file này,
// và rtl/microcode.mem, rtl/vmicrocode.mem, sw/traffic.hex vào project.
//
//   btnC  : reset            sw[0] : chế độ đêm      sw[1] : cảm biến xe phụ
//   sw[3:2]: chọn phương pháp hiển thị
//   led[5:0]: {ns_r, ns_y, ns_g, ew_r, ew_y, ew_g}   led[15:12]: phương pháp đang chọn
// ============================================================================
`timescale 1ns/1ps                                          // đơn vị thời gian và độ chính xác khi mô phỏng

module basys3_top (                                         // tên cổng trùng với basys3.xdc
    input  wire        clk,                                 // clock hệ thống
    input  wire        btnC,                                // nút giữa, reset mức cao
    input  wire [3:0]  sw,                                  // công tắc
    output wire [15:0] led                                  // LED đơn
);
    board_demo #(.CLK_HZ(100_000_000), .RST_ACTIVE_LOW(0)) u (  // clock 100 MHz
        .clk(clk), .btn_rst(btnC), .sw_night(sw[0]), .sw_sensor(sw[1]), .sel(sw[3:2]),  // đầu vào
        .led(led[5:0]), .led_sel(led[15:12])                // đèn và phương pháp đang chọn
    );
    assign led[11:6] = 6'b0;                                // LED không dùng thì tắt
endmodule
