// ============================================================================
// tb_mini_cpu.v - Kiểm tra riêng mini_cpu: đủ 16 lệnh, cờ Z, CALL/RET, HALT
//
// Chạy chương trình sw/cpu_test.hex, ghi lại mọi lần ghi cổng P_RES rồi so
// với danh sách mong đợi. Đồng thời đo CPI và kiểm tra CPU dừng hẳn sau HALT.
// ============================================================================
`timescale 1ns/1ps

module tb_mini_cpu;
    localparam N_EXP = 17;
    localparam [7:0] P_RES = 8'h10, P_FAIL = 8'h1F;

    reg clk = 1'b0, rst = 1'b1;
    always #5 clk = ~clk;

    wire [7:0] io_addr, io_wdata, dbg_pc;
    wire       io_we, halted;
    // cổng 0x20 trả 0xC3, các cổng khác trả về chính địa chỉ
    wire [7:0] io_rdata = (io_addr == 8'h20) ? 8'hC3 : io_addr;

    mini_cpu #(.PROG_FILE("sw/cpu_test.hex")) dut (
        .clk(clk), .rst(rst),
        .io_addr(io_addr), .io_wdata(io_wdata), .io_we(io_we), .io_rdata(io_rdata),
        .dbg_pc(dbg_pc), .halted(halted)
    );

    reg [7:0] expected [0:N_EXP-1];
    initial begin
        expected[ 0] = 8'h5A; expected[ 1] = 8'h5B; expected[ 2] = 8'h10;
        expected[ 3] = 8'h00; expected[ 4] = 8'hFE; expected[ 5] = 8'h88;
        expected[ 6] = 8'h08; expected[ 7] = 8'h3F; expected[ 8] = 8'hC3;
        expected[ 9] = 8'h07; expected[10] = 8'h77; expected[11] = 8'h11;
        expected[12] = 8'h22; expected[13] = 8'h33; expected[14] = 8'h44;
        expected[15] = 8'h11; expected[16] = 8'hD0;
    end

    integer n_out = 0, errors = 0, cycles = 0, n_instr = 0;
    reg [15:0] op_seen;     // bit i = 1 nếu opcode i đã được thực thi

    always @(posedge clk) begin
        if (rst) begin
            op_seen <= 16'h0;
        end else begin
            cycles = cycles + 1;
            if (dut.st == 2'd1) begin            // ST_EXEC
                n_instr = n_instr + 1;
                op_seen[dut.ir[15:12]] <= 1'b1;
            end
            if (io_we && io_addr == P_RES) begin
                if (n_out >= N_EXP) begin
                    $display("[LỖI] ghi thừa kết quả 0x%02h", io_wdata);
                    errors = errors + 1;
                end else if (io_wdata !== expected[n_out]) begin
                    $display("[LỖI] kết quả #%0d = 0x%02h, mong đợi 0x%02h",
                             n_out, io_wdata, expected[n_out]);
                    errors = errors + 1;
                end else
                    $display("  kết quả #%0d = 0x%02h  OK", n_out, io_wdata);
                n_out = n_out + 1;
            end
            if (io_we && io_addr == P_FAIL) begin
                $display("[LỖI] chương trình báo hỏng phép kiểm tra số %0d", io_wdata);
                errors = errors + 1;
            end
        end
    end

    reg [7:0] pc_at_halt;
    integer   instr_at_halt, k;

    initial begin
        $dumpfile("sim/tb_mini_cpu.vcd");
        $dumpvars(0, tb_mini_cpu);
        repeat (3) @(posedge clk);
        rst = 1'b0;

        fork : run
            begin wait (halted); disable run; end
            begin repeat (5000) @(posedge clk);
                  $display("[LỖI] quá thời gian, CPU không dừng"); errors = errors + 1; disable run; end
        join

        // sau HALT: PC đứng yên, không ghi cổng, không thực thi thêm lệnh
        pc_at_halt = dbg_pc; instr_at_halt = n_instr;
        for (k = 0; k < 50; k = k + 1) begin
            @(posedge clk);
            if (io_we || dbg_pc !== pc_at_halt) begin
                $display("[LỖI] CPU vẫn chạy sau HALT"); errors = errors + 1;
                k = 50;
            end
        end
        if (n_instr != instr_at_halt) begin
            $display("[LỖI] có lệnh được thực thi sau HALT"); errors = errors + 1;
        end
        if (n_out != N_EXP) begin
            $display("[LỖI] có %0d kết quả, mong đợi %0d", n_out, N_EXP); errors = errors + 1;
        end
        if (op_seen !== 16'hFFFF) begin
            $display("[LỖI] còn opcode chưa được chạy: op_seen = %b", op_seen); errors = errors + 1;
        end

        $display("");
        $display("Số lệnh đã thực thi : %0d", instr_at_halt);
        $display("Số chu kỳ tới HALT  : %0d", cycles - 50);
        $display("Opcode đã phủ       : %b (bit 15..0)", op_seen);
        $display("CPI                 : %0d.%02d",
                 (cycles - 50) / instr_at_halt, ((cycles - 50) * 100 / instr_at_halt) % 100);
        if (errors == 0) $display(">>> PASS");
        else             $display(">>> FAIL (%0d lỗi)", errors);
        $finish;
    end
endmodule
