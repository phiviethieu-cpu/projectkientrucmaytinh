// ============================================================================
// tb_top_board.v - Kiểm tra module top cho kit FPGA
//
// 4 bản top_board (IMPL = 0..3) cùng nhận clk, nút reset (mức thấp, như KEY
// của DE10-Lite) và 2 công tắc thay đổi không đồng bộ với clock. Kiểm tra:
//   - bộ chia tạo đúng 1 tick mỗi CLK_HZ chu kỳ
//   - bộ đồng bộ hoá + reset mức thấp hoạt động; mạch tự reset khi bật nguồn
//   - LED của 4 bản giống nhau tại mỗi tick, và chạy qua đủ các pha
// CLK_HZ đặt nhỏ (64) để mô phỏng nhanh; trên kit dùng 50_000_000.
// ============================================================================
`timescale 1ns/1ps
`include "tlc_defs.vh"

module tb_top_board;
    localparam CLK_HZ = 64;

    reg clk = 1'b0, key_n = 1'b1, sw_night = 1'b0, sw_sensor = 1'b0;
    always #10 clk = ~clk;     // 50 MHz

    wire [5:0] led [0:3];
    genvar g;
    generate
        for (g = 0; g < 4; g = g + 1) begin : dut
            top_board #(.CLK_HZ(CLK_HZ), .IMPL(g), .RST_ACTIVE_LOW(1)) u (
                .clk(clk), .btn_rst(key_n), .sw_night(sw_night), .sw_sensor(sw_sensor), .led(led[g]));
        end
    endgenerate

    wire tick = dut[0].u.tick;
    integer ntick = 0, errors = 0, last_tick_cycle = -1, cycle = 0;
    reg [7:0] seen;            // pha nào đã xuất hiện
    integer k;

    integer rst_cycles = 0;    // số chu kỳ reset nội bộ đang tích cực
    always @(posedge clk) begin
        cycle = cycle + 1;
        if (dut[0].u.rst) begin
            rst_cycles = rst_cycles + 1;
            last_tick_cycle = -1;  // bộ chia đếm lại từ đầu sau reset
        end
        if (tick) begin
            ntick = ntick + 1;
            if (last_tick_cycle >= 0 && cycle - last_tick_cycle != CLK_HZ) begin
                $display("[LỖI] khoảng cách 2 tick = %0d chu kỳ, mong đợi %0d", cycle - last_tick_cycle, CLK_HZ);
                errors = errors + 1;
            end
            last_tick_cycle = cycle;
            for (k = 1; k < 4; k = k + 1)
                if (led[k] !== led[0]) begin
                    $display("[LỖI] tick %0d: IMPL0=%b IMPL%0d=%b", ntick, led[0], k, led[k]);
                    errors = errors + 1;
                end
            case (led[0])
                `L_NSG: seen[0] = 1'b1;  `L_NSY: seen[1] = 1'b1;  `L_AR:  seen[2] = 1'b1;
                `L_EWG: seen[3] = 1'b1;  `L_EWY: seen[4] = 1'b1;  `L_FON: seen[5] = 1'b1;
                `L_OFF: seen[6] = 1'b1;  default: begin
                    $display("[LỖI] mã LED lạ %b", led[0]); errors = errors + 1; end
            endcase
        end
    end

    initial begin
        seen = 8'h80;
        $dumpfile("sim/tb_top_board.vcd");
        $dumpvars(0, tb_top_board);

        // bật nguồn: chưa nhấn nút, mạch phải tự reset 1-2 chu kỳ nhờ giá trị
        // đầu của bộ đồng bộ, sau đó tự thoát reset và hiện NSG
        repeat (5) @(posedge clk);
        if (rst_cycles == 0 || dut[0].u.rst !== 1'b0) begin
            $display("[LỖI] không tự reset khi bật nguồn (rst_cycles=%0d)", rst_cycles); errors = errors + 1;
        end

        // công tắc đổi lệch pha với clock (giữa 2 cạnh) để thử bộ đồng bộ
        #(CLK_HZ * 20 * 12 + 3) sw_sensor = 1'b1;
        #(CLK_HZ * 20 * 30 + 7) sw_night  = 1'b1;
        #(CLK_HZ * 20 * 12 + 1) sw_night  = 1'b0;

        // nhấn nút reset (mức thấp) giữa chừng: mọi bản phải về NSG
        #(CLK_HZ * 20 * 20 + 9) key_n = 1'b0;
        #(20 * 5)               key_n = 1'b1;
        #(CLK_HZ * 20 * 2);
        for (k = 0; k < 4; k = k + 1)
            if (led[k] !== `L_NSG) begin
                $display("[LỖI] IMPL%0d không về NSG sau reset: %b", k, led[k]); errors = errors + 1;
            end
        #(CLK_HZ * 20 * 30);

        if (seen !== 8'hFF) begin
            $display("[LỖI] chưa đi qua đủ các pha: seen = %b", seen); errors = errors + 1;
        end
        $display("Số tick: %0d, các pha đã thấy: %b", ntick, seen);
        if (errors == 0) $display(">>> PASS");
        else             $display(">>> FAIL (%0d lỗi)", errors);
        $finish;
    end
endmodule
