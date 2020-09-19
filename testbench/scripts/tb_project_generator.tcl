# In the source directory run the below command
# vivado -nojournal -nolog -mode batch -source tb_project_generator.tcl

# Environment variables
set FPGA_TYPE xcku040-ffva1156-2-e

# Generate ip
set argv $FPGA_TYPE
set argc 1
# source ../../ip/ip_generator.tcl
source ip_generator.tcl

# Create project
create_project tb_project ../tb_project -part $FPGA_TYPE -force
set_property target_language VHDL [current_project]
set_property target_simulator XSim [current_project]

# Add testbench files
add_files -norecurse "Firmware_tb.vhd constants_tb.vhd ../ip/$FPGA_TYPE/clockManager/clockManager.xci ../ip/$FPGA_TYPE/ila/ila.xci ../ip/$FPGA_TYPE/lut_input1/lut_input1.xci ../ip/$FPGA_TYPE/lut_input2/lut_input2.xci"
add_files "vme/"
add_files "dcfeb/"
add_files -fileset constrs_1 -norecurse "Firmware_tb.xdc kcu_pinout.xdc "
# add_files -fileset constrs_1 -norecurse "ibert_ultrascale_gth_kcu.xdc ibert_ultrascale_gth_ip_kcu.xdc"

# Set compile order for the constraints
# set_property USED_IN_SYNTHESIS false [get_files ibert_ultrascale_gth_ip_kcu.xdc]
# set_property PROCESSING_ORDER LATE [get_files ibert_ultrascale_gth_ip_kcu.xdc]

# Add ODMB source code
add_files "../../source/"

# Add tcl for simulation
set_property -name {xsim.simulate.custom_tcl} -value {../../../source/Firmware_tb.tcl} -objects [get_filesets sim_1]

set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 {../diagnose/}

# Set test bench as top module
set_property top Firmware_tb [get_filesets sources_1]
set_property top Firmware_tb [get_filesets sim_1]

# # Set ip as global
# set_property generate_synth_checkpoint false [get_files  ../ip/$FPGA_TYPE/clockManager/clockManager.xci]
# set_property generate_synth_checkpoint false [get_files  ../ip/$FPGA_TYPE/ila/ila.xci]
# set_property generate_synth_checkpoint false [get_files  ../ip/$FPGA_TYPE/lut_input1/lut_input1.xci]
# set_property generate_synth_checkpoint false [get_files  ../ip/$FPGA_TYPE/lut_input2/lut_input2.xci]

puts "\[Success\] Created tb_project"
close_project
