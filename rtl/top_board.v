// ============================================================================
// top_board.v - Module top để nạp lên kit FPGA
//
// Tạo tick 1 Hz từ clock hệ thống và chọn một trong bốn bộ điều khiển qua
// tham số IMPL: 0 = FSM cứng, 1 = vi chương trình ngang,
//               2 = vi chương trình dọc, 3 = CPU mini.
// File gán chân mẫu: boards/basys3.xdc (Vivado), boards/de10_lite.qsf (Quartus).
// ============================================================================
`timescale 1ns/1ps                                          // đơn vị thời gian và độ chính xác khi mô phỏng

module top_board #(
    parameter CLK_HZ         = 50_000_000,                  // tần số clock của kit
    parameter IMPL           = 0,                           // chọn bộ điều khiển 0..3
    parameter RST_ACTIVE_LOW = 0          // 1 nếu nút reset của kit tích cực mức thấp
) (
    input  wire       clk,                                  // clock hệ thống
    input  wire       btn_rst,     // nút reset
    input  wire       sw_night,    // công tắc chế độ đêm
    input  wire       sw_sensor,   // công tắc giả lập cảm biến xe đường phụ
    output wire [5:0] led          // {ns_r, ns_y, ns_g, ew_r, ew_y, ew_g}
);
    // ---- đồng bộ hoá đầu vào bất đồng bộ (2 flip-flop) ----
    // giá trị đầu là reset để mạch tự reset khi vừa nạp cấu hình
    reg [1:0] s_rst = 2'b11, s_night = 2'b00, s_sensor = 2'b00;  // hai tầng flip-flop cho mỗi đầu vào
    wire rst_in = RST_ACTIVE_LOW ? ~btn_rst : btn_rst;      // quy về mức cao
    always @(posedge clk) begin
        s_rst    <= {s_rst[0],    rst_in};                  // dịch qua hai tầng
        s_night  <= {s_night[0],  sw_night};                // dịch qua hai tầng
        s_sensor <= {s_sensor[0], sw_sensor};               // dịch qua hai tầng
    end
    wire rst = s_rst[1], night = s_night[1], sensor = s_sensor[1];  // tín hiệu đã đồng bộ

    // ---- bộ chia tạo tick 1 Hz ----
    localparam W = (CLK_HZ > 1) ? $clog2(CLK_HZ) : 1;       // số bit của bộ chia
    reg [W-1:0] div;                                        // đếm chu kỳ clock
    reg         tick;                                       // xung 1 Hz
    always @(posedge clk) begin
        if (rst) begin
            div  <= 0;
            tick <= 1'b0;
        end else if (div == CLK_HZ - 1) begin               // đủ một giây
            div  <= 0;
            tick <= 1'b1;                                   // phát tick trong đúng một chu kỳ
        end else begin
            div  <= div + 1'b1;                             // đếm tiếp
            tick <= 1'b0;
        end
    end

    // ---- chọn phương pháp ----
    generate                                                // chỉ một nhánh được tổng hợp
        if (IMPL == 0) begin : g_fsm
            tlc_fsm    u (.clk(clk), .rst(rst), .tick(tick), .night(night), .sensor(sensor), .lights(led));
        end else if (IMPL == 1) begin : g_micro
            tlc_micro  u (.clk(clk), .rst(rst), .tick(tick), .night(night), .sensor(sensor), .lights(led));
        end else if (IMPL == 2) begin : g_vmicro
            tlc_vmicro u (.clk(clk), .rst(rst), .tick(tick), .night(night), .sensor(sensor), .lights(led));
        end else begin : g_cpu
            tlc_cpu    u (.clk(clk), .rst(rst), .tick(tick), .night(night), .sensor(sensor), .lights(led),
                          .overrun());                      // không dùng trên kit
        end
    endgenerate
endmodule
