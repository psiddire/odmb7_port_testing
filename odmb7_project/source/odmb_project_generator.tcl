# In the source directory run the below command
# vivado -nojournal -nolog -mode batch -source odmb_project_generator.tcl

# Environment variables
set FPGA_TYPE xcku035-ffva1156-1-c

# Generate ip
set argv $FPGA_TYPE
set argc 1
source ip_generator.tcl

# Create project
create_project odmb_project ../odmb_project -part $FPGA_TYPE -force
set_property target_language VHDL [current_project]
set_property target_simulator XSim [current_project]

# Add files
add_files -norecurse "Firmware_pkg.vhd ../ip/$FPGA_TYPE/spi_readback_fifo/spi_readback_fifo.xci ../ip/$FPGA_TYPE/spi_cmd_fifo/spi_cmd_fifo.xci ../ip/$FPGA_TYPE/writeSpiFIFO/writeSpiFIFO.xci ../ip/$FPGA_TYPE/OdmbClockManager/OdmbClockManager.xci"
#add_files "vme/"
#add_files "dcfeb/"
add_files "odmb/"
add_files -fileset constrs_1 -norecurse "odmb/constraints_odmb7_ucsb_dev.xdc"

# Add tcl for simulation
set_property -name {xsim.simulate.custom_tcl} -value {Firmware_tb.tcl} -objects [get_filesets sim_1]

# add_files -norecurse "../tb_project/cfebjtag_tb_behav.wcfg"
set_property SOURCE_SET sources_1 [get_filesets sim_1]
# set_property xsim.view {my_tb_behav.wcfg my_tb_behav_1.wcfg my_tb_behav_2.wcfg} [get_filesets sim_1]

# Set test bench as top module
set_property top ODMB7_UCSB_DEV [get_filesets sources_1]
set_property top ODMB7_UCSB_DEV [get_filesets sim_1]

# Set ip as global
set_property generate_synth_checkpoint false [get_files  ../ip/$FPGA_TYPE/spi_readback_fifo/spi_readback_fifo.xci]
set_property generate_synth_checkpoint false [get_files  ../ip/$FPGA_TYPE/spi_cmd_fifo/spi_cmd_fifo.xci]
set_property generate_synth_checkpoint false [get_files  ../ip/$FPGA_TYPE/writeSpiFIFO/writeSpiFIFO.xci]
set_property generate_synth_checkpoint false [get_files  ../ip/$FPGA_TYPE/OdmbClockManager/OdmbClockManager.xci]

puts "\[Success\] Created odmb_project"
close_project
