library ieee;
library work;
library unisim;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use work.ucsb_types.all;
use unisim.vcomponents.all;

--! @brief TRGCNTRL: Applies LCT_L1A_DLY to RAW_LCT[7:1] to sync it with L1A and produce L1A_MATCH[7:1]
--! It also generates the PUSH that load the FIFOs/RAM in TRGFIFO
--! @details
entity TRGCNTRL is
  generic (
    NCFEB : integer range 1 to 7 := 7                         --! Number of DCFEBS, 7/5 
    );  
  port (
    CLK           : in std_logic;                             --! 40.079 MHz CMSCLK
    RAW_L1A       : in std_logic;                             --! L1A from VMEMON (delayed LCT) or CCB
    RAW_LCT       : in std_logic_vector(NCFEB downto 0);      --! LCT from VMEMON or OTMB
    CAL_LCT       : in std_logic;                             --! Calibration LCT (currently 0)
    CAL_L1A       : in std_logic;                             --! Calibration L1A (currently 0)
    LCT_L1A_DLY   : in std_logic_vector(5 downto 0);          --! LCT->L1A delay from VMECONFREGS
    OTMB_PUSH_DLY : in integer range 0 to 63;                 --! OTMBDAV->Fifo push delay (VMECONFREGS)
    ALCT_PUSH_DLY : in integer range 0 to 63;                 --! ALCTDAV->Fifo push delay (VMECONFREGS)
    PUSH_DLY      : in integer range 0 to 63;                 --! , currently hardcoded to 63
    ALCT_DAV      : in std_logic;                             --! LEGACY_ALCT_DAV from OTMB or VMEMON
    OTMB_DAV      : in std_logic;                             --! OTMB_DAV from OTMB or VMEMON

    CAL_MODE      : in std_logic;                             --! From VMEMON, causes L1A from INJPLS
    KILL          : in std_logic_vector(NCFEB+2 downto 1);    --! KILL mask from VMEMON
    PEDESTAL      : in std_logic;                             --! VMEMON's ODMB_PED(0)
    PEDESTAL_OTMB : in std_logic;                             --! VMEMON's ODMB_PED(1)

    ALCT_DAV_SYNC_OUT : out std_logic;                        --! ALCT_DAV delayed to FIFO push
    OTMB_DAV_SYNC_OUT : out std_logic;                        --! OTMB_DAV delayed to FIFO push

    DCFEB_L1A       : out std_logic;                          --! RAW_L1A delayed 1 clock cycle
    DCFEB_L1A_MATCH : out std_logic_vector(NCFEB downto 1);   --! L1A_MATCH to DCFEBs when L1A+LCT coin.
    FIFO_PUSH       : out std_logic;                          --! FIFO push signal
    FIFO_L1A_MATCH  : out std_logic_vector(NCFEB+2 downto 0); --! L1A_MATCHes/DAVs delayed to FIFO push
    LCT_ERR         : out std_logic;                          --! Debug error signal

    DIAGOUT         : out std_logic_vector(26 downto 0)       --! Debug signals
    );

end TRGCNTRL;

architecture TRGCNTRL_Arch of TRGCNTRL is

  signal DLY_LCT, LCT, LCT_IN : std_logic_vector(NCFEB downto 0);
  signal RAW_L1A_Q, L1A_IN    : std_logic;
  signal L1A                  : std_logic;
  type   LCT_TYPE is array (NCFEB downto 1) of std_logic_vector(4 downto 0);
  signal LCT_Q                : LCT_TYPE;
  signal LCT_ERR_D            : std_logic;
  signal L1A_MATCH            : std_logic_vector(NCFEB downto 1);
  signal FIFO_L1A_MATCH_INNER : std_logic_vector(NCFEB+2 downto 0);

  signal otmb_dav_sync, alct_dav_sync   : std_logic;
  signal fifo_push_inner                : std_logic;
  signal push_otmb_diff, push_alct_diff : integer range 0 to 63;

  signal ila_data : std_logic_vector(127 downto 0);

  constant alct_push_dly_cnst  : integer := 33;
  constant otmb_push_dly_cnst  : integer := 3;
  constant lct_l1a_dly_cnst    : std_logic_vector(5 downto 0) := "100110"; -- 0x26 = 38

begin  --Architecture

  -- Delay LCT signals (signs of a local muon) to account for for L1 trigger latency
  -- Generate DLY_LCT (delayed LCT signals)
  LCT_IN <= (others => CAL_LCT) when (CAL_MODE = '1') else RAW_LCT;
  GEN_DLY_LCT : for K in 0 to NCFEB generate
  begin
    LCTDLY_K : LCTDLY port map(DOUT => DLY_LCT(K), CLK => CLK, DELAY => LCT_L1A_DLY, DIN => LCT_IN(K));
  end generate GEN_DLY_LCT;

  -- Generate LCT (DLY_LCT with KILL mask applied)
  LCT(0) <= DLY_LCT(0);
  GEN_LCT : for K in 1 to ncfeb generate
  begin
    LCT(K) <= '0' when (KILL(K) = '1') else DLY_LCT(K);
  end generate GEN_LCT;

  -- Generate LCT_ERR (sent to an LED for debugging in ODMB2014, currently unused)
  LCT_ERR_D <= LCT(0) xor or_reduce(LCT(NCFEB downto 1));
  FDLCTERR : FD port map (Q => LCT_ERR, C => CLK, D => LCT_ERR_D);

  -- Generate L1A / Generate DCFEB_L1A (RAW_L1A delayed 1 clock cycle)
  L1A_IN <= CAL_L1A when CAL_MODE = '1' else RAW_L1A;
  FDL1A : FD port map (Q => RAW_L1A_Q, C => CLK, D => L1A_IN);
  L1A       <= RAW_L1A_Q;
  DCFEB_L1A <= L1A;

  -- Generate DCFEB_L1A_MATCH
  -- L1A_MATCH is set by looking for a coincidence between L1A and delayed LCTs in a 4 CMSCLK
  -- cycle window (or if PEDESTAL is set to 1, L1A_MATCH always generated)
  GEN_L1A_MATCH : for K in 1 to NCFEB generate
  begin
    LCT_Q(K)(0) <= LCT(K);
    GEN_LCT_Q : for H in 1 to 4 generate
    begin
      FD_H : FD port map (Q => LCT_Q(K)(H), C => CLK, D => LCT_Q(K)(H-1));
    end generate GEN_LCT_Q;
    L1A_MATCH(K) <= '1' when (L1A = '1' and KILL(K) = '0' and (LCT_Q(K) /= "00000" or PEDESTAL = '1')) else '0';
  end generate GEN_L1A_MATCH;
  DCFEB_L1A_MATCH <= L1A_MATCH(NCFEB downto 1);

  -- Generate FIFO_PUSH, FIFO_L1A_MATCH - All signals are pushed a total of ALCT_PUSH_DLY
  -- A delay of push_dly after L1A, generate fifo_push signals
  DS_L1A_PUSH : DELAY_SIGNAL port map(fifo_push_inner, clk, push_dly, l1a);

  --delay fifo_l1a_match from l1a_match by push_dly
  GEN_L1A_MATCH_PUSH_DLY : for K in 1 to NCFEB generate
  begin
    DS_L1AMATCH_PUSH : DELAY_SIGNAL port map(fifo_l1a_match_inner(K), clk, push_dly, l1a_match(K));
  end generate GEN_L1A_MATCH_PUSH_DLY;

  --delay OTMBDAV and ALCTDAV by push_dly-otmb_push_dly/alct_push_dly so that all signals are synced
  --for FIFO push
  --also, fifo_l1a_match(NCFEB+1) is delayed OTMBDAV, fifo_l1a_match(NCFEB+2) is ALCTDAV, and
  --fifo_l1a_match(0) is or of all other bits
  push_otmb_diff <= push_dly-otmb_push_dly when push_dly > otmb_push_dly else 0;
  DS_OTMB_PUSH : DELAY_SIGNAL port map(otmb_dav_sync, clk, push_otmb_diff, otmb_dav);
  fifo_l1a_match_inner(NCFEB+1) <= (otmb_dav_sync or pedestal_otmb) and fifo_push_inner and not kill(NCFEB+1);

  push_alct_diff <= push_dly-alct_push_dly when push_dly > alct_push_dly else 0;
  DS_ALCT_PUSH : DELAY_SIGNAL port map(alct_dav_sync, clk, push_alct_diff, alct_dav);
  fifo_l1a_match_inner(NCFEB+2) <= (alct_dav_sync or pedestal_otmb) and fifo_push_inner and not kill(NCFEB+2);

  fifo_l1a_match_inner(0) <= or_reduce(fifo_l1a_match_inner(NCFEB+2 downto 1));

  FIFO_PUSH      <= fifo_push_inner;
  FIFO_L1A_MATCH <= fifo_l1a_match_inner;

  OTMB_DAV_SYNC_OUT <= otmb_dav_sync;
  ALCT_DAV_SYNC_OUT <= alct_dav_sync;

  -- ila_data(3 downto 0)   <= otmb_dav & alct_dav & raw_lct(0) & raw_l1a; -- raw signal
  -- ila_data(18 downto 12) <= raw_lct(7 downto 1);
  -- ila_data(55 downto 51) <= LCT_Q(1);
  -- ila_data(60 downto 56) <= LCT_Q(2);
  -- ila_data(66 downto 61) <= LCT_L1A_DLY;
  -- ila_data(72 downto 67) <= std_logic_vector(to_unsigned(OTMB_PUSH_DLY, 6));
  -- ila_data(78 downto 73) <= std_logic_vector(to_unsigned(ALCT_PUSH_DLY, 6));
  -- ila_data(84 downto 79) <= std_logic_vector(to_unsigned(PUSH_DLY, 6));

  DIAGOUT(3 downto 0)         <= otmb_dav_sync & alct_dav_sync & fifo_push_inner & l1a;
  DIAGOUT(3+NCFEB downto 4)   <= lct(NCFEB downto 1);  
  DIAGOUT(10+NCFEB downto 11) <= l1a_match(NCFEB downto 1);
  DIAGOUT(20 downto 18)       <= raw_l1a_q & l1a_in & raw_l1a;
  -- DIAGOUT(26 downto 18) <= fifo_l1a_match_inner(9 downto 1);  
  -- DIAGOUT <= ila_data;

end TRGCNTRL_Arch;
