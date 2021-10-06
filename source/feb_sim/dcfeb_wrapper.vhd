-- DCFEB_LVDS_WRAPPER contains simulated DCFEB with LVDS to single IOBUFs

library ieee;
library unisim;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use unisim.vcomponents.all;

use work.Firmware_pkg.all;     -- for switch between sim and synthesis

entity DCFEB_DS_WRAPPER is
  generic (
    dcfeb_addr : std_logic_vector(3 downto 0) := "1000"  -- DCFEB address
    );  
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
    DIAGOUT       : out std_logic_vector(17 downto 0));
end DCFEB_DS_WRAPPER;


architecture DCFEB_DS_WRAPPER_ARCHITECTURE of DCFEB_DS_WRAPPER is

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

  signal tms       : std_logic := '0';
  signal tck       : std_logic := '0';
  signal tdi       : std_logic := '0';
  signal tdo       : std_logic := '0';
  signal injpls    : std_logic := '0';
  signal extpls    : std_logic := '0';
  signal resync    : std_logic := '0';
  signal bc0       : std_logic := '0';
  signal l1a       : std_logic := '0';
  signal l1a_match : std_logic := '0'; 

begin

  -- in simulation/real ODMB, use I/OBUFDS
  cfebjtag_conn_simulation_i : if in_simulation generate
    IB_DCFEB_TMS: IBUFDS port map (O => tms, I => TMS_P, IB => TMS_N);
    IB_DCFEB_TCK: IBUFDS port map (O => tck, I => TCK_P, IB => TCK_N);
    IB_DCFEB_TDI: IBUFDS port map (O => tdi, I => TDI_P, IB => TDI_N);
    OB_DCFEB_TDO: OBUFDS port map (I => tdo, O => TDO_P, OB => TDO_N);
    IB_DCFEB_INJPLS: IBUFDS port map (O => injpls, I => INJPLS_P, IB => INJPLS_N);
    IB_DCFEB_EXTPLS: IBUFDS port map (O => extpls, I => EXTPLS_P, IB => EXTPLS_N);
    IB_DCFEB_RESYNC: IBUFDS port map (O => resync, I => RESYNC_P, IB => RESYNC_N);
    IB_DCFEB_BC0: IBUFDS port map (O => bc0, I => BC0_P, IB => BC0_N);
    IB_DCFEB_L1A: IBUFDS port map (O => l1a, I => L1A_P, IB => L1A_N);
    IB_DCFEB_L1A_MATCH: IBUFDS port map (O => l1a_match, I => L1A_MATCH_P, IB => L1A_MATCH_N);
  end generate cfebjtag_conn_simulation_i;

  -- on KCU use the P lines as signals
  cfebjtag_conn_kcu_i : if in_synthesis generate
    tms       <= TMS_P;
    tck       <= TCK_P;
    tdi       <= TDI_P;
    TDO_P     <= tdo;
    TDO_N     <= '0';
    injpls    <= INJPLS_P;
    extpls    <= EXTPLS_p;
    resync    <= RESYNC_P;
    bc0       <= BC0_P;
    l1a       <= L1A_P;
    l1a_match <= L1A_MATCH_P;
  end generate cfebjtag_conn_kcu_i;

  dcfeb_i: dcfeb_v6
  port map (
    CLK             => CLK,  
    DCFEBCLK        => DCFEBCLK,
    RST             => RST,
    L1A             => l1a,
    L1A_MATCH       => l1a_match,
    TX_ACK          => TX_ACK,
    NWORDS_DUMMY    => NWORDS_DUMMY,
    DCFEB_DV        => DCFEB_DV,
    DCFEB_DATA      => DCFEB_DATA,
    ADC_MASK        => ADC_MASK,
    DCFEB_FSEL      => DCFEB_FSEL,
    DCFEB_JTAG_IR   => DCFEB_JTAG_IR,
    TRST            => TRST,
    TCK             => tck,  
    TMS             => tms,     
    TDI             => tdi,     
    TDO             => tdo,  
    RTN_SHFT_EN     => RTN_SHFT_EN,
    DONE            => DONE,
    INJPLS          => injpls,
    EXTPLS          => extpls,
    BC0             => bc0,
    RESYNC          => resync,
    DIAGOUT         => DIAGOUT
  );

end DCFEB_DS_WRAPPER_ARCHITECTURE;
