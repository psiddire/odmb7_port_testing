library ieee;
use ieee.std_logic_1164.all;

PACKAGE odmb7_components is

  -- GTH wizard wrapper for DCFEBs
  component gtwizard_ultrascale_0_example_wrapper
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
      gtwiz_reset_rxreset_out : out std_logic;
      gtwiz_userdata_tx_in : in std_logic_vector(111 downto 0);
      gtwiz_userdata_rx_out : out std_logic_vector(111 downto 0);
      drpclk_in : in std_logic_vector(6 downto 0);
      gtrefclk0_in : in std_logic_vector(6 downto 0);
      rx8b10ben_in : in std_logic_vector(6 downto 0);
      rxbufreset_in : in std_logic_vector(6 downto 0);
      rxcommadeten_in : in std_logic_vector(6 downto 0);
      rxmcommaalignen_in : in std_logic_vector(6 downto 0);
      rxpcommaalignen_in : in std_logic_vector(6 downto 0);
      tx8b10ben_in : in std_logic_vector(6 downto 0);
      txctrl0_in : in std_logic_vector(111 downto 0);
      txctrl1_in : in std_logic_vector(111 downto 0);
      txctrl2_in : in std_logic_vector(55 downto 0);
      gtpowergood_out : out std_logic_vector(6 downto 0);
      cplllock_out : out std_logic_vector(6 downto 0);
      rxbyteisaligned_out : out std_logic_vector(6 downto 0);
      rxbyterealign_out : out std_logic_vector(6 downto 0);
      rxcommadet_out : out std_logic_vector(6 downto 0);
      rxctrl0_out : out std_logic_vector(111 downto 0);
      rxctrl1_out : out std_logic_vector(111 downto 0);
      rxctrl2_out : out std_logic_vector(55 downto 0);
      rxctrl3_out : out std_logic_vector(55 downto 0);
      rxbufstatus_out : out std_logic_vector(20 downto 0);
      rxclkcorcnt_out : out std_logic_vector(13 downto 0);
      rxpmaresetdone_out : out std_logic_vector(6 downto 0);
      txpmaresetdone_out : out std_logic_vector(6 downto 0)
      );
  end component;

END odmb7_components;
  
