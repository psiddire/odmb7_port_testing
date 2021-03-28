--------------------------------------------------------------------------------
-- MGT wrapper
-- Based on example design
--------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.ucsb_types.all;

library UNISIM;
use UNISIM.VComponents.all;

use ieee.std_logic_misc.all;

entity mgt_cfeb is
  generic (
    NLINK     : integer range 1 to 20 := 7;  -- number of links
    DATAWIDTH : integer := 16                -- user data width
    );
  port (
    -- Clocks
    mgtrefclk   : in  std_logic; -- buffer'ed reference clock signal
    rxusrclk    : out std_logic; -- USRCLK for RX data readout
    sysclk      : in  std_logic; -- clock for the helper block, 80 MHz

    -- Serial data ports for transceiver at bank 224-225
    daq_rx_n    : in  std_logic_vector(NLINK-1 downto 0);
    daq_rx_p    : in  std_logic_vector(NLINK-1 downto 0);

    -- Receiver signals
    rxdata_feb1 : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
    rxdata_feb2 : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
    rxdata_feb3 : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
    rxdata_feb4 : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
    rxdata_feb5 : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
    rxdata_feb6 : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
    rxdata_feb7 : out std_logic_vector(DATAWIDTH-1 downto 0);  -- Data received
    rxd_valid   : out std_logic_vector(NLINK downto 1);   -- Flag for valid data
    crc_valid   : out std_logic_vector(NLINK downto 1);   -- Flag for valid CRC check
    bad_rx      : out std_logic_vector(NLINK downto 1);   -- Flag for fiber errors
    rxready     : out std_logic; -- Flag for rx reset done

    -- CFEB data FIFO full signals
    fifo_full   : in std_logic_vector(NLINK downto 1);   -- Flag for FIFO full
    fifo_afull  : in std_logic_vector(NLINK downto 1);   -- Flag for FIFO almost full

    -- PRBS signals
    prbs_type    : in  std_logic_vector(3 downto 0);
    prbs_rx_en   : in  std_logic_vector(NLINK downto 1);
    prbs_tst_cnt : in  std_logic_vector(15 downto 0);
    prbs_err_cnt : out std_logic_vector(15 downto 0);

    -- Reset
    reset        : in  std_logic
    );
end mgt_cfeb;

architecture Behavioral of mgt_cfeb is

  --------------------------------------------------------------------------
  -- Component declaration for the GTH transceiver container
  --------------------------------------------------------------------------
  component gtwiz_cfeb_r7_example_wrapper
    port (
      gthrxn_in : in std_logic_vector(6 downto 0);
      gthrxp_in : in std_logic_vector(6 downto 0);
      gthtxn_out : out std_logic_vector(6 downto 0);
      gthtxp_out : out std_logic_vector(6 downto 0);
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
      gtwiz_userdata_tx_in : in std_logic_vector(111 downto 0);
      gtwiz_userdata_rx_out : out std_logic_vector(111 downto 0);
      gtrefclk00_in : in std_logic_vector(1 downto 0);
      qpll0outclk_out : out std_logic_vector(1 downto 0);
      qpll0outrefclk_out : out std_logic_vector(1 downto 0);
      rx8b10ben_in : in std_logic_vector(6 downto 0);
      rxcommadeten_in : in std_logic_vector(6 downto 0);
      rxmcommaalignen_in : in std_logic_vector(6 downto 0);
      rxpcommaalignen_in : in std_logic_vector(6 downto 0);
      rxpd_in : in std_logic_vector(13 downto 0);
      rxprbscntreset_in : in std_logic_vector(6 downto 0);
      rxprbssel_in : in std_logic_vector(27 downto 0);
      tx8b10ben_in : in std_logic_vector(6 downto 0);
      txctrl0_in : in std_logic_vector(111 downto 0);
      txctrl1_in : in std_logic_vector(111 downto 0);
      txctrl2_in : in std_logic_vector(55 downto 0);
      txpd_in : in std_logic_vector(13 downto 0);
      gtpowergood_out : out std_logic_vector(6 downto 0);
      rxbyteisaligned_out : out std_logic_vector(6 downto 0);
      rxbyterealign_out : out std_logic_vector(6 downto 0);
      rxcommadet_out : out std_logic_vector(6 downto 0);
      rxctrl0_out : out std_logic_vector(111 downto 0);
      rxctrl1_out : out std_logic_vector(111 downto 0);
      rxctrl2_out : out std_logic_vector(55 downto 0);
      rxctrl3_out : out std_logic_vector(55 downto 0);
      rxpmaresetdone_out : out std_logic_vector(6 downto 0);
      rxprbserr_out : out std_logic_vector(6 downto 0);
      rxprbslocked_out : out std_logic_vector(6 downto 0);
      txpmaresetdone_out : out std_logic_vector(6 downto 0)
      );
  end component;

  component rx_frame_proc
    port (
      -- Inputs
      CLK : in std_logic;
      RST : in std_logic;                        -- reset signal from VMEMON
      RXDATA : in std_logic_vector(15 downto 0); -- direct rxdata out from gt wrapper
      RX_IS_K : in std_logic_vector(1 downto 0);
      RXDISPERR : in std_logic_vector(1 downto 0);
      RXNOTINTABLE : in std_logic_vector(1 downto 0);
      -- FIFO (almost) full inputs, triggers error state
      FF_FULL : in std_logic;
      FF_AF : in std_logic;
      -- Client outputs
      FRM_DATA : out std_logic_vector(15 downto 0);
      FRM_DATA_VALID : out std_logic;
      GOOD_CRC : out std_logic;
      CRC_CHK_VLD : out std_logic
      );
  end component;

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
  signal gtwiz_reset_all_int : std_logic;
  signal gtwiz_reset_tx_pll_and_datapath_int : std_logic := '0';
  signal gtwiz_reset_tx_datapath_int : std_logic := '0';
  signal gtwiz_reset_rx_pll_and_datapath_int : std_logic := '0';
  signal gtwiz_reset_rx_datapath_int : std_logic := '0';
  signal gtwiz_reset_rx_cdr_stable_int : std_logic := '0';
  signal gtwiz_reset_tx_done_int : std_logic := '0';
  signal gtwiz_reset_rx_done_int : std_logic := '0';
  signal gtwiz_userdata_tx_int : std_logic_vector(NLINK*DATAWIDTH-1 downto 0) := (others => '0');
  signal gtwiz_userdata_rx_int : std_logic_vector(NLINK*DATAWIDTH-1 downto 0) := (others => '0');
  -- signal drpclk_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
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

  signal hb_gtwiz_reset_all_int : std_logic := '0';

  -- ref clock
  signal gtrefclk0_int : std_logic := '0';
  signal gtrefclk00_int : std_logic_vector(1 downto 0);
  signal qpll0outclk_int : std_logic_vector(1 downto 0);
  signal qpll0outrefclk_int : std_logic_vector(1 downto 0);

  -- RX helper signals in channel number: ch(I) = feb(I-1)
  type t_rxd_nbyte_arr is array (integer range <>) of std_logic_vector(DATAWIDTH/8-1 downto 0);
  signal rxcharisk_ch : t_rxd_nbyte_arr(NLINK-1 downto 0);
  signal rxdisperr_ch : t_rxd_nbyte_arr(NLINK-1 downto 0);
  signal rxnotintable_ch : t_rxd_nbyte_arr(NLINK-1 downto 0);
  signal rxchariscomma_ch : t_rxd_nbyte_arr(NLINK-1 downto 0);
  signal codevalid_ch : t_rxd_nbyte_arr(NLINK-1 downto 0);

  -- internal signals based on channel number
  signal rxd_valid_ch : std_logic_vector(NLINK-1 downto 0);
  signal bad_rx_ch : std_logic_vector(NLINK-1 downto 0);
  signal good_crc_ch : std_logic_vector(NLINK-1 downto 0);
  signal crc_valid_ch : std_logic_vector(NLINK-1 downto 0);
  signal rxready_int : std_logic;

  -- delayed signal from rx_frame_proc
  type t_rxd_arr is array (integer range <>) of std_logic_vector(DATAWIDTH-1 downto 0);
  signal rxdata_checked_ch  : t_rxd_arr(NLINK-1 downto 0);

  -- Preset constants
  signal rx8b10ben_int : std_logic_vector(NLINK-1 downto 0) := (others => '1');
  signal rxcommadeten_int : std_logic_vector(NLINK-1 downto 0) := (others => '1');
  signal rxmcommaalignen_int : std_logic_vector(NLINK-1 downto 0) := (others => '1');
  signal rxpcommaalignen_int : std_logic_vector(NLINK-1 downto 0) := (others => '1');
  signal txctrl0_int : std_logic_vector(16*NLINK-1 downto 0) := (others => '0');
  signal txctrl1_int : std_logic_vector(16*NLINK-1 downto 0) := (others => '0');
  signal txctrl2_int : std_logic_vector(8*NLINK-1 downto 0) := (others => '0');

  signal txpd_int : std_logic_vector(2*NLINK-1 downto 0) := (others => '1');

  -- GT control
  signal loopback_int : std_logic_vector(3*NLINK-1 downto 0) := (others=> '0');
  signal rxprbscntreset_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxprbssel_int : std_logic_vector(4*NLINK-1 downto 0) := (others => '0');
  signal rxprbserr_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxprbslocked_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');

  signal rxpd_int : std_logic_vector(2*NLINK-1 downto 0) := (others => '0');

  -- debug signals
  signal ila_data_rx: std_logic_vector(191 downto 0) := (others=> '0');

begin

  ---------------------------------------------------------------------------------------------------------------------
  -- User data ports, note change between channel number and cfeb number
  ---------------------------------------------------------------------------------------------------------------------
  RXDATA_FEB1 <= rxdata_checked_ch(0);
  RXDATA_FEB2 <= rxdata_checked_ch(1);
  RXDATA_FEB3 <= rxdata_checked_ch(2);
  RXDATA_FEB4 <= rxdata_checked_ch(3);
  RXDATA_FEB5 <= rxdata_checked_ch(4);
  u_mgt_port_assign_7 : if NLINK >= 7 generate
    RXDATA_FEB6 <= rxdata_checked_ch(5);
    RXDATA_FEB7 <= rxdata_checked_ch(6);
  end generate;

  RXD_VALID <= rxd_valid_ch;
  CRC_VALID <= crc_valid_ch;
  BAD_RX <= bad_rx_ch;

  gen_rx_quality : for I in 0 to NLINK-1 generate
  begin
    rxcharisk_ch(I)     <= rxctrl0_int(16*I+DATAWIDTH/8-1 downto 16*I);
    rxdisperr_ch(I)     <= rxctrl1_int(16*I+DATAWIDTH/8-1 downto 16*I);
    rxchariscomma_ch(I) <= rxctrl2_int(8*I+DATAWIDTH/8-1 downto 8*I);
    rxnotintable_ch(I)  <= rxctrl3_int(8*I+DATAWIDTH/8-1 downto 8*I);

    bad_rx_ch(I) <= '1' when (rxbyteisaligned_int(I) = '0') or (rxbyterealign_int(I) = '1') or (or_reduce(rxdisperr_ch(I)) = '1') else '0';

    -- Module for RXDATA validity checks, working for 16 bit datawidth only
    rx_data_check_i : rx_frame_proc
      port map (
        CLK => gtwiz_userclk_rx_usrclk2_int,
        RST => reset,
        RXDATA => gtwiz_userdata_rx_int((I+1)*DATAWIDTH-1 downto I*DATAWIDTH),
        RX_IS_K => rxcharisk_ch(I),
        RXDISPERR => rxdisperr_ch(I),
        RXNOTINTABLE => rxnotintable_ch(I),
        FF_FULL => FIFO_FULL(I+1),
        FF_AF => FIFO_AFULL(I+1),
        FRM_DATA => rxdata_checked_ch(I),
        FRM_DATA_VALID => rxd_valid_ch(I),
        GOOD_CRC => good_crc_ch(I),    -- CRC is checked, but signal is not used
        CRC_CHK_VLD => crc_valid_ch(I) -- used for CRC counting 
        );

    -- Duplicating GT control inputs for all channels
    rxprbssel_int(4*I+3 downto 4*I) <= PRBS_TYPE when PRBS_RX_EN(I+1) = '1' else x"0";
  end generate gen_rx_quality;

  RXREADY <= rxready_int;
  rxready_int <= gtwiz_userclk_rx_active_int and gtwiz_reset_rx_done_int;

  -- MGT reference clk
  gtrefclk00_int <= (others => MGTREFCLK);
  RXUSRCLK <= gtwiz_userclk_rx_usrclk2_int;

  ---------------------------------------------------------------------------------------------------------------------
  -- USER CLOCKING RESETS
  ---------------------------------------------------------------------------------------------------------------------
  -- The TX/RX user clocking helper block should be held in reset until the clock source of that block is known to be
  -- stable. The following assignment is an example of how that stability can be determined, based on the selected TX/RX
  -- user clock source. Replace the assignment with the appropriate signal or logic to achieve that behavior as needed.
  gtwiz_userclk_tx_reset_int <= '0'; -- not using TX at all
  gtwiz_userclk_rx_reset_int <= nand_reduce(rxpmaresetdone_int);

  -- Declare signals which connect the VIO instance to the initialization module for debug purposes
  -- leave it untouched in this vhdl example
  -- TODO: leave the individual reset for now, only use one big reset
  gtwiz_reset_all_int <= RESET;
  rxprbscntreset_int <= (others => RESET);

  -- Potential useful individual reset signals
  -- gtwiz_reset_tx_datapath_int <= hb0_gtwiz_reset_tx_datapath_int;
  -- gtwiz_reset_tx_pll_and_datapath_int <= hb0_gtwiz_reset_tx_pll_and_datapath_int;
  -- gtwiz_reset_rx_datapath_int <= hb_gtwiz_reset_rx_datapath_init_int or hb_gtwiz_reset_rx_datapath_vio_int;

  ---------------------------------------------------------------------------------------------------------------------
  -- EXAMPLE WRAPPER INSTANCE
  ---------------------------------------------------------------------------------------------------------------------
  cfeb_wrapper_inst : gtwiz_cfeb_r7_example_wrapper
    port map (
      gthrxn_in                          => DAQ_RX_N,
      gthrxp_in                          => DAQ_RX_P,
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
      gtrefclk00_in                      => gtrefclk00_int,
      qpll0outclk_out                    => qpll0outclk_int,
      qpll0outrefclk_out                 => qpll0outrefclk_int,
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
      txpd_in                            => (others => '1'),  -- all TX disabled by "11"
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
