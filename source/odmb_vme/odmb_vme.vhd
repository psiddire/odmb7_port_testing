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

-- To mimic the behavior of ODMB_VME on the component CFEBJTAG

-- library UNISIM;
-- use UNISIM.VComponents.all;

use work.Firmware_pkg.all;     -- for switch between sim and synthesis

entity ODMB_VME is
  generic (
    NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
  );
  PORT (
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
    VME_DTACK_B   : inout std_logic;
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
    MASK_L1A             : out std_logic_vector (NCFEB downto 0);
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
end ODMB_VME;

architecture Behavioral of ODMB_VME is
  -- Constants
  constant bw_data  : integer := 16; -- data bit width

  component CONFREGS_DUMMY is
    port (
      SLOWCLK              : in std_logic;
      DEVICE               : in std_logic;
      STROBE               : in std_logic;
      COMMAND              : in std_logic_vector(9 downto 0);
      OUTDATA              : inout std_logic_vector(15 downto 0);
      DTACK                : out std_logic;
      LCT_L1A_DLY          : out std_logic_vector(5 downto 0);
      INJ_DLY              : out std_logic_vector(4 downto 0);
      EXT_DLY              : out std_logic_vector(4 downto 0);
      CALLCT_DLY           : out std_logic_vector(3 downto 0);
      CABLE_DLY            : out integer range 0 to 1
    );
  end component;

  component CFEBJTAG is
    generic (
      NCFEB   : integer range 1 to 7 := NCFEB
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

  component VMEMON is
    generic (
      NCFEB   : integer range 1 to 7 := NCFEB
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
      QPLL_LOCKED : in std_logic;

      OPT_RESET_PULSE : out std_logic;
      L1A_RESET_PULSE : out std_logic;
      FW_RESET        : out std_logic;
      REPROG_B        : out std_logic;
      TEST_INJ        : out std_logic;
      TEST_PLS        : out std_logic;
      TEST_PED        : out std_logic;
      TEST_BC0        : out std_logic;
      TEST_LCT        : out std_logic;
      OTMB_LCT_RQST   : out std_logic;
      OTMB_EXT_TRIG   : out std_logic;

      MASK_L1A      : out std_logic_vector(NCFEB downto 0);
      MASK_PLS      : out std_logic;
      TP_SEL        : out std_logic_vector(15 downto 0);
      MAX_WORDS_DCFEB        : out std_logic_vector(15 downto 0);
      ODMB_CTRL     : out std_logic_vector(15 downto 0);
      ODMB_DATA_SEL : out std_logic_vector(7 downto 0);
      ODMB_DATA     : in  std_logic_vector(15 downto 0);
      TXDIFFCTRL    : out std_logic_vector(3 downto 0);  -- Controls the TX voltage swing
      LOOPBACK      : out std_logic_vector(2 downto 0)  -- For internal loopback tests
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

  signal device    : std_logic_vector(9 downto 0) := (others => '0');
  signal cmd       : std_logic_vector(9 downto 0) := (others => '0');
  signal strobe    : std_logic := '0';
  signal tovme_b, doe_b : std_logic := '0';
  signal vme_data_out_buf : std_logic_vector(15 downto 0) := (others => '0'); --comment for real ODMB, needed for KCU

  signal dtack_dev : std_logic_vector(9 downto 0) := (others => '0');

  signal diagout_buf : std_logic_vector(17 downto 0) := (others => '0');
  signal led_cfebjtag     : std_logic := '0';
  signal led_command      : std_logic_vector(2 downto 0)  := (others => '0');

  signal dl_jtag_tck_inner : std_logic_vector(6 downto 0);
  signal dl_jtag_tdi_inner, dl_jtag_tms_inner : std_logic;

  -- ODMB implementation
  -- type dev_array is array(0 to 15) of std_logic_vector(15 downto 0);
  -- signal dev_outdata       : dev_array;

  -- Temporary, used in place of the array
  signal devout : std_logic_vector(bw_data-1 downto 0) := (others => '0');
  type dev_array is array(0 to 15) of std_logic_vector(15 downto 0);
  signal dev_outdata : dev_array;
  signal device_index : integer range 0 to 15;

  signal cmd_adrs_inner : std_logic_vector(17 downto 2) := (others => '0');

  -- signals between vme_master_fsm and command_module
  -- signal vme_adr     : std_logic_vector(23 downto 1) := (others => '0');


begin

  ----------------------------------
  -- Signal relaying for CFEBJTAG
  ----------------------------------
  DCFEB_TCK <= dl_jtag_tck_inner;
  DCFEB_TDI <= dl_jtag_tdi_inner;
  DCFEB_TMS <= dl_jtag_tms_inner;

  ----------------------------------
  -- Signal relaying for VME 
  ----------------------------------
  VME_OE_B  <= doe_b;
  VME_DIR_B <= tovme_b;

  --GEN_DEV_OUTDATA should be 10 to 15 once all modules are implemented
  GEN_DEV_OUTDATA : for dev in 5 to 15 generate
    dev_outdata(dev) <= (others => '0');
  end generate GEN_DEV_OUTDATA;
  device_index <= to_integer(unsigned(cmd_adrs_inner(15 downto 12)));
  VME_DATA_OUT <= dev_outdata(device_index);

  --Handle DTACK
  PULLUP_vme_dtack : PULLUP port map (O => VME_DTACK_B);
  VME_DTACK_B <= not or_reduce(dtack_dev);

  ----------------------------------
  -- debugging
  ----------------------------------
  DIAGOUT <= diagout_buf;

  ----------------------------------
  -- sub-modules
  ----------------------------------

  DEV4_DUMMY : CONFREGS_DUMMY
    port map (
          SLOWCLK => clk2p5,
          DEVICE  => device(4),
          STROBE  => strobe,
          COMMAND => cmd,
          OUTDATA => dev_outdata(4),
          DTACK => dtack_dev(4),
          LCT_L1A_DLY => LCT_L1A_DLY,
          INJ_DLY => INJ_DLY, 
          EXT_DLY => EXT_DLY, 
          CALLCT_DLY => CALLCT_DLY,
          CABLE_DLY => CABLE_DLY
    );

  DEV1_CFEBJTAG : CFEBJTAG
    generic map (NCFEB => NCFEB)
    port map (
      -- CSP_LVMB_LA_CTRL => CSP_LVMB_LA_CTRL,
      FASTCLK => clk40,
      SLOWCLK => clk2p5,
      RST     => rst,

      DEVICE  => device(1),
      STROBE  => strobe,
      COMMAND => cmd,

      WRITER  => VME_WRITE_B,
      INDATA  => vme_data_in,   -- VME_DATA_IN,
      OUTDATA => dev_outdata(1),

      DTACK   => dtack_dev(1),

      INITJTAGS => DCFEB_INITJTAG,
      TCK       => dl_jtag_tck_inner,
      TDI       => dl_jtag_tdi_inner,
      TMS       => dl_jtag_tms_inner,
      FEBTDO    => DCFEB_TDO,

      DIAGOUT => open,
      LED     => led_cfebjtag
      );

    DEV3_VMEMON : VMEMON
    generic map (NCFEB => NCFEB)
    port map (
      SLOWCLK => clk2p5,
      CLK40   => clk40,
      RST     => rst,

      DEVICE  => device(3),
      STROBE  => strobe,
      COMMAND => cmd,
      WRITER  => vme_write_b,

      INDATA  => vme_data_in,
      OUTDATA => dev_outdata(3),
      DTACK => dtack_dev(3),

      DCFEB_DONE  => dcfeb_done,
      QPLL_LOCKED => '1',

      OPT_RESET_PULSE => open,
      L1A_RESET_PULSE => L1A_RESET_PULSE,
      FW_RESET        => FW_RESET,
      REPROG_B        => open,
      TEST_INJ        => TEST_INJ,
      TEST_PLS        => TEST_PLS,
      TEST_PED        => TEST_PED,
      TEST_BC0        => TEST_BC0,
      TEST_LCT        => TEST_LCT,
      OTMB_LCT_RQST   => open,
      OTMB_EXT_TRIG   => open,

      MASK_PLS      => MASK_PLS,
      MASK_L1A      => MASK_L1A,
      TP_SEL        => open,
      MAX_WORDS_DCFEB => open,
      ODMB_CTRL     => ODMB_CTRL,
      ODMB_DATA_SEL => ODMB_DATA_SEL,
      ODMB_DATA     => ODMB_DATA,
      TXDIFFCTRL    => open,      -- Controls the TX voltage swing
      LOOPBACK      => open         -- For internal loopback tests
      );

  COMMAND_PM : COMMAND_MODULE
    port map (
      FASTCLK => clk40,
      SLOWCLK => clk2p5,
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
      DIAGOUT => diagout_buf,      -- temp
      LED     => led_command           -- temp
      );


end Behavioral;
