// ============================================================================
// tlc_vmicro.v - Phương pháp 2b: Vi chương trình DỌC (vertical microcode)
//
// Khác với tlc_micro.v (vi lệnh ngang: 1 vi lệnh = 1 pha, mọi trường song
// song), ở đây mỗi vi lệnh ngắn, mã hoá theo opcode và chỉ làm MỘT việc,
// thực thi trong 1 chu kỳ clock. Một pha đèn cần chuỗi 3-4 vi lệnh:
//     LIGHT x        ; đặt thanh ghi đèn
//     TIMER d        ; nạp bộ định thời d tick
//     BR TRUN, .     ; đứng chờ đến khi hết giờ
//     BR cond, addr  ; rẽ nhánh theo điều kiện, sai thì đi tiếp uPC+1
//
// Định dạng vi lệnh (10 bit):  [9:8] op | [7:0] arg
//   op 00 LIGHT : lights <- arg[5:0]
//   op 01 TIMER : tmr    <- arg[3:0]          (tmr giảm 1 ở mỗi tick)
//   op 10 BR    : if (cond arg[7:5]) uPC <- arg[4:0] else uPC <- uPC+1
//   op 11 CLR   : xoá các cờ yêu cầu theo arg (dự phòng mở rộng; bản này chưa dùng)
// Mã điều kiện:
//   000 ALWAYS  001 TRUN (tmr != 0)  010 NIGHT  011 !NIGHT
//   100 SN (sensor|night)  101 !SN  110 SENSOR  111 !SENSOR
//
// Vì vi chương trình ra quyết định vài chu kỳ sau tick, sensor/night được
// chụp tại cạnh tick (giống ngoại vi của CPU mini).
// ============================================================================
`timescale 1ns/1ps                                          // đơn vị thời gian và độ chính xác khi mô phỏng
`include "tlc_defs.vh"                                      // mã đèn và thời lượng các pha

module tlc_vmicro #(
    parameter UCODE_FILE = "rtl/vmicrocode.mem"             // file do sw/uasm.py sinh ra
) (
    input  wire       clk,                                  // clock hệ thống
    input  wire       rst,                                  // reset đồng bộ, mức cao
    input  wire       tick,                                 // xung 1 chu kỳ clock, mỗi giây một lần
    input  wire       night,                                // 1 = chế độ đêm
    input  wire       sensor,                               // 1 = có xe chờ ở đường phụ
    output reg  [5:0] lights                                // {ns_r, ns_y, ns_g, ew_r, ew_y, ew_g}
);
    localparam [1:0] OP_LIGHT = 2'b00, OP_TIMER = 2'b01, OP_BR = 2'b10, OP_CLR = 2'b11;  // mã vi lệnh

    // ---- Control store: 32 vi lệnh x 10 bit ----
    reg [9:0] ucode [0:31];                                 // bộ nhớ điều khiển
    initial $readmemb(UCODE_FILE, ucode);                   // nạp vi chương trình dạng nhị phân

    reg  [4:0] upc;                                         // địa chỉ vi lệnh
    reg  [3:0] tmr;                                         // bộ định thời, tính bằng tick
    reg        night_s, sensor_s;                           // đầu vào chụp tại tick
    wire [9:0] uinst = ucode[upc];                          // vi lệnh đang chạy
    wire [1:0] op    = uinst[9:8];                          // mã vi lệnh
    wire [2:0] csel  = uinst[7:5];                          // mã điều kiện của BR
    wire [4:0] addr  = uinst[4:0];                          // địa chỉ nhảy của BR

    reg cond;                                               // kết quả xét điều kiện
    always @* begin
        case (csel)
            3'b000: cond = 1'b1;                            // ALWAYS
            3'b001: cond = (tmr != 4'd0);                   // TRUN: định thời còn chạy
            3'b010: cond = night_s;                         // NIGHT
            3'b011: cond = !night_s;                        // NNIGHT
            3'b100: cond = sensor_s | night_s;              // SN
            3'b101: cond = !(sensor_s | night_s);           // NSN
            3'b110: cond = sensor_s;                        // SENSOR
            default:cond = !sensor_s;                       // NSENSOR
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            upc      <= 5'd0;                               // bắt đầu từ vi lệnh đầu tiên
            tmr      <= 4'd0;
            night_s  <= 1'b0;
            sensor_s <= 1'b0;
            lights   <= `L_AR;                              // đỏ toàn phần trong lúc reset
        end else begin
            if (tick) begin                                 // chụp đầu vào cùng lúc với FSM
                night_s  <= night;
                sensor_s <= sensor;
            end

            // bộ định thời: nạp bằng vi lệnh TIMER, giảm ở mỗi tick
            if (op == OP_TIMER)                             // vi lệnh TIMER
                tmr <= uinst[3:0];                          // nạp số tick
            else if (tick && tmr != 4'd0)                   // định thời còn chạy
                tmr <= tmr - 4'd1;                          // trừ một tick

            if (op == OP_LIGHT)                             // vi lệnh LIGHT
                lights <= uinst[5:0];                       // đổi đèn

            // bộ sắp xếp: chỉ có 2 lựa chọn, uPC+1 hoặc địa chỉ nhảy
            if (op == OP_BR && cond)                        // BR có điều kiện đúng
                upc <= addr;                                // nhảy
            else
                upc <= upc + 5'd1;                          // đi tiếp vi lệnh sau
        end
    end
endmodule
