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
    NCFEB       : integer range 1 to 7 := 7;  -- Number of DCFEBS, 7 for ME1/1, 5
    NREGS       : integer := 16
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
    OTMB_FF_CLK : in  std_logic;                          -- "TMB_FF_CLK" in Bank 45, not used
    RSVTD_IN    : in  std_logic_vector(7 downto 3);       -- "RSVTD[7:3]" in Bank 44-45
    RSVTD_OUT   : out std_logic_vector(2 downto 0);       -- "RSVTD[2:0]" in Bank 44-45
    LCT_RQST    : out std_logic_vector(2 downto 1);       -- Bank 45

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
end ODMB_VME;

architecture Behavioral of ODMB_VME is
  -- Constants
  constant bw_data  : integer := 16; -- data bit width
  constant num_dev  : integer := 9;  -- number of devices (exclude dev0)

  component QSPI_DUMMY is
    generic (
      NREGS  : integer := 16
      );
    port (
      SLOWCLK              : in std_logic;
      CLK                  : in std_logic;
      RST                  : in std_logic;
      BPI_CFG_UL_PULSE     : out std_logic;
      BPI_CFG_DL_PULSE     : out std_logic;
      BPI_CONST_UL_PULSE   : out std_logic;
      BPI_CONST_DL_PULSE   : out std_logic;
      CC_CFG_REG           : out std_logic_vector(15 downto 0);
      BPI_CFG_BUSY         : out std_logic;
      BPI_CONST_BUSY       : out std_logic;
      CC_CFG_REG_WE        : out integer range 0 to NREGS;
      CC_CONST_REG_WE      : out integer range 0 to NREGS;
      BPI_CFG_REGS         : in cfg_regs_array;
      BPI_CONST_REGS       : in cfg_regs_array
      );
  end component;
  
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
      
      -- To/From QSPI Interface
          QSPI_CFG_UL_PULSE   : in std_logic;
          QSPI_CONST_UL_PULSE : in std_logic;
          QSPI_REG_IN : in std_logic_vector(15 downto 0);
          QSPI_CFG_BUSY    : in  std_logic;
          QSPI_CONST_BUSY  : in  std_logic;
          QSPI_CFG_REG_WE   : in  integer range 0 to NREGS;
          QSPI_CONST_REG_WE : in  integer range 0 to NREGS;
          QSPI_CFG_REGS    : out cfg_regs_array;
          QSPI_CONST_REGS  : out cfg_regs_array
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

      -- DDU PRBS signals
      DDU_PRBS_TX_EN   : out std_logic;
      DDU_PRBS_RX_EN   : out std_logic;
      DDU_PRBS_TST_CNT : out std_logic_vector(15 downto 0);
      DDU_PRBS_ERR_CNT : in  std_logic_vector(15 downto 0);

      -- PC PRBS signals
      PC_PRBS_TX_EN   : out std_logic;
      PC_PRBS_RX_EN   : out std_logic;
      PC_PRBS_TST_CNT : out std_logic_vector(15 downto 0);
      PC_PRBS_ERR_CNT : in  std_logic_vector(15 downto 0);

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

  signal device    : std_logic_vector(num_dev downto 0) := (others => '0');
  signal cmd       : std_logic_vector(9 downto 0) := (others => '0');
  signal strobe    : std_logic := '0';
  signal tovme_b, doe_b : std_logic := '0';
  signal vme_data_out_buf : std_logic_vector(15 downto 0) := (others => '0'); --comment for real ODMB, needed for KCU

  -- lvmb signals
  signal lvmb_sdout : std_logic;

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
  
  -- OTMB signals assembly
  signal alct : std_logic_vector(17 downto 0);
  signal otmb_tx : std_logic_vector(48 downto 0);
  signal otmb_rx : std_logic_vector(5 downto 0);

  --temp bpi signals
  signal qspi_cfg_ul_pulse_inner : std_logic := '0';
  signal qspi_cfg_dl_pulse_inner : std_logic := '0';
  signal qspi_const_ul_pulse_inner : std_logic := '0';
  signal qspi_const_dl_pulse_inner : std_logic := '0';
  signal qspi_reg_in : std_logic_vector(15 downto 0) := (others => '0');
  signal qspi_cfg_busy : std_logic := '0';
  signal qspi_const_busy : std_logic := '0';
  signal qspi_cfg_reg_we : integer range 0 to NREGS := 0;
  signal qspi_const_reg_we : integer range 0 to NREGS := 0;
  signal const_regs_inner       : cfg_regs_array;
  signal cfg_regs_inner         : cfg_regs_array;

  -- VMEMON signals
  signal cafifo_l1a          : std_logic := '0';
  signal cafifo_l1a_match_in : std_logic_vector(NCFEB+2 downto 1) := (others => '0');

  signal otmb_lct_rqst : std_logic;
  signal otmb_ext_trig : std_logic;

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

  -- This will not be needed when all devs are ready --devtmp
  GEN_OUTDATA_DEV : for dev in 5 to num_dev generate --devtmp
    outdata_dev(dev) <= (others => '0');             --devtmp
  end generate GEN_OUTDATA_DEV;                      --devtmp
  idx_dev <= to_integer(unsigned(cmd_adrs_inner(15 downto 12)));
  VME_DATA_OUT <= outdata_dev(idx_dev);

  VME_DTACK_B <= not or_reduce(dtack_dev);
  
  u_lvmb_sdout : IBUFDS port map (I => LVMB_SDOUT_P, IB => LVMB_SDOUT_N, O => lvmb_sdout);

  ----------------------------------
  -- OTMB backplane pins
  ----------------------------------
  LCT_RQST(1)  <= otmb_lct_rqst                when otmb_rx(0) = '0' else otmb_rx(0);
  LCT_RQST(2)  <= otmb_ext_trig                when otmb_rx(0) = '0' else otmb_rx(1);
  RSVTD_OUT(0) <= cafifo_l1a                   when otmb_rx(0) = '0' else otmb_rx(3); -- TODO: cafifo_l1a is place holder only
  RSVTD_OUT(1) <= cafifo_l1a_match_in(NCFEB+1) when otmb_rx(0) = '0' else otmb_rx(4); -- TODO: cafifo_l1a is place holder only
  RSVTD_OUT(2) <= cafifo_l1a_match_in(NCFEB+2) when otmb_rx(0) = '0' else otmb_rx(5); -- TODO: cafifo_l1a is place holder only

  -- Output referred to odmb_device.vhd: dmb_tx_odmb(48 downto 0)
  -- dmb_tx_odmb_inner <= "101" & lct(7 downto 6) & alct_dav & eof_alct_data(16 downto 15) &
  --                      eof_alct_data_valid_b & lct(5 downto 0) & eof_otmb_data_valid_b & otmb_dav &
  --                      eof_otmb_data(16 downto 15) & eof_alct_data(14 downto 0) & eof_otmb_data(14 downto 0);

  -- otmb_tx <= (14 downto 0  => OTMB(14 downto 0),    -- tmb_data[14:0]      // fifo data
  --             29 downto 15 => OTMB(32 downto 18),   -- alct_data[14:0]     // alct data	
  --             30           => OTMB(15),             -- tmb_ddu_special     // DDU special
  --             31           => OTMB(16),             -- tmb_last_frame      // DMB last
  --             32           => OTMB_DAV,             -- tmb_first_frame     // DMB data available
  --             33           => OTMB(17),             -- tmb_/wr_enable      // DMB /wr
  --             34           => RAWLCT(0),            -- tmb_active_feb_flag // DMB active cfeb flag
  --             39 downto 35 => RAWLCT(5 downto 1),   -- tmb_active_feb[4:0] // DMB active cfeb list
  --             40           => OTMB(35),             -- alct_/wr_enable     // ALCT _wr_fifo
  --             41           => OTMB(33),             -- alct_ddu_special    // ALCT ddu_special (alct_data[15])
  --             42           => OTMB(34),             -- alct_last_frame     // ALCT last frame  (alct_data[16])
  --             43           => RSVTD_IN(7),          -- alct_first_frame    // ALCT first frame (ALCT_DAV)
  --             45 downto 44 => RSVTD_IN(5 downto 4), -- res_to_dmb[2:1]     // DMB active cfeb list
  --             46           => RSVTD_IN(6),          -- res_to_dmb[3]       // Not used, ='1' in PRBS test
  --             47           => RAWLCT(6),            -- res_to_dmb[4]       // Not used, ='0' in PRBS test
  --             48           => RSVTD_IN(3));         -- res_to_dmb[5]       // Not used, ='1' in PRBS test

  alct <= otmb(35 downto 18);
  otmb_tx <= RSVTD_IN(3) & RAWLCT(6) & RSVTD_IN(6) & RSVTD_IN(5) & RSVTD_IN(4) & RSVTD_IN(7) &
             alct(16 downto 15) & alct(17) & RAWLCT(5 downto 0) & otmb(17) & otmb(17) &
             otmb(16 downto 15) & alct(14 downto 0) & otmb(14 downto 0);

  ----------------------------------
  -- misc
  ----------------------------------
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

      DIAGOUT => diagout_buf,
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
      OTMB_LCT_RQST   => otmb_lct_rqst,
      OTMB_EXT_TRIG   => otmb_ext_trig,

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
        
        QSPI_CFG_UL_PULSE   => qspi_cfg_ul_pulse_inner,
        QSPI_CONST_UL_PULSE   => qspi_const_ul_pulse_inner,
        QSPI_REG_IN => qspi_reg_in,
        QSPI_CONST_BUSY  => qspi_const_busy,
        QSPI_CONST_REG_WE => qspi_const_reg_we,
        QSPI_CFG_BUSY    => qspi_cfg_busy,
        QSPI_CFG_REG_WE   => qspi_cfg_reg_we,
        
        QSPI_CONST_REGS  => const_regs_inner,
        QSPI_CFG_REGS    => cfg_regs_inner
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
      CLK160  => CLK1P25,
      RST     => RST,

      OUTDATA => outdata_dev(9),
      DTACK   => dtack_dev(9),

      -- DDU/PC/DCFEB COMMON PRBS
      MGT_PRBS_TYPE => MGT_PRBS_TYPE,

      -- TODO: DDU PRBS signals
      DDU_PRBS_TX_EN   => DDU_PRBS_TX_EN(0), -- temporary
      DDU_PRBS_RX_EN   => DDU_PRBS_RX_EN(0), -- temporary
      DDU_PRBS_TST_CNT => DDU_PRBS_TST_CNT,
      DDU_PRBS_ERR_CNT => DDU_PRBS_ERR_CNT,

      -- TODO: PC PRBS signals
      PC_PRBS_TX_EN   => SPY_PRBS_TX_EN,
      PC_PRBS_RX_EN   => SPY_PRBS_RX_EN,
      PC_PRBS_TST_CNT => SPY_PRBS_TST_CNT,
      PC_PRBS_ERR_CNT => SPY_PRBS_ERR_CNT,

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
      
  QSPI_DUMMY_I : QSPI_DUMMY
    generic map (NREGS => NREGS)
    port map (
      SLOWCLK => CLK2P5,
      CLK => CLK40,
      RST => RST, 
      BPI_CFG_UL_PULSE   => qspi_cfg_ul_pulse_inner,
      BPI_CFG_DL_PULSE   => qspi_cfg_dl_pulse_inner,
      BPI_CONST_UL_PULSE => qspi_const_ul_pulse_inner,
      BPI_CONST_DL_PULSE => qspi_const_dl_pulse_inner,
      CC_CFG_REG => qspi_reg_in,
      BPI_CONST_BUSY  => qspi_const_busy,
      CC_CONST_REG_WE => qspi_const_reg_we,
      BPI_CFG_BUSY    => qspi_cfg_busy,
      CC_CFG_REG_WE   => qspi_cfg_reg_we,
      BPI_CFG_REGS => cfg_regs_inner,
      BPI_CONST_REGS => const_regs_inner
    );


end Behavioral;
