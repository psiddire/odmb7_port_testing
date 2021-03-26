--------------------------------------------------------------------------------
-- MGT wrapper
-- Based on example design
--------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

library UNISIM;
use UNISIM.VComponents.all;

-- library work;
-- use work.ucsb_types.all;

entity mgt_ddu is
  generic (
    NCHANNL     : integer range 1 to 4 := 4;  -- number of (firmware) channels (max of TX/RX links)
    NRXLINK     : integer range 1 to 4 := 1;  -- number of (physical) RX links
    NTXLINK     : integer range 1 to 4 := 4;  -- number of (physical) TX links
    TXDATAWIDTH : integer := 32;              -- transmitter user data width
    RXDATAWIDTH : integer := 16               -- receiver user data width
    );
  port (
    -- Clocks
    mgtrefclk   : in  std_logic; -- buffer'ed reference clock signal
    txusrclk    : out std_logic; -- USRCLK for TX data readout
    rxusrclk    : out std_logic; -- USRCLK for RX data readout
    sysclk      : in  std_logic; -- clock for the helper block, 80 MHz

    -- Serial data ports for transceiver at bank 224-225
    daq_tx_n    : out std_logic_vector(3 downto 0);
    daq_tx_p    : out std_logic_vector(3 downto 0);
    bck_rx_n    : in  std_logic; -- for back pressure / loopback
    bck_rx_p    : in  std_logic; -- for back pressure / loopback
    b04_rx_n    : in  std_logic_vector(3 downto 1);
    b04_rx_p    : in  std_logic_vector(3 downto 1);

    -- Transmitter signals
    txdata_ch0  : in std_logic_vector(TXDATAWIDTH-1 downto 0);  -- Data received
    txdata_ch1  : in std_logic_vector(TXDATAWIDTH-1 downto 0);  -- Data received
    txdata_ch2  : in std_logic_vector(TXDATAWIDTH-1 downto 0);  -- Data received
    txdata_ch3  : in std_logic_vector(TXDATAWIDTH-1 downto 0);  -- Data received
    txd_valid   : in std_logic_vector(NTXLINK-1 downto 0);   -- Flag for valid data;

    -- Receiver signals
    rxdata_ch0  : out std_logic_vector(RXDATAWIDTH-1 downto 0);  -- Data received
    rxdata_ch1  : out std_logic_vector(RXDATAWIDTH-1 downto 0);  -- Data received
    rxdata_ch2  : out std_logic_vector(RXDATAWIDTH-1 downto 0);  -- Data received
    rxdata_ch3  : out std_logic_vector(RXDATAWIDTH-1 downto 0);  -- Data received
    rxd_valid   : out std_logic_vector(NRXLINK downto 1);   -- Flag for valid data;
    bad_rx      : out std_logic_vector(NRXLINK downto 1);   -- Flag for fiber errors;

    -- Clock active signals
    rxready     : out std_logic; -- Flag for rx reset done
    txready     : out std_logic; -- Flag for tx reset done

    -- PRBS signals
    prbs_type    : in  std_logic_vector(3 downto 0);
    prbs_rx_en   : in  std_logic_vector(NRXLINK downto 1);
    prbs_tst_cnt : in  std_logic_vector(15 downto 0);
    prbs_err_cnt : out std_logic_vector(15 downto 0);

    -- Reset
    reset        : in  std_logic
    );
end mgt_ddu;

architecture Behavioral of mgt_ddu is

  --------------------------------------------------------------------------
  -- Component declaration for the GTH transceiver container
  --------------------------------------------------------------------------
  component gtwiz_ddu_b4_example_wrapper
    port (
      gthrxn_in : in std_logic_vector(3 downto 0);
      gthrxp_in : in std_logic_vector(3 downto 0);
      gthtxn_out : out std_logic_vector(3 downto 0);
      gthtxp_out : out std_logic_vector(3 downto 0);
      gtwiz_userclk_tx_reset_in : in std_logic;
      gtwiz_userclk_tx_srcclk_out : out std_logic;
      gtwiz_userclk_tx_usrclk_out : out std_logic;
      gtwiz_userclk_tx_usrclk2_out : out std_logic;
      gtwiz_userclk_tx_active_out : out std_logic;
      gtwiz_userclk_rx_reset_in : in std_logic;
      gtwiz_userclk_rx_srcclk_out : out std_logic;
      gtwiz_userclk_rx_usrclk_out : out std_logic;
      gtwiz_userclk_rx_usrclk2_out : out std_logic;
      gtwiz_userclk_rx_active_out : out std_logic;
      gtwiz_reset_clk_freerun_in : in std_logic;
      gtwiz_reset_all_in : in std_logic;
      gtwiz_reset_tx_pll_and_datapath_in : in std_logic;
      gtwiz_reset_tx_datapath_in : in std_logic;
      gtwiz_reset_rx_pll_and_datapath_in : in std_logic;
      gtwiz_reset_rx_datapath_in : in std_logic;
      gtwiz_reset_rx_cdr_stable_out : out std_logic;
      gtwiz_reset_tx_done_out : out std_logic;
      gtwiz_reset_rx_done_out : out std_logic;
      gtwiz_userdata_tx_in : in std_logic_vector(NCHANNL*TXDATAWIDTH-1 downto 0);
      gtwiz_userdata_rx_out : out std_logic_vector(NCHANNL*RXDATAWIDTH-1 downto 0);
      gtrefclk00_in : in std_logic;
      gtrefclk01_in : in std_logic;
      qpll0outclk_out : out std_logic;
      qpll0outrefclk_out : out std_logic;
      qpll1outclk_out : out std_logic;
      qpll1outrefclk_out : out std_logic;
      rx8b10ben_in : in std_logic_vector(NCHANNL-1 downto 0);
      rxcommadeten_in : in std_logic_vector(NCHANNL-1 downto 0);
      rxmcommaalignen_in : in std_logic_vector(NCHANNL-1 downto 0);
      rxpcommaalignen_in : in std_logic_vector(NCHANNL-1 downto 0);
      rxpd_in : in std_logic_vector(2*NCHANNL-1 downto 0);
      rxprbscntreset_in : in std_logic_vector(NCHANNL-1 downto 0);
      rxprbssel_in : in std_logic_vector(4*NCHANNL-1 downto 0);
      tx8b10ben_in : in std_logic_vector(NCHANNL-1 downto 0);
      txctrl0_in : in std_logic_vector(16*NCHANNL-1 downto 0);
      txctrl1_in : in std_logic_vector(16*NCHANNL-1 downto 0);
      txctrl2_in : in std_logic_vector(8*NCHANNL-1 downto 0);
      txpd_in : in std_logic_vector(2*NCHANNL-1 downto 0);
      txprbsforceerr_in : in std_logic_vector(NCHANNL-1 downto 0);
      txprbssel_in : in std_logic_vector(4*NCHANNL-1 downto 0);
      gtpowergood_out : out std_logic_vector(NCHANNL-1 downto 0);
      rxbyteisaligned_out : out std_logic_vector(NCHANNL-1 downto 0);
      rxbyterealign_out : out std_logic_vector(NCHANNL-1 downto 0);
      rxcommadet_out : out std_logic_vector(NCHANNL-1 downto 0);
      rxctrl0_out : out std_logic_vector(16*NCHANNL-1 downto 0);
      rxctrl1_out : out std_logic_vector(16*NCHANNL-1 downto 0);
      rxctrl2_out : out std_logic_vector(8*NCHANNL-1 downto 0);
      rxctrl3_out : out std_logic_vector(8*NCHANNL-1 downto 0);
      rxpmaresetdone_out : out std_logic_vector(NCHANNL-1 downto 0);
      rxprbserr_out : out std_logic_vector(NCHANNL-1 downto 0);
      rxprbslocked_out : out std_logic_vector(NCHANNL-1 downto 0);
      txpmaresetdone_out : out std_logic_vector(NCHANNL-1 downto 0)
      );
  end component;

  constant IDLE16 : std_logic_vector(15 downto 0) := x"50BC"; -- TODO: what is the IDLE word from DCFEBs?
  constant IDLE32 : std_logic_vector(31 downto 0) := x"503C50BC";

  -- Synchronize the latched link down reset input and the VIO-driven signal into the free-running clock domain
  -- signals passed to wizard
  signal gthrxn_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal gthrxp_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal gthtxn_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal gthtxp_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal gtwiz_userclk_tx_reset_int : std_logic := '0';
  signal gtwiz_userclk_tx_srcclk_int : std_logic := '0';
  signal gtwiz_userclk_tx_usrclk_int : std_logic := '0';
  signal gtwiz_userclk_tx_usrclk2_int : std_logic := '0';
  signal gtwiz_userclk_tx_active_int : std_logic := '0';
  signal gtwiz_userclk_rx_reset_int : std_logic := '0';
  signal gtwiz_userclk_rx_srcclk_int : std_logic := '0';
  signal gtwiz_userclk_rx_usrclk_int : std_logic := '0';
  signal gtwiz_userclk_rx_usrclk2_int : std_logic := '0';
  signal gtwiz_userclk_rx_active_int : std_logic := '0';
  signal gtwiz_reset_clk_freerun_int : std_logic := '0';
  signal gtwiz_reset_all_int : std_logic;
  signal gtwiz_reset_tx_pll_and_datapath_int : std_logic := '0';
  signal gtwiz_reset_tx_datapath_int : std_logic := '0';
  signal gtwiz_reset_rx_pll_and_datapath_int : std_logic := '0';
  signal gtwiz_reset_rx_datapath_int : std_logic := '0';
  signal gtwiz_reset_rx_cdr_stable_int : std_logic := '0';
  signal gtwiz_reset_tx_done_int : std_logic := '0';
  signal gtwiz_reset_rx_done_int : std_logic := '0';
  signal gtwiz_userdata_tx_int : std_logic_vector(NCHANNL*TXDATAWIDTH-1 downto 0) := (others => '0'); -- depend on NCHANNL and TXDATAWIDTH
  signal gtwiz_userdata_rx_int : std_logic_vector(NCHANNL*RXDATAWIDTH-1 downto 0) := (others => '0'); -- depend on NCHANNL and RXDATAWIDTH
  signal gtpowergood_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal rxbyteisaligned_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal rxbyterealign_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal rxcommadet_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal rxctrl0_int : std_logic_vector(16*NCHANNL-1 downto 0) := (others => '0');
  signal rxctrl1_int : std_logic_vector(16*NCHANNL-1 downto 0) := (others => '0');
  signal rxctrl2_int : std_logic_vector(8*NCHANNL-1 downto 0) := (others => '0');
  signal rxctrl3_int : std_logic_vector(8*NCHANNL-1 downto 0) := (others => '0');
  signal rxpmaresetdone_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal txpmaresetdone_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');

  signal hb_gtwiz_reset_all_int : std_logic := '0';

  -- ref clock
  signal gtrefclk00_int : std_logic;
  signal qpll0outclk_int : std_logic;
  signal qpll0outrefclk_int : std_logic;
  signal gtrefclk01_int : std_logic;
  signal qpll1outclk_int : std_logic;
  signal qpll1outrefclk_int : std_logic;

  -- rx helper signals
  type rxd_nbyte_array_nlink is array (1 to NRXLINK) of std_logic_vector(RXDATAWIDTH/8-1 downto 0);
  signal rxcharisk_ch : rxd_nbyte_array_nlink;
  signal rxdisperr_ch : rxd_nbyte_array_nlink;
  signal rxnotintable_ch : rxd_nbyte_array_nlink;
  signal rxchariscomma_ch : rxd_nbyte_array_nlink;
  signal codevalid_ch : rxd_nbyte_array_nlink;

  signal bad_rx_int : std_logic_vector(NRXLINK downto 1);
  signal rxready_int : std_logic;
  signal txready_int : std_logic;

  -- Preset constants
  signal rx8b10ben_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '1');
  signal rxcommadeten_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '1');
  signal rxmcommaalignen_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '1');
  signal rxpcommaalignen_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '1');
  signal txctrl0_int : std_logic_vector(16*NCHANNL-1 downto 0) := (others => '0');
  signal txctrl1_int : std_logic_vector(16*NCHANNL-1 downto 0) := (others => '0');
  signal txctrl2_int : std_logic_vector(8*NCHANNL-1 downto 0) := (others => '0');

  signal txpd_int : std_logic_vector(2*NCHANNL-1 downto 0) := (others => '0');
  signal rxpd_int : std_logic_vector(2*NCHANNL-1 downto 0) := (others => '0');

  -- GT control
  signal loopback_int : std_logic_vector(3*NCHANNL-1 downto 0) := (others=> '0');
  signal rxprbscntreset_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal rxprbssel_int : std_logic_vector(4*NCHANNL-1 downto 0) := (others => '0');
  signal rxprbserr_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal rxprbslocked_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal txprbsforceerr_int : std_logic_vector(NCHANNL-1 downto 0) := (others => '0');
  signal txprbssel_int : std_logic_vector(4*NCHANNL-1 downto 0) := (others => '0');

  -- debug signals
  signal ila_data_rx: std_logic_vector(127 downto 0) := (others=> '0');
  signal gtpowergood_vio_sync : std_logic_vector(1 downto 0) := (others=> '0');
  signal txpmaresetdone_vio_sync: std_logic_vector(1 downto 0) := (others=> '0');
  signal rxpmaresetdone_vio_sync: std_logic_vector(1 downto 0) := (others=> '0');
  signal gtwiz_reset_rx_done_vio_sync: std_logic;
  signal gtwiz_reset_tx_done_vio_sync: std_logic;
  signal link_down_latched_reset_vio_int: std_logic;
  signal link_down_latched_reset_sync: std_logic;
  signal hb_gtwiz_reset_rx_datapath_vio_int: std_logic;
  signal hb_gtwiz_reset_rx_pll_and_datapath_vio_int: std_logic;
  signal rxdata_errctr_reset_vio_int : std_logic;

begin

  -- Serial ports connection
  daq_tx_n <= gthtxn_int;
  daq_tx_p <= gthtxp_int;
  gthrxn_int(0) <= bck_rx_n;
  gthrxp_int(0) <= bck_rx_p;
  gthrxn_int(3 downto 1) <= b04_rx_n;
  gthrxp_int(3 downto 1) <= b04_rx_p;

  ---------------------------------------------------------------------------------------------------------------------
  -- User data ports
  ---------------------------------------------------------------------------------------------------------------------
  gtwiz_userdata_tx_int(1*TXDATAWIDTH-1 downto 0*TXDATAWIDTH) <= TXDATA_CH0 when TXD_VALID(0) = '1' else IDLE16 when TXDATAWIDTH = 16 else IDLE32;
  gtwiz_userdata_tx_int(2*TXDATAWIDTH-1 downto 1*TXDATAWIDTH) <= TXDATA_CH1 when TXD_VALID(1) = '1' else IDLE16 when TXDATAWIDTH = 16 else IDLE32;
  gtwiz_userdata_tx_int(3*TXDATAWIDTH-1 downto 2*TXDATAWIDTH) <= TXDATA_CH2 when TXD_VALID(2) = '1' else IDLE16 when TXDATAWIDTH = 16 else IDLE32;
  gtwiz_userdata_tx_int(4*TXDATAWIDTH-1 downto 3*TXDATAWIDTH) <= TXDATA_CH3 when TXD_VALID(3) = '1' else IDLE16 when TXDATAWIDTH = 16 else IDLE32;
  txctrl2_int( 7 downto  0) <= x"00" when TXD_VALID(0) = '1' else x"01";
  txctrl2_int(15 downto  8) <= x"00" when TXD_VALID(1) = '1' else x"01";
  txctrl2_int(23 downto 16) <= x"00" when TXD_VALID(2) = '1' else x"01";
  txctrl2_int(31 downto 24) <= x"00" when TXD_VALID(3) = '1' else x"01";

  RXDATA_CH0 <= gtwiz_userdata_rx_int(1*RXDATAWIDTH-1 downto 0*RXDATAWIDTH);
  u_mgt_port_assign_2 : if NRXLINK >= 2 generate
    RXDATA_CH1 <= gtwiz_userdata_rx_int(2*RXDATAWIDTH-1 downto 1*RXDATAWIDTH);
  end generate;
  u_mgt_port_assign_3 : if NRXLINK >= 3 generate
    RXDATA_CH2 <= gtwiz_userdata_rx_int(3*RXDATAWIDTH-1 downto 2*RXDATAWIDTH);
  end generate;
  u_mgt_port_assign_4 : if NRXLINK >= 4 generate
    RXDATA_CH3 <= gtwiz_userdata_rx_int(4*RXDATAWIDTH-1 downto 3*RXDATAWIDTH);
  end generate;

  gen_rx_quality : for I in 1 to NRXLINK generate
  begin
    rxcharisk_ch(I)     <= rxctrl0_int(16*(I-1)+RXDATAWIDTH/8-1 downto 16*(I-1));
    rxdisperr_ch(I)     <= rxctrl1_int(16*(I-1)+RXDATAWIDTH/8-1 downto 16*(I-1));
    rxchariscomma_ch(I) <= rxctrl2_int(8*(I-1)+RXDATAWIDTH/8-1 downto 8*(I-1));
    rxnotintable_ch(I)  <= rxctrl3_int(8*(I-1)+RXDATAWIDTH/8-1 downto 8*(I-1));

    codevalid_ch(I) <= not (rxnotintable_ch(I) or rxdisperr_ch(I));
    bad_rx_int(I) <= not (rxbyteisaligned_int(I-1) and (not rxbyterealign_int(I-1)));

    -- RXDATA is valid only when it's been deemed aligned, recognized 8B/10B pattern and does not contain a K-character.
    -- The RXVALID port is not explained in UG576, so it's not used.
    RXD_VALID(I) <= '1' when (rxready_int = '1' and bad_rx_int(I) = '0' and and_reduce(codevalid_ch(I)) = '1' and or_reduce(rxchariscomma_ch(I)) = '0') else '0';

    -- Duplicating GT control inputs for all channels
    rxprbssel_int(4*I-1 downto 4*I-4) <= PRBS_TYPE when PRBS_RX_EN(I) = '1' else x"0";
  end generate gen_rx_quality;

  gen_rx_disabled : for I in NRXLINK+1 to NCHANNL-1 generate
    rxpd_int(2*I+1 downto 2*I) <= "11";
  end generate gen_rx_disabled;

  TXREADY <= gtwiz_userclk_tx_active_int and gtwiz_reset_tx_done_int;
  RXREADY <= rxready_int;
  rxready_int <= gtwiz_userclk_rx_active_int and gtwiz_reset_rx_done_int;

  -- MGT reference clk
  gtrefclk00_int <= MGTREFCLK;
  gtrefclk01_int <= MGTREFCLK;
  TXUSRCLK <= gtwiz_userclk_tx_usrclk2_int;
  RXUSRCLK <= gtwiz_userclk_rx_usrclk2_int;

  ---------------------------------------------------------------------------------------------------------------------
  -- USER CLOCKING RESETS
  ---------------------------------------------------------------------------------------------------------------------
  -- The TX/RX user clocking helper block should be held in reset until the clock source of that block is known to be
  -- stable. The following assignment is an example of how that stability can be determined, based on the selected TX/RX
  -- user clock source. Replace the assignment with the appropriate signal or logic to achieve that behavior as needed.
  gtwiz_userclk_tx_reset_int <= nand_reduce(txpmaresetdone_int);
  gtwiz_userclk_rx_reset_int <= nand_reduce(rxpmaresetdone_int);

  -- Declare signals which connect the VIO instance to the initialization module for debug purposes
  -- leave it untouched in this vhdl example
  -- TODO: leave the individual reset for now, only use one big reset
  gtwiz_reset_all_int <= RESET;
  rxprbscntreset_int <= (others => RESET);

  ---------------------------------------------------------------------------------------------------------------------
  -- EXAMPLE WRAPPER INSTANCE
  ---------------------------------------------------------------------------------------------------------------------
  ddu_wrapper_inst : gtwiz_ddu_b4_example_wrapper
    port map (
      gthrxn_in                          => gthrxn_int,
      gthrxp_in                          => gthrxp_int,
      gthtxn_out                         => gthtxn_int,
      gthtxp_out                         => gthtxp_int,
      gtwiz_userclk_tx_reset_in          => gtwiz_userclk_tx_reset_int,
      gtwiz_userclk_tx_srcclk_out        => gtwiz_userclk_tx_srcclk_int,
      gtwiz_userclk_tx_usrclk_out        => gtwiz_userclk_tx_usrclk_int,
      gtwiz_userclk_tx_usrclk2_out       => gtwiz_userclk_tx_usrclk2_int,
      gtwiz_userclk_tx_active_out        => gtwiz_userclk_tx_active_int,
      gtwiz_userclk_rx_reset_in          => gtwiz_userclk_rx_reset_int,
      gtwiz_userclk_rx_srcclk_out        => gtwiz_userclk_rx_srcclk_int,
      gtwiz_userclk_rx_usrclk_out        => gtwiz_userclk_rx_usrclk_int,
      gtwiz_userclk_rx_usrclk2_out       => gtwiz_userclk_rx_usrclk2_int,
      gtwiz_userclk_rx_active_out        => gtwiz_userclk_rx_active_int,
      gtwiz_reset_clk_freerun_in         => SYSCLK,
      gtwiz_reset_all_in                 => hb_gtwiz_reset_all_int,
      gtwiz_reset_tx_pll_and_datapath_in => gtwiz_reset_tx_pll_and_datapath_int,
      gtwiz_reset_tx_datapath_in         => gtwiz_reset_tx_datapath_int,
      gtwiz_reset_rx_pll_and_datapath_in => gtwiz_reset_rx_pll_and_datapath_int,
      gtwiz_reset_rx_datapath_in         => gtwiz_reset_rx_datapath_int,
      gtwiz_reset_rx_cdr_stable_out      => gtwiz_reset_rx_cdr_stable_int,
      gtwiz_reset_tx_done_out            => gtwiz_reset_tx_done_int,
      gtwiz_reset_rx_done_out            => gtwiz_reset_rx_done_int,
      gtwiz_userdata_tx_in               => gtwiz_userdata_tx_int,
      gtwiz_userdata_rx_out              => gtwiz_userdata_rx_int,
      gtrefclk00_in                      => gtrefclk00_int,
      gtrefclk01_in                      => gtrefclk01_int,
      qpll0outclk_out                    => qpll0outclk_int,
      qpll0outrefclk_out                 => qpll0outrefclk_int,
      qpll1outclk_out                    => qpll1outclk_int,
      qpll1outrefclk_out                 => qpll1outrefclk_int,
      rx8b10ben_in                       => (others => '1'),
      rxcommadeten_in                    => (others => '1'),
      rxmcommaalignen_in                 => (others => '1'),
      rxpcommaalignen_in                 => (others => '1'),
      rxpd_in                            => rxpd_int,
      rxprbscntreset_in                  => rxprbscntreset_int,
      rxprbssel_in                       => rxprbssel_int,
      tx8b10ben_in                       => (others => '1'),
      txctrl0_in                         => (others => '0'), -- not used in 8b10b
      txctrl1_in                         => (others => '0'), -- not used in 8b10b
      txctrl2_in                         => txctrl2_int,     -- K-character indicator
      txpd_in                            => txpd_int,
      txprbsforceerr_in                  => txprbsforceerr_int,
      txprbssel_in                       => txprbssel_int,
      gtpowergood_out                    => gtpowergood_int,
      rxbyteisaligned_out                => rxbyteisaligned_int,
      rxbyterealign_out                  => rxbyterealign_int,
      rxcommadet_out                     => rxcommadet_int,
      rxctrl0_out                        => rxctrl0_int,
      rxctrl1_out                        => rxctrl1_int,
      rxctrl2_out                        => rxctrl2_int,
      rxctrl3_out                        => rxctrl3_int,
      rxpmaresetdone_out                 => rxpmaresetdone_int,
      rxprbserr_out                      => rxprbserr_int,
      rxprbslocked_out                   => rxprbslocked_int,
      txpmaresetdone_out                 => txpmaresetdone_int
    );

  ---------------------------------------------------------------------------------------------------------------------
  -- Debug session
  ---------------------------------------------------------------------------------------------------------------------

end Behavioral;
