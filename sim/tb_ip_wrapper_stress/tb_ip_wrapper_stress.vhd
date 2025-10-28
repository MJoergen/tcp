library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std_unsigned.all;

library std;
  use std.env.stop;

-- The packet flow is as follows:
-- TB -> Client -> Server -> Loopback -> Server -> Client -> TB

entity tb_ip_wrapper_stress is
  generic (
    G_MAX_LENGTH    : natural;
    G_CNT_SIZE      : natural;
    G_RANDOM        : boolean;
    G_FAST          : boolean;
    G_SHOW_PACKETS  : boolean;
    G_SHOW_PROTOCOL : boolean
  );
end entity tb_ip_wrapper_stress;

-- Connect a IP client and a IP server and send data back and forth.

architecture simulation of tb_ip_wrapper_stress is

  constant C_MAC_PAYLOAD_BYTES : natural                       := 30;
  constant C_USER_BYTES        : natural                       := 20;
  constant C_ADDRESS_CLIENT    : std_logic_vector(31 downto 0) := x"C713C713";
  constant C_ADDRESS_SERVER    : std_logic_vector(31 downto 0) := x"53535353";
  constant C_PROTOCOL          : std_logic_vector(7 downto 0)  := x"06";

  constant C_TIMEOUT : time                                    := 200 ns;

  signal   clk     : std_logic                                 := '1';
  signal   rst     : std_logic                                 := '1';
  signal   running : std_logic                                 := '1';

  signal   client_user_established : std_logic;
  signal   server_user_established : std_logic;

  -- TB to Client
  signal   client_user_tx_ready : std_logic;
  signal   client_user_tx_valid : std_logic;
  signal   client_user_tx_data  : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal   client_user_tx_bytes : natural range 0 to C_USER_BYTES;
  signal   client_user_tx_last  : std_logic;

  -- Client to Server
  signal   tb_mac_payload_c2s_ready : std_logic;
  signal   tb_mac_payload_c2s_valid : std_logic;
  signal   tb_mac_payload_c2s_data  : std_logic_vector(C_MAC_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   tb_mac_payload_c2s_bytes : natural range 0 to C_MAC_PAYLOAD_BYTES;
  signal   tb_mac_payload_c2s_last  : std_logic;

  -- Server to User
  signal   server_user_rx_ready     : std_logic;
  signal   server_user_rx_valid     : std_logic;
  signal   server_user_rx_data      : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal   server_user_rx_bytes     : natural range 0 to C_USER_BYTES;
  signal   server_user_rx_bytes_slv : std_logic_vector(7 downto 0);
  signal   server_user_rx_last      : std_logic;

  -- Loopback data from server to client

  subtype  R_AXI_FIFO_DATA is natural range C_USER_BYTES * 8 - 1 downto 0;

  subtype  R_AXI_FIFO_BYTES is natural range C_USER_BYTES * 8 + 7 downto C_USER_BYTES * 8;

  constant C_AXI_FIFO_LAST : natural                           := C_USER_BYTES * 8 + 8;

  -- User to Server
  signal   server_user_tx_ready     : std_logic;
  signal   server_user_tx_valid     : std_logic;
  signal   server_user_tx_data      : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal   server_user_tx_bytes     : natural range 0 to C_USER_BYTES;
  signal   server_user_tx_bytes_slv : std_logic_vector(7 downto 0);
  signal   server_user_tx_last      : std_logic;

  -- Server to Client
  signal   tb_mac_payload_s2c_ready : std_logic;
  signal   tb_mac_payload_s2c_valid : std_logic;
  signal   tb_mac_payload_s2c_data  : std_logic_vector(C_MAC_PAYLOAD_BYTES * 8 - 1 downto 0);
  signal   tb_mac_payload_s2c_bytes : natural range 0 to C_MAC_PAYLOAD_BYTES;
  signal   tb_mac_payload_s2c_last  : std_logic;

  -- Client to TB
  signal   client_user_rx_ready : std_logic;
  signal   client_user_rx_valid : std_logic;
  signal   client_user_rx_data  : std_logic_vector(C_USER_BYTES * 8 - 1 downto 0);
  signal   client_user_rx_bytes : natural range 0 to C_USER_BYTES;
  signal   client_user_rx_last  : std_logic;

begin

  ----------------------------------------------------------
  -- Clock and reset
  ----------------------------------------------------------

  clk <= running and not clk after 5 ns;
  rst <= '1', '0' after 100 ns;


  ----------------------------------------------------------
  -- Generate stimuli and verify response
  ----------------------------------------------------------

  stim_verf_inst : entity work.stim_verf
    generic map (
      G_DEBUG      => true,
      G_RANDOM     => G_RANDOM,
      G_FAST       => G_FAST,
      G_MAX_LENGTH => G_MAX_LENGTH,
      G_CNT_SIZE   => G_CNT_SIZE,
      G_DATA_BYTES => C_USER_BYTES
    )
    port map (
      clk_i     => clk,
      rst_i     => rst,
      m_ready_i => client_user_tx_ready,
      m_valid_o => client_user_tx_valid,
      m_data_o  => client_user_tx_data,
      m_bytes_o => client_user_tx_bytes,
      m_last_o  => client_user_tx_last,
      s_ready_o => client_user_rx_ready,
      s_valid_i => client_user_rx_valid,
      s_data_i  => client_user_rx_data,
      s_bytes_i => client_user_rx_bytes,
      s_last_i  => client_user_rx_last
    ); -- stim_verf_inst : entity work.stim_verf


  ----------------------------------------------------------
  -- Instantiate DUT client (initiator)
  ----------------------------------------------------------

  ip_wrapper_client_inst : entity work.ip_wrapper
    generic map (
      G_SIM_NAME          => "CLIENT",
      G_MAC_PAYLOAD_BYTES => C_MAC_PAYLOAD_BYTES,
      G_USER_BYTES        => C_USER_BYTES
    )
    port map (
      clk_i                  => clk,
      rst_i                  => rst,
      user_start_i           => '1',
      user_src_address_i     => C_ADDRESS_CLIENT,
      user_dst_address_i     => C_ADDRESS_SERVER,
      user_protocol_i        => C_PROTOCOL,
      user_established_o     => client_user_established,
      user_rx_ready_i        => client_user_rx_ready,
      user_rx_valid_o        => client_user_rx_valid,
      user_rx_data_o         => client_user_rx_data,
      user_rx_bytes_o        => client_user_rx_bytes,
      user_rx_last_o         => client_user_rx_last,
      user_tx_ready_o        => client_user_tx_ready,
      user_tx_valid_i        => client_user_tx_valid,
      user_tx_data_i         => client_user_tx_data,
      user_tx_bytes_i        => client_user_tx_bytes,
      user_tx_last_i         => client_user_tx_last,
      mac_payload_rx_ready_o => tb_mac_payload_s2c_ready,
      mac_payload_rx_valid_i => tb_mac_payload_s2c_valid,
      mac_payload_rx_data_i  => tb_mac_payload_s2c_data,
      mac_payload_rx_bytes_i => tb_mac_payload_s2c_bytes,
      mac_payload_rx_last_i  => tb_mac_payload_s2c_last,
      mac_payload_tx_ready_i => tb_mac_payload_c2s_ready,
      mac_payload_tx_valid_o => tb_mac_payload_c2s_valid,
      mac_payload_tx_data_o  => tb_mac_payload_c2s_data,
      mac_payload_tx_bytes_o => tb_mac_payload_c2s_bytes,
      mac_payload_tx_last_o  => tb_mac_payload_c2s_last
    ); -- ip_wrapper_client_inst : entity work.ip_wrapper


  ----------------------------------------------------------
  -- Instantiate DUT server (responder)
  ----------------------------------------------------------

  ip_wrapper_server_inst : entity work.ip_wrapper
    generic map (
      G_SIM_NAME          => "SERVER",
      G_MAC_PAYLOAD_BYTES => C_MAC_PAYLOAD_BYTES,
      G_USER_BYTES        => C_USER_BYTES
    )
    port map (
      clk_i                  => clk,
      rst_i                  => rst,
      user_start_i           => '1',
      user_src_address_i     => C_ADDRESS_SERVER,
      user_dst_address_i     => X"00000000",
      user_protocol_i        => C_PROTOCOL,
      user_established_o     => server_user_established,
      user_rx_ready_i        => server_user_rx_ready,
      user_rx_valid_o        => server_user_rx_valid,
      user_rx_data_o         => server_user_rx_data,
      user_rx_bytes_o        => server_user_rx_bytes,
      user_rx_last_o         => server_user_rx_last,
      user_tx_ready_o        => server_user_tx_ready,
      user_tx_valid_i        => server_user_tx_valid,
      user_tx_data_i         => server_user_tx_data,
      user_tx_bytes_i        => server_user_tx_bytes,
      user_tx_last_i         => server_user_tx_last,
      mac_payload_rx_ready_o => tb_mac_payload_c2s_ready,
      mac_payload_rx_valid_i => tb_mac_payload_c2s_valid,
      mac_payload_rx_data_i  => tb_mac_payload_c2s_data,
      mac_payload_rx_bytes_i => tb_mac_payload_c2s_bytes,
      mac_payload_rx_last_i  => tb_mac_payload_c2s_last,
      mac_payload_tx_ready_i => tb_mac_payload_s2c_ready,
      mac_payload_tx_valid_o => tb_mac_payload_s2c_valid,
      mac_payload_tx_data_o  => tb_mac_payload_s2c_data,
      mac_payload_tx_bytes_o => tb_mac_payload_s2c_bytes,
      mac_payload_tx_last_o  => tb_mac_payload_s2c_last
    ); -- tcp_wrapper_server_inst : entity work.tcp_wrapper


  ----------------------------------------------------------
  -- Loopback data from server to client
  ----------------------------------------------------------

  axi_fifo_sync_inst : entity work.axi_fifo_sync
    generic map (
      G_RAM_STYLE => "auto",
      G_DATA_SIZE => C_USER_BYTES * 8 + 9,
      G_RAM_DEPTH => 4
    )
    port map (
      clk_i                      => clk,
      rst_i                      => rst,
      s_ready_o                  => server_user_rx_ready,
      s_valid_i                  => server_user_rx_valid,
      s_data_i(R_AXI_FIFO_DATA)  => server_user_rx_data,
      s_data_i(R_AXI_FIFO_BYTES) => server_user_rx_bytes_slv,
      s_data_i(C_AXI_FIFO_LAST)  => server_user_rx_last,
      m_ready_i                  => server_user_tx_ready,
      m_valid_o                  => server_user_tx_valid,
      m_data_o(R_AXI_FIFO_DATA)  => server_user_tx_data,
      m_data_o(R_AXI_FIFO_BYTES) => server_user_tx_bytes_slv,
      m_data_o(C_AXI_FIFO_LAST)  => server_user_tx_last
    ); -- axi_fifo_sync_inst : entity work.axi_fifo_sync

  server_user_rx_bytes_slv <= to_stdlogicvector(server_user_rx_bytes, 8);
  server_user_tx_bytes     <= to_integer(server_user_tx_bytes_slv);


  ----------------------------------------------------------
  -- Dump data packets
  ----------------------------------------------------------

  data_logger_c2s_inst : entity work.data_logger
    generic map (
      G_ENABLE    => G_SHOW_PACKETS,
      G_LOG_NAME  => "C2S", -- Client to Server
      G_DATA_SIZE => C_MAC_PAYLOAD_BYTES * 8
    )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      ready_i => tb_mac_payload_c2s_ready,
      valid_i => tb_mac_payload_c2s_valid,
      data_i  => tb_mac_payload_c2s_data,
      bytes_i => tb_mac_payload_c2s_bytes,
      last_i  => tb_mac_payload_c2s_last
    ); -- data_logger_c2s_inst : entity work.data_logger

  data_logger_s2c_inst : entity work.data_logger
    generic map (
      G_ENABLE    => G_SHOW_PACKETS,
      G_LOG_NAME  => "S2C", -- Server to Client
      G_DATA_SIZE => C_MAC_PAYLOAD_BYTES * 8
    )
    port map (
      clk_i   => clk,
      rst_i   => rst,
      ready_i => tb_mac_payload_s2c_ready,
      valid_i => tb_mac_payload_s2c_valid,
      data_i  => tb_mac_payload_s2c_data,
      bytes_i => tb_mac_payload_s2c_bytes,
      last_i  => tb_mac_payload_s2c_last
    ); -- data_logger_s2c_inst : entity work.data_logger

end architecture simulation;

