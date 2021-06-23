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
    NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
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
    RAWLCT        : in std_logic_vector (NFEB downto 0);
    
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
    KILL        : in std_logic_vector(NFEB+2 downto 1);
    LCT_ERR     : out std_logic;            -- To an LED in the original design
    RST         : in std_logic
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

  signal plsinjen, plsinjen_inv : std_logic := '0';

  signal CAL_LCT       : std_logic;
  signal cal_gtrg     : std_logic;

-- TRGCNTRL outputs
  signal cafifo_l1a_match_in_inner : std_logic_vector(NFEB+2 downto 0);
  signal cafifo_push               : std_logic;  -- PUSH from TRGCNTRL to CAFIFO

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
    generic map (NFEB => NFEB)
    port map (
      CLK           => clk40,
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
      KILL          => kill(NFEB+2 downto 1),
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

end Behavioral;
