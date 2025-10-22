-- ----------------------------------------------------------------------------
-- Title      : Main FPGA
-- Project    : XENTA, RCU, PCB1036 Board
-- ----------------------------------------------------------------------------
-- File       : tb_tcp_wrapper.vhd
-- Author     : Michael Jørgensen
-- Company    : Weibel Scientific
-- Created    : 2025-05-19
-- Platform   : Simulation
-- ----------------------------------------------------------------------------
-- Description:
-- Simple testbench for the MAC to WBUS interface.
-- ----------------------------------------------------------------------------

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_tcp_wrapper is
end entity tb_tcp_wrapper;

architecture simulation of tb_tcp_wrapper is

  constant C_BYTES       : natural                       := 30;
  constant C_PORT_CLIENT : std_logic_vector(15 downto 0) := X"C713";
  constant C_PORT_SERVER : std_logic_vector(15 downto 0) := X"0053";

  signal   clk     : std_logic                           := '1';
  signal   rst     : std_logic                           := '1';
  signal   running : std_logic                           := '1';

  signal   client_session_start       : std_logic;
  signal   client_session_src_port    : std_logic_vector(15 downto 0);
  signal   client_session_dst_port    : std_logic_vector(15 downto 0);
  signal   client_session_established : std_logic;
  signal   client_session_rx_ready    : std_logic;
  signal   client_session_rx_valid    : std_logic;
  signal   client_session_rx_data     : std_logic_vector(C_BYTES * 8 - 1 downto 0);
  signal   client_session_rx_bytes    : natural range 0 to C_BYTES - 1;
  signal   client_session_tx_ready    : std_logic;
  signal   client_session_tx_valid    : std_logic;
  signal   client_session_tx_data     : std_logic_vector(C_BYTES * 8 - 1 downto 0);
  signal   client_session_tx_bytes    : natural range 0 to C_BYTES - 1;

  signal   tb_ip_payload_rx_ready : std_logic;
  signal   tb_ip_payload_rx_valid : std_logic;
  signal   tb_ip_payload_rx_data  : std_logic_vector(C_BYTES * 8 - 1 downto 0);
  signal   tb_ip_payload_rx_bytes : natural range 0 to C_BYTES - 1;
  signal   tb_ip_payload_rx_last  : std_logic;
  signal   tb_ip_payload_tx_ready : std_logic;
  signal   tb_ip_payload_tx_valid : std_logic;
  signal   tb_ip_payload_tx_data  : std_logic_vector(C_BYTES * 8 - 1 downto 0);
  signal   tb_ip_payload_tx_bytes : natural range 0 to C_BYTES - 1;
  signal   tb_ip_payload_tx_last  : std_logic;

  signal   server_session_start       : std_logic;
  signal   server_session_src_port    : std_logic_vector(15 downto 0);
  signal   server_session_dst_port    : std_logic_vector(15 downto 0);
  signal   server_session_established : std_logic;
  signal   server_session_rx_ready    : std_logic;
  signal   server_session_rx_valid    : std_logic;
  signal   server_session_rx_data     : std_logic_vector(C_BYTES * 8 - 1 downto 0);
  signal   server_session_rx_bytes    : natural range 0 to C_BYTES - 1;
  signal   server_session_tx_ready    : std_logic;
  signal   server_session_tx_valid    : std_logic;
  signal   server_session_tx_data     : std_logic_vector(C_BYTES * 8 - 1 downto 0);
  signal   server_session_tx_bytes    : natural range 0 to C_BYTES - 1;

begin

  -------------------------------------
  -- Clock and reset
  -------------------------------------

  clk <= running and not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  -------------------------------------
  -- Instante DUT client
  -------------------------------------

  test_proc : process
    --

    procedure client_send (
      data : std_logic_vector
    )
    is
    begin
      client_session_tx_valid                           <= '1';
      client_session_tx_data(data'high downto data'low) <= data;
      client_session_tx_bytes                           <= data'length / 8;
      wait until rising_edge(clk);
      while client_session_tx_ready = '0' loop
        wait until rising_edge(clk);
      end loop;
      client_session_tx_valid <= '0';
    end procedure client_send;

    procedure client_verify (
      data : std_logic_vector
    )
    is
    begin
      client_session_rx_ready <= '1';
      while client_session_rx_valid = '0' loop
        wait until rising_edge(clk);
      end loop;
      assert client_session_rx_data(data'high downto data'low)   = data;
      assert client_session_rx_bytes = data'length / 8;
    end procedure;

    procedure server_send (
      data : std_logic_vector
    )
    is
    begin
      server_session_tx_valid                           <= '1';
      server_session_tx_data(data'high downto data'low) <= data;
      server_session_tx_bytes                           <= data'length / 8;
      wait until rising_edge(clk);
      while server_session_tx_ready = '0' loop
        wait until rising_edge(clk);
      end loop;
      server_session_tx_valid <= '0';
    end procedure server_send;

    procedure server_verify (
      data : std_logic_vector
    )
    is
    begin
      server_session_rx_ready <= '1';
      while server_session_rx_valid = '0' loop
        wait until rising_edge(clk);
      end loop;
      assert server_session_rx_data(data'high downto data'low)   = data
        report "server_verify FAIL. Received " &
               to_hstring(server_session_rx_data(data'high downto data'low)) &
               ", expected " & to_hstring(data);
      assert server_session_rx_bytes = data'length / 8;
    end procedure;

    variable timeout_v : time;
  begin
    client_session_start    <= '0';
    client_session_rx_ready <= '0';
    client_session_tx_valid <= '0';
    server_session_start    <= '0';
    server_session_rx_ready <= '0';
    server_session_tx_valid <= '0';

    wait until rst = '0';
    wait for 100 ns;
    wait until rising_edge(clk);

    report "TB: Test started";

    report "TB: Starting server";
    server_session_src_port <= C_PORT_SERVER;
    server_session_dst_port <= (others => '0');
    server_session_start    <= '1';
    wait until rising_edge(clk);

    report "TB: Starting client";
    client_session_src_port <= C_PORT_CLIENT;
    client_session_dst_port <= C_PORT_SERVER;
    client_session_start    <= '1';
    wait until rising_edge(clk);

    report "TB: Waiting for connection";
    timeout_v               := now + 1 ms;
    while (client_session_established /= '1' or server_session_established /= '1') and
      now < timeout_v
    loop
      wait until rising_edge(clk);
    end loop;

    assert now < timeout_v
      report "TB: Timeout waiting for connection";

    report "TB: Sending data";
    client_send(X"4321");
    server_verify(X"4321");
    server_send(X"8765");
    client_verify(X"8765");

    assert client_session_established = '1';
    assert server_session_established = '1';

    report "TB: Closing down client";
    client_session_start <= '0';
    wait until rising_edge(clk);

    report "TB: Waiting for closure";
    timeout_v            := now + 1 ms;
    while (client_session_established /= '0' or server_session_established /= '0') and
      now < timeout_v
    loop
      wait until rising_edge(clk);
    end loop;

    assert now < timeout_v
      report "TB: Timeout waiting for closure";

    report "TB: Test stopped";
    wait until rising_edge(clk);
    running <= '0';
    wait;
  end process test_proc;


  -------------------------------------
  -- Instante DUT client (initiator)
  -------------------------------------

  tcp_wrapper_client_inst : entity work.tcp_wrapper
    generic map (
      G_SIM_NAME => "CLIENT",
      G_BYTES    => C_BYTES
    )
    port map (
      clk_i                 => clk,
      rst_i                 => rst,
      session_start_i       => client_session_start,
      session_src_port_i    => client_session_src_port,
      session_dst_port_i    => client_session_dst_port,
      session_established_o => client_session_established,
      session_rx_ready_i    => client_session_rx_ready,
      session_rx_valid_o    => client_session_rx_valid,
      session_rx_data_o     => client_session_rx_data,
      session_rx_bytes_o    => client_session_rx_bytes,
      session_tx_ready_o    => client_session_tx_ready,
      session_tx_valid_i    => client_session_tx_valid,
      session_tx_data_i     => client_session_tx_data,
      session_tx_bytes_i    => client_session_tx_bytes,
      ip_payload_rx_ready_o => tb_ip_payload_rx_ready,
      ip_payload_rx_valid_i => tb_ip_payload_rx_valid,
      ip_payload_rx_data_i  => tb_ip_payload_rx_data,
      ip_payload_rx_bytes_i => tb_ip_payload_rx_bytes,
      ip_payload_rx_last_i  => tb_ip_payload_rx_last,
      ip_payload_tx_ready_i => tb_ip_payload_tx_ready,
      ip_payload_tx_valid_o => tb_ip_payload_tx_valid,
      ip_payload_tx_data_o  => tb_ip_payload_tx_data,
      ip_payload_tx_bytes_o => tb_ip_payload_tx_bytes,
      ip_payload_tx_last_o  => tb_ip_payload_tx_last
    ); -- tcp_wrapper_client_inst : entity work.tcp_wrapper


  -------------------------------------
  -- Instante DUT server (responder)
  -------------------------------------

  tcp_wrapper_server_inst : entity work.tcp_wrapper
    generic map (
      G_SIM_NAME => "SERVER",
      G_BYTES    => C_BYTES
    )
    port map (
      clk_i                 => clk,
      rst_i                 => rst,
      session_start_i       => server_session_start,
      session_src_port_i    => server_session_src_port,
      session_dst_port_i    => server_session_dst_port,
      session_established_o => server_session_established,
      session_rx_ready_i    => server_session_rx_ready,
      session_rx_valid_o    => server_session_rx_valid,
      session_rx_data_o     => server_session_rx_data,
      session_rx_bytes_o    => server_session_rx_bytes,
      session_tx_ready_o    => server_session_tx_ready,
      session_tx_valid_i    => server_session_tx_valid,
      session_tx_data_i     => server_session_tx_data,
      session_tx_bytes_i    => server_session_tx_bytes,
      ip_payload_rx_ready_o => tb_ip_payload_tx_ready,
      ip_payload_rx_valid_i => tb_ip_payload_tx_valid,
      ip_payload_rx_data_i  => tb_ip_payload_tx_data,
      ip_payload_rx_bytes_i => tb_ip_payload_tx_bytes,
      ip_payload_rx_last_i  => tb_ip_payload_tx_last,
      ip_payload_tx_ready_i => tb_ip_payload_rx_ready,
      ip_payload_tx_valid_o => tb_ip_payload_rx_valid,
      ip_payload_tx_data_o  => tb_ip_payload_rx_data,
      ip_payload_tx_bytes_o => tb_ip_payload_rx_bytes,
      ip_payload_tx_last_o  => tb_ip_payload_rx_last
    ); -- tcp_wrapper_server_inst : entity work.tcp_wrapper

end architecture simulation;

