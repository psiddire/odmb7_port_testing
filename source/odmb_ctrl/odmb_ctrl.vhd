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

use work.Firmware_pkg.all;     -- for switch between sim and synthesis

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
end ODMB_CTRL;

architecture Behavioral of ODMB_CTRL is
  -- Constants

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

  signal plsinjen, plsinjen_inv : std_logic := '0';

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
      CAL_GTRG => open,           --TODO connect to TRGCNTRL
      CALLCT => open,             --TODO connect to TRGCNTRL
      INJBACK => DCFEB_INJPULSE,
      PLSBACK => DCFEB_EXTPULSE,
      LCTRQST => open, 
      INJPLS => open              --unused
      );

end Behavioral;
