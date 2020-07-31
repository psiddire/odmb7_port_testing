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

entity ODMB7_UCSB_DEV is
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
    -- Signals controlled by ODMB_VME
    --------------------
    VME_DATA        : inout std_logic_vector(15 downto 0);  -- Bank 48
    -- VME_DATA_IN     : in std_logic_vector(15 downto 0);  -- FIXME: for real ODMB, there is one line, but for KCU, we can't have internal IOBUFs
    -- VME_DATA_OUT    : out std_logic_vector(15 downto 0); -- FIXME: for real ODMB, there is one line, but for KCU, we can't have internal IOBUFs
    VME_GAP_B       : in std_logic;                        -- Bank 48
    VME_GA_B        : in std_logic_vector(4 downto 0);     -- Bank 48
    VME_ADDR        : in std_logic_vector(23 downto 1);    -- Bank 46
    VME_AM          : in std_logic_vector(5 downto 0);     -- Bank 46
    VME_AS_B        : in std_logic;                        -- Bank 46
    VME_DS_B        : in std_logic_vector(1 downto 0);     -- Bank 46
    VME_LWORD_B     : in std_logic;                        -- Bank 48
    VME_WRITE_B     : in std_logic;                        -- Bank 48
    VME_IACK_B      : in std_logic;                        -- Bank 48
    VME_BERR_B      : in std_logic;                        -- Bank 48
    VME_SYSRST_B    : in std_logic;                        -- Bank 48, not used
    VME_SYSFAIL_B   : in std_logic;                        -- Bank 48
    VME_CLK_B       : in std_logic;                        -- Bank 48, not used
    KUS_VME_OE_B    : out std_logic;                       -- Bank 44
    KUS_VME_DIR_B   : out std_logic;                       -- Bank 44
    VME_DTACK_KUS_B : inout std_logic;                     -- Bank 44

    DCFEB_TCK_P    : out std_logic_vector(NCFEB downto 1); -- Bank 68
    DCFEB_TCK_N    : out std_logic_vector(NCFEB downto 1); -- Bank 68
    DCFEB_TMS_P    : out std_logic;                        -- Bank 68
    DCFEB_TMS_N    : out std_logic;                        -- Bank 68
    DCFEB_TDI_P    : out std_logic;                        -- Bank 68
    DCFEB_TDI_N    : out std_logic;                        -- Bank 68
    DCFEB_TDO_P    : in  std_logic_vector(NCFEB downto 1); -- Bank 67-68
    DCFEB_TDO_N    : in  std_logic_vector(NCFEB downto 1); -- Bank 67-68
    DCFEB_DONE     : in  std_logic_vector(NCFEB downto 1); -- Bank 68

    LVMB_PON   : out std_logic_vector(7 downto 0);
    PON_LOAD   : out std_logic;
    PON_OE_B   : out std_logic;
    R_LVMB_PON : in  std_logic_vector(7 downto 0);
    LVMB_CSB   : out std_logic_vector(6 downto 0);
    LVMB_SCLK  : out std_logic;
    LVMB_SDIN  : out std_logic;
    LVMB_SDOUT : in  std_logic;

    DCFEB_PRBS_FIBER_SEL : out std_logic_vector(3 downto 0);
    DCFEB_PRBS_EN        : out std_logic;
    DCFEB_PRBS_RST       : out std_logic;
    DCFEB_PRBS_RD_EN     : out std_logic;
    DCFEB_RXPRBSERR      : in  std_logic;
    DCFEB_PRBS_ERR_CNT   : in  std_logic_vector(15 downto 0);

    OTMB_TX : in  std_logic_vector(48 downto 0);
    OTMB_RX : out std_logic_vector(5 downto 0);

    --------------------
    -- Other
    --------------------
    DIAGOUT     : out std_logic_vector(17 downto 0); --for debugging
    RST         : in std_logic
    );
end ODMB7_UCSB_DEV;

architecture Behavioral of ODMB7_UCSB_DEV is
  -- Constants
  constant bw_data  : integer := 16; -- data bit width

  component ODMB_VME is
    generic (
      NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
      );
    port (
      --------------------
      -- Clock
      --------------------
      CLK160      : in std_logic;  -- For dcfeb prbs (160MHz)
      CLK40       : in std_logic;  -- NEW (fastclk -> 40MHz)
      CLK10       : in std_logic;  -- NEW (midclk -> fastclk/4 -> 10MHz)

      --------------------
      -- VME signals  <-- relevant ones only
      --------------------
      VME_DATA_IN   : in std_logic_vector (15 downto 0);
      VME_DATA_OUT  : out std_logic_vector (15 downto 0);
      VME_GAP_B     : in std_logic;
      VME_GA_B      : in std_logic_vector (4 downto 0); -- VME_GAP is GA(5)
      VME_ADDR      : in std_logic_vector (23 downto 1);
      VME_AM        : in std_logic_vector (5 downto 0);
      VME_AS_B      : in std_logic;
      VME_DS_B      : in std_logic_vector (1 downto 0);
      VME_LWORD_B   : in std_logic;
      VME_WRITE_B   : in std_logic;
      VME_IACK_B    : in std_logic;
      VME_BERR_B    : in std_logic;
      VME_SYSFAIL_B : in std_logic;
      VME_DTACK_B   : inout std_logic;
      VME_OE_B      : out std_logic;
      VME_DIR_B     : out std_logic;

      --------------------
      -- JTAG Signals To/From DCFEBs
      --------------------
      DCFEB_TCK    : out std_logic_vector (NCFEB downto 1);
      DCFEB_TMS    : out std_logic;
      DCFEB_TDI    : out std_logic;
      DCFEB_TDO    : in  std_logic_vector (NCFEB downto 1);

      DCFEB_DONE     : in std_logic_vector (NCFEB downto 1);
      DCFEB_INITJTAG : in std_logic;   -- TODO: where does this fit in

      --------------------
      -- From/To LVMB: ODMB & ODMB7 design, ODMB5 to be seen
      --------------------
      LVMB_PON   : out std_logic_vector(7 downto 0);
      PON_LOAD   : out std_logic;
      PON_OE_B   : out std_logic;
      R_LVMB_PON : in  std_logic_vector(7 downto 0);
      LVMB_CSB   : out std_logic_vector(6 downto 0);
      LVMB_SCLK  : out std_logic;
      LVMB_SDIN  : out std_logic;
      LVMB_SDOUT : in  std_logic;

      -- DIAGOUT_LVDBMON  : out std_logic_vector(17 downto 0);

      --------------------
      -- TODO: DCFEB PRBS signals
      --------------------
      DCFEB_PRBS_FIBER_SEL : out std_logic_vector(3 downto 0);
      DCFEB_PRBS_EN        : out std_logic;
      DCFEB_PRBS_RST       : out std_logic;
      DCFEB_PRBS_RD_EN     : out std_logic;
      DCFEB_RXPRBSERR      : in  std_logic;
      DCFEB_PRBS_ERR_CNT   : in  std_logic_vector(15 downto 0);

      --------------------
      -- TODO: OTMB PRBS signals
      --------------------
      OTMB_TX : in  std_logic_vector(48 downto 0);
      OTMB_RX : out std_logic_vector(5 downto 0);

      --------------------
      -- Other
      --------------------
      DIAGOUT     : out std_logic_vector (17 downto 0); -- for debugging
      RST         : in std_logic
      );
  end component;

  -- VME Signals

  -- signal cmd_adrs     : std_logic_vector (15 downto 0);
  signal vme_data_out : std_logic_vector (15 downto 0);
  signal vme_data_in  : std_logic_vector (15 downto 0);
  signal vme_dir_b    : std_logic;
  -- signal vme_oe_b   : std_logic;

  signal dcfeb_tck    : std_logic_vector (NCFEB downto 1);
  signal dcfeb_tms    : std_logic;
  signal dcfeb_tdi    : std_logic;
  signal dcfeb_tdo    : std_logic_vector (NCFEB downto 1);

  -- signals to generate dcfeb_initjtag when DCFEBs are done programming
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

begin

  -- Handle VME data line
  KUS_VME_DIR_B <= vme_dir_b;

  -- Handle DCFEB data line
  OB_DCFEB_TMS: OBUFDS port map (I => dcfeb_tms, O => DCFEB_TMS_P, OB => DCFEB_TMS_N);
  OB_DCFEB_TDI: OBUFDS port map (I => dcfeb_tdi, O => DCFEB_TDI_P, OB => DCFEB_TDI_N);
  GEN_DCFEBOUT_7 : for I in 1 to NCFEB generate
  begin
    OB_DCFEB_TCK: OBUFDS port map (I => dcfeb_tck(I), O => DCFEB_TCK_P(I), OB => DCFEB_TCK_N(I));
    OB_DCFEB_TDO: IBUFDS port map (O => dcfeb_tdo(I), I => DCFEB_TDO_P(I), IB => DCFEB_TDO_N(I));
  end generate GEN_DCFEBOUT_7;


  -- uncomment for real ODMB; in KCU we can't have internal IOBUFs
  GEN_VMEOUT_16 : for I in 0 to 15 generate
  begin
    VME_BUF : IOBUF port map(O => vme_data_in(I), IO => vme_data(I), I => vme_data_out(I), T => vme_dir_b);
  end generate GEN_VMEOUT_16;
  -- below lines: comment for real ODMB, needed for KCU (?)
  -- VME_DATA_OUT <= vme_data_out_buf;
  -- GEN_16 : for I in 0 to 15 generate
  -- begin
  --   PULLDOWN_vme_data_out_buf : PULLDOWN port map (O => vme_data_out_buf(I));
  -- end generate GEN_16;

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

  i_odmb_vme : ODMB_VME
    generic map (
      NCFEB => NCFEB
      )
    port map (
      CLK160         => CLK160,
      CLK40          => CLK40,
      CLK10          => CLK10,

      VME_DATA_IN    => vme_data_in,
      VME_DATA_OUT   => vme_data_out,
      VME_GAP_B      => VME_GAP_B,
      VME_GA_B       => VME_GA_B,
      VME_ADDR       => VME_ADDR,
      VME_AM         => VME_AM,
      VME_AS_B       => VME_AS_B,
      VME_DS_B       => VME_DS_B,
      VME_LWORD_B    => VME_LWORD_B,
      VME_WRITE_B    => VME_WRITE_B,
      VME_IACK_B     => VME_IACK_B,
      VME_BERR_B     => VME_BERR_B,
      VME_SYSFAIL_B  => VME_SYSFAIL_B,
      VME_DTACK_B    => VME_DTACK_KUS_B,
      VME_OE_B       => KUS_VME_OE_B,
      VME_DIR_B      => vme_dir_b,      -- to be used in IOBUF

      DCFEB_TCK      => dcfeb_tck,
      DCFEB_TMS      => dcfeb_tms,
      DCFEB_TDI      => dcfeb_tdi,
      DCFEB_TDO      => dcfeb_tdo,
      DCFEB_DONE     => DCFEB_DONE,
      DCFEB_INITJTAG => dcfeb_initjtag,

      LVMB_PON    => LVMB_PON,
      PON_LOAD    => PON_LOAD,
      PON_OE_B    => PON_OE_B,
      R_LVMB_PON  => R_LVMB_PON,
      LVMB_CSB    => LVMB_CSB,
      LVMB_SCLK   => LVMB_SCLK,
      LVMB_SDIN   => LVMB_SDIN,
      LVMB_SDOUT  => LVMB_SDOUT,

      DCFEB_PRBS_FIBER_SEL  => DCFEB_PRBS_FIBER_SEL,
      DCFEB_PRBS_EN         => DCFEB_PRBS_EN,
      DCFEB_PRBS_RST        => DCFEB_PRBS_RST,
      DCFEB_PRBS_RD_EN      => DCFEB_PRBS_RD_EN,
      DCFEB_RXPRBSERR       => DCFEB_RXPRBSERR,
      DCFEB_PRBS_ERR_CNT    => DCFEB_PRBS_ERR_CNT,

      OTMB_TX  => OTMB_TX,
      OTMB_RX  => OTMB_RX,

      DIAGOUT  => DIAGOUT,
      RST      => RST
      );

end Behavioral;
