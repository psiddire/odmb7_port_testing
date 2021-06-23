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
use work.odmb7_components.all;

library UNISIM;
use UNISIM.VComponents.all;

use ieee.std_logic_misc.all;

entity mgt_cfeb_mod is
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
    kill_rxout  : in  std_logic_vector(NLINK downto 1);   -- Kill DCFEB by no output
    kill_rxpd   : in  std_logic_vector(NLINK downto 1);   -- Kill bad DCFEB with power down RX

    -- CFEB data FIFO full signals
    fifo_full   : in std_logic_vector(NLINK downto 1);   -- Flag for FIFO full
    fifo_afull  : in std_logic_vector(NLINK downto 1);   -- Flag for FIFO almost full

    -- PRBS signals
    -- prbs_type    : in  std_logic_vector(3 downto 0);
    -- prbs_rx_en   : in  std_logic_vector(NLINK downto 1);
    -- prbs_tst_cnt : in  std_logic_vector(15 downto 0);
    -- prbs_err_cnt : out std_logic_vector(15 downto 0);

    -- Reset
    reset        : in  std_logic
    );
end mgt_cfeb_mod;

architecture Behavioral of mgt_cfeb_mod is

  --------------------------------------------------------------------------
  -- Component declaration moved to odmb7_components.vhd 
  --------------------------------------------------------------------------

  -- Temporary debugging
  component ila_cfeb is
    port (
      clk : in std_logic := '0';
      probe0 : in std_logic_vector(424 downto 0) := (others=> '0')
      );
  end component;

  --------------------------------------------------------
  -- unused signals from previous version is commented out 
  --------------------------------------------------------

  --signal gthrxn_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  --signal gthrxp_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal gthtxn_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal gthtxp_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal gtwiz_userclk_tx_reset_int : std_logic := '0';
  --signal gtwiz_userclk_tx_srcclk_int : std_logic := '0';
  --signal gtwiz_userclk_tx_usrclk_int : std_logic := '0';
  --signal gtwiz_userclk_tx_usrclk2_int : std_logic := '0';
  --signal gtwiz_userclk_tx_active_int : std_logic := '0';
  signal gtwiz_userclk_rx_reset_int : std_logic := '0';
  --signal gtwiz_userclk_rx_srcclk_int : std_logic := '0';
  --signal gtwiz_userclk_rx_usrclk_int : std_logic := '0';
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
  signal gtwiz_reset_rxreset_out : std_logic := '0';
  signal gtwiz_userdata_tx_int : std_logic_vector(NLINK*DATAWIDTH-1 downto 0) := (others => '0');
  signal gtwiz_userdata_rx_int : std_logic_vector(NLINK*DATAWIDTH-1 downto 0) := (others => '0');
  signal drpclk_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal gtpowergood_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal cplllock_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxbyteisaligned_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxbyterealign_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxcommadet_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxctrl0_int : std_logic_vector(16*NLINK-1 downto 0) := (others => '0');
  signal rxctrl1_int : std_logic_vector(16*NLINK-1 downto 0) := (others => '0');
  signal rxctrl2_int : std_logic_vector(8*NLINK-1 downto 0) := (others => '0');
  signal rxctrl3_int : std_logic_vector(8*NLINK-1 downto 0) := (others => '0');
  signal rxpmaresetdone_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal txpmaresetdone_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  signal rxbufstatus_int : std_logic_vector(3*NLINK-1 downto 0) := (others => '0');
  signal rxclkcorcnt_int : std_logic_vector(2*NLINK-1 downto 0) := (others => '0');

  signal hb_gtwiz_reset_all_int : std_logic := '0';

  -- ref clock
  signal gtrefclk0_int : std_logic_vector(6 downto 0);
  --signal gtrefclk00_int : std_logic_vector(1 downto 0);
  --signal qpll0outclk_int : std_logic_vector(1 downto 0);
  --signal qpll0outrefclk_int : std_logic_vector(1 downto 0);

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

  type t_rxd_arr is array (integer range <>) of std_logic_vector(DATAWIDTH-1 downto 0);
  signal rxdata_i_ch  : t_rxd_arr(NLINK-1 downto 0); -- rx userdata out of mgt wrapper
  signal rxdata_o_ch  : t_rxd_arr(NLINK-1 downto 0); -- delayed signal from rx_frame_proc
  signal rxbufreset_int : std_logic_vector(6 downto 0);

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
  --signal loopback_int : std_logic_vector(3*NLINK-1 downto 0) := (others=> '0');
  --signal rxprbscntreset_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  --signal rxprbssel_int : std_logic_vector(4*NLINK-1 downto 0) := (others => '0');
  --signal rxprbserr_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');
  --signal rxprbslocked_int : std_logic_vector(NLINK-1 downto 0) := (others => '0');

  signal rxpd_int : std_logic_vector(2*NLINK-1 downto 0) := (others => '0');

  -- debug signals
  signal ila_data_rx : std_logic_vector(424 downto 0) := (others=> '0');
  type t_ilad_arr is array (integer range <>) of std_logic_vector(47 downto 0);
  signal ila_data_ch : t_ilad_arr(NLINK-1 downto 0);

  -- vio signals
  signal gtwiz_reset_all_vio_int : std_logic := '0';
  signal gtwiz_reset_tx_pll_and_datapath_vio_int : std_logic := '0';
  signal gtwiz_reset_tx_datapath_vio_int : std_logic := '0';
  signal gtwiz_reset_rx_pll_and_datapath_vio_int : std_logic := '0';
  signal gtwiz_reset_rx_datapath_vio_int : std_logic := '0';
  signal gtwiz_reset_rx_buf_vio_int : std_logic_vector(6 downto 0) := (others => '0');

  signal gtpowergood_vio_sync : std_logic_vector(6 downto 0) := (others => '0');
  signal txpmaresetdone_vio_sync : std_logic_vector(6 downto 0) := (others => '0');
  signal rxpmaresetdone_vio_sync : std_logic_vector(6 downto 0) := (others => '0');
  signal gtwiz_reset_tx_done_vio_sync : std_logic := '0';
  signal gtwiz_reset_rx_done_vio_sync : std_logic := '0';

  attribute DONT_TOUCH : string;

  attribute DONT_TOUCH of bit_sync_vio_gtpowergood_0_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_gtpowergood_1_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_gtpowergood_2_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_gtpowergood_3_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_gtpowergood_4_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_gtpowergood_5_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_gtpowergood_6_inst: label is "TRUE";

  attribute DONT_TOUCH of bit_sync_vio_txpmaresetdone_0_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_txpmaresetdone_1_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_txpmaresetdone_2_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_txpmaresetdone_3_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_txpmaresetdone_4_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_txpmaresetdone_5_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_txpmaresetdone_6_inst: label is "TRUE";

  attribute DONT_TOUCH of bit_sync_vio_rxpmaresetdone_0_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_rxpmaresetdone_1_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_rxpmaresetdone_2_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_rxpmaresetdone_3_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_rxpmaresetdone_4_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_rxpmaresetdone_5_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_rxpmaresetdone_6_inst: label is "TRUE";

  attribute DONT_TOUCH of bit_sync_vio_gtwiz_reset_tx_done_inst: label is "TRUE";
  attribute DONT_TOUCH of bit_sync_vio_gtwiz_reset_rx_done_inst: label is "TRUE";
begin

  ---------------------------------------------------------------------------------------------------------------------
  -- User data ports, note change between channel number and cfeb number
  ---------------------------------------------------------------------------------------------------------------------
  RXDATA_FEB1 <= rxdata_o_ch(0);
  RXDATA_FEB2 <= rxdata_o_ch(1);
  RXDATA_FEB3 <= rxdata_o_ch(2);
  RXDATA_FEB4 <= rxdata_o_ch(3);
  RXDATA_FEB5 <= rxdata_o_ch(4);
  u_mgt_port_assign_7 : if NLINK >= 7 generate
    RXDATA_FEB6 <= rxdata_o_ch(5);
    RXDATA_FEB7 <= rxdata_o_ch(6);
  end generate;

  --RXD_VALID <= rxd_valid_ch and (not KILL_RXOUT) when rxready_int = '1' else (others => '0');
  --CRC_VALID <= crc_valid_ch and (not KILL_RXOUT) when rxready_int = '1' else (others => '0');
  BAD_RX <= bad_rx_ch;

  bit_sync_vio_gtpowergood_0_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => gtpowergood_int(0), o_out => gtpowergood_vio_sync(0));
  bit_sync_vio_gtpowergood_1_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => gtpowergood_int(1), o_out => gtpowergood_vio_sync(1));
  bit_sync_vio_gtpowergood_2_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => gtpowergood_int(2), o_out => gtpowergood_vio_sync(2));
  bit_sync_vio_gtpowergood_3_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => gtpowergood_int(3), o_out => gtpowergood_vio_sync(3));
  bit_sync_vio_gtpowergood_4_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => gtpowergood_int(4), o_out => gtpowergood_vio_sync(4));
  bit_sync_vio_gtpowergood_5_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => gtpowergood_int(5), o_out => gtpowergood_vio_sync(5));
  bit_sync_vio_gtpowergood_6_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => gtpowergood_int(6), o_out => gtpowergood_vio_sync(6));

  bit_sync_vio_txpmaresetdone_0_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => txpmaresetdone_int(0), o_out => txpmaresetdone_vio_sync(0));
  bit_sync_vio_txpmaresetdone_1_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => txpmaresetdone_int(1), o_out => txpmaresetdone_vio_sync(1));
  bit_sync_vio_txpmaresetdone_2_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => txpmaresetdone_int(2), o_out => txpmaresetdone_vio_sync(2));
  bit_sync_vio_txpmaresetdone_3_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => txpmaresetdone_int(3), o_out => txpmaresetdone_vio_sync(3));
  bit_sync_vio_txpmaresetdone_4_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => txpmaresetdone_int(4), o_out => txpmaresetdone_vio_sync(4));
  bit_sync_vio_txpmaresetdone_5_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => txpmaresetdone_int(5), o_out => txpmaresetdone_vio_sync(5));
  bit_sync_vio_txpmaresetdone_6_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => txpmaresetdone_int(6), o_out => txpmaresetdone_vio_sync(6));

  bit_sync_vio_rxpmaresetdone_0_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => rxpmaresetdone_int(0), o_out => rxpmaresetdone_vio_sync(0));
  bit_sync_vio_rxpmaresetdone_1_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => rxpmaresetdone_int(1), o_out => rxpmaresetdone_vio_sync(1));
  bit_sync_vio_rxpmaresetdone_2_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => rxpmaresetdone_int(2), o_out => rxpmaresetdone_vio_sync(2));
  bit_sync_vio_rxpmaresetdone_3_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => rxpmaresetdone_int(3), o_out => rxpmaresetdone_vio_sync(3));
  bit_sync_vio_rxpmaresetdone_4_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => rxpmaresetdone_int(4), o_out => rxpmaresetdone_vio_sync(4));
  bit_sync_vio_rxpmaresetdone_5_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => rxpmaresetdone_int(5), o_out => rxpmaresetdone_vio_sync(5));
  bit_sync_vio_rxpmaresetdone_6_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => rxpmaresetdone_int(6), o_out => rxpmaresetdone_vio_sync(6));
  
  bit_sync_vio_gtwiz_reset_tx_done_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => gtwiz_reset_tx_done_int, o_out => gtwiz_reset_tx_done_vio_sync);
  bit_sync_vio_gtwiz_reset_rx_done_inst : gtwizard_ultrascale_0_example_bit_synchronizer port map (clk_in => SYSCLK, i_in => gtwiz_reset_rx_done_int, o_out => gtwiz_reset_rx_done_vio_sync);

  gen_rx_quality : for I in 0 to NLINK-1 generate
  begin

    --rxdata_i_ch(I)      <= gtwiz_userdata_rx_int((I+1)*DATAWIDTH-1 downto I*DATAWIDTH);
    rxdata_o_ch(I)      <= gtwiz_userdata_rx_int((I+1)*DATAWIDTH-1 downto I*DATAWIDTH);
    rxcharisk_ch(I)     <= rxctrl0_int(16*I+DATAWIDTH/8-1 downto 16*I);
    rxdisperr_ch(I)     <= rxctrl1_int(16*I+DATAWIDTH/8-1 downto 16*I);
    rxchariscomma_ch(I) <= rxctrl2_int(8*I+DATAWIDTH/8-1 downto 8*I);
    rxnotintable_ch(I)  <= rxctrl3_int(8*I+DATAWIDTH/8-1 downto 8*I);

    bad_rx_ch(I) <= '1' when (rxbyteisaligned_int(I) = '0') or (rxbyterealign_int(I) = '1') or (or_reduce(rxdisperr_ch(I)) = '1') else '0';

    -- Power down the RX for killed DCFEB
    --rxpd_int(2*I+1 downto 2*I) <= "11" when KILL_RXPD(I+1) = '1' else "00";

    -- Module for RXDATA validity checks, working for 16 bit datawidth only
    --rx_data_check_i : rx_frame_proc
    --  port map (
    --    CLK => gtwiz_userclk_rx_usrclk2_int,
    --    RST => reset or KILL_RXOUT(I+1),
    --    RXDATA => rxdata_i_ch(I),
    --    RX_IS_K => rxcharisk_ch(I),
    --    RXDISPERR => rxdisperr_ch(I),
    --    RXNOTINTABLE => rxnotintable_ch(I),
    --    FF_FULL => FIFO_FULL(I+1),
    --    FF_AF => FIFO_AFULL(I+1),
    --    FRM_DATA => rxdata_o_ch(I),
    --    FRM_DATA_VALID => rxd_valid_ch(I),
    --    GOOD_CRC => good_crc_ch(I),    -- CRC is checked, but signal is not used
    --    CRC_CHK_VLD => crc_valid_ch(I) -- used for CRC counting 
    --    );

  end generate gen_rx_quality;

  RXREADY <= rxready_int;
  rxready_int <= gtwiz_userclk_rx_active_int and gtwiz_reset_rx_done_int;

  -- MGT reference clk
  gtrefclk0_int <= (others => MGTREFCLK);
  drpclk_int <= (others => SYSCLK);
  RXUSRCLK <= gtwiz_userclk_rx_usrclk2_int;
  ---------------------------------------------------------------------------------------------------------------------
  -- USER CLOCKING RESETS
  ---------------------------------------------------------------------------------------------------------------------
  -- The TX/RX user clocking helper block should be held in reset until the clock source of that block is known to be
  -- stable. The following assignment is an example of how that stability can be determined, based on the selected TX/RX
  -- user clock source. Replace the assignment with the appropriate signal or logic to achieve that behavior as needed.
  --gtwiz_userclk_tx_reset_int <= '0'; -- not using TX at all
  gtwiz_userclk_tx_reset_int <= nand_reduce(txpmaresetdone_int);
  gtwiz_userclk_rx_reset_int <= nand_reduce(rxpmaresetdone_int);

  -- Declare signals which connect the VIO instance to the initialization module for debug purposes
  -- leave it untouched in this vhdl example
  -- TODO: leave the individual reset for now, only use one big reset
  --gtwiz_reset_all_int <= RESET or gtwiz_reset_all_vio_int;
  gtwiz_reset_all_int <= gtwiz_reset_all_vio_int;

  gtwiz_reset_rx_pll_and_datapath_int <= gtwiz_reset_rx_pll_and_datapath_vio_int;
  gtwiz_reset_rx_datapath_int <= gtwiz_reset_rx_datapath_vio_int;

  rxbufreset_int <= gtwiz_reset_rx_buf_vio_int;
  --rxprbscntreset_int <= (others => RESET);

  -- Potential useful individual reset signals
  -- gtwiz_reset_tx_datapath_int <= hb0_gtwiz_reset_tx_datapath_int;
  -- gtwiz_reset_tx_pll_and_datapath_int <= hb0_gtwiz_reset_tx_pll_and_datapath_int;
  -- gtwiz_reset_rx_datapath_int <= hb_gtwiz_reset_rx_datapath_init_int or hb_gtwiz_reset_rx_datapath_vio_int;

  ---------------------------------------------------------------------------------------------------------------------
  -- EXAMPLE WRAPPER INSTANCE
  ---------------------------------------------------------------------------------------------------------------------
  cfeb_wrapper_inst : gtwizard_ultrascale_0_example_wrapper
    port map (
      gthrxn_in                          => DAQ_RX_N,
      gthrxp_in                          => DAQ_RX_P,
      gthtxn_out                         => gthtxn_int,
      gthtxp_out                         => gthtxp_int,
      -- tx for xDCFEBs not used
      gtwiz_userclk_tx_reset_in          => gtwiz_userclk_tx_reset_int,
      gtwiz_userclk_tx_srcclk_out        => open, --gtwiz_userclk_tx_srcclk_int,
      gtwiz_userclk_tx_usrclk_out        => open, --gtwiz_userclk_tx_usrclk_int,
      gtwiz_userclk_tx_usrclk2_out       => open, --gtwiz_userclk_tx_usrclk2_int,
      gtwiz_userclk_tx_active_out        => open, --gtwiz_userclk_tx_active_int,
      gtwiz_userclk_rx_reset_in          => gtwiz_userclk_rx_reset_int,
      gtwiz_userclk_rx_srcclk_out        => open, --gtwiz_userclk_rx_srcclk_int,
      gtwiz_userclk_rx_usrclk_out        => open, --gtwiz_userclk_rx_usrclk_int,
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
      gtwiz_reset_rxreset_out            => gtwiz_reset_rxreset_out,
      gtwiz_userdata_tx_in               => gtwiz_userdata_tx_int,
      gtwiz_userdata_rx_out              => gtwiz_userdata_rx_int,
      drpclk_in                          => drpclk_int,
      gtrefclk0_in                       => gtrefclk0_int,
      rx8b10ben_in                       => (others => '1'),
      rxbufreset_in                      => rxbufreset_int,
      rxcommadeten_in                    => (others => '1'),
      rxmcommaalignen_in                 => (others => '1'),
      rxpcommaalignen_in                 => (others => '1'),
      --rxpd_in                            => rxpd_int,
      --rxprbscntreset_in                  => rxprbscntreset_int,
      --rxprbssel_in                       => rxprbssel_int,
      tx8b10ben_in                       => (others => '1'),
      txctrl0_in                         => (others => '0'),  -- not used in 8b10b
      txctrl1_in                         => (others => '0'),  -- not used in 8b10b
      txctrl2_in                         => (others => '0'),  -- not using TX
      cplllock_out                       => cplllock_int,
      --txpd_in                            => (others => '1'),  -- all TX disabled by "11"
      gtpowergood_out                    => gtpowergood_int,
      rxbyteisaligned_out                => rxbyteisaligned_int,
      rxbyterealign_out                  => rxbyterealign_int,
      rxcommadet_out                     => rxcommadet_int,
      rxctrl0_out                        => rxctrl0_int,
      rxctrl1_out                        => rxctrl1_int,
      rxctrl2_out                        => rxctrl2_int,
      rxctrl3_out                        => rxctrl3_int,
      rxpmaresetdone_out                 => rxpmaresetdone_int,
      rxbufstatus_out                    => rxbufstatus_int,
      rxclkcorcnt_out                    => rxclkcorcnt_int,
      --rxprbserr_out                      => rxprbserr_int,
      --rxprbslocked_out                   => rxprbslocked_int,
      txpmaresetdone_out                 => txpmaresetdone_int
      );

  ---------------------------------------------------------------------------------------------------------------------
  -- Debugging
  ---------------------------------------------------------------------------------------------------------------------
  -- Monitor channel 1 (DCFEB2) only
  ila_data_assign : for I in 0 to NLINK-1 generate
  begin
    ila_data_ch(I)(15 downto 0)  <= rxdata_o_ch(I);
    ila_data_ch(I)(31 downto 16) <= rxdata_i_ch(I);
    ila_data_ch(I)(33 downto 32) <= codevalid_ch(I);
    ila_data_ch(I)(34)           <= rxd_valid_ch(I);
    ila_data_ch(I)(35)           <= crc_valid_ch(I);
    ila_data_ch(I)(36)           <= good_crc_ch(I);
    ila_data_ch(I)(37)           <= bad_rx_ch(I);
    ila_data_ch(I)(38)           <= rxbyteisaligned_int(I);
    ila_data_ch(I)(39)           <= rxbyterealign_int(I);
    ila_data_ch(I)(41 downto 40) <= rxcharisk_ch(I);
    ila_data_ch(I)(43 downto 42) <= rxdisperr_ch(I);
    ila_data_ch(I)(45 downto 44) <= rxchariscomma_ch(I);
    ila_data_ch(I)(47 downto 46) <= rxnotintable_ch(I);

    ila_data_rx(48*I+47 downto 48*I) <= ila_data_ch(I);
  end generate ila_data_assign;

  -- Input control signals
  ila_data_rx(352 downto 346)  <= kill_rxout;
  ila_data_rx(359 downto 353) <= kill_rxpd;
  ila_data_rx(360)            <= reset;
  ila_data_rx(361)            <= gtwiz_reset_tx_done_int;
  ila_data_rx(362)            <= gtwiz_reset_rx_done_int;
  ila_data_rx(369 downto 363) <= cplllock_int;
  ila_data_rx(390 downto 370) <= rxbufstatus_int;
  ila_data_rx(404 downto 391) <= rxclkcorcnt_int;
  ila_data_rx(405)            <= reset;
  ila_data_rx(406)            <= gtwiz_reset_all_int;
  ila_data_rx(413 downto 407) <= rxpmaresetdone_int;
  ila_data_rx(420 downto 414) <= txpmaresetdone_int;
  ila_data_rx(421)            <= gtwiz_reset_rxreset_out;

  mgt_cfeb_ila_inst : ila_cfeb
    port map(
      clk => gtwiz_userclk_rx_usrclk2_int,
      probe0 => ila_data_rx
      );

  mgt_cfeb_vio_inst : vio_cfeb
  PORT MAP (
    clk => gtwiz_userclk_rx_usrclk2_int,
    probe_in0 => "0",
    probe_in1 => "0",
    probe_in2 => "0",
    probe_in3 => gtpowergood_vio_sync,
    probe_in4 => txpmaresetdone_vio_sync,
    probe_in5 => rxpmaresetdone_vio_sync,
    probe_in6 => gtwiz_reset_tx_done_vio_sync,
    probe_in7 => gtwiz_reset_rx_done_vio_sync,
    probe_out0 => gtwiz_reset_all_vio_int,
    probe_out1 => gtwiz_reset_tx_pll_and_datapath_vio_int,
    probe_out2 => gtwiz_reset_tx_datapath_vio_int,
    probe_out3 => gtwiz_reset_rx_pll_and_datapath_vio_int,
    probe_out4 => gtwiz_reset_rx_datapath_vio_int,
    probe_out5 => gtwiz_reset_rx_buf_vio_int 
  );

end Behavioral;
