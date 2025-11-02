library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

entity top is
  generic (
    G_TIMESTAMP : std_logic_vector(31 downto 0); -- Automatically filled out by Vivado
    G_COMMIT_ID : std_logic_vector(31 downto 0)  -- Automatically filled out by Vivado
  );
  port (
    -- Main input clock and reset
    sys_clk_i      : in    std_logic;
    sys_rst_i      : in    std_logic;

    -- UART
    debug_rxd_i    : in    std_logic;
    debug_txd_o    : out   std_logic;

    -- Ethernet PHY. U4 = KSZ8081RNDCA (SMSC)
    eth_clk_o      : out   std_logic;
    eth_led2_o     : out   std_logic;
    eth_mdc_o      : out   std_logic;
    eth_mdio_io    : inout std_logic;
    eth_rst_n_o    : out   std_logic;
    eth_rx_d_i     : in    std_logic_vector(1 downto 0);
    eth_crs_dv_i   : in    std_logic;
    eth_rxer_i     : in    std_logic;
    eth_tx_d_o     : out   std_logic_vector(1 downto 0);
    eth_tx_en_o    : out   std_logic;

    -- Keyboard
    kb_io0_o       : out   std_logic;
    kb_io1_o       : out   std_logic;
    kb_io2_i       : in    std_logic;

    -- VGA
    vdac_blank_n_o : out   std_logic;
    vdac_clk_o     : out   std_logic;
    vdac_psave_n_o : out   std_logic;
    vdac_sync_n_o  : out   std_logic;
    vga_blue_o     : out   std_logic_vector(7 downto 0);
    vga_green_o    : out   std_logic_vector(7 downto 0);
    vga_hs_o       : out   std_logic;
    vga_red_o      : out   std_logic_vector(7 downto 0);
    vga_vs_o       : out   std_logic
  );
end entity top;

architecture synthesis of top is

  constant C_USER_BYTES : natural := 10;

  signal   user_clk            : std_logic;
  signal   user_rst            : std_logic;
  signal   user_mac_rx_ready   : std_logic;
  signal   user_mac_rx_valid   : std_logic;
  signal   user_mac_rx_data    : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal   user_mac_rx_last    : std_logic;
  signal   user_mac_rx_bytes   : natural range 0 to C_USER_BYTES;
  signal   user_mac_tx_ready   : std_logic;
  signal   user_mac_tx_valid   : std_logic;
  signal   user_mac_tx_data    : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal   user_mac_tx_last    : std_logic;
  signal   user_mac_tx_bytes   : natural range 0 to C_USER_BYTES;
  signal   user_uart_rx_ready_ : std_logic;
  signal   user_uart_rx_valid  : std_logic;
  signal   user_uart_rx_data   : std_logic_vector(7 downto 0);
  signal   user_uart_tx_ready  : std_logic;
  signal   user_uart_tx_valid  : std_logic;
  signal   user_uart_tx_data   : std_logic_vector(7 downto 0);
  signal   user_key_num        : integer range 0 to 79;
  signal   user_key_pressed_n  : std_logic;
  signal   user_vga_addr       : std_logic_vector(15 downto 0);
  signal   user_vga_data       : std_logic_vector(7 downto 0);
  signal   user_vga_wren       : std_logic;

begin

  mega65_wrapper_inst : entity work.mega65_wrapper
    generic map (
      G_USER_BYTES => C_USER_BYTES
    )
    port map (
      sys_clk_i            => sys_clk_i,
      sys_rst_i            => sys_rst_i,
      debug_rxd_i          => debug_rxd_i,
      debug_txd_o          => debug_txd_o,
      kb_io0_o             => kb_io0_o,
      kb_io1_o             => kb_io1_o,
      kb_io2_i             => kb_io2_i,
      vdac_blank_n_o       => vdac_blank_n_o,
      vdac_clk_o           => vdac_clk_o,
      vdac_psave_n_o       => vdac_psave_n_o,
      vdac_sync_n_o        => vdac_sync_n_o,
      vga_blue_o           => vga_blue_o,
      vga_green_o          => vga_green_o,
      vga_hs_o             => vga_hs_o,
      vga_red_o            => vga_red_o,
      vga_vs_o             => vga_vs_o,
      eth_clk_o            => eth_clk_o,
      eth_rst_n_o          => eth_rst_n_o,
      eth_led2_o           => eth_led2_o,
      eth_mdc_o            => eth_mdc_o,
      eth_mdio_io          => eth_mdio_io,
      eth_rx_d_i           => eth_rx_d_i,
      eth_crs_dv_i         => eth_crs_dv_i,
      eth_rxer_i           => eth_rxer_i,
      eth_tx_d_o           => eth_tx_d_o,
      eth_tx_en_o          => eth_tx_en_o,
      user_clk_o           => user_clk,
      user_rst_o           => user_rst,
      user_uart_rx_ready_i => user_uart_rx_ready,
      user_uart_rx_valid_o => user_uart_rx_valid,
      user_uart_rx_data_o  => user_uart_rx_data,
      user_uart_tx_ready_o => user_uart_tx_ready,
      user_uart_tx_valid_i => user_uart_tx_valid,
      user_uart_tx_data_i  => user_uart_tx_data,
      user_key_num_o       => user_key_num,
      user_key_pressed_n_o => user_key_pressed_n,
      user_vga_addr_i      => user_vga_addr,
      user_vga_data_i      => user_vga_data,
      user_vga_wren_i      => user_vga_wren,
      user_mac_rx_ready_i  => user_mac_rx_ready,
      user_mac_rx_valid_o  => user_mac_rx_valid,
      user_mac_rx_data_o   => user_mac_rx_data,
      user_mac_rx_last_o   => user_mac_rx_last,
      user_mac_rx_bytes_o  => user_mac_rx_bytes,
      user_mac_tx_ready_o  => user_mac_tx_ready,
      user_mac_tx_valid_i  => user_mac_tx_valid,
      user_mac_tx_data_i   => user_mac_tx_data,
      user_mac_tx_last_i   => user_mac_tx_last,
      user_mac_tx_bytes_i  => user_mac_tx_bytes
    ); -- mega65_wrapper_inst : entity work.mega65_wrapper

--  design_inst : entity work.design
--    generic map (
--      G_ETH_BYTES => C_USER_BYTES
--    )
--    port map (
--      clk_i          => user_clk,
--      rst_i          => user_rst,
--      eth_rx_ready_o => user_rx_ready,
--      eth_rx_valid_i => user_rx_valid,
--      eth_rx_data_i  => user_rx_data,
--      eth_rx_last_i  => user_rx_last,
--      eth_rx_bytes_i => user_rx_bytes,
--      eth_tx_ready_i => user_tx_ready,
--      eth_tx_valid_o => user_tx_valid,
--      eth_tx_data_o  => user_tx_data,
--      eth_tx_last_o  => user_tx_last,
--      eth_tx_bytes_o => user_tx_bytes
--    ); -- design_inst : entity work.design

end architecture synthesis;

