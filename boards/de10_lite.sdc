# clock 50 MHz, chu kỳ 20 ns
create_clock -name clk50 -period 20.000 [get_ports MAX10_CLK1_50]
# để Quartus tự tính độ bất định của clock
derive_clock_uncertainty
