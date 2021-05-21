library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

use work.ucsb_types.all;

entity odmb7_ucsb_dev is
  port (
    --------------------
    -- Input clocks
    --------------------
    CMS_CLK_FPGA_P : in std_logic;      -- system clock: 40.07897 MHz
    CMS_CLK_FPGA_N : in std_logic;      -- system clock: 40.07897 MHz
    GP_CLK_6_P : in std_logic;          -- clock synthesizer ODIV6: 80 MHz
    GP_CLK_6_N : in std_logic;          -- clock synthesizer ODIV6: 80 MHz
    GP_CLK_7_P : in std_logic;          -- clock synthesizer ODIV7: 80 MHz
    GP_CLK_7_N : in std_logic;          -- clock synthesizer ODIV7: 80 MHz
    REF_CLK_1_P : in std_logic;         -- refclk0 to 224
    REF_CLK_1_N : in std_logic;         -- refclk0 to 224
    REF_CLK_2_P : in std_logic;         -- refclk0 to 227
    REF_CLK_2_N : in std_logic;         -- refclk0 to 227
    REF_CLK_3_P : in std_logic;         -- refclk0 to 226
    REF_CLK_3_N : in std_logic;         -- refclk0 to 226
    REF_CLK_4_P : in std_logic;         -- refclk0 to 225
    REF_CLK_4_N : in std_logic;         -- refclk0 to 225
    REF_CLK_5_P : in std_logic;         -- refclk1 to 227
    REF_CLK_5_N : in std_logic;         -- refclk1 to 227
    CLK_125_REF_P : in std_logic;       -- refclk1 to 226
    CLK_125_REF_N : in std_logic;       -- refclk1 to 226
    EMCCLK : in std_logic;              -- Low frequency, 133 MHz for SPI programing clock
    LF_CLK : in std_logic;              -- Low frequency, 10 kHz

    --------------------
    -- Signals controlled by ODMB_VME
    --------------------
    -- From/To VME controller to/from MBV
    VME_DATA        : inout std_logic_vector(15 downto 0); -- Bank 48
    VME_GAP_B       : in std_logic;                        -- Bank 48
    VME_GA_B        : in std_logic_vector(4 downto 0);     -- Bank 48
    VME_ADDR        : in std_logic_vector(23 downto 1);    -- Bank 46
    VME_AM          : in std_logic_vector(5 downto 0);     -- Bank 46
    VME_AS_B        : in std_logic;                        -- Bank 46
    VME_DS_B        : in std_logic_vector(1 downto 0);     -- Bank 46
    VME_LWORD_B     : in std_logic;                        -- Bank 48
    VME_WRITE_B     : in std_logic;                        -- Bank 48
    VME_IACK_B      : in std_logic;                        -- Bank 48
    VME_BERR_B      : in std_logic;                        -- Bank 48
    VME_SYSRST_B    : in std_logic;                        -- Bank 48, not used
    VME_SYSFAIL_B   : in std_logic;                        -- Bank 48
    VME_CLK_B       : in std_logic;                        -- Bank 48, not used
    KUS_VME_OE_B    : out std_logic;                       -- Bank 44
    KUS_VME_DIR     : out std_logic;                       -- Bank 44
    VME_DTACK_KUS_B : out std_logic;                       -- Bank 44

    -- From/To PPIB (connectors J3 and J4)
    DCFEB_TCK_P    : out std_logic_vector(NCFEB downto 1); -- Bank 68
    DCFEB_TCK_N    : out std_logic_vector(NCFEB downto 1); -- Bank 68
    DCFEB_TMS_P    : out std_logic;                        -- Bank 68
    DCFEB_TMS_N    : out std_logic;                        -- Bank 68
    DCFEB_TDI_P    : out std_logic;                        -- Bank 68
    DCFEB_TDI_N    : out std_logic;                        -- Bank 68
    DCFEB_TDO_P    : in  std_logic_vector(NCFEB downto 1); -- "C_TDO" in Bank 67-68
    DCFEB_TDO_N    : in  std_logic_vector(NCFEB downto 1); -- "C_TDO" in Bank 67-68
    DCFEB_DONE     : in  std_logic_vector(NCFEB downto 1); -- "DONE_*" in Bank 68
    RESYNC_P       : out std_logic;                        -- Bank 66
    RESYNC_N       : out std_logic;                        -- Bank 66
    BC0_P          : out std_logic;                        -- Bank 68
    BC0_N          : out std_logic;                        -- Bank 68
    INJPLS_P       : out std_logic;                        -- Bank 66, ODMB CTRL
    INJPLS_N       : out std_logic;                        -- Bank 66, ODMB CTRL
    EXTPLS_P       : out std_logic;                        -- Bank 66, ODMB CTRL
    EXTPLS_N       : out std_logic;                        -- Bank 66, ODMB CTRL
    L1A_P          : out std_logic;                        -- Bank 66, ODMB CTRL
    L1A_N          : out std_logic;                        -- Bank 66, ODMB CTRL
    L1A_MATCH_P    : out std_logic_vector(NCFEB downto 1); -- Bank 66, ODMB CTRL
    L1A_MATCH_N    : out std_logic_vector(NCFEB downto 1); -- Bank 66, ODMB CTRL
    PPIB_OUT_EN_B  : out std_logic;                        -- Bank 68

    --------------------
    -- CCB Signals
    --------------------
    CCB_CMD        : in  std_logic_vector(5 downto 0);     -- Bank 44
    CCB_CMD_S      : in  std_logic;                        -- Bank 46
    CCB_DATA       : in  std_logic_vector(7 downto 0);     -- Bank 44
    CCB_DATA_S     : in  std_logic;                        -- Bank 46
    CCB_CAL        : in  std_logic_vector(2 downto 0);     -- Bank 44
    CCB_CRSV       : in  std_logic_vector(3 downto 0);     -- Bank 44
    CCB_DRSV       : in  std_logic_vector(1 downto 0);     -- Bank 45
    CCB_RSVO       : in  std_logic_vector(4 downto 0);     -- Bank 45
    CCB_RSVI       : out std_logic_vector(2 downto 0);     -- Bank 45
    CCB_BX0_B      : in  std_logic;                        -- "CCB_BX0" in Bank 46
    CCB_BX_RST_B   : in  std_logic;                        -- "CCB_BX_RST" in Bank 46
    CCB_L1A_RST_B  : in  std_logic;                        -- "CCB_L1A_RST" in Bank 46
    CCB_L1A_B      : in  std_logic;                        -- "CCB_L1A" in Bank 46
    CCB_L1A_RLS    : out std_logic;                        -- Bank 45
    CCB_CLKEN      : in  std_logic;                        -- Bank 46
    CCB_EVCNTRES_B : in  std_logic;                        -- "CCB_EVCNTRES" in Bank 46
    CCB_HARDRST_B  : in  std_logic;                        -- Bank 45 <-- should not be connected
    CCB_SOFT_RST_B : in  std_logic;                        -- "CCB_SOFT_RST" in Bank 45

    --------------------
    -- LVMB Signals
    --------------------
    LVMB_PON     : out std_logic_vector(7 downto 0);       -- Bank 67
    PON_LOAD_B   : out std_logic;                          -- Bank 67
    PON_OE       : out std_logic;                          -- Bank 67
    MON_LVMB_PON : in  std_logic_vector(7 downto 0);       -- Bank 67
    LVMB_CSB     : out std_logic_vector(6 downto 0);       -- Bank 67
    LVMB_SCLK    : out std_logic;                          -- Bank 68
    LVMB_SDIN    : out std_logic;                          -- Bank 68
    LVMB_SDOUT_P : in std_logic;                           -- C_LVMB_SDOUT_P in Bank 67
    LVMB_SDOUT_N : in std_logic;                           -- C_LVMB_SDOUT_N in Bank 67 --meta:uncomment_for_odmb

    --------------------------------
    -- OTMB communication signals
    --------------------------------
    OTMB        : in  std_logic_vector(35 downto 0);      -- "TMB[35:0]" in Bank 44-45
    RAWLCT      : in  std_logic_vector(NCFEB-1 downto 0); -- Bank 45
    OTMB_DAV    : in  std_logic;                          -- "TMB_DAV" in Bank 45
    OTMB_FF_CLK : in  std_logic;                          -- "TMB_FF_CLK" in Bank 45
    RSVTD_IN    : in  std_logic_vector(7 downto 3);       -- "RSVTD[7:3]" in Bank 44-45
    RSVTD_OUT   : out std_logic_vector(2 downto 0);       -- "RSVTD[2:0]" in Bank 44-45
    LCT_RQST    : out std_logic_vector(2 downto 1);       -- Bank 45

    --------------------------------
    -- ODMB optical ports
    --------------------------------
    -- Acutally connected optical TX/RX signals
    DAQ_RX_P     : in std_logic_vector(10 downto 0);
    DAQ_RX_N     : in std_logic_vector(10 downto 0);
    DAQ_SPY_RX_P : in std_logic;        -- DAQ_RX_P11 or SPY_RX_P
    DAQ_SPY_RX_N : in std_logic;        -- DAQ_RX_N11 or SPY_RX_N
    B04_RX_P     : in std_logic_vector(4 downto 2); -- B04 RX, no use yet
    B04_RX_N     : in std_logic_vector(4 downto 2); -- B04 RX, no use yet
    BCK_PRS_P    : in std_logic; -- B04_RX1_P
    BCK_PRS_N    : in std_logic; -- B04_RX1_N

    SPY_TX_P     : out std_logic;        -- output to PC
    SPY_TX_N     : out std_logic;        -- output to PC
    DAQ_TX_P     : out std_logic_vector(4 downto 1); -- B04 TX, output to FED
    DAQ_TX_N     : out std_logic_vector(4 downto 1); -- B04 TX, output to FED

    --------------------------------
    -- Optical control signals
    --------------------------------
    DAQ_SPY_SEL    : out std_logic;      -- 0 for DAQ_RX_P/N11, 1 for SPY_RX_P/N

    RX12_I2C_ENA   : out std_logic;
    RX12_SDA       : inout std_logic;
    RX12_SCL       : inout std_logic;
    RX12_CS_B      : out std_logic;
    RX12_RST_B    : out std_logic;
    RX12_INT_B     : in std_logic;
    RX12_PRESENT_B : in std_logic;

    TX12_I2C_ENA   : out std_logic;
    TX12_SDA       : inout std_logic;
    TX12_SCL       : inout std_logic;
    TX12_CS_B      : out std_logic;
    TX12_RST_B     : out std_logic;
    TX12_INT_B     : in std_logic;
    TX12_PRESENT_B : in std_logic;

    B04_I2C_ENA   : out std_logic;
    B04_SDA       : inout std_logic;
    B04_SCL       : inout std_logic;
    B04_CS_B      : out std_logic;
    B04_RST_B     : out std_logic;
    B04_INT_B     : in std_logic;
    B04_PRESENT_B : in std_logic;

    SPY_I2C_ENA   : out std_logic;
    SPY_SDA       : inout std_logic;
    SPY_SCL       : inout std_logic;
    SPY_SD        : in std_logic;   -- Signal Detect
    SPY_TDIS      : out std_logic;  -- Transmitter Disable

    --------------------------------
    -- Essential selector/reset signals not classified yet
    --------------------------------
    KUS_DL_SEL    : out std_logic;                         -- Bank 47, ODMB JTAG path select
    FPGA_SEL      : out std_logic;                         -- Bank 47, clock synthesizaer control input select
    RST_CLKS_B    : out std_logic;                         -- Bank 47, clock synthesizaer reset
    ODMB_DONE     : in std_logic;                          -- "DONE" in bank 66 (pin L9), monitor DONE_0 from Bank 0 (pin N7)

    --------------------------------
    -- System monitoring ports
    --------------------------------
    SYSMON_P      : in std_logic_vector(15 downto 0);
    SYSMON_N      : in std_logic_vector(15 downto 0);

    ADC_CS_B      : out std_logic_vector(4 downto 0); -- Bank 46
    ADC_DIN       : out std_logic; -- Bank 46 
    ADC_SCK       : out std_logic; -- Bank 46 
    ADC_DOUT      : in std_logic;   -- Bank 46

    --------------------------------
    -- Others
    --------------------------------
    LEDS_CFV      : out std_logic_vector(11 downto 0)
    );
end odmb7_ucsb_dev;

architecture Behavioral of odmb7_ucsb_dev is

  component odmb_clocking is
    port (
      -- Input ports
      CMS_CLK_FPGA_P : in std_logic;    -- system clock: 40.07897 MHz
      CMS_CLK_FPGA_N : in std_logic;    -- system clock: 40.07897 MHz
      GP_CLK_6_P     : in std_logic;    -- clock synthesizer ODIV6: 80 MHz
      GP_CLK_6_N     : in std_logic;    -- clock synthesizer ODIV6: 80 MHz
      GP_CLK_7_P     : in std_logic;    -- clock synthesizer ODIV7: 80 MHz
      GP_CLK_7_N     : in std_logic;    -- clock synthesizer ODIV7: 80 MHz
      REF_CLK_1_P    : in std_logic;    -- refclk0 to 224
      REF_CLK_1_N    : in std_logic;    -- refclk0 to 224
      REF_CLK_2_P    : in std_logic;    -- refclk0 to 227
      REF_CLK_2_N    : in std_logic;    -- refclk0 to 227
      REF_CLK_3_P    : in std_logic;    -- refclk0 to 226
      REF_CLK_3_N    : in std_logic;    -- refclk0 to 226
      REF_CLK_4_P    : in std_logic;    -- refclk0 to 225
      REF_CLK_4_N    : in std_logic;    -- refclk0 to 225
      REF_CLK_5_P    : in std_logic;    -- refclk1 to 227
      REF_CLK_5_N    : in std_logic;    -- refclk1 to 227
      CLK_125_REF_P  : in std_logic;    -- refclk1 to 226
      CLK_125_REF_N  : in std_logic;    -- refclk1 to 226
      EMCCLK         : in std_logic;    -- Low frequency, 133 MHz for SPI programing clock
      LF_CLK         : in std_logic;    -- Low frequency, 10 kHz

      -- Output clocks
      mgtrefclk0_224 : out std_logic;   -- MGT refclk for GT wizard
      mgtrefclk0_225 : out std_logic;   -- MGT refclk for GT wizard
      mgtrefclk0_226 : out std_logic;   -- MGT refclk for GT wizard
      mgtrefclk1_226 : out std_logic;   -- MGT refclk for GT wizard
      mgtrefclk0_227 : out std_logic;   -- MGT refclk for GT wizard
      mgtrefclk1_227 : out std_logic;   -- MGT refclk for GT wizard
      clk_sysclk625k : out std_logic;
      clk_sysclk1p25 : out std_logic;
      clk_sysclk2p5  : out std_logic;
      clk_sysclk10   : out std_logic;   -- derived clock from MMCM
      clk_sysclk20   : out std_logic;   -- derived clock from MMCM
      clk_sysclk40   : out std_logic;   -- derived clock from MMCM
      clk_sysclk80   : out std_logic;   -- derived clock from MMCM
      clk_cmsclk     : out std_logic;   -- buffed CMS clock, 40.07897 MHz
      clk_emcclk     : out std_logic;   -- buffed EMC clock
      clk_lfclk      : out std_logic;   -- buffed LF clock
      clk_gp6        : out std_logic;
      clk_gp7        : out std_logic;
      clk_mgtclk1    : out std_logic;   -- buffed ODIV2 port of the refclks, 160 MHz
      clk_mgtclk2    : out std_logic;   -- buffed ODIV2 port of the refclks, 160 MHz
      clk_mgtclk3    : out std_logic;   -- buffed ODIV2 port of the refclks, 160 MHz
      clk_mgtclk4    : out std_logic;   -- buffed ODIV2 port of the refclks, 160 MHz
      clk_mgtclk5    : out std_logic;   -- buffed ODIV2 port of the refclks, 160 MHz
      clk_mgtclk125  : out std_logic    -- buffed ODIV2 port of the refclks, 125 MHz
      );
  end component;

  component ODMB_VME is
    generic (
      NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
      );
    port (
      --------------------
      -- Clock
      --------------------
      CLK160      : in std_logic;  -- For dcfeb prbs (160MHz)
      CLK40       : in std_logic;  -- NEW (fastclk -> 40MHz)
      CLK10       : in std_logic;  -- NEW (midclk -> fastclk/4 -> 10MHz)
      CLK2P5      : in std_logic;  -- 2.5 MHz clock
      CLK1P25     : in std_logic;  -- 1.25 MHz clock

      --------------------
      -- VME signals  <-- relevant ones only
      --------------------
      VME_DATA_IN   : in std_logic_vector (15 downto 0);
      VME_DATA_OUT  : out std_logic_vector (15 downto 0);
      VME_GAP_B     : in std_logic;     -- Also known as GA(5)
      VME_GA_B      : in std_logic_vector (4 downto 0);
      VME_ADDR      : in std_logic_vector (23 downto 1);
      VME_AM        : in std_logic_vector (5 downto 0);
      VME_AS_B      : in std_logic;
      VME_DS_B      : in std_logic_vector (1 downto 0);
      VME_LWORD_B   : in std_logic;
      VME_WRITE_B   : in std_logic;
      VME_IACK_B    : in std_logic;
      VME_BERR_B    : in std_logic;
      VME_SYSFAIL_B : in std_logic;
      VME_DTACK_B   : out std_logic;
      VME_OE_B      : out std_logic;
      VME_DIR_B     : out std_logic;

      --------------------
      -- JTAG Signals To/From DCFEBs
      --------------------
      DCFEB_TCK    : out std_logic_vector (NCFEB downto 1);
      DCFEB_TMS    : out std_logic;
      DCFEB_TDI    : out std_logic;
      DCFEB_TDO    : in  std_logic_vector (NCFEB downto 1);

      DCFEB_DONE     : in std_logic_vector (NCFEB downto 1);
      DCFEB_INITJTAG : in std_logic;   -- TODO: where does this fit in

      --------------------
      -- From/To LVMB: ODMB & ODMB7 design, ODMB5 to be seen
      --------------------
      LVMB_PON     : out std_logic_vector(7 downto 0);
      PON_LOAD_B   : out std_logic;
      PON_OE       : out std_logic;
      R_LVMB_PON   : in  std_logic_vector(7 downto 0);
      LVMB_CSB     : out std_logic_vector(6 downto 0);
      LVMB_SCLK    : out std_logic;
      LVMB_SDIN    : out std_logic;
      LVMB_SDOUT   : in  std_logic;

      --------------------
      -- OTMB signals
      --------------------
      OTMB        : in  std_logic_vector(35 downto 0);      -- "TMB[35:0]" in Bank 44-45
      RAWLCT      : in  std_logic_vector(NCFEB-1 downto 0); -- Bank 45
      OTMB_DAV    : in  std_logic;                          -- "TMB_DAV" in Bank 45
      OTMB_FF_CLK : in  std_logic;                          -- "TMB_FF_CLK" in Bank 45
      RSVTD_IN    : in  std_logic_vector(7 downto 3);       -- "RSVTD[7:3]" in Bank 44-45
      RSVTD_OUT   : out std_logic_vector(2 downto 0);       -- "RSVTD[2:0]" in Bank 44-45
      LCT_RQST    : out std_logic_vector(2 downto 1);       -- Bank 45

      --------------------
      -- VMEMON Configuration signals for top level
      --------------------
      FW_RESET             : out std_logic;
      L1A_RESET_PULSE      : out std_logic;
      OPT_RESET_PULSE      : out std_logic;
      TEST_INJ             : out std_logic;
      TEST_PLS             : out std_logic;
      TEST_BC0             : out std_logic;
      TEST_PED             : out std_logic;
      TEST_LCT             : out std_logic;
      MASK_L1A             : out std_logic_vector(NCFEB downto 0);
      MASK_PLS             : out std_logic;
      ODMB_CAL             : out std_logic;
      MUX_DATA_PATH        : out std_logic;
      MUX_TRIGGER          : out std_logic;
      MUX_LVMB             : out std_logic;
      ODMB_PED             : out std_logic_vector(1 downto 0);
      ODMB_DATA            : in std_logic_vector(15 downto 0);
      ODMB_DATA_SEL        : out std_logic_vector(7 downto 0);

      --------------------
      -- VMECONFREGS Configuration signals for top level
      --------------------
      LCT_L1A_DLY      : out std_logic_vector(5 downto 0);
      CABLE_DLY        : out integer range 0 to 1;
      OTMB_PUSH_DLY    : out integer range 0 to 63;
      ALCT_PUSH_DLY    : out integer range 0 to 63;
      BX_DLY           : out integer range 0 to 4095;
      INJ_DLY          : out std_logic_vector(4 downto 0);
      EXT_DLY          : out std_logic_vector(4 downto 0);
      CALLCT_DLY       : out std_logic_vector(3 downto 0);
      ODMB_ID          : out std_logic_vector(15 downto 0);
      NWORDS_DUMMY     : out std_logic_vector(15 downto 0);
      KILL             : out std_logic_vector(NCFEB+2 downto 1);
      CRATEID          : out std_logic_vector(7 downto 0);
      CHANGE_REG_DATA  : in std_logic_vector(15 downto 0);
      CHANGE_REG_INDEX : in integer range 0 to NREGS;

      --------------------
      -- DDU/SPY/DCFEB/ALCT Optical PRBS test signals
      --------------------
      MGT_PRBS_TYPE        : out std_logic_vector(3 downto 0); -- DDU/SPY/DCFEB/ALCT Common PRBS type
      DDU_PRBS_TX_EN       : out std_logic_vector(3 downto 0);
      DDU_PRBS_RX_EN       : out std_logic_vector(3 downto 0);
      DDU_PRBS_TST_CNT     : out std_logic_vector(15 downto 0);
      DDU_PRBS_ERR_CNT     : in  std_logic_vector(15 downto 0);
      SPY_PRBS_TX_EN       : out std_logic_vector(0 downto 0);
      SPY_PRBS_RX_EN       : out std_logic_vector(0 downto 0);
      SPY_PRBS_TST_CNT     : out std_logic_vector(15 downto 0);
      SPY_PRBS_ERR_CNT     : in  std_logic_vector(15 downto 0);
      DCFEB_PRBS_FIBER_SEL : out std_logic_vector(3 downto 0);
      DCFEB_PRBS_EN        : out std_logic;
      DCFEB_PRBS_RST       : out std_logic;
      DCFEB_PRBS_RD_EN     : out std_logic;
      DCFEB_RXPRBSERR      : in  std_logic;
      DCFEB_PRBS_ERR_CNT   : in  std_logic_vector(15 downto 0);

      -------------------
      -- System monitoring
      -------------------

      -- Voltage monitoring through MAX127 chips
      ADC_CS_B     : out std_logic_vector(4 downto 0);
      ADC_DIN        : out std_logic;
      ADC_SCK        : out std_logic; 
      ADC_DOUT       : in  std_logic;

      --------------------
      -- Other
      --------------------
      DIAGOUT     : out std_logic_vector (17 downto 0); -- for debugging
      RST         : in std_logic;
      PON_RESET   : in std_logic
      );
  end component;

  component ODMB_CTRL is
    generic (
      NCFEB       : integer range 1 to 7 := NCFEB  -- Number of DCFEBS, 7 for ME1/1, 5
      );
    port (
      --------------------
      -- Clock
      --------------------
      CLK80       : in std_logic;
      CLK40       : in std_logic;

      --------------------
      -- ODMB VME <-> CALIBTRIG
      --------------------
      TEST_CCBINJ   : in std_logic;
      TEST_CCBPLS   : in std_logic;
      TEST_CCBPED   : in std_logic;

      --------------------
      -- Delay registers (from VMECONFREGS)
      --------------------
      LCT_L1A_DLY   : in std_logic_vector(5 downto 0);
      INJ_DLY       : in std_logic_vector(4 downto 0);
      EXT_DLY       : in std_logic_vector(4 downto 0);
      CALLCT_DLY    : in std_logic_vector(3 downto 0);

      --------------------
      -- Configuration
      --------------------
      CAL_MODE      : in std_logic;
      PEDESTAL      : in std_logic;

      --------------------
      -- Triggers
      --------------------
      RAW_L1A       : in std_logic;

      --------------------
      -- To/From DCFEBs (FF-EMU-MOD)
      --------------------
      DCFEB_INJPULSE  : out std_logic;
      DCFEB_EXTPULSE  : out std_logic;
      DCFEB_L1A       : out std_logic;
      DCFEB_L1A_MATCH : out std_logic_vector(NCFEB downto 1);

      --------------------
      -- Other
      --------------------
      DIAGOUT     : out std_logic_vector (17 downto 0); -- for debugging
      RST         : in std_logic
      );
  end component;

  component LCTDLY is  -- Aligns RAW_LCT with L1A by 2.4 us to 4.8 us
    port (
      DIN   : in std_logic;
      CLK   : in std_logic;
      DELAY : in std_logic_vector(5 downto 0);
      DOUT : out std_logic
      );
  end component;

  component mgt_spy is
    generic (
      NLINK     : integer range 1 to 20 := 1;  -- number of (physical) links
      DATAWIDTH  : integer := 16               -- receiver user data width
      );
    port (
      mgtrefclk       : in  std_logic; -- buffer'ed reference clock signal
      txusrclk        : out std_logic; -- USRCLK for TX data preparation
      rxusrclk        : out std_logic; -- USRCLK for RX data readout
      sysclk          : in  std_logic; -- clock for the helper block, 80 MHz
      spy_rx_n        : in  std_logic;
      spy_rx_p        : in  std_logic;
      spy_tx_n        : out std_logic;
      spy_tx_p        : out std_logic;
      txready         : out std_logic; -- Flag for tx reset done
      rxready         : out std_logic; -- Flag for rx reset done
      txdata          : in std_logic_vector(15 downto 0);  -- Data to be transmitted
      txd_valid       : in std_logic_vector(NLINK-1 downto 0);   -- Flag for tx data valid
      txdiffctrl      : in std_logic_vector(3 downto 0);   -- Controls the TX voltage swing
      loopback        : in std_logic_vector(2 downto 0);   -- For internal loopback tests
      rxdata          : out std_logic_vector(15 downto 0);  -- Data received
      rxd_valid       : out std_logic_vector(NLINK-1 downto 0);   -- Flag for valid data;
      bad_rx          : out std_logic_vector(NLINK-1 downto 0);   -- Flag for fiber errors;
      prbs_type       : in  std_logic_vector(3 downto 0);
      prbs_tx_en      : in  std_logic_vector(NLINK-1 downto 0);
      prbs_rx_en      : in  std_logic_vector(NLINK-1 downto 0);
      prbs_tst_cnt    : in  std_logic_vector(15 downto 0);
      prbs_err_cnt    : out std_logic_vector(15 downto 0);
      reset           : in  std_logic
      );
  end component;

  component mgt_alct is
    generic (
      NLINK : integer range 1 to 5 := 1;   -- number of links
      DATAWIDTH : integer := 16            -- user data width
      );
    port (
      mgtrefclk       : in  std_logic; -- buffer'ed reference clock signal
      rxusrclk        : out std_logic; -- USRCLK for RX data readout
      sysclk          : in  std_logic; -- clock for the helper block, 80 MHz
      daq_rx_n        : in  std_logic;
      daq_rx_p        : in  std_logic;
      rxready         : out std_logic; -- Flag for rx reset done
      rxdata          : out std_logic_vector(15 downto 0);  -- Data received
      rxd_valid       : out std_logic_vector(NLINK-1 downto 0);   -- Flag for valid data;
      bad_rx          : out std_logic_vector(NLINK-1 downto 0);   -- Flag for fiber errors;
      prbs_type       : in  std_logic_vector(3 downto 0);
      prbs_rx_en      : in  std_logic_vector(NLINK-1 downto 0);
      prbs_tst_cnt    : in  std_logic_vector(15 downto 0);
      prbs_err_cnt    : out std_logic_vector(15 downto 0);
      reset           : in  std_logic
      );
  end component;

  component mgt_cfeb is
    generic (
      NLINK     : integer range 1 to 20 := 7;  -- number of links
      DATAWIDTH : integer := 16                -- user data width
      );
    port (
      mgtrefclk    : in  std_logic; -- buffer'ed reference clock signal
      rxusrclk     : out std_logic; -- USRCLK for RX data readout
      sysclk       : in  std_logic; -- clock for the helper block, 80 MHz
      daq_rx_n     : in  std_logic_vector(NLINK-1 downto 0);
      daq_rx_p     : in  std_logic_vector(NLINK-1 downto 0);
      rxdata_feb1  : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
      rxdata_feb2  : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
      rxdata_feb3  : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
      rxdata_feb4  : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
      rxdata_feb5  : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
      rxdata_feb6  : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
      rxdata_feb7  : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
      rxd_valid    : out std_logic_vector(NLINK downto 1);   -- Flag for valid data
      crc_valid    : out std_logic_vector(NLINK downto 1);   -- Flag for valid CRC
      rxready      : out std_logic;                          -- Flag for rx reset done
      bad_rx       : out std_logic_vector(NLINK downto 1);   -- Flag for fiber errors
      kill_rxout   : in  std_logic_vector(NLINK downto 1);   -- Kill DCFEB by no output
      kill_rxpd    : in  std_logic_vector(NLINK downto 1);   -- Kill bad DCFEB with power down RX
      fifo_full    : in  std_logic_vector(NLINK downto 1);   -- Flag for FIFO full
      fifo_afull   : in  std_logic_vector(NLINK downto 1);   -- Flag for FIFO almost full
      prbs_type    : in  std_logic_vector(3 downto 0);
      prbs_rx_en   : in  std_logic_vector(NLINK downto 1);
      prbs_tst_cnt : in  std_logic_vector(15 downto 0);
      prbs_err_cnt : out std_logic_vector(15 downto 0);
      reset        : in  std_logic
      );
  end component;

  component mgt_ddu is
    generic (
      NCHANNL     : integer range 1 to 4 := 4;  -- number of (firmware) channels (max of TX/RX links)
      NRXLINK     : integer range 1 to 4 := 4;  -- number of (physical) RX links
      NTXLINK     : integer range 1 to 4 := 4;  -- number of (physical) TX links
      TXDATAWIDTH : integer := 16;              -- transmitter user data width
      RXDATAWIDTH  : integer := 16               -- receiver user data width
      );
    port (
      mgtrefclk    : in  std_logic; -- buffer'ed reference clock signal
      txusrclk     : out std_logic; -- USRCLK for TX data readout
      rxusrclk     : out std_logic; -- USRCLK for RX data readout
      sysclk       : in  std_logic; -- clock for the helper block, 80 MHz
      daq_tx_n     : out std_logic_vector(NTXLINK-1 downto 0);
      daq_tx_p     : out std_logic_vector(NTXLINK-1 downto 0);
      bck_rx_n     : in  std_logic; -- for back pressure / loopback
      bck_rx_p     : in  std_logic; -- for back pressure / loopback
      b04_rx_n     : in  std_logic_vector(3 downto 1); -- for back pressure / loopback
      b04_rx_p     : in  std_logic_vector(3 downto 1); -- for back pressure / loopback
      txdata_ch0   : in std_logic_vector(TXDATAWIDTH-1 downto 0);  -- Data received
      txdata_ch1   : in std_logic_vector(TXDATAWIDTH-1 downto 0);  -- Data received
      txdata_ch2   : in std_logic_vector(TXDATAWIDTH-1 downto 0);  -- Data received
      txdata_ch3   : in std_logic_vector(TXDATAWIDTH-1 downto 0);  -- Data received
      txd_valid    : in std_logic_vector(NTXLINK downto 1);   -- Flag for valid data;
      rxdata_ch0   : out std_logic_vector(RXDATAWIDTH-1 downto 0);  -- Data received
      rxdata_ch1   : out std_logic_vector(RXDATAWIDTH-1 downto 0);  -- Data received
      rxdata_ch2   : out std_logic_vector(RXDATAWIDTH-1 downto 0);  -- Data received
      rxdata_ch3   : out std_logic_vector(RXDATAWIDTH-1 downto 0);  -- Data received
      rxd_valid    : out std_logic_vector(NRXLINK downto 1);   -- Flag for valid data;
      bad_rx       : out std_logic_vector(NRXLINK downto 1);   -- Flag for fiber errors;
      rxready      : out std_logic; -- Flag for rx reset done
      txready      : out std_logic; -- Flag for tx reset done
      prbs_type    : in  std_logic_vector(3 downto 0);
      prbs_rx_en   : in  std_logic_vector(NRXLINK downto 1);
      prbs_tst_cnt : in  std_logic_vector(15 downto 0);
      prbs_err_cnt : out std_logic_vector(15 downto 0);
      reset        : in  std_logic
      );
  end component;

  --component prbs_tester is
  --  generic (
  --    DDU_NRXLINK  : integer := 1;
  --    SPY_NLINK  : integer := 1;
  --    ALCT_NLINK  : integer := 1;
  --    SPYDATAWIDTH : integer := 16;
  --    FEBDATAWIDTH : integer := 16;
  --    DDUTXDWIDTH  : integer := 32;
  --    DDURXDWIDTH  : integer := 16;
  --    SPY_PATTERN  : integer := 0;        -- 0 for PRBS, 1 for counter
  --    DDU_PATTERN  : integer := 0         -- 0 for PRBS, 1 for counter
  --    );
  --  port (
  --    sysclk         : in std_logic; -- sysclk
  --    -- Pattern generation and checking for SPY channel
  --    usrclk_spy_tx  : in std_logic; -- USRCLK for SPY TX data generation
  --    txdata_spy     : out std_logic_vector(SPYDATAWIDTH-1 downto 0); -- PRBS data out
  --    txd_valid_spy  : out std_logic_vector(SPY_NLINK-1 downto 0);
  --    usrclk_spy_rx  : in std_logic;  -- USRCLK for SPY RX data readout
  --    rxdata_spy     : in std_logic_vector(SPYDATAWIDTH-1 downto 0); -- PRBS data out
  --    rxd_valid_spy  : in std_logic_vector(SPY_NLINK-1 downto 0);
  --    rxready_spy    : in std_logic; -- Flag for rx reset done
  --    -- Pattern generation for mgt_ddu
  --    usrclk_ddu_tx  : in std_logic; -- USRCLK for SPY TX data generation
  --    txdata_ddu1    : out std_logic_vector(DDUTXDWIDTH-1 downto 0); -- PRBS data out
  --    txdata_ddu2    : out std_logic_vector(DDUTXDWIDTH-1 downto 0); -- PRBS data out
  --    txdata_ddu3    : out std_logic_vector(DDUTXDWIDTH-1 downto 0); -- PRBS data out
  --    txdata_ddu4    : out std_logic_vector(DDUTXDWIDTH-1 downto 0); -- PRBS data out
  --    txd_valid_ddu  : out std_logic_vector(4 downto 1);
  --    -- Pattern checking for mgt_ddu
  --    usrclk_ddu_rx  : in std_logic;  -- USRCLK for DDU RX data readout
  --    rxdata_ddu1    : in std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
  --    rxdata_ddu2    : in std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
  --    rxdata_ddu3    : in std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
  --    rxdata_ddu4    : in std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
  --    rxd_valid_ddu  : in std_logic_vector(DDU_NRXLINK downto 1);
  --    rxready_ddu    : in std_logic; -- Flag for rx reset done
  --    -- Receiver signals for mgt_cfeb
  --    usrclk_mgtc    : in std_logic; -- USRCLK for RX data readout
  --    rxdata_cfeb1   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    rxdata_cfeb2   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    rxdata_cfeb3   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    rxdata_cfeb4   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    rxdata_cfeb5   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    rxdata_cfeb6   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    rxdata_cfeb7   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    rxd_valid_mgtc : in std_logic_vector(7 downto 1);   -- Flag for valid data;
  --    rxready_mgtc   : in std_logic; -- Flag for rx reset done
  --    -- Receiver signals for mgt_alct
  --    usrclk_mgta    : in std_logic; -- USRCLK for RX data readout
  --    rxdata_alct    : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    rxd_valid_alct : in std_logic_vector(ALCT_NLINK-1 downto 0);
  --    rxready_alct   : in std_logic; -- Flag for rx reset done
  --    rxdata_daq8    : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    rxdata_daq9    : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    rxdata_daq10   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
  --    mgta_dvalid    : in std_logic_vector(4 downto 1);   -- Flag for valid data;
  --    -- LED indicator
  --    led_out       : out std_logic_vector(7 downto 0);
  --    -- Reset
  --    reset         : out std_logic
  --    );
  --end component;

  --------------------------------------
  -- Clock signals
  --------------------------------------
  signal mgtrefclk0_224 : std_logic;
  signal mgtrefclk0_225 : std_logic;
  signal mgtrefclk0_226 : std_logic;
  signal mgtrefclk1_226 : std_logic;
  signal mgtrefclk0_227 : std_logic;
  signal mgtrefclk1_227 : std_logic;
  signal sysclk625k : std_logic;
  signal sysclk1p25 : std_logic;
  signal sysclk2p5 : std_logic;
  signal sysclk10 : std_logic;
  signal sysclk20 : std_logic;
  signal sysclk40 : std_logic;
  signal sysclk80 : std_logic;
  signal cmsclk : std_logic;
  signal clk_emcclk : std_logic;
  signal clk_lfclk : std_logic;
  signal clk_gp6 : std_logic;
  signal clk_gp7 : std_logic;
  signal mgtclk1 : std_logic;
  signal mgtclk2 : std_logic;
  signal mgtclk3 : std_logic;
  signal mgtclk4 : std_logic;
  signal mgtclk5 : std_logic;
  signal mgtclk125 : std_logic;

  --------------------------------------
  -- VME signals
  --------------------------------------
  signal vme_dir_b        : std_logic;
  signal vme_dir          : std_logic;
  signal vme_oe_b         : std_logic;
  signal vme_data_out_buf : std_logic_vector(15 downto 0) := (others => '0');
  signal vme_data_in_buf  : std_logic_vector(15 downto 0) := (others => '0');
  signal rst              : std_logic := '0'; --meta:uncomment_for_odmb

  --------------------------------------
  -- PPIB/DCFEB signals
  --------------------------------------
  signal dcfeb_tck    : std_logic_vector (NCFEB downto 1) := (others => '0');
  signal dcfeb_tms    : std_logic := '0';
  signal dcfeb_tdi    : std_logic := '0';
  signal dcfeb_tdo    : std_logic_vector (NCFEB downto 1) := (others => '0');

  --------------------------------------
  -- Certain reset signals
  --------------------------------------
  signal reset_pulse        : std_logic := '0';
  signal reset_pulse_q      : std_logic := '0';
  signal l1acnt_rst         : std_logic := '0';
  signal l1acnt_rst_meta    : std_logic := '0';
  signal l1acnt_rst_sync    : std_logic := '0';
  signal l1a_reset_pulse    : std_logic := '0';
  signal l1a_reset_pulse_q  : std_logic := '0';
  signal opt_reset_pulse    : std_logic := '0';
  signal opt_reset_pulse_q  : std_logic := '0';
  signal premask_injpls     : std_logic := '0';
  signal premask_extpls     : std_logic := '0';
  signal dcfeb_injpls       : std_logic := '0';
  signal dcfeb_extpls       : std_logic := '0';
  signal test_bc0           : std_logic := '0';
  signal pre_bc0            : std_logic := '0';
  signal dcfeb_bc0          : std_logic := '0';
  signal dcfeb_resync       : std_logic := '0';
  signal dcfeb_l1a          : std_logic := '0';
  signal masked_l1a         : std_logic := '0';
  signal odmbctrl_l1a       : std_logic := '0';
  signal dcfeb_l1a_match    : std_logic_vector(NCFEB downto 1) := (others => '0');
  signal masked_l1a_match   : std_logic_vector(NCFEB downto 1) := (others => '0');
  signal odmbctrl_l1a_match : std_logic_vector(NCFEB downto 1) := (others => '0');
  signal ccb_bx0            : std_logic := '0';
  signal ccb_bx0_q          : std_logic := '0';
  attribute clock_buffer_type : string;
  attribute clock_buffer_type of CCB_CMD        : signal is "NONE";
  attribute clock_buffer_type of CCB_CMD_S      : signal is "NONE";
  attribute clock_buffer_type of CCB_DATA       : signal is "NONE";
  attribute clock_buffer_type of CCB_DATA_S     : signal is "NONE";
  attribute clock_buffer_type of CCB_CAL        : signal is "NONE";
  attribute clock_buffer_type of CCB_CRSV       : signal is "NONE";
  attribute clock_buffer_type of CCB_DRSV       : signal is "NONE";
  attribute clock_buffer_type of CCB_RSVO       : signal is "NONE";
  attribute clock_buffer_type of CCB_RSVI       : signal is "NONE";
  attribute clock_buffer_type of CCB_BX0_B      : signal is "NONE";
  attribute clock_buffer_type of CCB_BX_RST_B   : signal is "NONE";
  attribute clock_buffer_type of CCB_L1A_RST_B  : signal is "NONE";
  attribute clock_buffer_type of CCB_L1A_B      : signal is "NONE";
  attribute clock_buffer_type of CCB_L1A_RLS    : signal is "NONE";
  attribute clock_buffer_type of CCB_CLKEN      : signal is "NONE";
  attribute clock_buffer_type of CCB_EVCNTRES_B : signal is "NONE";

  -- signals to generate dcfeb_initjtag when DCFEBs are done programming
  signal pon_rst_reg        : std_logic_vector(31 downto 0) := x"00FFFFFF";
  signal pon_reset          : std_logic := '0';
  signal done_cnt_en        : std_logic_vector(NCFEB downto 1);
  signal done_cnt_rst       : std_logic_vector(NCFEB downto 1);
  signal done_cnt           : done_cnt_type;
  signal done_next_state    : done_state_array_type;
  signal done_current_state : done_state_array_type;
  signal dcfeb_done_pulse   : std_logic_vector(NCFEB downto 1) := (others => '0');
  signal dcfeb_initjtag     : std_logic := '0';
  signal dcfeb_initjtag_d   : std_logic := '0';
  signal dcfeb_initjtag_dd  : std_logic := '0';

  --------------------------------------
  -- CCB production test signals
  --------------------------------------

  signal ccb_cmd_bxev    : std_logic_vector(7 downto 0) := (others => '0');
  signal ccb_cmd_reg     : std_logic_vector(15 downto 0) := (others => '0');
  signal ccb_data_reg    : std_logic_vector(15 downto 0) := (others => '0');
  signal ccb_rsv         : std_logic_vector(15 downto 0) := (others => '0');
  signal ccb_other       : std_logic_vector(15 downto 0) := (others => '0');
  signal ccb_rsv_reg     : std_logic_vector(15 downto 0) := (others => '0');
  signal ccb_other_reg   : std_logic_vector(15 downto 0) := (others => '0');
  signal ccb_rsv_reg_b   : std_logic_vector(15 downto 0) := (others => '0');
  signal ccb_other_reg_b : std_logic_vector(15 downto 0) := (others => '0');

  --------------------------------------
  -- LVMB signals
  --------------------------------------
  signal lvmb_sdout : std_logic := '0';

  --------------------------------------
  -- Triggers
  --------------------------------------
  signal test_lct    : std_logic := '0';
  signal test_l1a    : std_logic := '0';
  signal raw_l1a     : std_logic := '0';
  signal raw_lct     : std_logic_vector(NCFEB downto 0);

  --------------------------------------
  -- Internal configuration signals
  --------------------------------------
  signal mask_pls         : std_logic := '0';
  signal mask_l1a         : std_logic_vector(NCFEB downto 0) := (others => '0');
  signal lct_l1a_dly      : std_logic_vector(5 downto 0) := (others => '0');
  signal inj_dly          : std_logic_vector(4 downto 0) := (others => '0');
  signal ext_dly          : std_logic_vector(4 downto 0) := (others => '0');
  signal callct_dly       : std_logic_vector(3 downto 0) := (others => '0');
  signal cable_dly        : integer range 0 to 1;
  signal odmb_ctrl_reg    : std_logic_vector(15 downto 0) := (others => '0');
  signal kill             : std_logic_vector(NCFEB+2 downto 1) := (others => '0');
  signal change_reg_data  : std_logic_vector(15 downto 0);
  signal change_reg_index : integer range 0 to NREGS := NREGS;

  --------------------------------------
  -- ODMB VME <=> ODMB CTRL signals
  --------------------------------------
  signal test_inj : std_logic := '0';
  signal test_pls : std_logic := '0';
  signal test_ped : std_logic := '0';

  --------------------------------------
  -- ODMB status signals
  --------------------------------------
  -- Counter arrays
  signal goodcrc_cnt         : t_twobyte_arr(NCFEB downto 1);
  signal dcfeb_bad_rx_cnt    : t_twobyte_arr(NCFEB downto 1);
  signal dcfeb_dvalid_cnt    : t_twobyte_arr(NCFEB downto 1); -- replacement for cafifo dav count

  signal into_cafifo_dav_cnt : t_twobyte_arr(NCFEB+2 downto 1);
  signal l1a_match_cnt       : t_twobyte_arr(NCFEB+2 downto 1);

  --------------------------------------
  -- Reset signals
  --------------------------------------
  signal fw_reset        : std_logic := '0';
  signal fw_reset_q      : std_logic := '0';
  signal opt_reset       : std_logic := '0';
  signal opt_reset_q     : std_logic := '0';
  signal ccb_softrst_b_q : std_logic := '1';
  signal fw_rst_reg      : std_logic_vector(31 downto 0) := (others => '0');
  signal opt_rst_reg     : std_logic_vector(31 downto 0) := (others => '0');
  signal reset           : std_logic := '0';

  --------------------------------------
  -- MGT PRBS signals as place holder
  --------------------------------------
  signal mgt_prbs_type : std_logic_vector(3 downto 0);

  signal dcfeb_prbs_fiber_sel : std_logic_vector(3 downto 0);
  signal dcfeb_prbs_en : std_logic;
  signal dcfeb_prbs_rst : std_logic;
  signal dcfeb_prbs_rd_en : std_logic;
  signal dcfeb_rxprbserr :  std_logic;

  --------------------------------------
  -- SPY channel signals
  --------------------------------------
  constant SPY_SEL : std_logic := '1';

  --------------------------------------
  -- MGT signals for SPY channels
  --------------------------------------
  constant SPY_NLINK : integer := 1;
  constant SPYDWIDTH : integer := 16;

  signal usrclk_spy_tx : std_logic; -- USRCLK for TX data preparation
  signal usrclk_spy_rx : std_logic; -- USRCLK for RX data readout
  signal spy_rx_n : std_logic;
  signal spy_rx_p : std_logic;
  signal spy_txready : std_logic; -- Flag for tx reset done
  signal spy_rxready : std_logic; -- Flag for rx reset done
  signal spy_txdata : std_logic_vector(15 downto 0);  -- Data to be transmitted
  signal spy_txd_valid : std_logic_vector(SPY_NLINK-1 downto 0);   -- Flag for tx data valid
  signal spy_txdiffctrl : std_logic_vector(3 downto 0);   -- Controls the TX voltage swing
  signal spy_loopback : std_logic_vector(2 downto 0);   -- For internal loopback tests
  signal spy_rxdata : std_logic_vector(15 downto 0);  -- Data received
  signal spy_rxd_valid : std_logic_vector(SPY_NLINK-1 downto 0);   -- Flag for valid data;
  signal spy_bad_rx : std_logic_vector(SPY_NLINK-1 downto 0);   -- Flag for fiber errors;
  signal spy_reset : std_logic;

  signal spy_prbs_tx_en : std_logic_vector(SPY_NLINK-1 downto 0);
  signal spy_prbs_rx_en : std_logic_vector(SPY_NLINK-1 downto 0);
  signal spy_prbs_tst_cnt : std_logic_vector(15 downto 0);
  signal spy_prbs_err_cnt : std_logic_vector(15 downto 0) := (others => '0');

  --------------------------------------
  -- MGT signals for DDU channels
  --------------------------------------
  constant DDU_NTXLINK : integer := 4;
  constant DDU_NRXLINK : integer := 4;
  constant DDUTXDWIDTH : integer := 16;
  constant DDURXDWIDTH : integer := 16;


  signal usrclk_ddu_tx : std_logic; -- USRCLK for TX data preparation
  signal usrclk_ddu_rx : std_logic; -- USRCLK for RX data readout
  signal ddu_txdata1 : std_logic_vector(DDUTXDWIDTH-1 downto 0);   -- Data to be transmitted
  signal ddu_txdata2 : std_logic_vector(DDUTXDWIDTH-1 downto 0);   -- Data to be transmitted
  signal ddu_txdata3 : std_logic_vector(DDUTXDWIDTH-1 downto 0);   -- Data to be transmitted
  signal ddu_txdata4 : std_logic_vector(DDUTXDWIDTH-1 downto 0);   -- Data to be transmitted
  signal ddu_txd_valid : std_logic_vector(DDU_NTXLINK downto 1);   -- Flag for tx valid data;
  signal ddu_rxdata1 : std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
  signal ddu_rxdata2 : std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
  signal ddu_rxdata3 : std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
  signal ddu_rxdata4 : std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
  signal ddu_rxd_valid : std_logic_vector(DDU_NRXLINK downto 1);   -- Flag for rx valid data;
  signal ddu_bad_rx : std_logic_vector(DDU_NRXLINK downto 1);   -- Flag for fiber errors;
  signal ddu_rxready : std_logic; -- Flag for rx reset done
  signal ddu_txready : std_logic; -- Flag for rx reset done
  signal ddu_reset : std_logic;

  signal ddu_prbs_tx_en : std_logic_vector(4 downto 1);
  signal ddu_prbs_rx_en : std_logic_vector(4 downto 1);
  signal ddu_prbs_tst_cnt : std_logic_vector(15 downto 0);
  signal ddu_prbs_err_cnt : std_logic_vector(15 downto 0);

  --------------------------------------
  -- MGT signals for DCFEB RX channels
  --------------------------------------
  signal usrclk_mgtc : std_logic;
  signal dcfeb1_data : std_logic_vector(15 downto 0);  -- Data received
  signal dcfeb2_data : std_logic_vector(15 downto 0);  -- Data received
  signal dcfeb3_data : std_logic_vector(15 downto 0);  -- Data received
  signal dcfeb4_data : std_logic_vector(15 downto 0);  -- Data received
  signal dcfeb5_data : std_logic_vector(15 downto 0);  -- Data received
  signal dcfeb6_data : std_logic_vector(15 downto 0);  -- Data received
  signal dcfeb7_data : std_logic_vector(15 downto 0);  -- Data received
  signal dcfeb_rxd_valid : std_logic_vector(NCFEB downto 1);   -- Flag for valid data;
  signal dcfeb_crc_valid : std_logic_vector(NCFEB downto 1);   -- Flag for valid data;
  signal dcfeb_bad_rx : std_logic_vector(NCFEB downto 1);   -- Flag for fiber errors;
  signal dcfeb_rxready : std_logic; -- Flag for rx reset done
  signal mgtc_reset : std_logic;

  signal dcfeb_prbs_rx_en : std_logic_vector(NCFEB downto 1);
  signal dcfeb_prbs_tst_cnt : std_logic_vector(15 downto 0);
  signal dcfeb_prbs_err_cnt :  std_logic_vector(15 downto 0) := (others => '0');

  -- Place holder signals for dcfeb data FIFOs
  signal dcfeb_datafifo_full : std_logic_vector(NCFEB downto 1) := (others => '0');
  signal dcfeb_datafifo_afull : std_logic_vector(NCFEB downto 1) := (others => '0');

  --------------------------------------
  -- MGT signals for ALCT RX channels
  --------------------------------------
  constant ALCT_NLINK : integer := 1;
  constant ALCTDWIDTH : integer := 16;

  signal usrclk_mgta : std_logic;
  signal alct_rxdata : std_logic_vector(15 downto 0);  -- Data received
  signal alct_rxd_valid : std_logic_vector(ALCT_NLINK-1 downto 0);   -- Flag for valid data;
  signal alct_bad_rx : std_logic_vector(ALCT_NLINK-1 downto 0);   -- Flag for valid data;
  signal alct_rxready : std_logic; -- Flag for rx reset done
  signal mgta_data_valid : std_logic_vector(4 downto 1);   -- Flag for valid data;
  signal mgta_bad_rx : std_logic_vector(4 downto 1);   -- Flag for fiber errors;
  signal mgta_rxready : std_logic; -- Flag for rx reset done
  signal mgta_reset : std_logic;
  signal mgt_reset : std_logic := '0';

  signal alct_prbs_rx_en : std_logic_vector(ALCT_NLINK-1 downto 0);
  signal alct_prbs_tst_cnt : std_logic_vector(15 downto 0);
  signal alct_prbs_err_cnt : std_logic_vector(15 downto 0) := (others => '0');

  signal daq8_rxdata  : std_logic_vector(15 downto 0);  -- Data received
  signal daq9_rxdata  : std_logic_vector(15 downto 0);  -- Data received
  signal daq10_rxdata : std_logic_vector(15 downto 0);  -- Data received

  --------------------------------------
  -- Miscellaneous
  --------------------------------------
  signal nwords_dummy  : std_logic_vector(15 downto 0);

  --------------------------------------
  -- Debug signals
  --------------------------------------
  signal diagout_inner : std_logic_vector(17 downto 0) := (others => '0');

  --------------------------------------
  -- Data readout signals
  --------------------------------------
  signal odmb_data : std_logic_vector(15 downto 0) := (others => '0');
  signal odmb_data_sel : std_logic_vector(7 downto 0) := (others => '0');

begin

  -------------------------------------------------------------------------------------------
  -- Constant driver for selector/reset pins for board to work
  -------------------------------------------------------------------------------------------
  KUS_DL_SEL <= '1';
  FPGA_SEL <= '0';
  RST_CLKS_B <= '1';

  -------------------------------------------------------------------------------------------
  -- Handle clock synthesizer signals and generate clocks
  -------------------------------------------------------------------------------------------
  u_clocking : odmb_clocking
    port map (
      CMS_CLK_FPGA_P => CMS_CLK_FPGA_P,
      CMS_CLK_FPGA_N => CMS_CLK_FPGA_N,
      GP_CLK_6_P     => GP_CLK_6_P,
      GP_CLK_6_N     => GP_CLK_6_N,
      GP_CLK_7_P     => GP_CLK_7_P,
      GP_CLK_7_N     => GP_CLK_7_N,
      REF_CLK_1_P    => REF_CLK_1_P,
      REF_CLK_1_N    => REF_CLK_1_N,
      REF_CLK_2_P    => REF_CLK_2_P,
      REF_CLK_2_N    => REF_CLK_2_N,
      REF_CLK_3_P    => REF_CLK_3_P,
      REF_CLK_3_N    => REF_CLK_3_N,
      REF_CLK_4_P    => REF_CLK_4_P,
      REF_CLK_4_N    => REF_CLK_4_N,
      REF_CLK_5_P    => REF_CLK_5_P,
      REF_CLK_5_N    => REF_CLK_5_N,
      CLK_125_REF_P  => CLK_125_REF_P,
      CLK_125_REF_N  => CLK_125_REF_N,
      EMCCLK         => EMCCLK,
      LF_CLK         => LF_CLK,
      mgtrefclk0_224 => mgtrefclk0_224,
      mgtrefclk0_225 => mgtrefclk0_225,
      mgtrefclk0_226 => mgtrefclk0_226,
      mgtrefclk1_226 => mgtrefclk1_226,
      mgtrefclk0_227 => mgtrefclk0_227,
      mgtrefclk1_227 => mgtrefclk1_227,
      clk_sysclk625k => sysclk625k,
      clk_sysclk1p25 => sysclk1p25,
      clk_sysclk2p5  => sysclk2p5,
      clk_sysclk10   => sysclk10,
      clk_sysclk20   => sysclk20,
      clk_sysclk40   => sysclk40,
      clk_sysclk80   => sysclk80,
      clk_cmsclk     => cmsclk,
      clk_emcclk     => clk_emcclk,
      clk_lfclk      => clk_lfclk,
      clk_gp6        => clk_gp6,
      clk_gp7        => clk_gp7,
      clk_mgtclk1    => mgtclk1,
      clk_mgtclk2    => mgtclk2,
      clk_mgtclk3    => mgtclk3,
      clk_mgtclk4    => mgtclk4,
      clk_mgtclk5    => mgtclk5,
      clk_mgtclk125  => mgtclk125
      );

  -------------------------------------------------------------------------------------------
  -- Handle VME signals
  -------------------------------------------------------------------------------------------

  -- Handle VME data direction and output enable lines
  KUS_VME_DIR <= vme_dir;
  vme_dir <= not vme_dir_b;
  KUS_VME_OE_B <= vme_oe_b;

  GEN_VMEOUT_16 : for I in 0 to 15 generate
  begin
    VME_BUF : IOBUF port map(O => vme_data_in_buf(I), IO => VME_DATA(I), I => vme_data_out_buf(I), T => vme_dir_b);
  end generate GEN_VMEOUT_16;

  -------------------------------------------------------------------------------------------
  -- Handle PPIB/DCFEB signals
  -------------------------------------------------------------------------------------------

  PPIB_OUT_EN_B <= '0';
  -- Handle DCFEB I/O buffers
  OB_DCFEB_TMS: OBUFDS port map (I => dcfeb_tms, O => DCFEB_TMS_P, OB => DCFEB_TMS_N);
  OB_DCFEB_TDI: OBUFDS port map (I => dcfeb_tdi, O => DCFEB_TDI_P, OB => DCFEB_TDI_N);
  OB_DCFEB_INJPLS: OBUFDS port map (I => dcfeb_injpls, O => INJPLS_P, OB => INJPLS_N);
  OB_DCFEB_EXTPLS: OBUFDS port map (I => dcfeb_extpls, O => EXTPLS_P, OB => EXTPLS_N);
  OB_DCFEB_RESYNC: OBUFDS port map (I => dcfeb_resync, O => RESYNC_P, OB => RESYNC_N);
  OB_DCFEB_BC0: OBUFDS port map (I => dcfeb_bc0, O => BC0_P, OB => BC0_N);
  OB_DCFEB_L1A: OBUFDS port map (I => dcfeb_l1a, O => L1A_P, OB => L1A_N);
  GEN_DCFEBJTAG_7 : for I in 1 to NCFEB generate
  begin
    OB_DCFEB_TCK: OBUFDS port map (I => dcfeb_tck(I), O => DCFEB_TCK_P(I), OB => DCFEB_TCK_N(I));
    IB_DCFEB_TDO: IBUFDS port map (O => dcfeb_tdo(I), I => DCFEB_TDO_P(I), IB => DCFEB_TDO_N(I));
    OB_DCFEB_L1A_MATCH: OBUFDS port map (I => dcfeb_l1a_match(I), O => L1A_MATCH_P(I), OB => L1A_MATCH_N(I));
  end generate GEN_DCFEBJTAG_7;

  --generate pulses if not masked
  dcfeb_injpls <= '0' when mask_pls = '1' else premask_injpls;
  dcfeb_extpls <= '0' when mask_pls = '1' else premask_extpls;

  --generate RESYNC, BC0, L1A, and L1A match signals to DCFEBs
  ccb_bx0   <= not CCB_BX0_B;
  FD_CCBBX0 : FD port map(Q => ccb_bx0_q, C => cmsclk, D => ccb_bx0);

  RESETPULSE      : PULSE2SAME port map(DOUT => reset_pulse, CLK_DOUT => cmsclk, RST => '0', DIN => reset);
  FD_RESETPULSE_Q : FD port map (Q => reset_pulse_q,     C => cmsclk, D => reset_pulse);
  FD_L1APULSE_Q   : FD port map (Q => l1a_reset_pulse_q, C => cmsclk, D => l1a_reset_pulse);

  --TODO: fix l1acnt_rst, 20MHz clock using ccb_bx0, and all other effects thereof)
  --TODO: fix this logic, copied from ODMB because timing violations
  --l1acnt_rst <= clk20 and (l1a_reset_pulse or l1a_reset_pulse_q or reset_pulse or reset_pulse_q);
  proc_sync_l1acnt : process (cmsclk)
  begin
    if rising_edge(cmsclk) then
      l1acnt_rst <= (l1a_reset_pulse or l1a_reset_pulse_q or reset_pulse or reset_pulse_q);
      l1acnt_rst_meta <= l1acnt_rst;
      l1acnt_rst_sync <= l1acnt_rst_meta;
    end if;
  end process;

  pre_bc0    <= test_bc0 or ccb_bx0_q;
  masked_l1a <= '0' when mask_l1a(0) = '1' else odmbctrl_l1a;

  DS_RESYNC : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_resync, CLK => cmsclk, NCYCLES => cable_dly, DIN => l1acnt_rst);
  DS_BC0    : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_bc0,    CLK => cmsclk, NCYCLES => cable_dly, DIN => pre_bc0   );
  DS_L1A    : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_l1a,    CLK => cmsclk, NCYCLES => cable_dly, DIN => masked_l1a);

  GEN_DCFEB_L1A_MATCH : for I in 1 to NCFEB generate
  begin
    masked_l1a_match(I) <= '0' when mask_l1a(I) = '1' else odmbctrl_l1a_match(I);
    DS_L1A_MATCH : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_l1a_match(I), CLK => cmsclk, NCYCLES => cable_dly, DIN => masked_l1a_match(I));
  end generate GEN_DCFEB_L1A_MATCH;

  -- FSM to handle initialization when DONE received from DCFEBs
  -- Generate dcfeb_initjtag
  done_fsm_regs : process (done_next_state, pon_reset, sysclk10)
  begin
    for dev in 1 to NCFEB loop
      if (pon_reset = '1') then
        done_current_state(dev) <= DONE_LOW;
      elsif rising_edge(sysclk10) then
        done_current_state(dev) <= done_next_state(dev);
        if done_cnt_rst(dev) = '1' then
          done_cnt(dev) <= 0;
        elsif done_cnt_en(dev) = '1' then
          done_cnt(dev) <= done_cnt(dev) + 1;
        end if;
      end if;
    end loop;
  end process;

  done_fsm_logic : process (done_current_state, DCFEB_DONE, done_cnt)
  begin
    for dev in 1 to NCFEB loop
      case done_current_state(dev) is
        when DONE_IDLE =>
          done_cnt_en(dev)      <= '0';
          dcfeb_done_pulse(dev) <= '0';
          if (DCFEB_DONE(dev) = '0') then
            done_next_state(dev) <= DONE_LOW;
            done_cnt_rst(dev)    <= '1';
          else
            done_next_state(dev) <= DONE_IDLE;
            done_cnt_rst(dev)    <= '0';
          end if;

        when DONE_LOW =>
          done_cnt_en(dev)      <= '0';
          dcfeb_done_pulse(dev) <= '0';
          done_cnt_rst(dev)     <= '0';
          if (DCFEB_DONE(dev) = '1') then
            done_next_state(dev) <= DONE_COUNTING;
          else
            done_next_state(dev) <= DONE_LOW;
          end if;

        when DONE_COUNTING =>
          if (DCFEB_DONE(dev) = '0') then
            done_next_state(dev)  <= DONE_LOW;
            done_cnt_en(dev)      <= '0';
            dcfeb_done_pulse(dev) <= '0';
            done_cnt_rst(dev)     <= '1';
          elsif (done_cnt(dev) = 3) then  -- DONE has to be high at least 400 us to avoid spurious edges
            done_next_state(dev)  <= DONE_IDLE;
            done_cnt_en(dev)      <= '0';
            dcfeb_done_pulse(dev) <= '1';
            done_cnt_rst(dev)     <= '0';
          else
            done_next_state(dev)  <= DONE_COUNTING;
            done_cnt_en(dev)      <= '1';
            dcfeb_done_pulse(dev) <= '0';
            done_cnt_rst(dev)     <= '0';
          end if;
      end case;
    end loop;
  end process;

  dcfeb_initjtag_dd <= or_reduce(dcfeb_done_pulse);
  -- FIXME: currently doesn't do anything because state machine pulses dcfeb_done_pulse for 1 40 MHz clock cycle, 10kHz on real board
  DS_DCFEB_INITJTAG    : DELAY_SIGNAL generic map(10) port map(DOUT => dcfeb_initjtag_d, CLK => sysclk625k, NCYCLES => 10, DIN => dcfeb_initjtag_dd);
  PULSE_DCFEB_INITJTAG : NPULSE2FAST port map(DOUT => dcfeb_initjtag, CLK_DOUT => sysclk2p5, RST => '0', NPULSE => 5, DIN => dcfeb_initjtag_d);

  -------------------------------------------------------------------------------------------
  -- Handle LVMB signals
  -------------------------------------------------------------------------------------------

  IB_LVMB_SDOUT: IBUFDS port map (O => lvmb_sdout, I => LVMB_SDOUT_P, IB => LVMB_SDOUT_N);

  -------------------------------------------------------------------------------------------
  -- Handle Triggers
  -------------------------------------------------------------------------------------------
  LCTDLY_GTRG : LCTDLY port map(DOUT => test_l1a, CLK => cmsclk, DELAY => lct_l1a_dly, DIN => test_lct);
  raw_l1a <= test_l1a;

  -------------------------------------------------------------------------------------------
  -- Handle Internal configuration signals
  -------------------------------------------------------------------------------------------

  -- FIXME: should change with bad_dcfeb_pulse and good_dcfeb_pulse, currently, KILL must be updated manually via VME command
  change_reg_data <= x"0" & "000" & kill(9) & kill(8) & kill(7 downto 1);
  change_reg_index <= NREGS;

  -------------------------------------------------------------------------------------------
  -- Handle CCB production test
  -------------------------------------------------------------------------------------------

  -- From CCB - for production tests
  ccb_cmd_bxev <= CCB_CMD & CCB_EVCNTRES_B & CCB_BX_RST_B;
  GEN_CCB : for index in 0 to 7 generate
    FDCMD : FDC port map(Q => ccb_cmd_reg(index), C => CCB_CMD_S, CLR => reset, D => ccb_cmd_bxev(index));
    FDDAT : FDC port map(Q => ccb_data_reg(index), C => CCB_DATA_S, CLR => reset, D => CCB_DATA(index));
  end generate GEN_CCB;

  ccb_rsv   <= "00000" & CCB_CRSV(3 downto 0) & CCB_DRSV(1 downto 0) & CCB_RSVO(4 downto 0);
  ccb_other <= "00000" & CCB_CAL(2 downto 0) & CCB_BX0_B & CCB_BX_RST_B & CCB_L1A_RST_B & CCB_L1A_B
               & CCB_CLKEN & CCB_EVCNTRES_B & CCB_CMD_S & CCB_DATA_S;
  GEN_CCB_FD : for index in 0 to 15 generate
    FDOTHER : FDC port map(Q => ccb_other_reg(index), C => ccb_other(index), CLR => reset, D => ccb_other_reg_b(index));
    FDRSV   : FDC port map(Q => ccb_rsv_reg(index), C => ccb_rsv(index), CLR => reset, D => ccb_rsv_reg_b(index));
    ccb_other_reg_b(index) <= not ccb_other_reg(index);
    ccb_rsv_reg_b(index)   <= not ccb_rsv_reg(index);
  end generate GEN_CCB_FD;

  -------------------------------------------------------------------------------------------
  -- Handle reset signals
  -------------------------------------------------------------------------------------------

  FD_CCB_SOFTRST : FD generic map(INIT => '1') port map (Q => ccb_softrst_b_q, C => cmsclk, D => CCB_SOFT_RST_B);

  FD_FW_RESET : FD port map (Q => fw_reset_q, C => cmsclk, D => fw_reset);
  fw_rst_reg <= x"3FFFF000" when ((fw_reset_q = '0' and fw_reset = '1') or ccb_softrst_b_q = '0') else
                fw_rst_reg(30 downto 0) & '0' when rising_edge(cmsclk) else
                fw_rst_reg;

  -- original: reset <= fw_rst_reg(31) or pon_rst_reg(31) or not pb0_q;
  -- pon_rst_reg used to be reset from pll lock
  pon_rst_reg <= pon_rst_reg(30 downto 0) & '0' when rising_edge(cmsclk) else
                 pon_rst_reg;
  pon_reset <= pon_rst_reg(31);

  reset <= fw_rst_reg(31) or pon_rst_reg(31);   -- Firmware reset

  FD_OPT_RESET : FD port map(Q => opt_reset_pulse_q, C => cmsclk, D => opt_reset_pulse);
  opt_rst_reg <= x"3FFFF000" when (opt_reset_pulse_q = '0' and opt_reset_pulse = '1') else
                 opt_rst_reg(30 downto 0) & '0' when rising_edge(cmsclk) else
                 opt_rst_reg;
  opt_reset <= opt_rst_reg(31) or pon_reset or mgt_reset;  -- Optical reset


  -------------------------------------------------------------------------------------------
  -- ODMB status signal generations
  -------------------------------------------------------------------------------------------

  -- TODO: unfinished counting to be filled
  DCFEB_RXSTAT_CNT : for dev in 1 to NCFEB generate
  begin
    C_GODDCRC_CNT : COUNT_EDGES port map(COUNT => goodcrc_cnt(dev), CLK => usrclk_mgtc, RST => reset, DIN => dcfeb_crc_valid(dev));
    C_DVALID_CNT  : COUNT_EDGES port map(COUNT => dcfeb_dvalid_cnt(dev), CLK => usrclk_mgtc, RST => reset, DIN => dcfeb_rxd_valid(dev));
    C_BAD_RX_CNT  : COUNT_EDGES port map(COUNT => dcfeb_bad_rx_cnt(dev), CLK => usrclk_mgtc, RST => reset, DIN => dcfeb_bad_rx(dev));
  end generate DCFEB_RXSTAT_CNT;

  -------------------------------------------------------------------------------------------
  -- Debug
  -------------------------------------------------------------------------------------------

  --DIAGOUT <= diagout_inner; --meta:comment_for_odmb

  -------------------------------------------------------------------------------------------
  -- Handle data readout
  -------------------------------------------------------------------------------------------

  odmb_status_pro : process (odmb_data_sel, VME_GAP_B, VME_GA_B)
  begin

    case odmb_data_sel is

      --debug register
      when x"06" => odmb_data <= x"7E57";

      when x"20" => odmb_data <= "0000000000" & VME_GAP_B & VME_GA_B;

      -- FIXME: Use dcfeb_dvalid_cnt in place of into_cafifo_dav_cnt for now
      when x"41" => odmb_data <= dcfeb_dvalid_cnt(1);
      when x"42" => odmb_data <= dcfeb_dvalid_cnt(2);
      when x"43" => odmb_data <= dcfeb_dvalid_cnt(3);
      when x"44" => odmb_data <= dcfeb_dvalid_cnt(4);
      when x"45" => odmb_data <= dcfeb_dvalid_cnt(5);
      when x"46" => odmb_data <= dcfeb_dvalid_cnt(6);
      when x"47" => odmb_data <= dcfeb_dvalid_cnt(7);
                    -- when x"48" => odmb_data <= into_cafifo_dav_cnt(8);
                    -- when x"49" => odmb_data <= into_cafifo_dav_cnt(9);

      when x"5A" => odmb_data <= ccb_cmd_reg;
      when x"5B" => odmb_data <= ccb_data_reg;
      when x"5C" => odmb_data <= ccb_other_reg;
      when x"5D" => odmb_data <= ccb_rsv_reg;

      when x"61" => odmb_data <= goodcrc_cnt(1);
      when x"62" => odmb_data <= goodcrc_cnt(2);
      when x"63" => odmb_data <= goodcrc_cnt(3);
      when x"64" => odmb_data <= goodcrc_cnt(4);
      when x"65" => odmb_data <= goodcrc_cnt(5);
      when x"66" => odmb_data <= goodcrc_cnt(6);
      when x"67" => odmb_data <= goodcrc_cnt(7);

      when others => odmb_data <= (others => '1');
    end case;
  end process;

  -------------------------------------------------------------------------------------------
  -- Sub-modules
  -------------------------------------------------------------------------------------------

  MBV : ODMB_VME
    generic map (
      NCFEB => NCFEB
      )
    port map (
      CLK160         => mgtclk1,
      CLK40          => cmsclk,
      CLK10          => sysclk10,
      CLK2P5         => sysclk2p5,
      CLK1P25        => sysclk1p25,

      VME_DATA_IN    => vme_data_in_buf,
      VME_DATA_OUT   => vme_data_out_buf,
      VME_GAP_B      => VME_GAP_B,
      VME_GA_B       => VME_GA_B,
      VME_ADDR       => VME_ADDR,
      VME_AM         => VME_AM,
      VME_AS_B       => VME_AS_B,
      VME_DS_B       => VME_DS_B,
      VME_LWORD_B    => VME_LWORD_B,
      VME_WRITE_B    => VME_WRITE_B,
      VME_IACK_B     => VME_IACK_B,
      VME_BERR_B     => VME_BERR_B,
      VME_SYSFAIL_B  => VME_SYSFAIL_B,
      VME_DTACK_B    => VME_DTACK_KUS_B,
      VME_OE_B       => vme_oe_b,
      VME_DIR_B      => vme_dir_b,      -- to be used in IOBUF

      DCFEB_TCK      => dcfeb_tck,
      DCFEB_TMS      => dcfeb_tms,
      DCFEB_TDI      => dcfeb_tdi,
      DCFEB_TDO      => dcfeb_tdo,
      DCFEB_DONE     => DCFEB_DONE,
      DCFEB_INITJTAG => dcfeb_initjtag,

      LVMB_PON    => LVMB_PON,
      PON_LOAD_B  => PON_LOAD_B,
      PON_OE      => PON_OE,
      R_LVMB_PON  => MON_LVMB_PON,
      LVMB_CSB    => LVMB_CSB,
      LVMB_SCLK   => LVMB_SCLK,
      LVMB_SDIN   => LVMB_SDIN,
      LVMB_SDOUT  => lvmb_sdout,

      OTMB        => OTMB,
      RAWLCT      => RAWLCT,
      OTMB_DAV    => OTMB_DAV,
      OTMB_FF_CLK => OTMB_FF_CLK,
      RSVTD_IN    => RSVTD_IN,
      RSVTD_OUT   => RSVTD_OUT,
      LCT_RQST    => LCT_RQST,

      FW_RESET => fw_reset,
      L1A_RESET_PULSE => l1a_reset_pulse,
      OPT_RESET_PULSE => opt_reset_pulse,
      TEST_INJ => test_inj,
      TEST_PLS => test_pls,
      TEST_BC0 => test_bc0,
      TEST_PED => test_ped,
      TEST_LCT => test_lct,
      MASK_L1A => mask_l1a,
      MASK_PLS => mask_pls,
      ODMB_CAL => odmb_ctrl_reg(0),
      MUX_DATA_PATH => odmb_ctrl_reg(7),
      MUX_TRIGGER => odmb_ctrl_reg(9),
      MUX_LVMB => odmb_ctrl_reg(10),
      ODMB_PED => odmb_ctrl_reg(14 downto 13),
      ODMB_DATA => odmb_data,
      ODMB_DATA_SEL => odmb_data_sel,

      LCT_L1A_DLY      => lct_l1a_dly,
      CABLE_DLY        => cable_dly,
      OTMB_PUSH_DLY    => open,
      ALCT_PUSH_DLY    => open,
      BX_DLY           => open,
      INJ_DLY          => inj_dly,
      EXT_DLY          => ext_dly,
      CALLCT_DLY       => callct_dly,
      ODMB_ID          => open,
      NWORDS_DUMMY     => nwords_dummy,
      KILL             => kill,
      CRATEID          => open,
      CHANGE_REG_DATA  => change_reg_data,
      CHANGE_REG_INDEX => change_reg_index,

      MGT_PRBS_TYPE        => mgt_prbs_type,
      DDU_PRBS_TX_EN       => ddu_prbs_tx_en,
      DDU_PRBS_RX_EN       => ddu_prbs_rx_en,
      DDU_PRBS_TST_CNT     => ddu_prbs_tst_cnt,
      DDU_PRBS_ERR_CNT     => ddu_prbs_err_cnt,
      SPY_PRBS_TX_EN       => spy_prbs_tx_en,
      SPY_PRBS_RX_EN       => spy_prbs_rx_en,
      SPY_PRBS_TST_CNT     => spy_prbs_tst_cnt,
      SPY_PRBS_ERR_CNT     => spy_prbs_err_cnt,
      DCFEB_PRBS_FIBER_SEL => dcfeb_prbs_fiber_sel,
      DCFEB_PRBS_EN        => dcfeb_prbs_en,
      DCFEB_PRBS_RST       => dcfeb_prbs_rst,
      DCFEB_PRBS_RD_EN     => dcfeb_prbs_rd_en,
      DCFEB_RXPRBSERR      => dcfeb_rxprbserr,
      DCFEB_PRBS_ERR_CNT   => dcfeb_prbs_err_cnt,

      ADC_CS_B             => ADC_CS_B, 
      ADC_DIN              => ADC_DIN, 
      ADC_SCK              => ADC_SCK,  
      ADC_DOUT             => ADC_DOUT, 

      DIAGOUT   => diagout_inner,
      RST       => reset,
      PON_RESET => pon_reset
      );

  MBC : ODMB_CTRL
    generic map (
      NCFEB => NCFEB
      )
    port map (
      CLK80 => sysclk80,
      CLK40 => cmsclk,

      TEST_CCBINJ => test_inj,
      TEST_CCBPLS => test_pls,
      TEST_CCBPED => test_ped,

      CAL_MODE => odmb_ctrl_reg(0),
      PEDESTAL => odmb_ctrl_reg(13),

      RAW_L1A => raw_l1a,

      LCT_L1A_DLY => lct_l1a_dly,
      INJ_DLY     => inj_dly,
      EXT_DLY     => ext_dly,
      CALLCT_DLY  => callct_dly,

      DCFEB_INJPULSE  => premask_injpls,
      DCFEB_EXTPULSE  => premask_extpls,
      DCFEB_L1A       => odmbctrl_l1a,
      DCFEB_L1A_MATCH => odmbctrl_l1a_match,

      DIAGOUT => open,
      RST     => reset
      );

  -------------------------------------------------------------------------------------------
  -- Constant driver for firefly selector/reset pins
  -------------------------------------------------------------------------------------------
  RX12_I2C_ENA <= '0';
  RX12_CS_B <= '1';
  RX12_RST_B <= '1';
  TX12_I2C_ENA <= '0';
  TX12_CS_B <= '1';
  TX12_RST_B <= '1';
  B04_I2C_ENA <= '0';
  B04_CS_B <= '1';
  B04_RST_B <= '1';
  SPY_TDIS <= '0';

  -------------------------------------------------------------------------------------------
  -- Optical ports for the SPY channel
  -------------------------------------------------------------------------------------------
  DAQ_SPY_SEL <= SPY_SEL; -- set for constant
  spy_rx_n <= DAQ_SPY_RX_N when SPY_SEL = '1' else '0';
  spy_rx_p <= DAQ_SPY_RX_P when SPY_SEL = '1' else '0';

  GTH_SPY : mgt_spy
    port map (
      mgtrefclk       => mgtrefclk1_226,
      txusrclk        => usrclk_spy_tx,
      rxusrclk        => usrclk_spy_rx,
      sysclk          => cmsclk,    -- maximum DRP clock frequency 62.5 MHz for 1.25 Gb/s line rate
      spy_rx_n        => spy_rx_n,
      spy_rx_p        => spy_rx_p,
      spy_tx_n        => SPY_TX_N,
      spy_tx_p        => SPY_TX_P,
      txready         => spy_txready,
      rxready         => spy_rxready,
      txdata          => spy_txdata,
      txd_valid       => spy_txd_valid,
      txdiffctrl      => spy_txdiffctrl,
      loopback        => spy_loopback,
      rxdata          => spy_rxdata,
      rxd_valid       => spy_rxd_valid,
      bad_rx          => spy_bad_rx,
      prbs_type       => mgt_prbs_type,
      prbs_tx_en      => spy_prbs_tx_en,
      prbs_rx_en      => spy_prbs_rx_en,
      prbs_tst_cnt    => spy_prbs_tst_cnt,
      prbs_err_cnt    => spy_prbs_err_cnt,
      reset           => opt_reset
      );


  GTH_DCFEB : mgt_cfeb
    generic map (
      NLINK     => 7,  -- number of links
      DATAWIDTH => 16  -- user data width
      )
    port map (
      mgtrefclk    => mgtrefclk0_224,
      rxusrclk     => usrclk_mgtc,
      sysclk       => sysclk80,
      daq_rx_n     => DAQ_RX_N(6 downto 0),
      daq_rx_p     => DAQ_RX_P(6 downto 0),
      rxdata_feb1  => dcfeb1_data,
      rxdata_feb2  => dcfeb2_data,
      rxdata_feb3  => dcfeb3_data,
      rxdata_feb4  => dcfeb4_data,
      rxdata_feb5  => dcfeb5_data,
      rxdata_feb6  => dcfeb6_data,
      rxdata_feb7  => dcfeb7_data,
      rxd_valid    => dcfeb_rxd_valid,
      crc_valid    => dcfeb_crc_valid,
      rxready      => dcfeb_rxready,
      bad_rx       => dcfeb_bad_rx,
      kill_rxout   => kill(7 downto 1),
      kill_rxpd    => (others => '0'),
      fifo_full    => dcfeb_datafifo_full,
      fifo_afull   => dcfeb_datafifo_afull,
      prbs_type    => mgt_prbs_type,
      prbs_rx_en   => dcfeb_prbs_rx_en,
      prbs_tst_cnt => dcfeb_prbs_tst_cnt,
      prbs_err_cnt => dcfeb_prbs_err_cnt,
      reset        => opt_reset
      );

  GTH_ALCT : mgt_alct
    port map (
      mgtrefclk       => mgtrefclk0_225,
      rxusrclk        => usrclk_mgta,
      sysclk          => sysclk80,
      daq_rx_n        => DAQ_RX_N(7),
      daq_rx_p        => DAQ_RX_P(7),
      rxready         => alct_rxready,
      rxdata          => alct_rxdata,
      rxd_valid       => alct_rxd_valid,
      bad_rx          => alct_bad_rx,
      prbs_type       => mgt_prbs_type,
      prbs_rx_en      => alct_prbs_rx_en(ALCT_NLINK-1 downto 0),
      prbs_tst_cnt    => alct_prbs_tst_cnt,
      prbs_err_cnt    => alct_prbs_err_cnt,
      reset           => opt_reset
      );

  GTH_DDU : mgt_ddu
    generic map (
      NCHANNL     => 4,            -- number of (firmware) channels (max of TX/RX links)
      NRXLINK     => DDU_NRXLINK,  -- number of (physical) RX links
      NTXLINK     => DDU_NTXLINK,  -- number of (physical) TX links
      TXDATAWIDTH => DDUTXDWIDTH,  -- transmitter user data width
      RXDATAWIDTH => DDURXDWIDTH   -- receiver user data width
      )
    port map (
      mgtrefclk    => mgtrefclk0_227,
      txusrclk     => usrclk_ddu_tx,
      rxusrclk     => usrclk_ddu_rx,
      sysclk       => sysclk80,
      daq_tx_n     => DAQ_TX_N,
      daq_tx_p     => DAQ_TX_P,
      bck_rx_n     => BCK_PRS_N,
      bck_rx_p     => BCK_PRS_P,
      b04_rx_n     => B04_RX_N,
      b04_rx_p     => B04_RX_P,
      txdata_ch0   => ddu_txdata1,
      txdata_ch1   => ddu_txdata2,
      txdata_ch2   => ddu_txdata3,
      txdata_ch3   => ddu_txdata4,
      txd_valid    => ddu_txd_valid,
      rxdata_ch0   => ddu_rxdata1,
      rxdata_ch1   => ddu_rxdata2,
      rxdata_ch2   => ddu_rxdata3,
      rxdata_ch3   => ddu_rxdata4,
      rxd_valid    => ddu_rxd_valid,
      bad_rx       => ddu_bad_rx,
      rxready      => ddu_rxready,
      txready      => ddu_txready,
      prbs_type    => mgt_prbs_type,
      prbs_rx_en   => ddu_prbs_rx_en(DDU_NRXLINK downto 1),
      prbs_tst_cnt => ddu_prbs_tst_cnt,
      prbs_err_cnt => ddu_prbs_err_cnt,
      reset        => opt_reset
      );

  -------------------------------------------------------------------------------------------
  -- Tester
  -------------------------------------------------------------------------------------------
  --u_mgt_tester : prbs_tester
  --  generic map (
  --    DDU_NRXLINK   => DDU_NRXLINK,
  --    SPYDATAWIDTH  => 16,
  --    FEBDATAWIDTH  => 16,
  --    DDUTXDWIDTH   => DDUTXDWIDTH,
  --    DDURXDWIDTH   => DDURXDWIDTH,
  --    SPY_PATTERN   => 0,
  --    DDU_PATTERN   => 0
  --    )
  --  port map (
  --    sysclk         => cmsclk,
  --    usrclk_spy_tx  => usrclk_spy_tx,
  --    txdata_spy     => spy_txdata,
  --    txd_valid_spy  => spy_txd_valid,
  --    usrclk_spy_rx  => usrclk_spy_rx,
  --    rxdata_spy     => spy_rxdata,
  --    rxd_valid_spy  => spy_rxd_valid,
  --    rxready_spy    => spy_rxready,
  --    usrclk_ddu_tx  => usrclk_ddu_tx,
  --    txdata_ddu1    => ddu_txdata1,
  --    txdata_ddu2    => ddu_txdata2,
  --    txdata_ddu3    => ddu_txdata3,
  --    txdata_ddu4    => ddu_txdata4,
  --    txd_valid_ddu  => ddu_txd_valid,
  --    usrclk_ddu_rx  => usrclk_ddu_rx,
  --    rxdata_ddu1    => ddu_rxdata1,
  --    rxdata_ddu2    => ddu_rxdata2,
  --    rxdata_ddu3    => ddu_rxdata3,
  --    rxdata_ddu4    => ddu_rxdata4,
  --    rxd_valid_ddu  => ddu_rxd_valid,
  --    rxready_ddu    => ddu_rxready,
  --    usrclk_mgtc    => usrclk_mgtc,
  --    rxdata_cfeb1   => dcfeb1_data,
  --    rxdata_cfeb2   => dcfeb2_data,
  --    rxdata_cfeb3   => dcfeb3_data,
  --    rxdata_cfeb4   => dcfeb4_data,
  --    rxdata_cfeb5   => dcfeb5_data,
  --    rxdata_cfeb6   => dcfeb6_data,
  --    rxdata_cfeb7   => dcfeb7_data,
  --    rxd_valid_mgtc => dcfeb_rxd_valid,
  --    rxready_mgtc   => dcfeb_rxready,
  --    usrclk_mgta    => usrclk_mgta,
  --    rxdata_alct    => alct_rxdata,
  --    rxd_valid_alct => alct_rxd_valid,
  --    rxready_alct   => alct_rxready,
  --    rxdata_daq8    => daq8_rxdata,
  --    rxdata_daq9    => daq9_rxdata,
  --    rxdata_daq10   => daq10_rxdata,
  --    mgta_dvalid    => mgta_data_valid,
  --    led_out        => LEDS_CFV(7 downto 0),
  --    reset          => mgt_reset
  --    );

  -------------------------------------------------------------------------------------------
  -- SYSMON module instantiation
  -------------------------------------------------------------------------------------------
--  sysmone1_inst : SYSMONE1
--    port map (
--      ALM => open,
--      OT => open,
--      DO => open,
--      DRDY => open,
--      BUSY => open,
--      CHANNEL => open,
--      EOC => open,
--      EOS => open,
--      JTAGBUSY => open,
--      JTAGLOCKED => open,
--      JTAGMODIFIED => open,
--      MUXADDR => open,
--      VAUXN => SYSMON_N, -- 16 bits AD[0-15]N
--      VAUXP => SYSMON_P, -- 16 bits AD[0-15]P
--      CONVST => '0',
--      CONVSTCLK => '0',
--      RESET => '0',
--      VN => '0',
--      VP => '0',
--      DADDR => X"00",
--      DCLK => '0',
--      DEN => '0',
--      DI => X"0000",
--      DWE => '0',
--      I2C_SCLK => '0',
--      I2C_SDA => '0'
--      );

end Behavioral;
