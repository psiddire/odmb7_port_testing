------------------------------
-- ODMB_CTRL: controls triggers, calibration, and the data path
------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;
use work.ucsb_types.all;
use work.odmb7_components.all;

entity ODMB_CTRL is
  generic (
    NCFEB       : integer range 1 to 7 := 7;  -- Number of DCFEBS, 7 for ME1/1, 5
    CAFIFO_SIZE : integer range 1 to 128 := 128  -- Number FIFO words in CAFIFO
  );
  PORT (
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
    OTMB_PUSH_DLY : in integer range 0 to 63;
    ALCT_PUSH_DLY : in integer range 0 to 63;
    PUSH_DLY      : in integer range 0 to 63;

    --------------------
    -- Configuration
    --------------------
    CAL_MODE      : in std_logic;
    PEDESTAL      : in std_logic;
    PEDESTAL_OTMB   : in  std_logic;

    --------------------
    -- TRGCNTRL
    --------------------
    RAW_L1A       : in std_logic;
    RAWLCT        : in std_logic_vector (NCFEB downto 0);
    
    --------------------
    -- DAV 
    --------------------
    OTMB_DAV : in std_logic;            
    ALCT_DAV : in std_logic;            

    --------------------
    -- To/From DCFEBs (FF-EMU-MOD)
    --------------------
    DCFEB_INJPULSE  : out std_logic;
    DCFEB_EXTPULSE  : out std_logic;
    DCFEB_L1A       : out std_logic;
    DCFEB_L1A_MATCH : out std_logic_vector(NCFEB downto 1);

    ALCT_DAV_SYNC_OUT : out std_logic;
    OTMB_DAV_SYNC_OUT : out std_logic;
    --------------------
    -- Other
    --------------------
    DIAGOUT     : out std_logic_vector (17 downto 0); -- for debugging
    KILL        : in std_logic_vector(NCFEB+2 downto 1);
    LCT_ERR     : out std_logic;            -- To an LED in the original design

    BX_DLY        : in integer range 0 to 4095;
    BC0         : in std_logic;
    CCB_BXRST_B : in  std_logic;       -- bxrst - from J3
    L1ACNT_RST  : in std_logic;
    BXCNT_RST   : in std_logic;
    RST         : in std_logic;

    EOF_DATA     : in std_logic_vector(NCFEB+2 downto 1);

-- From ALCT,OTMB,DCFEBs to CAFIFO
    ALCT_DV     : in std_logic;
    OTMB_DV     : in std_logic;
    DCFEB0_DV   : in std_logic;
    DCFEB0_DATA : in std_logic_vector(15 downto 0);
    DCFEB1_DV   : in std_logic;
    DCFEB1_DATA : in std_logic_vector(15 downto 0);
    DCFEB2_DV   : in std_logic;
    DCFEB2_DATA : in std_logic_vector(15 downto 0);
    DCFEB3_DV   : in std_logic;
    DCFEB3_DATA : in std_logic_vector(15 downto 0);
    DCFEB4_DV   : in std_logic;
    DCFEB4_DATA : in std_logic_vector(15 downto 0);
    DCFEB5_DV   : in std_logic;
    DCFEB5_DATA : in std_logic_vector(15 downto 0);
    DCFEB6_DV   : in std_logic;
    DCFEB6_DATA : in std_logic_vector(15 downto 0);

    EXT_DCFEB_L1A_CNT7 : out std_logic_vector(23 downto 0);
    DCFEB_L1A_DAV7     : out std_logic;
    CAFIFO_PREV_NEXT_L1A_MATCH : out std_logic_vector(15 downto 0);
    CAFIFO_PREV_NEXT_L1A       : out std_logic_vector(15 downto 0);
    CONTROL_DEBUG              : out std_logic_vector(15 downto 0);
    CAFIFO_DEBUG               : out std_logic_vector(15 downto 0);
    CAFIFO_WR_ADDR             : out std_logic_vector(7 downto 0);
    CAFIFO_RD_ADDR             : out std_logic_vector(7 downto 0);

-- From CAFIFO to Data FIFOs
    CAFIFO_L1A           : out std_logic;
    CAFIFO_L1A_MATCH_IN  : out std_logic_vector(NCFEB+2 downto 1);  -- From TRGCNTRL to CAFIFO to generate Data  
    CAFIFO_L1A_MATCH_OUT : out std_logic_vector(NCFEB+2 downto 1);  -- From CAFIFO to CONTROL  
    CAFIFO_L1A_CNT       : out std_logic_vector(23 downto 0);
    CAFIFO_L1A_DAV       : out std_logic_vector(NCFEB+2 downto 1);
    CAFIFO_BX_CNT        : out std_logic_vector(11 downto 0);

-- From GigaLinks
    DDU_DATA       : out std_logic_vector(15 downto 0);
    DDU_DATA_VALID : out std_logic;

-- From LOADFIFO
    JOEF : in std_logic_vector(NCFEB+2 downto 1);
-- For headers/trailers
    DAQMBID : in std_logic_vector(11 downto 0);  -- From CRATEID in SETFEBDLY, and GA
    AUTOKILLED_DCFEBS  : in std_logic_vector(NCFEB downto 1);
      
-- From/To Data FIFOs
    DATA_FIFO_RE : out std_logic_vector(NCFEB+2 downto 1);
    DATA_FIFO_OE : out std_logic_vector(NCFEB+2 downto 1);

    FIFO_OUT : in std_logic_vector(15 downto 0);
    FIFO_EOF : in std_logic;

    FIFO_EMPTY_B   : in std_logic_vector(NCFEB+2 downto 1);  -- emptyf*(7 DOWNTO 1) - from FIFOs
    FIFO_HALF_FULL : in std_logic_vector(NCFEB+2 downto 1)  -- 
    );
end ODMB_CTRL;

architecture Behavioral of ODMB_CTRL is

  component CALIBTRG is
    port (
      CMSCLK      : in  std_logic;
      CLK80       : in  std_logic;
      RST         : in  std_logic;
      PLSINJEN    : in  std_logic;
      CCBPLS      : in  std_logic;
      CCBINJ      : in  std_logic;
      FPLS        : in  std_logic;
      FINJ        : in  std_logic;
      FPED        : in  std_logic;
      PRELCT      : in  std_logic;
      PREGTRG     : in  std_logic;
      INJ_DLY     : in  std_logic_vector(4 downto 0);
      EXT_DLY     : in  std_logic_vector(4 downto 0);
      CALLCT_DLY  : in  std_logic_vector(3 downto 0);
      LCT_L1A_DLY : in  std_logic_vector(5 downto 0);
      RNDMPLS     : in  std_logic;
      RNDMGTRG    : in  std_logic;
      PEDESTAL    : out std_logic;
      CAL_GTRG    : out std_logic;
      CALLCT      : out std_logic;
      INJBACK     : out std_logic;
      PLSBACK     : out std_logic;
      LCTRQST     : out std_logic;
      INJPLS      : out std_logic
      );
  end component;


  --component DUMMY_TRIGCTRL is
  --  generic (
  --    NCFEB : integer range 1 to 7 := 7
  --    );
  --  port (
  --    CLK40       : in  std_logic;
  --    RAW_L1A     : in  std_logic;
  --    CAL_L1A     : in  std_logic;
  --    CAL_MODE    : in  std_logic;
  --    PEDESTAL    : in  std_logic;
  --    DCFEB_L1A   : out std_logic;
  --    DCFEB_L1A_MATCH : out std_logic_vector(NCFEB downto 1)
  --    );
  --end component;

  signal LOGICL : std_logic := '0';
  signal LOGICH : std_logic := '1';

  signal plsinjen, plsinjen_inv : std_logic := '0';

  signal CAL_LCT       : std_logic;
  signal cal_gtrg     : std_logic;

-- internal signals
  signal cafifo_l1a_match_in_inner : std_logic_vector(NCFEB+2 downto 0);
  signal cafifo_push               : std_logic;  -- PUSH from TRGCNTRL to CAFIFO
  signal cafifo_l1a_match_out_inner : std_logic_vector(NCFEB+2 downto 1);
  signal cafifo_l1a_cnt_out         : std_logic_vector(23 downto 0);
  signal cafifo_l1a_dav_out         : std_logic_vector(NCFEB+2 downto 1);
  signal cafifo_bx_cnt_out          : std_logic_vector(11 downto 0);
  signal cafifo_lost_pckt_out       : std_logic_vector(NCFEB+2 downto 1);
  signal cafifo_lone                : std_logic;

  signal bxrst, ccb_bxrst, ccb_bx0 : std_logic;
  signal status : std_logic_vector(47 downto 0) := (others => '0');
  signal rdffnxt : std_logic := '0';    -- from MBV

-- CONTROL outputs
  signal control_debug_full   : std_logic_vector(143 downto 0);
  signal cafifo_pop           : std_logic := '0';
  signal eof                  : std_logic := '0';
  signal ddu_data_inner       : std_logic_vector(15 downto 0);
  signal ddu_data_valid_inner : std_logic := 'L';

begin

  ----------------------------------
  -- Generate plsinjen (why is this oscillating?)
  ----------------------------------
  --current ODMB delays PLSINJEN after power-on for a couple clock cycles
  FDCE_plsinjen : FDCE port map(D => plsinjen_inv, C => CLK40, CE => '1', CLR => '0', Q => plsinjen);
  plsinjen_inv <= not plsinjen;

  ----------------------------------
  -- sub-modules
  ----------------------------------

  CALIBTRG_PM : CALIBTRG
    port map (
      CMSCLK => CLK40,
      CLK80 => CLK80,
      RST => RST, 
      PLSINJEN => PLSINJEN, 
      CCBPLS => '0',              --TODO generate from CCB input
      CCBINJ => '0',              --TODO generate from CCB input
      FPLS => TEST_CCBPLS,
      FINJ => TEST_CCBINJ, 
      FPED => TEST_CCBPED, 
      PRELCT => '0',              --unused
      PREGTRG => '0',             --unused
      INJ_DLY => INJ_DLY, 
      EXT_DLY => EXT_DLY, 
      CALLCT_DLY => CALLCT_DLY, 
      LCT_L1A_DLY => LCT_L1A_DLY, 
      RNDMPLS => '0',             --unused
      RNDMGTRG => '0',            --unused
      PEDESTAL => open,           --unused
      CAL_GTRG => cal_gtrg,           
      CALLCT => cal_lct,             --TODO connect to TRGCNTRL
      INJBACK => DCFEB_INJPULSE,
      PLSBACK => DCFEB_EXTPULSE,
      LCTRQST => open, 
      INJPLS => open              --unused
      );

  --DUMMY_TRIGCTRL_PM : DUMMY_TRIGCTRL
  --  generic map (
  --    NCFEB => NCFEB
  --  )
  --  port map (
  --    CLK40 => CLK40,
  --    RAW_L1A => RAW_L1A,
  --    CAL_L1A => cal_gtrg,
  --    CAL_MODE => CAL_MODE,
  --    PEDESTAL => PEDESTAL,
  --    DCFEB_L1A => DCFEB_L1A,
  --    DCFEB_L1A_MATCH => DCFEB_L1A_MATCH
  --  );

  TRGCNTRL_PM : TRGCNTRL
    generic map (NCFEB => NCFEB)
    port map (
      CLK           => clk40,
      CLK80        =>  clk80,
      RAW_L1A       => raw_l1a,
      RAW_LCT       => rawlct,
      CAL_LCT       => cal_lct,
      CAL_L1A       => cal_gtrg,
      LCT_L1A_DLY   => lct_l1a_dly,
      OTMB_PUSH_DLY => otmb_push_dly,
      ALCT_PUSH_DLY => alct_push_dly,
      PUSH_DLY      => push_dly,
      ALCT_DAV      => alct_dav,
      OTMB_DAV      => otmb_dav,

      CAL_MODE      => cal_mode,
      KILL          => kill(NCFEB+2 downto 1),
      PEDESTAL      => pedestal,
      PEDESTAL_OTMB => pedestal_otmb,

      ALCT_DAV_SYNC_OUT => ALCT_DAV_SYNC_OUT,
      OTMB_DAV_SYNC_OUT => OTMB_DAV_SYNC_OUT,

      DCFEB_L1A       => dcfeb_l1a,
      DCFEB_L1A_MATCH => dcfeb_l1a_match,
      FIFO_PUSH       => cafifo_push,
      FIFO_L1A_MATCH  => cafifo_l1a_match_in_inner,
      LCT_ERR         => lct_err
      );

  CAFIFO_PM : CAFIFO
    generic map (NCFEB => NCFEB, CAFIFO_SIZE => CAFIFO_SIZE)
    port map(
      --CSP_FREE_AGENT_PORT_LA_CTRL => CSP_FREE_AGENT_PORT_LA_CTRL,
      clk                         => clk40,
      dduclk                      => clk80,
      l1acnt_rst                  => l1acnt_rst,
      bxcnt_rst                   => bxcnt_rst,

      BC0     => bc0,
      CCB_BX0 => ccb_bx0,
      BXRST   => ccb_bxrst,
      BX_DLY  => BX_DLY,
      PUSH_DLY      => push_dly,

      pop          => cafifo_pop,
      l1a          => cafifo_push,
      l1a_match_in => cafifo_l1a_match_in_inner(NCFEB+2 downto 1),

      eof_data => eof_data,


      alct_dv     => alct_dv,
      otmb_dv     => otmb_dv,
      dcfeb0_dv   => dcfeb0_dv,
      dcfeb0_data => dcfeb0_data,
      dcfeb1_dv   => dcfeb1_dv,
      dcfeb1_data => dcfeb1_data,
      dcfeb2_dv   => dcfeb2_dv,
      dcfeb2_data => dcfeb2_data,
      dcfeb3_dv   => dcfeb3_dv,
      dcfeb3_data => dcfeb3_data,
      dcfeb4_dv   => dcfeb4_dv,
      dcfeb4_data => dcfeb4_data,
      dcfeb5_dv   => dcfeb5_dv,
      dcfeb5_data => dcfeb5_data,
      dcfeb6_dv   => dcfeb6_dv,
      dcfeb6_data => dcfeb6_data,

      cafifo_l1a_match => cafifo_l1a_match_out_inner,
      cafifo_l1a_cnt   => cafifo_l1a_cnt_out,
      cafifo_l1a_dav   => cafifo_l1a_dav_out,
      cafifo_bx_cnt    => cafifo_bx_cnt_out,
      cafifo_lost_pckt => cafifo_lost_pckt_out,
      cafifo_lone      => cafifo_lone,

      ext_dcfeb_l1a_cnt7 => ext_dcfeb_l1a_cnt7,
      dcfeb_l1a_dav7     => dcfeb_l1a_dav7,

      cafifo_prev_next_l1a_match => cafifo_prev_next_l1a_match,
      cafifo_prev_next_l1a       => cafifo_prev_next_l1a,
      control_debug              => control_debug_full,
      cafifo_debug               => cafifo_debug,
      cafifo_wr_addr             => cafifo_wr_addr,
      cafifo_rd_addr             => cafifo_rd_addr
      );

  CONTROL_FSM_PM : CONTROL_FSM
    generic map(NCFEB => NCFEB)
    port map(
      --CSP_CONTROL_FSM_PORT_LA_CTRL => CSP_CONTROL_FSM_PORT_LA_CTRL,
      CLK                          => clk80,
      CLKCMS                       => clk40,
      RST                          => l1acnt_rst,
      STATUS                       => status,

-- From DMB_VME
      RDFFNXT => rdffnxt,  -- from MBV (currently assigned as a signal to '0')
      KILL => KILL,
      
-- to GigaBit Link
      DOUT => ddu_data_inner,
      DAV  => ddu_data_valid_inner,

-- to Data FIFOs
      OEFIFO_B  => data_fifo_oe,
      RENFIFO_B => data_fifo_re,

-- from Data FIFOs
      FIFO_HALF_FULL => fifo_half_full,
      FFOR_B         => fifo_empty_b,
      DATAIN         => fifo_out(15 downto 0),
      DATAIN_LAST    => fifo_eof,

-- From JTAGCOM
      JOEF => joef,                     -- from LOADFIFO

-- From CONFREG and GA
      DAQMBID => daqmbid,
      AUTOKILLED_DCFEBS => AUTOKILLED_DCFEBS,

-- FROM SW1
      GIGAEN => LOGICH,

-- TO CAFIFO
      FIFO_POP => cafifo_pop,

-- TO PCFIFO
      EOF => eof,

-- DEBUG
      control_debug => control_debug_full,

-- FROM CAFIFO
      cafifo_l1a_dav   => cafifo_l1a_dav_out,
      cafifo_l1a_match => cafifo_l1a_match_out_inner,
      cafifo_l1a_cnt   => cafifo_l1a_cnt_out,
      cafifo_bx_cnt    => cafifo_bx_cnt_out,
      cafifo_lost_pckt => cafifo_lost_pckt_out,
      cafifo_lone      => cafifo_lone
      );

  cafifo_l1a_match_in  <= cafifo_l1a_match_in_inner(NCFEB+2 downto 1);
  cafifo_l1a_match_out <= cafifo_l1a_match_out_inner;
  cafifo_l1a_dav       <= cafifo_l1a_dav_out;
  cafifo_l1a_cnt       <= cafifo_l1a_cnt_out;
  cafifo_bx_cnt        <= cafifo_bx_cnt_out;

  ccb_bxrst <= not ccb_bxrst_b;
  control_debug <= control_debug_full(15 downto 0);

  DDU_DATA       <= ddu_data_inner;
  DDU_DATA_VALID <= ddu_data_valid_inner;

end Behavioral;
