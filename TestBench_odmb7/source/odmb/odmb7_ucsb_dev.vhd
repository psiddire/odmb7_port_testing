library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

-- To mimic the behavior of ODMB_VME on the component CFEBJTAG

-- library UNISIM;
-- use UNISIM.VComponents.all;

use work.Firmware_pkg.all;     -- for switch between sim and synthesis

entity odmb7_ucsb_dev is
  PORT (
    -- Clock
    CLK160      : in std_logic;  -- For dcfeb prbs (160MHz)
    CLK40       : in std_logic;  -- NEW (fastclk -> 40MHz)
    CLK10       : in std_logic;  -- NEW (midclk -> fastclk/4 -> 10MHz)
    -- VME signals <-- relevant ones only
    VME_DATA_IN    : in std_logic_vector (15 downto 0);  -- data(15 downto 0)
    VME_DATA_OUT   : out std_logic_vector (15 downto 0);  -- data(15 downto 0)
    VME_GA         : in std_logic_vector (5 downto 0); --gap is ga(5)
    VME_ADDR       : in std_logic_vector (23 downto 1);
    VME_AM         : in std_logic_vector (5 downto 0);
    VME_AS_B       : in std_logic;
    VME_DS_B       : in std_logic_vector (1 downto 0);
    VME_LWORD_B    : in std_logic;
    VME_WRITE_B    : in std_logic;
    VME_IACK_B     : in std_logic;
    VME_BERR_B     : in std_logic;
    VME_SYSFAIL_B  : in std_logic;
    VME_DTACK_V6_B : inout std_logic;
    VME_DOE_B      : in std_logic;
    --for debugging
    DIAGOUT        : out std_logic_vector (17 downto 0);
    -- JTAG Signals To/From DCFEBs
    DL_JTAG_TCK    : out std_logic_vector (6 downto 0);
    DL_JTAG_TMS    : out std_logic;
    DL_JTAG_TDI    : out std_logic;
    DL_JTAG_TDO    : in  std_logic_vector (6 downto 0);
    DCFEB_INITJTAG : in  std_logic;
    -- Reset
    RST         : in std_logic
    );
end odmb7_ucsb_dev;

architecture Behavioral of odmb7_ucsb_dev is
  -- Constants
  constant bw_data  : integer := 16;
  constant NCFEB    : integer := 7;

  component CONFREGS_DUMMY is
    port (
      SLOWCLK   : in std_logic;
      DEVICE    : in std_logic;
      STROBE    : in std_logic;
      COMMAND   : in std_logic_vector(9 downto 0);
      OUTDATA   : inout std_logic_vector(15 downto 0);
      DTACK     : out std_logic
    );
  end component;

  component CFEBJTAG is
    port (
      -- CSP_LVMB_LA_CTRL : inout std_logic_vector(35 downto 0);

      FASTCLK   : in std_logic;  -- fastclk -> 40 MHz
      SLOWCLK   : in std_logic;  -- midclk  -> 10 MHz
      RST       : in std_logic;
      DEVICE    : in std_logic;
      STROBE    : in std_logic;
      COMMAND   : in std_logic_vector(9 downto 0);
      WRITER    : in std_logic;
      INDATA    : in std_logic_vector(15 downto 0);
      OUTDATA   : inout std_logic_vector(15 downto 0);
      DTACK     : out std_logic;
      INITJTAGS : in  std_logic;
      TCK       : out std_logic_vector(NCFEB downto 1);
      TDI       : out std_logic;
      TMS       : out std_logic;
      FEBTDO    : in  std_logic_vector(NCFEB downto 1);
      DIAGOUT   : out std_logic_vector(17 downto 0);
      LED       : out std_logic
      );
  end component;

  component command_module is
    port (
      FASTCLK : in std_logic;
      SLOWCLK : in std_logic;

      GA      : in std_logic_vector(5 downto 0);
      ADR     : in std_logic_vector(23 downto 1);
      AM      : in std_logic_vector(5 downto 0);

      AS      : in std_logic;
      DS0     : in std_logic;
      DS1     : in std_logic;
      LWORD   : in std_logic;
      WRITER  : in std_logic;
      IACK    : in std_logic;
      BERR    : in std_logic;
      SYSFAIL : in std_logic;

      DEVICE  : out std_logic_vector(9 downto 0);
      STROBE  : out std_logic;
      COMMAND : out std_logic_vector(9 downto 0);
      ADRS    : out std_logic_vector(17 downto 2);

      TOVME_B : out std_logic;
      DOE_B   : out std_logic;

      DIAGOUT : out std_logic_vector(17 downto 0);
      LED     : out std_logic_vector(2 downto 0)
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
  signal device    : std_logic_vector(9 downto 0) := (others => '0');
  signal cmd       : std_logic_vector(9 downto 0) := (others => '0');
  signal strobe    : std_logic := '0';
  signal tovme_b, doe_b : std_logic := '0';

  signal dtack_dev : std_logic_vector(9 downto 0) := (others => '0');

  signal diagout_cfebjtag : std_logic_vector(17 downto 0) := (others => '0');
  signal led_cfebjtag     : std_logic := '0';
  signal diagout_command  : std_logic_vector(19 downto 0) := (others => '0');
  signal led_command      : std_logic_vector(2 downto 0)  := (others => '0');

  signal dl_jtag_tck_inner : std_logic_vector(6 downto 0);
  signal dl_jtag_tdi_inner, dl_jtag_tms_inner : std_logic;

  -- New, used in place of the array
--  signal devout : std_logic_vector(bw_data-1 downto 0) := (others => '0');
  -- New, to test  of the array
  signal dcfeb_initjtag_i : std_logic := '0';

  signal cmd_adrs_inner : std_logic_vector(17 downto 2) := (others => '0');

  -- signals between vme_master_fsm and command_module
--  signal vme_adr     : std_logic_vector(23 downto 1) := (others => '0');
  -- signals between vme_master_fsm and cfebjtag and lvdbmon modules
  signal vme_outdata : std_logic_vector(15 downto 0) := (others => '0');
  

begin

  -- For CFEBJTAG input
  dcfeb_initjtag_i <= DCFEB_INITJTAG;
  DIAGOUT <= diagout_cfebjtag;
  DL_JTAG_TCK <= dl_jtag_tck_inner;
  DL_JTAG_TDI <= dl_jtag_tdi_inner;
  DL_JTAG_TMS <= dl_jtag_tms_inner;
  
  VME_DATA_OUT <= vme_outdata;

  PULLUP_vme_dtack : PULLUP port map (O => VME_DTACK_V6_B);
  --vme_dtack <= 'H'; -- resolution 'H'+'1'='1', 'H'+'0'='0' vivado issuing multiple driver warnings...
  VME_DTACK_V6_B <= not or_reduce(dtack_dev);
  
  DEV4_DUMMY : CONFREGS_DUMMY
    port map (
          SLOWCLK => clk10,
          DEVICE  => device(4),
          STROBE  => strobe,
          COMMAND => cmd,
          OUTDATA => vme_outdata,
          DTACK => dtack_dev(4)
    );

  DEV1_CFEBJTAG : CFEBJTAG
    port map (
      -- CSP_LVMB_LA_CTRL => CSP_LVMB_LA_CTRL,
      FASTCLK => clk40,
      SLOWCLK => clk10,
      RST     => rst,

      DEVICE  => device(1),
      STROBE  => strobe,
      COMMAND => cmd,

      WRITER  => VME_WRITE_B,
      INDATA  => VME_DATA_IN,   -- VME_DATA_IN,
      OUTDATA => vme_outdata,  -- devout, -- dev_outdata(1),

      DTACK   => dtack_dev(1),

      INITJTAGS => dcfeb_initjtag_i,
      TCK       => dl_jtag_tck_inner,
      TDI       => dl_jtag_tdi_inner,
      TMS       => dl_jtag_tms_inner,
      FEBTDO    => DL_JTAG_TDO,

      DIAGOUT => diagout_cfebjtag,
      LED     => led_cfebjtag
      );

  COMMAND_PM : COMMAND_MODULE
    port map (
      FASTCLK => clk40,
      SLOWCLK => clk10,
      GA      => VME_GA,               -- gap = ga(5)
      ADR     => VME_ADDR,             -- input cmd = ADR(11 downto 2)
      AM      => VME_AM,
      AS      => VME_AS_B,
      DS0     => VME_DS_B(0),
      DS1     => VME_DS_B(1),
      LWORD   => VME_LWORD_B,
      WRITER  => VME_WRITE_B,
      IACK    => VME_IACK_B,
      BERR    => VME_BERR_B,
      SYSFAIL => VME_SYSFAIL_B,
      TOVME_B => tovme_b,
      DOE_B   => doe_b,
      DEVICE  => device,
      STROBE  => strobe,
      COMMAND => cmd,
      ADRS    => cmd_adrs_inner,
      DIAGOUT => open,      -- temp
      LED     => led_command           -- temp
      );


end Behavioral;
