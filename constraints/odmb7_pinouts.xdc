# ----------------------------------------------------------------------------------------------------------------------
# ODMB7 UltraScale FPGA Pinout XDC file
# ----------------------------------------------------------------------------------------------------------------------
# Location constraints for differential reference clock buffers
# Note: the IP core-level XDC constrains the transceiver channel data pin locations
# ----------------------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------------------
# Clock pins
# ----------------------------------------------------------------------------------------------------------------------

# System clocks
set_property package_pin AK17 [get_ports CMS_CLK_FPGA_P]
set_property package_pin AK16 [get_ports CMS_CLK_FPGA_N]
set_property IOSTANDARD LVDS  [get_ports CMS_CLK_FPGA_P]
set_property IOSTANDARD LVDS  [get_ports CMS_CLK_FPGA_N]

set_property package_pin AK22 [get_ports GP_CLK_6_P]
set_property package_pin AK23 [get_ports GP_CLK_6_N]
set_property IOSTANDARD LVDS  [get_ports GP_CLK_6_P]
set_property IOSTANDARD LVDS  [get_ports GP_CLK_6_N]

set_property package_pin E18  [get_ports GP_CLK_7_P]
set_property package_pin E17  [get_ports GP_CLK_7_N]
set_property IOSTANDARD LVDS  [get_ports GP_CLK_7_P]
set_property IOSTANDARD LVDS  [get_ports GP_CLK_7_N]

# Optical reference clocks
set_property package_pin AF6 [get_ports REF_CLK_1_P]
set_property package_pin AF5 [get_ports REF_CLK_1_N]
set_property package_pin P6  [get_ports REF_CLK_2_P]
set_property package_pin P5  [get_ports REF_CLK_2_N]
set_property package_pin V6  [get_ports REF_CLK_3_P]
set_property package_pin V5  [get_ports REF_CLK_3_N]
set_property package_pin AB6 [get_ports REF_CLK_4_P]
set_property package_pin AB5 [get_ports REF_CLK_4_N]
set_property package_pin M6  [get_ports REF_CLK_5_P]
set_property package_pin M5  [get_ports REF_CLK_5_N]
set_property package_pin T6  [get_ports CLK_125_REF_P]
set_property package_pin T5  [get_ports CLK_125_REF_N]

# ----------------------------------------------------------------------------------------------------------------------
# VME Communication
# ----------------------------------------------------------------------------------------------------------------------
set_property package_pin    V31         [get_ports VME_DATA[0]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[0]]
set_property package_pin    W31         [get_ports VME_DATA[1]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[1]]
set_property package_pin    V32         [get_ports VME_DATA[2]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[2]]
set_property package_pin    U34         [get_ports VME_DATA[3]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[3]]
set_property package_pin    V34         [get_ports VME_DATA[4]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[4]]
set_property package_pin    Y31         [get_ports VME_DATA[5]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[5]]
set_property package_pin    Y32         [get_ports VME_DATA[6]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[6]]
set_property package_pin    V33         [get_ports VME_DATA[7]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[7]]
set_property package_pin    W34         [get_ports VME_DATA[8]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[8]]
set_property package_pin    W30         [get_ports VME_DATA[9]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[9]]
set_property package_pin    Y30         [get_ports VME_DATA[10]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[10]]
set_property package_pin    W33         [get_ports VME_DATA[11]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[11]]
set_property package_pin    Y33         [get_ports VME_DATA[12]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[12]]
set_property package_pin    AC33        [get_ports VME_DATA[13]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[13]]
set_property package_pin    AD33        [get_ports VME_DATA[14]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[14]]
set_property package_pin    AA34        [get_ports VME_DATA[15]]
set_property IOSTANDARD     LVCMOS18    [get_ports VME_DATA[15]]

set_property PACKAGE_PIN     AK30       [get_ports VME_ADDR[1]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[1]]
set_property PACKAGE_PIN     AL30       [get_ports VME_ADDR[2]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[2]]
set_property PACKAGE_PIN     AM30       [get_ports VME_ADDR[3]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[3]]
set_property PACKAGE_PIN     AM31       [get_ports VME_ADDR[4]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[4]]
set_property PACKAGE_PIN     AL29       [get_ports VME_ADDR[5]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[5]]
set_property PACKAGE_PIN     AM29       [get_ports VME_ADDR[6]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[6]]
set_property PACKAGE_PIN     AN29       [get_ports VME_ADDR[7]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[7]]
set_property PACKAGE_PIN     AP30       [get_ports VME_ADDR[8]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[8]]
set_property PACKAGE_PIN     AN27       [get_ports VME_ADDR[9]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[9]]
set_property PACKAGE_PIN     AN28       [get_ports VME_ADDR[10]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[10]]
set_property PACKAGE_PIN     AP28       [get_ports VME_ADDR[11]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[11]]
set_property PACKAGE_PIN     AP29       [get_ports VME_ADDR[12]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[12]]
set_property PACKAGE_PIN     AN26       [get_ports VME_ADDR[13]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[13]]
set_property PACKAGE_PIN     AP26       [get_ports VME_ADDR[14]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[14]]
set_property PACKAGE_PIN     AJ28       [get_ports VME_ADDR[15]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[15]]
set_property PACKAGE_PIN     AK28       [get_ports VME_ADDR[16]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[16]]
set_property PACKAGE_PIN     AH27       [get_ports VME_ADDR[17]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[17]]
set_property PACKAGE_PIN     AH28       [get_ports VME_ADDR[18]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[18]]
set_property PACKAGE_PIN     AL27       [get_ports VME_ADDR[19]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[19]]
set_property PACKAGE_PIN     AL28       [get_ports VME_ADDR[20]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[20]]
set_property PACKAGE_PIN     AK26       [get_ports VME_ADDR[21]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[21]]
set_property PACKAGE_PIN     AK27       [get_ports VME_ADDR[22]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[22]]
set_property PACKAGE_PIN     AM26       [get_ports VME_ADDR[23]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_ADDR[23]]

set_property PACKAGE_PIN     AL33       [get_ports VME_AM[0]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_AM[0]]
set_property PACKAGE_PIN     AH34       [get_ports VME_AM[1]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_AM[1]]
set_property PACKAGE_PIN     AJ34       [get_ports VME_AM[2]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_AM[2]]
set_property PACKAGE_PIN     AH31       [get_ports VME_AM[3]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_AM[3]]
set_property PACKAGE_PIN     AH32       [get_ports VME_AM[4]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_AM[4]]
set_property PACKAGE_PIN     AH33       [get_ports VME_AM[5]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_AM[5]]

set_property PACKAGE_PIN     AB34       [get_ports VME_GAP_B]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_GAP_B]

set_property PACKAGE_PIN     AB30       [get_ports VME_GA_B[0]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_GA_B[0]]
set_property PACKAGE_PIN     AD34       [get_ports VME_GA_B[1]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_GA_B[1]]
set_property PACKAGE_PIN     AC34       [get_ports VME_GA_B[2]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_GA_B[2]]
set_property PACKAGE_PIN     AB29       [get_ports VME_GA_B[3]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_GA_B[3]]
set_property PACKAGE_PIN     AA29       [get_ports VME_GA_B[4]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_GA_B[4]]

set_property PACKAGE_PIN     AJ31       [get_ports VME_AS_B]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_AS_B]

set_property PACKAGE_PIN     AJ30       [get_ports VME_DS_B[0]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_DS_B[0]]
set_property PACKAGE_PIN     AJ33       [get_ports VME_DS_B[1]]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_DS_B[1]]

set_property PACKAGE_PIN     AC32       [get_ports VME_SYSFAIL_B]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_SYSFAIL_B]

set_property PACKAGE_PIN     AB32       [get_ports VME_BERR_B]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_BERR_B]

set_property PACKAGE_PIN     AB31       [get_ports VME_IACK_B]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_IACK_B]

set_property PACKAGE_PIN     AA32       [get_ports VME_LWORD_B]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_LWORD_B]

set_property PACKAGE_PIN     AA33       [get_ports VME_WRITE_B]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_WRITE_B]

set_property PACKAGE_PIN     AN23       [get_ports KUS_VME_OE_B]
set_property IOSTANDARD      LVCMOS18   [get_ports KUS_VME_OE_B]

set_property PACKAGE_PIN     AP23       [get_ports KUS_VME_DIR_B]
set_property IOSTANDARD      LVCMOS18   [get_ports KUS_VME_DIR_B]

set_property PACKAGE_PIN     AM25       [get_ports VME_DTACK_KUS_B]
set_property IOSTANDARD      LVCMOS18   [get_ports VME_DTACK_KUS_B]

# ----------------------------------------------------------------------------------------------------------------------
# DCFEB (PPIB) Communication
# ----------------------------------------------------------------------------------------------------------------------
set_property PACKAGE_PIN     F15    [get_ports DCFEB_TCK_P[1]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_P[1]]
set_property PACKAGE_PIN     F14    [get_ports DCFEB_TCK_N[1]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_N[1]]
set_property PACKAGE_PIN     D19    [get_ports DCFEB_TCK_P[2]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_P[2]]
set_property PACKAGE_PIN     D18    [get_ports DCFEB_TCK_N[2]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_N[2]]
set_property PACKAGE_PIN     D14    [get_ports DCFEB_TCK_P[3]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_P[3]]
set_property PACKAGE_PIN     C14    [get_ports DCFEB_TCK_N[3]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_N[3]]
set_property PACKAGE_PIN     E15    [get_ports DCFEB_TCK_P[4]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_P[4]]
set_property PACKAGE_PIN     D15    [get_ports DCFEB_TCK_N[4]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_N[4]]
set_property PACKAGE_PIN     B17    [get_ports DCFEB_TCK_P[5]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_P[5]]
set_property PACKAGE_PIN     B16    [get_ports DCFEB_TCK_N[5]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_N[5]]
set_property PACKAGE_PIN     C18    [get_ports DCFEB_TCK_P[6]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_P[6]]
set_property PACKAGE_PIN     C17    [get_ports DCFEB_TCK_N[6]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_N[6]]
set_property PACKAGE_PIN     C19    [get_ports DCFEB_TCK_P[7]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_P[7]]
set_property PACKAGE_PIN     B19    [get_ports DCFEB_TCK_N[7]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TCK_N[7]]

set_property PACKAGE_PIN     A19    [get_ports DCFEB_TMS_P]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TMS_P]
set_property PACKAGE_PIN     A18    [get_ports DCFEB_TMS_N]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TMS_N]

set_property PACKAGE_PIN     B14    [get_ports DCFEB_TDI_P]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDI_P]
set_property PACKAGE_PIN     A14    [get_ports DCFEB_TDI_N]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDI_N]

set_property PACKAGE_PIN     F23    [get_ports DCFEB_TDO_P[1]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_P[1]]
set_property PACKAGE_PIN     F24    [get_ports DCFEB_TDO_N[1]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_N[1]]
set_property PACKAGE_PIN     D20    [get_ports DCFEB_TDO_P[2]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_P[2]]
set_property PACKAGE_PIN     D21    [get_ports DCFEB_TDO_N[2]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_N[2]]
set_property PACKAGE_PIN     G20    [get_ports DCFEB_TDO_P[3]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_P[3]]
set_property PACKAGE_PIN     F20    [get_ports DCFEB_TDO_N[3]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_N[3]]
set_property PACKAGE_PIN     G24    [get_ports DCFEB_TDO_P[4]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_P[4]]
set_property PACKAGE_PIN     F25    [get_ports DCFEB_TDO_N[4]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_N[4]]
set_property PACKAGE_PIN     G22    [get_ports DCFEB_TDO_P[5]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_P[5]]
set_property PACKAGE_PIN     F22    [get_ports DCFEB_TDO_N[5]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_N[5]]
set_property PACKAGE_PIN     E20    [get_ports DCFEB_TDO_P[6]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_P[6]]
set_property PACKAGE_PIN     E21    [get_ports DCFEB_TDO_N[6]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_N[6]]
set_property PACKAGE_PIN     J19    [get_ports DCFEB_TDO_P[7]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_P[7]]
set_property PACKAGE_PIN     J18    [get_ports DCFEB_TDO_N[7]]
set_property IOSTANDARD      LVDS   [get_ports DCFEB_TDO_N[7]]

set_property PACKAGE_PIN     G19        [get_ports DCFEB_DONE[1]]
set_property IOSTANDARD      LVCMOS18   [get_ports DCFEB_DONE[1]]
set_property PACKAGE_PIN     F19        [get_ports DCFEB_DONE[2]]
set_property IOSTANDARD      LVCMOS18   [get_ports DCFEB_DONE[2]]
set_property PACKAGE_PIN     G15        [get_ports DCFEB_DONE[3]]
set_property IOSTANDARD      LVCMOS18   [get_ports DCFEB_DONE[3]]
set_property PACKAGE_PIN     G14        [get_ports DCFEB_DONE[4]]
set_property IOSTANDARD      LVCMOS18   [get_ports DCFEB_DONE[4]]
set_property PACKAGE_PIN     F18        [get_ports DCFEB_DONE[5]]
set_property IOSTANDARD      LVCMOS18   [get_ports DCFEB_DONE[5]]
set_property PACKAGE_PIN     F17        [get_ports DCFEB_DONE[6]]
set_property IOSTANDARD      LVCMOS18   [get_ports DCFEB_DONE[6]]
set_property PACKAGE_PIN     H14        [get_ports DCFEB_DONE[7]]
set_property IOSTANDARD      LVCMOS18   [get_ports DCFEB_DONE[7]]

set_property PACKAGE_PIN     B15    [get_ports BC0_P]
set_property IOSTANDARD      LVDS   [get_ports BC0_P]
set_property PACKAGE_PIN     A15    [get_ports BC0_N]
set_property IOSTANDARD      LVDS   [get_ports BC0_N]

set_property PACKAGE_PIN     E10    [get_ports INJPLS_P]
set_property IOSTANDARD      LVDS   [get_ports INJPLS_P]
set_property PACKAGE_PIN     D10    [get_ports INJPLS_N]
set_property IOSTANDARD      LVDS   [get_ports INJPLS_N]
set_property PACKAGE_PIN     B10    [get_ports EXTPLS_P]
set_property IOSTANDARD      LVDS   [get_ports EXTPLS_P]
set_property PACKAGE_PIN     A10    [get_ports EXTPLS_N]
set_property IOSTANDARD      LVDS   [get_ports EXTPLS_N]
set_property PACKAGE_PIN     D8     [get_ports RESYNC_P]
set_property IOSTANDARD      LVDS   [get_ports RESYNC_P]
set_property PACKAGE_PIN     C8     [get_ports RESYNC_N]
set_property IOSTANDARD      LVDS   [get_ports RESYNC_N]
set_property PACKAGE_PIN     B9     [get_ports L1A_P]
set_property IOSTANDARD      LVDS   [get_ports L1A_P]
set_property PACKAGE_PIN     A9     [get_ports L1A_N]
set_property IOSTANDARD      LVDS   [get_ports L1A_N]
set_property PACKAGE_PIN     L8     [get_ports L1A_MATCH_P[1]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_P[1]]
set_property PACKAGE_PIN     K8     [get_ports L1A_MATCH_N[1]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_N[1]]
set_property PACKAGE_PIN     D13    [get_ports L1A_MATCH_P[2]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_P[2]]
set_property PACKAGE_PIN     C13    [get_ports L1A_MATCH_N[2]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_N[2]]
set_property PACKAGE_PIN     A13    [get_ports L1A_MATCH_P[3]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_P[3]]
set_property PACKAGE_PIN     A12    [get_ports L1A_MATCH_N[3]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_N[3]]
set_property PACKAGE_PIN     F13    [get_ports L1A_MATCH_P[4]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_P[4]]
set_property PACKAGE_PIN     E13    [get_ports L1A_MATCH_N[4]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_N[4]]
set_property PACKAGE_PIN     C11    [get_ports L1A_MATCH_P[5]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_P[5]]
set_property PACKAGE_PIN     B11    [get_ports L1A_MATCH_N[5]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_N[5]]
set_property PACKAGE_PIN     C12    [get_ports L1A_MATCH_P[6]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_P[6]]
set_property PACKAGE_PIN     B12    [get_ports L1A_MATCH_N[6]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_N[6]]
set_property PACKAGE_PIN     E11    [get_ports L1A_MATCH_P[7]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_P[7]]
set_property PACKAGE_PIN     D11    [get_ports L1A_MATCH_N[7]]
set_property IOSTANDARD      LVDS   [get_ports L1A_MATCH_N[7]]


# ----------------------------------------------------------------------------------------------------------------------
# LVMB Communication
# ----------------------------------------------------------------------------------------------------------------------
set_property PACKAGE_PIN     B24        [get_ports LVMB_PON[0]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_PON[0]]
set_property PACKAGE_PIN     A24        [get_ports LVMB_PON[1]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_PON[1]]
set_property PACKAGE_PIN     C26        [get_ports LVMB_PON[2]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_PON[2]]
set_property PACKAGE_PIN     B26        [get_ports LVMB_PON[3]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_PON[3]]
set_property PACKAGE_PIN     B25        [get_ports LVMB_PON[4]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_PON[4]]
set_property PACKAGE_PIN     A25        [get_ports LVMB_PON[5]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_PON[5]]
set_property PACKAGE_PIN     A27        [get_ports LVMB_PON[6]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_PON[6]]
set_property PACKAGE_PIN     A28        [get_ports LVMB_PON[7]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_PON[7]]

set_property PACKAGE_PIN     C24        [get_ports PON_LOAD]
set_property IOSTANDARD      LVCMOS18   [get_ports PON_LOAD]

set_property PACKAGE_PIN     A23        [get_ports PON_OE_B]
set_property IOSTANDARD      LVCMOS18   [get_ports PON_OE_B]

set_property PACKAGE_PIN     C28        [get_ports LVMB_CSB[0]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_CSB[0]]
set_property PACKAGE_PIN     B29        [get_ports LVMB_CSB[1]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_CSB[1]]
set_property PACKAGE_PIN     A29        [get_ports LVMB_CSB[2]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_CSB[2]]
set_property PACKAGE_PIN     D29        [get_ports LVMB_CSB[3]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_CSB[3]]
set_property PACKAGE_PIN     C27        [get_ports LVMB_CSB[4]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_CSB[4]]
set_property PACKAGE_PIN     B27        [get_ports LVMB_CSB[5]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_CSB[5]]
set_property PACKAGE_PIN     C29        [get_ports LVMB_CSB[6]]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_CSB[6]]

set_property PACKAGE_PIN     A20        [get_ports MON_LVMB_PON[0]]
set_property IOSTANDARD      LVCMOS18   [get_ports MON_LVMB_PON[0]]
set_property PACKAGE_PIN     C21        [get_ports MON_LVMB_PON[1]]
set_property IOSTANDARD      LVCMOS18   [get_ports MON_LVMB_PON[1]]
set_property PACKAGE_PIN     C22        [get_ports MON_LVMB_PON[2]]
set_property IOSTANDARD      LVCMOS18   [get_ports MON_LVMB_PON[2]]
set_property PACKAGE_PIN     B21        [get_ports MON_LVMB_PON[3]]
set_property IOSTANDARD      LVCMOS18   [get_ports MON_LVMB_PON[3]]
set_property PACKAGE_PIN     B22        [get_ports MON_LVMB_PON[4]]
set_property IOSTANDARD      LVCMOS18   [get_ports MON_LVMB_PON[4]]
set_property PACKAGE_PIN     A22        [get_ports MON_LVMB_PON[5]]
set_property IOSTANDARD      LVCMOS18   [get_ports MON_LVMB_PON[5]]
set_property PACKAGE_PIN     D23        [get_ports MON_LVMB_PON[6]]
set_property IOSTANDARD      LVCMOS18   [get_ports MON_LVMB_PON[6]]
set_property PACKAGE_PIN     C23        [get_ports MON_LVMB_PON[7]]
set_property IOSTANDARD      LVCMOS18   [get_ports MON_LVMB_PON[7]]

set_property PACKAGE_PIN     L19        [get_ports LVMB_SCLK]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_SCLK]

set_property PACKAGE_PIN     L18        [get_ports LVMB_SDIN]
set_property IOSTANDARD      LVCMOS18   [get_ports LVMB_SDIN]

#set_property PACKAGE_PIN    H21        [get_ports LVMB_SDOUT_P]
#set_property IOSTANDARD     LVDS       [get_ports LVMB_SDOUT_P]
#set_property PACKAGE_PIN    G21        [get_ports LVMB_SDOUT_N]
#set_property IOSTANDARD     LVDS       [get_ports LVMB_SDOUT_N]

# ----------------------------------------------------------------------------------------------------------------------
# Optical TX/RX pins
# ----------------------------------------------------------------------------------------------------------------------
set_property package_pin AP2 [get_ports  DAQ_RX_P[0]]
set_property package_pin AP1 [get_ports  DAQ_RX_N[0]]
set_property package_pin AM2 [get_ports  DAQ_RX_P[1]]
set_property package_pin AM1 [get_ports  DAQ_RX_N[1]]
set_property package_pin AK2 [get_ports  DAQ_RX_P[2]]
set_property package_pin AK1 [get_ports  DAQ_RX_N[2]]
set_property package_pin AJ4 [get_ports  DAQ_RX_P[3]]
set_property package_pin AJ3 [get_ports  DAQ_RX_N[3]]
set_property package_pin AH2 [get_ports  DAQ_RX_P[4]]
set_property package_pin AH1 [get_ports  DAQ_RX_N[4]]
set_property package_pin AF2 [get_ports  DAQ_RX_P[5]]
set_property package_pin AF1 [get_ports  DAQ_RX_N[5]]
set_property package_pin AD2 [get_ports  DAQ_RX_P[6]]
set_property package_pin AD1 [get_ports  DAQ_RX_N[6]]
set_property package_pin AB2 [get_ports  DAQ_RX_P[7]]
set_property package_pin AB1 [get_ports  DAQ_RX_N[7]]
set_property package_pin Y2  [get_ports  DAQ_RX_P[8]]
set_property package_pin Y1  [get_ports  DAQ_RX_N[8]]
set_property package_pin V2  [get_ports  DAQ_RX_P[9]]
set_property package_pin V1  [get_ports  DAQ_RX_N[9]]
set_property package_pin T2  [get_ports  DAQ_RX_P[10]]
set_property package_pin T1  [get_ports  DAQ_RX_N[10]]
set_property package_pin P2  [get_ports  DAQ_SPY_RX_P]
set_property package_pin P1  [get_ports  DAQ_SPY_RX_N]
set_property package_pin N4  [get_ports  DAQ_TX_P[1]]
set_property package_pin N3  [get_ports  DAQ_TX_N[1]]
set_property package_pin L4  [get_ports  DAQ_TX_P[2]]
set_property package_pin L3  [get_ports  DAQ_TX_N[2]]
set_property package_pin J4  [get_ports  DAQ_TX_P[3]]
set_property package_pin J3  [get_ports  DAQ_TX_N[3]]
set_property package_pin G4  [get_ports  DAQ_TX_P[4]]
set_property package_pin G3  [get_ports  DAQ_TX_N[4]]
set_property package_pin M2  [get_ports  BCK_PRS_P]
set_property package_pin M1  [get_ports  BCK_PRS_N]
set_property package_pin K2  [get_ports  B04_RX_P[2]]
set_property package_pin K1  [get_ports  B04_RX_N[2]]
set_property package_pin H2  [get_ports  B04_RX_P[3]]
set_property package_pin H1  [get_ports  B04_RX_N[3]]
set_property package_pin F2  [get_ports  B04_RX_P[4]]
set_property package_pin F1  [get_ports  B04_RX_N[4]]
set_property package_pin R4  [get_ports  SPY_TX_P]
set_property package_pin R3  [get_ports  SPY_TX_N]

# ----------------------------------------------------------------------------------------------------------------------
# Optical control pins
# ----------------------------------------------------------------------------------------------------------------------
set_property package_pin  E12      [get_ports DAQ_SPY_SEL]
set_property IOSTANDARD   LVCMOS18 [get_ports DAQ_SPY_SEL]

set_property package_pin  K11      [get_ports RX12_I2C_ENA]
set_property IOSTANDARD   LVCMOS18 [get_ports RX12_I2C_ENA]
set_property package_pin  J11      [get_ports RX12_SDA]
set_property IOSTANDARD   LVCMOS18 [get_ports RX12_SDA]
set_property package_pin  H12      [get_ports RX12_SCL]
set_property IOSTANDARD   LVCMOS18 [get_ports RX12_SCL]
set_property package_pin  G12      [get_ports RX12_CS_B]
set_property IOSTANDARD   LVCMOS18 [get_ports RX12_CS_B]
set_property package_pin  F12      [get_ports RX12_RST_B]
set_property IOSTANDARD   LVCMOS18 [get_ports RX12_RST_B]
set_property package_pin  G9       [get_ports RX12_INT_B]
set_property IOSTANDARD   LVCMOS18 [get_ports RX12_INT_B]
set_property package_pin  F9       [get_ports RX12_PRESENT_B]
set_property IOSTANDARD   LVCMOS18 [get_ports RX12_PRESENT_B]

set_property package_pin  J13      [get_ports TX12_I2C_ENA]
set_property IOSTANDARD   LVCMOS18 [get_ports TX12_I2C_ENA]
set_property package_pin  H13      [get_ports TX12_SDA]
set_property IOSTANDARD   LVCMOS18 [get_ports TX12_SDA]
set_property package_pin  L12      [get_ports TX12_SCL]
set_property IOSTANDARD   LVCMOS18 [get_ports TX12_SCL]
set_property package_pin  G10      [get_ports TX12_CS_B]
set_property IOSTANDARD   LVCMOS18 [get_ports TX12_CS_B]
set_property package_pin  F10      [get_ports TX12_RST_B]
set_property IOSTANDARD   LVCMOS18 [get_ports TX12_RST_B]
set_property package_pin  J8       [get_ports TX12_INT_B]
set_property IOSTANDARD   LVCMOS18 [get_ports TX12_INT_B]
set_property package_pin  H8       [get_ports TX12_PRESENT_B]
set_property IOSTANDARD   LVCMOS18 [get_ports TX12_PRESENT_B]

set_property package_pin  K12      [get_ports B04_I2C_ENA]
set_property IOSTANDARD   LVCMOS18 [get_ports B04_I2C_ENA]
set_property package_pin  L13      [get_ports B04_SDA]
set_property IOSTANDARD   LVCMOS18 [get_ports B04_SDA]
set_property package_pin  K13      [get_ports B04_SCL]
set_property IOSTANDARD   LVCMOS18 [get_ports B04_SCL]
set_property package_pin  H11      [get_ports B04_CS_B]
set_property IOSTANDARD   LVCMOS18 [get_ports B04_CS_B]
set_property package_pin  G11      [get_ports B04_RST_B]
set_property IOSTANDARD   LVCMOS18 [get_ports B04_RST_B]
set_property package_pin  K10      [get_ports B04_INT_B]
set_property IOSTANDARD   LVCMOS18 [get_ports B04_INT_B]
set_property package_pin  J10      [get_ports B04_PRESENT_B]
set_property IOSTANDARD   LVCMOS18 [get_ports B04_PRESENT_B]

set_property package_pin  A8       [get_ports SPY_I2C_ENA]
set_property IOSTANDARD   LVCMOS18 [get_ports SPY_I2C_ENA]
set_property package_pin  H9       [get_ports SPY_SDA]
set_property IOSTANDARD   LVCMOS18 [get_ports SPY_SDA]
set_property package_pin  J9       [get_ports SPY_SCL]
set_property IOSTANDARD   LVCMOS18 [get_ports SPY_SCL]
set_property package_pin  F8       [get_ports SPY_SD]
set_property IOSTANDARD   LVCMOS18 [get_ports SPY_SD]
set_property package_pin  E8       [get_ports SPY_TDIS]
set_property IOSTANDARD   LVCMOS18 [get_ports SPY_TDIS]

