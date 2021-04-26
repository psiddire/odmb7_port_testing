-- SYSTEM_TEST: Provides utilities for testing components of ODMB

library ieee;
library work;
library unisim;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.ucsb_types.all;
use unisim.vcomponents.all;

entity SYSTEM_TEST is
  port (
    DEVICE  : in std_logic;
    COMMAND : in std_logic_vector(9 downto 0);
    INDATA  : in std_logic_vector(15 downto 0);
    STROBE  : in std_logic;
    WRITER  : in std_logic;
    SLOWCLK : in std_logic;
    CLK     : in std_logic;
    CLK160  : in std_logic;
    RST     : in std_logic;

    OUTDATA : out std_logic_vector(15 downto 0);
    DTACK   : out std_logic;

    -- DDU/PC/DCFEB COMMON PRBS
    MGT_PRBS_TYPE : out std_logic_vector(3 downto 0);

    -- DDU PRBS signals
    DDU_PRBS_TX_EN   : out std_logic;
    DDU_PRBS_RX_EN   : out std_logic;
    DDU_PRBS_TST_CNT : out std_logic_vector(15 downto 0);
    DDU_PRBS_ERR_CNT : in  std_logic_vector(15 downto 0);

    -- PC PRBS signals
    PC_PRBS_TX_EN   : out std_logic;
    PC_PRBS_RX_EN   : out std_logic;
    PC_PRBS_TST_CNT : out std_logic_vector(15 downto 0);
    PC_PRBS_ERR_CNT : in  std_logic_vector(15 downto 0);

    -- DCFEB PRBS signals
    DCFEB_PRBS_FIBER_SEL : out std_logic_vector(3 downto 0);
    DCFEB_PRBS_EN        : out std_logic;
    DCFEB_PRBS_RST       : out std_logic;
    DCFEB_PRBS_RD_EN     : out std_logic;
    DCFEB_RXPRBSERR      : in  std_logic;
    DCFEB_PRBS_ERR_CNT   : in  std_logic_vector(15 downto 0);

    -- OTMB PRBS signals
    OTMB_TX : in  std_logic_vector(48 downto 0);
    OTMB_RX : out std_logic_vector(5 downto 0)
    );
end SYSTEM_TEST;

architecture SYSTEM_TEST_Arch of SYSTEM_TEST is

  component PRBS_GEN is
    port (
      DOUT : out std_logic;

      CLK    : in std_logic;
      RST    : in std_logic;
      ENABLE : in std_logic
      );
  end component;

  -- Temporary debugging
  component ila_2 is
    port (
      clk : in std_logic := '0';
      probe0 : in std_logic_vector(383 downto 0) := (others=> '0')
      );
  end component;

  signal ila_data : std_logic_vector(383 downto 0) := (others => '0');
  signal outdata_inner : std_logic_vector(15 downto 0);
  signal dtack_inner : std_logic;

  signal cmddev                                : std_logic_vector (15 downto 0);
  signal w_ddu_prbs_tx_en, w_pc_prbs_tx_en     : std_logic;
  signal w_ddu_prbs_rx_en, w_pc_prbs_rx_en     : std_logic;
  signal r_ddu_prbs_err_cnt, r_pc_prbs_err_cnt : std_logic;
  signal strobe_pulse                          : std_logic;

  -- GLOBAL PRBS
  signal r_prbs_type, w_prbs_type : std_logic;
  signal prbs_type_inner          : std_logic_vector(3 downto 0);

  -- DCFEB PRBS
  constant dcfeb_prbs_rst_cycles : integer := 1;
  constant dcfeb_prbs_lock       : integer := 20000000;
  constant dcfeb_prbs_length     : integer := 119;  -- 10^10 at 1.25 MHZ

  signal w_dcfeb_prbs_en, r_dcfeb_prbs_err_cnt  : std_logic;
  signal w_dcfeb_prbs_fiber, r_dcfeb_prbs_fiber : std_logic;
  signal r_dcfeb_prbs_edge                      : std_logic;
  signal dcfeb_prbs_fiber_sel_inner             : std_logic_vector (3 downto 0);
  signal dcfeb_prbs_rst_cnt                     : integer;
  signal dcfeb_prbs_seq_cnt                     : std_logic_vector (15 downto 0);
  signal dcfeb_prbs_en_cnt                      : integer;
  signal dcfeb_prbs_rd_en_cnt                   : integer;
  signal dcfeb_prbserr_edge_cnt                 : std_logic_vector (15 downto 0);  -- counting the edges
  signal dcfeb_prbs_init_pulse                  : std_logic;
  signal dcfeb_prbs_reset_pulse                 : std_logic;
  signal dcfeb_prbs_rd_en_pulse                 : std_logic;
  signal dcfeb_prbs_en_pulse                    : std_logic;

  signal start_otmb_prbs_rx                     : std_logic;
  signal pulse_otmb_prbs_tx_end                 : std_logic;
  signal otmb_prbs_tx_rst                       : std_logic;
  signal otmb_prbs_rx_rst                       : std_logic;
  signal otmb_prbs_tx_en, otmb_prbs_tx_en_b     : std_logic;
  signal pulse_otmb_prbs_rx_end                 : std_logic;
  signal otmb_prbs_tx_xor                       : std_logic_vector(48 downto 0);
  signal otmb_prbs_tx                           : std_logic;
  signal otmb_prbs_tx_err                       : std_logic;
  signal w_otmb_prbs_en, r_otmb_prbs_err_cnt    : std_logic;
  signal r_otmb_prbs_good_cnt                   : std_logic;
  signal otmb_prbs_rx_cycles                    : integer;
  signal otmb_prbs_rx_sequences                 : std_logic_vector (15 downto 0);
  signal otmb_prbs_rx_en, otmb_prbs_rx_en_b     : std_logic;
  signal otmb_prbs_rx                           : std_logic;
  signal otmb_rx_inner                          : std_logic_vector(5 downto 0);
  signal otmb_tx_err_cntr                       : integer;
  signal otmb_tx_err_cnt                        : std_logic_vector(15 downto 0);
  signal q_otmb_prbs_tx_en, q_otmb_prbs_tx_en_b : std_logic;
  signal qq_otmb_prbs_tx_en                     : std_logic;
  signal mux_otmb_tx                            : std_logic_vector(48 downto 0);
  signal q_otmb_tx                              : std_logic_vector(48 downto 0);
  signal otmb_prbs_cnt_rst                      : std_logic;
  signal w_otmb_prbs_cnt_rst                    : std_logic;

  signal otmb_tx_good_cntr, otmb_tx_good_cntr_int : integer;
  signal otmb_tx_good_cnt                       : std_logic_vector(15 downto 0);
  signal otmb_prbs_tx_en_cnt                    : std_logic_vector(15 downto 0);
  signal r_otmb_prbs_en_cnt                     : std_logic;
  constant otmb_prbs_length                     : integer := 10000;

begin

  cmddev             <= "000" & DEVICE & COMMAND & "00";
  w_ddu_prbs_tx_en   <= '1' when (cmddev = x"1000" and STROBE = '1' and WRITER = '0') else '0';
  w_ddu_prbs_rx_en   <= '1' when (cmddev = x"1004" and STROBE = '1' and WRITER = '0') else '0';
  r_ddu_prbs_err_cnt <= '1' when (cmddev = x"100C" and WRITER = '1')                  else '0';

  w_pc_prbs_tx_en   <= '1' when (cmddev = x"1100" and STROBE = '1' and WRITER = '0') else '0';
  w_pc_prbs_rx_en   <= '1' when (cmddev = x"1104" and STROBE = '1' and WRITER = '0') else '0';
  r_pc_prbs_err_cnt <= '1' when (cmddev = x"110C" and WRITER = '1')                  else '0';

  w_dcfeb_prbs_en      <= '1' when (cmddev = x"1200" and STROBE = '1' and WRITER = '0') else '0';
  w_dcfeb_prbs_fiber   <= '1' when (cmddev = x"1204" and STROBE = '1' and WRITER = '0') else '0';
  r_dcfeb_prbs_fiber   <= '1' when (cmddev = x"1204" and WRITER = '1')                  else '0';
  r_dcfeb_prbs_edge    <= '1' when (cmddev = x"1208" and WRITER = '1')                  else '0';
  r_dcfeb_prbs_err_cnt <= '1' when (cmddev = x"120C" and WRITER = '1')                  else '0';

  w_prbs_type <= '1' when (cmddev = x"1300" and STROBE = '1' and WRITER = '0') else '0';
  r_prbs_type <= '1' when (cmddev = x"1300" and WRITER = '1')                  else '0';

  w_otmb_prbs_en       <= '1' when (cmddev = x"1400" and STROBE = '1' and WRITER = '0') else '0';
  r_otmb_prbs_en_cnt   <= '1' when (cmddev = x"1404" and WRITER = '1')                  else '0';
  r_otmb_prbs_good_cnt <= '1' when (cmddev = x"1408" and WRITER = '1')                  else '0';
  r_otmb_prbs_err_cnt  <= '1' when (cmddev = x"140C" and WRITER = '1')                  else '0';
  w_otmb_prbs_cnt_rst  <= '1' when (cmddev = x"1410" and STROBE = '1' and WRITER = '0') else '0';

  STROBE_PE : PULSE_EDGE port map (DOUT => strobe_pulse, PULSE1 => open, CLK => SLOWCLK, RST => RST, NPULSE => 1, DIN => STROBE);

  DDU_PRBS_RX_EN <= w_ddu_prbs_rx_en;
  PC_PRBS_RX_EN  <= w_pc_prbs_rx_en;

  FDC_DDU_TX_PRBS : FDC port map(Q => DDU_PRBS_TX_EN, C => w_ddu_prbs_tx_en, CLR => RST, D => or_reduce(INDATA));
  FDC_PC_TX_PRBS  : FDC port map(Q => PC_PRBS_TX_EN, C => w_pc_prbs_tx_en, CLR => RST, D => or_reduce(INDATA));

  GEN_PRBS : for i in 15 downto 0 generate
  begin
    FDC_DDU_PRBS   : FDC port map(Q => DDU_PRBS_TST_CNT(i), C => w_ddu_prbs_rx_en, CLR => RST, D => INDATA(i));
    FDC_PC_PRBS    : FDC port map(Q => PC_PRBS_TST_CNT(i), C => w_pc_prbs_rx_en, CLR => RST, D => INDATA(i));
    FDC_DCFEB_PRBS : FDC port map(Q => dcfeb_prbs_seq_cnt(i), C => w_dcfeb_prbs_en, CLR => RST, D => INDATA(i));
    FDC_OTMB_PRBS  : FDC port map(Q => otmb_prbs_rx_sequences(i), C => w_otmb_prbs_en, CLR => RST, D => INDATA(i));
  end generate GEN_PRBS;

  GEN_FIBER : for i in 3 downto 0 generate
  begin
    FDC_FIBER : FDC port map(Q => dcfeb_prbs_fiber_sel_inner(i), C => w_dcfeb_prbs_fiber, CLR => RST, D => INDATA(i));
  end generate GEN_FIBER;
  DCFEB_PRBS_FIBER_SEL <= dcfeb_prbs_fiber_sel_inner;

  GEN_PRBS_SEL : for i in 3 downto 0 generate
  begin
    FDC_PRBS_SEL : FDC port map(Q => prbs_type_inner(i), C => w_prbs_type, CLR => RST, D => INDATA(i));
  end generate GEN_PRBS_SEL;
  MGT_PRBS_TYPE <= prbs_type_inner;

  OUTDATA <= DDU_PRBS_ERR_CNT                    when (r_ddu_prbs_err_cnt = '1')   else
             PC_PRBS_ERR_CNT                     when (r_pc_prbs_err_cnt = '1')    else
             DCFEB_PRBS_ERR_CNT                  when (r_dcfeb_prbs_err_cnt = '1') else
             x"000" & dcfeb_prbs_fiber_sel_inner when (r_dcfeb_prbs_fiber = '1')   else
             dcfeb_prbserr_edge_cnt              when (r_dcfeb_prbs_edge = '1')    else
             otmb_prbs_tx_en_cnt                 when (r_otmb_prbs_en_cnt = '1')   else
             otmb_tx_good_cnt                    when (r_otmb_prbs_good_cnt = '1') else
             otmb_tx_err_cnt                     when (r_otmb_prbs_err_cnt = '1')  else
             x"000" & prbs_type_inner            when (r_prbs_type = '1')          else
             (others => 'L');

  otmb_tx_good_cnt <= std_logic_vector(to_unsigned(otmb_tx_good_cntr, 16));
  otmb_tx_err_cnt <= std_logic_vector(to_unsigned(otmb_tx_err_cntr, 16));

  DTACK <= strobe_pulse and (w_ddu_prbs_tx_en or w_ddu_prbs_rx_en or r_ddu_prbs_err_cnt or
                             w_pc_prbs_tx_en or w_pc_prbs_rx_en or r_pc_prbs_err_cnt or
                             w_otmb_prbs_en or r_otmb_prbs_en_cnt or w_dcfeb_prbs_en or
                             r_dcfeb_prbs_err_cnt or r_dcfeb_prbs_edge or
                             w_dcfeb_prbs_fiber or r_dcfeb_prbs_fiber or w_prbs_type or
                             r_prbs_type or r_otmb_prbs_good_cnt or r_otmb_prbs_err_cnt or
                             w_otmb_prbs_cnt_rst);

  -- DCFEB PRBS signals
  dcfeb_prbs_rst_cnt   <= dcfeb_prbs_lock+dcfeb_prbs_rst_cycles;
  dcfeb_prbs_en_cnt    <= dcfeb_prbs_length*to_integer(unsigned(dcfeb_prbs_seq_cnt))+dcfeb_prbs_rst_cnt;
  dcfeb_prbs_rd_en_cnt <= dcfeb_prbs_en_cnt-1;

  DCFEBPRBSINIT : PULSE_EDGE port map (DOUT => dcfeb_prbs_init_pulse, PULSE1 => open, CLK => CLK160, RST => RST, NPULSE => dcfeb_prbs_lock, DIN => w_dcfeb_prbs_en);
  DCFEBPRBSRST  : PULSE_EDGE port map (DOUT => dcfeb_prbs_reset_pulse, PULSE1 => open, CLK => CLK160, RST => RST, NPULSE => dcfeb_prbs_rst_cnt, DIN => w_dcfeb_prbs_en);
  DCFEBPRBSRDEN : PULSE_EDGE port map (DOUT => dcfeb_prbs_rd_en_pulse, PULSE1 => open, CLK => CLK160, RST => RST, NPULSE => dcfeb_prbs_rd_en_cnt, DIN => w_dcfeb_prbs_en);
  DCFEBPRBSEN : PULSE_EDGE port map (DOUT => dcfeb_prbs_en_pulse, PULSE1 => open, CLK => CLK160, RST => RST, NPULSE => dcfeb_prbs_en_cnt, DIN => w_dcfeb_prbs_en);
  PRBSERR_CNT : COUNT_EDGES port map (COUNT => dcfeb_prbserr_edge_cnt, CLK => DCFEB_RXPRBSERR, RST => RST, DIN => '1');

  DCFEB_PRBS_RST   <= dcfeb_prbs_reset_pulse and not dcfeb_prbs_init_pulse;
  DCFEB_PRBS_EN    <= dcfeb_prbs_en_pulse;
  DCFEB_PRBS_RD_EN <= dcfeb_prbs_en_pulse and not dcfeb_prbs_rd_en_pulse;

  -- OTMB PRBS RX test
  otmb_prbs_rx_cycles <= otmb_prbs_length*to_integer(unsigned(otmb_prbs_rx_sequences));

  FD_OTMB_START    : FD port map (Q => start_otmb_prbs_rx, C => CLK, D => w_otmb_prbs_en);
  PULSEOTMB_EN     : PULSE_EDGE port map (DOUT => otmb_prbs_rx_en, PULSE1 => open, CLK => CLK, RST => RST, NPULSE => otmb_prbs_rx_cycles, DIN => start_otmb_prbs_rx);
  otmb_prbs_rx_en_b <= not otmb_prbs_rx_en;
  PULSEOTMB_RX_RST : PULSE_EDGE port map (DOUT => pulse_otmb_prbs_rx_end, PULSE1 => open, CLK => SLOWCLK, RST => RST, NPULSE => 2, DIN => otmb_prbs_rx_en_b);
  otmb_prbs_rx_rst  <= pulse_otmb_prbs_rx_end or RST;

  PRBS_GEN_PM : PRBS_GEN port map (DOUT => otmb_prbs_rx, CLK => CLK, RST => otmb_prbs_rx_rst, ENABLE => otmb_prbs_rx_en);
  otmb_rx_inner <= (0 => otmb_prbs_rx_en, others => otmb_prbs_rx);
  OTMB_RX       <= otmb_rx_inner;

  -- OTMB PRBS TX test
  otmb_prbs_tx_en   <= q_otmb_tx(48);
  TX_EN_CNT        : COUNT_EDGES port map (COUNT => otmb_prbs_tx_en_cnt, CLK => CLK, RST => rst, DIN => otmb_prbs_tx_en);
  otmb_prbs_tx_en_b <= not otmb_prbs_tx_en;
  PULSEOTMB_TX_RST : PULSE_EDGE port map (DOUT => pulse_otmb_prbs_tx_end, PULSE1 => open, CLK => SLOWCLK, RST => RST, NPULSE => 2, DIN => otmb_prbs_tx_en_b);
  otmb_prbs_tx_rst  <= pulse_otmb_prbs_tx_end or RST;

  PE_EN  : PULSE_EDGE port map (DOUT => q_otmb_prbs_tx_en, PULSE1 => open, CLK => CLK, RST => RST, NPULSE => 50, DIN => otmb_prbs_tx_en);
  q_otmb_prbs_tx_en_b <= not q_otmb_prbs_tx_en;
  PE_EN2 : PULSE_EDGE port map (DOUT => qq_otmb_prbs_tx_en, PULSE1 => open, CLK => CLK, RST => RST, NPULSE => 100, DIN => q_otmb_prbs_tx_en_b);
  mux_otmb_tx         <= not q_otmb_tx when qq_otmb_prbs_tx_en = '1' else q_otmb_tx;

  PRBS_GEN_TX_PM   : PRBS_GEN port map (DOUT => otmb_prbs_tx, CLK => CLK, RST => otmb_prbs_tx_rst, ENABLE => otmb_prbs_tx_en);
  GEN_OTMB_PRBS_TX : for index in 48 downto 0 generate
    FD_OTMB_TX : FD port map (Q => q_otmb_tx(index), C => CLK, D => OTMB_TX(index));
    otmb_prbs_tx_xor(index) <= mux_otmb_tx(index) xor otmb_prbs_tx;
  end generate GEN_OTMB_PRBS_TX;
  otmb_prbs_tx_err <= or_reduce(otmb_prbs_tx_xor(47 downto 0));

  CNT_RST : PULSE_EDGE port map (DOUT => otmb_prbs_cnt_rst, PULSE1 => open, CLK => CLK, RST => RST, NPULSE => 2, DIN => w_otmb_prbs_cnt_rst);

  prbs_tx_cnt_proc : process (CLK, RST, otmb_prbs_tx_en, otmb_prbs_cnt_rst, otmb_tx_good_cntr_int,
                              otmb_prbs_tx_err, otmb_tx_err_cntr, otmb_tx_good_cntr)
    variable bit : std_logic;
  begin
    if (RST = '1' or otmb_prbs_cnt_rst = '1') then
      otmb_tx_err_cntr      <= 0;
      otmb_tx_good_cntr_int <= 0;
      otmb_tx_good_cntr     <= 0;
    elsif (falling_edge(CLK) and otmb_prbs_tx_en = '1') then
      if otmb_prbs_tx_err = '1' then
        otmb_tx_err_cntr <= otmb_tx_err_cntr + 1;
      else
        otmb_tx_good_cntr_int <= otmb_tx_good_cntr_int + 1;
        if otmb_tx_good_cntr_int = otmb_prbs_length then
          otmb_tx_good_cntr     <= otmb_tx_good_cntr + 1;
          otmb_tx_good_cntr_int <= 1;
        end if;
      end if;
    else
      otmb_tx_good_cntr_int <= otmb_tx_good_cntr_int;
      otmb_tx_good_cntr     <= otmb_tx_good_cntr;
      otmb_tx_err_cntr      <= otmb_tx_err_cntr;
    end if;
  end process;

  -- OTMB TX test signals
  ila_data(48 downto 0)    <= otmb_tx;
  ila_data(64 downto 49)   <= otmb_prbs_tx_en_cnt;
  ila_data(80 downto 65)   <= otmb_tx_good_cnt;
  ila_data(96 downto 81)   <= otmb_tx_err_cnt;
  ila_data(97)             <= w_otmb_prbs_en;       -- VME command
  ila_data(98)             <= r_otmb_prbs_en_cnt;   -- VME command
  ila_data(99)             <= r_otmb_prbs_good_cnt; -- VME command
  ila_data(100)            <= r_otmb_prbs_err_cnt;  -- VME command
  ila_data(101)            <= w_otmb_prbs_cnt_rst;  -- VME command
  ila_data(102)            <= otmb_prbs_tx_en;      -- from delayed otmb_tx
  ila_data(103)            <= otmb_prbs_tx_rst;
  ila_data(104)            <= q_otmb_prbs_tx_en;
  ila_data(105)            <= qq_otmb_prbs_tx_en;
  ila_data(106)            <= otmb_prbs_tx;
  ila_data(107)            <= otmb_prbs_tx_err;
  ila_data(156 downto 108) <= mux_otmb_tx;
  -- Output results
  ila_data(172 downto 157) <= outdata_inner;
  ila_data(173)            <= dtack_inner;
  -- OTMB RX test signals
  ila_data(174)            <= start_otmb_prbs_rx;
  ila_data(175)            <= otmb_prbs_rx_en;
  ila_data(176)            <= otmb_prbs_rx;
  ila_data(177)            <= CLK;

  ila_systest_inst : ila_2
    port map (
      clk    => CLK160,
      probe0 => ila_data
      );


end SYSTEM_TEST_Arch;
