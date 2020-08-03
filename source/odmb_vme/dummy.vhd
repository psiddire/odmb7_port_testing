library ieee;
library work;
library UNISIM;
use UNISIM.vcomponents.all;
use work.Latches_Flipflops.all;
use ieee.std_logic_1164.all;
use work.ucsb_types.all;


entity CONFREGS_DUMMY is
  port (
    SLOWCLK : in std_logic;
    DEVICE  : in std_logic;
    STROBE  : in std_logic;
    COMMAND : in std_logic_vector(9 downto 0);
    OUTDATA : out std_logic_vector(15 downto 0);
    DTACK   : out std_logic
    );
end CONFREGS_DUMMY;

architecture CONFREGS_DUMMY_Arch of CONFREGS_DUMMY is

  signal cmddev : std_logic_vector(15 downto 0);
  signal gen_output : std_logic := '0';
  signal read_output : std_logic := '0';
  signal d_dtack : std_logic := '0';

begin

  --output 0d3b when given VME command 4100
  cmddev <= "000" & DEVICE & COMMAND & "00";
  gen_output <= '1' when cmddev = x"1100" else '0';
  read_output <= STROBE and gen_output;
  OUTDATA(15 downto 0) <= x"0d3b" when (read_output = '1') else "ZZZZZZZZZZZZZZZZ";
  d_dtack <= '1' when (read_output = '1') else '0';
  FD_dtack : FD port map(D => d_dtack, C => SLOWCLK, Q => DTACK);


end CONFREGS_DUMMY_Arch;
