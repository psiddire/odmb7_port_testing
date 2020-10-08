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
    BPI_CFG_UL_PULSE     : out std_logic;
    BPI_CFG_DL_PULSE     : out std_logic;
    BPI_CONST_UL_PULSE   : out std_logic;
    BPI_CONST_DL_PULSE   : out std_logic;
    CC_CFG_REG           : out std_logic_vector(15 downto 0);
    BPI_CFG_BUSY         : out std_logic;
    BPI_CONST_BUSY       : out std_logic;
    CC_CFG_REG_WE        : out integer range 0 to NREGS;
    CC_CONST_REG_WE      : out integer range 0 to NREGS;
    BPI_CFG_REGS         : in cfg_regs_array;
    BPI_CONST_REGS       : in cfg_regs_array
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
  signal bpi_cfg_ul_pulse_inner : std_logic := '0';
  signal cc_cfg_reg_we_inner : integer := NREGS;

begin

  CC_CFG_REG <= cfg_reg_hardcode(cc_cfg_reg_we_inner) when (cc_cfg_reg_we_inner /= NREGS) else x"0000";
  BPI_CONST_BUSY <= '0';
  BPI_CFG_BUSY <= '0';
  BPI_CONST_DL_PULSE <= '0';
  BPI_CFG_DL_PULSE <= '0';
  BPI_CONST_UL_PULSE <= '0'; --never upload CONST REGs
  CC_CONST_REG_WE <= NREGS;
  BPI_CFG_UL_PULSE <= bpi_cfg_ul_pulse_inner;
  CC_CFG_REG_WE <= cc_cfg_reg_we_inner;

  --upload CFG registers on reset


  FDPE_cfg_ul_pulse : FDPE port map(Q => cfg_reg_count_enable, C => SLOWCLK, CE => ce_cfg_reg_count_enable, PRE => RST, D => '0');
  
  cfg_upload_proc : process (SLOWCLK)
  begin
    if rising_edge(SLOWCLK) then
      if (cfg_reg_count_enable = '0') then
        --IDLE state, don't do anything
        ce_cfg_reg_count_enable <= '0';
        bpi_cfg_ul_pulse_inner <= '0';
        cc_cfg_reg_we_inner <= NREGS;
      else
        if (cc_cfg_reg_we_inner = NREGS) then
          --first cycle after RST, move we to 0 but don't do anything else
          ce_cfg_reg_count_enable <= '0'; 
          bpi_cfg_ul_pulse_inner <= '0';
          cc_cfg_reg_we_inner <= 0;          
        elsif (cc_cfg_reg_we_inner = NREGS-1) then
          --reset everything for next RST
          ce_cfg_reg_count_enable <= '1';
          bpi_cfg_ul_pulse_inner <= '0';
          cc_cfg_reg_we_inner <= NREGS;
        else
          if (bpi_cfg_ul_pulse_inner = '0') then
            --on-cycle give a UL pulse
            ce_cfg_reg_count_enable <= '0';
            bpi_cfg_ul_pulse_inner <= '1';
            cc_cfg_reg_we_inner <= cc_cfg_reg_we_inner;
          else
            --off-cycle, update reg_we
            ce_cfg_reg_count_enable <= '0';
            bpi_cfg_ul_pulse_inner <= '0';
            cc_cfg_reg_we_inner <= cc_cfg_reg_we_inner + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

end QSPI_DUMMY_Arch;
