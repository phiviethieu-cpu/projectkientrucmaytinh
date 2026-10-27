// ============================================================================
// tlc_micro.v - Phương pháp 2: Điều khiển vi chương trình (microprogrammed)
//
// Phần cứng gồm bộ sắp xếp vi lệnh (micro-sequencer) cố định:
//   uPC  -> Control Store (ROM) -> vi lệnh nằm ngang (horizontal microinstruction)
//   bộ đếm tick + MUX chọn điều kiện + MUX chọn địa chỉ kế tiếp
// Hành vi đèn nằm hoàn toàn trong file microcode.mem; đổi hành vi chỉ cần
// sửa ROM, không phải sửa datapath.
//
// Định dạng vi lệnh (20 bit):
//   [19:14] LIGHTS  tổ hợp đèn xuất ra
//   [13:10] DUR     thời lượng (tick) tối thiểu của vi lệnh
//   [ 9: 8] COND    00 = luôn đúng, 01 = night, 10 = sensor|night, 11 = sensor
//   [ 7: 4] NEXT_T  địa chỉ kế tiếp khi COND đúng
//   [ 3: 0] NEXT_F  địa chỉ kế tiếp khi COND sai (= uPC hiện tại thì đứng chờ)
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
    output wire [5:0] lights
);
    localparam C_ALWAYS = 2'b00, C_NIGHT = 2'b01, C_SN = 2'b10, C_SENSOR = 2'b11;

    // ---- Control store: 16 vi lệnh x 20 bit ----
    reg [19:0] ucode [0:15];
    initial $readmemb(UCODE_FILE, ucode);

    reg  [3:0]  upc;
    reg  [3:0]  cnt;
    wire [19:0] uinst = ucode[upc];

    wire [3:0] dur    = uinst[13:10];
    wire [1:0] csel   = uinst[9:8];
    wire [3:0] next_t = uinst[7:4];
    wire [3:0] next_f = uinst[3:0];

    // MUX chọn điều kiện rẽ nhánh
    reg cond;
    always @* begin
        case (csel)
            C_ALWAYS: cond = 1'b1;
            C_NIGHT:  cond = night;
            C_SN:     cond = sensor | night;
            default:  cond = sensor;
        endcase
    end

    wire [3:0] target  = cond ? next_t : next_f;
    wire       expired = (cnt >= dur - 4'd1);

    // Bộ sắp xếp vi lệnh
    always @(posedge clk) begin
        if (rst) begin
            upc <= 4'd0;
            cnt <= 4'd0;
        end else if (tick) begin
            if (!expired)
                cnt <= cnt + 4'd1;
            else if (target != upc) begin
                upc <= target;
                cnt <= 4'd0;
            end
        end
    end

    assign lights = uinst[19:14];
endmodule
