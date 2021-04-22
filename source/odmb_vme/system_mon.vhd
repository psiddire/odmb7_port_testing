library ieee;
use ieee.std_logic_1164.all;
library unisim;
use unisim.vcomponents.all;
library work;
use ieee.numeric_std.all;

entity SYSTEM_MON is
  port (
    OUTDATA : out std_logic_vector(15 downto 0);
    INDATA  : in  std_logic_vector(15 downto 0);
    DTACK   : out std_logic;

    ADC_CS0_18     : out std_logic;
    ADC_CS1_18     : out std_logic;
    ADC_CS2_18     : out std_logic;
    ADC_CS3_18     : out std_logic;
    ADC_CS4_18     : out std_logic;
    ADC_DIN_18     : out std_logic;
    ADC_SCK_18     : out std_logic; 
    ADC_DOUT_18    : in  std_logic;

    SLOWCLK : in std_logic;
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

  component odmb7_voltageMon is
    port (
        CLK    : in  std_logic;
        --CLK_div2    : in  std_logic;
        CS     : out std_logic;
        DIN    : out std_logic;
        SCK    : out std_logic;
        DOUT   : in  std_logic;
        DVOUT    : out std_logic;
        DATADONE    : out std_logic;
        DATA   : out std_logic_vector(11 downto 0);

        startchannelvalid  : in std_logic
   );
  end component;

  signal drdy      : std_logic;
  signal den       : std_logic;
  signal q_strobe  : std_logic;
  signal q2_strobe : std_logic;

  signal which_chip : std_logic_vector(2 downto 0); -- there are 5 MAX1271 chips in total
  signal which_channel : std_logic_vector(3 downto 0); -- there are 8 channels to read per chip 
  -- add these two inner signals due to these two signals are needed for a long time, need to read all 8 channels per chip
  signal which_chip_inner : std_logic_vector(2 downto 0); -- there are 5 MAX1271 chips in total
  signal which_channel_inner : std_logic_vector(3 downto 0); -- there are 8 channels to read per chip 
  signal cs_inner: std_logic;

  signal dout_data : std_logic_vector(11 downto 0) := x"000"; 
  signal dout_data_inner : std_logic_vector(11 downto 0) := x"000"; 
  signal dout_valid: std_logic := '0';
  signal n_valid: integer := 0;
  signal startchannelvalid: std_logic := '0';
  signal startchannelvalid2: std_logic := '0';

  signal data_done: std_logic := '0';

  signal dd_dtack, d_dtack, q_dtack : std_logic;

  signal outdata_inner : std_logic_vector(15 downto 0);
  signal cmddev : std_logic_vector (15 downto 0);
  signal w_vol_mon: std_logic := '0';
  signal r_vol_mon: std_logic := '0';
  signal do_voltage_mon: std_logic := '0';

  type csstates is (S_CS_IDLE, S_CS_SET);
  signal csstate  : csstates := S_CS_IDLE;
  
begin
   
  -- decode command 
  cmddev <= "000" & DEVICE & COMMAND & "00";

  -- command 720X, where X represent nth MAX1271 chip to read
  w_vol_mon <= '1' when (CMDDEV(15 downto 4) = x"120" and WRITER = '0') else '0';
  r_vol_mon <= '1' when (CMDDEV(15 downto 0) = x"1300" and WRITER = '1') else '0';

  do_voltage_mon <= w_vol_mon or r_vol_mon;
  -- this signal is not actually used in reading dout_data_inner
  which_chip <= CMDDEV(2 downto 0) when (w_vol_mon = '1') else "000";
  which_channel <= INDATA when (do_voltage_mon = '1') else x"0";

  -- when w_vol_mon has a rising edge, trigger a sequence sent to MAX1271
  u1_oneshot : oneshot port map (trigger => w_vol_mon, clk => SLOWCLK, pulse => startchannelvalid);
  u2_oneshot : oneshot port map (trigger => startchannelvalid, clk => SLOWCLK, pulse => startchannelvalid2);

  
  processcs : process (SLOWCLK)
  begin
      if rising_edge(SLOWCLK) then
      case csstate is 
          when S_CS_IDLE =>

              ADC_CS0_18 <= '1';
              ADC_CS1_18 <= '1';
              ADC_CS2_18 <= '1';
              ADC_CS3_18 <= '1';
              ADC_CS4_18 <= '1';
              n_valid <= 0;
              which_chip_inner <= which_chip;
              which_channel_inner <= which_channel;

              if rising_edge(w_vol_mon) then
                 csstate <= S_CS_SET;
              end if;

          when S_CS_SET =>

            case which_chip is
              when x"1" => ADC_CS0_18 <= '0'; 
              when x"2" => ADC_CS1_18 <= '0'; 
              when x"3" => ADC_CS2_18 <= '0'; 
              when x"4" => ADC_CS3_18 <= '0'; 
              when x"5" => ADC_CS4_18 <= '0'; 
            end case;

            -- when starting read ADCs from MAX127, 8 readings will be returned consectively
            -- store one reading at a time per VME command...
            if (dout_valid = '1') then
                if (n_valid = (to_integer(signed(which_channel))-1)) then
                    dout_data_inner <= dout_data;
                end if;
                n_valid <= n_valid + 1;
            end if;

            if (data_done = '1') then
                csstate <= S_CS_IDLE;
                which_chip_inner <= "000";
                which_channel_inner <= x"0";
            end if;

      end case;  
     end if;  -- CLK1P25
  end process processcs;
          
  -- when w_vol_mon goes high, make a startchannelvalid pulse as well as associated cs_inner with one of the 5 CS
  -- one of the selected 5 cs will change back to 1 after datadone
  u_voltageMon : odmb7_voltageMon
      port map (
          CLK  => SLOWCLK, -- 1.25 MHz
--            CLK_div2  => CLK_div2,
          CS   => cs_inner,
          DIN  => ADC_DIN_18,
          SCK  => ADC_SCK_18,
          DOUT => ADC_DOUT_18,
          DVOUT => dout_valid,
          DATA => dout_data,
          DATADONE => data_done,
          startchannelvalid => startchannelvalid2 
    );

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

    OUTDATA <= x"0" & outdata_inner(15 downto 4) when ( CMDDEV(11 downto 8) = x"1" ) else -- Discarding the 4 LSB
               x"0" & dout_data_inner(11 downto 0) when (r_vol_mon = '1') else 
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
  
end SYSTEM_MON_ARCH;
