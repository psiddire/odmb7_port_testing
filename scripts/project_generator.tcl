# In the source directory run the below command
# vivado -nojournal -nolog -mode batch -source tb_project_generator.tcl

# Environment variables
set FPGA_TYPE xcku035-ffva1156-1-c

# Generate ip
set argv $FPGA_TYPE
set argc 1
# source ip_generator.tcl

# Create project
create_project project ../project -part $FPGA_TYPE -force
set_property target_language VHDL [current_project]
set_property target_simulator XSim [current_project]

# Add ODMB source code
add_files "../source/"

# Add IP core files
add_files "../ip/xcku035-ffva1156-1-c/ibert_odmb7_gth/ibert_odmb7_gth.xci"
add_files "../ip/xcku035-ffva1156-1-c/clock_manager/clock_manager.xci"
add_files "../ip/xcku035-ffva1156-1-c/vio_top/vio_top.xci"

# Add constraint files
add_files -fileset constrs_1 "../constraints/"

# Set compile order for the constraints
set_property USED_IN_SYNTHESIS false [get_files ibert_ultrascale_gth_ip.xdc]
set_property PROCESSING_ORDER LATE [get_files ibert_ultrascale_gth_ip.xdc]

# Add helper constant from testbench
# add_files "../testbench/source/Firmware_pkg.vhd"

# set_property SOURCE_SET sources_1 [get_filesets sim_1]
# add_files -fileset sim_1 {../diagnose/}

# Set test bench as top module
set_property top ODMB7_UCSB_DEV [get_filesets sources_1]

puts "\[Success\] Created project directory"
close_project
