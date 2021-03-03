if { $argc != 1 } {
  puts "\[Error\] Please type in one of the below commands in the source directory"
  puts "vivado -nojournal -nolog -mode batch -source ip_generator.tcl -tclargs xcku040-ffva1156-2-e"
  puts "vivado -nojournal -nolog -mode batch -source ip_generator.tcl -tclargs xcku035-ffva1156-1-c"
} else {
  # Set environment variable
  set FPGA_TYPE [lindex $argv 0] 

  # Create ip project manager
  create_project managed_ip_project ../ip/$FPGA_TYPE/managed_ip_project -part $FPGA_TYPE -ip -force
  set_property target_language VHDL [current_project]
  set_property target_simulator XSim [current_project]

  #ODMB IP cores
  #create OdmbClockManager
  #create_ip -name clk_wiz -vendor xilinx.com -library ip -version 5.4 -module_name OdmbClockManager
  create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name OdmbClockManager -dir ../ip/$FPGA_TYPE
  set_property -dict [list CONFIG.PRIMITIVE {MMCM} CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} CONFIG.PRIM_IN_FREQ {40.000} CONFIG.JITTER_OPTIONS {UI} CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT3_USED {true} CONFIG.CLKOUT4_USED {true} CONFIG.CLKOUT5_USED {true} CONFIG.CLK_OUT1_PORT {clk_out160} CONFIG.CLK_OUT2_PORT {clk_out80} CONFIG.CLK_OUT3_PORT {clk_out40} CONFIG.CLK_OUT4_PORT {clk_out20} CONFIG.CLK_OUT5_PORT {clk_out10} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {160.000} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {80.000} CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {40.000} CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {20.000} CONFIG.CLKOUT5_REQUESTED_OUT_FREQ {10.000} CONFIG.USE_LOCKED {false} CONFIG.USE_PHASE_ALIGNMENT {true} CONFIG.SECONDARY_SOURCE {Single_ended_clock_capable_pin} CONFIG.CLKIN1_UI_JITTER {0.010} CONFIG.CLKIN2_UI_JITTER {0.010} CONFIG.CLKIN1_JITTER_PS {250.0} CONFIG.CLKIN2_JITTER_PS {100.0} CONFIG.CLKOUT1_DRIVES {Buffer} CONFIG.CLKOUT2_DRIVES {Buffer} CONFIG.CLKOUT3_DRIVES {Buffer} CONFIG.CLKOUT4_DRIVES {Buffer} CONFIG.CLKOUT5_DRIVES {Buffer} CONFIG.CLKOUT6_DRIVES {Buffer} CONFIG.CLKOUT7_DRIVES {Buffer} CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} CONFIG.MMCM_DIVCLK_DIVIDE {1} CONFIG.MMCM_CLKFBOUT_MULT_F {24.000} CONFIG.MMCM_CLKIN1_PERIOD {25.000} CONFIG.MMCM_CLKIN2_PERIOD {10.0} CONFIG.MMCM_COMPENSATION {AUTO} CONFIG.MMCM_REF_JITTER2 {0.010} CONFIG.MMCM_CLKOUT0_DIVIDE_F {6.000} CONFIG.MMCM_CLKOUT1_DIVIDE {12} CONFIG.MMCM_CLKOUT2_DIVIDE {24} CONFIG.MMCM_CLKOUT3_DIVIDE {48} CONFIG.MMCM_CLKOUT4_DIVIDE {96} CONFIG.NUM_OUT_CLKS {5} CONFIG.CLKOUT1_JITTER {169.111} CONFIG.CLKOUT1_PHASE_ERROR {196.976} CONFIG.CLKOUT2_JITTER {200.412} CONFIG.CLKOUT2_PHASE_ERROR {196.976} CONFIG.CLKOUT3_JITTER {247.096} CONFIG.CLKOUT3_PHASE_ERROR {196.976} CONFIG.CLKOUT4_JITTER {298.160} CONFIG.CLKOUT4_PHASE_ERROR {196.976} CONFIG.CLKOUT5_JITTER {342.201} CONFIG.CLKOUT5_PHASE_ERROR {196.976}] [get_ips OdmbClockManager]

  #create spi_cmd_fifo
  create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name spi_cmd_fifo -dir ../ip/$FPGA_TYPE
set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Builtin_FIFO} CONFIG.Performance_Options {First_Word_Fall_Through} CONFIG.Input_Data_Width {16} CONFIG.Read_Clock_Frequency {40} CONFIG.Write_Clock_Frequency {2} CONFIG.Output_Data_Width {16} CONFIG.Empty_Threshold_Assert_Value {6} CONFIG.Empty_Threshold_Negate_Value {7}] [get_ips spi_cmd_fifo]

  # Create spi_readback_fifo
  create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name spi_readback_fifo -dir ../ip/$FPGA_TYPE
  set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Builtin_FIFO} CONFIG.Input_Data_Width {16} CONFIG.Input_Depth {512} CONFIG.Read_Clock_Frequency {2} CONFIG.Write_Clock_Frequency {40} CONFIG.Output_Data_Width {16} CONFIG.Output_Depth {512} CONFIG.Data_Count_Width {9} CONFIG.Write_Data_Count_Width {9} CONFIG.Read_Data_Count_Width {9} CONFIG.Full_Threshold_Assert_Value {511} CONFIG.Full_Threshold_Negate_Value {510} CONFIG.Performance_Options {First_Word_Fall_Through} CONFIG.Empty_Threshold_Assert_Value {6} CONFIG.Empty_Threshold_Negate_Value {7}] [get_ips spi_readback_fifo]

  #create writeSpiFIFO
  create_ip -name fifo_generator -vendor xilinx.com -library ip -module_name writeSpiFIFO -dir ../ip/$FPGA_TYPE
  set_property -dict [list CONFIG.Fifo_Implementation {Independent_Clocks_Builtin_FIFO} CONFIG.Performance_Options {First_Word_Fall_Through} CONFIG.asymmetric_port_width {true} CONFIG.Input_Data_Width {16} CONFIG.Read_Clock_Frequency {40} CONFIG.Write_Clock_Frequency {40} CONFIG.Programmable_Full_Type {Single_Programmable_Full_Threshold_Constant} CONFIG.Full_Threshold_Assert_Value {64} CONFIG.Output_Data_Width {4} CONFIG.Output_Depth {8192} CONFIG.Read_Data_Count_Width {13} CONFIG.Full_Threshold_Negate_Value {63} CONFIG.Empty_Threshold_Assert_Value {4} CONFIG.Empty_Threshold_Negate_Value {5}] [get_ips writeSpiFIFO]

  puts "\[Success\] Created ip for $FPGA_TYPE"
  close_project
}
