// ============================================================================
// board_demo.v - Bản demo trên kit: chạy song song CẢ 4 phương pháp
//
// Hai công tắc sel[1:0] chọn phương pháp nào được hiển thị ra LED, đổi được
// ngay khi đang chạy. Vì 4 bản nhận cùng tick và đầu vào, đèn không bị nhảy
// khi chuyển, đây là cách trực quan để thấy chúng tương đương.
//   sel = 0 FSM cứng, 1 vi chương trình ngang, 2 vi chương trình dọc, 3 CPU mini
// LED chỉ thị: led_sel hiện phương pháp đang chọn (one-hot).
// ============================================================================
`timescale 1ns/1ps                                          // đơn vị thời gian và độ chính xác khi mô phỏng

module board_demo #(
    parameter CLK_HZ         = 50_000_000,                  // tần số clock của kit
    parameter RST_ACTIVE_LOW = 0                            // 1 nếu nút reset tích cực mức thấp
) (
    input  wire       clk,                                  // clock hệ thống
    input  wire       btn_rst,                              // nút reset
    input  wire       sw_night,                             // công tắc chế độ đêm
    input  wire       sw_sensor,                            // công tắc giả lập cảm biến
    input  wire [1:0] sel,                                  // chọn bản hiển thị
    output reg  [5:0] led,                                  // đèn của bản đang chọn
    output wire [3:0] led_sel                               // báo bản đang chọn
);
    wire [5:0] l [0:3];                                     // đèn của bốn bản
    genvar g;                                               // biến lặp khi sinh mạch
    generate
        for (g = 0; g < 4; g = g + 1) begin : impl          // tạo bốn bản chạy song song
            top_board #(.CLK_HZ(CLK_HZ), .IMPL(g), .RST_ACTIVE_LOW(RST_ACTIVE_LOW)) u (  // bản thứ g
                .clk(clk), .btn_rst(btn_rst), .sw_night(sw_night), .sw_sensor(sw_sensor), .led(l[g]));
        end
    endgenerate

    reg [1:0] sel_s0, sel_s;   // đồng bộ hoá công tắc chọn
    always @(posedge clk) begin
        sel_s0 <= sel;                                      // tầng đồng bộ thứ nhất
        sel_s  <= sel_s0;                                   // tầng đồng bộ thứ hai
        led    <= l[sel_s];                                 // hiện bản đang chọn
    end
    assign led_sel = 4'b0001 << sel_s;                      // mã one-hot
endmodule
