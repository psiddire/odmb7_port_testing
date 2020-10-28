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
      RESYNC        : in std_logic;
      DIAGOUT       : out std_logic_vector(17 downto 0)
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
  
  -- VIO signals
--  ENTITY vio_input IS
--  PORT (
--  CLK : IN STD_LOGIC;
  
--  probe_out0 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0) := (others => '0');
--  probe_out1 : OUT STD_LOGIC_VECTOR(0 DOWNTO 0) := (others => '0') ;
--  probe_out2 : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) := (others => '0') ;
--  probe_out3 : OUT STD_LOGIC_VECTOR(15 DOWNTO 0) := (others => '0')
--  );
--  END vio_input;

  component vio_input is
  port (
    CLK : in std_logic;
    probe_out0 : out std_logic_vector(0 downto 0); --don't ask me why, but it complains about being std_logic
    probe_out1 : out std_logic_vector(0 downto 0); --" (vivado 2017.2)
    probe_out2 : out std_logic_vector(15 downto 0);
    probe_out3 : out std_logic_vector(15 downto 0)
  );
  end component;
  signal use_vio_input_vector : std_logic_vector(0 downto 0) := "0";
  signal vio_issue_vme_cmd_vector : std_logic_vector(0 downto 0) := "0";
  signal use_vio_input : std_logic := '0';
  signal vio_issue_vme_cmd : std_logic := '0';
  signal vio_issue_vme_cmd_q : std_logic := '0';
  signal vio_issue_vme_cmd_qq : std_logic := '0';
  signal vio_vme_addr : std_logic_vector(15 downto 0) := x"0000";
  signal vio_vme_data : std_logic_vector(15 downto 0) := x"0000";

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
  attribute mark_debug : string;
  signal vme_data_in      : std_logic_vector (15 downto 0) := (others => '0');
  signal rstn             : std_logic := '1';
  signal vc_cmd           : std_logic := '0';
  signal vc_cmd_q         : std_logic := '0';
  signal vc_cmd_rd        : std_logic := '0';
  signal vc_cmd_rd_q      : std_logic := '0';
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
  signal vme_dtack   : std_logic := 'H';

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
  signal dcfeb_diagout  : std_logic_vector(17 downto 0) := (others => '0');

  -- signal dcfeb_tdo_t    : std_logic_vector (NCFEB downto 1)  := (others => '0');

  signal dcfeb_done       : std_logic_vector (NCFEB downto 1) := (others => '0');

  signal lvmb_pon   : std_logic_vector(7 downto 0);
  signal pon_load   : std_logic;
  signal pon_oe_B   : std_logic;
  signal r_lvmb_PON : std_logic_vector(7 downto 0);
  signal lvmb_csb   : std_logic_vector(6 downto 0);
  signal lvmb_sclk  : std_logic;
  signal lvmb_sdin  : std_logic;
  signal lvmb_sdout : std_logic;

  signal dcfeb_prbs_FIBER_SEL : std_logic_vector(3 downto 0);
  signal dcfeb_prbs_EN        : std_logic;
  signal dcfeb_prbs_RST       : std_logic;
  signal dcfeb_prbs_RD_EN     : std_logic;
  signal dcfeb_rxprbserr      : std_logic;
  signal dcfeb_prbs_ERR_CNT   : std_logic_vector(15 downto 0);

  signal otmb_tx    : std_logic_vector(48 downto 0);
  signal otmb_rx    : std_logic_vector(5 downto 0);

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
  attribute mark_debug of cmddev : signal is "true";
  signal nextcmd   : std_logic := '1';
  signal cack      : std_logic := 'H';
  attribute mark_debug of cack : signal is "true";
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
    clk => sysclk,   -- everything is clocked on 40 MHz or slower so to maximize useful buffer size use 40 MHz
    probe0 => trig0,
    probe1 => data
  );
  trig0(255 downto 73) <= (others => '0');
  trig0(72 downto 55) <= diagout;
  trig0(54) <= vc_cmd;
  trig0(53 downto 50) <= std_logic_vector(lut_input_addr1_s);
  trig0(49) <= extpls;
  trig0(48) <= injpls;
  trig0(47 downto 32) <= vme_data_io_out;
  trig0(31 downto 16) <= vme_data_io_in;
  trig0(15 downto 0) <= cmddev;
  --
  data(4095 downto 101) <= (others => '0');
  data(100) <= rst_global;
  data(99) <= cack;
  data(98) <= vc_cmd;
  data(97 downto 80) <= dcfeb_diagout;
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
          
  -- Input VIO
  vio_input_i: vio_input
    port map(
              CLK => sysclk,
              PROBE_OUT0 => use_vio_input_vector,
              PROBE_OUT1 => vio_issue_vme_cmd_vector,
              PROBE_OUT2 => vio_vme_addr,
              PROBE_OUT3 => vio_vme_data
            );
  use_vio_input <= use_vio_input_vector(0);
  vio_issue_vme_cmd <= vio_issue_vme_cmd_vector(0);
            
  -- Process to generate counter and initialization
  startGenerator_i: process (sysclk) is
  begin
    if rising_edge(sysclk) then
      if (init_done = '0') then
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
    end if;
  end process;

  -- Process to read input from LUTs or VIO and give to VME 
  inputGenerator_i: process (sysclk) is
    variable init_input1: unsigned(bw_fifo-3 downto 0):= (others => '0');
    variable init_input2: unsigned(bw_fifo-3 downto 0):= (others => '1');
  begin
    if sysclk'event and sysclk='1' then
      if init_done = '1' then
        if (use_vio_input = '0') then
          --handle LUT input
          if waitCounter = 0  then
            if cack = '1' then
              inputCounter <= inputCounter + 1;
              waitCounter <= "1100000000";
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
          --handle VIO input
          if (vio_issue_vme_cmd = '1' and vio_issue_vme_cmd_q = '0') then
            --rising vio edge
            cmddev <= vio_vme_addr;
            vme_data_in <= vio_vme_data;
          elsif (vio_issue_vme_cmd_q = '1' and vio_issue_vme_cmd_qq = '0') then
            --next clock cycle, stop sending pulse
            cmddev <= std_logic_vector(init_input1);
            vme_data_in <= vme_data_in;
          else
            cmddev <= cmddev;
            vme_data_in <= vme_data_in;
          end if;
          vio_issue_vme_cmd_q <= vio_issue_vme_cmd;
          vio_issue_vme_cmd_qq <= vio_issue_vme_cmd_q;     
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
  vc_cmd <= '1' when (cmddev(15 downto 12) = x"1" or cmddev(15 downto 12) = x"4" or cmddev(15 downto 12) = x"3" or cmddev(15 downto 12) = x"6") else '0';
  vc_addr <= x"A8" & cmddev(15 downto 1);
  vc_rd <=  '1' when vme_data_in = x"2EAD" else '0';

  -- Manage ODMB<->VME<->VCC signals-------------------------------------------------------------------
  -- in simulation/real ODMB, use IOBUF
  vcc_data_simulation_i : if in_simulation generate
    VCC_GEN_15 : for I in 0 to 15 generate
    begin
      VME_BUF : IOBUF port map(O => vme_data_io_out_buf(I), IO => vme_data_io(I), I => vme_data_io_in_buf(I), T => vme_oe_b); 
    end generate VCC_GEN_15;
  end generate vcc_data_simulation_i;
  -- on KCU use the separated signals
  vcc_data_kcu_i : if in_synthesis generate
    vme_data_io_in <= vme_data_io_in_buf;
    vme_data_io_out_buf <= vme_data_io_out;
  end generate vcc_data_kcu_i;

  -- DCFEB simulation
  -- Manage ODMB<->PPIB<->DCFEB signals----------------------------------------------------------------
  -- in simulation/real ODMB, use I/OBUFDS
  cfebjtag_conn_simulation_i : if in_simulation generate
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
  cfebjtag_conn_kcu_i : if in_synthesis generate
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
  

  -- ODMB Firmware module
  odmb_i: entity work.ODMB7_UCSB_DEV
  port map(
    -- Clock
    CLK160         => sysclkQuad,
    CLK80          => sysclkDouble,
    CLK40          => sysclk,
    CLK10          => sysclkQuarter,
    RST            => rst_global,
    VME_DATA       => vme_data_io,
    VME_GAP_B      => vme_ga(5),
    VME_GA_B       => vme_ga(4 downto 0),
    VME_ADDR       => vme_addr,
    VME_AM         => vme_am,
    VME_AS_B       => vme_as,
    VME_DS_B       => vme_ds,
    VME_LWORD_B    => vme_lword,
    VME_WRITE_B    => vme_write_b,
    VME_IACK_B     => vme_iack,
    VME_BERR_B     => vme_berr,
    VME_SYSRST_B   => vme_sysrst,
    VME_SYSFAIL_B  => vme_sysfail,
    VME_DTACK_KUS_B => vme_dtack,
    VME_CLK_B       => vme_clk_b,
    KUS_VME_OE_B    => kus_vme_oe_b,
    KUS_VME_DIR_B   => vme_dir_b,
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
    PPIB_OUT_EN_B   => open,
    LVMB_PON        => lvmb_pon,
    PON_LOAD        => pon_load,
    PON_OE_B        => pon_oe_B,
    R_LVMB_PON      => r_lvmb_PON,
    LVMB_CSB        => lvmb_csb,
    LVMB_SCLK       => lvmb_sclk,
    LVMB_SDIN       => lvmb_sdin,
    LVMB_SDOUT      => lvmb_sdout,
    DCFEB_PRBS_FIBER_SEL => dcfeb_prbs_FIBER_SEL,
    DCFEB_PRBS_EN        => dcfeb_prbs_EN,
    DCFEB_PRBS_RST       => dcfeb_prbs_RST,
    DCFEB_PRBS_RD_EN     => dcfeb_prbs_RD_EN,
    DCFEB_RXPRBSERR      => dcfeb_rxprbserr,
    DCFEB_PRBS_ERR_CNT   => dcfeb_prbs_ERR_CNT,
    OTMB_TX         => otmb_tx,
    OTMB_RX         => otmb_rx,
    --KCU only signals
    DIAGOUT        => diagout,
    VME_DATA_IN    => vme_data_io_in,        --unused/open in real ODMB
    VME_DATA_OUT   => vme_data_io_out       --unused/open in real ODMB
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
    RESYNC          => dcfeb_resync,
    DIAGOUT         => dcfeb_diagout
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
