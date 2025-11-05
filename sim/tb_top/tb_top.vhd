library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

entity tb_top is
end entity tb_top;

architecture simulation of tb_top is

  constant C_SYS_CLK_KHZ   : natural := 100_000;
  constant C_UART_BAUDRATE : natural := 5_000_000;

  -- DUT ports
  signal   sys_clk      : std_logic  := '1';
  signal   sys_rst      : std_logic  := '1';
  signal   debug_rxd    : std_logic  := '1';
  signal   debug_txd    : std_logic  := '1';
  signal   eth_clk      : std_logic;
  signal   eth_rst_n    : std_logic;
  signal   eth_crs_dv   : std_logic;
  signal   eth_rx_d     : std_logic_vector(1 downto 0);
  signal   eth_tx_en    : std_logic;
  signal   eth_tx_d     : std_logic_vector(1 downto 0);
  signal   eth_rxer     : std_logic  := '0';
  signal   eth_led2     : std_logic;
  signal   eth_mdc      : std_logic;
  signal   eth_mdio     : std_logic;
  signal   kb_io0       : std_logic := '1';
  signal   kb_io1       : std_logic := '1';
  signal   kb_io2       : std_logic := '1';
  signal   vdac_blank_n : std_logic;
  signal   vdac_clk     : std_logic;
  signal   vdac_psave_n : std_logic;
  signal   vdac_sync_n  : std_logic;
  signal   vga_blue     : std_logic_vector(7 downto 0);
  signal   vga_green    : std_logic_vector(7 downto 0);
  signal   vga_hs       : std_logic;
  signal   vga_red      : std_logic_vector(7 downto 0);
  signal   vga_vs       : std_logic;

  signal   eth_tb_rx_valid : std_logic;
  signal   eth_tb_rx_last  : std_logic;
  signal   eth_tb_rx_ok    : std_logic;
  signal   eth_tb_rx_data  : std_logic_vector(7 downto 0);
  signal   eth_tb_tx_ready : std_logic;
  signal   eth_tb_tx_valid : std_logic;
  signal   eth_tb_tx_last  : std_logic;
  signal   eth_tb_tx_data  : std_logic_vector(7 downto 0);

  constant C_BYTES : natural         := 60;

  signal   eth_tb_tx_wide_ready : std_logic;
  signal   eth_tb_tx_wide_valid : std_logic;
  signal   eth_tb_tx_wide_last  : std_logic;
  signal   eth_tb_tx_wide_bytes : natural range 0 to C_BYTES;
  signal   eth_tb_tx_wide_data  : std_logic_vector(C_BYTES * 8 - 1 downto 0);

  signal   eth_tb_rx_wide_ready : std_logic;
  signal   eth_tb_rx_wide_valid : std_logic;
  signal   eth_tb_rx_wide_last  : std_logic;
  signal   eth_tb_rx_wide_bytes : natural range 0 to C_BYTES;
  signal   eth_tb_rx_wide_data  : std_logic_vector(C_BYTES * 8 - 1 downto 0);

  signal   tb_uart_tx_valid : std_logic;
  signal   tb_uart_tx_ready : std_logic;
  signal   tb_uart_tx_data  : std_logic_vector(7 downto 0);
  signal   tb_uart_rx_valid : std_logic;
  signal   tb_uart_rx_ready : std_logic;
  signal   tb_uart_rx_data  : std_logic_vector(7 downto 0);

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
      G_UART_BAUDRATE => C_UART_BAUDRATE,
      G_SIM           => true,
      G_TIMESTAMP     => X"12345678",
      G_COMMIT_ID     => X"87654321"
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


  ----------------------------------------------------------
  -- Generate Stimuli
  ----------------------------------------------------------

  stim_proc : process
  begin
    eth_tb_tx_wide_valid <= '0';
    tb_uart_tx_valid <= '0';
    wait until eth_rst_n = '1';
    wait for 100 ns;

    report "Stimulus UART";
    wait until rising_edge(sys_clk);
    tb_uart_tx_data  <= X"31";
    tb_uart_tx_valid <= '1';
    wait until rising_edge(sys_clk);
    while tb_uart_tx_ready = '0' loop
      wait until rising_edge(sys_clk);
    end loop;
    tb_uart_tx_valid <= '0';
    wait until rising_edge(sys_clk);

    report "Stimulus Ethernet";
    wait until rising_edge(eth_clk);
    eth_tb_tx_wide_data  <= X"1122334455667788" &
                            X"1122334455667788" &
                            X"1122334455667788" &
                            X"1122334455667788" &
                            X"1122334455667788" &
                            X"1122334455667788" &
                            X"1122334455667788" &
                            X"11223344";
    eth_tb_tx_wide_last  <= '1';
    eth_tb_tx_wide_valid <= '1';
    wait until rising_edge(eth_clk);
    while eth_tb_tx_wide_ready = '0' loop
      wait until rising_edge(eth_clk);
    end loop;
    eth_tb_tx_wide_valid <= '0';

    report "Stimulus finished";
    wait;
  end process stim_proc;

  wide2byte_inst : entity work.wide2byte
    generic map (
      G_BYTES => C_BYTES
    )
    port map (
      clk_i     => eth_clk,
      rst_i     => not eth_rst_n,
      s_ready_o => eth_tb_tx_wide_ready,
      s_valid_i => eth_tb_tx_wide_valid,
      s_last_i  => eth_tb_tx_wide_last,
      s_bytes_i => eth_tb_tx_wide_bytes,
      s_data_i  => eth_tb_tx_wide_data,
      m_ready_i => eth_tb_tx_ready,
      m_valid_o => eth_tb_tx_valid,
      m_last_o  => eth_tb_tx_last,
      m_data_o  => eth_tb_tx_data
    ); -- wide2byte_inst : entity work.wide2byte

  eth_rmii_inst : entity work.eth_rmii
    port map (
      eth_clk_i   => eth_clk,
      eth_rst_i   => not eth_rst_n,
      rx_valid_o  => eth_tb_rx_valid,
      rx_last_o   => eth_tb_rx_last,
      rx_ok_o     => eth_tb_rx_ok,
      rx_data_o   => eth_tb_rx_data,
      tx_ready_o  => eth_tb_tx_ready,
      tx_valid_i  => eth_tb_tx_valid,
      tx_last_i   => eth_tb_tx_last,
      tx_data_i   => eth_tb_tx_data,
      eth_rxd_i   => eth_tx_d,
      eth_rxerr_i => '0',
      eth_crsdv_i => eth_tx_en,
      eth_txd_o   => eth_rx_d,
      eth_txen_o  => eth_crs_dv
    ); -- eth_rmii_inst : entity work.eth_rmii

  byte2wide_inst : entity work.byte2wide
    generic map (
      G_BYTES => C_BYTES
    )
    port map (
      clk_i     => eth_clk,
      rst_i     => not eth_rst_n,
      s_ready_o => open,
      s_valid_i => eth_tb_rx_valid,
      s_last_i  => eth_tb_rx_last,
      s_data_i  => eth_tb_rx_data,
      m_ready_i => eth_tb_rx_wide_ready,
      m_valid_o => eth_tb_rx_wide_valid,
      m_last_o  => eth_tb_rx_wide_last,
      m_data_o  => eth_tb_rx_wide_data,
      m_bytes_o => eth_tb_rx_wide_bytes
    ); -- byte2wide_inst : entity work.byte2wide

  eth_resp_proc : process
  begin
    eth_tb_rx_wide_ready <= '0';
    wait until eth_rst_n = '1';
    wait for 100 ns;
    wait until rising_edge(eth_clk);

    eth_tb_rx_wide_ready <= '1';
    wait until rising_edge(eth_clk);
    while eth_tb_rx_wide_valid = '0' loop
      wait until rising_edge(eth_clk);
    end loop;
    report "Ethernet Response: " & to_hstring(eth_tb_rx_wide_data);
    eth_tb_rx_wide_ready <= '0';
    wait until rising_edge(eth_clk);
    wait;
  end process eth_resp_proc;

  uart_resp_proc : process
  begin
    tb_uart_rx_ready <= '0';
    wait until sys_rst = '0';
    wait for 100 ns;
    wait until rising_edge(sys_clk);

    tb_uart_rx_ready <= '1';
    wait until rising_edge(sys_clk);
    while true loop
      while tb_uart_rx_valid = '0' loop
        wait until rising_edge(sys_clk);
      end loop;
      report "UART Response: " & to_hstring(tb_uart_rx_data);
      wait until rising_edge(sys_clk);
    end loop;
  end process uart_resp_proc;

  uart_serdes_inst : entity work.uart_serdes
    generic map (
      G_DIVISOR => (C_SYS_CLK_KHZ * 1000) / C_UART_BAUDRATE
    )
    port map (
      clk_i      => sys_clk,
      rst_i      => sys_rst,
      uart_tx_o  => debug_rxd,
      uart_rx_i  => debug_txd,
      tx_valid_i => tb_uart_tx_valid,
      tx_ready_o => tb_uart_tx_ready,
      tx_data_i  => tb_uart_tx_data,
      rx_valid_o => tb_uart_rx_valid,
      rx_ready_i => tb_uart_rx_ready,
      rx_data_o  => tb_uart_rx_data
    ); -- uart_serdes_inst : entity work.uart_serdes

end architecture simulation;

