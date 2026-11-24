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

.equ P_RES,  0x10                       ; cổng nhận kết quả để testbench so sánh
.equ P_FAIL, 0x1F                       ; cổng nhận mã lỗi
.equ P_C3,   0x20                       ; cổng vào mà testbench trả về 0xC3

; ---- 1. LDI, OUT
            LDI  R0, 0x5A               ; R0 = 5A
            OUT  P_RES, R0              ; ghi R0 ra cổng kết quả -> 5A
; ---- 2. ADDI
            ADDI R0, 0x01               ; R0 = 5A + 1 = 5B
            OUT  P_RES, R0              ; ghi R0 -> 5B
; ---- 3. ADD có tràn, kết quả khác 0 -> Z = 0
            LDI  R1, 0xF0               ; R1 = F0
            LDI  R2, 0x20               ; R2 = 20
            ADD  R1, R2                 ; R1 = F0 + 20 = 110, giữ 8 bit -> 10; Z = 0
            LDI  R0, 3                  ; R0 = 3: số thứ tự phép kiểm tra
            JZ   fail                   ; Z = 1 là sai, nhảy tới fail
            OUT  P_RES, R1              ; ghi R1 -> 10
; ---- 4. ADD ra 0 (0x80 + 0x80) -> Z = 1
            LDI  R1, 0x80               ; R1 = 80
            ADD  R1, R1                 ; R1 = 80 + 80 = 100, giữ 8 bit -> 00; Z = 1
            LDI  R0, 4                  ; số thứ tự phép kiểm tra: 4
            JNZ  fail                   ; Z = 0 là sai, nhảy tới fail
            OUT  P_RES, R1              ; ghi R1 -> 00
; ---- 5. SUB ra số âm (bù 2) và SUB ra 0
            LDI  R1, 0x05               ; R1 = 5
            LDI  R2, 0x07               ; R2 = 7
            SUB  R1, R2                 ; R1 = 5 - 7 = -2, bù 2 là FE; Z = 0
            LDI  R0, 5                  ; số thứ tự phép kiểm tra: 5
            JZ   fail                   ; Z = 1 là sai, nhảy tới fail
            OUT  P_RES, R1              ; ghi R1 -> FE
            SUB  R2, R2                 ; R2 = 7 - 7 = 0; Z = 1
            JNZ  fail                   ; Z = 0 là sai, nhảy tới fail
; ---- 6. AND
            LDI  R1, 0xCC               ; R1 = CC
            LDI  R2, 0xAA               ; R2 = AA
            AND  R1, R2                 ; R1 = CC & AA = 88
            OUT  P_RES, R1              ; ghi R1 -> 88
; ---- 7. ANDI khác 0 và ANDI ra 0
            ANDI R1, 0x0F               ; R1 = 88 & 0F = 08; Z = 0
            LDI  R0, 7                  ; số thứ tự phép kiểm tra: 7
            JZ   fail                   ; Z = 1 là sai, nhảy tới fail
            OUT  P_RES, R1              ; ghi R1 -> 08
            ANDI R1, 0x70               ; R1 = 08 & 70 = 00; Z = 1
            JNZ  fail                   ; Z = 0 là sai, nhảy tới fail
; ---- 8. OR
            LDI  R1, 0x0F               ; R1 = 0F
            LDI  R2, 0x30               ; R2 = 30
            OR   R1, R2                 ; R1 = 0F OR 30 = 3F; Z = 0
            LDI  R0, 8                  ; số thứ tự phép kiểm tra: 8
            JZ   fail                   ; Z = 1 là sai, nhảy tới fail
            OUT  P_RES, R1              ; ghi R1 -> 3F
; ---- 9. LDI không làm đổi cờ Z
            SUB  R2, R2                 ; R2 = 0; Z = 1
            LDI  R1, 0x55               ; nạp số khác 0; Z phải vẫn = 1
            LDI  R0, 9                  ; số thứ tự phép kiểm tra: 9
            JNZ  fail                   ; Z = 0 nghĩa là LDI đã đổi Z: sai
; ---- 10. IN
            IN   R1, P_C3               ; đọc cổng 0x20, R1 = C3
            OUT  P_RES, R1              ; ghi R1 -> C3
            IN   R1, 0x07               ; đọc cổng 0x07, testbench trả về 07
            OUT  P_RES, R1              ; ghi R1 -> 07
; ---- 11. IN không làm đổi cờ Z
            ANDI R1, 0xFF               ; R1 = 07 & FF = 07; Z = 0
            IN   R1, 0x00               ; đọc được 0, Z phải vẫn = 0
            LDI  R0, 11                 ; số thứ tự phép kiểm tra: 11
            JZ   fail                   ; Z = 1 nghĩa là IN đã đổi Z: sai
; ---- 12. JMP nhảy qua lệnh báo lỗi
            LDI  R0, 12                 ; số thứ tự phép kiểm tra: 12
            JMP  skip                   ; nhảy qua dòng dưới
            JMP  fail                   ; không được chạy tới; chạy tới là JMP sai
skip:                                   ; đích của lệnh JMP skip
; ---- 13. CALL lưu địa chỉ trả về vào R3, RET quay về đúng chỗ
            CALL sub                    ; R3 = địa chỉ ret_pt, nhảy tới sub
ret_pt:     LDI  R1, ret_pt             ; RET quay về đây; R1 = địa chỉ ret_pt
            SUB  R1, R3                 ; R1 - R3 phải bằng 0 (R3 = địa chỉ trả về); Z = 1
            LDI  R0, 13                 ; số thứ tự phép kiểm tra: 13
            JNZ  fail                   ; Z = 0 nghĩa là CALL lưu sai địa chỉ
; ---- 14. 4 thanh ghi độc lập
            LDI  R0, 0x11               ; R0 = 11
            LDI  R1, 0x22               ; R1 = 22
            LDI  R2, 0x33               ; R2 = 33
            LDI  R3, 0x44               ; R3 = 44 (R3 không còn giữ địa chỉ trả về)
            OUT  P_RES, R0              ; ghi R0 -> 11
            OUT  P_RES, R1              ; ghi R1 -> 22
            OUT  P_RES, R2              ; ghi R2 -> 33
            OUT  P_RES, R3              ; ghi R3 -> 44
; ---- 15. NOP không làm gì
            NOP                         ; không làm gì
            OUT  P_RES, R0              ; R0 không đổi sau NOP -> 11
; ---- 16. HALT: sau HALT không được có thêm lệnh nào chạy
            LDI  R0, 0xD0               ; R0 = D0
            OUT  P_RES, R0              ; ghi R0 -> D0, kết quả cuối cùng
            HALT                        ; dừng CPU
            OUT  P_FAIL, R0             ; không bao giờ được chạy tới

sub:        LDI  R2, 0x77               ; chương trình con: R2 = 77
            OUT  P_RES, R2              ; ghi R2 -> 77, chứng tỏ CALL đã nhảy tới đây
            RET                         ; quay về địa chỉ trong R3

fail:       OUT  P_FAIL, R0             ; ghi R0 = số thứ tự phép kiểm tra hỏng
            HALT                        ; dừng CPU sau khi báo lỗi
