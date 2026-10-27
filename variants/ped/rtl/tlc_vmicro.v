// ============================================================================
// tlc_vmicro.v - Phương pháp 2b: Vi chương trình DỌC (vertical microcode)
//                BẢN CÓ PHA ĐI BỘ: uPC 5 -> 6 bit (chương trình 37 từ > 32),
//                vi lệnh 10 -> 11 bit, mã điều kiện 111 đổi thành PED, cài CLR
//
// Khác với tlc_micro.v (vi lệnh ngang: 1 vi lệnh = 1 pha, mọi trường song
// song), ở đây mỗi vi lệnh ngắn, mã hoá theo opcode và chỉ làm MỘT việc,
// thực thi trong 1 chu kỳ clock. Một pha đèn cần chuỗi 3-4 vi lệnh:
//     LIGHT x        ; đặt thanh ghi đèn
//     TIMER d        ; nạp bộ định thời d tick
//     BR TRUN, .     ; đứng chờ đến khi hết giờ
//     BR cond, addr  ; rẽ nhánh theo điều kiện, sai thì đi tiếp uPC+1
//
// Định dạng vi lệnh (11 bit):  [10:9] op | [8:0] arg
//   op 00 LIGHT : lights <- arg[5:0]
//   op 01 TIMER : tmr    <- arg[3:0]          (tmr giảm 1 ở mỗi tick)
//   op 10 BR    : if (cond arg[8:6]) uPC <- arg[5:0] else uPC <- uPC+1
//   op 11 CLR   : arg[0] = 1 -> xoá yêu cầu đi bộ
// Mã điều kiện:
//   000 ALWAYS  001 TRUN (tmr != 0)  010 NIGHT  011 !NIGHT
//   100 SN (sensor|night)  101 !SN  110 SENSOR  111 PED (ped_req)
//
// Vì vi chương trình ra quyết định vài chu kỳ sau tick, sensor/night được
// chụp tại cạnh tick (giống ngoại vi của CPU mini).
// ============================================================================
`timescale 1ns/1ps
`include "tlc_defs.vh"

module tlc_vmicro #(
    parameter UCODE_FILE = "rtl/vmicrocode.mem"
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,
    input  wire       night,
    input  wire       sensor,
    input  wire       ped,
    output reg  [5:0] lights
);
    localparam [1:0] OP_LIGHT = 2'b00, OP_TIMER = 2'b01, OP_BR = 2'b10, OP_CLR = 2'b11;

    // ---- Control store: 64 vi lệnh x 11 bit ----
    reg [10:0] ucode [0:63];
    initial $readmemb(UCODE_FILE, ucode);

    reg  [5:0]  upc;
    reg  [3:0]  tmr;
    reg         night_s, sensor_s, ped_req;
    wire [10:0] uinst = ucode[upc];
    wire [1:0]  op    = uinst[10:9];
    wire [2:0]  csel  = uinst[8:6];
    wire [5:0]  addr  = uinst[5:0];

    reg cond;
    always @* begin
        case (csel)
            3'b000: cond = 1'b1;
            3'b001: cond = (tmr != 4'd0);
            3'b010: cond = night_s;
            3'b011: cond = !night_s;
            3'b100: cond = sensor_s | night_s;
            3'b101: cond = !(sensor_s | night_s);
            3'b110: cond = sensor_s;
            default:cond = ped_req;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            upc      <= 6'd0;
            ped_req  <= 1'b0;
            tmr      <= 4'd0;
            night_s  <= 1'b0;
            sensor_s <= 1'b0;
            lights   <= `L_AR;
        end else begin
            if (tick) begin
                night_s  <= night;
                sensor_s <= sensor;
            end

            // bộ định thời: nạp bằng vi lệnh TIMER, giảm ở mỗi tick
            if (op == OP_TIMER)
                tmr <= uinst[3:0];
            else if (tick && tmr != 4'd0)
                tmr <= tmr - 4'd1;

            if (op == OP_LIGHT)
                lights <= uinst[5:0];

            if (op == OP_CLR && uinst[0]) ped_req <= 1'b0;
            else if (ped)                 ped_req <= 1'b1;

            // bộ sắp xếp: chỉ có 2 lựa chọn, uPC+1 hoặc địa chỉ nhảy
            if (op == OP_BR && cond)
                upc <= addr;
            else
                upc <= upc + 6'd1;
        end
    end
endmodule
