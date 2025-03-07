-- VMECONFREGS: Assigns values to the configuration registers and permanent registers.
-- Triple voting is employed for radiation hardness.

library ieee;
library work;
library unisim;
use unisim.vcomponents.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use work.ucsb_types.all;

--! @brief module for interacting with configuration and constant registers loaded from nonvolatile memory
--! @details Supported VME commands:
--! * W/R 40YZ read configuration register YZ/4
--! * R   4Y00 read constant register Y-1
--! * W/R 4FFC read constant register write mask (W disabled in most fw versions)
--! The specific quantities stored in the configuration and constant registers are
--! CFG register 0 (4000) LCT_L1A_DLY[5:0] LCT/L1A gap - 100
--! CFG register 1 (4004) OTMB_PUSH_DLY[5:0] L1A/OTMBDAV gap, read with "R 338C"
--! CFG register 2 (4008) CABLE_DLY[0:0] delays L1A[_MATCH], RESYNC, BC0 by 25 ns
--! CFG register 3 (400C) ALCT_DLY[5:0] L1A/ALCTDAV gap, read with "R 339C"
--! CFG register 4 (4010) INJ_DLY[4:0] delay for INJPLS in units of 12.5 ns
--! CFG register 5 (4014) EXT_DLY[4:0] delay for EXTPLS in units of 12.5 ns
--! CFG reguster 6 (4018) CALLCT_DLY[3:0] delay for calibration LCT in units of 25 ns
--! CFG register 7 (401C) KILL[9:1] for masking other boards (ALCT,TMB,7DCFEBs)
--! CFG register 8 (4020) CRATEID[6:0]
--! CFG register 9 (4024) Firmware ID, not writeable
--! CFG register 10 (4028) NWORDS_DUMMY[15:0] number of words generated by simulated FE boards
--! CFG register 11 (402C) BX_DLY[11:0] bunch crossing counter delay, unused
--! CONST register 0 (4100) ODMB unique ID
--! CONST register 1 (4200) Firmware version
--! CONST register 2 (4300) Firmware build
--! CONST register 3 (4400) Month/day firmware was synthesized
--! CONST register 4 (4500) Year firmware was synthesized
entity VMECONFREGS is
  generic (
    NCFEB   : integer range 1 to 7 := 7  -- Number of DCFEBS, 7 for ME1/1, 5
    );
  port (
    SLOWCLK : in std_logic; --! 2.5 MHz clock input
    CLK     : in std_logic; --! 40 MHz clock input
    RST     : in std_logic; --! Soft reset signal

    DEVICE   : in  std_logic;                    --! Indicates whether this is the selected VME device
    STROBE   : in  std_logic;                    --! Indicates VME command is ready to be executed
    COMMAND  : in  std_logic_vector(9 downto 0); --! VME command to be executed (x"4" & COMMAND & "00" is user-readable version)
    WRITER   : in  std_logic;                    --! Indicates if VME command is a read or write command
    DTACK    : out std_logic;                    --! Data acknowledge to be sent once command is initialized/executed

    INDATA  : in  std_logic_vector(15 downto 0); --! Input data from VME backplane
    OUTDATA : out std_logic_vector(15 downto 0); --! Output data to VME backplane

-- Configuration registers    
    LCT_L1A_DLY   : out std_logic_vector(5 downto 0);      --! Configuration register controlling LCT delay in CALIBTRG
    CABLE_DLY     : out integer range 0 to 1;              --! CFG register controlling delay for DCFEB bound signals (L1A,L1A_MATCH,RESYNC,BC0) in top level
    OTMB_PUSH_DLY : out integer range 0 to 63;             --! CFG register controlling delay between OTMBDAV and pushing to the FIFO in TRGCNTRL
    ALCT_PUSH_DLY : out integer range 0 to 63;             --! CFG register controlling delay between ALCTDAV and pushing to the FIFO in TRGCNTRL
    BX_DLY        : out integer range 0 to 4095;           --! CFG register that would be used in counting bunch crossings in CAFIFO, but actually unused

    INJ_DLY    : out std_logic_vector(4 downto 0);         --! CFG register controlling delay for calibration INJPULSE in CALIBTRG
    EXT_DLY    : out std_logic_vector(4 downto 0);         --! CFG register controlling delay for calibration EXTPULSE in CALIBTRG
    CALLCT_DLY : out std_logic_vector(3 downto 0);         --! CFG register controlling delay for calibration LCT in CALIBTRG

    ODMB_ID      : out std_logic_vector(15 downto 0);      --! CONST register storing the unique ODMB ID
    NWORDS_DUMMY : out std_logic_vector(15 downto 0);      --! CFG register controlling the number of words generated by dummy DCFEBs/ALCT/OTMB
    KILL         : out std_logic_vector(NCFEB+2 downto 1); --! CFG register controlling which boards (ALCT/OTMB/DCFEBs) should be ignored
    CRATEID      : out std_logic_vector(7 downto 0);       --! CFG register withe crate ID, used by CONTROL_FSM in packet generation

-- From ODMB_UCSB_V2 to change registers
    CHANGE_REG_DATA  : in std_logic_vector(15 downto 0);   --! Signal to set new value for KILL register n case of auto-kill
    CHANGE_REG_INDEX : in integer range 0 to NREGS;        --! Signal to enable writing to CFG registers, only ever 7(for setting KILL) or NREGS(none)

-- To/From SPI_PORT
    SPI_CFG_UL_PULSE   : in std_logic;               --! Signal from SPI_PORT to write CFG registers from PROM contents
    SPI_CONST_UL_PULSE : in std_logic;               --! Signal from SPI_PORT to write CONST registers from PROM contents
    SPI_REG_IN : in std_logic_vector(15 downto 0);   --! CFG or CONST register contents to be written, from SPI_PORT
    SPI_CFG_BUSY    : in  std_logic;                 --! From SPI_PORT, indicates CFG register upload in progress
    SPI_CONST_BUSY  : in  std_logic;                 --! From SPI_PORT, indicates CONST register upload in progress
    SPI_CFG_REG_WE   : in  integer range 0 to NREGS; --! Write enable for each CFG register, from SPI_PORT
    SPI_CONST_REG_WE : in  integer range 0 to NREGS; --! Write enable for each CONST register, from SPI_PORT
    SPI_CFG_REGS    : out cfg_regs_array;            --! Contents of CFG registers, used by SPI_PORT to save to PROM
    SPI_CONST_REGS  : out cfg_regs_array             --! Contents of CONST registers, used by SPI_PORT to save to PROM
    );
end VMECONFREGS;


architecture VMECONFREGS_Arch of VMECONFREGS is

  constant FW_VERSION       : std_logic_vector(15 downto 0) := x"D3B7";
  constant FW_ID            : std_logic_vector(15 downto 0) := x"D3B7";
  constant FW_MONTH_DAY     : std_logic_vector(15 downto 0) := x"1029";
  constant FW_YEAR          : std_logic_vector(15 downto 0) := x"2021";
  constant able_write_const : std_logic                     := '0';

  constant cfg_reg_mask_we   : std_logic_vector(15 downto 0) := x"FDFF";
  constant const_reg_mask_we : std_logic_vector(15 downto 0) := x"FFE1";
--  constant cfg_reg_init : cfg_regs_array := (x"FFF0", x"FFF1", x"FFF2", x"FFF3",
--                                             x"FFF4", x"FFF5", x"FFF6", x"FFF7",
--                                             x"FFF8", FW_VERSION, x"FFFA", x"FFFB",
--                                             x"FFFC", x"FFFD", x"FFFE", x"FFFF");
                                               constant cfg_reg_init : cfg_regs_array := (x"5468", x"6973", x"2069", x"7320",
                                                                                          x"6120", x"7465", x"7374", x"2066",
                                                                                          x"6F72", x"2077", x"7269", x"7469",
                                                                                          x"6E67", x"2050", x"524F", x"4D21");
  constant const_reg_init : cfg_regs_array := (x"0D3B", FW_VERSION, FW_ID, FW_MONTH_DAY,
                                               FW_YEAR, x"FFF5", x"FFF6", x"FFF7",
                                               x"FFF8", x"FFF9", x"FFFA", x"FFFB",
                                               x"FFFC", x"FFFD", x"FFFE", x"FFFF");
  constant cfg_reg_mask : cfg_regs_array := (x"003f", x"003f", x"0001", x"003f", 
                                             x"001f", x"001f", x"000f", x"01ff", 
                                             x"00ff", x"ffff", x"ffff", x"0fff", 
                                             x"ffff", x"ffff", x"ffff", x"ffff");
  signal do_cfg, do_const                                   : std_logic := '0';
  signal do_cfg_we, do_const_we, do_cfg_we_q, do_const_we_q : std_logic := '0';
  signal bit_const                                          : std_logic := '0';

  type rh_reg is array (2 downto 0) of std_logic_vector(15 downto 0);
  type rh_reg_array is array (0 to NREGS) of rh_reg;
  signal cfg_reg_triple : rh_reg_array;
  signal cfg_regs       : cfg_regs_array;

  signal cfg_reg_we, cfg_reg_index, vme_cfg_reg_we : integer range 0 to NREGS;
  signal cfg_reg_in                                : std_logic_vector(15 downto 0) := (others => '0');

  signal const_reg_triple : rh_reg_array;
  signal const_regs       : cfg_regs_array;

  signal const_reg_index, const_reg_index_p1 : integer range 0 to NCONST;
  signal const_reg_we, vme_const_reg_we      : integer range 0 to NREGS;
  signal const_reg_in                        : std_logic_vector(15 downto 0) := (others => '0');

  signal cmddev                                 : std_logic_vector (15 downto 0);
  signal dd_dtack, d_dtack, q_dtack, ce_d_dtack : std_logic := '0';

  signal w_mask_vme, r_mask_vme     : std_logic;
  signal mask_vme                   : std_logic_vector(NCONST downto 0)   := (others => '0');

begin

  --Decode command
  cmddev    <= "000" & DEVICE & COMMAND & "00";
  bit_const <= or_reduce(cmddev(11 downto 8));

  do_cfg     <= '1' when ((cmddev and x"1F00") = x"1000")                                                else '0'; --0x40YZ
  do_const   <= '1' when ((cmddev and x"10FF") = x"1000" and bit_const = '1')                            else '0'; --0x4Y00 where Y /= 0
  w_mask_vme <= '1' when (cmddev = x"1FFC" and WRITER = '0' and able_write_const = '1' and STROBE = '1') else '0';
  r_mask_vme <= '1' when (cmddev = x"1FFC" and WRITER = '1')                                             else '0';

  cfg_reg_index <= to_integer(unsigned(cmddev(5 downto 2)));

  const_reg_index_p1 <= to_integer(unsigned(cmddev(11 downto 8)));
  const_reg_index    <= const_reg_index_p1 - 1 when const_reg_index_p1 > 0 else NCONST;




  -- Write MASK_VME (0x4FFC)
  GEN_MASK_VME : for i in 0 to NCONST-1 generate
  begin
    fd_w_mask_vme : fdce port map(Q => mask_vme(i), C => CLK, CE => w_mask_vme, CLR => RST, D => INDATA(i));
  end generate GEN_MASK_VME;




  -- Output for read commands (R 0x40YZ and R 0x4Y00) and output data to top level
  OUTDATA <= mask_vme(15 downto 0) when r_mask_vme = '1' else
             const_regs(const_reg_index) when do_const = '1' else
             cfg_regs(cfg_reg_index); -- and cfg_reg_mask(cfg_reg_index);

  SPI_CFG_REGS   <= cfg_regs;
  SPI_CONST_REGS <= const_regs;

  LCT_L1A_DLY   <= cfg_regs(0)(5 downto 0);                          -- 0x4000
  OTMB_PUSH_DLY <= to_integer(unsigned(cfg_regs(1)(5 downto 0)));    -- 0x4004
  CABLE_DLY     <= to_integer(unsigned'("" & cfg_regs(2)(0)));       -- 0x4008
  ALCT_PUSH_DLY <= to_integer(unsigned(cfg_regs(3)(5 downto 0)));    -- 0x400C
  INJ_DLY       <= cfg_regs(4)(4 downto 0);                          -- 0x4010
  EXT_DLY       <= cfg_regs(5)(4 downto 0);                          -- 0x4014
  CALLCT_DLY    <= cfg_regs(6)(3 downto 0);                          -- 0x4018
  KILL          <= cfg_regs(7)(NCFEB+1 downto 0);                    -- 0x401C
  CRATEID       <= cfg_regs(8)(7 downto 0);                          -- 0x4020
  -- 0x4024 reserved for FW version
  NWORDS_DUMMY  <= cfg_regs(10)(15 downto 0);                        -- 0x4028
  BX_DLY        <= to_integer(unsigned(cfg_regs(11)(11 downto 0)));  -- 0x402C

  ODMB_ID <= const_regs(0)(15 downto 0);  -- 0x4100




  -- Write configuration registers (W 0x40YZ or top level signal) when vme_cfg_reg_we or CC_CFG_REG_WE are not NREGS
  do_cfg_we      <= do_cfg and not WRITER and STROBE and not SPI_CFG_BUSY;
  PULSE_CFGWE : PULSE2FAST port map(DOUT => do_cfg_we_q, CLK_DOUT => CLK, RST => RST, DIN => do_cfg_we);
  vme_cfg_reg_we <= cfg_reg_index when do_cfg_we_q = '1' else NREGS;

  cfg_reg_we <= CHANGE_REG_INDEX when CHANGE_REG_INDEX < NREGS else
                SPI_CFG_REG_WE when SPI_CFG_UL_PULSE = '1' else
                vme_cfg_reg_we;
  cfg_reg_in <= CHANGE_REG_DATA when CHANGE_REG_INDEX < NREGS else
                SPI_REG_IN when SPI_CFG_UL_PULSE = '1' else
                INDATA;

  cfg_reg_proc : process (RST, CLK, cfg_reg_we, cfg_reg_in, cfg_regs)
  begin
    for i in 0 to NREGS-1 loop
      for j in 0 to 2 loop
        if (RST = '1') then
          cfg_reg_triple(i)(j) <= cfg_reg_init(i);
        elsif rising_edge(CLK) then
          if (cfg_reg_we = i and cfg_reg_mask_we(i) = '1') then
            cfg_reg_triple(i)(j) <= cfg_reg_in;
          else
            cfg_reg_triple(i)(j) <= cfg_regs(i);
          end if;
        end if;
      end loop;
    end loop;
  end process;

  GEN_CFG_TRIPLEVOTING : for ind in 0 to NREGS-1 generate
  begin
    GEN_TRIPLEBITS : for ibit in 0 to 15 generate
    begin
      cfg_regs(ind)(ibit) <= (cfg_reg_triple(ind)(0)(ibit) and cfg_reg_triple(ind)(1)(ibit)) or
                             (cfg_reg_triple(ind)(1)(ibit) and cfg_reg_triple(ind)(2)(ibit)) or
                             (cfg_reg_triple(ind)(2)(ibit) and cfg_reg_triple(ind)(0)(ibit));
    end generate GEN_TRIPLEBITS;
  end generate GEN_CFG_TRIPLEVOTING;




  -- Writing protected registers (W 0x4Y00)
  do_const_we      <= do_const and not WRITER and STROBE and not SPI_CONST_BUSY and mask_vme(const_reg_index);
  PULSE_CONSTWE : PULSE2FAST port map(DOUT => do_const_we_q, CLK_DOUT => CLK, RST => RST, DIN => do_const_we);
  vme_const_reg_we <= const_reg_index when do_const_we_q = '1' else NCONST;

  const_reg_we <= vme_const_reg_we when (SPI_CONST_UL_PULSE = '0') else SPI_CONST_REG_WE;
  const_reg_in <= INDATA           when (SPI_CONST_UL_PULSE = '0') else SPI_REG_IN;

  const_reg_proc : process (RST, CLK, const_reg_we, const_reg_in, const_regs)
  begin
    for i in 0 to NCONST-1 loop
      for j in 0 to 2 loop
        if (RST = '1') then
          const_reg_triple(i)(j) <= const_reg_init(i);
        elsif rising_edge(CLK) then
          if (const_reg_we = i and const_reg_mask_we(i) = '1') then
            const_reg_triple(i)(j) <= const_reg_in;
          else
            const_reg_triple(i)(j) <= const_regs(i);
          end if;
        end if;
      end loop;
    end loop;
  end process;

  GEN_CONST_TRIPLEVOTING : for ind in 0 to NREGS-1 generate
  begin
    GEN_TRIPLEBITS : for ibit in 0 to 15 generate
    begin
      const_regs(ind)(ibit) <= (const_reg_triple(ind)(0)(ibit) and const_reg_triple(ind)(1)(ibit)) or
                               (const_reg_triple(ind)(1)(ibit) and const_reg_triple(ind)(2)(ibit)) or
                               (const_reg_triple(ind)(2)(ibit) and const_reg_triple(ind)(0)(ibit));
    end generate GEN_TRIPLEBITS;
  end generate GEN_CONST_TRIPLEVOTING;




  -- DTACK: always just issue on second SLOWCLK edge after STROBE
  ce_d_dtack <= STROBE and DEVICE;
  FD_D_DTACK : FDCE port map(Q => d_dtack, C => SLOWCLK, CE => ce_d_dtack, CLR => q_dtack, D => '1');
  FD_Q_DTACK : FD port map(Q => q_dtack, C => SLOWCLK, D => d_dtack);
  DTACK    <= q_dtack;

end VMECONFREGS_Arch;
