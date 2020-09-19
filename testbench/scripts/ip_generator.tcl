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
  
  # Create clockManager
  create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clockManager -dir ../ip/$FPGA_TYPE
  set_property -dict [list CONFIG.PRIM_IN_FREQ {300} CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT3_USED {true} CONFIG.CLKOUT4_USED {true} CONFIG.PRIMARY_PORT {clk_in300} CONFIG.CLK_OUT1_PORT {clk_out40} CONFIG.CLK_OUT2_PORT {clk_out10} CONFIG.CLK_OUT3_PORT {clk_out80} CONFIG.CLK_OUT4_PORT {clk_out160} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {40} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {10} CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {80.000} CONFIG.CLKOUT4_REQUESTED_OUT_FREQ {160.000} CONFIG.USE_LOCKED {false} CONFIG.USE_RESET {false} CONFIG.CLKIN1_JITTER_PS {33.330000000000005} CONFIG.MMCM_DIVCLK_DIVIDE {5} CONFIG.MMCM_CLKIN1_PERIOD {3.333} CONFIG.MMCM_CLKIN2_PERIOD {10.0} CONFIG.MMCM_CLKFBOUT_MULT_F {16.000} CONFIG.MMCM_CLKOUT0_DIVIDE_F {24.000} CONFIG.MMCM_CLKOUT1_DIVIDE {96} CONFIG.MMCM_CLKOUT2_DIVIDE {12} CONFIG.MMCM_CLKOUT3_DIVIDE {6} CONFIG.NUM_OUT_CLKS {4} CONFIG.CLKOUT1_JITTER {155.514} CONFIG.CLKOUT2_JITTER {203.128} CONFIG.CLKOUT2_PHASE_ERROR {98.575} CONFIG.CLKOUT3_JITTER {129.666} CONFIG.CLKOUT3_PHASE_ERROR {98.575} CONFIG.CLKOUT4_JITTER {135.961} CONFIG.CLKOUT4_PHASE_ERROR {121.733} CONFIG.CLKOUT1_DRIVES {BUFG} CONFIG.CLKOUT2_DRIVES {BUFG} CONFIG.CLKOUT3_DRIVES {BUFG} CONFIG.CLKOUT4_DRIVES {BUFG} CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} CONFIG.CLKOUT1_MATCHED_ROUTING {true} CONFIG.CLKOUT2_MATCHED_ROUTING {true} CONFIG.CLKOUT3_MATCHED_ROUTING {true} CONFIG.CLKOUT4_MATCHED_ROUTING {true} CONFIG.PRIM_SOURCE {No_buffer}] [get_ips clockManager]
 
  # Create ila
  create_ip -name ila -vendor xilinx.com -library ip -module_name ila -dir ../ip/$FPGA_TYPE
  set_property -dict [list CONFIG.C_PROBE1_TYPE {1} CONFIG.C_PROBE0_TYPE {2} CONFIG.C_PROBE1_WIDTH {4096} CONFIG.C_PROBE0_WIDTH {256} CONFIG.C_NUM_OF_PROBES {2} CONFIG.ALL_PROBE_SAME_MU {false}] [get_ips ila]
  
  # Create lut_input1
  create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name lut_input1 -dir ../ip/$FPGA_TYPE
  set_property -dict [list CONFIG.Memory_Type {Single_Port_ROM} CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {16} CONFIG.Enable_A {Always_Enabled} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Load_Init_File {true} CONFIG.Coe_File {../../../source/data/Input1.coe} CONFIG.Read_Width_A {16} CONFIG.Write_Width_B {16} CONFIG.Read_Width_B {16} CONFIG.Port_A_Write_Rate {0}] [get_ips lut_input1]
  #set_property -dict [list CONFIG.Memory_Type {Single_Port_ROM} CONFIG.Write_Width_A {12} CONFIG.Write_Depth_A {128} CONFIG.Enable_A {Always_Enabled} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Load_Init_File {true} CONFIG.Coe_File {../../../source/data/Input1.coe} CONFIG.Read_Width_A {12} CONFIG.Write_Width_B {12} CONFIG.Read_Width_B {12} CONFIG.Port_A_Write_Rate {0}] [get_ips lut_input1]
  #set_property -dict [list CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {8} CONFIG.Read_Width_A {16} CONFIG.Write_Width_B {16} CONFIG.Read_Width_B {16}] [get_ips lut_input1]
  
  # Create lut_input2
  create_ip -name blk_mem_gen -vendor xilinx.com -library ip -module_name lut_input2 -dir ../ip/$FPGA_TYPE
  set_property -dict [list CONFIG.Memory_Type {Single_Port_ROM} CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {16} CONFIG.Enable_A {Always_Enabled} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Load_Init_File {true} CONFIG.Coe_File {../../../source/data/Input2.coe} CONFIG.Read_Width_A {16} CONFIG.Write_Width_B {16} CONFIG.Read_Width_B {16} CONFIG.Port_A_Write_Rate {0}] [get_ips lut_input2]
  #set_property -dict [list CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {8} CONFIG.Read_Width_A {16} CONFIG.Write_Width_B {16} CONFIG.Read_Width_B {16}] [get_ips lut_input2]
  #set_property -dict [list CONFIG.Memory_Type {Single_Port_ROM} CONFIG.Write_Width_A {12} CONFIG.Write_Depth_A {128} CONFIG.Enable_A {Always_Enabled} CONFIG.Register_PortA_Output_of_Memory_Primitives {false} CONFIG.Load_Init_File {true} CONFIG.Coe_File {../../../source/data/Input2.coe} CONFIG.Read_Width_A {12} CONFIG.Write_Width_B {12} CONFIG.Read_Width_B {12} CONFIG.Port_A_Write_Rate {0}] [get_ips lut_input2]
  #set_property -dict [list CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {8} CONFIG.Read_Width_A {16} CONFIG.Write_Width_B {16} CONFIG.Read_Width_B {16}] [get_ips lut_input2]

  create_ip -name ibert_ultrascale_gth -vendor xilinx.com -library ip -version 1.4 -module_name ibert_kcu_gth -dir ../ip/$FPGA_TYPE
  set_property -dict [list CONFIG.C_SYSCLK_FREQUENCY {156.25} CONFIG.C_SYSCLK_IO_PIN_LOC_N {UNASSIGNED} CONFIG.C_SYSCLK_IO_PIN_LOC_P {UNASSIGNED} CONFIG.C_SYSCLK_IS_DIFF {0} CONFIG.C_SYSCLK_IO_PIN_STD {LVCMOS18} CONFIG.C_SYSCLK_MODE_EXTERNAL {0} CONFIG.C_SYSCLOCK_SOURCE_INT {QUAD227_0} CONFIG.C_RXOUTCLK_FREQUENCY {250.0} CONFIG.C_RXOUTCLK_GT_LOCATION {QUAD225_0} CONFIG.C_REFCLK_SOURCE_QUAD_4 {MGTREFCLK0_227} CONFIG.C_REFCLK_SOURCE_QUAD_3 {MGTREFCLK0_227} CONFIG.C_REFCLK_SOURCE_QUAD_2 {MGTREFCLK0_227} CONFIG.C_REFCLK_SOURCE_QUAD_1 {MGTREFCLK0_227} CONFIG.C_REFCLK_SOURCE_QUAD_0 {None} CONFIG.C_PROTOCOL_QUAD4 {Custom_1_/_10_Gbps} CONFIG.C_PROTOCOL_QUAD3 {Custom_1_/_10_Gbps} CONFIG.C_PROTOCOL_QUAD2 {Custom_1_/_10_Gbps} CONFIG.C_PROTOCOL_QUAD1 {Custom_1_/_10_Gbps} CONFIG.C_PROTOCOL_QUAD0 {None} CONFIG.C_GT_CORRECT {true} CONFIG.C_PROTOCOL_QUAD_COUNT_1 {4} CONFIG.C_PROTOCOL_REFCLK_FREQUENCY_1 {156.25} CONFIG.C_PROTOCOL_MAXLINERATE_1 {10}] [get_ips ibert_kcu_gth]


  puts "\[Success\] Created ip for $FPGA_TYPE"
  close_project
}
