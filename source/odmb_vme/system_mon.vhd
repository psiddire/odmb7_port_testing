library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;
library work;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity SYSTEM_MON is
  port (
    OUTDATA : out std_logic_vector(15 downto 0);
    INDATA  : in  std_logic_vector(15 downto 0);
    DTACK   : out std_logic;

    ADC_CS_B    : out std_logic_vector(4 downto 0);
    ADC_DIN     : out std_logic;
    ADC_SCK     : out std_logic; 
    ADC_DOUT    : in  std_logic;

    SLOWCLK : in std_logic;
    SLOWCLKX2 : in std_logic;
    FASTCLK : in std_logic;
    RST     : in std_logic;
    DEVICE  : in std_logic;
    STROBE  : in std_logic;
    COMMAND : in std_logic_vector(9 downto 0);
    WRITER  : in std_logic
    --VP      : in std_logic;
    --VN      : in std_logic;
    --VAUXP   : in std_logic_vector(15 downto 0);
    --VAUXN   : in std_logic_vector(15 downto 0)
    );
end SYSTEM_MON;

architecture SYSTEM_MON_ARCH of SYSTEM_MON is
  --component PULSE_EDGE is
  --  port (
  --    DOUT   : out std_logic;
  --    PULSE1 : out std_logic;
  --    CLK    : in  std_logic;
  --    RST    : in  std_logic;
  --    NPULSE : in  integer;
  --    DIN    : in  std_logic
  --    );
  --end component;
  component oneshot is
    port (
      trigger: in  std_logic;
      clk : in std_logic;
      pulse: out std_logic
    );
  end component;

  component ila_volMon is
      port (
          clk : in std_logic := '0';
          probe0 : in std_logic_vector(7 downto 0) := (others=> '0');
          probe1 : in std_logic_vector(15 downto 0) := (others=> '0');
          probe2 : in std_logic_vector(11 downto 0) := (others=> '0');
          probe3 : in std_logic_vector(11 downto 0) := (others=> '0');
          probe4 : in std_logic_vector(7 downto 0) := (others=> '0');
          probe5 : in std_logic_vector(11 downto 0) := (others=> '0');
          probe6 : in std_logic_vector(11 downto 0) := (others=> '0');
          probe7 : in std_logic_vector(11 downto 0) := (others=> '0');
          probe8 : in std_logic_vector(11 downto 0) := (others=> '0');
          probe9 : in std_logic_vector(11 downto 0) := (others=> '0');
          probe10 : in std_logic_vector(11 downto 0) := (others=> '0');
          probe11 : in std_logic_vector(11 downto 0) := (others=> '0');
          probe12 : in std_logic_vector(11 downto 0) := (others=> '0');
          probe13 : in std_logic_vector(7 downto 0) := (others=> '0');
          probe14 : in std_logic_vector(2 downto 0) := (others=> '0')

      );
  end component;

  component voltage_mon is
    port (
        CLK    : in  std_logic;
        CS     : out std_logic;
        DIN    : out std_logic;
        SCK    : out std_logic;
        DOUT   : in  std_logic;
        DVOUT    : out std_logic;
        DATADONE    : out std_logic;
        DATA   : out std_logic_vector(11 downto 0);
        DATAVALIDCNTR     : out std_logic_vector(7 downto 0);
        CURRENTCHANNELOUT   : out std_logic_vector(2 downto 0);
        CTRLSEQDONE    : out std_logic;

        startchannelvalid  : in std_logic
   );
  end component;

  signal drdy      : std_logic;
  signal den       : std_logic;
  signal q_strobe  : std_logic;
  signal q2_strobe : std_logic;

  -- for voltage monitoring (CS, DIN, CLK)
  signal adc_cs_inner : std_logic_vector(4 downto 0);
  signal adc_din_inner : std_logic;
  signal cs_inner: std_logic;
  signal din_inner : std_logic;
  signal clk_inner : std_logic;
  signal chip_selected : std_logic_vector(4 downto 0);
  
  -- vme command decoding
  signal cmddev : std_logic_vector (15 downto 0);
  signal w_vol_mon: std_logic := '0';
  signal r_vol_mon: std_logic := '0';
  signal which_chip : std_logic_vector(3 downto 0); -- there are 5 MAX1271 chips in total
  signal which_channel : std_logic_vector(3 downto 0); -- there are 8 channels to read per chip 
  signal which_chip_inner : std_logic_vector(3 downto 0); -- there are 5 MAX1271 chips in total
  signal which_channel_inner : std_logic_vector(3 downto 0); -- there are 8 channels to read per chip 

  -- internal buses to save voltage readings 
  type DOUTDATA is array (0 to 7) of std_logic_vector(11 downto 0);
  signal dout_data_inner_a : DOUTDATA;
  
  -- signals in/out odmb7_voltageMon
  signal dout_data : std_logic_vector(11 downto 0) := x"000"; 
  signal dout_valid: std_logic := '0';
  signal n_valid: integer := 0;
  signal startchannelvalid: std_logic := '0';
  signal startchannelvalid2: std_logic := '0';
  signal data_done: std_logic := '0';
  signal ctrlseqdone: std_logic := '0';
  signal data_valid_cntr : std_logic_vector(7 downto 0) := x"00"; 
  signal current_channel : std_logic_vector(2 downto 0) := "000"; 

  signal dd_dtack, d_dtack, q_dtack : std_logic;
  signal outdata_inner : std_logic_vector(15 downto 0);

  -- for ila
  signal variousflags: std_logic_vector(15 downto 0) := x"0000";
  signal ila_trigger: std_logic_vector(7 downto 0) := x"00";
  signal ila_adc : std_logic_vector(7 downto 0);
  
begin
   
  -- decode command 
  cmddev <= "000" & DEVICE & COMMAND & "00";

  -- command 720X, where X represent nth MAX1271 chip to read
  w_vol_mon <= '1' when (cmddev(15 downto 8) = x"12" and WRITER = '0') else '0';
  r_vol_mon <= '1' when (cmddev(15 downto 8) = x"13" and WRITER = '1') else '0';

  -- this signal is not actually used in reading dout_data_inner
  which_chip <= cmddev(7 downto 4) when (w_vol_mon = '1') else x"0";
  which_channel <= cmddev(7 downto 4) when (r_vol_mon = '1') else x"0";

  -- when w_vol_mon has a rising edge, trigger a sequence sent to MAX1271
  u1_oneshot : oneshot port map (trigger => w_vol_mon, clk => SLOWCLK, pulse => startchannelvalid);
  u2_oneshot : oneshot port map (trigger => startchannelvalid, clk => SLOWCLK, pulse => startchannelvalid2);

  -- need to keep which_chip persistent as we are reading 8 channels from 1 chip in one go
  -- which_channel_inner is probably not neccessary in the end
  which_inner_gen : for I in 3 downto 0 generate
  begin
      which_chip_inner_gen_i: FDCE port map(Q=>which_chip_inner(I), C=>SLOWCLK, CLR=>data_done, CE=>DEVICE, D=>which_chip(I));
      which_channel_inner_gen_i: FDCE port map(Q=>which_channel_inner(I), C=>SLOWCLK, CLR=>data_done, CE=>DEVICE, D=>which_channel(I));
  end generate which_inner_gen;
  
  -- sync DIN and CS using same clk
  cs_gen : for I in 4 downto 0 generate
  begin
      chip_selected(I) <= '1' when (to_integer(unsigned(which_chip_inner)) = I+1) else '0';
      -- need FDPE_1 for falling edge
      cs_gen_i: FDPE_1 port map(Q=>adc_cs_inner(I), C=>SLOWCLK, PRE=>data_done, CE=>chip_selected(I), D=>cs_inner);
  end generate cs_gen;
  din_gen_i: FDCE port map(Q=>adc_din_inner, C=>SLOWCLK, CLR=>data_done, CE=>or_reduce(which_chip_inner), D=>din_inner);

  process (SLOWCLK)
  begin
    if rising_edge(SLOWCLK) then
	  if (DEVICE = '1' or data_done = '1') then
	     n_valid <= 0;
	  else
	     if (dout_valid = '1') then
		     dout_data_inner_a(n_valid) <= dout_data;
		     n_valid <= n_valid + 1;
	     end if;
      end if; 
     end if; -- CLK1P25
  end process;

  u_voltageMon : voltage_mon
      port map (
          CLK  => SLOWCLK, -- 1.25 MHz
          CS   => cs_inner,
          DIN  => din_inner,
          SCK  => clk_inner,
          DOUT => ADC_DOUT,
          DVOUT => dout_valid,
          DATA => dout_data,
          DATADONE => data_done,
          DATAVALIDCNTR => data_valid_cntr,
          CURRENTCHANNELOUT => current_channel,
          CTRLSEQDONE => ctrlseqdone,
          startchannelvalid => startchannelvalid2 
    );
    
    ADC_SCK  <= clk_inner;
    ADC_DIN  <= adc_din_inner;
    ADC_CS_B <= adc_cs_inner;

  -- SYSMON part still need to be ported to work with KU
  --SYSMON_PM : SYSMON
  --  generic map(
  --    INIT_40          => X"3000",      -- config reg 0
  --    INIT_41          => X"20f0",      -- config reg 1
  --    INIT_42          => X"0a00",      -- config reg 2
  --    INIT_48          => X"3f01",      -- Sequencer channel selection
  --    INIT_49          => X"ffff",      -- Sequencer channel selection
  --    INIT_4A          => X"0f00",      -- Sequencer Average selection
  --    INIT_4B          => X"ffff",      -- Sequencer Average selection
  --    INIT_4C          => X"0000",      -- Sequencer Bipolar selection
  --    INIT_4D          => X"0000",      -- Sequencer Bipolar selection
  --    INIT_4E          => X"0800",      -- Sequencer Acq time selection
  --    INIT_4F          => X"ffff",      -- Sequencer Acq time selection
  --    INIT_50          => X"b5ed",      -- Temp alarm trigger
  --    INIT_51          => X"5999",      -- Vccint upper alarm limit
  --    INIT_52          => X"e000",      -- Vccaux upper alarm limit
  --    INIT_53          => X"b5c3",      -- Temp alarm OT upper (Default 125C -> ca33, 85C -> b5c3)
  --    INIT_54          => X"a93a",      -- Temp alarm reset
  --    INIT_55          => X"5111",      -- Vccint lower alarm limit
  --    INIT_56          => X"caaa",      -- Vccaux lower alarm limit
  --    INIT_57          => X"b0ce",      -- Temp alarm OT reset (Default 70C -> ae4e, 75C -> b0ce)
  --    SIM_DEVICE       => "VIRTEX6",
  --    SIM_MONITOR_FILE => "/home/adam/odmb_ucsb_v2_testing/source/odmb_vme/auxfile.txt"
  --    )
  --  port map(
  --    ALM          => open,
  --    BUSY         => open,
  --    CHANNEL      => open,
  --    DO           => outdata_inner,
  --    DRDY         => drdy,
  --    EOC          => open,
  --    EOS          => open,
  --    JTAGBUSY     => open,
  --    JTAGLOCKED   => open,
  --    JTAGMODIFIED => open,
  --    OT           => open,

  --    CONVST    => '0',
  --    CONVSTCLK => '0',
  --    DADDR     => command(8 downto 2),
  --    DCLK      => FASTCLK,
  --    DEN       => den,
  --    DI        => x"0000",
  --    DWE       => '0',
  --    RESET     => RST,
  --    VAUXN     => VAUXN,
  --    VAUXP     => VAUXP,
  --    VN        => VN,
  --    VP        => VP
  --    );

    --OUTDATA <= x"0" & outdata_inner(15 downto 4) when ( CMDDEV(11 downto 8) = x"1" ) else -- Discarding the 4 LSB
    OUTDATA <= x"0" & dout_data_inner_a(to_integer(signed(which_channel_inner))-1)(11 downto 0) when (r_vol_mon = '1') else 
               (others => 'L');

  --Enable sysmon output in first full clock cycle after strobe goes high
  FD_STROBE  : FD port map (Q=>q_strobe, C=>FASTCLK, D=>STROBE);
  FD_STROBE2 : FD port map (Q=>q2_strobe, C=>FASTCLK, D=>q_strobe);
  den <= '1' when (device = '1' and WRITER = '1' and q2_strobe = '0' and q_strobe = '1')
         else '0';

  --DTACK when OUTDATA contains valid data
  dd_dtack <= device and strobe; -- and drdy;
  FD_D_DTACK : FDC port map(Q=>d_dtack, C=>dd_dtack, CLR=>q_dtack, D=>'1');
  FD_Q_DTACK : FD port map(Q=>q_dtack, C=>SLOWCLK, D=>d_dtack);
  DTACK    <= q_dtack;
  
  ila_trigger <= "000" & data_done & DEVICE & STROBE & dout_valid & startchannelvalid;
  variousflags <= "00" & ctrlseqdone & which_channel & which_channel_inner & STROBE & DEVICE & dout_valid & data_done & cs_inner;
  ila_adc <= clk_inner & "0" & adc_cs_inner & adc_din_inner;

i_ila : ila_volMon
    port map(
        clk => SLOWCLKX2,
        probe0 => ila_trigger,
        probe1 => variousflags, 
        probe2 => dout_data,  
        probe3 => x"000", 
        probe4 => ila_adc,
        probe5 => dout_data_inner_a(0),
        probe6 => dout_data_inner_a(1),
        probe7 => dout_data_inner_a(2),
        probe8 => dout_data_inner_a(3),
        probe9 => dout_data_inner_a(4),
        probe10 => dout_data_inner_a(5),
        probe11 => dout_data_inner_a(6),
        probe12 => dout_data_inner_a(7),
        probe13 => data_valid_cntr,
        probe14 => current_channel 
        );

end SYSTEM_MON_ARCH;
