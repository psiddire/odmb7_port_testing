library ieee;
library work;
library UNISIM;
use UNISIM.vcomponents.all;
use work.Latches_Flipflops.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;

--! @brief module SPI communication to clock synthesizer chip
--! @details Supported VME commands:
--! W   X000 reset where INDATA(5:0) controls TEST & IF(1:0) & AC(2:0)
--! W   X004 set address to INDATA(15:0)
--! W   X008 set command to INDATA(7:0)
--! W/R X00C send command with address. Read back a byte if R
--! W/R X010 send command with no address. Read back a byte if R
--! W   X014 send command with address followed by INDATA(7:0)
--! 
--! Reset convetion: TEST control manufacturing test mode 
--! IF(1:0)= "00": I2C w/ address 1110100, "01": I2C w/address 1110101,
--!          "10": I2C w/ address 1110110, "11": SPI-secondary
--! AC(2:0) selects config slot
entity CLOCK_MON is
  port (
    --VME/Control signals
    RST               : in std_logic;                      --! Soft reset
    CLK2P5            : in std_logic;                      --! 2.5MHz clock (4MHz max for SCLK)
    DEVICE            : in std_logic;                      --! 1 if selected VME device
    STROBE            : in std_logic;                      --! Indicates VME command ready
    WRITER            : in std_logic;                      --! Indicates VME write/read (1=read)
    COMMAND           : in std_logic_vector(9 downto 0);   --! VME command signal.
    INDATA            : in std_logic_vector(15 downto 0);  --! VME input data
    OUTDATA           : out std_logic_vector(15 downto 0); --! VME output data
    DTACK             : out std_logic;                     --! VME data acknowledge (output ready)
    --output to FPGA pins
    RST_CLKS_B        : out std_logic;                     --! Reset bar signal to clock synthesizer
    FPGA_SEL          : out std_logic;                     --! Clock synth. input select (0=USB, 1=FPGA)
    FPGA_AC0          : out std_logic;                     --! Auto-Config(0) or general IO(0)
    FPGA_AC1          : out std_logic;                     --! Auto-Config(1) or general IO(1)
    FPGA_AC2          : out std_logic;                     --! Auto-Config(2) or general IO(2)
    FPGA_TEST         : out std_logic;                     --! Test mode or general IO(3)
    FPGA_IF0_CSN_B    : out std_logic;                     --! Interface Mode(0) or SPI chip select
    FPGA_IF1_MISO_IN  : in std_logic;                      --! Interface mode(1) or SPI secondary-out
    FPGA_IF1_MISO_OUT : out std_logic;                     --! Interface mode(1) or SPI secondary-out
    FPGA_MOSI         : out std_logic;                     --! SPI main-out-secondary-in
    FPGA_SCLK         : out std_logic;                     --! SPI clock
    --control output to FPGA pins
    FPGA_MISO_DIR     : out std_logic                      --! FPGA_MISO tri-state select (0=FPGA out)
    );
end CLOCK_MON;

architecture CLOCK_MON_Arch of CLOCK_MON is

  --strobe signals
  signal strobe_meta  : std_logic := '0';
  signal strobe_sync  : std_logic := '0';
  signal strobe_q     : std_logic;
  signal strobe_qq    : std_logic;
  signal strobe_pulse : std_logic;
  signal strobe_b     : std_logic;

  --human readable VME command
  signal cmddev : std_logic_vector(15 downto 0) := x"0000";

  --VME command signals
  signal vme_cmd_reset         : std_logic;
  signal vme_cmd_loadaddr      : std_logic;
  signal vme_cmd_loadcmd       : std_logic;
  signal vme_cmd_sendcmd       : std_logic;
  signal vme_cmd_sendcmdnoaddr : std_logic;
  signal vme_cmd_sendcmdwrite  : std_logic;
  signal vme_cmd_sendgeneral   : std_logic;

  --vme_cmd_reset
  signal rst_ac       : std_logic_vector(2 downto 0);
  signal rst_if       : std_logic_vector(1 downto 0);
  signal rst_test     : std_logic;
  signal rst_rst      : std_logic;
  signal rst_rst_q    : std_logic;
  signal rst_dtack_en : std_logic;
  signal rst_dtack    : std_logic;

  --load commands
  signal spi_addr      : std_logic_vector(15 downto 0);
  signal spi_cmd       : std_logic_vector(7 downto 0);
  signal load_dtack_en : std_logic;
  signal load_dtack    : std_logic;

  --shift commands
  signal mosi              : std_logic;
  signal cs_b              : std_logic;
  signal cmd_enable_shift  : std_logic;
  signal addr_enable_shift : std_logic;
  signal spi_counter       : unsigned(4 downto 0);
  signal read_byte         : std_logic_vector(7 downto 0) := x"00";
  signal shift_dtack_en    : std_logic;
  signal shift_dtack       : std_logic;
  signal mosi_sync         : std_logic;
  signal cs_b_sync         : std_logic;
  signal write_data        : std_logic_vector(7 downto 0);
                             
  type spi_states is (S_IDLE, S_SHIFT_CMD, S_SHIFT_ADDR, S_READ, S_WRITE, S_SET_DTACK);
  signal spi_state : spi_states := S_IDLE;

begin

  --strobe and VME commands
  strobe_CDC0 : FD port map(D => STROBE, C => CLK2P5, Q => strobe_meta);
  strobe_CDC1 : FD port map(D => strobe_meta, C => CLK2P5, Q => strobe_sync);
  strobe_q <= strobe_sync when rising_edge(CLK2P5);
  strobe_qq <= strobe_q when rising_edge(CLK2P5);
  strobe_pulse <= strobe_q and not strobe_qq;
  strobe_b <= not strobe_sync;

  cmddev <= "000" & device & command & "00";
  vme_cmd_reset         <= '1' when (cmddev=x"1000" and strobe_sync='1') else '0';
  vme_cmd_loadaddr      <= '1' when (cmddev=x"1004" and strobe_sync='1') else '0';
  vme_cmd_loadcmd       <= '1' when (cmddev=x"1008" and strobe_sync='1') else '0';
  vme_cmd_sendcmd       <= '1' when (cmddev=x"100C" and strobe_sync='1') else '0';
  vme_cmd_sendcmdnoaddr <= '1' when (cmddev=x"1010" and strobe_sync='1') else '0';
  vme_cmd_sendcmdwrite  <= '1' when (cmddev=x"1014" and strobe_sync='1') else '0';
  vme_cmd_sendgeneral   <= vme_cmd_sendcmd or vme_cmd_sendcmdnoaddr or vme_cmd_sendcmdwrite;

  --handle reset command
  rst_ac   <= INDATA(2 downto 0);
  rst_if   <= INDATA(4 downto 3);
  rst_test <= INDATA(5);
  --from data sheet: for clock chip, reset should be asserted for at least 1us, but MAX118 requires at least 10 us
  rst_puslse : NPULSE2SAME port map(DOUT => rst_rst, CLK_DOUT => CLK2P5, 
                                    RST => '0', NPULSE => 30, DIN => vme_cmd_reset);
  rst_rst_q <= rst_rst when rising_edge(CLK2P5);
  rst_dtack_en <= rst_rst_q and not rst_rst;
  FDC_rst_dtack : FDCE port map(D => '1', C => CLK2P5, CE => rst_dtack_en, 
                                CLR => strobe_b, Q => rst_dtack);

  --handle address and command with shift register
  process_cmd_addr : process (RST, CLK2P5)
  begin
  if (RST='1') then
    spi_addr <= x"0000";
    spi_cmd  <= x"00";
  elsif falling_edge(CLK2P5) then
    --handle addr
    if (vme_cmd_loadaddr='1') then
      spi_addr <= INDATA;
    elsif (addr_enable_shift='1') then
      spi_addr <= spi_addr(14 downto 0) & spi_addr(15);
    else
      spi_addr <= spi_addr;
    end if;
    --handle cmd
    if (vme_cmd_loadcmd='1') then
      spi_cmd <= INDATA(7 downto 0);
    elsif (cmd_enable_shift='1') then
      spi_cmd <= spi_cmd(6 downto 0) & spi_cmd(7);
    else
      spi_cmd <= spi_cmd;
    end if;
  end if; --CLK2P5 edge
  end process process_cmd_addr;
  load_dtack_en <= strobe_pulse and (vme_cmd_loadcmd or vme_cmd_loadaddr);
  FDC_load_dtack : FDCE port map(D => '1', C => CLK2P5, CE => load_dtack_en, 
                                 CLR => strobe_b, Q => load_dtack);

  --handle read/write commands
  process_clock_spi : process (CLK2P5)
  begin
  if rising_edge(CLK2P5) then
    case spi_state is
    when S_IDLE =>
      cs_b <= '1';
      mosi <= '1';
      cmd_enable_shift <= '0';
      addr_enable_shift <= '0';
      read_byte <= read_byte;
      shift_dtack_en <= '0';
      spi_counter <= "00000";
      if (vme_cmd_sendgeneral='1' and shift_dtack='0') then
        spi_state <= S_SHIFT_CMD;
        write_data <= INDATA(7 downto 0);
      else
        spi_state <= S_IDLE;
        write_data <= write_data;
      end if;

    when S_SHIFT_CMD =>
      cs_b <= '0';
      mosi <= spi_cmd(7);
      cmd_enable_shift <= '1';
      addr_enable_shift <= '0';
      read_byte <= read_byte;
      shift_dtack_en <= '0';
      write_data <= write_data;
      if (spi_counter = 7) then
        spi_counter <= "00000";
        if (vme_cmd_sendcmdnoaddr='0') then
          spi_state <= S_SHIFT_ADDR;
        elsif (WRITER='1') then
          spi_state <= S_READ;
        else
          spi_state <= S_SET_DTACK;
        end if;
      else
        spi_counter <= spi_counter + 1;
        spi_state <= S_SHIFT_CMD;
      end if;

    when S_SHIFT_ADDR =>
      cs_b <= '0';
      mosi <= spi_addr(15);
      cmd_enable_shift <= '0';
      addr_enable_shift <= '1';
      read_byte <= read_byte;
      shift_dtack_en <= '0';
      write_data <= write_data;
      if (spi_counter = 15) then
        spi_counter <= "00000";
        if (vme_cmd_sendcmdwrite='1') then
          spi_state <= S_WRITE;
        elsif (WRITER='1') then
          spi_state <= S_READ;
        else
          spi_state <= S_SET_DTACK;
        end if;
      else
        spi_counter <= spi_counter + 1;
        spi_state <= S_SHIFT_ADDR;
      end if;

    when S_READ => 
      mosi <= '0';
      cmd_enable_shift <= '0';
      addr_enable_shift <= '0';
      read_byte <= read_byte(6 downto 0) & FPGA_IF1_MISO_IN;
      shift_dtack_en <= '0';
      write_data <= write_data;
      if (spi_counter = 8) then
        cs_b <= '1';
        spi_counter <= "00000";
        spi_state <= S_SET_DTACK;
      else
        cs_b <= '0';
        spi_counter <= spi_counter + 1;
        spi_state <= S_READ;
      end if;

    when S_WRITE => 
      mosi <= write_data(7);
      cmd_enable_shift <= '0';
      addr_enable_shift <= '0';
      read_byte <= read_byte;
      shift_dtack_en <= '0';
      write_data <= write_data(6 downto 0) & write_data(7);
      if (spi_counter = 8) then
        cs_b <= '0';
        spi_counter <= "00000";
        spi_state <= S_SET_DTACK;
      else
        cs_b <= '0';
        spi_counter <= spi_counter + 1;
        spi_state <= S_WRITE;
      end if;

    when S_SET_DTACK => 
      cs_b <= '1';
      mosi <= '0';
      cmd_enable_shift <= '0';
      addr_enable_shift <= '0';
      read_byte <= read_byte;
      write_data <= write_data;
      if (spi_counter = 1) then
        shift_dtack_en <= '0';
        spi_counter <= "00000";
        spi_state <= S_IDLE;
      else
        shift_dtack_en <= '1';
        spi_counter <= spi_counter + 1;
        spi_state <= S_SET_DTACK;
      end if;

    end case;
  end if; --CLK2P5 edge
  end process process_clock_spi;
  FDCE_shift_dtack : FDCE port map(D => '1', C => CLK2P5, CE => shift_dtack_en, 
                                   CLR => strobe_b, Q => shift_dtack);

  cs_b_sync <= cs_b when falling_edge(CLK2P5);
  mosi_sync <= mosi when falling_edge(CLK2P5);

  --assign output to clock chip
  RST_CLKS_B        <= (not rst_rst) when (vme_cmd_reset='1') else '1';
  FPGA_SEL          <= '1' when ((vme_cmd_reset or vme_cmd_sendgeneral)='1') else 
                       '0';
  FPGA_AC0          <= rst_ac(0) when (vme_cmd_reset='1') else 'Z';
  FPGA_AC1          <= rst_ac(1) when (vme_cmd_reset='1') else 'Z';
  FPGA_AC2          <= rst_ac(2) when (vme_cmd_reset='1') else 'Z';
  FPGA_TEST         <= rst_test  when (vme_cmd_reset='1') else 'Z';
  FPGA_IF0_CSN_B    <= rst_if(0) when (vme_cmd_reset='1') else cs_b_sync;
  FPGA_IF1_MISO_OUT <= rst_if(1) when (vme_cmd_reset='1') else '1';
  FPGA_MOSI         <= mosi_sync;
  FPGA_SCLK         <= CLK2P5;
  FPGA_MISO_DIR     <= '0' when (vme_cmd_reset='1') else '1';

  --VME output
  OUTDATA <= x"00" & read_byte when 
             ((WRITER and (vme_cmd_sendcmd or vme_cmd_sendcmdnoaddr))='1') else 
             (others => 'Z');
  DTACK <= rst_dtack or load_dtack or shift_dtack;

end CLOCK_MON_Arch;
