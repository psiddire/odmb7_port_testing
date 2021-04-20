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

entity prbs_tester is
  generic (
    DDU_NRXLINK  : integer := 1;
    SPYDATAWIDTH : integer := 16;
    FEBDATAWIDTH : integer := 16;
    DDUTXDWIDTH  : integer := 32;
    DDURXDWIDTH  : integer := 16;
    SPY_PATTERN  : integer := 0;        -- 0 for PRBS, 1 for counter
    DDU_PATTERN  : integer := 0         -- 0 for PRBS, 1 for counter
    );
  port (
    sysclk         : in std_logic; -- sysclk
    -- Pattern generation and checking for SPY channel
    usrclk_spy_tx  : in std_logic; -- USRCLK for SPY TX data generation
    txdata_spy     : out std_logic_vector(SPYDATAWIDTH-1 downto 0); -- PRBS data out
    txd_valid_spy  : out std_logic;
    usrclk_spy_rx  : in std_logic;  -- USRCLK for SPY RX data readout
    rxdata_spy     : in std_logic_vector(SPYDATAWIDTH-1 downto 0); -- PRBS data out
    rxd_valid_spy  : in std_logic;
    rxready_spy    : in std_logic; -- Flag for rx reset done
    -- Pattern generation for mgt_ddu
    usrclk_ddu_tx  : in std_logic; -- USRCLK for SPY TX data generation
    txdata_ddu1    : out std_logic_vector(DDUTXDWIDTH-1 downto 0); -- PRBS data out
    txdata_ddu2    : out std_logic_vector(DDUTXDWIDTH-1 downto 0); -- PRBS data out
    txdata_ddu3    : out std_logic_vector(DDUTXDWIDTH-1 downto 0); -- PRBS data out
    txdata_ddu4    : out std_logic_vector(DDUTXDWIDTH-1 downto 0); -- PRBS data out
    txd_valid_ddu  : out std_logic_vector(4 downto 1);
    -- Pattern checking for mgt_ddu
    usrclk_ddu_rx  : in std_logic;  -- USRCLK for DDU RX data readout
    rxdata_ddu1    : in std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
    rxdata_ddu2    : in std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
    rxdata_ddu3    : in std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
    rxdata_ddu4    : in std_logic_vector(DDURXDWIDTH-1 downto 0);   -- Data received
    rxd_valid_ddu  : in std_logic_vector(DDU_NRXLINK downto 1);
    rxready_ddu    : in std_logic; -- Flag for rx reset done
    -- Receiver signals for mgt_cfeb
    usrclk_mgtc    : in std_logic; -- USRCLK for RX data readout
    rxdata_cfeb1   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    rxdata_cfeb2   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    rxdata_cfeb3   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    rxdata_cfeb4   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    rxdata_cfeb5   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    rxdata_cfeb6   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    rxdata_cfeb7   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    rxd_valid_mgtc : in std_logic_vector(7 downto 1);   -- Flag for valid data;
    rxready_mgtc   : in std_logic; -- Flag for rx reset done
    -- Receiver signals for mgt_alct
    usrclk_mgta    : in std_logic; -- USRCLK for RX data readout
    rxdata_alct    : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    rxd_valid_alct : in std_logic;
    rxready_alct   : in std_logic; -- Flag for rx reset done
    rxdata_daq8    : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    rxdata_daq9    : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    rxdata_daq10   : in std_logic_vector(FEBDATAWIDTH-1 downto 0);  -- Data received
    mgta_dvalid    : in std_logic_vector(4 downto 1);   -- Flag for valid data;

    -- LED indicator
    led_out       : out std_logic_vector(7 downto 0);
    -- Reset
    reset         : out std_logic
    );
end prbs_tester;

architecture Behavioral of prbs_tester is

  component gtwiz_prbs_any is
    generic  (
      CHK_MODE    : integer := 0;
      INV_PATTERN : integer := 0;
      POLY_LENGHT : integer := 31;
      POLY_TAP    : integer := 3;
      NBITS       : integer := 16
      );
    port (
      RST      : in std_logic;
      CLK      : in std_logic;
      DATA_IN  : in std_logic_vector(NBITS-1 downto 0);
      EN       : in std_logic;
      DATA_OUT : out std_logic_vector(NBITS-1 downto 0) := (others => '1')
      );
  end component;

  component vio_1
    port (
      clk : in std_logic;
      probe_in0  : in std_logic_vector(3 downto 0);
      probe_in1  : in std_logic_vector(6 downto 0);
      probe_in2  : in std_logic;
      probe_in3  : in std_logic;
      probe_in4  : in std_logic_vector(15 downto 0);
      probe_in5  : in std_logic_vector(15 downto 0);
      probe_in6  : in std_logic_vector(15 downto 0);
      probe_in7  : in std_logic_vector(15 downto 0);
      probe_in8  : in std_logic_vector(15 downto 0);
      probe_in9  : in std_logic_vector(15 downto 0);
      probe_out0 : out std_logic;
      probe_out1 : out std_logic;
      probe_out2 : out std_logic;
      probe_out3 : out std_logic
      );
  end component;

  component ila_1
    port (
      clk : in std_logic;
      probe0  : in std_logic_vector(127 downto 0)
      );
  end component;

  signal txdata_spy_int : std_logic_vector(SPYDATAWIDTH-1 downto 0) := (others => '0');
  signal txd_valid_spy_int : std_logic;
  signal txdata_ddu_int : std_logic_vector(DDUTXDWIDTH-1 downto 0) := (others => '0');
  signal txdata_ddu_prbs_int : std_logic_vector(DDUTXDWIDTH-1 downto 0) := (others => '0');
  signal txdata_ddu_cntr_int : std_logic_vector(DDUTXDWIDTH-1 downto 0) := (others => '0');
  signal txd_valid_ddu_int : std_logic_vector(4 downto 1) := (others => '0');

  signal prbs_anyerr_spy  : std_logic_vector(SPYDATAWIDTH-1 downto 0) := (others => '0');
  signal prbs_match_spy : std_logic := '0';

  type rdwidth_array_ddu is array (1 to 4) of std_logic_vector(DDURXDWIDTH-1 downto 0);
  signal rxdata_ddu_ch : rdwidth_array_ddu;
  signal prbs_anyerr_ddu : rdwidth_array_ddu;
  signal prbs_match_ddu : std_logic_vector(4 downto 1) := (others => '0');

  type dwidth_array_feb is array (1 to 7) of std_logic_vector(FEBDATAWIDTH-1 downto 0);
  signal rxdata_cfeb_ch : dwidth_array_feb;
  signal rxdata_alct_ch : dwidth_array_feb;
  signal prbs_anyerr_cfeb : dwidth_array_feb;
  signal prbs_match_cfeb : std_logic_vector(7 downto 1) := (others => '0');
  signal prbs_anyerr_mgta : dwidth_array_feb;
  signal prbs_match_mgta : std_logic_vector(4 downto 1) := (others => '0');

  signal prbs_anyerr_alct  : std_logic_vector(FEBDATAWIDTH-1 downto 0) := (others => '0');
  signal prbs_match_alct : std_logic := '0';

  -- signal txdata_valid_int : std_logic_vector(NTXLINK-1 downto 0) := (others => '0');
  signal txd_spy_init_ctr : unsigned(15 downto 0) := (others => '0');
  signal txd_spy_gen_ctr  : unsigned(15 downto 0) := (others => '0');
  signal txd_ddu_init_ctr : unsigned(15 downto 0) := (others => '0');
  signal txd_ddu_gen_ctr  : unsigned(15 downto 0) := (others => '0');

  signal txd_valid_vio_int : std_logic := '0';
  signal global_reset : std_logic := '0';
  signal rxdata_errctr_reset_vio_int : std_logic := '0';
  signal prbsgen_reset_vio_int : std_logic := '0';

  signal spy_rxdata_err_ctr  : unsigned(16 downto 0) := (others=> '0');
  signal spy_rxdata_nml_ctr  : unsigned(63 downto 0) := (others=> '0');
  signal alct_rxdata_err_ctr : unsigned(16 downto 0) := (others=> '0');
  signal alct_rxdata_nml_ctr : unsigned(63 downto 0) := (others=> '0');

  type errctr_array_four is array (1 to 4) of unsigned(16 downto 0);
  type nmlctr_array_four is array (1 to 4) of unsigned(63 downto 0);
  signal ddu_rxdata_err_ctr : errctr_array_four;
  signal ddu_rxdata_nml_ctr : nmlctr_array_four;

  type errctr_array_ncfeb is array (1 to NCFEB) of unsigned(16 downto 0);
  type nmlctr_array_ncfeb is array (1 to NCFEB) of unsigned(63 downto 0);
  signal cfeb_rxdata_err_ctr : errctr_array_ncfeb;
  signal cfeb_rxdata_nml_ctr : nmlctr_array_ncfeb;

  signal ila_data : std_logic_vector(255 downto 0);
  signal ila_spy_rx : std_logic_vector(127 downto 0);
  signal ila_spy_tx : std_logic_vector(127 downto 0);
  signal ila_ddu_tx : std_logic_vector(127 downto 0);
  signal ila_ddu_rx : std_logic_vector(127 downto 0);

begin

  ---------------------------------------------------------------------------------------------------------------------
  -- PRBS stimulus
  ---------------------------------------------------------------------------------------------------------------------

  -- Single TX PRBS pattern generator
  spy_datagen_prbs : if SPY_PATTERN = 0 generate
    prbs_stimulus_spy_inst : gtwiz_prbs_any
      generic map (
        CHK_MODE    => 0,
        INV_PATTERN => 1,
        POLY_LENGHT => 31,
        POLY_TAP    => 28,
        NBITS       => SPYDATAWIDTH
        )
      port map (
        RST      => global_reset,
        CLK      => usrclk_spy_tx,
        DATA_IN  => (others => '0'),
        EN       => '1',
        DATA_OUT => txdata_spy_int
        );

    txdata_spy_init_inst : process (usrclk_spy_tx)
    begin
      if (rising_edge(usrclk_spy_tx)) then
        if (global_reset = '1') then
          txd_valid_spy_int <= '0';
          txd_spy_init_ctr <= x"0000";
        elsif (txd_spy_init_ctr < 100) then
          txd_valid_spy_int <= '0';
          txd_spy_init_ctr <= txd_spy_init_ctr + 1;
        else
          txd_valid_spy_int <= txd_valid_vio_int;
        end if;
      end if;
    end process;
  end generate;

  txdata_spy <= txdata_spy_int;
  txd_valid_spy <= txd_valid_spy_int;

  spy_datagen_cntr : if SPY_PATTERN = 1 generate
    txdata_spy_gen_inst : process (usrclk_spy_tx)
    begin
      if (rising_edge(usrclk_spy_tx)) then
        if (global_reset = '1') then
          txd_valid_spy_int <= '0';
          txdata_spy_int <= x"0000";
          txd_spy_init_ctr <= x"0000";
        else
          if (txd_spy_init_ctr < 100 or rxready_spy = '0') then
            txdata_spy_int <= x"0000";
            txd_valid_spy_int <= '0';
            txd_spy_init_ctr <= txd_spy_init_ctr + 1;
          else
            txdata_spy_int <= std_logic_vector(txd_spy_gen_ctr);
            txd_valid_spy_int <= txd_valid_vio_int;
          end if;
          txd_spy_gen_ctr <= txd_spy_gen_ctr + 1;
        end if;
      end if;
    end process;
  end generate;

  prbs_stimulus_ddu_inst : gtwiz_prbs_any
    generic map (
      CHK_MODE    => 0,
      INV_PATTERN => 1,
      POLY_LENGHT => 31,
      POLY_TAP    => 28,
      NBITS       => DDUTXDWIDTH
      )
    port map (
      RST      => prbsgen_reset_vio_int,
      CLK      => usrclk_ddu_tx,
      DATA_IN  => (others => '0'),
      EN       => '1',
      DATA_OUT => txdata_ddu_prbs_int
      );

  -- txdata_ddu_init_inst : process (usrclk_ddu_tx)
  -- begin
  --   if (rising_edge(usrclk_ddu_tx)) then
  --     if (global_reset = '1') then
  --       txd_valid_ddu_int <= x"0";
  --       txd_ddu_init_ctr <= x"0000";
  --     elsif (txd_ddu_init_ctr < 100) then
  --       txd_valid_ddu_int <= x"0";
  --       txd_ddu_init_ctr <= txd_ddu_init_ctr + 1;
  --     else
  --       txd_valid_ddu_int <= x"F";
  --     end if;
  --   end if;
  -- end process;

  txdata_ddu1 <= txdata_ddu_prbs_int;
  txdata_ddu2 <= txdata_ddu_prbs_int;
  txdata_ddu3 <= txdata_ddu_cntr_int;
  txdata_ddu4 <= txdata_ddu_cntr_int;
  txd_valid_ddu <= txd_valid_ddu_int;

  txdata_ddu_gen_inst : process (usrclk_ddu_tx)
  begin
    if (rising_edge(usrclk_ddu_tx)) then
      if (prbsgen_reset_vio_int = '1') then
        txd_valid_ddu_int <= x"0";
        txdata_ddu_cntr_int <= (others => '0');
        txd_ddu_init_ctr <= x"0000";
      else
        if (txd_ddu_init_ctr < 100 or rxready_ddu = '0') then
          txdata_ddu_cntr_int <= (others => '0');
          txd_valid_ddu_int <= x"0";
          txd_ddu_init_ctr <= txd_ddu_init_ctr + 1;
        else
          -- txdata_ddu_cntr_int <= x"503C" & std_logic_vector(txd_ddu_gen_ctr);
          txdata_ddu_cntr_int(15 downto 0) <= std_logic_vector(txd_ddu_gen_ctr);
          txd_valid_ddu_int <= (others => txd_valid_vio_int);
        end if;
        txd_ddu_gen_ctr <= txd_ddu_gen_ctr + 1;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------------------------------------------------
  -- PRBS Checking
  ---------------------------------------------------------------------------------------------------------------------
  -- Individual RX PRBS pattern checking
  prbs_checking_spy : gtwiz_prbs_any
    generic map (
      CHK_MODE    => 1,
      INV_PATTERN => 1,
      POLY_LENGHT => 31,
      POLY_TAP    => 28,
      NBITS       => SPYDATAWIDTH
      )
    port map (
      RST      => prbsgen_reset_vio_int,
      CLK      => usrclk_spy_rx,
      DATA_IN  => rxdata_spy,
      EN       => rxd_valid_spy,
      DATA_OUT => prbs_anyerr_spy
      );

  prbs_match_spy <= not or_reduce(prbs_anyerr_spy);

  -- DDU regime
  rxdata_ddu_ch(1) <= rxdata_ddu1;
  rxdata_ddu_ch(2) <= rxdata_ddu2;
  rxdata_ddu_ch(3) <= rxdata_ddu3;
  rxdata_ddu_ch(4) <= rxdata_ddu4;

  gen_prbs_checking_ddu : for I in 1 to DDU_NRXLINK generate
    prbs_checking_spy : gtwiz_prbs_any
      generic map (
        CHK_MODE    => 1,
        INV_PATTERN => 1,
        POLY_LENGHT => 31,
        POLY_TAP    => 28,
        NBITS       => DDURXDWIDTH
        )
      port map (
        RST      => prbsgen_reset_vio_int,
        CLK      => usrclk_ddu_rx,
        DATA_IN  => rxdata_ddu_ch(I),
        EN       => rxd_valid_ddu(I),
        DATA_OUT => prbs_anyerr_ddu(I)
        );

    prbs_match_ddu(I) <= not or_reduce(prbs_anyerr_ddu(I));
  end generate gen_prbs_checking_ddu;

  -- assign the rest of the prbs match for unused rx channels to true
  gen_prbs_assign_ddu : for I in DDU_NRXLINK+1 to 4 generate
    prbs_match_ddu(I) <= '1';
  end generate gen_prbs_assign_ddu;

  rxdata_cfeb_ch(1) <= rxdata_cfeb1;
  rxdata_cfeb_ch(2) <= rxdata_cfeb2;
  rxdata_cfeb_ch(3) <= rxdata_cfeb3;
  rxdata_cfeb_ch(4) <= rxdata_cfeb4;
  rxdata_cfeb_ch(5) <= rxdata_cfeb5;
  rxdata_cfeb_ch(6) <= rxdata_cfeb6;
  rxdata_cfeb_ch(7) <= rxdata_cfeb7;

  gen_prbs_checking_cfeb : for I in 1 to 7 generate
    prbs_checking_cfeb : gtwiz_prbs_any
      generic map (
        CHK_MODE    => 1,
        INV_PATTERN => 1,
        POLY_LENGHT => 31,
        POLY_TAP    => 28,
        NBITS       => FEBDATAWIDTH
        )
      port map (
        RST      => prbsgen_reset_vio_int,
        CLK      => usrclk_mgtc,
        DATA_IN  => rxdata_cfeb_ch(I),
        EN       => rxd_valid_mgtc(I),
        DATA_OUT => prbs_anyerr_cfeb(I)
        );

    prbs_match_cfeb(I) <= not or_reduce(prbs_anyerr_cfeb(I));
  end generate gen_prbs_checking_cfeb;

  -- Checking for 1 channel alct data
  prbs_checking_alct : gtwiz_prbs_any
    generic map (
      CHK_MODE    => 1,
      INV_PATTERN => 1,
      POLY_LENGHT => 31,
      POLY_TAP    => 28,
      NBITS       => FEBDATAWIDTH
      )
    port map (
      RST      => prbsgen_reset_vio_int,
      CLK      => usrclk_mgta,
      DATA_IN  => rxdata_alct,
      EN       => rxd_valid_alct,
      DATA_OUT => prbs_anyerr_alct
      );

  prbs_match_alct <= not or_reduce(prbs_anyerr_alct);

  -- LED indicator for prbs_match of link(I)
  led_out(0) <= not and_reduce(prbs_match_cfeb(4 downto 1));
  led_out(1) <= not (and_reduce(prbs_match_cfeb(7 downto 5)));
  led_out(2) <= not prbs_match_alct;
  led_out(3) <= not prbs_match_spy;
  led_out(4) <= not and_reduce(prbs_match_ddu);
  led_out(7 downto 5) <= "111";         -- set the LEDs off

  reset <= global_reset;

  rxdata_errcounting_spy : process (usrclk_spy_rx)
  begin
    if (rising_edge(usrclk_spy_rx)) then
      if (rxdata_errctr_reset_vio_int = '1') then
        spy_rxdata_nml_ctr <= (others => '0');
        spy_rxdata_err_ctr <= (others => '0');
      elsif (rxready_spy = '1') then
        spy_rxdata_nml_ctr <= spy_rxdata_nml_ctr + 1;
        if (prbs_match_spy = '0') then
          spy_rxdata_err_ctr <= spy_rxdata_err_ctr + 1;
        end if;
      end if;
    end if;
  end process;

  rxdata_errcounting_ddu : process (usrclk_ddu_rx)
  begin
    if (rising_edge(usrclk_ddu_rx)) then
      if (rxdata_errctr_reset_vio_int = '1') then
        for I in 1 to DDU_NRXLINK loop
          ddu_rxdata_nml_ctr(I) <= (others => '0');
          ddu_rxdata_err_ctr(I) <= (others => '0');
        end loop;
      elsif (rxready_ddu = '1') then
        for I in 1 to DDU_NRXLINK loop
          ddu_rxdata_nml_ctr(I) <= ddu_rxdata_nml_ctr(I) + 1;
          if (prbs_match_ddu(I) = '0') then
            ddu_rxdata_err_ctr(I) <= ddu_rxdata_err_ctr(I) + 1;
          end if;
        end loop;
      end if;
    end if;
  end process;

  rxdata_errcounting_cfeb : process (usrclk_mgtc)
  begin
    if (rising_edge(usrclk_mgtc)) then
      if (rxdata_errctr_reset_vio_int = '1') then
        for I in 1 to NCFEB loop
          cfeb_rxdata_nml_ctr(I) <= (others => '0');
          cfeb_rxdata_err_ctr(I) <= (others => '0');
        end loop;
      elsif (rxready_mgtc = '1') then
        for I in 1 to NCFEB loop
          cfeb_rxdata_nml_ctr(I) <= cfeb_rxdata_nml_ctr(I) + 1;
          if (prbs_match_cfeb(I) = '0') then
            cfeb_rxdata_err_ctr(I) <= cfeb_rxdata_err_ctr(I) + 1;
          end if;
        end loop;
      end if;
    end if;
  end process;

  rxdata_errcounting_alct : process (usrclk_mgta)
  begin
    if (rising_edge(usrclk_mgta)) then
      if (rxdata_errctr_reset_vio_int = '1') then
        alct_rxdata_nml_ctr <= (others => '0');
        alct_rxdata_err_ctr <= (others => '0');
      elsif (rxready_alct = '1') then
        alct_rxdata_nml_ctr <= alct_rxdata_nml_ctr + 1;
        if (prbs_match_alct = '0') then
          alct_rxdata_err_ctr <= alct_rxdata_err_ctr + 1;
        end if;
      end if;
    end if;
  end process;

  prbs_test_vio_inst : vio_1
    port map (
      clk => sysclk,
      probe_in0 => prbs_match_ddu,
      probe_in1 => prbs_match_cfeb,
      probe_in2 => rxd_valid_spy,
      probe_in3 => rxready_ddu,
      probe_in4 => std_logic_vector(spy_rxdata_err_ctr(16 downto 1)),
      probe_in5 => std_logic_vector(ddu_rxdata_err_ctr(1)(16 downto 1)),
      probe_in6 => std_logic_vector(spy_rxdata_nml_ctr(39 downto 24)),
      probe_in7 => std_logic_vector(ddu_rxdata_nml_ctr(1)(39 downto 24)),
      probe_in8 => std_logic_vector(txd_spy_init_ctr),
      probe_in9 => std_logic_vector(alct_rxdata_nml_ctr(39 downto 24)),
      probe_out0 => rxdata_errctr_reset_vio_int,
      probe_out1 => prbsgen_reset_vio_int,
      probe_out2 => txd_valid_vio_int,
      probe_out3 => global_reset
      );

  spy_tx_ila_inst : ila_1
    port map (
      clk => usrclk_spy_tx,
      probe0 => ila_spy_tx
      );

  ila_spy_tx(15 downto 0)   <= txdata_spy_int;
  ila_spy_tx(16)            <= txd_valid_spy_int;
  ila_spy_tx(34 downto 19)  <= std_logic_vector(txd_spy_init_ctr);

  spy_rx_ila_inst : ila_1
    port map (
      clk => usrclk_spy_rx,
      probe0 => ila_spy_rx
      );

  ila_spy_rx(15 downto 0)   <= rxdata_spy;
  ila_spy_rx(16)            <= rxd_valid_spy;
  ila_spy_rx(17)            <= rxready_spy;
  ila_spy_rx(18)            <= rxready_spy;
  ila_spy_rx(34 downto 19)  <= prbs_anyerr_spy;

  ddu_tx_ila_inst : ila_1
    port map (
      clk => usrclk_ddu_tx,
      probe0 => ila_ddu_tx
      );

  -- ila_ddu_tx(31 downto 0)   <= txdata_ddu_int;
  ila_ddu_tx(15 downto 0)   <= txdata_ddu_prbs_int;
  ila_ddu_tx(31 downto 16)  <= txdata_ddu_cntr_int;
  ila_ddu_tx(32)            <= txd_valid_ddu_int(1);
  ila_ddu_tx(48 downto 33)  <= std_logic_vector(txd_ddu_init_ctr);
  ila_ddu_tx(64 downto 49)  <= txdata_spy_int;

  ddu_rx_ila_inst : ila_1
    port map (
      clk => usrclk_ddu_rx,
      probe0 => ila_ddu_rx
      );

  ila_ddu_rx(15 downto 0)   <= rxdata_ddu_ch(1);
  ila_ddu_rx(31 downto 16)  <= rxdata_ddu_ch(3);
  ila_ddu_rx(35 downto 32)  <= rxd_valid_ddu;
  ila_ddu_rx(36)            <= rxready_ddu;
  ila_ddu_rx(52 downto 37)  <= prbs_anyerr_ddu(1);
  ila_ddu_rx(68 downto 53)  <= prbs_anyerr_ddu(3);


end Behavioral;
