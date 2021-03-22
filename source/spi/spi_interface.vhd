------------------------------------------------------------------------
--   This module provides an interface for SPI communication with
--   an EPROM. It uses the Xilinx STARTUPE3 module to output 
--   to the normal data, clock, and chip select lines and contains
--   processes to generate the appropriate commands.
--
------------------------------------------------------------------------

library ieee;
Library UNISIM;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use UNISIM.vcomponents.all;
use work.ucsb_types.all;

entity spi_interface is
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
end spi_interface;

architecture behavioral of spi_interface is
  attribute mark_debug : string;
  attribute dont_touch : string;
  attribute keep : string;
  attribute shreg_extract : string;
  attribute async_reg     : string;

component oneshot is
port (
  trigger: in  std_logic;
  clk : in std_logic;
  pulse: out std_logic
);
end component oneshot;
 
COMPONENT writeSpiFIFO
  PORT (
      srst : IN STD_LOGIC;
      wr_clk : IN STD_LOGIC;
      rd_clk : IN STD_LOGIC;
      din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      wr_en : IN STD_LOGIC;
      rd_en : IN STD_LOGIC;
      dout : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
      full : OUT STD_LOGIC;
      empty : OUT STD_LOGIC;
      prog_full : OUT STD_LOGIC;
      wr_rst_busy : OUT STD_LOGIC;
      rd_rst_busy : OUT STD_LOGIC
        );
END COMPONENT;

  -- SPI COMMAND ADDRESS WIDTH (IN BITS): Ensure setting is correct for the target flash
  constant  AddrWidth        : integer   := 32;  -- 24 or 32 (3 or 4 byte addr mode)
  -- SPI SECTOR SIZE (IN Bits)
  constant  SectorSize       : integer := 65536; -- 64K bits
  constant  SizeSector       : std_logic_vector(31 downto 0) := X"00010000"; -- 65536 bits
  constant  SubSectorSize    : integer := 4096; -- 4K bits
  constant  SizeSubSector    : std_logic_vector(31 downto 0) := X"00001000"; -- 4K bits
  constant  NumberofSectors  : std_logic_vector(8 downto 0) := "000000000";  -- 512 Sectors total
  constant  PageSize         : std_logic_vector(31 downto 0) := X"00000100"; -- 
  constant  NumberofPages    : std_logic_vector(16 downto 0) := "10000000000000000"; -- 256 bytes pages = 20000h
  constant  AddrStart32      : std_logic_vector(31 downto 0) := X"00000000"; -- First address in SPI
  constant  AddrEnd32        : std_logic_vector(31 downto 0) := X"01FFFFFF"; -- Last address in SPI (256Mb)
  -- SPI flash information
  constant  Idcode25NQ256    : std_logic_vector(23 downto 0) := X"20BB19";  -- RDID N256Q 256 MB
  
  -- Device command opcodes
  constant  CmdREAD24        : std_logic_vector(7 downto 0)  := X"03";
  constant  CmdFASTREAD      : std_logic_vector(7 downto 0)  := X"0B";
  constant  CmdREAD32        : std_logic_vector(7 downto 0)  := X"13";
  constant  CmdRDID          : std_logic_vector(7 downto 0)  := X"9F";
  constant  CmdRDFlashPara   : std_logic_vector(7 downto 0)  := X"5A";
  constant  CmdRDFR24Quad    : std_logic_vector(7 downto 0)  := X"0C";
  constant  CmdFLAGStatus    : std_logic_vector(7 downto 0)  := X"70";
  constant  CmdStatus        : std_logic_vector(7 downto 0)  := X"05";
  constant  CmdWE            : std_logic_vector(7 downto 0)  := X"06";
  constant  CmdSE24          : std_logic_vector(7 downto 0)  := X"D8";
  constant  CmdSE32          : std_logic_vector(7 downto 0)  := X"DC";
  constant  CmdSSE24         : std_logic_vector(7 downto 0)  := X"20";
  constant  CmdSSE32         : std_logic_vector(7 downto 0)  := X"21";
  constant  CmdPP24          : std_logic_vector(7 downto 0)  := X"02";
  constant  CmdPP32          : std_logic_vector(7 downto 0)  := X"12";
  constant  CmdPP24Quad      : std_logic_vector(7 downto 0)  := X"32"; 
  constant  CmdPP32Quad      : std_logic_vector(7 downto 0)  := X"34"; 
  constant  Cmd4BMode        : std_logic_vector(7 downto 0)  := X"B7";
  constant  CmdExit4BMode    : std_logic_vector(7 downto 0)  := X"E9";

  ------------- STARTUPE3/SPI signals -------------------- 
  signal spi_miso         : std_logic;
  signal spi_mosi         : std_logic;
  signal spi_cs_bar       : std_logic;
  signal spi_cs_bar_input : std_logic := '1';
  signal spi_cs_bar_delay : std_logic := '1';
  signal di_out           : std_logic_vector(3 downto 0) := X"0";
  signal do_in            : std_logic_vector(3 downto 0) := "0000";
  signal qspi_io          : std_logic_vector(3 downto 1) := "111";
  signal dopin_ts         : std_logic_vector(3 downto 0) := "1110";
  
  ------------- Write FIFO signals -------------------- 
  signal write_fifo_output        : std_logic_vector(3 downto 0) := "0000";
  signal write_fifo_read_enable       : std_logic := '0';

  ------------- Read signals -------------------- 
  signal read_spi_cs_bar         : std_logic := '1';
  signal read_done               : std_logic := '1';
  signal read_word_limit         : unsigned(31 downto 0) := x"00000000";
  signal read_word_counter       : unsigned(31 downto 0) := x"00000000";
  signal read_data               : std_logic_vector(15 downto 0) := X"0000";
  signal read_data_valid         : std_logic := '0';
  signal read_data_counter       : std_logic_vector(3 downto 0) := "0000";
  signal read_address            : std_logic_vector(31 downto 0) := X"00000000";
  signal read_cmdcounter         : unsigned(5 downto 0) := "111111";
  signal read_cmdreg             : std_logic_vector(39 downto 0) := X"1111111111";

  ------------- Erase signals -------------------- 
  signal erase_spi_cs_bar       : std_logic := '1';
  signal erase_done             : std_logic := '1';
  signal erase_address          : std_logic_vector(31 downto 0) := x"00000000";
  signal erase_cmdcounter       : unsigned(5 downto 0) := "111111";
  signal erase_cmdreg           : std_logic_vector(39 downto 0) := x"1111111111";
  signal erase_status_bit_index : std_logic_vector(7 downto 0) := x"00";

  ------------- Write signals -------------------- 
  signal write_spi_cs_bar       : std_logic := '1';
  signal write_done             : std_logic := '1';
  signal write_address          : std_logic_vector(31 downto 0) := x"00000000";
  signal write_cmdcounter       : unsigned(5 downto 0) := "111111";
  signal write_cmdreg           : std_logic_vector(39 downto 0) := x"1111111111";
  signal write_word_limit       : unsigned(31 downto 0) := x"00000000";
  signal write_data_counter     : unsigned(1 downto 0) := "00";
  signal write_word_counter     : unsigned(31 downto 0) := x"00000000";
  signal write_status_bit_index : std_logic_vector(7 downto 0) := x"00";

  --------------- select read command and address -------------------- 
  --signal CmdIndex    : std_logic_vector(3 downto 0) := "0001";  
  --signal CmdSelect    : std_logic_vector(7 downto 0) := x"FF";  
  --signal AddSelect: std_logic_vector(31 downto 0) := x"00000000";  -- 32 bit command/addr
  --------------- other signals/regs/counters  ------------------------
  --signal data_valid_cntr : std_logic_vector(2 downto 0) := "000";
  --signal rddata          : std_logic_vector(1 downto 0) := "00";
  --signal spi_wrdata      : std_logic_vector(31 downto 0) := X"00000000";
  --signal page_count      : std_logic_vector(17 downto 0) := "111111111111111111";
  --signal StatusDataValid : std_logic := '0';
  --   ------- erase ----------------------------
  --signal er_sector_count          : std_logic_vector(13 downto 0) := "00000000000001";    -- subsector count
  --signal erase_address   : std_logic_vector(31 downto 0) := X"00000000"; -- start addr of current sector
  --signal erase_start     : std_logic := '0';
  --signal er_data_valid_cntr       : std_logic_vector(2 downto 0) := "000";
  --signal er_rddata       : std_logic_vector(1 downto 0) := "00";
  --signal er_status       : std_logic_vector(1 downto 0) := "11";
  --signal erase_inprogress: std_logic := '0';
  ------------- FIFO signals  ---------------------
  --signal fifo_empty      : std_logic := '0';
  --signal fifo_full       : std_logic := '0';
  --signal fifo_almostfull : std_logic := '0';
  --signal fifo_almostempty : std_logic := '0';
  --signal fifo_unconned   : std_logic_vector(15 downto 0) := X"0000";
  ------- Misc signal
  --signal reset_design    : std_logic := '0';
  --signal wrerr           : std_logic := '0';
  --signal rderr           : std_logic := '0';
  ----  syncers
  ----  place sync regs close together and no SRLs
  --signal synced_fifo_almostfull : std_logic_vector(1 downto 0) := "00";
  --  attribute keep of synced_fifo_almostfull : signal is "true";
  --  attribute async_reg of synced_fifo_almostfull : signal is "true";   
  --  attribute shreg_extract of synced_fifo_almostfull : signal is "no";

  --signal synced_read : std_logic_vector(1 downto 0) := "00";
  --  attribute keep of synced_read : signal is "true";
  --  attribute async_reg of synced_read : signal is "true";   
  --  attribute shreg_extract of synced_read : signal is "no";

  --signal synced_erase : std_logic_vector(1 downto 0) := "00";
  --  attribute keep of synced_erase : signal is "true";
  --  attribute async_reg of synced_erase : signal is "true";   
  --  attribute shreg_extract of synced_erase : signal is "no";

  type write_states is
  (
    S_WRITE_IDLE, S_WRITE_ASSERT_CS_WRITE_ENABLE, S_WRITE_SHIFT_WRITE_ENABLE,  S_WRITE_ASSERT_CS_PROGRAM,
    S_WRITE_SHIFT_PROGRAM, S_WRITE_SHIFT_DATA, S_WRITE_ASSERT_CS_READ_STATUS, S_WRITE_SHIFT_READ_STATUS,
    S_WRITE_ASSERT_CS_READ_STATUS_2, S_WRITE_SHIFT_READ_STATUS_2
  );
  signal write_state  : write_states := S_WRITE_IDLE;

  type read_states is
  (
    S_READ_IDLE, S_READ_ASSERT_CS, S_READ_SHIFT_READ
  );
  signal read_state : read_states := S_READ_IDLE;
  
  type erase_states is
  (
    S_ERASE_IDLE, S_ERASE_ASSERT_CS_WRITE_ENABLE, S_ERASE_SHIFT_WRITE_ENABLE, S_ERASE_ASSERT_CS_ERASE,
    S_ERASE_SHIFT_ERASE, S_ERASE_ASSERT_CS_READ_STATUS, S_ERASE_SHIFT_READ_STATUS
  );
  signal erase_state  : erase_states := S_ERASE_IDLE;

 begin

  STARTUPE3_inst : STARTUPE3
  port map (
          CFGCLK => open,
          CFGMCLK => open,
          EOS => open,
          DI => di_out,  -- inspi_miso D01 pin to Fabric
          PREQ => open,
          -- End outputs to fabric ports
          DO => do_in,
          DTS => dopin_ts,
          FCSBO => spi_cs_bar,
          FCSBTS =>  '0',
          GSR => '0',
          GTS => '0',
          KEYCLEARB => '1',
          PACK => '1',
          USRCCLKO => CLK,
          USRCCLKTS => '0',  -- Clk_ts,
          USRDONEO => '1',
          USRDONETS => '0'    
  );
  
  do_in <= qspi_io(3 downto 1) & spi_mosi;
  spi_miso <= di_out(1);
  
  qspi_io(3 downto 1) <= write_fifo_output(3 downto 1) when rising_edge(CLK);
  spi_cs_bar <= spi_cs_bar_input when falling_edge(CLK); --update spi_cs_bar on falling edges
  
  mux_mosi : process(CLK)
  begin
    if rising_edge(CLK) then
      if (read_done = '0') then spi_mosi <= read_cmdreg(39);
      elsif (erase_done = '0') then spi_mosi <= erase_cmdreg(39);
      else 
        case write_state is
          when S_WRITE_SHIFT_DATA =>
            spi_mosi <= write_fifo_output(0);
          when others =>
            spi_mosi <= write_cmdreg(39);
        end case;
      end if;
    end if; --CLK
  end process mux_mosi;

  
  mux_cs_bar: process (CLK)
  begin
    if rising_edge(CLK) then
      if (read_done = '0') then spi_cs_bar_input <= read_spi_cs_bar;
      elsif (erase_done = '0') then spi_cs_bar_input <= erase_spi_cs_bar;
      else spi_cs_bar_input <= write_spi_cs_bar;
      end if;
    end if; --CLK
  end process mux_cs_bar;

-----------------------------  program word FIFO  --------------------------------------------------

writeFIFO_i : writeSpiFIFO
  PORT MAP (
    srst => RST,
    wr_clk => CLK,
    rd_clk => CLK,
    din => WRITE_FIFO_INPUT,
    wr_en => WRITE_FIFO_WRITE_ENABLE,
    rd_en => write_fifo_read_enable,
    dout => write_fifo_output,
    full => open,
    empty => open,
    prog_full => open,
    wr_rst_busy => open,
    rd_rst_busy => open 
  );

-----------------------------  pass output signals  --------------------------------------------------
--    readdone                <= read_done;
--    out_read_spi_cs_bar           <= read_spi_cs_bar;
--    out_spi_cs_bar            <= spi_cs_b; 
--    out_spi_mosi             <= spi_mosi; 
--    out_spi_miso             <= spi_miso; 
--    out_CmdSelect          <= CmdSelect;
--    out_spi_cs_bar_input        <= spi_cs_bar_input; 
--    --out_read_data_counter <= read_data_counter;
--    out_read_data_counter(2 downto 0) <= er_data_valid_cntr;
--    out_cmdreg <= cmdreg;
--    out_cmdcntr32 <= read_cmdcounter;
--
--    out_wrwrite_fifo_read_enable <= write_fifo_read_enable;
--
--    out_wr_statusdatavalid <= StatusDataValid;
--    out_wr_rddata <= rddata;
--    out_wr_spistatus <= spi_status; 

OUT_READ_DATA <= read_data;
OUT_READ_DATA_VALID <= read_data_valid;
OUT_READ_DONE <= read_done;
OUT_ERASE_DONE <= erase_done;
OUT_WRITE_DONE <= write_done;

---------------------------------  PROM READ FSM  ----------------------------------------------
--CmdSelect <= CmdStatus when CmdIndex = x"1" else
--             CmdRDID   when CmdIndex = x"2" else
--             CmdRDFlashPara   when CmdIndex = x"3" else
--             --CmdRDFR24Quad  when CmdIndex = x"4" else
--             CmdFASTREAD    when CmdIndex = x"4" else
--             x"FF";

process_read : process (CLK)
  begin
  if rising_edge(CLK) then
  case read_state is 
   when S_READ_IDLE =>
        --when START_READ received, initiate read process
        read_spi_cs_bar <= '1';
        if (START_ADDRESS_VALID = '1') then read_address <= START_ADDRESS(23 downto 0) & x"00"; end if; --currently 3-byte addressing
        if (START_READ = '1') then 
          read_data_counter <= "0000";
          read_word_limit(31 downto 0) <= (x"00000" & READ_NWORDS(11 downto 0)) + 1; 
          read_data <= x"0000";
          read_state <= S_READ_ASSERT_CS;
          read_done <= '0';
         end if;

   when S_READ_ASSERT_CS =>
        --assert cs_bar and prep FASTREAD command
        read_cmdcounter <= "101001";  -- 40 bits = 8 command + 24 address + 8 dummy (10 dummy?? why?)
        read_cmdreg <=  CmdFASTREAD & read_address; --fast read
        read_spi_cs_bar <= '0';
        read_state <= S_READ_SHIFT_READ;

   when S_READ_SHIFT_READ =>
        --shift FASTREAD command, address, dummy cycles, then data back
        if (read_cmdcounter /= 0) then 
           read_cmdcounter <= read_cmdcounter - 1;
           read_cmdreg <= read_cmdreg(38 downto 0) & '0';
        else
          --command+address+dummy cycles are finished shifting, shift data back
          read_data_counter <= read_data_counter + 1;
          read_data <= read_data(14 downto 0) & spi_miso;
          if (read_data_counter = 15) then
              read_data_valid <= '1';
              read_word_counter <= read_word_counter + 1;
          else
              read_data_valid <= '0';
          end if;
          if (read_word_counter = read_word_limit) then
            read_state <= S_READ_IDLE;   -- Done. All info read 
            read_done <= '1';
            read_word_counter <= x"00000000";
            read_data_counter <= "0000";
            read_spi_cs_bar <= '1';
          end if;  -- if rddata valid
        end if; -- cmdcounter /= 32

   end case;  
 end if;  --rising_edge(CLK)
end process process_read;

-------------------------------  ERASE PROM FSM  --------------------------------------------------
process_erase : process (CLK)
  begin
  if rising_edge(CLK) then
  case erase_state is 
   when S_ERASE_IDLE =>
        --when START_ERASE received, initiate erase process
        erase_spi_cs_bar <= '1';
        if (START_ADDRESS_VALID = '1') then erase_address <= START_ADDRESS(23 downto 0) & x"00"; end if; --currently 3-byte addressing
        if (START_ERASE = '1') then
          erase_done <= '0';
          erase_state <= S_ERASE_ASSERT_CS_WRITE_ENABLE;
         end if;
                       
   when S_ERASE_ASSERT_CS_WRITE_ENABLE =>
        --assert CS and prep write enable commmand
        erase_cmdcounter <= "000111"; --8 bits of command
        erase_cmdreg <=  CmdWE & X"00000000";
        erase_spi_cs_bar <= '0';
        erase_state <= S_ERASE_SHIFT_WRITE_ENABLE;
                  
   when S_ERASE_SHIFT_WRITE_ENABLE =>
         --shift write enable
         if (erase_cmdcounter /= 0) then 
           erase_cmdcounter <= erase_cmdcounter - 1;  
           erase_cmdreg <= erase_cmdreg(38 downto 0) & '0';
         else 
           erase_spi_cs_bar <= '1';
           erase_state <= S_ERASE_ASSERT_CS_ERASE;        
         end if;
                   
   when S_ERASE_ASSERT_CS_ERASE =>
        --assert CS and prepare for erase
        erase_spi_cs_bar <= '0';   
        erase_cmdreg <=  CmdSE24 & erase_address; 
        erase_cmdcounter <= "011111"; --32 bits: 8 command + 24 address
        erase_state <= S_ERASE_SHIFT_ERASE;
                      
   when S_ERASE_SHIFT_ERASE =>     
        --shift erase command
        if (erase_cmdcounter /= 0) then 
          erase_cmdcounter <= erase_cmdcounter - 1;
          erase_cmdreg <= erase_cmdreg(38 downto 0) & '0';
        else
          erase_spi_cs_bar <= '1';
          erase_state <= S_ERASE_ASSERT_CS_READ_STATUS;
        end if;
                                      
   when S_ERASE_ASSERT_CS_READ_STATUS =>
        --assert cs and prepare for read status
        erase_spi_cs_bar <= '0';   
        erase_status_bit_index <= x"00";
        erase_cmdcounter <= "001111"; --16 bits = 8 command + 8 to skip first read cycle
        erase_cmdreg <=  CmdStatus & X"00000000";  -- Read Status register
        erase_state <= S_ERASE_SHIFT_READ_STATUS;
                  
   when S_ERASE_SHIFT_READ_STATUS =>
        --shift read status command and read back status register
        if (erase_cmdcounter /= 0) then 
          erase_cmdcounter <= erase_cmdcounter - 1;
          erase_cmdreg <= erase_cmdreg(38 downto 0) & '0';
        else
          --once command is shifted and first read cycle skipped, check bit 0 on each cycle to see if done
          erase_status_bit_index <= erase_status_bit_index + 1;
          if (erase_status_bit_index = 0) then 
            --status(0) is write in progress flag bit
            --note: Hualin's firmware only checks this on bit 0 of the next cycle. Not sure if necessary
            if (spi_miso = '0' or in_simulation) then
              erase_state <= S_ERASE_IDLE;
              erase_done <= '1';
            end if;
            --erase_in_progress_bit <= spi_miso;
          end if;
        end if;
   end case;  
 end if;  -- Clk
end process process_erase;

-------------------------------  WRITE PROM FSM  --------------------------------------------------

process_write : process (CLK)
  begin
  if rising_edge(Clk) then
  case write_state is 
   when S_WRITE_IDLE =>
        write_spi_cs_bar <= '1';
        write_done <= '0';
        --initalize program process when START_WRITE received
        if (START_ADDRESS_VALID = '1') then write_address <= START_ADDRESS(23 downto 0) & x"00"; end if; --currently, 3-byte addressing
        if (START_WRITE = '1') then
          write_fifo_read_enable <= '0';
          write_word_limit <= (x"00000" & WRITE_NWORDS(11 downto 0)) + 1; 
          dopin_ts <= "1110";
          write_state <= S_WRITE_ASSERT_CS_WRITE_ENABLE;
        end if;

   when S_WRITE_ASSERT_CS_WRITE_ENABLE =>
        --assert CS and prepare write enable command
        --if (page_count /= 0) then 
        --  if (synced_fifo_almostfull(1) = '1') then
        --    SpiCsB <= '0';
        --    write_state <= S_WR_WRCMD;
        --  end if;
        --else 
        --don't wait for fifo anymore?
        write_cmdcounter <= "000111";  -- 8 bits of command
        write_cmdreg <=  CmdWE & X"00000000";
        write_spi_cs_bar <= '0';
        write_state <= S_WRITE_SHIFT_WRITE_ENABLE;
        --end if;
                  
   when S_WRITE_SHIFT_WRITE_ENABLE =>
        --shift write enable command
        if (write_cmdcounter /= 0) then
          write_cmdcounter <= write_cmdcounter - 1;  
          write_cmdreg <= write_cmdreg(38 downto 0) & '0';
        else
          write_spi_cs_bar <= '1';
          write_state <= S_WRITE_ASSERT_CS_PROGRAM;
        end if;
                   
   when S_WRITE_ASSERT_CS_PROGRAM =>
        --assert CS and prepare fast page program command
        write_spi_cs_bar <= '0';
        write_data_counter <= "00";
        write_word_counter <= x"00000000";
        write_cmdreg <=  CmdPP24Quad & write_address;  -- Program Page at Current_Addr
        write_cmdcounter <= "011111"; --32 bits: 8 command + 24 address bits
        write_state <= S_WRITE_SHIFT_PROGRAM;
                                                 
   when S_WRITE_SHIFT_PROGRAM =>
        -- shift fast page program command
        if (write_cmdcounter /= 0) then 
          write_cmdcounter <= write_cmdcounter - 1;
          write_cmdreg <= write_cmdreg(38 downto 0) & '0';
        else 
          write_state <= S_WRITE_SHIFT_DATA;
          write_fifo_read_enable <= '1';
          dopin_ts <= "0000";
        end if;
                          
   when S_WRITE_SHIFT_DATA =>
        --shift the data to be programmed
        write_data_counter <= write_data_counter + 1;
        if (write_data_counter = 3) then
          --finished shifting 1 word
          write_address <= write_address + 1;
          write_word_counter <= write_word_counter + 1;
          if (((write_word_limit-1) = write_word_counter) or (write_address(7 downto 0) = 255)) then
            --finish shifting data when we reach word limit or hit the end of a page
            write_fifo_read_enable <= '0';
            write_spi_cs_bar <= '1'; --latched otherwise
            write_state <= S_WRITE_ASSERT_CS_READ_STATUS;
          else
            write_fifo_read_enable <= '1';
          end if;
        elsif (write_data_counter = 1) then
          --finished shifting 1 byte
          write_address <= write_address + 1;
          if (write_address(7 downto 0) = 255) then
            --finish shifting data when we reach word limit or hit the end of a page
            write_fifo_read_enable <= '0';
            write_spi_cs_bar <= '1'; --latched otherwise
            write_state <= S_WRITE_ASSERT_CS_READ_STATUS;
          else
            write_fifo_read_enable <= '1';
          end if;
        else
          write_fifo_read_enable <= '1';
        end if;
        
   when S_WRITE_ASSERT_CS_READ_STATUS =>
        -- assert CS and prep read status command
        -- this part is strange, if only do read status once, will get 11111111 always from miso
        write_fifo_read_enable <= '0';
        write_spi_cs_bar <= '0';
        dopin_ts <= "1110"; --latched otherwise
        write_cmdcounter <= "011111"; --16 bits: 8 command + 8 to skip the first cycle
        write_cmdreg <=  CmdStatus & X"00000000";
        write_state <= S_WRITE_SHIFT_READ_STATUS;
        
   when S_WRITE_SHIFT_READ_STATUS =>
        --shift read status command and read back status register
        if (write_cmdcounter /= 0) then 
          write_cmdcounter <= write_cmdcounter - 1;
          write_cmdreg <= write_cmdreg(38 downto 0) & '0';
        else
          write_spi_cs_bar <= '1';
          write_state <= S_WRITE_ASSERT_CS_READ_STATUS_2;
        end if; --write_cmdcounter = 

   when S_WRITE_ASSERT_CS_READ_STATUS_2 =>
        -- assert CS and prep read status command
        write_spi_cs_bar <= '0';
        write_cmdcounter <= "011111"; --16 bits: 8 command + 8 to skip the first cycle
        write_cmdreg <=  CmdStatus & X"00000000";
        write_state <= S_WRITE_SHIFT_READ_STATUS_2;

   when S_WRITE_SHIFT_READ_STATUS_2 =>
        --shift read status command and read back status register
        if (write_cmdcounter /= 0) then 
          write_cmdcounter <= write_cmdcounter - 1;
          write_cmdreg <= write_cmdreg(38 downto 0) & '0';
        else
          --once command is shifted and first read cycle skipped, check bit 0 on each cycle to see if done
          write_status_bit_index <= write_status_bit_index + 1;
          if (write_status_bit_index = 0) then 
            --status(0) is write in progress flag bit
            --note: Hualin's firmware only checks this on bit 0 of the next cycle. Not sure if necessary
            if (spi_miso = '0' or in_simulation) then
              write_spi_cs_bar <= '1';
              if (write_word_limit = write_word_counter) then
                write_state <= S_WRITE_IDLE;
                write_done <= '1';
              else 
                write_state <= S_WRITE_ASSERT_CS_WRITE_ENABLE;
              end if; --write_nwords_limit /= write_word_counter
            end if; --spi_miso = '0' or in_simulation
          end if; --write_status_bit_index = 0
        end if; --write_cmdcounter = 0

   --when S_WR_PPDONE =>
   --     dopin_ts <= "1110";
   --     SpiCsB <= '0';
   --     data_valid_cntr <= "000";
   --     cmdcounter <= "100111";
   --     write_state <= S_WR_PPDONE_WAIT;
   --                 
   --when S_WR_PPDONE_WAIT => 
   --     write_fifo_read_enable <= '0';  
   --     if (reset_design = '1') then write_state <= S_WR_IDLE;
   --     else 
   --       if (cmdcounter /= 31) then cmdcounter <= cmdcounter - 1; 
   --         cmdreg <= cmdreg(38 downto 0) & '0';
   --       else -- keep reading the status register
   --         data_valid_cntr <= data_valid_cntr + 1;  -- rolls over to 0
   --         rddata <= rddata(1) & spi_miso;  -- deser 1:8  
   --         --rddata <= rddata(1) & "0" ;  -- deser 1:8  
   --         if (data_valid_cntr = 7) then  -- catch status byte
   --           StatusDataValid <= '1';    -- copy WE and Write in progress one cycle after rddate
   --         else 
   --           StatusDataValid <= '0';
   --         end if;
   --         if (StatusDataValid = '1') then spi_status <= rddata; end if;  --  rddata valid from previous cycle
   --         if (spi_status = 0 or in_simulation) then    -- Done with page program
   --         --if spi_status = 1 then    -- Done with page program
   --           SpiCsB <= '1';   -- turn off SPI
   --           cmdcounter <= "100111";
   --           cmdreg <=  CmdWE & X"00000000";  -- Set WE bit
   --           data_valid_cntr <= "000";
   --           StatusDataValid <= '0';
   --           spi_status <= "11";
   --           page_count <= page_count - 1;
   --           write_state <= S_WR_ASSCS1;
   --         end if;  -- spi_status
   --       end if;  -- cmdcounter
   --     end if;  -- reset_design
                          
    end case;
   end if;  -- CLK
end process process_write;

--------------********* misc **************---------------------
--fifo_unconned(15 downto 0) <= data_to_fifo;
---- to top design. Some may require syncronizers when used   
--fifofull    <= fifo_full;
--fifoempty   <= fifo_empty;        -- May require synconizer when used
--fifoafull   <= fifo_almostfull;   -- May require synconizer when used
--fifowrerr   <= wrerr;
--fiforderr   <= rderr;             -- May require synconizer when used

--DIAGOUT(3 downto 0) <= do_in;
--DIAGOUT(4) <= di_out(1);
--DIAGOUT(5) <= spi_cs_bar;
--DIAGOUT(6) <= START_READ;
--DIAGOUT(7) <= read_done;
--DIAGOUT(8) <= START_ERASE;
--DIAGOUT(9) <= erase_done;
--DIAGOUT(10) <= START_WRITE;
--DIAGOUT(11) <= write_done;
--DIAGOUT(12) <= WRITE_FIFO_WRITE_ENABLE;
--DIAGOUT(13) <= read_data_valid;
--DIAGOUT(14) <= START_ADDRESS_VALID;
--DIAGOUT(17 downto 15) <= read_data(2 downto 0);
DIAGOUT(7 downto 0) <= WRITE_FIFO_INPUT(7 downto 0);
DIAGOUT(8) <= read_data_valid;
DIAGOUT(9) <= WRITE_FIFO_WRITE_ENABLE;
DIAGOUT(11 downto 10) <= read_data(1 downto 0);
DIAGOUT(15 downto 12) <= do_in;
DIAGOUT(16) <= spi_cs_bar;
DIAGOUT(17) <= START_ADDRESS_VALID;

end behavioral;

