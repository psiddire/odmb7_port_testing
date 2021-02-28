library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

--library work;
use work.ucsb_types.all;

entity odmb7_ucsb_dev is
  generic (
    NREGS       : integer := 16;
    NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
  );
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

    DCFEB_TCK_P    : out std_logic_vector(NCFEB downto 1); -- Bank 68
    DCFEB_TCK_N    : out std_logic_vector(NCFEB downto 1); -- Bank 68
    DCFEB_TMS_P    : out std_logic;                        -- Bank 68
    DCFEB_TMS_N    : out std_logic;                        -- Bank 68
    DCFEB_TDI_P    : out std_logic;                        -- Bank 68
    DCFEB_TDI_N    : out std_logic;                        -- Bank 68
    DCFEB_TDO_P    : in  std_logic_vector(NCFEB downto 1); -- "C_TDO" in Bank 67-68
    DCFEB_TDO_N    : in  std_logic_vector(NCFEB downto 1); -- "C_TDO" in Bank 67-68
    DCFEB_DONE     : in  std_logic_vector(NCFEB downto 1); -- "DONE_?" in Bank 68
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

    --------------------------------
    -- LVMB control/monitor signals
    --------------------------------
    LVMB_PON     : out std_logic_vector(7 downto 0);
    PON_LOAD     : out std_logic;
    PON_OE_B     : out std_logic;
    MON_LVMB_PON : in  std_logic_vector(7 downto 0);
    LVMB_CSB     : out std_logic_vector(6 downto 0);
    LVMB_SCLK    : out std_logic;
    LVMB_SDIN    : out std_logic;
    LVMB_SDOUT_P : in  std_logic;       -- C_LVMB_SDOUT_P in Bank 67
    LVMB_SDOUT_N : in  std_logic;       -- C_LVMB_SDOUT_N in Bank 67

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

    -- SPY_TX_P     : out std_logic;        -- output to PC
    -- SPY_TX_N     : out std_logic;        -- output to PC
    -- DAQ_TX_P     : out std_logic_vector(4 downto 1); -- B04 TX, output to FED
    -- DAQ_TX_N     : out std_logic_vector(4 downto 1); -- B04 TX, output to FED

    --------------------------------
    -- Optical control signals
    --------------------------------
    DAQ_SPY_SEL    : out std_logic;      -- 0 for DAQ_RX_P/N11, 1 for SPY_RX_P/N

    RX12_I2C_ENA   : out std_logic;
    RX12_SDA       : inout std_logic;
    RX12_SCL       : inout std_logic;
    RX12_CS_B      : out std_logic;
    RX12_RST_B     : out std_logic;
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
    KUS_DL_SEL    : out std_logic;  -- Bank 47, ODMB JTAG path select
    FPGA_SEL      : out std_logic;  -- Bank 47, clock synthesizaer control input select
    RST_CLKS_B    : out std_logic;  -- Bank 47, clock synthesizaer reset
    CCB_HARDRST_B : in std_logic;   -- Bank 45
    CCB_SOFT_RST  : in std_logic;   -- Bank 45
    ODMB_DONE     : in std_logic;   -- "DONE" in bank 66 (pin L9), monitor DONE_0 from Bank 0 (pin N7) 

    --------------------------------
    -- Clock synthesizer I2C
    --------------------------------

    --------------------------------
    -- SYSMON ports
    --------------------------------
    SYSMON_P      : in std_logic_vector(15 downto 0);
    SYSMON_N      : in std_logic_vector(15 downto 0);
    ADC_CS_B      : out std_logic_vector(4 downto 0);
    ADC_SCK       : out std_logic;
    ADC_DIN       : out std_logic;
    ADC_DOUT      : in std_logic;

    --------------------------------
    -- Others
    --------------------------------
    LEDS_CFV      : out std_logic_vector(11 downto 0)

    );
end odmb7_ucsb_dev;

architecture Behavioral of odmb7_ucsb_dev is
  -- Constants
  constant bw_data  : integer := 16; -- data bit width

  component odmb7_clocking is
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
      PON_LOAD     : out std_logic;
      PON_OE_B     : out std_logic;
      MON_LVMB_PON : in  std_logic_vector(7 downto 0);
      LVMB_CSB     : out std_logic_vector(6 downto 0);
      LVMB_SCLK    : out std_logic;
      LVMB_SDIN    : out std_logic;
      LVMB_SDOUT_P : in  std_logic;
      LVMB_SDOUT_N : in  std_logic;

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
      LCT_L1A_DLY   : out std_logic_vector(5 downto 0);
      CABLE_DLY     : out integer range 0 to 1;
      OTMB_PUSH_DLY : out integer range 0 to 63;
      ALCT_PUSH_DLY : out integer range 0 to 63;
      BX_DLY        : out integer range 0 to 4095;
      INJ_DLY       : out std_logic_vector(4 downto 0);
      EXT_DLY       : out std_logic_vector(4 downto 0);
      CALLCT_DLY    : out std_logic_vector(3 downto 0);
      ODMB_ID      : out std_logic_vector(15 downto 0);
      NWORDS_DUMMY : out std_logic_vector(15 downto 0);
      KILL         : out std_logic_vector(NCFEB+2 downto 1);
      CRATEID      : out std_logic_vector(7 downto 0);
      CHANGE_REG_DATA      : in std_logic_vector(15 downto 0);
      CHANGE_REG_INDEX     : in integer range 0 to NREGS;

      --------------------
      -- DDU/SPY/DCFEB/ALCT Optical PRBS test signals
      --------------------
      MGT_PRBS_TYPE        : out std_logic_vector(3 downto 0); -- DDU/SPY/DCFEB/ALCT Common PRBS type
      DDU_PRBS_TX_EN       : out std_logic_vector(3 downto 0);
      DDU_PRBS_RX_EN       : out std_logic_vector(3 downto 0);
      DDU_PRBS_TST_CNT     : out std_logic_vector(15 downto 0);
      DDU_PRBS_ERR_CNT     : in  std_logic_vector(15 downto 0);
      SPY_PRBS_TX_EN       : out std_logic;
      SPY_PRBS_RX_EN       : out std_logic;
      SPY_PRBS_TST_CNT     : out std_logic_vector(15 downto 0);
      SPY_PRBS_ERR_CNT     : in  std_logic_vector(15 downto 0);
      DCFEB_PRBS_FIBER_SEL : out std_logic_vector(3 downto 0);
      DCFEB_PRBS_EN        : out std_logic;
      DCFEB_PRBS_RST       : out std_logic;
      DCFEB_PRBS_RD_EN     : out std_logic;
      DCFEB_RXPRBSERR      : in  std_logic;
      DCFEB_PRBS_ERR_CNT   : in  std_logic_vector(15 downto 0);

      --------------------
      -- Other
      --------------------
      DIAGOUT     : out std_logic_vector (17 downto 0); -- for debugging
      RST         : in std_logic
      );
  end component;

  component ODMB_CTRL is
    generic (
      NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
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

  -- component alct_otmb_data_gen is
  --   port(
  --     clk            : in std_logic;
  --     rst            : in std_logic;
  --     l1a            : in std_logic;
  --     alct_l1a_match : in std_logic;
  --     otmb_l1a_match : in std_logic;
  --     nwords_dummy   : in std_logic_vector(15 downto 0);

  --     alct_dv   : out std_logic;
  --     alct_data : out std_logic_vector(15 downto 0);
  --     otmb_dv   : out std_logic;
  --     otmb_data : out std_logic_vector(15 downto 0));
  -- end component;

  --------------------------------------
  -- VME signals
  --------------------------------------
  -- signal cmd_adrs     : std_logic_vector (15 downto 0);
  signal vme_dir_b    : std_logic;
  signal vme_data_out_buf, vme_data_in_buf : std_logic_vector(15 downto 0) := (others => '0');

  --------------------------------------
  -- Clock synthesizer and clock signals
  --------------------------------------
  signal mgtrefclk0_224 : std_logic;
  signal mgtrefclk0_225 : std_logic;
  signal mgtrefclk0_226 : std_logic;
  signal mgtrefclk1_226 : std_logic;
  signal mgtrefclk0_227 : std_logic;
  signal mgtrefclk1_227 : std_logic;
  signal gth_sysclk_i : std_logic;
  signal clk_sysclk625k : std_logic;
  signal clk_sysclk1p25 : std_logic;
  signal clk_sysclk2p5 : std_logic;
  signal clk_sysclk10 : std_logic;
  signal clk_sysclk20 : std_logic;
  signal clk_sysclk40 : std_logic;
  signal clk_sysclk80 : std_logic;
  signal clk_cmsclk : std_logic;
  signal clk_emcclk : std_logic;
  signal clk_lfclk : std_logic;
  signal clk_gp6 : std_logic;
  signal clk_gp7 : std_logic;
  signal clk_mgtclk1 : std_logic;
  signal clk_mgtclk2 : std_logic;
  signal clk_mgtclk3 : std_logic;
  signal clk_mgtclk4 : std_logic;
  signal clk_mgtclk5 : std_logic;
  signal clk_mgtclk125 : std_logic;

  --------------------------------------
  -- PPIB/DCFEB signals
  --------------------------------------
  signal dcfeb_tck    : std_logic_vector (NCFEB downto 1) := (others => '0');
  signal dcfeb_tms    : std_logic := '0';
  signal dcfeb_tdi    : std_logic := '0';
  signal dcfeb_tdo    : std_logic_vector (NCFEB downto 1) := (others => '0');

  signal reset_pulse, reset_pulse_q : std_logic := '0';
  signal l1acnt_rst, l1a_reset_pulse, l1a_reset_pulse_q : std_logic := '0';
  signal premask_injpls, premask_extpls, dcfeb_injpls, dcfeb_extpls : std_logic := '0';
  signal test_bc0, pre_bc0, dcfeb_bc0, dcfeb_resync : std_logic := '0';
  signal dcfeb_l1a, masked_l1a, odmbctrl_l1a : std_logic := '0';
  signal dcfeb_l1a_match, masked_l1a_match, odmbctrl_l1a_match : std_logic_vector(NCFEB downto 1) := (others => '0');

  -- signals to generate dcfeb_initjtag when DCFEBs are done programming
  signal pon_rst_reg : std_logic_vector(31 downto 0) := x"00FFFFFF";
  signal pon_reset : std_logic := '0';
  signal done_cnt_en, done_cnt_rst                           : std_logic_vector(NCFEB downto 1);
  type done_cnt_type is array (NCFEB downto 1) of integer range 0 to 3;
  signal done_cnt                                            : done_cnt_type;
  type done_state_type is (DONE_IDLE, DONE_LOW, DONE_COUNTING);
  type done_state_array_type is array (NCFEB downto 1) of done_state_type;
  signal done_next_state, done_current_state                 : done_state_array_type;
  signal dcfeb_done_pulse : std_logic_vector(NCFEB downto 1) := (others => '0');
  signal dcfeb_initjtag : std_logic := '0';
  signal dcfeb_initjtag_d : std_logic := '0';
  signal dcfeb_initjtag_dd : std_logic := '0';

  -- OTMB backplane communication
  signal otmb_rx : std_logic_vector(5 downto 0);
  signal otmb_tx : std_logic_vector(48 downto 0);

  -- CAFIFO related signals place holder
  signal cafifo_l1a          : std_logic;
  signal cafifo_l1a_match_in : std_logic_vector(NCFEB+2 downto 1);
  signal nwords_dummy  : std_logic_vector(15 downto 0);

  -- ALCT signals
  signal gen_alct_data_valid : std_logic;
  signal gen_alct_data       : std_logic_vector(15 downto 0);
  signal alct_data_valid     : std_logic;
  signal alct_data           : std_logic_vector(15 downto 0);
  signal alct_q, alct_qq     : std_logic_vector(17 downto 0);

  signal rx_alct_data_valid  : std_logic;

  signal alct_fifo_data_valid : std_logic;
  signal alct_fifo_data_in    : std_logic_vector(17 downto 0);
  signal alct_fifo_data_out   : std_logic_vector (17 downto 0);

  -- OTMB signals
  signal gen_otmb_data_valid : std_logic;
  signal gen_otmb_data       : std_logic_vector(15 downto 0);
  signal otmb_data_valid     : std_logic;
  signal otmb_data           : std_logic_vector(15 downto 0);
  signal otmb_q, otmb_qq     : std_logic_vector(17 downto 0);

  signal rx_otmb_data_valid : std_logic;

  signal otmb_fifo_data_valid : std_logic;
  signal otmb_fifo_data_in    : std_logic_vector(17 downto 0);
  signal otmb_fifo_data_out   : std_logic_vector (17 downto 0);

  signal alct_dav_sync_out, otmb_dav_sync_out : std_logic;

  --------------------------------------
  -- MGT PRBS signals as place holder
  --------------------------------------
  signal mgt_prbs_type : std_logic_vector(3 downto 0);

  signal spy_prbs_tx_en : std_logic;
  signal spy_prbs_rx_en : std_logic;
  signal spy_prbs_tst_cnt : std_logic_vector(15 downto 0);
  signal spy_prbs_err_cnt : std_logic_vector(15 downto 0) := (others => '0');

  signal ddu_prbs_tx_en : std_logic_vector(3 downto 0);
  signal ddu_prbs_rx_en : std_logic_vector(3 downto 0);
  signal ddu_prbs_tst_cnt : std_logic_vector(15 downto 0);
  signal ddu_prbs_err_cnt : std_logic_vector(15 downto 0) := (others => '0');

  signal dcfeb_prbs_rx_en : std_logic_vector(7 downto 1);
  signal dcfeb_prbs_tst_cnt : std_logic_vector(15 downto 0);

  signal dcfeb_prbs_fiber_sel : std_logic_vector(3 downto 0);
  signal dcfeb_prbs_en : std_logic;
  signal dcfeb_prbs_rst : std_logic;
  signal dcfeb_prbs_rd_en : std_logic;
  signal dcfeb_rxprbserr :  std_logic;
  signal dcfeb_prbs_err_cnt :  std_logic_vector(15 downto 0) := (others => '0');

  signal alct_prbs_rx_en : std_logic_vector(4 downto 1);
  signal alct_prbs_tst_cnt : std_logic_vector(15 downto 0);
  signal alct_prbs_err_cnt : std_logic_vector(15 downto 0) := (others => '0');

  --------------------------------------
  -- Triggers
  --------------------------------------
  signal test_lct, test_pb_lct, test_l1a : std_logic := '0';
  signal raw_l1a : std_logic := '0';
  
  --------------------------------------
  -- Internal configuration signals
  --------------------------------------
  signal mask_pls : std_logic := '0';
  signal mask_l1a : std_logic_vector(NCFEB downto 0) := (others => '0');
  signal lct_l1a_dly : std_logic_vector(5 downto 0) := (others => '0');
  signal inj_dly : std_logic_vector(4 downto 0) := (others => '0');
  signal ext_dly : std_logic_vector(4 downto 0) := (others => '0');
  signal callct_dly : std_logic_vector(3 downto 0) := (others => '0');
  signal cable_dly : integer range 0 to 1;
  signal odmb_ctrl_reg : std_logic_vector(15 downto 0) := (others => '0');
  signal kill : std_logic_vector(NCFEB+2 downto 1) := (others => '0');
  signal change_reg_data  : std_logic_vector(15 downto 0);
  signal change_reg_index : integer range 0 to NREGS := NREGS;

  --------------------------------------
  -- ODMB VME<->ODMB CTRL signals
  --------------------------------------
  signal test_inj, test_pls, test_ped : std_logic := '0';

  --------------------------------------
  -- Reset signals
  --------------------------------------
  signal fw_reset, fw_reset_q : std_logic := '0';
  signal ccb_softrst_b_q : std_logic := '1'; --no CCB currently
  signal fw_rst_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal reset : std_logic := '0';

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
  PPIB_OUT_EN_B <= '0';

  -------------------------------------------------------------------------------------------
  -- Constant driver for transceiver selector/reset pins
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
  -- Handle clock signals
  -------------------------------------------------------------------------------------------
  u_clocking : odmb7_clocking
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
      clk_sysclk625k => clk_sysclk625k,
      clk_sysclk1p25 => clk_sysclk1p25,
      clk_sysclk2p5  => clk_sysclk2p5,
      clk_sysclk10   => clk_sysclk10,
      clk_sysclk20   => clk_sysclk20,
      clk_sysclk40   => clk_sysclk40,
      clk_sysclk80   => clk_sysclk80,
      clk_cmsclk     => clk_cmsclk,
      clk_emcclk     => clk_emcclk,
      clk_lfclk      => clk_lfclk,
      clk_gp6        => clk_gp6,
      clk_gp7        => clk_gp7,
      clk_mgtclk1    => clk_mgtclk1,
      clk_mgtclk2    => clk_mgtclk2,
      clk_mgtclk3    => clk_mgtclk3,
      clk_mgtclk4    => clk_mgtclk4,
      clk_mgtclk5    => clk_mgtclk5,
      clk_mgtclk125  => clk_mgtclk125
      );

  -------------------------------------------------------------------------------------------
  -- Handle VME signals
  -------------------------------------------------------------------------------------------
  -- Handle VME data direction line
  KUS_VME_DIR <= vme_dir_b;
  GEN_VMEOUT_16 : for I in 0 to 15 generate
  begin
    VME_BUF : IOBUF port map(O => vme_data_in_buf(I), IO => VME_DATA(I), I => vme_data_out_buf(I), T => vme_dir_b); 
  end generate GEN_VMEOUT_16;
  

  -------------------------------------------------------------------------------------------
  -- Handle PPIB/DCFEB signals
  -------------------------------------------------------------------------------------------
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
  RESETPULSE : PULSE2SAME port map(DOUT => reset_pulse, CLK_DOUT => clk_cmsclk, RST => '0', DIN => reset);
  FD_RESETPULSE_Q : FD port map (Q => reset_pulse_q,     C => clk_cmsclk, D => reset_pulse);
  FD_L1APULSE_Q   : FD port map (Q => l1a_reset_pulse_q, C => clk_cmsclk, D => l1a_reset_pulse);

  l1acnt_rst <= clk_sysclk20 and (l1a_reset_pulse or l1a_reset_pulse_q or reset_pulse or reset_pulse_q);
  pre_bc0    <= test_bc0;
  masked_l1a <= '0' when mask_l1a(0)='1' else odmbctrl_l1a;

  DS_RESYNC : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_resync, CLK => clk_cmsclk, NCYCLES => cable_dly, DIN => l1acnt_rst);
  DS_BC0    : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_bc0,    CLK => clk_cmsclk, NCYCLES => cable_dly, DIN => pre_bc0   );
  DS_L1A    : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_l1a,    CLK => clk_cmsclk, NCYCLES => cable_dly, DIN => masked_l1a);

  GEN_DCFEB_L1A_MATCH : for I in 1 to NCFEB generate
  begin
    masked_l1a_match(I) <= '0' when mask_l1a(I)='1' else odmbctrl_l1a_match(I);
    DS_L1A_MATCH : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_l1a_match(I), CLK => clk_cmsclk, NCYCLES => cable_dly, DIN => masked_l1a_match(I));
  end generate GEN_DCFEB_L1A_MATCH;

  -- FSM to handle initialization when DONE received from DCFEBs
  -- Generate dcfeb_initjtag
  done_fsm_regs : process (done_next_state, pon_reset, clk_sysclk10)
  begin
    for dev in 1 to NCFEB loop
      if (pon_reset = '1') then
        done_current_state(dev) <= DONE_LOW;
      elsif rising_edge(clk_sysclk10) then
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
  DS_DCFEB_INITJTAG    : DELAY_SIGNAL generic map(10) port map(DOUT => dcfeb_initjtag_d, CLK => clk_sysclk625k, NCYCLES => 10, DIN => dcfeb_initjtag_dd);
  PULSE_DCFEB_INITJTAG : NPULSE2FAST port map(DOUT => dcfeb_initjtag, CLK_DOUT => clk_sysclk2p5, RST => '0', NPULSE => 5, DIN => dcfeb_initjtag_d);

  -------------------------------------------------------------------------------------------
  -- Handle Triggers
  -------------------------------------------------------------------------------------------

  test_pb_lct <= test_lct;
  LCTDLY_GTRG : LCTDLY port map(DIN => test_pb_lct, CLK => clk_cmsclk, DELAY => lct_l1a_dly, DOUT => test_l1a);
  raw_l1a <= test_l1a;

  -------------------------------------------------------------------------------------------
  -- Handle Internal configuration signals
  -------------------------------------------------------------------------------------------
  
  --FIXME should change with bad_dcfeb_pulse and good_dcfeb_pulse, currently, KILL must be updated manually via VME command
  change_reg_data <= x"0" & "000" & kill(9) & kill(8) & kill(7 downto 1);
  change_reg_index <= NREGS;

  -------------------------------------------------------------------------------------------
  -- Handle reset signals
  -------------------------------------------------------------------------------------------

  FD_FW_RESET : FD port map (Q => fw_reset_q, C => clk_cmsclk, D => fw_reset);
  fw_rst_reg <= x"3FFFF000" when ((fw_reset_q = '0' and fw_reset = '1') or ccb_softrst_b_q = '0') else
                  fw_rst_reg(30 downto 0) & '0' when rising_edge(clk_cmsclk) else
                  fw_rst_reg;
  -- pon_rst_reg used to be reset from pll lock
  pon_rst_reg <= pon_rst_reg(30 downto 0) & '0' when rising_edge(clk_cmsclk) else
                 pon_rst_reg;
  pon_reset <= pon_rst_reg(31);
  reset <= fw_rst_reg(31) or pon_rst_reg(31); -- push button reset directly at PROGRAM_B
  -- original: reset <= fw_rst_reg(31) or pon_rst_reg(31) or not pb0_q;
  
  -------------------------------------------------------------------------------------------
  -- ALCT and OTMB data
  -------------------------------------------------------------------------------------------
  -- alct_otmb_data_gen_pm : alct_otmb_data_gen
  --   port map(
  --     -- Inputs
  --     clk            => clk_cmsclk,
  --     rst            => reset,
  --     l1a            => cafifo_l1a,
  --     alct_l1a_match => cafifo_l1a_match_in(NCFEB+2),
  --     otmb_l1a_match => cafifo_l1a_match_in(NCFEB+1),
  --     nwords_dummy   => nwords_dummy,
  --     -- Outputs
  --     alct_dv   => gen_alct_data_valid,
  --     alct_data => gen_alct_data,
  --     otmb_dv   => gen_otmb_data_valid,
  --     otmb_data => gen_otmb_data
  --     );

  -------------------------------------------------------------------------------------------
  -- Debug
  -------------------------------------------------------------------------------------------
  -- DIAGOUT(8 downto 0) <= diagout_inner(8 downto 0);
  -- DIAGOUT(9) <= reset;
  -- DIAGOUT(10) <= RST;
  -- DIAGOUT(11) <= fw_rst_reg(31);
  -- DIAGOUT(12) <= pon_rst_reg(31);
  -- DIAGOUT(17 downto 13) <= (others => '0');

  -------------------------------------------------------------------------------------------
  -- Handle data readout
  -------------------------------------------------------------------------------------------

  odmb_status_pro : process (odmb_data_sel, VME_GAP_B, VME_GA_B)
  begin
    case odmb_data_sel is
      --debug register
      when x"06" => odmb_data <= x"7E57";
      when x"20" => odmb_data <= "0000000000" & VME_GAP_B & VME_GA_B;
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
      CLK160         => clk_mgtclk1,
      CLK40          => clk_cmsclk,
      CLK10          => clk_sysclk10,
      CLK2P5	     => clk_sysclk2p5,
      CLK1P25	     => clk_sysclk1p25,

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
      VME_OE_B       => KUS_VME_OE_B,
      VME_DIR_B      => vme_dir_b,      -- to be used in IOBUF

      DCFEB_TCK      => dcfeb_tck,
      DCFEB_TMS      => dcfeb_tms,
      DCFEB_TDI      => dcfeb_tdi,
      DCFEB_TDO      => dcfeb_tdo,
      DCFEB_DONE     => DCFEB_DONE,
      DCFEB_INITJTAG => dcfeb_initjtag,

      LVMB_PON     => LVMB_PON,
      PON_LOAD     => PON_LOAD,
      PON_OE_B     => PON_OE_B,
      MON_LVMB_PON => MON_LVMB_PON,
      LVMB_CSB     => LVMB_CSB,
      LVMB_SCLK    => LVMB_SCLK,
      LVMB_SDIN    => LVMB_SDIN,
      LVMB_SDOUT_P => LVMB_SDOUT_P,
      LVMB_SDOUT_N => LVMB_SDOUT_N,

      OTMB        => OTMB,
      RAWLCT      => RAWLCT,
      OTMB_DAV    => OTMB_DAV,
      OTMB_FF_CLK => OTMB_FF_CLK,
      RSVTD_IN    => RSVTD_IN,
      RSVTD_OUT   => RSVTD_OUT,
      LCT_RQST    => LCT_RQST,
      
      FW_RESET => fw_reset,
      L1A_RESET_PULSE => l1a_reset_pulse,
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

      LCT_L1A_DLY => lct_l1a_dly,
      CABLE_DLY => cable_dly,
      OTMB_PUSH_DLY => open,
      ALCT_PUSH_DLY => open,
      BX_DLY => open,
      INJ_DLY => inj_dly, 
      EXT_DLY => ext_dly, 
      CALLCT_DLY => callct_dly,
      ODMB_ID => open,
      NWORDS_DUMMY => nwords_dummy,
      KILL => kill,
      CRATEID => open,
      CHANGE_REG_DATA => change_reg_data,
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

      DIAGOUT  => diagout_inner,
      RST      => reset
      );

  MBC : ODMB_CTRL 
    generic map (
      NCFEB => NCFEB
      )
    port map (
      CLK80 => clk_sysclk80,
      CLK40 => clk_cmsclk,

      TEST_CCBINJ => test_inj,
      TEST_CCBPLS => test_pls,
      TEST_CCBPED => test_ped, 

      CAL_MODE => odmb_ctrl_reg(0),
      PEDESTAL => odmb_ctrl_reg(13),

      RAW_L1A => raw_l1a,

      LCT_L1A_DLY => lct_l1a_dly,
      INJ_DLY => inj_dly, 
      EXT_DLY => ext_dly, 
      CALLCT_DLY => callct_dly, 
      
      DCFEB_INJPULSE => premask_injpls,
      DCFEB_EXTPULSE => premask_extpls,
      DCFEB_L1A => odmbctrl_l1a,                    
      DCFEB_L1A_MATCH => odmbctrl_l1a_match,        

      DIAGOUT => open,
      RST => reset
      );

end Behavioral;
