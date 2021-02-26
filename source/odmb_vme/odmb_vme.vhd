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

-- library UNISIM;
-- use UNISIM.VComponents.all;

use work.Firmware_pkg.all;     -- for switch between sim and synthesis

entity ODMB_VME is
  generic (
    NCFEB       : integer range 1 to 7 := 7;  -- Number of DCFEBS, 7 for ME1/1, 5
    NREGS       : integer := 16
  );
  PORT (
    --------------------
    -- Clock
    --------------------
    CLK160      : in std_logic;  -- For dcfeb prbs (160MHz)
    CLK40       : in std_logic;  -- NEW (fastclk -> 40MHz)
    CLK10       : in std_logic;  -- NEW (midclk -> fastclk/4 -> 10MHz)
    CLK2P5      : in std_logic;  -- 2.5 MHz clock
    CLK1P25     : in std_logic;

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
    PON_OE     : out std_logic;
    R_LVMB_PON : in  std_logic_vector(7 downto 0);
    LVMB_CSB   : out std_logic_vector(6 downto 0);
    LVMB_SCLK  : out std_logic;
    LVMB_SDIN  : out std_logic;
    LVMB_SDOUT : in  std_logic;

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
    -- VMEMON Configuration signals for top level and input from top level
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
        NREGS  : integer := 16;             -- Number of Configuration registers
        NCONST : integer := 16;             -- Number of Protected registers
        NFEB   : integer := 7               -- Number of DCFEBs
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
          KILL         : out std_logic_vector(NFEB+2 downto 1);
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
        ODMB_CAL      : out std_logic;
        TP_SEL        : out std_logic_vector(15 downto 0);
        MAX_WORDS_DCFEB : out std_logic_vector(15 downto 0);
        LOOPBACK      : out std_logic_vector(2 downto 0);  -- For internal loopback tests
        TXDIFFCTRL    : out std_logic_vector(3 downto 0);  -- Controls the TX voltage swing
        MUX_DATA_PATH   : out std_logic;
        MUX_TRIGGER     : out std_Logic;
        MUX_LVMB        : out std_logic;
        ODMB_PED        : out std_logic_vector(1 downto 0);
        TEST_PED        : out std_logic;
        MASK_L1A      : out std_logic_vector(NCFEB downto 0);
        MASK_PLS      : out std_logic;
        
        --exernal registers
        ODMB_DATA_SEL : out std_logic_vector(7 downto 0);
        ODMB_DATA     : in  std_logic_vector(15 downto 0)      
      );
  end component;
  
  component SPI_PORT is
    generic (
      NREGS  : integer := 16
      );
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

  type dev_array is array(0 to num_dev) of std_logic_vector(15 downto 0);
  signal outdata_dev : dev_array;
  signal dtack_dev   : std_logic_vector(num_dev downto 0) := (others => '0');
  signal idx_dev     : integer range 0 to num_dev;

  signal devout      : std_logic_vector(bw_data-1 downto 0) := (others => '0'); --devtmp: used in place of the array

  signal diagout_buf : std_logic_vector(17 downto 0) := (others => '0');
  signal led_cfebjtag     : std_logic := '0';
  signal led_command      : std_logic_vector(2 downto 0)  := (others => '0');

  signal dl_jtag_tck_inner : std_logic_vector(6 downto 0);
  signal dl_jtag_tdi_inner, dl_jtag_tms_inner : std_logic;

  signal cmd_adrs_inner : std_logic_vector(17 downto 2) := (others => '0');
  
  signal odmb_id_inner : std_logic_vector(15 downto 0);
  
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
  -- Signal relaying for command module
  ----------------------------------
  VME_OE_B  <= doe_b;
  VME_DIR_B <= tovme_b;

  outdata_dev(0) <= (others => '0');
  outdata_dev(2) <= (others => '0');
  outdata_dev(5) <= (others => '0');
  outdata_dev(7) <= (others => '0');
  -- This will not be needed when all devs are ready --devtmp
  GEN_OUTDATA_DEV : for dev in 9 to num_dev generate --devtmp
    outdata_dev(dev) <= (others => '0');             --devtmp
  end generate GEN_OUTDATA_DEV;                      --devtmp
  idx_dev <= to_integer(unsigned(cmd_adrs_inner(15 downto 12)));
  VME_DATA_OUT <= outdata_dev(idx_dev);

  --Handle DTACK
  PULLUP_vme_dtack : PULLUP port map (O => VME_DTACK_B);
  VME_DTACK_B <= not or_reduce(dtack_dev);
  
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

  DEV3_VMEMON : VMEMON
    generic map (NCFEB => NCFEB)
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
      ODMB_CAL      => ODMB_CAL,
      MUX_DATA_PATH => MUX_DATA_PATH,
      MUX_TRIGGER   => MUX_TRIGGER,
      MUX_LVMB      => MUX_LVMB,
      ODMB_PED      => ODMB_PED,
      ODMB_DATA_SEL => ODMB_DATA_SEL,   -- output: <= COMMAND[9:2] directly
      ODMB_DATA     => ODMB_DATA,       -- input depend on ODMB_DATA_SEL
      TXDIFFCTRL    => open,      -- TX voltage swing, W 3110 is disabled: constant output x"8"
      LOOPBACK      => open       -- For internal loopback tests, bbb for W 3100 bbb
      );
  
  DEV4_VMECONFREGS : VMECONFREGS
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
    generic map (NREGS => NREGS)
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
      LOADON => PON_LOAD,
      DIAGOUT => open
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
