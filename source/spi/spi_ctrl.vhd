library ieee;
library work;
library unisim;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;
use unisim.vcomponents.all;

--! @brief Module that interprets PROM commands and controls post-startup communication with EPROMs
--! @details supported PROM commands (sent with W 602C XXXX)
--! * 0001 write 1 (deprecated)
--! * 0002 read 1 (deprecated)
--! * 0003 write n (deprecated)
--! * (n-1)<<5 | 0004 read n words from PROM to readback FIFO
--! * (n) | 0006 read register n (1 - status register, 2 - flag status register, 3 - nonvolatile configuration register LSB, 4 - nonvolatile configuration register MSB, 5 - volatile configuration register, 6 - enhanced volatile configuration register)
--! * 000A erase sector
--! * (n-1)<<5 | 000C write n words to PROM (follow with n words to write)
--! * 0012 write configuration register (follow with 2 words to write to configuration register)
--! * 0013 write lock bit on sector
--! * 0014 erase lock bit on sector
--! * (addr_upper)<<5 | 0017 load address (follow with 1 word of lower address bits)
--! * 0019 start SPI timer
--! * 001A stop SPI timer
--! * 001B reset SPI timer
--! * (prom_number)<<5 | 001D switch to PROM prom_number (0 or 1)
entity SPI_CTRL is
  port (
    
    CLK40                 : in std_logic;                      --! 40 MHz clock input
    CLK2P5                : in std_logic;                      --! 2.5 MHz clock input
    RST                   : in std_logic;                      --! Soft reset signal
    
    CMD_FIFO_IN           : in std_logic_vector(15 downto 0);  --! SPI_CTRL command, clocked on CLK2P5
    CMD_FIFO_WRITE_EN     : in std_logic;                      --! Enable for SPI_CTRL command, clocked on CLK2P5
    
    READBACK_FIFO_OUT     : out std_logic_vector(15 downto 0); --! Read output from readback FIFO, clocked on CLK2P5
    READBACK_FIFO_READ_EN : in std_logic;                      --! Read enable for readback FIFO, clocked on CLK2P5
    READ_BUSY             : out std_logic;                     --! Indicates if a PROM read is in progress

    CNFG_DATA_IN          : in std_logic_vector(7 downto 4);   --! Data in from second EPROM
    CNFG_DATA_OUT         : out std_logic_vector(7 downto 4);  --! Data out to second EPROM
    CNFG_DATA_DIR         : out std_logic_vector(7 downto 4);  --! Tristate controller for second EPROM (1=to PROM)
    PROM_CS2_B            : out std_logic;                     --! Chip select for second EPROM
    
    RBK_WRD_CNT           : out std_logic_vector(10 downto 0); --! Number of words in readback FIFO
    
    FSM_ENABLE            : in std_logic;                      --! enable signal for finite state machine
    FSM_DISABLE           : in std_logic;                      --! disable signal for finite state machine
    SPI_TIMER             : out std_logic_vector(31 downto 0); --! SPI timer register
    SPI_STATUS            : out std_logic_vector(15 downto 0); --! SPI status register
    
    DIAGOUT               : out std_logic_vector(17 downto 0)  --! Debug signals

    );
end SPI_CTRL;


architecture SPI_CTRL_Arch of SPI_CTRL is

  component spi_interface is
    port
    (
      CLK                     : in std_logic;
      RST                     : in std_logic;
      ------------------ Signals to FIFO
      WRITE_FIFO_INPUT        : in std_logic_vector(15 downto 0);
      WRITE_FIFO_WRITE_ENABLE : in std_logic;
      ------------------ Address loading signals
      START_ADDRESS           : in std_logic_vector(31 downto 0);
      START_ADDRESS_VALID     : in std_logic;
      --PAGE_COUNT              : in std_logic_vector(17 downto 0);
      --PAGE_COUNT_VALID        : in std_logic;
      --SECTOR_COUNT            : in std_logic_vector(13 downto 0);
      --SECTOR_COUNT_VALID      : in std_logic;
      ------------------ Commands
      WRITE_NWORDS            : in unsigned(11 downto 0);
      START_WRITE             : in std_logic;
      OUT_WRITE_DONE          : out std_logic;
      READ_NWORDS             : in unsigned(11 downto 0);
      START_READ              : in std_logic;
      OUT_READ_DONE           : out std_logic;
      START_ERASE             : in std_logic;
      OUT_ERASE_DONE          : out std_logic;
      START_UNLOCK            : in std_logic;
      OUT_UNLOCK_DONE         : out std_logic;
      START_LOCK              : in std_logic;
      OUT_LOCK_DONE           : out std_logic;
      START_WRITE_CONFIG      : in std_logic;
      OUT_WRITE_CONFIG_DONE   : out std_logic;                   
      REGISTER_CONTENTS       : in std_logic_vector(15 downto 0); 
      START_READ_REGISTER     : in std_logic_vector(3 downto 0);
      OUT_READ_REGISTER_DONE  : out std_logic;                    
      OUT_REGISTER            : out std_logic_vector(7 downto 0); 
      OUT_REGISTER_WE         : out std_logic;                     
      ------------------ Read output
      OUT_READ_DATA           : out std_logic_vector(15 downto 0);
      OUT_READ_DATA_VALID     : out std_logic;
      ------------------ Signals to/from second EPROM
      PROM_SELECT             : in std_logic;
      CNFG_DATA_IN            : in std_logic_vector(7 downto 4); 
      CNFG_DATA_OUT           : out std_logic_vector(7 downto 4); 
      CNFG_DATA_DIR           : out std_logic_vector(7 downto 4); 
      PROM_CS2_B              : out std_logic; 
      ------------------ Debug
      DIAGOUT                 : out std_logic_vector(17 downto 0)
     ); 	
  end component spi_interface;

  component spi_cmd_fifo
    port (
      srst : IN STD_LOGIC;
      wr_clk : IN STD_LOGIC;
      rd_clk : IN STD_LOGIC;
      din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      wr_en : IN STD_LOGIC;
      rd_en : IN STD_LOGIC;
      dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
      full : OUT STD_LOGIC;
      empty : OUT STD_LOGIC;
      --prog_full : OUT STD_LOGIC;
      wr_rst_busy : OUT STD_LOGIC;
      rd_rst_busy : OUT STD_LOGIC
      );
    end component;

  component spi_readback_fifo
  port (
    srst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    --prog_full : OUT STD_LOGIC;
    wr_rst_busy : OUT STD_LOGIC;
    rd_rst_busy : OUT STD_LOGIC
    );
  end component;
  
  component ila_spi
  port (
    clk : in std_logic;
    probe0 : in std_logic_vector(511 downto 0)
    );
  end component;

  --CMD FIFO signals
  signal cmd_fifo_in_macro : std_logic_vector(15 downto 0) := x"0000";
  signal cmd_fifo_empty    : std_logic := '1';
  signal cmd_fifo_full     : std_logic := '0';
  signal cmd_fifo_read_en  : std_logic := '0';
  signal cmd_fifo_out      : std_logic_vector(15 downto 0) := x"0000";
  signal prom_addr         : std_logic_vector(31 downto 0) := x"00000000";
  signal prom_load_addr    : std_logic := '0';
  signal temp_pagecount    : std_logic_vector(17 downto 0) := x"0000" & "01";
  signal temp_sectorcount  : std_logic_vector(13 downto 0) := x"000" & "01";
  signal temp_cmdindex     : std_logic_vector(3 downto 0) := x"4"; --RDFR24QUAD
  signal read_nwords       : unsigned(11 downto 0) := (others => '0');
  type cmd_fifo_states is (
    S_IDLE, 
    S_LOAD_ADDR_CMD, S_LOAD_ADDR_STALL_1, S_LOAD_ADDR_STALL_2, S_LOAD_ADDR_LOWER,
    S_READ_CMD, S_READ_LOW, S_READ_WAIT, 
    S_READ_REGISTER_CMD, S_READ_REGISTER_LOW, S_READ_REGISTER_WAIT,
    S_WRITE_CMD, S_WRITE_STALL_1, S_WRITE_STALL_2, S_WRITE_WORD, S_WRITE_START, S_WRITE_WAIT, 
    S_ERASE_CMD, S_ERASE_LOW, S_ERASE_WAIT, 
    S_LOCK_CMD, S_LOCK_LOW, S_LOCK_WAIT,
    S_UNLOCK_CMD, S_UNLOCK_LOW, S_UNLOCK_WAIT,
    S_WRITE_CONFIG_CMD, S_WRITE_CONFIG_STALL_1, S_WRITE_CONFIG_STALL_2, S_WRITE_CONFIG_LOWER, S_WRITE_CONFIG_WAIT,
    S_START_TIMER_CMD, S_STOP_TIMER_CMD, S_RESET_TIMER_CMD,
    S_SWITCH_PROM_CMD,
    S_UNKNOWN_CMD, S_STALL
  );
  signal cmd_fifo_state      : cmd_fifo_states := S_IDLE;
  signal write_word_counter  : unsigned(11 downto 0) := (others => '0');
  
  signal program_nwords      : unsigned(11 downto 0) := (others => '0');
  signal write_fifo_write_en : std_logic := '0';
  signal prom_read_en        : std_logic := '0';
  signal prom_erase_en       : std_logic := '0';
  signal prom_write_en       : std_logic := '0';
  signal prom_unlock_en      : std_logic := '0';
  signal prom_lock_en        : std_logic := '0';
  signal prom_wr_config_en   : std_logic := '0';
  signal read_done           : std_logic := '0';
  signal erase_done          : std_logic := '0';
  signal write_done          : std_logic := '0';
  signal lock_done           : std_logic := '0';
  signal unlock_done         : std_logic := '0';
  signal write_config_done   : std_logic := '0';
  signal read_register_en    : std_logic_vector(3 downto 0) := x"0";
  signal read_register_done  : std_logic := '0';
  signal spi_timer_en        : std_logic := '0';
  signal spi_timer_rst       : std_logic := '0';
  signal register_contents   : std_logic_vector(15 downto 0) := (others => '0');
  
  signal fsm_is_enabled      : std_logic := '1';
  
  --READ signals
  type rd_fifo_states is (S_FIFOIDLE, S_FIFOWRITE_PRE, S_FIFOWRITE);
  signal rd_fifo_state : rd_fifo_states := S_FIFOIDLE;
  signal wr_dvalid_cnt : unsigned(31 downto 0) := x"00000000";
  signal load_rd_fifo  : std_logic := '0';

  --read FIFO signals
  signal readback_fifo_wr_en       : std_logic := '0';
  signal start_read_fifo_q         : std_logic := '0';
  signal readback_fifo_rd_en       : std_logic := '0';
  signal rd_data_valid             : std_logic := '0';
  signal spi_readdata              : std_logic_vector(15 downto 0) := x"0000";
  signal readback_fifo_wr_rst_busy : std_logic := '0'; 
  signal readback_fifo_rd_rst_busy : std_logic := '0';
  signal nwords_readback           : unsigned(10 downto 0) := "00000000000";
  signal read_en_clk40_meta        : std_logic := '0';
  signal read_en_clk40_sync1       : std_logic := '0';
  signal read_en_clk40_sync2       : std_logic := '0';
  signal read_en_clk40_pulse       : std_logic := '0';
  signal readback_fifo_full        : std_logic := '0';
  signal readback_fifo_empty       : std_logic := '0';

  --timer and status signals

  signal spi_timer_inner           : unsigned(31 downto 0) := x"00000000";
  signal spi_register_inner        : std_logic_vector(15 downto 0) := x"0000";
  signal spi_register_we           : std_logic := '0';
  signal spi_register_readback     : std_logic_vector(7 downto 0) := x"00";
  signal spi_timer_countup         : unsigned(7 downto 0) := x"FF";
  signal readback_fifo_empty_meta  : std_logic := '0';
  signal readback_fifo_empty_sync  : std_logic := '0';
  signal readback_fifo_full_meta   : std_logic := '0';
  signal readback_fifo_full_sync   : std_logic := '0';
  signal cmd_fifo_empty_meta       : std_logic := '0';
  signal cmd_fifo_empty_sync       : std_logic := '0';
  signal cmd_fifo_full_meta        : std_logic := '0';
  signal cmd_fifo_full_sync        : std_logic := '0';
  
  --debugging signals
  signal cmd_fifo_read_en_q     : std_logic := '0';
  signal cmd_fifo_read_en_pulse : std_logic := '0';
  signal ila_probe              : std_logic_vector(511 downto 0) := (others => '0');
  
  signal prom_cs2_b_inner       : std_logic := '0';
  signal cnfg_data_in_inner     : std_logic_vector(7 downto 4) := (others => '0');
  signal cnfg_data_out_inner     : std_logic_vector(7 downto 4) := (others => '0');
  signal cnfg_data_dir_inner     : std_logic_vector(7 downto 4) := (others => '0');

  --prom select signals
  signal prom_select : std_logic := '0';

begin

  ila_spi_i : ila_spi
    PORT MAP (
      clk => CLK40,
      probe0 => ila_probe
    );
  ila_probe(0) <= CMD_FIFO_WRITE_EN;
  ila_probe(16 downto 1) <= CMD_FIFO_IN;
  ila_probe(32 downto 17) <= cmd_fifo_out;
  ila_probe(33) <= write_fifo_write_en;
  ila_probe(65 downto 34) <= prom_addr;
  ila_probe(66) <= prom_load_addr;
  ila_probe(78 downto 67) <= std_logic_vector(program_nwords);
  ila_probe(79) <= prom_write_en;
  ila_probe(80) <= write_done;
  ila_probe(92 downto 81) <= std_logic_vector(read_nwords);
  ila_probe(93) <= prom_read_en;
  ila_probe(94) <= read_done;
  ila_probe(95) <= prom_erase_en;
  ila_probe(96) <= erase_done;
  ila_probe(112 downto 97) <= spi_readdata;
  ila_probe(113) <= readback_fifo_wr_en;
  ila_probe(114) <= cmd_fifo_read_en;
  ila_probe(115) <= prom_select;
  ila_probe(116) <= prom_cs2_b_inner;
  ila_probe(120 downto 117) <= cnfg_data_dir_inner;
  ila_probe(124 downto 121) <= cnfg_data_out_inner;
  ila_probe(128 downto 125) <= cnfg_data_in_inner;
  ila_probe(132 downto 129) <= read_register_en;
  ila_probe(133) <= read_register_done;
  ila_probe(141 downto 134) <= spi_register_readback;
  ila_probe(142) <= spi_register_we;
  
  PROM_CS2_B <= prom_cs2_b_inner;
  cnfg_data_in_inner <= CNFG_DATA_IN;
  CNFG_DATA_OUT <= cnfg_data_out_inner;
  CNFG_DATA_DIR <= cnfg_data_dir_inner;

  --translate depricated commands
  cmd_fifo_in_macro <= x"000C" when (CMD_FIFO_IN(4 downto 0) = "00001") else --01 write 1
                       x"000A" when (CMD_FIFO_IN(4 downto 0) = "00010") else --02 read 1
                       CMD_FIFO_IN(15 downto 5) & "01100" when (CMD_FIFO_IN(4 downto 0) = "00011") else --03 write n
                       CMD_FIFO_IN(15 downto 5) & "01100" when (CMD_FIFO_IN(4 downto 0) = "01011") else --0B program
                       CMD_FIFO_IN;
  
  --Handle outside signals coming to command FIFO
  spi_cmd_fifo_i : spi_cmd_fifo
      PORT MAP (
        srst => RST,
        wr_clk => CLK2P5,
        rd_clk => CLK40,
        din => cmd_fifo_in_macro,
        wr_en => CMD_FIFO_WRITE_EN,
        rd_en => cmd_fifo_read_en_pulse,
        dout => cmd_fifo_out,
        full => cmd_fifo_full,
        empty => cmd_fifo_empty,
        wr_rst_busy => open,
        rd_rst_busy => open
      );
      
  cmd_fifo_read_en_q <= cmd_fifo_read_en when rising_edge(CLK40) else cmd_fifo_read_en_q;
  cmd_fifo_read_en_pulse <= (not cmd_fifo_read_en_q) and cmd_fifo_read_en;
  
  enable_cmd_fifo_fsm : process(CLK40, RST)
  begin
    if (RST='1') then
      fsm_is_enabled <= '1';
    elsif rising_edge(CLK40) then
      if (FSM_ENABLE='1') then
        fsm_is_enabled <= '1';
      elsif (FSM_DISABLE='1') then
        fsm_is_enabled <= '0';
      else
        fsm_is_enabled <= fsm_is_enabled;
      end if;
    end if;
  end process;

  --FSM to process command FIFO
  process_cmd_fifo_fsm : process(CLK40, RST)
  begin
  if (RST='1') then
    cmd_fifo_state <= S_IDLE;
  elsif (rising_edge(CLK40)) then
    if (fsm_is_enabled='1') then
      case cmd_fifo_state is
      
      when S_IDLE =>
        --do nothing until command to process (command FIFO is not empty)
        if (cmd_fifo_empty='0') then
          case "000" & cmd_fifo_out(4 downto 0) is
          when x"04" =>
            --read n
            cmd_fifo_state  <= S_READ_CMD;
          when x"06" =>
            --read register
            cmd_fifo_state  <= S_READ_REGISTER_CMD;
          when x"0A" =>
            --erase sector (hardcode to 1 sector?)
            cmd_fifo_state  <= S_ERASE_CMD;
          when x"0C" =>
            --buffer program 
            cmd_fifo_state  <= S_WRITE_CMD;
          when x"12" =>
            --write configuration register
            cmd_fifo_state  <= S_WRITE_CONFIG_CMD;
          when x"13" =>
            --lock block
            cmd_fifo_state  <= S_LOCK_CMD;
          when x"14" =>
            --unlock
            cmd_fifo_state  <= S_UNLOCK_CMD;
          when x"17" =>
            --load address
            cmd_fifo_state  <= S_LOAD_ADDR_CMD;
          when x"19" =>
            --start timer
            cmd_fifo_state  <= S_START_TIMER_CMD;
          when x"1A" =>
            --stop timer
            cmd_fifo_state  <= S_STOP_TIMER_CMD;
          when x"1B" =>
            --reset timer
            cmd_fifo_state  <= S_RESET_TIMER_CMD;
          when x"1D" =>
            --switch prom
            cmd_fifo_state  <= S_SWITCH_PROM_CMD;
          when others =>
            --unknown command
            cmd_fifo_state  <= S_UNKNOWN_CMD;
          end case;
        else
          cmd_fifo_state    <= S_IDLE;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_READ_CMD =>
        --start read process by sending read enable and number of words to read. Also remove command from FIFO
        cmd_fifo_state      <= S_READ_LOW;
        prom_read_en        <= '1';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= "0" & unsigned(cmd_fifo_out(15 downto 5)); 
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_READ_LOW => 
        --needed to wait for read_done to go low
        cmd_fifo_state      <= S_READ_WAIT;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords; 
        program_nwords      <= program_nwords;
        write_word_counter  <= write_word_counter;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_READ_WAIT =>
        --don't process any more commands until read is finished
        if (read_done='1') then
          cmd_fifo_state    <= S_IDLE;
        else 
          cmd_fifo_state    <= S_READ_WAIT;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords; 
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_READ_REGISTER_CMD =>
        --start read process by sending read register enable. Also remove command from FIFO
        cmd_fifo_state      <= S_READ_REGISTER_LOW;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= cmd_fifo_out(8 downto 5);
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords; 
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_READ_REGISTER_LOW => 
        --needed to wait for read_done to go low
        cmd_fifo_state      <= S_READ_REGISTER_WAIT;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords; 
        program_nwords      <= program_nwords;
        write_word_counter  <= write_word_counter;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_READ_REGISTER_WAIT =>
        --don't process any more commands until read is finished
        if (read_register_done='1') then
          cmd_fifo_state    <= S_IDLE;
        else 
          cmd_fifo_state    <= S_READ_REGISTER_WAIT;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords; 
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_ERASE_CMD =>
        --start erase sector command with erase enable and remove command from FIFO
        cmd_fifo_state      <= S_ERASE_LOW;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '1';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_ERASE_LOW => 
        --wait for erase_done to go low
        cmd_fifo_state      <= S_ERASE_WAIT;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_ERASE_WAIT =>
        --don't accept any more commands until done with erase command
        if (erase_done='1') then
          cmd_fifo_state    <= S_IDLE;
        else 
          cmd_fifo_state    <= S_ERASE_WAIT;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_WRITE_CMD =>
        --read number of words to program from command and remove command from FIFO
        write_word_counter  <= x"000";
        cmd_fifo_state      <= S_WRITE_STALL_1; 
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;      
        program_nwords      <= "0" & unsigned(cmd_fifo_out(15 downto 5));
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_WRITE_STALL_1 =>
        --wait an extra cycle for empty to be potentially de-asserted
        cmd_fifo_state      <= S_WRITE_STALL_2;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
       
      when S_WRITE_STALL_2 =>
        --continue when next word to write ready in command FIFO
        if (cmd_fifo_empty='0') then
          cmd_fifo_state    <= S_WRITE_WORD;
        else
          cmd_fifo_state    <= S_WRITE_STALL_2;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_WRITE_WORD =>
        --write this word to the spi_interface write buffer FIFO (goes directly from command FIFO to spi_interface buffer)
        write_word_counter  <= write_word_counter + 1;
        if (write_word_counter = program_nwords) then
          cmd_fifo_state    <= S_WRITE_START;
        else
          cmd_fifo_state    <= S_WRITE_STALL_1;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '1';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_WRITE_START =>
        --start write command
        cmd_fifo_state      <= S_WRITE_WAIT;
        prom_read_en        <= '0';
        prom_write_en       <= '1';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_WRITE_WAIT => 
        --wait until write_done is 1
        if (write_done='1') then
          cmd_fifo_state    <= S_IDLE;
        else 
          cmd_fifo_state    <= S_WRITE_WAIT;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_WRITE_CONFIG_CMD =>
        --remove command from FIFO
        write_word_counter  <= x"000";
        cmd_fifo_state      <= S_WRITE_CONFIG_STALL_1; 
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;      
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_WRITE_CONFIG_STALL_1 => 
        --need to wait because empty takes an extra cycle to go low
        cmd_fifo_state      <= S_WRITE_CONFIG_STALL_2;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_WRITE_CONFIG_STALL_2 => 
        --continue when lower part of address is ready in command FIFO
        if (cmd_fifo_empty='0') then
          cmd_fifo_state    <= S_WRITE_CONFIG_LOWER;
        else
          cmd_fifo_state    <= S_WRITE_CONFIG_STALL_2;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
              
      when S_WRITE_CONFIG_LOWER =>
        --set lower part of address, remove command from FIFO, and pass address onto spi_interface
        cmd_fifo_state      <= S_WRITE_CONFIG_WAIT;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '1';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= cmd_fifo_out;

      when S_WRITE_CONFIG_WAIT =>
        --don't accept any more commands until done with erase command
        if (write_config_done='1') then
          cmd_fifo_state    <= S_IDLE;
        else 
          cmd_fifo_state    <= S_WRITE_CONFIG_WAIT;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_LOCK_CMD =>
        --start lock sector command with lock enable and remove command from FIFO
        cmd_fifo_state      <= S_LOCK_LOW;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '1';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_LOCK_LOW => 
        --wait for lock_done to go low
        cmd_fifo_state      <= S_LOCK_WAIT;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_LOCK_WAIT =>
        --don't accept any more commands until done with erase command
        if (lock_done='1') then
          cmd_fifo_state    <= S_IDLE;
        else 
          cmd_fifo_state    <= S_LOCK_WAIT;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_UNLOCK_CMD =>
        --start erase sector command with erase enable and remove command from FIFO
        cmd_fifo_state      <= S_UNLOCK_LOW;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '1';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_UNLOCK_LOW => 
        --wait for erase_done to go low
        cmd_fifo_state      <= S_UNLOCK_WAIT;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_UNLOCK_WAIT =>
        --don't accept any more commands until done with erase command
        if (erase_done='1') then
          cmd_fifo_state    <= S_IDLE;
        else 
          cmd_fifo_state    <= S_UNLOCK_WAIT;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_LOAD_ADDR_CMD =>
        --set the upper part of address and remove command from FIFO
        cmd_fifo_state      <= S_LOAD_ADDR_STALL_1;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= "00000" & cmd_fifo_out(15 downto 5) & prom_addr(15 downto 0);
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_LOAD_ADDR_STALL_1 => 
        --need to wait because empty takes an extra cycle to go low
        cmd_fifo_state      <= S_LOAD_ADDR_STALL_2;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
        
      when S_LOAD_ADDR_STALL_2 => 
        --continue when lower part of address is ready in command FIFO
        if (cmd_fifo_empty='0') then
          cmd_fifo_state    <= S_LOAD_ADDR_LOWER;
        else
          cmd_fifo_state    <= S_LOAD_ADDR_STALL_2;
        end if;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
              
      when S_LOAD_ADDR_LOWER =>
        --set lower part of address, remove command from FIFO, and pass address onto spi_interface
        cmd_fifo_state      <= S_STALL;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '1';
        cmd_fifo_read_en    <= '1';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr(31 downto 16) & cmd_fifo_out;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_START_TIMER_CMD =>
        --start timer and remove command from FIFO
        cmd_fifo_state      <= S_STALL;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';
        spi_timer_rst       <= '0';
        spi_timer_en        <= '1';
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_STOP_TIMER_CMD =>
        --stop timer and remove command from FIFO
        cmd_fifo_state      <= S_STALL;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';
        spi_timer_rst       <= '0';
        spi_timer_en        <= '0';
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_RESET_TIMER_CMD =>
        --stop timer and remove command from FIFO
        cmd_fifo_state      <= S_STALL;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';
        spi_timer_rst       <= '1';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_SWITCH_PROM_CMD =>
        --switch selected PROM and remove command from FIFO
        cmd_fifo_state      <= S_STALL;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';  
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= cmd_fifo_out(5);
        register_contents   <= register_contents;
        
      when S_UNKNOWN_CMD =>
        --do nothing but remove command from FIFO
        cmd_fifo_state      <= S_STALL;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '1';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;

      when S_STALL =>
        --need to wait because empty takes an extra cycle to go low
        cmd_fifo_state      <= S_IDLE;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
      
      when others =>
        --unimplemented state
        cmd_fifo_state      <= S_IDLE;
        prom_read_en        <= '0';
        prom_write_en       <= '0';
        prom_erase_en       <= '0';
        prom_lock_en        <= '0';
        prom_unlock_en      <= '0';
        prom_wr_config_en   <= '0';
        write_fifo_write_en <= '0';
        read_register_en    <= x"0";
        prom_load_addr      <= '0';
        cmd_fifo_read_en    <= '0';
        spi_timer_rst       <= '0';
        spi_timer_en        <= spi_timer_en;
        read_nwords         <= read_nwords;
        program_nwords      <= program_nwords;
        prom_addr           <= prom_addr;
        prom_select         <= prom_select;
        register_contents   <= register_contents;
      end case;
    end if;
  end if;
  end process;

  SPI_TIMER <= std_logic_vector(spi_timer_inner);
  SPI_STATUS <= spi_register_inner;

  timer_fst : process(CLK40, RST)
  begin
  if (rising_edge(CLK40)) then
    --genereate 1 MHz clock by counting
    if (spi_timer_countup = 39) then
      spi_timer_countup <= x"00";
      if (spi_timer_rst = '1') then
        spi_timer_inner <= x"00000000";
      elsif (spi_timer_en = '1') then
        spi_timer_inner <= spi_timer_inner + 1;
      end if;
    else
      if (spi_timer_rst = '1') then
        spi_timer_inner <= x"00000000";
      end if;
      spi_timer_countup <= spi_timer_countup + 1;
    end if;
  end if;
  end process;

  status_fsm : process(CLK40, RST)
  begin
  if (RST='1') then
    spi_register_inner <= x"0000";
  elsif (rising_edge(CLK40)) then
    readback_fifo_empty_meta <= readback_fifo_empty;
    readback_fifo_empty_sync <= readback_fifo_empty_meta;
    readback_fifo_full_meta <= readback_fifo_full;
    readback_fifo_full_sync <= readback_fifo_full_meta;
    cmd_fifo_empty_meta <= cmd_fifo_empty;
    cmd_fifo_empty_sync <= cmd_fifo_empty_meta;
    cmd_fifo_full_meta <= cmd_fifo_full;
    cmd_fifo_full_sync <= cmd_fifo_full_meta;
    if (spi_register_we = '1') then
      spi_register_inner <= readback_fifo_empty_sync & readback_fifo_full_sync & "00" & cmd_fifo_empty_sync & cmd_fifo_full_sync & "00" & spi_register_readback;
    else
      spi_register_inner <= readback_fifo_empty_sync & readback_fifo_full_sync & "00" & cmd_fifo_empty_sync & cmd_fifo_full_sync & "00" & spi_register_inner(7 downto 0);
    end if;
  end if;
  end process;
  
  --FSM to record number of words in readback FIFO. Involves some clock domain crossings
  process_nword_readback : process(CLK40, RST)
  begin
  if (RST='1') then
    nwords_readback <= "00000000000";
  elsif (rising_edge(CLK40)) then
    if (readback_fifo_wr_en = '1' and read_en_clk40_pulse = '0') then
      nwords_readback <= nwords_readback+1;
    elsif (read_en_clk40_pulse = '1' and readback_fifo_wr_en = '0' and readback_fifo_empty_sync /= '1') then
      nwords_readback <= nwords_readback-1;
    else
      nwords_readback <= nwords_readback;
    end if;
    read_en_clk40_meta <= READBACK_FIFO_READ_EN;
    read_en_clk40_sync1 <= read_en_clk40_meta;
    read_en_clk40_sync2 <= read_en_clk40_sync1;
    read_en_clk40_pulse <= read_en_clk40_sync1 and not read_en_clk40_sync2;
  end if;
  end process;
  
  RBK_WRD_CNT <= std_logic_vector(nwords_readback);

  --readback_fifo_wr_en <= '1' when (rd_data_valid = '1' and load_rd_fifo = '1') else '0';
  spi_readback_fifo_i : spi_readback_fifo
      PORT MAP (
        srst => RST,
        wr_clk => CLK40,
        rd_clk => CLK2P5,
        din => spi_readdata,
        wr_en => readback_fifo_wr_en,
        rd_en => READBACK_FIFO_READ_EN,
        dout => READBACK_FIFO_OUT,
        full => readback_fifo_full,
        empty => readback_fifo_empty,
        --prog_full => rd_fifo_prog_full,
        wr_rst_busy => readback_fifo_wr_rst_busy,
        rd_rst_busy => readback_fifo_rd_rst_busy
      );

  --SPI program shifts bytes in 2 nibbles with MSB at beginning

  spi_interface_inst: spi_interface 
  port map(
    CLK                     => CLK40,
    RST                     => RST,
    ------------------ Signals to FIFO
    WRITE_FIFO_INPUT        => cmd_fifo_out,
    WRITE_FIFO_WRITE_ENABLE => write_fifo_write_en,
    ------------------ Address loading signals
    START_ADDRESS           => prom_addr,
    START_ADDRESS_VALID     => prom_load_addr,
    --PAGE_COUNT            => temp_pagecount,
    --PAGE_COUNT_VALID      => prom_load_addr,
    --SECTOR_COUNT          => temp_sectorcount,
    --SECTOR_COUNT_VALID    => prom_load_addr,
    ------------------ Commands
    WRITE_NWORDS            => program_nwords,
    START_WRITE             => prom_write_en,
    OUT_WRITE_DONE          => write_done,
    READ_NWORDS             => read_nwords,
    START_READ              => prom_read_en,
    OUT_READ_DONE           => read_done,
    START_ERASE             => prom_erase_en,
    OUT_ERASE_DONE          => erase_done,
    START_UNLOCK            => prom_unlock_en,
    OUT_UNLOCK_DONE         => unlock_done,
    START_LOCK              => prom_lock_en,
    OUT_LOCK_DONE           => lock_done,
    START_WRITE_CONFIG      => prom_wr_config_en,
    OUT_WRITE_CONFIG_DONE   => write_config_done,
    REGISTER_CONTENTS       => register_contents,
    START_READ_REGISTER     => read_register_en,
    OUT_READ_REGISTER_DONE  => read_register_done,
    OUT_REGISTER            => spi_register_readback,
    OUT_REGISTER_WE         => spi_register_we,
    ------------------ Read output
    OUT_READ_DATA           => spi_readdata,
    OUT_READ_DATA_VALID     => readback_fifo_wr_en,
    ------------------ Signals to/from second EPROM
    PROM_SELECT             => prom_select,
    CNFG_DATA_IN            => CNFG_DATA_IN_inner,
    CNFG_DATA_OUT           => CNFG_DATA_OUT_inner,
    CNFG_DATA_DIR           => CNFG_DATA_DIR_inner,
    PROM_CS2_B              => PROM_CS2_B_inner,
    ------------------ Debug
    DIAGOUT                 => DIAGOUT
    );
    
  --read busy signal
  READ_BUSY <= not read_done;
    
  --debug
  --DIAGOUT(7 downto 0) <= cmd_fifo_out(7 downto 0);
  --DIAGOUT(12 downto 8) <= cmd_fifo_read_en & prom_read_en & prom_write_en & prom_erase_en & write_done;
  --DIAGOUT(16 downto 13) <= std_logic_vector(write_word_counter(3 downto 0));
  --DIAGOUT(17) <= cmd_fifo_read_en_pulse;
  
end SPI_CTRL_Arch;
