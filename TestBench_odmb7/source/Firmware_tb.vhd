library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.Firmware_pkg.all;

entity Firmware_tb is
  generic (
    NCFEB       : integer range 1 to 7 := 7
  );
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
  component dcfeb_v6 is
  port (
      clk          : in std_logic;
      dcfebclk     : in std_logic;
      rst          : in std_logic;
      l1a          : in std_logic;
      l1a_match    : in std_logic;
      tx_ack       : in std_logic;
      nwords_dummy : in std_logic_vector(15 downto 0);
  
      dcfeb_dv      : out std_logic;
      dcfeb_data    : out std_logic_vector(15 downto 0);
      adc_mask      : out std_logic_vector(11 downto 0);
      dcfeb_fsel    : out std_logic_vector(32 downto 0);
      dcfeb_jtag_ir : out std_logic_vector(9 downto 0);
      trst          : in  std_logic;
      tck           : in  std_logic;
      tms           : in  std_logic;
      tdi           : in  std_logic;
      rtn_shft_en   : out std_logic;
      tdo           : out std_logic;
      done          : out std_logic
   );
   end component;
   component vme_master is
   port (
       CLK         : in  std_logic;
       RSTN        : in  std_logic;
       SW_RESET    : in  std_logic;
       VME_CMD     : in  std_logic;
       VME_CMD_RD  : out std_logic;
       VME_ADDR    : in  std_logic_vector(23 downto 1);
       VME_WR      : in  std_logic;
       VME_WR_DATA : in  std_logic_vector(15 downto 0);
       VME_RD      : in  std_logic;
       VME_RD_DATA : out std_logic_vector(15 downto 0);
       GA          : out std_logic_vector(5 downto 0);
       ADDR        : out std_logic_vector(23 downto 1);
       AM          : out std_logic_vector(5 downto 0);
       AS          : out std_logic;
       DS0         : out std_logic;
       DS1         : out std_logic;
       LWORD       : out std_logic;
       WRITE_B     : out std_logic;
       IACK        : out std_logic;
       BERR        : out std_logic;
       SYSFAIL     : out std_logic;
       DTACK       : in  std_logic;
       DATA_IN     : in  std_logic_vector(15 downto 0);
       DATA_OUT    : out std_logic_vector(15 downto 0);
       OE_B        : out std_logic
       );
   end component;

  -- LUT constents
  constant bw_addr   : integer := 4;
  constant bw_addr_entries : integer := 9;
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

  --Diagnostic
  signal diagout          : std_logic_vector (17 downto 0) := (others => '0');

  -- VME signals
  -- Simulation (PC) -> VME
  signal vme_data_in      : std_logic_vector (15 downto 0) := (others => '0');
  signal rstn             : std_logic := '1';
  signal vc_cmd           : std_logic := '0';
  signal vc_cmd_rd        : std_logic := '0';
  signal vc_addr          : std_logic_vector(23 downto 1) := (others => '0');
  signal vc_rd            : std_logic := '0';
  signal vc_rd_data       : std_logic_vector(15 downto 0) := (others => '0');
  -- VME -> ODMB
  signal vme_ga      : std_logic_vector(5 downto 0) := (others => '0');
  signal vme_addr    : std_logic_vector(23 downto 1) := (others => '0');
  signal vme_am      : std_logic_vector(5 downto 0) := (others => '0');
  signal vme_as      : std_logic := '0';
  signal vme_ds      : std_logic_vector(1 downto 0) := (others => '0');
  signal vme_lword   : std_logic := '0';
  signal vme_write_b : std_logic := '0';
  signal vme_berr    : std_logic := '0';
  signal vme_iack    : std_logic := '0';
  signal vme_sysfail : std_logic := '0';
  signal vme_oe_b    : std_logic := '0';
  signal vme_data_io_in   : std_logic_vector(15 downto 0) := (others => '0');
  signal vme_data_io_out  : std_logic_vector (15 downto 0) := (others => '0');
  signal vme_data_io_in_buf   : std_logic_vector(15 downto 0) := (others => '0');
  signal vme_data_io_out_buf  : std_logic_vector (15 downto 0) := (others => '0');
  signal vme_data_io      : std_logic_vector(15 downto 0) := (others => '0'); 
  signal vme_dtack   : std_logic := 'H';

  -- DCFEB signals (ODMB <-> (xD)CFEB)
  signal dl_jtag_tck      : std_logic_vector (NCFEB downto 1)  := (others => '0');
  signal dl_jtag_tms      : std_logic := '0';
  signal dl_jtag_tdi      : std_logic := '0';
  signal dl_jtag_tdo      : std_logic_vector (NCFEB downto 1)  := (others => '0');
  signal dcfeb_initjtag   : std_logic := '0';
  signal dcfeb_done       : std_logic_vector (NCFEB downto 1) := (others => '0');

  -- ILA
  signal trig0 : std_logic_vector(255 downto 0) := (others=> '0');
  signal data  : std_logic_vector(4095 downto 0) := (others=> '0');
  -- LUT input
  signal lut_input_addr1_s : unsigned(bw_addr-1 downto 0) := (others=> '0');
  signal lut_input_addr2_s : unsigned(bw_addr-1 downto 0) := (others=> '0');
  signal lut_input1_dout_c : std_logic_vector(bw_input1-1 downto 0) := (others=> '0');
  signal lut_input2_dout_c : std_logic_vector(bw_input2-1 downto 0) := (others=> '0');

  --signals for generating input to VME
  signal input_dav : std_logic := '0';
  signal cmddev    : std_logic_vector(15 downto 0) := (others=> '0');
  signal nextcmd   : std_logic := '1';
  signal cack      : std_logic := 'H';
  signal cack_reg  : std_logic := 'H';
  signal cack_i  : std_logic := '1';

  -- Checker bit
  signal checker  : std_logic := '0';

begin

  --generate clock in simulation
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
  trig0(15 downto 0) <= vme_data_io_out;
  data(81 downto 64) <= diagout;
  data(63 downto 48) <= vme_data_in;
  data(47 downto 32) <= cmddev;
  data(19) <= dl_jtag_tck(2);
  data(18) <= dl_jtag_tms;
  data(17) <= dl_jtag_tdi;
  data(16) <= dl_jtag_tdo(2);
  data(15 downto 0) <= vme_data_io_out;

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

  -- Process to read input from LUTs and give to VME 
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
              if lut_input_addr1_s = bw_addr_entries-1 then
                lut_input_addr1_s <= x"0";
                lut_input_addr2_s <= x"0";
              else 
                lut_input_addr1_s <= lut_input_addr1_s + 1;
                lut_input_addr2_s <= lut_input_addr2_s + 1;
              end if;
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
  
  --generate VME acknowledge
    i_cmd_ack : process (vc_cmd, vc_cmd_rd) is
  begin
    if vc_cmd'event and vc_cmd = '1' then
      cack_i <= '0';
    end if;
    if vc_cmd_rd'event and vc_cmd_rd = '1' then
      cack_i <= '1';
    end if;
  end process;
  cack <= cack_i;

  --VME signal management
  rstn <= not rst_global;
  vc_cmd <= '1' when (cmddev(15 downto 12) = x"1" or cmddev(15 downto 12) = x"4") else '0';
  vc_addr <= x"A8" & cmddev(15 downto 1);
  vc_rd <=  '1' when vme_data_in = x"2EAD" else '0';
  --manage the VME data lines
  --can't use IOBUF's internally except in simulation. For KCU we connect vme_data_io_in and _out directly
  --GEN_15 : for I in 0 to 15 generate
  --begin
  --    VME_DATA_BUF : IOBUF port map(O => vme_data_io_out(I), IO => vme_data_io(I), I => vme_data_io_in(I), T => vme_oe_b); 
  --end generate GEN_15;
  
  vcc_data_simulation_i : if in_simulation generate
    VCC_GEN_15 : for I in 0 to 15 generate
    begin
      VME_BUF : IOBUF port map(O => vme_data_io_out_buf(I), IO => vme_data_io(I), I => vme_data_io_in_buf(I), T => vme_oe_b); 
    end generate VCC_GEN_15;
  end generate vcc_data_simulation_i;
  vcc_data_kcu_i : if in_synthesis generate
    vme_data_io_in <= vme_data_io_in_buf;
    vme_data_io_out_buf <= vme_data_io_out;
  end generate vcc_data_kcu_i;

  --Firmware process
  odmb_i: entity work.odmb7_ucsb_dev
  port map(
    -- Clock
    CLK160         => sysclkQuad,
    CLK40          => sysclk,
    CLK10          => sysclkQuarter,
    RST            => rst_global,
    VME_DATA       => vme_data_io,
    VME_DATA_IN    => vme_data_io_in,
    VME_DATA_OUT   => vme_data_io_out,
    VME_GA         => vme_ga,
    VME_ADDR       => vme_addr,
    VME_AM         => vme_am,
    VME_AS_B       => vme_as,
    VME_DS_B       => vme_ds,
    VME_LWORD_B    => vme_lword,
    VME_WRITE_B    => vme_write_b,
    VME_IACK_B     => vme_iack,
    VME_BERR_B     => vme_berr,
    VME_SYSFAIL_B  => vme_sysfail,
    VME_DTACK_V6_B => vme_dtack,
    VME_DOE_B      => vme_oe_b,
    DIAGOUT        => diagout,
    DCFEB_TCK    => dl_jtag_tck,
    DCFEB_TMS    => dl_jtag_tms,
    DCFEB_TDI    => dl_jtag_tdi,
    DCFEB_TDO    => dl_jtag_tdo,
    DCFEB_DONE   => dcfeb_done
    );
   
  --DCFEB
  dcfeb_i: dcfeb_v6
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
    rtn_shft_en     => open,
    done            => dcfeb_done(2)
  );
  
  vme_i : vme_master
  port map (
         clk            => sysclk,          -- VME controller
         rstn           => rstn,            -- VME controller
         sw_reset       => rst_global,      -- VME controller
         vme_cmd        => vc_cmd,          -- VME controller
         vme_cmd_rd     => vc_cmd_rd,       -- VME controller
         vme_wr         => vc_cmd,          -- VME controller
         vme_addr       => vc_addr,         -- VME controller
         vme_wr_data    => vme_data_in,     -- VME controller
         vme_rd         => vc_rd,           -- VME controller
         vme_rd_data    => vc_rd_data,      -- VME controller
         ga             => vme_ga,          -- between VME and ODMB
         addr           => vme_addr,        -- between VME and ODMB
         am             => vme_am,          -- between VME and ODMB
         as             => vme_as,          -- between VME and ODMB
         ds0            => vme_ds(0),       -- between VME and ODMB
         ds1            => vme_ds(1),       -- between VME and ODMB
         lword          => vme_lword,       -- between VME and ODMB
         write_b        => vme_write_b,     -- between VME and ODMB
         iack           => vme_iack,        -- between VME and ODMB
         berr           => vme_berr,        -- between VME and ODMB
         sysfail        => vme_sysfail,     -- between VME and ODMB
         dtack          => vme_dtack,       -- between VME and ODMB
         oe_b           => vme_oe_b,        -- between VME and ODMB
         data_in        => vme_data_io_out_buf,    -- between VME and ODMB
         data_out       => vme_data_io_in_buf      -- between VME and ODMB
  );
  

end Behavioral;
