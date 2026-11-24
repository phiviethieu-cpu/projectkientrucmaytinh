// ============================================================================
// mini_cpu.v - CPU 8 bit tối giản, đa chu kỳ (2 chu kỳ/lệnh: FETCH, EXEC)
//
//   - 4 thanh ghi 8 bit R0..R3, cờ Z
//   - Bộ nhớ chương trình 256 x 16 bit (ROM, nạp từ file .hex)
//   - Không gian I/O 256 cổng, truy cập bằng lệnh IN/OUT
//
// Định dạng lệnh 16 bit:  [15:12] op | [11:10] rd | [9:8] rs | [7:0] imm
//
//   op  lệnh             thao tác                          cờ Z
//   0   NOP
//   1   LDI  rd, imm     rd <- imm
//   2   ADD  rd, rs      rd <- rd + rs                     có
//   3   ADDI rd, imm     rd <- rd + imm                    có
//   4   SUB  rd, rs      rd <- rd - rs                     có
//   5   AND  rd, rs      rd <- rd & rs                     có
//   6   ANDI rd, imm     rd <- rd & imm                    có
//   7   OR   rd, rs      rd <- rd | rs                     có
//   8   IN   rd, port    rd <- IO[port]
//   9   OUT  port, rs    IO[port] <- rs
//   A   JMP  addr        pc <- addr
//   B   JZ   addr        if (Z)  pc <- addr
//   C   JNZ  addr        if (!Z) pc <- addr
//   D   CALL addr        R3 <- pc ; pc <- addr  (link register, không lồng nhau)
//   E   RET              pc <- R3
//   F   HALT             dừng
// ============================================================================
`timescale 1ns/1ps                                                  // đơn vị thời gian mô phỏng 1 ns, độ chính xác 1 ps
module mini_cpu #(                                                  // khai báo module CPU, phần trong #( ) là tham số
    parameter PROG_FILE = "sw/traffic.hex"                          // file mã máy nạp vào bộ nhớ chương trình
) (                                                                 // hết tham số, bắt đầu danh sách cổng
    input  wire       clk,                                          // clock hệ thống, mọi thanh ghi cập nhật ở cạnh lên
    input  wire       rst,                                          // reset đồng bộ, mức cao
    // bus I/O
    output wire [7:0] io_addr,                                      // địa chỉ cổng vào/ra (0..255)
    output wire [7:0] io_wdata,                                     // dữ liệu CPU ghi ra cổng (lệnh OUT)
    output wire       io_we,                                        // bằng 1 khi CPU đang ghi ra cổng
    input  wire [7:0] io_rdata,                                     // dữ liệu CPU đọc từ cổng vào (lệnh IN)
    // quan sát/gỡ lỗi
    output wire [7:0] dbg_pc,                                       // đưa PC ra ngoài để quan sát
    output wire       halted                                        // bằng 1 khi CPU đã dừng sau HALT
);                                                                  // hết danh sách cổng
    localparam [3:0] OP_NOP = 4'h0, OP_LDI = 4'h1, OP_ADD = 4'h2, OP_ADDI = 4'h3,  // mã opcode 0..3
                     OP_SUB = 4'h4, OP_AND = 4'h5, OP_ANDI = 4'h6, OP_OR  = 4'h7,  // mã opcode 4..7
                     OP_IN  = 4'h8, OP_OUT = 4'h9, OP_JMP = 4'hA, OP_JZ   = 4'hB,  // mã opcode 8..B
                     OP_JNZ = 4'hC, OP_CALL= 4'hD, OP_RET = 4'hE, OP_HALT = 4'hF;  // mã opcode C..F

    localparam [1:0] ST_FETCH = 2'd0, ST_EXEC = 2'd1, ST_HALT = 2'd2;  // ba trạng thái của FSM điều khiển

    // ---- Bộ nhớ chương trình ----
    reg [15:0] imem [0:255];                                        // bộ nhớ chương trình: 256 từ, mỗi từ 16 bit
    initial $readmemh(PROG_FILE, imem);                             // nạp mã máy từ file .hex khi khởi tạo

    // ---- Trạng thái kiến trúc ----
    reg [7:0]  pc;                                                  // PC: địa chỉ lệnh sẽ đọc ở lần FETCH tới
    reg [15:0] ir;                                                  // IR: lệnh đang thực thi
    reg [7:0]  r0, r1, r2, r3;                                      // bốn thanh ghi đa dụng 8 bit
    reg        z;                                                   // cờ Z: 1 nếu kết quả số học/logic gần nhất bằng 0
    reg [1:0]  st;                                                  // trạng thái FSM: FETCH, EXEC hoặc HALT

    wire [3:0] op  = ir[15:12];                                     // 4 bit cao của lệnh: opcode
    wire [1:0] rd  = ir[11:10];                                     // 2 bit: số hiệu thanh ghi đích
    wire [1:0] rs  = ir[9:8];                                       // 2 bit: số hiệu thanh ghi nguồn
    wire [7:0] imm = ir[7:0];                                       // 8 bit thấp: hằng số, địa chỉ nhảy hoặc số cổng

    // ---- Đọc tệp thanh ghi (2 cổng đọc tổ hợp) ----
    reg [7:0] a, b;                                                 // giá trị đọc ra: a của rd, b của rs
    always @* begin                                                 // mạch tổ hợp: đổi ngay khi đầu vào đổi
        case (rd) 2'd0: a = r0; 2'd1: a = r1; 2'd2: a = r2; default: a = r3; endcase  // MUX chọn thanh ghi theo rd
        case (rs) 2'd0: b = r0; 2'd1: b = r1; 2'd2: b = r2; default: b = r3; endcase  // MUX chọn thanh ghi theo rs
    end                                                             // hết khối đọc thanh ghi

    // ---- ALU ----
    reg [7:0] alu;                                                  // kết quả 8 bit của ALU
    reg       alu_wr;   // lệnh có ghi rd không
    reg       z_wr;     // lệnh có cập nhật cờ Z không
    always @* begin                                                 // mạch tổ hợp: tính và giải mã opcode
        alu = 8'h00; alu_wr = 1'b0; z_wr = 1'b0;                    // giá trị mặc định: không ghi gì, tránh sinh latch
        case (op)                                                   // chọn phép tính theo opcode
            OP_LDI:  begin alu = imm;      alu_wr = 1'b1;              end  // nạp hằng số vào rd, Z giữ nguyên
            OP_ADD:  begin alu = a + b;    alu_wr = 1'b1; z_wr = 1'b1; end  // cộng hai thanh ghi, giữ 8 bit thấp
            OP_ADDI: begin alu = a + imm;  alu_wr = 1'b1; z_wr = 1'b1; end  // cộng thanh ghi với hằng số (0xFF nghĩa là -1)
            OP_SUB:  begin alu = a - b;    alu_wr = 1'b1; z_wr = 1'b1; end  // trừ hai thanh ghi, số âm ở dạng bù 2
            OP_AND:  begin alu = a & b;    alu_wr = 1'b1; z_wr = 1'b1; end  // AND từng bit hai thanh ghi
            OP_ANDI: begin alu = a & imm;  alu_wr = 1'b1; z_wr = 1'b1; end  // AND thanh ghi với hằng số, dùng để lọc bit
            OP_OR:   begin alu = a | b;    alu_wr = 1'b1; z_wr = 1'b1; end  // OR từng bit hai thanh ghi
            OP_IN:   begin alu = io_rdata; alu_wr = 1'b1;              end  // lấy dữ liệu từ cổng vào, Z giữ nguyên
            default: ;                                              // lệnh khác: dùng giá trị mặc định ở trên
        endcase                                                     // hết case opcode
    end                                                             // hết khối ALU

    // ---- Bus I/O (tổ hợp, có hiệu lực trong chu kỳ EXEC) ----
    assign io_addr  = imm;                                          // số cổng lấy từ trường imm
    assign io_wdata = b;                                            // dữ liệu ghi ra là giá trị của rs
    assign io_we    = (st == ST_EXEC) && (op == OP_OUT);            // chỉ ghi khi đang ở EXEC và lệnh là OUT

    // ---- Khối điều khiển đa chu kỳ ----
    always @(posedge clk) begin                                     // mạch tuần tự: cập nhật ở cạnh lên của clock
        if (rst) begin                                              // nếu đang reset
            pc <= 8'h00; ir <= 16'h0000; z <= 1'b0; st <= ST_FETCH;  // PC về 0, IR = 0 (NOP), xoá Z, về FETCH
            r0 <= 8'h00; r1 <= 8'h00; r2 <= 8'h00; r3 <= 8'h00;     // xoá bốn thanh ghi
        end else begin                                              // không reset: chạy bình thường
            case (st)                                               // xét trạng thái hiện tại của FSM
                ST_FETCH: begin                                     // chu kỳ 1: lấy lệnh
                    ir <= imem[pc];                                 // đọc lệnh tại PC vào IR (đọc đồng bộ)
                    pc <= pc + 8'd1;                                // PC trỏ sang lệnh kế tiếp
                    st <= ST_EXEC;                                  // chu kỳ sau chuyển sang EXEC
                end                                                 // hết FETCH
                ST_EXEC: begin                                      // chu kỳ 2: thực thi lệnh trong IR
                    st <= ST_FETCH;                                 // mặc định quay lại FETCH (HALT sẽ ghi đè)
                    if (alu_wr) begin                               // nếu lệnh có kết quả cần ghi
                        case (rd)                                   // chọn thanh ghi đích theo rd
                            2'd0: r0 <= alu;                        // rd = 0: ghi R0
                            2'd1: r1 <= alu;                        // rd = 1: ghi R1
                            2'd2: r2 <= alu;                        // rd = 2: ghi R2
                            default: r3 <= alu;                     // rd = 3: ghi R3
                        endcase                                     // hết case rd
                    end                                             // hết phần ghi thanh ghi
                    if (z_wr) z <= (alu == 8'h00);                  // lệnh số học/logic: Z = 1 nếu kết quả bằng 0
                    case (op)                                       // xử lý các lệnh đổi luồng chương trình
                        OP_JMP:  pc <= imm;                         // nhảy không điều kiện
                        OP_JZ:   if (z)  pc <= imm;                 // nhảy nếu Z = 1
                        OP_JNZ:  if (!z) pc <= imm;                 // nhảy nếu Z = 0
                        OP_CALL: begin r3 <= pc; pc <= imm; end     // R3 giữ địa chỉ trả về (PC đã +1 ở FETCH), rồi nhảy
                        OP_RET:  pc <= r3;                          // quay về địa chỉ đã lưu trong R3
                        OP_HALT: st <= ST_HALT;                     // chuyển sang trạng thái dừng
                        default: ;                                  // lệnh khác: PC giữ giá trị đã +1 ở FETCH
                    endcase                                         // hết case lệnh nhảy
                end                                                 // hết EXEC
                default: ; // ST_HALT: đứng yên
            endcase                                                 // hết case trạng thái
        end                                                         // hết nhánh không reset
    end                                                             // hết khối điều khiển

    assign dbg_pc = pc;                                             // nối PC ra cổng quan sát
    assign halted = (st == ST_HALT);                                // báo CPU đang ở trạng thái HALT
endmodule                                                           // hết module
