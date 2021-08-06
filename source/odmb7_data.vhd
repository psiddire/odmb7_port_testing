library IEEE;
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;
use work.odmb7_ip_components.all;
use work.ucsb_types.all;

-- consider make this 2 different modules
-- one for dcfeb, one for alct+otmb
entity odmb7_data is
    generic (
      NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
      );
  port (

    CMSCLK     : in std_logic;
    SYSCLK80   : in std_logic;
    SYSCLK160  : in std_logic;
    RESET      : in std_logic;
    L1ACNT_FIFO_RST : in std_logic;
    KILL       : in std_logic_vector(NCFEB+2 downto 1);
    CAFIFO_L1A : in std_logic;
    CAFIFO_L1A_MATCH_IN : in std_logic_vector(NCFEB+2 downto 1);
    DCFEB_L1A : in std_logic;
    DCFEB_L1A_MATCH : in std_logic_vector(NCFEB downto 1);
    NWORDS_DUMMY   : in std_logic_vector(15 downto 0);

    DCFEB_TCK        : in std_logic_vector(NCFEB downto 1);
    DCFEB_TDO        : out std_logic_vector(NCFEB downto 1);
    DCFEB_TMS  : in std_logic;  
    DCFEB_TDI  : in std_logic;

    DATAFIFO_MASK : in std_logic;
    DCFEB_FIFO_RST : in std_logic_vector (NCFEB downto 1); -- auto-kill related

    EOF_DATA    : out std_logic_vector(NCFEB+2 downto 1);

    OTMB_DATA_IN       : in std_logic_vector(17 downto 0);
    ALCT_DATA_IN       : in std_logic_vector(17 downto 0);

    DCFEB_DV_IN        : in std_logic_vector(NCFEB downto 1);

    DCFEB1_DATA_IN      : in std_logic_vector(15 downto 0);
    DCFEB2_DATA_IN      : in std_logic_vector(15 downto 0);
    DCFEB3_DATA_IN      : in std_logic_vector(15 downto 0);
    DCFEB4_DATA_IN      : in std_logic_vector(15 downto 0);
    DCFEB5_DATA_IN      : in std_logic_vector(15 downto 0);
    DCFEB6_DATA_IN      : in std_logic_vector(15 downto 0);
    DCFEB7_DATA_IN      : in std_logic_vector(15 downto 0);

    GEN_DCFEB_SEL       : in std_logic;

    OTMB_FIFO_DATA_OUT       : out std_logic_vector(17 downto 0);
    OTMB_FIFO_DV       : out std_logic;

    ALCT_FIFO_DATA_OUT       : out std_logic_vector(17 downto 0);
    ALCT_FIFO_DV       : out std_logic;

    DCFEB1_FIFO_OUT      : out std_logic_vector(17 downto 0);
    DCFEB2_FIFO_OUT      : out std_logic_vector(17 downto 0);
    DCFEB3_FIFO_OUT      : out std_logic_vector(17 downto 0);
    DCFEB4_FIFO_OUT      : out std_logic_vector(17 downto 0);
    DCFEB5_FIFO_OUT      : out std_logic_vector(17 downto 0);
    DCFEB6_FIFO_OUT      : out std_logic_vector(17 downto 0);
    DCFEB7_FIFO_OUT      : out std_logic_vector(17 downto 0);
    DCFEB_DV_OUT         : out std_logic_vector(NCFEB downto 1);

    DATA_FIFO_RE        : in std_logic_vector(NCFEB+2 downto 1);
    DATA_FIFO_EMPTY     : out std_logic_vector(NCFEB+2 downto 1);
    DATA_FIFO_HALF_FULL : out std_logic_vector (NCFEB+2 downto 1)

    );
end odmb7_data;

architecture data_Arch of odmb7_data is
--
  component EOFGEN is
    port(
      clk : in std_logic;
      rst : in std_logic;

      dv_in   : in std_logic;
      data_in : in std_logic_vector(15 downto 0);

      dv_out   : out std_logic;
      data_out : out std_logic_vector(17 downto 0)
      );

  end component;

  component DCFEB_V6 is
    generic (
      dcfeb_addr : std_logic_vector(3 downto 0) := "1000"  -- DCFEB address
      );  
    port
      (clk          : in std_logic;
       dcfebclk     : in std_logic;
       rst          : in std_logic;
       l1a          : in std_logic;
       l1a_match    : in std_logic;
       tx_ack       : in std_logic;
       nwords_dummy : in std_logic_vector(15 downto 0);

       dcfeb_dv      : out std_logic;
       dcfeb_data    : out std_logic_vector(15 downto 0);
       adc_mask      : out std_logic_vector(11 downto 0);
       dcfeb_fsel    : out std_logic_vector(63 downto 0);
       dcfeb_jtag_ir : out std_logic_vector(9 downto 0);
       trst          : in  std_logic;
       tck           : in  std_logic;
       tms           : in  std_logic;
       tdi           : in  std_logic;
       rtn_shft_en   : out std_logic;
       injpls        : in std_logic; 
       extpls        : in std_logic;
       bc0           : in std_logic;
       resync        : in std_logic;
       tdo           : out std_logic);
  end component;

  component alct_otmb_data_gen is
    port(
      clk            : in std_logic;
      rst            : in std_logic;
      l1a            : in std_logic;
      alct_l1a_match : in std_logic;
      otmb_l1a_match : in std_logic;
      nwords_dummy   : in std_logic_vector(15 downto 0);

      alct_dv   : out std_logic;
      alct_data : out std_logic_vector(15 downto 0);
      otmb_dv   : out std_logic;
      otmb_data : out std_logic_vector(15 downto 0));
  end component;

  --signal gen_dcfeb_sel       : std_logic := '0';

  signal rx_alct_data_valid  : std_logic;
  signal alct_data_valid     : std_logic;
  signal gen_alct_data_valid : std_logic;

  signal gen_alct_data       : std_logic_vector(15 downto 0);
  signal alct_data           : std_logic_vector(15 downto 0);
  signal alct_q              : std_logic_vector(17 downto 0);
  signal alct_qq             : std_logic_vector(17 downto 0);

  signal alct_fifo_data_valid : std_logic;
  signal alct_fifo_data_in    : std_logic_vector(17 downto 0);
  signal alct_fifo_full       : std_logic;
  signal alct_fifo_empty      : std_logic;

  signal rx_otmb_data_valid  : std_logic;
  signal otmb_data_valid     : std_logic;
  signal gen_otmb_data_valid : std_logic;

  signal otmb_data           : std_logic_vector(15 downto 0);
  signal gen_otmb_data       : std_logic_vector(15 downto 0);
  signal otmb_q              : std_logic_vector(17 downto 0);
  signal otmb_qq             : std_logic_vector(17 downto 0);

  signal otmb_fifo_data_valid : std_logic;
  signal otmb_fifo_data_in    : std_logic_vector(17 downto 0);
  signal otmb_fifo_full       : std_logic;
  signal otmb_fifo_empty      : std_logic;

  signal dcfeb_fifo_empty  : std_logic_vector(NCFEB downto 1);
  signal dcfeb_fifo_full   : std_logic_vector(NCFEB downto 1);

  type dcfeb_addr_type is array (1 to NCFEB) of std_logic_vector(3 downto 0);
  constant dcfeb_addr  : dcfeb_addr_type := ("0001", "0010", "0011", "0100", "0101", "0110", "0111");
  constant push_dly    : integer := 63;  -- It needs to be > alct/otmb_push_dly
  constant push_dlyp4  : integer := push_dly+4;  -- push_dly+4

  type dcfeb_data_type is array (NCFEB downto 1) of std_logic_vector(15 downto 0);
  signal gen_dcfeb_data                       : dcfeb_data_type;
  signal rx_dcfeb_data                        : dcfeb_data_type;
  --signal dcfeb_data                           : dcfeb_data_type;

  signal gen_dcfeb_data_valid                 : std_logic_vector(NCFEB downto 1);
  signal dcfeb_data_valid_d, dcfeb_data_valid : std_logic_vector(NCFEB downto 1);

  type dcfeb_adc_mask_type is array (NCFEB downto 1) of std_logic_vector(11 downto 0);
  signal dcfeb_adc_mask : dcfeb_adc_mask_type;

  type dcfeb_fsel_type is array (NCFEB downto 1) of std_logic_vector(63 downto 0);
  signal dcfeb_fsel : dcfeb_fsel_type;

  type dcfeb_jtag_ir_type is array (NCFEB downto 1) of std_logic_vector(9 downto 0);
  signal dcfeb_jtag_ir : dcfeb_jtag_ir_type;

  signal gen_tdo : std_logic_vector(NCFEB downto 1) := (others => '0');

  type dcfeb_fifo_data_type is array (NCFEB downto 1) of std_logic_vector(15 downto 0);
  signal dcfeb_fifo_in : dcfeb_fifo_data_type;
  signal dcfeb_data : dcfeb_fifo_data_type;
  signal dcfeb_data_in_inner : dcfeb_fifo_data_type;

  type ext_dcfeb_fifo_data_type is array (NCFEB downto 1) of std_logic_vector(17 downto 0);
  signal eofgen_dcfeb_fifo_in    : ext_dcfeb_fifo_data_type;
  signal eofgen_dcfeb_data_valid : std_logic_vector(NCFEB downto 1);
  signal dcfeb_fifo_out          : ext_dcfeb_fifo_data_type;

  signal data_fifo_we            : std_logic_vector (NCFEB+2 downto 1);
  signal pulse_eof40, pulse_eof160  : std_logic_vector(NCFEB downto 1);

begin

  -- gen ALCT/OTMB data
  ALCT_OTMB_DATA_GEN_PM : alct_otmb_data_gen
    port map(
      clk            => cmsclk,
      rst            => reset,
      l1a            => cafifo_l1a,
      alct_l1a_match => cafifo_l1a_match_in(NCFEB+2),
      otmb_l1a_match => cafifo_l1a_match_in(NCFEB+1),
      nwords_dummy   => nwords_dummy,

      alct_dv   => gen_alct_data_valid,
      alct_data => gen_alct_data,
      otmb_dv   => gen_otmb_data_valid,
      otmb_data => gen_otmb_data
      );

  GENOTMBSYNC : for index in 0 to 17 generate
  begin
    FDALCT  : FD port map(Q => alct_q(index), C => cmsclk, D => alct_data_in(index));
    FDALCTQ : FD port map(Q => alct_qq(index), C => cmsclk, D => alct_q(index));
    FDOTMB  : FD port map(Q => otmb_q(index), C => cmsclk, D => otmb_data_in(index));
    FDOTMBQ : FD port map(Q => otmb_qq(index), C => cmsclk, D => otmb_q(index));
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
      srst       => l1acnt_fifo_rst,
      wr_clk    => cmsclk,
      rd_clk    => sysclk80,
      din       => alct_fifo_data_in,
      wr_en     => data_fifo_we(NCFEB+2),
      rd_en     => data_fifo_re(NCFEB+2),
      dout      => alct_fifo_data_out,
      full      => alct_fifo_full,
      empty     => alct_fifo_empty,
      prog_full => data_fifo_half_full(NCFEB+2)
      );

  datafifo_otmb_pm : datafifo_40mhz
    port map(
      srst       => l1acnt_fifo_rst,
      wr_clk    => cmsclk,
      rd_clk    => sysclk80,
      din       => otmb_fifo_data_in,
      wr_en     => data_fifo_we(NCFEB+1),
      rd_en     => data_fifo_re(NCFEB+1),
      dout      => otmb_fifo_data_out,
      full      => otmb_fifo_full,
      empty     => otmb_fifo_empty,
      prog_full => data_fifo_half_full(NCFEB+1)
      );

  -- eof_data 
  PULSEEOFALCT : PULSE2SAME port map(DOUT => eof_data(NCFEB+2), CLK_DOUT => cmsclk, RST => reset, DIN => alct_fifo_data_in(17));
  PULSEEOFOTMB : PULSE2SAME port map(DOUT => eof_data(NCFEB+1), CLK_DOUT => cmsclk, RST => reset, DIN => otmb_fifo_data_in(17));

  dcfeb_data_in_inner(1) <= dcfeb1_data_in;
  dcfeb_data_in_inner(2) <= dcfeb2_data_in;
  dcfeb_data_in_inner(3) <= dcfeb3_data_in;
  dcfeb_data_in_inner(4) <= dcfeb4_data_in;
  dcfeb_data_in_inner(5) <= dcfeb5_data_in;
  dcfeb_data_in_inner(6) <= dcfeb6_data_in;
  dcfeb_data_in_inner(7) <= dcfeb7_data_in;
  
  GEN_DCFEB : for I in NCFEB downto 1 generate
  begin

    DCFEB_V6_PM : DCFEB_V6
      generic map(
        dcfeb_addr => dcfeb_addr(I))
      port map(
        clk          => cmsclk,
        dcfebclk     => sysclk160,
        rst          => reset,
        l1a          => dcfeb_l1a,
        l1a_match    => dcfeb_l1a_match(I),
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
        injpls        => '0', 
        extpls        => '0',
        bc0           => '0',
        resync        => '0',
        tdo           => gen_tdo(I));

    dcfeb_data_valid_d(I) <= '0' when kill(I) = '1' else
                             dcfeb_dv_in(I) when (gen_dcfeb_sel = '0') else
                             gen_dcfeb_data_valid(I);
    dcfeb_data(I) <= dcfeb_data_in_inner(I) when (gen_dcfeb_sel = '0') else gen_dcfeb_data(I);

    FD_DCFEBDV   : FDC port map(Q => dcfeb_data_valid(I), C => sysclk160, CLR => reset, D => dcfeb_data_valid_d(I));
    FD_DCFEBDATA : FDVEC port map(DOUT => dcfeb_fifo_in(I), CLK => sysclk160, RST => reset, DIN => dcfeb_data(I));

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
        srst      => l1acnt_fifo_rst,
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
    PULSEEOFDCFEB : PULSE2SLOW port map(DOUT => pulse_eof40(i), CLK_DOUT => cmsclk, CLK_DIN => sysclk160, RST => reset, DIN => pulse_eof160(i));
    DS_EOF_PUSH   : DELAY_SIGNAL generic map(push_dlyp4) port map(DOUT => eof_data(I), CLK => cmsclk, NCYCLES => push_dlyp4, DIN => pulse_eof40(I));

    data_fifo_we(I) <= eofgen_dcfeb_data_valid(I) and datafifo_mask and not dcfeb_fifo_rst(I);
    data_fifo_we(NCFEB+2) <= alct_fifo_data_valid and datafifo_mask;
    data_fifo_we(NCFEB+1) <= otmb_fifo_data_valid and datafifo_mask;

  end generate GEN_DCFEB;

  dcfeb1_fifo_out <= dcfeb_fifo_out(1);
  dcfeb2_fifo_out <= dcfeb_fifo_out(2);
  dcfeb3_fifo_out <= dcfeb_fifo_out(3);
  dcfeb4_fifo_out <= dcfeb_fifo_out(4);
  dcfeb5_fifo_out <= dcfeb_fifo_out(5);
  dcfeb6_fifo_out <= dcfeb_fifo_out(6);
  dcfeb7_fifo_out <= dcfeb_fifo_out(7);

  alct_fifo_dv <= alct_fifo_data_valid;
  otmb_fifo_dv <= otmb_fifo_data_valid;

  dcfeb_dv_out <= dcfeb_data_valid;

  data_fifo_empty <= alct_fifo_empty & otmb_fifo_empty & dcfeb_fifo_empty;
end data_Arch;
