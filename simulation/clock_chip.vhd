library ieee;
library work;
library UNISIM;
use UNISIM.vcomponents.all;
use work.Latches_Flipflops.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;

--! @brief clock chip (ZL30267) SPI interface for testing
entity CLOCK_CHIP_SIM is
  port (
    FPGA_SEL   : in std_logic; --not a pin on real ZL30267
    RSTN       : in std_logic;
    AC0_GPIO0  : in std_logic;
    AC1_GPIO1  : in std_logic;
    AC2_GPIO2  : in std_logic;
    TEST_GPIO3 : in std_logic;
    IF0_CSN    : in std_logic;
    IF1_MISO   : inout std_logic;
    SCL_SCLK   : in std_logic;
    SDA_MOSI   : in std_logic
  );
end CLOCK_CHIP_SIM;

architecture CLOCK_CHIP_SIM_Arch of CLOCK_CHIP_SIM is
  
  signal rst_ac   : std_logic_vector(2 downto 0) := "000";
  signal rst_if   : std_logic_vector(1 downto 0) := "00";
  signal rst_test : std_logic := '0';

  signal ac_fpga       : std_logic_vector(2 downto 0);
  signal test_fpga     : std_logic;
  signal csn_fpga      : std_logic;
  signal miso_out_fpga : std_logic;
  signal miso_in_fpga  : std_logic;
  signal sclk_fpga     : std_logic;
  signal mosi_fpga     : std_logic;

  signal miso_in  : std_logic;
  signal miso_out : std_logic;
  signal miso_dir : std_logic;

  signal counter         : unsigned(7 downto 0) := x"00";
  signal miso_out_desync : std_logic;
  signal cmd             : std_logic_vector(7 downto 0);
  signal addr            : std_logic_vector(15 downto 0);

  signal read_reg : std_logic_vector(7 downto 0) := x"5A";

begin

  --simulate ODMB board multiplexers
  ac_fpga <= (AC0_GPIO0 & AC1_GPIO1 & AC2_GPIO2) when (FPGA_SEL='1') else "000";
  test_fpga <= TEST_GPIO3 when (FPGA_SEL='1') else '0';
  csn_fpga <= IF0_CSN when (FPGA_SEL='1') else '0';
  miso_out <= miso_out_fpga when (FPGA_SEL='1') else '1';
  miso_in_fpga <= miso_in when (FPGA_SEL='1') else '0';
  sclk_fpga <= SCL_SCLK when (FPGA_SEL='1') else '0';
  mosi_fpga <= SDA_MOSI when (FPGA_SEL='1') else '0';

  --iobuf
  MISOBUF : IOBUF port map(O => miso_in, IO => IF1_MISO, I => miso_out, T => miso_dir);

  --reset logic
  rst_ac <= ac_fpga when rising_edge(RSTN);
  rst_if <= (miso_in_fpga & csn_fpga) when rising_edge(RSTN);
  rst_test <= test_fpga when rising_edge(RSTN);

  --normal logic
  process_spi : process (sclk_fpga)
  begin
  if rising_edge(sclk_fpga) then
    if (rst_if = "11" and RSTN='1') then --in SPI mode and not reset
      if (csn_fpga = '1') then
        counter <= x"00";
        miso_dir <= '1';
      else
        if (counter < 8) then
          cmd <= cmd(6 downto 0) & mosi_fpga;
          miso_out_desync <= '1';
          miso_dir <= '1';
        elsif (counter < 23) then
          addr <= addr(14 downto 0) & mosi_fpga;
          miso_out_desync <= '1';
          miso_dir <= '1';
        elsif (counter = 23) then
          addr <= addr(14 downto 0) & mosi_fpga;
          if (cmd=x"03" and (addr(14 downto 0) & mosi_fpga)=x"F5F6") then
            miso_out_desync <= read_reg(7);
            read_reg <= read_reg(6 downto 0) & read_reg(7);
            miso_dir <= '0';
          else
            miso_out_desync <= '1';
            miso_dir <= '1';
          end if;
        else
          if (cmd=x"03" and addr=x"F5F6") then
            miso_out_desync <= read_reg(7);
            read_reg <= read_reg(6 downto 0) & read_reg(7);
            miso_dir <= '0';
          elsif (cmd=x"02" and addr=x"F5F6") then
            read_reg <= read_reg(6 downto 0) & mosi_fpga;
            miso_out_desync <= '1';
            miso_dir <= '1';
          else
            miso_out_desync <= '1';
            miso_dir <= '1';
          end if;
        end if;
        counter <= counter + 1;
      end if;
    elsif (RSTN='0') then
      read_reg <= x"5A";
    else
      counter <= x"00";
      miso_dir <= '1';
    end if; --SPI mode and not reset
  end if; --SCLK rising
  if falling_edge(sclk_fpga) then
    miso_out_fpga <= miso_out_desync;
  end if; --SCLK falling
  end process process_spi;

end CLOCK_CHIP_SIM_Arch;
