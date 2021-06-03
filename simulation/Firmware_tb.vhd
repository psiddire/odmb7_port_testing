library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

entity Firmware_tb is
  generic (
    NCFEB       : integer range 1 to 7 := 7
    );
end entity Firmware_tb;

architecture Behavioral of Firmware_tb is
  component clockManager_sim is
    port (
      CLK_IN40  : in std_logic := '0';
      CLK_OUT10  : out std_logic := '0';
      CLK_OUT80  : out std_logic := '0';
      CLK_OUT160  : out std_logic := '0';
      CLK_OUT125  : out std_logic := '0'
      );
  end component;

  component DCFEB_DS_WRAPPER is
    port (
      clk          : in std_logic;
      dcfebclk     : in std_logic;
      rst          : in std_logic;
      l1a_p        : in std_logic;
      l1a_n        : in std_logic;
      l1a_match_p  : in std_logic;
      l1a_match_n  : in std_logic;
      tx_ack       : in std_logic;
      nwords_dummy : in std_logic_vector(15 downto 0);
      dcfeb_dv      : out std_logic;
      dcfeb_data    : out std_logic_vector(15 downto 0);
      adc_mask      : out std_logic_vector(11 downto 0);
      dcfeb_fsel    : out std_logic_vector(63 downto 0);
      dcfeb_jtag_ir : out std_logic_vector(9 downto 0);
      trst          : in  std_logic;
      tck_p         : in  std_logic;
      tck_n         : in  std_logic;
      tms_p         : in  std_logic;
      tms_n         : in  std_logic;
      tdi_p         : in  std_logic;
      tdi_n         : in  std_logic;
      tdo_p         : out std_logic;
      tdo_n         : out std_logic;
      rtn_shft_en   : out std_logic;
      done          : out std_logic;
      INJPLS_P      : in std_logic;
      INJPLS_N      : in std_logic;
      EXTPLS_P      : in std_logic;
      EXTPLS_N      : in std_logic;
      BC0_P         : in std_logic;
      BC0_N         : in std_logic;
      RESYNC_P      : in std_logic;
      RESYNC_N      : in std_logic;
      DIAGOUT       : out std_logic_vector(17 downto 0)
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

  component LVMB is
    generic (
      NFEB : integer := NCFEB
      );
    port (
      RST : in std_logic;
      LVMB_SCLK     : in  std_logic;
      LVMB_SDIN     : in  std_logic;
      LVMB_SDOUT_P  : out std_logic;
      LVMB_SDOUT_N  : out std_logic;
      LVMB_CSB      : in std_Logic_vector((NFEB-1) downto 0);
      LVMB_PON      : in std_Logic_vector(NFEB downto 0);
      MON_LVMB_PON  : out std_Logic_vector(NFEB downto 0);
      PON_LOAD_B    : in std_logic;
      PON_OE        : in std_logic
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

  signal use_vio_input_vector : std_logic_vector(0 downto 0) := "0";
  signal vio_issue_vme_cmd_vector : std_logic_vector(0 downto 0) := "0";
  signal use_vio_input : std_logic := '0';
  signal vio_issue_vme_cmd : std_logic := '0';
  signal vio_issue_vme_cmd_q : std_logic := '0';
  signal vio_issue_vme_cmd_qq : std_logic := '0';
  signal vio_vme_addr : std_logic_vector(15 downto 0) := x"0000";
  signal vio_vme_data : std_logic_vector(15 downto 0) := x"0000";
  signal vio_vme_out : std_logic_vector(15 downto 0) := x"0000";
  signal vme_dtack_q : std_logic := '0';

  -- Clock signals
  signal clk_in_buf : std_logic := '0';
  signal sysclk : std_logic := '0';
  signal sysclk10 : std_logic := '0';
  signal sysclk80 : std_logic := '0';
  signal sysclk80_p : std_logic := '0';
  signal sysclk80_n : std_logic := '0';
  signal sysclk125 : std_logic := '0'; -- actually 124.444 from clockManager_sim, to be corrected with dedicated generation
  signal sysclk125_p : std_logic := '0';
  signal sysclk125_n : std_logic := '0';
  signal sysclk160 : std_logic := '0';
  signal sysclk160_p : std_logic := '0';
  signal sysclk160_n : std_logic := '0';
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
  signal vme_dir     : std_logic := '0';
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

  signal lvmb_pon     : std_logic_vector(7 downto 0);
  signal pon_load     : std_logic;
  signal pon_oe       : std_logic;
  signal r_lvmb_PON   : std_logic_vector(7 downto 0);
  signal lvmb_csb     : std_logic_vector(6 downto 0);
  signal lvmb_sclk    : std_logic;
  signal lvmb_sdin    : std_logic;
  signal lvmb_sdout_p : std_logic;
  signal lvmb_sdout_n : std_logic;

  signal dcfeb_prbs_FIBER_SEL : std_logic_vector(3 downto 0);
  signal dcfeb_prbs_EN        : std_logic;
  signal dcfeb_prbs_RST       : std_logic;
  signal dcfeb_prbs_RD_EN     : std_logic;
  signal dcfeb_rxprbserr      : std_logic;
  signal dcfeb_prbs_ERR_CNT   : std_logic_vector(15 downto 0);

  signal otmb_tx    : std_logic_vector(48 downto 0);
  signal otmb_rx    : std_logic_vector(5 downto 0);

  signal cms_clk_fpga_p : std_logic;
  signal cms_clk_fpga_n : std_logic;

  -- ILA
  signal trig0 : std_logic_vector(255 downto 0) := (others=> '0');
  signal data  : std_logic_vector(4095 downto 0) := (others=> '0');
  -- LUT input
  signal lut_input_addr1_s : unsigned(bw_addr-1 downto 0) := (others=> '0');
  signal lut_input_addr2_s : unsigned(bw_addr-1 downto 0) := (others=> '0');
  signal lut_input1_dout_c : std_logic_vector(bw_input1-1 downto 0) := (others=> '0');
  signal lut_input2_dout_c : std_logic_vector(bw_input2-1 downto 0) := (others=> '0');

  --signals for generating input to VME
  signal cmddev    : std_logic_vector(15 downto 0) := (others=> '0');
  attribute mark_debug of cmddev : signal is "true";
  signal nextcmd   : std_logic := '1';
  signal cack      : std_logic := 'H';
  attribute mark_debug of cack : signal is "true";
  signal cack_reg  : std_logic := 'H';
  signal cack_i    : std_logic := '1';

  -- Checker bit
  signal checker  : std_logic := '0';

begin

  -- generate clock in simulation
  process
    -- constant clk_period_by_2 : time := 1.666 ns;
    constant clk_period_by_2 : time := 12.5 ns;
  begin
    while 1=1 loop
      cms_clk_fpga_p <= '0';
      cms_clk_fpga_n <= '1';
      wait for clk_period_by_2;
      cms_clk_fpga_p <= '1';
      cms_clk_fpga_n <= '0';
      wait for clk_period_by_2;
    end loop;
  end process;

  ibufg_i : IBUFGDS
    port map (
      I => cms_clk_fpga_p,
      IB => cms_clk_fpga_n,
      O => sysclk --clk_in_buf
      );

  ClockManager_i : clockManager_sim
    port map(
      --CLK_IN40 => clk_in_buf,
      CLK_IN40 => sysclk,
      CLK_OUT10 => sysclk10,
      CLK_OUT80 => sysclk80,
      CLK_OUT160 => sysclk160,
      CLK_OUT125 => sysclk125
      );

  obufds_clk80 : OBUFDS
    port map (
      O => sysclk80_p,
      OB => sysclk80_n,
      I => sysclk80
      );

  obufds_clk125 : OBUFDS
    port map (
      O => sysclk125_p,
      OB => sysclk125_n,
      I => sysclk125
      );

  obufds_clk160 : OBUFDS
    port map (
      O => sysclk160_p,
      OB => sysclk160_n,
      I => sysclk160
      );

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

  --in simulation, VIO always outputs 0, even though this output is default 1
  --use_vio_input <= use_vio_input_vector(0);
  --vio_issue_vme_cmd <= vio_issue_vme_cmd_vector(0);

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
        --if (use_vio_input = '0') then
        --handle LUT input
        if waitCounter = 0  then
          if cack = '1' then
            inputCounter <= inputCounter + 1;
            --waitCounter <= "0000001000";
            waitCounter <= "1100000000";
            -- Initalize lut_input_addr_s
            if inputCounter = 0 then
              lut_input_addr1_s <= to_unsigned(0,bw_addr);
              lut_input_addr2_s <= to_unsigned(0,bw_addr);
              cmddev <= std_logic_vector(init_input1);
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
            end if;
          else
            cmddev <= std_logic_vector(init_input1);
          end if;
        else
          cmddev <= std_logic_vector(init_input1);
          waitCounter <= waitCounter - 1;
        end if;
      --else
      --  --handle VIO input
      --  if (vio_issue_vme_cmd = '1' and vio_issue_vme_cmd_q = '0') then
      --    --rising vio edge
      --    cmddev <= vio_vme_addr;
      --    vme_data_in <= vio_vme_data;
      --  elsif (vio_issue_vme_cmd_q = '1' and vio_issue_vme_cmd_qq = '0') then
      --    --next clock cycle, stop sending pulse
      --    cmddev <= std_logic_vector(init_input1);
      --    vme_data_in <= vme_data_in;
      --  else
      --    cmddev <= cmddev;
      --    vme_data_in <= vme_data_in;
      --  end if;
      --  vio_issue_vme_cmd_q <= vio_issue_vme_cmd;
      --  vio_issue_vme_cmd_qq <= vio_issue_vme_cmd_q;
      --end if;
      else
        inputCounter <= to_unsigned(0,bw_count);
      end if;
    end if;
  end process;

  -- generate vme output for vio
  --proc_vio_vme_out : process (sysclk) is
  --begin
  --if rising_edge(sysclk) then
  --  vme_dtack_q <= vme_dtack;
  --  if (vme_dtack='0' and vme_dtack_q='1') then
  --    vio_vme_out <= vme_data_io_out;
  --  end if;
  --end if;
  --end process;

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
  vc_cmd <= '1' when (cmddev(15 downto 12) = x"1" or cmddev(15 downto 12) = x"4" or cmddev(15 downto 12) = x"3" or cmddev(15 downto 12) = x"6" or cmddev(15 downto 12) = x"7" or cmddev(15 downto 12) = x"8") else '0';
  vc_addr <= x"A8" & cmddev(15 downto 1);
  vc_rd <=  '1' when vme_data_in = x"2EAD" else '0';

  -- Manage ODMB<->VME<->VCC signals-------------------------------------------------------------------
  -- in simulation/real ODMB, use IOBUF
  VCC_GEN_15 : for I in 0 to 15 generate
  begin
    VME_BUF : IOBUF port map(O => vme_data_io_out_buf(I), IO => vme_data_io(I), I => vme_data_io_in_buf(I), T => vme_oe_b);
  end generate VCC_GEN_15;

  -- ODMB Firmware module
  odmb_i: entity work.ODMB7_UCSB_DEV
    port map(
      -- Clock
      CMS_CLK_FPGA_P       => cms_clk_fpga_p,
      CMS_CLK_FPGA_N       => cms_clk_fpga_n,
      GP_CLK_6_P           => sysclk80_p,
      GP_CLK_6_N           => sysclk80_n,
      GP_CLK_7_P           => sysclk80_p,
      GP_CLK_7_N           => sysclk80_n,
      REF_CLK_1_P          => sysclk160_p,
      REF_CLK_1_N          => sysclk160_n,
      REF_CLK_2_P          => sysclk160_p,
      REF_CLK_2_N          => sysclk160_n,
      REF_CLK_3_P          => sysclk160_p,
      REF_CLK_3_N          => sysclk160_n,
      REF_CLK_4_P          => sysclk160_p,
      REF_CLK_4_N          => sysclk160_n,
      REF_CLK_5_P          => sysclk160_p,
      REF_CLK_5_N          => sysclk160_n,
      CLK_125_REF_P        => sysclk125_p,
      CLK_125_REF_N        => sysclk125_n,
      EMCCLK               => sysclk160, -- Low frequency, 133 MHz for SPI programing clock, use 160 for now...
      LF_CLK               => sysclk10, -- Low frequency, 10 kHz, use clk10 for now
      --RST                  => rst_global,
      VME_DATA             => vme_data_io,
      VME_GAP_B            => vme_ga(5),
      VME_GA_B             => vme_ga(4 downto 0),
      VME_ADDR             => vme_addr,
      VME_AM               => vme_am,
      VME_AS_B             => vme_as,
      VME_DS_B             => vme_ds,
      VME_LWORD_B          => vme_lword,
      VME_WRITE_B          => vme_write_b,
      VME_IACK_B           => vme_iack,
      VME_BERR_B           => vme_berr,
      VME_SYSRST_B         => vme_sysrst,
      VME_SYSFAIL_B        => vme_sysfail,
      VME_DTACK_KUS_B      => vme_dtack,
      VME_CLK_B            => vme_clk_b,
      KUS_VME_OE_B         => kus_vme_oe_b,
      KUS_VME_DIR          => vme_dir,
      DCFEB_TCK_P          => dcfeb_tck_p,
      DCFEB_TCK_N          => dcfeb_tck_n,
      DCFEB_TMS_P          => dcfeb_tms_p,
      DCFEB_TMS_N          => dcfeb_tms_n,
      DCFEB_TDI_P          => dcfeb_tdi_p,
      DCFEB_TDI_N          => dcfeb_tdi_n,
      DCFEB_TDO_P          => dcfeb_tdo_p,
      DCFEB_TDO_N          => dcfeb_tdo_n,
      DCFEB_DONE           => dcfeb_done,
      RESYNC_P             => resync_p,
      RESYNC_N             => resync_n,
      BC0_P                => bc0_p,
      BC0_N                => bc0_n,
      INJPLS_P             => injpls_p,
      INJPLS_N             => injpls_n,
      EXTPLS_P             => extpls_p,
      EXTPLS_N             => extpls_n,
      L1A_P                => l1a_p,
      L1A_N                => l1a_n,
      L1A_MATCH_P          => l1a_match_p,
      L1A_MATCH_N          => l1a_match_n,
      PPIB_OUT_EN_B        => open,
      KUS_DL_SEL           => open,
      ODMB_DONE            => '1',
      FPGA_SEL             => open,
      RST_CLKS_B           => open,
      CCB_CMD              => "011000",
      CCB_CMD_S            => sysclk80,
      CCB_DATA             => x"00",
      CCB_DATA_S           => '0',
      CCB_CAL              => "000",
      CCB_CRSV             => x"0",
      CCB_DRSV             => "00",
      CCB_RSVO             => "00000",
      CCB_RSVI             => open,
      CCB_BX0_B            => '1',
      CCB_BX_RST_B         => '1',
      CCB_L1A_RST_B        => '1',
      CCB_L1A_B            => '1',
      CCB_L1A_RLS          => open,
      CCB_CLKEN            => '0',
      CCB_EVCNTRES_B       => '1',
      CCB_HARDRST_B        => '0',
      CCB_SOFT_RST_B       => '1',
      LVMB_PON             => lvmb_pon,
      PON_LOAD_B           => pon_load,
      PON_OE               => pon_oe,
      MON_LVMB_PON         => r_lvmb_PON,
      LVMB_CSB             => lvmb_csb,
      LVMB_SCLK            => lvmb_sclk,
      LVMB_SDIN            => lvmb_sdin,
      LVMB_SDOUT_P         => lvmb_sdout_p,
      LVMB_SDOUT_N         => lvmb_sdout_n,
      OTMB                 => x"000000000",
      RAWLCT               => "0000000",
      OTMB_DAV             => '0',
      OTMB_FF_CLK          => '0',
      RSVTD_IN             => "00000",
      RSVTD_OUT            => open,
      LCT_RQST             => open,    --DCFEB_PRBS_FIBER_SEL => dcfeb_prbs_FIBER_SEL,
      DAQ_RX_P             => "00000000000",
      DAQ_RX_N             => "00000000000",
      DAQ_SPY_RX_P         => '0',
      DAQ_SPY_RX_N         => '0',
      B04_RX_P             => "000",
      B04_RX_N             => "000",
      BCK_PRS_P            => '0',
      BCK_PRS_N            => '0',
      SPY_TX_P             => open,
      SPY_TX_N             => open,
      DAQ_TX_P             => open,
      DAQ_TX_N             => open,
      DAQ_SPY_SEL          => open,
      RX12_I2C_ENA         => open,
      RX12_SDA             => open,
      RX12_SCL             => open,
      RX12_CS_B            => open,
      RX12_RST_B           => open,
      RX12_INT_B           => '0',
      RX12_PRESENT_B       => '0',
      TX12_I2C_ENA         => open,
      TX12_SDA             => open,
      TX12_SCL             => open,
      TX12_CS_B            => open,
      TX12_RST_B           => open,
      TX12_INT_B           => '0',
      TX12_PRESENT_B       => '0',
      B04_I2C_ENA          => open,
      B04_SDA              => open,
      B04_SCL              => open,
      B04_CS_B             => open,
      B04_RST_B            => open,
      B04_INT_B            => '0',
      B04_PRESENT_B        => '0',
      SPY_I2C_ENA          => open,
      SPY_SDA              => open,
      SPY_SCL              => open,
      SPY_SD               => '0',
      SPY_TDIS             => open,
      KUS_DL_SEL           => open,
      FPGA_SEL             => open,
      RST_CLKS_B           => open,
      SYSMON_P             => x"0000",
      SYSMON_N             => x"0000",
      ADC_CS_B           => open,
      ADC_DIN           => open,
      ADC_SCK           => open,
      ADC_DOUT          => '1',
      LEDS_CFV             => open
     --VME_DATA_IN          => vme_data_io_in,        --unused/open in real ODMB
     --VME_DATA_OUT         => vme_data_io_out,       --unused/open in real ODMB
      );

  -- DCFEB simulation slot 2
  dcfeb_i: DCFEB_DS_WRAPPER
    port map (
      CLK             => sysclk,
      DCFEBCLK        => '0', --160 MHz
      RST             => rst_global,
      L1A_P           => l1a_p,
      L1A_N           => l1a_n,
      L1A_MATCH_P     => l1a_match_p(2),
      L1A_MATCH_N     => l1a_match_n(2),
      TX_ACK          => '0',
      NWORDS_DUMMY    => x"0000",
      DCFEB_DV        => open,
      DCFEB_DATA      => open,
      ADC_MASK        => open,
      DCFEB_FSEL      => open,
      DCFEB_JTAG_IR   => open,
      TRST            => dcfeb_initjtag,
      TCK_P           => dcfeb_tck_p(2),  -- between ODMB and DCFEB (through PPIB)
      TCK_N           => dcfeb_tck_n(2),
      TMS_P           => dcfeb_tms_p,     -- between ODMB and DCFEB (through PPIB)
      TMS_N           => dcfeb_tms_n,
      TDI_P           => dcfeb_tdi_p,     -- between ODMB and DCFEB (through PPIB)
      TDI_N           => dcfeb_tdi_n,
      TDO_P           => dcfeb_tdo_p(2),  -- between ODMB and DCFEB (through PPIB)
      TDO_N           => dcfeb_tdo_n(2),
      RTN_SHFT_EN     => open,
      DONE            => dcfeb_done(2),
      INJPLS_P        => injpls_p,
      INJPLS_N        => injpls_n,
      EXTPLS_P        => extpls_p,
      EXTPLS_N        => extpls_n,
      BC0_P           => bc0_p,
      BC0_N           => bc0_n,
      RESYNC_P        => resync_p,
      RESYNC_N        => resync_n,
      DIAGOUT         => dcfeb_diagout
      );

  -- LVMB simulation
  lvmb_i : LVMB
    generic map (NFEB => NCFEB)
    port map (
      RST            => rst_global,
      LVMB_SCLK      => lvmb_sclk,
      LVMB_SDIN      => lvmb_sdin,
      LVMB_SDOUT_P   => lvmb_sdout_p,
      LVMB_SDOUT_N   => lvmb_sdout_n,
      LVMB_CSB       => lvmb_csb,
      LVMB_PON       => lvmb_pon,
      MON_LVMB_PON   => r_lvmb_pon,
      PON_LOAD_B     => pon_load,
      PON_OE         => pon_oe
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
