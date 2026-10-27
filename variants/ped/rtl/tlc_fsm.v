// ============================================================================
// tlc_fsm.v - Phương pháp 1: FSM cứng (hardwired control) - BẢN CÓ PHA ĐI BỘ
//
// Máy trạng thái Moore 8 trạng thái. Hàm chuyển trạng thái, thời lượng pha và
// tín hiệu đèn đều là logic tổ hợp viết trực tiếp bằng case.
// Muốn đổi hành vi thì phải sửa RTL và tổng hợp lại.
// ============================================================================
`timescale 1ns/1ps
`include "tlc_defs.vh"

module tlc_fsm (
    input  wire       clk,
    input  wire       rst,      // reset đồng bộ, mức cao
    input  wire       tick,     // xung 1 chu kỳ clock, mỗi giây một lần
    input  wire       night,    // 1 = chế độ đêm (vàng nhấp nháy)
    input  wire       sensor,   // 1 = có xe chờ ở đường phụ EW
    input  wire       ped,      // nút nhấn người đi bộ
    output reg  [5:0] lights
);
    localparam [3:0] S_NSG  = 4'd0,
                     S_NSY  = 4'd1,
                     S_AR1  = 4'd2,
                     S_EWG  = 4'd3,
                     S_EWY  = 4'd4,
                     S_AR2  = 4'd5,
                     S_FON  = 4'd6,
                     S_FOFF = 4'd7,
                     S_PED  = 4'd8;

    reg [3:0] state, next;
    reg       ped_req;  // chốt yêu cầu người đi bộ
    reg [3:0] cnt;      // số tick đã trôi qua trong pha hiện tại
    reg [3:0] dur;      // thời lượng pha hiện tại

    // Logic trạng thái kế tiếp và thời lượng pha
    always @* begin
        case (state)
            S_NSG:  begin dur = `T_NSG; next = (sensor | night) ? S_NSY : S_NSG; end
            S_NSY:  begin dur = `T_Y;   next = S_AR1;                            end
            S_AR1:  begin dur = `T_AR;  next = night ? S_FON : S_EWG;            end
            S_EWG:  begin dur = `T_EWG; next = S_EWY;                            end
            S_EWY:  begin dur = `T_Y;   next = S_AR2;                            end
            S_AR2:  begin dur = `T_AR;  next = night ? S_FON : ped_req ? S_PED : S_NSG; end
            S_FON:  begin dur = `T_FL;  next = S_FOFF;                           end
            S_FOFF: begin dur = `T_FL;  next = night ? S_FON : S_AR2;            end
            S_PED:  begin dur = `T_PED; next = S_NSG;                            end
            default:begin dur = `T_AR;  next = S_AR2;                            end // trạng thái lạ
        endcase
    end

    wire expired = (cnt >= dur - 4'd1);

    always @(posedge clk) begin
        if (rst) begin
            state <= S_NSG;
            cnt   <= 4'd0;
        end else if (tick) begin
            if (!expired)
                cnt <= cnt + 4'd1;
            else if (next != state) begin
                state <= next;
                cnt   <= 4'd0;
            end
            // expired && next == state: giữ nguyên (NS xanh chờ xe)
        end
    end

    // nút nhấn trong lúc đang ở pha PED bị bỏ qua
    always @(posedge clk) begin
        if (rst || state == S_PED) ped_req <= 1'b0;
        else if (ped)              ped_req <= 1'b1;
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
