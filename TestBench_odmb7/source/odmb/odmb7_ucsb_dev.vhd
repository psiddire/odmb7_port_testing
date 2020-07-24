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

entity ODMB7_UCSB_DEV is
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

    --------------------
    -- Signals controlled by VME
    --------------------
    -- VME_DATA       : inout std_logic_vector (15 downto 0);  -- FIXME: for real ODMB, there is one line, but for KCU, we can't have internal IOBUFs
    VME_DATA_IN    : in std_logic_vector (15 downto 0);  -- FIXME: inout for real ODMB
    VME_DATA_OUT   : out std_logic_vector (15 downto 0); -- FIXME: inout for real ODMB
    VME_GA         : in std_logic_vector (5 downto 0); -- gap is ga(5)
    VME_ADDR       : in std_logic_vector (23 downto 1);
    VME_AM         : in std_logic_vector (5 downto 0);
    VME_AS_B       : in std_logic;
    VME_DS_B       : in std_logic_vector (1 downto 0);
    VME_LWORD_B    : in std_logic;
    VME_WRITE_B    : in std_logic;
    VME_IACK_B     : in std_logic;
    VME_BERR_B     : in std_logic;
    VME_SYSFAIL_B  : in std_logic;
    VME_DTACK_V6_B : inout std_logic;
    VME_DOE_B      : in std_logic;
    --for debugging
    DIAGOUT        : out std_logic_vector (17 downto 0);

    DCFEB_TCK    : out std_logic_vector (NCFEB downto 1);
    DCFEB_TMS    : out std_logic;
    DCFEB_TDI    : out std_logic;
    DCFEB_TDO    : in  std_logic_vector (NCFEB downto 1);
    DCFEB_DONE   : in  std_logic_vector (NCFEB downto 1);

    --------------------
    -- Other
    --------------------
    RST         : in std_logic
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

      --------------------
      -- VME signals  <-- relevant ones only
      --------------------
      VME_DATA_IN    : in std_logic_vector (15 downto 0);
      VME_DATA_OUT   : out std_logic_vector (15 downto 0);
      VME_GA         : in std_logic_vector (5 downto 0); -- gap is ga(5)
      VME_ADDR       : in std_logic_vector (23 downto 1);
      VME_AM         : in std_logic_vector (5 downto 0);
      VME_AS_B       : in std_logic;
      VME_DS_B       : in std_logic_vector (1 downto 0);
      VME_LWORD_B    : in std_logic;
      VME_WRITE_B    : in std_logic;
      VME_IACK_B     : in std_logic;
      VME_BERR_B     : in std_logic;
      VME_SYSFAIL_B  : in std_logic;
      VME_DTACK_V6_B : inout std_logic;
      VME_DOE_B      : in std_logic;
      --for debugging
      DIAGOUT        : out std_logic_vector (17 downto 0);

      --------------------
      -- JTAG Signals To/From DCFEBs
      --------------------
      DCFEB_TCK    : out std_logic_vector (NCFEB downto 1);
      DCFEB_TMS    : out std_logic;
      DCFEB_TDI    : out std_logic;
      DCFEB_TDO    : in  std_logic_vector (NCFEB downto 1);
      DCFEB_DONE   : in  std_logic_vector (NCFEB downto 1);

      --------------------
      -- Other
      --------------------
      RST         : in std_logic
      );
  end component;

begin

  i_odmb_vme : ODMB_VME
    generic map (
      NCFEB => NCFEB
      )
    port map (
      CLK160         => CLK160,
      CLK40          => CLK40,
      CLK10          => CLK10,

      VME_DATA_IN    => VME_DATA_IN,
      VME_DATA_OUT   => VME_DATA_OUT,
      VME_GA         => VME_GA,
      VME_ADDR       => VME_ADDR,
      VME_AM         => VME_AM,
      VME_AS_B       => VME_AS_B,
      VME_DS_B       => VME_DS_B,
      VME_LWORD_B    => VME_LWORD_B,
      VME_WRITE_B    => VME_WRITE_B,
      VME_IACK_B     => VME_IACK_B,
      VME_BERR_B     => VME_BERR_B,
      VME_SYSFAIL_B  => VME_SYSFAIL_B,
      VME_DTACK_V6_B => VME_DTACK_V6_B,
      VME_DOE_B      => VME_DOE_B,
      DIAGOUT        => DIAGOUT,

      DCFEB_TCK      => DCFEB_TCK,
      DCFEB_TMS      => DCFEB_TMS,
      DCFEB_TDI      => DCFEB_TDI,
      DCFEB_TDO      => DCFEB_TDO,
      DCFEB_DONE     => DCFEB_DONE,

      RST            => RST
      );


end Behavioral;
