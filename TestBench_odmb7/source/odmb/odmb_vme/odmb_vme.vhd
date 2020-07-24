------------------------------
-- ODMB_VME: Handles the VME protocol and selects VME device
------------------------------

-- Device 0 => TESTCTRL
-- Device 1 => CFEBJTAG
-- Device 2 => ODMBJTAG
-- Device 3 => VMEMON
-- Device 4 => VMECONFREGS
-- Device 5 => TESTFIFOS
-- Device 6 => BPI_PORT
-- Device 7 => SYSTEM_MON
-- Device 8 => LVDBMON
-- Device 9 => SYSTEM_TEST

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;
use work.ucsb_types.all;

-- To mimic the behavior of ODMB_VME on the component CFEBJTAG

-- library UNISIM;
-- use UNISIM.VComponents.all;

use work.Firmware_pkg.all;     -- for switch between sim and synthesis

entity ODMB_VME is
  generic (
    NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
  );
  PORT (
    --------------------
    -- Clock
    --------------------
    CLK160      : in std_logic;  -- For dcfeb prbs (160MHz)
    CLK40       : in std_logic;  -- NEW (fastclk -> 40MHz)
    CLK10       : in std_logic;  -- NEW (midclk -> fastclk/4 -> 10MHz)

    --------------------
    -- VME signals  <-- relevant ones only
    --------------------
    -- VME_DATA       : inout std_logic_vector (15 downto 0);  -- FIXME: for real ODMB, there is one line, but for KCU, we can't have internal IOBUFs
    VME_DATA_IN    : in std_logic_vector (15 downto 0);  -- FIXME: inout for real ODMB
    VME_DATA_OUT   : out std_logic_vector (15 downto 0); -- FIXME: inout for real ODMB
    VME_GA         : in std_logic_vector (5 downto 0); -- gap is ga(5)
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

    --------------------
    -- JTAG Signals To/From DCFEBs
    --------------------
    DCFEB_TCK    : out std_logic_vector (NCFEB downto 1);
    DCFEB_TMS    : out std_logic;
    DCFEB_TDI    : out std_logic;
    DCFEB_TDO    : in  std_logic_vector (NCFEB downto 1);
    DCFEB_DONE   : in  std_logic_vector (NCFEB downto 1);

    --------------------
    -- Other
    --------------------
    RST         : in std_logic
    );
end ODMB_VME;

architecture Behavioral of ODMB_VME is
  -- Constants
  constant bw_data  : integer := 16; -- data bit width

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
    generic (
      NCFEB   : integer range 1 to 7 := NCFEB
    );
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

  component COMMAND_MODULE is
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

  signal device    : std_logic_vector(9 downto 0) := (others => '0');
  signal cmd       : std_logic_vector(9 downto 0) := (others => '0');
  signal strobe    : std_logic := '0';
  signal tovme_b, doe_b : std_logic := '0';
  --signal vme_data_in, vme_data_out : std_logic_vector(15 downto 0) := (others => '0'); --uncomment for real ODMB, not needed for KCU
  signal vme_data_out_buf : std_logic_vector(15 downto 0) := (others => '0'); --comment for real ODMB, needed for KCU

  signal dtack_dev : std_logic_vector(9 downto 0) := (others => '0');

  signal diagout_buf : std_logic_vector(17 downto 0) := (others => '0');
  signal led_cfebjtag     : std_logic := '0';
  signal led_command      : std_logic_vector(2 downto 0)  := (others => '0');

  signal dl_jtag_tck_inner : std_logic_vector(6 downto 0);
  signal dl_jtag_tdi_inner, dl_jtag_tms_inner : std_logic;

  -- New, used in place of the array
--  signal devout : std_logic_vector(bw_data-1 downto 0) := (others => '0');

  --signals to generate dcfeb_initjtag when DCFEBs are done programming
  signal pon_rst_reg : std_logic_vector(31 downto 0) := x"00FFFFFF";
  signal pon_reset : std_logic := '0';
  signal done_cnt_en, done_cnt_rst                           : std_logic_vector(NCFEB downto 1);
  type done_cnt_type is array (NCFEB downto 1) of integer range 0 to 3;
  signal done_cnt                                            : done_cnt_type;
  type done_state_type is (DONE_IDLE, DONE_LOW, DONE_COUNTING);
  type done_state_array_type is array (NCFEB downto 1) of done_state_type;
  signal done_next_state, done_current_state                 : done_state_array_type;
  signal dcfeb_done_pulse : std_logic_vector(NCFEB downto 1) := (others => '0');
  signal dcfeb_initjtag : std_logic := '0';
  signal dcfeb_initjtag_d : std_logic := '0';
  signal dcfeb_initjtag_dd : std_logic := '0';


  signal cmd_adrs_inner : std_logic_vector(17 downto 2) := (others => '0');

  -- signals between vme_master_fsm and command_module
--  signal vme_adr     : std_logic_vector(23 downto 1) := (others => '0');


begin

  -- FSM to handle initialization when DONE received from DCFEBs
  -- pon used to be generated from pll lock, may have to revert
  pon_rst_reg    <= pon_rst_reg(30 downto 0) & '0' when rising_edge(clk40) else
                    pon_rst_reg;
  pon_reset <= pon_rst_reg(31);
  -- Generate dcfeb_initjtag
  done_fsm_regs : process (done_next_state, pon_reset, CLK10)
  begin
    for dev in 1 to NCFEB loop
      if (pon_reset = '1') then
        done_current_state(dev) <= DONE_LOW;
      elsif rising_edge(CLK10) then
        done_current_state(dev) <= done_next_state(dev);
        if done_cnt_rst(dev) = '1' then
          done_cnt(dev) <= 0;
        elsif done_cnt_en(dev) = '1' then
          done_cnt(dev) <= done_cnt(dev) + 1;
        end if;
      end if;
    end loop;
  end process;
  done_fsm_logic : process (done_current_state, DCFEB_DONE, done_cnt)
  begin
    for dev in 1 to NCFEB loop
      case done_current_state(dev) is
        when DONE_IDLE =>
          done_cnt_en(dev)      <= '0';
          dcfeb_done_pulse(dev) <= '0';
          if (DCFEB_DONE(dev) = '0') then
            done_next_state(dev) <= DONE_LOW;
            done_cnt_rst(dev)    <= '1';
          else
            done_next_state(dev) <= DONE_IDLE;
            done_cnt_rst(dev)    <= '0';
          end if;

        when DONE_LOW =>
          done_cnt_en(dev)      <= '0';
          dcfeb_done_pulse(dev) <= '0';
          done_cnt_rst(dev)     <= '0';
          if (DCFEB_DONE(dev) = '1') then
            done_next_state(dev) <= DONE_COUNTING;
          else
            done_next_state(dev) <= DONE_LOW;
          end if;

        when DONE_COUNTING =>
          if (DCFEB_DONE(dev) = '0') then
            done_next_state(dev)  <= DONE_LOW;
            done_cnt_en(dev)      <= '0';
            dcfeb_done_pulse(dev) <= '0';
            done_cnt_rst(dev)     <= '1';
          elsif (done_cnt(dev) = 3) then  -- DONE has to be high at least 400 us to avoid spurious edges
            done_next_state(dev)  <= DONE_IDLE;
            done_cnt_en(dev)      <= '0';
            dcfeb_done_pulse(dev) <= '1';
            done_cnt_rst(dev)     <= '0';
          else
            done_next_state(dev)  <= DONE_COUNTING;
            done_cnt_en(dev)      <= '1';
            dcfeb_done_pulse(dev) <= '0';
            done_cnt_rst(dev)     <= '0';
          end if;
      end case;
     end loop;
  end process;
  dcfeb_initjtag_dd <= or_reduce(dcfeb_done_pulse);
  --temp use clk40 so I don't have to wait an eternity
  DS_DCFEB_INITJTAG    : DELAY_SIGNAL generic map(240) port map(DOUT => dcfeb_initjtag_d, CLK => CLK40, NCYCLES => 240, DIN => dcfeb_initjtag_dd);
  PULSE_DCFEB_INITJTAG : NPULSE2FAST port map(DOUT => dcfeb_initjtag, CLK_DOUT => CLK40, RST => '0', NPULSE => 5, DIN => dcfeb_initjtag_d);

  -- For CFEBJTAG input
  DCFEB_TCK <= dl_jtag_tck_inner;
  DCFEB_TDI <= dl_jtag_tdi_inner;
  DCFEB_TMS <= dl_jtag_tms_inner;

  -- debugging
  DIAGOUT <= diagout_buf;
  diagout_buf(17) <= device(4);
  diagout_buf(16 downto 8) <= cmd(8 downto 0);
  diagout_buf(7 downto 0) <= vme_data_out_buf(7 downto 0);

  -- Handle VME data line
  -- uncomment for real ODMB; in KCU we can't have internal IOBUFs
--  GEN_15 : for I in 0 to 15 generate
--  begin
--    VME_BUF : IOBUF port map(O => vme_data_in(I), IO => vme_data(I), I => vme_data_out(I), T => tovme_b);
--  end generate GEN_15;
  --below lines: comment for real ODMB, needed for KCU (?)
  VME_DATA_OUT <= vme_data_out_buf;
  --GEN_15 : for I in 0 to 15 generate
  --begin
  --  PULLDOWN_vme_data_out_buf : PULLDOWN port map (O => vme_data_out_buf(I));
  --end generate GEN_15;

  PULLUP_vme_dtack : PULLUP port map (O => VME_DTACK_V6_B);
  VME_DTACK_V6_B <= not or_reduce(dtack_dev);

  DEV4_DUMMY : CONFREGS_DUMMY
    port map (
          SLOWCLK => clk10,
          DEVICE  => device(4),
          STROBE  => strobe,
          COMMAND => cmd,
          OUTDATA => vme_data_out_buf, --change to vme_data_out in real ODMB, this is KCU fix
          DTACK => dtack_dev(4)
    );

  DEV1_CFEBJTAG : CFEBJTAG
    generic map (NCFEB => NCFEB)
    port map (
      -- CSP_LVMB_LA_CTRL => CSP_LVMB_LA_CTRL,
      FASTCLK => clk40,
      SLOWCLK => clk10,
      RST     => rst,

      DEVICE  => device(1),
      STROBE  => strobe,
      COMMAND => cmd,

      WRITER  => VME_WRITE_B,
      INDATA  => vme_data_in,   -- VME_DATA_IN,
      OUTDATA => vme_data_out_buf,  -- change to vme_data_out in real ODMB, this is KCU fix

      DTACK   => dtack_dev(1),

      INITJTAGS => dcfeb_initjtag,
      TCK       => dl_jtag_tck_inner,
      TDI       => dl_jtag_tdi_inner,
      TMS       => dl_jtag_tms_inner,
      FEBTDO    => DCFEB_TDO,

      DIAGOUT => open,
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
