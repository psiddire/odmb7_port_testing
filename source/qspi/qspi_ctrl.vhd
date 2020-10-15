library ieee;
library work;
library unisim;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;
use unisim.vcomponents.all;

entity QSPI_CTRL is
  port (
    
    CLK40   : in std_logic;
    RST     : in std_logic;

    START_READ : in std_logic;
    START_INFO : in std_logic; --pulse to load startaddr, sectorcount, and pagecount
    START_WRITE : in std_logic; --pulse to write data to PROM
    START_ERASE : in std_logic;
    START_READ_FIFO : in std_logic; --pulse to read one word from FIFO
    
    CMD_INDEX : in std_logic_vector(3 downto 0);
    READ_ADDR : in std_logic_vector(31 downto 0);
    WD_LIMIT : in std_logic_vector(31 downto 0);
    STARTADDR : in std_logic_vector(31 downto 0);
    PAGECOUNT : in std_logic_vector(16 downto 0);
    SECTORCOUNT : in std_logic_vector(13 downto 0);

    WRITE_FIFO_IN : in std_logic_vector(15 downto 0);
    WRITE_FIFO_EN : in std_Logic;
    FIFO_OUT : out std_logic_vector(15 downto 0);
    
    DIAGOUT : out std_logic_vector(17 downto 0)

    );
end QSPI_CTRL;


architecture QSPI_CTRL_Arch of QSPI_CTRL is

  component spiflashprogrammer_test is
  port
  (
    Clk         : in std_logic; -- untouch
    fifoclk     : in std_logic; -- TODO, make it 6MHz as in example, or use the same as spiclk
    ------------------------------------
    data_to_fifo : in std_logic_vector(31 downto 0); -- until sectorcountvalid, all hardcoded
    startaddr   : in std_logic_vector(31 downto 0);
    startaddrvalid   : in std_logic;
    pagecount   : in std_logic_vector(16 downto 0);
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
    write      : in std_logic;
    erase     : in std_logic; 
    eraseing     : out std_logic; 
    erasedone     : out std_logic; 
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
    out_wrfifo_rden: out std_logic;
    out_wr_status : out std_logic_vector(3 downto 0);
    out_fifo_rden : out std_logic;
    out_fifodout : out std_logic_vector(63 downto 0)
  ); 
  end component spiflashprogrammer_test;

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

  --when START_INFO received, turn on startaddrvalid, sectorcountvalid, and pagecountvalid for 10 clock cycles
  process_info : process(CLK40)
  begin
  if (rising_edge(CLK40)) then
    if (start_info_en = '0') then
      startaddrvalid <= '0';
      sectorcountvalid <= '0';
      pagecountvalid <= '0';
      load_bit_cntr <= 0;
      if (START_INFO = '1') then
        start_info_en <= '1';
      else
	start_info_en <= '0';
      end if;
    else
      if (load_bit_cntr < 10) then
        startaddrvalid <= '1';
        sectorcountvalid <= '1';
        pagecountvalid <= '1';
        start_info_en <= '1';
        load_bit_cntr <= load_bit_cntr + 1;
      else
        startaddrvalid <= '0';
        sectorcountvalid <= '0';
        pagecountvalid <= '0';
        start_info_en <= '0';
        load_bit_cntr <= 0;
      end if;
    end if;
  end if;
  end process;

  --when WRITE_FIFO_EN is pulsed, write to input fifo
  write_fifo_en_q <= WRITE_FIFO_EN when rising_edge(CLK40) else write_fifo_en_q;
  write_fifo_en_pulse <= WRITE_FIFO_EN and not write_fifo_en_q;
  spi_write_fifo_i : spi_readback_fifo
     PORT MAP (
        srst => RST,
        wr_clk => CLK40,
        rd_clk => CLK40,
        din => WRITE_FIFO_IN,
        wr_en => write_fifo_en_pulse,
        rd_en => write_fifo_rd_en,
        dout => write_fifo_out,
        full => open,
        empty => open,
        --prog_full => rd_fifo_prog_full,
        wr_rst_busy => open,
        rd_rst_busy => open
      );
  

  --when START_WRITE received, start writing from FIFO
  start_write_q <= START_WRITE when rising_edge(CLK40) else start_write_q;
  start_write_pulse <= START_WRITE and not start_write_q;
  process_write : process (CLK40)
  begin
  if (rising_edge(CLK40)) then
    case wr_prom_state is
    when S_IDLE =>
      fifo_wren <= '0';
      load_data_cntr <= x"00000000";
      write_data <= write_data;
      write_fifo_rd_en <= '0';
      start_write_prom_pulse <= '0';
      if (start_write_pulse = '1') then
        wr_prom_state <= S_WAIT_ERASE;
      else
        wr_prom_state <= S_IDLE;
      end if;
    when S_WAIT_ERASE =>
      fifo_wren <= '0';
      load_data_cntr <= load_data_cntr;
      write_data <= write_data;
      write_fifo_rd_en <= '0';
      start_write_prom_pulse <= start_write_prom_pulse;
      if (erasedone = '1') then
        wr_prom_state <= S_READ_LOWER;
      else
        wr_prom_state <= S_WAIT_ERASE;
      end if;
    when S_READ_LOWER =>
      fifo_wren <= '0';
      load_data_cntr <= load_data_cntr;
      write_data <= write_data(31 downto 16) & write_fifo_out;
      write_fifo_rd_en <= '1';
      start_write_prom_pulse <= start_write_prom_pulse;
      wr_prom_state <= S_READ_UPPER;
    when S_READ_UPPER =>
      fifo_wren <= '1';
      write_data <= write_fifo_out & write_data(15 downto 0);
      write_fifo_rd_en <= '1';
      --write at least 1 page for something to happen?
      if (load_data_cntr = x"80") then
        load_data_cntr <= x"00000000";
        start_write_prom_pulse <= '1';
        wr_prom_state <= S_IDLE;
      else
        load_data_cntr <= load_data_cntr + 1;
        start_write_prom_pulse <= start_write_prom_pulse;
        wr_prom_state <= S_READ_LOWER;
      end if;      
    end case;
  end if;
  end process;

  --when controller_read_start received from QSPI wrapper, read a word to FIFO
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
        if (wr_dvalid_cnt = unsigned(WD_LIMIT)) then
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

  --readback FIFO
  readback_fifo_wr_en <= '1' when (rd_data_valid = '1' and load_rd_fifo = '1') else '0';
  start_read_fifo_q <= START_READ_FIFO when rising_edge(CLK40);
  readback_fifo_rd_en <= START_READ_FIFO and not start_read_fifo_q;
  spi_readback_fifo_i : spi_readback_fifo
      PORT MAP (
        srst => RST,
        wr_clk => CLK40,
        rd_clk => CLK40,
        din => spi_readdata,
        wr_en => readback_fifo_wr_en,
        rd_en => readback_fifo_rd_en,
        dout => FIFO_OUT,
        full => open,
        empty => open,
        --prog_full => rd_fifo_prog_full,
        wr_rst_busy => readback_fifo_wr_rst_busy,
        rd_rst_busy => readback_fifo_rd_rst_busy
      );

  --handle START_READ and START_ERASE
  start_read_q <= START_READ when rising_edge(CLK40);
  start_read_pulse <= start_read and not start_read_q;
  start_erase_q <= START_ERASE when rising_edge(CLK40);
  start_erase_pulse <= start_erase and not start_erase_q;

  spiflashprogrammer_inst: spiflashprogrammer_test port map
  (
    clk => CLK40,
    fifoclk => CLK40, --drck,
    data_to_fifo => write_data,
    startaddr => STARTADDR,
    startaddrvalid => startaddrvalid,
    pagecount => PAGECOUNT,
    pagecountvalid => pagecountvalid,
    sectorcount => SECTORCOUNT,
    sectorcountvalid => sectorcountvalid,
    fifowren => fifo_wren,
    fifofull => open,
    fifoempty => open,
    fifoafull => open,
    fifowrerr => open,
    fiforderr => open,
    writedone => open,
    reset => RST,
    read => start_read_pulse,
    write => start_write_prom_pulse,
    eraseing => DIAGOUT(8),
    erasedone => erasedone,
    erase => start_erase_pulse,
    startwrite => open,
    out_read_inprogress => DIAGOUT(9),
    out_rd_SpiCsB => open,
    out_SpiCsB_N => DIAGOUT(0),
    out_read_start => controller_read_start,
    out_SpiMosi => DIAGOUT(1),
    out_SpiMiso => DIAGOUT(2),
    out_CmdSelect => open,
    in_CmdIndex => CMD_INDEX,
    in_rdAddr => READ_ADDR,
    in_wdlimit => WD_LIMIT,
    out_SpiCsB_FFDin => open,
    out_rd_data_valid_cntr => open,
    out_rd_data_valid => rd_data_valid,
    out_nword_cntr => open,
    out_cmdreg32 => open,
    out_cmdcntr32 => open,
    out_rd_rddata => spi_readdata,
    out_rd_rddata_all => open,
    out_er_status => open,
    out_wrfifo_rden => open,
    out_wr_status => DIAGOUT(7 downto 4),
    out_fifo_rden => open,
    out_fifodout => fifodout_inner
    );
    
  --debug
  DIAGOUT(17 downto 10) <= fifodout_inner(7 downto 0);
  
  DIAGOUT(3) <= fifo_wren;
  
end QSPI_CTRL_Arch;
