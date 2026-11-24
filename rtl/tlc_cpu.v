// ============================================================================
// tlc_cpu.v - Phương pháp 3: CPU mini + phần mềm (firmware)
//
// Ghép mini_cpu với các ngoại vi I/O đơn giản:
//   Cổng 0x00 đọc : {5'b0, sensor, night, tick_flag}   (sensor/night chụp tại tick)
//   Cổng 0x00 ghi : thanh ghi đèn (6 bit thấp)
//   Cổng 0x01 ghi : xoá tick_flag (báo đã xử lý tick)
//
// tick chỉ rộng 1 chu kỳ clock nên phần mềm không thể bắt nó bằng cách hỏi
// vòng (polling) trực tiếp. Ngoại vi chốt tick vào tick_flag, phần mềm hỏi
// vòng cờ này rồi xoá. Nếu tick mới đến khi cờ chưa được xoá thì overrun = 1
// (phần mềm bị trễ, mất tick).
//
// sensor/night được chụp (snapshot) đúng tại cạnh tick. Phần mềm đọc chúng
// muộn hàng chục chu kỳ sau tick; nếu đọc trực tiếp chân vào, CPU có thể thấy
// giá trị khác với giá trị FSM đã lấy mẫu tại tick -> hai cách ra quyết định
// khác nhau. Snapshot làm CPU ra quyết định trên đúng mẫu mà FSM dùng.
// ============================================================================
`timescale 1ns/1ps                                          // đơn vị thời gian và độ chính xác khi mô phỏng
`include "tlc_defs.vh"                                      // mã đèn và thời lượng các pha

module tlc_cpu #(                                           // CPU và ngoại vi ghép thành một bộ điều khiển
    parameter PROG_FILE = "sw/traffic.hex"                  // firmware đèn giao thông
) (
    input  wire       clk,                                  // clock hệ thống
    input  wire       rst,                                  // reset đồng bộ, mức cao
    input  wire       tick,                                 // xung 1 chu kỳ clock, mỗi giây một lần
    input  wire       night,                                // 1 = chế độ đêm
    input  wire       sensor,                               // 1 = có xe chờ ở đường phụ
    output reg  [5:0] lights,                               // thanh ghi đèn do phần mềm ghi
    output reg        overrun                               // 1 = phần mềm đã bỏ lỡ một tick
);
    localparam [7:0] P_IO = 8'h00, P_TACK = 8'h01;          // địa chỉ cổng

    wire [7:0] io_addr, io_wdata, io_rdata;                 // bus vào/ra của CPU
    wire       io_we;                                       // CPU đang ghi cổng
    reg        tick_flag;                                   // chốt tick cho phần mềm hỏi vòng
    reg        night_s, sensor_s;   // đầu vào chụp tại tick
    wire       tack = io_we && (io_addr == P_TACK);         // phần mềm xác nhận đã xử lý tick

    mini_cpu #(.PROG_FILE(PROG_FILE)) u_cpu (               // lõi CPU
        .clk(clk), .rst(rst),                               // clock, reset
        .io_addr(io_addr), .io_wdata(io_wdata), .io_we(io_we), .io_rdata(io_rdata),  // bus vào/ra
        .dbg_pc(), .halted()                                // không dùng
    );

    assign io_rdata = (io_addr == P_IO) ? {5'b0, sensor_s, night_s, tick_flag} : 8'h00;  // byte trả về cho lệnh IN

    always @(posedge clk) begin
        if (rst) begin
            tick_flag <= 1'b0;                              // xoá cờ tick
            overrun   <= 1'b0;
            night_s   <= 1'b0;
            sensor_s  <= 1'b0;
            lights    <= `L_AR;   // trước khi phần mềm chạy: đỏ toàn phần cho an toàn
        end else begin
            // tick mới thắng lệnh xoá nếu trùng chu kỳ
            if (tick) begin
                night_s   <= night;                         // chụp night tại tick
                sensor_s  <= sensor;                        // chụp sensor tại tick
                tick_flag <= 1'b1;                          // báo có tick mới
                if (tick_flag && !tack) overrun <= 1'b1;    // tick trước chưa xử lý xong
            end else if (tack)                              // phần mềm ghi cổng 1
                tick_flag <= 1'b0;                          // xoá cờ tick

            if (io_we && io_addr == P_IO)                   // phần mềm ghi cổng 0
                lights <= io_wdata[5:0];                    // đổi đèn
        end
    end
endmodule
