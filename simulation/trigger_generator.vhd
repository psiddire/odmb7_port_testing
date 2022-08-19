Library UNISIM;
library ieee;
use UNISIM.vcomponents.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;

entity trigger_generator is
  port (
    CLK      : in std_logic;
    OTMB_DAV : out std_logic;
    ALCT_DAV : out std_logic;
    LCT      : out std_logic_vector(7 downto 0);
    L1A_B    : out std_logic
  );
end trigger_generator;

architecture behavioral of trigger_generator is
  constant l1a_delay : integer range 0 to 150 := 138;
  constant otmb_dav_delay : integer range 0 to 10 := 3;
  constant alct_dav_delay : integer range 0 to 50 := 33;

  signal lct_counter : unsigned(15 downto 0) := x"05DB";

  signal enable : std_logic := '0';

  signal lct_inner : std_logic := '0';
  signal l1a_inner : std_logic := '0';
  signal otmb_dav_inner : std_logic := '0';
  signal alct_dav_inner : std_logic := '0';

begin 
   --wait for VME commands to set ODMB conf registers
  enable <= '0', '1' after 24 us;

  --With PU=200, singlemu L1 trigger expected to be 27 kHz(~1/1500 BX) (CMS-TDR-017)
  --Guesstimate 1 muon/chamber/muon trigger = 1/1500 BX
  --generate new lct every 6000 bx

  proc_lctgen : process (CLK)
  begin
    if rising_edge(CLK) then
      if (enable='1') then
        if (lct_counter /= 1500) then
          lct_counter <= lct_counter+1;
          lct_inner <= '0';
        else
          lct_counter <= x"0000";
          lct_inner <= '1';
        end if;
      end if;
    end if;
  end process;

  --delay L1A, OTMB_DAV, and ALCT_DAV 
  l1a_inner <= transport lct_inner after 3450 ns; --138 bx
  otmb_dav_inner <= transport lct_inner after 3550 ns; --138+3 bx
  alct_dav_inner <= transport lct_inner after 4300 ns; --138+33 bx
  --L1A_DELAYER : DELAY_SIGNAL port map(DOUT => l1a_inner, CLK => CLK, NCYCLES => l1a_delay, DIN => lct_inner);
  --OTMB_DELAYER : DELAY_SIGNAL port map(DOUT => OTMB_DAV, CLK => CLK, NCYCLES => otmb_dav_delay, DIN => l1a_inner);
  --ALCT_DELAYER : DELAY_SIGNAL port map(DOUT => ALCT_DAV, CLK => CLK, NCYCLES => alct_dav_delay, DIN => l1a_inner);

  LCT <= lct_inner & lct_inner & lct_inner & lct_inner & lct_inner & lct_inner & lct_inner & lct_inner;
  L1A_B <= not l1a_inner;
  OTMB_DAV <= otmb_dav_inner;
  ALCT_DAV <= alct_dav_inner;

end behavioral;

