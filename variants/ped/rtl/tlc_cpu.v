// ============================================================================
// tlc_cpu.v - Phương pháp 3: CPU mini + phần mềm (firmware) - BẢN CÓ PHA ĐI BỘ
//   mini_cpu.v KHÔNG đổi; chỉ thêm chốt nút nhấn vào ngoại vi.
//
// Ghép mini_cpu với các ngoại vi I/O đơn giản:
//   Cổng 0x00 đọc : {4'b0, ped, sensor, night, tick_flag}   (chụp tại tick)
//   Cổng 0x00 ghi : thanh ghi đèn (6 bit thấp)
//   Cổng 0x01 ghi : xoá tick_flag (báo đã xử lý tick)
//   Cổng 0x02 ghi : xoá yêu cầu đi bộ
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
`timescale 1ns/1ps
`include "tlc_defs.vh"

module tlc_cpu #(
    parameter PROG_FILE = "sw/traffic.hex"
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,
    input  wire       night,
    input  wire       sensor,
    input  wire       ped,
    output reg  [5:0] lights,
    output reg        overrun
);
    localparam [7:0] P_IO = 8'h00, P_TACK = 8'h01, P_PCLR = 8'h02;

    wire [7:0] io_addr, io_wdata, io_rdata;
    wire       io_we;
    reg        tick_flag;
    reg        night_s, sensor_s;   // đầu vào chụp tại tick
    reg        ped_req, ped_s;
    wire       tack = io_we && (io_addr == P_TACK);

    mini_cpu #(.PROG_FILE(PROG_FILE)) u_cpu (
        .clk(clk), .rst(rst),
        .io_addr(io_addr), .io_wdata(io_wdata), .io_we(io_we), .io_rdata(io_rdata),
        .dbg_pc(), .halted()
    );

    assign io_rdata = (io_addr == P_IO) ? {4'b0, ped_s, sensor_s, night_s, tick_flag} : 8'h00;

    always @(posedge clk) begin
        if (rst) begin
            tick_flag <= 1'b0;
            overrun   <= 1'b0;
            night_s   <= 1'b0;
            sensor_s  <= 1'b0;
            ped_req   <= 1'b0;
            ped_s     <= 1'b0;
            lights    <= `L_AR;   // trước khi phần mềm chạy: đỏ toàn phần cho an toàn
        end else begin
            // tick mới thắng lệnh xoá nếu trùng chu kỳ
            if (tick) begin
                night_s   <= night;
                sensor_s  <= sensor;
                ped_s     <= ped_req;
                tick_flag <= 1'b1;
                if (tick_flag && !tack) overrun <= 1'b1;
            end else if (tack)
                tick_flag <= 1'b0;

            if (io_we && io_addr == P_IO)
                lights <= io_wdata[5:0];

            if (io_we && io_addr == P_PCLR) ped_req <= 1'b0;
            else if (ped)                  ped_req <= 1'b1;
        end
    end
endmodule
