library ieee;
library work;
library UNISIM;
use UNISIM.vcomponents.all;
use work.Latches_Flipflops.all;
use ieee.std_logic_1164.all;
use work.ucsb_types.all;


entity CFEBJTAG is
  generic (
    NCFEB   : integer range 1 to 7 := 7
  );
  port (
    FASTCLK : in std_logic;
    SLOWCLK : in std_logic;
    RST     : in std_logic;

    DEVICE  : in std_logic;
    STROBE  : in std_logic;
    COMMAND : in std_logic_vector(9 downto 0);
    WRITER  : in std_logic;

    INDATA  : in  std_logic_vector(15 downto 0);
    OUTDATA : out std_logic_vector(15 downto 0);

    DTACK : out std_logic;

    INITJTAGS : in  std_logic;
    TCK       : out std_logic_vector(NCFEB downto 1);
    TDI       : out std_logic;
    TMS       : out std_logic;
    FEBTDO    : in  std_logic_vector(NCFEB downto 1);

    LED     : out std_logic;
    DIAGOUT : out std_logic_vector(17 downto 0)
    );
end CFEBJTAG;

architecture CFEBJTAG_Arch of CFEBJTAG is
  signal LOGICH : std_logic := '1';

  signal CMDDEV                                                  : std_logic_vector(15 downto 0);
  signal INSTSHFT_ARB, INSTSHFT_SP                               : std_logic;
  signal DATASHFT, INSTSHFT, READTDO, SELCFEB, READCFEB, RSTJTAG : std_logic;
  signal TAILSP                                                  : std_logic;
  signal TAILSP_B                                                : std_logic;
  signal RST_TAIL                                                : std_logic;
  signal RST_ITAIL                                               : std_logic;
  signal RST_HEAD                                                : std_logic;
  signal RST_DHEAD                                               : std_logic;

  signal tdi_inner                                               : std_logic;
  signal tms_inner                                               : std_logic;

  signal SELFEB                                   : std_logic_vector(7 downto 1);
  signal D_DTACK_SELCFEB, Q_DTACK_SELCFEB         : std_logic;
  signal D_DTACK_READCFEB, Q_DTACK_READCFEB       : std_logic;
  signal D1_LOAD, D2_LOAD, CLR_LOAD, Q_LOAD, LOAD : std_logic;

  signal Q_BUSY, D_BUSY, CLR_BUSY, BUSY, BUSYP1                           : std_logic;
  signal C_IHEADEN, CLR_IHEADEN, IHEADEN                                  : std_logic;
  signal SHIHEAD                                                          : std_logic;
  signal R_DONEIHEAD, Q_DONEIHEAD, CEO_DONEIHEAD, TC_DONEIHEAD, DONEIHEAD : std_logic;
  signal QV_DONEIHEAD                                                     : std_logic_vector(3 downto 0);
  signal Q3_SHIHEAD_TMS, Q4_SHIHEAD_TMS, Q5_SHIHEAD_TMS                   : std_logic;
  signal CE_SHIHEAD_TMS, Q1_SHIHEAD_TMS, Q2_SHIHEAD_TMS                   : std_logic;


  signal C_DHEADEN, CLR_DHEADEN, DHEADEN                                  : std_logic;
  signal SHDHEAD                                                          : std_logic;
  signal CE_DONEDHEAD                                                     : std_logic;
  signal R_DONEDHEAD, Q_DONEDHEAD, CEO_DONEDHEAD, TC_DONEDHEAD, DONEDHEAD : std_logic;
  signal QV_DONEDHEAD                                                     : std_logic_vector(3 downto 0);
  signal Q3_SHDHEAD_TMS, Q4_SHDHEAD_TMS, Q5_SHDHEAD_TMS                   : std_logic;
  signal CE_SHDHEAD_TMS, Q1_SHDHEAD_TMS, Q2_SHDHEAD_TMS                   : std_logic;
  signal C_DONEDHEAD                                                      : std_logic;


  signal SHDATA, SHDATAX, CE_SHIFT1 : std_logic;


  signal DV_DONEDATA, QV_DONEDATA                                          : std_logic_vector(3 downto 0);
  signal CE_DONEDATA, CLR_DONEDATA, UP_DONEDATA, CEO_DONEDATA, TC_DONEDATA : std_logic;
  signal D_DONEDATA                                                        : std_logic;
  signal DONEDATA                                                          : std_logic_vector(1 downto 0) := (others => '0');


  signal CE_TAILEN, CLR_TAILEN, CLR_TAILEN_Q, TAILEN : std_logic;
  signal SHTAIL                                      : std_logic;
  signal CE_DONETAIL, CLR_DONETAIL, Q_DONETAIL       : std_logic;
  signal CEO_DONETAIL, TC_DONETAIL, C_DONETAIL       : std_logic;
  signal QV_DONETAIL                                 : std_logic_vector(3 downto 0);
  signal DONETAIL                                    : std_logic;
  signal CE_SHTAIL_TMS, Q1_SHTAIL_TMS, Q2_SHTAIL_TMS : std_logic;


  signal CE_TCK_GLOBAL, D_TCK_GLOBAL, TCK_GLOBAL: std_logic;

  signal D1_RESETJTAG, Q1_RESETJTAG, Q2_RESETJTAG        : std_logic;
  signal Q3_RESETJTAG, CLR_RESETJTAG, RESETJTAG          : std_logic;
  signal OKRST, INITJTAGS_Q, INITJTAGS_QQ, INITJTAGS_QQQ : std_logic;
  signal CLR_RESETJTAG_PULSE : std_logic := '0';
  signal rst_init : std_logic := '0';

  signal CLR_RESETDONE, CEO_RESETDONE, TC_RESETDONE : std_logic;
  signal QV_RESETDONE                               : std_logic_vector(3 downto 0);
  signal RESETDONE                                  : std_logic;


  signal CE_RESETJTAG_TMS, Q1_RESETJTAG_TMS, Q2_RESETJTAG_TMS                   : std_logic;
  signal Q3_RESETJTAG_TMS, Q4_RESETJTAG_TMS, Q5_RESETJTAG_TMS, Q6_RESETJTAG_TMS : std_logic;


  signal CE_TDI : std_logic;
  signal QV_TDI : std_logic_vector(15 downto 0);

  signal RDTDODK                                                              : std_logic;
  signal TDO                                                                  : std_logic;
  signal Q_OUTDATA                                                            : std_logic_vector(15 downto 0);
  signal D_DTACK, CE_DTACK, CLR_DTACK, Q1_DTACK, Q2_DTACK, Q3_DTACK, Q4_DTACK : std_logic;
  signal DTACK_INNER                                                          : std_logic;

  signal strobe_slow                                                         : std_logic;

--  component ila_cfebjtag is
--    port (
--      clk    : in std_logic := 'X';
--      probe0 : in std_logic_vector(7 downto 0) := (others=> '0');
--      probe1 : in std_logic_vector(99 downto 0) := (others => '0')
--      );
--  end component;

--  signal ila_trig : std_logic_vector (7 downto 0);
--  signal ila_data : std_logic_vector (99 downto 0);

begin


-- COMMAND DECODER
  CMDDEV <= "000" & DEVICE & COMMAND & "00";
  DATASHFT <= '1' when (DEVICE = '1' and CMDDEV(7 downto 4) = x"0")  else '0';
  INSTSHFT_ARB <= '1' when (DEVICE = '1' and CMDDEV(7 downto 4) = x"3") else '0';
  INSTSHFT_SP <= '1' when (DEVICE = '1' and CMDDEV(7 downto 4) = x"4") else '0';
  INSTSHFT <= '1' when (DEVICE = '1' and (CMDDEV(7 downto 0) = x"1C" or INSTSHFT_ARB = '1' or INSTSHFT_SP = '1') ) else '0';
  READTDO  <= '1' when CMDDEV = x"1014" else '0';
  SELCFEB  <= '1' when CMDDEV = x"1020" else '0';
  READCFEB <= '1' when CMDDEV = x"1024" else '0';
  RSTJTAG  <= '1' when CMDDEV = x"1018" else '0';

-- Write SELFEB when SELCFEB=1 (The JTAG initialization should be broadcast)
  rst_init <= RST or initjtags;
  FDPE_selfeb1 : FDPE port map(D => INDATA(0), C => STROBE, CE => SELCFEB, PRE => rst_init, Q => SELFEB(1));
  FDPE_selfeb2 : FDPE port map(D => INDATA(1), C => STROBE, CE => SELCFEB, PRE => rst_init, Q => SELFEB(2));
  FDPE_selfeb3 : FDPE port map(D => INDATA(2), C => STROBE, CE => SELCFEB, PRE => rst_init, Q => SELFEB(3));
  FDPE_selfeb4 : FDPE port map(D => INDATA(3), C => STROBE, CE => SELCFEB, PRE => rst_init, Q => SELFEB(4));
  FDPE_selfeb5 : FDPE port map(D => INDATA(4), C => STROBE, CE => SELCFEB, PRE => rst_init, Q => SELFEB(5));
  FDPE_selfeb6 : FDPE port map(D => INDATA(5), C => STROBE, CE => SELCFEB, PRE => rst_init, Q => SELFEB(6));
  FDPE_selfeb7 : FDPE port map(D => INDATA(6), C => STROBE, CE => SELCFEB, PRE => rst_init, Q => SELFEB(7));

-- Syncing STROBE to SLOWCLK
  STROBE_PULSE  : PULSE2SLOW port map(DOUT => strobe_slow, CLK_DOUT => SLOWCLK, CLK_DIN => FASTCLK, RST => RST, DIN => STROBE);


-- Generate DTACK when SELCFEB=1
  D_DTACK_SELCFEB <= '1' when (STROBE = '1' and SELCFEB = '1') else '0';
  FD_selcfebdtack : FD port map(D => D_DTACK_SELCFEB, C => FASTCLK, Q => Q_DTACK_SELCFEB);
--    DTACK_INNER <= '0' when (Q_DTACK_SELCFEB='1') else 'Z'; -- BGB commented

-- Write SELFEB to OUTDATA when READCFEB=1
  OUTDATA <= "000000000" & SELFEB(7 downto 1) when (STROBE = '1' and READCFEB = '1') else (others => 'Z');


-- Generate DTACK when READCFEB=1
  D_DTACK_READCFEB <= '1' when (STROBE = '1' and READCFEB = '1') else '0';
  FD_readcfebdtack : FD port map(D => D_DTACK_READCFEB, C => FASTCLK, Q => Q_DTACK_READCFEB);
--    DTACK_INNER <= '0' when (Q_DTACK_READCFEB='1') else 'Z'; -- BGB commented

-- Generate LOAD
  D1_LOAD  <= DATASHFT or INSTSHFT;
  CLR_LOAD <= LOAD or RST;
  FDC_qload : FDC port map(D => D1_LOAD, C => STROBE, CLR => CLR_LOAD, Q => Q_LOAD);
  D2_LOAD  <= '1' when (Q_LOAD = '1' and BUSY = '0') else '0';
  FDC_load : FDC port map(D => D2_LOAD, C => SLOWCLK, CLR => RST, Q => LOAD);


-- Generate BUSY and BUSYP1
  FDC_qbusy : FDC port map(D => LOAD, C => SLOWCLK, CLR => RST, Q => Q_BUSY);
  CLR_BUSY <= '1' when ((DONEDATA(1) = '1' and (TAILEN = '0')) or RST = '1' or DONETAIL = '1') else '0';
  D_BUSY   <= '1' when (Q_BUSY = '1' or BUSY = '1')                                            else '0';
  FDC_busy : FDC port map(D => D_BUSY, C => SLOWCLK, CLR => CLR_BUSY, Q => BUSY);
  FDC_busyp1 : FDC port map(D => BUSY, C => SLOWCLK, CLR => RST, Q => BUSYP1);


-- Generate IHEADEN
-- NOTE: The old code set C_IHEADEN based on STROBE only.  The old DMB FW
-- schematics show C_IHEADEN set by STROBE and not BUSY.
-- This is old code.
--    C_IHEADEN <= '1' when (STROBE='1') else '0'; -- BGB commented
-- This is new code.
  C_IHEADEN   <= '1' when (STROBE = '1' and BUSY = '0')  else '0';  -- BGB uncommented
  CLR_IHEADEN <= '1' when (RST = '1' or DONEIHEAD = '1') else '0';
  FDCE_iheaden : FDCE port map(D => COMMAND(0), C => C_IHEADEN, CE => INSTSHFT, CLR => CLR_IHEADEN, Q => IHEADEN);

-- Generate SHIHEAD
  SHIHEAD <= '1' when (BUSY = '1' and IHEADEN = '1') else '0';


-- Generate DONEIHEAD
  R_DONEIHEAD <= '1' when (LOAD = '1' or RST = '1' or Q_DONEIHEAD = '1')        else '0';  -- Bug in FG Version (missing else '0')
  CB4RE(SLOWCLK, SHIHEAD, R_DONEIHEAD, QV_DONEIHEAD, QV_DONEIHEAD, CEO_DONEIHEAD, TC_DONEIHEAD);
  DONEIHEAD   <= '1' when ((QV_DONEIHEAD(1) = '1') and (QV_DONEIHEAD(3) = '1')) else '0';
  FD_qdoneihead : FD port map(D => DONEIHEAD, C => SLOWCLK, Q => Q_DONEIHEAD);


-- Generate TMS when SHIHEAD=1
  TMS <= tms_inner;
  CE_SHIHEAD_TMS <= '1'            when ((SHIHEAD = '1') and (TCK_GLOBAL = '1')) else '0';
  FDCE_q1shiheadtms : FDCE port map(D => Q5_SHIHEAD_TMS, C => SLOWCLK, CE => CE_SHIHEAD_TMS, CLR => RST, Q => Q1_SHIHEAD_TMS);
  FDCE_q2shiheadtms : FDCE port map(D => Q1_SHIHEAD_TMS, C => SLOWCLK, CE => CE_SHIHEAD_TMS, CLR => RST, Q => Q2_SHIHEAD_TMS);
  FDPE_q3shiheadtms : FDPE port map(D => Q2_SHIHEAD_TMS, C => SLOWCLK, CE => CE_SHIHEAD_TMS, PRE => RST, Q => Q3_SHIHEAD_TMS);
  FDPE_q4shiheadtms : FDPE port map(D => Q3_SHIHEAD_TMS, C => SLOWCLK, CE => CE_SHIHEAD_TMS, PRE => RST, Q => Q4_SHIHEAD_TMS);
  FDCE_q5shiheadtms : FDCE port map(D => Q4_SHIHEAD_TMS, C => SLOWCLK, CE => CE_SHIHEAD_TMS, CLR => RST, Q => Q5_SHIHEAD_TMS);  -- Bug in FG Version (FDCE replaces FDPE)
  tms_inner            <= Q5_SHIHEAD_TMS when (SHIHEAD = '1')                      else 'Z';  -- Bug in FG Version (Q5_SHDHEAD_TMS replaces '1')

-- generate DHEADEN
-- NOTE: The old code set C_DHEADEN based on STROBE only.  The old DMB FW
-- schematics show C_DHEADEN set by STROBE and not BUSY.
-- This is old code.
--    C_DHEADEN <= '1' when (STROBE='1') else '0'; -- BGB commented out
-- This is new code.
  C_DHEADEN   <= '1' when (STROBE = '1' and BUSY = '0')  else '0';  -- BGB uncommented
  CLR_DHEADEN <= '1' when (RST = '1' or DONEDHEAD = '1') else '0';
  FDCE_dheaden : FDCE port map(D => COMMAND(0), C => C_DHEADEN, CE => DATASHFT, CLR => CLR_DHEADEN, Q => DHEADEN);  -- Bug in FG Version (DATASHFT replaces INSTSHFT)


-- Generate SHDHEAD
  SHDHEAD <= '1' when (BUSY = '1' and DHEADEN = '1') else '0';
  CE_DONEDHEAD  <= '1' when (SHDHEAD = '1' and TCK_GLOBAL = '1') else '0';


-- Generate DONEDHEAD
  R_DONEDHEAD <= '1' when (LOAD = '1' or RST = '1' or Q_DONEDHEAD = '1')       else '0';
  CB4RE(SLOWCLK, CE_DONEDHEAD, R_DONEDHEAD, QV_DONEDHEAD, QV_DONEDHEAD, CEO_DONEDHEAD, TC_DONEDHEAD);
  DONEDHEAD   <= '1' when ((QV_DONEDHEAD(0) = '1') and (QV_DONEDHEAD(1) = '1')) else '0';
  C_DONEDHEAD <= SLOWCLK;
  FD_qdonedhead : FD port map(D => DONEDHEAD, C => C_DONEDHEAD, Q => Q_DONEDHEAD);


-- Generate TMS when SHDHEAD=1
  CE_SHDHEAD_TMS <= '1' when ((SHDHEAD = '1') and (TCK_GLOBAL = '1') ) else '0';
  SET_DHEAD_RST : PULSE2SAME port map(DOUT => RST_DHEAD, CLK_DOUT => FASTCLK, RST => RST, DIN => DONEDHEAD); -- TRY reset using fastCLT

  RST_HEAD <= RST or RST_DHEAD;
  FDCE_q1shdheadtms : FDCE port map(D => Q4_SHDHEAD_TMS, C => SLOWCLK, CE => CE_SHDHEAD_TMS, CLR => RST_HEAD, Q => Q1_SHDHEAD_TMS); --Q2 to Q3
  FDCE_q2shdheadtms : FDCE port map(D => Q1_SHDHEAD_TMS, C => SLOWCLK, CE => CE_SHDHEAD_TMS, CLR => RST_HEAD, Q => Q2_SHDHEAD_TMS);
  FDPE_q3shdheadtms : FDPE port map(D => Q2_SHDHEAD_TMS, C => SLOWCLK, CE => CE_SHDHEAD_TMS, PRE => RST_HEAD, Q => Q3_SHDHEAD_TMS);
  FDCE_q4shdheadtms : FDCE port map(D => Q3_SHDHEAD_TMS, C => SLOWCLK, CE => CE_SHDHEAD_TMS, CLR => RST_HEAD, Q => Q4_SHDHEAD_TMS); --Q2 to Q3

--  FDCE(Q3_SHDHEAD_TMS, SLOWCLK, CE_SHDHEAD_TMS, RST_HEAD, Q4_SHDHEAD_TMS);
  tms_inner            <= Q3_SHDHEAD_TMS when (SHDHEAD = '1')                      else 'Z';  -- Bug in FG Version (Q5_SHDHEAD_TMS replaces '1')

-- Generate SHDATA and SHDATAX
  SHDATA  <= '1' when (BUSY = '1' and DHEADEN = '0' and IHEADEN = '0' and DONEDATA(1) = '0') else '0';
  SHDATAX <= '1' when (BUSY = '1' and DHEADEN = '0' and IHEADEN = '0' and DONEDATA(1) = '0') else '0';


-- Generate DONEDATA
  DV_DONEDATA  <= COMMAND(9 downto 6);
  CE_DONEDATA  <= '1' when (SHDATA = '1' and TCK_GLOBAL = '1')                       else '0';
  CLR_DONEDATA <= '1' when (RST = '1' or DONEDATA(1) = '1' or DONEDATA(0) = '1') else '0';
  UP_DONEDATA  <= '0';                  -- connected to GND
  CB4CLED(SLOWCLK, CE_DONEDATA, CLR_DONEDATA, LOAD, UP_DONEDATA, DV_DONEDATA, QV_DONEDATA, QV_DONEDATA, CEO_DONEDATA, TC_DONEDATA);  -- Bug in FG Version (DV_DONEDATA vs D_DONEDATA)
  D_DONEDATA   <= '1' when (QV_DONEDATA = "0000" and LOAD = '0')                 else '0';  -- Bug in FG Version (D_DONEDATA vs (DONEDATA(1))
  FDCE_donedata0 : FDCE port map(D => D_DONEDATA, C => SLOWCLK, CE => SHDATA, CLR => LOAD, Q => DONEDATA(0));  -- Bug in FG Version (D_DONEDATA vs (DONEDATA(1))
  FDC_donedata1 : FDC port map(D => DONEDATA(0), C => SLOWCLK, CLR => LOAD, Q => DONEDATA(1));
  --FDC(DONEDATA(1), SLOWCLK, LOAD, DONEDATA(2));


-- Generate TMS when SHDATA=1 -- Guido - BUG!!!!!!!!!!
  tms_inner <= (TAILEN and D_DONEDATA) when (SHDATA = '1') else 'Z';  -- Bug in FG Version (D2_DONEDATA replaces DONEDATA(1))

-- Generate TAILEN
  CE_TAILEN  <= '1' when (INSTSHFT = '1' or DATASHFT = '1') else '0';
  CLR_TAILEN <= '1' when (RST = '1' or DONETAIL = '1')      else '0';
  FD_clrtailenq : FD port map(D => CLR_TAILEN, C => SLOWCLK, Q => CLR_TAILEN_Q);
  FDCE_tailen : FDCE port map(D => COMMAND(1), C => LOAD, CE => CE_TAILEN, CLR => CLR_TAILEN, Q => TAILEN);

-- Generate SHTAIL
  SHTAIL <= '1' when (BUSY = '1' and DONEDATA(1) = '1' and TAILEN = '1') else '0';
  FDCE_tailsp : FDCE port map(D => INSTSHFT_SP, C => LOAD, CE => CE_TAILEN, CLR => RST_ITAIL, Q => TAILSP);
  TAILSP_B <= not TAILSP;
  SET_ITAIL_RST : PULSE2SAME port map(DOUT => RST_ITAIL, CLK_DOUT => SLOWCLK, RST => RST, DIN => TAILSP_B);

-- Generate DONETAIL
-- NOTE: I think there was a bug in the old FW.  SLOWCLK was passed to FD_1, it
-- should be not SLOWCLK based on the OLD DMB FW schematics
  CE_DONETAIL  <= '1' when (SHTAIL = '1' and TCK_GLOBAL = '1') else '0';
  CLR_DONETAIL <= '1' when (RST = '1' or Q_DONETAIL = '1') else '0';
  CB4CE(SLOWCLK, CE_DONETAIL, CLR_DONETAIL, QV_DONETAIL, QV_DONETAIL, CEO_DONETAIL, TC_DONETAIL);
  DONETAIL     <= QV_DONETAIL(0) when (TAILSP = '1') else QV_DONETAIL(1);
-- This is old code.
  C_DONETAIL   <= SLOWCLK;              -- Bug in FG Version (old code was ok)
-- This is new code;
--  C_DONETAIL <= not SLOWCLK;    
  FD_1_qdonetail : FD_1 port map(D => DONETAIL, C => C_DONETAIL, Q => Q_DONETAIL);


-- Generate TMS when SHTAIL=1
  CE_SHTAIL_TMS <= '1'           when ((SHTAIL = '1') and (TCK_GLOBAL = '1')) else '0';
  RST_TAIL <=  RST or RST_ITAIL; --'1'               when (RST = '1' or RST_ITAIL = '1') else '0';
  FDCE_q1shtailtms : FDCE port map(D => Q2_SHTAIL_TMS, C => SLOWCLK, CE => CE_SHTAIL_TMS, CLR => RST_TAIL, Q => Q1_SHTAIL_TMS);
  FDPE_q2shtailtms : FDPE port map(D => Q1_SHTAIL_TMS, C => SLOWCLK, CE => CE_SHTAIL_TMS, PRE => RST_TAIL, Q => Q2_SHTAIL_TMS);
-- This code from Frank.
--  tms_inner <= '1' when (SHTAIL = '1') else 'Z';
-- This code from Guido.
  tms_inner           <= Q2_SHTAIL_TMS when (SHTAIL = '1')                      else 'Z';


-- Generate ENABLE
  CE_TCK_GLOBAL <= '1' when (RESETJTAG = '1' or BUSY = '1') else '0';
  D_TCK_GLOBAL  <= not TCK_GLOBAL;
  FDCE_tckglobal : FDCE port map(D => D_TCK_GLOBAL, C => SLOWCLK, CE => CE_TCK_GLOBAL, CLR => RST, Q => TCK_GLOBAL);


-- Generate RESETJTAG and OKRST 
  -- INITJTAGS comes from odmb_ucsb_v2 when the DCFEBs DONE bits go high
  FDC_initjtagsq : FDC port map(D => INITJTAGS, C => SLOWCLK, CLR => RST, Q => INITJTAGS_Q);
  FDC_initjtagsqq : FDC port map(D => INITJTAGS_Q, C => SLOWCLK, CLR => RST, Q => INITJTAGS_QQ);
  FDC_initjtagsqqq : FDC port map(D => INITJTAGS_QQ, C => SLOWCLK, CLR => RST, Q => INITJTAGS_QQQ);
  D1_RESETJTAG  <= '1' when ((STROBE = '1' and RSTJTAG = '1') or INITJTAGS = '1') else '0';
  FDC_q1resetjtag : FDC port map(D => D1_RESETJTAG, C => SLOWCLK, CLR => RST, Q => Q1_RESETJTAG);
  FDC_q2resetjtag : FDC port map(D => Q1_RESETJTAG, C => SLOWCLK, CLR => RST, Q => Q2_RESETJTAG);
  OKRST         <= '1' when (Q1_RESETJTAG = '1' and Q2_RESETJTAG = '1')           else '0';
  CLR_RESETJTAG <= '1' when (RESETDONE = '1' or RST = '1')                        else '0';
  FDC_q3resetjtag : FDCE port map(D => LOGICH, C => SLOWCLK, CE => OKRST, CLR => CLR_RESETJTAG, Q => Q3_RESETJTAG);
  FDC_resetjtag : FDC port map(D => Q3_RESETJTAG, C => SLOWCLK, CLR => CLR_RESETJTAG, Q => RESETJTAG);


-- Generate RESETDONE 
  -- PULSE2SLOW only works if the signal is 1 CC long in the original clock domain
  RESETJTAG_PULSE  : PULSE2FAST port map(DOUT => CLR_RESETJTAG_PULSE, CLK_DOUT => FASTCLK, RST => '0', DIN => CLR_RESETJTAG);
  RESETDONE_PULSE  : PULSE2SLOW port map(DOUT => CLR_RESETDONE, CLK_DOUT => SLOWCLK, CLK_DIN => FASTCLK, RST => '0', DIN => CLR_RESETJTAG_PULSE);
  CB4CE(SLOWCLK, RESETJTAG, CLR_RESETDONE, QV_RESETDONE, QV_RESETDONE, CEO_RESETDONE, TC_RESETDONE);
  RESETDONE     <= '1' when (QV_RESETDONE(2) = '1' and QV_RESETDONE(3) = '1') else '0';


-- Generate DTACK when RESETDONE=1 AND INITJTAGS=0
--    DTACK_INNER <= '0' when (RESETDONE='1' and INITJTAGS='0') else 'Z'; -- bgb commented out

-- Generate tms_inner when RESETJTAG=1
  CE_RESETJTAG_TMS <= (RESETJTAG and TCK_GLOBAL);
  FDCE_q1resetjtagtms : FDCE port map(D => Q6_RESETJTAG_TMS, C => SLOWCLK, CE => CE_RESETJTAG_TMS, CLR => RST, Q => Q1_RESETJTAG_TMS);
  FDPE_q2resetjtagtms : FDPE port map(D => Q1_RESETJTAG_TMS, C => SLOWCLK, CE => CE_RESETJTAG_TMS, PRE => RST, Q => Q2_RESETJTAG_TMS);
  FPDE_q3resetjtagtms : FDPE port map(D => Q2_RESETJTAG_TMS, C => SLOWCLK, CE => CE_RESETJTAG_TMS, PRE => RST, Q => Q3_RESETJTAG_TMS);
  FDPE_q4resetjtagtms : FDPE port map(D => Q3_RESETJTAG_TMS, C => SLOWCLK, CE => CE_RESETJTAG_TMS, PRE => RST, Q => Q4_RESETJTAG_TMS);
  FDPE_q5resetjtagtms : FDPE port map(D => Q4_RESETJTAG_TMS, C => SLOWCLK, CE => CE_RESETJTAG_TMS, PRE => RST, Q => Q5_RESETJTAG_TMS);
  FDPE_q6resetjtagtms : FDPE port map(D => Q5_RESETJTAG_TMS, C => SLOWCLK, CE => CE_RESETJTAG_TMS, PRE => RST, Q => Q6_RESETJTAG_TMS);
  tms_inner              <= Q6_RESETJTAG_TMS when (RESETJTAG = '1') else 'Z';  -- BGB

-- Generate TCK
  TCK(1) <= TCK_GLOBAL when SELFEB(1)='1' else '0';
  TCK(2) <= TCK_GLOBAL when SELFEB(2)='1' else '0';
  TCK(3) <= TCK_GLOBAL when SELFEB(3)='1' else '0';
  TCK(4) <= TCK_GLOBAL when SELFEB(4)='1' else '0';
  TCK(5) <= TCK_GLOBAL when SELFEB(5)='1' else '0';
  TCK(6) <= TCK_GLOBAL when SELFEB(6)='1' else '0';
  TCK(7) <= TCK_GLOBAL when SELFEB(7)='1' else '0';
  --TCK(7) <= SELFEB(7) and TCK_GLOBAL;


-- Generate TDI
  TDI <= tdi_inner;
  CE_TDI <= (SHDATA and TCK_GLOBAL);
  SR16CLRE(SLOWCLK, CE_TDI, RST, LOAD, QV_TDI(0), INDATA, QV_TDI, QV_TDI);
  tdi_inner    <= QV_TDI(0);


-- Generate TDO
  TDO <= FEBTDO(1) when SELFEB = "0000001" else
         FEBTDO(2) when SELFEB = "0000010" else
         FEBTDO(3) when SELFEB = "0000100" else
         FEBTDO(4) when SELFEB = "0001000" else
         FEBTDO(5) when SELFEB = "0010000" else
         FEBTDO(6) when SELFEB = "0100000" else
         FEBTDO(7) when SELFEB = "1000000" else
-- This is old code.
         '0';  -- BGB This is a mux now not multiple drivers
-- This is new code.           
--           'Z'; 

-- Generate RDTDODK
  RDTDODK <= '1' when (STROBE = '1' and READTDO = '1' and BUSYP1 = '0' and BUSY = '0') else '0';


-- Generate DTACK when RDTDODK=1-- generate DTACK when RDTDODK=1

--    DTACK_INNER <= '0' when (RDTDODK='1') else 'Z'; -- BGB commented out

-- Generate OUTDATA
  CE_SHIFT1            <= SHDATAX and not TCK_GLOBAL;               -- BGB
  SR16LCE(SLOWCLK, CE_SHIFT1, RST, TDO, Q_OUTDATA, Q_OUTDATA);  -- BGB
  OUTDATA(15 downto 0) <= Q_OUTDATA(15 downto 0) when (RDTDODK = '1') else "ZZZZZZZZZZZZZZZZ";

--BGB commented out
-- Generate DTACK when DATASHFT=1 or INSTSHFT=1
--    D_DTACK <= (DATASHFT or INSTSHFT);   
--    CE_DTACK <= not BUSY;
--    CLR_DTACK <= not STROBE;
--    FDCE(D_DTACK, SLOWCLK, CE_DTACK, CLR_DTACK, Q1_DTACK);
--    FDCE(Q1_DTACK, SLOWCLK, CE_DTACK, CLR_DTACK, Q2_DTACK);
--    FDCE(Q2_DTACK, SLOWCLK, CE_DTACK, CLR_DTACK, Q3_DTACK);
--    FDCE(Q3_DTACK, SLOWCLK, CE_DTACK, CLR_DTACK, Q4_DTACK);
--       DTACK_INNER <= '0' when (Q3_DTACK='1' and Q4_DTACK='1') else 'Z';

-- BGB back to old DMB logic
  D_DTACK   <= (DATASHFT or INSTSHFT);
  CE_DTACK  <= not BUSY;
  CLR_DTACK <= not STROBE;
  FDCE_q1dtack : FDCE port map(D => D_DTACK, C => SLOWCLK, CE => CE_DTACK, CLR => CLR_DTACK, Q => Q1_DTACK);
  FDC_q2dtack : FDC port map(D => Q1_DTACK, C => SLOWCLK, CLR => CLR_DTACK, Q => Q2_DTACK);
  FD_q3dtack : FD port map(D => Q2_DTACK, C => SLOWCLK, Q => Q3_DTACK);
  FD_q4dtack : FD port map(D => Q3_DTACK, C => SLOWCLK, Q => Q4_DTACK);

-- BGB
  DTACK_INNER <= '1' when (Q_DTACK_SELCFEB = '1') or
                 (Q_DTACK_READCFEB = '1') or
                 (RESETDONE = '1' and INITJTAGS_QQQ = '0') or
                 (RDTDODK = '1') or
                 (Q1_DTACK = '1' and Q2_DTACK = '1' and Q3_DTACK = '1' and Q4_DTACK = '1') else '0';
                                        -- BGB

-- DTACK_INNER ----> DTACK
  DTACK <= DTACK_INNER;


-- Generate LED.
  LED <= CE_SHIHEAD_TMS;  


-- generate DIAGOUT
  DIAGOUT(0)  <= '0';
  DIAGOUT(1)  <= Q_LOAD;
  DIAGOUT(2)  <= '0';
  DIAGOUT(3)  <= CLR_BUSY;
  DIAGOUT(4)  <= '0';
  DIAGOUT(5)  <= DONETAIL;
  DIAGOUT(6)  <= DONEDATA(1);
  DIAGOUT(7)  <= QV_DONEDATA(0);
  DIAGOUT(8) <= QV_DONETAIL(0);
  DIAGOUT(9) <= '0';
  DIAGOUT(10) <= CE_SHIFT1;
  DIAGOUT(11) <= STROBE;
  DIAGOUT(12) <= TDO;
  DIAGOUT(13) <= LOAD;
  DIAGOUT(14)  <= BUSY;
  DIAGOUT(15)  <= BUSYP1;
  DIAGOUT(16)  <= READTDO;
  DIAGOUT(17)  <= RDTDODK;
  

--  DIAGOUT(0)  <= LOAD;
--  DIAGOUT(1)  <= TCK_GLOBAL;
--  DIAGOUT(2)  <= BUSY;
--  DIAGOUT(3)  <= RDTDODK;
--  DIAGOUT(4)  <= QV_DONEIHEAD(3);
--  DIAGOUT(5)  <= Q1_SHIHEAD_TMS;
--  DIAGOUT(6)  <= RESETJTAG;
--  DIAGOUT(7)  <= SHDATAX;
--  --DIAGOUT(8)  <= SLOWCLK;
--  DIAGOUT(8)  <= CE_TCK_GLOBAL;
--  DIAGOUT(9)  <= READTDO;
--  DIAGOUT(10) <= RSTJTAG;
--  DIAGOUT(11) <= DHEADEN;
--  DIAGOUT(12) <= IHEADEN;
--  DIAGOUT(13) <= DONEDATA(1);
--  DIAGOUT(14) <= SHIHEAD;
--  DIAGOUT(15) <= DONEIHEAD;
--  DIAGOUT(16) <= SELCFEB;
--  DIAGOUT(17) <= DEVICE;

--  i_ila_cfebjtag : ila_cfebjtag
--     port map (
--       clk => FASTCLK,   -- to use the fastest clock here
--       probe0 => ila_trig,
--       probe1 => ila_data
--       );

--  ila_trig <= "0000000" & DEVICE;
--  ila_data <= FEBTDO	                                                          -- [7]    (99:93)
--            & LOAD & TCK_GLOBAL & tdi_inner & tms_inner                           -- [1]    (92:89)
--            & RST & RST_ITAIL & READTDO  & RDTDODK         	                  -- [1]    (88:85)
--            & SHDHEAD & DONEDHEAD & SHIHEAD & DONEIHEAD & DHEADEN  & IHEADEN      -- [1]    (84:79)
--            & SHTAIL  & DONETAIL  & TAILSP  & TAILEN    & CE_TAILEN & CLR_TAILEN  -- [1]    (78:73)
--            & Q1_DTACK & Q2_DTACK & Q3_DTACK & Q4_DTACK                           -- [1]    (72:69)
--            & Q1_SHIHEAD_TMS & Q2_SHIHEAD_TMS & Q3_SHIHEAD_TMS                    -- [1]    (68:64)
--            & Q4_SHIHEAD_TMS & Q5_SHIHEAD_TMS
--            & Q1_SHDHEAD_TMS & Q2_SHDHEAD_TMS & Q3_SHDHEAD_TMS                    -- [1]    (63:59)
--            & Q4_SHDHEAD_TMS & Q5_SHDHEAD_TMS
--            & Q1_RESETJTAG_TMS & Q2_RESETJTAG_TMS & Q3_RESETJTAG_TMS              -- [1]    (58:53)
--            & Q4_RESETJTAG_TMS & Q5_RESETJTAG_TMS & Q6_RESETJTAG_TMS
--            & Q1_RESETJTAG & Q2_RESETJTAG & Q3_RESETJTAG                          -- [1]    (52:50)
--            & Q1_SHTAIL_TMS & Q2_SHTAIL_TMS                                       -- [1]    (49:48)
--            & QV_DONEDATA & QV_DONETAIL                                           -- [4/4]  (47:40)
--            & QV_DONEIHEAD & QV_DONEDHEAD                                         -- [4/4]  (39:32)
--            & READTDO & SELCFEB & READCFEB & RSTJTAG                              -- [1]    (31:28)
--            & DATASHFT & INSTSHFT_ARB & INSTSHFT_SP & INSTSHFT                    -- [1]    (27:24)
--            & BUSY & SELFEB                                                       -- [1/7]  (23:16)
--            & CMDDEV;                                                             -- [16]   (15:0)


end CFEBJTAG_Arch;
