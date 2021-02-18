library ieee;
library work;
library unisim;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;
use unisim.vcomponents.all;

entity SPI_CTRL is
  port (
    
    CLK40   : in std_logic;
    CLK2P5  : in std_logic;
    RST     : in std_logic;
    
    CMD_FIFO_IN : in std_logic_vector(15 downto 0);
    CMD_FIFO_WRITE_EN : in std_logic;
    
    READBACK_FIFO_OUT : out std_logic_vector(15 downto 0);
    READBACK_FIFO_READ_EN : in std_logic;
    READ_BUSY : out std_logic;
    
    DIAGOUT : out std_logic_vector(17 downto 0)

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
      ------------------ Read output
      OUT_READ_DATA           : out std_logic_vector(15 downto 0);
      OUT_READ_DATA_VALID     : out std_logic;
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

  --CMD FIFO signals
  signal cmd_fifo_empty : std_logic := '1';
  signal cmd_fifo_read_en : std_logic := '0';
  signal cmd_fifo_out : std_logic_vector(15 downto 0) := x"0000";
  signal prom_addr : std_logic_vector(31 downto 0) := x"00000000";
  signal prom_load_addr : std_logic := '0';
  signal temp_pagecount : std_logic_vector(17 downto 0) := x"0000" & "01";
  signal temp_sectorcount : std_logic_vector(13 downto 0) := x"000" & "01";
  signal temp_cmdindex : std_logic_vector(3 downto 0) := x"4"; --RDFR24QUAD
  signal read_nwords : unsigned(11 downto 0) := (others => '0');
  type cmd_fifo_states is (
    S_IDLE, S_LOAD_ADDR_STALL, S_LOAD_ADDR_LOWER, S_LOAD_ADDR_STALL_2,
    S_READ_LOW, S_READ_WAIT, S_WRITE_STALL, S_WRITE_WORD,
    S_WRITE_WAIT, S_ERASE_LOW, S_ERASE_WAIT
  );
  signal cmd_fifo_state : cmd_fifo_states := S_IDLE;
  signal write_word_counter : unsigned(11 downto 0) := (others => '0');
  
  signal program_nwords : unsigned(11 downto 0) := (others => '0');
  signal write_fifo_write_en : std_logic := '0';
  signal prom_read_en, prom_erase_en, prom_write_en : std_logic := '0';
  signal read_done, erase_done, write_done : std_logic := '0';
  
  --READ signals
  signal wr_dvalid_cnt : unsigned(31 downto 0) := x"00000000";
  signal load_rd_fifo : std_logic := '0';
  type rd_fifo_states is (S_FIFOIDLE, S_FIFOWRITE_PRE, S_FIFOWRITE);
  signal rd_fifo_state : rd_fifo_states := S_FIFOIDLE;

  --read FIFO signals
  signal readback_fifo_wr_en : std_logic := '0';
  signal start_read_fifo_q : std_logic := '0';
  signal readback_fifo_rd_en : std_logic := '0';
  signal rd_data_valid : std_logic := '0';
  signal spi_readdata : std_logic_vector(15 downto 0) := x"0000";
  signal readback_fifo_wr_rst_busy, readback_fifo_rd_rst_busy : std_logic := '0';

begin

  --Handle outside signals coming to command FIFO
  spi_cmd_fifo_i : spi_cmd_fifo
      PORT MAP (
        srst => RST,
        wr_clk => CLK2P5,
        rd_clk => CLK40,
        din => CMD_FIFO_IN,
        wr_en => CMD_FIFO_WRITE_EN,
        rd_en => cmd_fifo_read_en,
        dout => cmd_fifo_out,
        full => open,
        empty => cmd_fifo_empty,
        wr_rst_busy => open,
        rd_rst_busy => open
      );

  --FSM to handle command FIFO
  process_cmd_fifo : process(CLK40, RST)
  begin
  if (RST='1') then
    cmd_fifo_state <= S_IDLE;
    prom_read_en <= '0';
    prom_write_en <= '0';
    prom_erase_en <= '0';
    write_fifo_write_en <= '0';
    prom_load_addr <= '0';
  elsif (rising_edge(CLK40)) then
    case cmd_fifo_state is
    
    when S_IDLE =>
      prom_load_addr <= '0';
      if (cmd_fifo_empty='0') then
        --command to be processed, interpret OPCODE
        cmd_fifo_read_en <= '1';
        case "000" & cmd_fifo_out(4 downto 0) is
        when x"04" =>
          --read n
          read_nwords <= "0" & unsigned(cmd_fifo_out(15 downto 5));
          prom_read_en <= '1';
          cmd_fifo_state <= S_READ_LOW;
        when x"0A" =>
          --erase sector 
          --(hardcode to 1 sector?)
          prom_erase_en <= '1';
          cmd_fifo_state <= S_ERASE_LOW;
        when x"0C" =>
          --buffer program 
          write_word_counter <= x"000";
          program_nwords <= ('0' & unsigned(cmd_fifo_out(15 downto 5)));
          cmd_fifo_state <= S_WRITE_STALL;
        when x"17" =>
          --load address
          prom_addr(31 downto 16) <= "00000" & cmd_fifo_out(15 downto 5);
          cmd_fifo_state <= S_LOAD_ADDR_STALL;
        when others =>
          --unknown command, skip
          cmd_fifo_state <= S_IDLE;
        end case;
      else
        cmd_fifo_read_en <= '0';
        cmd_fifo_state <= S_IDLE;
      end if;
      
    when S_READ_LOW => 
      prom_read_en <= '0';
      cmd_fifo_read_en <= '0';
      cmd_fifo_state <= S_READ_WAIT;
      
    when S_READ_WAIT =>
      cmd_fifo_read_en <= '0';
      if (read_done='1') then
        cmd_fifo_state <= S_IDLE;
      else 
        cmd_fifo_state <= S_READ_WAIT;
      end if;
      
    when S_ERASE_LOW => 
      prom_erase_en <= '0';
      cmd_fifo_read_en <= '0';
      cmd_fifo_state <= S_ERASE_WAIT;
      
    when S_ERASE_WAIT =>
      cmd_fifo_read_en <= '0';
      if (erase_done='1') then
        cmd_fifo_state <= S_IDLE;
      else 
        cmd_fifo_state <= S_ERASE_WAIT;
      end if;
      
    when S_WRITE_STALL =>
      --need to wait because empty takes an extra cycle to go low?
      cmd_fifo_read_en <= '0';
      write_fifo_write_en <= '0';
      cmd_fifo_state <= S_WRITE_WORD;
      
    when S_WRITE_WORD =>
      if (cmd_fifo_empty='0') then
        cmd_fifo_read_en <= '1';
        write_fifo_write_en <= '1';
        if (write_word_counter = program_nwords) then
          write_word_counter <= x"000";
          prom_write_en <= '1';
          cmd_fifo_state <= S_WRITE_WAIT;
        else
          write_word_counter <= write_word_counter + 1;
          cmd_fifo_state <= S_WRITE_STALL;
        end if;
      else
        cmd_fifo_read_en <= '0';
        write_word_counter <= write_word_counter;
        cmd_fifo_state <= S_WRITE_WORD;
      end if;
      
    when S_WRITE_WAIT => 
      prom_write_en <= '0';
      write_fifo_write_en <= '0';
      cmd_fifo_read_en <= '0';
      if (write_done='1') then
        cmd_fifo_state <= S_IDLE;
      else 
        cmd_fifo_state <= S_WRITE_WAIT;
      end if;
      
    when S_LOAD_ADDR_STALL => 
      --need to wait because empty takes an extra cycle to go low
      cmd_fifo_read_en <= '0';
      cmd_fifo_state <= S_LOAD_ADDR_LOWER;
            
    when S_LOAD_ADDR_LOWER =>
      if (cmd_fifo_empty='0') then
        cmd_fifo_read_en <= '1';
        prom_addr(15 downto 0) <= cmd_fifo_out;
        prom_load_addr <= '1';
        cmd_fifo_state <= S_LOAD_ADDR_STALL_2;
      else
        cmd_fifo_read_en <= '0';     
        cmd_fifo_state <= S_LOAD_ADDR_LOWER;
      end if;
      
    when S_LOAD_ADDR_STALL_2 =>
      --need to wait because empty takes an extra cycle to go low
      cmd_fifo_read_en <= '0';
      cmd_fifo_state <= S_IDLE;
    
    when others =>
      --unimplemented state
      cmd_fifo_read_en <= '0';
      cmd_fifo_state <= S_IDLE;
    end case;
  end if;
  end process;
  
  
--  --readback FIFO and controlling FSM
--  process_read : process (CLK40)
--  begin
--  if rising_edge(CLK40) then
--    case rd_fifo_state is
--      when S_FIFOIDLE =>
--        wr_dvalid_cnt <= x"00000000";
--        load_rd_fifo <= '0';
--        if (prom_read_en = '1') then
--          rd_fifo_state <= S_FIFOWRITE_PRE;
--	    else
--          rd_fifo_state <= S_FIFOIDLE;
--        end if;
--      when S_FIFOWRITE_PRE =>
--        wr_dvalid_cnt <= x"00000000";
--        load_rd_fifo <= '1';
--        rd_fifo_state <= S_FIFOWRITE;
--      when S_FIFOWRITE =>
--        if (read_done = '1') then
--          rd_fifo_state <= S_FIFOIDLE;
--          load_rd_fifo <= '0';
--          wr_dvalid_cnt <= x"00000000";
--	    else
--          if (rd_data_valid = '1') then
--            wr_dvalid_cnt <= wr_dvalid_cnt + 1;
--	      else 
--            wr_dvalid_cnt <= wr_dvalid_cnt;
--          end if;
--          load_rd_fifo <= '1';
--          rd_fifo_state <= S_FIFOWRITE;
--        end if;
--    end case;
--  end if;
--  end process;

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
        full => open,
        empty => open,
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
    ------------------ Read output
    OUT_READ_DATA           => spi_readdata,
    OUT_READ_DATA_VALID     => readback_fifo_wr_en,
    ------------------ Debug
    DIAGOUT                 => DIAGOUT
    );
    
  --read busy signal
  READ_BUSY <= not read_done;
    
  --debug
  --DIAGOUT(10 downto 3) <= spi_readdata(7 downto 0);
  --DIAGOUT(11) <= cmd_fifo_empty;
  --DIAGOUT(12) <= '0';
  --DIAGOUT(13) <= load_rd_fifo;
  --DIAGOUT(14) <= readback_fifo_wr_en;
  --DIAGOUT(15) <= READBACK_FIFO_READ_EN;
  --DIAGOUT(16) <= '0';
  --DIAGOUT(17) <= prom_write_en;
  
end SPI_CTRL_Arch;
