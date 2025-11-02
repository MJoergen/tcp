library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity tb_top is
end entity tb_top;

architecture simulation of tb_top is

  -- Main input clock and reset
  signal sys_clk : std_logic := '1';
  signal sys_rst : std_logic := '1';

  -- UART
  signal debug_rxd : std_logic;
  signal debug_txd : std_logic;

  -- Ethernet
  signal eth_clk    : std_logic;
  signal eth_rst_n  : std_logic;
  signal eth_crs_dv : std_logic;
  signal eth_rx_d   : std_logic_vector(1 downto 0);
  signal eth_tx_en  : std_logic;
  signal eth_tx_d   : std_logic_vector(1 downto 0);
  signal eth_rxer   : std_logic;
  signal eth_led2   : std_logic;
  signal eth_mdc    : std_logic;
  signal eth_mdio   : std_logic;

  -- Keyboard
  signal kb_io0 : std_logic;
  signal kb_io1 : std_logic;
  signal kb_io2 : std_logic;

  -- VGA
  signal vdac_blank_n : std_logic;
  signal vdac_clk     : std_logic;
  signal vdac_psave_n : std_logic;
  signal vdac_sync_n  : std_logic;
  signal vga_blue     : std_logic_vector(7 downto 0);
  signal vga_green    : std_logic_vector(7 downto 0);
  signal vga_hs       : std_logic;
  signal vga_red      : std_logic_vector(7 downto 0);
  signal vga_vs       : std_logic;

begin

  ----------------------------------------------------------
  -- Clock and reset
  ----------------------------------------------------------

  sys_clk <= not sys_clk after 5 ns;
  sys_rst <= '1', '0' after 100 ns;


  ----------------------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------------------

  top_inst : entity work.top
    generic map (
      G_TIMESTAMP => X"12345678",
      G_COMMIT_ID => X"87654321"
    )
    port map (
      sys_clk_i      => sys_clk,
      sys_rst_i      => sys_rst,
      debug_rxd_i    => debug_rxd,
      debug_txd_o    => debug_txd,
      eth_clk_o      => eth_clk,
      eth_rst_n_o    => eth_rst_n,
      eth_crs_dv_i   => eth_crs_dv,
      eth_rx_d_i     => eth_rx_d,
      eth_tx_en_o    => eth_tx_en,
      eth_tx_d_o     => eth_tx_d,
      eth_rxer_i     => eth_rxer,
      eth_led2_o     => eth_led2,
      eth_mdc_o      => eth_mdc,
      eth_mdio_io    => eth_mdio,
      kb_io0_o       => kb_io0,
      kb_io1_o       => kb_io1,
      kb_io2_i       => kb_io2,
      vdac_blank_n_o => vdac_blank_n,
      vdac_clk_o     => vdac_clk,
      vdac_psave_n_o => vdac_psave_n,
      vdac_sync_n_o  => vdac_sync_n,
      vga_blue_o     => vga_blue,
      vga_green_o    => vga_green,
      vga_hs_o       => vga_hs,
      vga_red_o      => vga_red,
      vga_vs_o       => vga_vs
    ); -- top_inst : entity work.top

end architecture simulation;

