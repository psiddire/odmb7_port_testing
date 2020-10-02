library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

--library work;
use work.ucsb_types.all;

use work.odmb_consts.all;     -- for switch between sim and synthesis

entity ODMB7_UCSB_DEV is
  generic (
    NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
  );
  PORT (
    --------------------
    -- Clocks
    --------------------
    CMS_CLK_FPGA_P : in std_logic;   -- system clock: 40.07897 MHz
    CMS_CLK_FPGA_N : in std_logic;   -- system clock: 40.07897 MHz
    GP_CLK_6_P : in std_logic;       -- system clock: ? MHz
    GP_CLK_6_N : in std_logic;       -- system clock: ? MHz
    GP_CLK_7_P : in std_logic;       -- system clock: ? MHz, pretend 80
    GP_CLK_7_N : in std_logic;       -- system clock: ? MHz, pretend 80
    REF_CLK_1_P : in std_logic;      -- optical TX/RX refclk, 160 MHz
    REF_CLK_1_N : in std_logic;      -- optical TX/RX refclk, 160 MHz
    REF_CLK_2_P : in std_logic;      -- optical TX/RX refclk, 160 MHz
    REF_CLK_2_N : in std_logic;      -- optical TX/RX refclk, 160 MHz
    REF_CLK_3_P : in std_logic;      -- optical TX/RX refclk, 160 MHz
    REF_CLK_3_N : in std_logic;      -- optical TX/RX refclk, 160 MHz
    REF_CLK_4_P : in std_logic;      -- optical TX/RX refclk, 160 MHz
    REF_CLK_4_N : in std_logic;      -- optical TX/RX refclk, 160 MHz
    REF_CLK_5_P : in std_logic;      -- optical TX/RX refclk, 160 MHz
    REF_CLK_5_N : in std_logic;      -- optical TX/RX refclk, 160 MHz
    CLK_125_REF_P : in std_logic;    -- optical TX/RX refclk, 125 MHz
    CLK_125_REF_N : in std_logic;    -- optical TX/RX refclk, 125 MHz

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
    KUS_VME_DIR_B   : out std_logic;                       -- Bank 44
    VME_DTACK_KUS_B : out std_logic;                       -- Bank 44

    DCFEB_TCK_P    : out std_logic_vector(NCFEB downto 1); -- Labeled as "TCK_X_P"; Bank 68
    DCFEB_TCK_N    : out std_logic_vector(NCFEB downto 1); -- Labeled as "TCK_X_N"; Bank 68
    DCFEB_TMS_P    : out std_logic;                        -- Labeled as "TMS_X_P"; Bank 68
    DCFEB_TMS_N    : out std_logic;                        -- Labeled as "TMS_X_N"; Bank 68
    DCFEB_TDI_P    : out std_logic;                        -- Labeled as "TDI_X_P"; Bank 68
    DCFEB_TDI_N    : out std_logic;                        -- Labeled as "TDI_X_N"; Bank 68
    DCFEB_TDO_P    : in  std_logic_vector(NCFEB downto 1); -- Labeled as "TDO_X_P"; Bank 67-68
    DCFEB_TDO_N    : in  std_logic_vector(NCFEB downto 1); -- Labeled as "TDO_X_N"; Bank 67-68
    DCFEB_DONE     : in  std_logic_vector(NCFEB downto 1); -- Labeled as "DONE_X"; Bank 68
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

    LVMB_PON     : out std_logic_vector(7 downto 0);
    PON_LOAD     : out std_logic;
    PON_OE_B     : out std_logic;
    LVMB_CSB     : out std_logic_vector(6 downto 0);
    LVMB_SCLK    : out std_logic;
    LVMB_SDIN    : out std_logic;
    LVMB_SDOUT_P : in  std_logic;
    LVMB_SDOUT_N : in  std_logic;
    MON_LVMB_PON : in  std_logic_vector(7 downto 0);

    --------------------------------
    -- OTMB communications
    --------------------------------
    -- TMB        : in  std_logic_vector(35 downto 0);  -- consist of OTMB and ALCT data
    -- RAWLCT     : in  std_logic_vector(6 downto 0);
    -- TMB_DAV    : in  std_logic;
    -- TMB_FF_CLK : in  std_logic;
    -- RSVTD      : in  std_logic_vector(7 downto 3); -- ???
    -- RSVTD      : out std_logic_vector(2 downto 0);
    -- LCT_RQST   : out std_logic_vector(2 downto 1);
    -- TMB_DONE   : out std_logic;  -- Labeled as "DONE" in schematic

    --------------------------------
    -- ODMB optical signals
    --------------------------------
    -- Optical TX/RX signals
    DAQ_RX_P : in std_logic_vector(10 downto 0);
    DAQ_RX_N : in std_logic_vector(10 downto 0);
    DAQ_SPY_RX_P : in std_logic;        -- DAQ_RX_P11 or SPY_RX_P
    DAQ_SPY_RX_N : in std_logic;        -- DAQ_RX_N11 or SPY_RX_N

    B04_RX_P : in std_logic_vector(4 downto 2); -- B04 RX, no use
    B04_RX_N : in std_logic_vector(4 downto 2); -- B04 RX, no use
    BCK_PRS_P : in std_logic; -- copy of B04_RX_P1
    BCK_PRS_N : in std_logic; -- copy of B04_RX_N1

    SPY_TX_P : out std_logic;        -- output to PC
    SPY_TX_N : out std_logic;        -- output to PC
    DAQ_TX_P : out std_logic_vector(4 downto 1); -- B04 TX, output to FED
    DAQ_TX_N : out std_logic_vector(4 downto 1); -- B04 TX, output to FED

    -- Optical control signals
    DAQ_SPY_SEL    : out std_logic;      -- 0 for DAQ_RX_P/N11, 1 for SPY_RX_P/N

    RX12_I2C_ENA   : out std_logic;
    RX12_SDA       : inout std_logic;
    RX12_SCL       : out std_logic;
    RX12_CS_B      : out std_logic;
    RX12_RST_B     : out std_logic;
    RX12_INT_B     : in std_logic;
    RX12_PRESENT_B : in std_logic;

    TX12_I2C_ENA   : out std_logic;
    TX12_SDA       : inout std_logic;
    TX12_SCL       : out std_logic;
    TX12_CS_B      : out std_logic;
    TX12_RST_B     : out std_logic;
    TX12_INT_B     : in std_logic;
    TX12_PRESENT_B : in std_logic;

    B04_I2C_ENA   : out std_logic;
    B04_SDA       : inout std_logic;
    B04_SCL       : out std_logic;
    B04_CS_B      : out std_logic;
    B04_RST_B     : out std_logic;
    B04_INT_B     : in std_logic;
    B04_PRESENT_B : in std_logic;

    SPY_I2C_ENA   : out std_logic;
    SPY_SDA       : inout std_logic;
    SPY_SCL       : out std_logic;
    SPY_SD        : in std_logic;       -- Signal Detect
    SPY_TDIS      : out std_logic       -- Transmitter Disable

    --------------------
    -- Other
    --------------------
    -- RST         : in std_logic

    --------------------------------
    -- Test bench signals (not in ODMB)
    --------------------------------
    -- ; --kcuonly
    -- TB_CLK160      : in std_logic;  --kcuonly
    -- TB_CLK80       : in std_logic;  --kcuonly
    -- TB_CLK40       : in std_logic;  --kcuonly
    -- TB_CLK20       : in std_logic;  --kcuonly
    -- TB_CLK10       : in std_logic   --kcuonly

    --------------------------------
    -- KCU signals (not in ODMB)
    --------------------------------
    -- ; --kcuonly
    -- VME_DATA_IN   : in  std_logic_vector (15 downto 0); --kcuonly
    -- VME_DATA_OUT  : out std_logic_vector (15 downto 0) --kcuonly

    -- --------------------------------
    -- -- IBERT test signals for KCU (not in ODMB)
    -- --------------------------------
    -- ; --kcuonly
    -- KCU_GTH_TXN_O : out std_logic_vector(15 downto 0); --kcuonly
    -- KCU_GTH_TXP_O : out std_logic_vector(15 downto 0); --kcuonly
    -- KCU_GTH_RXN_I : in std_logic_vector(15 downto 0); --kcuonly
    -- KCU_GTH_RXP_I : in std_logic_vector(15 downto 0) --kcuonly

    );
end ODMB7_UCSB_DEV;

architecture Behavioral of ODMB7_UCSB_DEV is
  -- Constants
  constant bw_data  : integer := 16; -- data bit width

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
      LVMB_PON   : out std_logic_vector(7 downto 0);
      PON_LOAD   : out std_logic;
      PON_OE_B   : out std_logic;
      R_LVMB_PON : in  std_logic_vector(7 downto 0);
      LVMB_CSB   : out std_logic_vector(6 downto 0);
      LVMB_SCLK  : out std_logic;
      LVMB_SDIN  : out std_logic;
      LVMB_SDOUT : in  std_logic;

      -- DIAGOUT_LVDBMON  : out std_logic_vector(17 downto 0);

      --------------------
      -- TODO: DCFEB PRBS signals
      --------------------
      DCFEB_PRBS_FIBER_SEL : out std_logic_vector(3 downto 0);
      DCFEB_PRBS_EN        : out std_logic;
      DCFEB_PRBS_RST       : out std_logic;
      DCFEB_PRBS_RD_EN     : out std_logic;
      DCFEB_RXPRBSERR      : in  std_logic;
      DCFEB_PRBS_ERR_CNT   : in  std_logic_vector(15 downto 0);

      --------------------
      -- TODO: OTMB PRBS signals
      --------------------
      OTMB_TX : in  std_logic_vector(48 downto 0);
      OTMB_RX : out std_logic_vector(5 downto 0);
      
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
      ODMB_CTRL            : out std_logic_vector(15 downto 0);
      ODMB_DATA            : in std_logic_vector(15 downto 0);
      ODMB_DATA_SEL        : out std_logic_vector(7 downto 0);

      --------------------
      -- VMECONFREGS Configuration signals for top level
      --------------------
      LCT_L1A_DLY          : out std_logic_vector(5 downto 0);
      INJ_DLY              : out std_logic_vector(4 downto 0);
      EXT_DLY              : out std_logic_vector(4 downto 0);
      CALLCT_DLY           : out std_logic_vector(3 downto 0);
      CABLE_DLY            : out integer range 0 to 1;

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

  component clock_manager is
    port (
      clk_in1_p  : in std_logic;
      clk_in1_n  : in std_logic;
      clk_out160 : out std_logic;
      clk_out80  : out std_logic;
      clk_out40  : out std_logic;
      clk_out20  : out std_logic;
      clk_out10  : out std_logic
      );
  end component;

  component ila is
    port (
      clk : in std_logic := '0';
      probe0 : in std_logic_vector(255 downto 0) := (others=> '0');
      probe1 : in std_logic_vector(4095 downto 0) := (others => '0')
      );
  end component;

  component vio_top
    port (
      clk : in std_logic;
      probe_in0 : in std_logic_vector(31 downto 0);
      probe_out0 : out std_logic_vector(0 downto 0)
      );
  end component;

  component ibert_odmb7_gth
    PORT (
      txn_o : out std_logic_vector(15 downto 0);
      txp_o : out std_logic_vector(15 downto 0);
      rxoutclk_o : out std_logic_vector(15 downto 0);
      rxn_i : in std_logic_vector(15 downto 0);
      rxp_i : in std_logic_vector(15 downto 0);
      gtrefclk0_i : in std_logic_vector(3 downto 0);
      gtrefclk1_i : in std_logic_vector(3 downto 0);
      gtnorthrefclk0_i : in std_logic_vector(3 downto 0);
      gtnorthrefclk1_i : in std_logic_vector(3 downto 0);
      gtsouthrefclk0_i : in std_logic_vector(3 downto 0);
      gtsouthrefclk1_i : in std_logic_vector(3 downto 0);
      gtrefclk00_i : in std_logic_vector(3 downto 0);
      gtrefclk10_i : in std_logic_vector(3 downto 0);
      gtrefclk01_i : in std_logic_vector(3 downto 0);
      gtrefclk11_i : in std_logic_vector(3 downto 0);
      gtnorthrefclk00_i : in std_logic_vector(3 downto 0);
      gtnorthrefclk10_i : in std_logic_vector(3 downto 0);
      gtnorthrefclk01_i : in std_logic_vector(3 downto 0);
      gtnorthrefclk11_i : in std_logic_vector(3 downto 0);
      gtsouthrefclk00_i : in std_logic_vector(3 downto 0);
      gtsouthrefclk10_i : in std_logic_vector(3 downto 0);
      gtsouthrefclk01_i : in std_logic_vector(3 downto 0);
      gtsouthrefclk11_i : in std_logic_vector(3 downto 0);
      clk : in std_logic
    );
  end component;

  --------------------------------------
  -- VME signals
  --------------------------------------
  -- signal cmd_adrs     : std_logic_vector (15 downto 0);
  signal vme_dir_b    : std_logic;
  signal vme_dir      : std_logic;
  signal vme_data_out_buf, vme_data_in_buf : std_logic_vector(15 downto 0) := (others => '0');

  --------------------------------------
  -- Clock synthesizer and clock signals
  --------------------------------------
  signal clk160          : std_logic := '0';  -- For dcfeb prbs (160MHz)
  signal clk80           : std_logic := '0';
  signal clk40           : std_logic := '0';  -- NEW (fastclk -> 40MHz)
  signal clk20           : std_logic := '0';
  signal clk10           : std_logic := '0';  -- NEW (midclk -> fastclk/4 -> 10MHz)
  signal clk2p5          : std_logic := '0';

  signal clk5_unbuf      : std_logic := '0';
  signal clk5_inv        : std_logic := '1';
  signal clk2p5_unbuf    : std_logic := '0';
  signal clk2p5_inv      : std_logic := '1';

  --------------------------------------
  -- PPIB/DCFEB signals
  --------------------------------------
  signal dcfeb_tck    : std_logic_vector (NCFEB downto 1) := (others => '0');
  signal dcfeb_tms    : std_logic := '0';
  signal dcfeb_tdi    : std_logic := '0';
  signal dcfeb_tdo    : std_logic_vector (NCFEB downto 1) := (others => '0');
  -- signal dcfeb_tms_t  : std_logic := '0';

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

  signal dcfeb_prbs_fiber_sel : std_logic_vector(3 downto 0) := (others => '0');
  signal dcfeb_prbs_en        : std_logic := '0';
  signal dcfeb_prbs_rst       : std_logic := '0';
  signal dcfeb_prbs_rd_en     : std_logic := '0';
  signal dcfeb_rxprbserr      : std_logic := '0';
  signal dcfeb_prbs_err_cnt   : std_logic_vector(15 downto 0) := (others => '0');

  --------------------------------------
  -- LVMB signals
  --------------------------------------
  signal lvmb_sdout : std_logic := '0';

  --------------------------------------
  -- OTMB signals
  --------------------------------------
  signal otmb_tx : std_logic_vector(48 downto 0) := (others => '0'); -- old, from ODMB design?
  signal otmb_rx : std_logic_vector(5 downto 0) := (others => '0');  -- old, from ODMB design?

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
  -- Data readout signals
  --------------------------------------
  signal odmb_data : std_logic_vector(15 downto 0) := (others => '0');
  signal odmb_data_sel : std_logic_vector(7 downto 0) := (others => '0');

  --------------------------------------
  -- Debug signals
  --------------------------------------
  signal vio_mon : std_logic_vector(31 downto 0) := (others => '0');

  --------------------------------------
  -- Signals for the IBERT test
  --------------------------------------
  signal gth_txn_o : std_logic_vector(15 downto 0);
  signal gth_txp_o : std_logic_vector(15 downto 0);
  signal gth_rxn_i : std_logic_vector(15 downto 0);
  signal gth_rxp_i : std_logic_vector(15 downto 0);
  signal gth_qrefclk0_i : std_logic_vector(3 downto 0);
  signal gth_qrefclk1_i : std_logic_vector(3 downto 0);
  signal gth_qnorthrefclk0_i : std_logic_vector(3 downto 0);
  signal gth_qnorthrefclk1_i : std_logic_vector(3 downto 0);
  signal gth_qsouthrefclk0_i : std_logic_vector(3 downto 0);
  signal gth_qsouthrefclk1_i : std_logic_vector(3 downto 0);
  signal gth_qrefclk00_i : std_logic_vector(3 downto 0);
  signal gth_qrefclk10_i : std_logic_vector(3 downto 0);
  signal gth_qrefclk01_i : std_logic_vector(3 downto 0);
  signal gth_qrefclk11_i : std_logic_vector(3 downto 0);
  signal gth_qnorthrefclk00_i : std_logic_vector(3 downto 0);
  signal gth_qnorthrefclk10_i : std_logic_vector(3 downto 0);
  signal gth_qnorthrefclk01_i : std_logic_vector(3 downto 0);
  signal gth_qnorthrefclk11_i : std_logic_vector(3 downto 0);
  signal gth_qsouthrefclk00_i : std_logic_vector(3 downto 0);
  signal gth_qsouthrefclk10_i : std_logic_vector(3 downto 0);
  signal gth_qsouthrefclk01_i : std_logic_vector(3 downto 0);
  signal gth_qsouthrefclk11_i : std_logic_vector(3 downto 0);

  signal mgtrefclk0_i : std_logic; -- from 226 in ODMB7, from 227 in KCU
  signal mgtrefclk1_i : std_logic; -- from 226 in ODMB7, from 227 in KCU
  signal mgtrefclk0_odiv2_i : std_logic;
  signal mgtrefclk1_odiv2_i : std_logic;
  signal gth_sysclk_i : std_logic;

begin

  -------------------------------------------------------------------------------------------
  -- Handle clock synthesizer signals and generate clocks
  -------------------------------------------------------------------------------------------
  clkgen_i : if not in_kcu105 generate
    u_clk_gen : clock_manager
      port map(
        clk_in1_p  => CMS_CLK_FPGA_P,
        clk_in1_n  => CMS_CLK_FPGA_N,
        clk_out160 => clk160,
        clk_out80  => clk80,
        clk_out40  => clk40,
        clk_out20  => clk20,
        clk_out10  => clk10
        );
  end generate clkgen_i;

  -- clkgen_kcu : if not in_kcu105 generate --kcuonly
  -- clk160 <= TB_CLK160; --kcuonly
  -- clk80  <= TB_CLK80; --kcuonly
  -- clk40  <= TB_CLK40; --kcuonly
  -- clk20  <= TB_CLK20; --kcuonly
  -- clk10  <= TB_CLK10; --kcuonly
-- end generate clkgen_kcu; --kcuonly

  -- In first version of test firmware, we will want to generate everything from 40 MHz cms clock, likely with Clock Manager IP
  -- generate 2p5 clock 
  clk5_inv <= not clk5_unbuf;
  clk2p5_inv <= not clk2p5_unbuf;
  FD_clk5   : FD port map(D => clk5_inv,   C => clk10, Q => clk5_unbuf  );
  FD_clk2p5 : FD port map(D => clk2p5_inv, C => clk10, Q => clk2p5_unbuf);
  BUFG_clk2p5 : BUFG port map(I => clk2p5_unbuf, O => clk2p5);

  -------------------------------------------------------------------------------------------
  -- Handle VME signals
  -------------------------------------------------------------------------------------------

  -- Handle VME data direction line
  KUS_VME_DIR_B <= vme_dir_b;
  vme_dir <= not vme_dir_b;

  -- FIXME: KCU only: multiplex vme_data_in and out lines together
  -- can't have internal IOBUFs on KCU
  -- vme_data_kcu_i : if in_kcu105 generate --kcuonly
  -- vme_data_in_buf <= VME_DATA_IN; --kcuonly
  -- VME_DATA_OUT <= vme_data_out_buf; --kcuonly
-- end generate vme_data_kcu_i; --kcuonly

  --real board/simulation can have IOBUFs
  vme_data_simulation_i : if not in_kcu105 generate
   GEN_VMEOUT_16 : for I in 0 to 15 generate
   begin
     VME_BUF : IOBUF port map(O => vme_data_in_buf(I), IO => VME_DATA(I), I => vme_data_out_buf(I), T => vme_dir_b); 
   end generate GEN_VMEOUT_16;
  end generate vme_data_simulation_i;
  
  -------------------------------------------------------------------------------------------
  -- Handle PPIB/DCFEB signals
  -------------------------------------------------------------------------------------------

  -- Handle DCFEB I/O buffers
  -- OB_DCFEB_TMS: OBUFTDS port map (I => dcfeb_tms, O => DCFEB_TMS_P, OB => DCFEB_TMS_N, T => dcfeb_tms_t);
  -- FIXME: KCU only: on KCU, just use P lines as signals
  kcu_dsio_i : if in_kcu105 generate
    DCFEB_TMS_P <= dcfeb_tms;
    DCFEB_TMS_N <= '0';
    DCFEB_TDI_P <= dcfeb_tdi;
    DCFEB_TDI_N <= '0';
    DCFEB_TCK_P <= dcfeb_tck;
    DCFEB_TCK_N <= (others => '0');
    INJPLS_P <= dcfeb_injpls;
    INJPLS_N <= '0';
    EXTPLS_P <= dcfeb_extpls;
    EXTPLS_N <= '0';
    RESYNC_P <= dcfeb_resync;
    RESYNC_N <= '0';
    BC0_P <= dcfeb_bc0;
    BC0_N <= '0';
    L1A_P <= dcfeb_l1a;
    L1A_N <= '0';
    L1A_MATCH_P <= dcfeb_l1a_match;
    L1A_MATCH_N <= (others => '0');
    dcfeb_tdo <= DCFEB_TDO_P;
    lvmb_sdout <= LVMB_SDOUT_P;
  end generate kcu_dsio_i;

  -- real board/simulation has I/OBUFs
  bufds_i : if not in_kcu105 generate
    -- DCFEB I/Os
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
    -- LVMB I/O
    IB_LVMB_SDOUT: IBUFDS port map (O => lvmb_sdout, I => LVMB_SDOUT_P, IB => LVMB_SDOUT_N);
  end generate bufds_i;

  --generate pulses if not masked
  dcfeb_injpls <= '0' when mask_pls = '1' else premask_injpls;
  dcfeb_extpls <= '0' when mask_pls = '1' else premask_extpls;
  
  --generate RESYNC, BC0, L1A, and L1A match signals to DCFEBs
  RESETPULSE : PULSE2SAME port map(DOUT => reset_pulse, CLK_DOUT => clk40, RST => '0', DIN => reset);
  FD_RESETPULSE_Q : FD port map (Q => reset_pulse_q,     C => clk40, D => reset_pulse);
  FD_L1APULSE_Q   : FD port map (Q => l1a_reset_pulse_q, C => clk40, D => l1a_reset_pulse);

  l1acnt_rst <= clk20 and (l1a_reset_pulse or l1a_reset_pulse_q or reset_pulse or reset_pulse_q);
  pre_bc0    <= test_bc0;
  masked_l1a <= '0' when mask_l1a(0)='1' else odmbctrl_l1a;

  DS_RESYNC : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_resync, CLK => clk40, NCYCLES => cable_dly, DIN => l1acnt_rst);
  DS_BC0    : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_bc0,    CLK => clk40, NCYCLES => cable_dly, DIN => pre_bc0   );
  DS_L1A    : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_l1a,    CLK => clk40, NCYCLES => cable_dly, DIN => masked_l1a);

  GEN_DCFEB_L1A_MATCH : for I in 1 to NCFEB generate
  begin
    masked_l1a_match(I) <= '0' when mask_l1a(I)='1' else odmbctrl_l1a_match(I);
    DS_L1A_MATCH : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_l1a_match(I), CLK => clk40, NCYCLES => cable_dly, DIN => masked_l1a_match(I));
  end generate GEN_DCFEB_L1A_MATCH;

  -- FSM to handle initialization when DONE received from DCFEBs
  -- Generate dcfeb_initjtag
  done_fsm_regs : process (done_next_state, pon_reset, clk10)
  begin
    for dev in 1 to NCFEB loop
      if (pon_reset = '1') then
        done_current_state(dev) <= DONE_LOW;
      elsif rising_edge(clk10) then
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
  -- FIXME: temporarily using clk40 so I don't have to wait an eternity, 10kHz in realistic design
  DS_DCFEB_INITJTAG    : DELAY_SIGNAL generic map(240) port map(DOUT => dcfeb_initjtag_d, CLK => clk40, NCYCLES => 240, DIN => dcfeb_initjtag_dd);
  -- FIXME: temporarily using clk40 so I don't have to wait an eternity, 625kHz in realistic design
  PULSE_DCFEB_INITJTAG : NPULSE2FAST port map(DOUT => dcfeb_initjtag, CLK_DOUT => clk40, RST => '0', NPULSE => 5, DIN => dcfeb_initjtag_d);

  -------------------------------------------------------------------------------------------
  -- Handle Triggers
  -------------------------------------------------------------------------------------------

  test_pb_lct <= test_lct;
  LCTDLY_GTRG : LCTDLY port map(DIN => test_pb_lct, CLK => clk40, DELAY => lct_l1a_dly, DOUT => test_l1a);
  raw_l1a <= test_l1a;

  -------------------------------------------------------------------------------------------
  -- Handle Internal configuration signals
  -------------------------------------------------------------------------------------------

  -------------------------------------------------------------------------------------------
  -- Handle reset signals
  -------------------------------------------------------------------------------------------

  FD_FW_RESET : FD port map (Q => fw_reset_q, C => clk40, D => fw_reset);
  fw_rst_reg <= x"3FFFF000" when ((fw_reset_q = '0' and fw_reset = '1') or ccb_softrst_b_q = '0') else
                  fw_rst_reg(30 downto 0) & '0' when rising_edge(clk40) else
                  fw_rst_reg;
  reset <= fw_rst_reg(31) or pon_rst_reg(31);
  -- original: reset <= fw_rst_reg(31) or pon_rst_reg(31) or not pb0_q;
  -- pon_rst_reg used to be reset from pll lock
  pon_rst_reg    <= pon_rst_reg(30 downto 0) & '0' when rising_edge(clk40) else
                    pon_rst_reg;
  pon_reset <= pon_rst_reg(31);

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
  -- IBERT test signals <-- only for KCU
  -------------------------------------------------------------------------------------------
  u_buf_gth_q3_clk0 : IBUFDS_GTE3 
    port map (
      O     => mgtrefclk0_i,
      ODIV2 => mgtrefclk0_odiv2_i,
      CEB   => '0',
      I     => REF_CLK_3_P,   -- from Quad227 in KCU
      IB    => REF_CLK_3_N    -- from Quad227 in KCU
      );

  u_buf_gth_q3_clk1 : IBUFDS_GTE3 
    port map (
      O     => mgtrefclk1_i,
      ODIV2 => mgtrefclk1_odiv2_i,
      CEB   => '0',
      I     => CLK_125_REF_P,
      IB    => CLK_125_REF_N
      );

  -- to simplify the datalines for KCU
  -- KCU_GTH_TXN_O <= gth_txn_o; --kcuonly
  -- KCU_GTH_TXP_O <= gth_txp_o; --kcuonly
  -- gth_rxn_i <= KCU_GTH_RXN_I; --kcuonly
  -- gth_rxp_i <= KCU_GTH_RXP_I; --kcuonly

  -- Real ODMB configs
  gth_mapping_i : if not in_kcu105 generate
    gth_rxp_i(10 downto 0)  <= DAQ_RX_P;
    gth_rxn_i(10 downto 0)  <= DAQ_RX_N;
    gth_rxp_i(11)           <= DAQ_SPY_RX_P;
    gth_rxn_i(11)           <= DAQ_SPY_RX_N;
    gth_rxp_i(12)           <= BCK_PRS_P;
    gth_rxn_i(12)           <= BCK_PRS_N;
    gth_rxp_i(15 downto 13) <= B04_RX_P;
    gth_rxn_i(15 downto 13) <= B04_RX_N;

    DAQ_TX_P <= gth_txp_o(15 downto 12);
    DAQ_TX_N <= gth_txn_o(15 downto 12);
    SPY_TX_P <= gth_txp_o(11);
    SPY_TX_N <= gth_txn_o(11);
  end generate gth_mapping_i;

  -- DAQ_SPY_SEL <= '1';   -- will connect to sel_si570_clk in KCU
  vio_mon <= odmb_data & vme_data_out_buf;

  u_vio_top : vio_top
    port map (
      clk => clk80,                  -- same as IBERT
      probe_in0 => vio_mon,
      probe_out0(0) => DAQ_SPY_SEL   -- default '1', should be '0' for KCU
      );

  -- Possible options for the IBERT sysclk
  
  -- u_gth_sysclk_internal : BUFG_GT 
  --   port map(
  --     I       => mgtrefclk0_odiv2_i,
  --     O       => gth_sysclk_i,
  --     CE      => '1',
  --     CEMASK  => '0',
  --     CLR     => '0',
  --     CLRMASK => '0',
  --     DIV     => "000"
  --     );

  -- ibufg_i : IBUFGDS
  --   port map (
  --     I => GP_CLK_7_P,
  --     IB => GP_CLK_7_N,
  --     O => gth_sysclk_i
  --     );

  gth_sysclk_i <= clk80;

  gth_qrefclk0_i(0) <= '0';
  gth_qrefclk1_i(0) <= '0';
  gth_qnorthrefclk0_i(0) <= '0';
  gth_qnorthrefclk1_i(0) <= '0';
  gth_qsouthrefclk0_i(0) <= mgtrefclk0_i;
  gth_qsouthrefclk1_i(0) <= '0';
  gth_qrefclk00_i(0) <= '0';
  gth_qrefclk10_i(0) <= '0';
  gth_qrefclk01_i(0) <= '0';
  gth_qrefclk11_i(0) <= '0';
  gth_qnorthrefclk00_i(0) <= '0';
  gth_qnorthrefclk10_i(0) <= '0';
  gth_qnorthrefclk01_i(0) <= '0';
  gth_qnorthrefclk11_i(0) <= '0';
  gth_qsouthrefclk00_i(0) <= mgtrefclk0_i;
  gth_qsouthrefclk10_i(0) <= '0';
  gth_qsouthrefclk01_i(0) <= '0';
  gth_qsouthrefclk11_i(0) <= '0';

  gth_qrefclk0_i(1) <= '0';
  gth_qrefclk1_i(1) <= '0';
  gth_qnorthrefclk0_i(1) <= '0';
  gth_qnorthrefclk1_i(1) <= '0';
  gth_qsouthrefclk0_i(1) <= mgtrefclk0_i;
  gth_qsouthrefclk1_i(1) <= '0';
  gth_qrefclk00_i(1) <= '0';
  gth_qrefclk10_i(1) <= '0';
  gth_qrefclk01_i(1) <= '0';
  gth_qrefclk11_i(1) <= '0';
  gth_qnorthrefclk00_i(1) <= '0';
  gth_qnorthrefclk10_i(1) <= '0';
  gth_qnorthrefclk01_i(1) <= '0';
  gth_qnorthrefclk11_i(1) <= '0';
  gth_qsouthrefclk00_i(1) <= mgtrefclk0_i;
  gth_qsouthrefclk10_i(1) <= '0';
  gth_qsouthrefclk01_i(1) <= '0';
  gth_qsouthrefclk11_i(1) <= '0';

  gth_qrefclk0_i(2) <= mgtrefclk0_i;
  gth_qrefclk1_i(2) <= mgtrefclk1_i;
  gth_qnorthrefclk0_i(2) <= '0';
  gth_qnorthrefclk1_i(2) <= '0';
  gth_qsouthrefclk0_i(2) <= '0';
  gth_qsouthrefclk1_i(2) <= '0';
  gth_qrefclk00_i(2) <= mgtrefclk0_i;
  gth_qrefclk10_i(2) <= mgtrefclk1_i;
  gth_qrefclk01_i(2) <= '0';
  gth_qrefclk11_i(2) <= '0';
  gth_qnorthrefclk00_i(2) <= '0';
  gth_qnorthrefclk10_i(2) <= '0';
  gth_qnorthrefclk01_i(2) <= '0';
  gth_qnorthrefclk11_i(2) <= '0';
  gth_qsouthrefclk00_i(2) <= '0';
  gth_qsouthrefclk10_i(2) <= '0';
  gth_qsouthrefclk01_i(2) <= '0';
  gth_qsouthrefclk11_i(2) <= '0';

  gth_qrefclk0_i(3) <= '0';
  gth_qrefclk1_i(3) <= '0';
  gth_qnorthrefclk0_i(3) <= mgtrefclk0_i;
  gth_qnorthrefclk1_i(3) <= '0';
  gth_qsouthrefclk0_i(3) <= '0';
  gth_qsouthrefclk1_i(3) <= '0';
  gth_qrefclk00_i(3) <= '0';
  gth_qrefclk10_i(3) <= '0';
  gth_qrefclk01_i(3) <= '0';
  gth_qrefclk11_i(3) <= '0';
  gth_qnorthrefclk00_i(3) <= mgtrefclk0_i;
  gth_qnorthrefclk10_i(3) <= '0';
  gth_qnorthrefclk01_i(3) <= '0';
  gth_qnorthrefclk11_i(3) <= '0';
  gth_qsouthrefclk00_i(3) <= '0';
  gth_qsouthrefclk10_i(3) <= '0';
  gth_qsouthrefclk01_i(3) <= '0';
  gth_qsouthrefclk11_i(3) <= '0';

  -------------------------------------------------------------------------------------------
  -- Sub-modules
  -------------------------------------------------------------------------------------------
  
  i_odmb_vme : ODMB_VME
    generic map (
      NCFEB => NCFEB
      )
    port map (
      CLK160         => clk160,
      CLK40          => clk40,
      CLK10          => clk10,
      CLK2P5	     => clk2p5,

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

      LVMB_PON    => LVMB_PON,
      PON_LOAD    => PON_LOAD,
      PON_OE_B    => PON_OE_B,
      R_LVMB_PON  => MON_LVMB_PON,
      LVMB_CSB    => LVMB_CSB,
      LVMB_SCLK   => LVMB_SCLK,
      LVMB_SDIN   => LVMB_SDIN,
      LVMB_SDOUT  => lvmb_sdout,

      DCFEB_PRBS_FIBER_SEL  => dcfeb_prbs_fiber_sel,
      DCFEB_PRBS_EN         => dcfeb_prbs_en,
      DCFEB_PRBS_RST        => dcfeb_prbs_rst,
      DCFEB_PRBS_RD_EN      => dcfeb_prbs_rd_en,
      DCFEB_RXPRBSERR       => dcfeb_rxprbserr,
      DCFEB_PRBS_ERR_CNT    => dcfeb_prbs_err_cnt,

      OTMB_TX  => otmb_tx,
      OTMB_RX  => otmb_rx,
      
      FW_RESET => fw_reset,
      L1A_RESET_PULSE => l1a_reset_pulse,
      TEST_INJ => test_inj,
      TEST_PLS => test_pls,
      TEST_BC0 => test_bc0,
      TEST_PED => test_ped,
      TEST_LCT => test_lct,
      MASK_L1A => mask_l1a,
      MASK_PLS => mask_pls,
      ODMB_CTRL => odmb_ctrl_reg,
      ODMB_DATA => odmb_data,
      ODMB_DATA_SEL => odmb_data_sel,

      LCT_L1A_DLY => lct_l1a_dly,
      INJ_DLY => inj_dly, 
      EXT_DLY => ext_dly, 
      CALLCT_DLY => callct_dly, 
      CABLE_DLY => cable_dly,

      DIAGOUT  => open,
      RST      => reset
      );

  MBC : ODMB_CTRL 
    generic map (
      NCFEB => NCFEB
      )
    port map (
      CLK80 => clk80,
      CLK40 => clk40,

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

  u_ibert_gth_core : ibert_odmb7_gth
    port map (
      txn_o => gth_txn_o,
      txp_o => gth_txp_o,
      rxn_i => gth_rxn_i,
      rxp_i => gth_rxp_i,
      clk => gth_sysclk_i,
      gtrefclk0_i => gth_qrefclk0_i,
      gtrefclk1_i => gth_qrefclk1_i,
      gtnorthrefclk0_i => gth_qnorthrefclk0_i,
      gtnorthrefclk1_i => gth_qnorthrefclk1_i,
      gtsouthrefclk0_i => gth_qsouthrefclk0_i,
      gtsouthrefclk1_i => gth_qsouthrefclk1_i,
      gtrefclk00_i => gth_qrefclk00_i,
      gtrefclk10_i => gth_qrefclk10_i,
      gtrefclk01_i => gth_qrefclk01_i,
      gtrefclk11_i => gth_qrefclk11_i,
      gtnorthrefclk00_i => gth_qnorthrefclk00_i,
      gtnorthrefclk10_i => gth_qnorthrefclk10_i,
      gtnorthrefclk01_i => gth_qnorthrefclk01_i,
      gtnorthrefclk11_i => gth_qnorthrefclk11_i,
      gtsouthrefclk00_i => gth_qsouthrefclk00_i,
      gtsouthrefclk10_i => gth_qsouthrefclk10_i,
      gtsouthrefclk01_i => gth_qsouthrefclk01_i,
      gtsouthrefclk11_i => gth_qsouthrefclk11_i
      );

  -------------------------------------------------------------------------------------------
  -- Debug functions
  -------------------------------------------------------------------------------------------
  


end Behavioral;
