--------------------------------------------------------------------------------
-- MGT wrapper
-- Based on example design
--------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;

use ieee.std_logic_misc.all;

entity mgt_alct is
  generic (
    NLINK : integer range 1 to 5 := 1;  -- number of links
    DATAWIDTH : integer := 16            -- user data width
    );
  port (
    -- Clocks
    mgtrefclk   : in  std_logic; -- buffer'ed reference clock signal
    rxusrclk    : out std_logic; -- USRCLK for RX data readout
    sysclk      : in  std_logic; -- clock for the helper block, 80 MHz

    -- Serial data ports for transceiver at bank 226
    daq_rx_n    : in  std_logic;
    daq_rx_p    : in  std_logic;
    rxready     : out std_logic; -- Flag for rx reset done

    -- Receiver signals
    rxdata      : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
    rxd_valid   : out std_logic_vector(NLINK-1 downto 0);   -- Flag for valid data;
    bad_rx      : out std_logic_vector(NLINK-1 downto 0);   -- Flag for fiber errors;

    -- PRBS signals
    prbs_type       : in  std_logic_vector(3 downto 0);
    prbs_rx_en      : in  std_logic_vector(NLINK-1 downto 0);
    prbs_tst_cnt    : in  std_logic_vector(15 downto 0);
    prbs_err_cnt    : out std_logic_vector(15 downto 0);

    -- Clock for the gtwizard system
    reset           : in  std_logic
    );
end mgt_alct;

architecture Behavioral of mgt_alct is

  --------------------------------------------------------------------------
  -- Component declaration for the GTH transceiver container
  --------------------------------------------------------------------------
  component gtwiz_alct_r1_example_wrapper
    port (
      gthrxn_in : in std_logic_vector(NLINK-1 downto 0);
      gthrxp_in : in std_logic_vector(NLINK-1 downto 0);
      gthtxn_out : out std_logic_vector(NLINK-1 downto 0);
      gthtxp_out : out std_logic_vector(NLINK-1 downto 0);
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
      gtwiz_userdata_tx_in : in std_logic_vector(NLINK*DATAWIDTH-1 downto 0);
      gtwiz_userdata_rx_out : out std_logic_vector(NLINK*DATAWIDTH-1 downto 0);
      drpclk_in : in std_logic_vector(NLINK-1 downto 0);
      gtrefclk0_in : in std_logic;
      rx8b10ben_in : in std_logic_vector(NLINK-1 downto 0);
      rxcommadeten_in : in std_logic_vector(NLINK-1 downto 0);
      rxmcommaalignen_in : in std_logic_vector(NLINK-1 downto 0);
      rxpcommaalignen_in : in std_logic_vector(NLINK-1 downto 0);
      rxpd_in : in std_logic_vector(2*NLINK-1 downto 0);
      rxprbscntreset_in : in std_logic_vector(NLINK-1 downto 0);
      rxprbssel_in : in std_logic_vector(4*NLINK-1 downto 0);
      tx8b10ben_in : in std_logic_vector(NLINK-1 downto 0);
      txctrl0_in : in std_logic_vector(16*NLINK-1 downto 0);
      txctrl1_in : in std_logic_vector(16*NLINK-1 downto 0);
      txctrl2_in : in std_logic_vector(8*NLINK-1 downto 0);
      txpd_in : in std_logic_vector(2*NLINK-1 downto 0);
      txprbsforceerr_in : in std_logic_vector(NLINK-1 downto 0);
      txprbssel_in : in std_logic_vector(4*NLINK-1 downto 0);
      gtpowergood_out : out std_logic_vector(NLINK-1 downto 0);
      rxbyteisaligned_out : out std_logic_vector(NLINK-1 downto 0);
      rxbyterealign_out : out std_logic_vector(NLINK-1 downto 0);
      rxcommadet_out : out std_logic_vector(NLINK-1 downto 0);
      rxctrl0_out : out std_logic_vector(16*NLINK-1 downto 0);
      rxctrl1_out : out std_logic_vector(16*NLINK-1 downto 0);
      rxctrl2_out : out std_logic_vector(8*NLINK-1 downto 0);
      rxctrl3_out : out std_logic_vector(8*NLINK-1 downto 0);
      rxpmaresetdone_out : out std_logic_vector(NLINK-1 downto 0);
      rxprbserr_out : out std_logic_vector(NLINK-1 downto 0);
      rxprbslocked_out : out std_logic_vector(NLINK-1 downto 0);
      txpmaresetdone_out : out std_logic_vector(NLINK-1 downto 0)
      );
  end component;

  component gtwiz_example_init is
    port (
      clk_freerun_in : in std_logic := '0';
      reset_all_in : in std_logic := '0';
      tx_init_done_in : in std_logic := '0';
      rx_init_done_in : in std_logic := '0';
      rx_data_good_in : in std_logic := '0';
      reset_all_out : out std_logic := '0';
      reset_rx_out : out std_logic := '0';
      init_done_out : out std_logic := '0';
      retry_ctr_out : out std_logic_vector(3 downto 0) := (others=> '0')
      );
  end component;

  constant IDLE : std_logic_vector(DATAWIDTH-1 downto 0) := x"50BC"; -- IDLE word for 16 bit width

  -- Synchronize the latched link down reset input and the VIO-driven signal into the free-running clock domain
  -- signals passed to wizard
  signal gthrxn_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal gthrxp_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal gthtxn_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal gthtxp_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
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
  signal gtwiz_reset_all_int : std_logic := '0';
  signal gtwiz_reset_tx_pll_and_datapath_int : std_logic := '0';
  signal gtwiz_reset_tx_datapath_int : std_logic := '0';
  signal gtwiz_reset_rx_pll_and_datapath_int : std_logic := '0';
  signal gtwiz_reset_rx_datapath_int : std_logic := '0';
  signal gtwiz_reset_rx_cdr_stable_int : std_logic := '0';
  signal gtwiz_reset_tx_done_int : std_logic := '0';
  signal gtwiz_reset_rx_done_int : std_logic := '0';
  signal gtwiz_userdata_tx_int : std_logic_vector(NLINK*DATAWIDTH-1 downto 0) := (others => '0');
  signal gtwiz_userdata_rx_int : std_logic_vector(NLINK*DATAWIDTH-1 downto 0) := (others => '0');
  signal drpclk_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal txctrl2_int : std_logic_vector(8*NLINK-1 downto 0) := (others => '0');
  signal gtpowergood_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxbyteisaligned_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxbyterealign_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxcommadet_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxctrl0_int : std_logic_vector(16*NLINK-1 downto 0) := (others => '0');
  signal rxctrl1_int : std_logic_vector(16*NLINK-1 downto 0) := (others => '0');
  signal rxctrl2_int : std_logic_vector(8*NLINK-1 downto 0) := (others => '0');
  signal rxctrl3_int : std_logic_vector(8*NLINK-1 downto 0) := (others => '0');
  signal rxpmaresetdone_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal txpmaresetdone_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');

  -- signal txdiffctrl_int : std_logic_vector(7 downto 0) := (others=> '0');
  -- -- signals local to this wrapper
  -- signal hb0_gtwiz_userclk_tx_reset_int : std_logic := '0';
  -- signal hb0_gtwiz_userclk_rx_reset_int : std_logic := '0';
  -- signal hb0_gtwiz_userclk_tx_srcclk_int : std_logic := '0';
  -- signal hb0_gtwiz_userclk_tx_usrclk_int : std_logic := '0';
  -- signal hb0_gtwiz_userclk_tx_usrclk2_int : std_logic := '0';
  -- signal hb0_gtwiz_userclk_tx_active_int : std_logic := '0';
  -- signal hb0_gtwiz_userclk_rx_srcclk_int : std_logic := '0';
  -- signal hb0_gtwiz_userclk_rx_usrclk_int : std_logic := '0';
  -- signal hb0_gtwiz_userclk_rx_usrclk2_int : std_logic := '0';
  -- signal hb0_gtwiz_userclk_rx_active_int : std_logic := '0';

  -- reset related
  -- signal hb0_gtwiz_reset_tx_pll_and_datapath_int : std_logic := '0';
  -- signal hb0_gtwiz_reset_tx_datapath_int : std_logic := '0';
  -- signal hb_gtwiz_reset_rx_datapath_init_int : std_logic := '0';
  -- signal gtwiz_reset_rx_pll_and_datapath_int : std_logic := '0';
  -- signal gtwiz_reset_rx_datapath_int : std_logic := '0';

  -- ref clock
  signal gtrefclk0_int : std_logic := '0';

  -- rx helper signals
  signal ch0_rxcharisk : std_logic_vector(DATAWIDTH/8-1 downto 0);
  signal ch0_rxdisperr : std_logic_vector(DATAWIDTH/8-1 downto 0);
  signal ch0_rxnotintable : std_logic_vector(DATAWIDTH/8-1 downto 0);
  signal ch0_rxchariscomma : std_logic_vector(DATAWIDTH/8-1 downto 0);
  signal ch0_codevalid : std_logic_vector(DATAWIDTH/8-1 downto 0);

  signal bad_rx_int : std_logic_vector(NLINK-1 downto 0);
  signal rxready_int : std_logic;

  -- GT control
  signal loopback_int : std_logic_vector(3*NLINK-1 downto 0) := (others=> '0');
  signal rxprbscntreset_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxprbssel_int : std_logic_vector(4*NLINK-1 downto 0) := (others => '0');
  signal rxprbserr_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxprbslocked_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal txprbsforceerr_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal txprbssel_int : std_logic_vector(4*NLINK-1 downto 0) := (others => '0');

  signal rxpd_int : std_logic_vector(2*NLINK-1 downto 0) := (others => '0');
  signal txpd_int : std_logic_vector(2*NLINK-1 downto 0) := (others => '0');

  -- debug signals
  signal ila_data_rx: std_logic_vector(191 downto 0) := (others=> '0');
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
  gthrxn_int(0) <= daq_rx_n;
  gthrxp_int(0) <= daq_rx_p;

  ---------------------------------------------------------------------------------------------------------------------
  -- User data ports
  ---------------------------------------------------------------------------------------------------------------------
  RXDATA <= gtwiz_userdata_rx_int(DATAWIDTH-1 downto 0);

  ch0_rxcharisk <= rxctrl0_int(DATAWIDTH/8-1 downto 0);
  ch0_rxdisperr <= rxctrl1_int(DATAWIDTH/8-1 downto 0);
  ch0_rxchariscomma <= rxctrl2_int(DATAWIDTH/8-1 downto 0);
  ch0_rxnotintable <= rxctrl3_int(DATAWIDTH/8-1 downto 0);

  ch0_codevalid <= not (ch0_rxnotintable or ch0_rxdisperr); -- May need to sync the input signals
  bad_rx_int(0) <= not (rxbyteisaligned_int(0) and (not rxbyterealign_int(0)));

  BAD_RX <= bad_rx_int;

  RXREADY <= rxready_int;
  rxready_int <= gtwiz_userclk_rx_active_int and gtwiz_reset_rx_done_int;

  -- RXDATA is valid only when it's been deemed aligned, recognized 8B/10B pattern and does not contain a K-character.
  -- The RXVALID port is not explained in UG576, so it's not used.
  RXD_VALID(0) <= '1' when (rxready_int = '1' and bad_rx_int(0) = '0' and and_reduce(ch0_codevalid) = '1' and or_reduce(ch0_rxchariscomma) = '0') else '0';

  -- MGT reference clk
  gtrefclk0_int <= MGTREFCLK;

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
  -- gtwiz_reset_rx_datapath_int <= hb_gtwiz_reset_rx_datapath_init_int;
  -- gtwiz_reset_tx_datapath_int <= hb0_gtwiz_reset_tx_datapath_int;

  ---------------------------------------------------------------------------------------------------------------------
  -- Duplicating GT control inputs for all channels
  ---------------------------------------------------------------------------------------------------------------------
  rxprbscntreset_int <= (others => RESET);
  rxprbssel_int(3 downto 0) <= PRBS_TYPE when PRBS_RX_EN(0) = '1' else x"0";

  -- rxprbserr_int  -- TODO: later
  -- rxprbslocked_int -- TODO: later
  -- txprbsforceerr_int -- TODO: later

  ---------------------------------------------------------------------------------------------------------------------
  -- EXAMPLE WRAPPER INSTANCE
  ---------------------------------------------------------------------------------------------------------------------
  alct_wrapper_inst : gtwiz_alct_r1_example_wrapper
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
      gtwiz_reset_all_in                 => gtwiz_reset_all_int,
      gtwiz_reset_tx_pll_and_datapath_in => gtwiz_reset_tx_pll_and_datapath_int,
      gtwiz_reset_tx_datapath_in         => gtwiz_reset_tx_datapath_int,
      gtwiz_reset_rx_pll_and_datapath_in => gtwiz_reset_rx_pll_and_datapath_int,
      gtwiz_reset_rx_datapath_in         => gtwiz_reset_rx_datapath_int,
      gtwiz_reset_rx_cdr_stable_out      => gtwiz_reset_rx_cdr_stable_int,
      gtwiz_reset_tx_done_out            => gtwiz_reset_tx_done_int,
      gtwiz_reset_rx_done_out            => gtwiz_reset_rx_done_int,
      gtwiz_userdata_tx_in               => gtwiz_userdata_tx_int,
      gtwiz_userdata_rx_out              => gtwiz_userdata_rx_int,
      drpclk_in                          => drpclk_int,
      gtrefclk0_in                       => gtrefclk0_int,
      rx8b10ben_in                       => (others => '1'),
      rxcommadeten_in                    => (others => '1'),
      rxmcommaalignen_in                 => (others => '1'),
      rxpcommaalignen_in                 => (others => '1'),
      rxpd_in                            => rxpd_int,
      rxprbscntreset_in                  => rxprbscntreset_int,
      rxprbssel_in                       => rxprbssel_int,
      tx8b10ben_in                       => (others => '1'),
      txctrl0_in                         => (others => '0'),  -- not used in 8b10b
      txctrl1_in                         => (others => '0'),  -- not used in 8b10b
      txctrl2_in                         => (others => '0'),  -- not using TX
      txpd_in                            => (others => '1'),  -- TX disabled by "11"
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


end Behavioral;
