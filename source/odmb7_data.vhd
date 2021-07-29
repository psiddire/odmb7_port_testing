
library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

-- consider make this 2 different modules
-- one for dcfeb, one for alct+otmb
entity odmb7_data is
    generic (
      NCFEB       : integer range 1 to 7 := NCFEB  -- Number of DCFEBS, 7 for ME1/1, 5
      );
  port (

    OTMB       : in std_logic_vector(17 downto 0);
    ALCT       : in std_logic_vector(17 downto 0);
    CMSCLK     : in std_logic;
    SYSCLK80   : in std_logic;
    SYSCLK160  : in std_logic;
    RESET      : in std_logic;
    L1ACNT_FIFO_RST : in std_logic;
    KILL       : in std_logic_vector(NCFEB+2 downto 1);
    CAFIFO_L1A : in std_logic;
    CAFIFO_L1A_MATCH_IN : in std_logic_vector(NCFEB+2 downto 1);
    INT_L1A : in std_logic;
    INT_L1A_MATCH : in std_logic_vector(NCFEB downto 1);
    DATA_FIFO_WE : in std_logic_vector(NCFEB+2 downto 1); 
    DATA_FIFO_RE : in std_logic_vector(NCFEB+2 downto 1);
    NWORDS_DUMMY   : in std_logic_vector(15 downto 0);

    DCFEB_TCK        : in std_logic_vector(NCFEB downto 1);
    DCFEB_TDO        : out std_logic_vector(NCFEB downto 1);
    DCFEB_TMS  : in std_logic;  
    DCFEB_TDI  : in std_logic;
    RX_DCFEB_DATA_VALID : in std_logic_vector(NCFEB downto 1); 

    EOF_DATA    : out std_logic_vector(NCFEB+2 downto 1);
    ALCT_DV     : out std_logic;
    OTMB_DV     : out std_logic;
    DCFEB0_DV   : out std_logic;
    DCFEB0_DATA : out std_logic_vector(15 downto 0);
    DCFEB1_DV   : out std_logic;
    DCFEB1_DATA : out std_logic_vector(15 downto 0);
    DCFEB2_DV   : out std_logic;
    DCFEB2_DATA : out std_logic_vector(15 downto 0);
    DCFEB3_DV   : out std_logic;
    DCFEB3_DATA : out std_logic_vector(15 downto 0);
    DCFEB4_DV   : out std_logic;
    DCFEB4_DATA : out std_logic_vector(15 downto 0);
    DCFEB5_DV   : out std_logic;
    DCFEB5_DATA : out std_logic_vector(15 downto 0);
    DCFEB6_DV   : out std_logic;
    DCFEB6_DATA : out std_logic_vector(15 downto 0);

    DATA_FIFO_HALF_FULL : std_logic_vector (NCFEB downto 2);

    );
end odmb7_data;

architecture data_Arch of odmb7_data is

  signal gen_dcfeb_sel       : std_logic := '0';

  signal rx_alct_data_valid  : std_logic;
  signal alct_data_valid     : std_logic;
  signal gen_alct_data_valid : std_logic;

  signal gen_alct_data       : std_logic_vector(15 downto 0);
  signal alct_q              : std_logic_vector(17 downto 0);
  signal alct_qq             : std_logic_vector(17 downto 0);

  signal alct_fifo_data_valid : std_logic;
  signal alct_fifo_data_in    : std_logic_vector(17 downto 0);
  signal alct_fifo_data_out   : std_logic_vector (17 downto 0);

  signal alct_fifo_data_out   : std_logic;
  signal alct_fifo_full       : std_logic;
  signal alct_fifo_empty      : std_logic;

  signal rx_otmb_data_valid  : std_logic;
  signal otmb_data_valid     : std_logic;
  signal gen_otmb_data_valid : std_logic;

  signal gen_otmb_data       : std_logic_vector(15 downto 0);
  signal otmb_q              : std_logic_vector(17 downto 0);
  signal otmb_qq             : std_logic_vector(17 downto 0);

  signal otmb_fifo_data_valid : std_logic;
  signal otmb_fifo_data_in    : std_logic_vector(17 downto 0);
  signal otmb_fifo_data_out   : std_logic_vector (17 downto 0);

  signal otmb_fifo_data_out   : std_logic;
  signal otmb_fifo_full       : std_logic;
  signal otmb_fifo_empty      : std_logic;

  type dcfeb_addr_type is array (1 to NCFEB) of std_logic_vector(3 downto 0);
  constant dcfeb_addr  : dcfeb_addr_type := ("0001", "0010", "0011", "0100", "0101", "0110", "0111");

  type dcfeb_data_type is array (NFEB downto 1) of std_logic_vector(15 downto 0);
  signal gen_dcfeb_data                       : dcfeb_data_type;
  signal rx_dcfeb_data                        : dcfeb_data_type;
  signal dcfeb_data                           : dcfeb_data_type;

  signal gen_dcfeb_data_valid                 : std_logic_vector(NFEB downto 1);
  signal dcfeb_data_valid_d, dcfeb_data_valid : std_logic_vector(NFEB downto 1);

  signal gen_dcfeb_data  : std_logic_vector(15 downto 0);
  signal dcfeb_adc_mask  : std_logic_vector(11 downto 0);
  signal dcfeb_fsel  : std_logic_vector(32 downto 0);
  signal dcfeb_jtag_ir  : std_logic_vector(9 downto 0);
  signal gen_tdo : std_logic_vector(NCFEB downto 1) := (others => '0');

  type ext_dcfeb_fifo_data_type is array (NFEB downto 1) of std_logic_vector(17 downto 0);
  signal eofgen_dcfeb_fifo_in    : ext_dcfeb_fifo_data_type;
  signal eofgen_dcfeb_data_valid : std_logic_vector(NFEB downto 1);
  signal dcfeb_fifo_out          : ext_dcfeb_fifo_data_type;
  signal pulse_eof40, pulse_eof160  : std_logic_vector(NFEB downto 1);

begin

  -- gen ALCT/OTMB data
  ALCT_OTMB_DATA_GEN_PM : alct_otmb_data_gen
    port map(
      clk            => cmsclk,
      rst            => reset,
      l1a            => cafifo_l1a,
      alct_l1a_match => cafifo_l1a_match_in(NFEB+2),
      otmb_l1a_match => cafifo_l1a_match_in(NFEB+1),
      nwords_dummy   => nwords_dummy,

      alct_dv   => gen_alct_data_valid,
      alct_data => gen_alct_data,
      otmb_dv   => gen_otmb_data_valid,
      otmb_data => gen_otmb_data
      );

  GENOTMBSYNC : for index in 0 to 17 generate
  begin
    FDALCT  : FD port map(alct_q(index), cmsclk, alct(index));
    FDALCTQ : FD port map(alct_qq(index), cmsclk, alct_q(index));
    FDOTMB  : FD port map(otmb_q(index), cmsclk, otmb(index));
    FDOTMBQ : FD port map(otmb_qq(index), cmsclk, otmb_q(index));
  end generate GENOTMBSYNC;

  rx_alct_data_valid <= not alct_qq(17);
  alct_data_valid    <= '0' when kill(9) = '1' else
                        rx_alct_data_valid when (gen_dcfeb_sel = '0') else
                        gen_alct_data_valid;

  alct_data <= alct_qq(15 downto 0) when (gen_dcfeb_sel = '0') else
               gen_alct_data;

  rx_otmb_data_valid <= not otmb_qq(17);
  otmb_data_valid    <= '0' when kill(8) = '1' else
                        rx_otmb_data_valid when (gen_dcfeb_sel = '0') else
                        gen_otmb_data_valid;

  otmb_data <= otmb_qq(15 downto 0) when (gen_dcfeb_sel = '0') else
               gen_otmb_data;

  ALCT_EOFGEN_PM : EOFGEN
    port map (
      clk => cmsclk,
      rst => reset,

      dv_in   => alct_data_valid,
      data_in => alct_data,

      dv_out   => alct_fifo_data_valid,
      data_out => alct_fifo_data_in
      );

  OTMB_EOFGEN_PM : EOFGEN
    port map (
      clk => cmsclk,
      rst => reset,

      dv_in   => otmb_data_valid,
      data_in => otmb_data,

      dv_out   => otmb_fifo_data_valid,
      data_out => otmb_fifo_data_in
      );


  -- datafifo for alct and otmb
  datafifo_alct_pm : datafifo_40mhz
    port map(
      rst       => l1acnt_fifo_rst,
      wr_clk    => cmsclk,
      rd_clk    => sysclk80,
      din       => alct_fifo_data_in,
      wr_en     => data_fifo_we(NFEB+2),
      rd_en     => data_fifo_re(NFEB+2),
      dout      => alct_fifo_data_out,
      full      => alct_fifo_full,
      empty     => alct_fifo_empty,
      prog_full => data_fifo_half_full(NFEB+2)
      );

  datafifo_otmb_pm : datafifo_40mhz
    port map(
      rst       => l1acnt_fifo_rst,
      wr_clk    => cmsclk,
      rd_clk    => sysclk80,
      din       => otmb_fifo_data_in,
      wr_en     => data_fifo_we(NFEB+1),
      rd_en     => data_fifo_re(NFEB+1),
      dout      => otmb_fifo_data_out,
      full      => otmb_fifo_full,
      empty     => otmb_fifo_empty,
      prog_full => data_fifo_half_full(NFEB+1)
      );

  -- eof_data 
  PULSEEOFALCT : PULSE2SAME port map(eof_data(NFEB+2), cmsclk, reset, alct_fifo_data_in(17));
  PULSEEOFOTMB : PULSE2SAME port map(eof_data(NFEB+1), cmsclk, reset, otmb_fifo_data_in(17));

  GEN_DCFEB : for I in NFEB downto 1 generate
  begin

    DCFEB_V6_PM : DCFEB_V6
      generic map(
        dcfeb_addr => dcfeb_addr(I))
      port map(
        clk          => cmsclk,
        dcfebclk     => sysclk160,
        rst          => reset,
        l1a          => int_l1a,
        l1a_match    => int_l1a_match(I),
        tx_ack       => '1',
        nwords_dummy => nwords_dummy,

        dcfeb_dv      => gen_dcfeb_data_valid(I),
        dcfeb_data    => gen_dcfeb_data(I),
        adc_mask      => dcfeb_adc_mask(I),
        dcfeb_fsel    => dcfeb_fsel(I),
        dcfeb_jtag_ir => dcfeb_jtag_ir(I),
        trst          => reset,
        tck           => dcfeb_tck(I),
        tms           => dcfeb_tms,
        tdi           => dcfeb_tdi,
        rtn_shft_en   => open,
        tdo           => gen_tdo(I));

    dcfeb_data_valid_d(I) <= '0' when kill(I) = '1' else
                             rx_dcfeb_data_valid(I) when (gen_dcfeb_sel = '0') else
                             gen_dcfeb_data_valid(I);
    dcfeb_data(I) <= rx_dcfeb_data(I) when (gen_dcfeb_sel = '0') else gen_dcfeb_data(I);

    FD_DCFEBDV   : FDC port map(dcfeb_data_valid(I), sysclk160, reset, dcfeb_data_valid_d(I));
    FD_DCFEBDATA : FDVEC port map(dcfeb_fifo_in(I), sysclk160, reset, dcfeb_data(I));

    --masked_l1a_match(I) <= '0' when mask_l1a(I) = '1' else int_l1a_match(I);
    --DS_L1AMATCH : DELAY_SIGNAL generic map(1)
    --  port map(DCFEB_L1A_MATCH(I), cmsclk, cable_dly, masked_l1a_match(I));
    
    --int_tdo(I) <= dcfeb_tdo(I) when (gen_dcfeb_sel = '0') else gen_tdo(I);
    dcfeb_tdo(I) <= gen_tdo(I);

    EOFGEN_PM : EOFGEN
      port map (
        clk => sysclk160,
        rst => reset,

        dv_in   => dcfeb_data_valid(I),
        data_in => dcfeb_fifo_in(I),

        dv_out   => eofgen_dcfeb_data_valid(I),
        data_out => eofgen_dcfeb_fifo_in(I)
        );

    datafifo_dcfeb_pm : datafifo_dcfeb
      port map(
        --need change due to use auto-kill
        --rst       => dcfeb_fifo_rst(I),
        rst       => l1acnt_fifo_rst(I),
        wr_clk    => sysclk160,
        rd_clk    => sysclk80,
        din       => eofgen_dcfeb_fifo_in(I),
        wr_en     => data_fifo_we(I),
        rd_en     => data_fifo_re(I),
        dout      => dcfeb_fifo_out(I),
        full      => dcfeb_fifo_full(I),
        empty     => dcfeb_fifo_empty(I),
        prog_full => data_fifo_half_full(I)
        );

    --pulse_eof160(i) <= eofgen_dcfeb_fifo_in(I)(17) and not kill(i) and not bad_dcfeb_pulse_long(i);
    pulse_eof160(i) <= eofgen_dcfeb_fifo_in(I)(17) and not kill(i);
    PULSEEOFDCFEB : PULSE2SLOW port map(pulse_eof40(i), cmsclk, sysclk160, reset, pulse_eof160(i));
    DS_EOF_PUSH   : DELAY_SIGNAL generic map(push_dlyp4) port map(eof_data(I), cmsclk, push_dlyp4, pulse_eof40(I));
  end generate GEN_DCFEB;

end data_Arch;
