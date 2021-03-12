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

entity VMECONFREGS is
  generic (
    NREGS  : integer := 16;             -- Number of Configuration registers
    NCONST : integer := 16;             -- Number of Protected registers
    NFEB   : integer := 7               -- Number of DCFEBs
    );
  port (
    SLOWCLK : in std_logic;
    CLK     : in std_logic;
    RST     : in std_logic;

    DEVICE   : in  std_logic;
    STROBE   : in  std_logic;
    COMMAND  : in  std_logic_vector(9 downto 0);
    WRITER   : in  std_logic;
    DTACK    : out std_logic;

    INDATA  : in  std_logic_vector(15 downto 0);
    OUTDATA : out std_logic_vector(15 downto 0);

-- Configuration registers    
    LCT_L1A_DLY   : out std_logic_vector(5 downto 0);
    CABLE_DLY     : out integer range 0 to 1;
    OTMB_PUSH_DLY : out integer range 0 to 63;
    ALCT_PUSH_DLY : out integer range 0 to 63;
    BX_DLY        : out integer range 0 to 4095;

    INJ_DLY    : out std_logic_vector(4 downto 0);
    EXT_DLY    : out std_logic_vector(4 downto 0);
    CALLCT_DLY : out std_logic_vector(3 downto 0);

    ODMB_ID      : out std_logic_vector(15 downto 0);
    NWORDS_DUMMY : out std_logic_vector(15 downto 0);
    KILL         : out std_logic_vector(NFEB+2 downto 1);
    CRATEID      : out std_logic_vector(7 downto 0);

-- From ODMB_UCSB_V2 to change registers
    CHANGE_REG_DATA  : in std_logic_vector(15 downto 0);
    CHANGE_REG_INDEX : in integer range 0 to NREGS;

-- To/From QSPI Interface
    SPI_CFG_UL_PULSE   : in std_logic;
    SPI_CONST_UL_PULSE : in std_logic;
    SPI_REG_IN : in std_logic_vector(15 downto 0);
    SPI_CFG_BUSY    : in  std_logic;
    SPI_CONST_BUSY  : in  std_logic;
    SPI_CFG_REG_WE   : in  integer range 0 to NREGS;
    SPI_CONST_REG_WE : in  integer range 0 to NREGS;
    SPI_CFG_REGS    : out cfg_regs_array;
    SPI_CONST_REGS  : out cfg_regs_array
    );
end VMECONFREGS;


architecture VMECONFREGS_Arch of VMECONFREGS is

  constant FW_VERSION       : std_logic_vector(15 downto 0) := x"D3B7";
  constant FW_ID            : std_logic_vector(15 downto 0) := x"D3B7";
  constant FW_MONTH_DAY     : std_logic_vector(15 downto 0) := x"1109";
  constant FW_YEAR          : std_logic_vector(15 downto 0) := x"2020";
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
  KILL          <= cfg_regs(7)(NFEB+1 downto 0);                     -- 0x401C
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
