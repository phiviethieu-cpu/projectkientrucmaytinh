// ============================================================================
// tlc_defs.vh - Hằng số dùng chung cho bộ điều khiển đèn giao thông
//
// Mã hoá đèn (6 bit): {ns_r, ns_y, ns_g, ew_r, ew_y, ew_g}
//   NS = hướng Bắc-Nam (đường chính), EW = hướng Đông-Tây (đường phụ)
// ============================================================================
`ifndef TLC_DEFS_VH
`define TLC_DEFS_VH

// Tổ hợp đèn của từng pha
`define L_NSG  6'b001_100   // NS xanh , EW đỏ
`define L_NSY  6'b010_100   // NS vàng , EW đỏ
`define L_AR   6'b100_100   // cả hai đỏ (khoảng giải phóng giao lộ)
`define L_EWG  6'b100_001   // NS đỏ   , EW xanh
`define L_EWY  6'b100_010   // NS đỏ   , EW vàng
`define L_FON  6'b010_010   // chế độ đêm: cả hai vàng (pha sáng)
`define L_OFF  6'b000_000   // chế độ đêm: tắt (pha tối)

// Thời lượng pha, đơn vị: tick (1 tick = 1 giây trên mạch thật)
`define T_NSG  4'd8         // xanh NS tối thiểu, sau đó chờ xe ở đường phụ
`define T_Y    4'd3         // vàng
`define T_AR   4'd1         // đỏ toàn phần
`define T_EWG  4'd5         // xanh EW
`define T_FL   4'd1         // nửa chu kỳ nhấp nháy

`endif
