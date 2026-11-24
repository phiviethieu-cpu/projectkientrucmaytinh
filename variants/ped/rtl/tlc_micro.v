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
`timescale 1ns/1ps                                          // đơn vị thời gian và độ chính xác khi mô phỏng
module tlc_micro #(
    parameter UCODE_FILE = "rtl/microcode.mem"              // file nội dung bộ nhớ điều khiển
) (
    input  wire       clk,                                  // clock hệ thống
    input  wire       rst,                                  // reset đồng bộ, mức cao
    input  wire       tick,                                 // xung 1 chu kỳ clock, mỗi giây một lần
    input  wire       night,                                // 1 = chế độ đêm
    input  wire       sensor,                               // 1 = có xe chờ ở đường phụ
    input  wire       ped,                                  // nút nhấn của người đi bộ
    output wire [5:0] lights                                // {ns_r, ns_y, ns_g, ew_r, ew_y, ew_g}
);
    localparam C_ALWAYS = 3'b000, C_NIGHT = 3'b001, C_SN = 3'b010, C_SENSOR = 3'b011,  // mã điều kiện 3 bit
               C_PED = 3'b100;                              // có yêu cầu đi bộ

    // ---- Control store: 16 vi lệnh x 22 bit ----
    reg [21:0] ucode [0:15];                                // bộ nhớ điều khiển
    initial $readmemb(UCODE_FILE, ucode);                   // nạp vi chương trình dạng nhị phân

    reg  [3:0]  upc;                                        // địa chỉ vi lệnh hiện tại, cũng là số hiệu pha
    reg  [3:0]  cnt;                                        // số tick đã qua trong pha
    reg         ped_req;                                    // chốt yêu cầu đi bộ
    wire [21:0] uinst = ucode[upc];                         // vi lệnh đang chạy, đọc bất đồng bộ

    wire [3:0] dur    = uinst[15:12];                       // trường thời lượng
    wire [2:0] csel   = uinst[11:9];                        // trường chọn điều kiện
    wire [3:0] next_t = uinst[8:5];                         // địa chỉ khi điều kiện đúng
    wire [3:0] next_f = uinst[4:1];                         // địa chỉ khi điều kiện sai
    wire       clrp   = uinst[0];                           // bit xoá yêu cầu đi bộ

    // MUX chọn điều kiện rẽ nhánh
    reg cond;
    always @* begin
        case (csel)
            C_ALWAYS: cond = 1'b1;                          // rẽ không điều kiện
            C_NIGHT:  cond = night;                         // ban đêm
            C_SN:     cond = sensor | night;                // có xe hoặc ban đêm
            C_SENSOR: cond = sensor;                        // có xe
            C_PED:    cond = ped_req;                       // có yêu cầu đi bộ
            default:  cond = 1'b0;                          // mã chưa dùng
        endcase
    end

    wire [3:0] target  = cond ? next_t : next_f;            // MUX địa chỉ kế tiếp
    wire       instant = (dur == 4'd0);                     // vi lệnh tức thời, không chờ tick
    wire       expired = instant || (cnt >= dur - 4'd1);    // đã đủ thời lượng

    // Bộ sắp xếp vi lệnh
    always @(posedge clk) begin
        if (rst) begin
            upc <= 4'd0;                                    // reset về vi lệnh NSG
            cnt <= 4'd0;
        end else if (tick || instant) begin                 // tại tick, hoặc ngay lập tức nếu DUR = 0
            if (!expired)                                   // chưa hết giờ
                cnt <= cnt + 4'd1;                          // đếm thêm một tick
            else if (target != upc) begin                   // target bằng upc nghĩa là đứng chờ
                upc <= target;                              // sang vi lệnh kế tiếp
                cnt <= 4'd0;
            end
        end
    end

    always @(posedge clk) begin
        if (rst || clrp) ped_req <= 1'b0;                   // vi lệnh PED xoá yêu cầu
        else if (ped)    ped_req <= 1'b1;                   // chốt nút nhấn
    end

    assign lights = uinst[21:16];                           // đèn lấy thẳng từ vi lệnh, không giải mã
endmodule
