library ieee;
library work;
library UNISIM;
use UNISIM.vcomponents.all;
use work.Latches_Flipflops.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;

entity SPI_PORT is
  generic (
    NREGS  : integer := 16
    );
  port (
    SLOWCLK              : in std_logic;
    CLK                  : in std_logic;
    RST                  : in std_logic;
    --VME signals
    DEVICE               : in  std_logic;
    STROBE               : in  std_logic;
    COMMAND              : in  std_logic_vector(9 downto 0);
    WRITER               : in  std_logic;
    DTACK                : out std_logic;
    INDATA               : in  std_logic_vector(15 downto 0);
    OUTDATA              : out std_logic_vector(15 downto 0);
    --CONFREGS signals
    SPI_CFG_UL_PULSE     : out std_logic;
    SPI_CONST_UL_PULSE   : out std_logic;
    SPI_UL_REG           : out std_logic_vector(15 downto 0);
    SPI_CFG_BUSY         : out std_logic;
    SPI_CONST_BUSY       : out std_logic;
    SPI_CFG_REG_WE       : out integer range 0 to NREGS;
    SPI_CONST_REG_WE     : out integer range 0 to NREGS;
    SPI_CFG_REGS         : in cfg_regs_array;
    SPI_CONST_REGS       : in cfg_regs_array;
    --signals to/from QSPI_CTRL
    SPI_CMD_FIFO_WRITE_EN     : out std_logic;
    SPI_CMD_FIFO_IN           : out std_logic_vector(15 downto 0);
    SPI_READBACK_FIFO_OUT     : in std_logic_vector(15 downto 0);
    SPI_READBACK_FIFO_READ_EN : out std_logic;
    SPI_READ_BUSY             : in std_logic
    );
end SPI_PORT;

architecture SPI_PORT_Arch of SPI_PORT is

  --signal cfg_reg_hardcode : cfg_regs_array := (x"0019", x"FFF1", x"0001", x"FFF3",
  --                                               x"0008", x"0008", x"0004", x"0000",
  --                                               x"D3B7", x"D3B7", x"00FF", x"0100",
  --                                               x"FFFC", x"FFFD", x"FFFE", x"FFFF");
  
  --CFG register download signals
  type cfg_download_states is (S_IDLE, S_SET_ADDR_LOWER, S_ERASE, S_BUFFER_PROGRAM, S_WRITE);
  signal cfg_download_state  : cfg_download_states := S_IDLE;
  signal spi_cmd_fifo_write_en_cfg_dl : std_logic := '0';
  signal spi_cmd_fifo_in_cfg_dl : std_logic_vector(15 downto 0) := x"0000";
  signal download_cfg_reg_index : integer := 0;
  
  --CFG register upload signals
  type cfg_upload_states is (S_IDLE, S_SET_ADDR_LOWER, S_READN, S_WAIT_READ_BUSY, S_WAIT_READ_DONE, S_WAIT_READ_STALL, S_READBACK);
  signal cfg_upload_state  : cfg_upload_states := S_IDLE;
  signal spi_cmd_fifo_write_en_cfg_ul : std_logic := '0';
  signal spi_cmd_fifo_in_cfg_ul : std_logic_vector(15 downto 0) := x"0000";
  signal upload_cfg_reg_index : integer := 0;  
  signal spi_readback_fifo_read_en_cfg_ul : std_logic := '0';
  signal spi_cfg_ul_pulse_inner : std_logic := '0';
  signal spi_cfg_reg_we_inner : integer := NREGS;
  signal spi_ul_reg_inner : std_logic_vector(15 downto 0) := x"0000";
  signal readback_fifo_stall_counter : unsigned(3 downto 0) := x"0";
  
  --SPI command command signals
  signal strobe_q, strobe_pulse : std_logic := '0';
  signal spi_cmd_fifo_write_en_cmd : std_logic := '0';
  signal spi_cmd_fifo_in_cmd : std_logic_vector(15 downto 0) := x"0000";
  
  --SPI read signals
  signal spi_read_data : std_logic_vector(15 downto 0) := x"0000";
  signal spi_readback_fifo_read_en_cmd : std_logic := '0';
  
  --command parsing signals
  signal cmddev : std_logic_vector(15 downto 0) := x"0000";
  signal do_cfg_upload, do_cfg_download, do_cfg_erase, do_spi_cmd, do_spi_read : std_logic := '0';
  
  --dtack signals
  signal ce_d_dtack, d_dtack, q_dtack : std_logic := '0';

begin

  --Decode command
  cmddev    <= "000" & DEVICE & COMMAND & "00";

  do_cfg_download <= '1' when (cmddev=x"1000" and STROBE='1') else '0'; --0x6000
  do_cfg_upload <= '1' when (cmddev=x"1004" and STROBE='1') else '0'; --0x6004
  --temp command for debugging
  do_cfg_erase <= '1' when (cmddev=x"1008" and STROBE='1') else '0';
  do_spi_cmd <= '1' when (cmddev=x"102C") else '0';
  do_spi_read <= '1' when (cmddev=x"1030") else '0';


  --generate strobe_pulse
  strobe_q <= STROBE when rising_edge(SLOWCLK);
  strobe_pulse <= strobe and not strobe_q;
  
  
  --handle SPI command command
  spi_cmd_fifo_write_en_cmd <= do_spi_cmd and strobe_pulse;
  spi_cmd_fifo_in_cmd <= INDATA;
  
  
  --handle SPI read command
  OUTDATA <= spi_read_data; --currently the only output in this module, will fix later
  spi_read_proc : process (SLOWCLK)
  begin
  if rising_edge(SLOWCLK) then
    if (do_spi_read='1' and strobe_pulse='1') then
      spi_read_data <= SPI_READBACK_FIFO_OUT;
      spi_readback_fifo_read_en_cmd <= '1';
    else
      spi_read_data <= spi_read_data;
      spi_readback_fifo_read_en_cmd <= '0';
    end if;
  end if;
  end process;


  --handle CFG download command
  cfg_download_proc : process (SLOWCLK)
  begin
  if rising_edge(SLOWCLK) then
    case cfg_download_state is
    when S_IDLE => 
      if do_cfg_download='1' then
        spi_cmd_fifo_write_en_cfg_dl <= '1';
        --send CMD to load address 003d...
        spi_cmd_fifo_in_cfg_dl <= x"07B7";
        cfg_download_state <= S_SET_ADDR_LOWER;
      else
        spi_cmd_fifo_write_en_cfg_dl <= '0';
        spi_cmd_fifo_in_cfg_dl <= x"0000";
        cfg_download_state <= S_IDLE;
      end if;
      
    when S_SET_ADDR_LOWER =>
      spi_cmd_fifo_write_en_cfg_dl <= '1';
      --send CMD to load address ....5000
      spi_cmd_fifo_in_cfg_dl <= x"5000";
      cfg_download_state <= S_ERASE;
    
    when S_ERASE =>
      spi_cmd_fifo_write_en_cfg_dl <= '1';
      --send CMD to erase block
      spi_cmd_fifo_in_cfg_dl <= x"000A";
      cfg_download_state <= S_BUFFER_PROGRAM;

    when S_BUFFER_PROGRAM =>
      spi_cmd_fifo_write_en_cfg_dl <= '1';
      --send CMD to buffer 16 word program
      spi_cmd_fifo_in_cfg_dl <= x"01CC";
      cfg_download_state <= S_WRITE;

    when S_WRITE =>
      spi_cmd_fifo_write_en_cfg_dl <= '1';
      --send CFG registers as program data
      spi_cmd_fifo_in_cfg_dl <= SPI_CFG_REGS(download_cfg_reg_index);
      if (download_cfg_reg_index=15) then
        download_cfg_reg_index <= 0;
        cfg_download_State <= S_IDLE;
      else
        download_cfg_reg_index <= download_cfg_reg_index + 1;
        cfg_download_state <= S_WRITE;
      end if;

    end case;
  end if;
  end process;
  
  
  --handle CFG upload command
  cfg_upload_proc : process (SLOWCLK)
  begin
  if rising_edge(SLOWCLK) then
    case cfg_upload_state is
    when S_IDLE => 
      spi_readback_fifo_read_en_cfg_ul <= '0';
      spi_cfg_ul_pulse_inner <= '0';
      spi_cfg_reg_we_inner <= NREGS;
      spi_ul_reg_inner <= x"0000";
      if do_cfg_upload='1' then
        spi_cmd_fifo_write_en_cfg_ul <= '1';
        --send CMD to load address 003d...
        spi_cmd_fifo_in_cfg_ul <= x"07B7";
        cfg_upload_state <= S_SET_ADDR_LOWER;
      else
        spi_cmd_fifo_write_en_cfg_ul <= '0';
        spi_cmd_fifo_in_cfg_ul <= x"0000";
        cfg_upload_state <= S_IDLE;
      end if;
     
    when S_SET_ADDR_LOWER =>
      spi_cmd_fifo_write_en_cfg_ul <= '1';
      spi_readback_fifo_read_en_cfg_ul <= '0';
      spi_cfg_ul_pulse_inner <= '0';
      spi_cfg_reg_we_inner <= NREGS;
      spi_ul_reg_inner <= x"0000";
      --send CMD to load address ....5000
      spi_cmd_fifo_in_cfg_ul <= x"5000";
      cfg_upload_state <= S_READN;
     
    when S_READN =>
      spi_cmd_fifo_write_en_cfg_ul <= '1';
      spi_readback_fifo_read_en_cfg_ul <= '0';
      --send CMD to read 16 words
      spi_cmd_fifo_in_cfg_ul <= x"01C4";
      cfg_upload_state <= S_WAIT_READ_BUSY;
      
    when S_WAIT_READ_BUSY =>
      spi_cmd_fifo_write_en_cfg_ul <= '0';
      spi_readback_fifo_read_en_cfg_ul <= '0';
      spi_cfg_ul_pulse_inner <= '0';
      spi_cfg_reg_we_inner <= NREGS;
      spi_ul_reg_inner <= x"0000";
      --wait for spi_ctrl to start reading
      spi_cmd_fifo_in_cfg_ul <= x"0000";
      if (SPI_READ_BUSY='1') then
        cfg_upload_state <= S_WAIT_READ_DONE;      
      else
        cfg_upload_state <= S_WAIT_READ_BUSY;
      end if;
      
    when S_WAIT_READ_DONE =>
        spi_cmd_fifo_write_en_cfg_ul <= '0';
        spi_readback_fifo_read_en_cfg_ul <= '0';
        spi_cfg_ul_pulse_inner <= '0';
        spi_cfg_reg_we_inner <= NREGS;
        spi_ul_reg_inner <= x"0000";
        --wait for spi_ctrl to finish reading
        spi_cmd_fifo_in_cfg_ul <= x"0000";
        if (SPI_READ_BUSY='1') then
          readback_fifo_stall_counter <= x"F";
          cfg_upload_state <= S_WAIT_READ_STALL;      
        else
          cfg_upload_state <= S_WAIT_READ_DONE;
        end if;
        
    when S_WAIT_READ_STALL => 
      --need to wait for some reason. FIFO propagation maybe?
      spi_cmd_fifo_write_en_cfg_ul <= '0';
      spi_readback_fifo_read_en_cfg_ul <= '0';
      spi_cfg_ul_pulse_inner <= '0';
      spi_cfg_reg_we_inner <= NREGS;
      spi_ul_reg_inner <= x"0000";
      spi_cmd_fifo_in_cfg_ul <= x"0000";
      if (readback_fifo_stall_counter=x"0") then
        cfg_upload_state <= S_READBACK;           
        readback_fifo_stall_counter <= x"F";
      else
        cfg_upload_state <= S_WAIT_READ_STALL;
        readback_fifo_stall_counter <= readback_fifo_stall_counter - 1;
      end if;
  
    when S_READBACK =>
      spi_cmd_fifo_write_en_cfg_ul <= '0';
      spi_readback_fifo_read_en_cfg_ul <= '1';
      spi_cmd_fifo_in_cfg_ul <= x"0000";
      spi_cfg_ul_pulse_inner <= '1';
      spi_cfg_reg_we_inner <= upload_cfg_reg_index;
      spi_ul_reg_inner <= SPI_READBACK_FIFO_OUT;
      --read values from readback fifo and send to CFG registers
      spi_cmd_fifo_in_cfg_ul <= SPI_CFG_REGS(download_cfg_reg_index);
      if (upload_cfg_reg_index=15) then
        upload_cfg_reg_index <= 0;
        cfg_upload_State <= S_IDLE;
      else
        upload_cfg_reg_index <= upload_cfg_reg_index + 1;
        cfg_upload_state <= S_READBACK;
      end if;
  
    end case;
  end if;
  end process;


  --multiplex signals to spi_ctrl
  SPI_CMD_FIFO_WRITE_EN <= spi_cmd_fifo_write_en_cmd or spi_cmd_fifo_write_en_cfg_dl or spi_cmd_fifo_write_en_cfg_ul;
  SPI_CMD_FIFO_IN <= spi_cmd_fifo_in_cmd when (spi_cmd_fifo_write_en_cmd='1') else
                     spi_cmd_fifo_in_cfg_dl when (spi_cmd_fifo_write_en_cfg_dl='1') else 
                     spi_cmd_fifo_in_cfg_ul when (spi_cmd_fifo_write_en_cfg_ul='1') else
                     x"0000";
  SPI_READBACK_FIFO_READ_EN <= spi_readback_fifo_read_en_cmd or spi_readback_fifo_read_en_cfg_ul;
  
  
  --signals to VMECONFREGS
  SPI_UL_REG <=  spi_ul_reg_inner when (spi_cfg_reg_we_inner /= NREGS) else x"0000";
  SPI_CONST_BUSY <= '0';
  SPI_CFG_BUSY <= '0';
  SPI_CONST_UL_PULSE <= '0'; --never upload CONST REGs
  SPI_CONST_REG_WE <= NREGS;
  SPI_CFG_UL_PULSE <= spi_cfg_ul_pulse_inner;
  SPI_CFG_REG_WE <= spi_cfg_reg_we_inner;
  
  
  --TODO: upload CFG registers on reset
  
  
  -- DTACK: always just issue on second SLOWCLK edge after STROBE
  ce_d_dtack <= STROBE and DEVICE;
  FD_D_DTACK : FDCE port map(Q => d_dtack, C => SLOWCLK, CE => ce_d_dtack, CLR => q_dtack, D => '1');
  FD_Q_DTACK : FD port map(Q => q_dtack, C => SLOWCLK, D => d_dtack);
  DTACK    <= q_dtack;

end SPI_PORT_Arch;
