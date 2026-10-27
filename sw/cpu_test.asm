; ============================================================================
; cpu_test.asm - Chương trình kiểm tra đủ 16 lệnh của mini_cpu
; Dùng với tb/tb_mini_cpu.v
;
; Mỗi kết quả được ghi ra cổng P_RES; testbench so với danh sách mong đợi.
; Nếu một phép kiểm tra cờ Z sai, chương trình nhảy tới `fail` và ghi
; mã lỗi ra cổng P_FAIL.
; Testbench cấp dữ liệu vào: cổng 0x20 trả 0xC3, các cổng khác trả về
; chính địa chỉ cổng.
; ============================================================================

.equ P_RES,  0x10
.equ P_FAIL, 0x1F
.equ P_C3,   0x20

; ---- 1. LDI, OUT
            LDI  R0, 0x5A
            OUT  P_RES, R0              ; -> 5A
; ---- 2. ADDI
            ADDI R0, 0x01
            OUT  P_RES, R0              ; -> 5B
; ---- 3. ADD có tràn, kết quả khác 0 -> Z = 0
            LDI  R1, 0xF0
            LDI  R2, 0x20
            ADD  R1, R2
            LDI  R0, 3
            JZ   fail
            OUT  P_RES, R1              ; -> 10
; ---- 4. ADD ra 0 (0x80 + 0x80) -> Z = 1
            LDI  R1, 0x80
            ADD  R1, R1
            LDI  R0, 4
            JNZ  fail
            OUT  P_RES, R1              ; -> 00
; ---- 5. SUB ra số âm (bù 2) và SUB ra 0
            LDI  R1, 0x05
            LDI  R2, 0x07
            SUB  R1, R2
            LDI  R0, 5
            JZ   fail
            OUT  P_RES, R1              ; -> FE
            SUB  R2, R2
            JNZ  fail
; ---- 6. AND
            LDI  R1, 0xCC
            LDI  R2, 0xAA
            AND  R1, R2
            OUT  P_RES, R1              ; -> 88
; ---- 7. ANDI khác 0 và ANDI ra 0
            ANDI R1, 0x0F
            LDI  R0, 7
            JZ   fail
            OUT  P_RES, R1              ; -> 08
            ANDI R1, 0x70
            JNZ  fail
; ---- 8. OR
            LDI  R1, 0x0F
            LDI  R2, 0x30
            OR   R1, R2
            LDI  R0, 8
            JZ   fail
            OUT  P_RES, R1              ; -> 3F
; ---- 9. LDI không làm đổi cờ Z
            SUB  R2, R2                 ; Z = 1
            LDI  R1, 0x55               ; Z phải vẫn = 1
            LDI  R0, 9
            JNZ  fail
; ---- 10. IN
            IN   R1, P_C3
            OUT  P_RES, R1              ; -> C3
            IN   R1, 0x07
            OUT  P_RES, R1              ; -> 07
; ---- 11. IN không làm đổi cờ Z
            ANDI R1, 0xFF               ; Z = 0
            IN   R1, 0x00               ; đọc được 0, Z phải vẫn = 0
            LDI  R0, 11
            JZ   fail
; ---- 12. JMP nhảy qua lệnh báo lỗi
            LDI  R0, 12
            JMP  skip
            JMP  fail
skip:
; ---- 13. CALL lưu địa chỉ trả về vào R3, RET quay về đúng chỗ
            CALL sub
ret_pt:     LDI  R1, ret_pt
            SUB  R1, R3                 ; R3 phải bằng địa chỉ ret_pt
            LDI  R0, 13
            JNZ  fail
; ---- 14. 4 thanh ghi độc lập
            LDI  R0, 0x11
            LDI  R1, 0x22
            LDI  R2, 0x33
            LDI  R3, 0x44
            OUT  P_RES, R0              ; -> 11
            OUT  P_RES, R1              ; -> 22
            OUT  P_RES, R2              ; -> 33
            OUT  P_RES, R3              ; -> 44
; ---- 15. NOP không làm gì
            NOP
            OUT  P_RES, R0              ; -> 11
; ---- 16. HALT: sau HALT không được có thêm lệnh nào chạy
            LDI  R0, 0xD0
            OUT  P_RES, R0              ; -> D0
            HALT
            OUT  P_FAIL, R0             ; không bao giờ được chạy tới

sub:        LDI  R2, 0x77
            OUT  P_RES, R2              ; -> 77
            RET

fail:       OUT  P_FAIL, R0             ; R0 = số thứ tự phép kiểm tra hỏng
            HALT
