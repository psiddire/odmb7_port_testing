library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.odmb_consts.all;

entity Firmware_tb is
  generic (
    NCFEB       : integer range 1 to 7 := 7
  );
  PORT ( 
    -- 300 MHz clk_in
    CLK_IN_P : in std_logic;
    CLK_IN_N : in std_logic;
    -- 40 MHz clk out
    J36_USER_SMA_GPIO_P : out std_logic;

    -- IBERT test pins
    MGTREFCLK0_227_P : in std_logic;
    MGTREFCLK0_227_N : in std_logic;
    MGTREFCLK1_227_P : in std_logic;
    MGTREFCLK1_227_N : in std_logic;

    GTH_TXN_O : out std_logic_vector(15 downto 0); -- simply things for now
    GTH_TXP_O : out std_logic_vector(15 downto 0); -- simply things for now
    GTH_RXN_I : in std_logic_vector(15 downto 0);  -- simply things for now
    GTH_RXP_I : in std_logic_vector(15 downto 0);  -- simply things for now

    SEL_SI570_CLK_O : out std_logic
  );      
end Firmware_tb;

architecture Behavioral of Firmware_tb is
  component clockManager is
  port (
    clk_in300  : in std_logic := '0';
    clk_out40  : out std_logic := '0';
    clk_out20  : out std_logic := '0';
    clk_out10  : out std_logic := '0';
    clk_out80  : out std_logic := '0';
    clk_out160 : out std_logic := '0'
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
      CLK          : in std_logic;
      DCFEBCLK     : in std_logic;
      RST          : in std_logic;
      L1A          : in std_logic;
      L1A_MATCH    : in std_logic;
      TX_ACK       : in std_logic;
      NWORDS_DUMMY : in std_logic_vector(15 downto 0);
      DCFEB_DV      : out std_logic;
      DCFEB_DATA    : out std_logic_vector(15 downto 0);
      ADC_MASK      : out std_logic_vector(11 downto 0);
      DCFEB_FSEL    : out std_logic_vector(63 downto 0);
      DCFEB_JTAG_IR : out std_logic_vector(9 downto 0);
      TRST          : in  std_logic;
      TCK           : in  std_logic;
      TMS           : in  std_logic;
      TDI           : in  std_logic;
      RTN_SHFT_EN   : out std_logic;
      TDO           : out std_logic;
      DONE          : out std_logic;
      INJPLS        : in std_logic;
      EXTPLS        : in std_logic;
      BC0           : in std_logic;
      RESYNC        : in std_logic
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
  constant bw_addr_entries : integer := 16;
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
  signal sysclkHalf : std_logic := '0'; 
  signal sysclkQuarter : std_logic := '0'; 
  signal sysclkDouble : std_logic := '0';
  signal sysclkQuad : std_logic := '0';
  signal init_done: std_logic := '0';
  signal sysclk_p : std_logic := '0';
  signal sysclk_n : std_logic := '1';
  -- Constants
  constant bw_output : integer := 20;
  constant bw_fifo   : integer := 18;
  constant bw_count  : integer := 16;
  constant bw_wait   : integer := 10;
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
  -- signal vme_gap     : std_logic := '0';
  signal vme_ga      : std_logic_vector(5 downto 0) := (others => '0');
  signal vme_addr    : std_logic_vector(23 downto 1) := (others => '0');
  signal vme_am      : std_logic_vector(5 downto 0) := (others => '0');
  signal vme_as      : std_logic := '0';
  signal vme_ds      : std_logic_vector(1 downto 0) := (others => '0');
  signal vme_lword   : std_logic := '0';
  signal vme_write_b : std_logic := '0';
  signal vme_berr    : std_logic := '0';
  signal vme_iack    : std_logic := '0';
  signal vme_sysrst  : std_logic := '0';
  signal vme_sysfail : std_logic := '0';
  signal vme_clk_b   : std_logic := '0';
  signal vme_oe_b    : std_logic := '0';
  signal kus_vme_oe_b : std_logic := '0';
  signal vme_dir_b   : std_logic := '0';
  signal vme_data_io_in   : std_logic_vector(15 downto 0) := (others => '0');
  signal vme_data_io_out  : std_logic_vector (15 downto 0) := (others => '0');
  signal vme_data_io_in_buf   : std_logic_vector(15 downto 0) := (others => '0');
  signal vme_data_io_out_buf  : std_logic_vector (15 downto 0) := (others => '0');
  signal vme_data_io      : std_logic_vector(15 downto 0) := (others => '0'); 
  signal vme_dtack   : std_logic := '0';

  -- DCFEB signals (ODMB <-> (xD)CFEB)
  signal dl_jtag_tck    : std_logic_vector (NCFEB downto 1)  := (others => '0');
  signal dl_jtag_tms    : std_logic := '0';
  signal dl_jtag_tdi    : std_logic := '0';
  signal dl_jtag_tdo    : std_logic_vector (NCFEB downto 1)  := (others => '0');
  signal dcfeb_initjtag : std_logic := '0';
  signal dcfeb_tck_p    : std_logic_vector (NCFEB downto 1)  := (others => '0');
  signal dcfeb_tck_n    : std_logic_vector (NCFEB downto 1)  := (others => '0');
  signal dcfeb_tms_p    : std_logic := '0';
  signal dcfeb_tms_n    : std_logic := '0';
  signal dcfeb_tdi_p    : std_logic := '0';
  signal dcfeb_tdi_n    : std_logic := '0';
  signal dcfeb_tdo_p    : std_logic_vector (NCFEB downto 1)  := (others => '0');
  signal dcfeb_tdo_n    : std_logic_vector (NCFEB downto 1)  := (others => '0');
  signal injpls         : std_logic := '0';
  signal injpls_p       : std_logic := '0';
  signal injpls_n       : std_logic := '0';
  signal extpls         : std_logic := '0'; 
  signal extpls_p       : std_logic := '0';
  signal extpls_n       : std_logic := '0';
  signal dcfeb_resync   : std_logic := '0';
  signal resync_p       : std_logic := '0';
  signal resync_n       : std_logic := '0';
  signal dcfeb_bc0      : std_logic := '0';
  signal bc0_p          : std_logic := '0';
  signal bc0_n          : std_logic := '0';
  signal dcfeb_l1a      : std_logic := '0';
  signal l1a_p          : std_logic := '0';
  signal l1a_n          : std_logic := '0';
  signal dcfeb_l1a_match : std_logic_vector(NCFEB downto 1) := (others => '0');
  signal l1a_match_p     : std_logic_vector(NCFEB downto 1) := (others => '0');
  signal l1a_match_n     : std_logic_vector(NCFEB downto 1) := (others => '0');

  -- signal dcfeb_tdo_t    : std_logic_vector (NCFEB downto 1)  := (others => '0');

  signal dcfeb_done       : std_logic_vector (NCFEB downto 1) := (others => '0');

  signal lvmb_pon     : std_logic_vector(7 downto 0);
  signal pon_load     : std_logic;
  signal pon_oe_B     : std_logic;
  signal r_lvmb_PON   : std_logic_vector(7 downto 0);
  signal lvmb_csb     : std_logic_vector(6 downto 0);
  signal lvmb_sclk    : std_logic;
  signal lvmb_sdin    : std_logic;
  signal lvmb_sdout_p : std_logic;
  signal lvmb_sdout_n : std_logic;

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

  signal daq_rx_p, daq_rx_n : std_logic_vector(10 downto 0) := (others => '0');
  signal b04_rx_p, b04_rx_n : std_logic_vector(4 downto 2) := (others => '0');
  signal daq_tx_p, daq_tx_n : std_logic_vector(4 downto 1) := (others => '0');
  signal bck_prs_p, bck_prs_n : std_logic := '0';
  signal spy_tx_p, spy_tx_n : std_logic := '0';
  signal daq_spy_rx_p, daq_spy_rx_n : std_logic := '0';

  signal rx12_sda, rx12_scl : std_logic := '0';
  signal rx12_i2c_ena, rx12_cs_b, rx12_rst_b : std_logic := '0';
  signal rx12_int_b, rx12_present_b : std_logic := '0';
  signal tx12_sda, tx12_scl : std_logic := '0';
  signal tx12_i2c_ena, tx12_cs_b, tx12_rst_b : std_logic := '0';
  signal tx12_int_b, tx12_present_b : std_logic := '0';
  signal b04_sda, b04_scl : std_logic := '0';
  signal b04_i2c_ena, b04_cs_b, b04_rst_b : std_logic := '0';
  signal b04_int_b, b04_present_b : std_logic := '0';
  signal spy_i2c_ena, spy_tdis : std_logic := '0';
  signal spy_sda, spy_scl : std_logic := '0';
  signal spy_sd : std_logic := '0';

  -- Dummy signals
  signal dummy_clk_p : std_logic := '1';
  signal dummy_clk_n : std_logic := '0';

  -- signal GTH_TXN_O : std_logic_vector(15 downto 0); -- simplify things for now
  -- signal GTH_TXP_O : std_logic_vector(15 downto 0); -- simplify things for now
  -- signal GTH_RXN_I : std_logic_vector(15 downto 0); -- simplify things for now
  -- signal GTH_RXP_I : std_logic_vector(15 downto 0); -- simplify things for now

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
  input_clk_synthesize_i : if in_kcu105 generate
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
            CLK_OUT20 => sysclkHalf,
            CLK_OUT10 => sysclkQuarter,
            CLK_OUT80 => sysclkDouble,
            CLK_OUT160 => sysclkQuad
          );

  J36_USER_SMA_GPIO_P <= sysclk;

  sysclk_p <= sysclk;
  sysclk_n <= not sysclk;
  
  i_ila : ila
  port map(
    clk => sysclk,   -- everything is clocked on 40 MHz or slower so to maximize useful buffer size use 40 MHz
    probe0 => trig0,
    probe1 => data
  );
  trig0(47 downto 32) <= vme_data_io_out;
  trig0(31 downto 16) <= vme_data_io_in;
  trig0(15 downto 0) <= cmddev;
  --
  data(79 downto 64) <= vme_data_io_out;
  data(63 downto 48) <= vme_data_io_in;
  data(47 downto 32) <= cmddev;
  data(21) <= dl_jtag_tck(2);
  data(20) <= dl_jtag_tms;
  data(19) <= dl_jtag_tdi;
  data(18) <= dl_jtag_tdo(2);
  data(17 downto 0) <= diagout;

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
            waitCounter <= "1000000000";
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
  
  -- Generate VME acknowledge
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

  --aVME signal management
  rstn <= not rst_global;
  vc_cmd <= '1' when (cmddev(15 downto 12) = x"1" or cmddev(15 downto 12) = x"4" or cmddev(15 downto 12) = x"3") else '0';
  vc_addr <= x"A8" & cmddev(15 downto 1);
  vc_rd <=  '1' when vme_data_in = x"2EAD" else '0';

  -- Manage ODMB<->VME<->VCC signals-------------------------------------------------------------------
  -- in simulation/real ODMB, use IOBUF
  vcc_data_simulation_i : if not in_kcu105 generate
    VCC_GEN_15 : for I in 0 to 15 generate
    begin
      VME_BUF : IOBUF port map(O => vme_data_io_out_buf(I), IO => vme_data_io(I), I => vme_data_io_in_buf(I), T => vme_oe_b); 
    end generate VCC_GEN_15;
  end generate vcc_data_simulation_i;
  -- on KCU use the separated signals
  vcc_data_kcu_i : if in_kcu105 generate
    vme_data_io_in <= vme_data_io_in_buf;
    vme_data_io_out_buf <= vme_data_io_out;
  end generate vcc_data_kcu_i;

  -- DCFEB simulation
  -- Manage ODMB<->PPIB<->DCFEB signals----------------------------------------------------------------
  -- in simulation/real ODMB, use I/OBUFDS
  cfebjtag_conn_simulation_i : if not in_kcu105 generate
    IB_DCFEB_TMS: IBUFDS port map (O => dl_jtag_tms, I => dcfeb_tms_p, IB => dcfeb_tms_n);
    IB_DCFEB_TDI: IBUFDS port map (O => dl_jtag_tdi, I => dcfeb_tdi_p, IB => dcfeb_tdi_n);
    IB_DCFEB_INJPLS: IBUFDS port map (O => injpls, I => injpls_p, IB => injpls_n);
    IB_DCFEB_EXTPLS: IBUFDS port map (O => extpls, I => extpls_p, IB => extpls_n);
    IB_DCFEB_RESYNC: IBUFDS port map (O => dcfeb_resync, I => resync_p, IB => resync_n);
    IB_DCFEB_BC0: IBUFDS port map (O => dcfeb_bc0, I => bc0_p, IB => bc0_n);
    IB_DCFEB_L1A: IBUFDS port map (O => dcfeb_l1a, I => l1a_p, IB => l1a_n);
    GEN_DCFEB_7 : for I in 1 to NCFEB generate
    begin
      IB_DCFEB_TCK: IBUFDS port map (O => dl_jtag_tck(I), I => dcfeb_tck_p(I), IB => dcfeb_tck_n(I));
      OB_DCFEB_TDO: OBUFDS port map (I => dl_jtag_tdo(I), O => dcfeb_tdo_p(I), OB => dcfeb_tdo_n(I));
      IB_DCFEB_L1A_MATCH: IBUFDS port map (O => dcfeb_l1a_match(I), I => l1a_match_p(I), IB => l1a_match_n(I));
      -- OB_DCFEB_TDO: OBUFTDS port map (I => dl_jtag_tdo(I), O => dcfeb_tdo_p(I), OB => dcfeb_tdo_n(I), T => dcfeb_tdo_t(I));
      -- dcfeb_tdo_t(I) <= '0' when dl_jtag_tdo(I) = '1' or dl_jtag_tdo(I) = '0' else '1';
    end generate GEN_DCFEB_7;
  end generate cfebjtag_conn_simulation_i;
  -- on KCU use the P lines as signals
  cfebjtag_conn_kcu_i : if in_kcu105 generate
    dl_jtag_tms <= dcfeb_tms_p;
    dl_jtag_tdi <= dcfeb_tdi_p;
    dl_jtag_tck <= dcfeb_tck_p;
    dcfeb_tdo_p <= dl_jtag_tdo;
    dcfeb_tdo_n <= (others => '0');
    injpls <= injpls_p;
    extpls <= extpls_p;
    dcfeb_resync <= resync_p;
    dcfeb_bc0 <= bc0_p;
    dcfeb_l1a <= l1a_p;
    dcfeb_l1a_match <= l1a_match_p;
  end generate cfebjtag_conn_kcu_i;
  

  -- IBERT ports re-mapping
  DAQ_RX_P     <= GTH_RXP_I(10 downto 0);
  DAQ_RX_N     <= GTH_RXN_I(10 downto 0);
  DAQ_SPY_RX_P <= GTH_RXP_I(11);
  DAQ_SPY_RX_N <= GTH_RXN_I(11);
  BCK_PRS_P    <= GTH_RXP_I(12);
  BCK_PRS_N    <= GTH_RXN_I(12);
  B04_RX_P     <= GTH_RXP_I(15 downto 13);
  B04_RX_N     <= GTH_RXN_I(15 downto 13);

  GTH_TXP_O(15 downto 12) <= DAQ_TX_P;
  GTH_TXN_O(15 downto 12) <= DAQ_TX_N;
  GTH_TXP_O(11)           <= SPY_TX_P;
  GTH_TXN_O(11)           <= SPY_TX_N;


  -- ODMB Firmware module
  odmb_i: entity work.ODMB7_UCSB_DEV
  port map(
    -- Clock
    TB_CLK160       => sysclkQuad,
    TB_CLK80        => sysclkDouble,
    TB_CLK40        => sysclk,
    TB_CLK20        => sysclkHalf,
    TB_CLK10        => sysclkQuarter,
    CMS_CLK_FPGA_P  => sysclk_p, -- system clock: 40.07897 MHz
    CMS_CLK_FPGA_N  => sysclk_n, -- system clock: 40.07897 MHz
    GP_CLK_6_P      => dummy_clk_p, -- system clock: ? MHz
    GP_CLK_6_N      => dummy_clk_n, -- system clock: ? MHz
    GP_CLK_7_P      => dummy_clk_p, -- system clock: ? MHz, pretend 80
    GP_CLK_7_N      => dummy_clk_n, -- system clock: ? MHz, pretend 80
    REF_CLK_1_P     => dummy_clk_p, -- optical TX/RX refclk, 160 MHz
    REF_CLK_1_N     => dummy_clk_n, -- optical TX/RX refclk, 160 MHz
    REF_CLK_2_P     => dummy_clk_p, -- optical TX/RX refclk, 160 MHz
    REF_CLK_2_N     => dummy_clk_n, -- optical TX/RX refclk, 160 MHz
    REF_CLK_3_P     => MGTREFCLK0_227_P, -- optical TX/RX refclk, 156.25 MHz
    REF_CLK_3_N     => MGTREFCLK0_227_N, -- optical TX/RX refclk, 156.25 MHz
    REF_CLK_4_P     => dummy_clk_p, -- optical TX/RX refclk, 160 MHz
    REF_CLK_4_N     => dummy_clk_n, -- optical TX/RX refclk, 160 MHz
    REF_CLK_5_P     => dummy_clk_p, -- optical TX/RX refclk, 160 MHz
    REF_CLK_5_N     => dummy_clk_n, -- optical TX/RX refclk, 160 MHz
    CLK_125_REF_P   => MGTREFCLK1_227_P, -- place holder
    CLK_125_REF_N   => MGTREFCLK1_227_N, -- place holder

    -- RST          => rst_global,
    VME_DATA        => vme_data_io,
    VME_GAP_B       => vme_ga(5),
    VME_GA_B        => vme_ga(4 downto 0),
    VME_ADDR        => vme_addr,
    VME_AM          => vme_am,
    VME_AS_B        => vme_as,
    VME_DS_B        => vme_ds,
    VME_LWORD_B     => vme_lword,
    VME_WRITE_B     => vme_write_b,
    VME_IACK_B      => vme_iack,
    VME_BERR_B      => vme_berr,
    VME_SYSRST_B    => vme_sysrst,
    VME_SYSFAIL_B   => vme_sysfail,
    VME_DTACK_KUS_B => vme_dtack,
    VME_CLK_B       => vme_clk_b,
    KUS_VME_OE_B    => kus_vme_oe_b,
    KUS_VME_DIR_B   => vme_dir_b,
    -- DIAGOUT      => diagout,
    DCFEB_TCK_P     => dcfeb_tck_p,
    DCFEB_TCK_N     => dcfeb_tck_n,
    DCFEB_TMS_P     => dcfeb_tms_p,
    DCFEB_TMS_N     => dcfeb_tms_n,
    DCFEB_TDI_P     => dcfeb_tdi_p,
    DCFEB_TDI_N     => dcfeb_tdi_n,
    DCFEB_TDO_P     => dcfeb_tdo_p,
    DCFEB_TDO_N     => dcfeb_tdo_n,
    DCFEB_DONE      => dcfeb_done,
    RESYNC_P        => resync_p,
    RESYNC_N        => resync_n,
    BC0_P           => bc0_p,
    BC0_N           => bc0_n,
    INJPLS_P        => injpls_p,
    INJPLS_N        => injpls_n,
    EXTPLS_P        => extpls_p,
    EXTPLS_N        => extpls_n,
    L1A_P           => l1a_p,
    L1A_N           => l1a_n,
    L1A_MATCH_P     => l1a_match_p,
    L1A_MATCH_N     => l1a_match_n,
    LVMB_PON        => lvmb_pon,
    PON_LOAD        => pon_load,
    PON_OE_B        => pon_oe_B,
    MON_LVMB_PON    => r_lvmb_PON,
    LVMB_CSB        => lvmb_csb,
    LVMB_SCLK       => lvmb_sclk,
    LVMB_SDIN       => lvmb_sdin,
    LVMB_SDOUT_P    => lvmb_sdout_p,
    LVMB_SDOUT_N    => lvmb_sdout_n,
    DAQ_RX_P        => DAQ_RX_P,
    DAQ_RX_N        => DAQ_RX_N,
    DAQ_SPY_RX_P    => DAQ_SPY_RX_P,
    DAQ_SPY_RX_N    => DAQ_SPY_RX_N,
    DAQ_SPY_SEL     => SEL_SI570_CLK_O,
    B04_RX_P        => B04_RX_P,
    B04_RX_N        => B04_RX_N,
    BCK_PRS_P       => BCK_PRS_P,
    BCK_PRS_N       => BCK_PRS_N,
    SPY_TX_P        => SPY_TX_P,
    SPY_TX_N        => SPY_TX_N,
    DAQ_TX_P        => DAQ_TX_P,
    DAQ_TX_N        => DAQ_TX_N,
    RX12_I2C_ENA    => RX12_I2C_ENA,
    RX12_SDA        => RX12_SDA,
    RX12_SCL        => RX12_SCL,
    RX12_CS_B       => RX12_CS_B,
    RX12_RST_B      => RX12_RST_B,
    RX12_INT_B      => RX12_INT_B,
    RX12_PRESENT_B  => RX12_PRESENT_B,
    TX12_I2C_ENA    => TX12_I2C_ENA,
    TX12_SDA        => TX12_SDA,
    TX12_SCL        => TX12_SCL,
    TX12_CS_B       => TX12_CS_B,
    TX12_RST_B      => TX12_RST_B,
    TX12_INT_B      => TX12_INT_B,
    TX12_PRESENT_B  => TX12_PRESENT_B,
    B04_I2C_ENA     => B04_I2C_ENA,
    B04_SDA         => B04_SDA,
    B04_SCL         => B04_SCL,
    B04_CS_B        => B04_CS_B,
    B04_RST_B       => B04_RST_B,
    B04_INT_B       => B04_INT_B,
    B04_PRESENT_B   => B04_PRESENT_B,
    SPY_I2C_ENA     => SPY_I2C_ENA,
    SPY_SDA         => SPY_SDA,
    SPY_SCL         => SPY_SCL,
    SPY_SD          => SPY_SD,
    SPY_TDIS        => SPY_TDIS
    --KCU only signals
    -- ,
    -- KCU_GTH_TXN_O   => GTH_TXN_O,
    -- KCU_GTH_TXP_O   => GTH_TXP_O,
    -- KCU_GTH_RXN_I   => GTH_RXN_I,
    -- KCU_GTH_RXP_I   => GTH_RXP_I,
    -- VME_DATA_IN     => vme_data_io_in,       --unused/open in real ODMB
    -- VME_DATA_OUT    => vme_data_io_out       --unused/open in real ODMB
    );
   
  -- DCFEB simulation
  dcfeb_i: dcfeb_v6
  port map (
    CLK             => sysclk,  
    DCFEBCLK        => sysclkQuad,
    RST             => rst_global,
    L1A             => dcfeb_l1a,
    L1A_MATCH       => dcfeb_l1a_match(2),
    TX_ACK          => '0',
    NWORDS_DUMMY    => x"0000",
    DCFEB_DV        => open,
    DCFEB_DATA      => open,
    ADC_MASK        => open,
    DCFEB_FSEL      => open,
    DCFEB_JTAG_IR   => open,
    TRST            => dcfeb_initjtag,
    TCK             => dl_jtag_tck(2),  -- between ODMB and DCFEB (through PPIB)
    TMS             => dl_jtag_tms,     -- between ODMB and DCFEB (through PPIB)
    TDI             => dl_jtag_tdi,     -- between ODMB and DCFEB (through PPIB)
    TDO             => dl_jtag_tdo(2),  -- between ODMB and DCFEB (through PPIB)
    RTN_SHFT_EN     => open,
    DONE            => dcfeb_done(2),
    INJPLS          => injpls,
    EXTPLS          => extpls,
    BC0             => dcfeb_bc0,
    RESYNC          => dcfeb_resync
  );
  
  -- VME simulation
  vme_i : vme_master
  port map (
    CLK            => sysclk,           -- VME controller
    RSTN           => rstn,             -- VME controller
    SW_RESET       => rst_global,       -- VME controller
    VME_CMD        => vc_cmd,           -- VME controller
    VME_CMD_RD     => vc_cmd_rd,        -- VME controller
    VME_WR         => vc_cmd,           -- VME controller
    VME_ADDR       => vc_addr,          -- VME controller
    VME_WR_DATA    => vme_data_in,      -- VME controller
    VME_RD         => vc_rd,            -- VME controller
    VME_RD_DATA    => vc_rd_data,       -- VME controller
    GA             => vme_ga,           -- between VME and ODMB
    ADDR           => vme_addr,         -- between VME and ODMB
    AM             => vme_am,           -- between VME and ODMB
    AS             => vme_as,           -- between VME and ODMB
    DS0            => vme_ds(0),        -- between VME and ODMB
    DS1            => vme_ds(1),        -- between VME and ODMB
    LWORD          => vme_lword,        -- between VME and ODMB
    WRITE_B        => vme_write_b,      -- between VME and ODMB
    IACK           => vme_iack,         -- between VME and ODMB
    BERR           => vme_berr,         -- between VME and ODMB
    SYSFAIL        => vme_sysfail,      -- between VME and ODMB
    DTACK          => vme_dtack,        -- between VME and ODMB
    OE_B           => vme_oe_b,         -- between VME and ODMB
    DATA_IN        => vme_data_io_out_buf,  -- between VME and ODMB
    DATA_OUT       => vme_data_io_in_buf    -- between VME and ODMB
  );
  

end Behavioral;
