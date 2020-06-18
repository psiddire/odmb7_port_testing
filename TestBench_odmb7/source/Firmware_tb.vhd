library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.Firmware_pkg.all;

entity Firmware_tb is
  PORT ( 
    -- 300 MHz clk_in
    CLK_IN_P : in std_logic;
    CLK_IN_N : in std_logic;
    -- 40 MHz clk out
    J36_USER_SMA_GPIO_P : out std_logic
  );      
end Firmware_tb;

architecture Behavioral of Firmware_tb is
  component clockManager is
  port (
    CLK_IN300  : in std_logic := '0';
    CLK_OUT40  : out std_logic := '0';
    CLK_OUT10  : out std_logic := '0';
    CLK_OUT80  : out std_logic := '0';
    CLK_OUT160 : out std_logic := '0'
  );
  end component;
  component ila is
  port (
    clk : in std_logic := '0';
    probe0 : in std_logic_vector(255 downto 0) := (others=> '0');
    probe1 : in std_logic_vector(4095 downto 0) := (others => '0')
  );
  end component;

  -- LUT constents
  constant bw_addr   : integer := 3;
  constant bw_input1 : integer := 16;
  constant bw_input2 : integer := 16;
  component lut_input1 is
  port (
    clka : in std_logic := '0';
    addra : in std_logic_vector(bw_addr-1 downto 0) := (others=> '0');
    douta : out std_logic_vector(bw_input1-1 downto 0) := (others => '0')
  );
  end component;
  component lut_input2 is
  port (
    clka : in std_logic := '0';
    addra : in std_logic_vector(bw_addr-1 downto 0) := (others=> '0');
    douta : out std_logic_vector(bw_input2-1 downto 0) := (others => '0')
  );
  end component;

  -- Clock signals
  signal clk_in_buf : std_logic := '0';
  signal sysclk : std_logic := '0';
  signal sysclkQuarter : std_logic := '0'; 
  signal sysclkDouble : std_logic := '0';
  signal sysclkQuad : std_logic := '0';
  signal init_done: std_logic := '0';
  -- Constants
  constant bw_output : integer := 20;
  constant bw_fifo   : integer := 18;
  constant bw_count  : integer := 16;
  constant bw_wait   : integer := 9;
  constant nclksrun  : integer := 2048;
  -- Counters
  signal waitCounter  : unsigned(bw_wait-1 downto 0) := (others=> '0');
  signal inputCounter : unsigned(bw_count-1 downto 0) := (others=> '0');
  signal startCounter  : unsigned(bw_count-1 downto 0) := (others=> '0');

  -- Reset
  signal rst_global : std_logic := '0';

  -- Mimic input/output from/to the VME and discrete logic part
  signal vme_data_in      : std_logic_vector (15 downto 0) := (others => '0');
  signal vme_data_out     : std_logic_vector (15 downto 0) := (others => '0'); 
  signal dl_jtag_tck      : std_logic_vector (6 downto 0)  := (others => '0');
  signal dl_jtag_tms      : std_logic := '0';
  signal dl_jtag_tdi      : std_logic := '0';
  signal dl_jtag_tdo      : std_logic_vector (6 downto 0)  := (others => '0');
  signal dcfeb_initjtag   : std_logic := '0';
  signal diagout          : std_logic_vector (17 downto 0) := (others => '0');

  -- ILA
  signal trig0 : std_logic_vector(255 downto 0) := (others=> '0');
  signal data  : std_logic_vector(4095 downto 0) := (others=> '0');
  -- LUT input
  signal lut_input_addr1_s : unsigned(bw_addr-1 downto 0) := (others=> '1');
  signal lut_input_addr2_s : unsigned(bw_addr-1 downto 0) := (others=> '1');
  signal lut_input1_dout_c : std_logic_vector(bw_input1-1 downto 0) := (others=> '0');
  signal lut_input2_dout_c : std_logic_vector(bw_input2-1 downto 0) := (others=> '0');

  signal input_dav : std_logic := '0';
  signal cmddev    : std_logic_vector(15 downto 0) := (others=> '0');
  signal nextcmd   : std_logic := '1';
  signal cack      : std_logic := 'H';
  signal cack_reg  : std_logic := 'H';

  -- Checker bit
  signal checker  : std_logic := '0';

begin

  input_clk_simulation_i : if in_simulation generate
    process
      constant clk_period_by_2 : time := 1.666 ns;
      begin
      while 1=1 loop
        clk_in_buf <= '0';
        wait for clk_period_by_2;
        clk_in_buf <= '1';
        wait for clk_period_by_2;
      end loop;
    end process;
  end generate input_clk_simulation_i;
  input_clk_synthesize_i : if in_synthesis generate
    ibufg_i : IBUFGDS
    port map (
               I => CLK_IN_P,
               IB => CLK_IN_N,
               O => clk_in_buf
             );
  end generate input_clk_synthesize_i;

  ClockManager_i : clockManager
  port map(
            CLK_IN300 => clk_in_buf,
            CLK_OUT40 => sysclk,
            CLK_OUT10 => sysclkQuarter,
            CLK_OUT80 => sysclkDouble,
            CLK_OUT160 => sysclkQuad
          );

  J36_USER_SMA_GPIO_P <= sysclk;

  i_ila : ila
  port map(
    clk => sysclkQuad,   -- to use the fastest clock here
    probe0 => trig0,
    probe1 => data
  );
  trig0(63 downto 48) <= cmddev;
  trig0(34) <= dl_jtag_tms;
  trig0(33) <= dl_jtag_tdi;
  trig0(32) <= dl_jtag_tdo(2);
  trig0(31 downto 16) <= vme_data_in;
  trig0(15 downto 0) <= vme_data_out;
  data(81 downto 64) <= diagout;
  data(63 downto 48) <= vme_data_in;
  data(47 downto 32) <= cmddev;
  data(19) <= dl_jtag_tck(2);
  data(18) <= dl_jtag_tms;
  data(17) <= dl_jtag_tdi;
  data(16) <= dl_jtag_tdo(2);
  data(15 downto 0) <= vme_data_out;

  -- Input LUTs
  lut_input1_i: lut_input1
  port map(
            clka=> sysclk,
            addra=> std_logic_vector(lut_input_addr1_s),
            douta=> lut_input1_dout_c
          );
  lut_input2_i: lut_input2
  port map(
            clka=> sysclk,
            addra=> std_logic_vector(lut_input_addr2_s),
            douta=> lut_input2_dout_c
          );



  -- Test CFEBJTAG functionality
  -- cfebjtag is used to talk to DCFEBs through JTAG, but we don't have CFEBs
  -- communication now, so let's test the the code is giving proper behavior

  -- Process to generate counter and initialization
  startGenerator_i: process (sysclk) is
  begin
    if sysclk'event and sysclk='1' then
      startCounter <= startCounter + 1;
      -- Set the intime to 1 only after 7 clk cycles
      if startCounter = 0 then
        rst_global <= '1';
      elsif startCounter = 1 then
        rst_global <= '0';
        init_done <= '0';
      elsif startCounter = 6 then
        dcfeb_initjtag <= '1';
      elsif startCounter = 7 then
        dcfeb_initjtag <= '0';
        init_done <= '1';
      end if;
    end if;
  end process;

  -- Process to read input from LUTs and pass to firmware
  inputGenerator_i: process (sysclk) is
    variable init_input1: unsigned(bw_fifo-3 downto 0):= (others => '0');
    variable init_input2: unsigned(bw_fifo-3 downto 0):= (others => '1');
  begin
    if sysclk'event and sysclk='1' then
      if init_done = '1' then
        if waitCounter = 0  then
          if cack = '1' then
            inputCounter <= inputCounter + 1;
            waitCounter <= "100000000";
            -- Initalize lut_input_addr_s
            if inputCounter = 0 then
              lut_input_addr1_s <= to_unsigned(0,bw_addr);
              lut_input_addr2_s <= to_unsigned(0,bw_addr);
              cmddev <= std_logic_vector(init_input1);
              input_dav <= '0';
            else
              lut_input_addr1_s <= lut_input_addr1_s + 1;
              lut_input_addr2_s <= lut_input_addr2_s + 1;
              -- The output is PRNS { rnd |= 1; rnd ^= (rnd << (i % 11 + 1)); }
              cmddev <= lut_input1_dout_c;
              vme_data_in <= lut_input2_dout_c;
              input_dav <= '1';
            end if;
          else
            cmddev <= std_logic_vector(init_input1);
            input_dav <= '0';
          end if;
        else
          cmddev <= std_logic_vector(init_input1);
          input_dav <= '0';
          waitCounter <= waitCounter - 1;
        end if;
      else
        inputCounter <= to_unsigned(0,bw_count);
        input_dav <= '0';
      end if;
    end if;
  end process;


  --Firmware process
  firmware_i: entity work.Firmware
  port map(
    -- Clock
    CLK160         => sysclkQuad,
    CLK80          => sysclkDouble,
    CLK40          => sysclk,
    CLK10          => sysclkQuarter,
    RST            => rst_global,
    VME_DATA_IN    => vme_data_in,
    VME_DATA_OUT   => vme_data_out,
    DIAGOUT        => diagout,
    DL_JTAG_TCK    => dl_jtag_tck,
    DL_JTAG_TMS    => dl_jtag_tms,
    DL_JTAG_TDI    => dl_jtag_tdi,
    DL_JTAG_TDO    => dl_jtag_tdo,
    DCFEB_INITJTAG => dcfeb_initjtag,
    CMDDEV         => cmddev,
    CACK           => cack
    );
    
  --add DCFEB
  dcfeb_i: entity work.dcfeb_v6
  port map (
    clk             => '0',
    dcfebclk        => '0',
    rst             => '0',
    l1a             => '0',
    l1a_match       => '0',
    tx_ack          => '0',
    nwords_dummy    => x"0000",
    dcfeb_dv        => open,
    dcfeb_data      => open,
    adc_mask        => open,
    dcfeb_fsel      => open,
    dcfeb_jtag_ir   => open,
    trst            => dcfeb_initjtag,
    tck             => dl_jtag_tck(2),
    tms             => dl_jtag_tms,
    tdi             => dl_jtag_tdi,
    tdo             => dl_jtag_tdo(2),
    rtn_shft_en     => open
  );

end Behavioral;
