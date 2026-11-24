// ============================================================================
// tlc_fsm.v - Phương pháp 1: FSM cứng (hardwired control) - BẢN CÓ PHA ĐI BỘ
//
// Máy trạng thái Moore 8 trạng thái. Hàm chuyển trạng thái, thời lượng pha và
// tín hiệu đèn đều là logic tổ hợp viết trực tiếp bằng case.
// Muốn đổi hành vi thì phải sửa RTL và tổng hợp lại.
// ============================================================================
`timescale 1ns/1ps                                          // đơn vị thời gian và độ chính xác khi mô phỏng
`include "tlc_defs.vh"                                      // mã đèn và thời lượng các pha

module tlc_fsm (                                            // bộ điều khiển dạng FSM cứng
    input  wire       clk,                                  // clock hệ thống
    input  wire       rst,      // reset đồng bộ, mức cao
    input  wire       tick,     // xung 1 chu kỳ clock, mỗi giây một lần
    input  wire       night,    // 1 = chế độ đêm (vàng nhấp nháy)
    input  wire       sensor,   // 1 = có xe chờ ở đường phụ EW
    input  wire       ped,      // nút nhấn người đi bộ
    output reg  [5:0] lights                                // {ns_r, ns_y, ns_g, ew_r, ew_y, ew_g}
);
    localparam [3:0] S_NSG  = 4'd0,                         // NS xanh
                     S_NSY  = 4'd1,                         // NS vàng
                     S_AR1  = 4'd2,                         // đỏ toàn phần trước khi EW xanh
                     S_EWG  = 4'd3,                         // EW xanh
                     S_EWY  = 4'd4,                         // EW vàng
                     S_AR2  = 4'd5,                         // đỏ toàn phần trước khi NS xanh
                     S_FON  = 4'd6,                         // đêm: vàng sáng
                     S_FOFF = 4'd7,                         // đêm: tắt
                     S_PED  = 4'd8;                         // pha người đi bộ, trạng thái thứ 9

    reg [3:0] state, next;                                  // 9 trạng thái nên cần 4 bit
    reg       ped_req;  // chốt yêu cầu người đi bộ
    reg [3:0] cnt;      // số tick đã trôi qua trong pha hiện tại
    reg [3:0] dur;      // thời lượng pha hiện tại

    // Logic trạng thái kế tiếp và thời lượng pha
    always @* begin
        case (state)
            S_NSG:  begin dur = `T_NSG; next = (sensor | night) ? S_NSY : S_NSG; end  // giữ xanh đến khi có xe hoặc ban đêm
            S_NSY:  begin dur = `T_Y;   next = S_AR1;                            end  // vàng xong thì đỏ toàn phần
            S_AR1:  begin dur = `T_AR;  next = night ? S_FON : S_EWG;            end  // chỗ duy nhất vào đêm từ phía NS
            S_EWG:  begin dur = `T_EWG; next = S_EWY;                            end  // EW xanh 5 tick cố định
            S_EWY:  begin dur = `T_Y;   next = S_AR2;                            end  // EW vàng xong thì đỏ toàn phần
            S_AR2:  begin dur = `T_AR;  next = night ? S_FON : ped_req ? S_PED : S_NSG; end  // rẽ ba hướng: đêm, đi bộ, NS
            S_FON:  begin dur = `T_FL;  next = S_FOFF;                           end  // nửa chu kỳ sáng
            S_FOFF: begin dur = `T_FL;  next = night ? S_FON : S_AR2;            end  // hết đêm thì qua AR2
            S_PED:  begin dur = `T_PED; next = S_NSG;                            end  // đi bộ xong về NS xanh
            default:begin dur = `T_AR;  next = S_AR2;                            end // trạng thái lạ
        endcase
    end

    wire expired = (cnt >= dur - 4'd1);                     // đã đủ số tick của pha

    always @(posedge clk) begin
        if (rst) begin
            state <= S_NSG;                                 // reset về NS xanh
            cnt   <= 4'd0;
        end else if (tick) begin                            // chỉ cập nhật tại tick
            if (!expired)                                   // chưa hết giờ
                cnt <= cnt + 4'd1;                          // đếm thêm một tick
            else if (next != state) begin                   // hết giờ và có pha mới
                state <= next;                              // chuyển pha
                cnt   <= 4'd0;
            end
            // expired && next == state: giữ nguyên (NS xanh chờ xe)
        end
    end

    // nút nhấn trong lúc đang ở pha PED bị bỏ qua
    always @(posedge clk) begin
        if (rst || state == S_PED) ped_req <= 1'b0;         // đang phục vụ thì xoá yêu cầu
        else if (ped)              ped_req <= 1'b1;         // chốt nút nhấn
    end

    // Logic ra (Moore): đèn chỉ phụ thuộc trạng thái
    always @* begin
        case (state)
            S_NSG:  lights = `L_NSG;
            S_NSY:  lights = `L_NSY;
            S_AR1,
            S_AR2,
            S_PED:  lights = `L_AR;
            S_EWG:  lights = `L_EWG;
            S_EWY:  lights = `L_EWY;
            S_FON:  lights = `L_FON;
            S_FOFF: lights = `L_OFF;
            default:lights = `L_AR;
        endcase
    end
endmodule
