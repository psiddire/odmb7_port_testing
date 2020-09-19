# file: ibert_ultrascale_gth_0.xdc
####################################################################################
##
## Input clocks setup for the time analysis
## to be synchronized with the setup from the clock synthesizer
##
####################################################################################

# Disable clock-capable IO pins
#########################
# set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets VME_AS_B_IBUF_inst/O]

# Input clock frequencies, refer to odmb7_pinouts.xdc for their location
#########################
# Clock frequency CMS_CLK_FPGA is included in the clock wizard IP
# create_clock -name cms_clk -period 25  [get_ports CMS_CLK_FPGA_P]
# set_clock_groups -group [get_clocks cms_clk -include_generated_clocks] -asynchronous

create_clock -name gp_clk_6 -period 25  [get_ports GP_CLK_6_P]
create_clock -name gp_clk_7 -period 12.5  [get_ports GP_CLK_7_P]
set_clock_groups -group [get_clocks gp_clk_6 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gp_clk_7 -include_generated_clocks] -asynchronous

# Optical refclk constraints
#########################
create_clock -name gth_refclk0_2 -period 6.25 [get_ports REF_CLK_3_P]
create_clock -name gth_refclk1_2 -period 8    [get_ports CLK_125_REF_P]
set_clock_groups -group [get_clocks gth_refclk0_2 -include_generated_clocks] -asynchronous
set_clock_groups -group [get_clocks gth_refclk1_2 -include_generated_clocks] -asynchronous

# Icon Constraints
#########################
set_property C_CLK_INPUT_FREQ_HZ 80000000 [get_debug_cores dbg_hub]
# set_property C_ENABLE_CLK_DIVIDER true [get_debug_cores dbg_hub]

