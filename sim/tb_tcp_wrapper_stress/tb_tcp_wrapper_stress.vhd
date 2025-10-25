library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;
library std;
  use std.env.stop;

entity tb_tcp_wrapper_stress is
  generic (
    G_RANDOM        : boolean;
    G_FAST          : boolean;
    G_SHOW_PACKETS  : boolean;
    G_SHOW_PROTOCOL : boolean
  );
end entity tb_tcp_wrapper_stress;

-- Connect a TCP client and a TCP server and send data back and forth.

architecture simulation of tb_tcp_wrapper_stress is

  constant C_IP_PAYLOAD_BYTES : natural                       := 30;
  constant C_SESSION_BYTES    : natural                       := 20;
  constant C_PORT_CLIENT      : std_logic_vector(15 downto 0) := x"C713";
  constant C_PORT_SERVER      : std_logic_vector(15 downto 0) := x"0053";

  constant C_TIMEOUT : time                                   := 200 ns;

  signal   clk     : std_logic                                := '1';
  signal   rst     : std_logic                                := '1';
  signal   ppms    : std_logic                                := '0';
  signal   running : std_logic                                := '1';

  signal   rand : std_logic_vector(63 downto 0);

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
  signal   tb_ip_payload_c2s_ready      : std_logic;
  signal   tb_ip_payload_c2s_valid      : std_logic;
  signal   tb_ip_payload_c2s_data       : std_logic_vector(C_IP_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   tb_ip_payload_c2s_bytes      : natural range 0 to C_IP_PAYLOAD_BYTES - 1;
  signal   tb_ip_payload_c2s_last       : std_logic;
  signal   tb_ip_payload_c2s_data_bytes : std_logic_vector(C_IP_PAYLOAD_BYTES * 8 + 7 downto 0);

  signal   tb_ip_payload_c2s_dropped_ready      : std_logic;
  signal   tb_ip_payload_c2s_dropped_valid      : std_logic;
  signal   tb_ip_payload_c2s_dropped_data       : std_logic_vector(C_IP_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   tb_ip_payload_c2s_dropped_bytes      : natural range 0 to C_IP_PAYLOAD_BYTES - 1;
  signal   tb_ip_payload_c2s_dropped_last       : std_logic;
  signal   tb_ip_payload_c2s_dropped_data_bytes : std_logic_vector(C_IP_PAYLOAD_BYTES * 8 + 7 downto 0);

  -- Server to Client
  signal   tb_ip_payload_s2c_ready      : std_logic;
  signal   tb_ip_payload_s2c_valid      : std_logic;
  signal   tb_ip_payload_s2c_data       : std_logic_vector(C_IP_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   tb_ip_payload_s2c_bytes      : natural range 0 to C_IP_PAYLOAD_BYTES - 1;
  signal   tb_ip_payload_s2c_last       : std_logic;
  signal   tb_ip_payload_s2c_data_bytes : std_logic_vector(C_IP_PAYLOAD_BYTES * 8 + 7 downto 0);

  signal   tb_ip_payload_s2c_dropped_ready      : std_logic;
  signal   tb_ip_payload_s2c_dropped_valid      : std_logic;
  signal   tb_ip_payload_s2c_dropped_data       : std_logic_vector(C_IP_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   tb_ip_payload_s2c_dropped_bytes      : natural range 0 to C_IP_PAYLOAD_BYTES - 1;
  signal   tb_ip_payload_s2c_dropped_last       : std_logic;
  signal   tb_ip_payload_s2c_dropped_data_bytes : std_logic_vector(C_IP_PAYLOAD_BYTES * 8 + 7 downto 0);

  signal   server_session_established : std_logic;
  signal   server_session_rx_ready    : std_logic;
  signal   server_session_rx_valid    : std_logic;
  signal   server_session_rx_data     : std_logic_vector(C_SESSION_BYTES * 8 - 1 downto 0);
  signal   server_session_rx_bytes    : natural range 0 to C_SESSION_BYTES - 1;
  signal   server_session_tx_ready    : std_logic;
  signal   server_session_tx_valid    : std_logic;
  signal   server_session_tx_data     : std_logic_vector(C_SESSION_BYTES * 8 - 1 downto 0);
  signal   server_session_tx_bytes    : natural range 0 to C_SESSION_BYTES - 1;

  signal   do_drop_c2s                : std_logic;
  signal   do_drop_s2c                : std_logic;
  signal   client_session_tx_do_valid : std_logic;

  subtype  R_DATA is natural range C_IP_PAYLOAD_BYTES * 8 - 1 downto 0;

  subtype  R_BYTES is natural range C_IP_PAYLOAD_BYTES * 8 + 7 downto C_IP_PAYLOAD_BYTES * 8;

  signal   stim_cnt   : std_logic_vector(7 downto 0);
  signal   verify_cnt : std_logic_vector(7 downto 0);

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
    ppms   <= '1';
    wait until rising_edge(clk);
    ppms   <= '0';
    wait until rising_edge(clk);
  end process ppms_proc;


  -------------------------------------
  -- Generate randomness
  -------------------------------------

  random_inst : entity work.random
    generic map (
      G_SEED => X"DEADBEAFC007BABE"
    )
    port map (
      clk_i    => clk,
      rst_i    => rst,
      update_i => '1',
      output_o => rand
    ); -- random_inst : entity work.random

  do_drop_c2s                <= and(rand(15 downto 12));
  do_drop_s2c                <= and(rand(25 downto 22));


  -------------------------------------
  -- Generate stimuli
  -------------------------------------

  client_session_tx_do_valid <= or(rand(42 downto 40)) when G_RANDOM else
                                '1';

  stimuli_proc : process (clk)
    variable bytes_v : natural range 1 to C_SESSION_BYTES;
  begin
    if rising_edge(clk) then
      if client_session_tx_ready = '1' then
        client_session_tx_valid <= '0';
        client_session_tx_data  <= (others => '0');
        client_session_tx_bytes <= 0;
      end if;

      if client_session_tx_valid = '0' or (G_FAST and client_session_tx_ready = '1') then
        if client_session_tx_do_valid = '1' then
          bytes_v  := (to_integer(rand(15 downto 0)) mod C_SESSION_BYTES) + 1;

          stim_cnt <= stim_cnt + bytes_v;

          for i in 0 to bytes_v - 1 loop
            client_session_tx_data(i * 8 + 7 downto i * 8) <= stim_cnt + i;
          end loop;

          client_session_tx_valid <= '1';
          client_session_tx_bytes <= bytes_v;
        end if;
      end if;

      if rst = '1' then
        client_session_tx_valid <= '0';
        client_session_tx_data  <= (others => '0');
        stim_cnt                <= (others => '0');
      end if;
    end if;
  end process stimuli_proc;


  -------------------------------------
  -- Verify output
  -------------------------------------

  client_session_rx_ready    <= or(rand(32 downto 30)) when G_RANDOM else
                                '1';

  verify_proc : process (clk)
  begin
    if rising_edge(clk) then
      if client_session_rx_valid = '1' and client_session_rx_ready = '1' then

        for i in 0 to client_session_rx_bytes - 1 loop
          assert client_session_rx_data(i * 8 + 7 downto i * 8) = verify_cnt(7 downto 0) + i
            report "Verify byte " & to_string(i) &
                   ". Received " & to_hstring(client_session_rx_data(i * 8 + 7 downto i * 8)) &
                   ", expected " & to_hstring(verify_cnt(7 downto 0) + i);
        end loop;

        verify_cnt <= verify_cnt + client_session_rx_bytes;

        -- Check for wrap-around
        if verify_cnt > verify_cnt + client_session_rx_bytes then
          stop;
        end if;
      end if;

      if rst = '1' then
        verify_cnt <= (others => '0');
      end if;
    end if;
  end process verify_proc;


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
      session_start_i       => '1',
      session_src_port_i    => C_PORT_CLIENT,
      session_dst_port_i    => C_PORT_SERVER,
      session_established_o => client_session_established,
      session_rx_ready_i    => client_session_rx_ready,
      session_rx_valid_o    => client_session_rx_valid,
      session_rx_data_o     => client_session_rx_data,
      session_rx_bytes_o    => client_session_rx_bytes,
      session_tx_ready_o    => client_session_tx_ready,
      session_tx_valid_i    => client_session_tx_valid,
      session_tx_data_i     => client_session_tx_data,
      session_tx_bytes_i    => client_session_tx_bytes,
      ip_payload_rx_ready_o => tb_ip_payload_s2c_dropped_ready,
      ip_payload_rx_valid_i => tb_ip_payload_s2c_dropped_valid,
      ip_payload_rx_data_i  => tb_ip_payload_s2c_dropped_data,
      ip_payload_rx_bytes_i => tb_ip_payload_s2c_dropped_bytes,
      ip_payload_rx_last_i  => tb_ip_payload_s2c_dropped_last,
      ip_payload_tx_ready_i => tb_ip_payload_c2s_ready,
      ip_payload_tx_valid_o => tb_ip_payload_c2s_valid,
      ip_payload_tx_data_o  => tb_ip_payload_c2s_data,
      ip_payload_tx_bytes_o => tb_ip_payload_c2s_bytes,
      ip_payload_tx_last_o  => tb_ip_payload_c2s_last
    ); -- tcp_wrapper_client_inst : entity work.tcp_wrapper

  -------------------------------------
  -- Drop random packets from client to server
  -------------------------------------

  axi_dropper_c2s_inst : entity work.axi_dropper
    generic map (
      G_DATA_SIZE => C_IP_PAYLOAD_BYTES * 8 + 8,
      G_ADDR_SIZE => 6,
      G_RAM_DEPTH => 64
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => tb_ip_payload_c2s_ready,
      s_valid_i => tb_ip_payload_c2s_valid,
      s_data_i  => tb_ip_payload_c2s_data_bytes,
      s_last_i  => tb_ip_payload_c2s_last,
      s_drop_i  => do_drop_c2s,
      m_ready_i => tb_ip_payload_c2s_dropped_ready,
      m_valid_o => tb_ip_payload_c2s_dropped_valid,
      m_data_o  => tb_ip_payload_c2s_dropped_data_bytes,
      m_last_o  => tb_ip_payload_c2s_dropped_last
    ); -- axi_dropper_c2s_inst : entity work.axi_dropper

  tb_ip_payload_c2s_data_bytes(R_DATA)  <= tb_ip_payload_c2s_data;
  tb_ip_payload_c2s_data_bytes(R_BYTES) <= to_stdlogicvector(tb_ip_payload_c2s_bytes, 8);

  tb_ip_payload_c2s_dropped_data        <= tb_ip_payload_c2s_dropped_data_bytes(R_DATA);
  tb_ip_payload_c2s_dropped_bytes       <= to_integer(tb_ip_payload_c2s_dropped_data_bytes(R_BYTES));


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
      session_start_i       => '1',
      session_dst_port_i    => X"0000",
      session_src_port_i    => C_PORT_SERVER,
      session_established_o => server_session_established,
      session_rx_ready_i    => server_session_rx_ready,
      session_rx_valid_o    => server_session_rx_valid,
      session_rx_data_o     => server_session_rx_data,
      session_rx_bytes_o    => server_session_rx_bytes,
      session_tx_ready_o    => server_session_tx_ready,
      session_tx_valid_i    => server_session_tx_valid,
      session_tx_data_i     => server_session_tx_data,
      session_tx_bytes_i    => server_session_tx_bytes,
      ip_payload_rx_ready_o => tb_ip_payload_c2s_dropped_ready,
      ip_payload_rx_valid_i => tb_ip_payload_c2s_dropped_valid,
      ip_payload_rx_data_i  => tb_ip_payload_c2s_dropped_data,
      ip_payload_rx_bytes_i => tb_ip_payload_c2s_dropped_bytes,
      ip_payload_rx_last_i  => tb_ip_payload_c2s_dropped_last,
      ip_payload_tx_ready_i => tb_ip_payload_s2c_ready,
      ip_payload_tx_valid_o => tb_ip_payload_s2c_valid,
      ip_payload_tx_data_o  => tb_ip_payload_s2c_data,
      ip_payload_tx_bytes_o => tb_ip_payload_s2c_bytes,
      ip_payload_tx_last_o  => tb_ip_payload_s2c_last
    ); -- tcp_wrapper_server_inst : entity work.tcp_wrapper

  -------------------------------------
  -- Drop random packets from server to client
  -------------------------------------

  axi_dropper_s2c_inst : entity work.axi_dropper
    generic map (
      G_DATA_SIZE => C_IP_PAYLOAD_BYTES * 8 + 8,
      G_ADDR_SIZE => 6,
      G_RAM_DEPTH => 64
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      s_ready_o => tb_ip_payload_s2c_ready,
      s_valid_i => tb_ip_payload_s2c_valid,
      s_data_i  => tb_ip_payload_s2c_data_bytes,
      s_last_i  => tb_ip_payload_s2c_last,
      s_drop_i  => do_drop_s2c,
      m_ready_i => tb_ip_payload_s2c_dropped_ready,
      m_valid_o => tb_ip_payload_s2c_dropped_valid,
      m_data_o  => tb_ip_payload_s2c_dropped_data_bytes,
      m_last_o  => tb_ip_payload_s2c_dropped_last
    ); -- axi_dropper_s2c_inst : entity work.axi_dropper


  tb_ip_payload_s2c_data_bytes(R_DATA)  <= tb_ip_payload_s2c_data;
  tb_ip_payload_s2c_data_bytes(R_BYTES) <= to_stdlogicvector(tb_ip_payload_s2c_bytes, 8);

  tb_ip_payload_s2c_dropped_data        <= tb_ip_payload_s2c_dropped_data_bytes(R_DATA);
  tb_ip_payload_s2c_dropped_bytes       <= to_integer(tb_ip_payload_s2c_dropped_data_bytes(R_BYTES));


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

