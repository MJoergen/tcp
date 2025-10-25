library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_tcp_wrapper is
  generic (
    G_SHOW_TESTS    : boolean := false;
    G_SHOW_PACKETS  : boolean := false;
    G_SHOW_PROTOCOL : boolean := false
  );
end entity tb_tcp_wrapper;

-- Connect a TCP client and a TCP server and send data back and forth.

architecture simulation of tb_tcp_wrapper is

  constant C_IP_PAYLOAD_BYTES : natural                       := 30;
  constant C_SESSION_BYTES    : natural                       := 20;
  constant C_PORT_CLIENT      : std_logic_vector(15 downto 0) := X"C713";
  constant C_PORT_SERVER      : std_logic_vector(15 downto 0) := X"0053";

  constant C_TIMEOUT : time                                   := 200 ns;

  signal   clk     : std_logic                                := '1';
  signal   rst     : std_logic                                := '1';
  signal   ppms    : std_logic                                := '0';
  signal   running : std_logic                                := '1';

  signal   client_session_start       : std_logic;
  signal   client_session_src_port    : std_logic_vector(15 downto 0);
  signal   client_session_dst_port    : std_logic_vector(15 downto 0);
  signal   client_session_established : std_logic;
  signal   client_session_rx_ready    : std_logic;
  signal   client_session_rx_valid    : std_logic;
  signal   client_session_rx_data     : std_logic_vector(C_SESSION_BYTES * 8 - 1 downto 0);
  signal   client_session_rx_bytes    : natural range 0 to C_SESSION_BYTES - 1;
  signal   client_session_tx_ready    : std_logic;
  signal   client_session_tx_valid    : std_logic;
  signal   client_session_tx_data     : std_logic_vector(C_SESSION_BYTES * 8 - 1 downto 0);
  signal   client_session_tx_bytes    : natural range 0 to C_SESSION_BYTES - 1;

  -- Client to Server
  signal   tb_ip_payload_c2s_ready : std_logic;
  signal   tb_ip_payload_c2s_valid : std_logic;
  signal   tb_ip_payload_c2s_data  : std_logic_vector(C_IP_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   tb_ip_payload_c2s_bytes : natural range 0 to C_IP_PAYLOAD_BYTES - 1;
  signal   tb_ip_payload_c2s_last  : std_logic;

  -- Server to Client
  signal   tb_ip_payload_s2c_ready : std_logic;
  signal   tb_ip_payload_s2c_valid : std_logic;
  signal   tb_ip_payload_s2c_data  : std_logic_vector(C_IP_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   tb_ip_payload_s2c_bytes : natural range 0 to C_IP_PAYLOAD_BYTES - 1;
  signal   tb_ip_payload_s2c_last  : std_logic;

  signal   server_session_start       : std_logic;
  signal   server_session_src_port    : std_logic_vector(15 downto 0);
  signal   server_session_dst_port    : std_logic_vector(15 downto 0);
  signal   server_session_established : std_logic;
  signal   server_session_rx_ready    : std_logic;
  signal   server_session_rx_valid    : std_logic;
  signal   server_session_rx_data     : std_logic_vector(C_SESSION_BYTES * 8 - 1 downto 0);
  signal   server_session_rx_bytes    : natural range 0 to C_SESSION_BYTES - 1;
  signal   server_session_tx_ready    : std_logic;
  signal   server_session_tx_valid    : std_logic;
  signal   server_session_tx_data     : std_logic_vector(C_SESSION_BYTES * 8 - 1 downto 0);
  signal   server_session_tx_bytes    : natural range 0 to C_SESSION_BYTES - 1;

begin

  -------------------------------------
  -- Clock and reset
  -------------------------------------

  clk <= running and not clk after 5 ns;
  rst <= '1', '0' after 100 ns;
  ppms_proc : process
    variable next_v : time := 100 us;
  begin
    wait until now = next_v;
    next_v := now + 100 us;
    wait until rising_edge(clk);
    ppms <= '1';
    wait until rising_edge(clk);
    ppms <= '0';
    wait until rising_edge(clk);
  end process ppms_proc;


  -------------------------------------
  -- Main test procedure
  -------------------------------------

  test_proc : process
    --

    procedure client_send (
      data : std_logic_vector
    )
    is
      variable data_v : std_logic_vector(data'high downto data'low);
    begin
      if G_SHOW_TESTS then
        report "TB: client_send: " & to_hstring(data);
      end if;
      data_v                               := data;
      client_session_tx_valid              <= '1';
      client_session_tx_data(data_v'range) <= data_v;
      client_session_tx_bytes              <= data_v'length / 8;
      wait until rising_edge(clk);
      while client_session_tx_ready = '0' loop
        wait until rising_edge(clk);
      end loop;
      client_session_tx_valid <= '0';

      wait until rising_edge(clk); -- TBD
      wait until rising_edge(clk); -- TBD
    end procedure client_send;

    procedure client_verify (
      data : std_logic_vector
    )
    is
      variable data_v : std_logic_vector(data'high downto data'low);
    begin
      data_v                  := data;
      client_session_rx_ready <= '1';
      while client_session_rx_valid = '0' loop
        wait until rising_edge(clk);
      end loop;
      if G_SHOW_TESTS then
        report "TB: client_verify: Received " &
               to_hstring(client_session_rx_data(data_v'range));
      end if;
      assert client_session_rx_data(data_v'range)   = data_v
        report "TB: client_verify FAIL. Expected " & to_hstring(data_v);
      assert client_session_rx_bytes = data_v'length / 8;
    end procedure client_verify;

    procedure server_send (
      data : std_logic_vector
    )
    is
      variable data_v : std_logic_vector(data'high downto data'low);
    begin
      if G_SHOW_TESTS then
        report "TB: server_send: " & to_hstring(data);
      end if;
      data_v                               := data;
      server_session_tx_valid              <= '1';
      server_session_tx_data(data_v'range) <= data_v;
      server_session_tx_bytes              <= data_v'length / 8;
      wait until rising_edge(clk);
      while server_session_tx_ready = '0' loop
        wait until rising_edge(clk);
      end loop;
      server_session_tx_valid <= '0';

      wait until rising_edge(clk); -- TBD
      wait until rising_edge(clk); -- TBD
    end procedure server_send;

    procedure server_verify (
      data : std_logic_vector
    )
    is
      variable data_v : std_logic_vector(data'high downto data'low);
    begin
      data_v                  := data;
      server_session_rx_ready <= '1';
      while server_session_rx_valid = '0' loop
        wait until rising_edge(clk);
      end loop;
      if G_SHOW_TESTS then
        report "TB: server_verify Received " &
               to_hstring(server_session_rx_data(data_v'range));
      end if;
      assert server_session_rx_data(data_v'range)   = data_v
        report "TB: server_verify FAIL. Expected " & to_hstring(data_v);
      assert server_session_rx_bytes = data_v'length / 8;
    end procedure server_verify;

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

    if G_SHOW_TESTS then
      report "TB: Starting server";
    end if;
    server_session_src_port <= C_PORT_SERVER;
    server_session_dst_port <= (others => '0'); -- This indicates a server
    server_session_start    <= '1';
    wait until rising_edge(clk);

    if G_SHOW_TESTS then
      report "TB: Starting client";
    end if;
    client_session_src_port <= C_PORT_CLIENT;
    client_session_dst_port <= C_PORT_SERVER;
    client_session_start    <= '1';
    wait until rising_edge(clk);

    if G_SHOW_TESTS then
      report "TB: Waiting for connection";
    end if;
    timeout_v               := now + C_TIMEOUT;
    while (client_session_established /= '1' or server_session_established /= '1') and
      now < timeout_v
    loop
      wait until rising_edge(clk);
    end loop;

    assert now < timeout_v
      report "TB: FAIL: Timeout waiting for connection";

    if G_SHOW_TESTS then
      report "TB: Sending data";
    end if;
    client_send(X"4321");
    server_verify(X"4321");
    server_send(X"8765");
    client_verify(X"8765");

    assert client_session_established = '1';
    assert server_session_established = '1';

    if G_SHOW_TESTS then
      report "TB: Closing down client";
    end if;
    client_session_start <= '0';
    wait until rising_edge(clk);

    if G_SHOW_TESTS then
      report "TB: Server waiting for closure from client";
    end if;
    timeout_v            := now + C_TIMEOUT;
    while (server_session_established /= '0') and
      now < timeout_v
    loop
      wait until rising_edge(clk);
    end loop;

    assert now < timeout_v
      report "TB: FAIL: Timeout waiting for closure";

    if G_SHOW_TESTS then
      report "TB: Closing down server";
    end if;
    server_session_start <= '0';
    wait until rising_edge(clk);

    if G_SHOW_TESTS then
      report "TB: Client waiting for closure from server";
    end if;
    timeout_v            := now + C_TIMEOUT;
    while (client_session_established /= '0') and
      now < timeout_v
    loop
      wait until rising_edge(clk);
    end loop;

    assert now < timeout_v
      report "TB: FAIL: Timeout waiting for closure";

    report "TB: Test stopped";
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    running <= '0';
    wait;
  end process test_proc;


  -------------------------------------
  -- Instantiate DUT client (initiator)
  -------------------------------------

  tcp_wrapper_client_inst : entity work.tcp_wrapper
    generic map (
      G_SHOW_PROTOCOL           => G_SHOW_PROTOCOL,
      G_INITIAL_SEQUENCE_NUMBER => X"11223344",
      G_SIM_NAME                => "CLIENT",
      G_IP_PAYLOAD_BYTES        => C_IP_PAYLOAD_BYTES,
      G_SESSION_BYTES           => C_SESSION_BYTES
    )
    port map (
      clk_i                 => clk,
      rst_i                 => rst,
      ppms_i                => ppms,
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
      ip_payload_rx_ready_o => tb_ip_payload_s2c_ready,
      ip_payload_rx_valid_i => tb_ip_payload_s2c_valid,
      ip_payload_rx_data_i  => tb_ip_payload_s2c_data,
      ip_payload_rx_bytes_i => tb_ip_payload_s2c_bytes,
      ip_payload_rx_last_i  => tb_ip_payload_s2c_last,
      ip_payload_tx_ready_i => tb_ip_payload_c2s_ready,
      ip_payload_tx_valid_o => tb_ip_payload_c2s_valid,
      ip_payload_tx_data_o  => tb_ip_payload_c2s_data,
      ip_payload_tx_bytes_o => tb_ip_payload_c2s_bytes,
      ip_payload_tx_last_o  => tb_ip_payload_c2s_last
    ); -- tcp_wrapper_client_inst : entity work.tcp_wrapper


  -------------------------------------
  -- Instantiate DUT server (responder)
  -------------------------------------

  tcp_wrapper_server_inst : entity work.tcp_wrapper
    generic map (
      G_SHOW_PROTOCOL           => G_SHOW_PROTOCOL,
      G_INITIAL_SEQUENCE_NUMBER => X"55667788",
      G_SIM_NAME                => "SERVER",
      G_IP_PAYLOAD_BYTES        => C_IP_PAYLOAD_BYTES,
      G_SESSION_BYTES           => C_SESSION_BYTES
    )
    port map (
      clk_i                 => clk,
      rst_i                 => rst,
      ppms_i                => ppms,
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
      ip_payload_rx_ready_o => tb_ip_payload_c2s_ready,
      ip_payload_rx_valid_i => tb_ip_payload_c2s_valid,
      ip_payload_rx_data_i  => tb_ip_payload_c2s_data,
      ip_payload_rx_bytes_i => tb_ip_payload_c2s_bytes,
      ip_payload_rx_last_i  => tb_ip_payload_c2s_last,
      ip_payload_tx_ready_i => tb_ip_payload_s2c_ready,
      ip_payload_tx_valid_o => tb_ip_payload_s2c_valid,
      ip_payload_tx_data_o  => tb_ip_payload_s2c_data,
      ip_payload_tx_bytes_o => tb_ip_payload_s2c_bytes,
      ip_payload_tx_last_o  => tb_ip_payload_s2c_last
    ); -- tcp_wrapper_server_inst : entity work.tcp_wrapper

  data_logger_c2s_inst : entity work.data_logger
    generic map (
      G_ENABLE    => G_SHOW_PACKETS,
      G_LOG_NAME  => "C2S", -- Client to Server
      G_DATA_SIZE => C_IP_PAYLOAD_BYTES * 8
    )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      ready_i => tb_ip_payload_c2s_ready,
      valid_i => tb_ip_payload_c2s_valid,
      data_i  => tb_ip_payload_c2s_data,
      bytes_i => tb_ip_payload_c2s_bytes,
      last_i  => tb_ip_payload_c2s_last
    ); -- data_logger_c2s_inst : entity work.data_logger

  data_logger_s2c_inst : entity work.data_logger
    generic map (
      G_ENABLE    => G_SHOW_PACKETS,
      G_LOG_NAME  => "S2C", -- Server to Client
      G_DATA_SIZE => C_IP_PAYLOAD_BYTES * 8
    )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      ready_i => tb_ip_payload_s2c_ready,
      valid_i => tb_ip_payload_s2c_valid,
      data_i  => tb_ip_payload_s2c_data,
      bytes_i => tb_ip_payload_s2c_bytes,
      last_i  => tb_ip_payload_s2c_last
    ); -- data_logger_s2c_inst : entity work.data_logger

end architecture simulation;

