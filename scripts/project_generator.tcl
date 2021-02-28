# In the source directory run the below command
# vivado -nojournal -nolog -mode batch -source project_generator.tcl

# Environment variables
set BOARD ODMB7
set FPGA_TYPE xcku035-ffva1156-1-c

set TOP_MODULE "odmb7_ucsb_dev"
set PROJECT_NAME project

# Generate ip
set argv $FPGA_TYPE
set argc 1
# create ip project when needed
# source ip_generator.tcl

# Create project
create_project $TOP_MODULE ../$PROJECT_NAME -part $FPGA_TYPE -force

set_property target_language VHDL [current_project]
set_property target_simulator XSim [current_project]

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# set_property generic $TOP_GENERIC [current_fileset]

# Add the top file and supporting sources
add_files -norecurse "../source/odmb7_ucsb_dev.vhd"
add_files -norecurse "../source/utils/package_ucsb_types.vhd"
add_files "../source/odmb_vme"
add_files "../source/odmb_ctrl"
# add_files -norecurse "../source/odmb7_clocking.vhd"

# Add common IP core configurations
add_files -norecurse "../ip/clockManager/clockManager.xci"

# Add common constraint files
add_files -fileset constrs_1 -norecurse "../constraints/odmb7_pinout.xdc"
add_files -fileset constrs_1 -norecurse "../constraints/odmb7_clocks.xdc"
add_files -fileset constrs_1 -norecurse "../constraints/odmb7_config.xdc"

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property -name "top" -value $TOP_MODULE -objects $obj
set_property -name "top_auto_set" -value "0" -objects $obj

# Set ip as global
set_property generate_synth_checkpoint false [get_files  ../ip/clockManager/clockManager.xci]

puts "\[Success\] Created project"
close_project
