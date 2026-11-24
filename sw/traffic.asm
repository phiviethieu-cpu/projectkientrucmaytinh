; ============================================================================
; traffic.asm - Firmware điều khiển đèn giao thông cho mini_cpu
; Dịch: python sw/asm.py sw/traffic.asm sw/traffic.hex
;
; Quy ước thanh ghi:
;   R0 - giá trị đèn      R1 - số tick cần chờ
;   R2 - tạm              R3 - địa chỉ trả về (CALL/RET)
; ============================================================================

.equ P_IO,    0x00      ; IN : {.., sensor, night, tick_flag}   OUT: đèn
.equ P_TACK,  0x01      ; OUT: xoá tick_flag

.equ M_TICK,  0x01                  ; bit 0: cờ tick
.equ M_NIGHT, 0x02                  ; bit 1: chế độ đêm
.equ M_SN,    0x06      ; sensor | night

; tổ hợp đèn {nsR nsY nsG ewR ewY ewG}
.equ L_NSG,   0b001100              ; NS xanh, EW đỏ
.equ L_NSY,   0b010100              ; NS vàng, EW đỏ
.equ L_AR,    0b100100              ; đỏ toàn phần
.equ L_EWG,   0b100001              ; NS đỏ, EW xanh
.equ L_EWY,   0b100010              ; NS đỏ, EW vàng
.equ L_FON,   0b010010              ; đêm: cả hai vàng
.equ L_OFF,   0b000000              ; đêm: tắt

; thời lượng (tick)
.equ T_NSG,   8                     ; xanh NS tối thiểu
.equ T_Y,     3                     ; vàng
.equ T_AR,    1                     ; đỏ toàn phần
.equ T_EWG,   5                     ; xanh EW
.equ T_FL,    1                     ; nửa chu kỳ nhấp nháy

; ---------------------------------------------------------------------------
nsg:        LDI  R0, L_NSG          ; NS xanh
            OUT  P_IO, R0           ; xuất ra thanh ghi đèn
            LDI  R1, T_NSG-1        ; chờ 7 tick đầu, chưa xét điều kiện
            CALL wait               ; chờ đủ R1 tick
nsg_hold:   LDI  R1, 1              ; tick thứ T_NSG trở đi: mỗi tick xét điều kiện
            CALL wait               ; chờ đủ R1 tick
            IN   R2, P_IO           ; đọc sensor, night, cờ tick
            ANDI R2, M_SN           ; chỉ giữ bit sensor và night
            JZ   nsg_hold           ; không có xe phụ và không phải ban đêm -> giữ xanh

nsy:        LDI  R0, L_NSY          ; NS vàng
            OUT  P_IO, R0           ; xuất ra thanh ghi đèn
            LDI  R1, T_Y            ; 3 tick
            CALL wait               ; chờ đủ R1 tick

ar1:        LDI  R0, L_AR           ; đỏ toàn phần lần 1
            OUT  P_IO, R0           ; xuất ra thanh ghi đèn
            LDI  R1, T_AR           ; 1 tick
            CALL wait               ; chờ đủ R1 tick
            IN   R2, P_IO           ; đọc sensor, night, cờ tick
            ANDI R2, M_NIGHT        ; chỉ giữ bit night
            JNZ  fon                ; ban đêm thì sang nhấp nháy

ewg:        LDI  R0, L_EWG          ; EW xanh
            OUT  P_IO, R0           ; xuất ra thanh ghi đèn
            LDI  R1, T_EWG          ; 5 tick
            CALL wait               ; chờ đủ R1 tick

ewy:        LDI  R0, L_EWY          ; EW vàng
            OUT  P_IO, R0           ; xuất ra thanh ghi đèn
            LDI  R1, T_Y            ; 3 tick
            CALL wait               ; chờ đủ R1 tick

ar2:        LDI  R0, L_AR           ; đỏ toàn phần lần 2
            OUT  P_IO, R0           ; xuất ra thanh ghi đèn
            LDI  R1, T_AR           ; 1 tick
            CALL wait               ; chờ đủ R1 tick
            IN   R2, P_IO           ; đọc sensor, night, cờ tick
            ANDI R2, M_NIGHT        ; chỉ giữ bit night
            JNZ  fon                ; ban đêm thì sang nhấp nháy
            JMP  nsg                ; hết một vòng, về NS xanh

fon:        LDI  R0, L_FON          ; đêm: vàng sáng
            OUT  P_IO, R0           ; xuất ra thanh ghi đèn
            LDI  R1, T_FL           ; 1 tick
            CALL wait               ; chờ đủ R1 tick

foff:       LDI  R0, L_OFF          ; đêm: tắt
            OUT  P_IO, R0           ; xuất ra thanh ghi đèn
            LDI  R1, T_FL           ; 1 tick
            CALL wait               ; chờ đủ R1 tick
            IN   R2, P_IO           ; đọc sensor, night, cờ tick
            ANDI R2, M_NIGHT        ; chỉ giữ bit night
            JNZ  fon                ; ban đêm thì sang nhấp nháy
            JMP  ar2                ; hết đêm, qua đỏ toàn phần rồi về NSG

; ---------------------------------------------------------------------------
; wait: chờ đủ R1 tick (R1 >= 1). Làm hỏng R1, R2, Z.
wait:       IN   R2, P_IO           ; đọc cờ tick
            ANDI R2, M_TICK         ; chỉ giữ bit cờ tick
            JZ   wait               ; hỏi vòng cờ tick
            OUT  P_TACK, R2         ; xoá cờ
            ADDI R1, 0xFF           ; R1 <- R1 - 1
            JNZ  wait               ; chưa đủ số tick thì chờ tiếp
            RET                     ; quay về chỗ gọi
