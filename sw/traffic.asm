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

.equ M_TICK,  0x01
.equ M_NIGHT, 0x02
.equ M_SN,    0x06      ; sensor | night

; tổ hợp đèn {nsR nsY nsG ewR ewY ewG}
.equ L_NSG,   0b001100
.equ L_NSY,   0b010100
.equ L_AR,    0b100100
.equ L_EWG,   0b100001
.equ L_EWY,   0b100010
.equ L_FON,   0b010010
.equ L_OFF,   0b000000

; thời lượng (tick)
.equ T_NSG,   8
.equ T_Y,     3
.equ T_AR,    1
.equ T_EWG,   5
.equ T_FL,    1

; ---------------------------------------------------------------------------
nsg:        LDI  R0, L_NSG
            OUT  P_IO, R0
            LDI  R1, T_NSG-1
            CALL wait
nsg_hold:   LDI  R1, 1              ; tick thứ T_NSG trở đi: mỗi tick xét điều kiện
            CALL wait
            IN   R2, P_IO
            ANDI R2, M_SN
            JZ   nsg_hold           ; không có xe phụ và không phải ban đêm -> giữ xanh

nsy:        LDI  R0, L_NSY
            OUT  P_IO, R0
            LDI  R1, T_Y
            CALL wait

ar1:        LDI  R0, L_AR
            OUT  P_IO, R0
            LDI  R1, T_AR
            CALL wait
            IN   R2, P_IO
            ANDI R2, M_NIGHT
            JNZ  fon

ewg:        LDI  R0, L_EWG
            OUT  P_IO, R0
            LDI  R1, T_EWG
            CALL wait

ewy:        LDI  R0, L_EWY
            OUT  P_IO, R0
            LDI  R1, T_Y
            CALL wait

ar2:        LDI  R0, L_AR
            OUT  P_IO, R0
            LDI  R1, T_AR
            CALL wait
            IN   R2, P_IO
            ANDI R2, M_NIGHT
            JNZ  fon
            JMP  nsg

fon:        LDI  R0, L_FON
            OUT  P_IO, R0
            LDI  R1, T_FL
            CALL wait

foff:       LDI  R0, L_OFF
            OUT  P_IO, R0
            LDI  R1, T_FL
            CALL wait
            IN   R2, P_IO
            ANDI R2, M_NIGHT
            JNZ  fon
            JMP  ar2

; ---------------------------------------------------------------------------
; wait: chờ đủ R1 tick (R1 >= 1). Làm hỏng R1, R2, Z.
wait:       IN   R2, P_IO
            ANDI R2, M_TICK
            JZ   wait               ; hỏi vòng cờ tick
            OUT  P_TACK, R2         ; xoá cờ
            ADDI R1, 0xFF           ; R1 <- R1 - 1
            JNZ  wait
            RET
