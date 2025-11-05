library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.video_modes_pkg.all;

-- This provides a generic user interface to the MEGA65 platform

entity mega65_wrapper is
  generic (
    G_UART_BAUDRATE : natural;
    G_SIM           : boolean
  );
  port (
    --------------------------------------------------------
    -- Connect to MEGA65 I/O ports
    --------------------------------------------------------

    -- Board clock and reset
    sys_clk_i            : in    std_logic; -- 100 MHz
    sys_rst_i            : in    std_logic;

    -- UART
    debug_rxd_i          : in    std_logic;
    debug_txd_o          : out   std_logic;

    -- Keyboard interface
    kb_io0_o             : out   std_logic;
    kb_io1_o             : out   std_logic;
    kb_io2_i             : in    std_logic;

    -- VGA interface
    vdac_blank_n_o       : out   std_logic;
    vdac_clk_o           : out   std_logic;
    vdac_psave_n_o       : out   std_logic;
    vdac_sync_n_o        : out   std_logic;
    vga_blue_o           : out   std_logic_vector(7 downto 0);
    vga_green_o          : out   std_logic_vector(7 downto 0);
    vga_hs_o             : out   std_logic;
    vga_red_o            : out   std_logic_vector(7 downto 0);
    vga_vs_o             : out   std_logic;

    -- Ethernet interface
    eth_clk_o            : out   std_logic;
    eth_led2_o           : out   std_logic;
    eth_mdc_o            : out   std_logic;
    eth_mdio_io          : inout std_logic;
    eth_rst_n_o          : out   std_logic;
    eth_rx_d_i           : in    std_logic_vector(1 downto 0);
    eth_crs_dv_i         : in    std_logic;
    eth_rxer_i           : in    std_logic;
    eth_tx_d_o           : out   std_logic_vector(1 downto 0);
    eth_tx_en_o          : out   std_logic;


    --------------------------------------------------------
    -- Connect to design (everything in user_clk domain)
    --------------------------------------------------------

    user_clk_o           : out   std_logic; -- 100 MHz
    user_rst_o           : out   std_logic;

    -- UART interface
    user_uart_rx_ready_i : in    std_logic;
    user_uart_rx_valid_o : out   std_logic;
    user_uart_rx_data_o  : out   std_logic_vector(7 downto 0);
    user_uart_tx_ready_o : out   std_logic;
    user_uart_tx_valid_i : in    std_logic;
    user_uart_tx_data_i  : in    std_logic_vector(7 downto 0);

    -- Keyboard events
    user_key_num_o       : out   integer range 0 to 79;
    user_key_pressed_n_o : out   std_logic;

    -- VGA frame buffer
    user_vga_addr_i      : in    std_logic_vector(15 downto 0);
    user_vga_data_i      : in    std_logic_vector(7 downto 0);
    user_vga_wren_i      : in    std_logic;

    -- Ethernet
    user_mac_rx_ready_i  : in    std_logic;
    user_mac_rx_valid_o  : out   std_logic;
    user_mac_rx_data_o   : out   std_logic_vector(7 downto 0);
    user_mac_rx_last_o   : out   std_logic;
    user_mac_tx_ready_o  : out   std_logic;
    user_mac_tx_valid_i  : in    std_logic;
    user_mac_tx_data_i   : in    std_logic_vector(7 downto 0);
    user_mac_tx_last_i   : in    std_logic
  );
end entity mega65_wrapper;

architecture synthesis of mega65_wrapper is

  constant C_USER_CLK_KHZ  : natural := 100_000;

  signal   vga_clk : std_logic;
  signal   vga_rst : std_logic;
  signal   eth_clk : std_logic;
  signal   eth_rst : std_logic;

begin

  ---------------------------------------------------------
  -- Local Clock and Reset
  ---------------------------------------------------------

  clk_rst_inst : entity work.clk_rst
    port map (
      sys_clk_i  => sys_clk_i,  -- 100 MHz
      sys_rst_i  => sys_rst_i,
      user_clk_o => user_clk_o, -- 100 MHz
      user_rst_o => user_rst_o,
      eth_clk_o  => eth_clk,    -- 50 MHz
      eth_rst_o  => eth_rst,
      vga_clk_o  => vga_clk,    -- 74.25 MHz
      vga_rst_o  => vga_rst
    ); -- clk_rst_inst


  ---------------------------------------------------------
  -- UART
  ---------------------------------------------------------

  uart_serdes_inst : entity work.uart_serdes
    generic map (
      G_DIVISOR => (C_USER_CLK_KHZ * 1000) / G_UART_BAUDRATE
    )
    port map (
      clk_i      => user_clk_o,
      rst_i      => user_rst_o,
      uart_tx_o  => debug_txd_o,
      uart_rx_i  => debug_rxd_i,
      -- Connection to user design
      tx_valid_i => user_uart_tx_valid_i,
      tx_ready_o => user_uart_tx_ready_o,
      tx_data_i  => user_uart_tx_data_i,
      rx_valid_o => user_uart_rx_valid_o,
      rx_ready_i => user_uart_rx_ready_i,
      rx_data_o  => user_uart_rx_data_o
    ); -- uart_serdes_inst : entity work.uart_serdes


  ----------------------------
  -- Keyboard
  ----------------------------

  keyboard_wrapper_inst : entity work.keyboard_wrapper
    generic map (
      G_SCAN_FREQUENCY => 1000
    )
    port map (
      clk_main_i       => user_clk_o,
      clk_main_speed_i => C_USER_CLK_KHZ * 1000,
      kio8_o           => kb_io0_o,
      kio9_o           => kb_io1_o,
      kio10_i          => kb_io2_i,
      enable_core_i    => '1',
      power_led_i      => '1',
      power_led_col_i  => X"445566",
      drive_led_i      => '1',
      drive_led_col_i  => X"665544",
      qnice_keys_n_o   => open,
      -- Connection to user design
      key_num_o        => user_key_num_o,
      key_pressed_n_o  => user_key_pressed_n_o
    ); -- keyboard_wrapper_inst : entity work.keyboard_wrapper


  --------------------------------------------------
  -- Instantiate VGA wrapper
  --------------------------------------------------

  vga_wrapper_inst : entity work.vga_wrapper
    port map (
      user_clk_i      => user_clk_o,
      user_rst_i      => user_rst_o,
      vga_clk_i       => vga_clk,
      vga_rst_i       => vga_rst,
      vdac_blank_n_o  => vdac_blank_n_o,
      vdac_clk_o      => vdac_clk_o,
      vdac_psave_n_o  => vdac_psave_n_o,
      vdac_sync_n_o   => vdac_sync_n_o,
      vga_blue_o      => vga_blue_o,
      vga_green_o     => vga_green_o,
      vga_hs_o        => vga_hs_o,
      vga_red_o       => vga_red_o,
      vga_vs_o        => vga_vs_o,
      -- Connection to user design
      user_vga_addr_i => user_vga_addr_i,
      user_vga_data_i => user_vga_data_i,
      user_vga_wren_i => user_vga_wren_i
    ); -- vga_wrapper_inst : entity work.vga_wrapper


  --------------------------------------------------
  -- Instantiate Ethernet wrapper
  --------------------------------------------------

  eth_wrapper_inst : entity work.eth_wrapper
    generic map (
      G_SIM => G_SIM
    )
    port map (
      user_clk_i      => user_clk_o,
      user_rst_i      => user_rst_o,
      eth_clk_i       => eth_clk,
      eth_rst_i       => eth_rst,
      eth_clk_o       => eth_clk_o,
      eth_rst_n_o     => eth_rst_n_o,
      eth_led2_o      => eth_led2_o,
      eth_mdc_o       => eth_mdc_o,
      eth_mdio_io     => eth_mdio_io,
      eth_rx_d_i      => eth_rx_d_i,
      eth_crs_dv_i    => eth_crs_dv_i,
      eth_rxer_i      => eth_rxer_i,
      eth_tx_d_o      => eth_tx_d_o,
      eth_tx_en_o     => eth_tx_en_o,
      -- Connection to user design
      user_rx_ready_i => user_mac_rx_ready_i,
      user_rx_valid_o => user_mac_rx_valid_o,
      user_rx_data_o  => user_mac_rx_data_o,
      user_rx_last_o  => user_mac_rx_last_o,
      user_tx_ready_o => user_mac_tx_ready_o,
      user_tx_valid_i => user_mac_tx_valid_i,
      user_tx_data_i  => user_mac_tx_data_i,
      user_tx_last_i  => user_mac_tx_last_i
    ); -- eth_wrapper_inst

end architecture synthesis;

