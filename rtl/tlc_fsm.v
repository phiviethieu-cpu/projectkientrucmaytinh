// ============================================================================
// tlc_fsm.v - Phương pháp 1: FSM cứng (hardwired control)
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
    output reg  [5:0] lights                                // {ns_r, ns_y, ns_g, ew_r, ew_y, ew_g}
);
    localparam [2:0] S_NSG  = 3'd0,                         // NS xanh
                     S_NSY  = 3'd1,                         // NS vàng
                     S_AR1  = 3'd2,                         // đỏ toàn phần trước khi EW xanh
                     S_EWG  = 3'd3,                         // EW xanh
                     S_EWY  = 3'd4,                         // EW vàng
                     S_AR2  = 3'd5,                         // đỏ toàn phần trước khi NS xanh
                     S_FON  = 3'd6,                         // đêm: vàng sáng
                     S_FOFF = 3'd7;                         // đêm: tắt

    reg [2:0] state, next;                                  // trạng thái hiện tại và kế tiếp
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
            S_AR2:  begin dur = `T_AR;  next = night ? S_FON : S_NSG;            end  // quay về NS hoặc vào đêm
            S_FON:  begin dur = `T_FL;  next = S_FOFF;                           end  // nửa chu kỳ sáng
            default:begin dur = `T_FL;  next = night ? S_FON : S_AR2;            end // S_FOFF
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

    // Logic ra (Moore): đèn chỉ phụ thuộc trạng thái
    always @* begin
        case (state)
            S_NSG:  lights = `L_NSG;
            S_NSY:  lights = `L_NSY;
            S_AR1,
            S_AR2:  lights = `L_AR;
            S_EWG:  lights = `L_EWG;
            S_EWY:  lights = `L_EWY;
            S_FON:  lights = `L_FON;
            default:lights = `L_OFF;
        endcase
    end
endmodule
