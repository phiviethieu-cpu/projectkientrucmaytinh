// ============================================================================
// tb_mini_cpu.v - Kiểm tra riêng mini_cpu: đủ 16 lệnh, cờ Z, CALL/RET, HALT
//
// Chạy chương trình sw/cpu_test.hex, ghi lại mọi lần ghi cổng P_RES rồi so
// với danh sách mong đợi. Đồng thời đo CPI và kiểm tra CPU dừng hẳn sau HALT.
// ============================================================================
`timescale 1ns/1ps                                                                  // đơn vị thời gian mô phỏng 1 ns, độ chính xác 1 ps

module tb_mini_cpu;                                                                 // module kiểm tra, không có cổng vào/ra
    localparam N_EXP = 17;                                                          // số kết quả mong đợi
    localparam [7:0] P_RES = 8'h10, P_FAIL = 8'h1F;                                 // cổng 0x10 nhận kết quả, cổng 0x1F nhận mã lỗi

    reg clk = 1'b0, rst = 1'b1;                                                     // clock ban đầu 0, reset ban đầu bật
    always #5 clk = ~clk;                                                           // đảo clock mỗi 5 ns: chu kỳ 10 ns

    wire [7:0] io_addr, io_wdata, dbg_pc;                                           // dây nối bus vào/ra và PC của CPU
    wire       io_we, halted;                                                       // dây báo ghi cổng và báo đã dừng
    // cổng 0x20 trả 0xC3, các cổng khác trả về chính địa chỉ
    wire [7:0] io_rdata = (io_addr == 8'h20) ? 8'hC3 : io_addr;                     // dữ liệu giả lập cho lệnh IN

    mini_cpu #(.PROG_FILE("sw/cpu_test.hex")) dut (                                 // tạo CPU cần kiểm tra (DUT), nạp chương trình thử
        .clk(clk), .rst(rst),                                                       // nối clock và reset
        .io_addr(io_addr), .io_wdata(io_wdata), .io_we(io_we), .io_rdata(io_rdata),  // nối bus vào/ra
        .dbg_pc(dbg_pc), .halted(halted)                                            // nối tín hiệu quan sát
    );                                                                              // hết phần nối DUT

    reg [7:0] expected [0:N_EXP-1];                                                 // bảng 17 giá trị mong đợi
    initial begin                                                                   // gán bảng khi bắt đầu mô phỏng
        expected[ 0] = 8'h5A; expected[ 1] = 8'h5B; expected[ 2] = 8'h10;           // LDI; ADDI; ADD tràn
        expected[ 3] = 8'h00; expected[ 4] = 8'hFE; expected[ 5] = 8'h88;           // ADD ra 0; SUB ra -2; AND
        expected[ 6] = 8'h08; expected[ 7] = 8'h3F; expected[ 8] = 8'hC3;           // ANDI; OR; IN cổng 0x20
        expected[ 9] = 8'h07; expected[10] = 8'h77; expected[11] = 8'h11;           // IN cổng 0x07; ghi trong chương trình con; R0
        expected[12] = 8'h22; expected[13] = 8'h33; expected[14] = 8'h44;           // R1; R2; R3
        expected[15] = 8'h11; expected[16] = 8'hD0;                                 // R0 sau NOP; giá trị ghi trước HALT
    end                                                                             // hết phần gán

    integer n_out = 0, errors = 0, cycles = 0, n_instr = 0;                         // bộ đếm: số kết quả, số lỗi, số chu kỳ, số lệnh
    reg [15:0] op_seen;     // bit i = 1 nếu opcode i đã được thực thi

    always @(posedge clk) begin                                                     // chạy ở mỗi cạnh lên của clock
        if (rst) begin                                                              // khi đang reset
            op_seen <= 16'h0;                                                       // xoá bản ghi opcode
        end else begin                                                              // khi CPU đang chạy
            cycles = cycles + 1;                                                    // đếm chu kỳ clock
            if (dut.st == 2'd1) begin                                               // mỗi lần ở EXEC là một lệnh được thực thi
                n_instr = n_instr + 1;                                              // đếm số lệnh
                op_seen[dut.ir[15:12]] <= 1'b1;                                     // đánh dấu opcode này đã chạy
            end                                                                     // hết phần đếm lệnh
            if (io_we && io_addr == P_RES) begin                                    // CPU vừa ghi một kết quả ra cổng P_RES
                if (n_out >= N_EXP) begin                                           // nhiều hơn số kết quả mong đợi
                    $display("[LỖI] ghi thừa kết quả 0x%02h", io_wdata);            // in lỗi ghi thừa
                    errors = errors + 1;                                            // tăng số lỗi
                end else if (io_wdata !== expected[n_out]) begin                    // giá trị khác mong đợi (!== so cả X, Z)
                    $display("[LỖI] kết quả #%0d = 0x%02h, mong đợi 0x%02h",        // in lỗi sai giá trị
                             n_out, io_wdata, expected[n_out]);                     // tham số của dòng in trên
                    errors = errors + 1;                                            // tăng số lỗi
                end else                                                            // giá trị đúng
                    $display("  kết quả #%0d = 0x%02h  OK", n_out, io_wdata);       // in kết quả đúng
                n_out = n_out + 1;                                                  // chuyển sang kết quả kế tiếp
            end                                                                     // hết phần kiểm tra kết quả
            if (io_we && io_addr == P_FAIL) begin                                   // chương trình tự báo hỏng qua cổng P_FAIL
                $display("[LỖI] chương trình báo hỏng phép kiểm tra số %0d", io_wdata);  // in số thứ tự phép kiểm tra hỏng
                errors = errors + 1;                                                // tăng số lỗi
            end                                                                     // hết phần báo hỏng
        end                                                                         // hết nhánh không reset
    end                                                                             // hết khối theo dõi

    reg [7:0] pc_at_halt;                                                           // PC lúc CPU dừng
    integer   instr_at_halt, k;                                                     // số lệnh lúc dừng và biến đếm vòng lặp

    initial begin                                                                   // kịch bản mô phỏng chính
        $dumpfile("sim/tb_mini_cpu.vcd");                                           // tên file sóng để mở bằng GTKWave
        $dumpvars(0, tb_mini_cpu);                                                  // ghi sóng mọi tín hiệu trong testbench
        repeat (3) @(posedge clk);                                                  // giữ reset qua 3 cạnh clock
        rst = 1'b0;                                                                 // nhả reset, CPU bắt đầu chạy

        fork : run                                                                  // chạy song song hai nhánh, nhánh nào xong trước thì dừng
            begin wait (halted); disable run; end                                   // nhánh 1: chờ CPU báo dừng
            begin repeat (5000) @(posedge clk);                                     // nhánh 2: giới hạn 5000 chu kỳ
                  $display("[LỖI] quá thời gian, CPU không dừng"); errors = errors + 1; disable run; end  // quá giới hạn thì báo lỗi và dừng chờ
        join                                                                        // hết hai nhánh song song

        // sau HALT: PC đứng yên, không ghi cổng, không thực thi thêm lệnh
        pc_at_halt = dbg_pc; instr_at_halt = n_instr;                               // lưu PC và số lệnh tại thời điểm dừng
        for (k = 0; k < 50; k = k + 1) begin                                        // theo dõi thêm 50 chu kỳ
            @(posedge clk);                                                         // chờ một cạnh lên
            if (io_we || dbg_pc !== pc_at_halt) begin                               // có ghi cổng hoặc PC đổi là sai
                $display("[LỖI] CPU vẫn chạy sau HALT"); errors = errors + 1;       // báo lỗi: HALT không dừng được CPU
                k = 50;                                                             // thoát vòng lặp
            end                                                                     // hết điều kiện lỗi
        end                                                                         // hết vòng lặp 50 chu kỳ
        if (n_instr != instr_at_halt) begin                                         // số lệnh tăng sau HALT là sai
            $display("[LỖI] có lệnh được thực thi sau HALT"); errors = errors + 1;  // báo lỗi
        end                                                                         // hết điều kiện
        if (n_out != N_EXP) begin                                                   // không đủ hoặc thừa kết quả
            $display("[LỖI] có %0d kết quả, mong đợi %0d", n_out, N_EXP); errors = errors + 1;  // báo lỗi
        end                                                                         // hết điều kiện
        if (op_seen !== 16'hFFFF) begin                                             // phải đủ 16 bit 1, tức đủ 16 opcode
            $display("[LỖI] còn opcode chưa được chạy: op_seen = %b", op_seen); errors = errors + 1;  // báo lỗi opcode chưa chạy
        end                                                                         // hết điều kiện

        $display("");                                                               // in dòng trống
        $display("Số lệnh đã thực thi : %0d", instr_at_halt);                       // in số lệnh (đúng: 74)
        $display("Số chu kỳ tới HALT  : %0d", cycles - 50);                         // trừ 50 chu kỳ theo dõi sau HALT (đúng: 148)
        $display("Opcode đã phủ       : %b (bit 15..0)", op_seen);                  // in bản đồ opcode đã chạy
        $display("CPI                 : %0d.%02d",                                  // in CPI với hai chữ số thập phân
                 (cycles - 50) / instr_at_halt, ((cycles - 50) * 100 / instr_at_halt) % 100);  // phần nguyên và phần thập phân của chu kỳ / lệnh
        if (errors == 0) $display(">>> PASS");                                      // không có lỗi: PASS
        else             $display(">>> FAIL (%0d lỗi)", errors);                    // có lỗi: FAIL kèm số lỗi
        $finish;                                                                    // kết thúc mô phỏng
    end                                                                             // hết kịch bản
endmodule                                                                           // hết module
