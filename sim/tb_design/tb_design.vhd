library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

entity tb_design is
end entity tb_design;

architecture simulation of tb_design is

  -- DUT ports
  signal running       : std_logic := '1';
  signal clk           : std_logic := '1';
  signal rst           : std_logic := '1';
  signal uart_rx_ready : std_logic;
  signal uart_rx_valid : std_logic;
  signal uart_rx_data  : std_logic_vector(7 downto 0);
  signal uart_tx_ready : std_logic;
  signal uart_tx_valid : std_logic;
  signal uart_tx_data  : std_logic_vector(7 downto 0);
  signal key_num       : integer range 0 to 79;
  signal key_pressed_n : std_logic;
  signal eth_rx_ready  : std_logic;
  signal eth_rx_valid  : std_logic;
  signal eth_rx_data   : std_logic_vector(7 downto 0);
  signal eth_rx_last   : std_logic;
  signal eth_tx_ready  : std_logic;
  signal eth_tx_valid  : std_logic;
  signal eth_tx_data   : std_logic_vector(7 downto 0);
  signal eth_tx_last   : std_logic;
  signal vga_addr      : std_logic_vector(15 downto 0);
  signal vga_data      : std_logic_vector(23 downto 0);
  signal vga_wren      : std_logic;

begin

  ----------------------------------------------------------
  -- Clock and reset
  ----------------------------------------------------------

  clk <= running and not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------------------
  design_inst : entity work.design
    port map (
      clk_i           => clk,
      rst_i           => rst,
      uart_rx_ready_o => uart_rx_ready,
      uart_rx_valid_i => uart_rx_valid,
      uart_rx_data_i  => uart_rx_data,
      uart_tx_ready_i => uart_tx_ready,
      uart_tx_valid_o => uart_tx_valid,
      uart_tx_data_o  => uart_tx_data,
      key_num_i       => key_num,
      key_pressed_n_i => key_pressed_n,
      eth_rx_ready_o  => eth_rx_ready,
      eth_rx_valid_i  => eth_rx_valid,
      eth_rx_data_i   => eth_rx_data,
      eth_rx_last_i   => eth_rx_last,
      eth_tx_ready_i  => eth_tx_ready,
      eth_tx_valid_o  => eth_tx_valid,
      eth_tx_data_o   => eth_tx_data,
      eth_tx_last_o   => eth_tx_last,
      vga_addr_o      => vga_addr,
      vga_data_o      => vga_data,
      vga_wren_o      => vga_wren
    ); -- design_inst : entity work.design

  test_proc : process
    --

    procedure eth_send (
      frame : std_logic_vector
    ) is
      variable frame_v : std_logic_vector(frame'length - 1 downto 0);
      variable bytes_v : natural;
    begin
      frame_v := frame;
      bytes_v := frame'length/8;

      for i in bytes_v - 1 downto 0 loop
        eth_rx_data <= frame_v(i * 8 + 7 downto i * 8);
        eth_rx_last <= '0';
        if i = 0 then
          eth_rx_last <= '1';
        end if;
        eth_rx_valid <= '1';
        wait until rising_edge(clk);
        while eth_rx_ready = '0' loop
          wait until rising_edge(clk);
        end loop;
      end loop;

      eth_rx_valid <= '0';
      wait until rising_edge(clk);
    end procedure eth_send;

  --
  begin
    uart_rx_valid <= '0';
    uart_tx_ready <= '0';
    key_pressed_n <= '1';
    eth_rx_valid  <= '0';
    eth_tx_ready  <= '0';
    wait until rst = '0';
    wait for 100 ns;
    wait until rising_edge(clk);

    report "Test started";

    eth_send(X"FFFFFFFFFFFF112233445566080045010203040506070809010203040506");
    wait for 10 us;

    wait until rising_edge(clk);

    report "Test finished";
    running       <= '0';
    wait;
  end process test_proc;

end architecture simulation;

