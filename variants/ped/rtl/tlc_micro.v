// ============================================================================
// tlc_micro.v - Phương pháp 2: Điều khiển vi chương trình (microprogrammed)
//               BẢN CÓ PHA ĐI BỘ
//
// Thay đổi phần cứng so với bản gốc:
//   - COND mở rộng 2 -> 3 bit để thêm điều kiện PED (4 mã cũ đã dùng hết)
//   - thêm trường CLRP: xoá yêu cầu đi bộ khi đang ở vi lệnh này
//   - DUR = 0 nghĩa là vi lệnh "tức thời": rẽ nhánh ngay chu kỳ sau, không
//     chờ tick (AR2 cần rẽ 3 hướng mà mỗi vi lệnh chỉ rẽ được 2)
//   - thanh ghi chốt nút nhấn ped_req
//
// Định dạng vi lệnh (22 bit):
//   [21:16] LIGHTS  [15:12] DUR  [11:9] COND  [8:5] NEXT_T  [4:1] NEXT_F  [0] CLRP
//   COND: 000 luôn đúng, 001 night, 010 sensor|night, 011 sensor, 100 ped_req
// ============================================================================
`timescale 1ns/1ps
module tlc_micro #(
    parameter UCODE_FILE = "rtl/microcode.mem"
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,
    input  wire       night,
    input  wire       sensor,
    input  wire       ped,
    output wire [5:0] lights
);
    localparam C_ALWAYS = 3'b000, C_NIGHT = 3'b001, C_SN = 3'b010, C_SENSOR = 3'b011,
               C_PED = 3'b100;

    // ---- Control store: 16 vi lệnh x 22 bit ----
    reg [21:0] ucode [0:15];
    initial $readmemb(UCODE_FILE, ucode);

    reg  [3:0]  upc;
    reg  [3:0]  cnt;
    reg         ped_req;
    wire [21:0] uinst = ucode[upc];

    wire [3:0] dur    = uinst[15:12];
    wire [2:0] csel   = uinst[11:9];
    wire [3:0] next_t = uinst[8:5];
    wire [3:0] next_f = uinst[4:1];
    wire       clrp   = uinst[0];

    // MUX chọn điều kiện rẽ nhánh
    reg cond;
    always @* begin
        case (csel)
            C_ALWAYS: cond = 1'b1;
            C_NIGHT:  cond = night;
            C_SN:     cond = sensor | night;
            C_SENSOR: cond = sensor;
            C_PED:    cond = ped_req;
            default:  cond = 1'b0;
        endcase
    end

    wire [3:0] target  = cond ? next_t : next_f;
    wire       instant = (dur == 4'd0);
    wire       expired = instant || (cnt >= dur - 4'd1);

    // Bộ sắp xếp vi lệnh
    always @(posedge clk) begin
        if (rst) begin
            upc <= 4'd0;
            cnt <= 4'd0;
        end else if (tick || instant) begin
            if (!expired)
                cnt <= cnt + 4'd1;
            else if (target != upc) begin
                upc <= target;
                cnt <= 4'd0;
            end
        end
    end

    always @(posedge clk) begin
        if (rst || clrp) ped_req <= 1'b0;
        else if (ped)    ped_req <= 1'b1;
    end

    assign lights = uinst[21:16];
endmodule
