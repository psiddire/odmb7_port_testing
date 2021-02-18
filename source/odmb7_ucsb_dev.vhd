library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library unisim;
use unisim.vcomponents.all;

--library work;
use work.ucsb_types.all;

use work.Firmware_pkg.all;     -- for switch between sim and synthesis

entity ODMB7_UCSB_DEV is
  generic (
    NREGS       : integer := 16;
    NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
  );
  PORT (
    --------------------
    -- Clocks from testbench
    --------------------
    CLK160      : in std_logic;  -- For dcfeb prbs (160MHz)
    CLK80       : in std_logic;
    CLK40       : in std_logic;  -- NEW (fastclk -> 40MHz)
    CLK10       : in std_logic;  -- NEW (midclk -> fastclk/4 -> 10MHz)

    --------------------
    -- Signals controlled by ODMB_VME
    --------------------
    VME_DATA        : inout std_logic_vector(15 downto 0); -- Bank 48
    VME_GAP_B       : in std_logic;                        -- Bank 48
    VME_GA_B        : in std_logic_vector(4 downto 0);     -- Bank 48
    VME_ADDR        : in std_logic_vector(23 downto 1);    -- Bank 46
    VME_AM          : in std_logic_vector(5 downto 0);     -- Bank 46
    VME_AS_B        : in std_logic;                        -- Bank 46
    VME_DS_B        : in std_logic_vector(1 downto 0);     -- Bank 46
    VME_LWORD_B     : in std_logic;                        -- Bank 48
    VME_WRITE_B     : in std_logic;                        -- Bank 48
    VME_IACK_B      : in std_logic;                        -- Bank 48
    VME_BERR_B      : in std_logic;                        -- Bank 48
    VME_SYSRST_B    : in std_logic;                        -- Bank 48, not used
    VME_SYSFAIL_B   : in std_logic;                        -- Bank 48
    VME_CLK_B       : in std_logic;                        -- Bank 48, not used
    KUS_VME_OE_B    : out std_logic;                       -- Bank 44
    KUS_VME_DIR     : out std_logic;                       -- Bank 44
    VME_DTACK_KUS_B : inout std_logic;                     -- Bank 44

    DCFEB_TCK_P    : out std_logic_vector(NCFEB downto 1); -- Bank 68
    DCFEB_TCK_N    : out std_logic_vector(NCFEB downto 1); -- Bank 68
    DCFEB_TMS_P    : out std_logic;                        -- Bank 68
    DCFEB_TMS_N    : out std_logic;                        -- Bank 68
    DCFEB_TDI_P    : out std_logic;                        -- Bank 68
    DCFEB_TDI_N    : out std_logic;                        -- Bank 68
    DCFEB_TDO_P    : in  std_logic_vector(NCFEB downto 1); -- Bank 67-68
    DCFEB_TDO_N    : in  std_logic_vector(NCFEB downto 1); -- Bank 67-68
    DCFEB_DONE     : in  std_logic_vector(NCFEB downto 1); -- Bank 68
    RESYNC_P       : out std_logic;                        -- Bank 66
    RESYNC_N       : out std_logic;                        -- Bank 66
    BC0_P          : out std_logic;                        -- Bank 68
    BC0_N          : out std_logic;                        -- Bank 68
    INJPLS_P       : out std_logic;                        -- Bank 66, ODMB CTRL
    INJPLS_N       : out std_logic;                        -- Bank 66, ODMB CTRL
    EXTPLS_P       : out std_logic;                        -- Bank 66, ODMB CTRL
    EXTPLS_N       : out std_logic;                        -- Bank 66, ODMB CTRL
    L1A_P          : out std_logic;                        -- Bank 66, ODMB CTRL
    L1A_N          : out std_logic;                        -- Bank 66, ODMB CTRL
    L1A_MATCH_P    : out std_logic_vector(NCFEB downto 1); -- Bank 66, ODMB CTRL
    L1A_MATCH_N    : out std_logic_vector(NCFEB downto 1); -- Bank 66, ODMB CTRL
    PPIB_OUT_EN_B  : out std_logic;                        -- Bank 68

    LVMB_PON   : out std_logic_vector(7 downto 0);
    PON_LOAD   : out std_logic;
    PON_OE_B   : out std_logic;
    R_LVMB_PON : in  std_logic_vector(7 downto 0);
    LVMB_CSB   : out std_logic_vector(6 downto 0);
    LVMB_SCLK  : out std_logic;
    LVMB_SDIN  : out std_logic;
    LVMB_SDOUT : in  std_logic;

    DCFEB_PRBS_FIBER_SEL : out std_logic_vector(3 downto 0);
    DCFEB_PRBS_EN        : out std_logic;
    DCFEB_PRBS_RST       : out std_logic;
    DCFEB_PRBS_RD_EN     : out std_logic;
    DCFEB_RXPRBSERR      : in  std_logic;
    DCFEB_PRBS_ERR_CNT   : in  std_logic_vector(15 downto 0);

    OTMB_TX : in  std_logic_vector(48 downto 0);
    OTMB_RX : out std_logic_vector(5 downto 0);

    --------------------
    -- Other
    --------------------
    DIAGOUT     : out std_logic_vector(17 downto 0); --for debugging
    RST         : in std_logic;

    --------------------------------
    -- KCU signals (not in real ODMB)
    --------------------------------
    VME_DATA_IN    : in std_logic_vector (15 downto 0); --no internal IOBUFs on KCU
    VME_DATA_OUT   : out std_logic_vector (15 downto 0) --no internal IOBUFs on KCU
    );
end ODMB7_UCSB_DEV;

architecture Behavioral of ODMB7_UCSB_DEV is
  -- Constants
  constant bw_data  : integer := 16; -- data bit width

  component ODMB_VME is
    generic (
      NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
      );
    port (
      --------------------
      -- Clock
      --------------------
      CLK160      : in std_logic;  -- For dcfeb prbs (160MHz)
      CLK40       : in std_logic;  -- NEW (fastclk -> 40MHz)
      CLK10       : in std_logic;  -- NEW (midclk -> fastclk/4 -> 10MHz)
      CLK2P5      : in std_logic;  -- 2.5 MHz clock
      CLK1P25     : in std_logic;

      --------------------
      -- VME signals  <-- relevant ones only
      --------------------
      VME_DATA_IN   : in std_logic_vector (15 downto 0);
      VME_DATA_OUT  : out std_logic_vector (15 downto 0);
      VME_GAP_B     : in std_logic;     -- Also known as GA(5)
      VME_GA_B      : in std_logic_vector (4 downto 0);
      VME_ADDR      : in std_logic_vector (23 downto 1);
      VME_AM        : in std_logic_vector (5 downto 0);
      VME_AS_B      : in std_logic;
      VME_DS_B      : in std_logic_vector (1 downto 0);
      VME_LWORD_B   : in std_logic;
      VME_WRITE_B   : in std_logic;
      VME_IACK_B    : in std_logic;
      VME_BERR_B    : in std_logic;
      VME_SYSFAIL_B : in std_logic;
      VME_DTACK_B   : inout std_logic;
      VME_OE_B      : out std_logic;
      VME_DIR_B     : out std_logic;

      --------------------
      -- JTAG Signals To/From DCFEBs
      --------------------
      DCFEB_TCK    : out std_logic_vector (NCFEB downto 1);
      DCFEB_TMS    : out std_logic;
      DCFEB_TDI    : out std_logic;
      DCFEB_TDO    : in  std_logic_vector (NCFEB downto 1);

      DCFEB_DONE     : in std_logic_vector (NCFEB downto 1);
      DCFEB_INITJTAG : in std_logic;   -- TODO: where does this fit in

      --------------------
      -- From/To LVMB: ODMB & ODMB7 design, ODMB5 to be seen
      --------------------
      LVMB_PON   : out std_logic_vector(7 downto 0);
      PON_LOAD   : out std_logic;
      PON_OE_B   : out std_logic;
      R_LVMB_PON : in  std_logic_vector(7 downto 0);
      LVMB_CSB   : out std_logic_vector(6 downto 0);
      LVMB_SCLK  : out std_logic;
      LVMB_SDIN  : out std_logic;
      LVMB_SDOUT : in  std_logic;

      --------------------
      -- TODO: DCFEB PRBS signals
      --------------------
      DCFEB_PRBS_FIBER_SEL : out std_logic_vector(3 downto 0);
      DCFEB_PRBS_EN        : out std_logic;
      DCFEB_PRBS_RST       : out std_logic;
      DCFEB_PRBS_RD_EN     : out std_logic;
      DCFEB_RXPRBSERR      : in  std_logic;
      DCFEB_PRBS_ERR_CNT   : in  std_logic_vector(15 downto 0);

      --------------------
      -- TODO: OTMB PRBS signals
      --------------------
      OTMB_TX : in  std_logic_vector(48 downto 0);
      OTMB_RX : out std_logic_vector(5 downto 0);
      
      --------------------
      -- VMEMON Configuration signals for top level
      --------------------
      FW_RESET             : out std_logic;
      L1A_RESET_PULSE      : out std_logic;
      TEST_INJ             : out std_logic;
      TEST_PLS             : out std_logic;
      TEST_BC0             : out std_logic;
      TEST_PED             : out std_logic;
      TEST_LCT             : out std_logic;
      MASK_L1A             : out std_logic_vector(NCFEB downto 0);
      MASK_PLS             : out std_logic;
      ODMB_CAL             : out std_logic;
      MUX_DATA_PATH        : out std_logic;
      MUX_TRIGGER          : out std_logic;
      MUX_LVMB             : out std_logic;
      ODMB_PED             : out std_logic_vector(1 downto 0);
      ODMB_DATA            : in std_logic_vector(15 downto 0);
      ODMB_DATA_SEL        : out std_logic_vector(7 downto 0);

      --------------------
      -- VMECONFREGS Configuration signals for top level
      --------------------
      LCT_L1A_DLY   : out std_logic_vector(5 downto 0);
      CABLE_DLY     : out integer range 0 to 1;
      OTMB_PUSH_DLY : out integer range 0 to 63;
      ALCT_PUSH_DLY : out integer range 0 to 63;
      BX_DLY        : out integer range 0 to 4095;
      INJ_DLY       : out std_logic_vector(4 downto 0);
      EXT_DLY       : out std_logic_vector(4 downto 0);
      CALLCT_DLY    : out std_logic_vector(3 downto 0);
      ODMB_ID      : out std_logic_vector(15 downto 0);
      NWORDS_DUMMY : out std_logic_vector(15 downto 0);
      KILL         : out std_logic_vector(NCFEB+2 downto 1);
      CRATEID      : out std_logic_vector(7 downto 0);
      CHANGE_REG_DATA      : in std_logic_vector(15 downto 0);
      CHANGE_REG_INDEX     : in integer range 0 to NREGS;

      --------------------
      -- Other
      --------------------
      DIAGOUT     : out std_logic_vector (17 downto 0); -- for debugging
      RST         : in std_logic;
      PON_RESET   : in std_logic
      );
  end component;

  component ODMB_CTRL is
    generic (
      NCFEB       : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
      );
    port (
      --------------------
      -- Clock
      --------------------
      CLK80       : in std_logic;
      CLK40       : in std_logic;

      --------------------
      -- ODMB VME <-> CALIBTRIG
      --------------------
      TEST_CCBINJ   : in std_logic;
      TEST_CCBPLS   : in std_logic;
      TEST_CCBPED   : in std_logic;

      --------------------
      -- Delay registers (from VMECONFREGS)
      --------------------
      LCT_L1A_DLY   : in std_logic_vector(5 downto 0);
      INJ_DLY       : in std_logic_vector(4 downto 0);
      EXT_DLY       : in std_logic_vector(4 downto 0);
      CALLCT_DLY    : in std_logic_vector(3 downto 0);

      --------------------
      -- Configuration
      --------------------
      CAL_MODE      : in std_logic;
      PEDESTAL      : in std_logic;

      --------------------
      -- Triggers
      --------------------
      RAW_L1A       : in std_logic;
      
      --------------------
      -- To/From DCFEBs (FF-EMU-MOD)
      --------------------
      DCFEB_INJPULSE  : out std_logic;
      DCFEB_EXTPULSE  : out std_logic;
      DCFEB_L1A       : out std_logic;
      DCFEB_L1A_MATCH : out std_logic_vector(NCFEB downto 1);

      --------------------
      -- Other
      --------------------
      DIAGOUT     : out std_logic_vector (17 downto 0); -- for debugging
      RST         : in std_logic
      );
  end component;


  component LCTDLY is  -- Aligns RAW_LCT with L1A by 2.4 us to 4.8 us
    port (
      DIN   : in std_logic;
      CLK   : in std_logic;
      DELAY : in std_logic_vector(5 downto 0);
      DOUT : out std_logic
      );
  end component;

  --------------------------------------
  -- VME signals
  --------------------------------------
  -- signal cmd_adrs     : std_logic_vector (15 downto 0);
  signal vme_dir_b, vme_oe_b    : std_logic;
  signal vme_dir      : std_logic;
  signal vme_data_out_buf, vme_data_in_buf : std_logic_vector(15 downto 0) := (others => '0');

  --------------------------------------
  -- Clock synthesizer and clock signals
  --------------------------------------
  signal clk20_unbuf     : std_logic := '0';
  signal clk20_inv       : std_logic := '1';
  signal clk20           : std_logic := '0';
  signal clk5_unbuf      : std_logic := '0';
  signal clk5_inv        : std_logic := '1';
  signal clk2p5_unbuf    : std_logic := '0';
  signal clk2p5_inv      : std_logic := '1';
  signal clk2p5          : std_logic := '0';
  signal clk1p25         : std_logic := '0';
  signal clk1p25_inv     : std_logic := '1';
  signal clk625k         : std_logic := '0';
  signal clk625k_inv     : std_logic := '1';
  signal clk625k_unbuf   : std_logic := '0';

  --------------------------------------
  -- PPIB/DCFEB signals
  --------------------------------------
  signal dcfeb_tck    : std_logic_vector (NCFEB downto 1) := (others => '0');
  signal dcfeb_tms    : std_logic := '0';
  signal dcfeb_tdi    : std_logic := '0';
  signal dcfeb_tdo    : std_logic_vector (NCFEB downto 1) := (others => '0');
  -- signal dcfeb_tms_t  : std_logic := '0';

  signal reset_pulse, reset_pulse_q : std_logic := '0';
  signal l1acnt_rst, l1a_reset_pulse, l1a_reset_pulse_q : std_logic := '0';
  signal premask_injpls, premask_extpls, dcfeb_injpls, dcfeb_extpls : std_logic := '0';
  signal test_bc0, pre_bc0, dcfeb_bc0, dcfeb_resync : std_logic := '0';
  signal dcfeb_l1a, masked_l1a, odmbctrl_l1a : std_logic := '0';
  signal dcfeb_l1a_match, masked_l1a_match, odmbctrl_l1a_match : std_logic_vector(NCFEB downto 1) := (others => '0');

  -- signals to generate dcfeb_initjtag when DCFEBs are done programming
  signal pon_rst_reg : std_logic_vector(31 downto 0) := x"00FFFFFF";
  signal pon_reset : std_logic := '0';
  signal done_cnt_en, done_cnt_rst                           : std_logic_vector(NCFEB downto 1);
  type done_cnt_type is array (NCFEB downto 1) of integer range 0 to 3;
  signal done_cnt                                            : done_cnt_type;
  type done_state_type is (DONE_IDLE, DONE_LOW, DONE_COUNTING);
  type done_state_array_type is array (NCFEB downto 1) of done_state_type;
  signal done_next_state, done_current_state                 : done_state_array_type;
  signal dcfeb_done_pulse : std_logic_vector(NCFEB downto 1) := (others => '0');
  signal dcfeb_initjtag : std_logic := '0';
  signal dcfeb_initjtag_d : std_logic := '0';
  signal dcfeb_initjtag_dd : std_logic := '0';

  --------------------------------------
  -- Triggers
  --------------------------------------
  signal test_lct, test_pb_lct, test_l1a : std_logic := '0';
  signal raw_l1a : std_logic := '0';
  
  --------------------------------------
  -- Internal configuration signals
  --------------------------------------
  signal mask_pls : std_logic := '0';
  signal mask_l1a : std_logic_vector(NCFEB downto 0) := (others => '0');
  signal lct_l1a_dly : std_logic_vector(5 downto 0) := (others => '0');
  signal inj_dly : std_logic_vector(4 downto 0) := (others => '0');
  signal ext_dly : std_logic_vector(4 downto 0) := (others => '0');
  signal callct_dly : std_logic_vector(3 downto 0) := (others => '0');
  signal cable_dly : integer range 0 to 1;
  signal odmb_ctrl_reg : std_logic_vector(15 downto 0) := (others => '0');
  signal kill : std_logic_vector(NCFEB+2 downto 1) := (others => '0');
  signal change_reg_data  : std_logic_vector(15 downto 0);
  signal change_reg_index : integer range 0 to NREGS := NREGS;

  --------------------------------------
  -- ODMB VME<->ODMB CTRL signals
  --------------------------------------
  signal test_inj, test_pls, test_ped : std_logic := '0';

  --------------------------------------
  -- Reset signals
  --------------------------------------
  signal fw_reset, fw_reset_q : std_logic := '0';
  signal ccb_softrst_b_q : std_logic := '1'; --no CCB currently
  signal fw_rst_reg : std_logic_vector(31 downto 0) := (others => '0');
  signal reset : std_logic := '0';

  --------------------------------------
  -- Debug signals
  --------------------------------------

  signal diagout_inner : std_logic_vector(17 downto 0) := (others => '0');

  --------------------------------------
  -- Data readout signals
  --------------------------------------
  signal odmb_data : std_logic_vector(15 downto 0) := (others => '0');
  signal odmb_data_sel : std_logic_vector(7 downto 0) := (others => '0');

begin

  -------------------------------------------------------------------------------------------
  -- Handle clock synthesizer signals and generate clocks
  -------------------------------------------------------------------------------------------

  -- In first version of test firmware, we will want to generate everything from 40 MHz cms clock, likely with Clock Manager IP
  -- generate 20 and 2p5 clock
  clk20_inv <= not clk20_unbuf;
  clk5_inv <= not clk5_unbuf;
  clk2p5_inv <= not clk2p5_unbuf;
  clk1p25_inv <= not clk1p25;
  clk625k_inv <= not clk625k_unbuf;
  FD_clk20  : FD port map(D => clk20_inv,  C => CLK40, Q => clk20_unbuf );
  FD_clk5   : FD port map(D => clk5_inv,   C => CLK10, Q => clk5_unbuf  );
  FD_clk2p5 : FD port map(D => clk2p5_inv, C => clk5_unbuf, Q => clk2p5_unbuf);
  FD_clk1p25 : FD port map(D => clk1p25_inv, C => clk2p5_unbuf, Q => clk1p25);
  FD_clk625k : FD port map(D => clk625k_inv, C => clk1p25, Q => clk625k_unbuf);
  BUFG_clk20  : BUFG port map(I => clk20_unbuf, O => clk20);
  BUFG_clk2p5 : BUFG port map(I => clk2p5_unbuf, O => clk2p5);
  BUFG_clk625k : BUFG port map(I => clk625k_unbuf, O => clk625k);

  -------------------------------------------------------------------------------------------
  -- Handle VME signals
  -------------------------------------------------------------------------------------------

  -- Handle VME data direction and output enable lines
  KUS_VME_DIR <= vme_dir;
  vme_dir <= not vme_dir_b;
  KUS_VME_OE_B <= vme_oe_b;

  -- FIXME: KCU only: multiplex vme_data_in and out lines together
  -- can't have internal IOBUFs on KCU
  vme_data_kcu_i : if in_synthesis generate
    vme_data_in_buf <= VME_DATA_IN;
    VME_DATA_OUT <= vme_data_out_buf when (vme_dir='1' and vme_oe_b='0') else (others => 'Z'); 
  end generate vme_data_kcu_i;
  --real board/simulation can have IOBUFs
  vme_data_simulation_i : if in_simulation generate
   GEN_VMEOUT_16 : for I in 0 to 15 generate
   begin
     VME_BUF : IOBUF port map(O => vme_data_in_buf(I), IO => VME_DATA(I), I => vme_data_out_buf(I), T => vme_dir_b); 
   end generate GEN_VMEOUT_16;
  end generate vme_data_simulation_i;
  

  -------------------------------------------------------------------------------------------
  -- Handle PPIB/DCFEB signals
  -------------------------------------------------------------------------------------------

  PPIB_OUT_EN_B <= '0';
  -- Handle DCFEB I/O buffers
  -- OB_DCFEB_TMS: OBUFTDS port map (I => dcfeb_tms, O => DCFEB_TMS_P, OB => DCFEB_TMS_N, T => dcfeb_tms_t);
  -- FIXME: KCU only: on KCU, just use P lines as signals
  cfebjtag_kcu_i : if in_synthesis generate
    DCFEB_TMS_P <= dcfeb_tms;
    DCFEB_TMS_N <= '0';
    DCFEB_TDI_P <= dcfeb_tdi;
    DCFEB_TDI_N <= '0';
    DCFEB_TCK_P <= dcfeb_tck;
    DCFEB_TCK_N <= (others => '0');
    INJPLS_P <= dcfeb_injpls;
    INJPLS_N <= '0';
    EXTPLS_P <= dcfeb_extpls;
    EXTPLS_N <= '0';
    RESYNC_P <= dcfeb_resync;
    RESYNC_N <= '0';
    BC0_P <= dcfeb_bc0;
    BC0_N <= '0';
    L1A_P <= dcfeb_l1a;
    L1A_N <= '0';
    L1A_MATCH_P <= dcfeb_l1a_match;
    L1A_MATCH_N <= (others => '0');
    dcfeb_tdo <= DCFEB_TDO_P;
  end generate cfebjtag_kcu_i;
  --real board/simulation has I/OBUFs
  cfebjtag_simulation_i : if in_simulation generate
    OB_DCFEB_TMS: OBUFDS port map (I => dcfeb_tms, O => DCFEB_TMS_P, OB => DCFEB_TMS_N);
    OB_DCFEB_TDI: OBUFDS port map (I => dcfeb_tdi, O => DCFEB_TDI_P, OB => DCFEB_TDI_N);
    OB_DCFEB_INJPLS: OBUFDS port map (I => dcfeb_injpls, O => INJPLS_P, OB => INJPLS_N);
    OB_DCFEB_EXTPLS: OBUFDS port map (I => dcfeb_extpls, O => EXTPLS_P, OB => EXTPLS_N);
    OB_DCFEB_RESYNC: OBUFDS port map (I => dcfeb_resync, O => RESYNC_P, OB => RESYNC_N);
    OB_DCFEB_BC0: OBUFDS port map (I => dcfeb_bc0, O => BC0_P, OB => BC0_N);
    OB_DCFEB_L1A: OBUFDS port map (I => dcfeb_l1a, O => L1A_P, OB => L1A_N);
    GEN_DCFEBJTAG_7 : for I in 1 to NCFEB generate
    begin
      OB_DCFEB_TCK: OBUFDS port map (I => dcfeb_tck(I), O => DCFEB_TCK_P(I), OB => DCFEB_TCK_N(I));
      IB_DCFEB_TDO: IBUFDS port map (O => dcfeb_tdo(I), I => DCFEB_TDO_P(I), IB => DCFEB_TDO_N(I));
      OB_DCFEB_L1A_MATCH: OBUFDS port map (I => dcfeb_l1a_match(I), O => L1A_MATCH_P(I), OB => L1A_MATCH_N(I));
    end generate GEN_DCFEBJTAG_7;
  end generate cfebjtag_simulation_i;

  --generate pulses if not masked
  dcfeb_injpls <= '0' when mask_pls = '1' else premask_injpls;
  dcfeb_extpls <= '0' when mask_pls = '1' else premask_extpls;
  
  --generate RESYNC, BC0, L1A, and L1A match signals to DCFEBs
  RESETPULSE : PULSE2SAME port map(DOUT => reset_pulse, CLK_DOUT => clk40, RST => '0', DIN => reset);
  FD_RESETPULSE_Q : FD port map (Q => reset_pulse_q,     C => CLK40, D => reset_pulse);
  FD_L1APULSE_Q   : FD port map (Q => l1a_reset_pulse_q, C => CLK40, D => l1a_reset_pulse);

  l1acnt_rst <= clk20 and (l1a_reset_pulse or l1a_reset_pulse_q or reset_pulse or reset_pulse_q);
  pre_bc0    <= test_bc0;
  masked_l1a <= '0' when mask_l1a(0)='1' else odmbctrl_l1a;

  DS_RESYNC : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_resync, CLK => CLK40, NCYCLES => cable_dly, DIN => l1acnt_rst);
  DS_BC0    : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_bc0,    CLK => CLK40, NCYCLES => cable_dly, DIN => pre_bc0   );
  DS_L1A    : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_l1a,    CLK => CLK40, NCYCLES => cable_dly, DIN => masked_l1a);

  GEN_DCFEB_L1A_MATCH : for I in 1 to NCFEB generate
  begin
    masked_l1a_match(I) <= '0' when mask_l1a(I)='1' else odmbctrl_l1a_match(I);
    DS_L1A_MATCH : DELAY_SIGNAL generic map (NCYCLES_MAX => 1) port map (DOUT => dcfeb_l1a_match(I), CLK => CLK40, NCYCLES => cable_dly, DIN => masked_l1a_match(I));
  end generate GEN_DCFEB_L1A_MATCH;

  -- FSM to handle initialization when DONE received from DCFEBs
  -- Generate dcfeb_initjtag
  done_fsm_regs : process (done_next_state, pon_reset, CLK10)
  begin
    for dev in 1 to NCFEB loop
      if (pon_reset = '1') then
        done_current_state(dev) <= DONE_LOW;
      elsif rising_edge(CLK10) then
        done_current_state(dev) <= done_next_state(dev);
        if done_cnt_rst(dev) = '1' then
          done_cnt(dev) <= 0;
        elsif done_cnt_en(dev) = '1' then
          done_cnt(dev) <= done_cnt(dev) + 1;
        end if;
      end if;
    end loop;
  end process;

  done_fsm_logic : process (done_current_state, DCFEB_DONE, done_cnt)
  begin
    for dev in 1 to NCFEB loop
      case done_current_state(dev) is
        when DONE_IDLE =>
          done_cnt_en(dev)      <= '0';
          dcfeb_done_pulse(dev) <= '0';
          if (DCFEB_DONE(dev) = '0') then
            done_next_state(dev) <= DONE_LOW;
            done_cnt_rst(dev)    <= '1';
          else
            done_next_state(dev) <= DONE_IDLE;
            done_cnt_rst(dev)    <= '0';
          end if;

        when DONE_LOW =>
          done_cnt_en(dev)      <= '0';
          dcfeb_done_pulse(dev) <= '0';
          done_cnt_rst(dev)     <= '0';
          if (DCFEB_DONE(dev) = '1') then
            done_next_state(dev) <= DONE_COUNTING;
          else
            done_next_state(dev) <= DONE_LOW;
          end if;

        when DONE_COUNTING =>
          if (DCFEB_DONE(dev) = '0') then
            done_next_state(dev)  <= DONE_LOW;
            done_cnt_en(dev)      <= '0';
            dcfeb_done_pulse(dev) <= '0';
            done_cnt_rst(dev)     <= '1';
          elsif (done_cnt(dev) = 3) then  -- DONE has to be high at least 400 us to avoid spurious edges
            done_next_state(dev)  <= DONE_IDLE;
            done_cnt_en(dev)      <= '0';
            dcfeb_done_pulse(dev) <= '1';
            done_cnt_rst(dev)     <= '0';
          else
            done_next_state(dev)  <= DONE_COUNTING;
            done_cnt_en(dev)      <= '1';
            dcfeb_done_pulse(dev) <= '0';
            done_cnt_rst(dev)     <= '0';
          end if;
      end case;
    end loop;
  end process;

  dcfeb_initjtag_dd <= or_reduce(dcfeb_done_pulse);
  -- FIXME: currently doesn't do anything because state machine pulses dcfeb_done_pulse for 1 40 MHz clock cycle, 10kHz on real board
  DS_DCFEB_INITJTAG    : DELAY_SIGNAL generic map(10) port map(DOUT => dcfeb_initjtag_d, CLK => clk625k, NCYCLES => 10, DIN => dcfeb_initjtag_dd);
  PULSE_DCFEB_INITJTAG : NPULSE2FAST port map(DOUT => dcfeb_initjtag, CLK_DOUT => clk2p5, RST => '0', NPULSE => 5, DIN => dcfeb_initjtag_d);

  -------------------------------------------------------------------------------------------
  -- Handle Triggers
  -------------------------------------------------------------------------------------------

  test_pb_lct <= test_lct;
  LCTDLY_GTRG : LCTDLY port map(DIN => test_pb_lct, CLK => CLK40, DELAY => lct_l1a_dly, DOUT => test_l1a);
  raw_l1a <= test_l1a;

  -------------------------------------------------------------------------------------------
  -- Handle Internal configuration signals
  -------------------------------------------------------------------------------------------
  
  --FIXME should change with bad_dcfeb_pulse and good_dcfeb_pulse, currently, KILL must be updated manually via VME command
  change_reg_data <= x"0" & "000" & kill(9) & kill(8) & kill(7 downto 1);
  change_reg_index <= NREGS;

  -------------------------------------------------------------------------------------------
  -- Handle reset signals
  -------------------------------------------------------------------------------------------

  FD_FW_RESET : FD port map (Q => fw_reset_q, C => CLK40, D => fw_reset);
  fw_rst_reg <= x"3FFFF000" when ((fw_reset_q = '0' and fw_reset = '1') or ccb_softrst_b_q = '0') else
                  fw_rst_reg(30 downto 0) & '0' when rising_edge(clk40) else
                  fw_rst_reg;
  reset <= fw_rst_reg(31) or pon_rst_reg(31) or RST;
  -- original: reset <= fw_rst_reg(31) or pon_rst_reg(31) or not pb0_q;
  -- pon_rst_reg used to be reset from pll lock
  pon_rst_reg    <= pon_rst_reg(30 downto 0) & '0' when rising_edge(clk40) else
                    pon_rst_reg;
  pon_reset <= pon_rst_reg(31);
  
  -------------------------------------------------------------------------------------------
  -- Debug
  -------------------------------------------------------------------------------------------

  DIAGOUT <= diagout_inner;

  -------------------------------------------------------------------------------------------
  -- Handle data readout
  -------------------------------------------------------------------------------------------

  odmb_status_pro : process (odmb_data_sel, VME_GAP_B, VME_GA_B)
  begin
    
    case odmb_data_sel is

      --debug register
      when x"06" => odmb_data <= x"7E57";

      when x"20" => odmb_data <= "0000000000" & VME_GAP_B & VME_GA_B;

      when others => odmb_data <= (others => '1');
    end case;
  end process;

  -------------------------------------------------------------------------------------------
  -- Sub-modules
  -------------------------------------------------------------------------------------------
  
  MBV : ODMB_VME
    generic map (
      NCFEB => NCFEB
      )
    port map (
      CLK160         => CLK160,
      CLK40          => CLK40,
      CLK10          => CLK10,
      CLK2P5	       => clk2p5,
      CLK1P25        => clk1p25,

      VME_DATA_IN    => vme_data_in_buf,
      VME_DATA_OUT   => vme_data_out_buf,
      VME_GAP_B      => VME_GAP_B,
      VME_GA_B       => VME_GA_B,
      VME_ADDR       => VME_ADDR,
      VME_AM         => VME_AM,
      VME_AS_B       => VME_AS_B,
      VME_DS_B       => VME_DS_B,
      VME_LWORD_B    => VME_LWORD_B,
      VME_WRITE_B    => VME_WRITE_B,
      VME_IACK_B     => VME_IACK_B,
      VME_BERR_B     => VME_BERR_B,
      VME_SYSFAIL_B  => VME_SYSFAIL_B,
      VME_DTACK_B    => VME_DTACK_KUS_B,
      VME_OE_B       => vme_oe_b,
      VME_DIR_B      => vme_dir_b,      -- to be used in IOBUF

      DCFEB_TCK      => dcfeb_tck,
      DCFEB_TMS      => dcfeb_tms,
      DCFEB_TDI      => dcfeb_tdi,
      DCFEB_TDO      => dcfeb_tdo,
      DCFEB_DONE     => DCFEB_DONE,
      DCFEB_INITJTAG => dcfeb_initjtag,

      LVMB_PON    => LVMB_PON,
      PON_LOAD    => PON_LOAD,
      PON_OE_B    => PON_OE_B,
      R_LVMB_PON  => R_LVMB_PON,
      LVMB_CSB    => LVMB_CSB,
      LVMB_SCLK   => LVMB_SCLK,
      LVMB_SDIN   => LVMB_SDIN,
      LVMB_SDOUT  => LVMB_SDOUT,

      DCFEB_PRBS_FIBER_SEL  => DCFEB_PRBS_FIBER_SEL,
      DCFEB_PRBS_EN         => DCFEB_PRBS_EN,
      DCFEB_PRBS_RST        => DCFEB_PRBS_RST,
      DCFEB_PRBS_RD_EN      => DCFEB_PRBS_RD_EN,
      DCFEB_RXPRBSERR       => DCFEB_RXPRBSERR,
      DCFEB_PRBS_ERR_CNT    => DCFEB_PRBS_ERR_CNT,

      OTMB_TX  => OTMB_TX,
      OTMB_RX  => OTMB_RX,
      
      FW_RESET => fw_reset,
      L1A_RESET_PULSE => l1a_reset_pulse,
      TEST_INJ => test_inj,
      TEST_PLS => test_pls,
      TEST_BC0 => test_bc0,
      TEST_PED => test_ped,
      TEST_LCT => test_lct,
      MASK_L1A => mask_l1a,
      MASK_PLS => mask_pls,
      ODMB_CAL => odmb_ctrl_reg(0),
      MUX_DATA_PATH => odmb_ctrl_reg(7),
      MUX_TRIGGER => odmb_ctrl_reg(9),
      MUX_LVMB => odmb_ctrl_reg(10),
      ODMB_PED => odmb_ctrl_reg(14 downto 13),
      ODMB_DATA => odmb_data,
      ODMB_DATA_SEL => odmb_data_sel,

      LCT_L1A_DLY => lct_l1a_dly,
      CABLE_DLY => cable_dly,
      OTMB_PUSH_DLY => open,
      ALCT_PUSH_DLY => open,
      BX_DLY => open,
      INJ_DLY => inj_dly, 
      EXT_DLY => ext_dly, 
      CALLCT_DLY => callct_dly,
      ODMB_ID => open,
      NWORDS_DUMMY => open,
      KILL => kill,
      CRATEID => open,
      CHANGE_REG_DATA => change_reg_data,
      CHANGE_REG_INDEX => change_reg_index,

      DIAGOUT   => diagout_inner,
      RST       => reset,
      PON_RESET => pon_reset
      );

  MBC : ODMB_CTRL 
    generic map (
      NCFEB => NCFEB
      )
    port map (
      CLK80 => CLK80,
      CLK40 => CLK40,

      TEST_CCBINJ => test_inj,
      TEST_CCBPLS => test_pls,
      TEST_CCBPED => test_ped, 

      CAL_MODE => odmb_ctrl_reg(0),
      PEDESTAL => odmb_ctrl_reg(13),

      RAW_L1A => raw_l1a,

      LCT_L1A_DLY => lct_l1a_dly,
      INJ_DLY => inj_dly, 
      EXT_DLY => ext_dly, 
      CALLCT_DLY => callct_dly, 
      
      DCFEB_INJPULSE => premask_injpls,
      DCFEB_EXTPULSE => premask_extpls,
      DCFEB_L1A => odmbctrl_l1a,                    
      DCFEB_L1A_MATCH => odmbctrl_l1a_match,        

      DIAGOUT => open,
      RST => reset
      );

end Behavioral;
