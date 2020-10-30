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
    
    DIAGOUT : out std_logic_vector(17 downto 0)

    );
end SPI_CTRL;


architecture SPI_CTRL_Arch of SPI_CTRL is

  component spiflashprogrammer_test is
  port
  (
    Clk         : in std_logic; -- untouch
    fifoclk     : in std_logic; -- TODO, make it 6MHz as in example, or use the same as spiclk
    ------------------------------------
    data_to_fifo : in std_logic_vector(15 downto 0); -- until sectorcountvalid, all hardcoded
    startaddr   : in std_logic_vector(31 downto 0);
    startaddrvalid   : in std_logic;
    pagecount   : in std_logic_vector(17 downto 0);
    pagecountvalid   : in std_logic;
    sectorcount : in std_logic_vector(13 downto 0);
    sectorcountvalid : in std_logic;
    ------------------------------------
    fifowren    : in Std_logic;
    fifofull    : out std_logic;
    fifoempty   : out std_logic;
    fifoafull   : out std_logic;
    fifowrerr   : out std_logic;
    fiforderr   : out std_logic;
    writedone   : out std_logic;
    ------------------------------------
    reset       : in  std_logic;
    read       : in std_logic;
    readdone   : out std_logic;
    write      : in std_logic;
    erase     : in std_logic; 
    eraseing     : out std_logic; 
    erasedone     : out std_logic; 
    ------------------------------------
    write_nwords : in unsigned(11 downto 0);
    ------------------------------------
    startwrite : out std_logic;
    out_read_inprogress : out std_logic;
    out_rd_SpiCsB: out std_logic;
    out_SpiCsB_N: out std_logic;
    out_read_start: out std_logic;
    out_SpiMosi: out std_logic;
    out_SpiMiso: out std_logic;
    out_CmdSelect: out std_logic_vector(7 downto 0);
    in_CmdIndex: in std_logic_vector(3 downto 0);
    in_rdAddr: in std_logic_vector(31 downto 0);
    in_wdlimit: in std_logic_vector(31 downto 0);
    out_SpiCsB_FFDin: out std_logic;
    out_rd_data_valid_cntr: out std_logic_vector(3 downto 0);
    out_rd_data_valid: out std_logic;
    out_nword_cntr: out std_logic_vector(31 downto 0);
    out_cmdreg32: out std_logic_vector(39 downto 0);
    out_cmdcntr32: out std_logic_vector(5 downto 0);
    out_rd_rddata: out std_logic_vector(15 downto 0);
    out_rd_rddata_all: out std_logic_vector(15 downto 0);
    out_er_status: out std_logic_vector(1 downto 0);
    out_wr_statusdatavalid: out std_logic;
    out_wr_spistatus: out std_logic_vector(1 downto 0);
    out_wrfifo_dout: out std_logic_vector(3 downto 0);
    out_wrfifo_rden: out std_logic
  ); 
  end component spiflashprogrammer_test;
  
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
  signal read_nwords : std_logic_vector(31 downto 0) := (others => '0');
  type cmd_fifo_states is (S_IDLE, S_LOAD_ADDR_STALL, S_LOAD_ADDR_LOWER, S_READ_LOW, S_READ_WAIT, S_WRITE_STALL, S_WRITE_WORD, S_WRITE_LOW, S_WRITE_WAIT, S_ERASE_LOW, S_ERASE_WAIT);
  signal cmd_fifo_state : cmd_fifo_states := S_IDLE;
  signal write_word_counter : unsigned(11 downto 0) := (others => '0');
  
  signal program_nwords : unsigned(11 downto 0) := (others => '0');
  signal write_fifo_write_en : std_logic := '0';
  signal prom_read_en, prom_erase_en, prom_write_en : std_logic := '0';
  signal read_done, erase_done, write_done : std_logic := '0';

  --INFO signals
  signal start_info_en : std_logic := '0';
  signal load_bit_cntr : integer range 0 to 10 := 0;
  signal startaddrvalid : std_logic := '0';
  signal sectorcountvalid : std_logic := '0';
  signal pagecountvalid : std_logic := '0';

  --WRITE FIFO signals
  signal write_fifo_en_q, write_fifo_en_pulse : std_logic := '0';
  signal write_fifo_rd_en : std_logic := '0';
  signal write_fifo_out : std_logic_vector(15 downto 0) := (others => '0');

  --WRITE signals
  signal start_write_q, start_write_pulse : std_logic := '0';
  signal start_write_en : std_logic := '0';
  signal fifo_wren : std_logic := '0';
  signal load_data_cntr : unsigned(31 downto 0) := x"00000000";
  type wr_prom_states is (S_IDLE, S_WAIT_ERASE, S_READ_LOWER, S_READ_UPPER);
  signal wr_prom_state : wr_prom_states := S_IDLE;
  signal write_data : std_logic_vector(31 downto 0) := x"00000000";
  signal erasedone : std_logic := '0';
  signal start_write_prom_pulse : std_logic := '0';

  --READ signals
  signal wr_dvalid_cnt : unsigned(31 downto 0) := x"00000000";
  signal load_rd_fifo : std_logic := '0';
  signal controller_read_start : std_logic := '0';
  type rd_fifo_states is (S_FIFOIDLE, S_FIFOWRITE_PRE, S_FIFOWRITE);
  signal rd_fifo_state : rd_fifo_states := S_FIFOIDLE;
  
  --READ FIFO and ERASE signals
  signal start_read_q, start_read_pulse, start_erase_q, start_erase_pulse : std_logic := '0';

  --read FIFO signals
  signal readback_fifo_wr_en : std_logic := '0';
  signal start_read_fifo_q : std_logic := '0';
  signal readback_fifo_rd_en : std_logic := '0';
  signal rd_data_valid : std_logic := '0';
  signal spi_readdata : std_logic_vector(15 downto 0) := x"0000";
  signal readback_fifo_wr_rst_busy, readback_fifo_rd_rst_busy : std_logic := '0';
  
  --debug
  signal fifodout_inner : std_logic_vector(63 downto 0);

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
  process_cmd_fifo : process(CLK40)
  begin
  if (rising_edge(CLK40)) then
    case cmd_fifo_state is
    
    when S_IDLE =>
      prom_load_addr <= '0';
      if (cmd_fifo_empty='0') then
        --command to be processed, interpret OPCODE
        cmd_fifo_read_en <= '1';
        case "000" & cmd_fifo_out(4 downto 0) is
        when x"04" =>
          --read n
          read_nwords <= x"00000" & "0" & cmd_fifo_out(15 downto 5);
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
          cmd_fifo_state <= S_WRITE_LOW;
        else
          write_word_counter <= write_word_counter + 1;
          cmd_fifo_state <= S_WRITE_STALL;
        end if;
      else
        cmd_fifo_read_en <= '0';
        write_word_counter <= write_word_counter;
        cmd_fifo_state <= S_WRITE_WORD;
      end if;
      
    when S_WRITE_LOW => 
      prom_write_en <= '0';
      cmd_fifo_read_en <= '0';
      cmd_fifo_state <= S_WRITE_WAIT;
      
    when S_WRITE_WAIT => 
      write_fifo_write_en <= '0';
      if (write_done='1') then
        cmd_fifo_state <= S_IDLE;
      else 
        cmd_fifo_state <= S_WRITE_WAIT;
      end if;
      
    when S_LOAD_ADDR_STALL => 
      --need to wait because empty takes an extra cycle to go low?
      cmd_fifo_read_en <= '0';
      cmd_fifo_state <= S_LOAD_ADDR_LOWER;
            
    when S_LOAD_ADDR_LOWER =>
      if (cmd_fifo_empty='0') then
        cmd_fifo_read_en <= '1';
        prom_addr(15 downto 0) <= cmd_fifo_out;
        prom_load_addr <= '1';
        cmd_fifo_state <= S_IDLE;
      else
        cmd_fifo_read_en <= '0';     
        cmd_fifo_state <= S_LOAD_ADDR_LOWER;
      end if;
    
    when others =>
      --unimplemented state
      cmd_fifo_read_en <= '0';
      cmd_fifo_state <= S_IDLE;
    end case;
  end if;
  end process;
  
  
  --readback FIFO and controlling FSM
  --when controller_read_start received from SPI wrapper, read a word to FIFO
  process_read : process (CLK40)
  begin
  if rising_edge(CLK40) then
    case rd_fifo_state is
      when S_FIFOIDLE =>
        wr_dvalid_cnt <= x"00000000";
        load_rd_fifo <= '0';
        if (controller_read_start = '1') then
          rd_fifo_state <= S_FIFOWRITE_PRE;
	    else
          rd_fifo_state <= S_FIFOIDLE;
        end if;
      when S_FIFOWRITE_PRE =>
        wr_dvalid_cnt <= x"00000000";
        load_rd_fifo <= '1';
        rd_fifo_state <= S_FIFOWRITE;
      when S_FIFOWRITE =>
        if (wr_dvalid_cnt = unsigned(read_nwords)) then
          rd_fifo_state <= S_FIFOIDLE;
          load_rd_fifo <= '0';
          wr_dvalid_cnt <= x"00000000";
	    else
          if (rd_data_valid = '1') then
            wr_dvalid_cnt <= wr_dvalid_cnt + 1;
	      else 
            wr_dvalid_cnt <= wr_dvalid_cnt;
          end if;
          load_rd_fifo <= '1';
          rd_fifo_state <= S_FIFOWRITE;
        end if;
    end case;
  end if;
  end process;

  readback_fifo_wr_en <= '1' when (rd_data_valid = '1' and load_rd_fifo = '1') else '0';
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

  spiflashprogrammer_inst: spiflashprogrammer_test port map
  (
    clk => CLK40,
    fifoclk => CLK40, --drck,
    data_to_fifo => cmd_fifo_out,
    startaddr => prom_addr,
    startaddrvalid => prom_load_addr,
    pagecount => temp_pagecount,
    pagecountvalid => prom_load_addr,
    sectorcount => temp_sectorcount,
    sectorcountvalid => prom_load_addr,
    fifowren => write_fifo_write_en,
    fifofull => open,
    fifoempty => open,
    fifoafull => open,
    fifowrerr => open,
    fiforderr => open,
    writedone => write_done,
    reset => RST,
    read => prom_read_en,
    readdone => read_done,
    write => prom_write_en,
    eraseing => open,
    erasedone => erase_done,
    erase => prom_erase_en,
    startwrite => open,
    write_nwords => program_nwords,
    out_read_inprogress => open,
    out_rd_SpiCsB => open,
    out_SpiCsB_N => DIAGOUT(2),
    out_read_start => controller_read_start,
    out_SpiMosi => DIAGOUT(1),
    out_SpiMiso => DIAGOUT(0),
    out_CmdSelect => open,
    in_CmdIndex => temp_cmdindex,
    in_rdAddr => x"00000000",
    in_wdlimit => read_nwords,
    out_SpiCsB_FFDin => open,
    out_rd_data_valid_cntr => open,
    out_rd_data_valid => rd_data_valid,
    out_nword_cntr => open,
    out_cmdreg32 => open,
    out_cmdcntr32 => open,
    out_rd_rddata => spi_readdata,
    out_rd_rddata_all => open,
    out_er_status => open,
    out_wr_statusdatavalid => open,
    out_wr_spistatus => open,
    out_wrfifo_dout => open,
    out_wrfifo_rden => open
    );
    
  --debug
  DIAGOUT(10 downto 3) <= read_nwords(11 downto 4);
  DIAGOUT(11) <= cmd_fifo_empty;
  DIAGOUT(12) <= controller_read_start;
  DIAGOUT(13) <= prom_read_en;
  DIAGOUT(14) <= prom_read_en;
  DIAGOUT(15) <= READBACK_FIFO_READ_EN;
  DIAGOUT(16) <= write_fifo_rd_en;
  DIAGOUT(17) <= prom_write_en;
  
end SPI_CTRL_Arch;
