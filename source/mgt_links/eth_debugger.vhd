--temporary debugging module for ethernet

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;

use ieee.std_logic_misc.all;

entity eth_debugger is
  port (
      RST : in std_logic; --rst
      CLK : in std_logic; --tx usrclk
      SPY_TXDATA : out std_logic_vector(15 downto 0); --data to transmit
      SPY_TXD_VALID : out std_logic_vector(1 downto 0);  --bottom two bits of tx_ctrl (indicate k-character)
      SPY_RXDATA : in std_logic_vector(15 downto 0); --data received (for loopback test)
      SPY_RXD_VALID : in std_logic
    );
end eth_debugger;

architecture Behavioral of eth_debugger is

  component ETHERNET_FRAME is
  port (
    CLK : in std_logic;                 -- User clock
    RST : in std_logic;                 -- Reset

    TXD_VLD : in std_logic;                      -- Flag for valid data
    TXD     : in std_logic_vector(15 downto 0);  -- Data with no frame

    ROM_CNT_OUT : out std_logic_vector(2 downto 0);

    TXD_ACK   : out std_logic;                     -- TX acknowledgement
    TXD_ISK   : out std_logic_vector(1 downto 0);  -- Data is K character
    TXD_FRAME : out std_logic_vector(15 downto 0)  -- Data to be transmitted
    );
  end component;
  
  component vio_ethdebug is
  port (
    CLK : in std_logic;
    PROBE_OUT0 : out std_logic_vector(0 downto 0);
    PROBE_OUT1 : out std_logic_vector(15 downto 0)
    );
  end component;
  
  component ila_ethdebug is
  port (
      CLK : in std_logic;
      PROBE0 : in std_logic_vector(127 downto 0)
    );
  end component;

  --between FSM and ETHERNET_FRAME
  signal tx_ack : std_logic := '0';
  signal txd : std_logic_vector(15 downto 0) := (others => '0');
  signal txd_vld : std_logic := '0';

  --between VIO and FSM
  signal vio_start_packet : std_logic;
  signal vio_start_packet_q : std_logic;
  signal vio_start_packet_pulse : std_logic := '0';
  signal vio_data : std_logic_vector(15 downto 0);

  --fsm
  signal word_cnt : integer range 0 to 65535;
  signal packet_cnt : unsigned(15 downto 0) := (others => '0'); --needed for our eth card?

  --fsm state
  type fsm_state_type is (S_IDLE, S_HEADER, S_TX, S_PACKET_COUNT);
  signal pc_fsm_state : fsm_state_type := S_IDLE;
  
  --debug
  signal spy_txdata_int : std_logic_vector(15 downto 0);
  signal spy_txd_valid_int : std_logic_vector(1 downto 0);
  signal ila_probe : std_logic_vector(127 downto 0);

begin

  ETHERNET_FRAME_PM : ETHERNET_FRAME
    port map (
      CLK => CLK,
      RST => RST,

      TXD_VLD => txd_vld,
      TXD     => txd,

      ROM_CNT_OUT => open,

      TXD_ACK   => tx_ack,
      TXD_ISK   => SPY_TXD_VALID_INT,
      TXD_FRAME => SPY_TXDATA_INT
      );
      
  SPY_TXD_VALID <= SPY_TXD_VALID_INT;
  SPY_TXDATA <= SPY_TXDATA_INT;

  vio_start_packet_q <= vio_start_packet when rising_edge(CLK);
  vio_start_packet_pulse <= vio_start_packet and not vio_start_packet_q;

  pc_fsm_logic : process(RST, CLK)
  begin
    if (RST='1') then
      pc_fsm_state <= S_IDLE;
    elsif rising_edge(CLK) then
      case pc_fsm_state is

        when S_IDLE =>
          txd_vld <= '0';
          txd <= vio_data;
          word_cnt <= 0;
          packet_cnt <= packet_cnt;
          if (vio_start_packet_pulse = '1') then
            pc_fsm_state <= S_HEADER;
          else
            pc_fsm_state <= S_IDLE;
          end if;

        when S_HEADER =>
          txd_vld <= '1';
          txd <= vio_data;
          word_cnt <= 0;
          packet_cnt <= packet_cnt;
          if (tx_ack = '1') then
            pc_fsm_state <= S_TX;
          else
            pc_fsm_state <= S_HEADER;
          end if;

        when S_TX =>
          txd_vld <= '1';
          txd <= vio_data;
          word_cnt <= word_cnt + 1;
          packet_cnt <= packet_cnt;
          if (word_cnt = 30) then
            pc_fsm_state <= S_PACKET_COUNT;
          else
            pc_fsm_state <= S_TX;
          end if;

        when S_PACKET_COUNT =>
          txd_vld <= '1';
          txd <= std_logic_vector(packet_cnt);
          packet_cnt <= packet_cnt + 1;
          word_cnt <= 0;
          pc_fsm_state <= S_IDLE; --rely on human reaction speed to be much slower than inter packet time

        when others =>
          pc_fsm_state <= S_IDLE;

      end case;
    end if;
  end process;
  
  vio_ethdebug_i : vio_ethdebug
    port map (
      CLK => CLK,
      PROBE_OUT0(0) => vio_start_packet,
      PROBE_OUT1 => vio_data
      );
      
  ila_ethdebug_i : ila_ethdebug
    port map (
      CLK => CLK,
      PROBE0 => ila_probe
    );

  ila_probe(0) <= RST;
  ila_probe(16 downto 1) <= vio_data;
  ila_probe(17) <= vio_start_packet;
  ila_probe(18) <= vio_start_packet_q;
  ila_probe(19) <= vio_start_packet_pulse;
  ila_probe(20) <= txd_vld;
  ila_probe(36 downto 21) <= txd;
  ila_probe(52 downto 37) <= std_logic_vector(packet_cnt);
  ila_probe(68 downto 53) <= spy_txdata_int;
  ila_probe(70 downto 69) <= spy_txd_valid_int;
  ila_probe(86 downto 71) <= SPY_RXDATA;
  ila_probe(87) <= SPY_RXD_VALID;

end Behavioral;
