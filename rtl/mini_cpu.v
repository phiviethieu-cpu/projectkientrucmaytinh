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
`timescale 1ns/1ps
module mini_cpu #(
    parameter PROG_FILE = "sw/traffic.hex"
) (
    input  wire       clk,
    input  wire       rst,
    // bus I/O
    output wire [7:0] io_addr,
    output wire [7:0] io_wdata,
    output wire       io_we,
    input  wire [7:0] io_rdata,
    // quan sát/gỡ lỗi
    output wire [7:0] dbg_pc,
    output wire       halted
);
    localparam [3:0] OP_NOP = 4'h0, OP_LDI = 4'h1, OP_ADD = 4'h2, OP_ADDI = 4'h3,
                     OP_SUB = 4'h4, OP_AND = 4'h5, OP_ANDI = 4'h6, OP_OR  = 4'h7,
                     OP_IN  = 4'h8, OP_OUT = 4'h9, OP_JMP = 4'hA, OP_JZ   = 4'hB,
                     OP_JNZ = 4'hC, OP_CALL= 4'hD, OP_RET = 4'hE, OP_HALT = 4'hF;

    localparam [1:0] ST_FETCH = 2'd0, ST_EXEC = 2'd1, ST_HALT = 2'd2;

    // ---- Bộ nhớ chương trình ----
    reg [15:0] imem [0:255];
    initial $readmemh(PROG_FILE, imem);

    // ---- Trạng thái kiến trúc ----
    reg [7:0]  pc;
    reg [15:0] ir;
    reg [7:0]  r0, r1, r2, r3;
    reg        z;
    reg [1:0]  st;

    wire [3:0] op  = ir[15:12];
    wire [1:0] rd  = ir[11:10];
    wire [1:0] rs  = ir[9:8];
    wire [7:0] imm = ir[7:0];

    // ---- Đọc tệp thanh ghi (2 cổng đọc tổ hợp) ----
    reg [7:0] a, b;
    always @* begin
        case (rd) 2'd0: a = r0; 2'd1: a = r1; 2'd2: a = r2; default: a = r3; endcase
        case (rs) 2'd0: b = r0; 2'd1: b = r1; 2'd2: b = r2; default: b = r3; endcase
    end

    // ---- ALU ----
    reg [7:0] alu;
    reg       alu_wr;   // lệnh có ghi rd không
    reg       z_wr;     // lệnh có cập nhật cờ Z không
    always @* begin
        alu = 8'h00; alu_wr = 1'b0; z_wr = 1'b0;
        case (op)
            OP_LDI:  begin alu = imm;      alu_wr = 1'b1;              end
            OP_ADD:  begin alu = a + b;    alu_wr = 1'b1; z_wr = 1'b1; end
            OP_ADDI: begin alu = a + imm;  alu_wr = 1'b1; z_wr = 1'b1; end
            OP_SUB:  begin alu = a - b;    alu_wr = 1'b1; z_wr = 1'b1; end
            OP_AND:  begin alu = a & b;    alu_wr = 1'b1; z_wr = 1'b1; end
            OP_ANDI: begin alu = a & imm;  alu_wr = 1'b1; z_wr = 1'b1; end
            OP_OR:   begin alu = a | b;    alu_wr = 1'b1; z_wr = 1'b1; end
            OP_IN:   begin alu = io_rdata; alu_wr = 1'b1;              end
            default: ;
        endcase
    end

    // ---- Bus I/O (tổ hợp, có hiệu lực trong chu kỳ EXEC) ----
    assign io_addr  = imm;
    assign io_wdata = b;
    assign io_we    = (st == ST_EXEC) && (op == OP_OUT);

    // ---- Khối điều khiển đa chu kỳ ----
    always @(posedge clk) begin
        if (rst) begin
            pc <= 8'h00; ir <= 16'h0000; z <= 1'b0; st <= ST_FETCH;
            r0 <= 8'h00; r1 <= 8'h00; r2 <= 8'h00; r3 <= 8'h00;
        end else begin
            case (st)
                ST_FETCH: begin
                    ir <= imem[pc];
                    pc <= pc + 8'd1;
                    st <= ST_EXEC;
                end
                ST_EXEC: begin
                    st <= ST_FETCH;
                    if (alu_wr) begin
                        case (rd)
                            2'd0: r0 <= alu;
                            2'd1: r1 <= alu;
                            2'd2: r2 <= alu;
                            default: r3 <= alu;
                        endcase
                    end
                    if (z_wr) z <= (alu == 8'h00);
                    case (op)
                        OP_JMP:  pc <= imm;
                        OP_JZ:   if (z)  pc <= imm;
                        OP_JNZ:  if (!z) pc <= imm;
                        OP_CALL: begin r3 <= pc; pc <= imm; end
                        OP_RET:  pc <= r3;
                        OP_HALT: st <= ST_HALT;
                        default: ;
                    endcase
                end
                default: ; // ST_HALT: đứng yên
            endcase
        end
    end

    assign dbg_pc = pc;
    assign halted = (st == ST_HALT);
endmodule
