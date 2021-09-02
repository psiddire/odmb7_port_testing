------------------------------
-- ODMB_VME: Handles the VME protocol and selects VME device
------------------------------

-- Device 0 => TESTCTRL
-- Device 1 => CFEBJTAG
-- Device 2 => ODMBJTAG
-- Device 3 => VMEMON
-- Device 4 => VMECONFREGS
-- Device 5 => TESTFIFOS
-- Device 6 => BPI_PORT
-- Device 7 => SYSTEM_MON
-- Device 8 => LVDBMON
-- Device 9 => SYSTEM_TEST

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;
use work.ucsb_types.all;

entity ODMB_VME is
  generic (
    NCFEB       : integer range 1 to 7 := 7
    );
  port (
    --------------------
    -- Clock
    --------------------
    CLK160      : in std_logic;  -- For dcfeb prbs (160MHz)
    CLK40       : in std_logic;  -- fastclk -> 40MHz
    CLK10       : in std_logic;  -- midclk -> fastclk/4 -> 10MHz
    CLK2P5      : in std_logic;  -- 2.5 MHz clock
    CLK1P25     : in std_logic;  -- 1.25 MHz clock

    --------------------
    -- VME signals  <-- relevant ones only
    --------------------
    VME_DATA_IN   : in std_logic_vector (15 downto 0);
    VME_DATA_OUT  : out std_logic_vector (15 downto 0);
    VME_GAP_B     : in std_logic;
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
    DCFEB_REPROG_B : out std_logic;  -- Hard reset to DCFEBs

    --------------------
    -- JTAG Signals To/From ODMBs
    --------------------
    ODMB_TCK    : out std_logic;
    ODMB_TMS    : out std_logic;
    ODMB_TDI    : out std_logic;
    ODMB_TDO    : in  std_logic;
    ODMB_SEL    : out std_logic;
    ODMB_INITJTAG : in std_logic;   -- TODO: where does this fit in

    --------------------
    -- From/To LVMB: ODMB & ODMB7 design, ODMB5 to be seen
    --------------------
    LVMB_PON   : out std_logic_vector(7 downto 0);
    PON_LOAD_B : out std_logic;
    PON_OE     : out std_logic;
    R_LVMB_PON : in  std_logic_vector(7 downto 0);
    LVMB_CSB   : out std_logic_vector(6 downto 0);
    LVMB_SCLK  : out std_logic;
    LVMB_SDIN  : out std_logic;
    LVMB_SDOUT : in  std_logic;

    --------------------
    -- OTMB connections through backplane
    --------------------
    OTMB        : in  std_logic_vector(35 downto 0);      -- "TMB[35:0]" in Bank 44-45
    RAWLCT      : in  std_logic_vector(7 downto 0);       -- Bank 45
    OTMB_DAV    : in  std_logic;                          -- "TMB_DAV" in Bank 45
    ALCT_DAV    : in  std_logic;                          -- "LEGACY_ALCT_DAV" in Bank 45
    OTMB_FF_CLK : in  std_logic;                          -- "TMB_FF_CLK" in Bank 45, not used
    RSVTD       : in  std_logic_vector(5 downto 3);       -- Bank 44-45, remapped from r4 schematics
    RSVFD       : out std_logic_vector(2 downto 0);       -- Bank 44-45, "RSVTD[2:0]" in r4 schematics
    LCT_RQST    : out std_logic_vector(2 downto 1);       -- Bank 45

    --------------------
    -- VMEMON Configuration signals for top level and input from top level
    --------------------
    FW_RESET             : out std_logic;
    L1A_RESET_PULSE      : out std_logic;
    OPT_RESET_PULSE      : out std_logic;
    TEST_INJ             : out std_logic;
    TEST_PLS             : out std_logic;
    TEST_BC0             : out std_logic;
    TEST_PED             : out std_logic;
    TEST_LCT             : out std_logic;
    MASK_L1A             : out std_logic_vector (NCFEB downto 0);
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
    LCT_L1A_DLY          : out std_logic_vector(5 downto 0);
    CABLE_DLY            : out integer range 0 to 1;
    OTMB_PUSH_DLY        : out integer range 0 to 63;
    ALCT_PUSH_DLY        : out integer range 0 to 63;
    BX_DLY               : out integer range 0 to 4095;
    INJ_DLY              : out std_logic_vector(4 downto 0);
    EXT_DLY              : out std_logic_vector(4 downto 0);
    CALLCT_DLY           : out std_logic_vector(3 downto 0);
    ODMB_ID              : out std_logic_vector(15 downto 0);
    NWORDS_DUMMY         : out std_logic_vector(15 downto 0);
    KILL                 : out std_logic_vector(NCFEB+2 downto 1);
    CRATEID              : out std_logic_vector(7 downto 0);
    CHANGE_REG_DATA      : in std_logic_vector(15 downto 0);
    CHANGE_REG_INDEX     : in integer range 0 to NREGS;

    --------------------
    -- DDU/SPY/DCFEB/ALCT Optical PRBS test signals
    --------------------
    MGT_PRBS_TYPE        : out std_logic_vector(3 downto 0); -- DDU/SPY/DCFEB/ALCT Common PRBS type
    FED_PRBS_TX_EN       : out std_logic_vector(3 downto 0);
    FED_PRBS_RX_EN       : out std_logic_vector(3 downto 0);
    FED_PRBS_TST_CNT     : out std_logic_vector(15 downto 0);
    FED_PRBS_ERR_CNT     : in  std_logic_vector(15 downto 0);
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
    -- System monitoring
    --------------------
    -- Current monitoring
    SYSMON_P      : in std_logic_vector(15 downto 0);
    SYSMON_N      : in std_logic_vector(15 downto 0);
    -- Voltage monitoring through MAX127 chips
    ADC_CS_B      : out std_logic_vector(4 downto 0);
    ADC_DIN       : out std_logic;
    ADC_SCK       : out std_logic;
    ADC_DOUT      : in  std_logic;
    -------------------

    --------------------
    -- Other
    --------------------
    DIAGOUT     : out std_logic_vector (17 downto 0); -- for debugging
    RST         : in std_logic;
    PON_RESET   : in std_logic
    );
end ODMB_VME;

architecture Behavioral of ODMB_VME is
  -- Constants
  constant bw_data  : integer := 16; -- data bit width
  constant num_dev  : integer := 9;  -- number of devices (exclude dev0)

  component VMECONFREGS is
    generic (
      NCFEB   : integer range 1 to 7 := 7
      );
    port (
      SLOWCLK : in std_logic;
      CLK     : in std_logic;
      RST     : in std_logic;

      DEVICE   : in  std_logic;
      STROBE   : in  std_logic;
      COMMAND  : in  std_logic_vector(9 downto 0);
      WRITER   : in  std_logic;
      DTACK    : out std_logic;

      INDATA  : in  std_logic_vector(15 downto 0);
      OUTDATA : out std_logic_vector(15 downto 0);

      -- Configuration registers
      LCT_L1A_DLY   : out std_logic_vector(5 downto 0);
      CABLE_DLY     : out integer range 0 to 1;
      OTMB_PUSH_DLY : out integer range 0 to 63;
      ALCT_PUSH_DLY : out integer range 0 to 63;
      BX_DLY        : out integer range 0 to 4095;

      INJ_DLY    : out std_logic_vector(4 downto 0);
      EXT_DLY    : out std_logic_vector(4 downto 0);
      CALLCT_DLY : out std_logic_vector(3 downto 0);

      ODMB_ID      : out std_logic_vector(15 downto 0);
      NWORDS_DUMMY : out std_logic_vector(15 downto 0);
      KILL         : out std_logic_vector(NCFEB+2 downto 1);
      CRATEID      : out std_logic_vector(7 downto 0);

      -- From ODMB_UCSB_V2 to change registers
      CHANGE_REG_DATA  : in std_logic_vector(15 downto 0);
      CHANGE_REG_INDEX : in integer range 0 to NREGS;

      -- To/From SPI Interface
      SPI_CFG_UL_PULSE   : in std_logic;
      SPI_CONST_UL_PULSE : in std_logic;
      SPI_REG_IN : in std_logic_vector(15 downto 0);
      SPI_CFG_BUSY    : in  std_logic;
      SPI_CONST_BUSY  : in  std_logic;
      SPI_CFG_REG_WE   : in  integer range 0 to NREGS;
      SPI_CONST_REG_WE : in  integer range 0 to NREGS;
      SPI_CFG_REGS    : out cfg_regs_array;
      SPI_CONST_REGS  : out cfg_regs_array
      );
  end component;

  component CFEBJTAG is
    generic (
      NCFEB     : integer range 1 to 7 := 7
      );
    port (
      -- CSP_LVMB_LA_CTRL : inout std_logic_vector(35 downto 0);

      FASTCLK   : in std_logic;  -- fastclk -> 40 MHz
      SLOWCLK   : in std_logic;  -- midclk  -> 10 MHz
      RST       : in std_logic;
      DEVICE    : in std_logic;
      STROBE    : in std_logic;
      COMMAND   : in std_logic_vector(9 downto 0);
      WRITER    : in std_logic;
      INDATA    : in std_logic_vector(15 downto 0);
      OUTDATA   : inout std_logic_vector(15 downto 0);
      DTACK     : out std_logic;
      INITJTAGS : in  std_logic;
      TCK       : out std_logic_vector(NCFEB downto 1);
      TDI       : out std_logic;
      TMS       : out std_logic;
      FEBTDO    : in  std_logic_vector(NCFEB downto 1);
      DIAGOUT   : out std_logic_vector(17 downto 0);
      LED       : out std_logic
      );
  end component;

  component ODMBJTAG is
    port (
      FASTCLK : in std_logic;
      SLOWCLK : in std_logic;
      RST     : in std_logic;
      DEVICE  : in std_logic;
      STROBE  : in std_logic;
      COMMAND : in std_logic_vector(9 downto 0);
      WRITER  : in std_logic;
      INDATA  : in  std_logic_vector(15 downto 0);
      OUTDATA : out std_logic_vector(15 downto 0);
      DTACK : out std_logic;
      INITJTAGS : in  std_logic;
      TCK       : out std_logic;
      TDI       : out std_logic;
      TMS       : out std_logic;
      ODMBTDO   : in  std_logic;
      JTAGSEL : out std_logic;
      LED : out std_logic
    );
  end component;

  component VMEMON is
    generic (
      NCFEB   : integer range 1 to 7 := 7
      );
    port (
      SLOWCLK : in std_logic;
      CLK40   : in std_logic;
      RST     : in std_logic;

      DEVICE  : in std_logic;
      STROBE  : in std_logic;
      COMMAND : in std_logic_vector(9 downto 0);
      WRITER  : in std_logic;

      INDATA  : in  std_logic_vector(15 downto 0);
      OUTDATA : out std_logic_vector(15 downto 0);

      DTACK : out std_logic;

      DCFEB_DONE  : in std_logic_vector(NCFEB downto 1);

      --reset signals
      OPT_RESET_PULSE : out std_logic;
      L1A_RESET_PULSE : out std_logic;
      FW_RESET        : out std_logic;
      REPROG_B        : out std_logic;

      --pulses
      TEST_INJ        : out std_logic;
      TEST_PLS        : out std_logic;
      TEST_LCT        : out std_logic;
      TEST_BC0        : out std_logic;
      OTMB_LCT_RQST   : out std_logic;
      OTMB_EXT_TRIG   : out std_logic;

      --internal register outputs
      ODMB_CAL        : out std_logic;
      TP_SEL          : out std_logic_vector(15 downto 0);
      MAX_WORDS_DCFEB : out std_logic_vector(15 downto 0);
      LOOPBACK        : out std_logic_vector(2 downto 0);  -- For internal loopback tests
      TXDIFFCTRL      : out std_logic_vector(3 downto 0);  -- Controls the TX voltage swing
      MUX_DATA_PATH   : out std_logic;
      MUX_TRIGGER     : out std_Logic;
      MUX_LVMB        : out std_logic;
      ODMB_PED        : out std_logic_vector(1 downto 0);
      TEST_PED        : out std_logic;
      MASK_L1A        : out std_logic_vector(NCFEB downto 0);
      MASK_PLS        : out std_logic;

      --exernal registers
      ODMB_DATA_SEL : out std_logic_vector(7 downto 0);
      ODMB_DATA     : in  std_logic_vector(15 downto 0)
      );
  end component;

  component SPI_PORT is
    port (
      SLOWCLK              : in std_logic;
      CLK                  : in std_logic;
      RST                  : in std_logic;
      --VME signals
      DEVICE               : in  std_logic;
      STROBE               : in  std_logic;
      COMMAND              : in  std_logic_vector(9 downto 0);
      WRITER               : in  std_logic;
      DTACK                : out std_logic;
      INDATA               : in  std_logic_vector(15 downto 0);
      OUTDATA              : out std_logic_vector(15 downto 0);
      --CONFREGS signals
      SPI_CFG_UL_PULSE     : out std_logic;
      SPI_CONST_UL_PULSE   : out std_logic;
      SPI_UL_REG           : out std_logic_vector(15 downto 0);
      SPI_CFG_BUSY         : out std_logic;
      SPI_CONST_BUSY       : out std_logic;
      SPI_CFG_REG_WE       : out integer range 0 to NREGS;
      SPI_CONST_REG_WE     : out integer range 0 to NREGS;
      SPI_CFG_REGS         : in cfg_regs_array;
      SPI_CONST_REGS       : in cfg_regs_array;
      --signals to/from SPI_CTRL
      SPI_CMD_FIFO_WRITE_EN : out std_logic;
      SPI_CMD_FIFO_IN      : out std_logic_vector(15 downto 0);
      SPI_READBACK_FIFO_OUT     : in std_logic_vector(15 downto 0);
      SPI_READBACK_FIFO_READ_EN : out std_logic;
      SPI_READ_BUSY             : in std_logic;
      SPI_NCMDS_SPICTRL         : in unsigned(15 downto 0);
      SPI_NCMDS_SPIINTR         : in unsigned(15 downto 0);
      --debug
      DIAGOUT                   : out std_logic_vector(17 downto 0)
      );
  end component;

  component SYSTEM_MON is
    port (
      OUTDATA   : out std_logic_vector(15 downto 0);
      DTACK     : out std_logic;

      ADC_CS_B  : out std_logic_vector(4 downto 0);
      ADC_DIN   : out std_logic;
      ADC_SCK   : out std_logic;
      ADC_DOUT  : in  std_logic;

      SLOWCLK   : in std_logic;
      FASTCLK   : in std_logic;
      RST       : in std_logic;

      DEVICE    : in std_logic;
      STROBE    : in std_logic;
      COMMAND   : in std_logic_vector(9 downto 0);
      WRITER    : in std_logic;

      VAUXP     : in std_logic_vector(15 downto 0);
      VAUXN     : in std_logic_vector(15 downto 0)
      );
  end component;

  component LVDBMON is
    port (
      SLOWCLK   : in std_logic;
      RST       : in std_logic;
      PON_RESET : in std_logic;
      DEVICE  : in std_logic;
      STROBE  : in std_logic;
      COMMAND : in std_logic_vector(9 downto 0);
      WRITER  : in std_logic;
      INDATA  : in  std_logic_vector(15 downto 0);
      OUTDATA : out std_logic_vector(15 downto 0);
      DTACK : out std_logic;

      LVADCEN : out std_logic_vector(6 downto 0);
      ADCCLK  : out std_logic;
      ADCDATA : out std_logic;
      ADCIN   : in  std_logic;
      LVTURNON   : out std_logic_vector(8 downto 1);
      R_LVTURNON : in  std_logic_vector(8 downto 1);
      LOADON     : out std_logic;
      DIAGOUT    : out std_logic_vector(17 downto 0)
      );
  end component;

  component SYSTEM_TEST is
    port (
      DEVICE  : in std_logic;
      COMMAND : in std_logic_vector(9 downto 0);
      INDATA  : in std_logic_vector(15 downto 0);
      STROBE  : in std_logic;
      WRITER  : in std_logic;
      SLOWCLK : in std_logic;
      CLK     : in std_logic;
      CLK160  : in std_logic;
      RST     : in std_logic;

      OUTDATA : out std_logic_vector(15 downto 0);
      DTACK   : out std_logic;

      -- DDU/PC/DCFEB COMMON PRBS
      MGT_PRBS_TYPE : out std_logic_vector(3 downto 0);

      -- FED PRBS signals
      FED_PRBS_TX_EN   : out std_logic;
      FED_PRBS_RX_EN   : out std_logic;
      FED_PRBS_TST_CNT : out std_logic_vector(15 downto 0);
      FED_PRBS_ERR_CNT : in  std_logic_vector(15 downto 0);

      -- PC PRBS signals
      SPY_PRBS_TX_EN   : out std_logic_vector(0 downto 0);
      SPY_PRBS_RX_EN   : out std_logic_vector(0 downto 0);
      SPY_PRBS_TST_CNT : out std_logic_vector(15 downto 0);
      SPY_PRBS_ERR_CNT : in  std_logic_vector(15 downto 0);

      -- DCFEB PRBS signals
      DCFEB_PRBS_FIBER_SEL : out std_logic_vector(3 downto 0);
      DCFEB_PRBS_EN        : out std_logic;
      DCFEB_PRBS_RST       : out std_logic;
      DCFEB_PRBS_RD_EN     : out std_logic;
      DCFEB_RXPRBSERR      : in  std_logic;
      DCFEB_PRBS_ERR_CNT   : in  std_logic_vector(15 downto 0);

      -- OTMB PRBS signals
      OTMB_TX : in  std_logic_vector(48 downto 0);
      OTMB_RX : out std_logic_vector(5 downto 0)
      );
  end component;

  component COMMAND_MODULE is
    port (
      FASTCLK : in std_logic;
      SLOWCLK : in std_logic;

      GAP     : in std_logic;
      GA      : in std_logic_vector(4 downto 0);
      ADR     : in std_logic_vector(23 downto 1);
      AM      : in std_logic_vector(5 downto 0);

      AS      : in std_logic;
      DS0     : in std_logic;
      DS1     : in std_logic;
      LWORD   : in std_logic;
      WRITER  : in std_logic;
      IACK    : in std_logic;
      BERR    : in std_logic;
      SYSFAIL : in std_logic;

      DEVICE  : out std_logic_vector(9 downto 0);
      STROBE  : out std_logic;
      COMMAND : out std_logic_vector(9 downto 0);
      ADRS    : out std_logic_vector(17 downto 2);

      TOVME_B : out std_logic;
      DOE_B   : out std_logic;

      DIAGOUT : out std_logic_vector(17 downto 0);
      LED     : out std_logic_vector(2 downto 0)
      );
  end component;

  component SPI_CTRL is
    port (

      CLK40   : in std_logic;
      CLK2P5  : in std_logic;
      RST     : in std_logic;

      CMD_FIFO_IN : in std_logic_vector(15 downto 0);
      CMD_FIFO_WRITE_EN : in std_logic;
      READBACK_FIFO_OUT : out std_logic_vector(15 downto 0);
      READBACK_FIFO_READ_EN : in std_logic;
      READ_BUSY : out std_logic;

      NCMDS_SPICTRL : out unsigned(15 downto 0);
      NCMDS_SPIINTR : out unsigned(15 downto 0);
      DIAGOUT : out std_logic_vector(17 downto 0)
      );
  end component;

  signal device    : std_logic_vector(num_dev downto 0) := (others => '0');
  signal cmd       : std_logic_vector(9 downto 0) := (others => '0');
  signal strobe    : std_logic := '0';
  signal tovme_b, doe_b : std_logic := '0';
  signal vme_data_out_buf : std_logic_vector(15 downto 0) := (others => '0'); --comment for real ODMB, needed for KCU

  type dev_data_array is array(0 to num_dev) of std_logic_vector(15 downto 0);
  signal outdata_dev : dev_data_array;
  signal dtack_dev   : std_logic_vector(num_dev downto 0) := (others => '0');
  signal idx_dev     : integer range 0 to num_dev;

  signal devout      : std_logic_vector(bw_data-1 downto 0) := (others => '0'); --devtmp: used in place of the array

  signal diagout_buf : std_logic_vector(17 downto 0) := (others => '0');
  signal led_cfebjtag     : std_logic := '0';
  signal led_command      : std_logic_vector(2 downto 0)  := (others => '0');

  signal dl_jtag_tck_inner : std_logic_vector(6 downto 0);
  signal dl_jtag_tdi_inner, dl_jtag_tms_inner : std_logic;

  signal odmb_jtag_tck_inner, odmb_jtag_tdi_inner, odmb_jtag_tms_inner : std_logic;
  signal led_odmbjtag, odmb_jtag_sel_inner : std_logic;

  signal cmd_adrs_inner : std_logic_vector(17 downto 2) := (others => '0');

  signal odmb_id_inner : std_logic_vector(15 downto 0);

  --------------------------------------
  -- OTMB signals assembly
  --------------------------------------
  signal alct : std_logic_vector(17 downto 0);
  signal otmb_tx : std_logic_vector(48 downto 0);
  signal otmb_rx : std_logic_vector(5 downto 0);
  signal otmb_lct_rqst : std_logic;
  signal otmb_ext_trig : std_logic;

  signal cafifo_l1a          : std_logic := '0';
  signal cafifo_l1a_match_in : std_logic_vector(NCFEB+2 downto 1) := (others => '0');

  --------------------------------------
  -- CFG and CONST register signals
  --------------------------------------
  signal spi_cfg_ul_pulse           : std_logic := '0';
  signal spi_const_ul_pulse         : std_logic := '0';
  signal spi_reg_in                 : std_logic_vector(15 downto 0) := (others => '0');
  signal spi_cfg_busy               : std_logic := '0';
  signal spi_const_busy             : std_logic := '0';
  signal spi_cfg_reg_we             : integer range 0 to NREGS := 0;
  signal spi_const_reg_we           : integer range 0 to NREGS := 0;
  signal spi_const_regs             : cfg_regs_array;
  signal spi_cfg_regs               : cfg_regs_array;
  signal spi_ncmds_spictrl          : unsigned (15 downto 0);
  signal spi_ncmds_spiintr          : unsigned (15 downto 0);

  --------------------------------------
  -- PROM signals
  --------------------------------------
  signal spi_cmd_fifo_write_en     : std_logic := '0';
  signal spi_cmd_fifo_in           : std_logic_vector(15 downto 0) := x"0000";
  signal spi_readback_fifo_read_en : std_logic := '0';
  signal spi_readback_fifo_out     : std_logic_vector(15 downto 0) := x"0000";
  signal spi_read_busy             : std_logic := '0';


begin

  ----------------------------------
  -- Signal relaying for CFEBJTAG
  ----------------------------------
  DCFEB_TCK <= dl_jtag_tck_inner;
  DCFEB_TDI <= dl_jtag_tdi_inner;
  DCFEB_TMS <= dl_jtag_tms_inner;

  ----------------------------------
  -- Signal relaying for ODMBJTAG
  ----------------------------------
  ODMB_TCK <= odmb_jtag_tck_inner;
  ODMB_TDI <= odmb_jtag_tdi_inner;
  ODMB_TMS <= odmb_jtag_tms_inner;
  ODMB_SEL <= odmb_jtag_sel_inner;

  ----------------------------------
  -- Signal relaying for command module
  ----------------------------------
  VME_OE_B  <= doe_b;
  VME_DIR_B <= tovme_b;

  outdata_dev(0) <= (others => '0');
  outdata_dev(5) <= (others => '0');
  outdata_dev(6) <= (others => '0');
  idx_dev <= to_integer(unsigned(cmd_adrs_inner(15 downto 12)));
  VME_DATA_OUT <= outdata_dev(idx_dev);

  VME_DTACK_B <= not or_reduce(dtack_dev);

  ----------------------------------
  -- OTMB backplane pins
  ----------------------------------
  LCT_RQST(1) <= otmb_lct_rqst                when otmb_rx(0) = '0' else otmb_rx(0);
  LCT_RQST(2) <= otmb_ext_trig                when otmb_rx(0) = '0' else otmb_rx(1);
  RSVFD(0)    <= cafifo_l1a                   when otmb_rx(0) = '0' else otmb_rx(3); -- TODO: cafifo_l1a is place holder only
  RSVFD(1)    <= cafifo_l1a_match_in(NCFEB+1) when otmb_rx(0) = '0' else otmb_rx(4); -- TODO: cafifo_l1a is place holder only
  RSVFD(2)    <= cafifo_l1a_match_in(NCFEB+2) when otmb_rx(0) = '0' else otmb_rx(5); -- TODO: cafifo_l1a is place holder only

  -- Output referred to odmb_device.vhd: dmb_tx_odmb(48 downto 0)
  -- dmb_tx_odmb_inner <= "101" & lct(7 downto 6) & alct_dav & eof_alct_data(16 downto 15) &
  --                      eof_alct_data_valid_b & lct(5 downto 0) & eof_otmb_data_valid_b & otmb_dav &
  --                      eof_otmb_data(16 downto 15) & eof_alct_data(14 downto 0) & eof_otmb_data(14 downto 0);

  otmb_tx(14 downto 0)  <= OTMB(14 downto 0);    -- tmb_data[14:0]      // fifo data
  otmb_tx(29 downto 15) <= OTMB(32 downto 18);   -- alct_data[14:0]     // alct data
  otmb_tx(30)           <= OTMB(15);             -- tmb_ddu_special     // DDU special
  otmb_tx(31)           <= OTMB(16);             -- tmb_last_frame      // DMB last
  otmb_tx(32)           <= OTMB_DAV;             -- tmb_first_frame     // DMB data available
  otmb_tx(33)           <= OTMB(17);             -- tmb_/wr_enable      // DMB /wr
  otmb_tx(34)           <= RAWLCT(0);            -- tmb_active_feb_flag // DMB active cfeb flag
  otmb_tx(39 downto 35) <= RAWLCT(5 downto 1);   -- tmb_active_feb[4:0] // DMB active cfeb list
  otmb_tx(40)           <= OTMB(35);             -- alct_/wr_enable     // ALCT _wr_fifo
  otmb_tx(41)           <= OTMB(33);             -- alct_ddu_special    // ALCT ddu_special (alct_data[15])
  otmb_tx(42)           <= OTMB(34);             -- alct_last_frame     // ALCT last frame  (alct_data[16])
  otmb_tx(43)           <= ALCT_DAV;             -- alct_first_frame    // ALCT first frame (ALCT_DAV)
  otmb_tx(45 downto 44) <= RAWLCT(7 downto 6);   -- res_to_dmb[2:1]     // DMB active cfeb list
  otmb_tx(48 downto 46) <= RSVTD(5 downto 3);    -- res_to_dmb[5:3]     // Not used, ="101" in PRBS test

  ----------------------------------
  -- misc
  ----------------------------------
  PON_OE  <= '1';
  ODMB_ID <= odmb_id_inner;

  ----------------------------------
  -- debugging
  ----------------------------------
  DIAGOUT <= diagout_buf;

  ----------------------------------
  -- sub-modules
  ----------------------------------

  DEV1_CFEBJTAG : CFEBJTAG
    generic map (
      NCFEB => NCFEB
      )
    port map (
      -- CSP_LVMB_LA_CTRL => CSP_LVMB_LA_CTRL,
      FASTCLK => clk40,
      SLOWCLK => clk2p5,
      RST     => rst,

      DEVICE  => device(1),
      STROBE  => strobe,
      COMMAND => cmd,
      WRITER  => VME_WRITE_B,

      INDATA  => VME_DATA_IN,
      OUTDATA => outdata_dev(1),
      DTACK   => dtack_dev(1),

      INITJTAGS => DCFEB_INITJTAG,
      TCK       => dl_jtag_tck_inner,
      TDI       => dl_jtag_tdi_inner,
      TMS       => dl_jtag_tms_inner,
      FEBTDO    => DCFEB_TDO,

      DIAGOUT => open,
      LED     => led_cfebjtag
      );

  DEV2_ODMBJTAG : ODMBJTAG
    port map (
      FASTCLK => clk40,
      SLOWCLK => clk2p5,
      RST     => rst,
      DEVICE  => device(2),
      STROBE  => strobe,
      COMMAND => cmd,
      WRITER  => VME_WRITE_B,
      INDATA  => VME_DATA_IN,
      OUTDATA => outdata_dev(2),
      DTACK   => dtack_dev(2),
      INITJTAGS => ODMB_INITJTAG,
      TCK       => odmb_jtag_tck_inner,
      TDI       => odmb_jtag_tdi_inner,
      TMS       => odmb_jtag_tms_inner,
      ODMBTDO   => ODMB_TDO,
      JTAGSEL   => odmb_jtag_sel_inner,
      LED       => led_odmbjtag
      );

  DEV3_VMEMON : VMEMON
    generic map (
      NCFEB => NCFEB
      )
    port map (
      SLOWCLK => clk2p5,
      CLK40   => clk40,
      RST     => rst,

      DEVICE  => device(3),
      STROBE  => strobe,
      COMMAND => cmd,
      WRITER  => VME_WRITE_B,

      INDATA  => VME_DATA_IN,
      OUTDATA => outdata_dev(3),
      DTACK   => dtack_dev(3),

      DCFEB_DONE  => dcfeb_done,

      OPT_RESET_PULSE => OPT_RESET_PULSE,
      L1A_RESET_PULSE => L1A_RESET_PULSE,
      FW_RESET        => FW_RESET,
      REPROG_B        => DCFEB_REPROG_B,
      TEST_INJ        => TEST_INJ,
      TEST_PLS        => TEST_PLS,
      TEST_PED        => TEST_PED,
      TEST_BC0        => TEST_BC0,
      TEST_LCT        => TEST_LCT,
      OTMB_LCT_RQST   => otmb_lct_rqst,
      OTMB_EXT_TRIG   => otmb_ext_trig,

      MASK_PLS        => MASK_PLS,
      MASK_L1A        => MASK_L1A,
      TP_SEL          => open,
      MAX_WORDS_DCFEB => open,
      ODMB_CAL        => ODMB_CAL,
      MUX_DATA_PATH   => MUX_DATA_PATH,
      MUX_TRIGGER     => MUX_TRIGGER,
      MUX_LVMB        => MUX_LVMB,
      ODMB_PED        => ODMB_PED,
      ODMB_DATA_SEL   => ODMB_DATA_SEL,   -- output XY under command R 3XYC, when XY /= 40
      ODMB_DATA       => ODMB_DATA,       -- input depend on ODMB_DATA_SEL
      TXDIFFCTRL      => open,      -- TX voltage swing, W 3110 is disabled: constant output x"8"
      LOOPBACK        => open       -- For internal loopback tests, bbb for W 3100 bbb
      );

  DEV4_VMECONFREGS : VMECONFREGS
    generic map (
      NCFEB => NCFEB
      )
    port map (
      SLOWCLK => CLK2P5,
      CLK => CLK40,
      RST => RST,
      DEVICE  => device(4),
      STROBE  => strobe,
      COMMAND => cmd,
      WRITER => VME_WRITE_B,
      DTACK => dtack_dev(4),
      INDATA => VME_DATA_IN,
      OUTDATA => outdata_dev(4),

      LCT_L1A_DLY => LCT_L1A_DLY,
      CABLE_DLY => CABLE_DLY,
      OTMB_PUSH_DLY => OTMB_PUSH_DLY,
      ALCT_PUSH_DLY => ALCT_PUSH_DLY,
      BX_DLY => BX_DLY,
      INJ_DLY => INJ_DLY,
      EXT_DLY => EXT_DLY,
      CALLCT_DLY => CALLCT_DLY,
      ODMB_ID => odmb_id_inner,
      NWORDS_DUMMY => NWORDS_DUMMY,
      KILL => KILL,
      CRATEID => CRATEID,

      CHANGE_REG_DATA  => CHANGE_REG_DATA,
      CHANGE_REG_INDEX => CHANGE_REG_INDEX,

      SPI_CFG_UL_PULSE    => spi_cfg_ul_pulse,
      SPI_CONST_UL_PULSE  => spi_const_ul_pulse,
      SPI_REG_IN          => spi_reg_in,
      SPI_CONST_BUSY      => spi_const_busy,
      SPI_CONST_REG_WE    => spi_const_reg_we,
      SPI_CFG_BUSY        => spi_cfg_busy,
      SPI_CFG_REG_WE      => spi_cfg_reg_we,
      SPI_CONST_REGS      => spi_const_regs,
      SPI_CFG_REGS        => spi_cfg_regs
      );

  DEV6_SPI_PORT_I : SPI_PORT
    port map (
      SLOWCLK => CLK2P5,
      CLK => CLK40,
      RST => RST,
      DEVICE => device(6),
      STROBE => strobe,
      COMMAND => cmd,
      WRITER => VME_WRITE_B,
      DTACK => dtack_dev(6),
      INDATA => VME_DATA_IN,
      OUTDATA => outdata_dev(6),
      SPI_CFG_UL_PULSE => spi_cfg_ul_pulse,
      SPI_CONST_UL_PULSE   => spi_const_ul_pulse,
      SPI_UL_REG => spi_reg_in,
      SPI_CFG_BUSY => spi_cfg_busy,
      SPI_CONST_BUSY => spi_const_busy,
      SPI_CONST_REG_WE => spi_const_reg_we,
      SPI_CFG_REG_WE => spi_cfg_reg_we,
      SPI_CFG_REGS => spi_cfg_regs,
      SPI_CONST_REGS => spi_const_regs,
      SPI_CMD_FIFO_WRITE_EN => spi_cmd_fifo_write_en,
      SPI_CMD_FIFO_IN => spi_cmd_fifo_in,
      SPI_READBACK_FIFO_OUT => spi_readback_fifo_out,
      SPI_READBACK_FIFO_READ_EN => spi_readback_fifo_read_en,
      SPI_READ_BUSY => spi_read_busy,
      SPI_NCMDS_SPICTRL => spi_ncmds_spictrl,
      SPI_NCMDS_SPIINTR => spi_ncmds_spiintr,
      DIAGOUT => open
      );

  DEV7_SYSMON : SYSTEM_MON
    port map(
      OUTDATA => outdata_dev(7),
      DTACK   => dtack_dev(7),

      SLOWCLK => CLK1P25,
      FASTCLK => CLK40,
      RST     => rst,

      DEVICE  => device(7),
      STROBE  => strobe,
      COMMAND => cmd,
      WRITER  => vme_write_b,

      ADC_CS_B =>  ADC_CS_B,
      ADC_DIN  =>  ADC_DIN,
      ADC_SCK  =>  ADC_SCK,
      ADC_DOUT =>  ADC_DOUT,

      VAUXP => SYSMON_P,
      VAUXN => SYSMON_N
      );

  DEV8_LVDBMON : LVDBMON
    port map(
      SLOWCLK => CLK1P25,
      RST => RST,
      PON_RESET => PON_RESET,
      DEVICE => device(8),
      STROBE => strobe,
      COMMAND => cmd,
      WRITER => vme_write_b,
      INDATA => VME_DATA_IN,
      OUTDATA => outdata_dev(8),
      DTACK => dtack_dev(8),
      --LVMB signals
      LVADCEN => LVMB_CSB,
      ADCCLK => LVMB_SCLK,
      ADCDATA => LVMB_SDIN,
      ADCIN => LVMB_SDOUT,
      LVTURNON => LVMB_PON,
      R_LVTURNON => R_LVMB_PON,
      LOADON => PON_LOAD_B,
      DIAGOUT => open
      );

  DEV9_SYSTEST : SYSTEM_TEST
    port map (
      --CSP_FREE_AGENT_PORT_LA_CTRL => CSP_FREE_AGENT_PORT_LA_CTRL,

      DEVICE  => device(9),
      COMMAND => cmd,
      INDATA  => VME_DATA_IN,
      STROBE  => strobe,
      WRITER  => VME_WRITE_B,
      SLOWCLK => CLK2P5,
      CLK     => CLK40,
      CLK160  => CLK160,  -- previously using CLK1P25, why?
      RST     => RST,

      OUTDATA => outdata_dev(9),
      DTACK   => dtack_dev(9),

      -- FED/PC/DCFEB COMMON PRBS
      MGT_PRBS_TYPE => MGT_PRBS_TYPE,
      -- TODO: FED PRBS signals
      FED_PRBS_TX_EN   => FED_PRBS_TX_EN(0), -- temporary
      FED_PRBS_RX_EN   => FED_PRBS_RX_EN(0), -- temporary
      FED_PRBS_TST_CNT => FED_PRBS_TST_CNT,
      FED_PRBS_ERR_CNT => FED_PRBS_ERR_CNT,
      -- TODO: PC PRBS signals
      SPY_PRBS_TX_EN   => SPY_PRBS_TX_EN,
      SPY_PRBS_RX_EN   => SPY_PRBS_RX_EN,
      SPY_PRBS_TST_CNT => SPY_PRBS_TST_CNT,
      SPY_PRBS_ERR_CNT => SPY_PRBS_ERR_CNT,
      -- TODO: DCFEB PRBS signals
      DCFEB_PRBS_FIBER_SEL => DCFEB_PRBS_FIBER_SEL,
      DCFEB_PRBS_EN        => DCFEB_PRBS_EN,
      DCFEB_PRBS_RST       => DCFEB_PRBS_RST,
      DCFEB_PRBS_RD_EN     => DCFEB_PRBS_RD_EN,
      DCFEB_RXPRBSERR      => DCFEB_RXPRBSERR,
      DCFEB_PRBS_ERR_CNT   => DCFEB_PRBS_ERR_CNT,

      --OTMB_PRBS signals
      OTMB_TX => otmb_tx,
      OTMB_RX => otmb_rx
      );

  COMMAND_PM : COMMAND_MODULE
    port map (
      FASTCLK => CLK40,
      SLOWCLK => CLK2P5,
      GAP     => VME_GAP_B,
      GA      => VME_GA_B,
      ADR     => VME_ADDR,             -- input cmd = ADR(11 downto 2)
      AM      => VME_AM,
      AS      => VME_AS_B,
      DS0     => VME_DS_B(0),
      DS1     => VME_DS_B(1),
      LWORD   => VME_LWORD_B,
      WRITER  => VME_WRITE_B,
      IACK    => VME_IACK_B,
      BERR    => VME_BERR_B,
      SYSFAIL => VME_SYSFAIL_B,
      TOVME_B => tovme_b,
      DOE_B   => doe_b,
      DEVICE  => device,
      STROBE  => strobe,
      COMMAND => cmd,
      ADRS    => cmd_adrs_inner,
      DIAGOUT => open,
      LED     => led_command
      );

  SPI_CTRL_I : SPI_CTRL
    port map (
      CLK40 => CLK40,
      CLK2P5 => CLK2P5,
      RST => RST,
      CMD_FIFO_IN => spi_cmd_fifo_in,
      CMD_FIFO_WRITE_EN => spi_cmd_fifo_write_en,
      READBACK_FIFO_OUT => spi_readback_fifo_out,
      READBACK_FIFO_READ_EN => spi_readback_fifo_read_en,
      READ_BUSY => spi_read_busy,
      NCMDS_SPICTRL => spi_ncmds_spictrl,
      NCMDS_SPIINTR => spi_ncmds_spiintr,
      DIAGOUT => diagout_buf
      );

end Behavioral;
