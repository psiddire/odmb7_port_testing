library ieee;
library work;
library unisim;
library hdlmacro;
use unisim.vcomponents.all;
use work.ucsb_types.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.and_reduce;
use ieee.std_logic_misc.or_reduce;
use ieee.std_logic_misc.xor_reduce;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

--! @brief Monitor state of the nine data FIFOs and create DDU packet when FIFOs are non-empty.
--! @details CONTROL_FSM: builds packets to DDU as data becomes available
entity CONTROL_FSM is
  generic (
    NCFEB : integer range 1 to 7 := 7  --! Number of DCFEBS, 7/5
    );  
  port (

    -- Chip Scope Pro Logic Analyzer control
    -- CSP_CONTROL_FSM_PORT_LA_CTRL : inout std_logic_vector(35 downto 0);

    RST    : in std_logic;                     --! From RESET or VMEMON L1A reset
    CLKCMS : in std_logic;                     --! 40.079 MHz CMS clock
    CLK    : in std_logic;                     --! DDU clock (typ 80 MHz)
    STATUS : in std_logic_vector(47 downto 0); --! Unused

    -- From DMB_VME
    RDFFNXT : in std_logic;                          --! Fixed to '0', unused
    KILL    : in std_logic_vector(NCFEB+2 downto 1); --! Killed FEBs, from VMECONFREGS

    -- to GigaBit Link
    DOUT : out std_logic_vector(15 downto 0); --! Output data to GTX
    DAV  : out std_logic;                     --! Data available signal to GTX

    -- to FIFOs
    OEFIFO_B  : out std_logic_vector(NCFEB+2 downto 1); --! selects FIFO to read in ODMB_DATA, set by FSM
    RENFIFO_B : out std_logic_vector(NCFEB+2 downto 1); --! read enable for FIFOs in ODMB_DATA, set by FSM

    -- from FIFOs
    FIFO_HALF_FULL : in std_logic_vector(NCFEB+2 downto 1); --! for status words, programmable full signal
    FFOR_B         : in std_logic_vector(NCFEB+2 downto 1); --! debug signal, fifo empty signal
    DATAIN         : in std_logic_vector(15 downto 0); --! data from FIFO (lower 15 bits in FIFOs)
    DATAIN_LAST    : in std_logic; --! indicates last word, top bit in data FIFOs

    -- From JTAGCOM
    JOEF : in std_logic_vector(NCFEB+2 downto 1); --! unused, not connected (in legacy design, from LOADFIFO)

    -- For headers/trailers
    DAQMBID : in std_logic_vector(11 downto 0); --! board ID from vmeconfregs for header/tailer
    AUTOKILLED_DCFEBS  : in std_logic_vector(NCFEB downto 1); --! not currently used, tied to 0 in top

    -- FROM SW1
    GIGAEN : in std_logic; --! unused, tied to 1

    -- TO CAFIFO
    FIFO_POP : out std_logic; --! Signal to advance to next event in CAFIFO

    -- TO DDUFIFO
    EOF : out std_logic; --! to PCFIFO, sent at end of packet

    -- DEBUG
    control_debug : out std_logic_vector(143 downto 0); --! debug signal

    -- FROM CAFIFO
    cafifo_l1a_dav   : in std_logic_vector(NCFEB+2 downto 1); --! Which data has arrived for current event, from CAFIFO
    cafifo_l1a_match : in std_logic_vector(NCFEB+2 downto 1); --! Current event's L1A matches, from CAFIFO
    cafifo_l1a_cnt   : in std_logic_vector(23 downto 0);      --! Current event's L1A #, from CAFIFO
    cafifo_bx_cnt    : in std_logic_vector(11 downto 0);      --! Current event's BX #, from CAFIFO
    cafifo_lost_pckt : in std_logic_vector(NCFEB+2 downto 1); --! Current event's lost packets, from CAFIFO
    cafifo_lone      : in std_logic                           --! Current event is matchless, from CAFIFO

    );
end CONTROL_FSM;

architecture CONTROL_arch of CONTROL_FSM is

  component csp_control_fsm_la is
    port (
      CLK     : in    std_logic := 'X';
      DATA    : in    std_logic_vector (127 downto 0);
      TRIG0   : in    std_logic_vector (7 downto 0);
      CONTROL : inout std_logic_vector (35 downto 0)
      );
  end component;

  signal fifo_pop_80 : std_logic := '0';

  type hdr_tail_array is array (8 downto 1) of std_logic_vector(15 downto 0);
  signal hdr_word, tail_word : hdr_tail_array;

  type lone_array is array (4 downto 1) of std_logic_vector(15 downto 0);
  signal lone_word : lone_array;

  constant fmt_vers         : std_logic_vector(1 downto 0)      := "10";
  constant l1a_dav_mismatch : std_logic                         := '0';
  constant ovlp             : std_logic_vector(5 downto 1)      := "00000";
  constant sync             : std_logic_vector(3 downto 0)      := "0000";
  constant alct_to_end      : std_logic                         := '0';
  constant otmb_to_end      : std_logic                         := '0';
  constant data_fifo_full   : std_logic_vector(NCFEB+2 downto 1) := (others => '0');
  -- constant data_fifo_half   : std_logic_vector(NCFEB+2 downto 1) := (others => '0');
  constant dmb_l1pipe       : std_logic_vector(7 downto 0)      := (others => '0');
  constant wait_max         : integer := 16;
  constant wait_dev_max     : integer := 5;

  type control_state is (IDLE, HEADER, WAIT_DEV, TX_DEV, TAIL, LONE, WAIT_IDLE);
  signal control_current_state, control_next_state, q_control_current_state : control_state := IDLE;

  signal hdr_tail_cnt_en       : std_logic             := '0';
  signal hdr_tail_cnt          : integer range 1 to 8  := 1;
  signal lone_cnt_en           : std_logic             := '0';
  signal lone_cnt              : integer range 1 to 4  := 1;
  signal wait_cnt_en           : std_logic             := '0';
  signal wait_cnt              : integer range 1 to wait_max := 1;
  signal wait_dev_cnt_en       : std_logic             := '0';
  signal wait_dev_cnt          : integer range 1 to wait_dev_max := 1;
  signal dev_cnt_en            : std_logic             := '0';
  signal dev_cnt               : integer range 1 to 9  := NCFEB+2;
  signal tx_cnt_en, tx_cnt_rst : std_logic             := '0';
  signal tx_cnt                : integer range 1 to 4  := 1;
  type tx_cnt_array is array (1 to 9) of integer range 1 to 4;
  --signal   tx_cnt                : tx_cnt_array          := (1, 1, 1, 1, 1, 1, 1, 1, 1);
  --constant tx_cnt_max            : tx_cnt_array          := (4, 4, 4, 4, 4, 4, 4, 2, 2);
  constant tx_cnt_max          : tx_cnt_array          := (3, 3, 3, 3, 3, 3, 3, 1, 1);

  signal reg_crc, crc : std_logic_vector(23 downto 0) := (others => '0');

  signal crc_clr, crc_en : std_logic;
  signal q_datain_last   : std_logic;

  --Declaring Logic Analyzer signals -- bgb
  signal control_fsm_la_data : std_logic_vector(127 downto 0);
  signal control_fsm_la_trig : std_logic_vector(7 downto 0);

  signal expect_pckt                      : std_logic                     := '0';
  signal dav_inner, dav_d                 : std_logic                     := '0';
  signal dout_inner, dout_d               : std_logic_vector(15 downto 0) := (others => '0');
  signal oefifo_b_inner, renfifo_b_inner  : std_logic_vector(NCFEB+2 downto 1);
  signal fifo_pop_inner, eof_inner, eof_d : std_logic                     := '0';
  signal d_fifo_pop_inner                 : std_logic                     := '0';


  signal dev_cnt_svl, hdr_tail_cnt_svl, lone_cnt_svl : std_logic_vector(4 downto 0) := (others => '0');

  signal current_state_svl, next_state_svl : std_logic_vector(3 downto 0) := (others => '0');
  signal bad_l1a_lone, bad_l1a_change, bad_l1a_change40 : std_logic := '0'; 
  signal cafifo_l1a_cnt_reg   : std_logic_vector(23 downto 0);
  signal cafifo_l1a_match_cfeb_big : std_logic_vector(7 downto 1) := (others => '0');
  signal fifo_half_full_cfeb_big   : std_logic_vector(7 downto 1) := (others => '0');

begin

  expect_pckt         <= or_reduce(cafifo_l1a_match);
  dev_cnt_svl         <= std_logic_vector(to_unsigned(dev_cnt, 5));
  hdr_tail_cnt_svl    <= std_logic_vector(to_unsigned(hdr_tail_cnt, 5));
  lone_cnt_svl        <= std_logic_vector(to_unsigned(lone_cnt, 5));
  bad_l1a_lone<= '1' when (or_reduce(cafifo_l1a_match) = '0' and cafifo_lone = '0'
                           and control_current_state /= IDLE and control_current_state /= WAIT_IDLE) else '0';
  FD_CFL1A : FDVEC generic map(0, 23) port map(DOUT => cafifo_l1a_cnt_reg, CLK => clk, RST => rst, DIN => CAFIFO_L1A_CNT);
  bad_l1a_change <= '1' when (cafifo_l1a_cnt_reg /= CAFIFO_L1A_CNT and control_current_state /= IDLE
                              and control_current_state /= WAIT_IDLE) else '0';
  FDBADL1A : PULSE2SLOW port map(DOUT => bad_l1a_change40, CLK_DOUT => CLKCMS, CLK_DIN => CLK, RST => RST, DIN => bad_l1a_change);
-- trigger assignments (8 bits)
  -- control_fsm_la_trig <= expect_pckt & q_datain_last & bad_l1a_lone  & cafifo_lone & CAFIFO_L1A_CNT(3 downto 0);
  control_fsm_la_data(119 downto 116)     <= std_logic_vector(to_unsigned(wait_dev_cnt, 4)); --[119:116]
  control_fsm_la_data(115 downto 107)     <= bad_l1a_change & bad_l1a_lone & lone_cnt_svl & cafifo_lone & RST; -- [115:107]
  control_fsm_la_data(106 downto 102)     <= std_logic_vector(to_unsigned(wait_cnt, 5)); -- [106:102]
  control_fsm_la_data(101 downto 97)      <= CAFIFO_L1A_CNT(4 downto 0); -- [101:97]
  control_fsm_la_data(89+NCFEB downto 88) <= FFOR_B; -- [96:88]
  control_fsm_la_data(80+NCFEB downto 79) <= cafifo_lost_pckt; -- [87:79]
  control_fsm_la_data(78 downto 72)       <= next_state_svl & eof_inner & fifo_pop_inner & fifo_pop_80; -- [78:72]
  control_fsm_la_data(64+NCFEB downto 63) <= oefifo_b_inner; -- [71:63]
  control_fsm_la_data(55+NCFEB downto 54) <= renfifo_b_inner; -- [62:54]
  control_fsm_la_data(53 downto 38)       <= dout_inner; -- [53:38]
  control_fsm_la_data(37 downto 35)       <= '0' & hdr_tail_cnt_en & dev_cnt_en; -- [37:35]
  control_fsm_la_data(27+NCFEB downto 26) <= CAFIFO_L1A_DAV; -- [34:26]
  control_fsm_la_data(18+NCFEB downto 17) <= CAFIFO_L1A_MATCH; -- [25:17]
  control_fsm_la_data(16 downto 15)       <= q_datain_last & expect_pckt; -- [16:15]
  control_fsm_la_data(14 downto 5)        <= hdr_tail_cnt_svl & dev_cnt_svl; -- [14:5]
  control_fsm_la_data(4 downto 0)         <= current_state_svl & dav_inner; -- [4:0]

  control_debug <= control_fsm_la_data & '0' & dev_cnt_svl & bad_l1a_change40 & hdr_tail_cnt_svl
                   & current_state_svl;

-- Needed because DATAIN_LAST does not arrive during the last word
  FDLAST : FD port map(Q => q_datain_last, C => clk, D => DATAIN_LAST);

-- 40 MHz pulse for FIFO_POP
  FDPOP : PULSE2SLOW port map(DOUT => fifo_pop_inner, CLK_DOUT => CLKCMS, CLK_DIN => CLK, RST => RST, DIN => fifo_pop_80);

  control_fsm_regs : process (control_next_state, RST, CLK, dev_cnt, dev_cnt_en, tx_cnt,
                              tx_cnt_en, tx_cnt_rst, hdr_tail_cnt_en, lone_cnt_en, wait_cnt_en, wait_dev_cnt_en)
  begin
    if (RST = '1') then
      control_current_state <= IDLE;
      hdr_tail_cnt          <= 1;
      lone_cnt              <= 1;
      wait_cnt              <= 1;
      wait_dev_cnt          <= 1;
      dev_cnt               <= NCFEB+2;
      tx_cnt                <= 1;
    elsif rising_edge(CLK) then
      if(wait_cnt_en = '1') then
        if(wait_cnt = wait_max) then
          wait_cnt <= 1;
        else
          wait_cnt <= wait_cnt + 1;
        end if;
      end if;
      if(wait_dev_cnt_en = '1') then
        if(wait_dev_cnt = wait_dev_max) then
          wait_dev_cnt <= 1;
        else
          wait_dev_cnt <= wait_dev_cnt + 1;
        end if;
      end if;
      if(hdr_tail_cnt_en = '1') then
        if(hdr_tail_cnt = 8) then
          hdr_tail_cnt <= 1;
        else
          hdr_tail_cnt <= hdr_tail_cnt + 1;
        end if;
      end if;
      if(lone_cnt_en = '1') then
        if(lone_cnt = 4) then
          lone_cnt <= 1;
        else
          lone_cnt <= lone_cnt + 1;
        end if;
      end if;
      if (dev_cnt_en = '1') then
        if(dev_cnt = NCFEB+2) then
          dev_cnt <= NCFEB+1;
        elsif(dev_cnt = NCFEB+1) then
          dev_cnt <= 1;
        elsif(dev_cnt = NCFEB) then
          dev_cnt <= NCFEB+2;
        else
          dev_cnt <= dev_cnt + 1;
        end if;
      end if;
      if(tx_cnt_rst = '1') then
        tx_cnt <= 1;
      elsif(tx_cnt_en = '1' and tx_cnt < 4) then
        tx_cnt <= tx_cnt+1;
      end if;
      control_current_state <= control_next_state;
    end if;
  end process;

  with control_current_state select
    current_state_svl <= x"1" when IDLE,
                         x"2" when HEADER,
                         x"3" when WAIT_DEV,
                         x"4" when TX_DEV,
                         x"5" when TAIL,
                         x"6" when LONE,
                         x"7" when WAIT_IDLE,
                         x"0" when others;
  
  with control_next_state select
    next_state_svl <= x"1" when IDLE,
                      x"2" when HEADER,
                      x"3" when WAIT_DEV,
                      x"4" when TX_DEV,
                      x"5" when TAIL,
                      x"6" when LONE,
                      x"7" when WAIT_IDLE,
                      x"0" when others;

  control_fsm_logic : process (control_current_state, cafifo_l1a_match, cafifo_l1a_dav,
                               hdr_word, hdr_tail_cnt, lone_cnt, dev_cnt, tx_cnt, DATAIN,
                               q_datain_last, tail_word, wait_cnt, wait_dev_cnt, cafifo_lone)
  begin
    oefifo_b_inner  <= (others => '1');
    renfifo_b_inner <= (others => '1');
    eof_d           <= '0';
    fifo_pop_80     <= '0';
    hdr_tail_cnt_en <= '0';
    lone_cnt_en     <= '0';
    wait_cnt_en     <= '0';
    wait_dev_cnt_en <= '0';
    dev_cnt_en      <= '0';
    tx_cnt_rst      <= '0';
    tx_cnt_en       <= '0';

    case control_current_state is
      when IDLE =>
        dout_d <= (others => '0');
        dav_d  <= '0';
        if (or_reduce(cafifo_l1a_match) = '1') then
          control_next_state <= HEADER;
        elsif cafifo_lone = '1' then
          control_next_state <= LONE;
        else
          control_next_state <= IDLE;
        end if;
        
      when HEADER =>
        dout_d          <= hdr_word(hdr_tail_cnt);
        dav_d           <= '1';
        hdr_tail_cnt_en <= '1';
        if (hdr_tail_cnt = 8) then
          control_next_state <= WAIT_DEV;
        else
          control_next_state <= HEADER;
        end if;

      when WAIT_DEV =>
        dout_d     <= (others => '0');
        dav_d      <= '0';
        tx_cnt_rst <= '1';
        wait_dev_cnt_en <= '1';
        if (wait_dev_cnt = wait_dev_max) then
          if (cafifo_l1a_match(dev_cnt) = '0' or cafifo_lost_pckt(dev_cnt) = '1' or KILL(dev_cnt) = '1') then
            dev_cnt_en <= '1';
            if (dev_cnt = NCFEB) then
              control_next_state <= TAIL;
            else
              control_next_state <= WAIT_DEV;
            end if;
          elsif (cafifo_l1a_dav(dev_cnt) = '1') then
            control_next_state      <= TX_DEV;
            oefifo_b_inner(dev_cnt) <= '0';
          else
            control_next_state <= WAIT_DEV;
          end if;
        else
          control_next_state <= WAIT_DEV;
        end if;
        
      when TX_DEV =>
        dout_d                   <= DATAIN;
        oefifo_b_inner(dev_cnt)  <= '0';
        renfifo_b_inner(dev_cnt) <= '0';
        tx_cnt_en                <= '1';
        if (tx_cnt >= tx_cnt_max(dev_cnt)) then
          dav_d <= '1';
        else
          dav_d <= '0';
        end if;
        if (q_datain_last = '1' or KILL(dev_cnt) = '1') then
          dev_cnt_en <= '1';
          if (dev_cnt = NCFEB) then
            control_next_state <= TAIL;
          else
            control_next_state <= WAIT_DEV;
          end if;
        else
          control_next_state <= TX_DEV;
        end if;

      when TAIL =>
        dout_d          <= tail_word(hdr_tail_cnt);
        dav_d           <= '1';
        hdr_tail_cnt_en <= '1';
        if (hdr_tail_cnt = 5) then -- With the synchronization ~13 cc to increase rd_addr_ou
          fifo_pop_80        <= '1';
        else
          fifo_pop_80        <= '0';
        end if;
        if (hdr_tail_cnt = 8) then
          control_next_state <= WAIT_IDLE;
          eof_d              <= '1';
        else
          control_next_state <= TAIL;
          eof_d              <= '0';
        end if;

      when LONE =>
        dout_d      <= lone_word(lone_cnt);
        dav_d       <= '1';
        lone_cnt_en <= '1';
        if (lone_cnt = 1) then -- With the synchronization ~13 cc to increase rd_addr_ou
          fifo_pop_80        <= '1';
        else
          fifo_pop_80        <= '0';
        end if;
        if (lone_cnt = 4) then
          control_next_state <= WAIT_IDLE;
          eof_d              <= '1';
        else
          control_next_state <= LONE;
          eof_d              <= '0';
        end if;

      when WAIT_IDLE =>
        dout_d      <= (others => '0');
        dav_d       <= '0';
        wait_cnt_en <= '1';
        if (wait_cnt = wait_max) then
          control_next_state <= IDLE;
        else
          control_next_state <= WAIT_IDLE;
        end if;

    end case;
  end process;

  FD_DAV  : FD port map(Q => dav_inner, C => CLK, D => dav_d);
  EOF_DAV : FD port map(Q => eof_inner, C => CLK, D => eof_d);

  GEN_FD_DOUT : for INDEX in 0 to 15 generate
    FD_DOUT : FD port map (Q => dout_inner(INDEX), C => CLK, D => dout_d(INDEX));
  end generate GEN_FD_DOUT;

  crc(4 downto 0) <= reg_crc(20 downto 16);
  crc(5)          <= dout_d(0) xor reg_crc(0) xor reg_crc(21);
  crc(6)          <= dout_d(0) xor dout_d(1) xor reg_crc(0) xor reg_crc(1);
  crc(7)          <= dout_d(1) xor dout_d(2) xor reg_crc(1) xor reg_crc(2);
  crc(8)          <= dout_d(2) xor dout_d(3) xor reg_crc(2) xor reg_crc(3);
  crc(9)          <= dout_d(3) xor dout_d(4) xor reg_crc(3) xor reg_crc(4);
  crc(10)         <= dout_d(4) xor dout_d(5) xor reg_crc(4) xor reg_crc(5);
  crc(11)         <= dout_d(5) xor dout_d(6) xor reg_crc(5) xor reg_crc(6);
  crc(12)         <= dout_d(6) xor dout_d(7) xor reg_crc(6) xor reg_crc(7);
  crc(13)         <= dout_d(7) xor dout_d(8) xor reg_crc(7) xor reg_crc(8);
  crc(14)         <= dout_d(8) xor dout_d(9) xor reg_crc(8) xor reg_crc(9);
  crc(15)         <= dout_d(9) xor dout_d(10) xor reg_crc(9) xor reg_crc(10);
  crc(16)         <= dout_d(10) xor dout_d(11) xor reg_crc(10) xor reg_crc(11);
  crc(17)         <= dout_d(11) xor dout_d(12) xor reg_crc(11) xor reg_crc(12);
  crc(18)         <= dout_d(12) xor dout_d(13) xor reg_crc(12) xor reg_crc(13);
  crc(19)         <= dout_d(13) xor dout_d(14) xor reg_crc(13) xor reg_crc(14);
  crc(20)         <= dout_d(14) xor dout_d(15) xor reg_crc(14) xor reg_crc(15);
  crc(21)         <= dout_d(15) xor reg_crc(15);
  crc(22)         <= crc(0) xor crc(1) xor crc(2) xor crc(3) xor crc(4) xor crc(5)
                     xor crc(6) xor crc(7) xor crc(8) xor crc(9) xor crc(10);
  crc(23)         <= crc(11) xor crc(12) xor crc(13) xor crc(14) xor crc(15) xor crc(16)
                     xor crc(17) xor crc(18) xor crc(19) xor crc(20) xor crc(21);
  -- crc(22)         <= xor_reduce(crc(10 downto 0)); 
  -- crc(23)         <= xor_reduce(crc(21 downto 11));


  GEN_REG_CRC : for K in 0 to 23 generate
  begin
    FDCE_REG_CRC : FDCE port map (Q => REG_CRC(K), C => CLK, CE => crc_en, CLR => crc_clr, D => CRC(K));
  end generate GEN_REG_CRC;

  crc_clr <= '1' when control_current_state = WAIT_IDLE
             else '0';

  crc_en <= '1' when (dav_d = '1' and not (control_current_state = TAIL and hdr_tail_cnt > 4))
            else '0';

  DAV       <= dav_inner;
  DOUT      <= dout_inner;
  OEFIFO_B  <= oefifo_b_inner;
  RENFIFO_B <= renfifo_b_inner;
  FIFO_POP  <= fifo_pop_inner;
  EOF       <= eof_inner;

  cafifo_l1a_match_cfeb_big(NCFEB downto 1) <= cafifo_l1a_match(NCFEB downto 1);
  fifo_half_full_cfeb_big(NCFEB downto 1) <= FIFO_HALF_FULL(NCFEB downto 1);
  hdr_word(1) <= x"9" & cafifo_l1a_cnt(11 downto 0);
  hdr_word(2) <= x"9" & cafifo_l1a_cnt(23 downto 12);
  hdr_word(3) <= x"9" & cafifo_l1a_match(NCFEB+2 downto NCFEB+1) & fmt_vers & l1a_dav_mismatch
                 & cafifo_l1a_match_cfeb_big(7 downto 1);
  hdr_word(4) <= x"9" & cafifo_bx_cnt;
  hdr_word(5) <= x"A" & cafifo_l1a_match(NCFEB+2 downto NCFEB+1) & fmt_vers & l1a_dav_mismatch
                 & cafifo_l1a_match_cfeb_big(7 downto 1);
  hdr_word(6) <= x"A" & DAQMBID(11 downto 0);
  hdr_word(7) <= x"A" & cafifo_l1a_match(NCFEB+2 downto NCFEB+1) & ovlp & cafifo_bx_cnt(4 downto 0);
  hdr_word(8) <= x"A" & sync & fmt_vers & l1a_dav_mismatch & cafifo_l1a_cnt(4 downto 0);

  tail_word(1) <= x"F" & alct_to_end & cafifo_bx_cnt(4 downto 0) & cafifo_l1a_cnt(5 downto 0);
  --tail_word(2) <= x"F" & ovlp & AUTOKILLED_DCFEBS;
  tail_word(2) <= x"F" & ovlp & "000" & x"0"; -- Set timeout to 0 to avoid DDU errors
  tail_word(3) <= x"F" & data_fifo_full(3 downto 1) & cafifo_lost_pckt(NCFEB+1) & dmb_l1pipe;
  -- tail_word(4) <= x"F" & cafifo_lost_pckt(9) & cafifo_lost_pckt(7 downto 1)
  --                 & data_fifo_full(7 downto 4);
  tail_word(4) <= x"F" & cafifo_lost_pckt(NCFEB+2) & "000" & x"0" -- Set timeout to 0 to avoid DDU errors
                  & data_fifo_full(7 downto 4);
  tail_word(5) <= x"E" & data_fifo_full(NCFEB+2 downto NCFEB+1) & not FIFO_HALF_FULL(NCFEB+2 downto NCFEB+1)
                  & otmb_to_end & not fifo_half_full_cfeb_big(7 downto 1);
  tail_word(6) <= x"E" & DAQMBID(11 downto 0);
  tail_word(7) <= x"E" & REG_CRC(22) & REG_CRC(10 downto 0);
  tail_word(8) <= x"E" & REG_CRC(23) & REG_CRC(21 downto 11);

  lone_word(1) <= x"8" & cafifo_l1a_cnt(11 downto 0);
  lone_word(2) <= x"8" & cafifo_l1a_cnt(23 downto 12);
  lone_word(3) <= x"8" & x"000";
  lone_word(4) <= x"8" & cafifo_bx_cnt;
  

end CONTROL_arch;
