library ieee;
library work;
library UNISIM;
use UNISIM.vcomponents.all;
use work.Latches_Flipflops.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;

entity QSPI_DUMMY is
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
    QSPI_CFG_UL_PULSE     : out std_logic;
    QSPI_CFG_DL_PULSE     : out std_logic;
    QSPI_CONST_UL_PULSE   : out std_logic;
    QSPI_CONST_DL_PULSE   : out std_logic;
    QSPI_UL_REG           : out std_logic_vector(15 downto 0);
    QSPI_CFG_BUSY         : out std_logic;
    QSPI_CONST_BUSY       : out std_logic;
    QSPI_CFG_REG_WE       : out integer range 0 to NREGS;
    QSPI_CONST_REG_WE     : out integer range 0 to NREGS;
    QSPI_CFG_REGS         : in cfg_regs_array;
    QSPI_CONST_REGS       : in cfg_regs_array;
    --signals to/from QSPI_CTRL
    QSPI_START_INFO      : out std_logic;
    QSPI_START_WRITE     : out std_logic;
    QSPI_START_ERASE     : out std_logic;
    QSPI_START_READ      : out std_logic;
    QSPI_START_READ_FIFO : out std_logic;
    QSPI_CMD_INDEX       : out std_logic_vector(3 downto 0);
    QSPI_READ_ADDR       : out std_logic_vector(31 downto 0);
    QSPI_WD_LIMIT        : out std_logic_vector(31 downto 0);
    QSPI_STARTADDR       : out std_logic_vector(31 downto 0);
    QSPI_PAGECOUNT       : out std_logic_vector(16 downto 0);
    QSPI_SECTORCOUNT     : out std_logic_vector(13 downto 0);
    QSPI_FIFO_OUT        : in std_logic_vector(15 downto 0);
    QSPI_FIFO_IN         : out std_logic_vector(15 downto 0);
    QSPI_WRITE_FIFO_EN   : out std_logic
    );
end QSPI_DUMMY;

architecture QSPI_DUMMY_Arch of QSPI_DUMMY is

  signal cfg_reg_hardcode : cfg_regs_array := (x"0019", x"FFF1", x"0001", x"FFF3",
                                                 x"0008", x"0008", x"0004", x"0000",
                                                 x"D3B7", x"D3B7", x"00FF", x"0100",
                                                 x"FFFC", x"FFFD", x"FFFE", x"FFFF");
  --what are normal values?
  
  signal ce_cfg_reg_count_enable : std_logic := '0';
  signal cfg_reg_count_enable : std_logic := '0';
  signal cfg_ul_pulse_pre : std_logic := '0';
  signal qspi_cfg_ul_pulse_inner : std_logic := '0';
  signal cc_cfg_reg_we_inner : integer := NREGS;
  
  signal fifo_read_en : std_logic := '0';
  signal fifo_read_cntr : unsigned(3 downto 0) := x"0";
  signal fifo_read_offcycle : std_logic := '0';
  
  signal do_cfg_upload_q : std_logic := '0';
  signal do_cfg_upload_pulse : std_logic := '0';
  signal qspi_read_fifo_pulse : std_logic := '0';
  
  --download to PROM signals
  --signal do_cfg_download_q, do_cfg_download_pulse : std_logic := '0';
  signal ul_cfg_reg_idx : integer := 0;
  type dl_cfg_states is (S_IDLE, S_ISSUE_INFO_1, S_ISSUE_ERASE, S_ISSUE_INFO_2, S_PUSH_REG, S_END_PULSE, S_ISSUE_WRITE);
  signal dl_cfg_state : dl_cfg_states := S_IDLE;
  signal qspi_fifo_in_inner : std_logic_vector(15 downto 0) := x"0000";
  
  --TEMP: erase PROM signals
  type er_cfg_states is (S_IDLE, S_ISSUE_INFO, S_ISSUE_ERASE);
  signal er_cfg_state : er_cfg_states := S_IDLE;
  signal qspi_start_info_inner1, qspi_start_info_inner2, qspi_start_erase_inner1, qspi_start_erase_inner2 : std_logic := '0';
  
  --command parsing signals
  signal cmddev : std_logic_vector(15 downto 0) := x"0000";
  signal do_cfg_upload, do_cfg_download, do_cfg_erase : std_logic := '0';
  
  --dtack signals
  signal ce_d_dtack, d_dtack, q_dtack : std_logic := '0';

begin

  --Decode command
  cmddev    <= "000" & DEVICE & COMMAND & "00";

  do_cfg_download <= '1' when (cmddev=x"1000" and strobe='1') else '0'; --0x6000
  do_cfg_upload <= '1' when (cmddev=x"1004" and strobe='1') else '0'; --0x6004
  --temp command for debugging
  do_cfg_erase <= '1' when (cmddev=x"1008" and strobe='1') else '0';

  --hardcode pages and sector
  QSPI_CMD_INDEX <= x"4"; --RDFR24QUAD
  QSPI_READ_ADDR <= x"00F3E000";
  QSPI_WD_LIMIT <= x"00000010";
  QSPI_STARTADDR <= x"00F3E000";
  QSPI_PAGECOUNT <= x"0000" & "1";
  QSPI_SECTORCOUNT <= x"000" & "01";
  
  --temporary: separate erase PROM command for debugging
  QSPI_START_INFO <= qspi_start_info_inner1 or qspi_start_info_inner2;
  QSPI_START_ERASE <= qspi_start_erase_inner1 or qspi_start_erase_inner2;
  fifo_erase_proc : process (SLOWCLK)
  begin
  if rising_edge(SLOWCLK) then
    case er_cfg_state is
    when S_IDLE => 
      qspi_start_info_inner1 <= '0';
      qspi_start_erase_inner1 <= '0';
      if (do_cfg_erase='1') then
        er_cfg_state <= S_ISSUE_INFO;
      else
        er_cfg_state <= S_IDLE;
      end if;
    when S_ISSUE_INFO =>
      qspi_start_info_inner1 <= '1';
      qspi_start_erase_inner1 <= '0';
      er_cfg_state <= S_ISSUE_ERASE;
    when S_ISSUE_ERASE =>
      qspi_start_info_inner1 <= '0';
      qspi_start_erase_inner1 <= '1';
      er_cfg_state <= S_IDLE;
    end case;
  end if;
  end process;
  
  --Handle download to PROM command
  --steps: set info, erase page (?), set info, write cfg registers to fifo, issue write command
  --do_cfg_download_q <= do_cfg_download when rising_edge(SLOWCLK) else do_cfg_download_q;
  --do_cfg_download_pulse <= do_cfg_download and not do_cfg_download_q;
  QSPI_FIFO_IN <= qspi_fifo_in_inner;
  fifo_write_proc : process (SLOWCLK)
  begin
  if rising_edge(SLOWCLK) then
    case dl_cfg_state is
    when S_IDLE =>
      qspi_start_info_inner2 <= '0';
      qspi_start_erase_inner2 <= '0';
      QSPI_START_WRITE <= '0';
      qspi_fifo_in_inner <= qspi_fifo_in_inner;
      QSPI_WRITE_FIFO_EN <= '0';
      ul_cfg_reg_idx <= 0;
      --this takes long enough that we shouldn't double write
      if (do_cfg_download='1') then
        dl_cfg_state <= S_ISSUE_INFO_2;
      else
        dl_cfg_state <= S_IDLE;
      end if;
    when S_ISSUE_INFO_1 =>
      qspi_start_info_inner2 <= '1';
      qspi_start_erase_inner2 <= '0';
      QSPI_START_WRITE <= '0';
      qspi_fifo_in_inner <= qspi_fifo_in_inner;
      QSPI_WRITE_FIFO_EN <= '0';
      ul_cfg_reg_idx <= ul_cfg_reg_idx;
      dl_cfg_state <= S_ISSUE_ERASE;
    when S_ISSUE_ERASE =>
      qspi_start_info_inner2 <= '0';
      qspi_start_erase_inner2 <= '0';
      QSPI_START_WRITE <= '0';
      qspi_fifo_in_inner <= qspi_fifo_in_inner;
      QSPI_WRITE_FIFO_EN <= '0';
      ul_cfg_reg_idx <= ul_cfg_reg_idx;
      dl_cfg_state <= S_ISSUE_INFO_2;
    when S_ISSUE_INFO_2 =>
      qspi_start_info_inner2 <= '1';
      qspi_start_erase_inner2 <= '0';
      QSPI_START_WRITE <= '0';
      qspi_fifo_in_inner <= qspi_fifo_in_inner;
      QSPI_WRITE_FIFO_EN <= '0';
      ul_cfg_reg_idx <= ul_cfg_reg_idx;
      dl_cfg_state <= S_PUSH_REG;  
    when S_PUSH_REG =>
      qspi_start_info_inner2 <= '0';
      qspi_start_erase_inner2 <= '0';
      QSPI_START_WRITE <= '0';
      qspi_fifo_in_inner <= QSPI_CFG_REGS(ul_cfg_reg_idx);
      QSPI_WRITE_FIFO_EN <= '1';
      ul_cfg_reg_idx <= ul_cfg_reg_idx;
      dl_cfg_state <= S_END_PULSE;
    when S_END_PULSE =>
      qspi_start_info_inner2 <= '0';
      qspi_start_erase_inner2 <= '0';
      QSPI_START_WRITE <= '0';
      qspi_fifo_in_inner <= qspi_fifo_in_inner;
      QSPI_WRITE_FIFO_EN <= '0';
      if (ul_cfg_reg_idx = (NREGS-1)) then
        ul_cfg_reg_idx <= 0;
        dl_cfg_state <= S_ISSUE_WRITE;
      else
        ul_cfg_reg_idx <= ul_cfg_reg_idx + 1;
        dl_cfg_state <= S_PUSH_REG;
      end if;
    when S_ISSUE_WRITE =>
      qspi_start_info_inner2 <= '0';
      qspi_start_erase_inner2 <= '0';
      QSPI_START_WRITE <= '1';
      qspi_fifo_in_inner <= qspi_fifo_in_inner;
      QSPI_WRITE_FIFO_EN <= '0';
      ul_cfg_reg_idx <= ul_cfg_reg_idx;
      dl_cfg_state <= S_IDLE;
    end case;
  end if;
  end process;
  
  --Handle upload from PROM command
  do_cfg_upload_q <= do_cfg_upload when rising_edge(SLOWCLK) else do_cfg_upload_q;
  do_cfg_upload_pulse <= do_cfg_upload and not do_cfg_upload_q;
  QSPI_START_READ <= do_cfg_upload_pulse; --start read from PROM as soon as we get the signal, but wait for a few (2.5MHz) cycles to read FIFO and wait until this is finished to start assigning registers
  DS_FIFOREAD : DELAY_SIGNAL generic map (NCYCLES_MAX => 16) port map (DOUT => qspi_read_fifo_pulse, CLK => SLOWCLK, NCYCLES => 16, DIN => do_cfg_upload_pulse); 
  DS_CFGULPULSEPRE : DELAY_SIGNAL generic map (NCYCLES_MAX => 34) port map (DOUT => cfg_ul_pulse_pre, CLK => SLOWCLK, NCYCLES => 34, DIN => qspi_read_fifo_pulse); 

  --pulse QSPI_START_READ_FIFO and assign cfg_reg_hardcode based on QSPI_FIFO_OUT
  fifo_read_proc : process (SLOWCLK)
  begin
    if rising_edge(SLOWCLK) then
      if (qspi_read_fifo_pulse='1') then
        fifo_read_en <= '1';
        fifo_read_offcycle <= '0';
        fifo_read_cntr <= x"0";
        QSPI_START_READ_FIFO <= '0';
      else
        if (fifo_read_en='1') then
          if (fifo_read_offcycle='0') then
            cfg_reg_hardcode(to_integer(fifo_read_cntr)) <= QSPI_FIFO_OUT;
            fifo_read_offcycle <= '1';
            fifo_read_en <= '1';
            fifo_read_cntr <= fifo_read_cntr;
            QSPI_START_READ_FIFO <= '1';
          else
            if (fifo_read_cntr=x"F") then
              fifo_read_en <= '0';
            else
              fifo_read_en <= '1';
            end if;
            QSPI_START_READ_FIFO <= '0';
            fifo_read_cntr <= fifo_read_cntr + 1;
            fifo_read_offcycle <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  QSPI_UL_REG <= cfg_reg_hardcode(cc_cfg_reg_we_inner) when (cc_cfg_reg_we_inner /= NREGS) else x"0000";
  QSPI_CONST_BUSY <= '0';
  QSPI_CFG_BUSY <= '0';
  QSPI_CONST_DL_PULSE <= '0';
  QSPI_CFG_DL_PULSE <= '0';
  QSPI_CONST_UL_PULSE <= '0'; --never upload CONST REGs
  QSPI_CONST_REG_WE <= NREGS;
  QSPI_CFG_UL_PULSE <= qspi_cfg_ul_pulse_inner;
  QSPI_CFG_REG_WE <= cc_cfg_reg_we_inner;

  --upload CFG registers on reset

  FDPE_cfg_ul_pulse : FDPE port map(Q => cfg_reg_count_enable, C => SLOWCLK, CE => ce_cfg_reg_count_enable, PRE => cfg_ul_pulse_pre, D => '0');
  
  cfg_upload_proc : process (SLOWCLK)
  begin
    if rising_edge(SLOWCLK) then
      if (cfg_reg_count_enable = '0') then
        --IDLE state, don't do anything
        ce_cfg_reg_count_enable <= '0';
        qspi_cfg_ul_pulse_inner <= '0';
        cc_cfg_reg_we_inner <= NREGS;
      else
        if (cc_cfg_reg_we_inner = NREGS) then
          --first cycle after RST, move we to 0 but don't do anything else
          ce_cfg_reg_count_enable <= '0'; 
          qspi_cfg_ul_pulse_inner <= '0';
          cc_cfg_reg_we_inner <= 0;          
        elsif (cc_cfg_reg_we_inner = NREGS-1) then
          --reset everything for next RST
          ce_cfg_reg_count_enable <= '1';
          qspi_cfg_ul_pulse_inner <= '0';
          cc_cfg_reg_we_inner <= NREGS;
        else
          if (qspi_cfg_ul_pulse_inner = '0') then
            --on-cycle give a UL pulse
            ce_cfg_reg_count_enable <= '0';
            qspi_cfg_ul_pulse_inner <= '1';
            cc_cfg_reg_we_inner <= cc_cfg_reg_we_inner;
          else
            --off-cycle, update reg_we
            ce_cfg_reg_count_enable <= '0';
            qspi_cfg_ul_pulse_inner <= '0';
            cc_cfg_reg_we_inner <= cc_cfg_reg_we_inner + 1;
          end if;
        end if;
      end if;
    end if;
  end process;
  
  -- DTACK: always just issue on second SLOWCLK edge after STROBE
  ce_d_dtack <= STROBE and DEVICE;
  FD_D_DTACK : FDCE port map(Q => d_dtack, C => SLOWCLK, CE => ce_d_dtack, CLR => q_dtack, D => '1');
  FD_Q_DTACK : FD port map(Q => q_dtack, C => SLOWCLK, D => d_dtack);
  DTACK    <= q_dtack;

end QSPI_DUMMY_Arch;
