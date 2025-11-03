-- ----------------------------------------------------------------------------
-- Description: Clock and Reset
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library unisim;
  use unisim.vcomponents.all;

library xpm;
  use xpm.vcomponents.all;

entity clk_rst is
  port (
    sys_clk_i  : in    std_logic; -- System Clock, 100 MHz
    sys_rst_i  : in    std_logic;

    user_clk_o : out   std_logic;
    user_rst_o : out   std_logic;

    eth_clk_o  : out   std_logic;
    eth_rst_o  : out   std_logic;

    vga_clk_o  : out   std_logic;
    vga_rst_o  : out   std_logic
  );
end entity clk_rst;

architecture synthesis of clk_rst is

  signal pll_vga_fb     : std_logic;
  signal pll_vga_locked : std_logic;
  signal pll_fb         : std_logic;
  signal pll_locked     : std_logic;
  signal pll_user_clk   : std_logic;
  signal pll_eth_clk    : std_logic;
  signal pll_vga_clk    : std_logic;

begin

  mmcme2_base_vga_inst : component mmcme2_base
    generic map (
      BANDWIDTH          => "OPTIMIZED",
      CLKFBOUT_MULT_F    => 37.125, -- 928.125 MHz
      CLKFBOUT_PHASE     => 0.000,
      CLKIN1_PERIOD      => 10.0,   -- INPUT @ 100 MHz
      CLKOUT0_DIVIDE_F   => 12.500, -- OUTPUT @ 74.25 MHz
      CLKOUT0_DUTY_CYCLE => 0.500,
      CLKOUT0_PHASE      => 0.000,
      DIVCLK_DIVIDE      => 4,
      REF_JITTER1        => 0.010,
      STARTUP_WAIT       => FALSE
    )
    port map (
      clkin1   => sys_clk_i,
      clkfbin  => pll_vga_fb,
      rst      => sys_rst_i,
      pwrdwn   => '0',
      clkout0  => pll_vga_clk,
      clkfbout => pll_vga_fb,
      locked   => pll_vga_locked
    ); -- mmcme2_base_inst : component mmcme2_base


  mmcme2_base_inst : component mmcme2_base
    generic map (
      BANDWIDTH          => "OPTIMIZED",
      CLKFBOUT_MULT_F    => 13.500, -- 1350 MHz
      CLKFBOUT_PHASE     => 0.000,
      CLKIN1_PERIOD      => 10.0,   -- INPUT @ 100 MHz
      CLKOUT0_DIVIDE_F   => 13.500, -- OUTPUT @ 100 MHz
      CLKOUT0_DUTY_CYCLE => 0.500,
      CLKOUT0_PHASE      => 0.000,
      CLKOUT1_DIVIDE     => 27,     -- OUTPUT @ 50 MHz
      CLKOUT1_DUTY_CYCLE => 0.500,
      CLKOUT1_PHASE      => 0.000,
      DIVCLK_DIVIDE      => 1,
      REF_JITTER1        => 0.010,
      STARTUP_WAIT       => FALSE
    )
    port map (
      clkin1   => sys_clk_i,
      clkfbin  => pll_fb,
      rst      => sys_rst_i,
      pwrdwn   => '0',
      clkout0  => pll_user_clk,
      clkout1  => pll_eth_clk,
      clkfbout => pll_fb,
      locked   => pll_locked
    ); -- mmcme2_base_inst : component mmcme2_base


  bufg_vga_inst : component bufg
    port map (
      i => pll_vga_clk,
      o => vga_clk_o
    ); -- bufg_vga_inst

  bufg_user_inst : component bufg
    port map (
      i => pll_user_clk,
      o => user_clk_o
    ); -- bufg_user_inst

  bufg_eth_inst : component bufg
    port map (
      i => pll_eth_clk,
      o => eth_clk_o
    ); -- bufg_eth_inst


  xpm_cdc_sync_vga_inst : component xpm_cdc_sync_rst
    generic map (
      DEST_SYNC_FF => 2,
      INIT         => 1
    )
    port map (
      src_rst  => not pll_vga_locked,
      dest_clk => vga_clk_o,
      dest_rst => vga_rst_o
    ); -- xpm_cdc_sync_vga_inst

  xpm_cdc_sync_user_inst : component xpm_cdc_sync_rst
    generic map (
      DEST_SYNC_FF => 2,
      INIT         => 1
    )
    port map (
      src_rst  => not pll_locked,
      dest_clk => user_clk_o,
      dest_rst => user_rst_o
    ); -- xpm_cdc_sync_user_inst

  xpm_cdc_sync_eth_inst : component xpm_cdc_sync_rst
    generic map (
      DEST_SYNC_FF => 2,
      INIT         => 1
    )
    port map (
      src_rst  => not pll_locked,
      dest_clk => eth_clk_o,
      dest_rst => eth_rst_o
    ); -- xpm_cdc_sync_eth_inst

end architecture synthesis;

