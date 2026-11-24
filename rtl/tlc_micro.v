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
`timescale 1ns/1ps                                          // đơn vị thời gian và độ chính xác khi mô phỏng
module tlc_micro #(
    parameter UCODE_FILE = "rtl/microcode.mem"              // file nội dung bộ nhớ điều khiển
) (
    input  wire       clk,                                  // clock hệ thống
    input  wire       rst,                                  // reset đồng bộ, mức cao
    input  wire       tick,                                 // xung 1 chu kỳ clock, mỗi giây một lần
    input  wire       night,                                // 1 = chế độ đêm
    input  wire       sensor,                               // 1 = có xe chờ ở đường phụ
    output wire [5:0] lights                                // {ns_r, ns_y, ns_g, ew_r, ew_y, ew_g}
);
    localparam C_ALWAYS = 2'b00, C_NIGHT = 2'b01, C_SN = 2'b10, C_SENSOR = 2'b11;  // mã điều kiện, đã dùng hết 4 mã

    // ---- Control store: 16 vi lệnh x 20 bit ----
    reg [19:0] ucode [0:15];                                // bộ nhớ điều khiển
    initial $readmemb(UCODE_FILE, ucode);                   // nạp vi chương trình dạng nhị phân

    reg  [3:0]  upc;                                        // địa chỉ vi lệnh hiện tại, cũng là số hiệu pha
    reg  [3:0]  cnt;                                        // số tick đã qua trong pha
    wire [19:0] uinst = ucode[upc];                         // vi lệnh đang chạy, đọc bất đồng bộ

    wire [3:0] dur    = uinst[13:10];                       // trường thời lượng
    wire [1:0] csel   = uinst[9:8];                         // trường chọn điều kiện
    wire [3:0] next_t = uinst[7:4];                         // địa chỉ khi điều kiện đúng
    wire [3:0] next_f = uinst[3:0];                         // địa chỉ khi điều kiện sai

    // MUX chọn điều kiện rẽ nhánh
    reg cond;
    always @* begin
        case (csel)
            C_ALWAYS: cond = 1'b1;                          // rẽ không điều kiện
            C_NIGHT:  cond = night;                         // ban đêm
            C_SN:     cond = sensor | night;                // có xe hoặc ban đêm
            default:  cond = sensor;                        // C_SENSOR
        endcase
    end

    wire [3:0] target  = cond ? next_t : next_f;            // MUX địa chỉ kế tiếp
    wire       expired = (cnt >= dur - 4'd1);               // đã đủ thời lượng

    // Bộ sắp xếp vi lệnh
    always @(posedge clk) begin
        if (rst) begin
            upc <= 4'd0;                                    // reset về vi lệnh NSG
            cnt <= 4'd0;
        end else if (tick) begin                            // chỉ cập nhật tại tick
            if (!expired)                                   // chưa hết giờ
                cnt <= cnt + 4'd1;                          // đếm thêm một tick
            else if (target != upc) begin                   // target bằng upc nghĩa là đứng chờ
                upc <= target;                              // sang vi lệnh kế tiếp
                cnt <= 4'd0;
            end
        end
    end

    assign lights = uinst[19:14];                           // đèn lấy thẳng từ vi lệnh, không giải mã
endmodule
