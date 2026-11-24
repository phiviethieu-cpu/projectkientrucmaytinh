// ============================================================================
// tb_ped.v - Testbench cho BẢN CÓ PHA ĐI BỘ (sửa từ tb/tb_tlc.v)
//   Thêm nút ped; pha PED = đỏ toàn phần T_PED tick ngay sau AR2, nên trên
//   đường đèn thấy AR kéo dài 1 + T_PED tick.
//
// Bốn DUT (FSM cứng, vi chương trình ngang, vi chương trình dọc, CPU mini)
// nhận cùng clk/rst/tick/night/sensor. Testbench kiểm tra:
//   1. Tương đương: tại mỗi tick, đèn của 4 DUT phải giống nhau
//   2. An toàn   : không bao giờ có hai hướng cùng được đi (trừ vàng nhấp nháy)
//   3. Đặc tả    : thời lượng từng pha và thứ tự chuyển pha đúng yêu cầu
//   4. Đo đạc    : độ trễ (số chu kỳ clock) từ tick đến lúc đèn đổi
// Đầu vào chỉ thay đổi ở giữa hai tick, giống nút nhấn/cảm biến thật.
// ============================================================================
`timescale 1ns/1ps                                                                  // đơn vị thời gian và độ chính xác khi mô phỏng
`include "tlc_defs.vh"                                                              // mã đèn và thời lượng các pha

module tb_ped;
    parameter TICK_DIV   = 64;     // số chu kỳ clock giữa 2 tick (thật: 50_000_000)
    parameter N_TICKS    = 360;                                                     // số tick của cả kịch bản
    parameter RAND_START = 150;    // từ tick này trở đi đầu vào ngẫu nhiên
    parameter SEED       = 2026;                                                    // seed cố định để chạy lại được

    reg clk = 1'b0, rst = 1'b1, tick = 1'b0, night = 1'b0, sensor = 1'b0, ped = 1'b0;  // đầu vào chung của bốn DUT
    always #5 clk = ~clk;          // 100 MHz

    wire [5:0] l_fsm, l_mic, l_vmc, l_cpu;                                          // đèn của từng DUT
    wire       cpu_overrun;                                                         // CPU bỏ lỡ tick

    tlc_fsm   dut_fsm (.clk(clk), .rst(rst), .tick(tick), .night(night), .sensor(sensor), .ped(ped), .lights(l_fsm));
    tlc_micro dut_mic (.clk(clk), .rst(rst), .tick(tick), .night(night), .sensor(sensor), .ped(ped), .lights(l_mic));
    tlc_vmicro dut_vmc(.clk(clk), .rst(rst), .tick(tick), .night(night), .sensor(sensor), .ped(ped), .lights(l_vmc));
    tlc_cpu   dut_cpu (.clk(clk), .rst(rst), .tick(tick), .night(night), .sensor(sensor), .ped(ped), .lights(l_cpu),
                       .overrun(cpu_overrun));

    // ---------------------------------------------------------------- tick
    integer div = 0;                                                                // bộ chia tạo tick
    always @(posedge clk) begin
        if (rst) begin
            div  <= 0;
            tick <= 1'b0;
        end else if (div == TICK_DIV - 1) begin                                     // đủ TICK_DIV chu kỳ
            div  <= 0;
            tick <= 1'b1;                                                           // tick rộng đúng một chu kỳ
        end else begin
            div  <= div + 1;
            tick <= 1'b0;
        end
    end

    // ------------------------------------------------------------ hàm phụ
    function [8*4-1:0] name;   // tên pha từ tổ hợp đèn
        input [5:0] l;
        case (l)
            `L_NSG: name = "NSG ";
            `L_NSY: name = "NSY ";
            `L_AR:  name = "AR  ";
            `L_EWG: name = "EWG ";
            `L_EWY: name = "EWY ";
            `L_FON: name = "FON ";
            `L_OFF: name = "OFF ";
            default:name = "????";
        endcase
    endfunction

    function unsafe;           // 1 = hai hướng cùng được đi, hoặc 1 hướng sáng >1 đèn
        input [5:0] l;
        reg ns_go, ew_go;
        begin
            ns_go  = l[4] | l[3];                                                   // NS vàng hoặc xanh
            ew_go  = l[1] | l[0];                                                   // EW vàng hoặc xanh
            unsafe = (ns_go && ew_go && l != `L_FON)                                // cùng được đi, trừ lúc nhấp nháy đêm
                   || ((l[5] + l[4] + l[3]) > 1)                                    // NS sáng nhiều hơn một đèn
                   || ((l[2] + l[1] + l[0]) > 1);                                   // EW sáng nhiều hơn một đèn
        end
    endfunction

    // ------------------------------------------------- bộ đếm & kiểm tra
    integer cycle = 0, ntick = 0;                                                   // số chu kỳ clock và số tick đã qua
    integer err_equiv = 0, err_safe = 0, err_spec = 0;                              // lỗi lệch nhau, mất an toàn, sai đặc tả
    integer t_last_tick = 0;                                                        // chu kỳ của tick gần nhất
    integer lat_fsm = 0, lat_mic = 0, lat_vmc = 0, lat_cpu = 0;   // độ trễ lớn nhất
    integer lat_cpu_sum = 0, n_cpu_chg = 0;                                         // để tính độ trễ trung bình của CPU
    reg [5:0] p_fsm, p_mic, p_vmc, p_cpu;                                           // đèn ở chu kỳ trước
    // kiểm tra đặc tả trên chuỗi pha (lấy mẫu tại tick)
    reg [5:0] cur_phase;                                                            // pha đang theo dõi
    integer   phase_len = 0;                                                        // pha này đã kéo dài mấy tick
    integer   n_phase [0:7];                                                        // số lần đi qua từng pha
    integer   k;

    initial for (k = 0; k < 8; k = k + 1) n_phase[k] = 0;

    always @(posedge clk) begin
        cycle <= cycle + 1;                                                         // đếm chu kỳ clock
        if (!rst) begin
            // (2) an toàn: kiểm tra mọi chu kỳ clock, mọi DUT
            if (unsafe(l_fsm) || unsafe(l_mic) || unsafe(l_vmc) || unsafe(l_cpu)) begin
                err_safe = err_safe + 1;
                $display("[SAFETY] cycle %0d: fsm=%b mic=%b vmc=%b cpu=%b", cycle, l_fsm, l_mic, l_vmc, l_cpu);
            end

            // (4) độ trễ: đèn đổi bao nhiêu chu kỳ sau tick gần nhất
            if (l_fsm != p_fsm && cycle - t_last_tick > lat_fsm) lat_fsm = cycle - t_last_tick;
            if (l_mic != p_mic && cycle - t_last_tick > lat_mic) lat_mic = cycle - t_last_tick;
            if (l_vmc != p_vmc && ntick > 0 && cycle - t_last_tick > lat_vmc) lat_vmc = cycle - t_last_tick;
            if (l_cpu != p_cpu && ntick > 0) begin                                  // đèn của CPU vừa đổi
                if (cycle - t_last_tick > lat_cpu) lat_cpu = cycle - t_last_tick;
                lat_cpu_sum = lat_cpu_sum + (cycle - t_last_tick);
                n_cpu_chg   = n_cpu_chg + 1;
            end

            if (tick) begin
                // Tại cạnh có tick, giá trị đọc được là đèn của khoảng [tick-1, tick)
                ntick = ntick + 1;
                t_last_tick = cycle;

                // (1) tương đương
                if (l_fsm !== l_mic || l_fsm !== l_vmc || l_fsm !== l_cpu) begin    // lấy FSM làm chuẩn
                    err_equiv = err_equiv + 1;
                    $display("[MISMATCH] tick %0d: fsm=%s mic=%s vmc=%s cpu=%s",
                             ntick, name(l_fsm), name(l_mic), name(l_vmc), name(l_cpu));
                end

                // (3) đặc tả: thời lượng & thứ tự pha
                if (ntick == 1) begin                                               // tick đầu tiên, chưa có pha trước
                    cur_phase = l_fsm; phase_len = 1;
                end else if (l_fsm == cur_phase) begin                              // vẫn ở pha cũ
                    phase_len = phase_len + 1;
                end else begin
                    check_phase(cur_phase, phase_len, l_fsm);                       // pha vừa kết thúc, kiểm tra theo đặc tả
                    $display("tick %4d | %s -> %s (kéo dài %0d tick) | sensor=%b night=%b",
                             ntick, name(cur_phase), name(l_fsm), phase_len, sensor, night);
                    cur_phase = l_fsm; phase_len = 1;
                end
            end
        end
        p_fsm <= l_fsm; p_mic <= l_mic; p_vmc <= l_vmc; p_cpu <= l_cpu;             // nhớ lại cho chu kỳ sau
    end

    task check_phase;                                                               // kiểm tra độ dài pha và pha kế tiếp
        input [5:0] ph; input integer len; input [5:0] nxt;                         // pha, độ dài, pha kế tiếp
        reg ok_len, ok_next;
        begin
            case (ph)
                `L_NSG: begin ok_len = (len >= `T_NSG); ok_next = (nxt == `L_NSY);                 n_phase[0] = n_phase[0] + 1; end
                `L_NSY: begin ok_len = (len == `T_Y);   ok_next = (nxt == `L_AR);                  n_phase[1] = n_phase[1] + 1; end
                `L_AR:  begin
                            if (len == `T_AR + `T_PED) begin   // AR2 + PED
                                ok_len = 1; ok_next = (nxt == `L_NSG); n_phase[7] = n_phase[7] + 1;
                            end else begin
                                ok_len = (len == `T_AR);  ok_next = (nxt == `L_EWG || nxt == `L_NSG || nxt == `L_FON);
                            end
                            n_phase[2] = n_phase[2] + 1;
                        end
                `L_EWG: begin ok_len = (len == `T_EWG); ok_next = (nxt == `L_EWY);                 n_phase[3] = n_phase[3] + 1; end
                `L_EWY: begin ok_len = (len == `T_Y);   ok_next = (nxt == `L_AR);                  n_phase[4] = n_phase[4] + 1; end
                `L_FON: begin ok_len = (len == `T_FL);  ok_next = (nxt == `L_OFF);                 n_phase[5] = n_phase[5] + 1; end
                `L_OFF: begin ok_len = (len == `T_FL);  ok_next = (nxt == `L_FON || nxt == `L_AR); n_phase[6] = n_phase[6] + 1; end
                default:begin ok_len = 0; ok_next = 0; end                          // mã đèn lạ
            endcase
            if (!ok_len || !ok_next) begin                                          // sai độ dài hoặc sai thứ tự
                err_spec = err_spec + 1;
                $display("[SPEC] tick %0d: pha %s dài %0d tick, chuyển sang %s", ntick, name(ph), len, name(nxt));
            end
        end
    endtask

    // ------------------------------------------------------ kịch bản test
    // nhấn nút đi bộ 1 chu kỳ clock, ở 3/4 khoảng sau tick thứ n
    task press_ped;
        input integer n;
        begin
            wait (ntick >= n);                                                      // đợi tới tick thứ n
            repeat (3 * TICK_DIV / 4) @(posedge clk);                               // lệch khỏi lúc sensor và night đổi
            ped <= 1'b1;        // non-blocking: tránh race với cạnh clock DUT lấy mẫu
            @(posedge clk);
            ped <= 1'b0;
        end
    endtask

    // các lần nhấn cố định: khi chạy bình thường, liên tiếp (có lần rơi vào
    // đúng pha PED, phải bị bỏ qua), và trong chế độ đêm (phục vụ sau khi hết đêm)
    initial begin
        press_ped(28);                                                              // nhấn khi chạy bình thường
        press_ped(36); press_ped(37); press_ped(38); press_ped(39);                 // nhấn liên tiếp
        press_ped(95);                                                              // nhấn trong chế độ đêm
    end
    // chờ tới giữa khoảng sau tick thứ n
    task at_tick;
        input integer n;
        begin
            wait (ntick >= n);                                                      // đợi tới tick thứ n
            repeat (TICK_DIV / 2) @(posedge clk);                                   // rồi đợi nửa khoảng tick
        end
    endtask

    integer seed = SEED;                                                            // trạng thái của $random
    integer i;

    initial begin
        $dumpfile("sim/tb_ped.vcd");                                                // file sóng cho GTKWave
        $dumpvars(0, tb_ped);                                                       // ghi mọi tín hiệu

        repeat (5) @(posedge clk);                                                  // giữ reset 5 chu kỳ
        rst = 1'b0;                                                                 // nhả reset

        $display("=== Pha 1: không có xe ở đường phụ -> NS xanh giữ nguyên ===");
        at_tick(20);  sensor = 1'b1;                                                // xe đến liên tục
        $display("=== Pha 2: tick 20, có xe đường phụ -> chạy chu kỳ đầy đủ ===");
        at_tick(60);  sensor = 1'b0;                                                // hết xe
        $display("=== Pha 3: tick 60, hết xe ===");
        at_tick(75);  sensor = 1'b1;                                                // xe chỉ xuất hiện trong một tick
        at_tick(76);  sensor = 1'b0;
        $display("=== Pha 4: tick 75, xe đến trong 1 tick ===");
        at_tick(90);  night = 1'b1;                                                 // bật đêm
        $display("=== Pha 5: tick 90, bật chế độ đêm ===");
        at_tick(110); night = 1'b0;                                                 // tắt đêm
        $display("=== Pha 6: tick 110, tắt chế độ đêm ===");
        at_tick(RAND_START);
        $display("=== Pha 7: tick %0d..%0d, đầu vào ngẫu nhiên ===", RAND_START, N_TICKS);
        for (i = RAND_START; i < N_TICKS; i = i + 1) begin                          // phần đầu vào ngẫu nhiên
            at_tick(i + 1);
            if (($random(seed) & 7) == 0) sensor = ~sensor;                         // xác suất 1/8 mỗi tick
            if (($random(seed) & 15) == 0) press_ped(i + 1);                        // xác suất 1/16 mỗi tick
            if (($random(seed) & 15) == 0) night  = ~night;                         // xác suất 1/16 mỗi tick
        end

        $display("");
        $display("================== KẾT QUẢ ==================");
        $display("Số tick đã so sánh            : %0d", ntick);
        $display("Lệch giữa 4 DUT (tương đương) : %0d", err_equiv);
        $display("Vi phạm an toàn               : %0d", err_safe);
        $display("Vi phạm đặc tả (thời lượng/thứ tự pha): %0d", err_spec);
        $display("CPU mất tick (overrun)        : %0d", cpu_overrun);
        $display("Số lần đi qua mỗi pha: NSG=%0d NSY=%0d AR=%0d EWG=%0d EWY=%0d FON=%0d OFF=%0d PED=%0d",
                 n_phase[0], n_phase[1], n_phase[2], n_phase[3], n_phase[4], n_phase[5], n_phase[6], n_phase[7]);
        $display("Độ trễ tick->đèn (chu kỳ clock): FSM=%0d  Micro ngang=%0d  Micro dọc=%0d  CPU max=%0d, tb=%0d",
                 lat_fsm, lat_mic, lat_vmc, lat_cpu, (n_cpu_chg > 0) ? lat_cpu_sum / n_cpu_chg : 0);
        if (err_equiv == 0 && err_safe == 0 && err_spec == 0 && !cpu_overrun && n_phase[7] >= 3)  // thêm điều kiện phục vụ đi bộ ít nhất 3 lần
            $display(">>> PASS");
        else
            $display(">>> FAIL");
        $finish;
    end
endmodule
